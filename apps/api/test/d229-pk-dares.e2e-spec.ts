/**
 * D229 (v1.50-live, CONVENTIONS §10.80): «PK أحكام» on top of D195 / D199 — the DARES type on invitations and the
 * random queue, lucky gifts worth 0 PK points in DARES only, the server's draw (one dare per level, the same for both
 * rooms, no repeats per host, a new cycle when a level is used up), the loser's accept / refuse / timeout, the
 * winner's verdict (done / not done / none by the timer's end), the loser or the winner leaving, the PK points
 * (+3 / +1 / 0 / −3, idempotent, audited), a draw giving no dare, reports with the automatic disable and their rate
 * limit. Same harness as D195 / D199: an in-memory media server, a FakeClock and the PK tick run by hand.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { LivePkService } from '../src/modules/live/live-pk.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { addPkPointsIn } from '../src/modules/live/pk-dares/pk-dare-match.js';
import { raiseMedalLevelsIn } from '../src/modules/medals/medal-awards.js';
import { importPkDaresIn } from '../src/modules/live/pk-dares/pk-dare-library.js';
import { parseDareImport, type PkDareImport } from '../src/modules/live/pk-dares/pk-dare-rules.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { seedMedalCatalogue } from './helpers/medals.js';
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
interface Dare {
  status: string;
  cause: string | null;
  loserRoomId: string;
  winnerRoomId: string;
  options: { id: string; level: string; textAr: string; textEn: string }[];
  drawn: number;
  revealAt: string;
  decideBy: string;
  startedAt: string | null;
  endsAt: string | null;
  points: number;
}
interface Match {
  id: string;
  status: string;
  type: string;
  winnerRoomId: string | null;
  sides: [{ roomId: string; score: number }, { roomId: string; score: number }];
  dare: Dare | null;
  seq: number;
}

/** Four dares per level from the real seed file (the e2e library). */
function testLibrary(): PkDareImport[] {
  const lines = readFileSync(new URL('../prisma/seed/pk-dares/pk-dares.v1.jsonl', import.meta.url), 'utf8')
    .split('\n')
    .filter((l) => l.trim().length > 0)
    .map((l) => parseDareImport(JSON.parse(l)) as PkDareImport);
  return (['EASY', 'MEDIUM', 'HARD'] as const).flatMap((level) =>
    lines.filter((d) => d.level === level && d.category === 'IMITATION').slice(0, 4),
  );
}

