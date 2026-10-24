/**
 * KL-037: contract v1.3 — live discovery, host lifecycle, public profile and follow
 * (CONVENTIONS §10, openapi v1.3, DB_PHASE2_DISCOVERY.md), end to end against PostgreSQL + Redis
 * with the API running as the DML-only runtime role.
 *
 * Time: the live module reads "now" from the injectable Clock. These tests replace it with a
 * FakeClock and move it forward instead of sleeping through the 45 s stale window.
 * Every response of a v1.3 operation is checked against openapi.yaml (`expectContract`).
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LiveRoomsService } from '../src/modules/live/live-rooms.service.js';
import { AccountLifecycleService } from '../src/modules/users/profiles/account-lifecycle.service.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += seconds * 1000;
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

const STALE_SECONDS = 45;
const MISSING_ROOM = '0192f1d0-0000-7000-8000-000000000000';
const ISO_Z = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

async function signup(ctx: TestContext, overrides: Partial<Record<string, unknown>> = {}): Promise<TestUser> {
  const { res } = await registerVerified(ctx, overrides);
  expect(res.status).toBe(201);
  // CP-010 (D93): going live needs the hosting permission. These v1.3 suites are about hosting,
  // so every account they create may host; kl063-live-video covers the refusal without it.
  await ctx.prisma.liveHost.create({ data: { userId: res.body.user.id as string, source: 'ADMIN' } });
  return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
}

function bearer(user: TestUser): { Authorization: string } {
  return { Authorization: `Bearer ${user.token}` };
}

/** Error body without the per-request id (for "identical body" comparisons). */
function errorShape(res: { status: number; body: { error?: Record<string, unknown> } }) {
  const { requestId: _ignored, ...rest } = res.body.error ?? {};
  return { status: res.status, ...rest };
}

function expectError(
  res: { status: number; body: { error?: { code?: string } } },
  status: number,
  code: string,
) {
  expect({ status: res.status, code: res.body.error?.code }).toEqual({ status, code });
}

async function createCategory(
  ctx: TestContext,
  slug: string,
  extra: { sortOrder?: number; isActive?: boolean; nameAr?: string; nameEn?: string } = {},
): Promise<string> {
  const row = await ctx.prisma.liveCategory.create({
    data: {
      slug,
      nameAr: extra.nameAr ?? `فئة ${slug}`,
      nameEn: extra.nameEn ?? `Category ${slug}`,
      sortOrder: extra.sortOrder ?? 0,
      isActive: extra.isActive ?? true,
    },
  });
  return row.id;
}

function liveApp(overrides: Record<string, string> = {}) {
  const clock = new FakeClock();
  return {
    clock,
    create: () =>
      createTestApp(
        { LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: String(STALE_SECONDS), ...overrides },
        [{ token: Clock, value: clock }],
      ),
  };
}

describe('KL-037 contract coverage', () => {
  it('openapi v1.3 declares exactly the ten new operations implemented here', () => {
    const v13 = operations()
      .filter((o) => /^\/api\/v1\/(live\/|users\/\{username\})/.test(o.path))
      // v1.4-levels (draft) adds /users/{username}/levels; KL-058 covers it.
      .filter((o) => o.path !== '/api/v1/users/{username}/levels')
      // v1.5-social (draft) adds posts, reposts, block and mute under /users/{username}; KL-060
      // covers them.
      .filter((o) => !/^\/api\/v1\/users\/\{username\}\/(posts|reposts|block|mute)$/.test(o.path))
      // CP-008 adds /users/{username}/stories; kl061-stories covers it.
      .filter((o) => o.path !== '/api/v1/users/{username}/stories')
      // CP-010 (v1.6-live draft) adds live video operations under /live/; kl063-live-video
      // covers them with its own exact list. CP-012 (v1.8-live draft) adds tapLiveRoom;
      // kl065-live-taps covers it. CP-011 (v1.7-live draft) adds the seat operations;
      // kl064-live-seats covers them with its own exact list.
      .filter(
        (o) =>
          !['createLiveMediaToken', 'updateLiveRoom', 'listLiveRoomViewers', 'tapLiveRoom'].includes(
            o.operationId,
          ),
      )
      .filter(
        (o) =>
          // CP-013 (v1.9-live draft) adds the chat operations; kl067-live-chat covers them.
          // CP-014 (v1.10-live draft) adds listLiveContributors; kl068-live-room-edit covers it.
          !/^\/api\/v1\/live\/rooms\/\{roomId\}\/(seats|seat-requests|seat-invites|moderators|chat|contributors)(\/|$)/.test(
            o.path,
          ),
      )
      .map((o) => o.operationId)
      .sort();
    expect(v13).toEqual(
      [
        'getLiveConfig',
        'listLiveCategories',
        'listLiveRooms',
        'startLiveRoom',
        'getLiveRoom',
        'heartbeatLiveRoom',
        'endLiveRoom',
        'getPublicProfile',
        'followUser',
        'unfollowUser',
      ].sort(),
    );
  });
});

