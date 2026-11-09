/**
 * D303 (owner 2026-11-07; contract v1.97-social, CONVENTIONS §10.114): gift events «فعاليات الهدايا» — an event of its
 * own gifts with typed boards (SENDERS, RECEIVERS, CREATORS, AGENCIES, CP), qualification minimums, prize bundles of
 * coins / cherries / bag items / VIP for N days, paid automatically at the end unless held, once per result and winner;
 * created from the panel and from the app's staff tools (`events.manage`); and animated / video promo banners that can
 * open an event. End to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { reverseGiftCherriesIn, taskCherryLockIn } from '../src/modules/economy/cherry-ledger.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { EventsService } from '../src/modules/programs/events.service.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { mp4 } from './helpers/mp4.js';
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
  ADMIN_TOTP_KEY: 'd303-admin-totp-test-key-0123456789-abcdefghijk',
  JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
  ADMIN_SESSION_IDLE_SECONDS: '86400',
  ADMIN_SESSION_MAX_SECONDS: '604800',
  RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
  RATE_LIMIT_ADMIN_IP: '100000/900',
  // The sweeper runs only when the test calls it.
  EVENTS_SWEEP_INTERVAL_SECONDS: '0',
};

interface User extends Person {
  readonly username: string;
}

describe('D303 contract coverage', () => {
  it('openapi v1.97-social declares the gift events and the banner video upload', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getAdminEventOptions GET /api/v1/admin/event-options',
        'createAdminGiftEvent POST /api/v1/admin/gift-events',
        'getAdminGiftEvent GET /api/v1/admin/gift-events/{eventId}',
        'updateAdminGiftEvent PUT /api/v1/admin/gift-events/{eventId}',
        'uploadAdminBannerVideo POST /api/v1/admin/banner-video-uploads',
        'listStaffEvents GET /api/v1/staff/events',
        'getStaffEventOptions GET /api/v1/staff/event-options',
        'createStaffGiftEvent POST /api/v1/staff/gift-events',
        'getStaffGiftEvent GET /api/v1/staff/gift-events/{eventId}',
        'updateStaffGiftEvent PUT /api/v1/staff/gift-events/{eventId}',
        'changeStaffEvent POST /api/v1/staff/events/{eventId}/{command}',
      ]),
    );
  });
});

describe('D303 gift events', { timeout: 600_000 }, () => {
  const media = new MemoryLiveMedia();
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let moderator: Admin;
  let sender1: User;
  let sender2: User;
  let host: User;
  let agencyOwner: User;
  let creator: User;
  let partnerA: User;
  let partnerB: User;
  let viewer: User;
  let agencyId: string;
  let eventId: string;
  let dbNow: Date;
  let art: Record<string, string> = {};

  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const user = async (): Promise<User> => {
    const person = await p.signup();
    const profile = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: person.id } });
    return { ...person, username: profile.username };
  };
  const fund = (u: User, coins: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(coins), 'ADMIN_GRANT', randomUUID()));
  const startLive = async (h: User, source: 'ADMIN' | 'CREATOR' = 'ADMIN') => {
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'D303' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    return room.body.id as string;
  };
  const join = async (roomId: string, u: User) => {
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
  const send = async (roomId: string, from: User, to: User, giftCode: string, quantity = 1) => {
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode, quantity, recipients: [to.username], source: 'COINS', clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body as { id?: string; giftId?: string };
  };
  const board = async (u: User, kind?: string, lang = 'en') => {
    const res = await ctx.http
      .get(`/api/v1/events/${eventId}/leaderboard`)
      .query(kind ? { board: kind } : {})
      .set(auth(u))
      .set('Accept-Language', lang);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getEventLeaderboard');
    return res.body as {
      board: string;
      final: boolean;
      minPoints: number;
      data: {
        rank: number;
        user: { id: string };
        partner?: { id: string };
        agency?: { id: string; name: string | null };
        score: number;
        qualified: boolean;
        prizeCoins: number;
        prize: {
          type: string;
          amount: number | null;
          days: number | null;
          code: string | null;
          name: string | null;
        }[];
      }[];
      me: {
        rank: number | null;
        score: number;
        qualified: boolean;
        pointsToQualify: number;
        prizeCoins: number;
      };
    };
  };
  const rows = (b: Awaited<ReturnType<typeof board>>) =>
    b.data.map((r) => [r.rank, r.user.id, r.score, r.qualified]);
  const eventUpload = (kind: string, bytes: Buffer, a: { cookie: string; csrf: string } = owner) =>
    ctx.http
      .post('/api/v1/admin/event-uploads')
      .query({ kind })
      .set('Cookie', a.cookie)
      .set('X-CSRF-Token', a.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(bytes);
  const picture = (w: number, h: number, alpha = false) =>
    sharp({
      create: alpha
        ? { width: w, height: h, channels: 4, background: { r: 229, g: 9, b: 20, alpha: 0.5 } }
        : { width: w, height: h, channels: 3, background: { r: 229, g: 9, b: 20 } },
    })
      .png()
      .toBuffer();

  const bundle = (coins: number) => [
    { type: 'COINS', amount: coins },
    { type: 'BAG_ITEM', itemCode: 'd303_frame', days: 7 },
    // Owner (follow-up): a permanent «دائم» item.
    { type: 'BAG_ITEM', itemCode: 'd303_car', days: null },
    { type: 'VIP', tierCode: 'VIP_1', days: 5 },
    { type: 'BADGE', badgeCode: 'gift_king', level: 3, days: 4 },
  ];
  const eventBody = (over: Record<string, unknown> = {}) => ({
    titleAr: 'ملك الهدايا',
    titleEn: 'Gift King',
    rulesAr: 'النقاط من هدايا الفعالية فقط',
    rulesEn: 'Points only from the event gifts',
    startsAt: new Date(dbNow.getTime() - 10 * 60_000).toISOString(),
    endsAt: new Date(dbNow.getTime() + 3 * HOUR_MS).toISOString(),
    timeZone: 'Asia/Riyadh',
    gifts: [
      { giftCode: 'd303_rose', pointsPerCoin: 2 },
      { giftCode: 'd303_crown', pointsPerCoin: 1, pointsPerGift: 50 },
    ],
    boards: [
      {
        kind: 'SENDERS',
        minPoints: 100,
        prizes: [
          { rankFrom: 1, rankTo: 1, items: bundle(1000) },
          { rankFrom: 2, rankTo: 3, items: [{ type: 'COINS', amount: 300 }] },
        ],
      },
      {
        kind: 'RECEIVERS',
        minPoints: 0,
        prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'CHERRIES', amount: 700 }] }],
      },
      {
        kind: 'CREATORS',
        minPoints: 0,
        prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'CHERRIES', amount: 900 }] }],
      },
      {
        kind: 'AGENCIES',
        minPoints: 0,
        prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'COINS', amount: 600 }] }],
      },
      {
        kind: 'CP',
        minPoints: 10,
        prizes: [
          {
            rankFrom: 1,
            rankTo: 1,
            items: [
              { type: 'BAG_ITEM', itemCode: 'd303_frame', days: null },
              { type: 'CP_MONEY', cherries: 400, coins: 250 },
            ],
          },
        ],
      },
    ],
    reason: 'D303 test event',
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
      ['d303_rose', 10],
      ['d303_crown', 100],
      ['d303_other', 10],
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
    await withMigrationClient(async (db) => {
      await db.bagItem.createMany({
        data: [
          {
            code: 'd303_frame',
            category: 'AVATAR_FRAME',
            nameAr: 'إطار',
            nameEn: 'Frame',
            assetKey: 'frame_d303',
            sortOrder: 900,
          },
          {
            code: 'd303_car',
            category: 'ENTRY_EFFECT',
            nameAr: 'مركبة',
            nameEn: 'Car',
            assetKey: 'car_d303',
            sortOrder: 901,
          },
        ],
        skipDuplicates: true,
      });
    });
    owner = await p.makeAdmin(['OWNER']);
    moderator = await p.makeAdmin(['MODERATION']);
    const people = await Promise.all(Array.from({ length: 8 }, () => user()));
    [sender1, sender2, host, agencyOwner, creator, partnerA, partnerB, viewer] = people as [
      User,
      User,
      User,
      User,
      User,
      User,
      User,
      User,
    ];
    const [row] = await ctx.prisma.$queryRaw<{ now: Date }[]>`SELECT now() AS now`;
    dbNow = row!.now;
  });
  afterAll(async () => {
    vi.useRealTimers();
    await withMigrationClient(async (db) => {
      await db.homeBanner.deleteMany();
      await db.event.deleteMany();
    });
    await ctx?.close();
  });

  it('uploads the event art against the published specs; refuses what is outside them; makes a badge', async () => {
    const specs = (await p.send(owner, 'get', '/admin/event-options')).body.specs as {
      kind: string;
      width: number | null;
    }[];
    expect(specs.map((x) => [x.kind, x.width])).toEqual([
      ['banner', 1500],
      ['banner_video', 1500],
      ['background', 1080],
      ['background_video', 1080],
      ['title', 1080],
      ['overlay', null],
      ['badge', 512],
      // v1.101-social (D325): a prize's display picture.
      ['prize', 512],
    ]);
    // Wrong shape, no transparency, too long a video, not an overlay, another role.
    const wrong = await eventUpload('banner', await picture(1500, 500));
    expect(wrong.status).toBe(409);
    expect(wrong.body.error.details[0]).toEqual({ field: 'file', issue: 'event_media_size' });
    expect(wrong.body.error.message).toContain('1500 × 300');
    const opaque = await eventUpload('badge', await picture(512, 512));
    expect(opaque.body.error.details[0].issue).toBe('event_media_transparency');
    const long = await eventUpload(
      'background_video',
      mp4({ durationMs: 16_000, width: 1080, height: 1920 }),
    );
    expect(long.body.error.details[0].issue).toBe('event_media_duration');
    const notLottie = await eventUpload('overlay', Buffer.from('{"nope":1}'));
    expect(notLottie.body.error.details[0].issue).toBe('event_media_format');
    expect((await eventUpload('badge', await picture(512, 512, true), moderator)).status).toBe(403);
    // Within the specs.
    const banner = await eventUpload('banner', await picture(3000, 600));
    expect(banner.status, JSON.stringify(banner.body)).toBe(201);
    expectContract(banner, 'uploadAdminEventMedia');
    expect(banner.body).toMatchObject({ kind: 'banner', width: 1500, height: 300 });
    const bg = await eventUpload('background', await picture(1080, 1920));
    expect(bg.status).toBe(201);
    expect(bg.body.key).toMatch(/^media\/events\/bg\/[0-9a-f-]{36}\.webp$/);
    const bgVideo = await eventUpload(
      'background_video',
      mp4({ durationMs: 8_000, width: 1080, height: 1920 }),
    );
    expect(bgVideo.status, JSON.stringify(bgVideo.body)).toBe(201);
    const title = await eventUpload('title', await picture(1080, 480, true));
    expect(title.status).toBe(201);
    const lottie = { v: '5.7.4', fr: 30, ip: 0, op: 90, w: 512, h: 512, layers: [] };
    const overlay = await eventUpload('overlay', Buffer.from(JSON.stringify(lottie)));
    expect(overlay.status, JSON.stringify(overlay.body)).toBe(201);
    expect(overlay.body).toMatchObject({ durationMs: 3000 });
    art = {
      backgroundKey: bgVideo.body.key as string,
      backgroundPosterKey: bg.body.key as string,
      titleKey: title.body.key as string,
      overlayKey: overlay.body.key as string,
    };
    const level1 = await eventUpload('badge', await picture(512, 512, true));
    const level3 = await eventUpload('badge', await picture(1024, 1024, true));
    expect([level1.status, level3.status]).toEqual([201, 201]);
    const badge = await p.send(owner, 'post', '/admin/event-badges', {
      code: 'gift_king',
      nameAr: 'ملك الهدايا',
      nameEn: 'Gift King',
      levels: [
        { level: 1, imageKey: level1.body.key },
        { level: 3, imageKey: level3.body.key },
      ],
      reason: 'the event badge',
    });
    expect(badge.status, JSON.stringify(badge.body)).toBe(201);
    expectContract(badge, 'createAdminEventBadge');
    const missing = await p.send(owner, 'post', '/admin/event-badges', {
      code: 'x_y',
      nameAr: 'س',
      nameEn: 'x',
      levels: [{ level: 1, imageKey: 'media/events/badge/00000000-0000-0000-0000-000000000000.webp' }],
      reason: 'missing',
    });
    expect(missing.status).toBe(409);
  });

  it('creates from the panel and from the app with the same validation and the events.manage capability', async () => {
    // Shape → 400; a rule → 409; another role → 403 (panel and app).
    expect((await p.send(owner, 'post', '/admin/gift-events', { ...eventBody(), gifts: [] })).status).toBe(
      400,
    );
    const overlap = await p.send(
      owner,
      'post',
      '/admin/gift-events',
      eventBody({
        boards: [
          {
            kind: 'SENDERS',
            prizes: [
              { rankFrom: 1, rankTo: 3, items: [{ type: 'COINS', amount: 1 }] },
              { rankFrom: 3, rankTo: 5, items: [{ type: 'COINS', amount: 1 }] },
            ],
          },
        ],
      }),
    );
    expect(overlap.status, JSON.stringify(overlap.body)).toBe(409);
    expect(overlap.body.error.code).toBe('ADMIN_ACTION_REFUSED');
    const unknown = await p.send(
      owner,
      'post',
      '/admin/gift-events',
      eventBody({ gifts: [{ giftCode: 'nope_gift' }] }),
    );
    expect(unknown.status).toBe(409);
    const badZone = await p.send(
      owner,
      'post',
      '/admin/gift-events',
      eventBody({ timeZone: 'Mars/Olympus' }),
    );
    expect(badZone.status).toBe(409);
    const badItem = await p.send(
      owner,
      'post',
      '/admin/gift-events',
      eventBody({
        boards: [
          {
            kind: 'SENDERS',
            prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'BAG_ITEM', itemCode: 'nope', days: 1 }] }],
          },
        ],
      }),
    );
    expect(badItem.status).toBe(409);
    expect((await p.send(moderator, 'post', '/admin/gift-events', eventBody())).status).toBe(403);
    // The board's money (owner): supporters coins, hosts cherries, CP the two-amount line.
    const cherriesToSupporters = await p.send(
      owner,
      'post',
      '/admin/gift-events',
      eventBody({
        boards: [
          { kind: 'SENDERS', prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'CHERRIES', amount: 5 }] }] },
        ],
      }),
    );
    expect(cherriesToSupporters.status).toBe(409);
    expect(cherriesToSupporters.body.error.message).toContain('SENDERS');
    const coinsToHosts = await p.send(
      owner,
      'post',
      '/admin/gift-events',
      eventBody({
        boards: [
          { kind: 'RECEIVERS', prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'COINS', amount: 5 }] }] },
        ],
      }),
    );
    expect(coinsToHosts.status).toBe(409);
    const cpZero = await p.send(
      owner,
      'post',
      '/admin/gift-events',
      eventBody({
        boards: [
          {
            kind: 'CP',
            prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'CP_MONEY', cherries: 0, coins: 0 }] }],
          },
        ],
      }),
    );
    expect(cpZero.status).toBe(400);
    const cpCoins = await p.send(
      owner,
      'post',
      '/admin/gift-events',
      eventBody({
        boards: [{ kind: 'CP', prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'COINS', amount: 5 }] }] }],
      }),
    );
    expect(cpCoins.status).toBe(409);
    expect((await p.send(moderator, 'get', '/admin/event-options')).status).toBe(403);

    // The app: a moderator is refused, the owner creates (audited via app).
    expect(
      (await ctx.http.post('/api/v1/staff/gift-events').set(auth(moderator)).send(eventBody())).status,
    ).toBe(403);
    expect((await ctx.http.get('/api/v1/staff/events').set(auth(viewer))).status).toBe(403);
    const options = await ctx.http.get('/api/v1/staff/event-options').set(auth(owner));
    expect(options.status).toBe(200);
    expectContract(options, 'getStaffEventOptions');
    expect(options.body.boardKinds).toEqual(['SENDERS', 'RECEIVERS', 'CREATORS', 'AGENCIES', 'CP']);
    const appMade = await ctx.http
      .post('/api/v1/staff/gift-events')
      .set(auth(owner))
      .send(eventBody({ titleEn: 'From the app' }));
    expect(appMade.status, JSON.stringify(appMade.body)).toBe(201);
    expectContract(appMade, 'createStaffGiftEvent');
    const appAudit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'event.create', targetId: appMade.body.id as string },
    });
    expect(appAudit.metadata).toMatchObject({ via: 'app', metric: 'EVENT_GIFTS' });
    // The app's event is not used further: removed (cascade) so it does not pay.
    await withMigrationClient((db) => db.event.delete({ where: { id: appMade.body.id as string } }));

    // A video background without its poster is refused; with the uploaded art it is accepted.
    const noPoster = await p.send(
      owner,
      'post',
      '/admin/gift-events',
      eventBody({ backgroundKey: art.backgroundKey }),
    );
    expect(noPoster.status).toBe(409);
    const made = await p.send(owner, 'post', '/admin/gift-events', eventBody(art));
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    expectContract(made, 'createAdminGiftEvent');
    eventId = made.body.id as string;
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'event.create', targetId: eventId },
    });
    expect(audit.metadata).toMatchObject({ via: 'panel', reason: 'D303 test event' });

    const list = await ctx.http.get('/api/v1/staff/events').set(auth(owner));
    expect(list.status).toBe(200);
    expectContract(list, 'listStaffEvents');
    expect(list.body.data.find((e: { id: string }) => e.id === eventId)).toMatchObject({
      state: 'RUNNING',
      editable: true,
    });
  });

  it('the event page lists the gifts with their points, the boards with their prize bundles and the time zone', async () => {
    const res = await ctx.http
      .get(`/api/v1/events/${eventId}`)
      .set(auth(viewer))
      .set('Accept-Language', 'ar');
    expect(res.status).toBe(200);
    expectContract(res, 'getEvent');
    expect(res.body.art.background).toMatchObject({ kind: 'VIDEO' });
    expect(res.body.art.background.posterUrl).toMatch(/\/bg\/.*\.webp$/);
    expect(res.body.art.overlay).toMatchObject({ format: 'LOTTIE' });
    expect(res.body.art.titleUrl).toMatch(/\/title\//);
    expect(res.body).toMatchObject({
      metric: 'EVENT_GIFTS',
      title: 'ملك الهدايا',
      timeZone: 'Asia/Riyadh',
      prizes: [],
    });
    expect(res.body.gifts).toEqual([
      expect.objectContaining({
        code: 'd303_rose',
        priceCoins: 10,
        pointsPerCoin: 2,
        pointsPerGift: 0,
        pointsEach: 20,
      }),
      expect.objectContaining({
        code: 'd303_crown',
        priceCoins: 100,
        pointsPerCoin: 1,
        pointsPerGift: 50,
        pointsEach: 150,
      }),
    ]);
    expect(res.body.boards.map((b: { kind: string }) => b.kind)).toEqual([
      'SENDERS',
      'RECEIVERS',
      'CREATORS',
      'AGENCIES',
      'CP',
    ]);
    expect(res.body.boards[0].prizes[0].items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          type: 'BAG_ITEM',
          code: 'd303_frame',
          days: 7,
          name: 'إطار',
          category: 'AVATAR_FRAME',
        }),
        expect.objectContaining({ type: 'VIP', code: 'VIP_1', days: 5, category: 'VIP', color: '#2E8B3D' }),
      ]),
    );
  });

  it('scores only the event gifts in the window, on every board, without reversed sends or a creator on the hosts board', async () => {
    // The agency of `host`; a creator member; a CP couple.
    const agency = await ctx.prisma.agency.create({
      data: {
        ownerUserId: agencyOwner.id,
        inviteCode: `D${randomUUID()
          .replace(/[^2-9]/g, '')
          .padEnd(7, '2')
          .slice(0, 7)}`,
        name: 'Kabso Stars',
        evaluateFrom: new Date(Date.UTC(dbNow.getUTCFullYear(), dbNow.getUTCMonth(), 1)),
      },
    });
    agencyId = agency.id;
    await ctx.prisma.agencyHost.create({
      data: {
        agencyId,
        hostUserId: host.id,
        commissionEligible: true,
        activatedAt: new Date(dbNow.getTime() - DAY_MS),
      },
    });
    const application = await ctx.prisma.creatorApplication.create({
      data: {
        userId: creator.id,
        status: 'APPROVED',
        country: 'SA',
        category: 'VIDEO',
        links: ['https://x.example/creator'],
        decidedAt: new Date(),
      },
    });
    await ctx.prisma.creatorMember.create({
      data: { userId: creator.id, applicationId: application.id, activatedAt: new Date() },
    });
    const [a, b] = [partnerA, partnerB].sort((x, y) => (x.id < y.id ? -1 : 1));
    const couple = await ctx.prisma.cpCouple.create({
      data: { userAId: a!.id, userBId: b!.id, since: new Date(dbNow.getTime() - DAY_MS) },
    });
    await ctx.prisma.cpPartner.createMany({
      data: [
        { userId: a!.id, coupleId: couple.id, partnerId: b!.id },
        { userId: b!.id, coupleId: couple.id, partnerId: a!.id },
      ],
    });
    for (const u of [sender1, sender2, partnerA]) await fund(u, 100_000);

    const hostRoom = await startLive(host);
    const creatorRoom = await startLive(creator, 'CREATOR');
    const cpRoom = await startLive(partnerB);
    for (const u of [sender1, sender2]) {
      await join(hostRoom, u);
      await join(creatorRoom, u);
    }
    await join(cpRoom, partnerA);

    await send(hostRoom, sender1, host, 'd303_rose', 3); // 30 coins × 2 = 60 points
    await send(hostRoom, sender2, host, 'd303_crown'); // 100 × 1 + 1 × 50 = 150
    await send(hostRoom, sender1, host, 'd303_other', 5); // not an event gift
    await send(creatorRoom, sender1, creator, 'd303_crown'); // 150 (creators' board, never the hosts')
    await send(cpRoom, partnerA, partnerB, 'd303_rose'); // 20: CP, and partnerA as a sender
    // An event gift to a non-host (no hosting permission, not a creator): it scores for the sender only (20).
    const like = await ctx.prisma.liveGift.findFirstOrThrow({ where: { senderId: partnerA.id } });
    const copy = await withMigrationClient((db) =>
      db.liveGift.create({
        data: {
          senderId: sender2.id,
          clientId: randomUUID(),
          roomId: cpRoom,
          giftCode: 'd303_rose',
          quantity: 1,
          source: 'COINS',
          unitPrice: 10,
          totalCoins: 10n,
          coinsCharged: 10n,
          recipientsKey: viewer.id,
          comboId: like.comboId,
          comboCount: 1,
          comboQuantity: 1n,
          hostShareBps: like.hostShareBps,
        },
      }),
    );
    await withMigrationClient((db) =>
      db.liveGiftRecipient.create({ data: { giftId: copy.id, userId: viewer.id, position: 0, coins: 10n } }),
    );
    // Before the window: moved an hour before the start.
    await send(hostRoom, sender2, host, 'd303_crown');
    const early = await ctx.prisma.liveGift.findFirstOrThrow({
      where: { senderId: sender2.id, giftCode: 'd303_crown' },
      orderBy: { createdAt: 'desc' },
    });
    await withMigrationClient((db) =>
      db.liveGift.update({
        where: { id: early.id },
        data: { createdAt: new Date(dbNow.getTime() - HOUR_MS) },
      }),
    );
    // A reversed send does not count (the team's reversal of its cherries).
    await send(hostRoom, sender2, host, 'd303_rose', 10);
    const reversed = await ctx.prisma.liveGift.findFirstOrThrow({
      where: { senderId: sender2.id, giftCode: 'd303_rose', quantity: 10 },
    });
    await withMigrationClient((db) =>
      db.$transaction((tx) => reverseGiftCherriesIn(tx, reversed.id, new Date())),
    );

    // The test clock stands still (fake Date): a moment later, so the sends are before «now».
    p.advance(1000);
    const senders = await board(sender1, 'SENDERS');
    expect(senders).toMatchObject({ board: 'SENDERS', final: false, minPoints: 100 });
    expect(rows(senders)).toEqual([
      [1, sender1.id, 210, true],
      [2, sender2.id, 170, true],
      [3, partnerA.id, 20, false],
    ]);
    expect(senders.data[0]!.prize.map((i) => i.type)).toEqual([
      'COINS',
      'BAG_ITEM',
      'BAG_ITEM',
      'VIP',
      'BADGE',
    ]);
    expect(senders.data[0]!.prizeCoins).toBe(1000);
    expect(senders.data[2]!.prize).toEqual([]);
    expect(senders.me).toMatchObject({
      rank: 1,
      score: 210,
      qualified: true,
      pointsToQualify: 0,
      prizeCoins: 1000,
    });
    expect((await board(partnerA, 'SENDERS')).me).toMatchObject({
      rank: 3,
      score: 20,
      qualified: false,
      pointsToQualify: 80,
    });
    expect((await board(viewer, 'SENDERS')).me).toMatchObject({
      rank: null,
      score: 0,
      qualified: false,
      pointsToQualify: 100,
    });
    // The first board by default.
    expect((await board(viewer)).board).toBe('SENDERS');

    // Owner (follow-up): the hosts' board includes content creators; a non-host recipient never enters it.
    expect(rows(await board(viewer, 'RECEIVERS'))).toEqual([
      [1, host.id, 210, true],
      [2, creator.id, 150, true],
      [3, partnerB.id, 20, true],
    ]);
    expect(rows(await board(viewer, 'CREATORS'))).toEqual([[1, creator.id, 150, true]]);
    const agencies = await board(agencyOwner, 'AGENCIES');
    expect(rows(agencies)).toEqual([[1, agencyOwner.id, 210, true]]);
    expect(agencies.data[0]!.agency).toEqual({ id: agencyId, name: 'Kabso Stars' });
    expect(agencies.me.rank).toBe(1);
    const cp = await board(partnerB, 'CP');
    expect(cp.data).toHaveLength(1);
    expect([cp.data[0]!.user.id, cp.data[0]!.partner!.id].sort()).toEqual([partnerA.id, partnerB.id].sort());
    expect(cp.data[0]).toMatchObject({ score: 20, qualified: true });
    expect(cp.me.rank).toBe(1);

    // A board the event does not have / a board on a D166 event → 400.
    expect(
      (await ctx.http.get(`/api/v1/events/${eventId}/leaderboard?board=NOPE`).set(auth(viewer))).status,
    ).toBe(400);
  });

  it('edits: the structure is locked once running (texts may change; the end only later)', async () => {
    const changed = await p.send(
      owner,
      'put',
      `/admin/gift-events/${eventId}`,
      eventBody({ gifts: [{ giftCode: 'd303_rose' }] }),
    );
    expect(changed.status, JSON.stringify(changed.body)).toBe(409);
    const earlier = await p.send(
      owner,
      'put',
      `/admin/gift-events/${eventId}`,
      eventBody({ endsAt: new Date(dbNow.getTime() + HOUR_MS).toISOString() }),
    );
    expect(earlier.status).toBe(409);
    const retitled = await p.send(
      owner,
      'put',
      `/admin/gift-events/${eventId}`,
      eventBody({ titleEn: 'Gift King II' }),
    );
    expect(retitled.status, JSON.stringify(retitled.body)).toBe(200);
    expectContract(retitled, 'updateAdminGiftEvent');
    const form = await p.send(owner, 'get', `/admin/gift-events/${eventId}`);
    expect(form.status).toBe(200);
    expectContract(form, 'getAdminGiftEvent');
    expect(form.body).toMatchObject({ structureLocked: true, state: 'RUNNING' });
    expect(form.body.form.titleEn).toBe('Gift King II');
    expect(form.body.form.boards).toHaveLength(5);
  });

  it('a hold before the end stops the automatic payout; released, it pays every winner once with items for their days', async () => {
    const sweeper = ctx.app.get(EventsService);
    const hold = await ctx.http
      .post(`/api/v1/staff/events/${eventId}/hold`)
      .set(auth(owner))
      .send({ reason: 'fraud check' });
    expect(hold.status, JSON.stringify(hold.body)).toBe(200);
    expectContract(hold, 'changeStaffEvent');
    expect(
      (
        await ctx.http
          .post(`/api/v1/staff/events/${eventId}/hold`)
          .set(auth(moderator))
          .send({ reason: 'x y z' })
      ).status,
    ).toBe(403);

    p.advance(4 * HOUR_MS);
    expect(await sweeper.sweep()).toEqual({ frozen: 1, paid: 0 });
    expect(await sweeper.sweep()).toEqual({ frozen: 0, paid: 0 });
    const frozen = await board(viewer, 'SENDERS');
    expect(frozen.final).toBe(true);
    expect(rows(frozen)).toEqual([
      [1, sender1.id, 210, true],
      [2, sender2.id, 170, true],
      [3, partnerA.id, 20, false],
    ]);
    expect(await ctx.prisma.eventPrizePayout.count()).toBe(0);

    // A winner no longer active at payout forfeits.
    await ctx.prisma.user.update({ where: { id: sender2.id }, data: { status: 'SUSPENDED' } });
    const release = await p.send(owner, 'post', `/admin/events/${eventId}/release`, { reason: 'checked' });
    expect(release.status, JSON.stringify(release.body)).toBe(200);
    const now = new Date();
    expect(await sweeper.sweep()).toEqual({ frozen: 0, paid: 1 });
    expect(await sweeper.sweep()).toEqual({ frozen: 0, paid: 0 });

    // sender1 (SENDERS #1): the whole bundle.
    const coins = await ctx.prisma.walletLedgerEntry.findMany({
      where: { userId: sender1.id, reason: 'EVENT_PRIZE' },
    });
    expect(coins.map((c) => Number(c.delta))).toEqual([1000]);
    const cherries = await ctx.prisma.cherryLedgerEntry.findMany({
      where: { userId: sender1.id, reason: 'EVENT_PRIZE' },
    });
    expect(cherries).toEqual([]); // supporters win coins, never cherries
    const items = await ctx.prisma.userBagItem.findMany({
      where: { userId: sender1.id, itemCode: { in: ['d303_frame', 'd303_car'] } },
      orderBy: { itemCode: 'asc' },
    });
    expect(items.map((i) => [i.itemCode, i.source, i.equipped])).toEqual([
      ['d303_car', 'EVENT', false],
      ['d303_frame', 'EVENT', false],
    ]);
    const days = (d: Date | null) => Math.round(((d?.getTime() ?? 0) - now.getTime()) / DAY_MS);
    expect(items.map((i) => (i.expiresAt === null ? 'permanent' : days(i.expiresAt)))).toEqual([
      'permanent',
      7,
    ]);
    const vip = await ctx.prisma.vipMembership.findUniqueOrThrow({ where: { userId: sender1.id } });
    expect(days(vip.expiresAt)).toBe(5);
    // Owner (follow-up): the cherry prize is withdrawable at once — not in the task-cherry lock.
    const lock = await taskCherryLockIn(ctx.prisma, host.id, {
      taskCherriesUnlockGiftMinor: 5000,
      rateCherries: 1_000_000,
      rateMinor: 110,
    });
    expect(lock.lockedCherries).toBe(0n);
    // The event badge for 4 days, shown with the medals while it lasts, gone once ended.
    const badgeKey = { userId_badgeCode: { userId: sender1.id, badgeCode: 'gift_king' } };
    const held = await ctx.prisma.userEventBadge.findUniqueOrThrow({ where: badgeKey });
    expect([days(held.expiresAt), held.level]).toEqual([4, 3]);
    const medals = await ctx.http
      .get(`/api/v1/users/${sender1.username}/medals`)
      .set(auth(viewer))
      .set('Accept-Language', 'en');
    expect(medals.status).toBe(200);
    expectContract(medals, 'listUserMedals');
    expect(medals.body.eventBadges).toEqual([
      expect.objectContaining({ code: 'gift_king', name: 'Gift King' }),
    ]);
    await withMigrationClient((db) =>
      db.userEventBadge.update({ where: badgeKey, data: { expiresAt: new Date(Date.now() - 1000) } }),
    );
    const later = await ctx.http.get(`/api/v1/users/${sender1.username}/medals`).set(auth(viewer));
    expect(later.body.eventBadges).toEqual([]);
    // partnerA ranked 3rd on SENDERS but below the minimum: nothing there (only the CP coins below).
    expect(
      await ctx.prisma.walletLedgerEntry.count({ where: { userId: partnerA.id, reason: 'EVENT_PRIZE' } }),
    ).toBe(1);
    // RECEIVERS #1, CREATORS #1 (cherries), AGENCIES → the owner.
    expect(
      (
        await ctx.prisma.cherryLedgerEntry.findMany({ where: { userId: host.id, reason: 'EVENT_PRIZE' } })
      ).map((c) => Number(c.delta)),
    ).toEqual([700]);
    expect(
      (
        await ctx.prisma.cherryLedgerEntry.findMany({ where: { userId: creator.id, reason: 'EVENT_PRIZE' } })
      ).map((c) => Number(c.delta)),
    ).toEqual([900]);
    expect(
      (
        await ctx.prisma.walletLedgerEntry.findMany({
          where: { userId: agencyOwner.id, reason: 'EVENT_PRIZE' },
        })
      ).map((c) => Number(c.delta)),
    ).toEqual([600]);
    // CP: both partners get the permanent frame; the money by role at payout — partnerB hosts (cherries 400),
    // partnerA does not (coins 250); never converted.
    for (const partner of [partnerA, partnerB]) {
      const frame = await ctx.prisma.userBagItem.findUniqueOrThrow({
        where: { userId_itemCode: { userId: partner.id, itemCode: 'd303_frame' } },
      });
      expect([frame.source, frame.expiresAt]).toEqual(['EVENT', null]);
    }
    const money = async (u: User) => [
      (await ctx.prisma.walletLedgerEntry.findMany({ where: { userId: u.id, reason: 'EVENT_PRIZE' } })).map(
        (c) => Number(c.delta),
      ),
      (await ctx.prisma.cherryLedgerEntry.findMany({ where: { userId: u.id, reason: 'EVENT_PRIZE' } })).map(
        (c) => Number(c.delta),
      ),
    ];
    expect(await money(partnerA)).toEqual([[250], []]);
    expect(await money(partnerB)).toEqual([[], [400]]);
    // One payout per result and winner; notified; audited.
    const payouts = await ctx.prisma.eventPrizePayout.findMany();
    expect(payouts.filter((x) => x.status === 'PAID')).toHaveLength(6);
    expect(payouts.filter((x) => x.status === 'FORFEITED').map((x) => x.userId)).toEqual([sender2.id]);
    expect(
      await ctx.prisma.walletLedgerEntry.count({ where: { userId: sender2.id, reason: 'EVENT_PRIZE' } }),
    ).toBe(0);
    const winners = new Set(payouts.filter((x) => x.status === 'PAID').map((x) => x.userId));
    expect(winners).toEqual(
      new Set([sender1.id, host.id, creator.id, agencyOwner.id, partnerA.id, partnerB.id]),
    );
    const notes = await ctx.prisma.notification.findMany({ where: { type: 'EVENT_PRIZE_WON', eventId } });
    expect(notes).toHaveLength(6);
    const inbox = await ctx.http.get('/api/v1/notifications').set(auth(sender1));
    expect(inbox.status).toBe(200);
    expectContract(inbox, 'listNotifications');
    expect(inbox.body.data.find((n: { type: string }) => n.type === 'EVENT_PRIZE_WON')).toMatchObject({
      target: { type: 'EVENT', id: eventId },
    });
    expect(await ctx.prisma.auditLog.count({ where: { action: 'event.payout', targetId: eventId } })).toBe(1);
    // A prize item is not transferable (D303: like a level reward).
    const bag = await ctx.http.get('/api/v1/me/bag?category=AVATAR_FRAME').set(auth(sender1));
    expect(bag.status, JSON.stringify(bag.body)).toBe(200);
    expectContract(bag, 'getMyBag');
    const frame = (bag.body.data as { code: string; source: string; transferable: boolean }[]).find(
      (i) => i.code === 'd303_frame',
    );
    expect(frame).toMatchObject({ source: 'EVENT', transferable: false });
    // Settled: hold and edits refused.
    expect((await p.send(owner, 'post', `/admin/events/${eventId}/hold`, { reason: 'late' })).status).toBe(
      409,
    );
    expect((await p.send(owner, 'put', `/admin/gift-events/${eventId}`, eventBody())).status).toBe(409);
    // The final board shows the frozen bundles.
    const final = await board(sender1, 'SENDERS');
    expect(final.data[0]!.prize.map((i) => i.type)).toEqual([
      'COINS',
      'BAG_ITEM',
      'BAG_ITEM',
      'VIP',
      'BADGE',
    ]);
  });

  it('a gift event with no qualified entrant is settled at once; a creators-only event is hidden from others', async () => {
    const made = await p.send(
      owner,
      'post',
      '/admin/gift-events',
      eventBody({
        audience: 'CREATORS',
        startsAt: new Date(Date.now() - 60_000).toISOString(),
        endsAt: new Date(Date.now() + HOUR_MS).toISOString(),
        boards: [
          {
            kind: 'CREATORS',
            minPoints: 1_000_000,
            prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'CHERRIES', amount: 5 }] }],
          },
        ],
      }),
    );
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    const id = made.body.id as string;
    const tab = async (u: User): Promise<string[]> => {
      const res = await ctx.http.get('/api/v1/events?tab=CALENDAR').set(auth(u));
      return (res.body.data as { id: string }[]).map((e) => e.id);
    };
    expect(await tab(creator)).toContain(id);
    expect(await tab(viewer)).not.toContain(id);
    p.advance(2 * HOUR_MS);
    const sweeper = ctx.app.get(EventsService);
    await sweeper.sweep();
    const e = await ctx.prisma.event.findUniqueOrThrow({ where: { id } });
    expect(e.paidAt).not.toBeNull();
    expect(await ctx.prisma.eventPrizePayout.count({ where: { result: { eventId: id } } })).toBe(0);
  });
});

describe('D303 animated and video banners', { timeout: 300_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let support: Admin;
  let viewer: Person;
  let eventId: string;
  const upload = (a: Admin, path: string, bytes: Buffer, placement?: string) => {
    const r = ctx.http.post(`/api/v1/admin/${path}`);
    return (placement ? r.query({ placement }) : r)
      .set('Cookie', a.cookie)
      .set('X-CSRF-Token', a.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(bytes);
  };
  const still = (w: number, h: number) =>
    sharp({ create: { width: w, height: h, channels: 3, background: { r: 30, g: 120, b: 200 } } })
      .png()
      .toBuffer();
  const animated = async (w: number, h: number, frames: number) => {
    const parts = await Promise.all(
      Array.from({ length: frames }, (_, i) =>
        sharp({
          create: {
            width: w,
            height: h,
            channels: 4,
            background: { r: 229, g: (i * 50) % 200, b: 20, alpha: 1 },
          },
        })
          .png()
          .toBuffer(),
      ),
    );
    return sharp(parts, { join: { animated: true } })
      .webp({ loop: 0, delay: Array(frames).fill(150), quality: 60 })
      .toBuffer();
  };
  const banners = async () => {
    const res = await ctx.http
      .get('/api/v1/home/banners')
      .set('Authorization', `Bearer ${viewer.token}`)
      .set('Accept-Language', 'en');
    expect(res.status).toBe(200);
    expectContract(res, 'listHomeBanners');
    return res.body.data as {
      id: string;
      kind: string;
      imageUrl: string;
      posterUrl: string;
      videoUrl: string | null;
      durationMs: number | null;
      eventId: string | null;
      link: string;
    }[];
  };

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(CONFIG, [{ token: OBJECT_STORAGE, value: storage }]);
    owner = await p.makeAdmin(['OWNER']);
    support = await p.makeAdmin(['SUPPORT']);
    viewer = await p.signup();
    const event = await withMigrationClient((db) =>
      db.event.create({
        data: {
          titleAr: 'فعالية',
          titleEn: 'Event',
          rulesAr: '',
          rulesEn: '',
          startsAt: new Date(),
          endsAt: new Date(Date.now() + DAY_MS),
          metric: 'GIFT_COINS_SENT',
        },
      }),
    );
    eventId = event.id;
    expect(viewer.id).toBeTruthy();
  });
  afterAll(async () => {
    vi.useRealTimers();
    await withMigrationClient(async (db) => {
      await db.homeBanner.deleteMany();
      await db.event.deleteMany();
    });
    await ctx?.close();
  });

  it('a still stays IMAGE; an animated WebP is ANIMATED with its first frame as the poster; a video banner opens an event', async () => {
    const s = await upload(owner, 'banner-uploads', await still(1500, 300), 'home');
    expect(s.status).toBe(201);
    const a = await upload(owner, 'banner-uploads', await animated(600, 120, 4), 'home');
    expect(a.status, JSON.stringify(a.body)).toBe(201);
    const poster = await upload(owner, 'banner-uploads', await still(1500, 300), 'home');
    const video = await upload(
      owner,
      'banner-video-uploads',
      mp4({ durationMs: 8_000, width: 1280, height: 256 }),
    );
    expect(video.status, JSON.stringify(video.body)).toBe(201);
    expectContract(video, 'uploadAdminBannerVideo');
    expect(video.body).toMatchObject({ durationMs: 8_000, width: 1280, height: 256 });
    // Limits: longer than 30 s, not a video, another role.
    expect((await upload(owner, 'banner-video-uploads', mp4({ durationMs: 31_000 }))).status).toBe(422);
    expect((await upload(owner, 'banner-video-uploads', await still(10, 10))).status).toBe(422);
    expect((await upload(support, 'banner-video-uploads', mp4({ durationMs: 5_000 }))).status).toBe(403);

    const add = (body: object) =>
      p.send(owner, 'post', '/admin/banners', {
        placement: 'home',
        link: '/families',
        reason: 'D303',
        ...body,
      });
    const one = await add({ mediaId: s.body.mediaId, sortOrder: 1 });
    expect(one.status, JSON.stringify(one.body)).toBe(201);
    const two = await add({ mediaId: a.body.mediaId, sortOrder: 2 });
    expect(two.status).toBe(201);
    expect(two.body.kind).toBe('ANIMATED');
    // A video on a non-home placement is refused; on home it opens the event.
    const roomPoster = await upload(owner, 'banner-uploads', await still(600, 800), 'room');
    const otherVideo = await upload(
      owner,
      'banner-video-uploads',
      mp4({ durationMs: 4_000, width: 640, height: 640 }),
    );
    expect(
      (
        await p.send(owner, 'post', '/admin/banners', {
          mediaId: roomPoster.body.mediaId,
          videoMediaId: otherVideo.body.mediaId,
          placement: 'room',
          link: '/families',
          reason: 'no',
        })
      ).status,
    ).toBe(409);
    const three = await add({
      mediaId: poster.body.mediaId,
      videoMediaId: video.body.mediaId,
      eventId,
      sortOrder: 0,
    });
    expect(three.status, JSON.stringify(three.body)).toBe(201);
    expect(three.body).toMatchObject({ kind: 'VIDEO', eventId, link: `/events/${eventId}` });

    const list = await banners();
    expect(list.map((b) => b.kind)).toEqual(['VIDEO', 'IMAGE', 'ANIMATED']);
    expect(list[0]).toMatchObject({ eventId, link: `/events/${eventId}`, durationMs: 8_000 });
    expect(list[0]!.videoUrl).toMatch(/video\.mp4$/);
    expect(list[0]!.posterUrl).toBe(list[0]!.imageUrl);
    expect(list[1]).toMatchObject({ videoUrl: null, durationMs: null, eventId: null });
    expect(list[1]!.posterUrl).toBe(list[1]!.imageUrl);
    expect(list[2]!.durationMs).toBe(600);
    expect(list[2]!.posterUrl).toMatch(/poster\.webp$/);
    const posterBytes = storage.objects.get(
      list[2]!.posterUrl.replace('https://media.example.test/', ''),
    )!.body;
    expect((await sharp(posterBytes, { animated: true }).metadata()).pages ?? 1).toBe(1);

    // Removing the video banner deletes its video and poster objects.
    const videoKey = list[0]!.videoUrl!.replace('https://media.example.test/', '');
    expect(storage.objects.has(videoKey)).toBe(true);
    const removed = await p.send(owner, 'post', `/admin/banners/${three.body.id as string}/remove`, {
      reason: 'done',
    });
    expect(removed.status).toBe(200);
    expect(storage.objects.has(videoKey)).toBe(false);
    expect((await banners()).map((b) => b.kind)).toEqual(['IMAGE', 'ANIMATED']);
  });
});
