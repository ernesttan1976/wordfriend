import { Router, Request, Response, NextFunction } from 'express';
import { AccessToken, type VideoGrant } from 'livekit-server-sdk';
import { authMiddleware, type AuthRequest } from '../auth/jwt';
import { config } from '../config';

const router = Router();

function requireLiveKitConfigured(res: Response): boolean {
  if (!config.livekitWsUrl || !config.livekitApiKey || !config.livekitApiSecret) {
    res.status(503).json({
      error: 'LiveKit is not configured',
      missing: {
        LIVEKIT_WS_URL: !config.livekitWsUrl,
        LIVEKIT_API_KEY: !config.livekitApiKey,
        LIVEKIT_API_SECRET: !config.livekitApiSecret,
      },
    });
    return false;
  }
  return true;
}

function normalizeIdentity(input: unknown): string | null {
  if (typeof input !== 'string') return null;
  const trimmed = input.trim();
  if (!trimmed) return null;
  if (trimmed.length > 128) return null;
  return trimmed;
}

async function mintToken(identity: string, grant: VideoGrant): Promise<string> {
  const at = new AccessToken(config.livekitApiKey, config.livekitApiSecret, {
    identity,
    // 6h is long enough for a session; clients should re-mint on reconnect.
    ttl: 6 * 60 * 60,
  });
  at.addGrant(grant);
  return await at.toJwt();
}

// Child/app token minting (protected by existing app JWT)
// POST /livekit/token
// Body: { identity: "child_client" }
router.post('/token', authMiddleware, (req: AuthRequest, res) => {
  if (!requireLiveKitConfigured(res)) return;

  const body = req.body as { identity?: unknown };
  const identity = normalizeIdentity(body?.identity) ?? 'child_client';
  const room = config.livekitRoom;

  void (async () => {
    const token = await mintToken(identity, {
      roomJoin: true,
      room,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    res.json({ token, wsUrl: config.livekitWsUrl, room });
  })();
});

function agentSecretMiddleware(req: Request, res: Response, next: NextFunction): void {
  if (!config.livekitAgentSecret) {
    res.status(403).json({ error: 'Agent token minting is disabled' });
    return;
  }

  const provided = req.header('x-agent-secret');
  if (!provided || provided !== config.livekitAgentSecret) {
    res.status(401).json({ error: 'Invalid agent secret' });
    return;
  }

  next();
}

// Optional agent token minting (protected by x-agent-secret)
// POST /livekit/agent-token
// Body: { identity?: "tutor_agent" }
router.post('/agent-token', agentSecretMiddleware, (req: Request, res) => {
  if (!requireLiveKitConfigured(res)) return;

  const body = req.body as { identity?: unknown };
  const identity = normalizeIdentity(body?.identity) ?? 'tutor_agent';
  const room = config.livekitRoom;

  void (async () => {
    const token = await mintToken(identity, {
      roomJoin: true,
      room,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    res.json({ token, wsUrl: config.livekitWsUrl, room });
  })();
});

export default router;
