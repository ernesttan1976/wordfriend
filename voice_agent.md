# Voice Agent Plan (LiveKit + Flutter + Node Agent)

## Product Shape
Add a realtime voice “tutor friend” to the existing spelling app.

Two user modes:
1. Free mode (primary): open conversation with the agent friend (general questions allowed), with optional “let’s practice a word” transitions.
2. Quiz mode: voice overlays the deterministic quiz UI and helps the child through the current word.

Constraints / decisions:
- Agent: Node only
- LiveKit: self-host
- Providers: OpenAI only (STT + LLM + TTS)
- Session model: single session at a time (one child/device active)
- Retention: store transcripts + parsed letters; do not store audio
- Failure policy: when uncertain, ask the child to repeat (don’t guess)
- Turn-taking: open-mic, long pauses allowed, auto-timeout after a max window, “smart choices” about whether the child is still spelling

Product stance (Free mode):
- Default to “teach how to construct the spelling”, not “spell it for them”.
- Non-linear is OK: exploratory learning is a feature, not a bug.
- Entertainment is allowed, but keep it learning-flavored (word families, patterns, mini-challenges) rather than pure small-talk.

## Existing Repo Hooks (Current Reality)
- Backend already stores `quiz_attempts.speech_recognized` and `typed_answer`.
- Backend grading for `listen_type` is deterministic (`normalizeForCompare` + exact match).
- Backend supports progressive hints: `POST /quiz/quiz-sessions/:id/hint`.
- Flutter currently starts quizzes only in `listen_type` from the UI.

Implication (MVP-friendly):
- Voice spelling attempts can be submitted as `typedAnswer` (parsed letters/spelling) plus `speechRecognized` (raw transcript), without schema changes.
- We can treat “voice spelling” as `listen_type` for scoring/persistence initially, and add a dedicated mode later if we want cleaner analytics.

## Architecture
Components:
- Flutter app: structured UI + local deterministic “teaching engine” behaviors (instant feedback, letter highlighting, client-side parsing helpers).
- Backend: canonical deterministic grading + spaced repetition + persistence; mints LiveKit tokens.
- LiveKit room: realtime transport (mic audio, agent audio, data/RPC).
- Node tutor agent: LiveKit Agents participant that runs STT -> LLM -> TTS; calls tools (RPC to Flutter, REST to backend).

### “Two brains” (and where truth lives)
- Canonical truth (persistence + progression): backend.
- Local brain (UX + immediate feedback + offline-ish behavior): Flutter.
- Consistency strategy:
  - Implement the same normalization + scoring logic in both Dart and TS.
  - Maintain a shared golden test vector file (JSON) consumed by both test suites to prevent drift.

## LiveKit: Rooms, Identity, Tokens
Single-session simplifies things:
- Room name: `wordfriend_main` (or `quiz_{quizSessionId}` if you want per-quiz isolation later).
- Identity:
  - Flutter: `child_client`
  - Agent: `tutor_agent`

Backend must mint tokens (never embed API secret in Flutter):
- `POST /livekit/token`
  - Auth: existing app JWT
  - Body: `{ identity: "child_client" }` (backend selects room + grants)
  - Returns: `{ token, wsUrl, room }`

(Optional) separate endpoint or config path for agent token minting used by the agent runtime:
- `POST /livekit/agent-token` protected by an env secret (not the user JWT), or just mint offline in the agent using server API key/secret.

Grants:
- Flutter: join room, publish mic, subscribe to audio, send/receive data, receive RPC, invoke RPC.
- Agent: join room, publish TTS audio, subscribe to mic, send/receive data, invoke RPC.

## Data Model / Retention
Store:
- Raw transcript: `quiz_attempts.speech_recognized`
- Parsed letters/spelling: `quiz_attempts.typed_answer` (initially)

Do not store:
- audio

Retention policy (recommended):
- Keep transcripts for N days (configurable), then purge.
- Always keep correctness/score stats.

## Flutter: Voice Overlay (Quiz Mode)
UI additions to `QuizScreen`:
- “Tutor” overlay panel:
  - Connect/disconnect
  - Mic indicator (open-mic on/off toggle)
  - Live transcript view (what the agent heard)
  - Agent status: listening / thinking / speaking
  - “Repeat last” button (forces agent to repeat the prompt / word)

Runtime behavior:
- On entering quiz: user can connect tutor.
- Open-mic: publish mic track while tutor is connected and mic is enabled.
- Long pauses: handled primarily by agent turn detection; Flutter only shows state.

Flutter-local deterministic engine responsibilities (quiz UX):
- Mirror backend’s `normalizeForCompare` in Dart.
- Provide immediate feedback while waiting for backend response (optimistic UI), but backend remains authoritative for persistence.
- Letter highlighting + hint display remain in Flutter (agent requests via RPC).

