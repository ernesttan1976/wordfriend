import { Router } from 'express';
import OpenAI from 'openai';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../auth/jwt';
import { config } from '../config';

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
            COUNT(wli.word_id)::int AS word_count,
            COALESCE(
              (
                SELECT json_agg(w.spelling ORDER BY wli2.position)
                FROM word_list_items wli2
                JOIN words w ON w.id = wli2.word_id
                WHERE wli2.word_list_id = wl.id
                ORDER BY wli2.position
                LIMIT 3
              ),
              '[]'
            ) AS preview_words
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
    `INSERT INTO word_lists (child_id, name, source, prompt, updated_at)
     VALUES ($1, $2, 'manual', $3, NOW())
     RETURNING id, name, source, prompt, created_at, updated_at`,
    [childId, name.trim(), prompt ?? null],
  );

  res.status(201).json(insertResult.rows[0]);
});

interface GenerateListBody {
  prompt: string;
  size?: number;
  name?: string;
}

interface GeneratedWord {
  spelling: string;
  phonics_pattern?: string | null;
}

function buildDeterministicHints(word: string) {
  const lettersOnly = word.replace(/[^A-Za-z]/g, '');
  const letterCount = `${lettersOnly.length} letters`;
  const firstLast = `${lettersOnly[0]} ... ${lettersOnly[lettersOnly.length - 1]}`;
  const consonants = lettersOnly
    .split('')
    .map((c) => (/[aeiouAEIOU]/.test(c) ? '_' : c))
    .join('');

  return {
    hintLetterCount: letterCount,
    hintFirstLast: firstLast,
    hintConsonants: consonants,
  };
}

function sanitizeGeneratedWord(raw: GeneratedWord): GeneratedWord | null {
  const spelling = (raw.spelling || '').trim();
  if (!spelling) return null;

  // Only keep reasonable alphabetic words; avoid numbers/symbols.
  if (!/^[A-Za-z]{2,24}$/.test(spelling)) return null;

  const phonicsPattern = raw.phonics_pattern?.trim() || null;
  return { spelling, phonics_pattern: phonicsPattern };
}

