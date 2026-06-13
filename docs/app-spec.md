
Normal people
Pronunciation -> Correct Spelling

Dyslexic people
LISTEN & WRITE: Pronunciation -> Sound Spelling "said" -> sayd
READ ALOUD: Correct Spelling -> Say as it is Spelled said -> "sayd"

Method
Learn to map the sound spelling to say as it is spelled
"said" -> "sayd"
said -> "sayd"

Construct the word from root word
say -> says, said, saying
should be sayed, but looks weird, so the y becomes i and the ed becomes d
Design a Flutter app that deploys to the web + Android. Must have a Dockerized express backend + Postgres db. It maintains a user curated list of spelling words. The app calls OpenRouter API AI for chat completions. Unique user profile, user prompts, spelling list, quiz data per person. Allow to choose boy or girl and age.

1. User can self-generate spelling word lists according to user prompts. This can spark kid's interest.
2. App will load 10 spelling words into the current quiz.
3. Quiz shall be either of these modes: "1. user listen and type" OR "2. user read and say aloud".
4. User listen and type: Use TTS to say the word in British English accent -> Let user type out the word -> app evaluates accuracy.
5. User read and say aloud: Show the word on the page -> user says the word -> app evaluates accuracy.
6. Keep record of frequency of right and wrong answers -> repeat more often for wrong answers.
7. Quiz shall be the basic version of this app. Next features shall be more fun kinds of games or interactions.
8. Fun and cute "My Little Pony" style theme for girls OR "Lego" style theme for boys.

---

## Detailed App Spec (MVP)

### 1. Product Goals

- Help 9–12 year olds (with and without dyslexia) map pronunciation, correct spelling, and "sound spelling" using structured practice.
- Support parents working with one child at home on a shared device.
- Deliver a solid MVP that covers AI word-list generation, both quiz modes, spaced repetition, and basic analytics.

### 2. Core User Flows

1. Onboarding
   - Parent signs in via social login (e.g. Google OAuth).
   - Parent sets up a single child profile: age, theme preference ("pony" or "lego").
   - App picks default difficulty based on age (9–12) and British English.

2. Word List Creation
   - Parent enters a free-form prompt like "words about volcanoes" or "practice -tion words for 10-year-old".
   - App sends prompt, age, and previous performance hints to OpenRouter.
   - AI returns a list (e.g. 10–25 words) with correct spelling and optional pattern labels.
   - Parent can:
     - Review and deselect words.
     - Save as a named list (e.g. "Week 3: volcanoes").

3. Quiz Setup
   - Parent or child picks a list to practice.
   - App composes a 10-word quiz by:
     - Pulling from the chosen list.
     - Biasing towards words with weaker past performance (spaced repetition).
   - User chooses mode:
     - Listen & Type.
     - Read & Say Aloud.

4. Listen & Type Quiz
   - For each word:
     - App plays TTS in British accent.
     - Child types spelling.
     - App compares to correct spelling (case-insensitive, optional small-tolerance for accents/whitespace).
     - Feedback UI:
       - Correct: confirm and show word.
       - Incorrect: show correct spelling and optional "sound spelling" cue.
     - Store attempt result for spaced repetition.

5. Read & Say Aloud Quiz
   - For each word:
     - Word is shown as text.
     - Child taps a button to start recording.
     - Audio sent to cloud speech recognition (e.g. Whisper API, or another free/cheap provider when available).
     - System computes a similarity score between recognized text and target word.
     - Feedback UI: show score and simple indicator (e.g. 1–5 stars), plus option to retry once.
     - Store score and result in history.

6. Progress & Review
   - Per-list view: show each word with stats:
     - Attempts, correct %, last practiced date.
   - Simple spaced-repetition stats: highlight "tricky words" that the child often gets wrong.

### 3. Learning Model & Repetition

- Each word has spaced repetition metadata per child:
  - Stability / difficulty score.
  - Next due date.
  - History of attempts (mode, correct, score).
