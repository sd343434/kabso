/**
 * KL-045: contract v1.3.1 and the KL-040 findings, end to end against PostgreSQL + Redis with the
 * API running as the DML-only runtime role.
 *
 *  - SEC-035: stale-room backlog at scale. Lists filter and write nothing; the sweeper ends rooms
 *    in bounded batches with a per-run budget, never overlapping in one instance and safe across
 *    instances.
 *  - SEC-036: text hygiene on register (displayName) and go-live (title).
 *  - SEC-037: malformed path usernames → 404, never 500.
 *  - SEC-038: signed cursors at the bounds of the sort keys never reach a database error.
 *  - QA-002: an existing follower of a private account re-PUTs follow → 200.
 *  - go-live re-checks the host's status inside its transaction.
 */
import { createHmac, hkdfSync } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { AppException } from '../src/common/errors/app-exception.js';
import { Clock } from '../src/common/time/clock.js';
import { CURSOR_MAX_STARTED_AT_MS, CURSOR_MAX_VIEWER_COUNT } from '../src/modules/live/live-cursor.js';
import { LiveRoomsService } from '../src/modules/live/live-rooms.service.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, newUser, registerVerified, type TestContext } from './helpers/test-app.js';

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

const cp = (...points: number[]) => String.fromCodePoint(...points);

async function signup(ctx: TestContext, overrides: Partial<Record<string, unknown>> = {}): Promise<TestUser> {
  const { res } = await registerVerified(ctx, overrides);
  expect(res.status, JSON.stringify(res.body)).toBe(201);
  // CP-010 (D93): going live needs the hosting permission. These v1.3 suites are about hosting,
  // so every account they create may host; kl063-live-video covers the refusal without it.
  await ctx.prisma.liveHost.create({ data: { userId: res.body.user.id as string, source: 'ADMIN' } });
  return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
}

function bearer(user: TestUser): { Authorization: string } {
  return { Authorization: `Bearer ${user.token}` };
}

function errorShape(res: { status: number; body: { error?: Record<string, unknown> } }) {
  const { requestId: _ignored, ...rest } = res.body.error ?? {};
  return { status: res.status, ...rest };
}

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)]!;
}

/** Inserts `count` ACTIVE hosts, each with one LIVE room whose last heartbeat is 1 h old. */
async function seedStaleRooms(ctx: TestContext, count: number, tag: string): Promise<void> {
  await ctx.prisma.$executeRaw`
    WITH u AS (
      INSERT INTO users (id, email, password_hash, status, email_verified_at, updated_at)
      SELECT gen_random_uuid(), ${tag} || g || '@example.test', 'x', 'ACTIVE', now(), now()
        FROM generate_series(1, ${count}::int) AS g
      RETURNING id, email
    ), p AS (
      INSERT INTO user_profiles (user_id, username, display_name, updated_at)
      SELECT id, split_part(email, '@', 1), 'Bulk host', now() FROM u
      RETURNING user_id
    )
    INSERT INTO live_rooms (id, host_user_id, title, started_at, last_heartbeat_at, updated_at)
    SELECT gen_random_uuid(), user_id, 'Stale', now() - interval '2 hours', now() - interval '1 hour', now()
      FROM p`;
}

