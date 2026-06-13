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
    'SELECT id, age, theme FROM children WHERE user_id = $1 LIMIT 1',
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
        'INSERT INTO children (user_id, age, theme) VALUES ($1, $2, $3) RETURNING id, age, theme',
        [userId, age, theme],
      );
      childId = insert.rows[0].id;
      await client.query('COMMIT');
      res.status(201).json(insert.rows[0]);
      return;
    }

    childId = existing.rows[0].id;
    const update = await client.query(
      'UPDATE children SET age = $1, theme = $2, updated_at = now() WHERE id = $3 RETURNING id, age, theme',
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

export default router;
