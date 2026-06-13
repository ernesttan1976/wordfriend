CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Users table: parent accounts authenticated via social login (e.g. Google)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_provider TEXT NOT NULL,
  auth_provider_id TEXT NOT NULL UNIQUE,
  email TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Children table: one child per parent for MVP
CREATE TABLE IF NOT EXISTS children (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  age INT NOT NULL,
  theme TEXT NOT NULL CHECK (theme IN ('pony', 'lego')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure at most one child per user (MVP constraint)
CREATE UNIQUE INDEX IF NOT EXISTS idx_children_user
  ON children (user_id);

-- Word lists created per child
CREATE TABLE IF NOT EXISTS word_lists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id UUID NOT NULL REFERENCES children(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('ai', 'manual')),
  prompt TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Words; shared across lists
CREATE TABLE IF NOT EXISTS words (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  spelling TEXT NOT NULL,
  phonics_pattern TEXT
);

-- Link table: which words belong to which lists
CREATE TABLE IF NOT EXISTS word_list_items (
  word_list_id UUID NOT NULL REFERENCES word_lists(id) ON DELETE CASCADE,
  word_id UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  position INT,
  PRIMARY KEY (word_list_id, word_id)
);

-- Per-child spaced repetition stats for each word
CREATE TABLE IF NOT EXISTS child_word_stats (
  child_id UUID NOT NULL REFERENCES children(id) ON DELETE CASCADE,
  word_id UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  sound_spelling TEXT,
  difficulty REAL NOT NULL DEFAULT 0,
  streak INT NOT NULL DEFAULT 0,
  last_result TEXT CHECK (last_result IN ('correct', 'incorrect')),
  last_practiced_at TIMESTAMPTZ,
  next_due_at TIMESTAMPTZ,
  PRIMARY KEY (child_id, word_id)
);

-- Quiz sessions
CREATE TABLE IF NOT EXISTS quiz_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id UUID NOT NULL REFERENCES children(id) ON DELETE CASCADE,
  mode TEXT NOT NULL CHECK (mode IN ('listen_type', 'read_say')),
  word_list_id UUID REFERENCES word_lists(id) ON DELETE SET NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);

-- Individual attempts inside a quiz session
CREATE TABLE IF NOT EXISTS quiz_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_session_id UUID NOT NULL REFERENCES quiz_sessions(id) ON DELETE CASCADE,
  word_id UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  mode TEXT NOT NULL CHECK (mode IN ('listen_type', 'read_say')),
  typed_answer TEXT,
  speech_recognized TEXT,
  score INT,
  is_correct BOOLEAN,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_child_word_stats_next_due
  ON child_word_stats (child_id, next_due_at);

CREATE INDEX IF NOT EXISTS idx_quiz_sessions_child
  ON quiz_sessions (child_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_quiz_attempts_session
  ON quiz_attempts (quiz_session_id, created_at);
