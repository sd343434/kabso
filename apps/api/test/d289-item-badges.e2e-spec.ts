/**
 * D289 (owner 2026-11-06; contract v1.79-live, CONVENTIONS §10.102): gift and store badges as a set — the panel sets
 * them on gifts and store items (one rule: «بمؤثرات صوتية» and «بدون مؤثرات صوتية» never together, 400
 * `ITEM_BADGES_INVALID`), «جديد» ends after 14 days or on the owner's date, «لفترة محدودة» / «موسمي» on the owner's date
 * and only the badge goes (the gift stays listed, the item stays on sale), the uploads answer what the panel pre-selects
 * (`hasAudio`, `fullscreen`), the deprecated `badge` / `isNew` stay in step, lucky gifts read as before. End to end
 * against PostgreSQL + Redis with the API as the DML-only runtime role, storage in memory, the clock faked.
 */
import { randomUUID } from 'node:crypto';
import { deflateSync } from 'node:zlib';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { mp3 } from './helpers/mp3.js';
import { mp4 } from './helpers/mp4.js';
import { expectContract, openapi } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const BASE = 'https://media.example.test';
const DAY = 86_400_000;

/** A protobuf varint / length-delimited field / float field, for a small SVGA 2.x movie. */
const varint = (n: number) => {
  const out: number[] = [];
  do {
    out.push((n & 0x7f) | (n > 0x7f ? 0x80 : 0));
    n = Math.floor(n / 128);
  } while (n > 0);
  return Buffer.from(out);
};
const field = (n: number, payload: Buffer) =>
  Buffer.concat([varint(n * 8 + 2), varint(payload.length), payload]);
const float = (n: number, value: number) => {
  const b = Buffer.alloc(4);
  b.writeFloatLE(value);
  return Buffer.concat([varint(n * 8 + 5), b]);
};
const svga = (w: number, h: number, audio: boolean) =>
  deflateSync(
    Buffer.concat([
      field(1, Buffer.from('2.0.0')),
      field(2, Buffer.concat([float(1, w), float(2, h)])),
      ...(audio ? [field(5, field(1, Buffer.from('sound_1')))] : []),
    ]),
  );

interface Badge {
  code: string;
  until: string | null;
  active?: boolean;
}
interface CatalogueGift {
  code: string;
  category: string;
  badge: string;
  badges: Badge[];
}

describe('D289 contract', () => {
  it('declares the nine badges in the display priority and the new fields', () => {
    const spec = openapi as unknown as {
      components: { schemas: Record<string, { enum?: string[]; required?: string[] }> };
    };
    const s = spec.components.schemas;
    expect(s.ItemBadgeCode?.enum).toEqual([
      'LIMITED',
      'NEW',
      'SEASONAL',
      'EXCLUSIVE',
      'MOST_WANTED',
      'FEATURED',
      'FULLSCREEN',
      'SOUND',
      'NO_SOUND',
    ]);
    expect(s.Gift?.required).toContain('badges');
    expect(s.StoreItem?.required).toContain('badges');
    expect(s.AdminStoreItem?.required).toContain('badges');
    expect(s.AdminStoreUpload?.required).toEqual(expect.arrayContaining(['hasAudio', 'fullscreen']));
  });
});

