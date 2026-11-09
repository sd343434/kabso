/**
 * D325 (owner 2026-11-08 / 11-09; contract v1.101-social, CONVENTIONS §10.127): events v2 «الفعاليات» — one events
 * system. Drafts without dates, publish / unpublish / discard; the launch festival as a draft; exclusive gifts and prize
 * items uploaded inside the event (bought only while it runs; prizes never sold); scoring COINS or MULTIPLIER (×1.2,
 * ×1.5) over the event's gifts or all gifts; several boards with minimums; prizes of every type and duration including
 * free gift pieces; milestones; weekly recurrence with the previous period; the audience and the start notification;
 * the Live home banner; the top 20 with the caller's own place; payout idempotency; D166 events continuing. End to end
 * against PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { EventsService } from '../src/modules/programs/events.service.js';
import { nextPeriodStartIn, payGiftEventIn } from '../src/modules/programs/gift-events.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  SEED_VIP_TIER_SQL,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const HOUR_MS = 3_600_000;
const DAY_MS = 24 * HOUR_MS;

const CONFIG = {
  LIVE_HOSTING_ENABLED: 'true',
  LIVE_HEARTBEAT_STALE_SECONDS: '3600',
  LIVE_GIFT_QUANTITIES: '1,3,5,10',
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
  ADMIN_TOTP_KEY: 'd325-admin-totp-test-key-0123456789-abcdefghijk',
  JWT_ACCESS_TTL_SECONDS: String(90 * 86_400),
  ADMIN_SESSION_IDLE_SECONDS: '86400',
  ADMIN_SESSION_MAX_SECONDS: '604800',
  RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
  RATE_LIMIT_ADMIN_IP: '100000/900',
  RATE_LIMIT_LIVE_GIFT_USER: '10000/60',
  // The sweeper runs only when the test calls it.
  EVENTS_SWEEP_INTERVAL_SECONDS: '0',
};

interface User extends Person {
  readonly username: string;
}

describe('D325 contract coverage', () => {
  it('openapi v1.101-social declares the events v2 operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'publishAdminEvent POST /api/v1/admin/events/{eventId}/publish',
        'unpublishAdminEvent POST /api/v1/admin/events/{eventId}/unpublish',
        'discardAdminEvent POST /api/v1/admin/events/{eventId}/discard',
        'createAdminLaunchFestival POST /api/v1/admin/gift-events/launch-festival',
        'getRunningEvents GET /api/v1/events/running',
        'getEventMilestones GET /api/v1/events/{eventId}/milestones',
      ]),
    );
  });
});

describe('D325 events v2', { timeout: 900_000 }, () => {
  const media = new MemoryLiveMedia();
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let s1: User;
  let s2: User;
  let s3: User;
  let host: User;
  let viewer: User;
  let cpA: User;
  let cpB: User;
  let roomId: string;
  let dbNow: Date;
  let e1: string;
  let e2: string;
  let itemCode: string;
  let itemId: string;
  let prizeKey: string;

  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const user = async (): Promise<User> => {
    const person = await p.signup();
    const profile = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: person.id } });
    return { ...person, username: profile.username };
  };
  const fund = (u: User, coins: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(coins), 'ADMIN_GRANT', randomUUID()));
  const join = async (u: User) => {
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
  /** The test moves the clock by hours and weeks: the live's heartbeat follows it (the room stays live). */
  const fresh = () =>
    withMigrationClient(
      (db) =>
        db.$executeRaw`UPDATE live_rooms SET last_heartbeat_at = ${new Date()} WHERE id = ${roomId}::uuid`,
    );
  const sendRaw = async (from: User, giftCode: string, quantity = 1, source: 'COINS' | 'BAG' = 'COINS') => {
    await fresh();
    return ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode, quantity, recipients: [host.username], source, clientId: randomUUID() });
  };
  const send = async (from: User, giftCode: string, quantity = 1, source: 'COINS' | 'BAG' = 'COINS') => {
    const res = await sendRaw(from, giftCode, quantity, source);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body as { id?: string; giftId?: string };
  };
  const board = async (u: User, id: string, kind?: string, period?: 'previous') => {
    const res = await ctx.http
      .get(`/api/v1/events/${id}/leaderboard`)
      .query({ ...(kind ? { board: kind } : {}), ...(period ? { period } : {}) })
      .set(auth(u))
      .set('Accept-Language', 'en');
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getEventLeaderboard');
    return res.body as {
      final: boolean;
      period: { index: number; previous: boolean } | null;
      data: {
        rank: number;
        user: { id: string };
        score: number;
        qualified: boolean;
        prize: { type: string }[];
      }[];
      me: { rank: number | null; score: number; qualified: boolean };
    };
  };
  const rows = (b: Awaited<ReturnType<typeof board>>) =>
    b.data.map((r) => [r.rank, r.user.id, r.score, r.qualified]);
  const picture = (w: number, h: number, alpha = false) =>
    sharp({
      create: alpha
        ? { width: w, height: h, channels: 4, background: { r: 229, g: 9, b: 20, alpha: 0.5 } }
        : { width: w, height: h, channels: 3, background: { r: 229, g: 9, b: 20 } },
    })
      .png()
      .toBuffer();
  const raw = (path: string, body: Buffer) =>
    ctx.http
      .post(`/api/v1${path}`)
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(body);
  const catalogue = async (u: User) => {
    const res = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(u));
    expect(res.status).toBe(200);
    return (res.body.data as { code: string }[]).map((g) => g.code);
  };
  const stock = async (u: User, code: string) =>
    (
      await ctx.prisma.userGiftStock.findUnique({
        where: { userId_giftCode: { userId: u.id, giftCode: code } },
      })
    )?.quantity ?? 0;
  const sweeper = () => ctx.app.get(EventsService);
  const iso = (ms: number) => new Date(ms).toISOString();
  const draft = (over: Record<string, unknown> = {}) => ({
    status: 'DRAFT',
    titleAr: 'فعالية',
    titleEn: 'Event',
    startsAt: null,
    endsAt: null,
    reason: 'D325 test',
    ...over,
  });

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(CONFIG, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
      { token: OBJECT_STORAGE, value: storage },
    ]);
    await withMigrationClient((db) => db.$executeRawUnsafe(SEED_VIP_TIER_SQL));
    for (const [code, price] of [
      ['v2_rose', 100],
      ['v2_lily', 10],
    ] as const) {
      await ctx.prisma.$transaction((tx) =>
        addGiftIn(tx, code, {
          category: 'POPULAR',
          nameAr: code,
          nameEn: code,
          priceCoins: price,
          assetKey: `gift_${code}`,
          animationKey: null,
          sortOrder: 0,
          badge: 'NONE',
          tagCode: null,
          tagNameAr: null,
          tagNameEn: null,
        }),
      );
    }
    owner = await p.makeAdmin(['OWNER']);
    [s1, s2, s3, host, viewer, cpA, cpB] = (await Promise.all(Array.from({ length: 7 }, () => user()))) as [
      User,
      User,
      User,
      User,
      User,
      User,
      User,
    ];
    await withMigrationClient((db) =>
      db.cpCouple.create({
        data: { userAId: cpA.id, userBId: cpB.id, since: new Date(Date.now() - DAY_MS) },
      }),
    );
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'D325' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    roomId = room.body.id as string;
    for (const u of [s1, s2, s3]) {
      await fund(u, 1_000_000);
      await join(u);
    }
    const [row] = await ctx.prisma.$queryRaw<{ now: Date }[]>`SELECT now() AS now`;
    dbNow = row!.now;
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('a draft needs no dates, is never shown, scored or swept; publish refuses it without dates; discard deletes it', async () => {
    const made = await p.send(owner, 'post', '/admin/gift-events', draft());
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    expectContract(made, 'createAdminGiftEvent');
    expect(made.body.status).toBe('DRAFT');
    const id = made.body.id as string;
    const list = await p.send(owner, 'get', '/admin/events');
    expect(list.status).toBe(200);
    expectContract(list, 'listAdminEvents');
    expect(list.body.data.find((e: { id: string }) => e.id === id)).toMatchObject({
      state: 'DRAFT',
      status: 'DRAFT',
      startsAt: null,
    });
    expect((await ctx.http.get(`/api/v1/events/${id}`).set(auth(viewer))).status).toBe(404);
    const app = await ctx.http.get('/api/v1/events').set(auth(viewer));
    expect(app.body.data.map((e: { id: string }) => e.id)).not.toContain(id);
    const form = await p.send(owner, 'get', `/admin/gift-events/${id}`);
    expectContract(form, 'getAdminGiftEvent');
    expect(form.body).toMatchObject({
      state: 'DRAFT',
      structureLocked: false,
      form: { status: 'DRAFT', startsAt: null },
    });
    const publish = await p.send(owner, 'post', `/admin/events/${id}/publish`, { reason: 'go live' });
    expect(publish.status).toBe(409);
    expect(publish.body.error.message).toMatch(/start date/);
    // A published body without gifts or boards stays a 400 (D303's shape).
    const bad = await p.send(owner, 'put', `/admin/gift-events/${id}`, draft({ status: 'PUBLISHED' }));
    expect(bad.status).toBe(400);
    await sweeper().sweepDetail();
    expect(await ctx.prisma.notification.count({ where: { eventId: id } })).toBe(0);
    const gone = await p.send(owner, 'post', `/admin/events/${id}/discard`, { reason: 'not needed' });
    expect(gone.status, JSON.stringify(gone.body)).toBe(200);
    expectContract(gone, 'discardAdminEvent');
    expect(gone.body).toEqual({ id, status: 'DELETED' });
    expect(await ctx.prisma.event.count({ where: { id } })).toBe(0);
    expect(await ctx.prisma.auditLog.count({ where: { action: 'event.discard', targetId: id } })).toBe(1);
  });

  it('makes «مهرجان انطلاقة Kabso» as a draft: four exclusive gifts ×1 / ×1 / ×1.2 / ×1.5, three boards, milestones', async () => {
    const made = await p.send(owner, 'post', '/admin/gift-events/launch-festival', {
      reason: 'prepare the launch',
    });
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    expectContract(made, 'createAdminLaunchFestival');
    const id = made.body.id as string;
    const gifts = await ctx.prisma.gift.findMany({ where: { eventId: id }, orderBy: { sortOrder: 'asc' } });
    // v1.102-social (D334, owner): neutral placeholder names; «شاشة كاملة» on the 1 000 000 and 3 000 000 gifts.
    expect(gifts.map((g) => [g.nameAr, g.nameEn, g.priceCoins, g.badges.includes('FULLSCREEN')])).toEqual([
      ['هدية المهرجان 1', 'Festival gift 1', 50_000, false],
      ['هدية المهرجان 2', 'Festival gift 2', 250_000, false],
      ['هدية المهرجان 3', 'Festival gift 3', 1_000_000, true],
      ['هدية المهرجان 4', 'Festival gift 4', 3_000_000, true],
    ]);
    const form = await p.send(owner, 'get', `/admin/gift-events/${id}`);
    expectContract(form, 'getAdminGiftEvent');
    expect(form.body.form).toMatchObject({
      status: 'DRAFT',
      startsAt: null,
      endsAt: null,
      titleAr: 'مهرجان انطلاقة Kabso',
      scoring: 'MULTIPLIER',
      countedGifts: 'EVENT_GIFTS',
    });
    expect(form.body.form.gifts.map((g: { pointsPerCoin: number }) => g.pointsPerCoin)).toEqual([
      1, 1, 1.2, 1.5,
    ]);
    expect(form.body.form.boards.map((b: { kind: string }) => b.kind)).toEqual([
      'SENDERS',
      'RECEIVERS',
      'CREATORS',
    ]);
    expect(form.body.form.milestones).toHaveLength(4);
    expect(form.body.ownGifts).toHaveLength(4);
    // Never listed (a draft), and the template is made once.
    expect(await catalogue(viewer)).not.toContain('kabso_festival_gift_4');
    expect(
      (await p.send(owner, 'post', '/admin/gift-events/launch-festival', { reason: 'again' })).status,
    ).toBe(409);
    // At launch: the dates set, then published; a future start lists nothing yet; back to a draft before the start.
    const body = { ...form.body.form, reason: 'set the launch dates' };
    const dated = await p.send(owner, 'put', `/admin/gift-events/${id}`, {
      ...body,
      startsAt: iso(Date.now() + 2 * DAY_MS),
      endsAt: iso(Date.now() + 9 * DAY_MS),
    });
    expect(dated.status, JSON.stringify(dated.body)).toBe(200);
    // A panel reason may be one or two characters.
    const published = await p.send(owner, 'post', `/admin/events/${id}/publish`, { reason: 'go' });
    expect(published.status, JSON.stringify(published.body)).toBe(200);
    expectContract(published, 'publishAdminEvent');
    expect(published.body.status).toBe('PUBLISHED');
    expect(await catalogue(viewer)).not.toContain('kabso_festival_gift_4');
    const back = await p.send(owner, 'post', `/admin/events/${id}/unpublish`, { reason: 'not yet' });
    expect(back.status, JSON.stringify(back.body)).toBe(200);
    expect(back.body.status).toBe('DRAFT');
  });

  it('uploads gifts and prize items inside the event (never sold), then publishes it with its banner', async () => {
    const made = await p.send(owner, 'post', '/admin/gift-events', draft({ titleEn: 'Stars' }));
    expect(made.status).toBe(201);
    e1 = made.body.id as string;
    // Two exclusive gifts with the D207 upload and the gift API, tied to the event.
    for (const code of ['v2_star', 'v2_moon']) {
      const img = await raw(`/admin/gift-uploads?kind=image&code=${code}`, await picture(256, 256));
      expect(img.status, JSON.stringify(img.body)).toBe(201);
      const gift = await p.send(owner, 'post', '/admin/gifts', {
        code,
        category: 'POPULAR',
        nameAr: code,
        nameEn: code,
        priceCoins: 100,
        imageObjectKey: img.body.key,
        badges: [{ code: 'FULLSCREEN' }],
        eventId: e1,
        reason: 'event gift',
      });
      expect(gift.status, JSON.stringify(gift.body)).toBe(201);
      expectContract(gift, 'createAdminGift');
    }
    // A lucky gift cannot be an event gift.
    const img = await raw('/admin/gift-uploads?kind=image&code=v2_bad', await picture(256, 256));
    const bad = await p.send(owner, 'post', '/admin/gifts', {
      code: 'v2_bad',
      category: 'LUCKY',
      nameAr: 'x',
      nameEn: 'x',
      priceCoins: 10,
      imageObjectKey: img.body.key,
      eventId: e1,
      reason: 'bad',
    });
    expect(bad.status).toBe(409);
    expect(await ctx.prisma.gift.count({ where: { eventId: e1 } })).toBe(2);
    // An exclusive frame: the store's art upload, no prices, off and hidden for good.
    const still = await raw('/admin/store/uploads?kind=still', await picture(300, 300, true));
    expect(still.status, JSON.stringify(still.body)).toBe(201);
    const item = await p.send(owner, 'post', '/admin/store/items', {
      kind: 'AVATAR_FRAME',
      nameAr: 'إطار النجوم',
      nameEn: 'Star frame',
      still: still.body.url,
      prices: [],
      eventId: e1,
      reason: 'event prize',
    });
    expect(item.status, JSON.stringify(item.body)).toBe(201);
    expectContract(item, 'createAdminStoreItem');
    expect(item.body).toMatchObject({ enabled: false, eventId: e1 });
    expect(item.body.hiddenAt).not.toBeNull();
    itemCode = item.body.code as string;
    itemId = item.body.id as string;
    const priced = await p.send(owner, 'post', '/admin/store/items', {
      kind: 'AVATAR_FRAME',
      nameAr: 'x',
      nameEn: 'x',
      prices: [{ currency: 'COINS', days: 7, amount: 10 }],
      eventId: e1,
      reason: 'sold?',
    });
    expect(priced.status).toBe(400);
    const storeList = await p.send(owner, 'get', '/admin/store/items');
    expect(storeList.body.data.map((i: { id: string }) => i.id)).not.toContain(itemId);
    const own = await p.send(owner, 'get', `/admin/store/items?eventId=${e1}`);
    expect(own.body.data.map((i: { id: string }) => i.id)).toEqual([itemId]);
    expect(
      (await p.send(owner, 'post', `/admin/store/items/${itemId}/enable`, { reason: 'sell' })).status,
    ).toBe(409);
    expect(
      (await ctx.http.get('/api/v1/store/items').set(auth(viewer))).body.data.map(
        (i: { id: string }) => i.id,
      ),
    ).not.toContain(itemId);
    // A medal, a prize picture and the banner.
    const badgeArt = await raw('/admin/event-uploads?kind=badge', await picture(512, 512, true));
    expect(badgeArt.status, JSON.stringify(badgeArt.body)).toBe(201);
    expect(
      (
        await p.send(owner, 'post', '/admin/event-badges', {
          code: 'v2_star_medal',
          nameAr: 'وسام النجوم',
          nameEn: 'Star medal',
          levels: [{ level: 1, imageKey: badgeArt.body.key }],
          reason: 'event medal',
        })
      ).status,
    ).toBe(201);
    const prize = await raw('/admin/event-uploads?kind=prize', await picture(512, 512));
    expect(prize.status, JSON.stringify(prize.body)).toBe(201);
    expectContract(prize, 'uploadAdminEventMedia');
    prizeKey = prize.body.key as string;
    expect(prizeKey).toMatch(/^media\/events\/prize\//);
    const banner = await raw('/admin/event-uploads?kind=banner', await picture(1500, 300));
    expect(banner.status, JSON.stringify(banner.body)).toBe(201);
    const options = await p.send(owner, 'get', `/admin/event-options?eventId=${e1}`);
    expectContract(options, 'getAdminEventOptions');
    expect(options.body.gifts.filter((g: { eventId: string | null }) => g.eventId === e1)).toHaveLength(2);
    expect(options.body.bagItems.find((b: { code: string }) => b.code === itemCode)).toMatchObject({
      eventId: e1,
    });
    // Other events never offer this one's gifts or items.
    expect(
      (await p.send(owner, 'get', '/admin/event-options')).body.gifts.map((g: { code: string }) => g.code),
    ).not.toContain('v2_star');

    const full = {
      status: 'PUBLISHED',
      titleAr: 'نجوم',
      titleEn: 'Stars',
      rulesAr: 'قواعد',
      rulesEn: 'Rules',
      startsAt: iso(dbNow.getTime() - 10 * 60_000),
      endsAt: iso(dbNow.getTime() + 3 * HOUR_MS),
      timeZone: 'Asia/Riyadh',
      scoring: 'MULTIPLIER',
      countedGifts: 'EVENT_GIFTS',
      bannerMediaId: banner.body.mediaId,
      gifts: [
        { giftCode: 'v2_star', pointsPerCoin: 1.2 },
        { giftCode: 'v2_moon', pointsPerCoin: 1.5 },
      ],
      boards: [
        {
          kind: 'SENDERS',
          minPoints: 200,
          prizes: [
            {
              rankFrom: 1,
              rankTo: 1,
              items: [
                { type: 'COINS', amount: 1000 },
                { type: 'BAG_ITEM', itemCode, days: 30, displayKey: prizeKey },
                { type: 'VIP', tierCode: 'VIP_1', days: 5 },
                { type: 'BADGE', badgeCode: 'v2_star_medal', level: 1, days: null },
                { type: 'GIFT_PIECES', giftCode: 'v2_star', count: 10, displayKey: prizeKey },
              ],
            },
            { rankFrom: 2, rankTo: 3, items: [{ type: 'COINS', amount: 300 }] },
          ],
        },
        {
          kind: 'RECEIVERS',
          minPoints: 0,
          prizes: [
            {
              rankFrom: 1,
              rankTo: 1,
              items: [
                { type: 'CHERRIES', amount: 700 },
                { type: 'GIFT_PIECES', giftCode: 'v2_moon', count: 2 },
              ],
            },
          ],
        },
      ],
      milestones: [
        { board: 'SENDERS', points: 120, prizes: [{ type: 'GIFT_PIECES', giftCode: 'v2_star', count: 1 }] },
        { board: 'SENDERS', points: 1000, prizes: [{ type: 'COINS', amount: 50 }] },
      ],
      reason: 'publish the stars event',
    };
    // Gift pieces only of the event's own gifts.
    const foreign = await p.send(owner, 'put', `/admin/gift-events/${e1}`, {
      ...full,
      milestones: [
        { board: 'SENDERS', points: 5, prizes: [{ type: 'GIFT_PIECES', giftCode: 'v2_rose', count: 1 }] },
      ],
    });
    expect(foreign.status).toBe(409);
    // A multiplier keeps two decimals at most.
    const fine = await p.send(owner, 'put', `/admin/gift-events/${e1}`, {
      ...full,
      gifts: [{ giftCode: 'v2_star', pointsPerCoin: 1.234 }],
    });
    expect(fine.status).toBe(400);
    const saved = await p.send(owner, 'put', `/admin/gift-events/${e1}`, full);
    expect(saved.status, JSON.stringify(saved.body)).toBe(200);
    expectContract(saved, 'updateAdminGiftEvent');
    expect(saved.body.status).toBe('PUBLISHED');
    // The Live home banner opens the event.
    const banners = await ctx.http.get('/api/v1/home/banners').set(auth(viewer));
    expect(banners.status).toBe(200);
    expect(banners.body.data.find((b: { eventId: string | null }) => b.eventId === e1)).toMatchObject({
      link: `/events/${e1}`,
    });
    // While it runs everyone may buy its gifts; the page shows the multipliers.
    expect(await catalogue(viewer)).toEqual(expect.arrayContaining(['v2_star', 'v2_moon']));
    const detail = await ctx.http.get(`/api/v1/events/${e1}`).set(auth(viewer)).set('Accept-Language', 'en');
    expect(detail.status).toBe(200);
    expectContract(detail, 'getEvent');
    expect(
      detail.body.gifts.map((g: Record<string, unknown>) => [
        g.code,
        g.multiplier,
        g.pointsPerCoin,
        g.pointsEach,
        g.exclusive,
        g.fullscreen,
      ]),
    ).toEqual([
      ['v2_star', 1.2, 1, 120, true, true],
      ['v2_moon', 1.5, 1, 150, true, true],
    ]);
    expect(detail.body).toMatchObject({
      recurrence: 'NONE',
      scoring: 'MULTIPLIER',
      period: { index: 0, hasPrevious: false },
    });
    expect(detail.body.milestones.map((m: { points: number }) => m.points)).toEqual([120, 1000]);
    const first = detail.body.boards[0].prizes[0].items as Record<string, unknown>[];
    expect(first.find((i) => i.type === 'GIFT_PIECES')).toMatchObject({ code: 'v2_star', count: 10 });
    expect(first.find((i) => i.type === 'BAG_ITEM')).toMatchObject({ days: 30 });
    expect(String(first.find((i) => i.type === 'BAG_ITEM')!.displayUrl)).toContain(prizeKey);
    const running = await ctx.http.get('/api/v1/events/running').set(auth(viewer));
    expect(running.status).toBe(200);
    expectContract(running, 'getRunningEvents');
    expect(running.body.data.find((e: { id: string }) => e.id === e1)).toMatchObject({
      giftCodes: ['v2_star', 'v2_moon'],
    });
  });

  it('scores ×1.2 and ×1.5 on the event gifts only; a COINS / ALL_GIFTS event counts every gift at its coins', async () => {
    const made = await p.send(owner, 'post', '/admin/gift-events', {
      status: 'PUBLISHED',
      titleAr: 'كل الهدايا',
      titleEn: 'All gifts',
      startsAt: iso(dbNow.getTime() - 10 * 60_000),
      endsAt: iso(dbNow.getTime() + 3 * HOUR_MS),
      scoring: 'COINS',
      countedGifts: 'ALL_GIFTS',
      // Listed with a multiplier, but the coins scoring ignores it.
      gifts: [{ giftCode: 'v2_rose', pointsPerCoin: 3 }],
      boards: [
        {
          kind: 'SENDERS',
          minPoints: 0,
          prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'COINS', amount: 5 }] }],
        },
      ],
      reason: 'all gifts event',
    });
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    e2 = made.body.id as string;
    await send(s1, 'v2_star');
    await send(s1, 'v2_moon');
    await send(s2, 'v2_star');
    await send(s3, 'v2_rose');
    await send(s3, 'v2_lily');
    const senders = await board(viewer, e1, 'SENDERS');
    expect(rows(senders)).toEqual([
      [1, s1.id, 270, true],
      [2, s2.id, 120, false],
    ]);
    const receivers = await board(viewer, e1, 'RECEIVERS');
    expect(rows(receivers)).toEqual([[1, host.id, 390, true]]);
    const all = await board(viewer, e2);
    expect(rows(all)).toEqual([
      [1, s1.id, 200, true],
      [2, s3.id, 110, true],
      [3, s2.id, 100, true],
    ]);
    const mine = await board(s2, e1, 'SENDERS');
    expect(mine.me).toMatchObject({ rank: 2, score: 120, qualified: false });
  });

  it('milestones show the progress and are given once, within a sweep', async () => {
    const before = await ctx.http
      .get(`/api/v1/events/${e1}/milestones`)
      .set(auth(s2))
      .set('Accept-Language', 'ar');
    expect(before.status).toBe(200);
    expectContract(before, 'getEventMilestones');
    expect(
      before.body.data.map((m: Record<string, unknown>) => [m.points, m.score, m.reached, m.granted]),
    ).toEqual([
      [120, 120, true, false],
      [1000, 120, false, false],
    ]);
    const r1 = await sweeper().sweepDetail();
    expect(r1.milestones).toBe(2); // s1 and s2 reached 120
    expect((await sweeper().sweepDetail()).milestones).toBe(0);
    expect(await stock(s2, 'v2_star')).toBe(1);
    expect(await stock(s1, 'v2_star')).toBe(1);
    const after = await ctx.http.get(`/api/v1/events/${e1}/milestones`).set(auth(s2));
    expect(after.body.data[0]).toMatchObject({ reached: true, granted: true });
    expect(
      await ctx.prisma.notification.count({ where: { recipientId: s2.id, type: 'EVENT_PRIZE_WON' } }),
    ).toBe(1);
  });

  it('pays every prize type with its duration at the end, once; the exclusive gift is then only sent from the bag', async () => {
    p.advance(4 * HOUR_MS);
    const r = await sweeper().sweepDetail();
    expect(r.frozen).toBe(2);
    expect(r.paid).toBe(2);
    const again = await sweeper().sweepDetail();
    expect([again.frozen, again.paid, again.milestones]).toEqual([0, 0, 0]);
    const now = new Date();
    const days = (d: Date | null) => Math.round(((d?.getTime() ?? 0) - now.getTime()) / DAY_MS);
    // s1 — SENDERS #1: coins, the exclusive frame for 30 days, VIP 5 days, the medal for good, 10 gift pieces.
    const coins = await ctx.prisma.walletLedgerEntry.findMany({
      where: { userId: s1.id, reason: 'EVENT_PRIZE' },
    });
    expect(coins.map((c) => Number(c.delta)).sort((a, b) => a - b)).toEqual([5, 1000]); // e2 #1 and e1 #1
    const frame = await ctx.prisma.userBagItem.findUniqueOrThrow({
      where: { userId_itemCode: { userId: s1.id, itemCode } },
    });
    expect([frame.source, days(frame.expiresAt)]).toEqual(['EVENT', 30]);
    const vip = await ctx.prisma.vipMembership.findUniqueOrThrow({ where: { userId: s1.id } });
    expect(days(vip.expiresAt)).toBe(5);
    const medal = await ctx.prisma.userEventBadge.findUniqueOrThrow({
      where: { userId_badgeCode: { userId: s1.id, badgeCode: 'v2_star_medal' } },
    });
    expect(medal.expiresAt).toBeNull();
    expect(await stock(s1, 'v2_star')).toBe(11); // 10 won + 1 milestone
    // s2 is below the board's minimum: no prize (only the milestone).
    expect(
      await ctx.prisma.walletLedgerEntry.count({ where: { userId: s2.id, reason: 'EVENT_PRIZE' } }),
    ).toBe(0);
    // host — RECEIVERS #1: cherries and 2 pieces of the moon gift.
    const cherries = await ctx.prisma.cherryLedgerEntry.findMany({
      where: { userId: host.id, reason: 'EVENT_PRIZE' },
    });
    expect(cherries.map((c) => Number(c.delta))).toEqual([700]);
    expect(await stock(host, 'v2_moon')).toBe(2);
    // Idempotent: paying again gives nothing more.
    const payouts = await ctx.prisma.eventPrizePayout.count();
    const e = await ctx.prisma.event.findUniqueOrThrow({ where: { id: e1 } });
    await ctx.prisma.$transaction((tx) => payGiftEventIn(tx, e, new Date()));
    expect(await ctx.prisma.eventPrizePayout.count()).toBe(payouts);
    expect(await stock(s1, 'v2_star')).toBe(11);
    expect((await p.send(owner, 'post', `/admin/events/${e1}/hold`, { reason: 'late' })).status).toBe(409);
    // The results are frozen (the D303 rule: no edit once ended).
    expect(rows(await board(viewer, e1, 'SENDERS'))).toEqual([
      [1, s1.id, 270, true],
      [2, s2.id, 120, false],
    ]);
    // After the event: not listed, not bought; the pieces are sent from the bag and score nowhere.
    expect(await catalogue(viewer)).not.toContain('v2_star');
    const bought = await sendRaw(s3, 'v2_star');
    expect(bought.status).toBe(409);
    expect(bought.body.error.code).toBe('GIFT_UNAVAILABLE');
    await send(s1, 'v2_star', 3, 'BAG');
    expect(await stock(s1, 'v2_star')).toBe(8);
    const bag = await ctx.http.get('/api/v1/me/gifts/bag').set(auth(s1));
    expect(bag.body.data.find((g: { code: string }) => g.code === 'v2_star')).toMatchObject({ quantity: 8 });
    const results = await p.send(owner, 'get', `/admin/gift-events/${e1}`);
    expect(results.body.state).toBe('PAID');
    expect(results.body.periods).toHaveLength(1);
    expect(results.body.milestoneGrants).toBe(2);
  });

  it('a weekly event restarts its boards each week; the previous week stays readable and is paid on its own', async () => {
    const start = dbNow.getTime() - 10 * 60_000;
    const made = await p.send(owner, 'post', '/admin/gift-events', {
      status: 'PUBLISHED',
      titleAr: 'نجم الأسبوع',
      titleEn: 'Weekly star',
      startsAt: iso(start),
      endsAt: null,
      permanent: true,
      recurrence: 'WEEKLY',
      timeZone: 'UTC',
      gifts: [{ giftCode: 'v2_rose', pointsPerCoin: 1 }],
      boards: [
        {
          kind: 'SENDERS',
          minPoints: 0,
          prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'COINS', amount: 10 }] }],
        },
      ],
      reason: 'weekly',
    });
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    const id = made.body.id as string;
    // A permanent one-off event and a too-short recurring one are refused.
    const short = await p.send(owner, 'post', '/admin/gift-events', {
      status: 'PUBLISHED',
      titleAr: 'x',
      titleEn: 'x',
      startsAt: iso(start),
      endsAt: iso(start + 3 * DAY_MS),
      recurrence: 'WEEKLY',
      gifts: [{ giftCode: 'v2_rose' }],
      boards: [{ kind: 'SENDERS' }],
      reason: 'short',
    });
    expect(short.status).toBe(409);
    await send(s2, 'v2_rose', 3); // week 0: s2 300 (and s3's earlier rose, 100)
    const week0 = await board(viewer, id);
    expect(week0.period).toMatchObject({ index: 0, previous: false });
    const w0 = rows(week0);
    expect(w0[0]).toEqual([1, s2.id, 300, true]);
    // A week later the period is frozen and paid; the boards start again from 0.
    p.advance(7 * DAY_MS);
    // A panel session lasts at most 7 days: sign in again.
    owner = await p.makeAdmin(['OWNER']);
    const r = await sweeper().sweepDetail();
    expect(r.rolled).toBe(1);
    const e = await ctx.prisma.event.findUniqueOrThrow({ where: { id } });
    expect(e.period).toBe(1);
    expect(e.frozenAt).toBeNull();
    expect(e.periodStartsAt!.getTime()).toBe(start + 7 * DAY_MS);
    expect(e.periodEndsAt!.getTime()).toBe(start + 14 * DAY_MS);
    expect(
      await ctx.prisma.walletLedgerEntry.count({
        where: { userId: s2.id, reason: 'EVENT_PRIZE', delta: 10n },
      }),
    ).toBe(1);
    expect(rows(await board(viewer, id))).toEqual([]);
    // Week 1's sends (their stored time moved into week 1).
    const sent = await send(s1, 'v2_rose', 1);
    const giftId = (sent.giftId ?? sent.id)!;
    await withMigrationClient(
      (db) =>
        db.$executeRaw`UPDATE live_gifts SET created_at = ${new Date(start + 7 * DAY_MS + HOUR_MS)} WHERE id = ${giftId}::uuid`,
    );
    const week1 = await board(viewer, id);
    expect(week1.period).toMatchObject({ index: 1, previous: false });
    expect(rows(week1)).toEqual([[1, s1.id, 100, true]]);
    const previous = await board(viewer, id, undefined, 'previous');
    expect(previous.final).toBe(true);
    expect(previous.period).toMatchObject({ index: 0, previous: true });
    expect(rows(previous)[0]).toEqual([1, s2.id, 300, true]);
    const detail = await ctx.http.get(`/api/v1/events/${id}`).set(auth(viewer));
    expect(detail.body.period).toMatchObject({ index: 1, hasPrevious: true });
    // Rolling again in the same week does nothing; a D166 event takes no period.
    expect((await sweeper().sweepDetail()).rolled).toBe(0);
    // A month after the 31st is the end of the next month (calendar months, in the event's zone).
    const next = await ctx.prisma.$transaction((tx) =>
      nextPeriodStartIn(tx, 'MONTHLY', new Date('2027-01-31T10:00:00Z'), 'UTC'),
    );
    expect(next.toISOString()).toBe('2027-02-28T10:00:00.000Z');
  });

  it('an audience event is shown and announced to its audience only, once', async () => {
    const made = await p.send(owner, 'post', '/admin/gift-events', {
      status: 'PUBLISHED',
      titleAr: 'ليلة الثنائي',
      titleEn: 'CP night',
      startsAt: iso(Date.now() - 60_000),
      endsAt: iso(Date.now() + DAY_MS),
      audience: 'CP',
      gifts: [{ giftCode: 'v2_rose' }],
      boards: [{ kind: 'CP' }],
      reason: 'cp night',
    });
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    const id = made.body.id as string;
    const r = await sweeper().sweepDetail();
    expect(r.started).toBeGreaterThanOrEqual(1);
    const notes = await ctx.prisma.notification.findMany({ where: { eventId: id, type: 'EVENT_STARTED' } });
    expect(notes.map((n) => n.recipientId).sort()).toEqual([cpA.id, cpB.id].sort());
    await sweeper().sweepDetail();
    expect(await ctx.prisma.notification.count({ where: { eventId: id, type: 'EVENT_STARTED' } })).toBe(2);
    const inbox = await ctx.http.get('/api/v1/notifications').set(auth(cpA));
    expect(inbox.status).toBe(200);
    expectContract(inbox, 'listNotifications');
    expect(inbox.body.data.find((n: { type: string }) => n.type === 'EVENT_STARTED')).toMatchObject({
      target: { type: 'EVENT', id },
    });
    const forCp = await ctx.http.get('/api/v1/events').set(auth(cpA));
    expect(forCp.body.data.map((e: { id: string }) => e.id)).toContain(id);
    expectContract(forCp, 'listEvents');
    const forViewer = await ctx.http.get('/api/v1/events').set(auth(viewer));
    expect(forViewer.body.data.map((e: { id: string }) => e.id)).not.toContain(id);
    expect(
      (await ctx.http.get('/api/v1/events/running').set(auth(viewer))).body.data.map(
        (e: { id: string }) => e.id,
      ),
    ).not.toContain(id);
    // An EVERYONE event notifies every active account once (the weekly one above, for one).
    expect(
      await ctx.prisma.notification.count({ where: { recipientId: viewer.id, type: 'EVENT_STARTED' } }),
    ).toBeGreaterThan(0);
  });

  it('a gift event board shows its top 20 and the caller below them', async () => {
    const made = await p.send(owner, 'post', '/admin/gift-events', {
      status: 'PUBLISHED',
      titleAr: 'عشرون',
      titleEn: 'Twenty',
      startsAt: iso(dbNow.getTime() - 10 * 60_000),
      endsAt: iso(Date.now() + DAY_MS),
      scoring: 'COINS',
      gifts: [{ giftCode: 'v2_lily' }],
      boards: [{ kind: 'SENDERS' }],
      reason: 'top 20',
    });
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    const id = made.body.id as string;
    const many = await Promise.all(Array.from({ length: 21 }, () => user()));
    for (const [i, u] of many.entries()) {
      await fund(u, 10_000);
      await join(u);
      await send(u, 'v2_lily', i === 20 ? 5 : 10); // the last sends least (still above s3's one lily)
    }
    const b = await board(many[20]!, id);
    expect(b.data).toHaveLength(20);
    expect(b.me).toMatchObject({ rank: 21, score: 50 });
  });

  it('D166 events go on as before (published, frozen and paid; their period recorded)', async () => {
    const made = await p.send(owner, 'post', '/admin/events', {
      titleAr: 'قديم',
      titleEn: 'Old',
      startsAt: iso(dbNow.getTime() - 10 * 60_000),
      endsAt: iso(Date.now() + HOUR_MS),
      metric: 'GIFT_COINS_SENT',
      prizes: '1:77',
      reason: 'old style',
    });
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    const id = made.body.id as string;
    expect((await ctx.prisma.event.findUniqueOrThrow({ where: { id } })).status).toBe('PUBLISHED');
    const live = await board(viewer, id);
    expect(live.data.length).toBeGreaterThan(0);
    expect(
      (await ctx.http.get(`/api/v1/events/${id}/leaderboard?period=previous`).set(auth(viewer))).status,
    ).toBe(400);
    p.advance(2 * HOUR_MS);
    await sweeper().sweepDetail();
    const e = await ctx.prisma.event.findUniqueOrThrow({ where: { id } });
    expect(e.frozenAt).not.toBeNull();
    expect(await ctx.prisma.eventPeriod.count({ where: { eventId: id } })).toBe(1);
  });
});
