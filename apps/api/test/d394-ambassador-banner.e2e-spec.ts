/**
 * D394 (openapi v1.142-social DRAFT, CONVENTIONS §10.26): a promo banner may open «برنامج سفراء Kabso» (D390, the
 * app route `/ambassadors`). The link allowlist accepts exactly `/ambassadors` in every placement — from the panel
 * (`createAdminBanner`) and from the `banner-admin` CLI — and still refuses anything around it, end to end against
 * PostgreSQL + Redis with the API as the DML-only runtime role. Object storage is the in-memory test double.
 */
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
  ADMIN_TOTP_KEY: 'd394-admin-totp-test-key-0123456789-abcdefghijk',
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

describe('D394 the ambassadors programme as a banner link', { timeout: 240_000 }, () => {
  let storage: MemoryObjectStorage;
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let viewer: Person;
  const list = async (placement: string) => {
    const res = await ctx.http
      .get('/api/v1/home/banners')
      .query({ placement })
      .set('Authorization', `Bearer ${viewer.token}`)
      .set('Accept-Language', 'ar');
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listHomeBanners');
    return res.body as { data: { id: string; link: string }[] };
  };
  const uploadPicture = (placement: string, bytes: Buffer) =>
    ctx.http
      .post('/api/v1/admin/banner-uploads')
      .query({ placement })
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(bytes);

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

  it('the panel adds a /ambassadors banner in each placement and the app lists it', async () => {
    for (const [placement, w, h] of [
      ['home', 1500, 300],
      ['hub_card', 720, 805],
      ['room', 600, 800],
      ['tasks', 1500, 500],
      ['wallet', 1500, 500],
    ] as const) {
      const up = await uploadPicture(placement, await png(w, h));
      expect(up.status, JSON.stringify(up.body)).toBe(201);
      const add = await p.send(owner, 'post', '/admin/banners', {
        mediaId: up.body.mediaId,
        placement,
        link: '/ambassadors',
        titleAr: 'برنامج سفراء Kabso',
        titleEn: 'Kabso Ambassadors',
        reason: 'D394 ambassadors banner',
      });
      expect(add.status, JSON.stringify(add.body)).toBe(201);
      expectContract(add, 'createAdminBanner');
      expect(add.body).toMatchObject({ link: '/ambassadors', enabled: true, showing: true });
      expect((await list(placement)).data.map((b) => [b.id, b.link])).toEqual([
        [add.body.id, '/ambassadors'],
      ]);
    }
  });

  it('a link around /ambassadors is still refused (409 with the allowed links); nothing is added', async () => {
    const before = await withMigrationClient((c) => c.homeBanner.count());
    for (const link of [
      '/ambassadors/me',
      '/ambassadors/',
      '/ambassador',
      '/Ambassadors',
      '/ambassadors?x=1',
    ]) {
      const up = await uploadPicture('home', await png(1500, 300));
      expect(up.status).toBe(201);
      const res = await p.send(owner, 'post', '/admin/banners', {
        mediaId: up.body.mediaId,
        placement: 'home',
        link,
        reason: 'D394 refused link',
      });
      expect(res.status, link).toBe(409);
      expect(res.body.error.code).toBe('ADMIN_ACTION_REFUSED');
      expect(res.body.error.message).toContain('/ambassadors');
    }
    expect(await withMigrationClient((c) => c.homeBanner.count())).toBe(before);
  });

  it('the CLI accepts --link /ambassadors and refuses an unknown link', async () => {
    const refused = await uploadPicture('home', await png(1500, 300));
    expect(bannerAdminFails('add', '--media', refused.body.mediaId, '--link', '/ambassadors/me')).toContain(
      '/ambassadors or an https:// URL',
    );
    const up = await uploadPicture('home', await png(1500, 300));
    const out = bannerAdmin('add', '--media', up.body.mediaId, '--link', '/ambassadors', '--sort', '5');
    const id = /^\+([0-9a-f-]{36}) home \/ambassadors /.exec(out)?.[1];
    expect(id, out).toBeDefined();
    expect((await list('home')).data.map((b) => b.id)).toContain(id);
  });

  it('a stored link outside the allowlist is left out on read; /ambassadors is kept', async () => {
    await withMigrationClient((c) =>
      c.homeBanner.updateMany({
        where: { link: '/ambassadors', placement: 'WALLET' },
        data: { link: '/ambassadors/x' },
      }),
    );
    expect((await list('wallet')).data).toEqual([]);
    expect((await list('room')).data.map((b) => b.link)).toEqual(['/ambassadors']);
  });
});