// Generate a new AI-powered list using OpenAI GPT-5.1
router.post('/generate', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  if (!config.openaiApiKey) {
    res.status(500).json({ error: 'AI service is not configured' });
    return;
  }

  const { prompt, size, name } = req.body as GenerateListBody;

  if (!prompt || !prompt.trim()) {
    res.status(400).json({ error: 'prompt is required' });
    return;
  }

  const limit = Math.max(5, Math.min(50, size ?? 10));

  const childResult = await pool.query(
    'SELECT id, age FROM children WHERE user_id = $1 LIMIT 1',
    [userId],
  );

  if (childResult.rows.length === 0) {
    res.status(404).json({ error: 'Child profile not found' });
    return;
  }

  const childId: string = childResult.rows[0].id;
  const age: number | null = childResult.rows[0].age ?? null;

  const openai = new OpenAI({ apiKey: config.openaiApiKey });

  const systemPrompt =
    'You help a child learn English spelling (British English). ' +
    'Generate a list of single English words that are age-appropriate, family-friendly, and match the requested theme or pattern. ' +
    'Focus on words that are useful for practice and avoid offensive, adult, or sensitive content. ' +
    'Respond ONLY with JSON in the format {"words":[{"spelling":"...","phonics_pattern":"..."}, ...]}. No extra text.';

  const userPromptParts = [
    `Prompt: ${prompt.trim()}`,
    `Target age: ${age ?? 'unknown (assume around 10-11)'}`,
    `Number of words: ${limit}`,
    'Prefer words that will help a dyslexic 9–12 year old connect sounds to letters.',
  ];

  try {
    const completion = await openai.chat.completions.create({
      model: config.openaiModel,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPromptParts.join('\n') },
      ],
      temperature: 0.7,
      max_completion_tokens: 800,
      response_format: { type: 'json_object' },
    });

    const content = completion.choices[0]?.message?.content;
    if (!content) {
      throw new Error('Empty response from OpenAI');
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(content);
    } catch (err) {
      console.error('Failed to parse OpenAI JSON', err, content);
      throw new Error('AI returned invalid JSON');
    }

    const wordsRaw = (parsed as { words?: GeneratedWord[] }).words;
    if (!Array.isArray(wordsRaw) || wordsRaw.length === 0) {
      throw new Error('AI returned no words');
    }

    const sanitized = wordsRaw
      .map(sanitizeGeneratedWord)
      .filter((w): w is GeneratedWord => w !== null)
      .slice(0, limit);

    if (sanitized.length === 0) {
      throw new Error('No valid words after sanitization');
    }

    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      // Generate short 2-word title via AI
      let listName = name?.trim();
      if (!listName) {
        const titleCompletion = await openai.chat.completions.create({
          model: config.openaiModel,
          messages: [
            { role: 'system', content: 'Generate a short, friendly 2-word title (max 2 words) for a children spelling list. Respond with plain text only.' },
            { role: 'user', content: `Prompt: ${prompt.trim()}` },
          ],
          temperature: 0.5,
          max_completion_tokens: 20,
        });

        listName =
          titleCompletion.choices[0]?.message?.content?.trim().split(/\s+/).slice(0, 2).join(' ') ||
          prompt.trim().split(/\s+/).slice(0, 2).join(' ');
      }

      const listInsert = await client.query(
        `INSERT INTO word_lists (child_id, name, source, prompt, updated_at)
         VALUES ($1, $2, 'ai', $3, NOW())
         RETURNING id, name, source, prompt, created_at, updated_at`,
        [childId, listName, prompt.trim()],
      );

      const list = listInsert.rows[0];
      const listId: string = list.id;

      let position = 0;
      const added: Array<{ id: string; spelling: string; phonicsPattern: string | null; position: number }> = [];

      for (const word of sanitized) {
        const spelling = word.spelling;
        const phonicsPattern = word.phonics_pattern ?? null;

        const existingWord = await client.query(
          'SELECT id, phonics_pattern FROM words WHERE spelling = $1 LIMIT 1',
          [spelling],
        );

        let wordId: string;

        if (existingWord.rows.length === 0) {
          // Generate hints (deterministic + AI sentence/similar)
          const det = buildDeterministicHints(spelling);

          const hintCompletion = await openai.chat.completions.create({
            model: config.openaiModel,
            messages: [
              {
                role: 'system',
                content:
                  'For the given single word, respond ONLY with JSON: {"sentence":"...","similar":"..."}. Sentence should use the word naturally. Similar should be a child-friendly similar word.',
              },
              { role: 'user', content: spelling },
            ],
            temperature: 0.6,
            max_completion_tokens: 100,
            response_format: { type: 'json_object' },
          });

          let sentenceHint: string | null = null;
          let similarHint: string | null = null;
          try {
            const parsedHints = JSON.parse(hintCompletion.choices[0]?.message?.content || '{}');
            sentenceHint = parsedHints.sentence ?? null;
            similarHint = parsedHints.similar ?? null;
          } catch {
            sentenceHint = null;
            similarHint = null;
          }

          const insertWord = await client.query(
            `INSERT INTO words (
               spelling, phonics_pattern,
               hint_letter_count, hint_first_last, hint_consonants,
               hint_sentence, hint_similar
             ) VALUES ($1,$2,$3,$4,$5,$6,$7)
             RETURNING id`,
            [
              spelling,
              phonicsPattern,
              det.hintLetterCount,
              det.hintFirstLast,
              det.hintConsonants,
              sentenceHint,
              similarHint,
            ],
          );
          wordId = insertWord.rows[0].id;
        } else {
          wordId = existingWord.rows[0].id;

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

      res.status(201).json({
        list,
        words: added,
      });
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('Failed to save generated word list', err);
      res.status(500).json({ error: 'Failed to save generated word list' });
    } finally {
      client.release();
    }
  } catch (err) {
    console.error('AI generation failed', err);
    res.status(500).json({ error: 'Failed to generate word list' });
  }
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

