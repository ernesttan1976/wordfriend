import { Router } from 'express';
import OpenAI from 'openai';
import { config } from '../config';
import { OPENAI_TTS_VOICES } from '../ttsVoices';
import { pool } from '../db';

const router = Router();

const openai = new OpenAI({ apiKey: config.openaiApiKey });

router.get('/voices', (_req, res) => {
  res.json({ voices: OPENAI_TTS_VOICES });
});

router.post('/', async (req, res) => {
  try {
    const { text, voice, force } = req.body as { text?: string; voice?: string; force?: boolean };

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

    const spelling = text.trim();

    // Check if we already have cached TTS for this word (unless forced)
    const existing = await pool.query(
      'SELECT id, tts_audio_base64 FROM words WHERE spelling = $1 LIMIT 1',
      [spelling],
    );

    if (!force && existing.rows.length > 0 && existing.rows[0].tts_audio_base64) {
      const buffer = Buffer.from(existing.rows[0].tts_audio_base64, 'base64');
      res.setHeader('Content-Type', 'audio/mpeg');
      res.setHeader('Cache-Control', 'public, max-age=31536000');
      return res.send(buffer);
    }

    const response = await openai.audio.speech.create({
      model: 'gpt-4o-mini-tts',
      voice: allowed.id,
      input: text,
      // Default speaking rate at 0.7x
      speed: 0.7,
    });

    const buffer = Buffer.from(await response.arrayBuffer());

    // Persist base64 to DB if word exists
    const base64 = buffer.toString('base64');
    if (existing.rows.length > 0) {
      await pool.query(
        'UPDATE words SET tts_audio_base64 = $1 WHERE id = $2',
        [base64, existing.rows[0].id],
      );
    }

    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Cache-Control', 'no-store');
    res.send(buffer);
  } catch (err) {
    console.error('TTS error', err);
    res.status(500).json({ error: 'TTS failed' });
  }
});

export default router;
