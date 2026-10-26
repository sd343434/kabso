/**
 * KL-078 / owner D105 (openapi v1.20-live DRAFT, CONVENTIONS §10.20, §10.12): kicking someone out
 * of a live, and one person's points and rank in a live, end to end against PostgreSQL + Redis
 * with the API as the DML-only runtime role. The media server is the in-memory fake behind the
 * LiveMediaProvider port, which records removals and data messages (here also in one ordered log,
 * so the `kick` data message is seen to go out before the removal).
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LiveRoomsService } from '../src/modules/live/live-rooms.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += Math.round(seconds * 1000);
  }
}

/** The fake media server, with removals and broadcasts also in one ordered log. */
class LoggingMedia extends MemoryLiveMedia {
  readonly log: string[] = [];
  override removeParticipant(room: string, identity: string): Promise<void> {
    this.log.push(`remove:${room}:${identity}`);
    return super.removeParticipant(room, identity);
  }
  override broadcastData(room: string, topic: string, payload: string): Promise<void> {
    this.log.push(`data:${room}:${topic}`);
    return super.broadcastData(room, topic, payload);
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

const MISSING_ROOM = '0192f1d0-0000-7000-8000-000000000000';
const DAY_MS = 24 * 3600_000;

describe('v1.20-live contract coverage', () => {
  it('openapi declares the kick operations and the one-person contribution', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids.filter((id) => id.includes('/kicks')).sort()).toEqual(
      [
        'kickFromLive POST /api/v1/live/rooms/{roomId}/kicks',
        'listLiveKicks GET /api/v1/live/rooms/{roomId}/kicks',
        'unkickFromLive DELETE /api/v1/live/rooms/{roomId}/kicks/{username}',
      ].sort(),
    );
    expect(ids).toContain('getLiveContributor GET /api/v1/live/rooms/{roomId}/contributors/{username}');
  });
});

