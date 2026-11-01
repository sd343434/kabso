/**
 * D207 (owner 2026-10-31; contract v1.46-live / v1.71-social, CONVENTIONS §10.66): gift categories managed in the
 * admin panel (add, rename / reorder / icon, on / off, delete — refused while gifts are in it unless they are moved
 * first; LUCKY / QUIPS only renamed or reordered), the app's tabs from the API, and uploading a gift's files from the
 * panel (the picture, an SVGA or MP4 effect — plain or side-by-side alpha — and an MP3 sound), each change audited
 * with the reason. End to end against PostgreSQL + Redis, the API as the DML-only runtime role, storage in memory.
 */
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { deflateSync } from 'node:zlib';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { mp3 } from './helpers/mp3.js';
import { mp4 } from './helpers/mp4.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const run = promisify(execFile);
const cli = (args: string[]) =>
  run('node', ['--import', 'tsx', 'src/cli/gift-admin.ts', ...args], {
    env: { ...process.env, DOTENV_CONFIG_QUIET: 'true' },
  });

const COOKIE = '__Host-kabso_admin';
const BASE = 'https://media.example.test';

const D207_OPS = [
  'listAdminGiftCategories',
  'createAdminGiftCategory',
  'updateAdminGiftCategory',
  'enableAdminGiftCategory',
  'disableAdminGiftCategory',
  'removeAdminGiftCategory',
  'uploadAdminGiftFile',
  'getAdminGiftFile',
];

interface Admin {
  id: string;
  email: string;
  password: string;
  secret: string;
  cookie: string;
  csrf: string;
}

const png = (w: number, h: number) =>
  sharp({ create: { width: w, height: h, channels: 4, background: { r: 230, g: 60, b: 120, alpha: 1 } } })
    .png()
    .toBuffer();
/** A minimal SVGA 2.x movie: zlib(protobuf MovieEntity { version: "2.0.0" }). */
const svga = () => deflateSync(Buffer.concat([Buffer.from([0x0a, 0x05]), Buffer.from('2.0.0')]));

describe('D207 contract coverage', () => {
  it('openapi v1.71-social declares the category and upload operations, each with the admin session and CSRF', () => {
    const mine = operations().filter((o) =>
      (typeof o.spec.description === 'string' ? o.spec.description : '').startsWith('(v1.71-social, D207)'),
    );
    expect(mine.map((o) => o.operationId).sort()).toEqual([...D207_OPS].sort());
    for (const o of mine) {
      expect(o.spec.security).toEqual([{ adminSession: [] }]);
      if (o.method !== 'get') expect(JSON.stringify(o.spec.parameters), o.operationId).toContain('AdminCsrf');
    }
  });
});

