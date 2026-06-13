import { Router } from 'express';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../auth/jwt';

const router = Router();

router.use(authMiddleware);

// Get all word lists for the current user's child
router.get('/', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const childResult = await pool.query(
    'SELECT id FROM children WHERE user_id = $1 LIMIT 1',
    [userId],
  );

  if (childResult.rows.length === 0) {
    res.status(404).json({ error: 'Child profile not found' });
    return;
  }

  const childId: string = childResult.rows[0].id;

  const listsResult = await pool.query(
    `SELECT wl.id,
            wl.name,
            wl.source,
            wl.prompt,
            wl.created_at,
            wl.updated_at,
            COUNT(wli.word_id)::int AS word_count
       FROM word_lists wl
       LEFT JOIN word_list_items wli ON wli.word_list_id = wl.id
      WHERE wl.child_id = $1
      GROUP BY wl.id
      ORDER BY wl.created_at DESC`,
    [childId],
  );

  res.json(listsResult.rows);
});

interface CreateListBody {
  name: string;
  prompt?: string | null;
}

// Create a new manual word list for the current user's child
router.post('/', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { name, prompt } = req.body as CreateListBody;

  if (!name || !name.trim()) {
    res.status(400).json({ error: 'name is required' });
    return;
  }

  const childResult = await pool.query(
    'SELECT id FROM children WHERE user_id = $1 LIMIT 1',
    [userId],
  );

  if (childResult.rows.length === 0) {
    res.status(404).json({ error: 'Child profile not found' });
    return;
  }

  const childId: string = childResult.rows[0].id;

  const insertResult = await pool.query(
    `INSERT INTO word_lists (child_id, name, source, prompt)
     VALUES ($1, $2, 'manual', $3)
     RETURNING id, name, source, prompt, created_at, updated_at`,
    [childId, name.trim(), prompt ?? null],
  );

  res.status(201).json(insertResult.rows[0]);
});

// Get a specific word list and its words
router.get('/:id', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { id } = req.params;

  const listResult = await pool.query(
    `SELECT wl.id,
            wl.name,
            wl.source,
            wl.prompt,
            wl.created_at,
            wl.updated_at,
            wl.child_id
       FROM word_lists wl
       JOIN children c ON wl.child_id = c.id
      WHERE wl.id = $1
        AND c.user_id = $2
      LIMIT 1`,
    [id, userId],
  );

  if (listResult.rows.length === 0) {
    res.status(404).json({ error: 'Word list not found' });
    return;
  }

  const list = listResult.rows[0];

  const wordsResult = await pool.query(
    `SELECT w.id,
            w.spelling,
            w.phonics_pattern,
            wli.position
       FROM word_list_items wli
       JOIN words w ON wli.word_id = w.id
      WHERE wli.word_list_id = $1
      ORDER BY COALESCE(wli.position, 0), w.spelling`,
    [id],
  );

  res.json({
    ...list,
    words: wordsResult.rows,
  });
});

interface IncomingWord {
  spelling: string;
  phonicsPattern?: string | null;
}

interface AddWordsBody {
  words: IncomingWord[];
}

function normalizeSpelling(spelling: string): string {
  return spelling.trim();
}

// Add words to a list (manual entry)
router.post('/:id/words', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { id: listId } = req.params;
  const { words } = req.body as AddWordsBody;

  if (!Array.isArray(words) || words.length === 0) {
    res.status(400).json({ error: 'words array is required' });
    return;
  }

  // Ensure the list belongs to the current user
  const listResult = await pool.query(
    `SELECT wl.id, wl.child_id
       FROM word_lists wl
       JOIN children c ON wl.child_id = c.id
      WHERE wl.id = $1
        AND c.user_id = $2
      LIMIT 1`,
    [listId, userId],
  );

  if (listResult.rows.length === 0) {
    res.status(404).json({ error: 'Word list not found' });
    return;
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const maxPosResult = await client.query(
      'SELECT COALESCE(MAX(position), 0) AS max_pos FROM word_list_items WHERE word_list_id = $1',
      [listId],
    );

    let position: number = maxPosResult.rows[0].max_pos ?? 0;

    const added: Array<{ id: string; spelling: string; phonicsPattern: string | null; position: number }> = [];

    for (const incoming of words) {
      const spelling = normalizeSpelling(incoming.spelling);

      if (!spelling) {
        // Skip empty strings rather than failing the whole request
        // This keeps UX simple for small mistakes.
        continue;
      }

      const phonicsPattern = incoming.phonicsPattern ?? null;

      // Find or create word by spelling
      const existingWord = await client.query(
        'SELECT id, spelling, phonics_pattern FROM words WHERE spelling = $1 LIMIT 1',
        [spelling],
      );

      let wordId: string;

      if (existingWord.rows.length === 0) {
        const insertWord = await client.query(
          'INSERT INTO words (spelling, phonics_pattern) VALUES ($1, $2) RETURNING id, spelling, phonics_pattern',
          [spelling, phonicsPattern],
        );
        wordId = insertWord.rows[0].id;
      } else {
        wordId = existingWord.rows[0].id;

        // Optionally backfill phonics_pattern if we have a new one
        if (!existingWord.rows[0].phonics_pattern && phonicsPattern) {
          await client.query(
            'UPDATE words SET phonics_pattern = $1 WHERE id = $2',
            [phonicsPattern, wordId],
          );
        }
      }

      position += 1;

      await client.query(
        `INSERT INTO word_list_items (word_list_id, word_id, position)
         VALUES ($1, $2, $3)
         ON CONFLICT (word_list_id, word_id) DO NOTHING`,
        [listId, wordId, position],
      );

      added.push({ id: wordId, spelling, phonicsPattern, position });
    }

    await client.query('COMMIT');

    res.status(201).json({ words: added });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Failed to add words to list', err);
    res.status(500).json({ error: 'Failed to add words to list' });
  } finally {
    client.release();
  }
});

// Get up to `size` recommended words from a list for the current user's child.
// This is a simple random selection for now; spaced repetition will refine it later.
router.get('/:id/recommendations', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { id: listId } = req.params;
  const sizeParam = req.query.size as string | undefined;
  const size = Math.max(1, Math.min(50, sizeParam ? parseInt(sizeParam, 10) || 10 : 10));

  // Ensure list belongs to this user and get child_id for future use
  const listResult = await pool.query(
    `SELECT wl.id, wl.child_id
       FROM word_lists wl
       JOIN children c ON wl.child_id = c.id
      WHERE wl.id = $1
        AND c.user_id = $2
      LIMIT 1`,
    [listId, userId],
  );

  if (listResult.rows.length === 0) {
    res.status(404).json({ error: 'Word list not found' });
    return;
  }

  const wordsResult = await pool.query(
    `SELECT w.id,
            w.spelling,
            w.phonics_pattern
       FROM word_list_items wli
       JOIN words w ON wli.word_id = w.id
      WHERE wli.word_list_id = $1
      ORDER BY random()
      LIMIT $2`,
    [listId, size],
  );

  res.json({ words: wordsResult.rows });
});

export default router;
