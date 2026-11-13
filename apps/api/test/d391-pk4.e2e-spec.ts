/**
 * D391 (v1.118-live DRAFT, CONVENTIONS §10.180, CP-041 phase 2): «PK رباعي» — PK 2 v 2 (TEAMS) by invitation. The
 * lobby (open, cancel, leave, expiry), the invitations (accept, decline, cancel, expiry, a place offered again, a taken
 * place), the busy rules between the 1 v 1 and the 4-way PK, blocks between any two of the four, the start (BATTLE, or
 * CONNECTED with the organiser's auto-start off), team scores with boosters shared by the team and limits per team,
 * money never multiplied, hosts who leave (the teammate carries on, a team gone, everyone gone), the result by time,
 * records, the supporters per team, the moderator's end (CLI and panel), the media tokens for the three other rooms,
 * the webhook never counting `pk4:` watchers, mutes and every data message — each response and message checked against
 * the contract. End to end against PostgreSQL + Redis with the API as the DML-only runtime role; the media server is
 * the in-memory fake; time is a FakeClock and the PK tick is run by hand.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../src/config/app-config.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { LivePkService } from '../src/modules/live/live-pk.service.js';
import { LivePk4Service } from '../src/modules/live/live-pk4.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, expectSchema, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, settle, type TestContext } from './helpers/test-app.js';

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
  outReason: string | null;
  mutedRoomIds: string[];
  pkPoints: number;
}

interface Team {
  team: 'A' | 'B';
  score: number;
  result: string | null;
  boost: { kind: string; multiplier: number } | null;
  boosterUses: Record<string, number>;
  supporters: { user: { id: string }; points: number }[];
}

interface Match {
  id: string;
  status: string;
  endReason: string | null;
  winnerTeam: 'A' | 'B' | null;
  effective: boolean | null;
  seq: number;
  startedAt: string;
  battleEndsAt: string;
  roundSeconds: number;
  organiserRoomId: string;
  teams: [Team, Team];
  seats: Seat[];
}

interface Lobby {
  id: string;
  status: string;
  expiresAt: string;
  createdAt: string;
  matchId: string | null;
  seats: {
    seat: number;
    state: string;
    roomId: string | null;
    invite: { id: string; status: string } | null;
  }[];
}

interface Host {
  user: TestUser;
  room: string;
}

function pkAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'pk:admin', ...args], {
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

describe('D391 contract coverage', () => {
  it('openapi v1.118-live declares the 4-way PK operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'getLivePk4 GET /api/v1/live/rooms/{roomId}/pk4',
      'listLivePk4Candidates GET /api/v1/live/rooms/{roomId}/pk4/candidates',
      'openLivePk4Lobby POST /api/v1/live/rooms/{roomId}/pk4/lobby',
      'closeLivePk4Lobby DELETE /api/v1/live/rooms/{roomId}/pk4/lobby',
      'inviteLivePk4 POST /api/v1/live/rooms/{roomId}/pk4/lobby/invites',
      'cancelLivePk4Invite DELETE /api/v1/live/rooms/{roomId}/pk4/lobby/invites/{inviteId}',
      'acceptLivePk4Invite POST /api/v1/live/rooms/{roomId}/pk4/invites/{inviteId}/accept',
      'declineLivePk4Invite POST /api/v1/live/rooms/{roomId}/pk4/invites/{inviteId}/decline',
      'startLivePk4 POST /api/v1/live/rooms/{roomId}/pk4/start',
      'endLivePk4 POST /api/v1/live/rooms/{roomId}/pk4/end',
      'muteLivePk4Host POST /api/v1/live/rooms/{roomId}/pk4/mute',
      'createLivePk4MediaToken POST /api/v1/live/rooms/{roomId}/pk4/media-token',
      'endAdminLivePk4 POST /api/v1/admin/lives/{roomId}/pk4/end',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D391 PK 2 v 2', { timeout: 600_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let pk4: LivePk4Service;
  let pk: LivePkService;
  let config: AppConfig;
  let seq = 0;
  const boosterCodes: Record<string, string> = {};
  let plainGift = '';
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
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(user)).send({ title: 'PK4' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return { user, room: res.body.id as string };
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
  const openLobby = (h: Host) => call('post', `live/rooms/${h.room}/pk4/lobby`, h.user, { format: 'TEAMS' });
  const invite = (org: Host, to: Host, seat: number) =>
    call('post', `live/rooms/${org.room}/pk4/lobby/invites`, org.user, { toRoomId: to.room, seat });
  const accept = (h: Host, inviteId: string) =>
    call('post', `live/rooms/${h.room}/pk4/invites/${inviteId}/accept`, h.user);
  const decline = (h: Host, inviteId: string) =>
    call('post', `live/rooms/${h.room}/pk4/invites/${inviteId}/decline`, h.user);
  const inviteIdOf = (lobby: Lobby, seat: number) => lobby.seats.find((s) => s.seat === seat)!.invite!.id;
  const state = async (room: string, u: TestUser | null) => {
    const res = await call('get', `live/rooms/${room}/pk4`, u);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getLivePk4');
    return res.body as { match: Match | null; lobby: Lobby | null; invite: { id: string } | null };
  };
  const messages = (room: string, type: string) =>
    media.broadcasts
      .filter((b) => b.room === room && b.topic === 'pk')
      .map((b) => JSON.parse(b.payload) as { type: string; event: string; match: Match; boost?: object })
      .filter((m) => m.type === type);
  const direct = (room: string, identity: string, type: string) =>
    media.data
      .filter((d) => d.room === room && d.identity === identity)
      .map((d) => JSON.parse(d.payload) as { type: string; event?: string; lobby?: Lobby; invite?: object })
      .filter((m) => m.type === type);
  /** Organiser `o` invites `t` (2), `x` and `y` (3, 4); all accept: the match. */
  const battle = async (): Promise<{ o: Host; t: Host; x: Host; y: Host; match: Match }> => {
    const [o, t, x, y] = [await live(), await live(), await live(), await live()];
    const lobby = await openLobby(o);
    expect(lobby.status, JSON.stringify(lobby.body)).toBe(201);
    let last: request.Response | null = null;
    for (const [h, seat] of [
      [t, 2],
      [x, 3],
      [y, 4],
    ] as const) {
      const inv = await invite(o, h, seat);
      expect(inv.status, JSON.stringify(inv.body)).toBe(201);
      last = await accept(h, inviteIdOf(inv.body as Lobby, seat));
      expect(last.status, JSON.stringify(last.body)).toBe(200);
    }
    const match = (last!.body as { match: Match }).match;
    expect(match).not.toBeNull();
    return { o, t, x, y, match };
  };
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const gift = async (fields: Partial<GiftFields> = {}): Promise<string> => {
    seq += 1;
    const code = `pkf${String(seq)}_${randomUUID().slice(0, 6)}`;
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
  const send = async (h: Host, u: TestUser, code: string) => {
    // The sender watches the room (the media webhook's viewer row).
    await webhook('participant_joined', h.room, u.id);
    return call('post', `live/rooms/${h.room}/gifts`, u, {
      giftCode: code,
      quantity: 1,
      recipients: [h.user.username],
      source: 'COINS',
      clientId: randomUUID(),
    });
  };
  /** Moves the clock, the hosts' heartbeats kept fresh every 15 s (an absent host is the one left out). */
  const advance = async (seconds: number, ...hosts: Host[]) => {
    let left = seconds;
    while (left > 0) {
      const step = Math.min(left, 15);
      clock.advance(step);
      left -= step;
      for (const h of hosts) {
        expect((await call('post', `live/rooms/${h.room}/heartbeat`, h.user)).status).toBe(204);
      }
    }
  };
  const matchRow = (id: string) => ctx.prisma.pk4Match.findUniqueOrThrow({ where: { id } });
  const snapshot = async (h: Host) => (await state(h.room, h.user)).match!;
  const record = async (u: TestUser) => ctx.prisma.pkHostRecord.findUnique({ where: { hostId: u.id } });

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
    config = ctx.app.get<AppConfig>(APP_CONFIG);
    const prices: Record<string, number> = {
      DOUBLE: 1000,
      DOUBLE_TURBO: 2000,
      TRIPLE: 3000,
      TRIPLE_TURBO: 4000,
    };
    for (const kind of ['DOUBLE', 'DOUBLE_TURBO', 'TRIPLE', 'TRIPLE_TURBO'] as const) {
      boosterCodes[kind] = await gift({ pkBooster: kind, priceCoins: prices[kind]!, sortOrder: 0 });
    }
    plainGift = await gift({ priceCoins: 100 });
    moderator = await admin.makeAdmin(['MODERATION']);
  });
  afterAll(async () => ctx?.close());

  // ---- The lobby and the invitations -------------------------------------------------------------------------------

  it('lobby → three invitations by place → the fourth acceptance starts one round in the four rooms', async () => {
    const [o, t, x, y] = [await live(), await live(), await live(), await live()];
    const cands = await call('get', `live/rooms/${o.room}/pk4/candidates`, o.user);
    expect(cands.status).toBe(200);
    expectContract(cands, 'listLivePk4Candidates');
    expect((cands.body.data as { roomId: string }[]).map((c) => c.roomId)).toEqual(
      expect.arrayContaining([t.room, x.room, y.room]),
    );

    // No lobby yet → PK_LOBBY_CLOSED; FREE_FOR_ALL is phase 3.
    expectError(await invite(o, t, 2), 409, 'PK_LOBBY_CLOSED', 'inviteLivePk4');
    expectError(
      await call('post', `live/rooms/${o.room}/pk4/lobby`, o.user, { format: 'FREE_FOR_ALL' }),
      409,
      'PK_UNAVAILABLE',
      'openLivePk4Lobby',
    );
    const opened = await openLobby(o);
    expect(opened.status).toBe(201);
    expectContract(opened, 'openLivePk4Lobby');
    const lobby = opened.body as Lobby;
    expect(new Date(lobby.expiresAt).getTime() - new Date(lobby.createdAt).getTime()).toBe(120_000);
    expect(lobby.seats.map((s) => s.state)).toEqual(['ACCEPTED', 'EMPTY', 'EMPTY', 'EMPTY']);
    // A second lobby of the same room → busy.
    expectError(await openLobby(o), 409, 'PK_HOST_BUSY', 'openLivePk4Lobby');

    const inv2 = await invite(o, t, 2);
    expect(inv2.status).toBe(201);
    expectContract(inv2, 'inviteLivePk4');
    const seat2 = (inv2.body as Lobby).seats[1]!;
    expect(seat2).toMatchObject({ state: 'INVITED', roomId: t.room, invite: { status: 'PENDING' } });
    const told = direct(t.room, t.user.id, 'pk4-invite');
    expect(told.at(-1)).toMatchObject({
      invite: { id: seat2.invite!.id, seat: 2, team: 'A', status: 'PENDING' },
    });
    expectSchema('Pk4Invite', (told.at(-1) as { invite: object }).invite);
    const inv = told.at(-1) as { invite: { createdAt: string; expiresAt: string } };
    expect(new Date(inv.invite.expiresAt).getTime() - new Date(inv.invite.createdAt).getTime()).toBe(30_000);
    expect((await state(t.room, t.user)).invite).toMatchObject({ id: seat2.invite!.id });
    // The place is taken; the same host cannot be invited twice; only the organiser invites.
    expectError(await invite(o, x, 2), 409, 'PK_SEAT_TAKEN', 'inviteLivePk4');
    expectError(await invite(o, t, 3), 400, 'VALIDATION_FAILED', 'inviteLivePk4');
    expectError(
      await call('post', `live/rooms/${t.room}/pk4/lobby/invites`, t.user, { toRoomId: x.room, seat: 3 }),
      409,
      'PK_LOBBY_CLOSED',
      'inviteLivePk4',
    );
    // Only the invited host accepts.
    expectError(await accept(x, seat2.invite!.id), 404, 'NOT_FOUND', 'acceptLivePk4Invite');
    const acc2 = await accept(t, seat2.invite!.id);
    expect(acc2.status).toBe(200);
    expectContract(acc2, 'acceptLivePk4Invite');
    expect((acc2.body as { lobby: Lobby }).lobby.seats[1]!.state).toBe('ACCEPTED');
    const lobbyMsg = direct(o.room, o.user.id, 'pk4-lobby').at(-1)!;
    expect(lobbyMsg).toMatchObject({ event: 'accepted' });
    expectSchema('Pk4Lobby', lobbyMsg.lobby);

    const inv3 = await invite(o, x, 3);
    const inv4 = await invite(o, y, 4);
    expect([inv3.status, inv4.status]).toEqual([201, 201]);
    expect((await accept(x, inviteIdOf(inv3.body as Lobby, 3))).status).toBe(200);
    const last = await accept(y, inviteIdOf(inv4.body as Lobby, 4));
    expect(last.status).toBe(200);
    expectContract(last, 'acceptLivePk4Invite');
    const match = (last.body as { match: Match; lobby: Lobby | null }).match;
    expect((last.body as { lobby: Lobby | null }).lobby).toBeNull();
    expect(match).toMatchObject({
      status: 'BATTLE',
      format: 'TEAMS',
      organiserRoomId: o.room,
      winnerTeam: null,
    });
    expect(match.seats.map((s) => [s.seat, s.team, s.roomId])).toEqual([
      [1, 'A', o.room],
      [2, 'A', t.room],
      [3, 'B', x.room],
      [4, 'B', y.room],
    ]);
    expect(new Date(match.battleEndsAt).getTime() - new Date(match.startedAt).getTime()).toBe(300_000);
    for (const h of [o, t, x, y]) {
      const m = messages(h.room, 'pk4-match').at(-1)!;
      expect(m).toMatchObject({ event: 'started', match: { id: match.id } });
      expectSchema('Pk4Match', m.match);
      expect(direct(h.room, h.user.id, 'pk4-lobby').at(-1)).toMatchObject({ event: 'started' });
    }
    // Every host and viewer reads the match; guests too.
    const viewer = await signup();
    expect((await state(x.room, viewer)).match?.id).toBe(match.id);
    const guest = await ctx.http.get(`/api/v1/live/rooms/${y.room}/pk4`);
    expect(guest.status).toBe(200);
    expectContract(guest, 'getLivePk4');
    expect(guest.body).toMatchObject({ match: { id: match.id }, lobby: null, invite: null });
    // A room in a 4-way PK is «in a PK» for the hub.
    const summary = await ctx.http.get(`/api/v1/live/rooms/${t.room}`);
    expect(summary.body.inPk).toBe(true);
    await pk4.end(o.user.id, o.room);
  });

  it('declined, cancelled and expired places are offered again; the lobby runs out → nobody starts', async () => {
    const [o, t, x, y] = [await live(), await live(), await live(), await live()];
    expect((await openLobby(o)).status).toBe(201);
    // Declined → the place is free.
    const inv = await invite(o, t, 2);
    const id = inviteIdOf(inv.body as Lobby, 2);
    const dec = await decline(t, id);
    expect(dec.status).toBe(204);
    expectContract(dec, 'declineLivePk4Invite');
    expect(direct(o.room, o.user.id, 'pk4-lobby').at(-1)).toMatchObject({ event: 'declined' });
    expectError(await accept(t, id), 409, 'PK_INVITE_CLOSED', 'acceptLivePk4Invite');
    // Offered to another host; the organiser takes it back.
    const again = await invite(o, x, 2);
    expect(again.status).toBe(201);
    const cancel = await call(
      'delete',
      `live/rooms/${o.room}/pk4/lobby/invites/${inviteIdOf(again.body as Lobby, 2)}`,
      o.user,
    );
    expect(cancel.status).toBe(204);
    expectContract(cancel, 'cancelLivePk4Invite');
    expect(direct(x.room, x.user.id, 'pk4-invite').at(-1)).toMatchObject({ invite: { status: 'CANCELLED' } });
    // Expired after 30 s (the tick): both told, the place free.
    const late = await invite(o, y, 2);
    const lateId = inviteIdOf(late.body as Lobby, 2);
    clock.advance(31);
    await pk4.tick();
    expect(direct(y.room, y.user.id, 'pk4-invite').at(-1)).toMatchObject({ invite: { status: 'EXPIRED' } });
    expect(direct(o.room, o.user.id, 'pk4-lobby').at(-1)).toMatchObject({ event: 'invite-expired' });
    expectError(await accept(y, lateId), 409, 'PK_INVITE_CLOSED', 'acceptLivePk4Invite');
    // An accepted host leaves before the start: the place is free again.
    const inv3 = await invite(o, t, 3);
    expect((await accept(t, inviteIdOf(inv3.body as Lobby, 3))).status).toBe(200);
    const left = await call('delete', `live/rooms/${t.room}/pk4/lobby`, t.user);
    expect(left.status).toBe(204);
    expectContract(left, 'closeLivePk4Lobby');
    expect((await state(o.room, o.user)).lobby!.seats[2]!.state).toBe('EMPTY');
    // The lobby runs out (120 s) with places missing: EXPIRED, everyone told, no match.
    const inv4 = await invite(o, x, 4);
    expect((await accept(x, inviteIdOf(inv4.body as Lobby, 4))).status).toBe(200);
    clock.advance(120);
    await pk4.tick();
    expect(direct(o.room, o.user.id, 'pk4-lobby').at(-1)).toMatchObject({
      event: 'expired',
      lobby: { status: 'EXPIRED' },
    });
    expect(direct(x.room, x.user.id, 'pk4-lobby').at(-1)).toMatchObject({ event: 'expired' });
    expect((await state(o.room, o.user)).lobby).toBeNull();
    expect(await ctx.prisma.pk4Match.count({ where: { organiserRoomId: o.room } })).toBe(0);
    // The organiser cancels a new lobby: the open invitation is cancelled and the invited host told.
    expect((await openLobby(o)).status).toBe(201);
    await invite(o, y, 2);
    const cancelled = await call('delete', `live/rooms/${o.room}/pk4/lobby`, o.user);
    expect(cancelled.status).toBe(204);
    expect(direct(y.room, y.user.id, 'pk4-invite').at(-1)).toMatchObject({ invite: { status: 'CANCELLED' } });
    expectError(
      await call('delete', `live/rooms/${o.room}/pk4/lobby`, o.user),
      409,
      'PK_LOBBY_CLOSED',
      'closeLivePk4Lobby',
    );
  });

  it('busy rules: a host in either PK is busy for the other; a random-queue waiter may be invited', async () => {
    const [a, b, o, w] = [await live(), await live(), await live(), await live()];
    // A 1 v 1 battle makes both hosts busy for 4-way.
    const inv = await call('post', `live/rooms/${a.room}/pk/invites`, a.user, { toRoomId: b.room });
    expect(inv.status).toBe(201);
    // An open 1 v 1 invitation already counts.
    expect((await openLobby(o)).status).toBe(201);
    expectError(await invite(o, b, 3), 409, 'PK_HOST_BUSY', 'inviteLivePk4');
    expect(
      (await call('post', `live/rooms/${b.room}/pk/invites/${inv.body.id as string}/accept`, b.user)).status,
    ).toBe(200);
    expectError(await invite(o, a, 3), 409, 'PK_HOST_BUSY', 'inviteLivePk4');
    expectError(await openLobby(a), 409, 'PK_HOST_BUSY', 'openLivePk4Lobby');
    const cands = await call('get', `live/rooms/${o.room}/pk4/candidates`, o.user);
    expect((cands.body.data as { roomId: string }[]).map((c) => c.roomId)).not.toContain(a.room);
    // A host waiting in the random queue may be invited; accepting ends the wait.
    const queued = await call('post', `live/rooms/${w.room}/pk/random`, w.user, {});
    expect(queued.body.status).toBe('WAITING');
    const invW = await invite(o, w, 2);
    expect(invW.status).toBe(201);
    expect((await accept(w, inviteIdOf(invW.body as Lobby, 2))).status).toBe(200);
    expect(await ctx.prisma.pkQueueEntry.count({ where: { hostId: w.user.id } })).toBe(0);
    // Now the organiser and the accepted host are busy for PK 1 v 1: no invitation, not listed, no random wait.
    const c = await live();
    expect(
      (await call('post', `live/rooms/${c.room}/pk/invites`, c.user, { toRoomId: w.room })).body.error.code,
    ).toBe('PK_HOST_BUSY');
    expect(
      (await call('post', `live/rooms/${c.room}/pk/invites`, c.user, { toRoomId: o.room })).body.error.code,
    ).toBe('PK_HOST_BUSY');
    const oneVone = await call('get', `live/rooms/${c.room}/pk/candidates`, c.user);
    expectContract(oneVone, 'listLivePkCandidates');
    const listed = (oneVone.body.data as { roomId: string }[]).map((r) => r.roomId);
    expect(listed).not.toContain(o.room);
    expect(listed).not.toContain(w.room);
    expect((await call('post', `live/rooms/${o.room}/pk/random`, o.user, {})).body.error.code).toBe(
      'PK_HOST_BUSY',
    );
    // A pending 4-way invitation also makes the invited host busy (for another lobby and for PK 1 v 1).
    const o2 = await live();
    expect((await openLobby(o2)).status).toBe(201);
    const pending = await invite(o, c, 3);
    expect(pending.status).toBe(201);
    expectError(await invite(o2, c, 2), 409, 'PK_HOST_BUSY', 'inviteLivePk4');
    await call('delete', `live/rooms/${o.room}/pk4/lobby`, o.user);
    await call('delete', `live/rooms/${o2.room}/pk4/lobby`, o2.user);
    await pk.end(a.user.id, a.room);
    await pk.end(a.user.id, a.room);
  });

  it('a block between any two of the lobby refuses the invitation and hides the host', async () => {
    const [o, t, x] = [await live(), await live(), await live()];
    expect((await openLobby(o)).status).toBe(201);
    const inv = await invite(o, t, 2);
    expect((await accept(t, inviteIdOf(inv.body as Lobby, 2))).status).toBe(200);
    // x blocked the teammate (not the organiser).
    await ctx.prisma.userBlock.create({ data: { blockerId: x.user.id, blockedId: t.user.id } });
    expectError(await invite(o, x, 3), 404, 'NOT_FOUND', 'inviteLivePk4');
    const cands = await call('get', `live/rooms/${o.room}/pk4/candidates`, o.user);
    expect((cands.body.data as { roomId: string }[]).map((c) => c.roomId)).not.toContain(x.room);
    await call('delete', `live/rooms/${o.room}/pk4/lobby`, o.user);
  });

  // ---- The battle --------------------------------------------------------------------------------------------------

  it('team score = the sum of both hosts; boosters are the team’s (shared, limits per team); money unmultiplied', async () => {
    const { o, t, x, y } = await battle();
    const fan = await signup();
    await coins(fan, 1_000_000);
    const before = (await ctx.prisma.wallet.findUniqueOrThrow({ where: { userId: fan.id } })).coins;
    // Plain gifts in each room: each host's own points, the team's sum.
    expect((await send(o, fan, plainGift)).status).toBe(201);
    expect((await send(t, fan, plainGift)).status).toBe(201);
    expect((await send(x, fan, plainGift)).status).toBe(201);
    let m = await snapshot(o);
    expect(m.seats.map((s) => s.score)).toEqual([100, 100, 100, 0]);
    expect(m.teams.map((tm) => tm.score)).toEqual([200, 100]);
    await settle(ctx);
    expect(messages(x.room, 'pk4-match').at(-1)).toMatchObject({ event: 'score' });
    // DOUBLE sent in the teammate's room: active for both rooms of team A (the gift itself counts ×1).
    const boost = await send(t, fan, boosterCodes.DOUBLE!);
    expect(boost.status, JSON.stringify(boost.body)).toBe(201);
    await settle(ctx);
    const boostMsg = messages(y.room, 'pk4-match').at(-1)!;
    expect(boostMsg).toMatchObject({ event: 'boost', boost: { team: 'A', roomId: t.room, kind: 'DOUBLE' } });
    expectSchema('Pk4Match', boostMsg.match);
    expect((await send(o, fan, plainGift)).status).toBe(201); // ×2 in the organiser's room
    m = await snapshot(x);
    expect(m.seats.map((s) => s.score)).toEqual([300, 1100, 100, 0]);
    expect(m.teams[0]).toMatchObject({ score: 1400, boost: { kind: 'DOUBLE', multiplier: 2 } });
    expect(m.teams[1].boost).toBeNull();
    // Team B unaffected.
    expect((await send(y, fan, plainGift)).status).toBe(201);
    expect((await snapshot(y)).seats[3]!.score).toBe(100);
    // Limits per team: the second DOUBLE from the organiser's room is refused while the first is active (equal).
    const equal = await send(o, fan, boosterCodes.DOUBLE!);
    expectError(equal, 409, 'PK_BOOSTER_UNAVAILABLE');
    expect(equal.body.error.details).toEqual([{ field: 'giftCode', issue: 'active_higher' }]);
    await advance(31, o, t, x, y);
    expect((await send(o, fan, boosterCodes.DOUBLE!)).status).toBe(201);
    await advance(31, o, t, x, y);
    const third = await send(t, fan, boosterCodes.DOUBLE!);
    expect(third.body.error.details).toEqual([{ field: 'giftCode', issue: 'limit_reached' }]);
    m = await snapshot(o);
    expect(m.teams[0].boosterUses.DOUBLE).toBe(2);
    expect(m.teams[1].boosterUses.DOUBLE).toBe(0);
    // Team B may still use its own.
    expect((await send(x, fan, boosterCodes.DOUBLE!)).status).toBe(201);
    // Money: the sender paid the real price of each send, no multiplier.
    const after = (await ctx.prisma.wallet.findUniqueOrThrow({ where: { userId: fan.id } })).coins;
    expect(before - after).toBe(BigInt(100 * 5 + 1000 * 3)); // the refused boosters charged nothing
    // Supporters per team (from both rooms).
    expect(m.teams[0].supporters).toEqual([
      { user: expect.objectContaining({ id: fan.id }), points: m.teams[0].score },
    ]);
    await pk4.end(o.user.id, o.room);
    await pk4.end(t.user.id, t.room);
  });

  it('a host who leaves is out; the teammate carries on; both of a team out → the other team wins; records', async () => {
    const { o, t, x, y, match } = await battle();
    const fan = await signup();
    await coins(fan, 100_000);
    expect((await send(o, fan, plainGift)).status).toBe(201);
    // The organiser ends: out (FORFEIT), points kept, the battle goes on.
    const end = await call('post', `live/rooms/${o.room}/pk4/end`, o.user);
    expect(end.status).toBe(200);
    expectContract(end, 'endLivePk4');
    expect(end.body).toMatchObject({ status: 'BATTLE' });
    expect((end.body as Match).seats[0]).toMatchObject({ out: true, outReason: 'FORFEIT', score: 100 });
    expect(messages(x.room, 'pk4-match').at(-1)).toMatchObject({ event: 'out' });
    // Gifts in an out host's room no longer count.
    expect((await send(o, fan, plainGift)).status).toBe(201);
    expect((await snapshot(t)).teams[0].score).toBe(100);
    // The teammate leaves the media session for 30 s: team A gone → team B wins at once.
    await webhook('participant_left', t.room, t.user.id);
    await advance(31, t, x, y);
    await pk4.tick();
    const m = await snapshot(x);
    expect(m).toMatchObject({ status: 'RESULT', endReason: 'DISCONNECT', winnerTeam: 'B', effective: true });
    expect(m.teams.map((tm) => tm.result)).toEqual(['LOSS', 'WIN']);
    expect(messages(y.room, 'pk4-match').at(-1)).toMatchObject({ event: 'ended' });
    // Records: a win for each of team B, a loss for each of team A (with the PK points of the panel).
    for (const h of [x, y]) expect(await record(h.user)).toMatchObject({ wins: 1, losses: 0, points: 3 });
    for (const h of [o, t]) expect(await record(h.user)).toMatchObject({ wins: 0, losses: 1 });
    // Idempotent: another tick writes nothing more.
    await pk4.tick();
    expect(await record(x.user)).toMatchObject({ wins: 1 });
    // RESULT → CLOSED after PK_RESULT_SECONDS; the places are released and the watchers removed.
    await advance(61, x, y);
    await pk4.tick();
    expect((await matchRow(match.id)).status).toBe('CLOSED');
    expect(messages(o.room, 'pk4-match').at(-1)).toMatchObject({ event: 'closed' });
    expect(await ctx.prisma.pk4Seat.count({ where: { matchId: match.id, active: true } })).toBe(0);
    // Free again for PK 1 v 1.
    expect((await call('post', `live/rooms/${x.room}/pk/invites`, x.user, { toRoomId: y.room })).status).toBe(
      201,
    );
  });

  it('everyone gone at once → a draw, void for the records; the time running out → the higher team wins', async () => {
    const one = await battle();
    for (const h of [one.o, one.t, one.x, one.y]) {
      expect((await call('post', `live/rooms/${h.room}/end`, h.user)).status).toBe(200);
    }
    await pk4.tick();
    const gone = await matchRow(one.match.id);
    expect(gone).toMatchObject({ endReason: 'FORFEIT', winnerTeam: null, effective: false });
    for (const h of [one.o, one.x]) expect(await record(h.user)).toBeNull();

    const two = await battle();
    const fan = await signup();
    await coins(fan, 100_000);
    expect((await send(two.x, fan, plainGift)).status).toBe(201);
    expect((await send(two.y, fan, plainGift)).status).toBe(201);
    expect((await send(two.t, fan, plainGift)).status).toBe(201);
    await advance(301, two.o, two.t, two.x, two.y);
    await pk4.tick();
    const m = await snapshot(two.o);
    expect(m).toMatchObject({ status: 'RESULT', endReason: 'TIME', winnerTeam: 'B' });
    expect(m.teams.map((tm) => tm.score)).toEqual([100, 200]);
    expect(await record(two.t.user)).toMatchObject({ losses: 1 });
    expect(await record(two.y.user)).toMatchObject({ wins: 1 });
    // A host's End during the result closes it for the four rooms.
    const end = await call('post', `live/rooms/${two.t.room}/pk4/end`, two.t.user);
    expect(end.body).toMatchObject({ status: 'CLOSED' });
  });

  it('auto-start off → CONNECTED; any of the four starts it; End while CONNECTED cancels it (void)', async () => {
    const [o, t, x, y] = [await live(), await live(), await live(), await live()];
    await call('put', 'me/live-pk', o.user, { autoStart: false, roundMinutes: 3 });
    expect((await openLobby(o)).status).toBe(201);
    let last: request.Response | null = null;
    for (const [h, seat] of [
      [t, 2],
      [x, 3],
      [y, 4],
    ] as const) {
      const inv = await invite(o, h, seat);
      last = await accept(h, inviteIdOf(inv.body as Lobby, seat));
    }
    const match = (last!.body as { match: Match }).match;
    expect(match).toMatchObject({ status: 'CONNECTED', roundSeconds: 180 });
    expect(messages(x.room, 'pk4-match').at(-1)).toMatchObject({ event: 'connected' });
    // Boosters refused while CONNECTED.
    const fan = await signup();
    await coins(fan, 100_000);
    expect((await send(x, fan, boosterCodes.DOUBLE!)).body.error.details).toEqual([
      { field: 'giftCode', issue: 'no_match' },
    ]);
    const start = await call('post', `live/rooms/${y.room}/pk4/start`, y.user);
    expect(start.status).toBe(200);
    expectContract(start, 'startLivePk4');
    expect(start.body).toMatchObject({ status: 'BATTLE' });
    const again = await call('post', `live/rooms/${o.room}/pk4/start`, o.user);
    expect(again.body).toMatchObject({ status: 'BATTLE', seq: (start.body as Match).seq });
    await pk4.end(o.user.id, o.room);
    // Busy while its result shows.
    expectError(await openLobby(o), 409, 'PK_HOST_BUSY', 'openLivePk4Lobby');
    await pk4.end(t.user.id, t.room);
    await pk4.end(t.user.id, t.room);
    // A second lobby with the same four (auto-start still off), cancelled by an End while CONNECTED.
    expect((await openLobby(o)).status).toBe(201);
    for (const [h, seat] of [
      [t, 2],
      [x, 3],
      [y, 4],
    ] as const) {
      const inv = await invite(o, h, seat);
      expect(inv.status, JSON.stringify(inv.body)).toBe(201);
      last = await accept(h, inviteIdOf(inv.body as Lobby, seat));
    }
    const connected = (last!.body as { match: Match }).match;
    expect(connected.status).toBe('CONNECTED');
    const cancel = await call('post', `live/rooms/${x.room}/pk4/end`, x.user);
    expect(cancel.body).toMatchObject({ status: 'CLOSED', endReason: 'CANCELLED', effective: false });
  });

  it('mute any of the other three for the own room', async () => {
    const { o, x, match } = await battle();
    const res = await call('post', `live/rooms/${o.room}/pk4/mute`, o.user, { roomId: x.room, muted: true });
    expect(res.status).toBe(200);
    expectContract(res, 'muteLivePk4Host');
    expect((res.body as Match).seats[0]!.mutedRoomIds).toEqual([x.room]);
    expect(messages(x.room, 'pk4-match').at(-1)).toMatchObject({ event: 'mute' });
    expectError(
      await call('post', `live/rooms/${o.room}/pk4/mute`, o.user, { roomId: o.room, muted: true }),
      400,
      'VALIDATION_FAILED',
      'muteLivePk4Host',
    );
    const off = await call('post', `live/rooms/${o.room}/pk4/mute`, o.user, { roomId: x.room, muted: false });
    expect((off.body as Match).seats[0]!.mutedRoomIds).toEqual([]);
    await pk4.end(o.user.id, o.room);
    expect((await matchRow(match.id)).status).toBe('BATTLE');
  });

  // ---- Media -------------------------------------------------------------------------------------------------------

  it('media tokens for the three other rooms; the webhook never counts `pk4:` watchers; the cap', async () => {
    const { o, t, x, y, match } = await battle();
    const viewer = await signup();
    const res = await call('post', `live/rooms/${x.room}/pk4/media-token`, viewer, {});
    expect(res.status).toBe(200);
    expectContract(res, 'createLivePk4MediaToken');
    expect(res.body).toMatchObject({ layer: 'LOW', capped: false });
    const rooms = res.body.rooms as { roomId: string; identity: string; hostIdentity: string }[];
    expect(rooms.map((r) => r.roomId).sort()).toEqual([o.room, t.room, y.room].sort());
    expect(rooms.every((r) => r.identity === `pk4:${match.id}:${viewer.id}`)).toBe(true);
    expect(rooms.find((r) => r.roomId === o.room)!.hostIdentity).toBe(o.user.id);
    const issued = media.issued.filter((i) => i.identity === `pk4:${match.id}:${viewer.id}`);
    expect(issued.every((i) => i.publish === false)).toBe(true);
    // The host's own: MEDIUM.
    const hostTok = await call('post', `live/rooms/${o.room}/pk4/media-token`, o.user, {});
    expect(hostTok.body).toMatchObject({ layer: 'MEDIUM' });
    // A guest needs its guest id.
    const guestId = randomUUID();
    const guest = await call('post', `live/rooms/${y.room}/pk4/media-token`, null, { guestId });
    expect(guest.status).toBe(200);
    expect((guest.body.rooms as { identity: string }[])[0]!.identity).toBe(
      `pk4:${match.id}:guest:${guestId}`,
    );
    // A watcher joining another room is never a viewer there.
    const before = (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: o.room } })).viewerCount;
    await webhook('participant_joined', o.room, `pk4:${match.id}:${viewer.id}`);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: o.room } })).viewerCount).toBe(before);
    expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId: o.room } })).toBe(0);
    expect(media.removed.some((r) => r.room === o.room && r.identity.startsWith('pk4:'))).toBe(false);
    await webhook('participant_left', o.room, `pk4:${match.id}:${viewer.id}`);
    // A watcher of another match (or a room not in it) is disconnected.
    const stray = `pk4:${randomUUID()}:${viewer.id}`;
    await webhook('participant_joined', o.room, stray);
    expect(media.removed).toContainEqual({ room: o.room, identity: stray });
    // The cap: a room with that many watchers is left out.
    await webhook('participant_joined', o.room, `pk4:${match.id}:${viewer.id}`);
    const cap = config.pk.pk4 as { maxWatchersPerRoom: number };
    cap.maxWatchersPerRoom = 1;
    try {
      const other = await signup();
      const capped = await call('post', `live/rooms/${x.room}/pk4/media-token`, other, {});
      expect(capped.body).toMatchObject({ capped: true });
      expect((capped.body.rooms as { roomId: string }[]).map((r) => r.roomId)).not.toContain(o.room);
    } finally {
      cap.maxWatchersPerRoom = 0;
    }
    // The match closes → the watchers are removed from the four rooms.
    await pk4.end(o.user.id, o.room);
    await pk4.end(t.user.id, t.room);
    await pk4.end(o.user.id, o.room);
    expect(media.removed).toContainEqual({ room: o.room, identity: `pk4:${match.id}:${viewer.id}` });
    expectError(
      await call('post', `live/rooms/${x.room}/pk4/media-token`, viewer, {}),
      409,
      'PK_NOT_ACTIVE',
      'createLivePk4MediaToken',
    );
  });

  // ---- Moderation --------------------------------------------------------------------------------------------------

  it('the panel lists 4-way rooms and a moderator ends one (void); `pk-admin end` takes a 4-way id', async () => {
    const one = await battle();
    const list = await admin.send(moderator, 'get', '/admin/lives?mode=PK');
    expect(list.status, JSON.stringify(list.body)).toBe(200);
    expectContract(list, 'listAdminLives');
    const row = (
      list.body.data as { id: string; pk4: { matchId: string; team: string; hosts: unknown[] } | null }[]
    ).find((r) => r.id === one.x.room);
    expect(row?.pk4).toMatchObject({ matchId: one.match.id, team: 'B' });
    expect(row?.pk4?.hosts).toHaveLength(4);
    const detail = await admin.send(moderator, 'get', `/admin/lives/${one.t.room}`);
    expectContract(detail, 'getAdminLive');
    expect(detail.body.pk4).toMatchObject({ matchId: one.match.id, team: 'A' });
    const ended = await admin.send(moderator, 'post', `/admin/lives/${one.t.room}/pk4/end`, {
      reason: 'test',
    });
    expect(ended.status, JSON.stringify(ended.body)).toBe(200);
    expectContract(ended, 'endAdminLivePk4');
    expect(ended.body).toEqual({ matchId: one.match.id, previousStatus: 'BATTLE' });
    expect(await matchRow(one.match.id)).toMatchObject({
      status: 'CLOSED',
      endReason: 'ADMIN',
      effective: false,
    });
    expect(messages(one.y.room, 'pk4-match').at(-1)).toMatchObject({ event: 'closed' });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'live.pk.admin_end', targetId: one.match.id } }),
    ).toBe(1);
    const again = await admin.send(moderator, 'post', `/admin/lives/${one.t.room}/pk4/end`, { reason: 'x' });
    expect(again.body.error.code).toBe('PK_NOT_ACTIVE');

    const two = await battle();
    expect(pkAdmin('list').out).toContain(`${two.match.id} BATTLE PK4/TEAMS`);
    expect(pkAdmin('show', two.match.id).out).toContain('PK4/TEAMS');
    const cli = pkAdmin('end', two.match.id, '--reason', 'moderator test');
    expect(cli.status, cli.out).toBe(0);
    expect(await matchRow(two.match.id)).toMatchObject({ status: 'CLOSED', endReason: 'ADMIN' });
    await pk4.tick();
    expect(messages(two.o.room, 'pk4-match').at(-1)).toMatchObject({ event: 'closed' });
    expect(await record(two.o.user)).toBeNull();
  });
});
