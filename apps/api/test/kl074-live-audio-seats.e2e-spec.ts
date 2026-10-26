/**
 * KL-074 / owner D100, amended by D103: AUDIO rooms have 5, 10, 15, 20 or 25 tiles, the host
 * included (openapi v1.18-live DRAFT, CONVENTIONS §10.9), end to end against PostgreSQL + Redis with the API as the
 * DML-only runtime role and the in-memory media server.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D100 / D103 audio room sizes', () => {
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
  const start = (u: TestUser, seatCount: number) =>
    ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'Voices', mode: 'AUDIO', seatCount });
  const live = (roomId: string) => `/api/v1/live/rooms/${roomId}`;
  const end = async (roomId: string, u: TestUser) =>
    ctx.http
      .post(`${live(roomId)}/end`)
      .set(auth(u))
      .expect(200);

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [
      { token: LIVE_MEDIA_PROVIDER, value: new MemoryLiveMedia() },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('the config lists 5, 10, 15, 20 and 25; 6, 9 and 13 are refused; 5 and 10 start', async () => {
    const h = await host();
    const cfg = await ctx.http.get('/api/v1/live/config').set(auth(h));
    expect(cfg.status).toBe(200);
    expectContract(cfg, 'getLiveConfig');
    expect(cfg.body.seatCounts).toEqual({ MULTI: [4, 6, 9, 12], AUDIO: [5, 10, 15, 20, 25] });
    for (const old of [6, 9, 13]) {
      const res = await start(h, old);
      expect(res.status).toBe(400);
      expect(res.body.error.details).toEqual([{ field: 'seatCount', issue: 'invalid_value' }]);
    }
    for (const size of [5, 10]) {
      const res = await start(h, size);
      expect(res.status).toBe(201);
      expectContract(res, 'startLiveRoom');
      expect(res.body.seatCount).toBe(size);
      const seats = await ctx.http.get(`${live(res.body.id)}/seats`).set(auth(h));
      expect(seats.status).toBe(200);
      expect(seats.body.seats.map((s: { index: number }) => s.index)).toEqual(
        Array.from({ length: size - 1 }, (_, i) => i + 1),
      );
      await end(res.body.id, h);
    }
  });

  it('25 tiles: seats 1 … 24, the last one can be taken, and the room resizes within the set', async () => {
    const [h, guest] = [await host(), await signup()];
    const started = await start(h, 25);
    expect(started.status).toBe(201);
    expectContract(started, 'startLiveRoom');
    const roomId = started.body.id as string;
    expect(started.body.seatCount).toBe(25);

    const read = await ctx.http.get(`${live(roomId)}/seats`).set(auth(h));
    expect(read.status).toBe(200);
    expectContract(read, 'getLiveRoomSeats');
    expect(read.body.seats.map((s: { index: number }) => s.index)).toEqual(
      Array.from({ length: 24 }, (_, i) => i + 1),
    );

    const asked = await ctx.http
      .post(`${live(roomId)}/seat-requests`)
      .set(auth(guest))
      .send({ seatIndex: 24 });
    expect(asked.status).toBe(201);
    const accepted = await ctx.http
      .post(`${live(roomId)}/seat-requests/${asked.body.id}/accept`)
      .set(auth(h))
      .send({});
    expect(accepted.status).toBe(200);
    const after = await ctx.http.get(`${live(roomId)}/seats`).set(auth(h));
    expect(after.body.seats[23]).toMatchObject({ index: 24, state: 'TAKEN' });

    // Shrinking below the occupied seat 24 is refused; moving to another allowed size is not.
    const shrink = await ctx.http.patch(live(roomId)).set(auth(h)).send({ seatCount: 20 });
    expect(shrink.status).toBe(409);
    expect(shrink.body.error.code).toBe('LIVE_SEAT_UNAVAILABLE');
    for (const old of [6, 9, 13]) {
      const bad = await ctx.http.patch(live(roomId)).set(auth(h)).send({ seatCount: old });
      expect(bad.status).toBe(400);
    }
    await end(roomId, h);

    const second = await start(h, 15);
    expect(second.status).toBe(201);
    const grow = await ctx.http.patch(live(second.body.id)).set(auth(h)).send({ seatCount: 20 });
    expect(grow.status).toBe(200);
    expect(grow.body.seatCount).toBe(20);
    await end(second.body.id, h);
  });

  it('the database refuses an AUDIO size outside the set and a seat index above 24', async () => {
    const h = await host();
    const started = await start(h, 10);
    expect(started.status).toBe(201);
    const roomId = started.body.id as string;
    for (const old of [6, 9, 13]) {
      await expect(
        ctx.prisma.liveRoom.update({ where: { id: roomId }, data: { seatCount: old } }),
      ).rejects.toThrow();
    }
    // The allowed sizes pass the CHECK.
    await ctx.prisma.liveRoom.update({ where: { id: roomId }, data: { seatCount: 5 } });
    await expect(
      ctx.prisma.liveRoomSeat.create({ data: { roomId, seatIndex: 25, locked: true } }),
    ).rejects.toThrow();
    await end(roomId, h);
  });
});
