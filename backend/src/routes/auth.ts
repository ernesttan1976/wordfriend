import { Router } from 'express';
import { verifyGoogleIdToken } from '../auth/google';
import { pool } from '../db';
import { signAccessToken, AuthRequest } from '../auth/jwt';

const router = Router();

interface GoogleAuthBody {
  idToken: string;
}

router.post('/google', async (req: AuthRequest, res) => {
  const { idToken } = req.body as GoogleAuthBody;

  if (!idToken) {
    res.status(400).json({ error: 'idToken is required' });
    return;
  }

  try {
    const googleUser = await verifyGoogleIdToken(idToken);

    // Find or create user
    const { rows } = await pool.query(
      'SELECT id, email FROM users WHERE auth_provider = $1 AND auth_provider_id = $2',
      ['google', googleUser.sub],
    );

    let userId: string;
    let email: string | null | undefined = googleUser.email;

    if (rows.length === 0) {
      const insert = await pool.query(
        `INSERT INTO users (auth_provider, auth_provider_id, email, created_at, updated_at)
         VALUES ($1, $2, $3, now(), now())
         RETURNING id, email`,
        ['google', googleUser.sub, googleUser.email ?? null],
      );
      userId = insert.rows[0].id;
      email = insert.rows[0].email;
    } else {
      userId = rows[0].id;
      email = rows[0].email;
    }

    const token = signAccessToken({ id: userId, email });

    res.json({
      token,
      user: {
        id: userId,
        email,
      },
    });
  } catch (err) {
    console.error('Google auth failed', err);
    res.status(401).json({ error: 'Invalid Google token' });
  }
});

export default router;
