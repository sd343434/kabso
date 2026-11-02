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
