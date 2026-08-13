const LETTER_WORDS: Record<string, string> = {
  a: 'a',
  ay: 'a',
  b: 'b',
  bee: 'b',
  be: 'b',
  c: 'c',
  see: 'c',
  sea: 'c',
  d: 'd',
  dee: 'd',
  e: 'e',
  ee: 'e',
  f: 'f',
  ef: 'f',
  g: 'g',
  gee: 'g',
  h: 'h',
  aitch: 'h',
  i: 'i',
  eye: 'i',
  j: 'j',
  jay: 'j',
  k: 'k',
  kay: 'k',
  l: 'l',
  el: 'l',
  m: 'm',
  em: 'm',
  n: 'n',
  en: 'n',
  o: 'o',
  oh: 'o',
  p: 'p',
  pee: 'p',
  q: 'q',
  cue: 'q',
  r: 'r',
  are: 'r',
  s: 's',
  ess: 's',
  t: 't',
  tee: 't',
  u: 'u',
  you: 'u',
  v: 'v',
  vee: 'v',
  w: 'w',
  doubleyou: 'w',
  x: 'x',
  ex: 'x',
  y: 'y',
  why: 'y',
  z: 'z',
  zee: 'z',
  zed: 'z',
};

export function parseSpelledLetters(transcript: string): {
  letters: string;
  confidence: number;
  tokens: string[];
} {
  const raw = transcript
    .toLowerCase()
    .replace(/[^a-z\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (!raw) return { letters: '', confidence: 0, tokens: [] };
  const tokens = raw.split(' ');

  const out: string[] = [];
  let recognized = 0;

  for (let i = 0; i < tokens.length; i += 1) {
    const t = tokens[i];

    // "double l" / "double el" patterns.
    if (t === 'double' && i + 1 < tokens.length) {
      const next = tokens[i + 1];
      const mapped = LETTER_WORDS[next];
      if (mapped) {
        out.push(mapped, mapped);
        recognized += 2;
        i += 1;
        continue;
      }
    }

    const mapped = LETTER_WORDS[t];
    if (mapped) {
      out.push(mapped);
      recognized += 1;
      continue;
    }

    // If token itself is a single letter.
    if (t.length === 1 && t >= 'a' && t <= 'z') {
      out.push(t);
      recognized += 1;
      continue;
    }
  }

  const confidence = tokens.length === 0 ? 0 : Math.min(1, recognized / Math.max(1, tokens.length));
  return { letters: out.join(''), confidence, tokens };
}
