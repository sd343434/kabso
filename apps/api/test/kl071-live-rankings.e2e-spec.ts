/**
 * KL-071 / CP-016 part A (D99): the popularity board (openapi v1.13-live DRAFT, CONVENTIONS
 * §10.15), end to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 * Time: the windows and the tap counting rules read "now" from the injectable Clock; a FakeClock
 * starts on a Wednesday at 10:15 UTC and is moved forward. Each suite uses its own hosts, and
 * the hourly rows are cleared before each test so earlier tests do not leak into the board.
 */
import type request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LiveRankingsService } from '../src/modules/live/live-rankings.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

class FakeClock extends Clock {
  ms = Date.parse('2026-10-21T10:15:00.000Z'); // a Wednesday
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

interface Board {
  period: string;
  startsAt: string;
  endsAt: string;
  data: { rank: number; host: { id: string }; points: number; liveRoom: { id: string } | null }[];
  me?: { rank: number | null; points: number };
}

describe('CP-016 A contract coverage', () => {
  it('openapi declares listLiveRankings', () => {
    expect(
      operations()
        .filter((o) => o.path === '/api/v1/live/rankings')
        .map((o) => o.operationId),
    ).toEqual(['listLiveRankings']);
  });
});

function suite(timeZone?: string) {
  const clock = new FakeClock();
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
  const goLive = async (u: TestUser): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: `Room of ${u.username}` });
    expect(res.status).toBe(201);
    return res.body.id as string;
  };
  /** [n] taps (multiples of 10), one batch of 10 a second. */
  const taps = async (roomId: string, u: TestUser, n: number) => {
    for (let left = n; left > 0; left -= 10) {
      clock.advance(1);
      const res = await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/taps`)
        .set(auth(u))
        .send({ count: Math.min(10, left) });
      expect(res.status).toBe(200);
    }
  };
  const board = async (period?: string, u?: TestUser): Promise<Board> => {
    const req: request.Test = ctx.http.get(`/api/v1/live/rankings${period ? `?period=${period}` : ''}`);
    if (u) void req.set(auth(u));
    const res = await req;
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listLiveRankings');
    return res.body as Board;
  };
  return {
    clock,
    get: () => ctx,
    setup: async () => {
      ctx = await createTestApp(
        {
          LIVE_HOSTING_ENABLED: 'true',
          LIVE_HEARTBEAT_STALE_SECONDS: '3600',
          ...(timeZone ? { LIVE_RANKINGS_TIME_ZONE: timeZone } : {}),
        },
        [
          { token: Clock, value: clock },
          { token: LIVE_MEDIA_PROVIDER, value: media },
        ],
      );
    },
    teardown: async () => ctx?.close(),
    clear: () =>
      withMigrationClient(async (c) => {
        await c.liveHostPointsHourly.deleteMany();
      }),
    auth,
    signup,
    host,
    goLive,
    taps,
    board,
  };
}

describe('CP-016 A the popularity board (UTC)', () => {
  const t = suite();
  const { clock, signup, host, goLive, taps, board } = t;
  beforeAll(t.setup);
  afterAll(t.teardown);
  beforeEach(async () => {
    await t.clear();
    clock.ms = Date.parse('2026-10-21T10:15:00.000Z');
  });

  it('ranks hosts by points this hour; the live room is attached; me for a host', async () => {
    const [a, b] = [await host(), await host()];
    const fan = await signup();
    const [ra, rb] = [await goLive(a), await goLive(b)];
    await taps(ra, fan, 30);
    await taps(rb, fan, 50);

    const hour = await board('HOUR', a);
    expect(hour.period).toBe('HOUR');
    expect(hour.startsAt).toBe('2026-10-21T10:00:00.000Z');
    expect(hour.endsAt).toBe('2026-10-21T11:00:00.000Z');
    expect(hour.data.map((e) => [e.rank, e.host.id, e.points, e.liveRoom?.id])).toEqual([
      [1, b.id, 50, rb],
      [2, a.id, 30, ra],
    ]);
    expect(hour.me).toEqual({ rank: 2, points: 30 });
    // Default period is HOUR; guests read it without `me`; a fan (not a host) has no `me`.
    const guest = await board();
    expect(guest.period).toBe('HOUR');
    expect(guest.me).toBeUndefined();
    expect((await board('HOUR', fan)).me).toBeUndefined();
    // A host without points: rank null.
    expect((await board('HOUR', await host())).me).toEqual({ rank: null, points: 0 });
  });

  it('a new hour starts empty; the day and the week keep counting; a new week resets', async () => {
    const a = await host();
    const fan = await signup();
    const ra = await goLive(a);
    await taps(ra, fan, 20);
    // 11:15 the same day; heartbeats keep the live fresh meanwhile.
    for (let i = 0; i < 2; i += 1) {
      clock.advance(1800);
      expect((await t.get().http.post(`/api/v1/live/rooms/${ra}/heartbeat`).set(t.auth(a))).status).toBe(204);
    }
    await taps(ra, fan, 10);
    expect((await board('HOUR')).data.map((e) => e.points)).toEqual([10]);
    const day = await board('DAY');
    expect(day.startsAt).toBe('2026-10-21T00:00:00.000Z');
    expect(day.data.map((e) => e.points)).toEqual([30]);
    const week = await board('WEEK');
    expect(week.startsAt).toBe('2026-10-19T00:00:00.000Z'); // Monday
    expect(week.endsAt).toBe('2026-10-26T00:00:00.000Z');
    expect(week.data.map((e) => e.points)).toEqual([30]);
    clock.ms = Date.parse('2026-10-26T00:30:00.000Z'); // next Monday
    expect((await board('WEEK')).data).toEqual([]);
    expect((await board('DAY')).data).toEqual([]);
  });

  it('points follow the host across lives; the host off air has liveRoom null', async () => {
    const a = await host();
    const fan = await signup();
    const first = await goLive(a);
    await taps(first, fan, 20);
    expect((await t.get().http.post(`/api/v1/live/rooms/${first}/end`).set(t.auth(a))).status).toBe(200);
    expect((await board('HOUR')).data[0]).toMatchObject({ points: 20, liveRoom: null });
    const second = await goLive(a);
    await taps(second, fan, 10);
    expect((await board('HOUR')).data[0]).toMatchObject({ points: 30, liveRoom: { id: second } });
  });

  it('blocks hide hosts from the reader; inactive hosts are left out; bad period → 400', async () => {
    const [a, b] = [await host(), await host()];
    const fan = await signup();
    await taps(await goLive(a), fan, 10);
    await taps(await goLive(b), fan, 20);
    await t.get().http.put(`/api/v1/users/${b.username}/block`).set(t.auth(fan)).expect(200);
    expect((await board('HOUR', fan)).data.map((e) => e.host.id)).toEqual([a.id]);
    await t.get().prisma.user.update({ where: { id: a.id }, data: { status: 'SUSPENDED' } });
    expect((await board('HOUR')).data.map((e) => e.host.id)).toEqual([b.id]);
    const bad = await t.get().http.get('/api/v1/live/rankings?period=MONTH');
    expect(bad.status).toBe(400);
    expectContract(bad, 'listLiveRankings');
  });

  it('the sweeper removes hourly rows older than 15 days', async () => {
    const a = await host();
    const fan = await signup();
    await taps(await goLive(a), fan, 10);
    const rankings = t.get().app.get(LiveRankingsService);
    expect(await rankings.sweepRetention(new Date(clock.ms + 14 * 24 * 3600_000))).toBe(0);
    expect(await rankings.sweepRetention(new Date(clock.ms + 16 * 24 * 3600_000))).toBe(1);
  });
});

describe('CP-016 A the board in another time zone', () => {
  const t = suite('Asia/Riyadh');
  beforeAll(t.setup);
  afterAll(t.teardown);

  it('the day starts at midnight in Riyadh (21:00 UTC the day before)', async () => {
    t.clock.ms = Date.parse('2026-10-21T22:30:00.000Z'); // 01:30 on the 22nd in Riyadh
    const day = await t.board('DAY');
    expect(day.startsAt).toBe('2026-10-21T21:00:00.000Z');
    expect(day.endsAt).toBe('2026-10-22T21:00:00.000Z');
  });
});