- Algorithm (MVP):
  - Start each new word with a neutral difficulty.
  - On correct attempts (high score for speaking): decrease difficulty, push next due date further.
  - On incorrect attempts: increase difficulty, bring next due date closer.
  - Use a simplified SM-2 style model (lightweight Anki-like) tuned for 9–12.
- Quiz selection:
  - Primary source: words due today from the selected list.
  - If fewer than 10 due, top up with:
    - Recently added words not yet learned.
    - Tricky words with high difficulty.

### 4. Data Model (Postgres)

Tables (simplified):

- `users`
  - `id` (UUID, pk)
  - `auth_provider` (text, e.g. "google")
  - `auth_provider_id` (text, unique)  // provider-subject identifier
  - `created_at`, `updated_at`

- `children`
  - `id` (UUID, pk)
  - `user_id` (fk -> users.id)
  - `age` (int)
  - `theme` (enum: `pony`, `lego`, maybe `neutral` later)
  - `created_at`, `updated_at`

- `word_lists`
  - `id` (UUID, pk)
  - `child_id` (fk -> children.id)
  - `name` (text)
  - `source` (enum: `ai`, `manual`)
  - `prompt` (text, nullable)
  - `created_at`, `updated_at`

- `words`
  - `id` (UUID, pk)
  - `spelling` (text, unique per list scope)
  - `phonics_pattern` (text, nullable, e.g. "ai/ay", "-tion")

- `word_list_items`
  - `word_list_id` (fk -> word_lists.id)
  - `word_id` (fk -> words.id)
  - `position` (int)
  - pk: (`word_list_id`, `word_id`)

- `child_word_stats`
  - `child_id` (fk -> children.id)
  - `word_id` (fk -> words.id)
  - `sound_spelling` (text, nullable)
  - `difficulty` (float)
  - `streak` (int)
  - `last_result` (enum: `correct`, `incorrect`)
  - `last_practiced_at` (timestamp)
  - `next_due_at` (timestamp)
  - pk: (`child_id`, `word_id`)

- `quiz_sessions`
  - `id` (UUID, pk)
  - `child_id` (fk -> children.id)
  - `mode` (enum: `listen_type`, `read_say`)
  - `word_list_id` (fk -> word_lists.id, nullable for mixed sessions)
  - `started_at`, `completed_at`

- `quiz_attempts`
  - `id` (UUID, pk)
  - `quiz_session_id` (fk -> quiz_sessions.id)
  - `word_id` (fk -> words.id)
  - `mode` (enum: `listen_type`, `read_say`)
  - `typed_answer` (text, nullable)
  - `speech_recognized` (text, nullable)
  - `score` (int, 0–100)
  - `is_correct` (bool)
  - `created_at`

### 5. Backend Architecture (Express + TypeScript)

- Tech stack
  - Node.js + Express + TypeScript.
  - Postgres via an ORM (e.g. Prisma or Knex). Keep it simple and strongly typed.
  - Docker Compose: separate containers for API and Postgres.

- High-level modules
  - `auth` (social login, JWT issuance).
  - `children` (profile & settings for the single child).
  - `lists` (word lists CRUD, AI generation integration).
  - `quiz` (session creation, question selection, evaluation, stats update).
  - `tts` and `speech` integration helpers.

- Key API endpoints (sketch)
  - `POST /auth/social/google` – exchange Google token for app JWT.
  - `GET /me` – current user info + child profile.
  - `POST /children` / `PATCH /children/:id` – configure age, theme.
  - `POST /word-lists/generate` – body: `{ prompt, targetAge, size }` → uses OpenRouter.
  - `GET /word-lists` / `GET /word-lists/:id`.
  - `POST /word-lists/:id/words` – manual adds.
  - `POST /quiz-sessions` – body: `{ wordListId, mode }` → returns ordered words and IDs.
  - `POST /quiz-sessions/:id/attempts` – record each attempt.
  - `GET /children/:id/stats` – summary per list and per word.

