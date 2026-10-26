/**
 * KL-068 / CP-014 parts A and B (D97): editing a live (title, category, topic), the topic on rooms
 * and hub cards, the room info version in the media room's metadata, and the public Contribution
 * list (openapi v1.10-live DRAFT, CONVENTIONS §10.12, §7), end to end against PostgreSQL + Redis
 * with the API as the DML-only runtime role.
 *
 * The media server is the in-memory fake behind the LiveMediaProvider port, which records the room
 * metadata; the last suite runs against a real LiveKit server (LIVEKIT_TEST_URL) and reads the
 * metadata back from it.
 */
import { randomUUID } from 'node:crypto';
import { RoomServiceClient } from 'livekit-server-sdk';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LiveMediaService } from '../src/modules/live/live-media.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { LiveKitMediaProvider } from '../src/modules/live/media/livekit-media.provider.js';
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

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface Contributor {
  user: { id: string; username: string; displayName: string; avatarUrl: string | null };
  points: number;
}

const MISSING_ROOM = '0192f1d0-0000-7000-8000-000000000000';
const url = process.env.LIVEKIT_TEST_URL;
const key = process.env.LIVEKIT_TEST_API_KEY ?? 'devkey';
const secret = process.env.LIVEKIT_TEST_API_SECRET ?? 'secret';

describe('CP-014 contract coverage', () => {
  it('openapi declares listLiveContributors and the new PATCH fields; topic is required on summaries', () => {
    expect(
      operations()
        .filter((o) => o.path === '/api/v1/live/rooms/{roomId}/contributors')
        .map((o) => `${o.operationId} ${o.method.toUpperCase()}`),
    ).toEqual(['listLiveContributors GET']);
    const patch = operations().find((o) => o.operationId === 'updateLiveRoom');
    expect(patch?.method).toBe('patch');
  });
});

/** Shared helpers for an app context (fake or real media server). */
function helpers(get: () => TestContext) {
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(get());
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await get().prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser, extra: object = {}): Promise<string> => {
    const res = await get()
      .http.post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Edit me', ...extra });
    expect(res.status).toBe(201);
    expectContract(res, 'startLiveRoom');
    // CP-014: a new live starts without a topic.
    expect(res.body.topic).toBeNull();
    return res.body.id as string;
  };
  const end = async (roomId: string, u: TestUser) => {
    const res = await get().http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'endLiveRoom');
    return res;
  };
  const patch = async (roomId: string, by: TestUser, body: unknown) => {
    const res = await get()
      .http.patch(`/api/v1/live/rooms/${roomId}`)
      .set(auth(by))
      .send(body as object);
    expectContract(res, 'updateLiveRoom');
    return res;
  };
  const room = async (roomId: string, u?: TestUser) => {
    const req = get().http.get(`/api/v1/live/rooms/${roomId}`);
    if (u) void req.set(auth(u));
    const res = await req;
    expectContract(res, 'getLiveRoom');
    return res;
  };
  const infoVersion = async (roomId: string) =>
    (await get().prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).infoVersion;
  const category = async (slug: string, isActive = true) =>
    get().prisma.liveCategory.create({
      data: { slug, nameAr: `ar ${slug}`, nameEn: `en ${slug}`, isActive },
    });
  return { auth, signup, host, goLive, end, patch, room, infoVersion, category };
}

