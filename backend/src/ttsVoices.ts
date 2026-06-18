export const OPENAI_TTS_VOICES = [
  { id: 'alloy', label: 'Alloy (Neutral)' },
  { id: 'aria', label: 'Aria (Bright)' },
  { id: 'sage', label: 'Sage (Calm)' },
  { id: 'verse', label: 'Verse (Expressive)' },
];

export type OpenAiTtsVoiceId = typeof OPENAI_TTS_VOICES[number]['id'];
