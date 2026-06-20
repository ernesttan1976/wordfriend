import { Router } from 'express';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../auth/jwt';
import { updateAfterAttempt } from '../spacedRepetition';
import OpenAI from 'openai';
import { config } from '../config';

const router = Router();

router.use(authMiddleware);

const openai = config.openaiApiKey
  ? new OpenAI({ apiKey: config.openaiApiKey })
  : null;

type QuizMode = 'listen_type' | 'read_say';

interface CreateSessionBody {
  wordListId: string;
  mode: QuizMode;
  size?: number;
}

interface CandidateWordRow {
  id: string;
  spelling: string;
  phonics_pattern: string | null;
  difficulty: number | null;
  streak: number | null;
  next_due_at: Date | null;
  last_result: 'correct' | 'incorrect' | null;
}

function selectWordsForQuiz(candidates: CandidateWordRow[], size: number, now: Date): CandidateWordRow[] {
  if (candidates.length <= size) return candidates;

  // Compute a priority score per word.
  // Higher score = more urgent to practice.
  const scored = candidates.map((w) => {
    const difficulty = w.difficulty ?? 3; // base difficulty
    const nextDue = w.next_due_at;

    let score = 0;

    // New words (no stats) get a small boost so they appear early.
    if (w.next_due_at === null && w.last_result === null) {
      score += 3;
    }

    if (!nextDue || nextDue <= now) {
      // Due now or overdue.
      score += 5;
    } else {
      // Not yet due: smaller bonus depending on how soon they are due.
      const msUntil = nextDue.getTime() - now.getTime();
      const daysUntil = msUntil / (24 * 60 * 60 * 1000);
      if (daysUntil < 1) score += 4;
      else if (daysUntil < 3) score += 2;
      else score += 1;
    }

    // Harder words should get more priority.
    score += difficulty;

    return { word: w, score };
  });

  scored.sort((a, b) => b.score - a.score || a.word.spelling.localeCompare(b.word.spelling));

  return scored.slice(0, size).map((s) => s.word);
}

// Create a new quiz session and select words using spaced repetition signals.
router.post('/quiz-sessions', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { wordListId, mode, size } = req.body as CreateSessionBody;

  if (!wordListId) {
    res.status(400).json({ error: 'wordListId is required' });
    return;
  }

  if (mode !== 'listen_type' && mode !== 'read_say') {
    res.status(400).json({ error: "mode must be 'listen_type' or 'read_say'" });
    return;
  }

  const limit = Math.max(1, Math.min(50, size ?? 10));

  // Ensure the list belongs to the current user's child and get child_id.
  const listResult = await pool.query(
    `SELECT wl.id, wl.child_id
       FROM word_lists wl
       JOIN children c ON wl.child_id = c.id
      WHERE wl.id = $1
        AND c.user_id = $2
      LIMIT 1`,
    [wordListId, userId],
  );

  if (listResult.rows.length === 0) {
    res.status(404).json({ error: 'Word list not found' });
    return;
  }

  const childId: string = listResult.rows[0].child_id;

  // Get global difficulty bias for this child
  const biasResult = await pool.query(
    'SELECT global_difficulty_bias FROM children WHERE id = $1 LIMIT 1',
    [childId],
  );

  const globalBias: number = biasResult.rows[0]?.global_difficulty_bias ?? 0;

  const wordsResult = await pool.query(
    `SELECT w.id,
            w.spelling,
            w.phonics_pattern,
            cws.difficulty,
            cws.streak,
            cws.next_due_at,
            cws.last_result
       FROM word_list_items wli
       JOIN words w ON wli.word_id = w.id
  LEFT JOIN child_word_stats cws
         ON cws.word_id = w.id
        AND cws.child_id = $2
      WHERE wli.word_list_id = $1`,
    [wordListId, childId],
  );

  const now = new Date();

  const candidates: CandidateWordRow[] = wordsResult.rows.map((row) => ({
    id: row.id as string,
    spelling: row.spelling as string,
    phonics_pattern: (row.phonics_pattern ?? null) as string | null,
    difficulty: (row.difficulty ?? null) as number | null,
    streak: (row.streak ?? null) as number | null,
    next_due_at: (row.next_due_at ?? null) as Date | null,
    last_result: (row.last_result ?? null) as 'correct' | 'incorrect' | null,
  }));

  // Apply global bias to difficulty before selection
  candidates.forEach((c) => {
    const base = c.difficulty ?? 3;
    c.difficulty = Math.max(1, Math.min(10, base + globalBias));
  });

  if (candidates.length === 0) {
    res.status(400).json({ error: 'Word list has no words' });
    return;
  }

  const selected = selectWordsForQuiz(candidates, limit, now);

  const sessionResult = await pool.query(
    `INSERT INTO quiz_sessions (child_id, mode, word_list_id)
     VALUES ($1, $2, $3)
     RETURNING id, child_id, mode, word_list_id, started_at, completed_at`,
    [childId, mode, wordListId],
  );

  const session = sessionResult.rows[0];

  res.status(201).json({
    id: session.id,
    mode: session.mode,
    wordListId: session.word_list_id,
    startedAt: session.started_at,
    completedAt: session.completed_at,
    words: selected.map((w) => ({
      id: w.id,
      spelling: w.spelling,
      phonics_pattern: w.phonics_pattern,
    })),
  });
});