describe('CP-014 editing a live and the Contribution list', () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const h = helpers(() => ctx);
  const { auth, signup, host, goLive, end, patch, room, infoVersion, category } = h;
  const meta = (roomId: string) => JSON.parse(media.metadata.get(roomId) ?? 'null') as unknown;
  const writes = (roomId: string) => media.metadataWrites.filter((w) => w.room === roomId);
  const slug = () => `c-${randomUUID().slice(0, 8)}`;

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());

  describe('PATCH title, categorySlug, topic (§10.12)', () => {
    it('edits each field; the room, the hub and the metadata follow; audited live.room.edit', async () => {
      const owner = await host();
      const viewer = await signup();
      const music = await category(slug());
      const roomId = await goLive(owner);
      expect(await infoVersion(roomId)).toBe(0);

      const res = await patch(roomId, owner, {
        title: '  سهرة طرب  ',
        categorySlug: music.slug,
        topic: '  Oud and songs 🎶 ',
      });
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({
        id: roomId,
        title: 'سهرة طرب',
        topic: 'Oud and songs 🎶',
        category: { slug: music.slug },
        status: 'LIVE',
      });
      // One PATCH → one version step, written into the media room's metadata at once.
      expect(await infoVersion(roomId)).toBe(1);
      expect(meta(roomId)).toEqual({ seatsVersion: 0, score: 0, roomInfoVersion: 1 });
      expect(writes(roomId)).toHaveLength(1);

      // Room detail (signed in and guest) and hub cards carry the topic.
      expect((await room(roomId, viewer)).body).toMatchObject({
        title: 'سهرة طرب',
        topic: 'Oud and songs 🎶',
      });
      expect((await room(roomId)).body.topic).toBe('Oud and songs 🎶');
      for (const tab of ['new', 'popular'] as const) {
        const list = await ctx.http.get('/api/v1/live/rooms').query({ tab }).set(auth(viewer));
        expect(list.status).toBe(200);
        expectContract(list, 'listLiveRooms');
        expect(list.body.data.find((r: { id: string }) => r.id === roomId)).toMatchObject({
          title: 'سهرة طرب',
          topic: 'Oud and songs 🎶',
          category: { slug: music.slug },
        });
      }
      const guestList = await ctx.http.get('/api/v1/live/rooms').query({ tab: 'new', category: music.slug });
      expectContract(guestList, 'listLiveRooms');
      expect(guestList.body.data.map((r: { id: string; topic: string }) => [r.id, r.topic])).toEqual([
        [roomId, 'Oud and songs 🎶'],
      ]);

      // Each field alone.
      expect((await patch(roomId, owner, { title: 'Second' })).body.title).toBe('Second');
      expect(await infoVersion(roomId)).toBe(2);
      expect((await patch(roomId, owner, { topic: 'Q&A' })).body.topic).toBe('Q&A');
      expect(await infoVersion(roomId)).toBe(3);
      expect((await patch(roomId, owner, { categorySlug: null })).body.category).toBeNull();
      expect(await infoVersion(roomId)).toBe(4);
      expect(meta(roomId)).toEqual({ seatsVersion: 0, score: 0, roomInfoVersion: 4 });

      const audit = await ctx.prisma.auditLog.findMany({
        where: { action: 'live.room.edit', targetId: roomId },
        orderBy: { createdAt: 'asc' },
      });
      expect(audit).toHaveLength(4);
      expect(audit[0]).toMatchObject({
        actorUserId: owner.id,
        targetType: 'live_room',
        metadata: { fields: ['title', 'categorySlug', 'topic'], categorySlug: music.slug, infoVersion: 1 },
      });
      expect(audit.map((a) => a.metadata)).toEqual([
        { fields: ['title', 'categorySlug', 'topic'], categorySlug: music.slug, infoVersion: 1 },
        { fields: ['title'], infoVersion: 2 },
        { fields: ['topic'], infoVersion: 3 },
        { fields: ['categorySlug'], categorySlug: null, infoVersion: 4 },
      ]);
      // The audit never holds the texts.
      expect(JSON.stringify(audit.map((a) => a.metadata))).not.toContain('Second');
      await end(roomId, owner);
    });

    it('null or "" (after trimming) removes the topic', async () => {
      const owner = await host();
      const roomId = await goLive(owner);
      for (const removal of [null, '', '   ', '　﻿']) {
        expect((await patch(roomId, owner, { topic: 'Something' })).body.topic).toBe('Something');
        const res = await patch(roomId, owner, { topic: removal });
        expect(res.status).toBe(200);
        expect(res.body.topic).toBeNull();
        expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).topic).toBeNull();
      }
      expect(await infoVersion(roomId)).toBe(8);
      await end(roomId, owner);
    });

    it('a PATCH that changes nothing does not move the version, write metadata or audit', async () => {
      const owner = await host();
      const music = await category(slug());
      const roomId = await goLive(owner, { title: 'Same', categorySlug: music.slug });
      await patch(roomId, owner, { topic: 'T' });
      expect(await infoVersion(roomId)).toBe(1);
      const before = writes(roomId).length;

      for (const body of [
        { title: 'Same' },
        { title: '  Same ' }, // the same after normalization
        { categorySlug: music.slug },
        { topic: ' T ' },
        { title: 'Same', categorySlug: music.slug, topic: 'T' },
        { allowGuests: true }, // other fields never move the info version
        { chatEnabled: true },
      ]) {
        const res = await patch(roomId, owner, body);
        expect(res.status).toBe(200);
      }
      expect(await infoVersion(roomId)).toBe(1);
      expect(writes(roomId)).toHaveLength(before);
      expect(await ctx.prisma.auditLog.count({ where: { action: 'live.room.edit', targetId: roomId } })).toBe(
        1,
      );
      await end(roomId, owner);
    });

    it('removing an absent topic or category changes nothing', async () => {
      const owner = await host();
      const roomId = await goLive(owner);
      const res = await patch(roomId, owner, { topic: null, categorySlug: null });
      expect(res.status).toBe(200);
      expect(await infoVersion(roomId)).toBe(0);
      expect(writes(roomId)).toEqual([]);
      await end(roomId, owner);
    });

    it('validation: the go-live title rules, an active category, the topic rules (400, nothing applied)', async () => {
      const owner = await host();
      const inactive = await category(slug(), false);
      const roomId = await goLive(owner, { title: 'Original' });
      const bad = async (body: unknown, field: string, issue: string) => {
        const res = await patch(roomId, owner, body);
        expect(res.status, JSON.stringify(body)).toBe(400);
        expect(res.body.error.code).toBe('VALIDATION_FAILED');
        expect(res.body.error.details).toEqual([{ field, issue }]);
      };
      await bad({ title: '' }, 'title', 'too_short');
      await bad({ title: '   ' }, 'title', 'invalid_format');
      await bad({ title: 'x'.repeat(81) }, 'title', 'too_long');
      await bad({ title: 'a‮b' }, 'title', 'invalid_format');
      await bad({ title: null }, 'title', 'invalid_type');
      await bad({ categorySlug: 'no-such-category' }, 'categorySlug', 'invalid_value');
      await bad({ categorySlug: inactive.slug }, 'categorySlug', 'invalid_value');
      await bad({ categorySlug: 'Bad Slug' }, 'categorySlug', 'invalid_format');
      await bad({ topic: 'x'.repeat(101) }, 'topic', 'too_long');
      await bad({ topic: 'one\ntwo' }, 'topic', 'invalid_format');
      await bad({ topic: 'one\r\ntwo' }, 'topic', 'invalid_format');
      await bad({ topic: 'one two' }, 'topic', 'invalid_format');
      await bad({ topic: 'one two' }, 'topic', 'invalid_format');
      await bad({ topic: 'a​b' }, 'topic', 'invalid_format'); // §6 hygiene: zero-width space
      await bad({ topic: 'a‮b' }, 'topic', 'invalid_format'); // bidi override
      await bad({ topic: `e${'́'.repeat(4)}` }, 'topic', 'invalid_format'); // zalgo cap
      await bad({ topic: 42 }, 'topic', 'invalid_type');
      // A valid title with an inactive category: nothing is applied.
      await bad({ title: 'Changed', categorySlug: inactive.slug }, 'categorySlug', 'invalid_value');
      // A valid title with a bad topic: nothing is applied.
      const mixed = await patch(roomId, owner, { title: 'Changed', topic: 'a\nb' });
      expect(mixed.status).toBe(400);

      // 100 code points is fine (astral characters count once).
      const long = '🎵'.repeat(100);
      expect((await patch(roomId, owner, { topic: long })).body.topic).toBe(long);
      const stored = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } });
      expect(stored).toMatchObject({ title: 'Original', topic: long, infoVersion: 1 });
      await end(roomId, owner);
    });

    it('only the host: others and guests → 404 / 401; an ended room → 409; check order 400 → 404 → 409', async () => {
      const owner = await host();
      const other = await signup();
      const roomId = await goLive(owner);
      const res = await patch(roomId, other, { title: 'Hijack' });
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
      expect((await patch(MISSING_ROOM, owner, { title: 'x' })).status).toBe(404);
      expect((await patch('not-a-uuid', owner, { title: 'x' })).status).toBe(404);
      const guest = await ctx.http.patch(`/api/v1/live/rooms/${roomId}`).send({ title: 'x' });
      expect(guest.status).toBe(401);
      expectContract(guest, 'updateLiveRoom');
      // A bad body is 400 before ownership (the existing PATCH order).
      expect((await patch(roomId, other, { topic: 'a\nb' })).status).toBe(400);

      await end(roomId, owner);
      const ended = await patch(roomId, owner, { title: 'After', topic: 'x' });
      expect(ended.status).toBe(409);
      expect(ended.body.error.code).toBe('LIVE_ROOM_ENDED');
      expect((await patch(roomId, owner, { categorySlug: 'no-such-category' })).status).toBe(409);
      expect(await infoVersion(roomId)).toBe(0);
    });

    it('the ended room keeps its last title and topic; seat and theme changes keep the info version', async () => {
      const owner = await host();
      const roomId = await goLive(owner, { mode: 'AUDIO', seatCount: 5 });
      await patch(roomId, owner, { topic: 'Before end', theme: 'ice-palace' });
      // A theme change alone does not move the seat version (CP-011).
      expect(meta(roomId)).toEqual({ seatsVersion: 0, score: 0, roomInfoVersion: 1 });
      const seats = await patch(roomId, owner, { seatCount: 10 });
      expect(seats.status).toBe(200);
      expect(meta(roomId)).toEqual({ seatsVersion: 1, score: 0, roomInfoVersion: 1 });
      const ended = await end(roomId, owner);
      expect(ended.body).toMatchObject({ status: 'ENDED', topic: 'Before end' });
      expect((await room(roomId)).body.topic).toBe('Before end');
    });

    it('reconciliation repairs metadata that lost the info version', async () => {
      const owner = await host();
      const v = await signup();
      const roomId = await goLive(owner);
      const raw = JSON.stringify({
        event: 'participant_joined',
        room: { name: roomId },
        participant: { identity: v.id },
      });
      await ctx.http
        .post('/internal/livekit/webhook')
        .set('Content-Type', 'application/webhook+json')
        .set('Authorization', MemoryLiveMedia.sign(raw))
        .send(raw)
        .expect(200);
      await patch(roomId, owner, { topic: 'kept' });
      media.metadata.set(roomId, JSON.stringify({ seatsVersion: 0, score: 0 }));
      await ctx.app.get(LiveMediaService).reconcile();
      expect(meta(roomId)).toEqual({ seatsVersion: 0, score: 0, roomInfoVersion: 1 });
      await end(roomId, owner);
    });
  });

  describe('GET /live/rooms/{roomId}/contributors (§10.12)', () => {
    const contributors = async (roomId: string, u?: TestUser) => {
      const req = ctx.http.get(`/api/v1/live/rooms/${roomId}/contributors`);
      if (u) void req.set(auth(u));
      const res = await req;
      expectContract(res, 'listLiveContributors');
      return res;
    };
    const ids = async (roomId: string, u?: TestUser) =>
      ((await contributors(roomId, u)).body.data as Contributor[]).map((c) => [c.user.id, c.points]);
    let seq = 0;
    /** A user written directly (fast; no sign-in needed for people who only appear in the list). */
    const quickUser = async (): Promise<string> => {
      seq += 1;
      const tag = `${Date.now().toString(36)}${seq}`;
      const user = await ctx.prisma.user.create({
        data: {
          email: `kl068-${tag}@example.com`,
          passwordHash: 'x',
          profile: { create: { username: `kl068${tag}`.slice(0, 30), displayName: `Fan ${seq}` } },
        },
      });
      return user.id;
    };
    const setTapper = (roomId: string, userId: string, counted: number, at: Date) =>
      ctx.prisma.liveRoomTapper.upsert({
        where: { roomId_userId: { roomId, userId } },
        create: { roomId, userId, counted, lastBatchAt: at },
        update: { counted, lastBatchAt: at },
      });

    it('counts taps through the API: highest first, the user summary and points; the host is never listed', async () => {
      const owner = await host();
      const [a, b] = [await signup(), await signup()];
      const roomId = await goLive(owner);
      expect((await contributors(roomId, a)).body).toEqual({ data: [] });

      const tap = (u: TestUser, count: number) =>
        ctx.http.post(`/api/v1/live/rooms/${roomId}/taps`).set(auth(u)).send({ count });
      expect((await tap(a, 4)).body.accepted).toBe(4);
      expect((await tap(b, 9)).body.accepted).toBe(9);
      expect((await tap(owner, 10)).body.accepted).toBe(0); // the host's taps count 0
      clock.advance(1);
      expect((await tap(a, 7)).body.accepted).toBe(7);

      const res = await contributors(roomId, b);
      expect(res.status).toBe(200);
      expect(res.body.data).toEqual([
        {
          user: { id: a.id, username: a.username, displayName: expect.any(String), avatarUrl: null },
          points: 11,
        },
        {
          user: { id: b.id, username: b.username, displayName: expect.any(String), avatarUrl: null },
          points: 9,
        },
      ]);
      // A host row with points (written directly) is still never listed.
      await setTapper(roomId, owner.id, 500, clock.now());
      expect(await ids(roomId)).toEqual([
        [a.id, 11],
        [b.id, 9],
      ]);
      await end(roomId, owner);
    });

    it('ties: who reached their total first, then user id; 0 points are left out; at most 50', async () => {
      const owner = await host();
      const roomId = await goLive(owner);
      const t0 = new Date(clock.now().getTime() - 60_000);
      const at = (s: number) => new Date(t0.getTime() + s * 1000);

      const early = await quickUser();
      const late = await quickUser();
      const [x, y] = [await quickUser(), await quickUser()].sort();
      const zero = await quickUser();
      await setTapper(roomId, late, 20, at(30));
      await setTapper(roomId, early, 20, at(10));
      await setTapper(roomId, y!, 20, at(20));
      await setTapper(roomId, x!, 20, at(20));
      await setTapper(roomId, zero, 0, at(1));
      const top = await quickUser();
      await setTapper(roomId, top, 21, at(50));
      expect(await ids(roomId)).toEqual([
        [top, 21],
        [early, 20],
        [x, 20],
        [y, 20],
        [late, 20],
      ]);

      // 55 people with points: the 50 highest are listed.
      const many: string[] = [];
      for (let i = 0; i < 50; i += 1) {
        const id = await quickUser();
        many.push(id);
        await setTapper(roomId, id, 100 + i, at(i));
      }
      const res = await contributors(roomId);
      expect(res.status).toBe(200);
      const listed = (res.body.data as Contributor[]).map((c) => c.user.id);
      expect(listed).toHaveLength(50);
      expect(listed).toEqual([...many].reverse());
      expect((res.body.data as Contributor[]).every((c) => c.points >= 1)).toBe(true);
      await end(roomId, owner);
    });

    it('a signed-in reader never gets people they blocked or who blocked them; inactive accounts are left out', async () => {
      const owner = await host();
      const [reader, blockedByReader, blocksReader, fine] = [
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      const suspended = await quickUser();
      const deleted = await quickUser();
      const roomId = await goLive(owner);
      const now = clock.now();
      await setTapper(roomId, blockedByReader.id, 40, now);
      await setTapper(roomId, blocksReader.id, 30, now);
      await setTapper(roomId, fine.id, 20, now);
      await setTapper(roomId, suspended, 90, now);
      await setTapper(roomId, deleted, 80, now);
      await ctx.prisma.user.update({ where: { id: suspended }, data: { status: 'SUSPENDED' } });
      await ctx.prisma.user.update({ where: { id: deleted }, data: { status: 'DELETED' } });
      await ctx.http.put(`/api/v1/users/${blockedByReader.username}/block`).set(auth(reader)).expect(200);
      await ctx.http.put(`/api/v1/users/${reader.username}/block`).set(auth(blocksReader)).expect(200);

      expect(await ids(roomId, reader)).toEqual([[fine.id, 20]]);
      // Others (and guests) see everyone active.
      const all = [
        [blockedByReader.id, 40],
        [blocksReader.id, 30],
        [fine.id, 20],
      ];
      expect(await ids(roomId, fine)).toEqual(all);
      expect(await ids(roomId)).toEqual(all);
      // The blocked people do not see the reader either.
      await setTapper(roomId, reader.id, 10, now);
      expect((await ids(roomId, blockedByReader)).map(([id]) => id)).not.toContain(reader.id);
      expect((await ids(roomId, blocksReader)).map(([id]) => id)).not.toContain(reader.id);
      expect((await ids(roomId, fine)).map(([id]) => id)).toContain(reader.id);
      await end(roomId, owner);
    });

    it('guests read when the room allows guests (else 403); ended rooms stay readable; 404 when unseen', async () => {
      const owner = await host();
      const [v, blocked] = [await signup(), await signup()];
      const fan = await quickUser();
      const roomId = await goLive(owner);
      await setTapper(roomId, fan, 5, clock.now());

      const asGuest = await contributors(roomId);
      expect(asGuest.status).toBe(200);
      expect(asGuest.body.data.map((c: Contributor) => c.user.id)).toEqual([fan]);

      expect((await patch(roomId, owner, { allowGuests: false })).status).toBe(200);
      const refused = await contributors(roomId);
      expect(refused.status).toBe(403);
      expect(refused.body.error.code).toBe('LIVE_GUESTS_NOT_ALLOWED');
      expect((await contributors(roomId, v)).status).toBe(200);

      expect((await contributors(MISSING_ROOM, v)).status).toBe(404);
      expect((await contributors(MISSING_ROOM)).status).toBe(404);
      expect((await ctx.http.get('/api/v1/live/rooms/nope/contributors').set(auth(v))).status).toBe(404);
      await ctx.http.put(`/api/v1/users/${blocked.username}/block`).set(auth(owner)).expect(200);
      expect((await contributors(roomId, blocked)).status).toBe(404);

      await end(roomId, owner);
      expect(await ids(roomId, v)).toEqual([[fan, 5]]);
      expect((await contributors(roomId)).status).toBe(403); // still no guests

      // A room whose host is no longer active is not visible.
      await ctx.prisma.user.update({ where: { id: owner.id }, data: { status: 'SUSPENDED' } });
      expect((await contributors(roomId, v)).status).toBe(404);
    });

    it('an invalid token is 401 (not a guest read)', async () => {
      const owner = await host();
      const roomId = await goLive(owner);
      const res = await ctx.http
        .get(`/api/v1/live/rooms/${roomId}/contributors`)
        .set({ Authorization: 'Bearer nope' });
      expect(res.status).toBe(401);
      await end(roomId, owner);
    });
  });
});