describe('KL-045 SEC-035: stale-room backlog at scale', () => {
  const BACKLOG = 40_000;
  const BATCH = 500;
  const clock = new FakeClock();
  let ctx: TestContext;
  let other: TestContext;
  let rooms: LiveRoomsService;
  let viewer: TestUser;
  let freshRoom: string;

  beforeAll(async () => {
    // Two API instances on the same database (createTestApp resets the database, so both are
    // created before any data is written). Neither runs the background timer; the tests drive it.
    other = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_SWEEP_BATCH_SIZE: String(BATCH) }, [
      { token: Clock, value: clock },
    ]);
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_SWEEP_BATCH_SIZE: String(BATCH) }, [
      { token: Clock, value: clock },
    ]);
    rooms = ctx.app.get(LiveRoomsService);
    ctx.app.getHttpServer().setMaxListeners(32);
    viewer = await signup(ctx);
    const host = await signup(ctx);
    const res = await ctx.http.post('/api/v1/live/rooms').set(bearer(host)).send({ title: 'Fresh one' });
    expect(res.status).toBe(201);
    freshRoom = res.body.id;
    await seedStaleRooms(ctx, BACKLOG, 'bulka');
  }, 180_000);

  afterAll(async () => {
    await ctx?.close();
    await other?.close();
  });

  const liveCount = () => ctx.prisma.liveRoom.count({ where: { status: 'LIVE' } });
  const timeoutAudits = () => ctx.prisma.auditLog.count({ where: { action: 'live.room.timeout' } });

  it('lists stay fast, correct and write-free with a 40k stale backlog', async () => {
    expect(await liveCount()).toBe(BACKLOG + 1);
    const timings: number[] = [];
    for (const tab of ['popular', 'new', 'following', 'new', 'popular', 'new', 'popular', 'new']) {
      const started = performance.now();
      const res = await ctx.http.get('/api/v1/live/rooms').query({ tab }).set(bearer(viewer));
      timings.push(performance.now() - started);
      expectContract(res, 'listLiveRooms');
      expect(res.status).toBe(200);
      expect(res.body.data.map((r: { id: string }) => r.id)).toEqual(tab === 'following' ? [] : [freshRoom]);
    }
    // Parallel list calls are not serialised behind a write.
    const started = performance.now();
    const parallel = await Promise.all(
      Array.from({ length: 10 }, () =>
        ctx.http.get('/api/v1/live/rooms').query({ tab: 'new' }).set(bearer(viewer)),
      ),
    );
    const parallelMs = performance.now() - started;
    expect(parallel.map((r) => r.status)).toEqual(Array(10).fill(200));
    process.stdout.write(
      `[KL-045] list with ${BACKLOG} stale rooms: median ${median(timings).toFixed(1)} ms, ` +
        `max ${Math.max(...timings).toFixed(1)} ms; 10 parallel in ${parallelMs.toFixed(1)} ms\n`,
    );
    expect(median(timings)).toBeLessThan(500);
    expect(Math.max(...timings)).toBeLessThan(2000);
    expect(parallelMs).toBeLessThan(3000);
    // No writes: every stale room is still LIVE and nothing was audited as timed out.
    expect(await liveCount()).toBe(BACKLOG + 1);
    expect(await timeoutAudits()).toBe(0);
  }, 60_000);

  it('room detail and profile end only the one room they read', async () => {
    const stale = await ctx.prisma.liveRoom.findFirstOrThrow({
      where: { status: 'LIVE', title: 'Stale' },
      select: { id: true, lastHeartbeatAt: true, hostUserId: true },
    });
    const res = await ctx.http.get(`/api/v1/live/rooms/${stale.id}`).set(bearer(viewer));
    expectContract(res, 'getLiveRoom');
    expect(res.body).toMatchObject({
      status: 'ENDED',
      endReason: 'HEARTBEAT_TIMEOUT',
      endedAt: stale.lastHeartbeatAt.toISOString(),
    });
    expect(await liveCount()).toBe(BACKLOG); // exactly one room ended
    expect(await timeoutAudits()).toBe(1);

    const other = await ctx.prisma.liveRoom.findFirstOrThrow({
      where: { status: 'LIVE', title: 'Stale' },
      select: { hostUserId: true },
    });
    const profile = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: other.hostUserId } });
    const prof = await ctx.http.get(`/api/v1/users/${profile.username}`).set(bearer(viewer));
    expectContract(prof, 'getPublicProfile');
    expect(prof.body.liveRoomId).toBeNull();
    expect(await liveCount()).toBe(BACKLOG - 1);
    expect(await timeoutAudits()).toBe(2);
  }, 60_000);

  it('the sweeper drains the backlog in bounded batches, within a per-run budget', async () => {
    const remaining = BACKLOG - 2;
    // A run in progress in this instance blocks a second run (no overlap).
    const firstRun = rooms.runSweep({ maxBatches: 40 });
    const overlapping = await rooms.runSweep();
    expect(overlapping).toEqual({ ended: 0, batches: 0, stoppedBy: 'already_running' });
    // Lists stay fast while the sweeper works.
    const listStarted = performance.now();
    const during = await ctx.http.get('/api/v1/live/rooms').query({ tab: 'new' }).set(bearer(viewer));
    const listDuringSweepMs = performance.now() - listStarted;
    expect(during.status).toBe(200);
    expect(during.body.data.map((r: { id: string }) => r.id)).toEqual([freshRoom]);

    const sweepStarted = performance.now();
    const first = await firstRun;
    const firstMs = performance.now() - sweepStarted;
    expect(first).toEqual({ ended: 40 * BATCH, batches: 40, stoppedBy: 'batch_budget' });
    expect(await liveCount()).toBe(remaining - 40 * BATCH + 1);

    // A time budget also ends a run.
    expect(await rooms.runSweep({ budgetMs: 0 })).toEqual({ ended: 0, batches: 0, stoppedBy: 'time_budget' });

    // The next run (default budget) drains the rest; the last batch is partial.
    const secondStarted = performance.now();
    const second = await rooms.runSweep();
    const secondMs = performance.now() - secondStarted;
    expect(second.stoppedBy).toBe('drained');
    expect(second.ended).toBe(remaining - 40 * BATCH);
    expect(second.batches).toBe(Math.floor((remaining - 40 * BATCH) / BATCH) + 1);
    expect(await liveCount()).toBe(1); // only the fresh room
    expect(await rooms.runSweep()).toEqual({ ended: 0, batches: 1, stoppedBy: 'drained' });

    // Every timed-out room was ended exactly once, with endedAt = last heartbeat.
    expect(await timeoutAudits()).toBe(BACKLOG);
    const wrong = await ctx.prisma.$queryRaw<{ n: bigint }[]>`
      SELECT count(*) AS n FROM live_rooms
       WHERE title = 'Stale' AND (status <> 'ENDED' OR end_reason <> 'HEARTBEAT_TIMEOUT'
             OR ended_at IS DISTINCT FROM last_heartbeat_at)`;
    expect(Number(wrong[0]!.n)).toBe(0);
    const duplicates = await ctx.prisma.$queryRaw<{ n: bigint }[]>`
      SELECT count(*) AS n FROM (
        SELECT target_id FROM audit_logs WHERE action = 'live.room.timeout'
         GROUP BY target_id HAVING count(*) > 1) d`;
    expect(Number(duplicates[0]!.n)).toBe(0);
    process.stdout.write(
      `[KL-045] sweep of ${BACKLOG} stale rooms, batch ${BATCH}: run 1 = 40 batches / ${first.ended} rooms in ` +
        `${firstMs.toFixed(0)} ms; run 2 = ${second.batches} batches / ${second.ended} rooms in ` +
        `${secondMs.toFixed(0)} ms; list during the sweep ${listDuringSweepMs.toFixed(1)} ms\n`,
    );
  }, 180_000);

  it('two instances sweeping at once end each room exactly once', async () => {
    const BACKLOG2 = 5_000;
    await seedStaleRooms(ctx, BACKLOG2, 'bulkb');
    const auditsBefore = await timeoutAudits();
    const otherRooms = other.app.get(LiveRoomsService);
    const results = await Promise.all([rooms.runSweep(), otherRooms.runSweep()]);
    expect(results.map((r) => r.stoppedBy)).toEqual(['drained', 'drained']);
    expect(results[0].ended + results[1].ended).toBe(BACKLOG2);
    expect(await liveCount()).toBe(1);
    expect((await timeoutAudits()) - auditsBefore).toBe(BACKLOG2);
    process.stdout.write(
      `[KL-045] two instances: ${results[0].ended} + ${results[1].ended} rooms in ` +
        `${results[0].batches} + ${results[1].batches} batches\n`,
    );
  }, 120_000);
});

