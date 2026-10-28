/**
 * D132 (owner 2026-10-27): lucky gifts (openapi v1.27-live DRAFT, CONVENTIONS §10.27, §10.23), end
 * to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 *
 * The draws come from a scripted `LUCKY_RNG` — a test-only provider override (the production module
 * binds the CSPRNG and nothing reachable over HTTP or configuration replaces it). Unscripted draws
 * return 999 999 (no win). Each daily-protection test moves the FakeClock to a new day, so it
 * starts with an empty budget. `gift-admin` runs as on the server in its own test.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn, grantStockIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import type { LuckyRng } from '../src/modules/gifts/lucky-odds.js';
import { LUCKY_RNG } from '../src/modules/gifts/lucky-rng.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import type { Redis } from 'ioredis';
import { REDIS } from '../src/redis/redis.module.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, settle, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.UTC(2026, 9, 27, 12, 0, 0);
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += Math.round(seconds * 1000);
  }
}

/** Test-only draws: the scripted values first, then "no win". Counts every call. */
class ScriptedRng implements LuckyRng {
  private queue: number[] = [];
  calls = 0;
  script(...values: number[]): void {
    this.queue = [...values];
  }
  int(maxExclusive: number): number {
    expect(maxExclusive).toBe(1_000_000);
    this.calls += 1;
    return this.queue.shift() ?? 999_999;
  }
}

/** Draw values of the default table (D148, CONVENTIONS §10.27): the first value of each outcome. */
const DRAW = {
  x5: 0,
  x10: 48_918,
  x25: 64_369,
  x50: 68_272,
  x100: 69_736,
  x250: 70_305,
  x500: 70_435,
  x1000: 70_475,
  none: 999_999,
} as const;

/** The default table's outcomes (D148): multiplier and chance per million. */
const TABLE: [number, number][] = [
  [5, 48_918],
  [10, 15_451],
  [25, 3_903],
  [50, 1_464],
  [100, 569],
  [250, 130],
  [500, 40],
  [1000, 12],
];

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly token: string;
}

function giftAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'gift:admin', ...args], {
      cwd: fileURLToPath(new URL('..', import.meta.url)),
      env: process.env,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { status: 0, out };
  } catch (err) {
    const e = err as { status: number; stderr: string };
    return { status: e.status, out: e.stderr };
  }
}

describe('D132 contract coverage', () => {
  it('openapi v1.27-live declares the lucky-gift operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('getLuckyGiftOdds GET /api/v1/live/gifts/lucky/odds');
    expect(ids).toContain('confirmLuckyGiftAge PUT /api/v1/me/lucky-gifts/age-confirmation');
  });
});

/**
 * D145d / D148 load check (owner: 100 lucky sends a second from one user): 100 sends one at a time
 * (the MAX X queue's way), then 3 rounds of 100 started 10 ms apart; every send must succeed and
 * continue the same combo in order. Prints the measurements (they are not pass/fail thresholds).
 */
async function loadCheck(ctx: TestContext, f: Fixtures, tag: string): Promise<void> {
  /** Percentile `p` (0–1) of `xs` in ms, rounded to 0.1. */
  const pct = (xs: number[], p: number) => {
    const sorted = [...xs].sort((a, b) => a - b);
    const v = sorted[Math.min(sorted.length - 1, Math.floor(p * sorted.length))] ?? 0;
    return Math.round(v * 10) / 10;
  };
  /** Times every interactive transaction of the app (connection, advisory lock wait and body). */
  const timeTransactions = () => {
    const prisma = ctx.prisma as unknown as { $transaction: (...a: unknown[]) => Promise<unknown> };
    const original = prisma.$transaction;
    const times: number[] = [];
    prisma.$transaction = function (this: unknown, ...a: unknown[]) {
      const t0 = performance.now();
      return original.apply(this, a).finally(() => times.push(performance.now() - t0));
    };
    return { times, restore: () => void (prisma.$transaction = original) };
  };
  const { h, viewer, roomId } = await f.scene();
  const code = await f.gift();
  const report: string[] = [];

  // 1) The MAX X queue's way: one send in flight at a time, as fast as the server answers.
  const tx1 = timeTransactions();
  const seq: number[] = [];
  const cpu1 = process.cpuUsage();
  const seqStart = performance.now();
  for (let i = 0; i < 100; i++) {
    const t0 = performance.now();
    const res = await f.send(roomId, viewer, f.body(code, [h]));
    seq.push(performance.now() - t0);
    expect(res.status, `sequential ${String(i)}: ${JSON.stringify(res.body)}`).toBe(201);
  }
  const seqSeconds = (performance.now() - seqStart) / 1000;
  const seqCpu = process.cpuUsage(cpu1);
  tx1.restore();
  report.push(
    `sequential 100: ${seqSeconds.toFixed(2)} s (${(100 / seqSeconds).toFixed(1)} sends/s); ` +
      `HTTP p50 ${String(pct(seq, 0.5))} p95 ${String(pct(seq, 0.95))} max ${String(pct(seq, 1))} ms; ` +
      `transaction p50 ${String(pct(tx1.times, 0.5))} p95 ${String(pct(tx1.times, 0.95))} max ${String(pct(tx1.times, 1))} ms; ` +
      // The API and the test client share this one Node process (one core at most).
      `Node CPU ${((seqCpu.user + seqCpu.system) / 1000 / 100).toFixed(1)} ms per send`,
  );
  await new Promise((r) => setTimeout(r, 1100));

  // 2) 100 a second offered: each round starts 100 sends 10 ms apart without waiting for the
  // answers (one fresh 1 s window per round), then waits for them all.
  for (let round = 0; round < 3; round++) {
    const tx = timeTransactions();
    const latencies: number[] = [];
    const cpu = process.cpuUsage();
    const t0 = performance.now();
    const pending: Promise<request.Response>[] = [];
    for (let i = 0; i < 100; i++) {
      const due = t0 + i * 10 - performance.now();
      if (due > 0) await new Promise((r) => setTimeout(r, due));
      const start = performance.now();
      pending.push(
        f.send(roomId, viewer, f.body(code, [h])).then((res) => {
          latencies.push(performance.now() - start);
          return res;
        }),
      );
    }
    const offered = (performance.now() - t0) / 1000;
    const answers = await Promise.all(pending);
    const drained = (performance.now() - t0) / 1000;
    const used = process.cpuUsage(cpu);
    tx.restore();
    const statuses = answers.map((r) => r.status);
    report.push(
      `round ${String(round + 1)}: 100 offered in ${offered.toFixed(2)} s, all answered after ${drained.toFixed(2)} s ` +
        `(${(100 / drained).toFixed(1)} sends/s committed); 429s ${String(statuses.filter((s) => s === 429).length)}; ` +
        `HTTP p50 ${String(pct(latencies, 0.5))} p95 ${String(pct(latencies, 0.95))} max ${String(pct(latencies, 1))} ms; ` +
        `transaction (incl. lock wait) p50 ${String(pct(tx.times, 0.5))} p95 ${String(pct(tx.times, 0.95))} max ${String(pct(tx.times, 1))} ms; ` +
        `Node CPU ${(((used.user + used.system) / 1000 / (drained * 1000)) * 100).toFixed(0)} % of one core`,
    );
    for (const [i, res] of answers.entries()) {
      expect(res.status, `round ${String(round)} send ${String(i)}: ${JSON.stringify(res.body)}`).toBe(201);
    }
    await new Promise((r) => setTimeout(r, 1100));
  }
  expect(await ctx.prisma.liveGift.count({ where: { senderId: viewer.id } })).toBe(400);
  // Each send is one combo step of the same streak, in order.
  const combo = await ctx.prisma.liveGift.findMany({
    where: { senderId: viewer.id },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    select: { comboCount: true },
  });
  expect(new Set(combo.map((c) => c.comboCount)).size).toBe(combo.length);
  process.stderr.write(`[${tag}] ${report.join(`\n[${tag}] `)}\n`);
}

