/**
 * KL-084 / CP-021 (D112, owner 2026-10-26): the CP space (openapi v1.24-live DRAFT, CONVENTIONS
 * §10.24, §10.5, §10.11, §10.21, §11.7, §4, §7), end to end against PostgreSQL + Redis with the
 * API as the DML-only runtime role: daily CP tasks (check-in, claims, reset, no farming), CP
 * privileges by level (profile flags, the chat bubble, the entrance info on `join`), the public
 * couple page, the CP gift wall, the couples ranking (week and all), confessions (write, retry,
 * text rules, blocked words, delete, report, rate limit) and blocks.
 *
 * Coins are granted straight through the ledger (`creditIn`, as `wallet-admin` does). Time comes
 * from a FakeClock (CP day and week in UTC, the default LIVE_RANKINGS_TIME_ZONE).
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { uuidv7 } from '../src/modules/levels/uuidv7.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
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
  /** Moves to the next UTC day at `hour`:00. */
  nextUtcDay(hour = 1): void {
    const d = new Date(this.ms);
    this.ms = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + 1, hour);
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface Couple {
  readonly a: TestUser;
  readonly b: TestUser;
  readonly id: string;
}

const DAY = 24 * 3600;

describe('CP-021 contract coverage', () => {
  it('openapi declares the CP space operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'getMyCpTasks GET /api/v1/cp/me/tasks',
      'checkInCp POST /api/v1/cp/me/check-in',
      'claimCpTask POST /api/v1/cp/me/tasks/{code}/claim',
      'getMyCpPrivileges GET /api/v1/cp/me/privileges',
      'listMyCpConfessions GET /api/v1/cp/me/confessions',
      'createCpConfession POST /api/v1/cp/me/confessions',
      'deleteCpConfession DELETE /api/v1/cp/me/confessions/{confessionId}',
      'listCpRankings GET /api/v1/cp/rankings',
      'getCpCouple GET /api/v1/cp/couples/{coupleId}',
      'getCpGiftWall GET /api/v1/cp/couples/{coupleId}/gift-wall',
      'listCpCoupleConfessions GET /api/v1/cp/couples/{coupleId}/confessions',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('CP-021 the CP space', { timeout: 180_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
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
  const grant = (u: TestUser, coins: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(coins), 'ADMIN_GRANT', uuidv7()));
  const pair = async (): Promise<Couple> => {
    const [a, b] = [await signup(), await signup()];
    await grant(a, 99);
    const sent = await ctx.http
      .post('/api/v1/cp/requests')
      .set(auth(a))
      .send({ username: b.username, clientId: randomUUID() });
    expect(sent.status).toBe(201);
    const accepted = await ctx.http
      .post(`/api/v1/cp/requests/${sent.body.request.id as string}/accept`)
      .set(auth(b));
    expect(accepted.status).toBe(200);
    return { a, b, id: accepted.body.id as string };
  };
  const gift = async (u: TestUser, amount: number) => {
    await grant(u, amount);
    const res = await ctx.http
      .post('/api/v1/cp/me/gifts')
      .set(auth(u))
      .send({ amount, clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    clock.advance(1);
    return res.body as { gift: { id: string }; cp: { points: number; level: number } };
  };
  /** Raises the couple to at least `level` with CP gifts of 1314 (tiers 520, 1314, 5200, 13140, 52000). */
  const raise = async (u: TestUser, level: number) => {
    const need = [0, 0, 520, 1314, 5200, 13140, 52000][level]!;
    let points = (await ctx.http.get('/api/v1/cp/me').set(auth(u))).body.cp.points as number;
    while (points < need) points = (await gift(u, 1314)).cp.points;
  };
  const tasks = async (u: TestUser, lang = 'en') => {
    const res = await ctx.http.get('/api/v1/cp/me/tasks').set(auth(u)).set('Accept-Language', lang);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyCpTasks');
    return res.body as {
      day: string;
      timeZone: string;
      startsAt: string;
      resetsAt: string;
      checkedIn: { me: boolean; partner: boolean };
      tasks: {
        code: string;
        name: string;
        progress: number;
        target: number;
        completed: boolean;
        claimed: boolean;
        reward: number;
      }[];
    };
  };
  const task = async (u: TestUser, code: string) => (await tasks(u)).tasks.find((t) => t.code === code)!;
  const checkIn = (u: TestUser) => ctx.http.post('/api/v1/cp/me/check-in').set(auth(u));
  const claim = (u: TestUser, code: string) =>
    ctx.http.post(`/api/v1/cp/me/tasks/${code}/claim`).set(auth(u));
  const myPoints = async (u: TestUser) =>
    (await ctx.http.get('/api/v1/cp/me').set(auth(u))).body.cp.points as number;
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser): Promise<string> => {
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'CP space' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const hook = (event: string, roomName: string, identity: string) => {
    const raw = JSON.stringify({ event, room: { name: roomName }, participant: { identity } });
    return ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
  };
  const join = async (roomId: string, u: TestUser) => {
    clock.advance(2); // the "joined" line is throttled to one a second per room
    expect((await hook('participant_joined', roomId, u.id)).status).toBe(200);
  };
  const say = async (roomId: string, u: TestUser, text: string) => {
    clock.advance(2); // the 1-a-second chat counting rule
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/chat`)
      .set(auth(u))
      .send({ text, clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'sendLiveChatMessage');
    return res.body as { id: string; text: string; cpBubble: boolean };
  };
  const block = async (by: TestUser, u: TestUser) =>
    expect((await ctx.http.put(`/api/v1/users/${u.username}/block`).set(auth(by))).status).toBe(200);
  const unblock = async (by: TestUser, u: TestUser) =>
    expect((await ctx.http.delete(`/api/v1/users/${u.username}/block`).set(auth(by))).status).toBe(200);
  const publicCouple = (reader: TestUser, coupleId: string, lang = 'en') =>
    ctx.http.get(`/api/v1/cp/couples/${coupleId}`).set(auth(reader)).set('Accept-Language', lang);

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    clock.nextUtcDay(1);
  });
  afterAll(async () => ctx?.close());

  // ---- Couple gifts -----------------------------------------------------------------------------

  it('GET /cp/config names the five gift cards (ar/en) and keeps the amounts', async () => {
    const u = await signup();
    for (const [lang, names] of [
      ['en', ['Rose Love', 'Angel Heart', 'Love Carriage', 'Swan Love', 'Eternal Heart']],
      ['ar', ['وردة الحب', 'قلب الملاك', 'عربة الحب', 'بجعتا الحب', 'القلب الأبدي']],
    ] as const) {
      const res = await ctx.http.get('/api/v1/cp/config').set(auth(u)).set('Accept-Language', lang);
      expect(res.status).toBe(200);
      expectContract(res, 'getCpConfig');
      expect(res.body.giftAmounts).toEqual([10, 52, 99, 520, 1314]);
      expect(res.body.gifts).toEqual(
        ['rose_love', 'angel_heart', 'love_carriage', 'swan_love', 'eternal_heart'].map((code, i) => ({
          code,
          amount: [10, 52, 99, 520, 1314][i],
          name: names[i],
          assetKey: `cp_gift_${code}`,
        })),
      );
    }
  });

  // ---- Daily tasks ------------------------------------------------------------------------------

  describe('daily tasks', () => {
    it('check-in, gift and chat-together complete, claim once per day per couple, and reset at 00:00', async () => {
      const { a, b, id } = await pair();
      const lonely = await signup();
      for (const res of [
        await ctx.http.get('/api/v1/cp/me/tasks').set(auth(lonely)),
        await checkIn(lonely),
        await claim(lonely, 'CHECK_IN'),
      ]) {
        expect(res.status).toBe(409);
        expect(res.body.error.code).toBe('CP_NOT_PAIRED');
      }
      expect((await claim(a, 'NOPE')).status).toBe(404);

      const first = await tasks(a);
      expect(first.timeZone).toBe('UTC');
      expect(first.day).toBe(clock.now().toISOString().slice(0, 10));
      expect(new Date(first.resetsAt).getTime() - new Date(first.startsAt).getTime()).toBe(DAY * 1000);
      expect(first.checkedIn).toEqual({ me: false, partner: false });
      expect(
        first.tasks.map((t) => [t.code, t.reward, t.progress, t.target, t.completed, t.claimed]),
      ).toEqual([
        ['CHECK_IN', 10, 0, 2, false, false],
        ['SEND_GIFT', 20, 0, 1, false, false],
        ['CHAT_TOGETHER', 30, 0, 1, false, false],
      ]);
      expect((await tasks(a, 'ar')).tasks[0]!.name).toBe('تسجيل الحضور معاً');

      // CHECK_IN: both partners, once each per day.
      const notYet = await claim(a, 'CHECK_IN');
      expect(notYet.status).toBe(409);
      expectContract(notYet, 'claimCpTask');
      expect(notYet.body.error.code).toBe('CP_TASK_NOT_COMPLETED');
      const ci = await checkIn(a);
      expect(ci.status).toBe(201);
      expectContract(ci, 'checkInCp');
      expect(ci.body.checkedIn).toEqual({ me: true, partner: false });
      const again = await checkIn(a);
      expect(again.status).toBe(200);
      expectContract(again, 'checkInCp');
      expect((await task(b, 'CHECK_IN')).progress).toBe(1);
      expect((await tasks(b)).checkedIn).toEqual({ me: false, partner: true });
      expect((await claim(a, 'CHECK_IN')).body.error.code).toBe('CP_TASK_NOT_COMPLETED');
      expect((await checkIn(b)).status).toBe(201);
      const claimed = await claim(a, 'CHECK_IN');
      expect(claimed.status).toBe(201);
      expectContract(claimed, 'claimCpTask');
      expect(claimed.body.task).toMatchObject({
        code: 'CHECK_IN',
        progress: 2,
        completed: true,
        claimed: true,
      });
      expect(claimed.body.cp).toMatchObject({ id, points: 10 });
      // The partner's claim (and a retry) add nothing.
      const twice = await claim(b, 'CHECK_IN');
      expect(twice.status).toBe(200);
      expectContract(twice, 'claimCpTask');
      expect(twice.body.cp.points).toBe(10);
      expect((await claim(a, 'CHECK_IN')).status).toBe(200);
      expect(await myPoints(a)).toBe(10);

      // SEND_GIFT: either partner's CP gift today.
      expect((await claim(b, 'SEND_GIFT')).body.error.code).toBe('CP_TASK_NOT_COMPLETED');
      await gift(b, 10);
      expect((await claim(b, 'SEND_GIFT')).status).toBe(201);
      expect(await myPoints(a)).toBe(10 + 10 + 20);

      // CHAT_TOGETHER: both write in the chat of the same live.
      const [h1, h2] = [await host(), await host()];
      const [room1, room2] = [await goLive(h1), await goLive(h2)];
      for (const r of [room1, room2]) for (const u of [a, b]) await join(r, u);
      await say(room1, a, 'hello');
      await say(room2, b, 'hi'); // a different live: not together
      expect((await task(a, 'CHAT_TOGETHER')).progress).toBe(0);
      expect((await claim(a, 'CHAT_TOGETHER')).body.error.code).toBe('CP_TASK_NOT_COMPLETED');
      await say(room1, b, 'together');
      expect((await task(a, 'CHAT_TOGETHER')).completed).toBe(true);
      expect((await claim(a, 'CHAT_TOGETHER')).status).toBe(201);
      expect(await myPoints(b)).toBe(70);

      // One ledger row per gain (gift + three claims), matching the couple's points.
      const ledger = await ctx.prisma.cpPointsEntry.findMany({
        where: { coupleId: id },
        orderBy: { createdAt: 'asc' },
      });
      expect(ledger.map((r) => [r.source, r.points])).toEqual([
        ['TASK', 10],
        ['GIFT', 10],
        ['TASK', 20],
        ['TASK', 30],
      ]);
      expect(await ctx.prisma.cpTaskClaim.count({ where: { coupleId: id } })).toBe(3);

      // 00:00 UTC: a new CP day, nothing done or claimed; yesterday's claims stay claimed.
      clock.nextUtcDay(0);
      clock.advance(60);
      const fresh = await tasks(a);
      expect(fresh.day).toBe(clock.now().toISOString().slice(0, 10));
      expect(fresh.checkedIn).toEqual({ me: false, partner: false });
      expect(fresh.tasks.every((t) => t.progress === 0 && !t.completed && !t.claimed)).toBe(true);
      expect((await claim(a, 'CHECK_IN')).body.error.code).toBe('CP_TASK_NOT_COMPLETED');
      expect((await claim(a, 'CHAT_TOGETHER')).body.error.code).toBe('CP_TASK_NOT_COMPLETED');
      expect(await myPoints(a)).toBe(70);
    });

    it('two partners claiming at once add the reward once', async () => {
      const { a, b, id } = await pair();
      expect((await checkIn(a)).status).toBe(201);
      expect((await checkIn(b)).status).toBe(201);
      const results = await Promise.all([claim(a, 'CHECK_IN'), claim(b, 'CHECK_IN'), claim(a, 'CHECK_IN')]);
      expect(results.map((r) => r.status).sort()).toEqual([200, 200, 201]);
      expect(await myPoints(a)).toBe(10);
      expect(await ctx.prisma.cpPointsEntry.count({ where: { coupleId: id, source: 'TASK' } })).toBe(1);
    });

    it('a couple formed today does not inherit chat written before it formed', async () => {
      const [h] = [await host()];
      const room = await goLive(h);
      const [x, y] = [await signup(), await signup()];
      await join(room, x);
      await join(room, y);
      await say(room, x, 'before');
      await say(room, y, 'before too');
      await grant(x, 99);
      const sent = await ctx.http
        .post('/api/v1/cp/requests')
        .set(auth(x))
        .send({ username: y.username, clientId: randomUUID() });
      clock.advance(5);
      expect(
        (await ctx.http.post(`/api/v1/cp/requests/${sent.body.request.id as string}/accept`).set(auth(y)))
          .status,
      ).toBe(200);
      expect((await task(x, 'CHAT_TOGETHER')).progress).toBe(0);
      await say(room, x, 'after');
      await say(room, y, 'after too');
      expect((await task(x, 'CHAT_TOGETHER')).progress).toBe(1);
    });
  });

  // ---- Privileges -------------------------------------------------------------------------------

  describe('privileges', () => {
    it('unlock with the CP level, on GET /cp/me/privileges, the profile and the couple page', async () => {
      const lonely = await signup();
      const none = await ctx.http.get('/api/v1/cp/me/privileges').set(auth(lonely));
      expect(none.status).toBe(200);
      expectContract(none, 'getMyCpPrivileges');
      expect(none.body.level).toBeNull();
      expect(none.body.privileges.every((p: { unlocked: boolean }) => !p.unlocked)).toBe(true);

      const { a, b, id } = await pair();
      const mine = async (lang = 'en') => {
        const res = await ctx.http.get('/api/v1/cp/me/privileges').set(auth(a)).set('Accept-Language', lang);
        expectContract(res, 'getMyCpPrivileges');
        return res.body as {
          level: number;
          privileges: { code: string; name: string; unlockLevel: number; unlocked: boolean }[];
        };
      };
      const l1 = await mine();
      expect(l1.level).toBe(1);
      expect(l1.privileges.map((p) => [p.code, p.unlockLevel, p.unlocked])).toEqual([
        ['SPECIAL_FRAME', 1, true],
        ['CHAT_BUBBLE', 2, false],
        ['MIC_EFFECT', 3, false],
        ['ENTRANCE_EFFECT', 4, false],
        ['GIFT_WALL', 5, false],
      ]);
      expect((await mine('ar')).privileges[1]!.name).toBe('فقاعة دردشة حصرية');

      const profile = async (reader: TestUser, u: TestUser) => {
        const res = await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(reader));
        expect(res.status).toBe(200);
        expectContract(res, 'getPublicProfile');
        return res.body.cp as { id: string; privileges: string[]; level: number };
      };
      const stranger = await signup();
      expect(await profile(stranger, b)).toMatchObject({ id, level: 1, privileges: ['SPECIAL_FRAME'] });

      await raise(a, 3);
      expect((await mine()).privileges.filter((p) => p.unlocked).map((p) => p.code)).toEqual([
        'SPECIAL_FRAME',
        'CHAT_BUBBLE',
        'MIC_EFFECT',
      ]);
      expect((await profile(stranger, a)).privileges).toEqual(['SPECIAL_FRAME', 'CHAT_BUBBLE', 'MIC_EFFECT']);
      const page = await publicCouple(stranger, id);
      expect(page.body.privileges).toEqual(['SPECIAL_FRAME', 'CHAT_BUBBLE', 'MIC_EFFECT']);
      await raise(a, 5);
      expect((await mine()).privileges.every((p) => p.unlocked)).toBe(true);
    });

    it('the chat bubble is set on messages of a level-2 couple, stored, listed and broadcast', async () => {
      const { a, b } = await pair();
      const single = await signup();
      const h = await host();
      const room = await goLive(h);
      for (const u of [a, b, single]) await join(room, u);
      expect((await say(room, a, 'level one')).cpBubble).toBe(false);
      expect((await say(room, single, 'no couple')).cpBubble).toBe(false);
      await raise(a, 2);
      const bubbled = await say(room, b, 'level two');
      expect(bubbled.cpBubble).toBe(true);
      const sent = media
        .broadcastsOf(room, 'chat')
        .map((p) => p.message as { id: string; cpBubble: boolean })
        .find((m) => m.id === bubbled.id);
      expect(sent?.cpBubble).toBe(true);
      const list = await ctx.http.get(`/api/v1/live/rooms/${room}/chat`).set(auth(single));
      expectContract(list, 'listLiveChatMessages');
      expect(
        (list.body.data as { text: string; cpBubble: boolean }[]).map((m) => [m.text, m.cpBubble]),
      ).toEqual([
        ['level one', false],
        ['no couple', false],
        ['level two', true],
      ]);
      // A block between the partners, or an inactive partner, turns the live effects off.
      await block(a, b);
      expect((await say(room, b, 'blocked')).cpBubble).toBe(false);
      await unblock(a, b);
      expect((await say(room, b, 'unblocked')).cpBubble).toBe(true);
      await ctx.prisma.user.update({ where: { id: a.id }, data: { status: 'SUSPENDED' } });
      expect((await say(room, b, 'partner away')).cpBubble).toBe(false);
      await ctx.prisma.user.update({ where: { id: a.id }, data: { status: 'ACTIVE' } });
    });

    it('a joiner whose couple unlocked the Entrance Effect brings the couple in the join line', async () => {
      const { a, b, id } = await pair();
      const low = await pair();
      const h = await host();
      const room = await goLive(h);
      await raise(low.a, 3);
      await join(room, low.a);
      await raise(a, 4);
      await join(room, a);
      const joins = media.broadcastsOf(room, 'join') as {
        user: { id: string };
        cp: { coupleId: string; partner: { id: string; username: string }; level: number } | null;
      }[];
      expect(joins.map((j) => [j.user.id, j.cp])).toEqual([
        [low.a.id, null],
        [
          a.id,
          { coupleId: id, partner: expect.objectContaining({ id: b.id, username: b.username }), level: 4 },
        ],
      ]);
    });
  });

  // ---- The couple page and the gift wall --------------------------------------------------------

  describe('the couple page and the gift wall', () => {
    it('anyone signed in reads a couple; blocks, inactive partners and ended couples → 404', async () => {
      const { a, b, id } = await pair();
      const stranger = await signup();
      clock.advance(2 * DAY);
      const res = await publicCouple(stranger, id, 'ar');
      expect(res.status).toBe(200);
      expectContract(res, 'getCpCouple');
      expect(res.body).toMatchObject({
        id,
        days: 3,
        points: 0,
        level: 1,
        levelName: 'ثنائي متحمّس',
        nextLevelName: 'ثنائي فضّي',
        pointsToNext: 520,
        privileges: ['SPECIAL_FRAME'],
        mine: false,
      });
      expect((res.body.partners as { id: string }[]).map((p) => p.id)).toEqual([a.id, b.id].sort());
      expect((await publicCouple(a, id)).body.mine).toBe(true);
      expect((await ctx.http.get('/api/v1/cp/couples/not-a-uuid').set(auth(a))).status).toBe(404);
      expect((await publicCouple(a, randomUUID())).status).toBe(404);

      await block(stranger, b);
      const hidden = await publicCouple(stranger, id);
      expect(hidden.status).toBe(404);
      expectContract(hidden, 'getCpCouple');
      await unblock(stranger, b);
      await block(a, stranger); // either way
      expect((await publicCouple(stranger, id)).status).toBe(404);
      await unblock(a, stranger);
      expect((await publicCouple(stranger, id)).status).toBe(200);

      await ctx.prisma.user.update({ where: { id: b.id }, data: { status: 'SUSPENDED' } });
      expect((await publicCouple(stranger, id)).status).toBe(404);
      await ctx.prisma.user.update({ where: { id: b.id }, data: { status: 'ACTIVE' } });

      expect((await ctx.http.delete('/api/v1/cp/me').set(auth(a))).status).toBe(204);
      expect((await publicCouple(stranger, id)).status).toBe(404);
      expect((await publicCouple(a, id)).status).toBe(404);
    });

    it('lists CP gifts newest first with totals; others read it only once GIFT_WALL is unlocked', async () => {
      const { a, b, id } = await pair();
      const stranger = await signup();
      const wall = (reader: TestUser, query: Record<string, string> = {}) =>
        ctx.http.get(`/api/v1/cp/couples/${id}/gift-wall`).query(query).set(auth(reader));
      await gift(a, 52);
      await gift(b, 520);
      const own = await wall(b);
      expect(own.status).toBe(200);
      expectContract(own, 'getCpGiftWall');
      expect(
        own.body.data.map(
          (g: { amount: number; giftCode: string; sender: { id: string }; receiver: { id: string } }) => [
            g.amount,
            g.giftCode,
            g.sender.id,
            g.receiver.id,
          ],
        ),
      ).toEqual([
        [520, 'swan_love', b.id, a.id],
        [52, 'angel_heart', a.id, b.id],
      ]);
      expect(own.body.totals).toEqual({ gifts: 2, coins: 572 });
      const locked = await wall(stranger);
      expect(locked.status).toBe(403);
      expectContract(locked, 'getCpGiftWall');
      expect(locked.body.error.code).toBe('CP_PRIVILEGE_LOCKED');

      await raise(a, 5);
      const open = await wall(stranger, { limit: '2' });
      expect(open.status).toBe(200);
      expectContract(open, 'getCpGiftWall');
      expect(open.body.data).toHaveLength(2);
      expect(open.body.page.hasMore).toBe(true);
      const total = open.body.totals as { gifts: number; coins: number };
      let seen = open.body.data.length as number;
      let cursor = open.body.page.nextCursor as string | null;
      while (cursor) {
        const next = await wall(stranger, { limit: '2', cursor });
        expect(next.status).toBe(200);
        seen += next.body.data.length as number;
        cursor = next.body.page.nextCursor as string | null;
      }
      expect(seen).toBe(total.gifts);
      expect(total.coins).toBe(572 + 1314 * (total.gifts - 2));
      expect((await wall(stranger, { cursor: 'forged' })).status).toBe(400);
      await block(stranger, a);
      expect((await wall(stranger)).status).toBe(404);
    });
  });

  // ---- Confessions ------------------------------------------------------------------------------

  describe('confessions', () => {
    const confess = (u: TestUser, body: object) =>
      ctx.http.post('/api/v1/cp/me/confessions').set(auth(u)).send(body);

    it('partners write, retry, read; text rules and both partners blocked words apply', async () => {
      const { a, b, id } = await pair();
      await ctx.prisma.liveHost.create({ data: { userId: b.id, source: 'ADMIN', blockedWords: ['secret'] } });
      const clientId = randomUUID();
      const created = await confess(a, { text: '  my secret love  ', clientId });
      expect(created.status).toBe(201);
      expectContract(created, 'createCpConfession');
      expect(created.body).toMatchObject({ coupleId: id, text: 'my ****** love' });
      expect(created.body.author.id).toBe(a.id);
      expect(created.body.recipient.id).toBe(b.id);
      const retry = await confess(a, { text: 'different', clientId });
      expect(retry.status).toBe(200);
      expect(retry.body.id).toBe(created.body.id);

      for (const [text, issue] of [
        ['   ', 'required'],
        ['line\nbreak', 'invalid_format'],
        ['x'.repeat(201), 'too_long'],
      ] as const) {
        const bad = await confess(a, { text, clientId: randomUUID() });
        expect(bad.status).toBe(400);
        expectContract(bad, 'createCpConfession');
        expect(bad.body.error.details).toEqual([{ field: 'text', issue }]);
      }
      expect((await confess(a, { text: 'x', clientId: randomUUID(), extra: true })).status).toBe(400);

      clock.advance(1);
      expect((await confess(b, { text: 'me too', clientId: randomUUID() })).status).toBe(201);
      const lonely = await signup();
      const notPaired = await confess(lonely, { text: 'hi', clientId: randomUUID() });
      expect(notPaired.status).toBe(409);
      expect(notPaired.body.error.code).toBe('CP_NOT_PAIRED');
      expect((await ctx.http.get('/api/v1/cp/me/confessions').set(auth(lonely))).status).toBe(409);

      for (const reader of [a, b]) {
        const res = await ctx.http.get('/api/v1/cp/me/confessions').set(auth(reader));
        expect(res.status).toBe(200);
        expectContract(res, 'listMyCpConfessions');
        expect(res.body.data.map((c: { text: string }) => c.text)).toEqual(['me too', 'my ****** love']);
      }
      const stranger = await signup();
      const pub = await ctx.http
        .get(`/api/v1/cp/couples/${id}/confessions`)
        .query({ limit: '1' })
        .set(auth(stranger));
      expect(pub.status).toBe(200);
      expectContract(pub, 'listCpCoupleConfessions');
      expect(pub.body.data.map((c: { text: string }) => c.text)).toEqual(['me too']);
      const rest = await ctx.http
        .get(`/api/v1/cp/couples/${id}/confessions`)
        .query({ limit: '1', cursor: pub.body.page.nextCursor as string })
        .set(auth(stranger));
      expect(rest.body.data.map((c: { text: string }) => c.text)).toEqual(['my ****** love']);
      expect(rest.body.page.hasMore).toBe(false);

      // A block between the partners stops new confessions (403); a blocked reader gets 404.
      await block(b, a);
      const refused = await confess(a, { text: 'still?', clientId: randomUUID() });
      expect(refused.status).toBe(403);
      expectContract(refused, 'createCpConfession');
      await unblock(b, a);
      await block(stranger, a);
      expect((await ctx.http.get(`/api/v1/cp/couples/${id}/confessions`).set(auth(stranger))).status).toBe(
        404,
      );
    });

    it('either partner deletes one; strangers cannot; reports remove it', async () => {
      const { a, b, id } = await pair();
      const other = await pair();
      const one = (await confess(a, { text: 'first', clientId: randomUUID() })).body.id as string;
      clock.advance(1);
      const two = (await confess(a, { text: 'second', clientId: randomUUID() })).body.id as string;
      // Not on the caller's couple page → 404.
      expect((await ctx.http.delete(`/api/v1/cp/me/confessions/${one}`).set(auth(other.a))).status).toBe(404);
      expect((await ctx.http.delete('/api/v1/cp/me/confessions/nope').set(auth(a))).status).toBe(404);
      // The recipient removes it; again → 204.
      expect((await ctx.http.delete(`/api/v1/cp/me/confessions/${one}`).set(auth(b))).status).toBe(204);
      expect((await ctx.http.delete(`/api/v1/cp/me/confessions/${one}`).set(auth(a))).status).toBe(204);
      const left = await ctx.http.get(`/api/v1/cp/couples/${id}/confessions`).set(auth(other.b));
      expect(left.body.data.map((c: { id: string }) => c.id)).toEqual([two]);

      // Reports: anyone who can read it, not its author; a removed one is not reportable.
      const report = (u: TestUser, targetId: string) =>
        ctx.http
          .post('/api/v1/reports')
          .set(auth(u))
          .send({ targetType: 'CP_CONFESSION', targetId, reason: 'HARASSMENT' });
      expect((await report(a, two)).status).toBe(400);
      expect((await report(other.a, one)).status).toBe(404);
      const filed = await report(other.a, two);
      expect(filed.status).toBe(201);
      expectContract(filed, 'createReport');
      expect(filed.body).toMatchObject({ targetType: 'CP_CONFESSION', targetId: two, status: 'OPEN' });
      expect((await report(other.a, two)).status).toBe(200);
      expect((await report(b, two)).status).toBe(201); // the recipient may report it too

      const mod = await signup();
      await withMigrationClient(async (c) => {
        await c.user.update({ where: { id: mod.id }, data: { role: 'ADMIN' } });
        await c.userAdminPermission.create({ data: { userId: mod.id, permission: 'MODERATION' } });
      });
      const acted = await ctx.http
        .post(`/api/v1/admin/reports/${filed.body.id as string}/actions`)
        .set(auth(mod))
        .send({ action: 'REMOVE_TARGET' });
      expect(acted.status).toBe(200);
      expect(acted.body).toMatchObject({ status: 'ACTIONED', targetType: 'CP_CONFESSION' });
      expect(await ctx.prisma.report.count({ where: { targetCpConfessionId: two, status: 'OPEN' } })).toBe(0);
      const after = await ctx.http.get('/api/v1/cp/me/confessions').set(auth(a));
      expect(after.body.data).toEqual([]);
      const row = await ctx.prisma.cpConfession.findUniqueOrThrow({ where: { id: two } });
      expect(row.deletedById).toBe(mod.id);
    });
  });

  // ---- The couples ranking ----------------------------------------------------------------------

  describe('the couples ranking', () => {
    it('ranks couples by points gained this CP week or in all, hides blocked couples, pages and shows me', async () => {
      clock.advance(8 * DAY); // a new CP week: earlier gains of this file are last week's
      const x = await pair();
      const y = await pair();
      const z = await pair();
      await gift(x.a, 1314); // this week, then moved to last week below
      const rank = async (reader: TestUser, period?: string, extra: Record<string, string> = {}) => {
        const res = await ctx.http
          .get('/api/v1/cp/rankings')
          .query({ ...(period ? { period } : {}), ...extra })
          .set(auth(reader));
        expect(res.status, JSON.stringify(res.body)).toBe(200);
        expectContract(res, 'listCpRankings');
        return res.body as {
          period: string;
          startsAt: string | null;
          endsAt: string | null;
          data: {
            rank: number;
            coupleId: string;
            points: number;
            partners: { id: string }[];
            levelName: string;
          }[];
          page: { hasMore: boolean; nextCursor: string | null };
          me: { coupleId: string; rank: number | null; points: number } | null;
        };
      };
      clock.advance(8 * DAY);
      await gift(y.a, 520);
      await gift(x.b, 10);
      await gift(z.b, 99);

      const week = await rank(x.a);
      expect(week.period).toBe('WEEK');
      const start = new Date(week.startsAt!);
      expect(start.getUTCDay()).toBe(1); // Monday
      expect(start.getUTCHours()).toBe(0);
      expect(new Date(week.endsAt!).getTime() - start.getTime()).toBe(7 * DAY * 1000);
      const ids = (r: typeof week) => r.data.map((e) => e.coupleId);
      expect(ids(week)).toEqual([y.id, z.id, x.id]);
      expect(week.data.map((e) => [e.rank, e.points])).toEqual([
        [1, 520],
        [2, 99],
        [3, 10],
      ]);
      expect(week.data[0]!.partners.map((p) => p.id)).toEqual([y.a.id, y.b.id].sort());
      expect(week.me).toEqual({ coupleId: x.id, rank: 3, points: 10 });

      const all = await rank(x.a, 'ALL');
      expect(all.startsAt).toBeNull();
      const mineAll = all.data.filter((e) => [x.id, y.id, z.id].includes(e.coupleId));
      expect(mineAll.map((e) => [e.coupleId, e.points])).toEqual([
        [x.id, 1324],
        [y.id, 520],
        [z.id, 99],
      ]);
      expect(all.data.map((e) => e.points)).toEqual([...all.data.map((e) => e.points)].sort((p, q) => q - p));
      expect(all.me).toEqual({
        coupleId: x.id,
        rank: all.data.find((e) => e.coupleId === x.id)!.rank,
        points: 1324,
      });

      // Paging with a signed offset cursor.
      const p1 = await rank(x.a, 'WEEK', { limit: '2' });
      expect(ids(p1)).toEqual([y.id, z.id]);
      expect(p1.page.hasMore).toBe(true);
      const p2 = await rank(x.a, 'WEEK', { limit: '2', cursor: p1.page.nextCursor! });
      expect(p2.data.map((e) => [e.rank, e.coupleId])).toEqual([[3, x.id]]);
      expect(p2.page.hasMore).toBe(false);
      expect((await ctx.http.get('/api/v1/cp/rankings').query({ cursor: 'x' }).set(auth(x.a))).status).toBe(
        400,
      );
      expect((await ctx.http.get('/api/v1/cp/rankings').query({ period: 'DAY' }).set(auth(x.a))).status).toBe(
        400,
      );
      // Another reader's cursor is refused (cursors are per reader and window).
      expect(
        (await ctx.http.get('/api/v1/cp/rankings').query({ cursor: p1.page.nextCursor! }).set(auth(y.a)))
          .status,
      ).toBe(400);

      // A reader who blocked (or was blocked by) a partner does not see that couple.
      const reader = await signup();
      await block(reader, y.b);
      expect(ids(await rank(reader))).toEqual([z.id, x.id]);
      await block(z.a, reader);
      expect(ids(await rank(reader))).toEqual([x.id]);
      expect((await rank(reader)).me).toBeNull();
      // Inactive partners and ended couples leave the ranking.
      await ctx.prisma.user.update({ where: { id: x.b.id }, data: { status: 'SUSPENDED' } });
      expect(ids(await rank(y.a))).toEqual([y.id, z.id]);
      await ctx.prisma.user.update({ where: { id: x.b.id }, data: { status: 'ACTIVE' } });
      expect((await ctx.http.delete('/api/v1/cp/me').set(auth(z.b))).status).toBe(204);
      expect(ids(await rank(y.a))).toEqual([y.id, x.id]);

      // Task claims count for the week.
      expect((await checkIn(x.a)).status).toBe(201);
      expect((await checkIn(x.b)).status).toBe(201);
      expect((await claim(x.b, 'CHECK_IN')).status).toBe(201);
      expect((await rank(y.a)).data.find((e) => e.coupleId === x.id)?.points).toBe(20);
    });
  });
});

describe('CP-021 confession rate limit', { timeout: 60_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_CP_CONFESSION_USER: '2/3600' });
  });
  afterAll(async () => ctx?.close());

  it('allows 2 an hour per user here (10 by default) and answers 429 after', async () => {
    const signup = async () => {
      const { res } = await registerVerified(ctx);
      return {
        id: res.body.user.id as string,
        username: res.body.user.username as string,
        token: res.body.tokens.accessToken as string,
      };
    };
    const [a, b] = [await signup(), await signup()];
    await ctx.prisma.$transaction((tx) => creditIn(tx, a.id, 99n, 'ADMIN_GRANT', uuidv7()));
    const sent = await ctx.http
      .post('/api/v1/cp/requests')
      .set({ Authorization: `Bearer ${a.token}` })
      .send({ username: b.username, clientId: randomUUID() });
    await ctx.http
      .post(`/api/v1/cp/requests/${sent.body.request.id as string}/accept`)
      .set({ Authorization: `Bearer ${b.token}` });
    const statuses: number[] = [];
    for (let i = 0; i < 3; i++) {
      const res = await ctx.http
        .post('/api/v1/cp/me/confessions')
        .set({ Authorization: `Bearer ${a.token}` })
        .send({ text: `note ${i}`, clientId: randomUUID() });
      statuses.push(res.status);
      if (res.status === 429) {
        expectContract(res, 'createCpConfession');
        expect(res.headers['retry-after']).toBeDefined();
      }
    }
    expect(statuses).toEqual([201, 201, 429]);
  });
});
