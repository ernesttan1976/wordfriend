export type LastResult = 'correct' | 'incorrect' | null;

export interface ExistingStats {
  difficulty: number | null;
  streak: number | null;
  next_due_at: Date | null;
  last_result: LastResult;
}

export interface UpdatedStats {
  difficulty: number;
  streak: number;
  next_due_at: Date;
  last_result: Exclude<LastResult, null>;
}

// Basic spaced repetition update logic.
// Higher difficulty = word is harder and should be shown more often.
// next_due_at is scheduled closer for higher difficulty and farther out for easy words.
export function updateAfterAttempt(existing: ExistingStats | null, isCorrect: boolean, now: Date): UpdatedStats {
  const prevDifficulty = existing?.difficulty ?? 3; // 0 (easy) .. 5 (hard)
  const prevStreak = existing?.streak ?? 0;

  let difficulty = prevDifficulty;
  let streak = prevStreak;

  if (isCorrect) {
    difficulty = Math.max(0, prevDifficulty - 1);
    streak = prevStreak + 1;
  } else {
    difficulty = Math.min(5, prevDifficulty + 1);
    streak = 0;
  }

  // Base interval: easy words further away, hard words sooner.
  let intervalDays = 1 + (5 - difficulty); // difficulty 5 -> 1 day, 0 -> 6 days

  // Reward streaks by pushing next due further out a bit.
  intervalDays += Math.floor(streak / 2);

  // Clamp to sensible bounds for kids' practice.
  if (intervalDays < 1) intervalDays = 1;
  if (intervalDays > 21) intervalDays = 21;

  const intervalMs = intervalDays * 24 * 60 * 60 * 1000;
  const next_due_at = new Date(now.getTime() + intervalMs);

  return {
    difficulty,
    streak,
    next_due_at,
    last_result: isCorrect ? 'correct' : 'incorrect',
  };
}
