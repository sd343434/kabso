/**
 * D350: LiveKit's signed webhook on the public path `POST /livekit/webhook`, for a dedicated media node that is not on
 * the API's docker network. Off by default (404 NOT_FOUND, as an unknown route; the internal route is unchanged).
 * With LIVEKIT_PUBLIC_WEBHOOK_ENABLED=true it is the same handler as `POST /internal/livekit/webhook`: a signed join
 * records the viewer; a wrong signature is 401. The second app uses the REAL LiveKitMediaProvider, so the signature is
 * the one LiveKit sends (a JWT signed with the API secret carrying the body's sha256, made here with the server SDK).
 */
import { createHash } from 'node:crypto';
import { AccessToken } from 'livekit-server-sdk';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { LiveKitMediaProvider } from '../src/modules/live/media/livekit-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

const KEY = 'APId350test';
const SECRET = 'd350-e2e-secret-0123456789-abcdefghijklmnopqrstuvwxyz';

interface TestUser {
  readonly id: string;
  readonly token: string;
}

async function users(ctx: TestContext) {
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id as string, token: res.body.tokens.accessToken as string };
  };
  const host = await signup();
  await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
  const viewer = await signup();
  const live = await ctx.http
    .post('/api/v1/live/rooms')
    .set({ Authorization: `Bearer ${host.token}` })
    .send({ title: 'D350 webhook' });
  expect(live.status, JSON.stringify(live.body)).toBe(201);
  return { host, viewer, roomId: live.body.id as string };
}

const joined = (roomId: string, identity: string) =>
  JSON.stringify({ event: 'participant_joined', room: { name: roomId }, participant: { identity } });

describe('D350 public LiveKit webhook — off by default', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' });
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('answers 404 NOT_FOUND like an unknown route; the internal route still records the join', async () => {
    const { viewer, roomId } = await users(ctx);
    const raw = joined(roomId, viewer.id);
    const pub = await ctx.http
      .post('/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(pub.status).toBe(404);
    expect(pub.body.error.code).toBe('NOT_FOUND');
    expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId, userId: viewer.id } })).toBe(0);

    const internal = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(internal.status).toBe(200);
    expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId, userId: viewer.id } })).toBe(1);
  });
});

describe('D350 public LiveKit webhook — enabled, real signature check', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  const provider = new LiveKitMediaProvider('ws://127.0.0.1:9', KEY, SECRET);
  const sign = (raw: string, secret = SECRET, key = KEY) => {
    const token = new AccessToken(key, secret, { ttl: 300 });
    token.sha256 = createHash('sha256').update(raw).digest('base64');
    return token.toJwt();
  };
  const post = (path: string, raw: string, authorization: string | undefined) => {
    const req = ctx.http.post(path).set('Content-Type', 'application/webhook+json');
    if (authorization !== undefined) req.set('Authorization', authorization);
    return req.send(raw);
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVEKIT_PUBLIC_WEBHOOK_ENABLED: 'true' }, [
      { token: LIVE_MEDIA_PROVIDER, value: provider },
    ]);
  });
  afterAll(async () => {
    provider.onModuleDestroy();
    await ctx?.close();
  });

  it('records a join signed by LiveKit and refuses anything else with 401', async () => {
    const { viewer, roomId } = await users(ctx);
    const raw = joined(roomId, viewer.id);
    const count = () => ctx.prisma.liveRoomViewer.count({ where: { roomId, userId: viewer.id } });

    for (const [why, authorization] of [
      ['no signature', undefined],
      ['wrong secret', await sign(raw, `${SECRET}x`)],
      ['wrong key', await sign(raw, SECRET, `${KEY}x`)],
      ['signed for another body', await sign(joined(roomId, 'someone-else'))],
      ['not a JWT', 'Bearer nope'],
    ] as const) {
      const res = await post('/livekit/webhook', raw, authorization);
      expect(res.status, why).toBe(401);
      expect(res.body.error.code, why).toBe('AUTH_UNAUTHENTICATED');
    }
    expect(await count()).toBe(0);

    const ok = await post('/livekit/webhook', raw, await sign(raw));
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expect(ok.body).toEqual({ ok: true });
    expect(await count()).toBe(1);

    // Not under the API prefix, and only POST.
    expect((await post('/api/v1/livekit/webhook', raw, await sign(raw))).status).toBe(404);
    expect((await ctx.http.get('/livekit/webhook')).status).toBe(404);
  });

  it('the internal route keeps working next to it', async () => {
    const { viewer, roomId } = await users(ctx);
    const raw = joined(roomId, viewer.id);
    const res = await post('/internal/livekit/webhook', raw, await sign(raw));
    expect(res.status).toBe(200);
    expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId, userId: viewer.id } })).toBe(1);
  });
});