// Create a quiz session from an explicit set of word IDs (e.g. random multi-list)
router.post('/quiz-sessions/from-words', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { mode, wordIds } = req.body as {
    mode?: QuizMode;
    wordIds?: string[];
  };

  if (mode !== 'listen_type' && mode !== 'read_say') {
    res.status(400).json({ error: "mode must be 'listen_type' or 'read_say'" });
    return;
  }

  if (!Array.isArray(wordIds) || wordIds.length === 0) {
    res.status(400).json({ error: 'wordIds array is required' });
    return;
  }

  // Get child for current user
  const childResult = await pool.query(
    'SELECT id FROM children WHERE user_id = $1 LIMIT 1',
    [userId],
  );

  if (childResult.rows.length === 0) {
    res.status(404).json({ error: 'Child profile not found' });
    return;
  }

  const childId: string = childResult.rows[0].id;

  // Ensure all words belong to at least one list owned by this child
  const wordsCheck = await pool.query(
    `SELECT DISTINCT w.id, w.spelling, w.phonics_pattern
       FROM words w
       JOIN word_list_items wli ON wli.word_id = w.id
       JOIN word_lists wl ON wli.word_list_id = wl.id
      WHERE w.id = ANY($1)
        AND wl.child_id = $2`,
    [wordIds, childId],
  );

  if (wordsCheck.rows.length === 0) {
    res.status(404).json({ error: 'No valid words found for this user' });
    return;
  }

  const selectedWords = wordsCheck.rows;

  const sessionResult = await pool.query(
    `INSERT INTO quiz_sessions (child_id, mode, word_list_id)
     VALUES ($1, $2, NULL)
     RETURNING id, child_id, mode, word_list_id, started_at, completed_at`,
    [childId, mode],
  );

  const session = sessionResult.rows[0];

  res.status(201).json({
    id: session.id,
    mode: session.mode,
    wordListId: null,
    startedAt: session.started_at,
    completedAt: session.completed_at,
    words: selectedWords.map((w) => ({
      id: w.id,
      spelling: w.spelling,
      phonics_pattern: w.phonics_pattern,
    })),
  });
});

interface RecordAttemptBody {
  wordId: string;
  typedAnswer?: string;
  speechRecognized?: string;
  score?: number; // optional override, mainly for read_say
}

function normalizeForCompare(input: string): string {
  return input
    .trim()
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[^a-z]/g, '');
}

function levenshtein(a: string, b: string): number {
  const m = a.length;
  const n = b.length;
  if (m === 0) return n;
  if (n === 0) return m;

  const dp: number[][] = Array.from({ length: m + 1 }, () => new Array(n + 1).fill(0));

  for (let i = 0; i <= m; i += 1) dp[i][0] = i;
  for (let j = 0; j <= n; j += 1) dp[0][j] = j;

  for (let i = 1; i <= m; i += 1) {
    for (let j = 1; j <= n; j += 1) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost,
      );
    }
  }

  return dp[m][n];
}

function similarityScore(a: string, b: string): number {
  if (!a && !b) return 100;
  const maxLen = Math.max(a.length, b.length);
  if (maxLen === 0) return 0;
  const dist = levenshtein(a, b);
  const score = Math.round(((maxLen - dist) / maxLen) * 100);
  return Math.max(0, Math.min(100, score));
}