describe('KL-045 v1.3.1 behaviour', () => {
  const clock = new FakeClock();
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [{ token: Clock, value: clock }]);
    ctx.app.getHttpServer().setMaxListeners(32);
  });

  afterAll(async () => {
    await ctx?.close();
  });

  describe('SEC-036 text hygiene on write', () => {
    it.each([
      ['Hangul filler only', cp(0x3164)],
      ['Hangul filler inside', `Ali${cp(0x3164)}Ali`],
      ['braille blank', `Ali${cp(0x2800)}`],
      ['line separator', `Sara${cp(0x2028)}Ali`],
      ['soft hyphen', `Ka${cp(0xad)}bso`],
      ['tag characters outside an emoji', `Ali${cp(0xe0041, 0xe0042)}`],
      ['Arabic number sign', `${cp(0x600)}12`],
      ['variation selector at the start', `${cp(0xfe0f)}Ali`],
    ])('register rejects a displayName with %s (400 invalid_format)', async (_label, displayName) => {
      const res = await ctx.http.post('/api/v1/auth/register').send(newUser({ displayName }));
      expect(res.status).toBe(400);
      expect(res.body.error).toMatchObject({
        code: 'VALIDATION_FAILED',
        details: [{ field: 'displayName', issue: 'invalid_format' }],
      });
    });

    it('register accepts the contract examples (Scotland flag, U+3000, ZWNJ, IVS)', async () => {
      for (const displayName of [
        `Ali ${cp(0x1f3f4, 0xe0067, 0xe0062, 0xe0073, 0xe0063, 0xe0074, 0xe007f)}`,
        `山田${cp(0x3000)}太郎`,
        `مهر${cp(0x200c)}آرا`,
        `${cp(0x845b, 0xe0100)}城`,
        `Ali ${cp(0x2665, 0xfe0e)}`,
      ]) {
        const user = await signup(ctx, { displayName });
        const me = await ctx.http.get('/api/v1/me').set(bearer(user));
        expect(me.body.displayName).toBe(displayName);
      }
    });

    it('go-live rejects hygiene violations in the title and accepts RGI emoji', async () => {
      const host = await signup(ctx);
      for (const title of [
        `Live${cp(0x2028)}now`,
        cp(0x2800, 0x2800),
        `Quiz ${cp(0x6dd)}1`,
        `Hi${cp(0xfffc)}`,
      ]) {
        const res = await ctx.http.post('/api/v1/live/rooms').set(bearer(host)).send({ title });
        expectContract(res, 'startLiveRoom');
        expect(res.status).toBe(400);
        expect(res.body.error.details).toEqual([{ field: 'title', issue: 'invalid_format' }]);
      }
      const title = `Night ${cp(0x1f3f3, 0xfe0f, 0x200d, 0x1f308)} ${cp(0x31, 0xfe0f, 0x20e3)}`;
      const ok = await ctx.http.post('/api/v1/live/rooms').set(bearer(host)).send({ title });
      expectContract(ok, 'startLiveRoom');
      expect(ok.status).toBe(201);
      expect(ok.body.title).toBe(title);
    });
  });

  describe('SEC-037 malformed path usernames', () => {
    it('GET profile, PUT and DELETE follow answer the identical 404 (never 500)', async () => {
      const viewer = await signup(ctx);
      const names = [
        '%00',
        'abc%00',
        'a%00bc',
        `${'a'.repeat(10)}%00${'b'.repeat(10)}`,
        '%C3%A9t%C3%A9',
        'x'.repeat(300),
        'ab',
        '%E2%80%AEabc',
        'abc%20',
        'ABC',
      ];
      const bodies = new Set<string>();
      for (const name of names) {
        for (const [op, req] of [
          ['getPublicProfile', () => ctx.http.get(`/api/v1/users/${name}`)],
          ['followUser', () => ctx.http.put(`/api/v1/users/${name}/follow`)],
          ['unfollowUser', () => ctx.http.delete(`/api/v1/users/${name}/follow`)],
        ] as const) {
          const res = await req().set(bearer(viewer));
          expectContract(res, op);
          expect({ name, op, status: res.status }).toEqual({ name, op, status: 404 });
          bodies.add(JSON.stringify(errorShape(res)));
        }
      }
      expect([...bodies]).toEqual([
        JSON.stringify({ status: 404, code: 'NOT_FOUND', message: 'Resource not found.' }),
      ]);
    });
  });

  describe('SEC-038 cursor bounds', () => {
    const forge = (payload: unknown): string => {
      const key = Buffer.from(hkdfSync('sha256', ctx.config.live.cursorKey, 'kabso', 'live-cursor/v1', 32));
      const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
      const tag = createHmac('sha256', key).update(`live-cursor\u0000${body}`).digest().subarray(0, 16);
      return `${body}.${tag.toString('base64url')}`;
    };

    it('validly signed cursors at the bounds return 200; beyond them 400 (never 500)', async () => {
      const viewer = await signup(ctx);
      const id = '0192f1d0-0000-7000-8000-000000000000';
      const base = { v: 1, c: null, u: null, i: id };
      for (const tab of ['popular', 'new'] as const) {
        for (const [n, s] of [
          [CURSOR_MAX_VIEWER_COUNT, CURSOR_MAX_STARTED_AT_MS],
          [0, 0],
          [CURSOR_MAX_VIEWER_COUNT, 0],
          [0, CURSOR_MAX_STARTED_AT_MS],
        ]) {
          const res = await ctx.http
            .get('/api/v1/live/rooms')
            .query({ tab, cursor: forge({ ...base, t: tab, n, s }) })
            .set(bearer(viewer));
          expectContract(res, 'listLiveRooms');
          expect({ tab, n, s, status: res.status }).toEqual({ tab, n, s, status: 200 });
        }
        for (const bad of [
          { n: CURSOR_MAX_VIEWER_COUNT + 1, s: 0 },
          { n: 0, s: CURSOR_MAX_STARTED_AT_MS + 1 },
          { n: 0, s: 8_640_000_000_000_000 },
        ]) {
          const res = await ctx.http
            .get('/api/v1/live/rooms')
            .query({ tab, cursor: forge({ ...base, t: tab, ...bad }) })
            .set(bearer(viewer));
          expect(res.status).toBe(400);
          expect(res.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
        }
      }
    });
  });

  describe('QA-002 follow on a private account', () => {
    it('an existing follower re-PUTs → 200 (no new edge); a new follow stays 403', async () => {
      const fan = await signup(ctx);
      const target = await signup(ctx);
      expect((await ctx.http.put(`/api/v1/users/${target.username}/follow`).set(bearer(fan))).status).toBe(
        200,
      );
      await ctx.prisma.userSettings.update({ where: { userId: target.id }, data: { isPrivate: true } });

      const again = await ctx.http.put(`/api/v1/users/${target.username}/follow`).set(bearer(fan));
      expectContract(again, 'followUser');
      expect(again.status).toBe(200);
      expect(again.body).toEqual({ isFollowing: true, followerCount: 1 });
      expect(await ctx.prisma.follow.count({ where: { followeeId: target.id } })).toBe(1);

      const stranger = await signup(ctx);
      const denied = await ctx.http.put(`/api/v1/users/${target.username}/follow`).set(bearer(stranger));
      expectContract(denied, 'followUser');
      expect({ status: denied.status, code: denied.body.error?.code }).toEqual({
        status: 403,
        code: 'AUTH_FORBIDDEN',
      });
      expect(await ctx.prisma.follow.count({ where: { followeeId: target.id } })).toBe(1);

      const leave = await ctx.http.delete(`/api/v1/users/${target.username}/follow`).set(bearer(fan));
      expect(leave.body).toEqual({ isFollowing: false, followerCount: 0 });
      const back = await ctx.http.put(`/api/v1/users/${target.username}/follow`).set(bearer(fan));
      expect(back.status).toBe(403); // a former follower is a new follow
    });
  });

  describe('go-live re-checks the host inside its transaction', () => {
    it('a host suspended after authentication cannot create a room', async () => {
      const host = await signup(ctx);
      await ctx.prisma.user.update({ where: { id: host.id }, data: { status: 'SUSPENDED' } });
      const rooms = ctx.app.get(LiveRoomsService);
      const attempt = rooms.startRoom(host.id, { title: 'Race' }, 'en', { ip: null, requestId: null });
      await expect(attempt).rejects.toBeInstanceOf(AppException);
      await expect(attempt).rejects.toMatchObject({ code: 'AUTH_UNAUTHENTICATED' });
      expect(await ctx.prisma.liveRoom.count({ where: { hostUserId: host.id } })).toBe(0);
    });
  });
});
