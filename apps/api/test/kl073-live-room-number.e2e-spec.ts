/**
 * KL-073 / CP-016 part G (D99): the host's public room number (openapi v1.15-live DRAFT,
 * CONVENTIONS §10.17), end to end against PostgreSQL + Redis with the API as the DML-only runtime
 * role.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('CP-016 G the room number', () => {
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
  const goLive = async (u: TestUser): Promise<{ id: string; roomNumber: number | null }> => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: `Room of ${u.username}` });
    expect(res.status).toBe(201);
    expectContract(res, 'startLiveRoom');
    return res.body as { id: string; roomNumber: number | null };
  };
  const end = async (u: TestUser, roomId: string) =>
    expect((await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u))).status).toBe(200);

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' });
  });
  afterAll(async () => ctx?.close());

  it('nine digits, the same in every live of a host, different between hosts', async () => {
    const [a, b] = [await host(), await host()];
    const first = await goLive(a);
    expect(String(first.roomNumber)).toMatch(/^[1-9][0-9]{8}$/);
    const stored = await ctx.prisma.liveHost.findUniqueOrThrow({ where: { userId: a.id } });
    expect(first.roomNumber).toBe(stored.roomNumber);

    // Viewers and guests read it on the room too.
    const viewer = await signup();
    const read = await ctx.http.get(`/api/v1/live/rooms/${first.id}`).set(auth(viewer));
    expect(read.status).toBe(200);
    expectContract(read, 'getLiveRoom');
    expect(read.body.roomNumber).toBe(first.roomNumber);

    await end(a, first.id);
    expect((await goLive(a)).roomNumber).toBe(first.roomNumber);
    expect((await goLive(b)).roomNumber).not.toBe(first.roomNumber);
  });

  it('null once the hosting permission is gone (an ended room stays readable)', async () => {
    const a = await host();
    const room = await goLive(a);
    await end(a, room.id);
    await ctx.prisma.liveHost.delete({ where: { userId: a.id } });
    const read = await ctx.http.get(`/api/v1/live/rooms/${room.id}`).set(auth(a));
    expect(read.status).toBe(200);
    expectContract(read, 'getLiveRoom');
    expect(read.body.roomNumber).toBeNull();
  });

  it('the database refuses numbers outside nine digits and duplicates', async () => {
    const [a, b] = [await signup(), await signup()];
    await expect(
      ctx.prisma.liveHost.create({ data: { userId: a.id, source: 'ADMIN', roomNumber: 12345 } }),
    ).rejects.toThrow();
    const made = await ctx.prisma.liveHost.create({ data: { userId: a.id, source: 'ADMIN' } });
    await expect(
      ctx.prisma.liveHost.create({ data: { userId: b.id, source: 'ADMIN', roomNumber: made.roomNumber } }),
    ).rejects.toThrow();
  });
});