type Fixtures = ReturnType<typeof fixtures>;

/** Shared fixtures over one app. */
function fixtures(get: () => TestContext, clock: FakeClock) {
  let seq = 0;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(get());
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).toLowerCase(),
      token: res.body.tokens.accessToken as string,
    };
  };
  const join = async (roomId: string, u: TestUser) => {
    const raw = JSON.stringify({
      event: 'participant_joined',
      room: { name: roomId },
      participant: { identity: u.id },
    });
    const res = await get()
      .http.post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(res.status).toBe(200);
  };
  const coins = (u: TestUser, amount: number) =>
    get().prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const gift = async (fields: Partial<GiftFields> = {}): Promise<string> => {
    seq += 1;
    const code = `l${String(seq)}_${randomUUID().slice(0, 6)}`;
    await get().prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'LUCKY',
        nameAr: `حظ ${String(seq)}`,
        nameEn: `Lucky ${String(seq)}`,
        priceCoins: 10,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: seq,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
        ...fields,
      }),
    );
    return code;
  };
  const wallet = async (u: TestUser) => {
    const res = await get().http.get('/api/v1/wallet/me').set(auth(u));
    expect(res.status).toBe(200);
    return res.body.coins as number;
  };
  const confirmAge = async (u: TestUser) => {
    const res = await get()
      .http.put('/api/v1/me/lucky-gifts/age-confirmation')
      .set(auth(u))
      .send({ adult: true });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    return res;
  };
  /** A live with a host, a seated guest and a viewer (who confirmed 18+), everyone with coins. */
  const scene = async () => {
    const h = await signup();
    await get().prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const [s1, viewer] = [await signup(), await signup()];
    const res = await get()
      .http.post('/api/v1/live/rooms')
      .set(auth(h))
      .send({ title: 'Lucky', mode: 'AUDIO', seatCount: 10 });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const roomId = res.body.id as string;
    await join(roomId, s1);
    await get().prisma.liveRoomSeat.create({ data: { roomId, seatIndex: 1, userId: s1.id } });
    await join(roomId, viewer);
    for (const u of [h, s1, viewer]) await coins(u, 1_000_000);
    await confirmAge(viewer);
    return { h, s1, viewer, roomId };
  };
  const body = (code: string, recipients: TestUser[], extra: object = {}) => ({
    giftCode: code,
    quantity: 1,
    recipients: recipients.map((r) => r.username),
    source: 'COINS',
    clientId: randomUUID(),
    ...extra,
  });
  const send = (
    roomId: string,
    u: TestUser,
    payload: unknown,
    country: string | null = 'SA',
  ): request.Test => {
    const req = get().http.post(`/api/v1/live/rooms/${roomId}/gifts`).set(auth(u));
    if (country !== null) void req.set('CF-IPCountry', country);
    return req.send(payload as object);
  };
  const newDay = () => clock.advance(24 * 3600);
  return { auth, signup, join, coins, gift, wallet, confirmAge, scene, body, send, newDay };
}

