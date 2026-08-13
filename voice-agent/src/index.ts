import 'dotenv/config';

import { Room, TrackKind, AudioStream, type RemoteAudioTrack } from '@livekit/rtc-node';
import OpenAI, { toFile } from 'openai';
import { z } from 'zod';

import { systemPrompt } from './prompts';
import { parseSpelledLetters } from './spelling/parse';

const env = z
  .object({
    OPENAI_API_KEY: z.string().min(1),
    BACKEND_BASE_URL: z.string().url().default('http://localhost:4000'),
    LIVEKIT_AGENT_SECRET: z.string().min(1),
    OPENAI_MODEL: z.string().optional(),
  })
  .parse(process.env);

const openai = new OpenAI({ apiKey: env.OPENAI_API_KEY });

type Mode = 'free' | 'quiz';

type LessonContext = {
  quizSessionId: string;
  wordId: string;
  word: string;
  attempts: string[];
  hintLevel: number;
  visibleHints: string[];
};

async function mintAgentToken(): Promise<{ token: string; wsUrl: string; room: string }> {
  const url = new URL('/livekit/agent-token', env.BACKEND_BASE_URL);
  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-agent-secret': env.LIVEKIT_AGENT_SECRET,
    },
    body: JSON.stringify({ identity: 'tutor_agent' }),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`agent-token failed: ${resp.status} ${text}`);
  }

  const json = (await resp.json()) as { token: string; wsUrl: string; room: string };
  return json;
}

function rms(pcm16: Int16Array): number {
  if (pcm16.length === 0) return 0;
  let sum = 0;
  for (let i = 0; i < pcm16.length; i += 1) {
    const v = pcm16[i] / 32768;
    sum += v * v;
  }
  return Math.sqrt(sum / pcm16.length);
}

