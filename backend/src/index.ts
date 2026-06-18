import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { healthCheck } from './db';
import { config } from './config';
import authRoutes from './routes/auth';
import childRoutes from './routes/child';
import wordListsRoutes from './routes/wordLists';
import quizRoutes from './routes/quiz';

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json());

// Simple request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  console.log(`[REQ] ${req.method} ${req.originalUrl}`);

  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(
      `[RES] ${req.method} ${req.originalUrl} ${res.statusCode} ${duration}ms`
    );
  });

  next();
});

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

app.use('/auth', authRoutes);
app.use('/child', childRoutes);
app.use('/word-lists', wordListsRoutes);
app.use('/', quizRoutes);

// Centralized error handler
app.use((err: any, req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('[ERROR]', {
    method: req.method,
    url: req.originalUrl,
    message: err?.message,
    stack: err?.stack,
  });

  res.status(500).json({
    error: 'Internal server error',
  });
});

const port = config.port;

app.listen(port, () => {
  // Basic startup log
  console.log(`API listening on port ${port}`);
});