// Rename a word list
router.put('/:id', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { id } = req.params;
  const { name } = req.body as { name?: string };

  if (!name || !name.trim()) {
    res.status(400).json({ error: 'name is required' });
    return;
  }

  const result = await pool.query(
    `UPDATE word_lists wl
        SET name = $1, updated_at = now()
      FROM children c
     WHERE wl.id = $2
       AND wl.child_id = c.id
       AND c.user_id = $3
     RETURNING wl.id, wl.name, wl.source, wl.prompt, wl.created_at, wl.updated_at`,
    [name.trim(), id, userId],
  );

  if (result.rows.length === 0) {
    res.status(404).json({ error: 'Word list not found' });
    return;
  }

  res.json(result.rows[0]);
});

// Delete a word list
router.delete('/:id', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { id } = req.params;

  const result = await pool.query(
    `DELETE FROM word_lists wl
      USING children c
     WHERE wl.id = $1
       AND wl.child_id = c.id
       AND c.user_id = $2
     RETURNING wl.id`,
    [id, userId],
  );

  if (result.rows.length === 0) {
    res.status(404).json({ error: 'Word list not found' });
    return;
  }

  res.status(204).send();
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

// Update a word (spelling and/or phonics_pattern) within a list
router.put('/:listId/words/:wordId', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { listId, wordId } = req.params;
  const { spelling, phonicsPattern } = req.body as {
    spelling?: string;
    phonicsPattern?: string | null;
  };

  if (!spelling || !spelling.trim()) {
    res.status(400).json({ error: 'spelling is required' });
    return;
  }

  // Ensure list belongs to user and word is part of the list
  const ownershipCheck = await pool.query(
    `SELECT 1
       FROM word_list_items wli
       JOIN word_lists wl ON wli.word_list_id = wl.id
       JOIN children c ON wl.child_id = c.id
      WHERE wli.word_list_id = $1
        AND wli.word_id = $2
        AND c.user_id = $3
      LIMIT 1`,
    [listId, wordId, userId],
  );

  if (ownershipCheck.rows.length === 0) {
    res.status(404).json({ error: 'Word not found in this list' });
    return;
  }

  const result = await pool.query(
    `UPDATE words
        SET spelling = $1,
            phonics_pattern = $2
      WHERE id = $3
      RETURNING id, spelling, phonics_pattern`,
    [spelling.trim(), phonicsPattern ?? null, wordId],
  );

  res.json(result.rows[0]);
});

// Remove a word from a specific list (does not delete the global word)
router.delete('/:listId/words/:wordId', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { listId, wordId } = req.params;

  const result = await pool.query(
    `DELETE FROM word_list_items wli
      USING word_lists wl, children c
     WHERE wli.word_list_id = $1
       AND wli.word_id = $2
       AND wli.word_list_id = wl.id
       AND wl.child_id = c.id
       AND c.user_id = $3
     RETURNING wli.word_id`,
    [listId, wordId, userId],
  );

  if (result.rows.length === 0) {
    res.status(404).json({ error: 'Word not found in this list' });
    return;
  }

  res.status(204).send();
});

interface RandomFromListsBody {
  listIds: string[];
  size?: number;
}

// Random words from multiple selected lists
router.post('/random-from-lists', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { listIds, size } = req.body as RandomFromListsBody;

  if (!Array.isArray(listIds) || listIds.length === 0) {
    res.status(400).json({ error: 'listIds array is required' });
    return;
  }

  const limit = Math.max(1, Math.min(50, size ?? 10));

  // Ensure all lists belong to this user
  const listsCheck = await pool.query(
    `SELECT wl.id
       FROM word_lists wl
       JOIN children c ON wl.child_id = c.id
      WHERE wl.id = ANY($1)
        AND c.user_id = $2`,
    [listIds, userId],
  );

  if (listsCheck.rows.length === 0) {
    res.status(404).json({ error: 'No valid lists found' });
    return;
  }

  const wordsResult = await pool.query(
    `SELECT w.id,
            w.spelling,
            w.phonics_pattern
       FROM word_list_items wli
       JOIN words w ON wli.word_id = w.id
      WHERE wli.word_list_id = ANY($1)
      GROUP BY w.id, w.spelling, w.phonics_pattern
      ORDER BY random()
      LIMIT $2`,
    [listIds, limit],
  );

  res.json({ words: wordsResult.rows });
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
