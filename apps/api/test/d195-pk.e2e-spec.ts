/**
 * D195 (v1.43-live DRAFT, CONVENTIONS §10.58, CP-038): PK 1 v 1 between two SOLO video lives —
 * invitations (accept, decline, cancel, expiry, cooldown, the switch), the random queue, scores from
 * gifts (idempotent), the four boosters (multipliers, windows, limits, replacement), money never
 * multiplied, forfeit / disconnect / away, a draw, the snapshot, blocks, the moderator's end
 * (`pk-admin`), records and history, PK guests (3 seats) and the cross-room media token. End to end
 * against PostgreSQL + Redis with the API as the DML-only runtime role; the media server is the
 * in-memory fake that records every data message; time is a FakeClock and the PK tick is run by hand.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { LivePkService } from '../src/modules/live/live-pk.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
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
  readonly email: string;
  readonly token: string;
}

interface Side {
  roomId: string;
  score: number;
  boost: { kind: string; multiplier: number; endsAt: string } | null;
  boosterUses: Record<string, number>;
  supporters: { user: { id: string }; points: number }[];
  guests: { user: { id: string }; seatIndex: number }[];
  mutesOpponent: boolean;
}

interface Match {
  id: string;
  status: string;
  endReason: string | null;
  winnerRoomId: string | null;
  loserCauseRoomId: string | null;
  seq: number;
  sides: [Side, Side];
  boosters: { kind: string; giftCode: string | null }[];
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

describe('D195 contract coverage', () => {
  it('openapi v1.43-live declares the PK operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'getLivePk GET /api/v1/live/rooms/{roomId}/pk',
      'listLivePkCandidates GET /api/v1/live/rooms/{roomId}/pk/candidates',
      'inviteLivePk POST /api/v1/live/rooms/{roomId}/pk/invites',
      'cancelLivePkInvite DELETE /api/v1/live/rooms/{roomId}/pk/invites/{inviteId}',
      'acceptLivePkInvite POST /api/v1/live/rooms/{roomId}/pk/invites/{inviteId}/accept',
      'declineLivePkInvite POST /api/v1/live/rooms/{roomId}/pk/invites/{inviteId}/decline',
      'joinLivePkRandom POST /api/v1/live/rooms/{roomId}/pk/random',
      'leaveLivePkRandom DELETE /api/v1/live/rooms/{roomId}/pk/random',
      'endLivePk POST /api/v1/live/rooms/{roomId}/pk/end',
      'muteLivePkOpponent POST /api/v1/live/rooms/{roomId}/pk/mute-opponent',
      'createLivePkMediaToken POST /api/v1/live/rooms/{roomId}/pk/media-token',
      'getLivePkHost GET /api/v1/live/pk/hosts/{username}',
      'getMyLivePk GET /api/v1/me/live-pk',
      'setMyLivePk PUT /api/v1/me/live-pk',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D195 PK 1 v 1', { timeout: 300_000 }, () => {
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
  const matchOf = async (id: string) => ctx.prisma.pkMatch.findUniqueOrThrow({ where: { id } });
  const pkMessages = (roomId: string) =>
    media.broadcasts
      .filter((b) => b.room === roomId && b.topic === 'pk')
      .map(
        (b) =>
          JSON.parse(b.payload) as { type: string; event: string; match: Match; boost?: { kind: string } },
      );
  const cherries = async (u: TestUser) =>
    (await ctx.prisma.cherryWallet.findUnique({ where: { userId: u.id } }))?.cherries ?? 0n;
  const liveScore = async (roomId: string) =>
    (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).score;
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
    // D199: these D195 matches use small gifts; every finished match counts (no «effective PK» floor).
    ctx = await createTestApp(
      { LIVE_HOSTING_ENABLED: 'true', PK_SCORE_BROADCAST_MS: '0', PK_EFFECTIVE_MIN_POINTS: '0' },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
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

  // ---- Invitations ------------------------------------------------------------------------------

  it('invite → the invited host gets a pk-invite message → accept starts a 5-minute battle for both rooms', async () => {
    const [a, b] = [await host(), await host()];
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    const cands = await call('get', `live/rooms/${roomA}/pk/candidates`, a);
    expect(cands.status).toBe(200);
    expectContract(cands, 'listLivePkCandidates');
    expect((cands.body.data as { roomId: string }[]).map((c) => c.roomId)).toContain(roomB);
    expect((cands.body.data as { roomId: string }[]).map((c) => c.roomId)).not.toContain(roomA);

    const inv = await invite(roomA, a, roomB);
    expect(inv.status).toBe(201);
    expectContract(inv, 'inviteLivePk');
    expect(inv.body).toMatchObject({ status: 'PENDING', fromRoomId: roomA, toRoomId: roomB });
    expect(
      new Date(inv.body.expiresAt as string).getTime() - new Date(inv.body.createdAt as string).getTime(),
    ).toBe(15_000);
    const told = media.data
      .filter((d) => d.room === roomB && d.identity === b.id)
      .map((d) => JSON.parse(d.payload) as unknown);
    expect(told.at(-1)).toMatchObject({ type: 'pk-invite', invite: { id: inv.body.id, status: 'PENDING' } });
    expect((await state(roomB, b)).invite).toMatchObject({ id: inv.body.id });
    expect((await state(roomA, a)).invite).toMatchObject({ id: inv.body.id });

    // Only the invited host may accept.
    expectError(await acceptInvite(roomA, a, inv.body.id as string), 404, 'NOT_FOUND', 'acceptLivePkInvite');
    const acc = await acceptInvite(roomB, b, inv.body.id as string);
    expect(acc.status).toBe(200);
    expectContract(acc, 'acceptLivePkInvite');
    const match = acc.body as Match & { battleEndsAt: string; startedAt: string };
    expect(match).toMatchObject({ status: 'BATTLE', source: 'INVITE', endReason: null, winnerRoomId: null });
    expect(match.sides.map((s) => s.roomId)).toEqual([roomA, roomB]);
    expect(new Date(match.battleEndsAt).getTime() - new Date(match.startedAt).getTime()).toBe(300_000);
    expect(match.boosters.map((r) => [r.kind, r.giftCode !== null])).toEqual([
      ['DOUBLE', true],
      ['DOUBLE_TURBO', true],
      ['TRIPLE', true],
      ['TRIPLE_TURBO', true],
    ]);
    for (const room of [roomA, roomB]) {
      expect(pkMessages(room).at(-1)).toMatchObject({
        type: 'pk-match',
        event: 'started',
        match: { id: match.id },
      });
    }
    // Both are busy now: a second invitation either way → PK_HOST_BUSY.
    const c = await host();
    const roomC = await goLive(c);
    expectError(await invite(roomC, c, roomA), 409, 'PK_HOST_BUSY', 'inviteLivePk');
    // The battle is the room's snapshot for viewers and guests too.
    const viewer = await signup();
    expect((await state(roomA, viewer)).match?.id).toBe(match.id);
    const guest = await ctx.http.get(`/api/v1/live/rooms/${roomB}/pk`);
    expect(guest.status).toBe(200);
    expect(guest.body).toMatchObject({
      match: { id: match.id },
      invite: null,
      queue: null,
      invitesEnabled: null,
    });
  });

  it('decline, cancel and expiry (15 s) close an invitation; a closed one cannot be accepted', async () => {
    const [a, b] = [await host(), await host()];
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    const one = await invite(roomA, a, roomB);
    const dec = await call('post', `live/rooms/${roomB}/pk/invites/${one.body.id as string}/decline`, b);
    expect(dec.status).toBe(204);
    expectError(await acceptInvite(roomB, b, one.body.id as string), 409, 'PK_INVITE_CLOSED');
    expect(
      media.data
        .filter((d) => d.identity === a.id)
        .map((d) => JSON.parse(d.payload) as unknown)
        .at(-1),
    ).toMatchObject({
      type: 'pk-invite',
      invite: { status: 'DECLINED' },
    });

    // Cooldown: 10 s between two invitations of the same host.
    const soon = await invite(roomA, a, roomB);
    expectError(soon, 409, 'PK_INVITE_COOLDOWN', 'inviteLivePk');
    expect(Number(soon.headers['retry-after'])).toBeGreaterThan(0);
    await advance(10, [roomA, a], [roomB, b]);
    const two = await invite(roomA, a, roomB);
    expect(two.status).toBe(201);
    const del = await call('delete', `live/rooms/${roomA}/pk/invites/${two.body.id as string}`, a);
    expect(del.status).toBe(204);
    expectError(await acceptInvite(roomB, b, two.body.id as string), 409, 'PK_INVITE_CLOSED');

    await advance(10, [roomA, a], [roomB, b]);
    const three = await invite(roomA, a, roomB);
    expect(three.status).toBe(201);
    await advance(15, [roomA, a], [roomB, b]);
    expect((await pk.tick()).expiredInvites).toBeGreaterThanOrEqual(1);
    expect(
      (await ctx.prisma.pkInvite.findUniqueOrThrow({ where: { id: three.body.id as string } })).status,
    ).toBe('EXPIRED');
    expectError(
      await acceptInvite(roomB, b, three.body.id as string),
      409,
      'PK_INVITE_CLOSED',
      'acceptLivePkInvite',
    );
  });

  it('a host who switched invitations off cannot be invited and is not a candidate', async () => {
    const [a, b] = [await host(), await host()];
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    const off = await call('put', 'me/live-pk', b, { invitesEnabled: false });
    expect(off.status).toBe(200);
    expectContract(off, 'setMyLivePk');
    expect(off.body).toMatchObject({ invitesEnabled: false, record: { wins: 0, losses: 0, draws: 0 } });
    expectError(await invite(roomA, a, roomB), 409, 'PK_INVITES_OFF');
    const cands = await call('get', `live/rooms/${roomA}/pk/candidates`, a);
    expect((cands.body.data as { roomId: string }[]).map((c) => c.roomId)).not.toContain(roomB);
    await call('put', 'me/live-pk', b, { invitesEnabled: true });
  });

  it('blocked hosts (either way) are never candidates, invited (404) or paired at random', async () => {
    const [a, b] = [await host(), await host()];
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    await ctx.prisma.userBlock.create({ data: { blockerId: b.id, blockedId: a.id } });
    const cands = await call('get', `live/rooms/${roomA}/pk/candidates`, a);
    expect((cands.body.data as { roomId: string }[]).map((c) => c.roomId)).not.toContain(roomB);
    expectError(await invite(roomA, a, roomB), 404, 'NOT_FOUND', 'inviteLivePk');
    // Make sure no one else waits in the queue (earlier tests).
    await ctx.prisma.pkQueueEntry.deleteMany({});
    const ra = await call('post', `live/rooms/${roomA}/pk/random`, a);
    expect(ra.body.status).toBe('WAITING');
    const rb = await call('post', `live/rooms/${roomB}/pk/random`, b);
    expect(rb.body.status).toBe('WAITING');
    await call('delete', `live/rooms/${roomA}/pk/random`, a);
    await call('delete', `live/rooms/${roomB}/pk/random`, b);
  });

  it('random match: the first host waits, the second is paired with them at once; a wait expires after 60 s', async () => {
    await ctx.prisma.pkQueueEntry.deleteMany({});
    const [a, b, c] = [await host(), await host(), await host()];
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    const roomC = await goLive(c);
    const first = await call('post', `live/rooms/${roomA}/pk/random`, a);
    expect(first.status).toBe(200);
    expectContract(first, 'joinLivePkRandom');
    expect(first.body).toMatchObject({ status: 'WAITING', match: null });
    // Again: the same wait.
    expect((await call('post', `live/rooms/${roomA}/pk/random`, a)).body.queue).toEqual(first.body.queue);
    expect((await state(roomA, a)).queue).toEqual(first.body.queue);
    const second = await call('post', `live/rooms/${roomB}/pk/random`, b);
    expect(second.body.status).toBe('MATCHED');
    expect((second.body.match as Match).sides.map((s) => s.roomId)).toEqual([roomA, roomB]);
    expect(await ctx.prisma.pkQueueEntry.count({ where: { hostId: { in: [a.id, b.id] } } })).toBe(0);

    // A busy host cannot queue.
    expectError(
      await call('post', `live/rooms/${roomA}/pk/random`, a),
      409,
      'PK_HOST_BUSY',
      'joinLivePkRandom',
    );
    const waiting = await call('post', `live/rooms/${roomC}/pk/random`, c);
    expect(waiting.body.status).toBe('WAITING');
    await advance(60, [roomC, c]);
    await pk.tick();
    expect(await ctx.prisma.pkQueueEntry.count({ where: { hostId: c.id } })).toBe(0);
    expect(
      media.data
        .filter((d) => d.identity === c.id)
        .map((d) => JSON.parse(d.payload) as unknown)
        .at(-1),
    ).toEqual({
      type: 'pk-queue',
      status: 'EXPIRED',
    });
  });

  it('D210: a wait whose live ended is dropped at the next tick and never messaged', async () => {
    const c = await host();
    const roomC = await goLive(c);
    expect((await call('post', `live/rooms/${roomC}/pk/random`, c)).body.status).toBe('WAITING');
    expect((await ctx.http.post(`/api/v1/live/rooms/${roomC}/end`).set(auth(c))).status).toBe(200);
    const before = media.data.length;
    await pk.tick();
    expect(await ctx.prisma.pkQueueEntry.count({ where: { hostId: c.id } })).toBe(0);
    // Long past the wait's own expiry: still nothing is sent to the ended room.
    await advance(120);
    await pk.tick();
    expect(media.data.slice(before).filter((d) => d.room === roomC || d.identity === c.id)).toEqual([]);
  });

  it('only a SOLO video live of the caller may start a PK', async () => {
    const [a, b] = [await host(), await host()];
    const audio = await goLive(a, { mode: 'AUDIO', seatCount: 10 });
    const roomB = await goLive(b);
    expectError(await invite(audio, a, roomB), 409, 'PK_UNAVAILABLE', 'inviteLivePk');
    expectError(await invite(roomB, a, audio), 404, 'NOT_FOUND');
  });

  // ---- Scores and boosters ------------------------------------------------------------------------

  it('PK points are the coin value of gifts sent in each room; a retried send is counted once', async () => {
    const { a, b, roomA, roomB, match } = await battle();
    const fan = await signup();
    await coins(fan, 100_000);
    await join(roomA, fan);
    const code = await gift({ priceCoins: 250 });
    const clientId = randomUUID();
    const first = await send(roomA, fan, code, [a], { clientId });
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    const retry = await send(roomA, fan, code, [a], { clientId });
    expect(retry.status).toBe(200);
    // Gifts in the other room count for the other side.
    const fan2 = await signup();
    await coins(fan2, 100_000);
    await join(roomB, fan2);
    expect((await send(roomB, fan2, code, [b], { quantity: 10 })).status).toBe(201);
    await settle(ctx);
    const m = await matchOf(match.id);
    expect([m.scoreA, m.scoreB]).toEqual([250n, 2500n]);
    expect(await ctx.prisma.pkGiftPoint.count({ where: { matchId: match.id } })).toBe(2);
    const snap = (await state(roomB, fan2)).match!;
    expect(snap.sides[0]).toMatchObject({
      roomId: roomA,
      score: 250,
      supporters: [{ user: { id: fan.id }, points: 250 }],
    });
    expect(snap.sides[1]).toMatchObject({
      roomId: roomB,
      score: 2500,
      supporters: [{ user: { id: fan2.id }, points: 2500 }],
    });
    expect(
      pkMessages(roomA)
        .filter((p) => p.event === 'score')
        .at(-1)?.match.sides[1].score,
    ).toBe(2500);
  });

  it('boosters: Double ×2 any time; Triple too early is refused and charges nothing; limits; higher replaces lower', async () => {
    const { a, roomA, roomB, b, match } = await battle();
    const fan = await signup();
    await coins(fan, 1_000_000);
    await join(roomA, fan);
    const code = await gift({ priceCoins: 100 });
    // Not to a guest or more than one: the host alone, quantity 1.
    expectError(
      await send(roomA, fan, boosterCodes.DOUBLE!, [a], { quantity: 10 }),
      400,
      'VALIDATION_FAILED',
    );
    // Triple in the first minute: refused, nothing charged.
    const before = (await ctx.prisma.wallet.findUniqueOrThrow({ where: { userId: fan.id } })).coins;
    const early = await send(roomA, fan, boosterCodes.TRIPLE!, [a]);
    expectError(early, 409, 'PK_BOOSTER_UNAVAILABLE', 'sendLiveGift');
    expect(early.body.error.details).toEqual([{ field: 'giftCode', issue: 'too_early' }]);
    expect((await ctx.prisma.wallet.findUniqueOrThrow({ where: { userId: fan.id } })).coins).toBe(before);
    expectError(await send(roomA, fan, boosterCodes.DOUBLE_TURBO!, [a]), 409, 'PK_BOOSTER_UNAVAILABLE');

    // Double: its own 1 000 coins count ×1, then the room's gifts ×2 for 30 s.
    expect((await send(roomA, fan, boosterCodes.DOUBLE!, [a])).status).toBe(201);
    await settle(ctx);
    const boostMsg = pkMessages(roomB)
      .filter((p) => p.event === 'boost')
      .at(-1)!;
    expect(boostMsg.boost).toMatchObject({ roomId: roomA, kind: 'DOUBLE', multiplier: 2 });
    expect((await matchOf(match.id)).scoreA).toBe(1000n);
    expect((await send(roomA, fan, code, [a])).status).toBe(201);
    expect((await matchOf(match.id)).scoreA).toBe(1200n);
    const snap = (await state(roomA, fan)).match!;
    expect(snap.sides[0].boost).toMatchObject({ kind: 'DOUBLE', multiplier: 2 });
    expect(snap.sides[0].boosterUses.DOUBLE).toBe(1);
    // A second Double while one is active: not higher → refused.
    const same = await send(roomA, fan, boosterCodes.DOUBLE!, [a]);
    expect(same.body.error.details).toEqual([{ field: 'giftCode', issue: 'active_higher' }]);
    // After 30 s it is over: ×1 again; the second Double is allowed, a third is over the limit.
    await advance(30, [roomA, a], [roomB, b]);
    expect((await send(roomA, fan, code, [a])).status).toBe(201);
    expect((await matchOf(match.id)).scoreA).toBe(1300n);
    expect((await send(roomA, fan, boosterCodes.DOUBLE!, [a])).status).toBe(201);
    await advance(30, [roomA, a], [roomB, b]);
    const third = await send(roomA, fan, boosterCodes.DOUBLE!, [a]);
    expect(third.body.error.details).toEqual([{ field: 'giftCode', issue: 'limit_reached' }]);

    // Double Turbo ×3 in the last 2 minutes (here 70 s left); Triple ×5 only in the last minute, and
    // there it replaces the active Double Turbo; a lower one is refused; Triple Turbo ×10 replaces Triple.
    await advance(300 - 60 - 70, [roomA, a], [roomB, b]); // 70 s left
    expect((await send(roomA, fan, boosterCodes.DOUBLE_TURBO!, [a])).status).toBe(201);
    const s0 = (await matchOf(match.id)).scoreA;
    expect((await send(roomA, fan, code, [a])).status).toBe(201);
    expect((await matchOf(match.id)).scoreA - s0).toBe(300n);
    expect((await send(roomA, fan, boosterCodes.TRIPLE!, [a])).body.error.details).toEqual([
      { field: 'giftCode', issue: 'too_early' },
    ]);
    await advance(10, [roomA, a], [roomB, b]); // 60 s left
    expect((await send(roomA, fan, boosterCodes.TRIPLE!, [a])).status).toBe(201);
    const replaced = await ctx.prisma.pkBoost.findFirstOrThrow({
      where: { matchId: match.id, kind: 'DOUBLE_TURBO' },
    });
    expect(replaced.replaced).toBe(true);
    const s1 = (await matchOf(match.id)).scoreA;
    expect((await send(roomA, fan, code, [a])).status).toBe(201);
    expect((await matchOf(match.id)).scoreA - s1).toBe(500n);
    expect((await send(roomA, fan, boosterCodes.DOUBLE!, [a])).body.error.details).toEqual([
      { field: 'giftCode', issue: 'limit_reached' },
    ]);
    expect((await send(roomA, fan, boosterCodes.TRIPLE_TURBO!, [a])).status).toBe(201);
    const s2 = (await matchOf(match.id)).scoreA;
    expect((await send(roomA, fan, code, [a])).status).toBe(201);
    expect((await matchOf(match.id)).scoreA - s2).toBe(1000n);
    await settle(ctx);
    expect(
      pkMessages(roomA)
        .filter((p) => p.event === 'boost')
        .map((p) => p.boost!.kind),
    ).toEqual(['DOUBLE', 'DOUBLE', 'DOUBLE_TURBO', 'TRIPLE', 'TRIPLE_TURBO']);
  });

  it('money is never multiplied: under Triple Turbo ×10 the host earns the same cherries and live score as at ×1', async () => {
    const { a, b, roomA, roomB, match } = await battle();
    const fan = await signup();
    await coins(fan, 1_000_000);
    await join(roomA, fan);
    const code = await gift({ priceCoins: 1000 });
    const c0 = await cherries(a);
    const l0 = await liveScore(roomA);
    expect((await send(roomA, fan, code, [a])).status).toBe(201);
    const plainCherries = (await cherries(a)) - c0;
    const plainScore = (await liveScore(roomA)) - l0;
    expect(plainCherries).toBeGreaterThan(0n);
    await advance(250, [roomA, a], [roomB, b]);
    expect((await send(roomA, fan, boosterCodes.TRIPLE_TURBO!, [a])).status).toBe(201);
    const c1 = await cherries(a);
    const l1 = await liveScore(roomA);
    const p1 = (await matchOf(match.id)).scoreA;
    expect((await send(roomA, fan, code, [a])).status).toBe(201);
    expect((await matchOf(match.id)).scoreA - p1).toBe(10_000n);
    expect((await cherries(a)) - c1).toBe(plainCherries);
    expect((await liveScore(roomA)) - l1).toBe(plainScore);
    const sent = await ctx.prisma.liveGift.findFirstOrThrow({
      where: { senderId: fan.id, giftCode: code },
      orderBy: { createdAt: 'desc' },
    });
    expect(sent.totalCoins).toBe(1000n);
  });

  it('a booster outside a battle is refused (no match)', async () => {
    const h = await host();
    const room = await goLive(h);
    const fan = await signup();
    await coins(fan, 100_000);
    await join(room, fan);
    const res = await send(room, fan, boosterCodes.DOUBLE!, [h]);
    expectError(res, 409, 'PK_BOOSTER_UNAVAILABLE', 'sendLiveGift');
    expect(res.body.error.details).toEqual([{ field: 'giftCode', issue: 'no_match' }]);
    const cat = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(fan));
    expectContract(cat, 'getGiftCatalogue');
    expect(
      (cat.body.data as { code: string; pkBooster: string | null }[]).find(
        (g) => g.code === boosterCodes.TRIPLE,
      )?.pkBooster,
    ).toBe('TRIPLE');
  });

  // ---- Ends, results, records ---------------------------------------------------------------------

  it('time up: the higher score wins; 60 s of result; then CLOSED; records and history', async () => {
    const { a, b, roomA, roomB, match } = await battle();
    const fan = await signup();
    await coins(fan, 100_000);
    await join(roomB, fan);
    const code = await gift({ priceCoins: 40 });
    expect((await send(roomB, fan, code, [b])).status).toBe(201);
    await advance(300, [roomA, a], [roomB, b]);
    // A gift after the time is up (before the tick) counts for nothing.
    expect((await send(roomB, fan, code, [b])).status).toBe(201);
    expect((await pk.tick()).ended).toBeGreaterThanOrEqual(1);
    const ended = (await state(roomA, a)).match!;
    expect(ended).toMatchObject({ status: 'RESULT', endReason: 'TIME', winnerRoomId: roomB });
    expect(ended.sides[1].supporters).toEqual([expect.objectContaining({ points: 40 })]);
    expect(pkMessages(roomA).at(-1)?.event).toBe('ended');
    await advance(59, [roomA, a], [roomB, b]);
    await pk.tick();
    expect((await matchOf(match.id)).status).toBe('RESULT');
    await advance(1, [roomA, a], [roomB, b]);
    await pk.tick();
    expect((await matchOf(match.id)).status).toBe('CLOSED');
    expect((await state(roomA, a)).match).toBeNull();
    expect(pkMessages(roomB).at(-1)).toMatchObject({ event: 'closed', match: { status: 'CLOSED' } });

    const profile = await call('get', `live/pk/hosts/${b.username}`, null);
    expect(profile.status).toBe(200);
    expectContract(profile, 'getLivePkHost');
    expect(profile.body.record).toMatchObject({ wins: 1, losses: 0, draws: 0 });
    expect(profile.body.recent[0]).toMatchObject({
      id: match.id,
      result: 'WIN',
      endReason: 'TIME',
      score: 40,
      opponentScore: 0,
      opponent: { id: a.id },
      durationSeconds: 300,
      supporters: [{ user: { id: fan.id }, points: 40 }],
    });
    const mine = await call('get', 'me/live-pk', a);
    expectContract(mine, 'getMyLivePk');
    expect(mine.body.record).toMatchObject({ wins: 0, losses: 1, draws: 0 });
    // They may PK again.
    expect((await invite(roomA, a, roomB)).status).toBe(201);
  });

  it('a draw: equal scores at time up', async () => {
    const { a, b, roomA, roomB, match } = await battle();
    await advance(300, [roomA, a], [roomB, b]);
    await pk.tick();
    expect(await matchOf(match.id)).toMatchObject({ status: 'RESULT', endReason: 'TIME', winner: null });
    expect((await ctx.prisma.pkHostRecord.findUniqueOrThrow({ where: { hostId: a.id } })).draws).toBe(1);
    expect((await ctx.prisma.pkHostRecord.findUniqueOrThrow({ where: { hostId: b.id } })).draws).toBe(1);
  });

  it('forfeit: a host ends early → the opponent wins; ending again closes the result', async () => {
    const { a, b, roomA, roomB, match } = await battle();
    const res = await call('post', `live/rooms/${roomA}/pk/end`, a);
    expect(res.status).toBe(200);
    expectContract(res, 'endLivePk');
    expect(res.body).toMatchObject({
      status: 'RESULT',
      endReason: 'FORFEIT',
      winnerRoomId: roomB,
      loserCauseRoomId: roomA,
    });
    const again = await call('post', `live/rooms/${roomB}/pk/end`, b);
    expect(again.body.status).toBe('CLOSED');
    expectError(await call('post', `live/rooms/${roomB}/pk/end`, b), 409, 'PK_NOT_ACTIVE', 'endLivePk');
    expect((await ctx.prisma.pkHostRecord.findUniqueOrThrow({ where: { hostId: b.id } })).wins).toBe(1);
    void match;
  });

  it('ending the live during a battle is a forfeit too', async () => {
    const { a, roomA, roomB, match } = await battle();
    expect((await ctx.http.post(`/api/v1/live/rooms/${roomA}/end`).set(auth(a))).status).toBe(200);
    await pk.tick();
    expect(await matchOf(match.id)).toMatchObject({ endReason: 'FORFEIT', winner: 'B', loserCause: 'A' });
    // The other room is gone from the result too: the next tick closes it.
    void roomB;
  });

  it('disconnect: the host out of the media session for 30 s loses; back in time, nothing happens', async () => {
    const { a, b, roomA, roomB, match } = await battle();
    await webhook('participant_left', roomB, b.id);
    await advance(20, [roomA, a], [roomB, b]);
    await webhook('participant_joined', roomB, b.id);
    await advance(20, [roomA, a], [roomB, b]);
    await pk.tick();
    expect((await matchOf(match.id)).status).toBe('BATTLE');
    await webhook('participant_left', roomB, b.id);
    await advance(30, [roomA, a], [roomB, b]);
    await pk.tick();
    expect(await matchOf(match.id)).toMatchObject({ status: 'RESULT', endReason: 'DISCONNECT', winner: 'A' });
  });

  it('away (D170) more than 30 s loses as AWAY', async () => {
    const { a, b, roomA, roomB, match } = await battle();
    expect((await call('post', `live/rooms/${roomA}/host-presence`, a, { away: true })).status).toBe(204);
    await advance(30, [roomA, a], [roomB, b]);
    await pk.tick();
    expect(await matchOf(match.id)).toMatchObject({ endReason: 'AWAY', winner: 'B', loserCause: 'A' });
  });

  it('a moderator ends a PK (pk-admin end, audited): void, closed, both rooms told', async () => {
    const { a, roomA, roomB, match } = await battle();
    expect(pkAdmin('end', match.id).status).toBe(1);
    const res = pkAdmin('end', match.id, '--reason', 'abuse report 42');
    expect(res, res.out).toMatchObject({ status: 0 });
    expect(await matchOf(match.id)).toMatchObject({
      status: 'CLOSED',
      endReason: 'ADMIN',
      winner: null,
      adminReason: 'abuse report 42',
    });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'live.pk.admin_end', targetId: match.id } }),
    ).toBe(1);
    await pk.tick();
    expect(pkMessages(roomB).at(-1)).toMatchObject({ event: 'closed', match: { endReason: 'ADMIN' } });
    expect(pkAdmin('end', match.id, '--reason', 'again').status).toBe(1);
    const history = await call('get', `live/pk/hosts/${a.username}`, null);
    expect(history.body.recent[0]).toMatchObject({ id: match.id, result: 'VOID' });
    expect(await ctx.prisma.pkHostRecord.count({ where: { hostId: a.id } })).toBe(0);
    void roomA;
  });

  // ---- Snapshot, mute, guests, media ------------------------------------------------------------

  it('mute opponent: the host turns the other host off for their own room; seq grows', async () => {
    const { a, roomA, roomB, match } = await battle();
    const res = await call('post', `live/rooms/${roomA}/pk/mute-opponent`, a, { muted: true });
    expect(res.status).toBe(200);
    expectContract(res, 'muteLivePkOpponent');
    expect((res.body as Match).sides[0].mutesOpponent).toBe(true);
    expect((res.body as Match).sides[1].mutesOpponent).toBe(false);
    expect((res.body as Match).seq).toBeGreaterThan(match.seq);
    expect(pkMessages(roomB).at(-1)?.event).toBe('mute');
    expectError(
      await call('post', `live/rooms/${roomA}/pk/mute-opponent`, a, { muted: 'yes' }),
      400,
      'VALIDATION_FAILED',
    );
  });

  it('PK guests: each host keeps up to 3 seated guests; the 4th request is refused; both rooms see them', async () => {
    const { a, roomA, roomB, b } = await battle();
    const guests = [await signup(), await signup(), await signup(), await signup()];
    for (const g of guests.slice(0, 3)) {
      const r = await call('post', `live/rooms/${roomA}/seat-requests`, g, {});
      expect(r.status, JSON.stringify(r.body)).toBe(201);
      const acc = await call(
        'post',
        `live/rooms/${roomA}/seat-requests/${r.body.id as string}/accept`,
        a,
        {},
      );
      expect(acc.status, JSON.stringify(acc.body)).toBe(200);
    }
    const fourth = await call('post', `live/rooms/${roomA}/seat-requests`, guests[3]!, {});
    expectError(fourth, 409, 'LIVE_SEAT_UNAVAILABLE', 'requestLiveSeat');
    const snap = (await state(roomB, b)).match!;
    expect(snap.sides[0].guests.map((g) => g.user.id).sort()).toEqual(
      guests
        .slice(0, 3)
        .map((g) => g.id)
        .sort(),
    );
    expect(snap.sides[1].guests).toEqual([]);
  });

  it('the cross-room media token: watch-only for the other room; never a viewer there; refused when blocked', async () => {
    const { a, roomA, roomB, b, match } = await battle();
    const viewer = await signup();
    const res = await call('post', `live/rooms/${roomA}/pk/media-token`, viewer, {});
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'createLivePkMediaToken');
    expect(res.body).toMatchObject({
      roomId: roomB,
      identity: `pk:${match.id}:${viewer.id}`,
      hostIdentity: b.id,
    });
    expect(media.issued.at(-1)).toMatchObject({
      room: roomB,
      publish: false,
      identity: `pk:${match.id}:${viewer.id}`,
    });
    const guestId = randomUUID();
    const guest = await ctx.http.post(`/api/v1/live/rooms/${roomA}/pk/media-token`).send({ guestId });
    expect(guest.body.identity).toBe(`pk:${match.id}:guest:${guestId}`);
    // Joining the other room as a PK watcher: not recorded, not counted, not kicked.
    const before = (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomB } })).viewerCount;
    await webhook('participant_joined', roomB, res.body.identity as string);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomB } })).viewerCount).toBe(before);
    expect(
      await ctx.prisma.liveRoomViewer.count({
        where: { roomId: roomB, identity: res.body.identity as string },
      }),
    ).toBe(0);
    expect(media.removed.filter((r) => r.identity === res.body.identity)).toEqual([]);
    // Blocked by the other host → 404.
    const blocked = await signup();
    await ctx.prisma.userBlock.create({ data: { blockerId: b.id, blockedId: blocked.id } });
    expectError(
      await call('post', `live/rooms/${roomA}/pk/media-token`, blocked, {}),
      404,
      'NOT_FOUND',
      'createLivePkMediaToken',
    );
    // After the PK closes, the watcher is disconnected and a new join is refused.
    await call('post', `live/rooms/${roomA}/pk/end`, a);
    await call('post', `live/rooms/${roomA}/pk/end`, a);
    expect(media.removed.some((r) => r.room === roomB && r.identity === res.body.identity)).toBe(true);
    await webhook('participant_joined', roomB, `pk:${match.id}:${randomUUID()}`);
    expect(media.removed.at(-1)?.identity.startsWith(`pk:${match.id}:`)).toBe(true);
    expectError(await call('post', `live/rooms/${roomA}/pk/media-token`, viewer, {}), 409, 'PK_NOT_ACTIVE');
  });
});
