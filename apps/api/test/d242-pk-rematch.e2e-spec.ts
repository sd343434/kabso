/**
 * D242 (openapi v1.55-live DRAFT, CONVENTIONS §10.85) «جولة أخرى»: a rematch with the same opponent from the PK's
 * result — offer, accept (a new battle between the same rooms, scores and boosters from zero, its own records),
 * decline, lapse, both tapping, withdraw, a host gone, the limit in a row, a DARES rematch with its own dare and
 * idempotency. End to end against PostgreSQL + Redis (PK_REMATCH_MAX = 2 here).
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LivePkService } from '../src/modules/live/live-pk.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { importPkDaresIn } from '../src/modules/live/pk-dares/pk-dare-library.js';
import { parseDareImport, type PkDareImport } from '../src/modules/live/pk-dares/pk-dare-rules.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

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

interface Match {
  id: string;
  status: string;
  type: string;
  seq: number;
  sides: { roomId: string; score: number; boosterUses: Record<string, number>; pkPoints: number }[];
  resultEndsAt: string | null;
  forfeitPoints: number;
  dare: { status: string } | null;
  rematch: { byRoomId: string; expiresAt: string } | null;
  rematchOf: string | null;
  rematchCount: number;
  rematchesLeft: number | null;
  mode: string;
  roundSeconds: number;
}

describe('D242 contract coverage', () => {
  it('openapi v1.55-live declares the rematch operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'offerLivePkRematch POST /api/v1/live/rooms/{roomId}/pk/rematch',
      'cancelLivePkRematch DELETE /api/v1/live/rooms/{roomId}/pk/rematch',
      'acceptLivePkRematch POST /api/v1/live/rooms/{roomId}/pk/rematch/accept',
      'declineLivePkRematch POST /api/v1/live/rooms/{roomId}/pk/rematch/decline',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D242 «جولة أخرى»', { timeout: 600_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let pk: LivePkService;
  let gift = '';

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
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser): Promise<string> => {
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'PK' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const call = (method: 'get' | 'post' | 'delete', path: string, u: TestUser | null, body?: object) => {
    const req = ctx.http[method](`/api/v1/${path}`);
    if (u) void req.set(auth(u));
    return body === undefined ? req : req.send(body);
  };
  const expectError = (res: request.Response, status: number, code: string, operationId?: string) => {
    if (operationId) expectContract(res, operationId);
    expect({ status: res.status, code: res.body.error?.code }, JSON.stringify(res.body)).toEqual({
      status,
      code,
    });
  };
  const heartbeat = async (roomId: string, u: TestUser) => {
    const res = await call('post', `live/rooms/${roomId}/heartbeat`, u);
    expect(res.status).toBe(204);
  };
  const webhook = async (event: string, roomId: string, identity: string) => {
    const raw = JSON.stringify({ event, room: { name: roomId }, participant: { identity } });
    const res = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(res.status).toBe(200);
  };
  const state = async (room: string, u: TestUser): Promise<Match | null> => {
    const res = await call('get', `live/rooms/${room}/pk`, u);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getLivePk');
    return res.body.match as Match | null;
  };
  const events = (roomId: string) =>
    media.broadcasts
      .filter((b) => b.room === roomId && b.topic === 'pk')
      .map((b) => JSON.parse(b.payload) as { event: string; match: Match });
  type Pair = { a: TestUser; b: TestUser; roomA: string; roomB: string };
  const advance = async (seconds: number, s: Pair) => {
    let left = seconds;
    while (left > 0) {
      const step = Math.min(left, 15);
      clock.advance(step);
      left -= step;
      await heartbeat(s.roomA, s.a);
      await heartbeat(s.roomB, s.b);
    }
  };
  /** Two hosts in a battle (A invited B). */
  const battle = async (type: 'NORMAL' | 'DARES' = 'NORMAL'): Promise<Pair & { match: Match }> => {
    const [a, b] = [await host(), await host()];
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    const inv = await call('post', `live/rooms/${roomA}/pk/invites`, a, { toRoomId: roomB, type });
    expect(inv.status, JSON.stringify(inv.body)).toBe(201);
    const acc = await call('post', `live/rooms/${roomB}/pk/invites/${inv.body.id as string}/accept`, b);
    expect(acc.status, JSON.stringify(acc.body)).toBe(200);
    return { a, b, roomA, roomB, match: acc.body as Match };
  };
  /** A's forfeit: the RESULT (B wins), no dare in a NORMAL PK. */
  const forfeit = async (s: Pair): Promise<Match> => {
    const res = await call('post', `live/rooms/${s.roomA}/pk/end`, s.a);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body.status).toBe('RESULT');
    return res.body as Match;
  };
  const offer = (room: string, u: TestUser) => call('post', `live/rooms/${room}/pk/rematch`, u);
  const accept = (room: string, u: TestUser) => call('post', `live/rooms/${room}/pk/rematch/accept`, u);
  const decline = (room: string, u: TestUser) => call('post', `live/rooms/${room}/pk/rematch/decline`, u);
  /** B wins the running battle by one gift, then the time runs out. */
  const timeUp = async (s: Pair) => {
    const f = await signup();
    await ctx.prisma.$transaction((tx) => creditIn(tx, f.id, 10_000n, 'ADMIN_GRANT', randomUUID()));
    await webhook('participant_joined', s.roomB, f.id);
    const sent = await call('post', `live/rooms/${s.roomB}/gifts`, f, {
      giftCode: gift,
      quantity: 1,
      recipients: [s.b.username],
      source: 'COINS',
      clientId: randomUUID(),
    });
    expect(sent.status, JSON.stringify(sent.body)).toBe(201);
    await advance(301, s);
    await pk.tick();
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        PK_SCORE_BROADCAST_MS: '0',
        PK_EFFECTIVE_MIN_POINTS: '0',
        PK_REMATCH_MAX: '2',
      },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
    pk = ctx.app.get(LivePkService);
    gift = `d242_${randomUUID().slice(0, 6)}`;
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, gift, {
        category: 'POPULAR',
        nameAr: 'هدية',
        nameEn: 'Gift',
        priceCoins: 100,
        assetKey: `gift_${gift}`,
        animationKey: null,
        sortOrder: 1,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
    // The DARES rematch needs a dare library (4 per level from the seed).
    const lines = readFileSync(new URL('../prisma/seed/pk-dares/pk-dares.v1.jsonl', import.meta.url), 'utf8')
      .split('\n')
      .filter((l) => l.trim().length > 0)
      .map((l) => parseDareImport(JSON.parse(l)) as PkDareImport);
    const library = (['EASY', 'MEDIUM', 'HARD'] as const).flatMap((level) =>
      lines.filter((d) => d.level === level && d.category === 'IMITATION').slice(0, 4),
    );
    await withMigrationClient(async (db) => {
      await db.$transaction(
        (tx) =>
          importPkDaresIn(tx, library, {
            dryRun: false,
            reason: 'd242 e2e',
            actor: { userId: null, via: 'cli' },
            createdBy: 'SEED',
          }),
        { timeout: 120_000 },
      );
      await db.pkDare.updateMany({
        where: { code: { in: library.map((d) => d.code) } },
        data: { active: true, reportCount: 0, disabledReason: null },
      });
    });
  });
  afterAll(async () => ctx?.close());

  it('offer → accept: a new battle between the same rooms, from zero; the old match closes quietly', async () => {
    const s = await battle();
    const first = await forfeit(s);
    expect(first.rematch).toBeNull();
    expect(first.rematchesLeft).toBe(2);
    const o = await offer(s.roomA, s.a);
    expect(o.status, JSON.stringify(o.body)).toBe(200);
    expectContract(o, 'offerLivePkRematch');
    expect(o.body.rematch).toMatchObject({ byRoomId: s.roomA });
    expect(Date.parse(o.body.rematch.expiresAt) - clock.now().getTime()).toBe(15_000);
    expect(events(s.roomB).at(-1)).toMatchObject({
      event: 'rematch-offer',
      match: { rematch: { byRoomId: s.roomA } },
    });
    // Idempotent: the same offer again.
    expect((await offer(s.roomA, s.a)).body.rematch.byRoomId).toBe(s.roomA);
    // The asking host cannot accept their own offer.
    expectError(await accept(s.roomA, s.a), 409, 'PK_REMATCH_CLOSED', 'acceptLivePkRematch');

    const acc = await accept(s.roomB, s.b);
    expect(acc.status, JSON.stringify(acc.body)).toBe(200);
    expectContract(acc, 'acceptLivePkRematch');
    const next = acc.body as Match;
    expect(next.id).not.toBe(first.id);
    expect(next).toMatchObject({
      status: 'BATTLE',
      rematchOf: first.id,
      rematchCount: 1,
      rematchesLeft: 1,
      rematch: null,
      mode: first.mode,
      roundSeconds: first.roundSeconds,
    });
    expect(next.sides.map((x) => x.roomId)).toEqual([s.roomA, s.roomB]);
    expect(next.sides.map((x) => x.score)).toEqual([0, 0]);
    for (const side of next.sides) expect(Object.values(side.boosterUses).every((n) => n === 0)).toBe(true);
    expect((await ctx.prisma.pkMatch.findUniqueOrThrow({ where: { id: first.id } })).status).toBe('CLOSED');
    expect((await state(s.roomA, s.a))!.id).toBe(next.id);
    // Both rooms: `rematch` with the new match; no `closed` for the old one (the media stays).
    for (const room of [s.roomA, s.roomB]) {
      expect(events(room).at(-1)).toMatchObject({ event: 'rematch', match: { id: next.id } });
      expect(events(room).some((e) => e.event === 'closed' && e.match.id === first.id)).toBe(false);
    }
    // The chain's PK watchers stay valid (an identity of the first match).
    expect(await pk.allowsWatcher(s.roomB, `pk:${first.id}:${randomUUID()}`)).toBe(true);
    // Idempotent accept: the new battle as it is; an offer during the rematch's battle too.
    expect((await accept(s.roomB, s.b)).body.id).toBe(next.id);
    expect((await offer(s.roomA, s.a)).body.id).toBe(next.id);
    // Each battle counts: B won the forfeit, the rematch counts once it ends.
    await forfeit(s);
    const rec = await call('get', 'me/live-pk', s.b);
    expect(rec.body.record).toMatchObject({ wins: 2 });
  });

  it('offer → decline: the PK closes; the asking host is told', async () => {
    const s = await battle();
    await forfeit(s);
    expect((await offer(s.roomB, s.b)).status).toBe(200);
    const d = await decline(s.roomA, s.a);
    expect(d.status, JSON.stringify(d.body)).toBe(204);
    const evs = events(s.roomB).map((e) => e.event);
    expect(evs.slice(-2)).toEqual(['rematch-declined', 'closed']);
    expect(await state(s.roomA, s.a)).toBeNull();
    expectError(await decline(s.roomA, s.a), 409, 'PK_NOT_ACTIVE', 'declineLivePkRematch');
  });

  it('offer → no answer in 15 s: it lapses and the PK closes', async () => {
    const s = await battle();
    await forfeit(s);
    expect((await offer(s.roomA, s.a)).status).toBe(200);
    // The result stays open while the offer runs, even past its own 60 s.
    await advance(14, s);
    await pk.tick();
    expect((await state(s.roomA, s.a))!.rematch).not.toBeNull();
    await advance(2, s);
    await pk.tick();
    expect(
      events(s.roomA)
        .map((e) => e.event)
        .slice(-2),
    ).toEqual(['rematch-expired', 'closed']);
    expect(await state(s.roomA, s.a)).toBeNull();
    expectError(await accept(s.roomB, s.b), 409, 'PK_NOT_ACTIVE');
  });

  it('both tap «جولة أخرى»: the second tap is an acceptance', async () => {
    const s = await battle();
    await forfeit(s);
    expect((await offer(s.roomA, s.a)).status).toBe(200);
    const both = await offer(s.roomB, s.b);
    expect(both.status).toBe(200);
    expect(both.body).toMatchObject({ status: 'BATTLE', rematchCount: 1 });
  });

  it('withdrawn: the offer ends, the result goes on, an accept is refused', async () => {
    const s = await battle();
    await forfeit(s);
    expect((await offer(s.roomA, s.a)).status).toBe(200);
    expectError(await call('delete', `live/rooms/${s.roomB}/pk/rematch`, s.b), 409, 'PK_REMATCH_CLOSED');
    const c = await call('delete', `live/rooms/${s.roomA}/pk/rematch`, s.a);
    expect(c.status, JSON.stringify(c.body)).toBe(200);
    expectContract(c, 'cancelLivePkRematch');
    expect(c.body).toMatchObject({ status: 'RESULT', rematch: null });
    expect(events(s.roomB).at(-1)?.event).toBe('rematch-cancelled');
    expectError(await accept(s.roomB, s.b), 409, 'PK_REMATCH_CLOSED');
  });

  it('no offer during the battle, with a host away, or past the limit in a row', async () => {
    const s = await battle();
    expectError(await offer(s.roomA, s.a), 409, 'PK_REMATCH_UNAVAILABLE', 'offerLivePkRematch');
    await forfeit(s);
    // B's app went to the background (D170 away): no rematch.
    const away = await call('post', `live/rooms/${s.roomB}/host-presence`, s.b, { away: true });
    expect(away.status).toBe(204);
    expectError(await offer(s.roomA, s.a), 409, 'PK_REMATCH_UNAVAILABLE');
    expect((await call('post', `live/rooms/${s.roomB}/host-presence`, s.b, { away: false })).status).toBe(
      204,
    );
    // PK_REMATCH_MAX = 2: two rematches, then none.
    for (const n of [1, 2]) {
      expect((await offer(s.roomA, s.a)).status).toBe(200);
      const r = await accept(s.roomB, s.b);
      expect(r.body).toMatchObject({ status: 'BATTLE', rematchCount: n, rematchesLeft: 2 - n });
      await forfeit(s);
    }
    expectError(await offer(s.roomA, s.a), 409, 'PK_REMATCH_UNAVAILABLE');
    expect((await state(s.roomA, s.a))!.rematchesLeft).toBe(0);
  });

  it('a DARES rematch: only after the dare is over, then the new battle has its own dare', async () => {
    const s = await battle('DARES');
    await timeUp(s);
    const first = (await state(s.roomA, s.a))!;
    expect(first.dare).not.toBeNull();
    // The dare runs: no rematch yet.
    expectError(await offer(s.roomB, s.b), 409, 'PK_REMATCH_UNAVAILABLE');
    await advance(5, s);
    const refused = await call('post', `live/rooms/${s.roomA}/pk/dare/refuse`, s.a);
    expect(refused.status, JSON.stringify(refused.body)).toBe(200);
    expect((await offer(s.roomB, s.b)).status).toBe(200);
    const next = (await accept(s.roomA, s.a)).body as Match;
    expect(next).toMatchObject({ status: 'BATTLE', type: 'DARES', dare: null, rematchOf: first.id });
    await timeUp(s);
    const second = (await state(s.roomA, s.a))!;
    expect(second.id).toBe(next.id);
    expect(second.status).toBe('RESULT');
    expect(second.dare).not.toBeNull();
  });

  it("D276 «نقاط PK»: both hosts' PK points on their sides, for both rooms and viewers", async () => {
    const s = await battle();
    expect(s.match.sides.map((x) => x.pkPoints)).toEqual([0, 0]);
    // B wins the forfeit: +3 (the default win); A withdrew: −3 (D276).
    const ended = await forfeit(s);
    expect(ended.sides.map((x) => x.pkPoints)).toEqual([-3, 3]);
    expect(ended.forfeitPoints).toBe(-3);
    for (const [room, u] of [
      [s.roomA, s.a],
      [s.roomB, s.b],
    ] as const) {
      expect((await state(room, u))!.sides.map((x) => x.pkPoints)).toEqual([-3, 3]);
    }
    // A viewer of A's room reads B's points too.
    const viewer = await signup();
    expect((await state(s.roomA, viewer))!.sides.map((x) => x.pkPoints)).toEqual([-3, 3]);
    // The rematch's battle starts with the points so far.
    expect((await offer(s.roomA, s.a)).status).toBe(200);
    const next = (await accept(s.roomB, s.b)).body as Match;
    expect(next.sides.map((x) => x.pkPoints)).toEqual([-3, 3]);
  });

  it("D276: after a DARES match's dare, a whole result phase is left for «جولة أخرى»", async () => {
    const s = await battle('DARES');
    await timeUp(s);
    await advance(5, s);
    const refused = await call('post', `live/rooms/${s.roomA}/pk/dare/refuse`, s.a);
    expect(refused.status, JSON.stringify(refused.body)).toBe(200);
    const after = (await state(s.roomA, s.a))!;
    expect(Date.parse(after.resultEndsAt!) - clock.now().getTime()).toBeGreaterThanOrEqual(60_000);
    // Still there 30 s later (before D276 the PK closed 8 s after the dare).
    await advance(30, s);
    await pk.tick();
    expect((await state(s.roomA, s.a))!.status).toBe('RESULT');
    expect((await offer(s.roomB, s.b)).status).toBe(200);
  });

  const record = async (u: TestUser) =>
    (await call('get', 'me/live-pk', u)).body.record as {
      wins: number;
      losses: number;
      draws: number;
      points: number;
    };

  it('D276 «انسحاب = −3»: the host who ends during the battle gets −3 and a loss; the other +3 and a win', async () => {
    const s = await battle();
    await forfeit(s);
    expect(await record(s.a)).toMatchObject({ wins: 0, losses: 1, draws: 0, points: -3 });
    expect(await record(s.b)).toMatchObject({ wins: 1, losses: 0, points: 3 });
    const row = await ctx.prisma.pkPointEvent.findMany({ where: { hostId: s.a.id } });
    expect(row.map((r) => [r.kind, r.points])).toEqual([['LOSS', -3]]);
  });

  it('D276: both hosts away (both withdrew) → both −3 and a loss, no draw', async () => {
    const s = await battle();
    for (const [room, u] of [
      [s.roomA, s.a],
      [s.roomB, s.b],
    ] as const) {
      expect((await call('post', `live/rooms/${room}/host-presence`, u, { away: true })).status).toBe(204);
    }
    await advance(31, s);
    await pk.tick();
    const m = (await state(s.roomA, s.a))!;
    expect(m.status).toBe('RESULT');
    expect(m.sides.map((x) => x.pkPoints)).toEqual([-3, -3]);
    for (const u of [s.a, s.b])
      expect(await record(u)).toMatchObject({ losses: 1, draws: 0, wins: 0, points: -3 });
  });

  it('D276: ending in the result phase is not a withdrawal (the loss stays 0)', async () => {
    const s = await battle();
    await timeUp(s);
    expect((await state(s.roomA, s.a))!.status).toBe('RESULT');
    const end = await call('post', `live/rooms/${s.roomA}/pk/end`, s.a);
    expect(end.status, JSON.stringify(end.body)).toBe(200);
    expect(end.body.status).toBe('CLOSED');
    expect(await record(s.a)).toMatchObject({ losses: 1, points: 0 });
    expect(await record(s.b)).toMatchObject({ wins: 1, points: 3 });
  });

  it('D276: the panel value is used (forfeitPoints −5), and the match says it', async () => {
    await ctx.prisma.pkDareSettings.upsert({
      where: { id: 1 },
      create: { id: 1, forfeitPoints: -5 },
      update: { forfeitPoints: -5 },
    });
    try {
      const s = await battle();
      expect(s.match.forfeitPoints).toBe(-5);
      await forfeit(s);
      expect(await record(s.a)).toMatchObject({ losses: 1, points: -5 });
    } finally {
      await ctx.prisma.pkDareSettings.deleteMany({ where: { id: 1 } });
    }
  });
});
