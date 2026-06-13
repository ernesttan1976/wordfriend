import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { healthCheck } from './db';

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.get('/health/db', async (_req, res) => {
  const dbOk = await healthCheck();
  if (!dbOk) {
    res.status(500).json({ status: 'error', db: 'unhealthy' });
    return;
  }
  res.json({ status: 'ok', db: 'healthy' });
});

const port = process.env.PORT || 4000;

app.listen(port, () => {
  // Basic startup log
  console.log(`API listening on port ${port}`);
});
