import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';
import { config } from '../config';

export interface AuthUser {
  id: string;
  email?: string | null;
}

export interface AuthRequest extends Request {
  user?: AuthUser;
}

const JWT_EXPIRES_IN = '7d';

export function signAccessToken(user: AuthUser): string {
  if (!config.jwtSecret) {
    throw new Error('JWT_SECRET is not configured');
  }

  const payload = {
    sub: user.id,
    email: user.email ?? undefined,
  };

  return jwt.sign(payload, config.jwtSecret, {
    expiresIn: JWT_EXPIRES_IN,
  });
}

export function authMiddleware(req: AuthRequest, res: Response, next: NextFunction): void {
  const header = req.header('Authorization');
  if (!header || !header.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing Authorization header' });
    return;
  }

  const token = header.slice('Bearer '.length);

  try {
    if (!config.jwtSecret) {
      throw new Error('JWT_SECRET is not configured');
    }

    const decoded = jwt.verify(token, config.jwtSecret) as { sub: string; email?: string };
    req.user = { id: decoded.sub, email: decoded.email }; // attach minimal user context
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}
