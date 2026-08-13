# Voice Agent

Node LiveKit participant that listens to the child's mic, transcribes via OpenAI, and sends text responses back to Flutter over LiveKit data messages.

## Run (dev)

1. Ensure backend is running and `LIVEKIT_AGENT_SECRET` is set on the backend.
2. Ensure LiveKit server is reachable and backend `LIVEKIT_*` envs are configured.
3. Create `voice-agent/.env` from `.env.example`.
4. Run:

```bash
cd voice-agent
npm install
npm run dev
```
