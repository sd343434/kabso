/**
 * KL-070 / CP-016 part B (D99): the host's blocked words (openapi v1.12-live DRAFT, CONVENTIONS
 * §10.14, §7), end to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 * The media server is the in-memory fake behind the LiveMediaProvider port (it records the chat
 * data messages and accepts the signed webhook that puts a viewer in the room).
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('CP-016 B contract coverage', () => {
  it('openapi declares getLiveBlockedWords and setLiveBlockedWords', () => {
    expect(
      operations()
        .filter((o) => o.path === '/api/v1/me/live-blocked-words')
        .map((o) => `${o.operationId} ${o.method.toUpperCase()}`)
        .sort(),
    ).toEqual(['getLiveBlockedWords GET', 'setLiveBlockedWords PUT']);
  });
});

describe('CP-016 B blocked words', () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const get = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/live-blocked-words').set(auth(u));
    expectContract(res, 'getLiveBlockedWords');
    return res;
  };
  const put = async (u: TestUser, body: unknown) => {
    const res = await ctx.http
      .put('/api/v1/me/live-blocked-words')
      .set(auth(u))
      .send(body as object);
    expectContract(res, 'setLiveBlockedWords');
    return res;
  };
  const goLive = async (u: TestUser): Promise<string> => {
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'Words' });
    expect(res.status).toBe(201);
    return res.body.id as string;
  };
  const join = async (roomId: string, u: TestUser) => {
    const raw = JSON.stringify({
      event: 'participant_joined',
      room: { name: roomId },
      participant: { identity: u.id },
    });
    const res = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(res.status).toBe(200);
  };
  const say = async (roomId: string, u: TestUser, text: string) => {
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/chat`)
      .set(auth(u))
      .send({ text, clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'sendLiveChatMessage');
    return res.body as { text: string };
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('starts empty; PUT replaces, normalizes and drops duplicates; audited with the count', async () => {
    const h = await host();
    expect((await get(h)).body).toEqual({ words: [] });
    const saved = await put(h, { words: ['  Spam ', 'spam', 'غبي', 'غَبي', 'go away'] });
    expect(saved.status).toBe(200);
    expect(saved.body).toEqual({ words: ['Spam', 'غبي', 'go away'] });
    expect((await get(h)).body).toEqual({ words: ['Spam', 'غبي', 'go away'] });
    expect((await put(h, { words: [] })).body).toEqual({ words: [] });
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'live.blocked_words.update', actorUserId: h.id },
      orderBy: { createdAt: 'asc' },
    });
    expect(audit.map((a) => a.metadata)).toEqual([{ count: 3 }, { count: 0 }]);
  });

  it('masks the host’s words in their lives, stored and sent; other hosts unaffected', async () => {
    const h = await host();
    const other = await host();
    const viewer = await signup();
    await put(h, { words: ['dumb', 'غبي'] });
    const roomId = await goLive(h);
    await join(roomId, viewer);
    const sent = await say(roomId, viewer, 'you are DUMB والغبي, not a class act');
    expect(sent.text).toBe('you are **** وال***, not a class act');
    const listed = await ctx.http.get(`/api/v1/live/rooms/${roomId}/chat`).set(auth(viewer));
    expect(listed.body.data.map((m: { text: string }) => m.text)).toContain(sent.text);
    const raw = await ctx.prisma.liveChatMessage.findMany({ where: { roomId } });
    expect(raw.some((m) => /dumb|غبي/i.test(m.text))).toBe(false);
    const broadcast = media.broadcasts.filter((b) => b.room === roomId).map((b) => b.payload);
    expect(broadcast.some((p) => p.includes('****'))).toBe(true);
    expect(broadcast.some((p) => /DUMB/.test(p))).toBe(false);
    // The host's own messages too.
    expect((await say(roomId, h, 'dumb')).text).toBe('****');

    const otherRoom = await goLive(other);
    await join(otherRoom, viewer);
    expect((await say(otherRoom, viewer, 'dumb')).text).toBe('dumb');
  });

  it('refuses: no permission → 403; bad words → 400; over 100 → too_long; strict body', async () => {
    const plain = await signup();
    expect((await get(plain)).status).toBe(403);
    const refused = await put(plain, { words: ['x'] });
    expect(refused.status).toBe(403);
    expect(refused.body.error.code).toBe('LIVE_HOSTING_NOT_ALLOWED');

    const h = await host();
    expect((await put(h, { words: [''] })).status).toBe(400);
    expect((await put(h, { words: ['x'.repeat(31)] })).status).toBe(400);
    expect((await put(h, { words: ['a\nb'] })).status).toBe(400);
    const many = await put(h, { words: Array.from({ length: 101 }, (_, i) => `w${i}`) });
    expect(many.status).toBe(400);
    expect(many.body.error.details).toEqual([{ field: 'words', issue: 'too_long' }]);
    expect((await put(h, { words: [], extra: 1 })).status).toBe(400);
    expect((await put(h, {})).status).toBe(400);
  });
});

describe('CP-016 B rate limit', () => {
  it('PUT: 30 / hour / user (here 2)', async () => {
    const ctx = await createTestApp({
      LIVE_HOSTING_ENABLED: 'true',
      RATE_LIMIT_LIVE_BLOCKED_WORDS_USER: '2/3600',
    });
    try {
      const { res } = await registerVerified(ctx);
      const headers = { Authorization: `Bearer ${res.body.tokens.accessToken as string}` };
      await ctx.prisma.liveHost.create({ data: { userId: res.body.user.id, source: 'ADMIN' } });
      const put = () => ctx.http.put('/api/v1/me/live-blocked-words').set(headers).send({ words: [] });
      expect((await put()).status).toBe(200);
      expect((await put()).status).toBe(200);
      expect((await put()).status).toBe(429);
      // GET uses the default bucket.
      expect((await ctx.http.get('/api/v1/me/live-blocked-words').set(headers)).status).toBe(200);
    } finally {
      await ctx.close();
    }
  });
});