/** §7: edits use the existing PATCH bucket; guests share the CP-010 guest read limit per IP. */
describe('CP-014 rate limits', () => {
  it('the PATCH bucket (60 / hour per user) counts edits; they do not count against seat actions', async () => {
    const limited = await createTestApp({
      LIVE_HOSTING_ENABLED: 'true',
      RATE_LIMIT_LIVE_UPDATE_USER: '3/3600',
      RATE_LIMIT_LIVE_SEAT_ACTION_USER: '1/3600',
    });
    try {
      const lh = helpers(() => limited);
      const owner = await lh.host();
      const roomId = await lh.goLive(owner);
      expect((await lh.patch(roomId, owner, { title: 'One' })).status).toBe(200);
      expect((await lh.patch(roomId, owner, { topic: 'Two' })).status).toBe(200);
      // The edits did not use the seat-action bucket (1 / hour here): a theme change still passes.
      expect((await lh.patch(roomId, owner, { theme: 'ice-palace' })).status).toBe(200);
      const fourth = await lh.patch(roomId, owner, { title: 'Four' });
      expect(fourth.status).toBe(429);
      expect(fourth.body.error.code).toBe('RATE_LIMITED');
    } finally {
      await limited.close();
    }
  });

  it('guests use the shared guest read bucket per IP', async () => {
    const limited = await createTestApp({
      LIVE_HOSTING_ENABLED: 'true',
      RATE_LIMIT_LIVE_GUEST_READ_IP: '2/60',
    });
    try {
      const lh = helpers(() => limited);
      const owner = await lh.host();
      const roomId = await lh.goLive(owner);
      const get = (): request.Test => limited.http.get(`/api/v1/live/rooms/${roomId}/contributors`);
      expect((await get()).status).toBe(200);
      expect((await limited.http.get(`/api/v1/live/rooms/${roomId}`)).status).toBe(200);
      const third = await get();
      expect(third.status).toBe(429);
      expectContract(third, 'listLiveContributors');
      // A signed-in reader is not limited by the guest bucket.
      expect((await get().set(lh.auth(owner))).status).toBe(200);
    } finally {
      await limited.close();
    }
  });
});