describe('D132 lucky gifts (on)', { timeout: 180_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  const rng = new ScriptedRng();
  let ctx: TestContext;
  const f = fixtures(() => ctx, clock);

  const expectError = (res: request.Response, status: number, code: string) => {
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    expect(res.body.error.code).toBe(code);
    expectContract(res, 'sendLiveGift');
  };
  const ledger = (u: TestUser) =>
    ctx.prisma.walletLedgerEntry.findMany({ where: { userId: u.id }, orderBy: { createdAt: 'asc' } });
  const dayRow = (day: string) =>
    ctx.prisma.luckyGiftDay.findUnique({ where: { day: new Date(`${day}T00:00:00.000Z`) } });
  const today = () => clock.now().toISOString().slice(0, 10);

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LUCKY_GIFTS_ENABLED: 'true',
        LUCKY_GIFTS_DISABLED_COUNTRIES: 'IR,KP',
        LUCKY_GIFTS_COUNTRY_HEADER: 'CF-IPCountry',
        // The D132 arithmetic below is checked without the D148 guarantee (its own describe has it).
        LUCKY_PITY_AFTER: '0',
      },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: LUCKY_RNG, value: rng },
      ],
    );
  });
  afterAll(async () => ctx?.close());

  describe('odds and the 18+ statement', () => {
    it('publishes the table to guests; a signed-in caller learns why they may not send yet', async () => {
      const guest = await ctx.http.get('/api/v1/live/gifts/lucky/odds');
      expect(guest.status).toBe(200);
      expectContract(guest, 'getLuckyGiftOdds');
      // This app runs without the guarantee (LUCKY_PITY_AFTER=0): the draws alone return 69.1275 %.
      expect(guest.body).toEqual({
        enabled: true,
        drawsPerGift: 1,
        returnPercent: 69.1275,
        hostSharePercent: 10,
        outcomes: TABLE.map(([multiplier, chancePerMillion]) => ({
          multiplier,
          chancePerMillion,
          probability: chancePerMillion / 1_000_000,
        })),
        noWinChancePerMillion: 929_513,
        noWinProbability: 0.929513,
        bigWinMultiplier: 100,
        pity: null,
        dailyProtection: true,
        dayTimeZone: 'UTC',
        minimumAge: 18,
        caller: null,
      });
      const sum = (guest.body.outcomes as { multiplier: number; probability: number }[]).reduce(
        (a, o) => a + o.multiplier * o.probability,
        0,
      );
      expect(sum).toBeCloseTo(0.691275, 10);

      const u = await f.signup();
      const odds = (country: string | null) => {
        const req = ctx.http.get('/api/v1/live/gifts/lucky/odds').set(f.auth(u));
        if (country !== null) void req.set('CF-IPCountry', country);
        return req;
      };
      const before = await odds('SA');
      expectContract(before, 'getLuckyGiftOdds');
      expect(before.body.caller).toEqual({ eligible: false, reason: 'AGE_UNCONFIRMED', ageConfirmed: false });
      expect((await odds('IR')).body.caller).toEqual({
        eligible: false,
        reason: 'REGION_UNAVAILABLE',
        ageConfirmed: false,
      });
      expect((await odds(null)).body.caller.reason).toBe('REGION_UNAVAILABLE');

      const first = await f.confirmAge(u);
      expectContract(first, 'confirmLuckyGiftAge');
      expect(first.body).toEqual({ ageConfirmedAt: clock.now().toISOString() });
      clock.advance(60);
      // Idempotent: the first time is kept, one audit row.
      expect((await f.confirmAge(u)).body).toEqual(first.body);
      expect(
        await ctx.prisma.auditLog.count({ where: { action: 'lucky.age_confirm', targetId: u.id } }),
      ).toBe(1);
      expect((await odds('SA')).body.caller).toEqual({ eligible: true, reason: null, ageConfirmed: true });
    });

    it('the statement must be exactly {"adult": true} and needs a token', async () => {
      const u = await f.signup();
      const put = (b: object) =>
        ctx.http.put('/api/v1/me/lucky-gifts/age-confirmation').set(f.auth(u)).send(b);
      for (const [b, details] of [
        [{}, [{ field: 'adult', issue: 'required' }]],
        [{ adult: false }, [{ field: 'adult', issue: 'invalid_value' }]],
        [{ adult: 'yes' }, [{ field: 'adult', issue: 'invalid_value' }]],
        [{ adult: true, birthYear: 1990 }, [{ field: 'birthYear', issue: 'unknown_field' }]],
      ] as const) {
        const res = await put(b);
        expect(res.status).toBe(400);
        expectContract(res, 'confirmLuckyGiftAge');
        expect(res.body.error.details).toEqual(details);
      }
      expect(await ctx.prisma.luckyGiftAgeConfirmation.count({ where: { userId: u.id } })).toBe(0);
      const anonymous = await ctx.http.put('/api/v1/me/lucky-gifts/age-confirmation').send({ adult: true });
      expect(anonymous.status).toBe(401);
    });
  });

  describe('catalogue', () => {
    it('lists the LUCKY tab and its gifts while lucky gifts are on', async () => {
      const u = await f.signup();
      const code = await f.gift({ nameEn: 'Clover' });
      const res = await ctx.http.get('/api/v1/gifts/catalogue').set(f.auth(u)).set('Accept-Language', 'en');
      expect(res.status).toBe(200);
      expectContract(res, 'getGiftCatalogue');
      expect(res.body.categories).toEqual(['POPULAR', 'EVENT', 'FUN', 'LUCKY']);
      expect(res.body.data.find((g: { code: string }) => g.code === code)).toMatchObject({
        category: 'LUCKY',
        name: 'Clover',
        priceCoins: 10,
      });
    });
  });

  describe('D145c / D145d rate limits (owner: «too many attempts» during a lucky streak; 100 / s)', () => {
    it('D145d load: 100 lucky sends a second from one user — 3 rounds of 100 started 10 ms apart all succeed (no 429); sequential sends measured too', async () => {
      await loadCheck(ctx, f, 'D145d load');
    });

    it('a 101st lucky send in one second → 429 with Retry-After, nothing charged; a retry with the same clientId is not counted; normal gifts keep 120 / min', async () => {
      const { h, viewer, roomId } = await f.scene();
      const code = await f.gift();
      const before = await f.wallet(viewer);
      // A burst past 100 / s, all at once: refused with Retry-After, nothing charged for it.
      const burst = [];
      for (let i = 0; i < 101; i++) burst.push(f.body(code, [h]));
      const answers = await Promise.all(burst.map((b) => f.send(roomId, viewer, b)));
      const limited = answers.filter((r) => r.status === 429);
      expect(limited.length).toBeGreaterThanOrEqual(1);
      expect(answers.filter((r) => r.status === 201).length).toBe(101 - limited.length);
      expectError(limited[0]!, 429, 'RATE_LIMITED');
      expect(Number(limited[0]!.headers['retry-after'])).toBeGreaterThanOrEqual(1);
      const sent = 101 - limited.length;
      expect(await ctx.prisma.liveGift.count({ where: { senderId: viewer.id } })).toBe(sent);
      expect(await f.wallet(viewer)).toBe(before - sent * 10);
      // The same clientId once the window passed: sent (and a retry of a done one is free).
      await new Promise((r) => setTimeout(r, 1100));
      const lastBody = burst[answers.indexOf(limited[0]!)]!;
      expect((await f.send(roomId, viewer, lastBody)).status).toBe(201);
      const replays = await Promise.all(Array.from({ length: 120 }, () => f.send(roomId, viewer, lastBody)));
      expect(replays.every((r) => r.status === 200)).toBe(true);

      // Normal gifts keep their own bucket (120 / min, RATE_LIMIT_LIVE_GIFT_USER).
      const normal = await f.gift({ category: 'POPULAR' });
      const normals = [];
      for (let i = 0; i < 121; i++) normals.push((await f.send(roomId, h, f.body(normal, [h]))).status);
      expect(normals.slice(0, 120).every((s) => s === 201)).toBe(true);
      expect(normals[120]).toBe(429);
    });
  });

  describe('gates', () => {
    it('18+: refused until the caller confirmed; nothing charged, drawn or stored', async () => {
      const { h, s1, roomId } = await f.scene();
      const code = await f.gift();
      const calls = rng.calls;
      expectError(await f.send(roomId, s1, f.body(code, [h])), 403, 'LUCKY_GIFT_AGE_UNCONFIRMED');
      expect(rng.calls).toBe(calls);
      expect(await f.wallet(s1)).toBe(1_000_000);
      expect(await ctx.prisma.liveGift.count({ where: { senderId: s1.id } })).toBe(0);
      await f.confirmAge(s1);
      expect((await f.send(roomId, s1, f.body(code, [h]))).status).toBe(201);
    });

    it('region: a listed edge country, a missing one, or a listed own country → 403; others pass', async () => {
      const { h, viewer, roomId } = await f.scene();
      const code = await f.gift();
      expectError(
        await f.send(roomId, viewer, f.body(code, [h]), 'IR'),
        403,
        'LUCKY_GIFT_REGION_UNAVAILABLE',
      );
      expectError(
        await f.send(roomId, viewer, f.body(code, [h]), 'kp'),
        403,
        'LUCKY_GIFT_REGION_UNAVAILABLE',
      );
      // Unknown country while a list is configured: fail closed.
      expectError(
        await f.send(roomId, viewer, f.body(code, [h]), null),
        403,
        'LUCKY_GIFT_REGION_UNAVAILABLE',
      );
      expectError(
        await f.send(roomId, viewer, f.body(code, [h]), 'XX'),
        403,
        'LUCKY_GIFT_REGION_UNAVAILABLE',
      );
      expect(await f.wallet(viewer)).toBe(1_000_000);
      // The caller's own country counts too (v1.27.1-live `Me.country`).
      const patched = await ctx.http.patch('/api/v1/me').set(f.auth(viewer)).send({ country: 'ir' });
      expect(patched.status).toBe(200);
      expectError(
        await f.send(roomId, viewer, f.body(code, [h]), 'SA'),
        403,
        'LUCKY_GIFT_REGION_UNAVAILABLE',
      );
      await ctx.http.patch('/api/v1/me').set(f.auth(viewer)).send({ country: 'SA' });
      expect((await f.send(roomId, viewer, f.body(code, [h]), 'SA')).status).toBe(201);
      // A normal gift is never region-gated.
      const normal = await f.gift({ category: 'POPULAR' });
      expect((await f.send(roomId, viewer, f.body(normal, [h]), 'IR')).status).toBe(201);
    });

    it('a lucky gift is sent with coins only (bag → 400 source); gift-admin refuses to put it in a bag', async () => {
      const { h, viewer, roomId } = await f.scene();
      const code = await f.gift();
      await ctx.prisma.$transaction((tx) => grantStockIn(tx, viewer.id, code, 5));
      const res = await f.send(roomId, viewer, f.body(code, [h], { source: 'BAG' }));
      expect(res.status).toBe(400);
      expect(res.body.error.details).toEqual([{ field: 'source', issue: 'invalid_value' }]);
      expectContract(res, 'sendLiveGift');
      expect(giftAdmin('grant', viewer.email, code, '1')).toEqual({
        status: 1,
        out: `${code} is a LUCKY gift; lucky gifts cannot be put in a bag.\n`,
      });
    });
  });

  describe('sending', () => {
    it('draws once per gift, credits the wins, counts 10 % for the room and full Wizard; a retry never draws again', async () => {
      const publish = async (code: 'ATTRACTIVENESS' | 'SUPPORT' | 'WIZARD') => {
        const category = await ctx.prisma.levelCategory.create({
          data: { code, nameAr: 'فئة', nameEn: code, descriptionAr: 'وصف', descriptionEn: 'About' },
        });
        const version = await ctx.prisma.levelCategoryVersion.create({
          data: {
            categoryId: category.id,
            versionNumber: 1,
            status: 'PUBLISHED',
            multiplier: '1',
            valueUnit: 'COIN',
            publishedAt: clock.now(),
            levels: { create: [{ levelNumber: 1, nameAr: 'أ', nameEn: 'A', requiredPoints: 0n }] },
          },
        });
        await ctx.prisma.levelCategory.update({
          where: { id: category.id },
          data: { isEnabled: true, publishedVersionId: version.id },
        });
      };
      for (const code of ['ATTRACTIVENESS', 'SUPPORT', 'WIZARD'] as const) await publish(code);

      f.newDay();
      const { h, s1, viewer, roomId } = await f.scene();
      // Fill today's budget first: 1 314 × 100 coins, nothing won (85 % of it is 111 690).
      const big = await f.gift({ priceCoins: 100 });
      rng.script();
      expect((await f.send(roomId, viewer, f.body(big, [h], { quantity: 1314 }))).status).toBe(201);

      const scoreBefore = (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).score;
      const contributionBefore = (
        await ctx.prisma.liveRoomTapper.findUniqueOrThrow({
          where: { roomId_userId: { roomId, userId: viewer.id } },
        })
      ).points;
      const coinsBefore = await f.wallet(viewer);
      // 10 gifts to each of two people = 20 draws: the 1st wins ×5, the 4th ×100, the rest nothing.
      rng.script(DRAW.x5, DRAW.none, DRAW.none, DRAW.x100);
      const calls = rng.calls;
      const payload = f.body(big, [h, s1], { quantity: 10 });
      const res = await f.send(roomId, viewer, payload);
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'sendLiveGift');
      expect(rng.calls - calls).toBe(20);
      expect(res.body.gift).toMatchObject({
        unitPrice: 100,
        quantity: 10,
        totalCoins: 2_000,
        source: 'COINS',
      });
      expect(res.body.luckyResult).toEqual({
        draws: 20,
        wins: [
          { multiplier: 5, count: 1, coins: 500 },
          { multiplier: 100, count: 1, coins: 10_000 },
        ],
        coinsWon: 10_500,
        topMultiplier: 100,
        downgraded: 0,
        guaranteed: false,
      });
      expect(res.body.coins).toBe(coinsBefore - 2_000 + 10_500);
      expect(await f.wallet(viewer)).toBe(coinsBefore - 2_000 + 10_500);
      const giftId = res.body.gift.id as string;

      // Ledger: the charge (LUCKY_GIFT) and the win (LUCKY_GIFT_WIN), both referencing the send.
      const rows = (await ledger(viewer)).filter((r) => r.referenceId === giftId);
      expect(rows.map((r) => [r.reason, Number(r.delta), Number(r.balanceAfter)])).toEqual([
        ['LUCKY_GIFT', -2_000, coinsBefore - 2_000],
        ['LUCKY_GIFT_WIN', 10_500, coinsBefore - 2_000 + 10_500],
      ]);

      // The audit row of the draws and the day.
      const audit = await ctx.prisma.luckyGiftDraw.findUniqueOrThrow({ where: { giftId } });
      expect(audit).toMatchObject({
        senderId: viewer.id,
        giftCode: big,
        unitPrice: 100,
        quantity: 10,
        recipients: 2,
        draws: 20,
        wins: [
          [0, 5, 5],
          [3, 100, 100],
        ],
        coinsWon: 10_500n,
        topMultiplier: 100,
        downgraded: 0,
        budgetBefore: 111_690n + 1_700n,
        budgetAfter: 111_690n + 1_700n - 10_500n,
        spendAfter: 133_400n,
      });
      expect(audit.odds).toEqual({ rtpBps: 8500, hostShareBps: 1000, outcomes: TABLE, pity: null });
      expect(audit).toMatchObject({ lossesBefore: 1_314, lossesAfter: 16, guaranteed: 0 });
      expect(await dayRow(today())).toMatchObject({
        spendCoins: 133_400n,
        paidCoins: 10_500n,
        sends: 2,
        draws: 1_334n,
      });

      // Host share 10 %: the score and Contribution grow by 2 000 × 100 × 10 % = 20 000.
      expect(
        (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).score - scoreBefore,
      ).toBe(20_000n);
      const contribution = await ctx.prisma.liveRoomTapper.findUniqueOrThrow({
        where: { roomId_userId: { roomId, userId: viewer.id } },
      });
      expect(contribution.points - contributionBefore).toBe(20_000n);
      // Charm: 10 % of 1 000 per recipient; Wizard: the full 1 000 per recipient; no Support (switch off).
      const credits = await ctx.prisma.pointsLedgerEntry.findMany({
        where: { sourceTransactionId: { startsWith: `gift:${giftId}:` } },
      });
      expect(
        credits
          .map((e) => [e.userId, e.sourceType, e.pointsDelta])
          .sort((a, b) => `${String(a[0])}${String(a[1])}`.localeCompare(`${String(b[0])}${String(b[1])}`)),
      ).toEqual(
        [
          [h.id, 'GIFT_RECEIVED', 100n],
          [s1.id, 'GIFT_RECEIVED', 100n],
          [viewer.id, 'LUCKY_GIFT_SENT', 1_000n],
          [viewer.id, 'LUCKY_GIFT_SENT', 1_000n],
        ].sort((a, b) => `${String(a[0])}${String(a[1])}`.localeCompare(`${String(b[0])}${String(b[1])}`)),
      );

      // The big win goes to the room as a `lucky-win` data message (×100 ≥ bigWinMultiplier).
      await settle(ctx);
      expect(media.broadcastsOf(roomId, 'lucky-win')).toEqual([
        {
          type: 'lucky-win',
          win: {
            giftId,
            roomId,
            giftCode: big,
            sender: res.body.gift.sender,
            multiplier: 100,
            coinsWon: 10_500,
            createdAt: res.body.gift.createdAt,
          },
        },
      ]);
      expect(media.broadcasts.filter((b) => b.room === roomId && b.topic === 'lucky')).toHaveLength(1);

      // A retry: 200, the same result, no draw, no charge, no credit, no message.
      const retry = await f.send(roomId, viewer, payload);
      expect(retry.status).toBe(200);
      expectContract(retry, 'sendLiveGift');
      expect(retry.body).toEqual({ ...res.body, coins: coinsBefore - 2_000 + 10_500 });
      expect(rng.calls - calls).toBe(20);
      expect((await ledger(viewer)).filter((r) => r.referenceId === giftId)).toHaveLength(2);
      expect(await ctx.prisma.luckyGiftDraw.count({ where: { giftId } })).toBe(1);
      await settle(ctx);
      expect(media.broadcastsOf(roomId, 'lucky-win')).toHaveLength(1);

      // A small win (×5) is not announced.
      rng.script(DRAW.x5);
      const small = await f.send(roomId, viewer, f.body(big, [h]));
      expect(small.body.luckyResult.topMultiplier).toBe(5);
      await settle(ctx);
      expect(media.broadcastsOf(roomId, 'lucky-win')).toHaveLength(1);
    });

    it('concurrent retries with one clientId: one send, one set of draws', async () => {
      const { h, viewer, roomId } = await f.scene();
      const code = await f.gift();
      const payload = f.body(code, [h], { quantity: 10 });
      const results = await Promise.all([f.send(roomId, viewer, payload), f.send(roomId, viewer, payload)]);
      expect(results.map((r) => r.status).sort()).toEqual([200, 201]);
      const ids = new Set(results.map((r) => r.body.gift.id as string));
      expect(ids.size).toBe(1);
      expect(await ctx.prisma.luckyGiftDraw.count({ where: { senderId: viewer.id } })).toBe(1);
      expect((await ledger(viewer)).filter((r) => r.reason === 'LUCKY_GIFT')).toHaveLength(1);
      expect(results[0].body.luckyResult).toEqual(results[1].body.luckyResult);
    });
  });

  describe('daily protection', () => {
    it('a win above the day budget is downgraded to what fits, or withheld; the day never pays more than 85 %', async () => {
      f.newDay();
      const { h, viewer, roomId } = await f.scene();
      const code = await f.gift({ priceCoins: 10 });

      // First lucky send of the day: spend 10, budget 8 → a ×5 win (50) cannot be paid.
      rng.script(DRAW.x5);
      const first = await f.send(roomId, viewer, f.body(code, [h]));
      expect(first.status).toBe(201);
      expect(first.body.luckyResult).toEqual({
        draws: 1,
        wins: [],
        coinsWon: 0,
        topMultiplier: null,
        downgraded: 1,
        guaranteed: false,
      });
      expect(await f.wallet(viewer)).toBe(1_000_000 - 10);
      expect((await ledger(viewer)).some((r) => r.reason === 'LUCKY_GIFT_WIN')).toBe(false);
      const audit = await ctx.prisma.luckyGiftDraw.findUniqueOrThrow({
        where: { giftId: first.body.gift.id },
      });
      expect(audit).toMatchObject({ wins: [[0, 5, 0]], coinsWon: 0n, budgetBefore: 8n, budgetAfter: 8n });

      // 990 more coins of lucky gifts without a win: the day's spend is 1 000 (budget 850).
      expect((await f.send(roomId, viewer, f.body(code, [h], { quantity: 99 }))).status).toBe(201);

      // ×500 (5 000) does not fit in 858 (= floor(1 010 × 85 %)): it pays ×50 (500); ×100 would be 1 000.
      rng.script(DRAW.x500);
      const capped = await f.send(roomId, viewer, f.body(code, [h]));
      expect(capped.body.luckyResult).toEqual({
        draws: 1,
        wins: [{ multiplier: 50, count: 1, coins: 500 }],
        coinsWon: 500,
        topMultiplier: 50,
        downgraded: 1,
        guaranteed: false,
      });
      expect(
        await ctx.prisma.luckyGiftDraw.findUniqueOrThrow({ where: { giftId: capped.body.gift.id } }),
      ).toMatchObject({ wins: [[0, 500, 50]], budgetBefore: 858n, budgetAfter: 358n, spendAfter: 1_010n });

      // Three ×100 draws (1 000 coins each): spend 1 110 → budget floor(943.5) − 500 paid = 443, so
      // the first pays ×25 (250; ×50 = 500 does not fit), the second ×10 (100), the third ×5 (50),
      // leaving 43.
      rng.script(DRAW.x100, DRAW.x100, DRAW.x100);
      const many = await f.send(roomId, viewer, f.body(code, [h], { quantity: 10 }));
      expect(many.body.luckyResult).toMatchObject({ draws: 10, downgraded: 3 });
      const day = await dayRow(today());
      expect(day!.paidCoins).toBeLessThanOrEqual((day!.spendCoins * 8_500n) / 10_000n);
      expect(day).toMatchObject({ spendCoins: 1_110n, paidCoins: 900n });
      expect(many.body.luckyResult.wins).toEqual([
        { multiplier: 5, count: 1, coins: 50 },
        { multiplier: 10, count: 1, coins: 100 },
        { multiplier: 25, count: 1, coins: 250 },
      ]);

      // No ×100 or ×500 was paid, so the room got no big-win message.
      await settle(ctx);
      expect(media.broadcastsOf(roomId, 'lucky-win')).toEqual([]);
    });
  });

  describe('admin', () => {
    it('gift-admin: --category LUCKY, lucky-wins and lucky-day', async () => {
      const code = `cli_lucky_${randomUUID().slice(0, 6)}`;
      expect(
        giftAdmin(
          'add',
          code,
          '--category',
          'LUCKY',
          '--name-ar',
          'برسيم',
          '--name-en',
          'Clover',
          '--price',
          '10',
          '--asset',
          'gift_clover',
        ),
      ).toEqual({ status: 0, out: `+${code} (LUCKY, 10 coins).\n` });
      expect((await ctx.prisma.gift.findUniqueOrThrow({ where: { code } })).category).toBe('LUCKY');
      expect(
        giftAdmin(
          'add',
          `${code}_x`,
          '--category',
          'JACKPOT',
          '--name-ar',
          'x',
          '--name-en',
          'x',
          '--price',
          '1',
          '--asset',
          'a',
        ).status,
      ).toBe(1);

      const wins = giftAdmin('lucky-wins', '--limit', '5', '--min-multiplier', '100');
      expect(wins.status).toBe(0);
      expect(wins.out).toMatch(/ top=x100 won=10500 downgraded=0 /);
      expect(wins.out).not.toMatch(/top=x5 /);

      const day = giftAdmin('lucky-day', today());
      expect(day.status).toBe(0);
      expect(day.out).toBe(
        `${today()}: spend=1110 paid=900 budget left=43 (RTP 85 %) realised=81.08 % sends=4 draws=111\n`,
      );
      expect(giftAdmin('lucky-day', '2026-13-40').status).toBe(1);
      expect(giftAdmin('lucky-day', '2001-01-01')).toEqual({
        status: 0,
        out: '2001-01-01: no lucky gifts.\n',
      });
    });
  });
});