## Flutter: Free Mode Screen
Add a “Free chat with friend” screen (default entry point):
- Connect/disconnect tutor
- Open-mic toggle
- Transcript + text bubbles (agent + child)
- Conversation starters (4 large choices, rotated based on recent history):
  - Examples: “Help me spell a word”, “Word family game”, “Why is this spelled like that?”, “Teach me a pattern”
- Chat-first UI with an on-demand spelling helper drawer (hybrid, but not split view):
  - Helper stays hidden during normal chat.
  - Helper opens when the child asks about spelling or the agent proposes a micro-challenge.
  - Helper content: (1) attempt box (letters heard / typed), (2) root/suffix/prefix chips, (3) related words cards, (4) optional hints.
- “Start practice” button:
  - transitions into a quiz session (or a lightweight “practice one word” flow) and begins sending `lesson_context` messages

### App Restructure (Free Mode First)
Current app landing after auth + child selection goes to word lists. With Free mode primary, restructure the top-level IA:
- Auth -> Child selection -> Free mode home
- Word lists becomes a secondary destination (library), not the home screen
- Quiz becomes an explicit activity launched from Free mode (CTA) or from a list

Navigation (MVP):
- Free mode home AppBar actions to reach: Word Lists, Stats, Child Profile
- Later: bottom nav or a dedicated “Home / Library / Stats” structure if needed

### Animated Avatar ("Face that talks")
Free mode centers an always-visible avatar so the experience reads as a conversation:
- Show the mascot above the chat transcript.
- Animate during agent speech and optionally while listening.
- MVP implementation (Flutter): mouth-flap driven by an audio level signal (0..1). Source options:
  - LiveKit: subscribe to remote audio track levels (RMS/energy) if exposed by the SDK
  - Fallback: infer speaking state from agent events ("speaking" / "listening") and do a subtle loop
- The avatar animation should be local-only (no network dependency) so it remains responsive.

Persistence:
- Default: do not write free-mode transcripts into `quiz_attempts` (since they’re not attempts).
- If you want logs, create a separate lightweight table later; not required initially.

## Agent: Node Tutor (Quiz + Free)
Project structure (suggested):
- `voice-agent/`
  - `package.json`
  - `src/index.ts`
  - `src/prompts.ts`
  - `src/spelling/parse.ts`
  - `src/spelling/scoring.ts` (mirrors backend logic)
  - `src/tools/flutterRpc.ts`
  - `src/tools/backendApi.ts`

### Agent State Machine
States:
- `FREE`: general conversation; can answer general questions; can suggest practice.
- `QUIZ`: guided spelling tutor; uses lesson context; strongly prefers structured teaching patterns.

Transitions:
- Flutter sends `mode = "quiz"` context -> agent enters QUIZ.
- Flutter sends `mode = "free"` -> agent enters FREE.
- Agent can request transition (“Want to practice a word?”), but Flutter decides.

### FREE mode teaching policy (when child asks “How do you spell X?”)
Default behavior is “teach-first”:
1. Ask for at least one attempt (spoken letters or typed) before revealing the full spelling.
2. Teach construction tools:
   - break into parts (prefix/root/suffix) when applicable
   - compare to similar spelled words / patterns
   - expose a small word family (2–4 related words) to strengthen memory
3. Confirm via active recall:
   - ask the child to spell it again (letter-by-letter) or fill missing letters
4. Only then, if the child is stuck, reveal (and immediately re-test once).

If the child explicitly says “just tell me”, comply only after at least one attempt.

### Agent Inputs (from Flutter over data channel)
Message schema (JSON):
- `lesson_context`:
  - `{ type, mode: "quiz", quizSessionId, wordId, word, attempts: string[], hintLevel: number, visibleHints: string[] }`
- `free_context`:
  - `{ type, mode: "free", childName?: string, preferences?: {...} }`
- `ui_event`:
  - `{ type, event: "next_word" | "hint_pressed" | "replay_pressed" | ... }`

### Agent Outputs
- `transcript_partial` / `transcript_final`:
  - `{ type, text, isFinal, confidence?: number }`
- `ui_command` via RPC:
  - highlight, reveal, hint, next word, celebrate, etc.
- Spoken audio (TTS) published as agent audio track.

## Open-Mic Turn Handling (Long Pauses + Smart Timeout)
Goal: tolerate “E… (pause) … Q … (pause) … U …” without cutting off too early, but still progress.

Approach:
- Use LiveKit turn detection tuned for spelling mode:
  - Longer endpointing windows than normal conversation.
  - Treat single-letter utterances as “likely continuing”.
- Add an agent-side “spelling capture window”:
  - When agent prompts “Spell it”, start a timer `maxSpellWindow` (ex: 25–40s).
  - If the child is silent for `softSilence` (ex: 4–7s) and we have partial letters, ask: “Keep going, what’s the next letter?” (don’t submit yet).
  - If silent for `hardSilence` (ex: 10–14s), ask to repeat the last chunk or offer a hint tool.
  - If `maxSpellWindow` hits, summarize what was heard and ask to restart the spelling attempt.

