/**
 * D215 (v1.48-live DRAFT, CONVENTIONS §10.70) — owner, two Android phones on staging: «عندما اقوم بفتح
 * لايف وافتح لايف من هاتف اخر لا يظهر صديق في بيكيه فقط بالعشوائي». Two hosts who follow each other (the
 * follow made through the API, as the app does), both live through the API, both with fresh heartbeats:
 * the PK sheet's «الأصدقاء» (`listLivePkCandidates?friends=true`) lists the other host — also while that
 * host is waiting in the random queue (they tapped «مطابقة عشوائية», or Auto Match keeps them there),
 * which before v1.48-live hid them so that only the random match found them. An invitation to a waiting
 * host is accepted and the battle starts (both waits end); while it is open the waiting host is not
 * random-matched with anyone else; declined, they keep waiting. Real API (the media server is the
 * in-memory fake; time is a FakeClock).
 */
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
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
  readonly token: string;
}

describe('D215 PK friends: mutual followers live on two phones', { timeout: 300_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const host = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    const u = {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const call = (method: 'get' | 'post' | 'put' | 'delete', path: string, u: TestUser, body?: object) => {
    const req = ctx.http[method](`/api/v1/${path}`).set(auth(u));
    return body === undefined ? req : req.send(body);
  };
  const ok = (res: request.Response, status: number) => {
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    return res;
  };
  const goLive = async (u: TestUser): Promise<string> =>
    ok(await call('post', 'live/rooms', u, { title: 'PK' }), 201).body.id as string;
  const follow = async (from: TestUser, to: TestUser) => {
    ok(await call('put', `users/${to.username}/follow`, from), 200);
  };
  const friends = async (room: string, u: TestUser): Promise<string[]> => {
    const res = ok(await call('get', `live/rooms/${room}/pk/candidates?friends=true`, u), 200);
    expectContract(res, 'listLivePkCandidates');
    return (res.body.data as { roomId: string }[]).map((c) => c.roomId);
  };
  const heartbeat = async (room: string, u: TestUser) => {
    ok(await call('post', `live/rooms/${room}/heartbeat`, u), 204);
  };
  /** Two mutual followers, both live (the owner's two phones). */
  const twoPhones = async () => {
    const [a, b] = [await host(), await host()];
    await follow(a, b);
    await follow(b, a);
    const roomA = await goLive(a);
    const roomB = await goLive(b);
    await heartbeat(roomA, a);
    await heartbeat(roomB, b);
    return { a, b, roomA, roomB };
  };
  const end = async (...pairs: [string, TestUser][]) => {
    for (const [room, u] of pairs) await call('post', `live/rooms/${room}/end`, u);
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', PK_SCORE_BROADCAST_MS: '0' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('both idle: each sees the other in «الأصدقاء»; a one-way follow is not a friend', async () => {
    const { a, b, roomA, roomB } = await twoPhones();
    expect(await friends(roomA, a)).toEqual([roomB]);
    expect(await friends(roomB, b)).toEqual([roomA]);
    const fan = await host();
    await follow(fan, a);
    const fanRoom = await goLive(fan);
    expect(await friends(roomA, a)).toEqual([roomB]);
    expect(await friends(fanRoom, fan)).toEqual([]);
    await end([roomA, a], [roomB, b], [fanRoom, fan]);
  });

  it('the friend waiting in the random queue is still listed, invited and the battle starts', async () => {
    clock.advance(16); // the invitation cooldown of the earlier tests
    const { a, b, roomA, roomB } = await twoPhones();
    const wait = ok(await call('post', `live/rooms/${roomB}/pk/random`, b), 200);
    expect(wait.body.status).toBe('WAITING');
    // Before v1.48-live B vanished here and only the random match found them.
    expect(await friends(roomA, a)).toEqual([roomB]);
    const inv = ok(await call('post', `live/rooms/${roomA}/pk/invites`, a, { toRoomId: roomB }), 201);
    expectContract(inv, 'inviteLivePk');
    // While the invitation is open B is not random-matched with another host.
    const other = await host();
    const otherRoom = await goLive(other);
    const otherWait = ok(await call('post', `live/rooms/${otherRoom}/pk/random`, other), 200);
    expect(otherWait.body.status).toBe('WAITING');
    const acc = ok(
      await call('post', `live/rooms/${roomB}/pk/invites/${inv.body.id as string}/accept`, b),
      200,
    );
    expectContract(acc, 'acceptLivePkInvite');
    expect(acc.body.source).toBe('INVITE');
    const sides = (acc.body.sides as { roomId: string }[]).map((s) => s.roomId).sort();
    expect(sides).toEqual([roomA, roomB].sort());
    const snapshot = ok(await call('get', `live/rooms/${roomB}/pk`, b), 200);
    expect(snapshot.body.queue).toBeNull();
    expect(await ctx.prisma.pkQueueEntry.count({ where: { hostId: b.id } })).toBe(0);
    await end([roomA, a], [roomB, b], [otherRoom, other]);
  });

  it('declined, the waiting friend keeps waiting (and is random-matched as before)', async () => {
    clock.advance(16);
    const { a, b, roomA, roomB } = await twoPhones();
    ok(await call('post', `live/rooms/${roomB}/pk/random`, b), 200);
    const inv = ok(await call('post', `live/rooms/${roomA}/pk/invites`, a, { toRoomId: roomB }), 201);
    ok(await call('post', `live/rooms/${roomB}/pk/invites/${inv.body.id as string}/decline`, b), 204);
    const snapshot = ok(await call('get', `live/rooms/${roomB}/pk`, b), 200);
    expect(snapshot.body.queue).not.toBeNull();
    // The inviter is still not busy, and the random match with B works.
    const random = ok(await call('post', `live/rooms/${roomA}/pk/random`, a), 200);
    expect(random.body.status).toBe('MATCHED');
    expectContract(random, 'joinLivePkRandom');
    await end([roomA, a], [roomB, b]);
  });

  it('the caller waiting in the queue still cannot invite (409 PK_HOST_BUSY)', async () => {
    clock.advance(16);
    const { a, b, roomA, roomB } = await twoPhones();
    ok(await call('post', `live/rooms/${roomA}/pk/random`, a), 200);
    const res = await call('post', `live/rooms/${roomA}/pk/invites`, a, { toRoomId: roomB });
    expect({ status: res.status, code: res.body.error?.code }).toEqual({ status: 409, code: 'PK_HOST_BUSY' });
    await end([roomA, a], [roomB, b]);
  });
});
