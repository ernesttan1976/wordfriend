import { OAuth2Client, TokenPayload } from 'google-auth-library';
import { config } from '../config';

const client = new OAuth2Client(config.googleClientId);

export interface GoogleUser {
  sub: string;
  email?: string | null;
}

export async function verifyGoogleIdToken(idToken: string): Promise<GoogleUser> {
  if (!config.googleClientId) {
    throw new Error('GOOGLE_CLIENT_ID is not configured');
  }

  const ticket = await client.verifyIdToken({
    idToken,
    audience: config.googleClientId,
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