describe('D148 lucky gifts: eight tiers, the guarantee, the global ticker', { timeout: 180_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  const rng = new ScriptedRng();
  let ctx: TestContext;
  const f = fixtures(() => ctx, clock);
  const auditOf = (giftId: string) => ctx.prisma.luckyGiftDraw.findUniqueOrThrow({ where: { giftId } });
  const streakOf = async (u: TestUser) =>
    (await ctx.prisma.luckyGiftPity.findUnique({ where: { userId: u.id } }))?.losses ?? null;
  /** A second live (another host) the viewer joins too. */
  const otherRoom = async (viewer: TestUser) => {
    const host = await f.signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(f.auth(host))
      .send({ title: 'Other', mode: 'AUDIO', seatCount: 10 });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const roomId = res.body.id as string;
    await f.join(roomId, viewer);
    return { host, roomId };
  };

  beforeAll(async () => {
    // The defaults (LUCKY_PITY_AFTER 15, LUCKY_PITY_MULTIPLIER 5, the D148 table).
    ctx = await createTestApp(
      { LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600', LUCKY_GIFTS_ENABLED: 'true' },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: LUCKY_RNG, value: rng },
      ],
    );
    await ctx.app.get<Redis>(REDIS).del('lucky:ticker:gate', 'lucky:ticker:pending');
  });
  afterAll(async () => ctx?.close());

  it('the odds list the eight tiers and the guarantee; 84.9999 % with it', async () => {
    const res = await ctx.http.get('/api/v1/live/gifts/lucky/odds');
    expect(res.status).toBe(200);
    expectContract(res, 'getLuckyGiftOdds');
    expect(res.body).toMatchObject({
      enabled: true,
      returnPercent: 84.9999,
      outcomes: TABLE.map(([multiplier, chancePerMillion]) => ({ multiplier, chancePerMillion })),
      noWinChancePerMillion: 929_513,
      pity: { after: 15, multiplier: 5 },
      bigWinMultiplier: 100,
    });
  });

  it('15 losing draws in a row (across rooms) → the 16th pays ×5, flagged guaranteed; any win resets the streak; a retry replays it', async () => {
    f.newDay();
    const { h, viewer, roomId } = await f.scene();
    const other = await otherRoom(viewer);
    const code = await f.gift();
    rng.script();
    // 10 losses in the first room, 5 in the other.
    for (let i = 0; i < 10; i++) expect((await f.send(roomId, viewer, f.body(code, [h]))).status).toBe(201);
    expect(await streakOf(viewer)).toBe(10);
    for (let i = 0; i < 5; i++) {
      const res = await f.send(other.roomId, viewer, f.body(code, [other.host]));
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expect(res.body.luckyResult).toMatchObject({ coinsWon: 0, guaranteed: false });
    }
    expect(await streakOf(viewer)).toBe(15);

    const coinsBefore = await f.wallet(viewer);
    const payload = f.body(code, [other.host]);
    const res = await f.send(other.roomId, viewer, payload);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'sendLiveGift');
    expect(res.body.luckyResult).toEqual({
      draws: 1,
      wins: [{ multiplier: 5, count: 1, coins: 50 }],
      coinsWon: 50,
      topMultiplier: 5,
      downgraded: 0,
      guaranteed: true,
    });
    expect(res.body.coins).toBe(coinsBefore - 10 + 50);
    expect(await auditOf(res.body.gift.id)).toMatchObject({
      wins: [[0, 0, 5]],
      coinsWon: 50n,
      lossesBefore: 15,
      lossesAfter: 0,
      guaranteed: 1,
      odds: { rtpBps: 8500, hostShareBps: 1000, outcomes: TABLE, pity: [15, 5] },
    });
    expect(await streakOf(viewer)).toBe(0);
    const retry = await f.send(other.roomId, viewer, payload);
    expect(retry.status).toBe(200);
    expect(retry.body.luckyResult).toEqual(res.body.luckyResult);
    expect(await streakOf(viewer)).toBe(0);

    // A win of its own resets the streak: 9 losses, then ×10.
    rng.script(...Array<number>(9).fill(DRAW.none), DRAW.x10);
    const ten = await f.send(roomId, viewer, f.body(code, [h], { quantity: 10 }));
    expect(ten.body.luckyResult).toMatchObject({ topMultiplier: 10, guaranteed: false });
    expect(await streakOf(viewer)).toBe(0);
  });

  it('concurrent sends of one sender keep one exact streak: 48 single draws at once → exactly 3 guaranteed wins', async () => {
    f.newDay();
    const { h, viewer, roomId } = await f.scene();
    const code = await f.gift();
    rng.script();
    const answers = await Promise.all(
      Array.from({ length: 48 }, () => f.send(roomId, viewer, f.body(code, [h]))),
    );
    expect(answers.every((r) => r.status === 201)).toBe(true);
    expect(answers.filter((r) => r.body.luckyResult.guaranteed === true)).toHaveLength(3);
    // In the order the sends ran (their combo step), each starts from the streak the one before left.
    const rows = await ctx.prisma.liveGift.findMany({
      where: { senderId: viewer.id },
      orderBy: { comboCount: 'asc' },
      include: { luckyDraw: true },
    });
    expect(rows.map((r) => r.comboCount)).toEqual(Array.from({ length: 48 }, (_, i) => i + 1));
    expect(rows.map((r) => r.luckyDraw!.lossesBefore)).toEqual(Array.from({ length: 48 }, (_, i) => i % 16));
    expect(rows.map((r) => r.luckyDraw!.guaranteed)).toEqual(
      Array.from({ length: 48 }, (_, i) => (i % 16 === 15 ? 1 : 0)),
    );
    expect(await streakOf(viewer)).toBe(0);
    expect(await f.wallet(viewer)).toBe(1_000_000 - 480 + 150);
  });

  it('daily protection: a guarantee larger than what is left pays nothing and stays due; the next draw that fits pays it', async () => {
    f.newDay();
    const { h, s1, viewer, roomId } = await f.scene();
    await f.confirmAge(s1);
    const code = await f.gift({ priceCoins: 100 });
    rng.script();
    for (let i = 0; i < 15; i++) expect((await f.send(roomId, viewer, f.body(code, [h]))).status).toBe(201);
    // Someone else wins ×10 (1 000 of the day's 1 360).
    rng.script(DRAW.x10);
    expect((await f.send(roomId, s1, f.body(code, [h]))).body.luckyResult.coinsWon).toBe(1_000);
    // The viewer's 16th draw is guaranteed ×5 = 500, but floor(1 700 × 85 %) − 1 000 = 445 is left.
    rng.script();
    const due = await f.send(roomId, viewer, f.body(code, [h]));
    expect(due.body.luckyResult).toEqual({
      draws: 1,
      wins: [],
      coinsWon: 0,
      topMultiplier: null,
      downgraded: 1,
      guaranteed: false,
    });
    expect(await auditOf(due.body.gift.id)).toMatchObject({
      wins: [[0, 0, 0]],
      budgetBefore: 445n,
      lossesBefore: 15,
      lossesAfter: 16,
      guaranteed: 0,
    });
    // The 17th: floor(1 800 × 85 %) − 1 000 = 530 ≥ 500 → the guarantee is paid now.
    const paid = await f.send(roomId, viewer, f.body(code, [h]));
    expect(paid.body.luckyResult).toMatchObject({ coinsWon: 500, topMultiplier: 5, guaranteed: true });
    expect(await auditOf(paid.body.gift.id)).toMatchObject({
      budgetBefore: 530n,
      budgetAfter: 30n,
      lossesAfter: 0,
    });
    const day = await ctx.prisma.luckyGiftDay.findFirstOrThrow({ orderBy: { day: 'desc' } });
    expect(day.paidCoins).toBeLessThanOrEqual((day.spendCoins * 8_500n) / 10_000n);
  });

  it('«لحظة الحظ»: a ×100+ win goes to every other live as a lucky-ticker — at most one per 10 s, the biggest waiting one next', async () => {
    f.newDay();
    const redis = ctx.app.get<Redis>(REDIS);
    await redis.del('lucky:ticker:gate', 'lucky:ticker:pending');
    const { h, s1, viewer, roomId } = await f.scene();
    await f.confirmAge(s1);
    const elsewhere = await otherRoom(viewer);
    const code = await f.gift({ priceCoins: 10 });
    // A day's budget for the wins below: s1 sends 1 314 gifts of 100 first (85 % of 131 400 is
    // 111 690; s1's own guarantees take about 41 000 of it).
    const filler = await f.gift({ priceCoins: 100 });
    rng.script();
    expect((await f.send(roomId, s1, f.body(filler, [h], { quantity: 1314 }))).status).toBe(201);

    rng.script(DRAW.x250);
    const first = await f.send(roomId, viewer, f.body(code, [h]));
    expect(first.body.luckyResult.topMultiplier).toBe(250);
    await settle(ctx);
    const ticker = (room: string) => media.broadcastsOf(room, 'lucky-ticker');
    expect(ticker(elsewhere.roomId)).toEqual([
      {
        type: 'lucky-ticker',
        win: {
          giftId: first.body.gift.id,
          roomId,
          giftCode: code,
          sender: first.body.gift.sender,
          multiplier: 250,
          coinsWon: 2_500,
          createdAt: first.body.gift.createdAt,
        },
        room: {
          id: roomId,
          title: 'Lucky',
          host: expect.objectContaining({ id: h.id, username: h.username }),
        },
      },
    ]);
    // Not to its own room (it shows the big card there), only the lucky-win.
    expect(ticker(roomId)).toEqual([]);
    expect(media.broadcastsOf(roomId, 'lucky-win')).toHaveLength(1);

    // Within 10 s: a ×100 and then a ×1000 wait; the ×1000 replaces the ×100, which is dropped.
    rng.script(DRAW.x100);
    expect((await f.send(roomId, s1, f.body(code, [h]))).body.luckyResult.topMultiplier).toBe(100);
    rng.script(DRAW.x1000);
    const jackpot = await f.send(roomId, viewer, f.body(code, [h]));
    expect(jackpot.body.luckyResult.topMultiplier).toBe(1000);
    await settle(ctx);
    expect(ticker(elsewhere.roomId)).toHaveLength(1);
    await new Promise((r) => setTimeout(r, 10_300));
    await settle(ctx);
    const told = ticker(elsewhere.roomId) as { win: { multiplier: number; giftId: string } }[];
    expect(told.map((t) => t.win.multiplier)).toEqual([250, 1000]);
    expect(told[1]!.win.giftId).toBe(jackpot.body.gift.id);
    expect(await redis.get('lucky:ticker:pending')).toBeNull();
  });

  it('D148 load: the same check with the guarantee on (every send writes the streak)', async () => {
    f.newDay();
    await loadCheck(ctx, f, 'D148 load');
  });
});

