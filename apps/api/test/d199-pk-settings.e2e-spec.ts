/**
 * D199 (v1.44-live, CONVENTIONS §10.62): the PK Setting page on top of D195's PK — per-host settings, the random
 * choice when two hosts' settings differ, auto-start off (CONNECTED → start / cancel), best of three (rounds,
 * per-round scores and booster limits), the «effective PK» threshold, the random queue's gender and region
 * preferences, Auto Match, suggestions and friends, and the Data Center's gift-givers. Same harness as D195: the
 * media server is an in-memory fake, time is a FakeClock and the PK tick is run by hand.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { LivePkService } from '../src/modules/live/live-pk.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
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
  readonly email: string;
  readonly token: string;
}

interface Side {
  roomId: string;
  score: number;
  totalScore: number;
  roundsWon: number;
  boost: { kind: string; multiplier: number; endsAt: string } | null;
  boosterUses: Record<string, number>;
  supporters: { user: { id: string }; points: number }[];
  guests: { user: { id: string }; seatIndex: number }[];
  mutesOpponent: boolean;
}

interface Match {
  id: string;
  status: string;
  mode: string;
  round: number;
  rounds: number;
  roundSeconds: number;
  startedAt: string;
  battleEndsAt: string;
  connectedAt: string | null;
  settingsFromRoomId: string | null;
  effective: boolean | null;
  endReason: string | null;
  winnerRoomId: string | null;
  loserCauseRoomId: string | null;
  seq: number;
  sides: [Side, Side];
  boosters: { kind: string; giftCode: string | null }[];
}

describe('D199 PK settings, best of three, auto-start, auto match', { timeout: 300_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let pk: LivePkService;
  let seq = 0;
  const boosterCodes: Record<string, string> = {};

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).toLowerCase(),
      token: res.body.tokens.accessToken as string,
    };
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
      .send({ title: 'PK', ...extra });
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
  const join = (roomId: string, u: TestUser) => webhook('participant_joined', roomId, u.id);
  const heartbeat = async (roomId: string, u: TestUser) => {
    const res = await ctx.http.post(`/api/v1/live/rooms/${roomId}/heartbeat`).set(auth(u));
    expect(res.status).toBe(204);
  };
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const gift = async (fields: Partial<GiftFields> = {}): Promise<string> => {
    seq += 1;
    const code = `pk${String(seq)}_${randomUUID().slice(0, 6)}`;
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
  const invite = (fromRoom: string, from: TestUser, toRoom: string) =>
    call('post', `live/rooms/${fromRoom}/pk/invites`, from, { toRoomId: toRoom });
  const acceptInvite = (room: string, u: TestUser, inviteId: string) =>
    call('post', `live/rooms/${room}/pk/invites/${inviteId}/accept`, u);
  const state = async (room: string, u: TestUser | null) => {
    const res = await call('get', `live/rooms/${room}/pk`, u);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getLivePk');
    return res.body as { match: Match | null; invite: { id: string; status: string } | null; queue: unknown };
  };
  /** Two hosts live and in a PK battle (A invited B). */
  const battle = async (): Promise<{
    a: TestUser;
    b: TestUser;
    roomA: string;
    roomB: string;
    match: Match;
  }> => {
    const [a, b] = [await host(), await host()];
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    const inv = await invite(roomA, a, roomB);
    expect(inv.status, JSON.stringify(inv.body)).toBe(201);
    const acc = await acceptInvite(roomB, b, inv.body.id as string);
    expect(acc.status, JSON.stringify(acc.body)).toBe(200);
    return { a, b, roomA, roomB, match: acc.body as Match };
  };
  const send = (roomId: string, u: TestUser, code: string, to: TestUser[], extra: object = {}) =>
    call('post', `live/rooms/${roomId}/gifts`, u, {
      giftCode: code,
      quantity: 1,
      recipients: to.map((r) => r.username),
      source: 'COINS',
      clientId: randomUUID(),
      ...extra,
    });
  const clockIso = () => clock.now().toISOString();
  const matchOf = async (id: string) => ctx.prisma.pkMatch.findUniqueOrThrow({ where: { id } });
  const pkMessages = (roomId: string) =>
    media.broadcasts
      .filter((b) => b.room === roomId && b.topic === 'pk')
      .map(
        (b) =>
          JSON.parse(b.payload) as { type: string; event: string; match: Match; boost?: { kind: string } },
      );
  /** Keeps both rooms fresh while the clock moves (heartbeats). */
  const keepAlive = async (...pairs: [string, TestUser][]) => {
    for (const [room, u] of pairs) await heartbeat(room, u);
  };
  const advance = async (seconds: number, ...pairs: [string, TestUser][]) => {
    let left = seconds;
    while (left > 0) {
      const step = Math.min(left, 15);
      clock.advance(step);
      left -= step;
      await keepAlive(...pairs);
    }
  };

  beforeAll(async () => {
    // The owner's «effective PK» default (3000 PK points) stays on.
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', PK_SCORE_BROADCAST_MS: '0' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    pk = ctx.app.get(LivePkService);
    const prices: Record<string, number> = {
      DOUBLE: 1000,
      DOUBLE_TURBO: 2000,
      TRIPLE: 3000,
      TRIPLE_TURBO: 4000,
    };
    for (const kind of ['DOUBLE', 'DOUBLE_TURBO', 'TRIPLE', 'TRIPLE_TURBO'] as const) {
      boosterCodes[kind] = await gift({ pkBooster: kind, priceCoins: prices[kind]!, sortOrder: 0 });
    }
  });
  afterAll(async () => ctx?.close());

  const settings = async (u: TestUser, body: object) => {
    const res = await call('put', 'me/live-pk', u, body);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'setMyLivePk');
    return res.body as Record<string, unknown>;
  };
  const fanWith = async (amount: number, ...rooms: string[]) => {
    const fan = await signup();
    await coins(fan, amount);
    for (const r of rooms) await join(r, fan);
    return fan;
  };
  const start = (room: string, u: TestUser) => call('post', `live/rooms/${room}/pk/start`, u);
  const clearQueue = () => ctx.prisma.pkQueueEntry.deleteMany({});

  it('openapi v1.44-live declares startLivePk', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('startLivePk POST /api/v1/live/rooms/{roomId}/pk/start');
  });

  it('the PK Setting page: defaults, partial updates, refusals, audit', async () => {
    const u = await host();
    const mine = await call('get', 'me/live-pk', u);
    expect(mine.status).toBe(200);
    expectContract(mine, 'getMyLivePk');
    expect(mine.body).toEqual({
      invitesEnabled: true,
      mode: 'SINGLE',
      roundMinutes: null,
      roundSeconds: 300,
      autoStart: true,
      randomGender: 'BOTH',
      randomRegion: 'GLOBAL',
      autoMatch: false,
      recommendable: true,
      effectiveMinPoints: 3000,
      record: { wins: 0, losses: 0, draws: 0, points: 0, daresDone: 0, daresRefused: 0 },
    });
    expect(await settings(u, { mode: 'BEST_OF_THREE', roundMinutes: 3 })).toMatchObject({
      mode: 'BEST_OF_THREE',
      roundMinutes: 3,
      roundSeconds: 180,
      autoStart: true,
    });
    expect(
      await settings(u, { autoStart: false, randomGender: 'FEMALE', randomRegion: 'SAME_COUNTRY' }),
    ).toMatchObject({
      mode: 'BEST_OF_THREE',
      autoStart: false,
      randomGender: 'FEMALE',
      randomRegion: 'SAME_COUNTRY',
    });
    for (const bad of [{}, { roundMinutes: 4 }, { mode: 'TEAM' }, { autoMatch: 'yes' }, { other: true }]) {
      expectError(await call('put', 'me/live-pk', u, bad), 400, 'VALIDATION_FAILED', 'setMyLivePk');
    }
    const audit = await ctx.prisma.auditLog.findMany({
      where: { actorUserId: u.id, action: 'live.pk.settings' },
      orderBy: { createdAt: 'asc' },
    });
    expect(audit.map((a) => a.metadata)).toEqual([
      { mode: 'BEST_OF_THREE', roundMinutes: 3 },
      { autoStart: false, randomGender: 'FEMALE', randomRegion: 'SAME_COUNTRY' },
    ]);
    // The same values again change nothing (no audit row).
    await settings(u, { autoStart: false });
    expect(
      await ctx.prisma.auditLog.count({ where: { actorUserId: u.id, action: 'live.pk.settings' } }),
    ).toBe(2);
  });

  it('auto-start off: CONNECTED (no points, no booster) until a host starts it; the round time is the setting', async () => {
    const [a, b] = [await host(), await host()];
    await settings(a, { autoStart: false, roundMinutes: 3 });
    await settings(b, { autoStart: false, roundMinutes: 3 });
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    const inv = await invite(roomA, a, roomB);
    const acc = await acceptInvite(roomB, b, inv.body.id as string);
    expect(acc.status).toBe(200);
    expectContract(acc, 'acceptLivePkInvite');
    const m = acc.body as Match;
    expect(m).toMatchObject({
      status: 'CONNECTED',
      mode: 'SINGLE',
      roundSeconds: 180,
      settingsFromRoomId: null,
    });
    expect(m.connectedAt).not.toBeNull();
    expect(new Date(m.battleEndsAt).getTime() - new Date(m.startedAt).getTime()).toBe(300_000);
    expect(pkMessages(roomA).at(-1)?.event).toBe('connected');

    const fan = await fanWith(100_000, roomA);
    const code = await gift({ priceCoins: 50 });
    expect((await send(roomA, fan, code, [a])).status).toBe(201);
    expect((await matchOf(m.id)).scoreA).toBe(0n);
    expectError(await send(roomA, fan, boosterCodes.DOUBLE!, [a]), 409, 'PK_BOOSTER_UNAVAILABLE');
    // The media token works while connected (the hosts see each other).
    const token = await call('post', `live/rooms/${roomA}/pk/media-token`, fan, {});
    expect(token.status, JSON.stringify(token.body)).toBe(200);

    const outsider = await host();
    expectError(await start(roomA, outsider), 404, 'NOT_FOUND', 'startLivePk');
    await advance(20, [roomA, a], [roomB, b]);
    const started = await start(roomB, b);
    expect(started.status).toBe(200);
    expectContract(started, 'startLivePk');
    const s = started.body as Match;
    expect(s.status).toBe('BATTLE');
    expect(new Date(s.battleEndsAt).getTime() - new Date(s.startedAt).getTime()).toBe(180_000);
    expect(pkMessages(roomA).at(-1)?.event).toBe('started');
    // Idempotent once running.
    const again = await start(roomA, a);
    expect(again.status).toBe(200);
    expect((again.body as Match).battleEndsAt).toBe(s.battleEndsAt);
    expect((await send(roomA, fan, code, [a])).status).toBe(201);
    expect((await matchOf(m.id)).scoreA).toBe(50n);
    await advance(180, [roomA, a], [roomB, b]);
    await pk.tick();
    expect((await matchOf(m.id)).status).toBe('RESULT');
    await call('post', `live/rooms/${roomA}/pk/end`, a);
    expectError(await start(roomA, a), 409, 'PK_NOT_ACTIVE', 'startLivePk');
  });

  it('a CONNECTED PK is cancelled by End, a host gone or the deadline — void, never in the history', async () => {
    const [a, b] = [await host(), await host()];
    await settings(a, { autoStart: false });
    await settings(b, { autoStart: false });
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    const first = await acceptInvite(roomB, b, (await invite(roomA, a, roomB)).body.id as string);
    expect((first.body as Match).status).toBe('CONNECTED');
    const ended = await call('post', `live/rooms/${roomA}/pk/end`, a);
    expect(ended.status).toBe(200);
    expect(ended.body).toMatchObject({
      status: 'CLOSED',
      endReason: 'CANCELLED',
      winnerRoomId: null,
      effective: false,
    });
    expect(pkMessages(roomB).at(-1)).toMatchObject({ event: 'closed' });

    await advance(11, [roomA, a], [roomB, b]);
    const second = await acceptInvite(roomB, b, (await invite(roomA, a, roomB)).body.id as string);
    const id = (second.body as Match).id;
    await advance(299, [roomA, a], [roomB, b]);
    await pk.tick();
    expect((await matchOf(id)).status).toBe('CONNECTED');
    await advance(1, [roomA, a], [roomB, b]);
    await pk.tick();
    expect(await matchOf(id)).toMatchObject({ status: 'CLOSED', endReason: 'CANCELLED' });

    const history = await call('get', `live/pk/hosts/${a.username}`, null);
    expect(history.body.recent).toEqual([]);
    expect(history.body.record).toMatchObject({ wins: 0, losses: 0, draws: 0 });
  });

  it("the hosts' settings differ: one host's are used and named", async () => {
    const [a, b] = [await host(), await host()];
    await settings(a, { mode: 'BEST_OF_THREE', roundMinutes: 3 });
    await settings(b, { roundMinutes: 10 });
    const seen = new Set<string>();
    for (let i = 0; i < 12 && seen.size < 2; i += 1) {
      const roomA = await goLive(a);
      const roomB = await goLive(b);
      const m = (await acceptInvite(roomB, b, (await invite(roomA, a, roomB)).body.id as string))
        .body as Match;
      expect([roomA, roomB]).toContain(m.settingsFromRoomId);
      if (m.settingsFromRoomId === roomA)
        expect(m).toMatchObject({ mode: 'BEST_OF_THREE', roundSeconds: 180, rounds: 3 });
      else expect(m).toMatchObject({ mode: 'SINGLE', roundSeconds: 600, rounds: 1 });
      seen.add(m.settingsFromRoomId === roomA ? 'A' : 'B');
      for (const [r, u] of [
        [roomA, a],
        [roomB, b],
      ] as const) {
        const end = await call('post', `live/rooms/${r}/end`, u);
        expect(end.status).toBe(200);
      }
      await pk.tick();
      await advance(11);
    }
    expect(seen).toEqual(new Set(['A', 'B']));
  });

  it('best of three: per-round scores and booster limits, 2 rounds won, totals, an effective PK in the record', async () => {
    const [a, b] = [await host(), await host()];
    await settings(a, { mode: 'BEST_OF_THREE', roundMinutes: 3 });
    await settings(b, { mode: 'BEST_OF_THREE', roundMinutes: 3 });
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    const m = (await acceptInvite(roomB, b, (await invite(roomA, a, roomB)).body.id as string)).body as Match;
    expect(m).toMatchObject({
      status: 'BATTLE',
      mode: 'BEST_OF_THREE',
      round: 1,
      rounds: 3,
      roundSeconds: 180,
    });
    const fanA = await fanWith(1_000_000, roomA);
    const fanB = await fanWith(1_000_000, roomB);
    const big = await gift({ priceCoins: 2000 });
    const pair: [string, TestUser][] = [
      [roomA, a],
      [roomB, b],
    ];

    // Round 1: A 2000 + Double (1000, ×1) then 2000 × 2 = 7000; B 2000. Double used twice → the limit.
    expect((await send(roomA, fanA, big, [a])).status).toBe(201);
    expect((await send(roomA, fanA, boosterCodes.DOUBLE!, [a])).status).toBe(201);
    expect((await send(roomA, fanA, big, [a])).status).toBe(201);
    await advance(30, ...pair);
    expect((await send(roomA, fanA, boosterCodes.DOUBLE!, [a])).status).toBe(201);
    await advance(30, ...pair);
    expectError(await send(roomA, fanA, boosterCodes.DOUBLE!, [a]), 409, 'PK_BOOSTER_UNAVAILABLE');
    expect((await send(roomB, fanB, big, [b])).status).toBe(201);
    await advance(120, ...pair);
    await pk.tick();
    let now = (await state(roomA, a)).match!;
    expect(now).toMatchObject({ status: 'BATTLE', round: 2 });
    expect(now.sides[0]).toMatchObject({ score: 0, roundsWon: 1, totalScore: 8000, boost: null });
    expect(now.sides[0].boosterUses.DOUBLE).toBe(0);
    expect(now.sides[1]).toMatchObject({ score: 0, roundsWon: 0, totalScore: 2000 });
    expect(pkMessages(roomB).at(-1)?.event).toBe('round');
    expect(new Date(now.battleEndsAt).getTime() - Date.parse(clockIso())).toBe(180_000);

    // Round 2: the limit is per round — Double works again; B wins the round.
    expect((await send(roomA, fanA, boosterCodes.DOUBLE!, [a])).status).toBe(201);
    expect((await send(roomB, fanB, big, [b])).status).toBe(201);
    expect((await send(roomB, fanB, big, [b])).status).toBe(201);
    await advance(180, ...pair);
    await pk.tick();
    now = (await state(roomA, a)).match!;
    expect(now).toMatchObject({ status: 'BATTLE', round: 3 });
    expect(now.sides.map((x) => x.roundsWon)).toEqual([1, 1]);

    // Round 3: A wins → 2–1.
    expect((await send(roomA, fanA, big, [a])).status).toBe(201);
    await advance(180, ...pair);
    await pk.tick();
    now = (await state(roomA, a)).match!;
    expect(now).toMatchObject({
      status: 'RESULT',
      endReason: 'TIME',
      winnerRoomId: roomA,
      round: 3,
      effective: true,
    });
    expect(now.sides.map((x) => x.roundsWon)).toEqual([2, 1]);
    expect(now.sides.map((x) => x.totalScore)).toEqual([11000, 6000]);

    const history = await call('get', `live/pk/hosts/${a.username}`, null);
    expectContract(history, 'getLivePkHost');
    expect(history.body.record).toMatchObject({ wins: 1, losses: 0, draws: 0 });
    expect(history.body.recent[0]).toMatchObject({
      result: 'WIN',
      mode: 'BEST_OF_THREE',
      score: 11000,
      opponentScore: 6000,
      roundsWon: 2,
      opponentRoundsWon: 1,
      effective: true,
    });
  });

  it('below the effective threshold: the result stands but the records do not count it', async () => {
    const { a, b, roomA, roomB, match } = await battle();
    const fan = await fanWith(100_000, roomB);
    const code = await gift({ priceCoins: 2999 });
    expect((await send(roomB, fan, code, [b])).status).toBe(201);
    await advance(300, [roomA, a], [roomB, b]);
    await pk.tick();
    expect(await matchOf(match.id)).toMatchObject({ status: 'RESULT', winner: 'B', effective: false });
    const profile = await call('get', `live/pk/hosts/${b.username}`, null);
    expect(profile.body.record).toMatchObject({ wins: 0, losses: 0, draws: 0 });
    expect(profile.body.recent[0]).toMatchObject({ result: 'WIN', effective: false, score: 2999 });
  });

  it('random queue: gender and region preferences hold both ways (unknown gender matches any)', async () => {
    await clearQueue();
    const profile = (u: TestUser, data: object) =>
      ctx.prisma.userProfile.update({ where: { userId: u.id }, data });
    const [man, woman, unknown, wantsWomen] = [await host(), await host(), await host(), await host()];
    await profile(man, { gender: 'MALE', countryCode: 'SA' });
    await profile(woman, { gender: 'FEMALE', countryCode: 'EG' });
    await profile(unknown, { gender: 'UNDISCLOSED', countryCode: 'SA' });
    await profile(wantsWomen, { gender: 'MALE', countryCode: 'SA' });
    await settings(wantsWomen, { randomGender: 'FEMALE' });
    const rooms = new Map<TestUser, string>();
    for (const u of [man, woman, unknown, wantsWomen]) rooms.set(u, await goLive(u));
    // One second apart: the queue pairs whoever waited longest.
    const random = async (u: TestUser) => {
      clock.advance(1);
      return call('post', `live/rooms/${rooms.get(u)}/pk/random`, u);
    };

    expect((await random(wantsWomen)).body.status).toBe('WAITING');
    expect((await random(man)).body.status).toBe('WAITING'); // a man for someone who wants women: no
    const paired = await random(woman);
    expect(paired.body.status).toBe('MATCHED');
    expectContract(paired, 'joinLivePkRandom');
    expect((paired.body.match as Match).sides.map((x) => x.roomId)).toContain(rooms.get(wantsWomen));
    // UNDISCLOSED matches the waiting man.
    expect((await random(unknown)).body.status).toBe('MATCHED');
    for (const u of [man, woman, unknown, wantsWomen])
      await call('post', `live/rooms/${rooms.get(u)}/end`, u);
    await pk.tick();

    await clearQueue();
    await advance(16);
    const [saudi, egyptian, sameCountry] = [await host(), await host(), await host()];
    await profile(saudi, { countryCode: 'SA' });
    await profile(egyptian, { countryCode: 'EG' });
    await profile(sameCountry, { countryCode: 'SA' });
    await settings(sameCountry, { randomRegion: 'SAME_COUNTRY' });
    for (const u of [saudi, egyptian, sameCountry]) rooms.set(u, await goLive(u));
    expect((await random(sameCountry)).body.status).toBe('WAITING');
    expect((await random(egyptian)).body.status).toBe('WAITING'); // Egypt ≠ Saudi Arabia, either way
    const sa = await random(saudi);
    expect(sa.body.status).toBe('MATCHED');
    expect((sa.body.match as Match).sides.map((x) => x.roomId)).toContain(rooms.get(sameCountry));
    for (const u of [saudi, egyptian, sameCountry]) await call('post', `live/rooms/${rooms.get(u)}/end`, u);
    await pk.tick();
  });

  it('Auto Match: idle hosts are queued and paired by the tick; off leaves the queue', async () => {
    await clearQueue();
    await advance(16);
    const [a, b] = [await host(), await host()];
    await settings(a, { autoMatch: true });
    await settings(b, { autoMatch: true });
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    await pk.tick();
    const m = (await state(roomA, a)).match;
    expect(m).toMatchObject({ source: 'RANDOM', status: 'BATTLE' });
    expect(m!.sides.map((x) => x.roomId).sort()).toEqual([roomA, roomB].sort());
    // End the match: no re-queue during the rest, then queued again.
    await call('post', `live/rooms/${roomA}/pk/end`, a);
    await call('post', `live/rooms/${roomA}/pk/end`, a);
    await pk.tick();
    expect(await ctx.prisma.pkQueueEntry.count({ where: { hostId: { in: [a.id, b.id] } } })).toBe(0);
    await settings(b, { autoMatch: false });
    await advance(31, [roomA, a], [roomB, b]);
    await pk.tick();
    expect(await ctx.prisma.pkQueueEntry.count({ where: { hostId: a.id } })).toBe(1);
    expect(await ctx.prisma.pkQueueEntry.count({ where: { hostId: b.id } })).toBe(0);
    await settings(a, { autoMatch: false });
    expect(await ctx.prisma.pkQueueEntry.count({ where: { hostId: a.id } })).toBe(0);
    for (const [r, u] of [
      [roomA, a],
      [roomB, b],
    ] as const)
      await call('post', `live/rooms/${r}/end`, u);
  });

  it('suggestions skip hosts who opted out (search still finds them); friends = mutual follows', async () => {
    await advance(16);
    const [me, hidden, friend, fan] = [await host(), await host(), await host(), await host()];
    await settings(hidden, { recommendable: false });
    const myRoom = await goLive(me);
    const hiddenRoom = await goLive(hidden);
    const friendRoom = await goLive(friend);
    const fanRoom = await goLive(fan);
    await ctx.prisma.follow.createMany({
      data: [
        { followerId: me.id, followeeId: friend.id },
        { followerId: friend.id, followeeId: me.id },
        { followerId: fan.id, followeeId: me.id },
      ],
    });
    const list = async (query: string) => {
      const res = await call('get', `live/rooms/${myRoom}/pk/candidates${query}`, me);
      expect(res.status).toBe(200);
      expectContract(res, 'listLivePkCandidates');
      return (res.body.data as { roomId: string }[]).map((c) => c.roomId);
    };
    const suggested = await list('');
    expect(suggested).toEqual(expect.arrayContaining([friendRoom, fanRoom]));
    expect(suggested).not.toContain(hiddenRoom);
    expect(await list(`?q=${hidden.username}`)).toEqual([hiddenRoom]);
    expect(await list('?friends=true')).toEqual([friendRoom]);
    expectError(
      await call('get', `live/rooms/${myRoom}/pk/candidates?friends=yes`, me),
      400,
      'VALIDATION_FAILED',
    );
  });

  it("the Data Center's gift-givers: different senders other than the host", async () => {
    const h = await host();
    const room = await goLive(h);
    const [f1, f2] = [await fanWith(10_000, room), await fanWith(10_000, room)];
    await fanWith(10_000, room); // watches, sends nothing
    const code = await gift({ priceCoins: 10 });
    for (const u of [f1, f1, f2]) expect((await send(room, u, code, [h])).status).toBe(201);
    const stats = await call('get', `live/rooms/${room}/stats`, h);
    expect(stats.status).toBe(200);
    expectContract(stats, 'getLiveRoomStats');
    expect(stats.body.giftGivers).toBe(2);
  });
});