describe('D207 gift categories and gift files in the panel', { timeout: 600_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  let clock = Date.now();
  const nextCode = (secret: string) => {
    clock += 30_000;
    vi.setSystemTime(clock);
    return totpCode(secret, clock);
  };
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const { res, payload } = await registerVerified(ctx);
    const email = payload.email;
    const password = payload.password;
    await withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, email, role as never));
    });
    const login = await ctx.http.post('/api/v1/admin/auth/login').send({ email, password });
    const pending = cookieOf(login);
    const csrf = login.body.csrfToken as string;
    const enrol = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf);
    const secret = enrol.body.secret as string;
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: nextCode(secret) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return {
      id: res.body.user.id as string,
      email,
      password,
      secret,
      cookie: cookieOf(confirm),
      csrf: confirm.body.session.csrfToken as string,
    };
  };
  const get = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const send = (method: 'post' | 'patch', a: Admin, path: string, body: object = {}) =>
    ctx.http[method](`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);
  const post = (a: Admin, path: string, body: object = {}) => send('post', a, path, body);
  const upload = (a: Admin, kind: string, code: string, body: Buffer, csrf = true) => {
    const req = ctx.http
      .post(`/api/v1/admin/gift-uploads?kind=${kind}&code=${code}`)
      .set('Cookie', a.cookie)
      .set('Content-Type', 'application/octet-stream');
    return (csrf ? req.set('X-CSRF-Token', a.csrf) : req).send(body);
  };
  const lastAudit = async (action: string, targetId: string) => {
    const rows = await ctx.prisma.auditLog.findMany({
      where: { action, targetId },
      orderBy: { createdAt: 'asc' },
    });
    expect(rows.length, action).toBeGreaterThan(0);
    return rows[rows.length - 1]!;
  };
  /** The panel change's audit row with this reason (Date is frozen, so rows may share a timestamp). */
  const expectPanelAudit = async (action: string, targetId: string, actor: Admin, reason: string) => {
    const rows = await ctx.prisma.auditLog.findMany({ where: { action, targetId } });
    const row = rows.find((r) => (r.metadata as Record<string, unknown>).reason === reason);
    expect(row, `${action} ${targetId} ${reason}`).toBeDefined();
    expect(row!.actorUserId).toBe(actor.id);
    const meta = row!.metadata as Record<string, unknown>;
    expect(meta.via).toBe('panel');
    return meta;
  };
  const catalogue = (lang: 'ar' | 'en') =>
    ctx.http
      .get('/api/v1/gifts/catalogue')
      .set('Authorization', `Bearer ${viewerToken}`)
      .set('Accept-Language', lang);

  let owner: Admin;
  let support: Admin;
  let finance: Admin;
  let viewerToken: string;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_SESSION_IDLE_SECONDS: '3600',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        MEDIA_PUBLIC_BASE_URL: BASE,
        LUCKY_GIFTS_ENABLED: 'true',
      },
      [{ token: OBJECT_STORAGE, value: storage }],
    );
    owner = await makeAdmin(['OWNER']);
    support = await makeAdmin(['SUPPORT']);
    finance = await makeAdmin(['FINANCE']);
    viewerToken = (await registerVerified(ctx)).res.body.tokens.accessToken as string;
  });

  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the five seeded categories, in the old tab order with the app names; read with catalog.view', async () => {
    const res = await get(support, '/admin/gift-categories');
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listAdminGiftCategories');
    expect(res.body.data.map((c: { code: string }) => c.code)).toEqual([
      'POPULAR',
      'EVENT',
      'FUN',
      'LUCKY',
      'QUIPS',
    ]);
    expect(res.body.data.map((c: { nameAr: string }) => c.nameAr)).toEqual([
      'شائعة',
      'مناسبات',
      'مرح',
      'الحظ',
      'إفيهات',
    ]);
    expect(
      res.body.data.filter((c: { special: boolean }) => c.special).map((c: { kind: string }) => c.kind),
    ).toEqual(['LUCKY', 'QUIPS']);
    // gifts.categories is OWNER only: support / finance are refused before anything changes.
    const body = { code: 'SPORTS', nameAr: 'رياضة', nameEn: 'Sports', reason: 'x' };
    expect((await post(support, '/admin/gift-categories', body)).status).toBe(403);
    expect((await post(finance, '/admin/gift-categories', body)).status).toBe(403);
    expect((await get(finance, '/admin/auth/session')).body.capabilities).not.toContain('gifts.categories');
    expect((await get(owner, '/admin/auth/session')).body.capabilities).toContain('gifts.categories');
    expect(await ctx.prisma.giftCategory.count({ where: { code: 'SPORTS' } })).toBe(0);
  });

  it('add, rename / reorder, turn off and on a category — each audited with the reason; the app tabs follow', async () => {
    const created = await post(owner, '/admin/gift-categories', {
      code: 'SPORTS',
      nameAr: 'رياضة',
      nameEn: 'Sports',
      sortOrder: 5,
      reason: 'world cup',
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    expectContract(created, 'createAdminGiftCategory');
    await expectPanelAudit('gift.category.add', 'SPORTS', owner, 'world cup');
    const again = await post(owner, '/admin/gift-categories', {
      code: 'SPORTS',
      nameAr: 'a',
      nameEn: 'b',
      reason: 'x',
    });
    expect(again.status).toBe(409);
    expect(
      (await post(owner, '/admin/gift-categories', { code: 'sports', nameAr: 'a', nameEn: 'b', reason: 'x' }))
        .status,
    ).toBe(400);
    expect(
      (await post(owner, '/admin/gift-categories', { code: 'NOREASON', nameAr: 'a', nameEn: 'b' })).status,
    ).toBe(400);
    // A gift in it, so the app lists the tab.
    await ctx.prisma.gift.create({
      data: {
        code: 'd207_ball',
        category: 'SPORTS',
        nameAr: 'كرة',
        nameEn: 'Ball',
        priceCoins: 10,
        assetKey: 'b',
      },
    });
    let cat = await catalogue('ar');
    expect(cat.status).toBe(200);
    expectContract(cat, 'getGiftCatalogue');
    expect(cat.body.tabs[0]).toEqual({ code: 'SPORTS', kind: 'NORMAL', name: 'رياضة', iconUrl: null });
    expect(cat.body.categories).toEqual(cat.body.tabs.map((t: { code: string }) => t.code));
    expect(cat.body.categories).toEqual(['SPORTS', 'POPULAR', 'EVENT', 'FUN', 'LUCKY', 'QUIPS']);
    const v1 = cat.body.version as string;

    const icon = await upload(owner, 'icon', 'SPORTS', await png(96, 96));
    expect(icon.status, JSON.stringify(icon.body)).toBe(201);
    const upd = await send('patch', owner, '/admin/gift-categories/SPORTS', {
      nameEn: 'Sport',
      sortOrder: 60,
      iconObjectKey: icon.body.key,
      reason: 'rename',
    });
    expect(upd.status, JSON.stringify(upd.body)).toBe(200);
    expectContract(upd, 'updateAdminGiftCategory');
    expect(upd.body.changed.sort()).toEqual(['iconObjectKey', 'nameEn', 'sortOrder']);
    const meta = await expectPanelAudit('gift.category.update', 'SPORTS', owner, 'rename');
    expect(meta.changes).toMatchObject({
      nameEn: { from: 'Sports', to: 'Sport' },
      sortOrder: { from: 5, to: 60 },
    });
    cat = await catalogue('en');
    expect(cat.body.categories.at(-1)).toBe('SPORTS');
    expect(cat.body.tabs.at(-1)).toEqual({
      code: 'SPORTS',
      kind: 'NORMAL',
      name: 'Sport',
      iconUrl: `${BASE}/${icon.body.key}`,
    });
    expect(cat.body.version).not.toBe(v1);
    // An icon uploaded for another category is refused.
    const other = await upload(owner, 'icon', 'OTHER', await png(64, 64));
    expect(
      (
        await send('patch', owner, '/admin/gift-categories/SPORTS', {
          iconObjectKey: other.body.key,
          reason: 'x',
        })
      ).status,
    ).toBe(409);

    const off = await post(owner, '/admin/gift-categories/SPORTS/disable', { reason: 'off season' });
    expect(off.status).toBe(200);
    expectContract(off, 'disableAdminGiftCategory');
    expect(off.body).toEqual({ code: 'SPORTS', enabled: false, changed: true });
    await expectPanelAudit('gift.category.disable', 'SPORTS', owner, 'off season');
    cat = await catalogue('ar');
    expect(cat.body.categories).not.toContain('SPORTS');
    expect(cat.body.data.map((g: { code: string }) => g.code)).not.toContain('d207_ball');
    const on = await post(owner, '/admin/gift-categories/SPORTS/enable', { reason: 'back' });
    expect(on.body.changed).toBe(true);
    await expectPanelAudit('gift.category.enable', 'SPORTS', owner, 'back');
    expect((await catalogue('ar')).body.data.map((g: { code: string }) => g.code)).toContain('d207_ball');
    expect(
      (await send('patch', owner, '/admin/gift-categories/NOPE', { nameAr: 'x', reason: 'x' })).status,
    ).toBe(404);
  });

  it('LUCKY and QUIPS are renamed or reordered only — never turned off or deleted', async () => {
    const ren = await send('patch', owner, '/admin/gift-categories/LUCKY', {
      nameAr: 'حظ',
      reason: 'shorter',
    });
    expect(ren.status).toBe(200);
    expect(ren.body.changed).toEqual(['nameAr']);
    expect((await post(owner, '/admin/gift-categories/LUCKY/disable', { reason: 'x' })).status).toBe(409);
    const rm = await post(owner, '/admin/gift-categories/QUIPS/remove', { reason: 'x' });
    expect(rm.status).toBe(409);
    expect(rm.body.error?.message ?? JSON.stringify(rm.body)).toContain('special');
    expect(await ctx.prisma.giftCategory.count({ where: { code: { in: ['LUCKY', 'QUIPS'] } } })).toBe(2);
    expect((await catalogue('ar')).body.tabs.find((t: { code: string }) => t.code === 'LUCKY').name).toBe(
      'حظ',
    );
  });

  it('delete is refused while gifts are in it; «نقل الهدايا إلى تصنيف آخر ثم الحذف» moves them first', async () => {
    const refusedRes = await post(owner, '/admin/gift-categories/SPORTS/remove', { reason: 'cleanup' });
    expect(refusedRes.status).toBe(409);
    expect(JSON.stringify(refusedRes.body)).toContain('1 gift');
    expect(await ctx.prisma.giftCategory.count({ where: { code: 'SPORTS' } })).toBe(1);
    // Not into a special category, nor itself, nor a missing one.
    for (const moveTo of ['QUIPS', 'LUCKY', 'SPORTS', 'MISSING']) {
      expect(
        (await post(owner, '/admin/gift-categories/SPORTS/remove', { moveTo, reason: 'x' })).status,
        moveTo,
      ).toBe(409);
    }
    const moved = await post(owner, '/admin/gift-categories/SPORTS/remove', {
      moveTo: 'FUN',
      reason: 'cleanup',
    });
    expect(moved.status, JSON.stringify(moved.body)).toBe(200);
    expectContract(moved, 'removeAdminGiftCategory');
    expect(moved.body).toEqual({ code: 'SPORTS', removed: true, movedTo: 'FUN', movedGifts: ['d207_ball'] });
    const meta = await expectPanelAudit('gift.category.delete', 'SPORTS', owner, 'cleanup');
    expect(meta).toMatchObject({ movedTo: 'FUN', movedGifts: ['d207_ball'] });
    expect((await ctx.prisma.gift.findUnique({ where: { code: 'd207_ball' } }))?.category).toBe('FUN');
    expect(await ctx.prisma.giftCategory.count({ where: { code: 'SPORTS' } })).toBe(0);
    // An empty category is deleted without moving anything.
    await post(owner, '/admin/gift-categories', {
      code: 'EMPTY',
      nameAr: 'فارغ',
      nameEn: 'Empty',
      reason: 'x',
    });
    const gone = await post(owner, '/admin/gift-categories/EMPTY/remove', { reason: 'unused' });
    expect(gone.body).toEqual({ code: 'EMPTY', removed: true, movedTo: null, movedGifts: [] });
  });

  it('uploads: valid files are stored content-addressed; invalid ones refused with the reason, nothing stored', async () => {
    const before = storage.objects.size;
    const img = await upload(owner, 'image', 'd207_car', await png(256, 256));
    expect(img.status, JSON.stringify(img.body)).toBe(201);
    expectContract(img, 'uploadAdminGiftFile');
    expect(img.body).toMatchObject({ kind: 'image', contentType: 'image/png', width: 256, height: 256 });
    expect(img.body.key).toMatch(/^media\/gifts\/d207_car\/[0-9a-f]{32}\.png$/);
    expect(img.body.url).toBe(`${BASE}/${img.body.key}`);
    expect(storage.objects.get(img.body.key)?.contentType).toBe('image/png');

    const plain = await upload(
      owner,
      'animation',
      'd207_car',
      mp4({ durationMs: 5000, width: 720, height: 1280 }),
    );
    expect(plain.status, JSON.stringify(plain.body)).toBe(201);
    expectContract(plain, 'uploadAdminGiftFile');
    expect(plain.body).toMatchObject({
      format: 'MP4',
      detectedAlpha: 'NONE',
      width: 720,
      height: 1280,
      durationMs: 5000,
    });
    const sbs = await upload(
      owner,
      'animation',
      'd207_car',
      mp4({ durationMs: 4000, width: 1500, height: 750 }),
    );
    expect(sbs.body).toMatchObject({
      format: 'MP4',
      detectedAlpha: 'SIDE_BY_SIDE',
      contentType: 'video/mp4',
    });
    const sv = await upload(owner, 'animation', 'd207_car', svga());
    expect(sv.body).toMatchObject({ format: 'SVGA', contentType: 'application/octet-stream' });
    expect(sv.body.key).toMatch(/\.svga$/);
    const snd = await upload(owner, 'sound', 'd207_car', mp3({ durationMs: 3000 }));
    expect(snd.status, JSON.stringify(snd.body)).toBe(201);
    expect(snd.body.contentType).toBe('audio/mpeg');
    expect(snd.body.durationMs).toBeGreaterThan(2900);

    // The panel previews from its own origin: the bytes back with their type (catalog.view), never cached.
    const back = await get(
      finance,
      `/admin/gift-files?key=${encodeURIComponent(plain.body.key as string)}`,
    ).buffer(true);
    expect(back.status).toBe(200);
    expect(back.headers['content-type']).toMatch(/^video\/mp4/);
    expect(back.headers['cache-control']).toBe('no-store');
    expect(Buffer.compare(back.body as Buffer, storage.objects.get(plain.body.key as string)!.body)).toBe(0);
    expect(
      (await get(finance, `/admin/gift-files?key=${encodeURIComponent(snd.body.key as string)}`)).headers[
        'content-type'
      ],
    ).toMatch(/^audio\/mpeg/);
    expect((await get(finance, '/admin/gift-files?key=media%2Fposts%2Fx.png')).status).toBe(400);
    expect(
      (await get(finance, `/admin/gift-files?key=media%2Fgifts%2Fd207_car%2F${'0'.repeat(32)}.png`)).status,
    ).toBe(404);
    expect(
      (await ctx.http.get(`/api/v1/admin/gift-files?key=${encodeURIComponent(img.body.key as string)}`))
        .status,
    ).toBe(401);

    const stored = storage.objects.size;
    expect(stored - before).toBe(5);
    const bad: [string, Buffer, string][] = [
      [
        'image',
        await sharp(await png(256, 256))
          .jpeg()
          .toBuffer(),
        'PNG or WebP',
      ],
      ['image', await png(300, 200), 'square'],
      ['image', await png(100, 100), '128'],
      ['animation', mp4({ durationMs: 4000, codec: 'hvc1' }), 'H.264'],
      ['animation', mp4({ durationMs: 20_000 }), '15'],
      ['animation', Buffer.from('PK\u0003\u0004 a zip'), 'SVGA 1.x'],
      ['sound', mp3({ durationMs: 20_000 }), '15 s'],
      ['sound', Buffer.from('not an mp3 at all, really'), 'MP3'],
    ];
    for (const [kind, body, why] of bad) {
      const res = await upload(owner, kind, 'd207_car', body);
      expect(res.status, `${kind} ${why}`).toBe(409);
      expect(JSON.stringify(res.body), `${kind} ${why}`).toContain(why);
    }
    expect(storage.objects.size).toBe(stored);
    // Permissions and CSRF: support cannot upload; an icon needs gifts.categories; no CSRF → 403.
    expect((await upload(support, 'image', 'd207_car', await png(256, 256))).status).toBe(403);
    expect((await upload(owner, 'image', 'd207_car', await png(256, 256), false)).status).toBe(403);
    expect((await upload(owner, 'image', 'Bad Code', await png(256, 256))).status).toBe(400);
    expect((await upload(owner, 'video', 'd207_car', await png(256, 256))).status).toBe(400);
  });

  it('a gift with its picture, an MP4 effect of each kind and an MP3; the app sees format, transparency and sound', async () => {
    const img = (await upload(owner, 'image', 'd207_car', await png(256, 256))).body.key as string;
    const sbs = (
      await upload(owner, 'animation', 'd207_car', mp4({ durationMs: 4000, width: 1440, height: 720 }))
    ).body;
    const plain = (
      await upload(
        owner,
        'animation',
        'd207_car',
        mp4({ durationMs: 5000, width: 720, height: 1280, dataBytes: 777 }),
      )
    ).body;
    const sound = (await upload(owner, 'sound', 'd207_car', mp3({ durationMs: 3000 }))).body;
    const base = {
      code: 'd207_car',
      category: 'POPULAR',
      nameAr: 'سيارة',
      nameEn: 'Car',
      priceCoins: 900,
      reason: 'new',
    };
    // «صورة الهدية» is required.
    const noImage = await post(owner, '/admin/gifts', base);
    expect(noImage.status).toBe(400);
    // An MP4 needs its transparency.
    expect(
      (await post(owner, '/admin/gifts', { ...base, imageObjectKey: img, animationObjectKey: sbs.key }))
        .status,
    ).toBe(409);
    // A file uploaded for another gift.
    const foreign = (await upload(owner, 'image', 'd207_other', await png(200, 200))).body.key as string;
    expect((await post(owner, '/admin/gifts', { ...base, imageObjectKey: foreign })).status).toBe(409);
    // A key that was never stored.
    expect(
      (
        await post(owner, '/admin/gifts', {
          ...base,
          imageObjectKey: `media/gifts/d207_car/${'0'.repeat(32)}.png`,
        })
      ).status,
    ).toBe(409);
    const created = await post(owner, '/admin/gifts', {
      ...base,
      imageObjectKey: img,
      animationObjectKey: sbs.key,
      animationAlpha: sbs.detectedAlpha,
      audioObjectKey: sound.key,
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    const add = await expectPanelAudit('gift.add', 'd207_car', owner, 'new');
    expect(add).toMatchObject({
      animationFormat: 'MP4',
      animationAlpha: 'SIDE_BY_SIDE',
      audioObjectKey: sound.key,
    });
    let gift = (await catalogue('ar')).body.data.find((g: { code: string }) => g.code === 'd207_car');
    expect(gift).toMatchObject({
      assetKey: 'd207_car',
      imageUrl: `${BASE}/${img}`,
      animationUrl: `${BASE}/${sbs.key}`,
      animationFormat: 'MP4',
      animationAlpha: 'SIDE_BY_SIDE',
      animationBytes: sbs.bytes,
      audioUrl: `${BASE}/${sound.key}`,
      audioBytes: sound.bytes,
    });
    expect(gift.audioDurationMs).toBeGreaterThan(2900);

    // The plain kind: a video with its background, transparency NONE (the admin's choice is stored per gift).
    const toPlain = await send('patch', owner, '/admin/gifts/d207_car', {
      animationObjectKey: plain.key,
      animationAlpha: 'NONE',
      reason: 'plain video',
    });
    expect(toPlain.status, JSON.stringify(toPlain.body)).toBe(200);
    expect(toPlain.body.changed.sort()).toEqual(['animationAlpha', 'animationBytes', 'animationObjectKey']);
    gift = (await catalogue('ar')).body.data.find((g: { code: string }) => g.code === 'd207_car');
    expect(gift).toMatchObject({
      animationFormat: 'MP4',
      animationAlpha: 'NONE',
      animationUrl: `${BASE}/${plain.key}`,
    });
    // The admin overrides the detection: the same file as side-by-side.
    const override = await send('patch', owner, '/admin/gifts/d207_car', {
      animationAlpha: 'SIDE_BY_SIDE',
      reason: 'it has alpha',
    });
    expect(override.body.changed).toEqual(['animationAlpha']);
    const um = await expectPanelAudit('gift.update', 'd207_car', owner, 'it has alpha');
    expect(um.changes).toEqual({ animationAlpha: { from: 'NONE', to: 'SIDE_BY_SIDE' } });

    // An SVGA instead (no transparency), then «إزالة» of the effect and of the sound.
    const sv = (await upload(owner, 'animation', 'd207_car', svga())).body;
    expect(
      (
        await send('patch', owner, '/admin/gifts/d207_car', {
          animationObjectKey: sv.key,
          animationAlpha: 'NONE',
          reason: 'x',
        })
      ).status,
    ).toBe(409);
    expect(
      (await send('patch', owner, '/admin/gifts/d207_car', { animationObjectKey: sv.key, reason: 'svga' }))
        .status,
    ).toBe(200);
    gift = (await catalogue('ar')).body.data.find((g: { code: string }) => g.code === 'd207_car');
    expect(gift).toMatchObject({ animationFormat: 'SVGA', animationAlpha: null });
    const removed = await send('patch', owner, '/admin/gifts/d207_car', {
      animationObjectKey: null,
      audioObjectKey: null,
      reason: 'remove files',
    });
    expect(removed.status).toBe(200);
    gift = (await catalogue('ar')).body.data.find((g: { code: string }) => g.code === 'd207_car');
    expect(gift).toMatchObject({
      animationUrl: null,
      animationFormat: null,
      audioUrl: null,
      audioDurationMs: null,
    });
    expect(gift.imageUrl).toBe(`${BASE}/${img}`);
    // The picture is replaced, never removed.
    expect(
      (await send('patch', owner, '/admin/gifts/d207_car', { imageObjectKey: null, reason: 'x' })).status,
    ).toBe(409);

    // A QUIPS gift takes no MP3 (it has its bundled sound).
    const qs = (await upload(owner, 'sound', 'd207_q', mp3({ durationMs: 1000 }))).body.key as string;
    const qimg = (await upload(owner, 'image', 'd207_q', await png(128, 128))).body.key as string;
    const quip = await post(owner, '/admin/gifts', {
      code: 'd207_q',
      category: 'QUIPS',
      nameAr: 'إفيه',
      nameEn: 'Quip',
      priceCoins: 0,
      soundKey: 'kabi/x',
      soundMs: 1000,
      imageObjectKey: qimg,
      audioObjectKey: qs,
      reason: 'x',
    });
    expect(quip.status).toBe(409);
    expect(JSON.stringify(quip.body)).toContain('QUIPS');

    const list = await get(finance, '/admin/gifts');
    expectContract(list, 'listAdminGifts');
    expect(list.body.categories.map((c: { code: string }) => c.code)).toEqual([
      'POPULAR',
      'EVENT',
      'FUN',
      'LUCKY',
      'QUIPS',
    ]);
    expect(list.body.uploads).toEqual({ storage: false, publicUrls: true });
    // A gift of a category that does not exist.
    expect(
      (await post(owner, '/admin/gifts', { ...base, code: 'd207_x', category: 'NOPE', imageObjectKey: img }))
        .status,
    ).toBe(409);
  });

  it('gift-admin: categories, category-add / update / disable / delete --move-to (the same rules, via cli)', async () => {
    const add = await cli([
      'category-add',
      'CLI_CAT',
      '--name-ar',
      'تجربة',
      '--name-en',
      'Trial',
      '--sort',
      '70',
    ]);
    expect(add.stdout).toContain('+category CLI_CAT');
    await ctx.prisma.gift.create({
      data: {
        code: 'd207_cli',
        category: 'CLI_CAT',
        nameAr: 'هدية',
        nameEn: 'Gift',
        priceCoins: 5,
        assetKey: 'x',
      },
    });
    expect((await cli(['category-update', 'CLI_CAT', '--name-en', 'Trials'])).stdout).toContain(
      'nameEn updated',
    );
    expect((await cli(['category-disable', 'CLI_CAT'])).stdout).toContain('disabled');
    await expect(cli(['category-disable', 'QUIPS'])).rejects.toMatchObject({
      stderr: expect.stringContaining('special'),
    });
    await expect(cli(['category-delete', 'CLI_CAT'])).rejects.toMatchObject({
      stderr: expect.stringContaining('move them'),
    });
    const listed = await cli(['categories']);
    expect(listed.stdout).toMatch(/- 70 CLI_CAT NORMAL "تجربة" \/ "Trials" gifts=1/);
    expect((await cli(['category-delete', 'CLI_CAT', '--move-to', 'EVENT'])).stdout).toContain(
      '1 gift(s) moved to EVENT',
    );
    expect((await ctx.prisma.gift.findUnique({ where: { code: 'd207_cli' } }))?.category).toBe('EVENT');
    const row = await lastAudit('gift.category.delete', 'CLI_CAT');
    expect(row.actorUserId).toBeNull();
    expect(row.metadata).toMatchObject({ via: 'cli', movedTo: 'EVENT', movedGifts: ['d207_cli'] });
    // add takes any existing category, and refuses a missing one.
    await expect(
      cli([
        'add',
        'd207_cli2',
        '--category',
        'NOPE',
        '--name-ar',
        'x',
        '--name-en',
        'x',
        '--price',
        '5',
        '--asset',
        'x',
      ]),
    ).rejects.toMatchObject({ stderr: expect.stringContaining('no gift category NOPE') });
    expect((await cli(['list'])).stdout).toContain('d207_cli');
  });
});