describe('D132 lucky gifts (off)', { timeout: 60_000 }, () => {
  const clock = new FakeClock();
  const rng = new ScriptedRng();
  let ctx: TestContext;
  const f = fixtures(() => ctx, clock);

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LUCKY_RNG, value: rng },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('no LUCKY tab or gift, odds say disabled, a send is GIFT_UNAVAILABLE without a draw', async () => {
    const { h, viewer, roomId } = await f.scene();
    const code = await f.gift();
    const cat = await ctx.http.get('/api/v1/gifts/catalogue').set(f.auth(viewer));
    expect(cat.body.categories).toEqual(['POPULAR', 'EVENT', 'FUN']);
    expect(cat.body.data.map((g: { code: string }) => g.code)).not.toContain(code);
    await ctx.prisma.$transaction((tx) => grantStockIn(tx, viewer.id, code, 3));
    expect((await ctx.http.get('/api/v1/me/gifts/bag').set(f.auth(viewer))).body.data).toEqual([]);

    const odds = await ctx.http.get('/api/v1/live/gifts/lucky/odds').set(f.auth(viewer));
    expect(odds.status).toBe(200);
    expectContract(odds, 'getLuckyGiftOdds');
    expect(odds.body).toMatchObject({
      enabled: false,
      caller: { eligible: false, reason: 'DISABLED', ageConfirmed: true },
    });

    const res = await f.send(roomId, viewer, f.body(code, [h]), null);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('GIFT_UNAVAILABLE');
    expect(rng.calls).toBe(0);
    expect(await f.wallet(viewer)).toBe(1_000_000);
  });
});