### 6. AI Integration (OpenRouter)

- Use OpenRouter for list generation only in MVP.
- Prompt template (conceptual):

  - System: "You are helping a 9–12 year old learn English spelling with a focus on British English. Generate spelling words that are age-appropriate, family-friendly, and focused on the requested theme or pattern. Output JSON only."
  - User: includes `prompt`, `age`, optional hints about tricky words or targeted patterns.

- Response format example:

```json
{
  "words": [
    { "spelling": "volcano", "phonics_pattern": "long a" },
    { "spelling": "eruption", "phonics_pattern": "-tion" }
  ]
}
```

- Backend validates and sanitizes AI output (no profanity, reasonable length, alphabetic only).

### 7. TTS & Speech Recognition

- TTS (Listen & Type mode)
  - Use a free or free-tier-friendly cloud TTS with British English (e.g. Google Cloud TTS free tier if acceptable, or another similar service).
  - Fallback: for web, browser `speechSynthesis` if needed; for Android, platform TTS APIs.
  - API returns either URLs for pre-generated audio files or text for the client to synthesize.

- Speech Recognition (Read & Say Aloud)
  - Use a low-cost or free cloud STT (e.g. Whisper API or comparable) for accuracy.
  - Client records short clips, uploads to backend, backend calls STT.
  - Backend compares recognized text to target word using fuzzy match (e.g. Levenshtein distance) to produce a 0–100 score, mapped to 1–5 stars.

### 8. Flutter App Architecture

- Flutter web + Android using latest stable, null-safety.
- Suggested packages:
  - State management: Riverpod or Provider (keep it simple at first).
  - HTTP client: `dio` or `http`.
  - Auth (Google sign-in): `google_sign_in` + backend exchange.
  - Audio playback and recording: `just_audio`, `record` (or equivalents that work on web + Android).

- Main screens
  - Auth / Welcome.
  - Child Setup (age, theme).
  - Home / Dashboard (lists, quick start quiz).
  - Word List Management.
  - Quiz Screen (Listen & Type).
  - Quiz Screen (Read & Say Aloud).
  - Progress Screen.

- Theming
  - Two high-level themes: Pony (pastel, rounded, softer typography) and Lego (primary colors, blocky shapes).
  - Theme chosen per child and applied app-wide.

### 9. Privacy, Safety, Compliance

- Store minimal data:
  - Parent account uses social login; store provider ID and email.
  - No extra PII for the child beyond age and theme preference.
- Child-safe guarantees:
  - Filter AI-generated words for profanity and inappropriate topics on backend.
  - Avoid storing or transmitting unnecessary voice data; keep only transient audio for scoring.
  - Consider opt-in consent info for parents about voice processing.

### 10. Testing Strategy

- Backend
  - Unit tests for spaced repetition logic and scoring (typed vs recognized vs target).
  - Integration tests for key APIs: auth flow, list generation (with mocked OpenRouter), quiz lifecycle.

- Flutter
  - Widget tests for quiz flows.
  - A few golden tests for main screens to keep theme changes safe.

### 11. Phased Implementation Plan

1. Backend Foundations
   - Set up Express TS, Postgres schema, Docker Compose, basic migrations.
   - Implement auth and child profile endpoints.

2. Word Lists & AI
   - CRUD for word lists and words.
   - Integrate OpenRouter for list generation with validation.

3. Quiz Engine & Spaced Repetition
   - Implement spaced repetition model and word selection.
   - Implement quiz session and attempts APIs.

4. Flutter MVP UI
   - Auth + onboarding.
   - List screens + basic quiz UIs (no audio yet).

5. Audio & Speech
   - Integrate TTS for Listen & Type.
   - Integrate STT + scoring for Read & Say Aloud.

6. Polish & QA
   - Apply pony/lego themes.
   - Add progress screen and simple analytics.
   - Tighten error handling, loading states, and tests.