describe('D105 kicking someone out of a live', () => {
  const clock = new FakeClock();
  const media = new LoggingMedia();
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
  const goLive = async (u: TestUser, extra: object = {}): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Kick', ...extra });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expect(res.body.kicked).toBe(false);
    return res.body.id as string;
  };
  const end = async (roomId: string, u: TestUser) => {
    expect((await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u))).status).toBe(200);
  };
  const hook = (event: string, roomName: string, identity: string) => {
    const raw = JSON.stringify({ event, room: { name: roomName }, participant: { identity } });
    return ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
  };
  const join = async (roomId: string, u: TestUser) => {
    expect((await hook('participant_joined', roomId, u.id)).status).toBe(200);
  };
  const kick = (roomId: string, by: TestUser | null, body: unknown): request.Test => {
    const req = ctx.http.post(`/api/v1/live/rooms/${roomId}/kicks`);
    if (by) void req.set(auth(by));
    return req.send(body as object);
  };
  const kickOk = async (roomId: string, by: TestUser, target: TestUser, status = 201) => {
    const res = await kick(roomId, by, { username: target.username });
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    expectContract(res, 'kickFromLive');
    return res.body as { user: { id: string; username: string }; kickedAt: string };
  };
  const listKicks = async (roomId: string, by: TestUser) => {
    const res = await ctx.http.get(`/api/v1/live/rooms/${roomId}/kicks`).set(auth(by));
    expectContract(res, 'listLiveKicks');
    return res;
  };
  const unkick = async (roomId: string, by: TestUser, username: string) => {
    const res = await ctx.http.delete(`/api/v1/live/rooms/${roomId}/kicks/${username}`).set(auth(by));
    expectContract(res, 'unkickFromLive');
    return res;
  };
  const token = async (roomId: string, u: TestUser) => {
    const res = await ctx.http.post(`/api/v1/live/rooms/${roomId}/media-token`).set(auth(u)).send({});
    expectContract(res, 'createLiveMediaToken');
    return res;
  };
  const room = async (roomId: string, u: TestUser) => {
    const res = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(u));
    expectContract(res, 'getLiveRoom');
    expect(res.status).toBe(200);
    return res.body as { kicked: boolean; viewerCount: number };
  };
  const seats = async (roomId: string, u: TestUser) => {
    const res = await ctx.http.get(`/api/v1/live/rooms/${roomId}/seats`).set(auth(u));
    expect(res.status).toBe(200);
    return res.body as {
      version: number;
      seats: { index: number; state: string; user: { id: string } | null }[];
      moderators: { id: string }[];
    };
  };
  const addModerator = (roomId: string, by: TestUser, username: string) =>
    ctx.http.put(`/api/v1/live/rooms/${roomId}/moderators/${username}`).set(auth(by));
  /** `u` joins and sits on a seat (asked and accepted by the host). */
  const seat = async (roomId: string, h: TestUser, u: TestUser) => {
    await join(roomId, u);
    const asked = await ctx.http.post(`/api/v1/live/rooms/${roomId}/seat-requests`).set(auth(u)).send({});
    expect(asked.status).toBe(201);
    const accepted = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/seat-requests/${asked.body.id}/accept`)
      .set(auth(h))
      .send({});
    expect(accepted.status).toBe(200);
  };
  const expectCode = (res: request.Response, status: number, code: string) => {
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    expect(res.body.error.code).toBe(code);
  };
  const kickAudits = (targetId: string, action = 'live.kick') =>
    ctx.prisma.auditLog.findMany({ where: { action, targetId } });

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    ctx.app.getHttpServer().setMaxListeners(64);
  });
  afterAll(async () => ctx?.close());

  it('the host kicks a seated viewer of an AUDIO live: removed, seat freed, data message first, then 403 LIVE_KICKED everywhere', async () => {
    const owner = await host();
    const v = await signup();
    const roomId = await goLive(owner, { mode: 'AUDIO', seatCount: 5 });
    await seat(roomId, owner, v);
    expect((await seats(roomId, owner)).seats.find((s) => s.index === 1)?.user?.id).toBe(v.id);
    expect((await room(roomId, owner)).viewerCount).toBe(1);
    const versionBefore = (await seats(roomId, owner)).version;
    media.log.length = 0;

    const kicked = await kickOk(roomId, owner, v);
    expect(kicked).toEqual({
      user: { id: v.id, username: v.username, displayName: expect.any(String), avatarUrl: null },
      kickedAt: clock.now().toISOString(),
    });

    // The room gets `kick` on topic `kick`, before the person is removed from the media session.
    const data = media.broadcasts.filter((b) => b.room === roomId && b.topic === 'kick');
    expect(data).toHaveLength(1);
    expect(JSON.parse(data[0]!.payload)).toEqual({
      type: 'kick',
      user: kicked.user,
      by: { id: owner.id, username: owner.username, displayName: expect.any(String), avatarUrl: null },
      at: kicked.kickedAt,
    });
    const kickData = media.log.indexOf(`data:${roomId}:kick`);
    const removal = media.log.indexOf(`remove:${roomId}:${v.id}`);
    expect(kickData).toBeGreaterThanOrEqual(0);
    expect(removal).toBeGreaterThan(kickData);
    expect(media.removed).toContainEqual({ room: roomId, identity: v.id });

    // Seat freed (version moved), media-session row gone, publishing withdrawn.
    const after = await seats(roomId, owner);
    expect(after.seats.find((s) => s.index === 1)?.state).toBe('EMPTY');
    expect(after.version).toBeGreaterThan(versionBefore);
    expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId, identity: v.id } })).toBe(0);
    expect((await room(roomId, owner)).viewerCount).toBe(0);
    expect(media.lastPermission(roomId, v.id)).toEqual({ visible: false, sources: [] });

    // Until the live ends: token, chat, bullet, taps and seat requests → 403 LIVE_KICKED.
    expect((await room(roomId, v)).kicked).toBe(true);
    expect((await room(roomId, owner)).kicked).toBe(false);
    expectCode(await token(roomId, v), 403, 'LIVE_KICKED');
    const chat = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/chat`)
      .set(auth(v))
      .send({ text: 'back', clientId: randomUUID() });
    expectCode(chat, 403, 'LIVE_KICKED');
    expectContract(chat, 'sendLiveChatMessage');
    const bullet = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/bullets`)
      .set(auth(v))
      .send({ text: 'back', clientId: randomUUID() });
    expectCode(bullet, 403, 'LIVE_KICKED');
    expectContract(bullet, 'sendLiveBullet');
    const taps = await ctx.http.post(`/api/v1/live/rooms/${roomId}/taps`).set(auth(v)).send({ count: 5 });
    expectCode(taps, 403, 'LIVE_KICKED');
    expectContract(taps, 'tapLiveRoom');
    const ask = await ctx.http.post(`/api/v1/live/rooms/${roomId}/seat-requests`).set(auth(v)).send({});
    expectCode(ask, 403, 'LIVE_KICKED');
    expectContract(ask, 'requestLiveSeat');

    // A join with a token issued before the kick is refused and disconnected again.
    media.removed.length = 0;
    await join(roomId, v);
    expect(media.removed).toEqual([{ room: roomId, identity: v.id }]);
    expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId, identity: v.id } })).toBe(0);

    // Audited once.
    const audits = await kickAudits(v.id);
    expect(audits).toHaveLength(1);
    expect(audits[0]).toMatchObject({ actorUserId: owner.id, targetType: 'user' });
    expect(audits[0]!.metadata).toMatchObject({ roomId, wasSeated: true });
    await end(roomId, owner);
  });

  it('a video (SOLO) live too; kicking again → 200 with the first kick, nothing sent or audited again', async () => {
    const owner = await host();
    const v = await signup();
    const roomId = await goLive(owner);
    await join(roomId, v);
    expect((await token(roomId, v)).status).toBe(200);
    const first = await kickOk(roomId, owner, v);
    clock.advance(5);
    const again = await kickOk(roomId, owner, v, 200);
    expect(again).toEqual(first);
    expect(media.broadcastsOf(roomId, 'kick')).toHaveLength(1);
    expect(await kickAudits(v.id)).toHaveLength(1);
    expectCode(await token(roomId, v), 403, 'LIVE_KICKED');
    // Someone not in the room can be kicked too.
    const absent = await signup();
    await kickOk(roomId, owner, absent);
    expectCode(await token(roomId, absent), 403, 'LIVE_KICKED');
    await end(roomId, owner);
  });

  it('a moderator kicks a viewer; nobody kicks the host or themselves; a moderator never kicks a moderator; viewers cannot kick', async () => {
    const owner = await host();
    const [mod, mod2, v, w] = [await signup(), await signup(), await signup(), await signup()];
    const roomId = await goLive(owner, { mode: 'MULTI', seatCount: 4 });
    for (const u of [mod, mod2, v, w]) await join(roomId, u);
    expect((await addModerator(roomId, owner, mod.username)).status).toBe(200);
    expect((await addModerator(roomId, owner, mod2.username)).status).toBe(200);

    const byMod = await kickOk(roomId, mod, v);
    expect(byMod.user.id).toBe(v.id);
    const data = media.broadcastsOf(roomId, 'kick');
    expect(data.at(-1)).toMatchObject({ user: { id: v.id }, by: { id: mod.id } });
    expectCode(await token(roomId, v), 403, 'LIVE_KICKED');

    const refused = [
      await kick(roomId, mod, { username: owner.username }), // the host
      await kick(roomId, mod, { username: mod2.username }), // another moderator
      await kick(roomId, mod, { username: mod.username }), // themselves
      await kick(roomId, owner, { username: owner.username }), // the host themselves
      await kick(roomId, w, { username: mod.username }), // a viewer
      await kick(roomId, w, { username: w.username }), // a viewer, themselves
    ];
    for (const res of refused) {
      expectCode(res, 403, 'AUTH_FORBIDDEN');
      expectContract(res, 'kickFromLive');
    }
    expect(await ctx.prisma.liveRoomKick.count({ where: { roomId } })).toBe(1);

    // The host may kick a moderator: the role goes with it, and a kicked user cannot be appointed.
    await kickOk(roomId, owner, mod2);
    expect((await seats(roomId, owner)).moderators.map((m) => m.id)).toEqual([mod.id]);
    const reappoint = await addModerator(roomId, owner, mod2.username);
    expect(reappoint.status).toBe(422);
    expect(reappoint.body.error.details).toEqual([{ field: 'username', issue: 'invalid_value' }]);
    await end(roomId, owner);
  });

  it('check order: 401, 404 room, 409 ended, 400 body, 403 not host/moderator, 404 user', async () => {
    const owner = await host();
    const v = await signup();
    const roomId = await goLive(owner);
    expectCode(await kick(roomId, null, { username: v.username }), 401, 'AUTH_UNAUTHENTICATED');
    expectCode(await kick(MISSING_ROOM, owner, { username: v.username }), 404, 'NOT_FOUND');
    expectCode(await kick(roomId, owner, {}), 400, 'VALIDATION_FAILED');
    expectCode(await kick(roomId, owner, { username: v.username, extra: 1 }), 400, 'VALIDATION_FAILED');
    // Not host or moderator comes before the user lookup.
    expectCode(await kick(roomId, v, { username: 'nobody.here' }), 403, 'AUTH_FORBIDDEN');
    expectCode(await kick(roomId, owner, { username: 'nobody.here' }), 404, 'NOT_FOUND');
    expectCode(await kick(roomId, owner, { username: 'Not A Username!' }), 404, 'NOT_FOUND');
    await end(roomId, owner);
    const ended = await kick(roomId, owner, { username: v.username });
    expectCode(ended, 409, 'LIVE_ROOM_ENDED');
    expectContract(ended, 'kickFromLive');
  });

  it('list (host and moderators) and undo: the person may get a token again; idempotent; audited once', async () => {
    const owner = await host();
    const [mod, v, w] = [await signup(), await signup(), await signup()];
    const roomId = await goLive(owner, { mode: 'AUDIO', seatCount: 5 });
    await join(roomId, mod);
    expect((await addModerator(roomId, owner, mod.username)).status).toBe(200);
    await join(roomId, v);
    await kickOk(roomId, owner, v);
    clock.advance(2);
    await kickOk(roomId, mod, w);

    const listed = await listKicks(roomId, mod);
    expect(listed.status).toBe(200);
    expect((listed.body.data as { user: { id: string } }[]).map((k) => k.user.id)).toEqual([w.id, v.id]);
    expect((await listKicks(roomId, owner)).body.data).toHaveLength(2);
    expectCode(await listKicks(roomId, v), 403, 'AUTH_FORBIDDEN');

    expectCode(await unkick(roomId, v, w.username), 403, 'AUTH_FORBIDDEN');
    expectCode(await unkick(roomId, owner, 'nobody.here'), 404, 'NOT_FOUND');
    expect((await unkick(roomId, mod, v.username)).status).toBe(204);
    expect((await unkick(roomId, mod, v.username)).status).toBe(204);
    expect(await kickAudits(v.id, 'live.kick.undo')).toHaveLength(1);
    expect((await room(roomId, v)).kicked).toBe(false);
    expect((await token(roomId, v)).status).toBe(200);
    expect(
      (await listKicks(roomId, owner)).body.data.map((k: { user: { id: string } }) => k.user.id),
    ).toEqual([w.id]);

    await end(roomId, owner);
    // The list stays readable on the ended room; undo needs a live room.
    expect((await listKicks(roomId, owner)).status).toBe(200);
    expectCode(await unkick(roomId, owner, w.username), 409, 'LIVE_ROOM_ENDED');
  });

  it('a kick lasts until that live ends: a new live of the same host lets the person in', async () => {
    const owner = await host();
    const v = await signup();
    const first = await goLive(owner);
    await kickOk(first, owner, v);
    expectCode(await token(first, v), 403, 'LIVE_KICKED');
    await end(first, owner);

    const second = await goLive(owner);
    expect((await room(second, v)).kicked).toBe(false);
    expect((await token(second, v)).status).toBe(200);
    await join(second, v);
    const chat = await ctx.http
      .post(`/api/v1/live/rooms/${second}/chat`)
      .set(auth(v))
      .send({ text: 'back again', clientId: randomUUID() });
    expect(chat.status).toBe(201);
    await end(second, owner);
  });

  it('retention: kicks are removed with the chat mutes, 30 days after their room ended', async () => {
    const owner = await host();
    const v = await signup();
    const roomId = await goLive(owner);
    await kickOk(roomId, owner, v);
    await end(roomId, owner);
    const now = clock.now();
    const at = new Date(now.getTime() - 31 * DAY_MS);
    await ctx.prisma.liveRoom.update({
      where: { id: roomId },
      data: { startedAt: at, lastHeartbeatAt: at, endedAt: at },
    });
    const result = await ctx.app.get(LiveRoomsService).sweepChatRetention(now);
    expect(result.kicks).toBeGreaterThanOrEqual(1);
    expect(await ctx.prisma.liveRoomKick.count({ where: { roomId } })).toBe(0);
  });
});

describe('D105 one person’s points in a live (GET …/contributors/{username})', () => {
  const clock = new FakeClock();
  let ctx: TestContext;
  let seq = 0;

  interface Person {
    readonly id: string;
    readonly username: string;
  }
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async () => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const quickUser = async (): Promise<Person> => {
    seq += 1;
    const tag = `${Date.now().toString(36)}${seq}`;
    const username = `kl078${tag}`.slice(0, 30);
    const user = await ctx.prisma.user.create({
      data: {
        email: `kl078-${tag}@example.com`,
        passwordHash: 'x',
        profile: { create: { username, displayName: `Fan ${seq}` } },
      },
    });
    return { id: user.id, username };
  };
  const setTapper = (roomId: string, userId: string, counted: number, at: Date) =>
    ctx.prisma.liveRoomTapper.upsert({
      where: { roomId_userId: { roomId, userId } },
      create: { roomId, userId, counted, lastBatchAt: at, points: counted, pointsAt: at },
      update: { counted, lastBatchAt: at, points: counted, pointsAt: at },
    });
  const standing = async (roomId: string, username: string, reader?: { token: string }) => {
    const req = ctx.http.get(`/api/v1/live/rooms/${roomId}/contributors/${username}`);
    if (reader) void req.set(auth(reader));
    const res = await req;
    expectContract(res, 'getLiveContributor');
    return res;
  };
  const list = async (roomId: string, reader?: { token: string }) => {
    const req = ctx.http.get(`/api/v1/live/rooms/${roomId}/contributors`);
    if (reader) void req.set(auth(reader));
    const res = await req;
    expect(res.status).toBe(200);
    return (res.body.data as { user: { id: string }; points: number }[]).map((c) => [c.user.id, c.points]);
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('points and rank match the list (ties as the list orders them); 0 points → rank null; the host → 0', async () => {
    const owner = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: owner.id, source: 'ADMIN' } });
    const started = await ctx.http.post('/api/v1/live/rooms').set(auth(owner)).send({ title: 'Points' });
    expect(started.status).toBe(201);
    const roomId = started.body.id as string;
    const t0 = new Date(clock.now().getTime() - 60_000);
    const at = (s: number) => new Date(t0.getTime() + s * 1000);

    const top = await quickUser();
    const early = await quickUser();
    const [x, y] = [await quickUser(), await quickUser()].sort((a, b) => (a.id < b.id ? -1 : 1));
    const late = await quickUser();
    const zero = await quickUser();
    const none = await quickUser();
    await setTapper(roomId, top.id, 21, at(50));
    await setTapper(roomId, late.id, 20, at(30));
    await setTapper(roomId, early.id, 20, at(10));
    await setTapper(roomId, y!.id, 20, at(20));
    await setTapper(roomId, x!.id, 20, at(20));
    await setTapper(roomId, zero.id, 0, at(1));
    await setTapper(roomId, owner.id, 500, at(2)); // never listed, never ranked

    const listed = await list(roomId);
    expect(listed).toEqual([
      [top.id, 21],
      [early.id, 20],
      [x!.id, 20],
      [y!.id, 20],
      [late.id, 20],
    ]);
    for (const [i, person] of [top, early, x!, y!, late].entries()) {
      const res = await standing(roomId, person.username);
      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        user: { id: person.id, username: person.username, displayName: expect.any(String), avatarUrl: null },
        points: listed[i]![1],
        rank: i + 1,
      });
    }
    expect((await standing(roomId, zero.username)).body).toMatchObject({ points: 0, rank: null });
    expect((await standing(roomId, none.username)).body).toMatchObject({ points: 0, rank: null });
    expect((await standing(roomId, owner.username)).body).toMatchObject({
      user: { id: owner.id },
      points: 0,
      rank: null,
    });

    // Real taps through the API count the same way.
    const fan = await signup();
    const tapped = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/taps`)
      .set(auth(fan))
      .send({ count: 10 });
    expect(tapped.body.accepted).toBe(10);
    expect((await standing(roomId, fan.username, fan)).body).toMatchObject({ points: 10, rank: 6 });

    // A reader's blocks are left out of the ranking, as in the list; a blocked person → 404.
    const reader = await signup();
    await ctx.http.put(`/api/v1/users/${fan.username}/block`).set(auth(reader)).expect(200);
    expect((await standing(roomId, fan.username, reader)).status).toBe(404);
    expect((await standing(roomId, late.username, reader)).body.rank).toBe(5);

    // Unknown user / room → 404; ended rooms stay readable.
    expect((await standing(roomId, 'nobody.here')).status).toBe(404);
    expect((await standing(MISSING_ROOM, top.username)).status).toBe(404);
    expect((await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(owner))).status).toBe(200);
    expect((await standing(roomId, top.username)).body).toMatchObject({ points: 21, rank: 1 });
  });

  it('guests read it while the room allows guests (else 403 LIVE_GUESTS_NOT_ALLOWED)', async () => {
    const owner = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: owner.id, source: 'ADMIN' } });
    const started = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(owner))
      .send({ title: 'Guests', allowGuests: false });
    expect(started.status).toBe(201);
    const roomId = started.body.id as string;
    const fan = await quickUser();
    await setTapper(roomId, fan.id, 3, clock.now());
    const refused = await standing(roomId, fan.username);
    expect(refused.status).toBe(403);
    expect(refused.body.error.code).toBe('LIVE_GUESTS_NOT_ALLOWED');
    await ctx.http
      .patch(`/api/v1/live/rooms/${roomId}`)
      .set(auth(owner))
      .send({ allowGuests: true })
      .expect(200);
    expect((await standing(roomId, fan.username)).body).toMatchObject({ points: 3, rank: 1 });
    await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(owner)).expect(200);
  });
});