// Record a single attempt in an existing session and update spaced repetition stats.
router.post('/quiz-sessions/:id/attempts', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { id: sessionId } = req.params;
  const { wordId, typedAnswer, speechRecognized, score: incomingScore } = req.body as RecordAttemptBody;

  if (!wordId) {
    res.status(400).json({ error: 'wordId is required' });
    return;
  }

  const sessionResult = await pool.query(
    `SELECT qs.id,
            qs.child_id,
            qs.mode,
            qs.word_list_id
       FROM quiz_sessions qs
       JOIN children c ON qs.child_id = c.id
      WHERE qs.id = $1
        AND c.user_id = $2
      LIMIT 1`,
    [sessionId, userId],
  );

  if (sessionResult.rows.length === 0) {
    res.status(404).json({ error: 'Quiz session not found' });
    return;
  }

  const session = sessionResult.rows[0] as {
    id: string;
    child_id: string;
    mode: QuizMode;
    word_list_id: string | null;
  };

  const wordResult = await pool.query(
    'SELECT id, spelling FROM words WHERE id = $1 LIMIT 1',
    [wordId],
  );

  if (wordResult.rows.length === 0) {
    res.status(404).json({ error: 'Word not found' });
    return;
  }

  const word = wordResult.rows[0] as { id: string; spelling: string };

  const normalizedTarget = normalizeForCompare(word.spelling);
  let isCorrect = false;
  let score = 0;

  if (session.mode === 'listen_type') {
    if (!typedAnswer) {
      res.status(400).json({ error: 'typedAnswer is required for listen_type mode' });
      return;
    }
    const normalizedTyped = normalizeForCompare(typedAnswer);
    isCorrect = normalizedTyped === normalizedTarget;
    score = isCorrect ? 100 : 0;
  } else if (session.mode === 'read_say') {
    if (!speechRecognized && incomingScore == null) {
      res.status(400).json({ error: 'speechRecognized or score is required for read_say mode' });
      return;
    }

    if (speechRecognized) {
      const normalizedRecognized = normalizeForCompare(speechRecognized);
      score = similarityScore(normalizedRecognized, normalizedTarget);
    } else if (typeof incomingScore === 'number') {
      score = Math.max(0, Math.min(100, Math.round(incomingScore)));
    }

    isCorrect = score >= 80; // simple threshold for now
  }

  const client = await pool.connect();
  const now = new Date();

  try {
    await client.query('BEGIN');

    await client.query(
      `INSERT INTO quiz_attempts
         (quiz_session_id, word_id, mode, typed_answer, speech_recognized, score, is_correct)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        session.id,
        word.id,
        session.mode,
        typedAnswer ?? null,
        speechRecognized ?? null,
        score,
        isCorrect,
      ],
    );

    const statsResult = await client.query(
      `SELECT difficulty, streak, next_due_at, last_result
         FROM child_word_stats
        WHERE child_id = $1 AND word_id = $2
        LIMIT 1`,
      [session.child_id, word.id],
    );

    const existing = statsResult.rows.length
      ? {
          difficulty: statsResult.rows[0].difficulty as number | null,
          streak: statsResult.rows[0].streak as number | null,
          next_due_at: (statsResult.rows[0].next_due_at ?? null) as Date | null,
          last_result: (statsResult.rows[0].last_result ?? null) as 'correct' | 'incorrect' | null,
        }
      : null;

    const updated = updateAfterAttempt(existing, isCorrect, now);

    await client.query(
      `INSERT INTO child_word_stats
         (child_id, word_id, sound_spelling, difficulty, streak, last_result, last_practiced_at, next_due_at)
       VALUES ($1, $2, NULL, $3, $4, $5, $6, $7)
       ON CONFLICT (child_id, word_id)
       DO UPDATE SET
         difficulty = EXCLUDED.difficulty,
         streak = EXCLUDED.streak,
         last_result = EXCLUDED.last_result,
         last_practiced_at = EXCLUDED.last_practiced_at,
         next_due_at = EXCLUDED.next_due_at`,
      [
        session.child_id,
        word.id,
        updated.difficulty,
        updated.streak,
        updated.last_result,
        now,
        updated.next_due_at,
      ],
    );

    await client.query('COMMIT');

    // --- Adaptive global difficulty bias adjustment ---
    const sessionTotals = await pool.query(
      `SELECT COUNT(*)::int AS total,
              COALESCE(SUM(CASE WHEN is_correct THEN 1 ELSE 0 END),0)::int AS correct
         FROM quiz_attempts
        WHERE quiz_session_id = $1`,
      [session.id],
    );

    const total = sessionTotals.rows[0].total as number;
    const correct = sessionTotals.rows[0].correct as number;

    if (total >= 5) {
      const accuracy = total > 0 ? correct / total : 0;

      const biasRes = await pool.query(
        'SELECT global_difficulty_bias FROM children WHERE id = $1 LIMIT 1',
        [session.child_id],
      );

      let bias: number = biasRes.rows[0]?.global_difficulty_bias ?? 0;

      if (accuracy >= 0.85) bias += 1;
      else if (accuracy <= 0.3) bias -= 1;

      bias = Math.max(-3, Math.min(3, bias));

      await pool.query(
        'UPDATE children SET global_difficulty_bias = $1 WHERE id = $2',
        [bias, session.child_id],
      );
    }

    res.status(201).json({
      wordId: word.id,
      score,
      isCorrect,
      stats: updated,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Failed to record quiz attempt', err);
    res.status(500).json({ error: 'Failed to record quiz attempt' });
  } finally {
    client.release();
  }
});

// Progressive hints using stored pre-generated hints
router.post('/quiz-sessions/:id/hint', async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { id: sessionId } = req.params;
  const { wordId, level } = req.body as { wordId?: string; level?: number };

  if (!wordId || typeof level !== 'number') {
    res.status(400).json({ error: 'wordId and level required' });
    return;
  }

  const safeLevel = Math.min(5, Math.max(1, Math.floor(level)));

  const sessionResult = await pool.query(
    `SELECT qs.id
       FROM quiz_sessions qs
       JOIN children c ON qs.child_id = c.id
      WHERE qs.id = $1 AND c.user_id = $2
      LIMIT 1`,
    [sessionId, userId],
  );

  if (sessionResult.rows.length === 0) {
    res.status(404).json({ error: 'Quiz session not found' });
    return;
  }

  const wordResult = await pool.query(
    `SELECT hint_letter_count,
            hint_first_last,
            hint_consonants,
            hint_sentence,
            hint_similar,
            spelling
       FROM words
      WHERE id = $1
      LIMIT 1`,
    [wordId],
  );

  if (wordResult.rows.length === 0) {
    res.status(404).json({ error: 'Word not found' });
    return;
  }

  const w = wordResult.rows[0];

  const spelling: string = w.spelling;

  // Level 4: mask the word inside the sentence
  let maskedSentence: string | null = w.hint_sentence;
  if (typeof maskedSentence === 'string' && maskedSentence.length > 0) {
    const blank = '_'.repeat(spelling.length);
    const escaped = spelling.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp(`\\b${escaped}\\b`, 'gi');
    maskedSentence = maskedSentence.replace(regex, blank);
  }

  // Level 5: use stored similar/root-form hint only
  let similarWord: string | null = null;

  if (typeof w.hint_similar === 'string' && w.hint_similar.length > 0) {
    similarWord = w.hint_similar;
  }

  const allHints = [
    w.hint_letter_count,
    similarWord,
    maskedSentence,
    w.hint_first_last,
    w.hint_consonants,
  ].filter((h) => typeof h === 'string' && h.length > 0);

  const visibleHints = allHints.slice(0, safeLevel);

  res.json({ hints: visibleHints });
});

// Aggregate quiz statistics for current user's child
router.get('/stats', async (req: AuthRequest, res) => {
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

  // Scoring rules:
  // - Correct on first try (no incorrect attempts for that word in session) = 1 point
  // - Incorrect first, eventually correct (same word in same session) = 0.5 point
  // - Never correct = 0 points
  const totalsResult = await pool.query(
    `WITH per_word AS (
         SELECT
           qa.quiz_session_id,
           qa.word_id,
           BOOL_OR(qa.is_correct) AS ever_correct,
           BOOL_OR(NOT qa.is_correct) AS ever_incorrect
         FROM quiz_attempts qa
         JOIN quiz_sessions qs ON qa.quiz_session_id = qs.id
         WHERE qs.child_id = $1
         GROUP BY qa.quiz_session_id, qa.word_id
       )
       SELECT
         COUNT(*)::int AS total_words,
         COALESCE(SUM(
           CASE
             WHEN ever_correct AND NOT ever_incorrect THEN 1.0
             WHEN ever_correct AND ever_incorrect THEN 0.5
             ELSE 0.0
           END
         ), 0)::float AS score
       FROM per_word`,
    [childId],
  );

  const total = totalsResult.rows[0].total_words as number;
  const correct = totalsResult.rows[0].score as number;
  const accuracyPercent = total > 0 ? Math.round((correct / total) * 100) : 0;

  const last7DaysResult = await pool.query(
    `SELECT COUNT(*)::int AS total
       FROM quiz_attempts qa
       JOIN quiz_sessions qs ON qa.quiz_session_id = qs.id
      WHERE qs.child_id = $1
        AND qa.created_at >= NOW() - INTERVAL '7 days'`,
    [childId],
  );

  const last7DaysAttempts = last7DaysResult.rows[0].total as number;

  res.json({
    correctCount: correct,
    totalWords: total,
    accuracyPercent,
    last7DaysAttempts,
  });
});

export default router;
