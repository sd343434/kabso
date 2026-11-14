/**
 * D154c (owner 2026-10-28, item 13; contract v1.34-live, CONVENTIONS §10.35): newcomers «الجدد» — the
 * host's and moderators' list of the people in the live whose account is younger than NEWCOMER_DAYS
 * (owner: 30), and the «جديد 🌱» chat badge — end to end against PostgreSQL + Redis.
 */
import type request from 'supertest';
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

describe('D154c contract coverage', () => {
  it('openapi v1.34-live declares the newcomers operation', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('listLiveNewcomers GET /api/v1/live/rooms/{roomId}/newcomers');
  });
});

describe('D154c newcomers', { timeout: 120_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  /** Makes `u`'s account `days` old. */
  const age = (u: TestUser, days: number) =>
    ctx.prisma.user.update({
      where: { id: u.id },
      data: { createdAt: new Date(Date.now() - days * 86_400_000) },
    });
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
  const list = (roomId: string, u: TestUser): request.Test =>
    ctx.http.get(`/api/v1/live/rooms/${roomId}/newcomers`).set(auth(u));

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('the host and moderators see the newcomers in the room (never their signup date); viewers cannot', async () => {
    const h = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    await age(h, 400);
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'Welcome' });
    expect(room.status).toBe(201);
    const roomId = room.body.id as string;
    const [fresh, month, veteran, mod, away] = [
      await signup(),
      await signup(),
      await signup(),
      await signup(),
      await signup(),
    ];
    await age(month, 29);
    await age(veteran, 31);
    await age(mod, 90);
    for (const u of [fresh, month, veteran, mod]) await join(roomId, u);
    await ctx.prisma.liveRoomModerator.create({ data: { roomId, userId: mod.id } });

    const res = await list(roomId, h);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listLiveNewcomers');
    expect(res.body.newcomerDays).toBe(30);
    const names = (res.body.data as { username: string }[]).map((u) => u.username);
    expect(names.sort()).toEqual([fresh.username, month.username].sort());
    expect(names).not.toContain(away.username);
    expect(JSON.stringify(res.body)).not.toMatch(/createdAt|created_at|joined/i);

    const byMod = await list(roomId, mod);
    expect(byMod.status).toBe(200);
    const forbidden = await list(roomId, fresh);
    expect(forbidden.status).toBe(403);
    expect(forbidden.body.error.code).toBe('AUTH_FORBIDDEN');
    expectContract(forbidden, 'listLiveNewcomers');

    // A block either way hides the person from the caller's list.
    await ctx.prisma.userBlock.create({ data: { blockerId: fresh.id, blockedId: h.id } });
    const afterBlock = await list(roomId, h);
    expect((afterBlock.body.data as { username: string }[]).map((u) => u.username)).toEqual([month.username]);

    // The chat badge: «جديد 🌱» for a young account only.
    const say = async (u: TestUser) => {
      const sent = await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/chat`)
        .set(auth(u))
        .send({ text: 'hi', clientId: crypto.randomUUID() });
      expect(sent.status, JSON.stringify(sent.body)).toBe(201);
      return sent.body.authorBadges as { newcomer: boolean };
    };
    expect((await say(month)).newcomer).toBe(true);
    expect((await say(veteran)).newcomer).toBe(false);

    await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
    const ended = await list(roomId, h);
    expect(ended.status).toBe(409);
    expect(ended.body.error.code).toBe('LIVE_ROOM_ENDED');
  });
});
