import { Pool } from 'pg';
import { config } from './config';

if (!config.databaseUrl) {
  // Fail fast in development if env is misconfigured
  throw new Error('DATABASE_URL environment variable is required');
}

export const pool = new Pool({ connectionString: config.databaseUrl });

export async function healthCheck(): Promise<boolean> {
  try {
    const res = await pool.query('SELECT 1');
    return res.rowCount === 1;
  } catch {
    return false;
  }
}
