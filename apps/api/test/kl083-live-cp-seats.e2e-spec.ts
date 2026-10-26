/**
 * KL-083 / D111 (owner 2026-10-26, "CP pair on seats"): `LiveSeats.couples` lists the CP couples
 * (CP-018) whose partners both sit in an audio room now, the host included (openapi v1.23.3-live
 * DRAFT, CONVENTIONS §10.9), end to end against PostgreSQL + Redis with the API as the DML-only
 * runtime role and the in-memory media server.
 *
 * Couples are formed through the API (`sendCpRequest` + `acceptCpRequest`), with coins granted
 * straight through the ledger (`creditIn`, as `wallet-admin` does).
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { uuidv7 } from '../src/modules/levels/uuidv7.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface Couple {
  userIds: string[];
  level: number;
  levelName: string;
  privileges: string[];
}

/** D115: a level-6 couple has every CP privilege (nothing new unlocks at 6, D113). */
const ALL_CP_PRIVILEGES = ['SPECIAL_FRAME', 'CHAT_BUBBLE', 'MIC_EFFECT', 'ENTRANCE_EFFECT', 'GIFT_WALL'];

describe('D111 CP couples on seats', { timeout: 120_000 }, () => {
  let ctx: TestContext;
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
  const live = (roomId: string) => `/api/v1/live/rooms/${roomId}`;
  const start = async (u: TestUser, seatCount = 10): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Couples', mode: 'AUDIO', seatCount });
    expect(res.status).toBe(201);
    return res.body.id as string;
  };
  const end = (roomId: string, u: TestUser) =>
    ctx.http
      .post(`${live(roomId)}/end`)
      .set(auth(u))
      .expect(200);

  /** Forms a CP couple through the API (99 coins granted to the sender first). */
  const pair = async (from: TestUser, to: TestUser): Promise<void> => {
    await ctx.prisma.$transaction((tx) => creditIn(tx, from.id, 99n, 'ADMIN_GRANT', uuidv7()));
    const sent = await ctx.http
      .post('/api/v1/cp/requests')
      .set(auth(from))
      .send({ username: to.username, clientId: randomUUID() });
    expect(sent.status).toBe(201);
    const accepted = await ctx.http
      .post(`/api/v1/cp/requests/${sent.body.request.id}/accept`)
      .set(auth(to))
      .send({});
    expect(accepted.status).toBe(200);
  };

  /** Seats `u` on `seatIndex` (the host accepts their request); returns the `LiveSeats` answer. */
  const seat = async (roomId: string, h: TestUser, u: TestUser, seatIndex: number) => {
    const asked = await ctx.http
      .post(`${live(roomId)}/seat-requests`)
      .set(auth(u))
      .send({ seatIndex });
    expect(asked.status).toBe(201);
    const accepted = await ctx.http
      .post(`${live(roomId)}/seat-requests/${asked.body.id}/accept`)
      .set(auth(h))
      .set('Accept-Language', 'en')
      .send({});
    expect(accepted.status).toBe(200);
    expectContract(accepted, 'acceptLiveSeatRequest');
    return accepted.body as { couples: Couple[]; version: number };
  };

  const seats = async (roomId: string, as?: TestUser, lang = 'en') => {
    const req = ctx.http.get(`${live(roomId)}/seats`).set('Accept-Language', lang);
    const res = as ? await req.set(auth(as)) : await req;
    expect(res.status).toBe(200);
    expectContract(res, 'getLiveRoomSeats');
    return res.body as { couples: Couple[]; version: number };
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [
      { token: LIVE_MEDIA_PROVIDER, value: new MemoryLiveMedia() },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('both partners seated → listed (host included, seat order, localized); one seated → not', async () => {
    const h = await host();
    const [a, b, c, d] = [await signup(), await signup(), await signup(), await signup()];
    await pair(a, b);
    await pair(h, c);
    const roomId = await start(h);

    // Nobody seated: the host's partner is not on a seat yet.
    expect((await seats(roomId, h)).couples).toEqual([]);

    // One partner of a → b seated: not listed.
    expect((await seat(roomId, h, b, 2)).couples).toEqual([]);
    expect((await seats(roomId)).couples).toEqual([]);

    // Both seated: listed, in seat order (b on 2, a on 3 → [b, a]).
    const both = await seat(roomId, h, a, 3);
    expect(both.couples).toEqual([
      { userIds: [b.id, a.id], level: 1, levelName: 'Eager couple', privileges: ['SPECIAL_FRAME'] },
    ]);

    // The host's partner seated: the host's couple is listed first (seat 0), with the host first.
    await seat(roomId, h, c, 1);
    await seat(roomId, h, d, 4);
    const all = await seats(roomId, d);
    expect(all.couples).toEqual([
      { userIds: [h.id, c.id], level: 1, levelName: 'Eager couple', privileges: ['SPECIAL_FRAME'] },
      { userIds: [b.id, a.id], level: 1, levelName: 'Eager couple', privileges: ['SPECIAL_FRAME'] },
    ]);
    // Guests read the same list; Arabic names by Accept-Language.
    expect((await seats(roomId, undefined, 'ar')).couples).toEqual([
      { userIds: [h.id, c.id], level: 1, levelName: 'ثنائي متحمّس', privileges: ['SPECIAL_FRAME'] },
      { userIds: [b.id, a.id], level: 1, levelName: 'ثنائي متحمّس', privileges: ['SPECIAL_FRAME'] },
    ]);

    // One partner leaves the seat: no longer listed.
    await ctx.http
      .post(`${live(roomId)}/seats/me/leave`)
      .set(auth(a))
      .expect(204);
    expect((await seats(roomId, h)).couples).toEqual([
      { userIds: [h.id, c.id], level: 1, levelName: 'Eager couple', privileges: ['SPECIAL_FRAME'] },
    ]);
    await end(roomId, h);
  });

  it('an ended couple is not listed, and forming or ending one raises the seat version', async () => {
    const h = await host();
    const [a, b] = [await signup(), await signup()];
    const roomId = await start(h);
    await seat(roomId, h, a, 1);
    await seat(roomId, h, b, 2);
    const before = await seats(roomId, h);
    expect(before.couples).toEqual([]);

    await pair(a, b);
    const formed = await seats(roomId, h);
    expect(formed.version).toBeGreaterThan(before.version);
    expect(formed.couples).toEqual([
      { userIds: [a.id, b.id], level: 1, levelName: 'Eager couple', privileges: ['SPECIAL_FRAME'] },
    ]);

    // A CP gift that moves the level (520 → Silver) raises the version and shows the new level.
    await ctx.prisma.$transaction((tx) => creditIn(tx, a.id, 520n, 'ADMIN_GRANT', uuidv7()));
    const gift = await ctx.http
      .post('/api/v1/cp/me/gifts')
      .set(auth(a))
      .send({ amount: 520, clientId: randomUUID() });
    expect(gift.status).toBe(201);
    const levelled = await seats(roomId, h);
    expect(levelled.version).toBeGreaterThan(formed.version);
    expect(levelled.couples).toEqual([
      {
        userIds: [a.id, b.id],
        level: 2,
        levelName: 'Silver couple',
        privileges: ['SPECIAL_FRAME', 'CHAT_BUBBLE'],
      },
    ]);

    // D115: level 3 unlocks the Couple Mic Effect, listed with the couple so apps play it.
    await ctx.prisma.$transaction((tx) => creditIn(tx, a.id, 1314n, 'ADMIN_GRANT', uuidv7()));
    const gift3 = await ctx.http
      .post('/api/v1/cp/me/gifts')
      .set(auth(a))
      .send({ amount: 1314, clientId: randomUUID() });
    expect(gift3.status).toBe(201);
    const mic = await seats(roomId, h);
    expect(mic.version).toBeGreaterThan(levelled.version);
    expect(mic.couples).toEqual([
      {
        userIds: [a.id, b.id],
        level: 3,
        levelName: 'Gold couple',
        privileges: ['SPECIAL_FRAME', 'CHAT_BUBBLE', 'MIC_EFFECT'],
      },
    ]);

    // D113: the sixth tier (52 000 points, Eternal couple) is a tier change like any other. The
    // couple is set just under it at level 5 (instead of 40 gifts of 1314), then one gift crosses it.
    await ctx.prisma.cpCouple.updateMany({
      where: { userAId: { in: [a.id, b.id] }, endedAt: null },
      data: { points: 52_000n - 100n, level: 5 },
    });
    await ctx.prisma.$transaction((tx) => creditIn(tx, a.id, 520n, 'ADMIN_GRANT', uuidv7()));
    const before6 = await seats(roomId, h);
    const gift6 = await ctx.http
      .post('/api/v1/cp/me/gifts')
      .set(auth(a))
      .send({ amount: 520, clientId: randomUUID() });
    expect(gift6.status).toBe(201);
    expectContract(gift6, 'sendCpGift');
    expect(gift6.body.cp).toMatchObject({
      level: 6,
      levelName: 'Eternal couple',
      nextLevelName: null,
      pointsToNext: null,
    });
    const eternal = await seats(roomId, h);
    expect(eternal.version).toBeGreaterThan(before6.version);
    expect(eternal.couples).toEqual([
      { userIds: [a.id, b.id], level: 6, levelName: 'Eternal couple', privileges: ALL_CP_PRIVILEGES },
    ]);
    expect((await seats(roomId, h, 'ar')).couples).toEqual([
      { userIds: [a.id, b.id], level: 6, levelName: 'ثنائي أبدي', privileges: ALL_CP_PRIVILEGES },
    ]);

    await ctx.http.delete('/api/v1/cp/me').set(auth(b)).expect(204);
    const ended = await seats(roomId, h);
    expect(ended.version).toBeGreaterThan(levelled.version);
    expect(ended.couples).toEqual([]);
    await end(roomId, h);
  });

  it('a block between the partners hides the couple until it is lifted; a partner not ACTIVE hides it', async () => {
    const h = await host();
    const [a, b] = [await signup(), await signup()];
    await pair(a, b);
    const roomId = await start(h);
    await seat(roomId, h, a, 1);
    await seat(roomId, h, b, 2);
    const shown = await seats(roomId, h);
    expect(shown.couples).toHaveLength(1);

    await ctx.http.put(`/api/v1/users/${b.username}/block`).set(auth(a)).expect(200);
    const blocked = await seats(roomId, h);
    expect(blocked.couples).toEqual([]);
    expect(blocked.version).toBeGreaterThan(shown.version);

    await ctx.http.delete(`/api/v1/users/${b.username}/block`).set(auth(a)).expect(200);
    const unblocked = await seats(roomId, h);
    expect(unblocked.couples).toEqual([
      { userIds: [a.id, b.id], level: 1, levelName: 'Eager couple', privileges: ['SPECIAL_FRAME'] },
    ]);
    expect(unblocked.version).toBeGreaterThan(blocked.version);

    // Not ACTIVE (status flipped straight in the database, without the suspension flow that would
    // also take the seat): hidden, as on the public profile.
    await ctx.prisma.user.update({ where: { id: b.id }, data: { status: 'SUSPENDED' } });
    expect((await seats(roomId, h)).couples).toEqual([]);
    await ctx.prisma.user.update({ where: { id: b.id }, data: { status: 'ACTIVE' } });
    await end(roomId, h);
  });
});
