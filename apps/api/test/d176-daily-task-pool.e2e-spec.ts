/**
 * D176 (owner 2026-10-30: «أريد أن تصنع الكثير من المهام اليومية، ترسل لكل شخص بناءً على مستواه»;
 * rewards «العملات فقط»; contract v1.50-social, CONVENTIONS §10.41.1, §10.41.2): the daily task pool —
 * a deterministic per-person, per-day assignment by level band (the higher of Support and Charm),
 * host tasks for hosts, progress from stored data only, one payout per task and day within the daily
 * cap, a new list each day — plus the Event Center's calendar line and tone and the Task Center's
 * banner placement. End to end against PostgreSQL + Redis.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import {
  DEFAULT_POOL_TASKS,
  DEFAULT_TASK_POOL_BANDS,
  assignDailyTasks,
  seedOf,
} from '../src/modules/programs/programs-rules.js';
import {
  POOL_REPLACES_TASKS,
  seedDefaultTaskPoolIn,
  seedDefaultTasksIn,
} from '../src/modules/programs/programs-seed.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, findOperation, openapi } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

/** Real time moved by an offset (rows written by the database keep real times). */
class FakeClock extends Clock {
  private offset = 0;
  now(): Date {
    return new Date(Date.now() + this.offset);
  }
  advance(ms: number): void {
    this.offset += ms;
  }
  reset(): void {
    this.offset = 0;
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface Task {
  code: string;
  pooled: boolean;
  period: string;
  audience: string;
  metric: string;
  progress: number;
  target: number;
  rewardCoins: number;
  completed: boolean;
  claimed: boolean;
  claimedCoins: number | null;
}

interface MyTasks {
  day: string;
  dailyEarnedCoins: number;
  band: { band: number; level: number; name: string; host: boolean };
  tasks: Task[];
}

const HOUR_MS = 3_600_000;
const DAY_MS = 24 * HOUR_MS;
const CAP = 20;
const template = new Map(DEFAULT_POOL_TASKS.map((t) => [t.code, t]));

/** A fixed-offset zone where it is about noon now, so "today" never ends in the middle of a test. */
function noonZone(): string {
  const offset = 12 - new Date().getUTCHours();
  if (offset === 0) return 'Etc/GMT';
  return offset > 0 ? `Etc/GMT-${String(offset)}` : `Etc/GMT+${String(-offset)}`;
}

describe('D176 contract coverage', () => {
  it('openapi v1.50-social declares the pool, the calendar line and tone, and the tasks banners', () => {
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    const task = schemas.ProgramTask as {
      required: string[];
      properties: Record<string, { enum?: string[] }>;
    };
    expect(task.required).toContain('pooled');
    expect(task.properties.metric!.enum).toEqual(
      expect.arrayContaining([
        'WATCH_MINUTES',
        'AUDIO_ROOMS',
        'LIVE_TAPS',
        'NEW_HOST_GIFTS',
        'POSTS',
        'REELS',
        'STORIES',
        'POST_COMMENTS',
        'DM_FRIENDS',
        'DM_VOICE_MESSAGES',
        'HOST_GIFTS_RECEIVED',
        'HOST_GUESTS',
      ]),
    );
    // Coins only (owner 2026-10-30): no experience reward on a task.
    expect(Object.keys(task.properties).some((k) => /exp/i.test(k))).toBe(false);
    expect((schemas.MyTasks as { required: string[] }).required).toContain('band');
    expect((schemas.EventSummary as { required: string[] }).required).toEqual(
      expect.arrayContaining(['summary', 'tone']),
    );
    expect(JSON.stringify(findOperation('listHomeBanners').spec)).toContain('tasks');
  });
});

describe('D176 daily task pool', { timeout: 240_000 }, () => {
  const media = new MemoryLiveMedia();
  const clock = new FakeClock();
  let ctx: TestContext;
  let friends: TestUser[] = [];
  let support = '';
  let charm = '';

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
  const tasks = async (u: TestUser, lang = 'en'): Promise<MyTasks> => {
    const res = await ctx.http.get('/api/v1/me/tasks').set(auth(u)).set('Accept-Language', lang);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyTasks');
    return res.body as MyTasks;
  };
  const task = async (u: TestUser, code: string): Promise<Task | undefined> =>
    (await tasks(u)).tasks.find((t) => t.code === code);
  const claim = (u: TestUser, code: string) => ctx.http.post(`/api/v1/me/tasks/${code}/claim`).set(auth(u));
  const follow = async (a: TestUser, b: TestUser) => {
    const res = await ctx.http.put(`/api/v1/users/${b.username}/follow`).set(auth(a));
    expect(res.status).toBe(200);
  };
  const setLevels = async (u: TestUser, supportLevel: number, charmLevel: number) => {
    for (const [categoryId, level] of [
      [support, supportLevel],
      [charm, charmLevel],
    ] as const) {
      await ctx.prisma.userLevelState.upsert({
        where: { userId_categoryId: { userId: u.id, categoryId } },
        create: { userId: u.id, categoryId, currentLevel: level === 0 ? null : level },
        update: { currentLevel: level === 0 ? null : level },
      });
    }
  };
  /** Only `codes` stay switched on in the pool (the team's `task-admin set … --enabled`). */
  const onlyPool = async (codes: readonly string[]) => {
    await ctx.prisma.taskDefinition.updateMany({ where: { pool: true }, data: { enabled: false } });
    await ctx.prisma.taskDefinition.updateMany({
      where: { code: { in: [...codes] } },
      data: { enabled: true },
    });
  };
  const fullPool = () =>
    ctx.prisma.taskDefinition.updateMany({ where: { pool: true }, data: { enabled: true } });
  const startLive = async (host: TestUser) => {
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Pool' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    return room.body.id as string;
  };
  /** `u` joins the live (the media server's webhook), as a sender must before a gift. */
  const join = async (roomId: string, u: TestUser) => {
    const raw = JSON.stringify({
      event: 'participant_joined',
      room: { name: roomId },
      participant: { identity: u.id },
    });
    const res = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(res.status).toBe(200);
  };
  const sendGift = async (roomId: string, from: TestUser, to: TestUser) => {
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({
        giftCode: 'pool_rose',
        quantity: 1,
        recipients: [to.username],
        source: 'COINS',
        clientId: randomUUID(),
      });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  /** What the rules pick for `u` on `day` from the pool templates switched on now. */
  const expected = async (u: TestUser, day: string, band: number, host: boolean) => {
    const rows = await ctx.prisma.taskDefinition.findMany({ where: { pool: true, enabled: true } });
    return assignDailyTasks(
      rows.map((t) => ({
        code: t.code,
        group: t.poolGroup!,
        audience: t.audience,
        bandTargets: t.bandTargets,
        bandRewards: t.bandRewards,
        sortOrder: t.sortOrder,
      })),
      DEFAULT_TASK_POOL_BANDS[band - 1]!,
      host,
      seedOf(`${u.id}:${day}`),
    );
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: noonZone(),
        TASK_DAILY_CAP_COINS: String(CAP),
      },
      [
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: Clock, value: clock },
      ],
    );
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, 'pool_rose', {
        category: 'POPULAR',
        nameAr: 'وردة',
        nameEn: 'Rose',
        priceCoins: 10,
        assetKey: 'gift_pool_rose',
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
    // The database is emptied for the tests: the migrations' defaults again (task-admin seed-defaults).
    expect(await seedDefaultTasksIn(ctx.prisma)).toBe(6);
    expect(await seedDefaultTaskPoolIn(ctx.prisma)).toBe(DEFAULT_POOL_TASKS.length);
    expect(await seedDefaultTaskPoolIn(ctx.prisma)).toBe(0);
    const level = (code: 'SUPPORT' | 'ATTRACTIVENESS') =>
      ctx.prisma.levelCategory.create({
        data: { code, nameAr: code, nameEn: code, descriptionAr: '-', descriptionEn: '-', isEnabled: true },
      });
    support = (await level('SUPPORT')).id;
    charm = (await level('ATTRACTIVENESS')).id;
    for (let i = 0; i < 3; i++) friends.push(await signup());
    friends = [...friends];
  });
  afterAll(async () => ctx?.close());

  it("each person's day: the band's count, deterministic, stable on reload; D166's fixed daily tasks off", async () => {
    const me = await signup();
    const first = await tasks(me);
    expect(first.band).toEqual({ band: 1, level: 0, name: 'Starter', host: false });
    expect(first.tasks).toHaveLength(6);
    expect(first.tasks.every((t) => t.pooled && t.period === 'DAILY' && t.audience === 'EVERYONE')).toBe(
      true,
    );
    const want = await expected(me, first.day, 1, false);
    expect(first.tasks.map((t) => [t.code, t.target, t.rewardCoins])).toEqual(
      want.map((p) => [p.code, p.target, p.rewardCoins]),
    );
    for (const code of POOL_REPLACES_TASKS) expect(first.tasks.map((t) => t.code)).not.toContain(code);
    // The same list on every read of the day, in Arabic too (names follow the language).
    expect((await tasks(me)).tasks.map((t) => t.code)).toEqual(first.tasks.map((t) => t.code));
    const ar = await tasks(me, 'ar');
    expect(ar.band.name).toBe('مبتدئ');
    expect(ar.tasks.map((t) => t.code)).toEqual(first.tasks.map((t) => t.code));
    expect(await ctx.prisma.taskAssignment.count({ where: { userId: me.id } })).toBe(6);
    // Another person gets another list (different seeds).
    const other = await signup();
    const theirs = await tasks(other);
    expect(theirs.tasks.map((t) => t.code)).toEqual(
      (await expected(other, theirs.day, 1, false)).map((p) => p.code),
    );
    // A pool task that is not one of the caller's today: 404, nothing paid.
    const missing = DEFAULT_POOL_TASKS.find(
      (t) => t.audience === 'EVERYONE' && !first.tasks.some((x) => x.code === t.code),
    )!;
    expect((await claim(me, missing.code)).status).toBe(404);
    expect((await claim(me, 'P_HOST_GUEST')).status).toBe(404);
    expect(await ctx.prisma.walletLedgerEntry.count({ where: { userId: me.id } })).toBe(0);
  });

  it('level bands: the higher of Support and Charm picks the band, its count, targets and rewards', async () => {
    for (const [supportLevel, charmLevel, band, count] of [
      [12, 3, 2, 7],
      [3, 45, 3, 7],
      [61, 70, 4, 8],
    ] as const) {
      const me = await signup();
      await setLevels(me, supportLevel, charmLevel);
      const mine = await tasks(me);
      expect(mine.band).toMatchObject({ band, level: Math.max(supportLevel, charmLevel) });
      expect(mine.tasks).toHaveLength(count);
      for (const t of mine.tasks) {
        expect(t.target).toBe(template.get(t.code)!.bandTargets[band - 1]);
        expect(t.rewardCoins).toBe(template.get(t.code)!.bandRewards[band - 1]);
      }
      expect(mine.tasks.map((t) => t.code)).toEqual(
        (await expected(me, mine.day, band, false)).map((p) => p.code),
      );
    }
    // A task both bands have: band 4 asks more and pays more than band 1.
    const low = await signup();
    const high = await signup();
    await setLevels(high, 80, 0);
    await onlyPool(['P_FOLLOW']);
    try {
      const a = (await tasks(low)).tasks;
      const b = (await tasks(high)).tasks;
      expect(a).toEqual([expect.objectContaining({ code: 'P_FOLLOW', target: 1, rewardCoins: 2 })]);
      expect(b).toEqual([expect.objectContaining({ code: 'P_FOLLOW', target: 10, rewardCoins: 5 })]);
      // A level reached later in the day does not change today's list (it applies tomorrow).
      await setLevels(low, 90, 0);
      expect((await tasks(low)).tasks).toEqual(a);
      expect((await tasks(low)).band.band).toBe(1);
    } finally {
      await fullPool();
    }
  });

  it("hosts get their band's host tasks first; others never do; weekly host tasks stay", async () => {
    const host = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const mine = await tasks(host);
    expect(mine.band).toMatchObject({ band: 1, host: true });
    const daily = mine.tasks.filter((t) => t.pooled);
    expect(daily).toHaveLength(6);
    expect(daily.slice(0, 2).every((t) => t.audience === 'HOSTS')).toBe(true);
    expect(daily.slice(2).every((t) => t.audience === 'EVERYONE')).toBe(true);
    expect(daily.map((t) => t.code)).toEqual((await expected(host, mine.day, 1, true)).map((p) => p.code));
    // D166's weekly host tasks are fixed tasks and still shown after the pool.
    expect(mine.tasks.filter((t) => !t.pooled).map((t) => t.code)).toEqual([
      'HOST_LIVE_MINUTES',
      'HOST_GIFT_COINS',
    ]);
    const viewer = await signup();
    expect((await tasks(viewer)).tasks.some((t) => t.audience === 'HOSTS')).toBe(false);
  });

  it('progress from stored data: follows, posts, stories, comments, friends messaged, voice messages', async () => {
    await onlyPool(['P_FOLLOW', 'P_POST', 'P_STORY', 'P_POST_COMMENTS', 'P_DM_FRIEND', 'P_DM_VOICE']);
    try {
      const me = await signup();
      const [a, b] = friends as [TestUser, TestUser];
      const before = await tasks(me);
      expect(before.tasks.map((t) => t.code).sort()).toEqual([
        'P_DM_FRIEND',
        'P_DM_VOICE',
        'P_FOLLOW',
        'P_POST',
        'P_POST_COMMENTS',
        'P_STORY',
      ]);
      expect(before.tasks.every((t) => t.progress === 0 && !t.completed)).toBe(true);
      expect((await claim(me, 'P_FOLLOW')).body.error.code).toBe('TASK_NOT_COMPLETED');

      await follow(me, a);
      await follow(a, me); // a friend: both follow each other
      await ctx.prisma.post.create({ data: { authorId: me.id, text: 'hello', publishedAt: new Date() } });
      // A deleted post does not count.
      await ctx.prisma.post.create({
        data: { authorId: me.id, text: 'gone', publishedAt: new Date(), deletedAt: new Date() },
      });
      const picture = await ctx.prisma.mediaAsset.create({
        data: {
          ownerId: me.id,
          kind: 'STORY_IMAGE',
          width: 10,
          height: 10,
          largeKey: 'k/l',
          thumbKey: 'k/t',
          byteSize: 1,
        },
      });
      await ctx.prisma.story.create({
        data: { authorId: me.id, mediaAssetId: picture.id, expiresAt: new Date(Date.now() + DAY_MS) },
      });
      const theirPost = await ctx.prisma.post.create({
        data: { authorId: b.id, text: 'theirs', publishedAt: new Date() },
      });
      const ownPost = await ctx.prisma.post.findFirstOrThrow({ where: { authorId: me.id, deletedAt: null } });
      // A comment on the caller's own post does not count; one on someone else's does.
      await ctx.prisma.comment.create({ data: { postId: ownPost.id, authorId: me.id, text: 'self' } });
      await ctx.prisma.comment.create({ data: { postId: theirPost.id, authorId: me.id, text: 'nice' } });
      const dm = async (to: TestUser, kind: 'TEXT' | 'VOICE') => {
        const [low, high] = [me.id, to.id].sort();
        const conversation =
          (await ctx.prisma.dmConversation.findFirst({ where: { userLowId: low!, userHighId: high! } })) ??
          (await ctx.prisma.dmConversation.create({
            data: { userLowId: low!, userHighId: high!, lastMessageAt: new Date() },
          }));
        await ctx.prisma.dmMessage.create({
          data: {
            conversationId: conversation.id,
            senderId: me.id,
            recipientId: to.id,
            clientId: randomUUID(),
            kind,
            text: kind === 'TEXT' ? 'hi' : null,
            expiresAt: new Date(Date.now() + DAY_MS),
          },
        });
      };
      await dm(b, 'TEXT'); // b is not a friend (no follows both ways): does not count
      await dm(a, 'VOICE');

      const after = await tasks(me);
      const by = (code: string) => after.tasks.find((t) => t.code === code)!;
      expect(by('P_FOLLOW')).toMatchObject({ progress: 1, completed: true });
      expect(by('P_POST')).toMatchObject({ progress: 1, completed: true });
      expect(by('P_STORY')).toMatchObject({ progress: 1, completed: true });
      expect(by('P_POST_COMMENTS')).toMatchObject({ progress: 1, completed: true });
      expect(by('P_DM_FRIEND')).toMatchObject({ progress: 1, completed: true });
      expect(by('P_DM_VOICE')).toMatchObject({ progress: 1, completed: true });

      // Claimed once each, at the band's coins; again → 200, nothing paid again.
      let paid = 0;
      for (const t of after.tasks) {
        const res = await claim(me, t.code);
        expect(res.status, JSON.stringify(res.body)).toBe(201);
        expectContract(res, 'claimMyTask');
        expect(res.body).toMatchObject({
          paidCoins: t.rewardCoins,
          task: { code: t.code, claimed: true, pooled: true },
        });
        paid += t.rewardCoins;
      }
      expect(paid).toBe(2 + 4 + 3 + 2 + 2 + 2);
      const again = await claim(me, 'P_POST');
      expect(again.status).toBe(200);
      expect(again.body.paidCoins).toBe(4);
      const ledger = await ctx.prisma.walletLedgerEntry.findMany({
        where: { userId: me.id, reason: 'TASK_REWARD' },
      });
      expect(ledger).toHaveLength(6);
      expect(ledger.reduce((s, e) => s + Number(e.delta), 0)).toBe(paid);
      expect((await tasks(me)).dailyEarnedCoins).toBe(paid);
    } finally {
      await fullPool();
    }
  });

  it('progress in lives: minutes watched, audio rooms, comments, hearts, gifts, a new host; the daily cap', async () => {
    await onlyPool([
      'P_WATCH_MINUTES',
      'P_AUDIO_ROOMS',
      'P_LIVE_COMMENTS',
      'P_LIVE_TAPS',
      'P_SEND_GIFT',
      'P_NEW_HOST',
    ]);
    try {
      const me = await signup();
      const hostA = await signup();
      const hostB = await signup();
      await creditIn(ctx.prisma, me.id, 1_000n, 'ADMIN_GRANT', randomUUID());
      const roomA = await startLive(hostA);
      const roomB = await startLive(hostB);
      await ctx.prisma.liveRoom.update({ where: { id: roomB }, data: { mode: 'AUDIO' } });
      const listed = await tasks(me);
      expect(listed.tasks).toHaveLength(6);

      await ctx.prisma.liveRoomAudience.create({
        data: {
          roomId: roomA,
          identity: me.id,
          userId: me.id,
          firstJoinedAt: new Date(),
          watchMs: 5n * 60_000n,
        },
      });
      // 10 s in the audio room is not enough; 20 s is.
      await ctx.prisma.liveRoomAudience.create({
        data: { roomId: roomB, identity: me.id, userId: me.id, firstJoinedAt: new Date(), watchMs: 10_000n },
      });
      expect(await task(me, 'P_AUDIO_ROOMS')).toMatchObject({ progress: 0 });
      await ctx.prisma.liveRoomAudience.update({
        where: { roomId_identity: { roomId: roomB, identity: me.id } },
        data: { watchMs: 20_000n },
      });
      for (let i = 0; i < 3; i++) {
        await ctx.prisma.liveChatMessage.create({
          data: {
            roomId: roomA,
            userId: me.id,
            clientId: randomUUID(),
            text: `hi ${String(i)}`,
            authorRole: 'VIEWER',
          },
        });
      }
      await ctx.prisma.liveRoomTapper.create({
        data: { roomId: roomA, userId: me.id, counted: 20, points: 20n, pointsAt: new Date() },
      });
      await join(roomA, me);
      await sendGift(roomA, me, hostA); // a gift, and hostA's permission is new: also a new host supported

      const now = await tasks(me);
      for (const t of now.tasks) expect(t, t.code).toMatchObject({ completed: true, progress: t.target });
      expect(now.tasks.find((t) => t.code === 'P_WATCH_MINUTES')).toMatchObject({ progress: 5, target: 5 });

      // The cap (20 here): check-in 5, then 4 + 3 + 3 + 2 = 17, then the 5-coin gift task pays 3, and the
      // last task is refused with TASK_DAILY_CAP_REACHED.
      expect((await ctx.http.post('/api/v1/me/check-in').set(auth(me))).status).toBe(201);
      for (const code of ['P_WATCH_MINUTES', 'P_AUDIO_ROOMS', 'P_LIVE_COMMENTS', 'P_LIVE_TAPS']) {
        expect((await claim(me, code)).status).toBe(201);
      }
      const capped = await claim(me, 'P_SEND_GIFT');
      expect(capped.status).toBe(201);
      expect(capped.body.paidCoins).toBe(3);
      const refused = await claim(me, 'P_NEW_HOST');
      expect(refused.status).toBe(409);
      expect(refused.body.error.code).toBe('TASK_DAILY_CAP_REACHED');
      expect((await tasks(me)).dailyEarnedCoins).toBe(CAP);
    } finally {
      await fullPool();
    }
  });

  it('host tasks from stored data: minutes live, gifts received, guests accepted', async () => {
    await onlyPool(['P_HOST_LIVE_30', 'P_HOST_GIFTS', 'P_HOST_GUEST']);
    await ctx.prisma.taskPoolBand.update({ where: { band: 1 }, data: { hostCount: 3 } });
    try {
      const host = await signup();
      const fan = await signup();
      const guest = await signup();
      await creditIn(ctx.prisma, fan.id, 1_000n, 'ADMIN_GRANT', randomUUID());
      const room = await startLive(host);
      const mine = await tasks(host);
      expect(
        mine.tasks
          .filter((t) => t.pooled)
          .map((t) => t.code)
          .sort(),
      ).toEqual(['P_HOST_GIFTS', 'P_HOST_GUEST', 'P_HOST_LIVE_30']);
      // Live for 31 minutes (the room started 31 minutes ago, its last heartbeat now).
      const started = new Date(Date.now() - 31 * 60_000);
      await ctx.prisma.liveRoom.update({
        where: { id: room },
        data: { startedAt: started, lastHeartbeatAt: new Date() },
      });
      await join(room, fan);
      for (let i = 0; i < 3; i++) await sendGift(room, fan, host);
      await ctx.prisma.liveSeatRequest.create({
        data: { roomId: room, userId: guest.id, status: 'ACCEPTED', handledAt: new Date() },
      });
      // A request still pending does not count.
      await ctx.prisma.liveSeatRequest.create({ data: { roomId: room, userId: fan.id } });
      const after = await tasks(host);
      const by = (code: string) => after.tasks.find((t) => t.code === code)!;
      expect(by('P_HOST_LIVE_30').progress).toBe(30);
      expect(by('P_HOST_LIVE_30').completed).toBe(true);
      expect(by('P_HOST_GIFTS')).toMatchObject({ progress: 3, completed: true });
      expect(by('P_HOST_GUEST')).toMatchObject({ progress: 1, completed: true });
      for (const code of ['P_HOST_LIVE_30', 'P_HOST_GIFTS', 'P_HOST_GUEST']) {
        expect((await claim(host, code)).status).toBe(201);
      }
      // The fan (not a host) cannot claim a host task.
      expect((await claim(fan, 'P_HOST_GIFTS')).status).toBe(404);
    } finally {
      await ctx.prisma.taskPoolBand.update({ where: { band: 1 }, data: { hostCount: 2 } });
      await fullPool();
    }
  });

  it("a template changed during the day keeps today's target; the next day is a new list with fresh progress", async () => {
    const me = await signup();
    await onlyPool(['P_FOLLOW', 'P_POST']);
    try {
      await follow(me, friends[2]!);
      const today = await tasks(me);
      expect(today.tasks.find((t) => t.code === 'P_FOLLOW')).toMatchObject({ target: 1, completed: true });
      expect((await claim(me, 'P_FOLLOW')).status).toBe(201);
      // The team raises band 1's follow target: today's list keeps the assigned target.
      await ctx.prisma.taskDefinition.update({
        where: { code: 'P_FOLLOW' },
        data: { bandTargets: [4, 3, 5, 10] },
      });
      expect(await task(me, 'P_FOLLOW')).toMatchObject({ target: 1, claimed: true });

      clock.advance(DAY_MS);
      try {
        const next = await tasks(me);
        expect(next.day).not.toBe(today.day);
        expect(next.dailyEarnedCoins).toBe(0);
        expect(next.tasks.find((t) => t.code === 'P_FOLLOW')).toMatchObject({
          target: 4,
          progress: 0,
          claimed: false,
          claimedCoins: null,
        });
        expect(next.tasks.map((t) => t.code)).toEqual(
          (await expected(me, next.day, 1, false)).map((p) => p.code),
        );
        // Yesterday's follow does not count today.
        expect((await claim(me, 'P_FOLLOW')).body.error.code).toBe('TASK_NOT_COMPLETED');
        expect(await ctx.prisma.taskAssignment.count({ where: { userId: me.id } })).toBe(4);
      } finally {
        clock.reset();
      }
    } finally {
      await ctx.prisma.taskDefinition.update({
        where: { code: 'P_FOLLOW' },
        data: { bandTargets: [1, 3, 5, 10] },
      });
      await fullPool();
    }
  });

  it('no pool configured: only the fixed tasks, nothing assigned', async () => {
    await ctx.prisma.taskDefinition.updateMany({ where: { pool: true }, data: { enabled: false } });
    try {
      const me = await signup();
      const mine = await tasks(me);
      expect(mine.tasks).toEqual([]);
      expect(mine.band).toMatchObject({ band: 1, level: 0 });
      expect(await ctx.prisma.taskAssignment.count({ where: { userId: me.id } })).toBe(0);
    } finally {
      await fullPool();
    }
  });

  it("events: the calendar bar's second line and tone, per language; the tasks banner slot", async () => {
    const me = await signup();
    const now = Date.now();
    const styled = await ctx.prisma.event.create({
      data: {
        titleAr: 'رحلة المجد',
        titleEn: 'Glory trip',
        rulesAr: '-',
        rulesEn: '-',
        startsAt: new Date(now - HOUR_MS),
        endsAt: new Date(now + HOUR_MS),
        metric: 'GIFT_COINS_SENT',
        summaryAr: 'جائزة المركز الأول 5000 عملة',
        summaryEn: 'First place wins 5,000 coins',
        tone: 'TEAL',
      },
    });
    const plain = await ctx.prisma.event.create({
      data: {
        titleAr: 'عادية',
        titleEn: 'Plain',
        rulesAr: '-',
        rulesEn: '-',
        startsAt: new Date(now - HOUR_MS),
        endsAt: new Date(now + HOUR_MS),
        metric: 'NEW_FOLLOWERS',
        summaryAr: 'بالعربية فقط',
      },
    });
    const list = async (lang: string) => {
      const res = await ctx.http
        .get('/api/v1/events?tab=CALENDAR')
        .set(auth(me))
        .set('Accept-Language', lang);
      expect(res.status).toBe(200);
      expectContract(res, 'listEvents');
      return res.body.data as { id: string; summary: string | null; tone: string | null }[];
    };
    const en = await list('en');
    expect(en.find((e) => e.id === styled.id)).toMatchObject({
      summary: 'First place wins 5,000 coins',
      tone: 'TEAL',
    });
    // No fallback to the other language.
    expect(en.find((e) => e.id === plain.id)).toMatchObject({ summary: null, tone: null });
    const ar = await list('ar');
    expect(ar.find((e) => e.id === styled.id)?.summary).toBe('جائزة المركز الأول 5000 عملة');
    expect(ar.find((e) => e.id === plain.id)?.summary).toBe('بالعربية فقط');
    const detail = await ctx.http
      .get(`/api/v1/events/${styled.id}`)
      .set(auth(me))
      .set('Accept-Language', 'en');
    expect(detail.status).toBe(200);
    expectContract(detail, 'getEvent');
    expect(detail.body).toMatchObject({ summary: 'First place wins 5,000 coins', tone: 'TEAL' });
    // The database refuses an unknown tone.
    await expect(
      ctx.prisma.event.update({ where: { id: plain.id }, data: { tone: 'NEON' } }),
    ).rejects.toThrow();

    const banners = await ctx.http.get('/api/v1/home/banners?placement=tasks').set(auth(me));
    expect(banners.status).toBe(200);
    expectContract(banners, 'listHomeBanners');
    expect(banners.body.data).toEqual([]);
  });
});