describe('KL-037 live discovery and host lifecycle (hosting enabled)', () => {
  const { clock, create } = liveApp();
  let ctx: TestContext;
  let rooms: LiveRoomsService;

  beforeAll(async () => {
    ctx = await create();
    rooms = ctx.app.get(LiveRoomsService);
    // supertest binds the server once per request; the race tests run a dozen at once.
    ctx.app.getHttpServer().setMaxListeners(64);
  });

  afterAll(async () => {
    await ctx?.close();
  });

  const startRoom = (user: TestUser, body: unknown, lang?: string) => {
    const req = ctx.http.post('/api/v1/live/rooms').set(bearer(user));
    if (lang) void req.set('Accept-Language', lang);
    return req.send(body as object);
  };
  const heartbeat = (user: TestUser, roomId: string) =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/heartbeat`).set(bearer(user)).send();
  const end = (user: TestUser, roomId: string) =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(bearer(user)).send();
  const getRoom = (user: TestUser, roomId: string) =>
    ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(bearer(user));
  const list = (user: TestUser, query: Record<string, string | number>) =>
    ctx.http.get('/api/v1/live/rooms').query(query).set(bearer(user));

  /** Goes live and returns the room id (expects 201). */
  async function goLive(user: TestUser, title = 'Live now', categorySlug?: string): Promise<string> {
    const res = await startRoom(user, { title, ...(categorySlug ? { categorySlug } : {}) });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  }

  /** Every page of a tab (limit `limit`), checking each page against the contract. */
  async function allPages(user: TestUser, query: Record<string, string | number>, limit: number) {
    const ids: string[] = [];
    let cursor: string | null = null;
    let pages = 0;
    do {
      const res = await list(user, { ...query, limit, ...(cursor ? { cursor } : {}) });
      expectContract(res, 'listLiveRooms');
      expect(res.status).toBe(200);
      expect(res.body.data.length).toBeLessThanOrEqual(limit);
      ids.push(...res.body.data.map((r: { id: string }) => r.id));
      cursor = res.body.page.nextCursor;
      expect(res.body.page.hasMore).toBe(cursor !== null);
      pages += 1;
      expect(pages).toBeLessThan(50);
    } while (cursor);
    return { ids, pages };
  }

  async function endEverything(): Promise<void> {
    await ctx.prisma.$executeRawUnsafe(
      `UPDATE live_rooms SET status = 'ENDED', end_reason = 'HOST_ENDED', ended_at = last_heartbeat_at WHERE status = 'LIVE'`,
    );
  }

  beforeEach(async () => {
    await endEverything();
  });

  describe('GET /live/config and /live/categories', () => {
    it('returns the server-driven switch and timings', async () => {
      const user = await signup(ctx);
      const res = await ctx.http.get('/api/v1/live/config').set(bearer(user));
      expectContract(res, 'getLiveConfig');
      expect(res.body).toEqual({
        hostingEnabled: true,
        heartbeatIntervalSeconds: 15,
        heartbeatStaleAfterSeconds: 45,
        // CP-011 (v1.7-live): room themes and seat counts per mode.
        themes: ['classic', 'ice-palace', 'desert-night', 'rose-garden'],
        seatCounts: { MULTI: [4, 6, 9, 12], AUDIO: [5, 9, 13] },
      });
    });

    it('lists active categories by sortOrder then slug, localized; empty when none exist', async () => {
      const en = await signup(ctx, { locale: 'en' });
      const ar = await signup(ctx, { locale: 'ar' });
      const empty = await ctx.http.get('/api/v1/live/categories').set(bearer(en));
      expectContract(empty, 'listLiveCategories');
      expect(empty.body).toEqual({ data: [] });

      await createCategory(ctx, 'zeta', { sortOrder: 1, nameAr: 'زيتا', nameEn: 'Zeta' });
      await createCategory(ctx, 'beta', { sortOrder: 2, nameAr: 'بيتا', nameEn: 'Beta' });
      await createCategory(ctx, 'alpha', { sortOrder: 2, nameAr: 'ألفا', nameEn: 'Alpha' });
      await createCategory(ctx, 'hidden', { sortOrder: 0, isActive: false });

      const byHeader = await ctx.http
        .get('/api/v1/live/categories')
        .set(bearer(ar))
        .set('Accept-Language', 'en-US');
      expectContract(byHeader, 'listLiveCategories');
      expect(byHeader.body.data).toEqual([
        { slug: 'zeta', name: 'Zeta' },
        { slug: 'alpha', name: 'Alpha' },
        { slug: 'beta', name: 'Beta' },
      ]);
      const arabic = await ctx.http
        .get('/api/v1/live/categories')
        .set(bearer(en))
        .set('Accept-Language', 'ar');
      expect(arabic.body.data.map((c: { name: string }) => c.name)).toEqual(['زيتا', 'ألفا', 'بيتا']);
      // Not ar/en → the caller's stored locale.
      const storedEn = await ctx.http
        .get('/api/v1/live/categories')
        .set(bearer(en))
        .set('Accept-Language', 'fr');
      expect(storedEn.body.data[0]).toEqual({ slug: 'zeta', name: 'Zeta' });
      const storedAr = await ctx.http.get('/api/v1/live/categories').set(bearer(ar));
      expect(storedAr.body.data[0]).toEqual({ slug: 'zeta', name: 'زيتا' });
      await ctx.prisma.liveCategory.deleteMany({});
    });
  });

  describe('POST /live/rooms (go live)', () => {
    it('creates a SOLO room (201) with the documented shape and audits live.room.start', async () => {
      await createCategory(ctx, 'music', { nameAr: 'موسيقى', nameEn: 'Music' });
      const host = await signup(ctx, { locale: 'en', displayName: 'ليلى' });
      const res = await startRoom(host, { title: '  سهرة طرب  ', categorySlug: 'music' }, 'ar');
      expectContract(res, 'startLiveRoom');
      expect(res.status).toBe(201);
      expect(res.body).toEqual({
        id: expect.any(String),
        title: 'سهرة طرب',
        mode: 'SOLO',
        viewerCount: 0,
        startedAt: clock.now().toISOString(),
        coverUrl: null,
        category: { slug: 'music', name: 'موسيقى' },
        host: { id: host.id, username: host.username, displayName: 'ليلى', avatarUrl: null },
        status: 'LIVE',
        endedAt: null,
        endReason: null,
        // CP-010: guests may watch unless the host says otherwise (default true).
        allowGuests: true,
        // CP-011 (v1.7-live): a SOLO room has no seats; the default theme.
        seatCount: null,
        occupiedSeats: 0,
        theme: 'classic',
        // CP-012 (v1.8-live): a new live starts at 0 points.
        score: 0,
        scoreParts: { total: 0, tapPoints: 0, supportPoints: 0 },
        // CP-013 (v1.9-live): a new live starts with the chat on; the host is never muted.
        chatEnabled: true,
        chatMuted: false,
        // CP-014 (v1.10-live): a new live starts without a topic.
        topic: null,
      });
      const audit = await ctx.prisma.auditLog.findMany({
        where: { action: 'live.room.start', targetId: res.body.id },
      });
      expect(audit).toHaveLength(1);
      expect(audit[0]).toMatchObject({ actorUserId: host.id, targetType: 'live_room' });
      await ctx.prisma.liveRoom.deleteMany({});
      await ctx.prisma.liveCategory.deleteMany({});
    });

    it('validates the body (400) with field details', async () => {
      await createCategory(ctx, 'inactive-cat', { isActive: false });
      const host = await signup(ctx);
      const cases: [unknown, { field: string; issue: string }[]][] = [
        [{}, [{ field: 'title', issue: 'required' }]],
        [{ title: '' }, [{ field: 'title', issue: 'too_short' }]],
        [{ title: '   ' }, [{ field: 'title', issue: 'invalid_format' }]],
        [{ title: 'x'.repeat(81) }, [{ field: 'title', issue: 'too_long' }]],
        [{ title: 'line\nbreak' }, [{ field: 'title', issue: 'invalid_format' }]],
        [{ title: '...' }, [{ field: 'title', issue: 'invalid_format' }]],
        [{ title: 42 }, [{ field: 'title', issue: 'invalid_type' }]],
        // CP-011 (v1.7-live) made `mode` a field (SOLO, MULTI, AUDIO); PK cannot be started.
        [{ title: 'ok', mode: 'PK' }, [{ field: 'mode', issue: 'invalid_value' }]],
        [{ title: 'ok', foo: 1 }, [{ field: 'foo', issue: 'unknown_field' }]],
        [{ title: 'ok', categorySlug: 'Bad Slug' }, [{ field: 'categorySlug', issue: 'invalid_format' }]],
        [{ title: 'ok', categorySlug: 'unknown-cat' }, [{ field: 'categorySlug', issue: 'invalid_value' }]],
        [{ title: 'ok', categorySlug: 'inactive-cat' }, [{ field: 'categorySlug', issue: 'invalid_value' }]],
        [[], [{ field: '', issue: 'invalid_type' }]],
      ];
      for (const [body, details] of cases) {
        const res = await startRoom(host, body);
        expectContract(res, 'startLiveRoom');
        expect({ body, status: res.status, details: res.body.error?.details }).toEqual({
          body,
          status: 400,
          details,
        });
      }
      // Reserved terms and mixed scripts are fine in a title (content, not identity).
      const ok = await startRoom(host, { title: 'Kabso support Q&A' });
      expect(ok.status).toBe(201);
      expect(await ctx.prisma.liveRoom.count({ where: { hostUserId: host.id } })).toBe(1);
    });

    it('refuses a second go-live while the room is fresh (409), but replaces a stale one', async () => {
      const host = await signup(ctx);
      const first = await goLive(host, 'First');
      const again = await startRoom(host, { title: 'Second' });
      expectContract(again, 'startLiveRoom');
      expectError(again, 409, 'LIVE_ROOM_ALREADY_ACTIVE');

      const startedAt = clock.now();
      clock.advance(STALE_SECONDS + 1);
      const second = await goLive(host, 'Second');
      expect(second).not.toBe(first);
      const old = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: first } });
      expect(old).toMatchObject({ status: 'ENDED', endReason: 'HEARTBEAT_TIMEOUT', endedAt: startedAt });
      expect(
        await ctx.prisma.auditLog.count({ where: { action: 'live.room.timeout', targetId: first } }),
      ).toBe(1);
    });

    it('requires a verified email (403 AUTH_FORBIDDEN for legacy unverified accounts)', async () => {
      const host = await signup(ctx);
      await ctx.prisma.user.update({ where: { id: host.id }, data: { emailVerifiedAt: null } });
      const res = await startRoom(host, { title: 'Hello' });
      expectContract(res, 'startLiveRoom');
      expectError(res, 403, 'AUTH_FORBIDDEN');
    });

    it('parallel go-live: exactly one 201, the rest 409, one LIVE row (also when a stale room exists)', async () => {
      for (const withStale of [false, true]) {
        const host = await signup(ctx);
        if (withStale) {
          await goLive(host, 'Old');
          clock.advance(STALE_SECONDS + 1);
        }
        const results = await Promise.all(
          Array.from({ length: 12 }, (_, i) => startRoom(host, { title: `Race ${i}` })),
        );
        const statuses = results.map((r) => r.status).sort();
        expect(statuses.filter((s) => s === 201)).toHaveLength(1);
        expect(statuses.filter((s) => s === 409)).toHaveLength(11);
        for (const r of results) expectContract(r, 'startLiveRoom');
        expect(await ctx.prisma.liveRoom.count({ where: { hostUserId: host.id, status: 'LIVE' } })).toBe(1);
        if (withStale) {
          expect(
            await ctx.prisma.auditLog.count({
              where: { action: 'live.room.timeout', metadata: { path: ['hostUserId'], equals: host.id } },
            }),
          ).toBe(1);
        }
      }
    });
  });

  describe('heartbeat', () => {
    it('keeps a room fresh (204); never revives a stale room (409, ended as HEARTBEAT_TIMEOUT)', async () => {
      const host = await signup(ctx);
      const viewer = await signup(ctx);
      const roomId = await goLive(host);
      clock.advance(STALE_SECONDS - 1);
      const hb = await heartbeat(host, roomId);
      expectContract(hb, 'heartbeatLiveRoom');
      expect(hb.status).toBe(204);
      const beatAt = clock.now();
      clock.advance(STALE_SECONDS - 1);
      expect((await list(viewer, { tab: 'new' })).body.data.map((r: { id: string }) => r.id)).toContain(
        roomId,
      );

      clock.advance(2); // now 46 s after the last beat
      const late = await heartbeat(host, roomId);
      expectContract(late, 'heartbeatLiveRoom');
      expectError(late, 409, 'LIVE_ROOM_ENDED');
      const room = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } });
      expect(room).toMatchObject({ status: 'ENDED', endReason: 'HEARTBEAT_TIMEOUT', endedAt: beatAt });
      // Still 409 afterwards (already ENDED).
      expectError(await heartbeat(host, roomId), 409, 'LIVE_ROOM_ENDED');
    });

    it('answers 404 for non-hosts, malformed and unknown ids (never 403); 409 for an ended room', async () => {
      const host = await signup(ctx);
      const other = await signup(ctx);
      const roomId = await goLive(host);
      const notHost = await heartbeat(other, roomId);
      expectContract(notHost, 'heartbeatLiveRoom');
      const malformed = await heartbeat(host, 'not-a-uuid');
      const unknown = await heartbeat(host, MISSING_ROOM);
      for (const res of [notHost, malformed, unknown]) {
        expectContract(res, 'heartbeatLiveRoom');
        expect(errorShape(res)).toEqual({ status: 404, code: 'NOT_FOUND', message: 'Resource not found.' });
      }
      expect((await end(host, roomId)).status).toBe(200);
      const ended = await heartbeat(host, roomId);
      expectError(ended, 409, 'LIVE_ROOM_ENDED');
      // A non-host still gets 404 for the ended room.
      expectError(await heartbeat(other, roomId), 404, 'NOT_FOUND');
    });
  });

  describe('end', () => {
    it('ends with HOST_ENDED (200), is idempotent and keeps the original reason and time', async () => {
      const host = await signup(ctx);
      const roomId = await goLive(host);
      clock.advance(10);
      const endedAt = clock.now().toISOString();
      const res = await end(host, roomId);
      expectContract(res, 'endLiveRoom');
      expect(res.body).toMatchObject({ id: roomId, status: 'ENDED', endReason: 'HOST_ENDED', endedAt });
      clock.advance(10);
      const again = await end(host, roomId);
      expectContract(again, 'endLiveRoom');
      expect(again.body).toEqual(res.body);
      const audits = await ctx.prisma.auditLog.findMany({
        where: { action: 'live.room.end', targetId: roomId },
      });
      expect(audits).toHaveLength(1);
      expect(audits[0]!.metadata).toEqual({ reason: 'HOST_ENDED' });
    });

    it('a stale room is reported as timed out, not host-ended', async () => {
      const host = await signup(ctx);
      const roomId = await goLive(host);
      const lastBeat = clock.now().toISOString();
      clock.advance(STALE_SECONDS + 5);
      const res = await end(host, roomId);
      expectContract(res, 'endLiveRoom');
      expect(res.body).toMatchObject({ status: 'ENDED', endReason: 'HEARTBEAT_TIMEOUT', endedAt: lastBeat });
    });

    it('404 for non-hosts, malformed and unknown ids', async () => {
      const host = await signup(ctx);
      const other = await signup(ctx);
      const roomId = await goLive(host);
      for (const res of [await end(other, roomId), await end(host, 'nope'), await end(host, MISSING_ROOM)]) {
        expectContract(res, 'endLiveRoom');
        expectError(res, 404, 'NOT_FOUND');
      }
      expect((await getRoom(other, roomId)).body.status).toBe('LIVE');
    });

    it('concurrent end, sweep and heartbeat: exactly one end wins and is audited once', async () => {
      const host = await signup(ctx);
      const roomId = await goLive(host);
      clock.advance(STALE_SECONDS + 1);
      const results = await Promise.all([
        ...Array.from({ length: 5 }, () => end(host, roomId)),
        rooms.sweepStale(),
        rooms.sweepStale(),
        heartbeat(host, roomId),
      ]);
      const endBodies = results.slice(0, 5).map((r) => (r as { body: unknown }).body);
      for (const body of endBodies) expect(body).toEqual(endBodies[0]);
      expect(endBodies[0]).toMatchObject({ status: 'ENDED', endReason: 'HEARTBEAT_TIMEOUT' });
      const audits = await ctx.prisma.auditLog.count({
        where: { targetId: roomId, action: { in: ['live.room.end', 'live.room.timeout'] } },
      });
      expect(audits).toBe(1);
    });
  });

  describe('GET /live/rooms/{roomId}', () => {
    it('returns LIVE and ENDED rooms; a stale LIVE room is returned (and stored) as ENDED', async () => {
      const host = await signup(ctx);
      const viewer = await signup(ctx);
      const roomId = await goLive(host);
      const live = await getRoom(viewer, roomId);
      expectContract(live, 'getLiveRoom');
      expect(live.body).toMatchObject({ id: roomId, status: 'LIVE', endedAt: null, endReason: null });

      const lastBeat = clock.now().toISOString();
      clock.advance(STALE_SECONDS + 1);
      const stale = await getRoom(viewer, roomId);
      expectContract(stale, 'getLiveRoom');
      expect(stale.body).toMatchObject({
        status: 'ENDED',
        endReason: 'HEARTBEAT_TIMEOUT',
        endedAt: lastBeat,
      });
      expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).status).toBe('ENDED');
    });

    it('same 404 for unknown, malformed and non-ACTIVE-host rooms', async () => {
      const host = await signup(ctx);
      const viewer = await signup(ctx);
      const roomId = await goLive(host);
      await ctx.prisma.user.update({ where: { id: host.id }, data: { status: 'SUSPENDED' } });
      const responses = [
        await getRoom(viewer, MISSING_ROOM),
        await getRoom(viewer, 'malformed'),
        await getRoom(viewer, roomId),
      ];
      for (const res of responses) expectContract(res, 'getLiveRoom');
      expect(new Set(responses.map((r) => JSON.stringify(errorShape(r)))).size).toBe(1);
      expect(errorShape(responses[0]!)).toEqual({
        status: 404,
        code: 'NOT_FOUND',
        message: 'Resource not found.',
      });
    });
  });

  describe('GET /live/rooms (lists)', () => {
    it('empty list shape', async () => {
      const viewer = await signup(ctx);
      for (const tab of ['popular', 'new', 'following']) {
        const res = await list(viewer, { tab });
        expectContract(res, 'listLiveRooms');
        expect(res.body).toEqual({ data: [], page: { nextCursor: null, hasMore: false } });
      }
    });

    it('paginates every tab across pages with ties (same startedAt) without duplicates or gaps', async () => {
      const viewer = await signup(ctx);
      const hosts: TestUser[] = [];
      for (let i = 0; i < 9; i += 1) hosts.push(await signup(ctx));
      // Three groups of three rooms with identical startedAt (ties broken by id desc).
      const created: { id: string; startedAt: number }[] = [];
      for (let g = 0; g < 3; g += 1) {
        for (let i = 0; i < 3; i += 1) {
          const id = await goLive(hosts[g * 3 + i]!, `Room ${g}-${i}`);
          created.push({ id, startedAt: clock.now().getTime() });
        }
        clock.advance(1);
      }
      // Keep all fresh at the final clock position.
      for (const [i, host] of hosts.entries())
        expect((await heartbeat(host, created[i]!.id)).status).toBe(204);
      for (const host of hosts.slice(0, 6)) {
        expect((await ctx.http.put(`/api/v1/users/${host.username}/follow`).set(bearer(viewer))).status).toBe(
          200,
        );
      }
      const byNew = [...created]
        .sort((a, b) => b.startedAt - a.startedAt || (a.id < b.id ? 1 : -1))
        .map((r) => r.id);

      for (const limit of [1, 2, 4, 50]) {
        const newTab = await allPages(viewer, { tab: 'new' }, limit);
        expect(newTab.ids).toEqual(byNew);
        expect(newTab.pages).toBe(Math.max(1, Math.ceil(9 / limit)));
        // popular ≡ new while every score is 0 (CP-012, §10.4).
        expect((await allPages(viewer, { tab: 'popular' }, limit)).ids).toEqual(byNew);
        const followed = new Set(created.slice(0, 6).map((r) => r.id));
        expect((await allPages(viewer, { tab: 'following' }, limit)).ids).toEqual(
          byNew.filter((id) => followed.has(id)),
        );
      }

      // CP-012 (v1.8-live): popular orders by score first (fixture written directly; kl065 covers
      // scores reached by tapping). The viewer count no longer orders it.
      await ctx.prisma.liveRoom.update({ where: { id: created[0]!.id }, data: { score: BigInt(5) } });
      await ctx.prisma.liveRoom.update({ where: { id: created[4]!.id }, data: { score: BigInt(5) } });
      await ctx.prisma.liveRoom.update({ where: { id: created[8]!.id }, data: { score: BigInt(2) } });
      await ctx.prisma.liveRoom.update({ where: { id: created[1]!.id }, data: { viewerCount: 50 } });
      const top = [created[4]!, created[0]!].sort(
        (a, b) => b.startedAt - a.startedAt || (a.id < b.id ? 1 : -1),
      );
      const expectedPopular = [
        ...top.map((r) => r.id),
        created[8]!.id,
        ...byNew.filter((id) => ![created[0]!.id, created[4]!.id, created[8]!.id].includes(id)),
      ];
      for (const limit of [1, 2, 3, 50]) {
        expect((await allPages(viewer, { tab: 'popular' }, limit)).ids).toEqual(expectedPopular);
      }
      const page = await list(viewer, { tab: 'popular', limit: 1 });
      expect(page.body.data[0]).toMatchObject({
        score: 5,
        viewerCount: 0,
        mode: 'SOLO',
        coverUrl: null,
        category: null,
      });
      expect(page.body.data[0].startedAt).toMatch(ISO_Z);
      await ctx.prisma.liveRoom.updateMany({ data: { viewerCount: 0, score: BigInt(0) } });
    });

    it('filters every tab by category; unknown/inactive slug → 200 empty; malformed → 400', async () => {
      await createCategory(ctx, 'music', { nameEn: 'Music' });
      await createCategory(ctx, 'retired', { isActive: false });
      const viewer = await signup(ctx, { locale: 'en' });
      const a = await signup(ctx);
      const b = await signup(ctx);
      const c = await signup(ctx);
      const musicA = await goLive(a, 'A', 'music');
      clock.advance(1);
      const plainB = await goLive(b, 'B');
      clock.advance(1);
      const musicC = await goLive(c, 'C', 'music');
      await ctx.http.put(`/api/v1/users/${a.username}/follow`).set(bearer(viewer));
      await ctx.http.put(`/api/v1/users/${b.username}/follow`).set(bearer(viewer));

      expect((await allPages(viewer, { tab: 'new', category: 'music' }, 1)).ids).toEqual([musicC, musicA]);
      expect((await allPages(viewer, { tab: 'popular', category: 'music' }, 5)).ids).toEqual([
        musicC,
        musicA,
      ]);
      expect((await allPages(viewer, { tab: 'following', category: 'music' }, 5)).ids).toEqual([musicA]);
      expect((await allPages(viewer, { tab: 'following' }, 5)).ids).toEqual([plainB, musicA]);
      const withCategory = await list(viewer, { tab: 'new', category: 'music' });
      expect(withCategory.body.data[0].category).toEqual({ slug: 'music', name: 'Music' });

      for (const category of ['unknown-slug', 'retired']) {
        const res = await list(viewer, { tab: 'new', category });
        expectContract(res, 'listLiveRooms');
        expect(res.body).toEqual({ data: [], page: { nextCursor: null, hasMore: false } });
      }
      const bad = await list(viewer, { tab: 'new', category: 'Not Valid' });
      expectContract(bad, 'listLiveRooms');
      expect(bad.status).toBe(400);
      expect(bad.body.error.details).toEqual([{ field: 'category', issue: 'invalid_format' }]);
      await ctx.prisma.liveRoom.deleteMany({});
      await ctx.prisma.liveCategory.deleteMany({});
    });

    // v1.3.1 (SEC-035): the list filters stale rooms and writes nothing; the sweeper ends them.
    it('lists only fresh LIVE rooms of ACTIVE hosts and does not end the stale ones it skips', async () => {
      const viewer = await signup(ctx);
      const fresh = await signup(ctx);
      const stale = await signup(ctx);
      const suspended = await signup(ctx);
      const staleRoom = await goLive(stale);
      clock.advance(30);
      const freshRoom = await goLive(fresh);
      const suspendedRoom = await goLive(suspended);
      await ctx.prisma.user.update({ where: { id: suspended.id }, data: { status: 'SUSPENDED' } });
      clock.advance(20); // staleRoom: 50 s without a beat; the others: 20 s
      const res = await list(viewer, { tab: 'new' });
      expectContract(res, 'listLiveRooms');
      expect(res.body.data.map((r: { id: string }) => r.id)).toEqual([freshRoom]);
      expect(await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: staleRoom } })).toMatchObject({
        status: 'LIVE',
        endReason: null,
      });
      expect(await ctx.prisma.auditLog.count({ where: { targetId: staleRoom } })).toBe(1); // start only
      expect(await rooms.sweepStale()).toBe(1);
      expect(await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: staleRoom } })).toMatchObject({
        status: 'ENDED',
        endReason: 'HEARTBEAT_TIMEOUT',
      });
      // The suspended host's room is hidden (ACTIVE filter) but not rewritten by the list.
      expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: suspendedRoom } })).status).toBe(
        'LIVE',
      );
    });

    it('rejects invalid, tampered and mismatched cursors with 400 cursor/invalid_value', async () => {
      const viewer = await signup(ctx);
      const other = await signup(ctx);
      await createCategory(ctx, 'music');
      for (let i = 0; i < 3; i += 1) {
        const host = await signup(ctx);
        await goLive(host, `R${i}`, 'music');
        await ctx.http.put(`/api/v1/users/${host.username}/follow`).set(bearer(viewer));
      }
      const page = async (query: Record<string, string | number>) =>
        (await list(viewer, { ...query, limit: 1 })).body.page.nextCursor as string;
      const newCursor = await page({ tab: 'new' });
      const musicCursor = await page({ tab: 'new', category: 'music' });
      const followingCursor = await page({ tab: 'following' });
      expect(newCursor && musicCursor && followingCursor).toBeTruthy();

      const [payload, tag] = newCursor.split('.');
      const decoded = JSON.parse(Buffer.from(payload!, 'base64url').toString()) as Record<string, unknown>;
      const tampered = `${Buffer.from(JSON.stringify({ ...decoded, n: 1000 })).toString('base64url')}.${tag}`;

      const cases: [TestUser, Record<string, string>][] = [
        [viewer, { tab: 'new', cursor: 'garbage' }],
        [viewer, { tab: 'new', cursor: tampered }],
        [viewer, { tab: 'popular', cursor: newCursor }],
        [viewer, { tab: 'new', category: 'music', cursor: newCursor }],
        [viewer, { tab: 'new', cursor: musicCursor }],
        [viewer, { tab: 'new', category: 'other', cursor: musicCursor }],
        [other, { tab: 'following', cursor: followingCursor }],
        [viewer, { tab: 'new', cursor: followingCursor }],
      ];
      for (const [user, query] of cases) {
        const res = await list(user, query);
        expectContract(res, 'listLiveRooms');
        expect({ query, status: res.status, details: res.body.error?.details }).toEqual({
          query,
          status: 400,
          details: [{ field: 'cursor', issue: 'invalid_value' }],
        });
      }
      // The same cursors are accepted for the scope they were issued for (public tabs: any caller).
      expect((await list(other, { tab: 'new', cursor: newCursor })).status).toBe(200);
      expect((await list(viewer, { tab: 'following', cursor: followingCursor })).status).toBe(200);
      await ctx.prisma.liveRoom.deleteMany({});
      await ctx.prisma.liveCategory.deleteMany({});
    });

    it('validates tab and limit (400)', async () => {
      const viewer = await signup(ctx);
      const cases: [Record<string, string | number>, { field: string; issue: string }[]][] = [
        [{}, [{ field: 'tab', issue: 'required' }]],
        [{ tab: 'trending' }, [{ field: 'tab', issue: 'invalid_value' }]],
        [{ tab: 'new', limit: 0 }, [{ field: 'limit', issue: 'too_small' }]],
        [{ tab: 'new', limit: 51 }, [{ field: 'limit', issue: 'too_big' }]],
        [{ tab: 'new', limit: 'x' }, [{ field: 'limit', issue: 'invalid_format' }]],
      ];
      for (const [query, details] of cases) {
        const res = await list(viewer, query);
        expectContract(res, 'listLiveRooms');
        expect({ query, status: res.status, details: res.body.error?.details }).toEqual({
          query,
          status: 400,
          details,
        });
      }
    });
  });

  describe('sweeper and suspension', () => {
    it('the sweeper ends every stale room once (parallel sweeps) with endedAt = last heartbeat', async () => {
      const hosts = [await signup(ctx), await signup(ctx), await signup(ctx)];
      const roomIds: string[] = [];
      for (const host of hosts) roomIds.push(await goLive(host));
      const lastBeat = clock.now();
      clock.advance(STALE_SECONDS - 1);
      expect(await rooms.sweepStale()).toBe(0); // 44 s: still fresh
      // At exactly 45 s the heartbeat is no longer fresh (fresh = lastHeartbeatAt > now − 45 s).
      clock.advance(1);
      const counts = await Promise.all([rooms.sweepStale(), rooms.sweepStale(), rooms.sweepStale()]);
      expect(counts.reduce((a, b) => a + b, 0)).toBe(3);
      for (const id of roomIds) {
        expect(await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id } })).toMatchObject({
          status: 'ENDED',
          endReason: 'HEARTBEAT_TIMEOUT',
          endedAt: lastBeat,
        });
        expect(
          await ctx.prisma.auditLog.count({ where: { action: 'live.room.timeout', targetId: id } }),
        ).toBe(1);
      }
    });

    it('suspension ends the LIVE room with HOST_SUSPENDED and keeps follow rows', async () => {
      const host = await signup(ctx);
      const fan = await signup(ctx);
      await ctx.http.put(`/api/v1/users/${host.username}/follow`).set(bearer(fan));
      const roomId = await goLive(host);
      expect(await ctx.app.get(AccountLifecycleService).suspend(host.id)).toBe(true);
      expect(await ctx.app.get(AccountLifecycleService).suspend(host.id)).toBe(false);
      expect(await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).toMatchObject({
        status: 'ENDED',
        endReason: 'HOST_SUSPENDED',
      });
      const audit = await ctx.prisma.auditLog.findMany({
        where: { action: 'live.room.end', targetId: roomId },
      });
      expect(audit.map((a) => a.metadata)).toEqual([{ reason: 'HOST_SUSPENDED', hostUserId: host.id }]);
      expect(await ctx.prisma.follow.count({ where: { followeeId: host.id } })).toBe(1);
      // The suspended host's token no longer works.
      expectError(await heartbeat(host, roomId), 401, 'AUTH_UNAUTHENTICATED');
    });
  });
});

describe('KL-037 public profile and follow', () => {
  const { clock, create } = liveApp();
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await create();
    ctx.app.getHttpServer().setMaxListeners(64);
  });

  afterAll(async () => {
    await ctx?.close();
  });

  const profile = (viewer: TestUser, username: string) =>
    ctx.http.get(`/api/v1/users/${encodeURIComponent(username)}`).set(bearer(viewer));
  const follow = (viewer: TestUser, username: string) =>
    ctx.http.put(`/api/v1/users/${encodeURIComponent(username)}/follow`).set(bearer(viewer));
  const unfollow = (viewer: TestUser, username: string) =>
    ctx.http.delete(`/api/v1/users/${encodeURIComponent(username)}/follow`).set(bearer(viewer));

  it('returns the documented public fields only (never email, role, status, locale, createdAt)', async () => {
    const viewer = await signup(ctx);
    const target = await signup(ctx, { displayName: 'ليلى' });
    const res = await profile(viewer, target.username);
    expectContract(res, 'getPublicProfile');
    expect(res.body).toEqual({
      id: target.id,
      username: target.username,
      displayName: 'ليلى',
      avatarUrl: null,
      bio: null,
      isPrivate: false,
      followerCount: 0,
      followingCount: 0,
      isFollowing: false,
      // CP-007: the caller's own mute state.
      isMuted: false,
      isSelf: false,
      liveRoomId: null,
    });
    const self = await profile(target, target.username);
    expectContract(self, 'getPublicProfile');
    expect(self.body).toMatchObject({ isSelf: true, isFollowing: false, isMuted: false });
    expect(JSON.stringify(res.body)).not.toMatch(/@|email|ACTIVE|USER|createdAt|locale/);
  });

  it('liveRoomId is the fresh LIVE room only; a stale one is ended on read', async () => {
    const host = await signup(ctx);
    const viewer = await signup(ctx);
    const created = await ctx.http.post('/api/v1/live/rooms').set(bearer(host)).send({ title: 'Hi' });
    expect(created.status).toBe(201);
    expect((await profile(viewer, host.username)).body.liveRoomId).toBe(created.body.id);
    // The host resumes via its own profile after a lost go-live response (§10.3).
    expect((await profile(host, host.username)).body.liveRoomId).toBe(created.body.id);
    clock.advance(STALE_SECONDS + 1);
    const res = await profile(viewer, host.username);
    expectContract(res, 'getPublicProfile');
    expect(res.body.liveRoomId).toBeNull();
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: created.body.id } })).endReason).toBe(
      'HEARTBEAT_TIMEOUT',
    );
  });

  it('identical 404 for unknown, malformed, pending-only, SUSPENDED and DELETED usernames', async () => {
    const viewer = await signup(ctx);
    const suspended = await signup(ctx);
    const deleted = await signup(ctx);
    await ctx.prisma.user.update({ where: { id: suspended.id }, data: { status: 'SUSPENDED' } });
    expect(await ctx.app.get(AccountLifecycleService).softDelete(deleted.id)).toBe(true);
    const pendingName = `pend${Date.now().toString(36)}`;
    const reg = await ctx.http.post('/api/v1/auth/register').send({
      email: `${pendingName}@example.com`,
      password: 'correct horse battery staple',
      username: pendingName,
      displayName: 'Pending',
    });
    expect(reg.status).toBe(202);

    const names = [
      'nobody_here',
      'Bad Name!',
      'a',
      'x'.repeat(64),
      '..',
      'admin',
      pendingName,
      suspended.username,
      deleted.username,
      'username-availability-x',
    ];
    const bodies = new Set<string>();
    for (const name of names) {
      const res = await profile(viewer, name);
      expectContract(res, 'getPublicProfile');
      expect({ name, status: res.status }).toEqual({ name, status: 404 });
      bodies.add(JSON.stringify(errorShape(res)));
    }
    expect([...bodies]).toEqual([
      JSON.stringify({ status: 404, code: 'NOT_FOUND', message: 'Resource not found.' }),
    ]);
    // The static availability route is not shadowed by GET /users/{username}.
    const availability = await ctx.http
      .get('/api/v1/users/username-availability')
      .query({ username: 'freename1' });
    expect(availability.status).toBe(200);
  });

  it('follow / unfollow are idempotent and report the target follower count', async () => {
    const fan = await signup(ctx);
    const fan2 = await signup(ctx);
    const star = await signup(ctx);
    const first = await follow(fan, star.username);
    expectContract(first, 'followUser');
    expect(first.body).toEqual({ isFollowing: true, followerCount: 1 });
    const repeat = await follow(fan, star.username);
    expectContract(repeat, 'followUser');
    expect(repeat.body).toEqual({ isFollowing: true, followerCount: 1 });
    expect((await follow(fan2, star.username)).body).toEqual({ isFollowing: true, followerCount: 2 });
    expect(await ctx.prisma.follow.count({ where: { followeeId: star.id } })).toBe(2);

    const viewed = await profile(fan, star.username);
    expect(viewed.body).toMatchObject({ followerCount: 2, followingCount: 0, isFollowing: true });
    expect((await profile(star, fan.username)).body).toMatchObject({ followingCount: 1, isFollowing: false });

    const off = await unfollow(fan, star.username);
    expectContract(off, 'unfollowUser');
    expect(off.body).toEqual({ isFollowing: false, followerCount: 1 });
    const offAgain = await unfollow(fan, star.username);
    expectContract(offAgain, 'unfollowUser');
    expect(offAgain.body).toEqual({ isFollowing: false, followerCount: 1 });
    expect((await profile(fan, star.username)).body.isFollowing).toBe(false);
  });

  it('parallel follows of the same target create one edge', async () => {
    const fan = await signup(ctx);
    const star = await signup(ctx);
    const results = await Promise.all(Array.from({ length: 8 }, () => follow(fan, star.username)));
    for (const res of results) expect(res.body).toEqual({ isFollowing: true, followerCount: 1 });
    expect(await ctx.prisma.follow.count({ where: { followeeId: star.id } })).toBe(1);
  });

  it('self → 400 username/invalid_value; private target → 403 on PUT, unfollow allowed', async () => {
    const fan = await signup(ctx);
    const priv = await signup(ctx);
    const self = await follow(fan, fan.username);
    expectContract(self, 'followUser');
    expect(self.status).toBe(400);
    expect(self.body.error).toMatchObject({
      code: 'VALIDATION_FAILED',
      details: [{ field: 'username', issue: 'invalid_value' }],
    });
    const selfDelete = await unfollow(fan, fan.username);
    expectContract(selfDelete, 'unfollowUser');
    expect(selfDelete.body.error.details).toEqual([{ field: 'username', issue: 'invalid_value' }]);

    expect((await follow(fan, priv.username)).status).toBe(200); // existing follower before going private
    await ctx.prisma.userSettings.update({ where: { userId: priv.id }, data: { isPrivate: true } });
    const newFan = await signup(ctx);
    const forbidden = await follow(newFan, priv.username);
    expectContract(forbidden, 'followUser');
    expectError(forbidden, 403, 'AUTH_FORBIDDEN');
    expect((await profile(newFan, priv.username)).body).toMatchObject({ isPrivate: true, followerCount: 1 });
    const leave = await unfollow(fan, priv.username);
    expectContract(leave, 'unfollowUser');
    expect(leave.body).toEqual({ isFollowing: false, followerCount: 0 });
  });

  it('404 for unknown, malformed, suspended and deleted targets', async () => {
    const fan = await signup(ctx);
    const suspended = await signup(ctx);
    const deleted = await signup(ctx);
    await ctx.prisma.user.update({ where: { id: suspended.id }, data: { status: 'SUSPENDED' } });
    await ctx.prisma.user.update({ where: { id: deleted.id }, data: { status: 'DELETED' } });
    for (const name of ['nobody_here', 'Bad Name!', suspended.username, deleted.username]) {
      for (const [op, res] of [
        ['followUser', await follow(fan, name)],
        ['unfollowUser', await unfollow(fan, name)],
      ] as const) {
        expectContract(res, op);
        expect({ name, op, ...errorShape(res) }).toEqual({
          name,
          op,
          status: 404,
          code: 'NOT_FOUND',
          message: 'Resource not found.',
        });
      }
    }
  });

  it('soft delete removes follow rows in both directions; suspension keeps them', async () => {
    const a = await signup(ctx);
    const b = await signup(ctx);
    const c = await signup(ctx);
    await follow(a, b.username);
    await follow(b, a.username);
    await follow(c, b.username);
    await follow(b, c.username);
    expect(await ctx.app.get(AccountLifecycleService).softDelete(b.id)).toBe(true);
    expect(await ctx.app.get(AccountLifecycleService).softDelete(b.id)).toBe(false);
    expect(
      await ctx.prisma.follow.count({ where: { OR: [{ followerId: b.id }, { followeeId: b.id }] } }),
    ).toBe(0);
    expect((await profile(a, a.username)).body).toMatchObject({ followerCount: 0, followingCount: 0 });
    expect(await ctx.prisma.user.findUniqueOrThrow({ where: { id: b.id } })).toMatchObject({
      status: 'DELETED',
    });
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: b.id } })).deletedAt).not.toBeNull();

    await follow(a, c.username);
    expect(await ctx.app.get(AccountLifecycleService).suspend(c.id)).toBe(true);
    expect(await ctx.prisma.follow.count({ where: { followeeId: c.id } })).toBe(1);
  });

  it('the database refuses a self-follow (CHECK backstop)', async () => {
    const a = await signup(ctx);
    await expect(ctx.prisma.follow.create({ data: { followerId: a.id, followeeId: a.id } })).rejects.toThrow(
      /follows_no_self_follow|check constraint/i,
    );
  });
});

describe('KL-037 hosting disabled (LIVE_HOSTING_ENABLED=false)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'false', RATE_LIMIT_LIVE_START_HOUR_USER: '2/3600' });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('go-live and heartbeat → 503 LIVE_HOSTING_UNAVAILABLE without Retry-After; end still works', async () => {
    const host = await signup(ctx);
    const config = await ctx.http.get('/api/v1/live/config').set(bearer(host));
    expect(config.body.hostingEnabled).toBe(false);

    const start = await ctx.http.post('/api/v1/live/rooms').set(bearer(host)).send({ title: 'Hi' });
    expectContract(start, 'startLiveRoom');
    expectError(start, 503, 'LIVE_HOSTING_UNAVAILABLE');
    expect(start.headers['retry-after']).toBeUndefined();
    // The switch is checked before the body.
    expectError(
      await ctx.http.post('/api/v1/live/rooms').set(bearer(host)).send({ nope: 1 }),
      503,
      'LIVE_HOSTING_UNAVAILABLE',
    );

    // A room left over from when hosting was on (fixture).
    const room = await ctx.prisma.liveRoom.create({ data: { hostUserId: host.id, title: 'Old' } });
    const hb = await ctx.http.post(`/api/v1/live/rooms/${room.id}/heartbeat`).set(bearer(host)).send();
    expectContract(hb, 'heartbeatLiveRoom');
    expectError(hb, 503, 'LIVE_HOSTING_UNAVAILABLE');
    expect(hb.headers['retry-after']).toBeUndefined();

    const ended = await ctx.http.post(`/api/v1/live/rooms/${room.id}/end`).set(bearer(host)).send();
    expectContract(ended, 'endLiveRoom');
    expect(ended.body).toMatchObject({ status: 'ENDED', endReason: 'HOST_ENDED' });
    // The 3rd go-live attempt in the hour is rate limited: counted before the switch.
    const limited = await ctx.http.post('/api/v1/live/rooms').set(bearer(host)).send({ title: 'Hi' });
    expectContract(limited, 'startLiveRoom');
    expectError(limited, 429, 'RATE_LIMITED');
    expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
  });
});

describe('KL-037 rate limits (CONVENTIONS §7)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({
      LIVE_HOSTING_ENABLED: 'true',
      RATE_LIMIT_AUTHENTICATED_USER: '4/900',
      RATE_LIMIT_LIVE_LIST_USER: '6/900',
      RATE_LIMIT_PROFILE_USER: '5/900',
      RATE_LIMIT_LIVE_HEARTBEAT_USER: '2/60',
      RATE_LIMIT_LIVE_END_USER: '2/3600',
      RATE_LIMIT_LIVE_START_DAY_USER: '2/86400',
      RATE_LIMIT_FOLLOW_HOUR_USER: '3/3600',
    });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('the list bucket replaces the default bucket and returns 429 with Retry-After when exhausted', async () => {
    const user = await signup(ctx);
    for (let i = 0; i < 6; i += 1) {
      expect((await ctx.http.get('/api/v1/live/rooms').query({ tab: 'new' }).set(bearer(user))).status).toBe(
        200,
      );
    }
    const limited = await ctx.http.get('/api/v1/live/rooms').query({ tab: 'new' }).set(bearer(user));
    expectContract(limited, 'listLiveRooms');
    expectError(limited, 429, 'RATE_LIMITED');
    expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
    // The default bucket (4) was not consumed by the six list calls.
    expect((await ctx.http.get('/api/v1/live/config').set(bearer(user))).status).toBe(200);
  });

  it('profile, heartbeat, end and the go-live day bucket have their own limits', async () => {
    const user = await signup(ctx);
    const target = await signup(ctx);
    for (let i = 0; i < 5; i += 1) {
      expect((await ctx.http.get(`/api/v1/users/${target.username}`).set(bearer(user))).status).toBe(200);
    }
    const profile = await ctx.http.get(`/api/v1/users/${target.username}`).set(bearer(user));
    expectContract(profile, 'getPublicProfile');
    expectError(profile, 429, 'RATE_LIMITED');

    const host = await signup(ctx);
    const room = await ctx.http.post('/api/v1/live/rooms').set(bearer(host)).send({ title: 'One' });
    expect(room.status).toBe(201);
    for (let i = 0; i < 2; i += 1) {
      expect(
        (await ctx.http.post(`/api/v1/live/rooms/${room.body.id}/heartbeat`).set(bearer(host))).status,
      ).toBe(204);
    }
    const hb = await ctx.http.post(`/api/v1/live/rooms/${room.body.id}/heartbeat`).set(bearer(host));
    expectContract(hb, 'heartbeatLiveRoom');
    expectError(hb, 429, 'RATE_LIMITED');
    for (let i = 0; i < 2; i += 1) {
      expect((await ctx.http.post(`/api/v1/live/rooms/${room.body.id}/end`).set(bearer(host))).status).toBe(
        200,
      );
    }
    const endLimited = await ctx.http.post(`/api/v1/live/rooms/${room.body.id}/end`).set(bearer(host));
    expectContract(endLimited, 'endLiveRoom');
    expectError(endLimited, 429, 'RATE_LIMITED');
    expect((await ctx.http.post('/api/v1/live/rooms').set(bearer(host)).send({ title: 'Two' })).status).toBe(
      201,
    );
    const third = await ctx.http.post('/api/v1/live/rooms').set(bearer(host)).send({ title: 'Three' });
    expectError(third, 429, 'RATE_LIMITED');
  });

  it('follow and unfollow share one bucket; no-op calls count too', async () => {
    const fan = await signup(ctx);
    const star = await signup(ctx);
    expect((await ctx.http.put(`/api/v1/users/${star.username}/follow`).set(bearer(fan))).status).toBe(200);
    expect((await ctx.http.put(`/api/v1/users/${star.username}/follow`).set(bearer(fan))).status).toBe(200);
    expect((await ctx.http.delete(`/api/v1/users/${star.username}/follow`).set(bearer(fan))).status).toBe(
      200,
    );
    const limited = await ctx.http.delete(`/api/v1/users/${star.username}/follow`).set(bearer(fan));
    expectContract(limited, 'unfollowUser');
    expectError(limited, 429, 'RATE_LIMITED');
    const put = await ctx.http.put(`/api/v1/users/${star.username}/follow`).set(bearer(fan));
    expectContract(put, 'followUser');
    expectError(put, 429, 'RATE_LIMITED');
  });
});

describe('KL-037 background sweeper', () => {
  const clock = new FakeClock();
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_SWEEP_INTERVAL_SECONDS: '1' }, [
      { token: Clock, value: clock },
    ]);
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('ends a stale room on its own schedule', async () => {
    const host = await signup(ctx);
    const res = await ctx.http.post('/api/v1/live/rooms').set(bearer(host)).send({ title: 'Sweep me' });
    expect(res.status).toBe(201);
    clock.advance(STALE_SECONDS + 1);
    const deadline = Date.now() + 5000;
    let status = 'LIVE';
    while (status === 'LIVE' && Date.now() < deadline) {
      await new Promise((r) => setTimeout(r, 100));
      status = (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: res.body.id } })).status;
    }
    expect(status).toBe('ENDED');
  });
});

describe('KL-037 authentication', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  // CP-010 (D93): guests may read the live config, the popular and new lists and a room; those
  // reads are covered in kl063-live-video. Everything else still needs a token, including the
  // following list.
  it('every v1.3 operation answers 401 AUTH_UNAUTHENTICATED without a token (except the guest reads)', async () => {
    const calls: [string, () => Promise<{ status: number; body: { error?: { code?: string } } }>][] = [
      ['listLiveCategories', () => ctx.http.get('/api/v1/live/categories')],
      ['listLiveRooms', () => ctx.http.get('/api/v1/live/rooms?tab=following')],
      ['startLiveRoom', () => ctx.http.post('/api/v1/live/rooms').send({ title: 'x' })],
      ['heartbeatLiveRoom', () => ctx.http.post(`/api/v1/live/rooms/${MISSING_ROOM}/heartbeat`)],
      ['endLiveRoom', () => ctx.http.post(`/api/v1/live/rooms/${MISSING_ROOM}/end`)],
      ['getPublicProfile', () => ctx.http.get('/api/v1/users/someone')],
      ['followUser', () => ctx.http.put('/api/v1/users/someone/follow')],
      ['unfollowUser', () => ctx.http.delete('/api/v1/users/someone/follow')],
    ];
    for (const [operationId, call] of calls) {
      const res = await call();
      expectContract(res as never, operationId);
      expect({ operationId, status: res.status, code: res.body.error?.code }).toEqual({
        operationId,
        status: 401,
        code: 'AUTH_UNAUTHENTICATED',
      });
    }
  });
});