function wavFromPcm16(pcm: Buffer, sampleRate: number): Buffer {
  // 16-bit PCM, mono
  const numChannels = 1;
  const bitsPerSample = 16;
  const byteRate = sampleRate * numChannels * (bitsPerSample / 8);
  const blockAlign = numChannels * (bitsPerSample / 8);
  const dataSize = pcm.length;
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + dataSize, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(numChannels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write('data', 36);
  header.writeUInt32LE(dataSize, 40);
  return Buffer.concat([header, pcm]);
}

class AgentState {
  mode: Mode = 'free';
  lesson: LessonContext | null = null;
  history: Array<{ role: 'user' | 'assistant'; content: string }> = [];
}

async function main(): Promise<void> {
  const { token, wsUrl, room } = await mintAgentToken();

  const state = new AgentState();
  const lkRoom = new Room();

  await lkRoom.connect(wsUrl, token);
  console.log(`[agent] connected room=${room}`);

  function sendJson(obj: unknown): void {
    const data = Buffer.from(JSON.stringify(obj), 'utf8');
    lkRoom.localParticipant?.publishData(data, { reliable: true });
  }

  function setStatus(status: 'listening' | 'thinking' | 'speaking' | 'connecting'): void {
    sendJson({ type: 'agent_status', status });
  }

  setStatus('listening');

  lkRoom.on('dataReceived', (payload: Uint8Array) => {
    try {
      const raw = Buffer.from(payload).toString('utf8');
      const decoded = JSON.parse(raw) as any;
      if (!decoded || typeof decoded !== 'object') return;

      if (decoded.type === 'lesson_context' && decoded.mode === 'quiz') {
        state.mode = 'quiz';
        state.lesson = {
          quizSessionId: String(decoded.quizSessionId ?? ''),
          wordId: String(decoded.wordId ?? ''),
          word: String(decoded.word ?? ''),
          attempts: Array.isArray(decoded.attempts) ? decoded.attempts.map(String) : [],
          hintLevel: Number(decoded.hintLevel ?? 0),
          visibleHints: Array.isArray(decoded.visibleHints) ? decoded.visibleHints.map(String) : [],
        };
        return;
      }

      if (decoded.type === 'free_context' && decoded.mode === 'free') {
        state.mode = 'free';
        state.lesson = null;
        return;
      }

      if (decoded.type === 'child_text') {
        const text = String(decoded.text ?? '').trim();
        if (!text) return;
        void handleUserText(text);
        return;
      }

      if (decoded.type === 'ui_event' && decoded.event === 'starter') {
        const text = String(decoded.text ?? '').trim();
        if (!text) return;
        void handleUserText(text);
        return;
      }
    } catch {
      // ignore
    }
  });

  lkRoom.on('trackSubscribed', (track: any) => {
    if (track.kind !== TrackKind.KIND_AUDIO) return;
    void handleAudioTrack(track as RemoteAudioTrack);
  });

  async function handleUserText(text: string): Promise<void> {
    sendJson({ type: 'transcript_final', text, isFinal: true });

    const response = await llmRespond(text);
    sendJson({ type: 'agent_message', text: response });
  }

  async function llmRespond(text: string): Promise<string> {
    setStatus('thinking');

    state.history.push({ role: 'user', content: text });
    state.history = state.history.slice(-12);

    const sys = systemPrompt(state.mode);
    const model = env.OPENAI_MODEL ?? 'gpt-5.1-mini';

    const extraContext: string[] = [];
    if (state.mode === 'quiz' && state.lesson) {
      extraContext.push(
        `QUIZ_CONTEXT: word=${state.lesson.word} attempts=${JSON.stringify(state.lesson.attempts)} hintLevel=${state.lesson.hintLevel}`,
      );
    }

    const completion = await openai.chat.completions.create({
      model,
      messages: [
        { role: 'system', content: sys },
        ...(extraContext.length ? [{ role: 'system' as const, content: extraContext.join('\n') }] : []),
        ...state.history,
      ],
      temperature: 0.7,
    });

    const out = completion.choices[0]?.message?.content?.trim() ?? '';
    const safe = out || "Let's try a quick spelling game. Tell me a word you want to practice.";
    state.history.push({ role: 'assistant', content: safe });
    state.history = state.history.slice(-12);

    setStatus('speaking');
    // Flutter will do TTS; we just mark speaking briefly.
    setTimeout(() => setStatus('listening'), 600);
    return safe;
  }

  async function handleAudioTrack(track: RemoteAudioTrack): Promise<void> {
    console.log('[agent] audio track subscribed');
    const stream = new AudioStream(track);

    let capturing = false;
    let lastVoiceAt = 0;
    let startAt = 0;
    let pcmChunks: Buffer[] = [];
    let sampleRate = 48000;

    const threshold = 0.015;

    const getHardSilenceMs = (): number => (state.mode === 'quiz' ? 12000 : 3500);
    const getMaxSegmentMs = (): number => (state.mode === 'quiz' ? 40000 : 25000);

    for await (const frame of stream) {
      // frame: { data: Int16Array, sampleRate: number, channels: number }
      const data = (frame as any).data as Int16Array;
      const sr = (frame as any).sampleRate as number;
      if (sr) sampleRate = sr;

      const energy = rms(data);
      const now = Date.now();

      if (!capturing) {
        if (energy >= threshold) {
          capturing = true;
          startAt = now;
          lastVoiceAt = now;
          pcmChunks = [];
          setStatus('listening');
        } else {
          continue;
        }
      }

      // Append PCM16 little-endian.
      pcmChunks.push(Buffer.from(data.buffer));
      if (energy >= threshold) lastVoiceAt = now;

      const hardSilence = now - lastVoiceAt >= getHardSilenceMs();
      const tooLong = now - startAt >= getMaxSegmentMs();

      if (hardSilence || tooLong) {
        capturing = false;
        const pcm = Buffer.concat(pcmChunks);
        pcmChunks = [];

        // Guard: ignore tiny segments.
        if (pcm.length < 48000 * 2 * 0.4) {
          continue;
        }

        void (async () => {
          try {
            setStatus('thinking');

            const wav = wavFromPcm16(pcm, sampleRate);
            const file = await toFile(wav, 'audio.wav');
            const tr = await openai.audio.transcriptions.create({
              model: 'gpt-4o-mini-transcribe',
              file,
            });
            const text = (tr.text ?? '').trim();
            if (!text) {
              setStatus('listening');
              return;
            }

            sendJson({ type: 'transcript_final', text, isFinal: true });

            if (state.mode === 'quiz') {
              const parsed = parseSpelledLetters(text);
              if (parsed.letters && parsed.confidence >= 0.75) {
                sendJson({
                  type: 'spelling_parsed',
                  letters: parsed.letters,
                  confidence: parsed.confidence,
                });
              }
            }

            const response = await llmRespond(text);
            sendJson({ type: 'agent_message', text: response });
          } catch (e) {
            console.error('[agent] stt/llm error', e);
            setStatus('listening');
          }
        })();
      }
    }
  }
}

void main();
