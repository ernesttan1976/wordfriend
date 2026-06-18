import { Router } from 'express';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../auth/jwt';

const router = Router();

router.use(authMiddleware);

// Get the single child profile for the current user (if any)
router.get('/', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { rows } = await pool.query(
    'SELECT id, age, theme, tts_engine, tts_voice FROM children WHERE user_id = $1 LIMIT 1',
    [userId],
  );

  if (rows.length === 0) {
    res.status(404).json({ error: 'Child profile not found' });
    return;
  }

  res.json(rows[0]);
});

interface UpsertChildBody {
  age: number;
  theme: 'pony' | 'lego';
}

// Create or update the single child profile for this user
router.put('/', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { age, theme } = req.body as UpsertChildBody;

  if (!age || age <= 0) {
    res.status(400).json({ error: 'Valid age is required' });
    return;
  }

  if (theme !== 'pony' && theme !== 'lego') {
    res.status(400).json({ error: "theme must be 'pony' or 'lego'" });
    return;
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const existing = await client.query(
      'SELECT id FROM children WHERE user_id = $1 LIMIT 1',
      [userId],
    );

    let childId: string;

    if (existing.rows.length === 0) {
      const insert = await client.query(
        `INSERT INTO children (user_id, age, theme, tts_engine, created_at, updated_at)
         VALUES ($1, $2, $3, 'native', now(), now())
         RETURNING id, age, theme, tts_engine, tts_voice`,
        [userId, age, theme],
      );
      childId = insert.rows[0].id;
      await client.query('COMMIT');
      res.status(201).json(insert.rows[0]);
      return;
    }

    childId = existing.rows[0].id;
    const update = await client.query(
      `UPDATE children
       SET age = $1,
           theme = $2,
           updated_at = now()
       WHERE id = $3
       RETURNING id, age, theme, tts_engine, tts_voice`,
      [age, theme, childId],
    );

    await client.query('COMMIT');
    res.json(update.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Failed to upsert child profile', err);
    res.status(500).json({ error: 'Failed to save child profile' });
  } finally {
    client.release();
  }
});

// Update TTS settings for this user's child
router.patch('/tts-settings', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { ttsEngine, ttsVoice } = req.body as {
    ttsEngine?: 'native' | 'openai';
    ttsVoice?: string;
  };

  if (ttsEngine !== 'native' && ttsEngine !== 'openai') {
    res.status(400).json({ error: 'Invalid ttsEngine' });
    return;
  }

  if (ttsEngine === 'openai' && (!ttsVoice || typeof ttsVoice !== 'string')) {
    res.status(400).json({ error: 'Valid ttsVoice required for openai engine' });
    return;
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const existing = await client.query(
      'SELECT id FROM children WHERE user_id = $1 LIMIT 1',
      [userId],
    );

    if (existing.rows.length === 0) {
      await client.query('ROLLBACK');
      res.status(404).json({ error: 'Child profile not found' });
      return;
    }

    const childId = existing.rows[0].id;

    const update = await client.query(
      `UPDATE children
       SET tts_engine = $1,
           tts_voice = $2,
           updated_at = now()
       WHERE id = $3
       RETURNING id, age, theme, tts_engine, tts_voice`,
      [ttsEngine, ttsEngine === 'openai' ? ttsVoice : null, childId],
    );

    await client.query('COMMIT');
    res.json(update.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Failed to update TTS settings', err);
    res.status(500).json({ error: 'Failed to update TTS settings' });
  } finally {
    client.release();
  }
});

export default router;
