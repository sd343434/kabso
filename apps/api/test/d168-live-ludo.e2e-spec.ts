/**
 * D168 (owner 2026-11-02; contract v1.45-live, CONVENTIONS §10.42): Ludo «لودو» inside a live room —
 * the host opens a game, people in the room take seats, the server rolls its die, checks every
 * intent, captures, runs the 15 s turn timers and the 30 s away rule, applies concurrent intents
 * once, and tells the room every change — end to end against PostgreSQL + Redis. The die is
 * scripted here (the server's crypto RNG otherwise) and pieces are placed by hand where a long game
 * would be needed to reach a position.
 */
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LUDO_DICE, LiveLudoService, type LudoDice } from '../src/modules/live/live-ludo.service.js';
import type { LudoState } from '../src/modules/live/live-ludo.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
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

/** The die, scripted: the next numbers rolled (1 when the script is empty). */
class ScriptedDice implements LudoDice {
  next: number[] = [];
  roll(): number {
    return this.next.shift() ?? 1;
  }
}

interface TestUser {
  readonly id: string;
  readonly token: string;
}

describe('D168 contract coverage', () => {
  it('openapi v1.45-live declares the Ludo operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const id of [
      'getLiveLudo GET /api/v1/live/rooms/{roomId}/ludo',
      'createLiveLudo POST /api/v1/live/rooms/{roomId}/ludo',
      'takeLiveLudoSeat PUT /api/v1/live/rooms/{roomId}/ludo/seats/{seat}',
      'leaveLiveLudoSeat DELETE /api/v1/live/rooms/{roomId}/ludo/seats/{seat}',
      'startLiveLudo POST /api/v1/live/rooms/{roomId}/ludo/start',
      'rollLiveLudo POST /api/v1/live/rooms/{roomId}/ludo/roll',
      'moveLiveLudo POST /api/v1/live/rooms/{roomId}/ludo/move',
      'endLiveLudo POST /api/v1/live/rooms/{roomId}/ludo/end',
    ]) {
      expect(ids).toContain(id);
    }
  });
});

