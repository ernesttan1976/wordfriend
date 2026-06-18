import { Router } from 'express';
import OpenAI from 'openai';
import { config } from '../config';
import { OPENAI_TTS_VOICES } from '../ttsVoices';

const router = Router();

const openai = new OpenAI({ apiKey: config.openaiApiKey });

router.get('/voices', (_req, res) => {
  res.json({ voices: OPENAI_TTS_VOICES });
});

router.post('/', async (req, res) => {
  try {
    const { text, voice } = req.body as { text?: string; voice?: string };

    if (!text || typeof text !== 'string') {
      return res.status(400).json({ error: 'Invalid text' });
    }

    if (text.length > 100) {
      return res.status(400).json({ error: 'Text too long' });
    }

    const allowed = OPENAI_TTS_VOICES.find(v => v.id === voice);
    if (!allowed) {
      return res.status(400).json({ error: 'Invalid voice' });
    }

    if (!config.openaiApiKey) {
      return res.status(500).json({ error: 'OpenAI not configured' });
    }

    const response = await openai.audio.speech.create({
      model: 'gpt-4o-mini-tts',
      voice: allowed.id,
      input: text,
    });

    const buffer = Buffer.from(await response.arrayBuffer());

    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Cache-Control', 'no-store');
    res.send(buffer);
  } catch (err) {
    console.error('TTS error', err);
    res.status(500).json({ error: 'TTS failed' });
  }
});

export default router;
