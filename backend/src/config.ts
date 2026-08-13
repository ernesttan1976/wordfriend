export const config = {
  port: Number(process.env.PORT) || 4000,
  // Do not default to empty string; fail fast if missing
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET || '',
  googleClientId: process.env.GOOGLE_CLIENT_ID || '',
  openaiApiKey: process.env.OPENAI_API_KEY || '',
  openaiModel: process.env.OPENAI_MODEL || 'gpt-5.1',

  // LiveKit (used by the voice agent feature)
  livekitWsUrl: process.env.LIVEKIT_WS_URL || '',
  livekitApiKey: process.env.LIVEKIT_API_KEY || '',
  livekitApiSecret: process.env.LIVEKIT_API_SECRET || '',
  livekitRoom: process.env.LIVEKIT_ROOM || 'wordfriend_main',
  // Optional: protect /livekit/agent-token with a shared secret header.
  livekitAgentSecret: process.env.LIVEKIT_AGENT_SECRET || '',
};

// Basic runtime checks in development to catch missing env
if (process.env.NODE_ENV !== 'production') {
  if (!config.databaseUrl) {
    console.warn('Warning: DATABASE_URL is not set');
  }
  if (!config.jwtSecret) {
    console.warn('Warning: JWT_SECRET is not set');
  }
  if (!config.googleClientId) {
    console.warn('Warning: GOOGLE_CLIENT_ID is not set');
  }
  if (!config.openaiApiKey) {
    console.warn('Warning: OPENAI_API_KEY is not set');
  }

  // LiveKit is optional unless you are enabling voice.
  if (!config.livekitWsUrl) {
    console.warn('Warning: LIVEKIT_WS_URL is not set');
  }
  if (!config.livekitApiKey) {
    console.warn('Warning: LIVEKIT_API_KEY is not set');
  }
  if (!config.livekitApiSecret) {
    console.warn('Warning: LIVEKIT_API_SECRET is not set');
  }
}
