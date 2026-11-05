/**
 * D279 (v1.70-live, CONVENTIONS §10.5.1): `PublicProfile.live` — the profile's «في بث الآن» card. The facts of the
 * user's fresh LIVE room (`roomId` = `liveRoomId`, title, mode, startedAt, viewerCount, score) on someone else's
 * profile and on the own one; null when not live, after the live ends or goes stale, and across a block either way
 * (while `liveRoomId` stays as before). Every profile response is checked against openapi.yaml.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { expectContract } from './helpers/openapi.js';
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

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

const STALE_SECONDS = 45;

describe('D279 PublicProfile.live («في بث الآن»)', () => {
  const clock = new FakeClock();
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp(
      { LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: String(STALE_SECONDS) },
      [{ token: Clock, value: clock }],
    );
  });

  afterAll(async () => {
    await ctx?.close();
  });

  async function signup(host = false): Promise<TestUser> {
    const { res } = await registerVerified(ctx, {});
    expect(res.status).toBe(201);
    const id = res.body.user.id as string;
    if (host) await ctx.prisma.liveHost.create({ data: { userId: id, source: 'ADMIN' } });
    return { id, username: res.body.user.username, token: res.body.tokens.accessToken };
  }

  const bearer = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });

  async function profile(caller: TestUser, of: TestUser) {
    const res = await ctx.http.get(`/api/v1/users/${of.username}`).set(bearer(caller));
    expectContract(res, 'getPublicProfile');
    expect(res.status).toBe(200);
    return res.body as { liveRoomId: string | null; live: Record<string, unknown> | null };
  }

  async function goLive(host: TestUser, title: string): Promise<{ id: string; startedAt: string }> {
    const res = await ctx.http.post('/api/v1/live/rooms').set(bearer(host)).send({ title });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return { id: res.body.id as string, startedAt: res.body.startedAt as string };
  }

  it('not live: live is null (and liveRoomId too)', async () => {
    const [host, viewer] = [await signup(true), await signup()];
    const body = await profile(viewer, host);
    expect(body.liveRoomId).toBeNull();
    expect(body.live).toBeNull();
  });

  it("live: the room's facts on someone else's profile and on the own one; gone when it ends", async () => {
    const [host, viewer] = [await signup(true), await signup()];
    const room = await goLive(host, 'سهرة الجمعة');
    await ctx.prisma.liveRoom.update({ where: { id: room.id }, data: { score: 41_900n, viewerCount: 93 } });
    const expected = {
      roomId: room.id,
      title: 'سهرة الجمعة',
      mode: 'SOLO',
      startedAt: room.startedAt,
      viewerCount: 93,
      score: 41_900,
    };
    const other = await profile(viewer, host);
    expect(other.liveRoomId).toBe(room.id);
    expect(other.live).toEqual(expected);
    // The own profile («أنت في بث الآن»).
    const own = await profile(host, host);
    expect(own.live).toEqual(expected);
    // The live ends → no card.
    const end = await ctx.http.post(`/api/v1/live/rooms/${room.id}/end`).set(bearer(host)).send();
    expect(end.status).toBe(200);
    const after = await profile(viewer, host);
    expect(after.liveRoomId).toBeNull();
    expect(after.live).toBeNull();
  });

  it('a stale live (no heartbeat) is neither the ring nor the card, and it is ended', async () => {
    const [host, viewer] = [await signup(true), await signup()];
    const room = await goLive(host, 'Stale soon');
    clock.advance(STALE_SECONDS + 1);
    const body = await profile(viewer, host);
    expect(body.liveRoomId).toBeNull();
    expect(body.live).toBeNull();
    const row = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: room.id } });
    expect(row.status).toBe('ENDED');
    expect(row.endReason).toBe('HEARTBEAT_TIMEOUT');
  });

  it('a block either way hides the card (the room is hidden too); the ring field is unchanged', async () => {
    const [host, blocker, blocked] = [await signup(true), await signup(), await signup()];
    const room = await goLive(host, 'Blocked');
    // The viewer blocked the host.
    await ctx.http.put(`/api/v1/users/${host.username}/block`).set(bearer(blocker)).expect(200);
    const mine = await profile(blocker, host);
    expect(mine.liveRoomId).toBe(room.id);
    expect(mine.live).toBeNull();
    // The host blocked the viewer.
    await ctx.http.put(`/api/v1/users/${blocked.username}/block`).set(bearer(host)).expect(200);
    const theirs = await profile(blocked, host);
    expect(theirs.liveRoomId).toBe(room.id);
    expect(theirs.live).toBeNull();
    // Unblocked → the card again.
    await ctx.http.delete(`/api/v1/users/${host.username}/block`).set(bearer(blocker)).expect(200);
    expect((await profile(blocker, host)).live).toMatchObject({ roomId: room.id, title: 'Blocked' });
  });
});