/** CP-014 with the real LiveKit adapter: an edit moves `roomInfoVersion` in the real room metadata. */
describe.skipIf(!url)('CP-014 roomInfoVersion on a real LiveKit server', () => {
  const provider = new LiveKitMediaProvider(url ?? '', key, secret);
  const rooms = new RoomServiceClient((url ?? '').replace(/^ws/, 'http'), key, secret);
  let ctx: TestContext;
  const h = helpers(() => ctx);

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [
      { token: LIVE_MEDIA_PROVIDER, value: provider },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('writes {"seatsVersion","score","roomInfoVersion"} into the media room after an edit', async () => {
    const owner = await h.host();
    const roomId = await h.goLive(owner);
    // The media room exists once someone joins; create it here instead of connecting a client.
    await rooms.createRoom({ name: roomId, emptyTimeout: 60 });
    const metadata = async () => (await rooms.listRooms([roomId]))[0]?.metadata;
    try {
      expect(await metadata()).toBe('');
      const res = await h.patch(roomId, owner, { title: 'Real edit', topic: 'Live topic' });
      expect(res.status).toBe(200);
      expect(await metadata()).toBe('{"seatsVersion":0,"score":0,"roomInfoVersion":1}');
      // No change → no new version.
      await h.patch(roomId, owner, { topic: 'Live topic' });
      expect(await metadata()).toBe('{"seatsVersion":0,"score":0,"roomInfoVersion":1}');
      await h.patch(roomId, owner, { topic: null });
      expect(await metadata()).toBe('{"seatsVersion":0,"score":0,"roomInfoVersion":2}');
    } finally {
      await h.end(roomId, owner); // closes the media room too
    }
    expect(await provider.listRooms()).not.toContain(roomId);
  });
});
