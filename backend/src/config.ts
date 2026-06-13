export const config = {
  port: Number(process.env.PORT) || 4000,
  databaseUrl: process.env.DATABASE_URL || '',
  jwtSecret: process.env.JWT_SECRET || '',
  googleClientId: process.env.GOOGLE_CLIENT_ID || '',
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
}