The “smart choices” rule:
- If transcript looks like letter-names / spelled letters: stay in spelling capture.
- If transcript looks like the child said the whole word: confirm: “Did you mean to spell it letter by letter or say the word?”
- If transcript is ambiguous: ask to repeat, narrower scope (“Say just the last 3 letters”).

## Parsing Spoken Spelling (Store Both Raw + Parsed)
We store:
- raw transcript (verbatim)
- parsed result (letters/spelling string) + parse confidence (agent-side, sent to Flutter and used to decide “ask repeat”)

Parsing pipeline:
1. Deterministic parser first (fast, consistent):
   - tokenize transcript
   - map common homophones (“bee”->b, “sea”->c, “are”->r, “you”->u, etc.)
   - accept separators (“comma”, “dash”, pauses)
   - handle “double L”, “two Ls” patterns
2. If deterministic parse confidence < threshold:
   - ask the LLM to produce a structured parse:
     - `{ letters: ["e","q","u",...], confidence: 0..1, uncertainties: [...] }`
3. If still < threshold:
   - ask the child to repeat (required behavior)

Never “grade” off a low-confidence parse.

## Deterministic Scoring (Backend + Flutter)
Canonical scoring:
- normalize: lowercase, strip non-letters, NFKD
- compare equality (quiz spelling)
- keep similarity scoring (Levenshtein) as a secondary metric for encouragement, not correctness (optional)

Implementation plan:
- Backend: already has normalize + compare.
- Flutter: implement the same normalize + compare.
- Shared golden tests:
  - `tests/spelling_golden.json` (examples: punctuation, accents, spaces, common misreads)
  - Node + Flutter tests both load and assert identical output.

## Agent Tooling
### Backend REST tool
Agent calls backend to submit attempts:
- `POST /quiz/quiz-sessions/:id/attempts`
  - `{ wordId, typedAnswer: parsedSpelling, speechRecognized: rawTranscript }`

Agent may call hint endpoint:
- `POST /quiz/quiz-sessions/:id/hint` with `{ wordId, level }`

Auth:
- Use a dedicated “agent token” for backend calls (not the child JWT), or reuse child JWT only if you’re comfortable with the agent acting on behalf of the child. Recommended: agent token.

### Flutter RPC surface (minimal)
RPC methods Flutter exposes:
- `highlightRange(start:int, end:int)`
- `setHintLevel(level:int)` (Flutter then calls backend hint endpoint)
- `showHints(hints:string[])`
- `celebrate(type:string)`
- `requestRepeatWord(slow:bool)`
- `nextWord()`

Rule:
- Flutter remains authoritative; RPC is “request”, not “force”.

## Free Mode Policy (General Questions Allowed)
Agent can answer general questions, but keep it kid-safe:
- No personal data requests.
- No unsafe instructions.
- If sensitive topic: encourage asking parent/guardian.
- Steer toward learning-friendly explanations.

Free mode still benefits from “tutor friend” personality:
- can suggest spelling games
- can offer to practice patterns (-tion, -ment, double consonants)
- can transition into quiz with explicit user action

Free mode should feel “endlessly fun” without becoming empty:
- Prefer playful learning loops: quick word-quests, word-family tangents, pattern spotting, mini recall challenges.
- Avoid long monologues; keep turns short and interactive.

## Rollout Plan (Phases)
Phase 1: LiveKit connectivity + audio loop
- Backend token minting
- Flutter connects + open-mic publish
- Agent joins + TTS speaks back
- Transcript displayed in Flutter

Phase 2: Quiz mode voice attempts end-to-end
- Flutter sends `lesson_context`
- Agent prompts spelling
- Agent parses transcript -> submits attempt -> receives correctness
- Flutter UI updates based on backend response

Phase 3: Turn-taking tuning for spelling mode
- long pauses
- smart timeout window
- repeat-on-uncertainty paths

Phase 4: RPC-driven UI assistance
- highlight suffixes
- request hints
- celebration / pacing

Phase 5: Free mode polish (now primary)
- conversation starters rotation
- spelling helper drawer behaviors
- safe general Q&A + learning loops
- “start practice” transitions

## Acceptance Criteria
- Child can spell a quiz word by speaking letters with long pauses; agent does not interrupt prematurely.
- If agent is unsure, it asks to repeat rather than guessing.
- Raw transcript and parsed spelling are both persisted (transcript only; no audio).
- Backend and Flutter scoring match on golden test vectors.
- Free mode works without corrupting quiz progression.
- In Free mode, when the child asks how to spell a word, the agent asks for at least one attempt before revealing the full spelling.
- In Free mode, the spelling helper UI appears only when relevant (asked for spelling / micro-challenge) and otherwise stays out of the way.

## Open Questions (Need One-Time Decisions)
- Timeouts: pick initial values for `softSilence`, `hardSilence`, `maxSpellWindow`.
- Room naming: single fixed room vs per-quiz room.
- Backend auth for agent: dedicated agent secret/token vs acting as child.
