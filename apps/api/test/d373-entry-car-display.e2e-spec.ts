/**
 * D373 (owner 2026-11-11: «سيارات الدخول ستكون اما بشاشة كاملة او نصف الشاشة … من لوحة الادمن انت تحدد كيف ستكون الدخلة
 * اما بشاشة كاملة او نصف شاشة»; contract v1.128-social, CONVENTIONS §10.165): an entry car's display «طريقة العرض» —
 * FULL_SCREEN or HALF_SCREEN — set in the panel per store entry car and per VIP ENTRY_EFFECT perk, audited, refused for
 * any other kind / perk, FULL_SCREEN for every car that existed before (migration default), and delivered where the app
 * reads the car: `UserSummary.wear.entryEffect` (also in the live `join` data message and the room's host) and the VIP
 * catalogue's `VipPerk`. End to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { LiveMediaService } from '../src/modules/live/live-media.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, openapi } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const BASE = 'https://media.example.test';
const VIP1 = '01a25200-0000-7000-8000-000000000001';
const ART = `${BASE}/media/store/${'a'.repeat(32)}.svga`;
const STILL = `${BASE}/media/store/${'b'.repeat(32)}.png`;

type Json = Record<string, unknown>;
const schema = (name: string) =>
  ((openapi.components as Json).schemas as Record<string, Json & { properties?: Json; required?: string[] }>)[
    name
  ]!;

describe('D373 contract', () => {
  it('openapi v1.128-social declares EntryDisplay and the entryDisplay fields', () => {
    expect(schema('EntryDisplay').enum).toEqual(['FULL_SCREEN', 'HALF_SCREEN']);
    for (const name of [
      'StoreWornItem',
      'VipPerk',
      'AdminVipPerk',
      'AdminVipPerkInput',
      'AdminStoreItem',
      'AdminStoreItemCreateRequest',
      'AdminStoreItemUpdateRequest',
    ]) {
      expect(Object.keys(schema(name).properties!), name).toContain('entryDisplay');
    }
    // Optional on the worn item (other kinds have none) and on requests; always present on the panel's / app's rows.
    expect(schema('StoreWornItem').required).not.toContain('entryDisplay');
    expect(schema('VipPerk').required).toContain('entryDisplay');
    expect(schema('AdminVipPerk').required).toContain('entryDisplay');
    expect(schema('AdminStoreItem').required).toContain('entryDisplay');
  });
});

describe('D373 an entry car plays full screen or half screen', { timeout: 180_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let car: { id: string; code: string };

  const auth = (u: Person) => ({ Authorization: `Bearer ${u.token}` });
  const coins = (u: Person, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const usernameOf = async (u: Person) =>
    (await ctx.http.get('/api/v1/me').set(auth(u))).body.username as string;
  const audits = (targetId: string, action: string) =>
    ctx.prisma.auditLog.findMany({ where: { targetId, action }, orderBy: { createdAt: 'asc' } });

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: ADMIN_KEY,
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
        MEDIA_PUBLIC_BASE_URL: BASE,
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
      },
      [
        { token: OBJECT_STORAGE, value: new MemoryObjectStorage() },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
    owner = await p.makeAdmin(['OWNER']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('an entry car that existed before D373 is FULL_SCREEN (the migration default); so is the seeded VIP perk', async () => {
    // A row written without the column, as every car before the migration.
    await withMigrationClient(async (db) => {
      await db.$executeRawUnsafe(`
        INSERT INTO bag_items (code, category, name_ar, name_en, asset_key, sort_order)
          VALUES ('store_0123456789ab', 'ENTRY_EFFECT', 'سيارة قديمة', 'Old car', 'store_0123456789ab', 5)`);
      await db.$executeRawUnsafe(`
        INSERT INTO store_items (id, bag_code, kind, name_ar, name_en, animation, animation_format, sort_order, updated_at)
          VALUES ('${randomUUID()}', 'store_0123456789ab', 'ENTRY_EFFECT', 'سيارة قديمة', 'Old car', '${ART}', 'SVGA', 5, now())`);
    });
    const old = await ctx.prisma.storeItem.findUniqueOrThrow({ where: { bagCode: 'store_0123456789ab' } });
    expect(old.entryDisplay).toBe('FULL_SCREEN');
    const list = await p.send(owner, 'get', '/admin/store/items');
    expect(list.status).toBe(200);
    expectContract(list, 'listAdminStoreItems');
    expect(
      (list.body.data as { code: string; entryDisplay: string }[]).find((i) => i.code === old.bagCode),
    ).toMatchObject({ entryDisplay: 'FULL_SCREEN' });

    const u = await p.signup();
    const tiers = await ctx.http.get('/api/v1/vip/tiers').set(auth(u)).set('Accept-Language', 'en');
    expect(tiers.status).toBe(200);
    expectContract(tiers, 'listVipTiers');
    const perks = (tiers.body.data as { perks: { code: string; entryDisplay: string | null }[] }[])[0]!.perks;
    expect(perks.find((x) => x.code === 'ENTRY_EFFECT')!.entryDisplay).toBe('FULL_SCREEN');
    // Every other perk has none.
    expect(perks.filter((x) => x.code !== 'ENTRY_EFFECT').every((x) => x.entryDisplay === null)).toBe(true);
  });

  it('the panel sets a store car HALF_SCREEN (audited); any other kind is refused', async () => {
    const created = await p.send(owner, 'post', '/admin/store/items', {
      kind: 'ENTRY_EFFECT',
      nameAr: 'سيارة النصف',
      nameEn: 'Half car',
      still: STILL,
      animation: ART,
      artWidth: 750,
      artHeight: 1334,
      entryDisplay: 'HALF_SCREEN',
      prices: [{ currency: 'COINS', days: 7, amount: 10_000 }],
      enabled: true,
      reason: 'owner D373',
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    expectContract(created, 'createAdminStoreItem');
    expect(created.body.entryDisplay).toBe('HALF_SCREEN');
    car = { id: created.body.id as string, code: created.body.code as string };
    const [add] = await audits(car.id, 'store.item.add');
    expect((add!.metadata as { after: Json }).after.entryDisplay).toBe('HALF_SCREEN');

    // A car created without it: FULL_SCREEN.
    const plain = await p.send(owner, 'post', '/admin/store/items', {
      kind: 'ENTRY_EFFECT',
      nameAr: 'سيارة',
      nameEn: 'Car',
      prices: [],
      reason: 'owner D373',
    });
    expect(plain.status).toBe(201);
    expect(plain.body.entryDisplay).toBe('FULL_SCREEN');

    // Another kind: refused with it, null without it.
    const frameBad = await p.send(owner, 'post', '/admin/store/items', {
      kind: 'AVATAR_FRAME',
      nameAr: 'إطار',
      nameEn: 'Frame',
      entryDisplay: 'HALF_SCREEN',
      prices: [],
      reason: 'x',
    });
    expect(frameBad.status).toBe(400);
    expect(frameBad.body.error.code).toBe('VALIDATION_FAILED');
    expect(frameBad.body.error.details).toContainEqual(
      expect.objectContaining({ field: 'entryDisplay', issue: 'not_allowed' }),
    );
    const frame = await p.send(owner, 'post', '/admin/store/items', {
      kind: 'AVATAR_FRAME',
      nameAr: 'إطار',
      nameEn: 'Frame',
      prices: [],
      reason: 'x',
    });
    expect(frame.status).toBe(201);
    expect(frame.body.entryDisplay).toBeNull();
    const framePatch = await p.send(owner, 'patch', `/admin/store/items/${frame.body.id as string}`, {
      entryDisplay: 'FULL_SCREEN',
      reason: 'x',
    });
    expect(framePatch.status).toBe(400);
    expect(framePatch.body.error.details).toContainEqual(
      expect.objectContaining({ field: 'entryDisplay', issue: 'not_allowed' }),
    );
    const invalid = await p.send(owner, 'patch', `/admin/store/items/${car.id}`, {
      entryDisplay: 'QUARTER',
      reason: 'x',
    });
    expect(invalid.status).toBe(400);

    // Back and forth, each change audited with its before / after.
    const full = await p.send(owner, 'patch', `/admin/store/items/${car.id}`, {
      entryDisplay: 'FULL_SCREEN',
      reason: 'try full',
    });
    expect(full.status, JSON.stringify(full.body)).toBe(200);
    expectContract(full, 'updateAdminStoreItem');
    expect(full.body.entryDisplay).toBe('FULL_SCREEN');
    const half = await p.send(owner, 'patch', `/admin/store/items/${car.id}`, {
      entryDisplay: 'HALF_SCREEN',
      reason: 'half after all',
    });
    expect(half.body.entryDisplay).toBe('HALF_SCREEN');
    const updates = await audits(car.id, 'store.item.update');
    expect(
      updates.map((a) => {
        const m = a.metadata as { before: Json; after: Json; reason: string; via: string };
        return [m.before.entryDisplay, m.after.entryDisplay, m.reason, m.via];
      }),
      // (The test clock stands still: both rows have the same time.)
    ).toEqual(
      expect.arrayContaining([
        ['HALF_SCREEN', 'FULL_SCREEN', 'try full', 'panel'],
        ['FULL_SCREEN', 'HALF_SCREEN', 'half after all', 'panel'],
      ]),
    );
    expect(updates).toHaveLength(2);
  });

  it('the worn car carries its display to the profile, the join data message and the host of the room', async () => {
    const host = await p.signup();
    await coins(host, 100_000);
    const bought = await ctx.http
      .post('/api/v1/me/store/purchases')
      .set(auth(host))
      .set('Idempotency-Key', randomUUID())
      .send({ itemId: car.id, currency: 'COINS', days: 7, price: 10_000 });
    expect(bought.status, JSON.stringify(bought.body)).toBe(201);
    const wear = await ctx.http
      .put('/api/v1/me/bag/equipped')
      .set(auth(host))
      .send({ category: 'ENTRY_EFFECT', code: car.code });
    expect(wear.status, JSON.stringify(wear.body)).toBe(200);
    expectContract(wear, 'setMyBagEquipped');

    const viewer = await p.signup();
    const profile = await ctx.http.get(`/api/v1/users/${await usernameOf(host)}`).set(auth(viewer));
    expect(profile.status).toBe(200);
    expectContract(profile, 'getPublicProfile');
    expect(profile.body.wear.entryEffect).toMatchObject({
      code: car.code,
      format: 'SVGA',
      width: 750,
      height: 1334,
      entryDisplay: 'HALF_SCREEN',
    });

    // The room's host (its own SQL path) and a join of the wearer.
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Cars' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    expectContract(room, 'startLiveRoom');
    expect(room.body.host.wear.entryEffect.entryDisplay).toBe('HALF_SCREEN');
    const read = await ctx.http.get(`/api/v1/live/rooms/${room.body.id as string}`).set(auth(viewer));
    expect(read.status).toBe(200);
    expectContract(read, 'getLiveRoom');
    expect(read.body.host.wear.entryEffect.entryDisplay).toBe('HALF_SCREEN');

    const host2 = await p.signup();
    await ctx.prisma.liveHost.create({ data: { userId: host2.id, source: 'ADMIN' } });
    const room2 = await ctx.http.post('/api/v1/live/rooms').set(auth(host2)).send({ title: 'Other' });
    expect(room2.status).toBe(201);
    const roomId = room2.body.id as string;
    await ctx.app
      .get<LiveMediaService, { onJoined(r: string, i: string): Promise<void> }>(LiveMediaService)
      .onJoined(roomId, host.id);
    const joins = media.broadcastsOf(roomId, 'join');
    const joined = joins.find((j) => (j.user as { id: string }).id === host.id)!;
    expect(
      (joined.user as { wear: { entryEffect: { code: string; entryDisplay: string } } }).wear.entryEffect,
    ).toMatchObject({ code: car.code, entryDisplay: 'HALF_SCREEN' });

    // Another worn kind never carries a display.
    const frameRow = await ctx.prisma.storeItem.findFirstOrThrow({ where: { kind: 'AVATAR_FRAME' } });
    await ctx.prisma.userBagItem.create({
      data: {
        userId: host.id,
        itemCode: frameRow.bagCode,
        category: 'AVATAR_FRAME',
        source: 'ADMIN',
        equipped: true,
      },
    });
    const again = await ctx.http.get(`/api/v1/users/${await usernameOf(host)}`).set(auth(viewer));
    expectContract(again, 'getPublicProfile');
    expect(again.body.wear.avatarFrame.code).toBe(frameRow.bagCode);
    expect(again.body.wear.avatarFrame).not.toHaveProperty('entryDisplay');
  });

  it('the panel sets the VIP ENTRY_EFFECT perk HALF_SCREEN (audited, kept when not sent); other perks refused', async () => {
    const list = await p.send(owner, 'get', '/admin/vip/tiers');
    expect(list.status).toBe(200);
    expectContract(list, 'listAdminVipTiers');
    const tier = (list.body.data as { id: string; perks: Json[] }[]).find((t) => t.id === VIP1)!;
    expect(tier.perks.find((x) => x.code === 'ENTRY_EFFECT')!.entryDisplay).toBe('FULL_SCREEN');
    expect(tier.perks.find((x) => x.code === 'BADGE')!.entryDisplay).toBeNull();
    // The panel's perk inputs: the output less what is not an input. v1.129-social (D374): a perk outside the catalogue
    // (retired, or saved before it) is dropped, as the panel does — the server refuses its code.
    const inputs = (extra: (code: string) => Json) =>
      tier.perks
        .filter((x) => x.catalogued !== false && x.retired !== true)
        .map((x) => {
          // v1.129-social (D374): `category`, `catalogued` and `retired` are read-only too.
          const { available: _a, entryDisplay: _e, category: _c, catalogued: _k, retired: _r, ...rest } = x;
          void _a;
          void _e;
          void _c;
          void _k;
          void _r;
          return { ...rest, ...extra(x.code as string) };
        });

    const bad = await p.send(owner, 'patch', `/admin/vip/tiers/${VIP1}`, {
      perks: inputs((code) => (code === 'BADGE' ? { entryDisplay: 'HALF_SCREEN' } : {})),
      reason: 'x',
    });
    expect(bad.status).toBe(400);
    expect(JSON.stringify(bad.body.error.details)).toContain('entryDisplay');

    const ok = await p.send(owner, 'patch', `/admin/vip/tiers/${VIP1}`, {
      perks: inputs((code) => (code === 'ENTRY_EFFECT' ? { entryDisplay: 'HALF_SCREEN' } : {})),
      reason: 'owner D373',
    });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'updateAdminVipTier');
    expect((ok.body.perks as Json[]).find((x) => x.code === 'ENTRY_EFFECT')!.entryDisplay).toBe(
      'HALF_SCREEN',
    );
    const [audit] = await audits(VIP1, 'vip.tier.update');
    const meta = audit!.metadata as { before: { perks: Json[] }; after: { perks: Json[] }; reason: string };
    expect(meta.before.perks.find((x) => x.code === 'ENTRY_EFFECT')!.entryDisplay).toBe('FULL_SCREEN');
    expect(meta.after.perks.find((x) => x.code === 'ENTRY_EFFECT')!.entryDisplay).toBe('HALF_SCREEN');
    expect(meta.after.perks.find((x) => x.code === 'BADGE')).not.toHaveProperty('entryDisplay');

    // An older panel sends the perks without it: the display stays.
    const rename = await p.send(owner, 'patch', `/admin/vip/tiers/${VIP1}`, {
      perks: inputs(() => ({})),
      reason: 'older panel',
    });
    expect(rename.status).toBe(200);
    expect((rename.body.perks as Json[]).find((x) => x.code === 'ENTRY_EFFECT')!.entryDisplay).toBe(
      'HALF_SCREEN',
    );

    // The app's catalogue.
    const u = await p.signup();
    const tiers = await ctx.http.get('/api/v1/vip/tiers').set(auth(u)).set('Accept-Language', 'ar');
    expectContract(tiers, 'listVipTiers');
    const perks = (
      tiers.body.data as { id: string; perks: { code: string; entryDisplay: string | null }[] }[]
    ).find((t) => t.id === VIP1)!.perks;
    expect(perks.find((x) => x.code === 'ENTRY_EFFECT')!.entryDisplay).toBe('HALF_SCREEN');
  });
});
