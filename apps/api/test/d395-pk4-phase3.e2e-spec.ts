/**
 * D395 (v1.119-live DRAFT, CONVENTIONS §10.181, CP-041 phases 3–4; owner «أ و ب»): «PK رباعي» for two to four hosts —
 * the organiser's «ابدأ الآن» with two or three hosts and the automatic start when the lobby's time runs out, TEAMS
 * with three (two v one) and two (like a 1 v 1), FREE_FOR_ALL «الكل ضد الكل» with four, three and two (places by score,
 * equal scores share a place, a host who leaves takes the last free place, one host left wins, records, boosters and
 * supporters per host), the 4-way random queue (four only: match, cancel, busy, timeout, one wait per host, blocks,
 * random teams), «PK أحكام» for four (the losing side does one dare, the winning side judges; TEAMS and FREE_FOR_ALL
 * with two, three and four hosts) and «جولة أخرى» for four (every present host accepts; with two, three and four),
 * the panel's 4-way view — each response and message checked against the contract. End to end against PostgreSQL +
 * Redis with the API as the DML-only runtime role; the media server is the in-memory fake; time is a FakeClock and the
 * PK tick is run by hand.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { LivePkService } from '../src/modules/live/live-pk.service.js';
import { LivePk4Service } from '../src/modules/live/live-pk4.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { importPkDaresIn } from '../src/modules/live/pk-dares/pk-dare-library.js';
import { parseDareImport, type PkDareImport } from '../src/modules/live/pk-dares/pk-dare-rules.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, expectSchema, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  settle,
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

interface Seat {
  seat: number;
  team: 'A' | 'B';
  roomId: string;
  host: { id: string };
  score: number;
  out: boolean;
  place: number | null;
  result: 'WIN' | 'LOSS' | 'DRAW' | null;
  boost: { kind: string; multiplier: number } | null;
  boosterUses: Record<string, number>;
  supporters: { user: { id: string }; points: number }[];
}

interface Dare {
  status: string;
  cause: string | null;
  loserRoomIds: string[];
  winnerRoomIds: string[];
  options: { id: string }[];
  drawn: number;
  points: number;
}

interface Match {
  id: string;
  format: 'TEAMS' | 'FREE_FOR_ALL';
  type: 'NORMAL' | 'DARES';
  source: string;
  playerCount: number;
  status: string;
  endReason: string | null;
  winnerTeam: 'A' | 'B' | null;
  effective: boolean | null;
  organiserRoomId: string;
  teams: { team: 'A' | 'B'; score: number; result: string | null }[];
  seats: Seat[];
  dare: Dare | null;
  rematch: { byRoomId: string; acceptedRoomIds: string[]; waitingRoomIds: string[] } | null;
  rematchOf: string | null;
  rematchesLeft: number | null;
}

interface Lobby {
  id: string;
  status: string;
  format: string;
  type: string;
  accepted: number;
  canStart: boolean;
  matchId: string | null;
  seats: {
    seat: number;
    role: string;
    state: string;
    roomId: string | null;
    invite: { id: string } | null;
  }[];
}

interface Host {
  user: TestUser;
  room: string;
}

/** The e2e dare library: a few active dares per level (the seed file's own lines). */
function testLibrary(): PkDareImport[] {
  const lines = readFileSync(new URL('../prisma/seed/pk-dares/pk-dares.v1.jsonl', import.meta.url), 'utf8')
    .split('\n')
    .filter((l) => l.trim().length > 0)
    .map((l) => parseDareImport(JSON.parse(l)) as PkDareImport);
  return (['EASY', 'MEDIUM', 'HARD'] as const).flatMap((level) =>
    lines.filter((d) => d.level === level && d.category === 'IMITATION').slice(0, 6),
  );
}

