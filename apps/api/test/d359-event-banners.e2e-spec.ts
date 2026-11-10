/**
 * D359 (owner decision: events reach the «البث» hub ONLY through the existing home banner carousel; contract
 * v1.119-social, CONVENTIONS §10.154, migration `20270423090000_event_banner_options`):
 * 1. The event wizard's «بانر صفحة البث»: the picture made a banner opening the event (`/events/<id>`, `eventId`),
 *    turned off (picture kept) and on again, «يظهر قبل البداية» (an upcoming event shown from its publish), the picture
 *    removed → no banner; the form reads the settings back.
 * 2. An event banner goes the moment its event ends (an early «إنهاء» included), even a banner linked from
 *    «البانرات» with no end of its own — at query time.
 * 3. Running events' banners first, then the rest, each group in the admin's order.
 * End to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const HOUR_MS = 3_600_000;

const CONFIG = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
  ADMIN_TOTP_KEY: 'd359-admin-totp-test-key-0123456789-abcdefghijk',
  JWT_ACCESS_TTL_SECONDS: String(90 * 86_400),
  ADMIN_SESSION_IDLE_SECONDS: '86400',
  ADMIN_SESSION_MAX_SECONDS: '604800',
  RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
  RATE_LIMIT_ADMIN_IP: '100000/900',
  EVENTS_SWEEP_INTERVAL_SECONDS: '0',
};

interface Banner {
  id: string;
  link: string;
  eventId: string | null;
}

describe('D359 event banners on the Live hub', { timeout: 600_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let viewer: Person;

  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const iso = (ms: number) => new Date(ms).toISOString();
  const picture = () =>
    sharp({ create: { width: 1500, height: 300, channels: 3, background: { r: 20, g: 90, b: 200 } } })
      .png()
      .toBuffer();
  const uploadBanner = async () => {
    const res = await ctx.http
      .post('/api/v1/admin/event-uploads?kind=banner')
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(await picture());
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.mediaId as string;
  };
  const body = (over: Record<string, unknown>) => ({
    status: 'PUBLISHED',
    titleAr: 'فعالية',
    titleEn: 'Event',
    rulesAr: 'القواعد',
    rulesEn: 'Rules',
    startsAt: iso(Date.now() - 60_000),
    endsAt: iso(Date.now() + 2 * HOUR_MS),
    gifts: [{ giftCode: 'd359_rose' }],
    boards: [{ kind: 'SENDERS' }],
    reason: 'D359 test',
    ...over,
  });
  const giftEvent = async (over: Record<string, unknown>) => {
    const res = await p.send(owner, 'post', '/admin/gift-events', body(over));
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const edit = async (id: string, over: Record<string, unknown>) => {
    const res = await p.send(owner, 'put', `/admin/gift-events/${id}`, body(over));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
  };
  const form = async (id: string) => {
    const res = await p.send(owner, 'get', `/admin/gift-events/${id}`);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getAdminGiftEvent');
    return res.body.form as {
      bannerMediaId: string | null;
      bannerEnabled: boolean;
      bannerBeforeStart: boolean;
    };
  };
  const hub = async (): Promise<Banner[]> => {
    const res = await ctx.http.get('/api/v1/home/banners').set(auth(viewer));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listHomeBanners');
    return res.body.data as Banner[];
  };
  const hubEvents = async () => (await hub()).map((b) => b.eventId);
  const ownBanners = (eventId: string) =>
    ctx.prisma.homeBanner.count({ where: { eventId, placement: 'HOME' } });
  /** A banner as «البانرات» makes it (`sortOrder` chosen by the admin), optionally opening an event. */
  const plainBanner = async (sortOrder: number, eventId: string | null = null) => {
    const row = await ctx.prisma.homeBanner.create({
      data: {
        mediaId: await uploadBanner(),
        placement: 'HOME',
        link: eventId ? `/events/${eventId}` : '/families',
        eventId,
        sortOrder,
        startsAt: new Date(Date.now() - 60_000),
        enabled: true,
      },
    });
    return row.id;
  };
  const clearBanners = () => withMigrationClient((db) => db.$executeRaw`DELETE FROM home_banners`);

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(CONFIG, [{ token: OBJECT_STORAGE, value: storage }]);
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, 'd359_rose', {
        category: 'POPULAR',
        nameAr: 'd359_rose',
        nameEn: 'd359_rose',
        priceCoins: 100,
        assetKey: 'gift_d359_rose', // gitleaks:allow (an asset name)
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
    owner = await p.makeAdmin(['OWNER']);
    viewer = await p.signup();
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('the migration: both columns with their defaults (older events keep their banner, shown from the start)', async () => {
    const cols = await ctx.prisma.$queryRaw<
      { column_name: string; column_default: string; is_nullable: string }[]
    >`
      SELECT column_name, column_default, is_nullable FROM information_schema.columns
      WHERE table_name = 'events' AND column_name IN ('banner_enabled', 'banner_before_start')
      ORDER BY column_name`;
    expect(cols).toEqual([
      { column_name: 'banner_before_start', column_default: 'false', is_nullable: 'NO' },
      { column_name: 'banner_enabled', column_default: 'true', is_nullable: 'NO' },
    ]);
  });

  it('«بانر صفحة البث»: the banner opens the event; off keeps the picture; on again; removed picture → none', async () => {
    await clearBanners();
    const media = await uploadBanner();
    const id = await giftEvent({ titleEn: 'Wizard banner', bannerMediaId: media });
    // Defaults: on, from the start.
    expect(await form(id)).toMatchObject({
      bannerMediaId: media,
      bannerEnabled: true,
      bannerBeforeStart: false,
    });
    const [shown] = (await hub()).filter((b) => b.eventId === id);
    expect(shown).toMatchObject({ link: `/events/${id}`, eventId: id });
    // The event page it opens is there for the viewer.
    expect((await ctx.http.get(`/api/v1/events/${id}`).set(auth(viewer))).status).toBe(200);

    // Off (a display setting: allowed while running) → no banner, the picture kept on the event.
    await edit(id, { titleEn: 'Wizard banner', bannerMediaId: media, bannerEnabled: false });
    expect(await ownBanners(id)).toBe(0);
    expect(await hubEvents()).not.toContain(id);
    expect(await form(id)).toMatchObject({ bannerMediaId: media, bannerEnabled: false });
    // A later edit that leaves the setting out keeps it off.
    await edit(id, { titleEn: 'Wizard banner 2', bannerMediaId: media });
    expect(await ownBanners(id)).toBe(0);

    // On again → the same picture is the banner again.
    await edit(id, { titleEn: 'Wizard banner', bannerMediaId: media, bannerEnabled: true });
    expect(await hubEvents()).toContain(id);
    expect((await ctx.prisma.homeBanner.findFirstOrThrow({ where: { eventId: id } })).mediaId).toBe(media);

    // A new picture replaces it (one banner); no picture → none.
    const second = await uploadBanner();
    await edit(id, { titleEn: 'Wizard banner', bannerMediaId: second });
    expect(
      await ctx.prisma.homeBanner.findMany({ where: { eventId: id }, select: { mediaId: true } }),
    ).toEqual([{ mediaId: second }]);
    await edit(id, { titleEn: 'Wizard banner', bannerMediaId: null });
    expect(await ownBanners(id)).toBe(0);
    expect(await hubEvents()).not.toContain(id);
  });

  it('«يظهر قبل البداية»: an upcoming event is announced from its publish, else from its start', async () => {
    await clearBanners();
    const later = { startsAt: iso(Date.now() + HOUR_MS), endsAt: iso(Date.now() + 3 * HOUR_MS) };
    const atStart = await giftEvent({ ...later, titleEn: 'At start', bannerMediaId: await uploadBanner() });
    const early = await giftEvent({
      ...later,
      titleEn: 'Early',
      bannerMediaId: await uploadBanner(),
      bannerBeforeStart: true,
    });
    expect(await form(early)).toMatchObject({ bannerBeforeStart: true });
    expect(await hubEvents()).toEqual([early]);
    // Turned on later for the first one: shown at once.
    const f = await form(atStart);
    await edit(atStart, {
      ...later,
      titleEn: 'At start',
      bannerMediaId: f.bannerMediaId,
      bannerBeforeStart: true,
    });
    expect((await hubEvents()).sort()).toEqual([atStart, early].sort());
    await edit(atStart, {
      ...later,
      titleEn: 'At start',
      bannerMediaId: f.bannerMediaId,
      bannerBeforeStart: false,
    });
    expect(await hubEvents()).toEqual([early]);
    // Unpublished (before the start) → its banner goes.
    const res = await p.send(owner, 'post', `/admin/events/${early}/unpublish`, { reason: 'D359 unpublish' });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(await hubEvents()).toEqual([]);
  });

  it('an event banner goes the moment its event ends — «إنهاء» early, and a «البانرات» banner without an end', async () => {
    await clearBanners();
    const id = await giftEvent({ titleEn: 'Ends', bannerMediaId: await uploadBanner() });
    const linked = await plainBanner(-10, id); // linked from «البانرات», no end of its own
    const plain = await plainBanner(5);
    expect((await hub()).map((b) => b.id)).toEqual(
      expect.arrayContaining([
        linked,
        plain,
        ...(await ctx.prisma.homeBanner.findMany({ where: { eventId: id } })).map((b) => b.id),
      ]),
    );
    const end = await p.send(owner, 'post', `/admin/events/${id}/end`, { reason: 'D359 end early' });
    expect(end.status, JSON.stringify(end.body)).toBe(200);
    p.advance(1_000);
    // Both banners of the event are gone at once (their rows are still there: no sweeper needed).
    expect((await hub()).map((b) => b.id)).toEqual([plain]);
    expect(await ownBanners(id)).toBe(2);

    // An event that ends by its own date: shown until then, gone after.
    const short = await giftEvent({
      titleEn: 'Short',
      endsAt: iso(Date.now() + 10 * 60_000),
      bannerMediaId: await uploadBanner(),
    });
    await plainBanner(-1, short);
    expect((await hubEvents()).filter((e) => e === short)).toHaveLength(2);
    p.advance(11 * 60_000);
    expect(await hubEvents()).toEqual([null]);
  });

  it('running events first, then the rest, each group in the admin order', async () => {
    await clearBanners();
    const first = await plainBanner(-20); // the admin's first banner, no event
    const upcoming = await giftEvent({
      titleEn: 'Upcoming',
      startsAt: iso(Date.now() + HOUR_MS),
      endsAt: iso(Date.now() + 3 * HOUR_MS),
      bannerMediaId: await uploadBanner(),
      bannerBeforeStart: true,
    });
    const runA = await giftEvent({ titleEn: 'Running A', bannerMediaId: await uploadBanner() });
    const runB = await giftEvent({ titleEn: 'Running B', bannerMediaId: await uploadBanner() });
    // The admin orders inside the running group: B before A; and the upcoming one before the plain one.
    await ctx.prisma.homeBanner.updateMany({ where: { eventId: runB }, data: { sortOrder: -5 } });
    await ctx.prisma.homeBanner.updateMany({ where: { eventId: runA }, data: { sortOrder: 3 } });
    await ctx.prisma.homeBanner.updateMany({ where: { eventId: upcoming }, data: { sortOrder: -30 } });
    const last = await plainBanner(10);
    const order = await hub();
    expect(order.map((b) => b.eventId ?? b.id)).toEqual([runB, runA, upcoming, first, last]);
    // A guest-free check of the shape: every event banner links its event page.
    for (const b of order.filter((x) => x.eventId)) expect(b.link).toBe(`/events/${b.eventId}`);
  });
});
