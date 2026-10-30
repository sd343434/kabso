/**
 * D124: the live hub's promo banners (openapi v1.26-live DRAFT, CONVENTIONS §10.26, §11.1), end to
 * end against PostgreSQL + Redis with the API as the DML-only runtime role. Object storage is the
 * in-memory test double; the `banner-admin` CLI runs as an operator would run it (migration role,
 * `--media` with an upload made through the API).
 */
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { storeBannerImage } from '../src/modules/home/home-banners.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly email: string;
  readonly token: string;
}

const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
};

const HOUR = 3600 * 1000;
const iso = (offsetMs: number) => new Date(Date.now() + offsetMs).toISOString();

/** `pnpm banner:admin …` as an operator would run it; returns stdout, or throws with stderr. */
function bannerAdmin(...args: string[]): string {
  const env = { ...process.env };
  // The `--media` path never touches storage; keep the CLI from reaching a real bucket.
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

describe('D124 contract coverage', () => {
  it('openapi declares listHomeBanners on GET /home/banners and the HOME_BANNER media kind', () => {
    expect(
      operations()
        .filter((o) => o.path === '/api/v1/home/banners')
        .map((o) => `${o.operationId} ${o.method.toUpperCase()}`),
    ).toEqual(['listHomeBanners GET']);
  });
});

// Each case runs the CLI as a process several times (about 1–3 s each).
describe('D124 home banners', { timeout: 240_000 }, () => {
  let storage: MemoryObjectStorage;
  let ctx: TestContext;
  let admin: TestUser;
  let viewer: TestUser;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, email: String(payload.email), token: res.body.tokens.accessToken };
  };
  const upload = async (u: TestUser, kind = 'HOME_BANNER', w = 1800, h = 600) => {
    const bytes = await sharp({
      create: { width: w, height: h, channels: 3, background: { r: 200, g: 40, b: 90 } },
    })
      .png()
      .toBuffer();
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType: 'image/png', byteSize: bytes.length });
    expect(slot.status).toBe(201);
    storage.upload(slot.body.uploadUrl, bytes, 'image/png');
    const done = await ctx.http.post(`/api/v1/media/uploads/${slot.body.uploadId}/complete`).set(auth(u));
    expect(done.status).toBe(200);
    expectContract(done, 'completeMediaUpload');
    return done.body as { id: string; url: string; thumbUrl: string; width: number; height: number };
  };
  /** Adds a banner with the CLI on a fresh upload; returns its id. */
  const add = async (...args: string[]): Promise<string> => {
    const media = await upload(admin);
    const out = bannerAdmin('add', '--media', media.id, ...args);
    const id = /^\+([0-9a-f-]{36}) /.exec(out)?.[1];
    expect(id, out).toBeDefined();
    return id!;
  };
  const list = async (u: TestUser = viewer, language = 'ar') => {
    const res = await ctx.http.get('/api/v1/home/banners').set(auth(u)).set('Accept-Language', language);
    expect(res.status).toBe(200);
    expectContract(res, 'listHomeBanners');
    return res;
  };
  const ids = async () => ((await list()).body.data as { id: string }[]).map((b) => b.id);
  const clear = () => withMigrationClient((c) => c.homeBanner.deleteMany());

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
    admin = await signup();
    viewer = await signup();
  });
  afterAll(async () => ctx?.close());

  it('a HOME_BANNER upload is cover-cropped to 1 500 × 500 and 320 × 107 WebP, whatever its size', async () => {
    for (const [w, h] of [
      [1800, 600],
      [600, 600],
      [4000, 400],
    ] as const) {
      const asset = await upload(admin, 'HOME_BANNER', w, h);
      expect(asset.url).toMatch(/\/1500\.webp$/);
      expect([asset.width, asset.height]).toEqual([1500, 500]);
      const thumb = await sharp(
        storage.objects.get(asset.thumbUrl.replace('https://media.example.test/', ''))!.body,
      ).metadata();
      expect([thumb.width, thumb.height, thumb.format]).toEqual([320, 107, 'webp']);
    }
  });

  it('the hub banners are for signed-in callers only, empty with no banner, and sends cache headers', async () => {
    await clear();
    const anonymous = await ctx.http.get('/api/v1/home/banners');
    expect(anonymous.status).toBe(401);
    const res = await list();
    expect(res.body).toEqual({ data: [] });
    expect(res.headers['cache-control']).toBe('private, max-age=60');
    expect(res.headers.vary).toContain('Accept-Language');
  });

  it('shows a banner with its picture, localized title, side and link', async () => {
    await clear();
    const id = await add(
      '--link',
      '/cp/space',
      '--title-ar',
      'فضاء الثنائيات',
      '--title-en',
      'The CP space',
      '--text-side',
      'left',
    );
    const ar = (await list(viewer, 'ar')).body.data;
    expect(ar).toHaveLength(1);
    expect(ar[0]).toMatchObject({
      id,
      width: 1500,
      height: 500,
      title: 'فضاء الثنائيات',
      titleSide: 'LEFT',
      link: '/cp/space',
    });
    expect(ar[0].imageUrl).toMatch(/^https:\/\/media\.example\.test\/media\/[0-9a-f-]{36}\/1500\.webp$/);
    expect((await list(viewer, 'en')).body.data[0].title).toBe('The CP space');
    // No title in a language: null, never the other language.
    await clear();
    await add('--link', '/families', '--title-ar', 'العائلات');
    expect((await list(viewer, 'en')).body.data[0]).toMatchObject({ title: null, titleSide: 'RIGHT' });
  });

  it('only banners inside their window are active (start ≤ now < end, no end = open)', async () => {
    await clear();
    const open = await add('--link', '/families');
    const current = await add('--link', '/families', '--starts', iso(-HOUR), '--ends', iso(HOUR));
    await add('--link', '/families', '--starts', iso(HOUR)); // not yet
    await add('--link', '/families', '--starts', iso(-2 * HOUR), '--ends', iso(-HOUR)); // over
    expect((await ids()).sort()).toEqual([open, current].sort());
    const listed = bannerAdmin('list');
    expect(listed.split('\n').filter((l) => l.startsWith('+ '))).toHaveLength(2);
    expect(listed.split('\n').filter((l) => l.startsWith('~ '))).toHaveLength(2);
  });

  it('orders by sortOrder, then the latest start, then id, at most 10', async () => {
    await clear();
    const late = await add('--link', '/families', '--sort', '20');
    const first = await add('--link', '/families', '--sort', '5');
    const older = await add('--link', '/families', '--sort', '10', '--starts', iso(-2 * HOUR));
    const newer = await add('--link', '/families', '--sort', '10', '--starts', iso(-HOUR));
    expect(await ids()).toEqual([first, newer, older, late]);
    for (let i = 0; i < 8; i++) await add('--link', '/families', '--sort', String(30 + i));
    expect(await ids()).toHaveLength(10);
  });

  it('disable hides a banner, enable shows it again; remove deletes it and its picture', async () => {
    await clear();
    const id = await add('--link', '/live?tab=trending');
    expect(bannerAdmin('disable', id)).toContain('disabled');
    expect(bannerAdmin('disable', id)).toContain('already disabled');
    expect(await ids()).toEqual([]);
    expect(bannerAdmin('list')).toMatch(new RegExp(`^- ${id}`, 'm'));
    expect(bannerAdmin('enable', id)).toContain('enabled');
    expect(await ids()).toEqual([id]);
    const disabledAtStart = await add('--link', '/families', '--disabled');
    expect(await ids()).toEqual([id]);

    const mediaId = (await withMigrationClient((c) => c.homeBanner.findUniqueOrThrow({ where: { id } })))
      .mediaId;
    expect(bannerAdmin('remove', id)).toContain('removed');
    expect(await ids()).toEqual([]);
    expect(await withMigrationClient((c) => c.mediaAsset.findUnique({ where: { id: mediaId } }))).toBeNull();
    expect(bannerAdminFails('remove', id)).toContain(`No banner ${id}`);
    expect(bannerAdminFails('enable', '00000000-0000-7000-8000-000000000000')).toContain('No banner');
    const audit = await withMigrationClient((c) =>
      c.auditLog.findMany({
        where: { targetId: { in: [id, disabledAtStart] } },
        orderBy: { createdAt: 'asc' },
      }),
    );
    expect(audit.map((a) => a.action)).toEqual([
      'banner.add',
      'banner.disable',
      'banner.enable',
      'banner.add',
      'banner.remove',
    ]);
  });

  it('refuses links outside the allowlist and accepts every allowed shape', async () => {
    await clear();
    for (const link of [
      'http://kabso.app',
      '/settings',
      '/live?tab=popular',
      'javascript:alert(1)',
      '/users/A',
    ]) {
      const media = await upload(admin);
      expect(bannerAdminFails('add', '--media', media.id, '--link', link)).toMatch(/link|username/i);
    }
    expect(await ids()).toEqual([]);
    for (const link of [
      '/cp/space',
      '/families',
      '/live?tab=new',
      '/home/room/0193a4b2-7c1d-7e2f-8a3b-4c5d6e7f8091',
      '/users/sara.k',
      'https://kabso.app/events',
    ]) {
      await add('--link', link);
    }
    expect((await list()).body.data.map((b: { link: string }) => b.link).sort()).toEqual(
      [
        '/cp/space',
        '/families',
        '/home/room/0193a4b2-7c1d-7e2f-8a3b-4c5d6e7f8091',
        '/live?tab=new',
        '/users/sara.k',
        'https://kabso.app/events',
      ].sort(),
    );
    // A stored link that no longer passes the rules is left out, not sent.
    await withMigrationClient((c) =>
      c.homeBanner.updateMany({ where: { link: '/families' }, data: { link: '/nope' } }),
    );
    expect((await list()).body.data).toHaveLength(5);
  });

  it('takes only a fresh, unused HOME_BANNER asset', async () => {
    await clear();
    const post = await upload(admin, 'POST_IMAGE');
    expect(bannerAdminFails('add', '--media', post.id, '--link', '/families')).toContain('not a HOME_BANNER');
    const cover = await upload(admin, 'FAMILY_COVER');
    expect(bannerAdminFails('add', '--media', cover.id, '--link', '/families')).toContain(
      'not a HOME_BANNER',
    );
    const media = await upload(admin);
    bannerAdmin('add', '--media', media.id, '--link', '/families');
    expect(bannerAdminFails('add', '--media', media.id, '--link', '/families')).toContain('already used');
    const old = await upload(admin);
    await withMigrationClient((c) =>
      c.mediaAsset.update({ where: { id: old.id }, data: { createdAt: new Date(Date.now() - 25 * HOUR) } }),
    );
    expect(bannerAdminFails('add', '--media', old.id, '--link', '/families')).toContain(
      'older than 24 hours',
    );
    expect(
      bannerAdminFails('add', '--media', '00000000-0000-7000-8000-000000000000', '--link', '/families'),
    ).toContain('No media');
    // Bad fields are refused before anything is touched.
    const fresh = await upload(admin);
    expect(
      bannerAdminFails(
        'add',
        '--media',
        fresh.id,
        '--link',
        '/families',
        '--ends',
        iso(-HOUR),
        '--starts',
        iso(0),
      ),
    ).toContain('--ends must be after --starts');
    expect(
      bannerAdminFails('add', '--media', fresh.id, '--link', '/families', '--title-en', 'x'.repeat(41)),
    ).toContain('1–40');
    expect(bannerAdminFails('add', '--link', '/families')).toContain('exactly one of --image');
    expect(
      (await withMigrationClient((c) => c.mediaAsset.findUniqueOrThrow({ where: { id: fresh.id } })))
        .attachedAt,
    ).toBeNull();
    // An attached banner picture is never swept as an unattached upload.
    expect(
      (await withMigrationClient((c) => c.mediaAsset.findUniqueOrThrow({ where: { id: media.id } })))
        .attachedAt,
    ).not.toBeNull();
  });

  it('the CLI image path stores a 3:1 HOME_BANNER asset owned by the operator account', async () => {
    const bytes = await sharp({ create: { width: 1290, height: 800, channels: 3, background: '#335' } })
      .jpeg()
      .toBuffer();
    const asset = await withMigrationClient((c) => storeBannerImage(c, storage, admin.id, bytes));
    expect(asset).toMatchObject({
      kind: 'HOME_BANNER',
      ownerId: admin.id,
      width: 1500,
      height: 500,
      attachedAt: null,
    });
    expect(storage.objects.has(asset.largeKey)).toBe(true);
    const id = bannerAdmin('add', '--media', asset.id, '--link', 'https://kabso.app/gifts');
    expect(id).toMatch(/^\+/);
  });

  it('D137: ROOM banners are 3:4 (600 × 800), listed only with placement=room; HOME stays the default', async () => {
    await clear();
    const home = await add('--link', '/families');
    const bytes = await sharp({ create: { width: 900, height: 900, channels: 3, background: '#a35' } })
      .png()
      .toBuffer();
    const asset = await withMigrationClient((c) => storeBannerImage(c, storage, admin.id, bytes, 'ROOM'));
    expect([asset.width, asset.height]).toEqual([600, 800]);
    expect(asset.largeKey).toMatch(/\/600\.webp$/);
    const thumb = await sharp(storage.objects.get(asset.thumbKey)!.body).metadata();
    expect([thumb.width, thumb.height]).toEqual([240, 320]);
    const out = bannerAdmin('add', '--media', asset.id, '--link', '/cp/space', '--placement', 'room');
    const room = /^\+([0-9a-f-]{36}) room /.exec(out)?.[1];
    expect(room, out).toBeDefined();
    // A 3:1 upload cannot be a ROOM banner, and a 3:4 picture cannot be a HOME one.
    const wide = await upload(admin);
    expect(() =>
      bannerAdmin('add', '--media', wide.id, '--link', '/families', '--placement', 'room'),
    ).toThrow();
    expect(() =>
      bannerAdmin('add', '--media', wide.id, '--link', '/families', '--placement', 'side'),
    ).toThrow();
    expect(await ids()).toEqual([home]);
    const res = await ctx.http
      .get('/api/v1/home/banners?placement=room')
      .set(auth(viewer))
      .set('Accept-Language', 'en');
    expect(res.status).toBe(200);
    expectContract(res, 'listHomeBanners');
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0]).toMatchObject({ id: room, width: 600, height: 800, link: '/cp/space' });
    const homeExplicit = await ctx.http.get('/api/v1/home/banners?placement=home').set(auth(viewer));
    expect(homeExplicit.body.data.map((b: { id: string }) => b.id)).toEqual([home]);
    const bad = await ctx.http.get('/api/v1/home/banners?placement=side').set(auth(viewer));
    expect(bad.status).toBe(400);
    expect(bad.body.error.details).toEqual([{ field: 'placement', issue: 'invalid_value' }]);
    expect(bannerAdmin('list')).toContain(`${room} room`);
  });

  it('D173: a guest (no token) reads the ROOM banners, in Arabic without Accept-Language; HOME stays signed-in only', async () => {
    await clear();
    const home = await add('--link', '/families');
    const bytes = await sharp({ create: { width: 700, height: 900, channels: 3, background: '#3a5' } })
      .png()
      .toBuffer();
    const asset = await withMigrationClient((c) => storeBannerImage(c, storage, admin.id, bytes, 'ROOM'));
    const out = bannerAdmin(
      'add',
      '--media',
      asset.id,
      '--link',
      '/cp/space',
      '--placement',
      'room',
      '--title-ar',
      'عرض الغرفة',
      '--title-en',
      'Room offer',
    );
    const room = /^\+([0-9a-f-]{36}) room /.exec(out)?.[1];
    expect(room, out).toBeDefined();
    const guest = await ctx.http.get('/api/v1/home/banners?placement=room');
    expect(guest.status).toBe(200);
    expectContract(guest, 'listHomeBanners');
    expect(guest.body.data.map((b: { id: string }) => b.id)).toEqual([room]);
    expect(guest.body.data[0].title).toBe('عرض الغرفة');
    expect(guest.headers['cache-control']).toBe('private, max-age=60');
    const guestEn = await ctx.http.get('/api/v1/home/banners?placement=room').set('Accept-Language', 'en');
    expect(guestEn.body.data[0].title).toBe('Room offer');
    // The live hub's banners stay for signed-in callers.
    expect((await ctx.http.get('/api/v1/home/banners')).status).toBe(401);
    expect((await ctx.http.get('/api/v1/home/banners?placement=home')).status).toBe(401);
    const bad = await ctx.http.get('/api/v1/home/banners?placement=side');
    expect(bad.status).toBe(400);
    // A bad token is still refused (OptionalAuth checks a token when one is sent).
    const forged = await ctx.http
      .get('/api/v1/home/banners?placement=room')
      .set('Authorization', 'Bearer not-a-token');
    expect(forged.status).toBe(401);
    const signedIn = await ctx.http.get('/api/v1/home/banners').set(auth(viewer));
    expect(signedIn.body.data.map((b: { id: string }) => b.id)).toEqual([home]);
  });
});
