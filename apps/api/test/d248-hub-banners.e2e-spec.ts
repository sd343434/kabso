/**
 * D248 (openapi v1.59-live DRAFT, CONVENTIONS §10.90): the live hub's card-size banner (`placement=hub_card`, the
 * live card's aspect, 720 × 805) and adding banners from the panel («البانرات والفعاليات»), end to end against
 * PostgreSQL + Redis with the API as the DML-only runtime role. Object storage is the in-memory test double; the
 * `banner-admin` CLI runs as an operator would run it (migration role).
 */
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
  ADMIN_TOTP_KEY: 'd248-admin-totp-test-key-0123456789-abcdefghijk',
  ADMIN_SESSION_IDLE_SECONDS: '7200',
  ADMIN_SESSION_MAX_SECONDS: '28800',
  RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
  RATE_LIMIT_ADMIN_IP: '10000/900',
};

/** `pnpm banner:admin …` as an operator would run it; returns stdout, or throws with stderr. */
function bannerAdmin(...args: string[]): string {
  const env = { ...process.env };
  delete env.S3_BUCKET;
  return execFileSync('pnpm', ['-s', 'banner:admin', ...args], {
    cwd: fileURLToPath(new URL('..', import.meta.url)),
    env,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function bannerAdminFails(...args: string[]): string {
  try {
    bannerAdmin(...args);
  } catch (err) {
    return String((err as { stderr?: string }).stderr ?? err);
  }
  throw new Error(`banner:admin ${args.join(' ')} succeeded`);
}

const png = (w: number, h: number) =>
  sharp({ create: { width: w, height: h, channels: 3, background: { r: 30, g: 120, b: 200 } } })
    .png()
    .toBuffer();

/** D248c: an animated WebP (or GIF) of [frames] Kabso-red frames, [delay] ms each. */
async function animated(w: number, h: number, frames: number, delay = 100, format: 'webp' | 'gif' = 'webp') {
  const parts = await Promise.all(
    Array.from({ length: frames }, (_, i) =>
      sharp({
        create: {
          width: w,
          height: h,
          channels: 4,
          background: { r: 229, g: (i * 37) % 200, b: 20, alpha: 1 },
        },
      })
        .png()
        .toBuffer(),
    ),
  );
  const joined = sharp(parts, { join: { animated: true } });
  return format === 'gif'
    ? joined.gif({ loop: 0, delay: Array(frames).fill(delay) }).toBuffer()
    : joined.webp({ loop: 0, delay: Array(frames).fill(delay), quality: 60 }).toBuffer();
}

const framesOf = async (body: Buffer) => {
  const m = await sharp(body, { animated: true }).metadata();
  return { format: m.format, width: m.width, pageHeight: m.pageHeight ?? m.height, pages: m.pages ?? 1 };
};

describe('D248 contract coverage', () => {
  it('openapi declares the hub card placement and the panel banner add', () => {
    const ops = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ops).toContain('createAdminBanner POST /api/v1/admin/banners');
    expect(ops).toContain('uploadAdminBannerPicture POST /api/v1/admin/banner-uploads');
    expect(ops).toContain('listHomeBanners GET /api/v1/home/banners');
  });
});

describe('D248 hub card banners', { timeout: 240_000 }, () => {
  let storage: MemoryObjectStorage;
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let support: Admin;
  let viewer: Person;
  const auth = (u: Person) => ({ Authorization: `Bearer ${u.token}` });
  const list = async (placement?: string, u: Person = viewer) => {
    const res = await ctx.http
      .get('/api/v1/home/banners')
      .query(placement === undefined ? {} : { placement })
      .set(auth(u))
      .set('Accept-Language', 'en');
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listHomeBanners');
    return res.body as {
      data: { id: string; width: number; height: number; imageUrl: string }[];
      cell?: number;
    };
  };
  const uploadPicture = (a: Admin, placement: string, bytes: Buffer) =>
    ctx.http
      .post('/api/v1/admin/banner-uploads')
      .query({ placement })
      .set('Cookie', a.cookie)
      .set('X-CSRF-Token', a.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(bytes);

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
    owner = await p.makeAdmin(['OWNER']);
    support = await p.makeAdmin(['SUPPORT']);
    viewer = await p.signup();
  });
  afterAll(async () => {
    vi.useRealTimers();
    await withMigrationClient((c) => c.homeBanner.deleteMany());
    await ctx?.close();
  });

  it('no hub card banner: an empty list with the default cell 4; the home list is unchanged; no token → 401', async () => {
    expect(await list('hub_card')).toEqual({ data: [], cell: 4 });
    expect(await list()).toEqual({ data: [] });
    expect((await ctx.http.get('/api/v1/home/banners?placement=hub_card')).status).toBe(401);
    const bad = await ctx.http.get('/api/v1/home/banners?placement=HUB_CARD').set(auth(viewer));
    expect(bad.status).toBe(400);
  });

  it('the panel uploads a picture cover-cropped to the live card (720 × 805, thumb 288 × 322) and adds it', async () => {
    const up = await uploadPicture(owner, 'hub_card', await png(1200, 900));
    expect(up.status, JSON.stringify(up.body)).toBe(201);
    expectContract(up, 'uploadAdminBannerPicture');
    expect(up.body).toMatchObject({ placement: 'HUB_CARD', width: 720, height: 805 });
    const thumbKey = String(up.body.thumbUrl).replace('https://media.example.test/', '');
    const thumb = await sharp(storage.objects.get(thumbKey)!.body).metadata();
    expect([thumb.width, thumb.height, thumb.format]).toEqual([288, 322, 'webp']);

    const add = await p.send(owner, 'post', '/admin/banners', {
      mediaId: up.body.mediaId,
      placement: 'hub_card',
      link: '/families',
      sortOrder: 1,
      reason: 'D248 card banner',
    });
    expect(add.status, JSON.stringify(add.body)).toBe(201);
    expectContract(add, 'createAdminBanner');
    expect(add.body).toMatchObject({
      placement: 'HUB_CARD',
      link: '/families',
      enabled: true,
      showing: true,
    });

    const hub = await list('hub_card');
    expect(hub.cell).toBe(4);
    expect(hub.data.map((b) => [b.id, b.width, b.height])).toEqual([[add.body.id, 720, 805]]);
    expect(hub.data[0]!.imageUrl).toMatch(/\/720\.webp$/);
    // Never in the carousel's list (nor the room's).
    expect((await list()).data).toEqual([]);
    expect((await list('room')).data).toEqual([]);

    const audit = await withMigrationClient((c) =>
      c.auditLog.findFirst({ where: { action: 'banner.add', targetId: add.body.id } }),
    );
    expect(audit?.actorUserId).toBe(owner.id);
    expect(audit?.metadata).toMatchObject({
      placement: 'HUB_CARD',
      via: 'panel',
      reason: 'D248 card banner',
    });

    const rows = await p.send(owner, 'get', '/admin/banners');
    expectContract(rows, 'listAdminBanners');
    expect(
      (rows.body.data as { id: string; placement: string }[]).find((b) => b.id === add.body.id)?.placement,
    ).toBe('HUB_CARD');
  });

  it('a picture serves only its own placement; the CLI rules refuse bad fields (409); one use only', async () => {
    const home = await uploadPicture(owner, 'home', await png(1800, 600));
    expect(home.status).toBe(201);
    // D248b: the hub carousel is 5:1 (1 500 × 300, thumb 320 × 64); TASKS / WALLET stay 3:1.
    expect([home.body.width, home.body.height]).toEqual([1500, 300]);
    const homeThumb = await sharp(
      storage.objects.get(String(home.body.thumbUrl).replace('https://media.example.test/', ''))!.body,
    ).metadata();
    expect([homeThumb.width, homeThumb.height]).toEqual([320, 64]);
    const wallet = await uploadPicture(owner, 'wallet', await png(1800, 600));
    expect([wallet.body.width, wallet.body.height]).toEqual([1500, 500]);
    const card = await uploadPicture(owner, 'hub_card', await png(500, 500));
    expect(card.status).toBe(201);

    const wrong = await p.send(owner, 'post', '/admin/banners', {
      mediaId: home.body.mediaId,
      placement: 'hub_card',
      link: '/families',
      reason: 'x',
    });
    expect(wrong.status).toBe(409);
    expect(wrong.body.error.message).toMatch(/720 × 805/);
    const wrong2 = await p.send(owner, 'post', '/admin/banners', {
      mediaId: card.body.mediaId,
      placement: 'home',
      link: '/families',
      reason: 'x',
    });
    expect(wrong2.status).toBe(409);
    const badLink = await p.send(owner, 'post', '/admin/banners', {
      mediaId: card.body.mediaId,
      placement: 'hub_card',
      link: 'http://example.com',
      reason: 'x',
    });
    expect(badLink.status).toBe(409);
    const noReason = await p.send(owner, 'post', '/admin/banners', {
      mediaId: card.body.mediaId,
      placement: 'hub_card',
      link: '/families',
    });
    expect(noReason.status).toBe(400);

    const ok = await p.send(owner, 'post', '/admin/banners', {
      mediaId: home.body.mediaId,
      placement: 'home',
      link: '/cp/space',
      titleAr: 'فضاء الثنائيات',
      reason: 'carousel',
    });
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    expect((await list()).data.map((b) => b.id)).toEqual([ok.body.id]);
    const again = await p.send(owner, 'post', '/admin/banners', {
      mediaId: home.body.mediaId,
      placement: 'home',
      link: '/cp/space',
      reason: 'twice',
    });
    expect(again.status).toBe(409);
  });

  it('not an image → 409, nothing stored; an unknown placement → 400; catalog.manage only (SUPPORT 403)', async () => {
    const before = storage.objects.size;
    const junk = await uploadPicture(owner, 'hub_card', Buffer.from('not a picture at all'));
    expect(junk.status).toBe(409);
    expect(storage.objects.size).toBe(before);
    expect((await uploadPicture(owner, 'cards', await png(10, 10))).status).toBe(400);
    expect((await uploadPicture(support, 'hub_card', await png(720, 805))).status).toBe(403);
    expect(
      (
        await p.send(support, 'post', '/admin/banners', {
          mediaId: owner.id,
          placement: 'home',
          link: '/x',
          reason: 'r',
        })
      ).status,
    ).toBe(403);
  });

  it('the CLI: --placement hub_card with --media (a 3:1 upload) is refused; several card banners in order', async () => {
    const up = await uploadPicture(owner, 'home', await png(1500, 500));
    const out = bannerAdminFails(
      'add',
      '--media',
      up.body.mediaId,
      '--link',
      '/families',
      '--placement',
      'hub_card',
    );
    expect(out).toMatch(/not a 720 × 805 hub card banner picture/);
    const second = await uploadPicture(owner, 'hub_card', await png(720, 805));
    const added = bannerAdmin(
      'add',
      '--media',
      second.body.mediaId,
      '--link',
      '/cp/space',
      '--placement',
      'hub-card',
    );
    const id = /^\+([0-9a-f-]{36}) hub_card /.exec(added)?.[1];
    expect(id, added).toBeDefined();
    const hub = await list('hub_card');
    // sort 0 (the CLI's default) before sort 1 (the panel's).
    expect(hub.data).toHaveLength(2);
    expect(hub.data[0]!.id).toBe(id);
  });
});

describe('D248c animated banners', { timeout: 240_000 }, () => {
  let storage: MemoryObjectStorage;
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let viewer: Person;
  const up = (placement: string, bytes: Buffer) =>
    ctx.http
      .post('/api/v1/admin/banner-uploads')
      .query({ placement })
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(bytes);
  const stored = (url: string) => storage.objects.get(url.replace('https://media.example.test/', ''))!.body;

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
    owner = await p.makeAdmin(['OWNER']);
    viewer = await p.signup();
  });
  afterAll(async () => {
    vi.useRealTimers();
    await withMigrationClient((c) => c.homeBanner.deleteMany());
    await ctx?.close();
  });

  it('an animated WebP for each category stays animated, every frame cropped to the placement; a still thumbnail', async () => {
    for (const [placement, w, h] of [
      ['home', 1500, 300],
      ['hub_card', 720, 805],
      ['room', 600, 800],
    ] as const) {
      const res = await up(placement, await animated(400, 300, 6, 120));
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'uploadAdminBannerPicture');
      expect(res.body).toMatchObject({ width: w, height: h, animated: true, frames: 6, durationMs: 720 });
      expect(await framesOf(stored(res.body.imageUrl))).toEqual({
        format: 'webp',
        width: w,
        pageHeight: h,
        pages: 6,
      });
      expect((await framesOf(stored(res.body.thumbUrl))).pages).toBe(1);
    }
  });

  it('an animated GIF becomes an animated WebP; the ROOM banner is added and listed (guests too)', async () => {
    const res = await up('room', await animated(300, 400, 4, 100, 'gif'));
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expect(res.body).toMatchObject({ width: 600, height: 800, animated: true, frames: 4 });
    expect(await framesOf(stored(res.body.imageUrl))).toMatchObject({ format: 'webp', pages: 4 });
    const add = await p.send(owner, 'post', '/admin/banners', {
      mediaId: res.body.mediaId,
      placement: 'room',
      link: '/families',
      reason: 'animated room promo',
    });
    expect(add.status, JSON.stringify(add.body)).toBe(201);
    const list = await ctx.http.get('/api/v1/home/banners?placement=room');
    expect(list.status).toBe(200);
    expect((list.body.data as { id: string; width: number }[]).map((b) => [b.id, b.width])).toEqual([
      [add.body.id, 600],
    ]);
    expect(viewer.id).toBeTruthy();
  });

  it('a still GIF, JPEG and PNG stay stills', async () => {
    for (const bytes of [
      await sharp({ create: { width: 900, height: 300, channels: 3, background: '#e50914' } })
        .gif()
        .toBuffer(),
      await sharp({ create: { width: 900, height: 300, channels: 3, background: '#e50914' } })
        .jpeg()
        .toBuffer(),
      await png(900, 300),
    ]) {
      const res = await up('home', bytes);
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expect(res.body).toMatchObject({ width: 1500, height: 300, animated: false, frames: 1 });
      expect((await framesOf(stored(res.body.imageUrl))).pages).toBe(1);
    }
  });

  it('limits: more than 150 frames, longer than 10 s → 409 with the issue, nothing stored', async () => {
    const before = storage.objects.size;
    const many = await up('home', await animated(16, 16, 151, 20));
    expect(many.status).toBe(409);
    expect(many.body.error.details[0]).toEqual({ field: 'file', issue: 'banner_animation_too_many_frames' });
    const long = await up('home', await animated(16, 16, 11, 1000));
    expect(long.status).toBe(409);
    expect(long.body.error.details[0]).toEqual({ field: 'file', issue: 'banner_animation_too_long' });
    expect(storage.objects.size).toBe(before);
  });
});

describe('D248 HOME_HUB_CARD_CELL', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  beforeAll(async () => {
    ctx = await createTestApp({ HOME_HUB_CARD_CELL: '6' });
  });
  afterAll(async () => ctx?.close());

  it('the server setting moves the card banner to another cell', async () => {
    const viewer = await p.signup();
    const res = await ctx.http
      .get('/api/v1/home/banners?placement=hub_card')
      .set('Authorization', `Bearer ${viewer.token}`);
    expect(res.status).toBe(200);
    expectContract(res, 'listHomeBanners');
    expect(res.body.cell).toBe(6);
  });
});