describe('D229 «PK أحكام»', { timeout: 600_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let pk: LivePkService;
  let seq = 0;
  let normalGift = '';
  let luckyGift = '';
  let library: PkDareImport[] = [];

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
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'PK أحكام' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
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
  const call = (
    method: 'get' | 'post' | 'put' | 'delete',
    path: string,
    u: TestUser | null,
    body?: object,
  ) => {
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
  const advance = async (seconds: number, ...pairs: [string, TestUser][]) => {
    let left = seconds;
    while (left > 0) {
      const step = Math.min(left, 15);
      clock.advance(step);
      left -= step;
      for (const [room, u] of pairs) await heartbeat(room, u);
    }
  };
  const gift = async (fields: Partial<GiftFields> = {}): Promise<string> => {
    seq += 1;
    const code = `d229_${String(seq)}_${randomUUID().slice(0, 6)}`;
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: `هدية ${String(seq)}`,
        nameEn: `Gift ${String(seq)}`,
        priceCoins: 100,
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
  const fan = async (amount: number, ...rooms: string[]) => {
    const u = await signup();
    await ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
    for (const r of rooms) await webhook('participant_joined', r, u.id);
    return u;
  };
  const send = (roomId: string, u: TestUser, code: string, to: TestUser) =>
    call('post', `live/rooms/${roomId}/gifts`, u, {
      giftCode: code,
      quantity: 1,
      recipients: [to.username],
      source: 'COINS',
      clientId: randomUUID(),
    });
  const state = async (room: string, u: TestUser | null): Promise<Match | null> => {
    const res = await call('get', `live/rooms/${room}/pk`, u);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getLivePk');
    return res.body.match as Match | null;
  };
  const pkMessages = (roomId: string) =>
    media.broadcasts
      .filter((b) => b.room === roomId && b.topic === 'pk')
      .map((b) => JSON.parse(b.payload) as { type: string; event: string; match: Match });
  const record = async (u: TestUser) => {
    const res = await call('get', 'me/live-pk', u);
    expect(res.status).toBe(200);
    expectContract(res, 'getMyLivePk');
    return res.body.record as {
      wins: number;
      losses: number;
      draws: number;
      points: number;
      daresDone: number;
      daresRefused: number;
    };
  };

  /** Two hosts in a «PK أحكام» battle (A invited B). */
  const dareBattle = async () => {
    const [a, b] = [await host(), await host()];
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    const inv = await call('post', `live/rooms/${roomA}/pk/invites`, a, { toRoomId: roomB, type: 'DARES' });
    expect(inv.status, JSON.stringify(inv.body)).toBe(201);
    expectContract(inv, 'inviteLivePk');
    const acc = await call('post', `live/rooms/${roomB}/pk/invites/${inv.body.id as string}/accept`, b);
    expect(acc.status, JSON.stringify(acc.body)).toBe(200);
    return { a, b, roomA, roomB, match: acc.body as Match, inviteBody: inv.body as { type: string } };
  };
  /** A battle that B wins by one gift; then the time runs out (tick) → the draw. */
  const dareResult = async () => {
    const s = await dareBattle();
    const f = await fan(10_000, s.roomB);
    const sent = await send(s.roomB, f, normalGift, s.b);
    expect(sent.status, JSON.stringify(sent.body)).toBe(201);
    await advance(301, [s.roomA, s.a], [s.roomB, s.b]);
    await pk.tick();
    const m = (await state(s.roomA, s.a))!;
    return { ...s, f, m };
  };
  const reveal = async (s: { roomA: string; a: TestUser; roomB: string; b: TestUser }) =>
    advance(5, [s.roomA, s.a], [s.roomB, s.b]);

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        PK_SCORE_BROADCAST_MS: '0',
        PK_EFFECTIVE_MIN_POINTS: '0',
        LUCKY_GIFTS_ENABLED: 'true',
        RATE_LIMIT_LIVE_PK_DARE_REPORT_USER: '3/600',
      },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
    pk = ctx.app.get(LivePkService);
    normalGift = await gift();
    luckyGift = await gift({ category: 'LUCKY', priceCoins: 10 });
    // The e2e library: only these 12 dares (4 per level) are active.
    library = testLibrary();
    await withMigrationClient(async (db) => {
      await db.$executeRaw`UPDATE pk_dares SET active = false`;
      await db.$transaction(
        (tx) =>
          importPkDaresIn(tx, library, {
            dryRun: false,
            reason: 'd229 e2e',
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

  it('openapi v1.50-live declares the dare operations and the panel «أحكام PK»', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'acceptLivePkDare POST /api/v1/live/rooms/{roomId}/pk/dare/accept',
        'refuseLivePkDare POST /api/v1/live/rooms/{roomId}/pk/dare/refuse',
        'judgeLivePkDare POST /api/v1/live/rooms/{roomId}/pk/dare/verdict',
        'reportLivePkDare POST /api/v1/live/rooms/{roomId}/pk/dare/report',
        'listAdminPkDares GET /api/v1/admin/pk-dares',
        'createAdminPkDare POST /api/v1/admin/pk-dares',
        'importAdminPkDares POST /api/v1/admin/pk-dares/import',
        'updateAdminPkDare PATCH /api/v1/admin/pk-dares/{dareId}',
        'clearAdminPkDareReports POST /api/v1/admin/pk-dares/{dareId}/reports/clear',
        'getAdminPkDareSettings GET /api/v1/admin/pk-dare-settings',
        'updateAdminPkDareSettings PUT /api/v1/admin/pk-dare-settings',
      ]),
    );
  });

  it('an invitation offers «PK أحكام»: the invited host sees the type, the match keeps it; a bad type is 400', async () => {
    const s = await dareBattle();
    expect(s.inviteBody.type).toBe('DARES');
    const told = media.data.find((m) => m.room === s.roomB && JSON.parse(m.payload).type === 'pk-invite');
    expect(JSON.parse(told!.payload).invite.type).toBe('DARES');
    expect(s.match.type).toBe('DARES');
    expect(s.match.dare).toBeNull();
    const [c, d] = [await host(), await host()];
    const roomC = await goLive(c);
    const roomD = await goLive(d);
    expectError(
      await call('post', `live/rooms/${roomC}/pk/invites`, c, { toRoomId: roomD, type: 'FUN' }),
      400,
      'VALIDATION_FAILED',
    );
    const normal = await call('post', `live/rooms/${roomC}/pk/invites`, c, { toRoomId: roomD });
    expect(normal.body.type).toBe('NORMAL');
  });

  it('random: a DARES waiter is paired only with a DARES waiter (and NORMAL with NORMAL)', async () => {
    await ctx.prisma.pkQueueEntry.deleteMany({});
    const [n1, d1, d2, n2] = [await host(), await host(), await host(), await host()];
    const [rn1, rd1, rd2, rn2] = [await goLive(n1), await goLive(d1), await goLive(d2), await goLive(n2)];
    const w1 = await call('post', `live/rooms/${rn1}/pk/random`, n1);
    expect(w1.body.status).toBe('WAITING');
    expect(w1.body.queue.type).toBe('NORMAL');
    const w2 = await call('post', `live/rooms/${rd1}/pk/random`, d1, { type: 'DARES' });
    expectContract(w2, 'joinLivePkRandom');
    expect(w2.body).toMatchObject({ status: 'WAITING', queue: { type: 'DARES' } });
    const m = await call('post', `live/rooms/${rd2}/pk/random`, d2, { type: 'DARES' });
    expect(m.body.status).toBe('MATCHED');
    expect(m.body.match.type).toBe('DARES');
    expect(m.body.match.sides.map((x: { roomId: string }) => x.roomId)).toEqual([rd1, rd2]);
    const n = await call('post', `live/rooms/${rn2}/pk/random`, n2);
    expect(n.body.status).toBe('MATCHED');
    expect(n.body.match.type).toBe('NORMAL');
    expect(n.body.match.sides[0].roomId).toBe(rn1);
  });

  it('lucky gifts give 0 PK points in «PK أحكام» only (still charged as gifts); normal PK keeps counting them', async () => {
    const s = await dareBattle();
    const f = await fan(50_000, s.roomA);
    const conf = await call('put', 'me/lucky-gifts/age-confirmation', f, { adult: true });
    expect(conf.status, JSON.stringify(conf.body)).toBe(200);
    const before = (await ctx.prisma.wallet.findUnique({ where: { userId: f.id } }))?.coins;
    const lucky = await send(s.roomA, f, luckyGift, s.a);
    expect(lucky.status, JSON.stringify(lucky.body)).toBe(201);
    const after = (await ctx.prisma.wallet.findUnique({ where: { userId: f.id } }))?.coins;
    expect(before! > after!, 'the lucky gift is charged').toBe(true);
    expect((await state(s.roomA, s.a))!.sides[0].score).toBe(0);
    expect(await ctx.prisma.pkGiftPoint.count({ where: { matchId: s.match.id } })).toBe(0);
    // Still a gift: stored, and the host's cherries credited with its real value.
    expect(await ctx.prisma.liveGift.count({ where: { roomId: s.roomA, giftCode: luckyGift } })).toBe(1);
    expect(
      await ctx.prisma.cherryLedgerEntry.count({ where: { userId: s.a.id, reason: 'GIFT_RECEIVED' } }),
    ).toBeGreaterThan(0);
    expect((await send(s.roomA, f, normalGift, s.a)).status).toBe(201);
    expect((await state(s.roomA, s.a))!.sides[0].score).toBe(100);
    // The same lucky gift in a normal PK counts its coin value.
    const [c, d] = [await host(), await host()];
    const roomC = await goLive(c);
    const roomD = await goLive(d);
    const inv = await call('post', `live/rooms/${roomC}/pk/invites`, c, { toRoomId: roomD });
    await call('post', `live/rooms/${roomD}/pk/invites/${inv.body.id as string}/accept`, d);
    await webhook('participant_joined', roomC, f.id);
    expect((await send(roomC, f, luckyGift, c)).status).toBe(201);
    expect((await state(roomC, c))!.sides[0].score).toBe(10);
  });

  it('a draw gives no dare; both hosts get +1 PK point', async () => {
    const s = await dareBattle();
    await advance(301, [s.roomA, s.a], [s.roomB, s.b]);
    await pk.tick();
    const m = (await state(s.roomA, s.a))!;
    expect(m.status).toBe('RESULT');
    expect(m.winnerRoomId).toBeNull();
    expect(m.dare).toBeNull();
    expect(await record(s.a)).toMatchObject({ draws: 1, points: 1 });
    expect(await record(s.b)).toMatchObject({ draws: 1, points: 1 });
  });

  it('the draw: one dare per level, the same for both rooms, revealed after the shuffle; loser accepts, winner judges «نُفّذ»', async () => {
    pk.darePick = () => 2;
    const s = await dareResult();
    pk.darePick = null;
    expect(s.m.winnerRoomId).toBe(s.roomB);
    const dare = s.m.dare!;
    expect(dare.status).toBe('DRAWING');
    expect(dare.options.map((o) => o.level)).toEqual(['EASY', 'MEDIUM', 'HARD']);
    expect(dare.drawn).toBe(2);
    expect(dare).toMatchObject({ loserRoomId: s.roomA, winnerRoomId: s.roomB, points: 0 });
    const inA = pkMessages(s.roomA)
      .filter((x) => x.match.id === s.m.id && x.match.dare !== null)
      .at(-1)!;
    const inB = pkMessages(s.roomB)
      .filter((x) => x.match.id === s.m.id && x.match.dare !== null)
      .at(-1)!;
    expect(inA.match.dare!.drawn).toBe(inB.match.dare!.drawn);
    expect(inA.match.dare!.options).toEqual(inB.match.dare!.options);
    const viewer = await signup();
    expect((await state(s.roomB, viewer))!.dare!.options).toEqual(dare.options);
    // Before the reveal nobody can answer; the winner never can.
    expectError(
      await call('post', `live/rooms/${s.roomA}/pk/dare/accept`, s.a),
      409,
      'PK_DARE_CLOSED',
      'acceptLivePkDare',
    );
    await reveal(s);
    expectError(
      await call('post', `live/rooms/${s.roomB}/pk/dare/accept`, s.b),
      403,
      'PK_DARE_FORBIDDEN',
      'acceptLivePkDare',
    );
    expectError(
      await call('post', `live/rooms/${s.roomB}/pk/dare/verdict`, s.b, { done: true }),
      409,
      'PK_DARE_CLOSED',
    );
    const acc = await call('post', `live/rooms/${s.roomA}/pk/dare/accept`, s.a);
    expect(acc.status, JSON.stringify(acc.body)).toBe(200);
    expectContract(acc, 'acceptLivePkDare');
    expect(acc.body.dare.status).toBe('ACTIVE');
    expect(new Date(acc.body.dare.endsAt).getTime() - new Date(acc.body.dare.startedAt).getTime()).toBe(
      180_000,
    );
    expect((await call('post', `live/rooms/${s.roomA}/pk/dare/accept`, s.a)).status).toBe(200);
    // After accepting the loser cannot refuse; only the winner judges.
    expectError(await call('post', `live/rooms/${s.roomA}/pk/dare/refuse`, s.a), 409, 'PK_DARE_CLOSED');
    expectError(
      await call('post', `live/rooms/${s.roomA}/pk/dare/verdict`, s.a, { done: true }),
      403,
      'PK_DARE_FORBIDDEN',
    );
    expectError(
      await call('post', `live/rooms/${s.roomB}/pk/dare/verdict`, viewer, { done: true }),
      404,
      'NOT_FOUND',
    );
    await advance(60, [s.roomA, s.a], [s.roomB, s.b]);
    const v = await call('post', `live/rooms/${s.roomB}/pk/dare/verdict`, s.b, { done: true });
    expect(v.status, JSON.stringify(v.body)).toBe(200);
    expectContract(v, 'judgeLivePkDare');
    expect(v.body.dare).toMatchObject({ status: 'DONE', cause: 'WINNER_DONE', points: 0 });
    expect((await call('post', `live/rooms/${s.roomB}/pk/dare/verdict`, s.b, { done: true })).status).toBe(
      200,
    );
    expectError(
      await call('post', `live/rooms/${s.roomB}/pk/dare/verdict`, s.b, { done: false }),
      409,
      'PK_DARE_CLOSED',
    );
    expect(await record(s.b)).toMatchObject({ wins: 1, points: 3 });
    expect(await record(s.a)).toMatchObject({ losses: 1, points: 0, daresDone: 1, daresRefused: 0 });
    // Both rooms were told; the PK stays open for the outcome, then closes.
    expect(
      pkMessages(s.roomA).filter((x) => x.event === 'dare' && x.match.id === s.m.id).length,
    ).toBeGreaterThanOrEqual(2);
    expect((await state(s.roomA, s.a))!.status).toBe('RESULT');
    await advance(61, [s.roomA, s.a], [s.roomB, s.b]);
    await pk.tick();
    expect(await state(s.roomA, s.a)).toBeNull();
    const audits = await ctx.prisma.auditLog.findMany({
      where: { targetId: s.m.id },
      select: { action: true },
    });
    expect(audits.map((x) => x.action)).toEqual(
      expect.arrayContaining([
        'live.pk.dare.draw',
        'live.pk.dare.answer',
        'live.pk.dare.verdict',
        'live.pk.points',
      ]),
    );
  });

  it('the draw is fair: crypto random over the three cards (no fixed card)', async () => {
    const counts = [0, 0, 0];
    for (let i = 0; i < 9; i += 1) {
      const s = await dareResult();
      counts[s.m.dare!.drawn] = (counts[s.m.dare!.drawn] ?? 0) + 1;
      expect(s.m.dare!.options[s.m.dare!.drawn]!.id).toBeDefined();
      const row = await ctx.prisma.pkMatchDare.findUniqueOrThrow({ where: { matchId: s.m.id } });
      expect(row.dareId).toBe(row.optionIds[row.drawn]);
    }
    expect(counts.reduce((x, y) => x + y, 0)).toBe(9);
    expect(counts.filter((n) => n > 0).length).toBeGreaterThanOrEqual(2);
  });

  it('the loser refuses «رفض»: −3 PK points at once, no verdict for the winner', async () => {
    const s = await dareResult();
    await reveal(s);
    const r = await call('post', `live/rooms/${s.roomA}/pk/dare/refuse`, s.a);
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expectContract(r, 'refuseLivePkDare');
    expect(r.body.dare).toMatchObject({ status: 'REFUSED', cause: 'LOSER_REFUSED', points: -3 });
    expect((await call('post', `live/rooms/${s.roomA}/pk/dare/refuse`, s.a)).status).toBe(200);
    expectError(
      await call('post', `live/rooms/${s.roomB}/pk/dare/verdict`, s.b, { done: true }),
      409,
      'PK_DARE_CLOSED',
    );
    expectError(await call('post', `live/rooms/${s.roomA}/pk/dare/accept`, s.a), 409, 'PK_DARE_CLOSED');
    expect(await record(s.a)).toMatchObject({ losses: 1, points: -3, daresRefused: 1, daresDone: 0 });
  });

  it('no answer within the decision time (30 s) counts as refused', async () => {
    const s = await dareResult();
    await advance(5 + 31, [s.roomA, s.a], [s.roomB, s.b]);
    await pk.tick();
    const m = (await state(s.roomA, s.a))!;
    expect(m.dare).toMatchObject({ status: 'REFUSED', cause: 'DECIDE_TIMEOUT', points: -3 });
    expect(await record(s.a)).toMatchObject({ points: -3, daresRefused: 1 });
  });

  it('the winner judges «لم يُنفّذ»: counted as refused (−3)', async () => {
    const s = await dareResult();
    await reveal(s);
    expect((await call('post', `live/rooms/${s.roomA}/pk/dare/accept`, s.a)).status).toBe(200);
    const v = await call('post', `live/rooms/${s.roomB}/pk/dare/verdict`, s.b, { done: false });
    expect(v.body.dare).toMatchObject({ status: 'REFUSED', cause: 'WINNER_NOT_DONE', points: -3 });
    expect(await record(s.a)).toMatchObject({ points: -3, daresRefused: 1 });
  });

  it('no verdict by the timer end counts as done; the winner leaving changes nothing', async () => {
    const s = await dareResult();
    await reveal(s);
    expect((await call('post', `live/rooms/${s.roomA}/pk/dare/accept`, s.a)).status).toBe(200);
    // The winner ends their live: the dare keeps running in the loser's room.
    expect((await call('post', `live/rooms/${s.roomB}/end`, s.b)).status).toBe(200);
    await advance(90, [s.roomA, s.a]);
    await pk.tick();
    expect((await state(s.roomA, s.a))!.dare!.status).toBe('ACTIVE');
    await advance(91, [s.roomA, s.a]);
    await pk.tick();
    const m = (await state(s.roomA, s.a))!;
    expect(m.dare).toMatchObject({ status: 'DONE', cause: 'TIMER', points: 0 });
    expect(await record(s.a)).toMatchObject({ daresDone: 1, points: 0 });
    expectError(
      await call('post', `live/rooms/${s.roomB}/pk/dare/verdict`, s.b, { done: false }),
      409,
      'PK_DARE_CLOSED',
    );
  });

  it('the loser ending their live during the dare: not done (−3)', async () => {
    const s = await dareResult();
    await reveal(s);
    expect((await call('post', `live/rooms/${s.roomA}/pk/dare/accept`, s.a)).status).toBe(200);
    expect((await call('post', `live/rooms/${s.roomA}/end`, s.a)).status).toBe(200);
    await pk.tick();
    const row = await ctx.prisma.pkMatchDare.findUniqueOrThrow({ where: { matchId: s.m.id } });
    expect(row).toMatchObject({ status: 'REFUSED', cause: 'LOSER_LEFT', points: -3 });
    expect(await record(s.a)).toMatchObject({ points: -3, daresRefused: 1 });
  });

  it('the loser ending the PK (End) while deciding: refused (−3)', async () => {
    const s = await dareResult();
    await reveal(s);
    const e = await call('post', `live/rooms/${s.roomA}/pk/end`, s.a);
    expect(e.status, JSON.stringify(e.body)).toBe(200);
    expect(e.body.dare).toMatchObject({ status: 'REFUSED', cause: 'LOSER_LEFT' });
    expect(e.body.status).toBe('CLOSED');
  });

  it('no repeats per host until a level is used up, then a new cycle', async () => {
    const [loser, winner] = [await host(), await host()];
    const seen = new Set<string>();
    for (let round = 0; round < 5; round += 1) {
      const roomL = await goLive(loser);
      const roomW = await goLive(winner);
      const inv = await call('post', `live/rooms/${roomL}/pk/invites`, loser, {
        toRoomId: roomW,
        type: 'DARES',
      });
      expect(inv.status, JSON.stringify(inv.body)).toBe(201);
      await call('post', `live/rooms/${roomW}/pk/invites/${inv.body.id as string}/accept`, winner);
      const f = await fan(1000, roomW);
      await send(roomW, f, normalGift, winner);
      await advance(301, [roomL, loser], [roomW, winner]);
      await pk.tick();
      const m = (await state(roomL, loser))!;
      const ids = m.dare!.options.map((o) => o.id);
      if (round < 4) {
        for (const id of ids) {
          expect(seen.has(id), `round ${String(round)} repeated ${id}`).toBe(false);
          seen.add(id);
        }
      } else {
        // 4 per level in the test library: the fifth draw starts the loser's new cycle.
        const row = await ctx.prisma.pkDareSeen.findUniqueOrThrow({ where: { hostId: loser.id } });
        expect(row.cycles).toBeGreaterThanOrEqual(1);
      }
      await call('post', `live/rooms/${roomL}/pk/end`, loser);
      await call('post', `live/rooms/${roomL}/end`, loser);
      await call('post', `live/rooms/${roomW}/end`, winner);
      await pk.tick();
    }
    expect(seen.size).toBe(12);
    const bits = (await ctx.prisma.pkDareSeen.findUniqueOrThrow({ where: { hostId: winner.id } })).bits;
    // Compact: one bit per dare number (2.5 KB for a fresh 20 000-dare library).
    const [max] = await ctx.prisma.$queryRaw<{ n: number }[]>`SELECT max(seq_no)::int AS n FROM pk_dares`;
    expect(bits.length).toBe(Math.floor(max!.n / 8) + 1);
  });

  it('PK points are written once per match, host and kind (a retry never counts twice)', async () => {
    const s = await dareResult();
    const before = await record(s.b);
    const again = await ctx.prisma.$transaction((tx) =>
      addPkPointsIn(tx, {
        matchId: s.m.id,
        hostId: s.b.id,
        kind: 'WIN',
        points: 3,
        counter: 'wins',
        now: clock.now(),
      }),
    );
    expect(again).toBe(false);
    await pk.tick();
    await pk.tick();
    expect(await record(s.b)).toEqual(before);
    expect(await ctx.prisma.pkPointEvent.count({ where: { matchId: s.m.id } })).toBe(2);
  });

  it('reports: one per person, auto-disabled at the threshold, unknown dares 404, rate limited', async () => {
    const s = await dareResult();
    const dareId = s.m.dare!.options[0]!.id;
    expectError(
      await call('post', `live/rooms/${s.roomA}/pk/dare/report`, s.a, { dareId: randomUUID() }),
      404,
      'NOT_FOUND',
      'reportLivePkDare',
    );
    const first = await call('post', `live/rooms/${s.roomA}/pk/dare/report`, s.a, { dareId });
    expect(first.status).toBe(204);
    expect((await call('post', `live/rooms/${s.roomA}/pk/dare/report`, s.a, { dareId })).status).toBe(204);
    expect((await ctx.prisma.pkDare.findUniqueOrThrow({ where: { id: dareId } })).reportCount).toBe(1);
    expect((await call('post', `live/rooms/${s.roomA}/pk/dare/report`, s.a, { dareId })).status).toBe(429);
    for (let i = 0; i < 4; i += 1) {
      const v = await signup();
      expect((await call('post', `live/rooms/${s.roomB}/pk/dare/report`, v, { dareId })).status).toBe(204);
    }
    const d = await ctx.prisma.pkDare.findUniqueOrThrow({ where: { id: dareId } });
    expect(d).toMatchObject({ reportCount: 5, active: false, disabledReason: 'REPORTS' });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'pk_dare.auto_disable', targetId: dareId } }),
    ).toBe(1);
    expectError(
      await call('post', `live/rooms/${s.roomA}/pk/dare/report`, null, { dareId }),
      401,
      'AUTH_UNAUTHENTICATED',
    );
    await ctx.prisma.pkDare.update({
      where: { id: dareId },
      data: { active: true, disabledReason: null, reportCount: 0 },
    });
  });

  it('host profile: the record and the history show the points and the dare', async () => {
    const s = await dareResult();
    await reveal(s);
    await call('post', `live/rooms/${s.roomA}/pk/dare/refuse`, s.a);
    const res = await call('get', `live/pk/hosts/${s.a.username}`, null);
    expect(res.status).toBe(200);
    expectContract(res, 'getLivePkHost');
    expect(res.body.record).toMatchObject({ points: -3, daresRefused: 1 });
    expect(res.body.recent[0]).toMatchObject({ type: 'DARES', dare: { status: 'REFUSED', mine: true } });
  });

  // D300 «لاعب الأحكام» / Dares Player (owner 2026-11-07: «عندما يكون نقاط PK تحدي = 1500 / 3000 / 5000 / 20000»; owner
  // answer: «PK أحكام» only): the medal follows the host's DARES-match points (`dares_points`) in the very transaction
  // that writes them (real matches through the API); NORMAL-match points never count; a refused dare lowers the points,
  // never the level. The catalogue is seeded here (the last test of this file).
  it('D300 «لاعب الأحكام»: only «PK أحكام» points count — NORMAL never; crossing 1 500 → level 1; a refused dare keeps it; a jump to level 3', async () => {
    await seedMedalCatalogue(ctx.prisma);
    const level = async (u: TestUser) =>
      (
        await ctx.prisma.userMedal.findUnique({
          where: { userId_medalCode: { userId: u.id, medalCode: 'DARES_PLAYER' } },
        })
      )?.level ?? null;
    const preset = (u: TestUser, points: number, daresPoints: number) =>
      ctx.prisma.pkHostRecord.upsert({
        where: { hostId: u.id },
        create: { hostId: u.id, points, daresPoints },
        update: { points, daresPoints },
      });
    const daresPoints = async (u: TestUser) =>
      (await ctx.prisma.pkHostRecord.findUniqueOrThrow({ where: { hostId: u.id } })).daresPoints;
    /** A battle of `type` that B wins by one gift (+3 for B), ended by the time (tick). */
    const battle = async (type: 'NORMAL' | 'DARES') => {
      const [a, b] = [await host(), await host()];
      const roomA = await goLive(a);
      const roomB = await goLive(b);
      const inv = await call('post', `live/rooms/${roomA}/pk/invites`, a, { toRoomId: roomB, type });
      expect(inv.status, JSON.stringify(inv.body)).toBe(201);
      const acc = await call('post', `live/rooms/${roomB}/pk/invites/${inv.body.id as string}/accept`, b);
      expect(acc.status, JSON.stringify(acc.body)).toBe(200);
      return { a, b, roomA, roomB };
    };
    const bWins = async (s: { a: TestUser; b: TestUser; roomA: string; roomB: string }) => {
      const f = await fan(10_000, s.roomB);
      const sent = await send(s.roomB, f, normalGift, s.b);
      expect(sent.status, JSON.stringify(sent.body)).toBe(201);
      await advance(301, [s.roomA, s.a], [s.roomB, s.b]);
      await pk.tick();
    };

    // A NORMAL battle: B at 1 498 (all types and DARES alike) wins +3 — the all-types total passes 1 500, the DARES
    // total stays 1 498: no medal.
    const n = await battle('NORMAL');
    await preset(n.b, 1_498, 1_498);
    await bWins(n);
    expect(await record(n.b)).toMatchObject({ wins: 1, points: 1_501 });
    expect(await daresPoints(n.b)).toBe(1_498);
    expect(await level(n.b)).toBeNull();

    // A «PK أحكام» battle: B at 1 498 DARES points (0 in all) wins +3 → 1 501 DARES points: level 1 at once. A holds
    // level 1 at exactly 1 500 DARES points and refuses the dare (−3).
    const s = await battle('DARES');
    await preset(s.b, 0, 1_498);
    await preset(s.a, 1_500, 1_500);
    await ctx.prisma.$transaction((tx) =>
      raiseMedalLevelsIn(tx, 'PK_DARES_POINTS', [{ userId: s.a.id, value: 1_500 }]),
    );
    expect(await level(s.a)).toBe(1);
    await bWins(s);
    expect(await record(s.b)).toMatchObject({ wins: 1, points: 3 });
    expect(await daresPoints(s.b)).toBe(1_501);
    expect(await level(s.b)).toBe(1);
    expect(
      await ctx.prisma.notification.count({
        where: { recipientId: s.b.id, type: 'MEDAL_AWARDED', medalCode: 'DARES_PLAYER', medalLevel: 1 },
      }),
    ).toBe(1);
    await reveal(s);
    const refused = await call('post', `live/rooms/${s.roomA}/pk/dare/refuse`, s.a);
    expect(refused.status, JSON.stringify(refused.body)).toBe(200);
    expect(await record(s.a)).toMatchObject({ points: 1_497, daresRefused: 1 });
    expect(await daresPoints(s.a)).toBe(1_497);
    expect(await level(s.a)).toBe(1);
    const page = await call('get', 'medals', s.a);
    expect(page.status).toBe(200);
    expectContract(page, 'listMedals');
    const mine = (page.body.data as { code: string }[]).find((m) => m.code === 'DARES_PLAYER');
    // The sheet shows the DARES points; the medal sits with the other medals (owner: «هذه ميداليات»).
    expect(mine).toMatchObject({
      metric: 'PK_DARES_POINTS',
      category: 'ACHIEVEMENT',
      level: 1,
      maxLevel: 4,
      iconAsset: 'medal_dares_player_l1',
      progress: { value: 1_497, next: 3_000, requirements: [] },
      eligible: true,
    });
    const normalPage = await call('get', 'medals', n.b);
    expect((normalPage.body.data as { code: string }[]).find((m) => m.code === 'DARES_PLAYER')).toMatchObject(
      {
        level: 0,
        progress: { value: 1_498, next: 1_500 },
      },
    );

    // A second «PK أحكام» battle: B at 4 998 DARES points wins (+3 → 5 001) — straight to level 3, audited from nothing.
    const s2 = await battle('DARES');
    await preset(s2.b, 4_998, 4_998);
    await bWins(s2);
    expect(await level(s2.b)).toBe(3);
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'medals.level_up', targetId: s2.b.id },
    });
    expect(audit.map((a) => a.metadata)).toEqual([
      expect.objectContaining({
        medalCode: 'DARES_PLAYER',
        from: null,
        to: 3,
        metric: 'PK_DARES_POINTS',
        value: 5_001,
      }),
    ]);
    const top = await call('get', 'medals', s2.b);
    expectContract(top, 'listMedals');
    expect((top.body.data as { code: string }[]).find((m) => m.code === 'DARES_PLAYER')).toMatchObject({
      level: 3,
      iconAsset: 'medal_dares_player_l3',
      progress: { value: 5_001, next: 20_000 },
    });
  });
});
