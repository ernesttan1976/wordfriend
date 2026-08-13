import { OAuth2Client, TokenPayload } from 'google-auth-library';
import { config } from '../config';

// Accept a single client id or a comma-separated list of ids.
// This is useful when you have distinct Web/Android/iOS OAuth client ids.
function parseGoogleClientIds(raw: string): string[] {
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

const client = new OAuth2Client();

export interface GoogleUser {
  sub: string;
  email?: string | null;
}

export async function verifyGoogleIdToken(idToken: string): Promise<GoogleUser> {
  const googleClientIds = parseGoogleClientIds(config.googleClientId);
  if (googleClientIds.length === 0) {
    throw new Error('GOOGLE_CLIENT_ID is not configured');
  }

  const ticket = await client.verifyIdToken({
    idToken,
    audience: googleClientIds,
  });

  const payload: TokenPayload | undefined = ticket.getPayload();

  if (!payload || !payload.sub) {
    throw new Error('Invalid Google ID token');
  }

  return {
    sub: payload.sub,
    email: payload.email,
  };
}