describe('D289 gift and store badges', { timeout: 600_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let viewer: Person;

  const auth = (u: Person) => ({ Authorization: `Bearer ${u.token}` });
  const catalogue = async (lang = 'en') => {
    const res = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(viewer)).set('Accept-Language', lang);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getGiftCatalogue');
    return res.body as { version: string; data: CatalogueGift[] };
  };
  const adminGifts = async () => {
    const res = await p.send(owner, 'get', '/admin/gifts');
    expect(res.status).toBe(200);
    expectContract(res, 'listAdminGifts');
    return res.body.data as (CatalogueGift & { lucky: boolean })[];
  };
  const giftUpload = (kind: string, code: string, body: Buffer) =>
    ctx.http
      .post(`/api/v1/admin/gift-uploads?kind=${kind}&code=${code}`)
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(body);
  const storeUpload = (kind: 'animation' | 'still', body: Buffer) =>
    ctx.http
      .post(`/api/v1/admin/store/uploads?kind=${kind}`)
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(body);
  const png = () =>
    sharp({ create: { width: 128, height: 128, channels: 4, background: '#e1122d' } })
      .png()
      .toBuffer();
  const newGift = async (code: string, body: Record<string, unknown>) => {
    const image = await giftUpload('image', code, await png());
    expect(image.status, JSON.stringify(image.body)).toBe(201);
    return p.send(owner, 'post', '/admin/gifts', {
      code,
      category: 'POPULAR',
      nameAr: `هدية ${code}`,
      nameEn: `Gift ${code}`,
      priceCoins: 10,
      imageObjectKey: image.body.key,
      reason: 'owner D289',
      ...body,
    });
  };
  const iso = (ms: number) => new Date(p.now() + ms).toISOString();
  /** Moves the clock on by days: the panel session and the viewer's token are signed in again. */
  const later = async (ms: number) => {
    p.advance(ms);
    owner = await p.makeAdmin(['OWNER']);
    viewer = await p.signup();
  };

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
        LUCKY_GIFTS_ENABLED: 'true',
      },
      [{ token: OBJECT_STORAGE, value: storage }],
    );
    owner = await p.makeAdmin(['OWNER']);
    viewer = await p.signup();
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the uploads answer what the panel pre-selects: sound and a full-screen frame (MP4, SVGA, MP3)', async () => {
    const loud = await giftUpload(
      'animation',
      'fx_d289',
      mp4({ durationMs: 3000, width: 720, height: 1280 }),
    );
    expect(loud.status, JSON.stringify(loud.body)).toBe(201);
    expectContract(loud, 'uploadAdminGiftFile');
    expect(loud.body).toMatchObject({ format: 'MP4', hasAudio: true, fullscreen: true });
    const quiet = await giftUpload(
      'animation',
      'fx_d289',
      mp4({ durationMs: 3000, width: 800, height: 800, sound: false }),
    );
    expect(quiet.body).toMatchObject({ format: 'MP4', hasAudio: false, fullscreen: false });
    // Side by side: the picture is half the file's width (720 × 1280 → portrait, full screen).
    const sbs = await giftUpload(
      'animation',
      'fx_d289',
      mp4({ durationMs: 3000, width: 2560, height: 1280, sound: false }),
    );
    expect(sbs.body).toMatchObject({ detectedAlpha: 'SIDE_BY_SIDE', fullscreen: false });
    const movie = await giftUpload('animation', 'fx_d289', svga(750, 1334, true));
    expect(movie.status, JSON.stringify(movie.body)).toBe(201);
    expectContract(movie, 'uploadAdminGiftFile');
    expect(movie.body).toMatchObject({
      format: 'SVGA',
      width: 750,
      height: 1334,
      hasAudio: true,
      fullscreen: true,
    });
    const small = await giftUpload('animation', 'fx_d289', svga(300, 300, false));
    expect(small.body).toMatchObject({ format: 'SVGA', hasAudio: false, fullscreen: false });
    const sound = await giftUpload('sound', 'fx_d289', mp3({ durationMs: 2000 }));
    expect(sound.status, JSON.stringify(sound.body)).toBe(201);
    expect(sound.body.hasAudio).toBe(true);

    const store = await storeUpload('animation', svga(750, 1334, false));
    expect(store.status, JSON.stringify(store.body)).toBe(201);
    expectContract(store, 'uploadAdminStoreArt');
    expect(store.body).toMatchObject({ format: 'SVGA', hasAudio: false, fullscreen: true });
    const storeVideo = await storeUpload('animation', mp4({ durationMs: 3000, width: 1080, height: 1920 }));
    expect(storeVideo.body).toMatchObject({ format: 'MP4', hasAudio: true, fullscreen: true });
    const still = await storeUpload('still', await png());
    expect(still.body).toMatchObject({ hasAudio: null, fullscreen: null });
  });

  it("sets a gift's badges; refuses the two sound badges and broken ends with 400, changing nothing", async () => {
    const created = await newGift('d289_rose', {
      badges: [
        { code: 'SOUND' },
        { code: 'NEW' },
        { code: 'LIMITED', until: iso(3 * DAY) },
        { code: 'FULLSCREEN' },
      ],
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    expectContract(created, 'createAdminGift');

    const row = (await catalogue()).data.find((g) => g.code === 'd289_rose')!;
    expect(row.badge).toBe('NEW');
    expect(row.badges.map((b) => b.code)).toEqual(['LIMITED', 'NEW', 'FULLSCREEN', 'SOUND']);
    expect(row.badges.find((b) => b.code === 'NEW')?.until).toBe(iso(14 * DAY));
    expect(row.badges.find((b) => b.code === 'SOUND')?.until).toBeNull();

    const before = await ctx.prisma.gift.findUniqueOrThrow({ where: { code: 'd289_rose' } });
    const both = await p.send(owner, 'patch', '/admin/gifts/d289_rose', {
      badges: [{ code: 'SOUND' }, { code: 'NO_SOUND' }],
      reason: 'both',
    });
    expect(both.status, JSON.stringify(both.body)).toBe(400);
    expectContract(both, 'updateAdminGift');
    expect(both.body.error).toMatchObject({
      code: 'ITEM_BADGES_INVALID',
      details: [{ field: 'badges', issue: 'sound_exclusive' }],
    });
    const noEnd = await p.send(owner, 'patch', '/admin/gifts/d289_rose', {
      badges: [
        { code: 'LIMITED' },
        { code: 'SEASONAL', until: iso(-DAY) },
        { code: 'FEATURED', until: iso(DAY) },
      ],
      reason: 'ends',
    });
    expect(noEnd.status).toBe(400);
    expect(noEnd.body.error.details).toEqual([
      { field: 'badges[0].until', issue: 'until_required' },
      { field: 'badges[1].until', issue: 'until_past' },
      { field: 'badges[2].until', issue: 'until_not_allowed' },
    ]);
    const createdBoth = await newGift('d289_both', { badges: [{ code: 'NO_SOUND' }, { code: 'SOUND' }] });
    expect(createdBoth.status).toBe(400);
    expect(createdBoth.body.error.code).toBe('ITEM_BADGES_INVALID');
    expect(await ctx.prisma.gift.findUnique({ where: { code: 'd289_both' } })).toBeNull();
    const legacyAndSet = await p.send(owner, 'patch', '/admin/gifts/d289_rose', {
      badge: 'NEW',
      badges: [],
      reason: 'x',
    });
    expect(legacyAndSet.status).toBe(400);
    expect(legacyAndSet.body.error).toMatchObject({ code: 'VALIDATION_FAILED' });
    const unknown = await p.send(owner, 'patch', '/admin/gifts/d289_rose', {
      badges: [{ code: 'HOT' }],
      reason: 'x',
    });
    expect(unknown.status).toBe(400);
    expect(unknown.body.error.code).toBe('VALIDATION_FAILED');
    expect(await ctx.prisma.gift.findUniqueOrThrow({ where: { code: 'd289_rose' } })).toEqual(before);

    // The database holds the rule too.
    await withMigrationClient(async (db) => {
      await expect(
        db.gift.update({ where: { code: 'd289_rose' }, data: { badges: ['SOUND', 'NO_SOUND'] } }),
      ).rejects.toThrow();
      await expect(
        db.gift.update({
          where: { code: 'd289_rose' },
          data: { badges: ['LIMITED'], badgeLimitedUntil: null },
        }),
      ).rejects.toThrow();
    });

    // A change is audited with the set as text; the panel lists every stored badge.
    const changed = await p.send(owner, 'patch', '/admin/gifts/d289_rose', {
      badges: [{ code: 'NO_SOUND' }, { code: 'MOST_WANTED' }],
      reason: 'silent now',
    });
    expect(changed.status, JSON.stringify(changed.body)).toBe(200);
    expect(changed.body.changed).toEqual(expect.arrayContaining(['badges', 'badge']));
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'gift.update', targetId: 'd289_rose' },
      orderBy: { createdAt: 'desc' },
    });
    expect(audit.metadata).toMatchObject({
      changes: {
        badges: {
          from: `LIMITED@${iso(3 * DAY)},NEW@${iso(14 * DAY)},FULLSCREEN,SOUND`,
          to: 'MOST_WANTED,NO_SOUND',
        },
        badge: { from: 'NEW', to: 'NONE' },
      },
      reason: 'silent now',
      via: 'panel',
    });
    const listed = (await adminGifts()).find((g) => g.code === 'd289_rose')!;
    expect(listed.badges).toEqual([
      { code: 'MOST_WANTED', until: null, active: true },
      { code: 'NO_SOUND', until: null, active: true },
    ]);
  });

  it('a timed badge ends by itself — only the badge goes; the gift stays listed and the version changes', async () => {
    const res = await newGift('d289_cake', {
      badges: [
        { code: 'NEW', until: iso(2 * DAY) },
        { code: 'SEASONAL', until: iso(5 * DAY) },
        { code: 'EXCLUSIVE' },
      ],
    });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const v0 = await catalogue();
    expect(v0.data.find((g) => g.code === 'd289_cake')).toMatchObject({
      badge: 'NEW',
      badges: [
        { code: 'NEW', until: iso(2 * DAY) },
        { code: 'SEASONAL', until: iso(5 * DAY) },
        { code: 'EXCLUSIVE', until: null },
      ],
    });
    const start = p.now();
    await later(2 * DAY + 1000);
    const v1 = await catalogue();
    expect(v1.version).not.toBe(v0.version);
    expect(v1.data.find((g) => g.code === 'd289_cake')).toMatchObject({
      badge: 'EVENT',
      badges: [
        { code: 'SEASONAL', until: new Date(start + 5 * DAY).toISOString() },
        { code: 'EXCLUSIVE', until: null },
      ],
    });
    await later(3 * DAY);
    const v2 = await catalogue();
    expect(v2.data.find((g) => g.code === 'd289_cake')).toMatchObject({
      badge: 'NONE',
      badges: [{ code: 'EXCLUSIVE', until: null }],
    });
    // The panel still has the ended ones (not shown).
    const listed = (await adminGifts()).find((g) => g.code === 'd289_cake')!;
    expect(listed.badges.map((b) => [b.code, b.active])).toEqual([
      ['NEW', false],
      ['SEASONAL', false],
      ['EXCLUSIVE', true],
    ]);
    // Re-saving without the ended ones works; an ended end sent back is refused.
    const again = await p.send(owner, 'patch', '/admin/gifts/d289_cake', {
      badges: [{ code: 'NEW', until: new Date(start + 2 * DAY).toISOString() }],
      reason: 'x',
    });
    expect(again.status).toBe(400);
    expect(again.body.error.details).toEqual([{ field: 'badges[0].until', issue: 'until_past' }]);
  });

  it('the deprecated single badge stays in step; lucky gifts read as before', async () => {
    // The older panel / CLI value: NEW gets 14 days, EVENT a «موسمي» without an end, NONE takes both off.
    expect((await newGift('d289_old', { badge: 'NEW' })).status).toBe(201);
    let row = (await catalogue()).data.find((g) => g.code === 'd289_old')!;
    expect(row).toMatchObject({ badge: 'NEW', badges: [{ code: 'NEW', until: iso(14 * DAY) }] });
    await p.send(owner, 'patch', '/admin/gifts/d289_old', {
      badges: [{ code: 'SOUND' }, { code: 'NEW' }],
      reason: 'x',
    });
    await p.send(owner, 'patch', '/admin/gifts/d289_old', { badge: 'EVENT', reason: 'x' });
    row = (await catalogue()).data.find((g) => g.code === 'd289_old')!;
    expect(row).toMatchObject({
      badge: 'EVENT',
      badges: [
        { code: 'SEASONAL', until: null },
        { code: 'SOUND', until: null },
      ],
    });
    expect(await ctx.prisma.gift.findUniqueOrThrow({ where: { code: 'd289_old' } })).toMatchObject({
      badge: 'EVENT',
      badges: ['SEASONAL', 'SOUND'],
      badgeSeasonalUntil: null,
    });

    // A lucky gift without badges is exactly what it was; with the old NEW it reads NEW.
    expect((await newGift('d289_lucky', { category: 'LUCKY' })).status).toBe(201);
    expect((await newGift('d289_lucky_new', { category: 'LUCKY', badge: 'NEW' })).status).toBe(201);
    const data = (await catalogue()).data;
    expect(data.find((g) => g.code === 'd289_lucky')).toMatchObject({
      category: 'LUCKY',
      badge: 'NONE',
      badges: [],
    });
    expect(data.find((g) => g.code === 'd289_lucky_new')).toMatchObject({ category: 'LUCKY', badge: 'NEW' });
    expect((await adminGifts()).find((g) => g.code === 'd289_lucky')).toMatchObject({
      lucky: true,
      badges: [],
    });
  });

  it('store items: badges set, «جديد» ends after 14 days, the item stays on sale; isNew in step', async () => {
    const still = await storeUpload('still', await png());
    const base = {
      kind: 'AVATAR_FRAME',
      still: still.body.url,
      prices: [{ currency: 'COINS', days: 7, amount: 50_000 }],
      enabled: true,
      reason: 'owner D289',
    };
    const both = await p.send(owner, 'post', '/admin/store/items', {
      ...base,
      nameAr: 'إطار',
      nameEn: 'Frame',
      badges: [{ code: 'SOUND' }, { code: 'NO_SOUND' }],
    });
    expect(both.status, JSON.stringify(both.body)).toBe(400);
    expectContract(both, 'createAdminStoreItem');
    expect(both.body.error).toMatchObject({
      code: 'ITEM_BADGES_INVALID',
      details: [{ field: 'badges', issue: 'sound_exclusive' }],
    });
    const created = await p.send(owner, 'post', '/admin/store/items', {
      ...base,
      nameAr: 'إطار العرض',
      nameEn: 'Offer frame',
      badges: [
        { code: 'NEW' },
        { code: 'MOST_WANTED' },
        { code: 'LIMITED', until: iso(20 * DAY) },
        { code: 'SOUND' },
      ],
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    expectContract(created, 'createAdminStoreItem');
    expect(created.body).toMatchObject({ isNew: true });
    expect(created.body.badges.map((b: Badge) => b.code)).toEqual(['LIMITED', 'NEW', 'MOST_WANTED', 'SOUND']);
    const id = created.body.id as string;
    const legacy = await p.send(owner, 'post', '/admin/store/items', {
      ...base,
      nameAr: 'إطار قديم',
      nameEn: 'Old frame',
      isNew: true,
    });
    expect(legacy.status).toBe(201);
    expect(legacy.body.badges).toEqual([{ code: 'NEW', until: iso(14 * DAY), active: true }]);
    const conflict = await p.send(owner, 'patch', `/admin/store/items/${id}`, {
      isNew: false,
      badges: [],
      reason: 'x',
    });
    expect(conflict.status).toBe(400);
    expect(conflict.body.error.code).toBe('VALIDATION_FAILED');

    const list = async () => {
      const res = await ctx.http.get('/api/v1/store/items').set(auth(viewer));
      expect(res.status).toBe(200);
      expectContract(res, 'listStoreItems');
      return (res.body.data as { id: string; isNew: boolean; badges: Badge[] }[]).find((i) => i.id === id);
    };
    expect(await list()).toMatchObject({
      isNew: true,
      badges: [
        { code: 'LIMITED', until: iso(20 * DAY) },
        { code: 'NEW', until: iso(14 * DAY) },
        { code: 'MOST_WANTED', until: null },
        { code: 'SOUND', until: null },
      ],
    });
    await later(14 * DAY + 1000);
    const after14 = await list();
    expect(after14?.isNew).toBe(false);
    expect(after14?.badges.map((b) => b.code)).toEqual(['LIMITED', 'MOST_WANTED', 'SOUND']);
    await later(7 * DAY);
    const ended = await list();
    // Still on sale (listed), only the badges with an end are gone.
    expect(ended?.badges.map((b) => b.code)).toEqual(['MOST_WANTED', 'SOUND']);
    const admin = await p.send(owner, 'get', '/admin/store/items');
    expectContract(admin, 'listAdminStoreItems');
    const row = (admin.body.data as { id: string; isNew: boolean; badges: Badge[] }[]).find(
      (i) => i.id === id,
    )!;
    expect(row.isNew).toBe(true);
    expect(row.badges.map((b) => [b.code, b.active])).toEqual([
      ['LIMITED', false],
      ['NEW', false],
      ['MOST_WANTED', true],
      ['SOUND', true],
    ]);

    // The whole set replaced; the deprecated switch keeps the rest.
    const replaced = await p.send(owner, 'patch', `/admin/store/items/${id}`, {
      badges: [{ code: 'SEASONAL', until: iso(30 * DAY) }, { code: 'NO_SOUND' }],
      reason: 'season',
    });
    expect(replaced.status, JSON.stringify(replaced.body)).toBe(200);
    expectContract(replaced, 'updateAdminStoreItem');
    expect(replaced.body).toMatchObject({ isNew: false });
    p.advance(1000);
    const flipped = await p.send(owner, 'patch', `/admin/store/items/${id}`, {
      isNew: true,
      reason: 'new again',
    });
    expect(flipped.body.badges.map((b: Badge) => b.code)).toEqual(['NEW', 'SEASONAL', 'NO_SOUND']);
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'store.item.update', targetId: id },
      orderBy: { createdAt: 'desc' },
    });
    expect(audit.metadata).toMatchObject({
      before: { badges: `SEASONAL@${iso(30 * DAY - 1000)},NO_SOUND`, isNew: false },
      after: { badges: `NEW@${iso(14 * DAY)},SEASONAL@${iso(30 * DAY - 1000)},NO_SOUND`, isNew: true },
    });
  });

  it('D289b «حذف»: never bought → deleted with its art; bought → hidden, kept by its owner; restore; audit; 403', async () => {
    const pic = async (colour: string) => {
      const still = await storeUpload(
        'still',
        await sharp({ create: { width: 200, height: 200, channels: 4, background: colour } })
          .png()
          .toBuffer(),
      );
      expect(still.status).toBe(201);
      return still.body.url as string;
    };
    const add = async (nameEn: string, still: string) => {
      const res = await p.send(owner, 'post', '/admin/store/items', {
        kind: 'AVATAR_FRAME',
        nameAr: nameEn,
        nameEn,
        still,
        prices: [{ currency: 'COINS', days: 7, amount: 1_000 }],
        enabled: true,
        reason: 'D289b',
      });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      return res.body as { id: string; code: string };
    };
    const keyOf = (url: string) => url.slice(url.indexOf('media/store/'));
    const mistakeArt = await pic('#123456');
    const mistake = await add('Mistake', mistakeArt);
    const sharedArt = await pic('#654321');
    const shared1 = await add('Shared one', sharedArt);
    const shared2 = await add('Shared two', sharedArt);
    const sold = await add('Sold', await pic('#abcdef'));

    // Capability: SUPPORT reads the store but cannot delete.
    const support = await p.makeAdmin(['SUPPORT']);
    const refused = await ctx.http
      .delete(`/api/v1/admin/store/items/${mistake.id}`)
      .set('Cookie', support.cookie)
      .set('X-CSRF-Token', support.csrf);
    expect(refused.status).toBe(403);

    // Never bought, nobody holds it: deleted for real, its own art too (no body: the reason is optional).
    const gone = await ctx.http
      .delete(`/api/v1/admin/store/items/${mistake.id}`)
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf);
    expect(gone.status, JSON.stringify(gone.body)).toBe(200);
    expectContract(gone, 'deleteAdminStoreItem');
    expect(gone.body).toMatchObject({
      result: 'DELETED',
      id: mistake.id,
      owners: 0,
      purchases: 0,
      item: null,
    });
    expect(await ctx.prisma.storeItem.findUnique({ where: { id: mistake.id } })).toBeNull();
    expect(await ctx.prisma.bagItem.findUnique({ where: { code: mistake.code } })).toBeNull();
    expect(await storage.head(keyOf(mistakeArt))).toBeNull();
    const deletedAudit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'store.item.delete', targetId: mistake.id },
    });
    expect(deletedAudit.actorUserId).toBe(owner.id);
    expect(deletedAudit.metadata).toMatchObject({ case: 'deleted', code: mistake.code, via: 'panel' });
    // A file another item still uses stays.
    expect(
      (await p.send(owner, 'patch', '/admin/store/items/' + shared1.id, { nameEn: 'S1', reason: 'x' }))
        .status,
    ).toBe(200);
    const del1 = await ctx.http
      .delete(`/api/v1/admin/store/items/${shared1.id}`)
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .send({ reason: 'added twice' });
    expect(del1.body.result).toBe('DELETED');
    expect(await storage.head(keyOf(sharedArt))).not.toBeNull();
    expect(
      (
        await ctx.prisma.auditLog.findFirstOrThrow({
          where: { action: 'store.item.delete', targetId: shared1.id },
        })
      ).metadata,
    ).toMatchObject({ reason: 'added twice' });
    expect(shared2.id).toBeTruthy();

    // Bought by someone: hidden, never sold again, kept by its owner.
    await ctx.prisma.$transaction((tx) => creditIn(tx, viewer.id, 10_000n, 'ADMIN_GRANT', randomUUID()));
    const buy = (key = randomUUID()) =>
      ctx.http
        .post('/api/v1/me/store/purchases')
        .set('Authorization', `Bearer ${viewer.token}`)
        .set('Idempotency-Key', key)
        .send({ itemId: sold.id, currency: 'COINS', days: 7, price: 1_000 });
    expect((await buy()).status).toBe(201);
    const hid = await ctx.http
      .delete(`/api/v1/admin/store/items/${sold.id}`)
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .send({});
    expect(hid.status, JSON.stringify(hid.body)).toBe(200);
    expectContract(hid, 'deleteAdminStoreItem');
    expect(hid.body).toMatchObject({ result: 'HIDDEN', owners: 1, purchases: 1, item: { enabled: false } });
    expect(hid.body.item.hiddenAt).toBeTruthy();
    expect(
      (
        await ctx.prisma.auditLog.findFirstOrThrow({
          where: { action: 'store.item.hide', targetId: sold.id },
        })
      ).metadata,
    ).toMatchObject({ case: 'hidden', owners: 1, purchases: 1, wasEnabled: true, via: 'panel' });
    const listed = await ctx.http.get('/api/v1/store/items').set('Authorization', `Bearer ${viewer.token}`);
    expect((listed.body.data as { id: string }[]).map((i) => i.id)).not.toContain(sold.id);
    const again = await buy();
    expect(again.status).toBe(409);
    expect(again.body.error).toMatchObject({
      code: 'STORE_UNAVAILABLE',
      details: [{ field: 'item', issue: 'item_off' }],
    });
    const bag = await ctx.http.get('/api/v1/me/bag').set('Authorization', `Bearer ${viewer.token}`);
    expect(bag.status).toBe(200);
    const mine = (bag.body.data as { code: string; art?: { still: string | null } }[]).find(
      (b) => b.code === sold.code,
    );
    expect(mine?.art?.still).toBeTruthy();
    const catalogue = await ctx.http
      .get('/api/v1/bag/catalogue')
      .set('Authorization', `Bearer ${viewer.token}`);
    expect((catalogue.body.data as { code: string }[]).map((b) => b.code)).not.toContain(sold.code);
    expect((catalogue.body.data as { code: string }[]).map((b) => b.code)).toContain(shared2.code);
    // Deleting again changes nothing; switching it on is refused; restore puts it back.
    const twice = await ctx.http
      .delete(`/api/v1/admin/store/items/${sold.id}`)
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf);
    expect(twice.body.result).toBe('HIDDEN');
    expect(await ctx.prisma.auditLog.count({ where: { action: 'store.item.hide', targetId: sold.id } })).toBe(
      1,
    );
    const on = await p.send(owner, 'post', `/admin/store/items/${sold.id}/enable`, { reason: 'x' });
    expect(on.status).toBe(409);
    const restored = await p.send(owner, 'post', `/admin/store/items/${sold.id}/restore`, {});
    expect(restored.status, JSON.stringify(restored.body)).toBe(200);
    expectContract(restored, 'restoreAdminStoreItem');
    expect(restored.body).toMatchObject({ hiddenAt: null, enabled: true });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'store.item.restore', targetId: sold.id } }),
    ).toBe(1);
    const back = await ctx.http.get('/api/v1/store/items').set('Authorization', `Bearer ${viewer.token}`);
    expect((back.body.data as { id: string }[]).map((i) => i.id)).toContain(sold.id);
    const supportRestore = await p.send(support, 'post', `/admin/store/items/${sold.id}/restore`, {});
    expect(supportRestore.status).toBe(403);
  });
});