describe('D168 Ludo in a live room', { timeout: 180_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  const dice = new ScriptedDice();
  let ctx: TestContext;
  let ludo: LiveLudoService;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id as string, token: res.body.tokens.accessToken as string };
  };
  const webhook = async (roomId: string, u: TestUser, event: 'participant_joined' | 'participant_left') => {
    const raw = JSON.stringify({ event, room: { name: roomId }, participant: { identity: u.id } });
    const res = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(res.status).toBe(200);
  };
  const live = async () => {
    const h = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'Ludo night' });
    expect(room.status).toBe(201);
    return { h, roomId: room.body.id as string };
  };
  const path = (roomId: string, rest = '') => `/api/v1/live/rooms/${roomId}/ludo${rest}`;
  const expectError = (res: request.Response, status: number, code: string, op: string) => {
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    expect(res.body.error.code).toBe(code);
    expectContract(res, op);
  };
  const lastLudo = (roomId: string) =>
    media.broadcastsOf(roomId, 'ludo').at(-1)?.game as Record<string, unknown>;

  /** A LIVE room with a host and [n] viewers in its media session. */
  const roomWith = async (n: number) => {
    const { h, roomId } = await live();
    const viewers: TestUser[] = [];
    for (let i = 0; i < n; i += 1) {
      const v = await signup();
      await webhook(roomId, v, 'participant_joined');
      viewers.push(v);
    }
    return { h, roomId, viewers };
  };

  /** A started game: [players] seated on [seats] (players[i] on seats[i]). */
  const started = async (opts: { players?: 2 | 4; mode?: 'CLASSIC' | 'QUICK'; seats: number[] }) => {
    const { h, roomId, viewers } = await roomWith(opts.seats.length);
    const created = await ctx.http
      .post(path(roomId))
      .set(auth(h))
      .send({ mode: opts.mode ?? 'CLASSIC', players: opts.players ?? 4 });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    for (const [i, seat] of opts.seats.entries()) {
      const took = await ctx.http.put(path(roomId, `/seats/${seat}`)).set(auth(viewers[i]!));
      expect(took.status, JSON.stringify(took.body)).toBe(200);
    }
    const lobby = await ctx.http.get(path(roomId)).set(auth(h));
    const start = await ctx.http
      .post(path(roomId, '/start'))
      .set(auth(h))
      .send({ version: lobby.body.game.version });
    expect(start.status, JSON.stringify(start.body)).toBe(200);
    return { h, roomId, viewers, game: start.body };
  };

  /** Places pieces by hand (a test fixture): the stored state's seats get [pieces]. */
  const place = async (roomId: string, pieces: Record<number, number[]>) => {
    const row = await ctx.prisma.liveLudoGame.findFirstOrThrow({ where: { roomId, status: 'PLAYING' } });
    const state = row.state as unknown as LudoState;
    const next = {
      ...state,
      seats: state.seats.map((s) => (pieces[s.seat] ? { ...s, pieces: pieces[s.seat] } : s)),
    };
    await ctx.prisma.liveLudoGame.update({ where: { id: row.id }, data: { state: next as object } });
    return row.version;
  };

  /** Ends every other open game, so the server's timer only sees this test's game. */
  const endOthers = () =>
    ctx.prisma.liveLudoGame.updateMany({
      where: { status: { in: ['LOBBY', 'PLAYING'] } },
      data: { status: 'ENDED', dueAt: null },
    });

  const roll = (roomId: string, u: TestUser, version: number) =>
    ctx.http.post(path(roomId, '/roll')).set(auth(u)).send({ version });
  const move = (roomId: string, u: TestUser, version: number, piece: number) =>
    ctx.http.post(path(roomId, '/move')).set(auth(u)).send({ version, piece });

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
      { token: LUDO_DICE, value: dice },
    ]);
    ludo = ctx.app.get(LiveLudoService);
  });
  afterAll(async () => ctx?.close());

  it('the host opens a game; people in the room take seats; the host starts it; everyone reads it', async () => {
    const { h, roomId, viewers } = await roomWith(2);
    const [a, b] = viewers as [TestUser, TestUser];
    const guest = await ctx.http.get(path(roomId));
    expect(guest.status).toBe(200);
    expectContract(guest, 'getLiveLudo');
    expect(guest.body).toEqual({ game: null });

    // Only the host opens a game; one game per room.
    expectError(
      await ctx.http.post(path(roomId)).set(auth(a)).send({ mode: 'CLASSIC', players: 4 }),
      403,
      'AUTH_FORBIDDEN',
      'createLiveLudo',
    );
    const bad = await ctx.http.post(path(roomId)).set(auth(h)).send({ mode: 'CLASSIC', players: 3 });
    expect(bad.status).toBe(400);
    const created = await ctx.http.post(path(roomId)).set(auth(h)).send({ mode: 'QUICK', players: 2 });
    expect(created.status).toBe(201);
    expectContract(created, 'createLiveLudo');
    expect(created.body).toMatchObject({ status: 'LOBBY', mode: 'QUICK', maxPlayers: 2, piecesPerPlayer: 2 });
    expect(created.body.seats.map((s: { seat: number; color: string }) => [s.seat, s.color])).toEqual([
      [0, 'RED'],
      [2, 'YELLOW'],
    ]);
    expect(lastLudo(roomId)).toMatchObject({ id: created.body.id, status: 'LOBBY' });
    expectError(
      await ctx.http.post(path(roomId)).set(auth(h)).send({ mode: 'CLASSIC', players: 4 }),
      409,
      'LUDO_GAME_EXISTS',
      'createLiveLudo',
    );

    // Seats: a game of 2 uses seats 0 and 2; one seat per person; not after leaving.
    expectError(
      await ctx.http.put(path(roomId, '/seats/1')).set(auth(a)),
      409,
      'LUDO_SEAT_UNAVAILABLE',
      'takeLiveLudoSeat',
    );
    const sat = await ctx.http.put(path(roomId, '/seats/0')).set(auth(a));
    expect(sat.status).toBe(200);
    expectContract(sat, 'takeLiveLudoSeat');
    expect(sat.body.seats[0].user.id).toBe(a.id);
    expectError(
      await ctx.http.put(path(roomId, '/seats/2')).set(auth(a)),
      409,
      'LUDO_SEAT_UNAVAILABLE',
      'takeLiveLudoSeat',
    );
    expectError(
      await ctx.http.put(path(roomId, '/seats/0')).set(auth(b)),
      409,
      'LUDO_SEAT_UNAVAILABLE',
      'takeLiveLudoSeat',
    );

    // Fewer than 2 seated: not startable; a stale version changes nothing.
    const one = await ctx.http.get(path(roomId));
    expectError(
      await ctx.http.post(path(roomId, '/start')).set(auth(h)).send({ version: one.body.game.version }),
      409,
      'LUDO_NOT_STARTABLE',
      'startLiveLudo',
    );
    await ctx.http.put(path(roomId, '/seats/2')).set(auth(b)).expect(200);
    expectError(
      await ctx.http.post(path(roomId, '/start')).set(auth(h)).send({ version: one.body.game.version }),
      409,
      'LUDO_STALE_VERSION',
      'startLiveLudo',
    );
    const lobby = await ctx.http.get(path(roomId)).set(auth(b));
    const start = await ctx.http
      .post(path(roomId, '/start'))
      .set(auth(h))
      .send({ version: lobby.body.game.version });
    expect(start.status).toBe(200);
    expectContract(start, 'startLiveLudo');
    expect(start.body).toMatchObject({
      status: 'PLAYING',
      turn: 0,
      phase: 'ROLL',
      sixes: 0,
      turnSeconds: 15,
      events: [{ kind: 'START' }],
    });
    expect(start.body.seats.map((s: { pieces: number[] }) => s.pieces)).toEqual([
      [-1, -1],
      [-1, -1],
    ]);
    expect(Date.parse(start.body.turnEndsAt) - clock.now().getTime()).toBe(15_000);

    // Late joiners and guests read the whole game.
    const late = await ctx.http.get(path(roomId));
    expectContract(late, 'getLiveLudo');
    expect(late.body.game).toMatchObject({
      id: created.body.id,
      status: 'PLAYING',
      version: start.body.version,
    });
    // No seat once started.
    const c = await signup();
    await webhook(roomId, c, 'participant_joined');
    expectError(
      await ctx.http.put(path(roomId, '/seats/0')).set(auth(c)),
      409,
      'LUDO_SEAT_UNAVAILABLE',
      'takeLiveLudoSeat',
    );
  });

  it('only people in the room play: a non-member is refused; spectators cannot roll', async () => {
    const { h, roomId } = await roomWith(0);
    await ctx.http.post(path(roomId)).set(auth(h)).send({ mode: 'CLASSIC', players: 4 }).expect(201);
    const outsider = await signup();
    expectError(
      await ctx.http.put(path(roomId, '/seats/1')).set(auth(outsider)),
      403,
      'LUDO_NOT_IN_ROOM',
      'takeLiveLudoSeat',
    );
    // The host may play too.
    const hostSeat = await ctx.http.put(path(roomId, '/seats/1')).set(auth(h));
    expect(hostSeat.status).toBe(200);
    const unauthenticated = await ctx.http.post(path(roomId, '/roll')).send({ version: 0 });
    expect(unauthenticated.status).toBe(401);
  });

  it('rolls and moves: the server die, turns, a 6 out of the base, choosing a piece, wrong turns refused', async () => {
    const { roomId, viewers, game } = await started({ seats: [0, 2] });
    const [red, yellow] = viewers as [TestUser, TestUser];

    expectError(await roll(roomId, yellow, game.version), 409, 'LUDO_NOT_YOUR_TURN', 'rollLiveLudo');
    expectError(await move(roomId, red, game.version, 0), 409, 'LUDO_NOT_YOUR_TURN', 'moveLiveLudo');
    expectError(await roll(roomId, red, game.version + 5), 409, 'LUDO_STALE_VERSION', 'rollLiveLudo');

    // A 3 with every piece in the base: no move, the turn passes.
    dice.next = [3];
    const passed = await roll(roomId, red, game.version);
    expect(passed.status).toBe(200);
    expectContract(passed, 'rollLiveLudo');
    expect(passed.body.events.map((e: { kind: string }) => e.kind)).toEqual(['ROLL', 'NO_MOVE']);
    expect(passed.body).toMatchObject({ turn: 2, phase: 'ROLL', dice: 3 });

    // A 6: four pieces may leave → the player chooses (new 15 s), then another turn.
    dice.next = [6];
    const six = await roll(roomId, yellow, passed.body.version);
    expect(six.body).toMatchObject({ turn: 2, phase: 'MOVE', dice: 6, sixes: 1, movable: [0, 1, 2, 3] });
    expectError(
      await move(roomId, yellow, six.body.version, 3 + 1),
      400,
      'VALIDATION_FAILED',
      'moveLiveLudo',
    );
    const moved = await move(roomId, yellow, six.body.version, 2);
    expect(moved.status).toBe(200);
    expectContract(moved, 'moveLiveLudo');
    expect(moved.body.events).toEqual([
      {
        kind: 'MOVE',
        seat: 2,
        piece: 2,
        from: -1,
        to: 0,
        dice: 6,
        captured: [],
        reached: false,
        auto: false,
      },
    ]);
    expect(moved.body.seats[1].pieces).toEqual([-1, -1, 0, -1]);
    expect(moved.body).toMatchObject({ turn: 2, phase: 'ROLL' });
    expect(lastLudo(roomId)).toMatchObject({ version: moved.body.version, turn: 2 });

    // One legal piece: moved at once by the roll.
    dice.next = [4];
    const single = await roll(roomId, yellow, moved.body.version);
    expect(single.body.events.map((e: { kind: string }) => e.kind)).toEqual(['ROLL', 'MOVE']);
    expect(single.body.seats[1].pieces).toEqual([-1, -1, 4, -1]);
    expect(single.body.turn).toBe(0);
  });

  it('a capture sends the piece home and gives another turn; the exact roll finishes; the first home wins', async () => {
    const { roomId, viewers } = await started({ seats: [0, 1] });
    const [red, green] = viewers as [TestUser, TestUser];
    // Red at square 3; green at its step 44 = square 5.
    const version = await place(roomId, { 0: [3, -1, -1, -1], 1: [44, -1, -1, -1] });
    dice.next = [2];
    const hit = await roll(roomId, red, version);
    expect(hit.status, JSON.stringify(hit.body)).toBe(200);
    expect(hit.body.events[1]).toMatchObject({
      kind: 'MOVE',
      from: 3,
      to: 5,
      captured: [{ seat: 1, piece: 0, from: 44 }],
    });
    expect(hit.body.seats[1].pieces).toEqual([-1, -1, -1, -1]);
    expect(hit.body).toMatchObject({ turn: 0, phase: 'ROLL' });

    // The exact roll is needed: 54 + 4 passes the centre (no move); then 3 reaches it and the game.
    const v2 = await place(roomId, { 0: [57, 57, 57, 54] });
    dice.next = [4];
    const over = await roll(roomId, red, v2);
    expect(over.body.events.map((e: { kind: string }) => e.kind)).toEqual(['ROLL', 'NO_MOVE']);
    dice.next = [6];
    const greenTurn = await roll(roomId, green, over.body.version);
    expect(greenTurn.body.phase).toBe('MOVE');
    const out = await move(roomId, green, greenTurn.body.version, 0);
    dice.next = [1];
    const back = await roll(roomId, green, out.body.version);
    expect(back.body.turn).toBe(0);
    dice.next = [3];
    const won = await roll(roomId, red, back.body.version);
    expect(won.status).toBe(200);
    expect(won.body).toMatchObject({ status: 'FINISHED', winner: 0, turn: null, phase: null });
    expect(won.body.events.map((e: { kind: string }) => e.kind)).toEqual(['ROLL', 'MOVE', 'WIN']);
    const row = await ctx.prisma.liveLudoGame.findUniqueOrThrow({ where: { id: won.body.id } });
    expect(row.winnerUserId).toBe(red.id);
    // Nothing free to play is charged or paid (no ledger rows for the players).
    expect(await ctx.prisma.walletLedgerEntry.count({ where: { userId: { in: [red.id, green.id] } } })).toBe(
      0,
    );
    // The room may open a new game.
    expect((await ctx.http.get(path(roomId))).body).toEqual({ game: null });
  });

  it('the server plays a turn on timeout: it rolls, then plays the best move', async () => {
    await endOthers();
    const { roomId, game } = await started({ seats: [0, 2] });
    dice.next = [6, 2];
    clock.advance(14);
    expect(await ludo.tick()).toBe(0);
    clock.advance(1);
    expect(await ludo.tick()).toBe(1);
    const rolled = (await ctx.http.get(path(roomId))).body.game;
    expect(rolled.version).toBe(game.version + 1);
    expect(rolled.events).toEqual([{ kind: 'ROLL', seat: 0, dice: 6, auto: true }]);
    expect(rolled).toMatchObject({ phase: 'MOVE', turn: 0 });
    clock.advance(15);
    expect(await ludo.tick()).toBe(1);
    const moved = (await ctx.http.get(path(roomId))).body.game;
    expect(moved.events[0]).toMatchObject({ kind: 'MOVE', seat: 0, piece: 0, from: -1, to: 0, auto: true });
    expect(lastLudo(roomId)).toMatchObject({ version: moved.version });
  });

  it('a player away 30 s becomes AUTO and the server plays their turns; back in the room they play again', async () => {
    await endOthers();
    const { roomId, viewers, game } = await started({ seats: [0, 2] });
    const [red, yellow] = viewers as [TestUser, TestUser];
    await webhook(roomId, red, 'participant_left');
    clock.advance(10);
    await webhook(roomId, red, 'participant_joined'); // back in time
    await webhook(roomId, red, 'participant_left');
    clock.advance(29);
    await ludo.tick(); // the turn timer (15 s) played a roll; red is not AUTO yet
    let now = (await ctx.http.get(path(roomId))).body.game;
    expect(now.seats[0].auto).toBe(false);
    clock.advance(1);
    dice.next = [1];
    await ludo.tick();
    now = (await ctx.http.get(path(roomId))).body.game;
    expect(now.seats[0].auto).toBe(true);
    expect(
      now.events.some(
        (e: { kind: string; reason?: string }) => e.kind === 'AUTO' && e.reason === 'DISCONNECTED',
      ),
    ).toBe(true);
    // Yellow plays; then red's AUTO turn is played 1.5 s after it starts.
    if (now.turn === 2) {
      dice.next = [1];
      now = (await roll(roomId, yellow, now.version)).body;
    }
    expect(now.turn).toBe(0);
    expect(Date.parse(now.turnEndsAt) - clock.now().getTime()).toBeLessThanOrEqual(1500);
    clock.advance(2);
    dice.next = [3];
    expect(await ludo.tick()).toBe(1);
    now = (await ctx.http.get(path(roomId))).body.game;
    expect(now.events[0]).toMatchObject({ kind: 'ROLL', seat: 0, auto: true });
    // Back in the room: control again.
    await webhook(roomId, red, 'participant_joined');
    now = (await ctx.http.get(path(roomId))).body.game;
    expect(now.seats[0].auto).toBe(false);
    expect(game.id).toBe(now.id);
  });

  it('leaving a started game makes the seat AUTO for good; the host can remove a player and end the game', async () => {
    const { h, roomId, viewers } = await started({ seats: [0, 1, 2] });
    const [red, green] = viewers as [TestUser, TestUser];
    const left = await ctx.http.delete(path(roomId, '/seats/1')).set(auth(green));
    expect(left.status).toBe(200);
    expectContract(left, 'leaveLiveLudoSeat');
    expect(left.body.seats[1]).toMatchObject({ auto: true, user: { id: green.id } });
    expect(left.body.events).toEqual([{ kind: 'AUTO', seat: 1, reason: 'LEFT' }]);
    await webhook(roomId, green, 'participant_joined');
    expect((await ctx.http.get(path(roomId))).body.game.seats[1].auto).toBe(true);
    expectError(
      await ctx.http.delete(path(roomId, '/seats/0')).set(auth(green)),
      403,
      'AUTH_FORBIDDEN',
      'leaveLiveLudoSeat',
    );
    const removed = await ctx.http.delete(path(roomId, '/seats/2')).set(auth(h));
    expect(removed.body.seats[2].auto).toBe(true);

    expectError(
      await ctx.http.post(path(roomId, '/end')).set(auth(red)),
      403,
      'AUTH_FORBIDDEN',
      'endLiveLudo',
    );
    const ended = await ctx.http.post(path(roomId, '/end')).set(auth(h));
    expect(ended.status).toBe(200);
    expectContract(ended, 'endLiveLudo');
    expect(ended.body).toMatchObject({ status: 'ENDED', winner: null, events: [{ kind: 'END' }] });
    expect(lastLudo(roomId)).toMatchObject({ status: 'ENDED' });
    expect((await ctx.http.get(path(roomId))).body).toEqual({ game: null });
    expectError(await ctx.http.post(path(roomId, '/end')).set(auth(h)), 404, 'NOT_FOUND', 'endLiveLudo');
  });

  it('concurrent intents on one version are applied once', async () => {
    const { roomId, viewers, game } = await started({ seats: [0, 2] });
    const red = viewers[0]!;
    dice.next = [6, 6, 6, 6, 6, 6];
    const answers = await Promise.all(Array.from({ length: 6 }, () => roll(roomId, red, game.version)));
    const ok = answers.filter((r) => r.status === 200);
    expect(ok).toHaveLength(1);
    for (const r of answers.filter((x) => x.status !== 200)) {
      expect(r.status).toBe(409);
      expect(['LUDO_STALE_VERSION', 'LUDO_NOT_YOUR_TURN']).toContain(r.body.error.code);
    }
    const now = (await ctx.http.get(path(roomId))).body.game;
    expect(now.version).toBe(game.version + 1);
    expect(now).toMatchObject({ dice: 6, sixes: 1, phase: 'MOVE' });
  });

  it('a lobby seat is freed when its player leaves the room; the game ends with the live', async () => {
    await endOthers();
    const { h, roomId, viewers } = await roomWith(1);
    const v = viewers[0]!;
    await ctx.http.post(path(roomId)).set(auth(h)).send({ mode: 'CLASSIC', players: 4 }).expect(201);
    await ctx.http.put(path(roomId, '/seats/3')).set(auth(v)).expect(200);
    await webhook(roomId, v, 'participant_left');
    expect((await ctx.http.get(path(roomId))).body.game.seats[3].user).toBeNull();
    await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h));
    await ludo.tick();
    const row = await ctx.prisma.liveLudoGame.findFirstOrThrow({ where: { roomId } });
    expect(row.status).toBe('ENDED');
    expect(row.endedAt).not.toBeNull();
  });
});