describe('D395 contract coverage', () => {
  it('openapi v1.119-live declares the phase-3 operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'startLivePk4Lobby POST /api/v1/live/rooms/{roomId}/pk4/lobby/start',
      'joinLivePk4Random POST /api/v1/live/rooms/{roomId}/pk4/random',
      'leaveLivePk4Random DELETE /api/v1/live/rooms/{roomId}/pk4/random',
      'acceptLivePk4Dare POST /api/v1/live/rooms/{roomId}/pk4/dare/accept',
      'refuseLivePk4Dare POST /api/v1/live/rooms/{roomId}/pk4/dare/refuse',
      'judgeLivePk4Dare POST /api/v1/live/rooms/{roomId}/pk4/dare/verdict',
      'reportLivePk4Dare POST /api/v1/live/rooms/{roomId}/pk4/dare/report',
      'offerLivePk4Rematch POST /api/v1/live/rooms/{roomId}/pk4/rematch',
      'cancelLivePk4Rematch DELETE /api/v1/live/rooms/{roomId}/pk4/rematch',
      'acceptLivePk4Rematch POST /api/v1/live/rooms/{roomId}/pk4/rematch/accept',
      'declineLivePk4Rematch POST /api/v1/live/rooms/{roomId}/pk4/rematch/decline',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe(
  'D395 «PK رباعي» for two to four, FREE_FOR_ALL, random, dares, rematch',
  { timeout: 900_000 },
  () => {
    const clock = new FakeClock();
    const media = new MemoryLiveMedia();
    let ctx: TestContext;
    let pk4: LivePk4Service;
    let pk: LivePkService;
    let seq = 0;
    const gifts: Record<number, string> = {};
    const boosterCodes: Record<string, string> = {};
    let luckyGift = '';
    const admin = panel(() => ctx);
    let moderator: Admin;

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
    const live = async (): Promise<Host> => {
      const user = await signup();
      await ctx.prisma.liveHost.create({ data: { userId: user.id, source: 'ADMIN' } });
      clock.advance(0.01);
      const res = await ctx.http.post('/api/v1/live/rooms').set(auth(user)).send({ title: 'PK4 phase 3' });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      return { user, room: res.body.id as string };
    };
    const hosts = async (n: number): Promise<Host[]> => {
      const out: Host[] = [];
      for (let i = 0; i < n; i += 1) out.push(await live());
      return out;
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
    const openLobby = (h: Host, format: 'TEAMS' | 'FREE_FOR_ALL', type?: 'DARES' | 'NORMAL') =>
      call('post', `live/rooms/${h.room}/pk4/lobby`, h.user, type ? { format, type } : { format });
    const invite = (org: Host, to: Host, seat: number) =>
      call('post', `live/rooms/${org.room}/pk4/lobby/invites`, org.user, { toRoomId: to.room, seat });
    const accept = (h: Host, inviteId: string) =>
      call('post', `live/rooms/${h.room}/pk4/invites/${inviteId}/accept`, h.user);
    const inviteIdOf = (lobby: Lobby, seat: number) => lobby.seats.find((s) => s.seat === seat)!.invite!.id;
    const join = async (org: Host, h: Host, seat: number): Promise<request.Response> => {
      const inv = await invite(org, h, seat);
      expect(inv.status, JSON.stringify(inv.body)).toBe(201);
      const acc = await accept(h, inviteIdOf(inv.body as Lobby, seat));
      expect(acc.status, JSON.stringify(acc.body)).toBe(200);
      return acc;
    };
    const startNow = (h: Host) => call('post', `live/rooms/${h.room}/pk4/lobby/start`, h.user);
    const state = async (room: string, u: TestUser | null) => {
      const res = await call('get', `live/rooms/${room}/pk4`, u);
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'getLivePk4');
      return res.body as {
        match: Match | null;
        lobby: Lobby | null;
        invite: { id: string } | null;
        queue: { format: string; type: string; expiresAt: string } | null;
      };
    };
    const snapshot = async (h: Host) => (await state(h.room, h.user)).match!;
    const messages = (room: string) =>
      media.broadcasts
        .filter((b) => b.room === room && b.topic === 'pk')
        .map((b) => JSON.parse(b.payload) as { type: string; event: string; match: Match; boost?: object })
        .filter((m) => m.type === 'pk4-match');
    const direct = (room: string, identity: string, type: string) =>
      media.data
        .filter((d) => d.room === room && d.identity === identity)
        .map(
          (d) => JSON.parse(d.payload) as { type: string; event?: string; status?: string; matchId?: string },
        )
        .filter((m) => m.type === type);
    const coins = (u: TestUser, amount: number) =>
      ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
    const gift = async (fields: Partial<GiftFields> = {}): Promise<string> => {
      seq += 1;
      const code = `p3g${String(seq)}_${randomUUID().slice(0, 6)}`;
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
    let fan: TestUser;
    const send = async (h: Host, code: string) => {
      await webhook('participant_joined', h.room, fan.id);
      const res = await call('post', `live/rooms/${h.room}/gifts`, fan, {
        giftCode: code,
        quantity: 1,
        recipients: [h.user.username],
        source: 'COINS',
        clientId: randomUUID(),
      });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      return res;
    };
    /** Gives each host its PK points with gifts of 100 / 200 / 300 / 500 coins. */
    const give = async (...pairs: [Host, 100 | 200 | 300 | 500][]) => {
      for (const [h, value] of pairs) await send(h, gifts[value]!);
    };
    /** Moves the clock, the hosts' heartbeats kept fresh every 15 s. */
    const advance = async (seconds: number, ...hs: Host[]) => {
      let left = seconds;
      while (left > 0) {
        const step = Math.min(left, 15);
        clock.advance(step);
        left -= step;
        for (const h of hs) {
          expect((await call('post', `live/rooms/${h.room}/heartbeat`, h.user)).status).toBe(204);
        }
      }
    };
    /** The round runs out (300 s) and the tick ends it. */
    const timeUp = async (...hs: Host[]) => {
      await advance(301, ...hs);
      await pk4.tick();
    };
    const record = async (u: TestUser) => ctx.prisma.pkHostRecord.findUnique({ where: { hostId: u.id } });
    const end = (h: Host) => call('post', `live/rooms/${h.room}/pk4/end`, h.user);
    /** Organiser `o` and the others in places 2.. of a `format` lobby; four → it starts on the last acceptance. */
    const lobbyBattle = async (
      format: 'TEAMS' | 'FREE_FOR_ALL',
      n: 2 | 3 | 4,
      type: 'NORMAL' | 'DARES' = 'NORMAL',
    ): Promise<{ hs: Host[]; match: Match }> => {
      const hs = await hosts(n);
      const o = hs[0]!;
      expect((await openLobby(o, format, type)).status).toBe(201);
      let last: request.Response | null = null;
      for (const [i, h] of hs.slice(1).entries()) last = await join(o, h, i + 2);
      if (n < 4) {
        last = await startNow(o);
        expect(last.status, JSON.stringify(last.body)).toBe(200);
        expectContract(last, 'startLivePk4Lobby');
      }
      const match = (last!.body as { match: Match }).match;
      expect(match).not.toBeNull();
      return { hs, match };
    };
    const seatOf = (m: Match, h: Host) => m.seats.find((s) => s.roomId === h.room)!;

    beforeAll(async () => {
      ctx = await createTestApp(
        {
          ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
          ADMIN_SESSION_IDLE_SECONDS: '3600',
          ADMIN_SESSION_MAX_SECONDS: '28800',
          RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
          RATE_LIMIT_ADMIN_IP: '100000/900',
          LIVE_HOSTING_ENABLED: 'true',
          LIVE_HEARTBEAT_STALE_SECONDS: '3600',
          PK_SCORE_BROADCAST_MS: '0',
          PK_EFFECTIVE_MIN_POINTS: '0',
          LUCKY_GIFTS_ENABLED: 'true',
          RATE_LIMIT_LIVE_PK_INVITE_USER: '10000/600',
          RATE_LIMIT_LIVE_PK_ACTION_USER: '10000/600',
        },
        [
          { token: Clock, value: clock },
          { token: LIVE_MEDIA_PROVIDER, value: media },
        ],
      );
      pk4 = ctx.app.get(LivePk4Service);
      pk = ctx.app.get(LivePkService);
      for (const value of [100, 200, 300, 500]) gifts[value] = await gift({ priceCoins: value });
      const prices: Record<string, number> = {
        DOUBLE: 1000,
        DOUBLE_TURBO: 2000,
        TRIPLE: 3000,
        TRIPLE_TURBO: 4000,
      };
      for (const kind of ['DOUBLE', 'DOUBLE_TURBO', 'TRIPLE', 'TRIPLE_TURBO'] as const) {
        boosterCodes[kind] = await gift({ pkBooster: kind, priceCoins: prices[kind]!, sortOrder: 0 });
      }
      luckyGift = await gift({ category: 'LUCKY', priceCoins: 10 });
      fan = await signup();
      await coins(fan, 50_000_000);
      expect((await call('put', 'me/lucky-gifts/age-confirmation', fan, { adult: true })).status).toBe(200);
      moderator = await admin.makeAdmin(['MODERATION']);
      const library = testLibrary();
      await withMigrationClient(async (db) => {
        await db.$transaction(
          (tx) =>
            importPkDaresIn(tx, library, {
              dryRun: false,
              reason: 'd395 e2e',
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

    // ---- Starting with two or three -----------------------------------------------------------------------------------

    it('«ابدأ الآن»: not before one host accepted; three start TEAMS two v one; open invitations are cancelled', async () => {
      const [o, t, x, y] = await hosts(4);
      const opened = await openLobby(o, 'TEAMS');
      expect(opened.status).toBe(201);
      expect(opened.body).toMatchObject({ format: 'TEAMS', type: 'NORMAL', accepted: 1, canStart: false });
      // Only the organiser is in: refused, too few.
      const early = await startNow(o);
      expectError(early, 409, 'PK_UNAVAILABLE', 'startLivePk4Lobby');
      expect(early.body.error.details).toEqual([{ field: 'lobby', issue: 'too_few' }]);
      await join(o, t, 2);
      await join(o, x, 3);
      const pending = await invite(o, y, 4);
      expect(pending.status).toBe(201);
      const lobby = (await state(o.room, o.user)).lobby!;
      expect(lobby).toMatchObject({ accepted: 3, canStart: true });
      expectSchema('Pk4Lobby', lobby);
      // Only the organiser starts it.
      expectError(await startNow(t), 409, 'PK_LOBBY_CLOSED', 'startLivePk4Lobby');
      const started = await startNow(o);
      expect(started.status, JSON.stringify(started.body)).toBe(200);
      expectContract(started, 'startLivePk4Lobby');
      const match = (started.body as { match: Match }).match;
      expect(match).toMatchObject({ format: 'TEAMS', status: 'BATTLE', playerCount: 3, source: 'INVITE' });
      expect(match.seats.map((s) => [s.seat, s.team, s.roomId])).toEqual([
        [1, 'A', o.room],
        [2, 'A', t.room],
        [3, 'B', x.room],
      ]);
      expect(match.teams).toHaveLength(2);
      // The pending invitation was cancelled (its host told); the three rooms get the match, the fourth nothing.
      expect(direct(y.room, y.user.id, 'pk4-invite').at(-1)).toMatchObject({
        invite: { status: 'CANCELLED' },
      });
      for (const h of [o, t, x]) {
        const m = messages(h.room).at(-1)!;
        expect(m).toMatchObject({ event: 'started', match: { id: match.id, playerCount: 3 } });
        expectSchema('Pk4Match', m.match);
      }
      expect(messages(y.room)).toHaveLength(0);
      expect((await state(y.room, y.user)).match).toBeNull();
      const audit = await ctx.prisma.auditLog.findFirst({
        where: {
          action: 'live.pk4.lobby',
          targetId: lobby.id,
          metadata: { path: ['event'], equals: 'started-early' },
        },
      });
      expect(audit?.actorUserId).toBe(o.user.id);
      // Two v one: team sums; the lone host leaves → the pair wins at once; records per host.
      await give([o, 100], [t, 100], [x, 300]);
      let m = await snapshot(x);
      expect(m.teams.map((tm) => tm.score)).toEqual([200, 300]);
      const left = await end(x);
      expect(left.status).toBe(200);
      expectContract(left, 'endLivePk4');
      m = left.body as Match;
      expect(m).toMatchObject({ status: 'RESULT', endReason: 'FORFEIT', winnerTeam: 'A', effective: true });
      expect(m.seats.map((s) => s.result)).toEqual(['WIN', 'WIN', 'LOSS']);
      expect(m.seats.map((s) => s.place)).toEqual([null, null, null]);
      expect((await record(o.user))?.wins).toBe(1);
      expect((await record(t.user))?.wins).toBe(1);
      expect((await record(x.user))?.losses).toBe(1);
      await end(o);
    });

    it('the lobby’s time runs out with two in: it starts by itself; the organiser and the teammate play like a 1 v 1', async () => {
      const [o, t] = await hosts(2);
      const opened = (await openLobby(o, 'TEAMS')).body as Lobby;
      await join(o, t, 2);
      await advance(121, o, t);
      const ticked = await pk4.tick();
      expect(ticked.started).toBe(1);
      const m = await snapshot(o);
      expect(m).toMatchObject({ status: 'BATTLE', playerCount: 2, format: 'TEAMS' });
      // Both on team A would be no match: the teammate plays on the other side.
      expect(m.seats.map((s) => [s.seat, s.team, s.roomId])).toEqual([
        [1, 'A', o.room],
        [3, 'B', t.room],
      ]);
      expect(direct(t.room, t.user.id, 'pk4-lobby').at(-1)).toMatchObject({ event: 'started' });
      const audit = await ctx.prisma.auditLog.findFirst({
        where: {
          action: 'live.pk4.lobby',
          targetId: opened.id,
          metadata: { path: ['event'], equals: 'auto-started' },
        },
      });
      expect(audit).not.toBeNull();
      // No gifts: equal scores at the end → a draw for both.
      await timeUp(o, t);
      const done = await snapshot(t);
      expect(done).toMatchObject({ status: 'RESULT', endReason: 'TIME', winnerTeam: null });
      expect(done.seats.map((s) => s.result)).toEqual(['DRAW', 'DRAW']);
      expect((await record(o.user))?.draws).toBe(1);
      await end(o);
    });

    it('the lobby’s end with three in starts FREE_FOR_ALL (two stacked, one big tile); with one in it expires', async () => {
      const [o, a, b] = await hosts(3);
      expect((await openLobby(o, 'FREE_FOR_ALL')).status).toBe(201);
      await join(o, a, 3);
      await join(o, b, 4);
      await advance(121, o, a, b);
      await pk4.tick();
      const m = await snapshot(o);
      expect(m).toMatchObject({ format: 'FREE_FOR_ALL', playerCount: 3, teams: [] });
      // Packed: 1 and 2 on the start side, 3 alone on the end side.
      expect(m.seats.map((s) => [s.seat, s.team, s.roomId])).toEqual([
        [1, 'A', o.room],
        [2, 'A', a.room],
        [3, 'B', b.room],
      ]);
      await give([o, 200], [a, 500], [b, 100]);
      await timeUp(o, a, b);
      const done = await snapshot(b);
      expect(done.seats.map((s) => [s.roomId, s.place, s.result])).toEqual([
        [o.room, 2, 'LOSS'],
        [a.room, 1, 'WIN'],
        [b.room, 3, 'LOSS'],
      ]);
      await end(o);
    });

    // ---- FREE_FOR_ALL ------------------------------------------------------------------------------------------------

    it('FREE_FOR_ALL with four: PLAYER places, each host alone, boosters and supporters per host, places 1–4 and ties', async () => {
      const hs = await hosts(4);
      const [o, a, b, c] = hs as [Host, Host, Host, Host];
      const opened = await openLobby(o, 'FREE_FOR_ALL');
      expectContract(opened, 'openLivePk4Lobby');
      expect((opened.body as Lobby).seats.map((s) => s.role)).toEqual([
        'ORGANISER',
        'PLAYER',
        'PLAYER',
        'PLAYER',
      ]);
      await join(o, a, 2);
      await join(o, b, 3);
      const last = await join(o, c, 4);
      const match = (last.body as { match: Match }).match;
      expect(match).toMatchObject({ format: 'FREE_FOR_ALL', playerCount: 4, teams: [], winnerTeam: null });
      // A booster is the host's own (limits per host).
      await send(a, boosterCodes.DOUBLE!);
      await settle(ctx);
      expect(messages(o.room).at(-1)).toMatchObject({ event: 'boost', boost: { seat: 2, roomId: a.room } });
      await give([a, 100]);
      let m = await snapshot(o);
      expect(m.seats.map((s) => s.score)).toEqual([0, 1200, 0, 0]);
      expect(seatOf(m, a).boost).toMatchObject({ kind: 'DOUBLE', multiplier: 2 });
      expect(seatOf(m, b).boost).toBeNull();
      expect(seatOf(m, a).boosterUses.DOUBLE).toBe(1);
      expect(seatOf(m, b).boosterUses.DOUBLE).toBe(0);
      expect(seatOf(m, a).supporters).toEqual([
        { user: expect.objectContaining({ id: fan.id }), points: 1200 },
      ]);
      // b's own booster is free to use (a's does not count against it); b's next gift counts ×2.
      await send(b, boosterCodes.DOUBLE!);
      // Two tied at the top (b: 1000 + 100 × 2), o and c behind (c below o).
      await give([o, 500], [b, 100]);
      m = await snapshot(o);
      expect(m.seats.map((s) => s.score)).toEqual([500, 1200, 1200, 0]);
      await timeUp(o, a, b, c);
      m = await snapshot(c);
      expect(m.seats.map((s) => [s.place, s.result])).toEqual([
        [3, 'LOSS'],
        [1, 'DRAW'],
        [1, 'DRAW'],
        [4, 'LOSS'],
      ]);
      expect(m).toMatchObject({ status: 'RESULT', endReason: 'TIME', effective: true });
      expect(m.seats.every((s) => s.supporters.length <= 3)).toBe(true);
      expect((await record(a.user))?.draws).toBe(1);
      expect((await record(b.user))?.draws).toBe(1);
      expect((await record(o.user))?.losses).toBe(1);
      expect((await record(c.user))?.losses).toBe(1);
      const ended = await ctx.prisma.auditLog.findFirst({
        where: { action: 'live.pk4.end', targetId: match.id },
      });
      expect(ended?.metadata).toMatchObject({ format: 'FREE_FOR_ALL', players: 4 });
      await end(o);
    });

    it('FREE_FOR_ALL outs: a host who leaves takes the last free place; one host left on air wins at once', async () => {
      const { hs, match } = await lobbyBattle('FREE_FOR_ALL', 4);
      const [o, a, b, c] = hs as [Host, Host, Host, Host];
      await give([c, 500], [b, 300], [a, 200]);
      // c leaves first (with the best score): the 4th place; the battle goes on.
      const out = await end(c);
      expect((out.body as Match).status).toBe('BATTLE');
      expect(seatOf(out.body as Match, c).out).toBe(true);
      clock.advance(1);
      expect(((await end(b)).body as Match).status).toBe('BATTLE');
      clock.advance(1);
      // a leaves: only o is left on air → o is 1st at once, though o has no points.
      const last = (await end(a)).body as Match;
      expect(last).toMatchObject({ status: 'RESULT', endReason: 'FORFEIT', id: match.id });
      expect(last.seats.map((s) => [s.roomId, s.place, s.result])).toEqual([
        [o.room, 1, 'WIN'],
        [a.room, 2, 'LOSS'],
        [b.room, 3, 'LOSS'],
        [c.room, 4, 'LOSS'],
      ]);
      await end(o);
    });

    it('FREE_FOR_ALL with two: half the screen each; equal scores → a draw; a higher score wins', async () => {
      const { hs, match } = await lobbyBattle('FREE_FOR_ALL', 2);
      const [o, a] = hs as [Host, Host];
      expect(match.seats.map((s) => [s.seat, s.team])).toEqual([
        [1, 'A'],
        [3, 'B'],
      ]);
      await give([o, 200], [a, 200]);
      await timeUp(o, a);
      expect((await snapshot(o)).seats.map((s) => [s.place, s.result])).toEqual([
        [1, 'DRAW'],
        [1, 'DRAW'],
      ]);
      await end(o);
      const second = await lobbyBattle('FREE_FOR_ALL', 2);
      await give([second.hs[1]!, 100]);
      await timeUp(...second.hs);
      expect((await snapshot(second.hs[0]!)).seats.map((s) => [s.place, s.result])).toEqual([
        [2, 'LOSS'],
        [1, 'WIN'],
      ]);
      await end(second.hs[0]!);
    });

    it('everyone gone at once in FREE_FOR_ALL → a void draw (no places, no records)', async () => {
      const { hs, match } = await lobbyBattle('FREE_FOR_ALL', 3);
      // The three lives end before the next tick: all out at once.
      for (const h of hs) expect((await call('post', `live/rooms/${h.room}/end`, h.user)).status).toBe(200);
      await pk4.tick();
      const row = await ctx.prisma.pk4Match.findUniqueOrThrow({ where: { id: match.id } });
      expect(row.effective).toBe(false);
      const seats = await ctx.prisma.pk4Seat.findMany({ where: { matchId: match.id } });
      expect(seats.every((s) => s.place === null)).toBe(true);
      for (const h of hs) expect(await record(h.user)).toBeNull();
    });

    // ---- The 4-way random queue --------------------------------------------------------------------------------------

    it('random: four only — three wait, the fourth matches them (TEAMS drawn at random); cancel; one wait per host', async () => {
      const hs = await hosts(5);
      const [a, b, c, d, e] = hs as [Host, Host, Host, Host, Host];
      const join4 = (h: Host, format: 'TEAMS' | 'FREE_FOR_ALL', type?: 'DARES') =>
        call('post', `live/rooms/${h.room}/pk4/random`, h.user, type ? { format, type } : { format });
      const first = await join4(a, 'TEAMS');
      expect(first.status).toBe(200);
      expectContract(first, 'joinLivePk4Random');
      expect(first.body).toMatchObject({
        status: 'WAITING',
        match: null,
        queue: { format: 'TEAMS', type: 'NORMAL' },
      });
      const q = first.body.queue as { joinedAt: string; expiresAt: string };
      expect(new Date(q.expiresAt).getTime() - new Date(q.joinedAt).getTime()).toBe(120_000);
      expect((await state(a.room, a.user)).queue).toMatchObject({ format: 'TEAMS' });
      // The same call again: the same wait.
      expect((await join4(a, 'TEAMS')).body.queue).toEqual(first.body.queue);
      // A waiting host is busy for its own lobby and its own 1 v 1 invitation.
      expectError(await openLobby(a, 'TEAMS'), 409, 'PK_HOST_BUSY', 'openLivePk4Lobby');
      // e waits for 1 v 1 then joins the 4-way queue: one wait per host (the 1 v 1 wait is replaced), and back.
      expect((await call('post', `live/rooms/${e.room}/pk/random`, e.user, {})).body.status).toBe('WAITING');
      expect((await join4(e, 'FREE_FOR_ALL')).body.status).toBe('WAITING');
      expect(await ctx.prisma.pkQueueEntry.count({ where: { hostId: e.user.id } })).toBe(0);
      expect((await call('post', `live/rooms/${e.room}/pk/random`, e.user, {})).body.status).toBe('WAITING');
      expect(await ctx.prisma.pk4QueueEntry.count({ where: { hostId: e.user.id } })).toBe(0);
      expect((await call('delete', `live/rooms/${e.room}/pk/random`, e.user)).status).toBe(204);
      // A different format never matches.
      expect((await join4(e, 'FREE_FOR_ALL')).body.status).toBe('WAITING');
      // b waits then cancels; it is not matched.
      expect((await join4(b, 'TEAMS')).body.status).toBe('WAITING');
      const left = await call('delete', `live/rooms/${b.room}/pk4/random`, b.user);
      expect(left.status).toBe(204);
      expectContract(left, 'leaveLivePk4Random');
      expect((await call('delete', `live/rooms/${b.room}/pk4/random`, b.user)).status).toBe(204);
      expect((await state(b.room, b.user)).queue).toBeNull();
      expect((await join4(c, 'TEAMS')).body.status).toBe('WAITING');
      expect((await join4(d, 'TEAMS')).body.status).toBe('WAITING');
      // Three waiting (a, c, d): b joins again as the fourth → matched.
      pk4.randomSource = () => 0;
      const matched = await join4(b, 'TEAMS');
      pk4.randomSource = null;
      expect(matched.status).toBe(200);
      expectContract(matched, 'joinLivePk4Random');
      expect(matched.body).toMatchObject({ status: 'MATCHED', queue: null });
      const m = matched.body.match as Match;
      expect(m).toMatchObject({ source: 'RANDOM', format: 'TEAMS', playerCount: 4 });
      expect(new Set(m.seats.map((s) => s.roomId))).toEqual(new Set([a.room, b.room, c.room, d.room]));
      expect(m.seats.filter((s) => s.team === 'A')).toHaveLength(2);
      for (const h of [a, c, d]) {
        expect(direct(h.room, h.user.id, 'pk4-queue').at(-1)).toMatchObject({
          status: 'MATCHED',
          matchId: m.id,
        });
      }
      expect(
        await ctx.prisma.pk4QueueEntry.count({
          where: { hostId: { in: [a, b, c, d].map((h) => h.user.id) } },
        }),
      ).toBe(0);
      // e (FREE_FOR_ALL) still waits, then stops.
      expect((await state(e.room, e.user)).queue).toMatchObject({ format: 'FREE_FOR_ALL' });
      expect((await call('delete', `live/rooms/${e.room}/pk4/random`, e.user)).status).toBe(204);
      for (const h of [a, b, c, d]) await end(h);
    });

    it('random: a block between any two keeps them apart; a busy host is refused; the wait runs out (told)', async () => {
      const hs = await hosts(5);
      const [a, b, c, d, x] = hs as [Host, Host, Host, Host, Host];
      const join4 = (h: Host) =>
        call('post', `live/rooms/${h.room}/pk4/random`, h.user, { format: 'FREE_FOR_ALL' });
      await ctx.prisma.userBlock.create({ data: { blockerId: c.user.id, blockedId: a.user.id } });
      for (const h of [a, b, c]) expect((await join4(h)).body.status).toBe('WAITING');
      // d: a, b, c are waiting, but c blocked a → no four can be made.
      expect((await join4(d)).body.status).toBe('WAITING');
      // A host in a lobby is busy.
      expect((await openLobby(x, 'TEAMS')).status).toBe(201);
      expectError(await join4(x), 409, 'PK_HOST_BUSY', 'joinLivePk4Random');
      expect((await call('delete', `live/rooms/${x.room}/pk4/lobby`, x.user)).status).toBe(204);
      // x joins: x, a, b, d fit (the longest waits first, c left out) → matched.
      const m = (await join4(x)).body as { status: string; match: Match };
      expect(m.status).toBe('MATCHED');
      expect(new Set(m.match.seats.map((s) => s.roomId))).toEqual(new Set([x.room, a.room, b.room, d.room]));
      expect(m.match.teams).toEqual([]);
      // c's wait runs out: deleted and told.
      await advance(121, c);
      await pk4.tick();
      expect(await ctx.prisma.pk4QueueEntry.count({ where: { hostId: c.user.id } })).toBe(0);
      expect(direct(c.room, c.user.id, 'pk4-queue').at(-1)).toMatchObject({ status: 'EXPIRED' });
      for (const h of [x, a, b, d]) await end(h);
    });

    // ---- «PK أحكام» for four ----------------------------------------------------------------------------------------

    it('dares TEAMS with four: the losing team does one dare (either answers), the winning team judges', async () => {
      pk4.darePick = () => 1;
      const { hs } = await lobbyBattle('TEAMS', 4, 'DARES');
      pk4.darePick = null;
      const [o, t, x, y] = hs as [Host, Host, Host, Host];
      await give([o, 500], [x, 100]);
      // A lucky gift adds no PK points in «PK أحكام».
      await send(t, luckyGift);
      expect(seatOf(await snapshot(o), t).score).toBe(0);
      pk4.darePick = () => 1;
      await timeUp(o, t, x, y);
      pk4.darePick = null;
      let m = await snapshot(o);
      expect(m.winnerTeam).toBe('A');
      expect(m.dare).toMatchObject({ status: 'DRAWING', drawn: 1 });
      expect(new Set(m.dare!.loserRoomIds)).toEqual(new Set([x.room, y.room]));
      expect(new Set(m.dare!.winnerRoomIds)).toEqual(new Set([o.room, t.room]));
      expectSchema('Pk4Match', m);
      // Before the reveal: closed; a winner cannot answer, a loser cannot judge.
      expectError(await call('post', `live/rooms/${x.room}/pk4/dare/accept`, x.user), 409, 'PK_DARE_CLOSED');
      await advance(5, o, t, x, y);
      expectError(
        await call('post', `live/rooms/${o.room}/pk4/dare/accept`, o.user),
        403,
        'PK_DARE_FORBIDDEN',
        'acceptLivePk4Dare',
      );
      const accepted = await call('post', `live/rooms/${y.room}/pk4/dare/accept`, y.user);
      expect(accepted.status).toBe(200);
      expectContract(accepted, 'acceptLivePk4Dare');
      expect((accepted.body as Match).dare!.status).toBe('ACTIVE');
      // The other loser's accept again is idempotent; a rematch waits for the dare.
      expect((await call('post', `live/rooms/${x.room}/pk4/dare/accept`, x.user)).status).toBe(200);
      expectError(
        await call('post', `live/rooms/${o.room}/pk4/rematch`, o.user),
        409,
        'PK_REMATCH_UNAVAILABLE',
      );
      expectError(
        await call('post', `live/rooms/${x.room}/pk4/dare/verdict`, x.user, { done: true }),
        403,
        'PK_DARE_FORBIDDEN',
      );
      // A viewer reports a card.
      const viewer = await signup();
      const rep = await call('post', `live/rooms/${y.room}/pk4/dare/report`, viewer, {
        dareId: m.dare!.options[0]!.id,
      });
      expect(rep.status).toBe(204);
      expectContract(rep, 'reportLivePk4Dare');
      // Either winner's verdict counts: not done → refused for both losers.
      const verdict = await call('post', `live/rooms/${t.room}/pk4/dare/verdict`, t.user, { done: false });
      expect(verdict.status).toBe(200);
      expectContract(verdict, 'judgeLivePk4Dare');
      m = verdict.body as Match;
      expect(m.dare).toMatchObject({ status: 'REFUSED', cause: 'WINNER_NOT_DONE', points: -3 });
      expectError(
        await call('post', `live/rooms/${o.room}/pk4/dare/verdict`, o.user, { done: true }),
        409,
        'PK_DARE_CLOSED',
      );
      for (const h of [x, y]) expect(await record(h.user)).toMatchObject({ daresRefused: 1, losses: 1 });
      expect(await record(o.user)).toMatchObject({ wins: 1, daresRefused: 0 });
      expect(
        await ctx.prisma.pk4PointEvent.count({
          where: { kind: 'DARE_REFUSED', hostId: { in: [x.user.id, y.user.id] } },
        }),
      ).toBe(2);
      for (const h of hs) await end(h);
    });

    it('dares FREE_FOR_ALL with three: the last place does it, the 1st judges, the 2nd may not; done counts', async () => {
      const { hs } = await lobbyBattle('FREE_FOR_ALL', 3, 'DARES');
      const [o, a, b] = hs as [Host, Host, Host];
      await give([a, 500], [o, 200], [b, 100]);
      await timeUp(o, a, b);
      let m = await snapshot(o);
      expect(m.dare!.loserRoomIds).toEqual([b.room]);
      expect(m.dare!.winnerRoomIds).toEqual([a.room]);
      await advance(5, o, a, b);
      expectError(
        await call('post', `live/rooms/${o.room}/pk4/dare/accept`, o.user),
        403,
        'PK_DARE_FORBIDDEN',
      );
      expect((await call('post', `live/rooms/${b.room}/pk4/dare/accept`, b.user)).status).toBe(200);
      expectError(
        await call('post', `live/rooms/${o.room}/pk4/dare/verdict`, o.user, { done: true }),
        403,
        'PK_DARE_FORBIDDEN',
      );
      m = (await call('post', `live/rooms/${a.room}/pk4/dare/verdict`, a.user, { done: true })).body as Match;
      expect(m.dare).toMatchObject({ status: 'DONE', cause: 'WINNER_DONE' });
      expect(await record(b.user)).toMatchObject({ daresDone: 1, daresRefused: 0 });
      expect(messages(o.room).at(-1)).toMatchObject({ event: 'dare' });
      for (const h of hs) await end(h);
    });

    it('dares FREE_FOR_ALL with four: the 4th left → the 3rd does it; no answer in time → refused', async () => {
      const { hs } = await lobbyBattle('FREE_FOR_ALL', 4, 'DARES');
      const [o, a, b, c] = hs as [Host, Host, Host, Host];
      await give([o, 500], [a, 300], [b, 200], [c, 100]);
      await end(c); // the 4th (lowest score) leaves the battle first
      await timeUp(o, a, b, c);
      let m = await snapshot(o);
      expect(m.seats.map((s) => s.place)).toEqual([1, 2, 3, 4]);
      expect(m.dare!.loserRoomIds).toEqual([b.room]);
      // In «PK أحكام» the host who left and lost gets the withdrawal's points, still a loss.
      expect(
        await ctx.prisma.pk4PointEvent.findFirst({ where: { hostId: c.user.id, kind: 'LOSS' } }),
      ).toMatchObject({
        points: -3,
      });
      await advance(5 + 31, o, a, b, c);
      await pk4.tick();
      m = await snapshot(o);
      expect(m.dare).toMatchObject({ status: 'REFUSED', cause: 'DECIDE_TIMEOUT' });
      expect(await record(b.user)).toMatchObject({ daresRefused: 1 });
      for (const h of hs) await end(h);
    });

    it('dares with two (like a 1 v 1): the loser refuses; a draw has no dare', async () => {
      const { hs } = await lobbyBattle('TEAMS', 2, 'DARES');
      const [o, t] = hs as [Host, Host];
      await give([t, 100]);
      await timeUp(o, t);
      expect((await snapshot(o)).dare).toMatchObject({ loserRoomIds: [o.room], winnerRoomIds: [t.room] });
      await advance(5, o, t);
      const refused = await call('post', `live/rooms/${o.room}/pk4/dare/refuse`, o.user);
      expect(refused.status).toBe(200);
      expectContract(refused, 'refuseLivePk4Dare');
      expect((refused.body as Match).dare).toMatchObject({ status: 'REFUSED', cause: 'LOSER_REFUSED' });
      expect((await call('post', `live/rooms/${o.room}/pk4/dare/refuse`, o.user)).status).toBe(200);
      for (const h of hs) await end(h);
      const draw = await lobbyBattle('TEAMS', 2, 'DARES');
      await timeUp(...draw.hs);
      expect((await snapshot(draw.hs[0]!)).dare).toBeNull();
      for (const h of draw.hs) await end(h);
    });

    // ---- «جولة أخرى» for four ---------------------------------------------------------------------------------------

    it('rematch with four: every host accepts; the last acceptance starts a new battle with the same places', async () => {
      const { hs, match } = await lobbyBattle('TEAMS', 4);
      const [o, t, x, y] = hs as [Host, Host, Host, Host];
      await give([o, 100]);
      await timeUp(o, t, x, y);
      const offered = await call('post', `live/rooms/${x.room}/pk4/rematch`, x.user);
      expect(offered.status).toBe(200);
      expectContract(offered, 'offerLivePk4Rematch');
      let m = offered.body as Match;
      expect(m.rematch).toMatchObject({ byRoomId: x.room, acceptedRoomIds: [x.room] });
      expect(new Set(m.rematch!.waitingRoomIds)).toEqual(new Set([o.room, t.room, y.room]));
      expect(messages(o.room).at(-1)).toMatchObject({ event: 'rematch-offer' });
      // Idempotent for the asking host; another host's offer is an acceptance.
      expect(
        ((await call('post', `live/rooms/${x.room}/pk4/rematch`, x.user)).body as Match).rematch!
          .acceptedRoomIds,
      ).toHaveLength(1);
      expect(
        ((await call('post', `live/rooms/${o.room}/pk4/rematch`, o.user)).body as Match).rematch!
          .acceptedRoomIds,
      ).toHaveLength(2);
      const third = await call('post', `live/rooms/${t.room}/pk4/rematch/accept`, t.user);
      expect(third.status).toBe(200);
      expectContract(third, 'acceptLivePk4Rematch');
      expect(messages(y.room).at(-1)).toMatchObject({ event: 'rematch-accepted' });
      m = (await call('post', `live/rooms/${y.room}/pk4/rematch/accept`, y.user)).body as Match;
      expect(m).toMatchObject({ status: 'BATTLE', source: 'REMATCH', rematchOf: match.id, playerCount: 4 });
      expect(m.seats.map((s) => [s.seat, s.roomId])).toEqual([
        [1, o.room],
        [2, t.room],
        [3, x.room],
        [4, y.room],
      ]);
      expect(m.seats.every((s) => s.score === 0)).toBe(true);
      for (const h of hs)
        expect(messages(h.room).at(-1)).toMatchObject({ event: 'rematch', match: { id: m.id } });
      expect((await ctx.prisma.pk4Match.findUniqueOrThrow({ where: { id: match.id } })).status).toBe(
        'CLOSED',
      );
      // The chain's watchers stay valid.
      expect(await pk4.allowsWatcher(o.room, `pk4:${match.id}:${fan.id}`)).toBe(true);
      for (const h of hs) await end(h);
    });

    it('rematch with three present (one left the battle): the present three accept; the new battle is two v one', async () => {
      const { hs } = await lobbyBattle('TEAMS', 4);
      const [o, t, x, y] = hs as [Host, Host, Host, Host];
      await give([x, 100]);
      await end(y); // y leaves the battle: not present for the rematch
      await timeUp(o, t, x, y);
      const offer = (await call('post', `live/rooms/${o.room}/pk4/rematch`, o.user)).body as Match;
      expect(new Set(offer.rematch!.waitingRoomIds)).toEqual(new Set([t.room, x.room]));
      // y is not present: may not accept.
      expectError(
        await call('post', `live/rooms/${y.room}/pk4/rematch/accept`, y.user),
        409,
        'PK_REMATCH_UNAVAILABLE',
      );
      await call('post', `live/rooms/${t.room}/pk4/rematch/accept`, t.user);
      const m = (await call('post', `live/rooms/${x.room}/pk4/rematch/accept`, x.user)).body as Match;
      expect(m).toMatchObject({ status: 'BATTLE', playerCount: 3 });
      expect(m.seats.map((s) => [s.seat, s.team, s.roomId])).toEqual([
        [1, 'A', o.room],
        [2, 'A', t.room],
        [3, 'B', x.room],
      ]);
      // y's room gets the old match's `closed`.
      expect(messages(y.room).at(-1)).toMatchObject({ event: 'closed' });
      expect((await state(y.room, y.user)).match).toBeNull();
      for (const h of [o, t, x]) await end(h);
    });

    it('rematch with two: a decline closes the PK; a lapsed offer closes it; the asking host may withdraw', async () => {
      const { hs } = await lobbyBattle('FREE_FOR_ALL', 2);
      const [o, a] = hs as [Host, Host];
      await timeUp(o, a);
      expect((await call('post', `live/rooms/${o.room}/pk4/rematch`, o.user)).status).toBe(200);
      // The asking host cannot decline their own offer; the other declines → closed.
      expectError(
        await call('post', `live/rooms/${o.room}/pk4/rematch/decline`, o.user),
        409,
        'PK_REMATCH_CLOSED',
      );
      const declined = await call('post', `live/rooms/${a.room}/pk4/rematch/decline`, a.user);
      expect(declined.status).toBe(204);
      expectContract(declined, 'declineLivePk4Rematch');
      expect(
        messages(o.room)
          .map((x) => x.event)
          .slice(-2),
      ).toEqual(['rematch-declined', 'closed']);
      // A second pair: the offer lapses (15 s) → closed.
      const second = await lobbyBattle('FREE_FOR_ALL', 2);
      await timeUp(...second.hs);
      await call('post', `live/rooms/${second.hs[0]!.room}/pk4/rematch`, second.hs[0]!.user);
      const withdrawn = await call(
        'delete',
        `live/rooms/${second.hs[0]!.room}/pk4/rematch`,
        second.hs[0]!.user,
      );
      expect(withdrawn.status).toBe(200);
      expectContract(withdrawn, 'cancelLivePk4Rematch');
      expect((withdrawn.body as Match).rematch).toBeNull();
      await call('post', `live/rooms/${second.hs[1]!.room}/pk4/rematch`, second.hs[1]!.user);
      await advance(16, ...second.hs);
      await pk4.tick();
      expect(
        messages(second.hs[0]!.room)
          .map((x) => x.event)
          .slice(-2),
      ).toEqual(['rematch-expired', 'closed']);
      // A dares rematch keeps its type; the rematch count limits it (PK_REMATCH_MAX, 5).
      const audit = await ctx.prisma.auditLog.count({ where: { action: 'live.pk4.rematch' } });
      expect(audit).toBeGreaterThan(0);
    });

    // ---- Busy rules with 1 v 1, the panel, moderation ---------------------------------------------------------------

    it('the panel shows the type, the hosts playing and the places; a moderator’s end cancels an open dare', async () => {
      const { hs, match } = await lobbyBattle('FREE_FOR_ALL', 3, 'DARES');
      const [o, a, b] = hs as [Host, Host, Host];
      // A 1 v 1 invitation to a host of the match is refused (busy in a 4-way PK).
      expectError(
        await call('post', `live/rooms/${(await live()).room}/pk/invites`, null, { toRoomId: a.room }),
        401,
        'AUTH_UNAUTHENTICATED',
      );
      const busy = await live();
      expectError(
        await call('post', `live/rooms/${busy.room}/pk/invites`, busy.user, { toRoomId: a.room }),
        409,
        'PK_HOST_BUSY',
      );
      const list = await admin.send(moderator, 'get', `/admin/lives/${o.room}`);
      expect(list.status, JSON.stringify(list.body)).toBe(200);
      expect(list.body.pk4).toMatchObject({ format: 'FREE_FOR_ALL', type: 'DARES', playerCount: 3 });
      expect(list.body.pk4.hosts).toHaveLength(3);
      await give([a, 300], [o, 100]);
      await timeUp(o, a, b);
      expect((await snapshot(o)).dare).not.toBeNull();
      const ended = await admin.send(moderator, 'post', `/admin/lives/${o.room}/pk4/end`, {
        reason: 'd395 moderation check',
      });
      expect(ended.status, JSON.stringify(ended.body)).toBe(200);
      const dare = await ctx.prisma.pk4MatchDare.findUniqueOrThrow({ where: { matchId: match.id } });
      expect(dare).toMatchObject({ status: 'CANCELLED', cause: 'ADMIN' });
      expect((await ctx.prisma.pk4Match.findUniqueOrThrow({ where: { id: match.id } })).status).toBe(
        'CLOSED',
      );
      void pk;
    });
  },
);
