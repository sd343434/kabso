/**
 * D168 (v1.45-social, CONVENTIONS §10.42, §11.1, §11.14): editing the own profile — the display
 * name and bio of `PATCH /me`, the profile photo (`AVATAR` media, `PUT` / `DELETE /me/avatar`) — and
 * post videos of at most 90 s (stored longer ones kept), end to end against PostgreSQL + Redis with
 * the API as the DML-only runtime role. Object storage is the in-memory double; every response is
 * checked against openapi.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { mp4 } from './helpers/mp4.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
  RATE_LIMIT_MEDIA_UPLOAD_USER: '1000/3600',
  RATE_LIMIT_POST_CREATE_HOUR_USER: '1000/3600',
  RATE_LIMIT_POST_CREATE_DAY_USER: '1000/86400',
};

const MIGRATION = new URL(
  '../prisma/migrations/20261213090000_profile_avatar_video_90s/migration.sql',
  import.meta.url,
);

describe('D168 contract coverage', () => {
  it('openapi declares setMyAvatar and removeMyAvatar on /me/avatar', () => {
    expect(
      operations()
        .filter((o) => o.path === '/api/v1/me/avatar')
        .map((o) => `${o.operationId} ${o.method.toUpperCase()}`)
        .sort(),
    ).toEqual(['removeMyAvatar DELETE', 'setMyAvatar PUT']);
  });
});

describe('D168 editing the own profile', () => {
  let storage: MemoryObjectStorage;
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const patchMe = async (u: TestUser, body: unknown) => {
    const res = await ctx.http
      .patch('/api/v1/me')
      .set(auth(u))
      .send(body as object);
    expectContract(res, 'updateMe');
    return res;
  };
  const profile = async (viewer: TestUser, of: TestUser) => {
    const res = await ctx.http.get(`/api/v1/users/${of.username}`).set(auth(viewer));
    expect(res.status).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body as { displayName: string; bio: string | null; avatarUrl: string | null };
  };
  const me = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMe');
    return res.body as { displayName: string; bio: string | null; avatarUrl: string | null };
  };
  const image = (w: number, h: number) =>
    sharp({ create: { width: w, height: h, channels: 3, background: { r: 200, g: 40, b: 90 } } })
      .jpeg()
      .toBuffer();
  const slot = (u: TestUser, body: unknown) =>
    ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send(body as object);
  const uploadBytes = async (u: TestUser, kind: string, bytes: Buffer, contentType: string) => {
    const s = await slot(u, { kind, contentType, byteSize: bytes.length });
    expect(s.status, JSON.stringify(s.body)).toBe(201);
    expect(storage.upload(s.body.uploadUrl, bytes, contentType)).toBe(true);
    return s.body.uploadId as string;
  };
  const complete = (u: TestUser, uploadId: string, body?: unknown) => {
    const req = ctx.http.post(`/api/v1/media/uploads/${uploadId}/complete`).set(auth(u));
    return body === undefined ? req : req.send(body as object);
  };
  const photo = async (u: TestUser, kind = 'AVATAR', w = 1200, h = 900) => {
    const id = await uploadBytes(u, kind, await image(w, h), 'image/jpeg');
    const done = await complete(u, id);
    expect(done.status).toBe(200);
    expectContract(done, 'completeMediaUpload');
    return done.body as { id: string; url: string; thumbUrl: string; width: number; height: number };
  };
  const putAvatar = async (u: TestUser, body: unknown) => {
    const res = await ctx.http
      .put('/api/v1/me/avatar')
      .set(auth(u))
      .send(body as object);
    expectContract(res, 'setMyAvatar');
    return res;
  };
  const deleteAvatar = async (u: TestUser) => {
    const res = await ctx.http.delete('/api/v1/me/avatar').set(auth(u));
    expectContract(res, 'removeMyAvatar');
    return res;
  };
  const keyOf = (url: string) => url.replace('https://media.example.test/', '');
  const audits = (userId: string, action: string) =>
    ctx.prisma.auditLog.findMany({ where: { actorUserId: userId, action }, orderBy: { createdAt: 'asc' } });

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
  });
  afterAll(async () => ctx?.close());

  describe('name and bio (PATCH /me)', () => {
    it('changes the name and bio; profiles show them; the audit names fields, never values', async () => {
      const u = await signup();
      const other = await signup();
      const res = await patchMe(u, { displayName: '  ليلى  ', bio: '  أهلاً\r\nبكم  ' });
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({ displayName: 'ليلى', bio: 'أهلاً\nبكم' });
      expect(await me(u)).toMatchObject({ displayName: 'ليلى', bio: 'أهلاً\nبكم' });
      expect(await profile(other, u)).toMatchObject({ displayName: 'ليلى', bio: 'أهلاً\nبكم' });
      const rows = await audits(u.id, 'user.profile.update');
      expect(rows).toHaveLength(1);
      expect(rows[0]!.metadata).toEqual({ fields: ['displayName', 'bio'] });
      expect(JSON.stringify(rows[0]!.metadata)).not.toContain('ليلى');
    });

    it('null or an empty bio clears it; an unchanged value writes no audit row', async () => {
      const u = await signup();
      await patchMe(u, { bio: 'hello' });
      expect((await patchMe(u, { bio: null })).body.bio).toBeNull();
      await patchMe(u, { bio: 'again' });
      expect((await patchMe(u, { bio: '  \n ' })).body.bio).toBeNull();
      const before = (await audits(u.id, 'user.profile.update')).length;
      const same = await patchMe(u, { bio: null });
      expect(same.status).toBe(200);
      expect((await audits(u.id, 'user.profile.update')).length).toBe(before);
    });

    it('locale and country still work alone and together with a name', async () => {
      const u = await signup();
      const res = await patchMe(u, { locale: 'en', country: 'sa', displayName: 'Nour' });
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({ locale: 'en', country: 'SA', displayName: 'Nour' });
    });

    it('refuses bad names and bios with field details; nothing changes', async () => {
      const u = await signup();
      const before = await me(u);
      const cases: [unknown, string, string][] = [
        [{ displayName: '' }, 'displayName', 'too_short'],
        [{ displayName: 'x'.repeat(51) }, 'displayName', 'too_long'],
        [{ displayName: 'a‮b' }, 'displayName', 'invalid_format'],
        [{ displayName: 'Admin' }, 'displayName', 'reserved_term'],
        [{ bio: 'ب'.repeat(301) }, 'bio', 'too_long'],
        [{ bio: '1\n2\n3\n4\n5\n6' }, 'bio', 'too_long'],
        [{ bio: 'x'.repeat(1201) }, 'bio', 'too_long'],
        [{ bio: 'a​b' }, 'bio', 'invalid_format'],
        [{}, 'body', 'required'],
      ];
      for (const [body, field, issue] of cases) {
        const res = await patchMe(u, body);
        expect(res.status, JSON.stringify(body)).toBe(400);
        expect(res.body.error.code).toBe('VALIDATION_FAILED');
        expect(res.body.error.details, JSON.stringify(body)).toContainEqual({ field, issue });
      }
      const unknown = await patchMe(u, { avatarUrl: 'https://evil.test/a.png' });
      expect(unknown.status).toBe(400);
      expect(await me(u)).toEqual(before);
    });

    it('needs a session', async () => {
      const res = await ctx.http.patch('/api/v1/me').send({ displayName: 'x' });
      expect(res.status).toBe(401);
    });
  });

  describe('the profile photo (AVATAR, /me/avatar)', () => {
    it('an AVATAR upload is a centre-cropped square: 640 px and a 320 px thumb', async () => {
      const u = await signup();
      const a = await photo(u, 'AVATAR', 1200, 900);
      expect(a.url).toBe(`https://media.example.test/media/${a.id}/640.webp`);
      expect([a.width, a.height]).toEqual([640, 640]);
      const thumb = await sharp(storage.objects.get(`media/${a.id}/320.webp`)!.body).metadata();
      expect([thumb.width, thumb.height]).toEqual([320, 320]);
    });

    it('sets the photo; Me, the public profile and summaries show it; replacing deletes the old one', async () => {
      const u = await signup();
      const viewer = await signup();
      const first = await photo(u);
      const set = await putAvatar(u, { mediaId: first.id });
      expect(set.status).toBe(200);
      expect(set.body).toEqual({ avatarUrl: first.url });
      expect((await me(u)).avatarUrl).toBe(first.url);
      expect((await profile(viewer, u)).avatarUrl).toBe(first.url);
      // A UserSummary: the follower list of the viewer once u follows them.
      const follow = await ctx.http.put(`/api/v1/users/${viewer.username}/follow`).set(auth(u));
      expect(follow.status).toBe(200);
      const followers = await ctx.http.get(`/api/v1/users/${viewer.username}/followers`).set(auth(viewer));
      expect(followers.status).toBe(200);
      expectContract(followers, 'listUserFollowers');
      expect(followers.body.data.find((i: { id: string }) => i.id === u.id).avatarUrl).toBe(first.url);

      // The same photo again changes nothing.
      expect((await putAvatar(u, { mediaId: first.id })).body).toEqual({ avatarUrl: first.url });

      const second = await photo(u);
      const replaced = await putAvatar(u, { mediaId: second.id });
      expect(replaced.status).toBe(200);
      expect((await me(u)).avatarUrl).toBe(second.url);
      expect(await ctx.prisma.mediaAsset.findUnique({ where: { id: first.id } })).toBeNull();
      expect(storage.objects.has(keyOf(first.url))).toBe(false);
      expect(storage.objects.has(`media/${first.id}/320.webp`)).toBe(false);
      expect(storage.objects.has(keyOf(second.url))).toBe(true);
      const profileRow = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: u.id } });
      expect(profileRow.avatarMediaId).toBe(second.id);
      const rows = await audits(u.id, 'user.avatar.update');
      expect(rows.map((r) => r.metadata)).toEqual([{ avatar: 'set' }, { avatar: 'set' }]);
    });

    it('refuses an asset that is not a READY, unattached AVATAR of the caller', async () => {
      const u = await signup();
      const other = await signup();
      const cover = await photo(u, 'POST_IMAGE');
      const foreign = await photo(other);
      const used = await photo(u);
      expect((await putAvatar(u, { mediaId: used.id })).status).toBe(200);
      const current = await photo(u);
      expect((await putAvatar(u, { mediaId: current.id })).status).toBe(200);
      for (const body of [
        { mediaId: cover.id },
        { mediaId: foreign.id },
        { mediaId: used.id }, // deleted when it was replaced
        { mediaId: randomUUID() },
        { mediaId: 'nope' },
      ]) {
        const res = await putAvatar(u, body);
        expect(res.status, JSON.stringify(body)).toBe(400);
        expect(res.body.error.details).toEqual([{ field: 'mediaId', issue: 'invalid_value' }]);
      }
      const strict = await putAvatar(u, { mediaId: current.id, extra: 1 });
      expect(strict.status).toBe(400);
      expect(strict.body.error.details).toEqual([{ field: 'extra', issue: 'unknown_field' }]);
      expect((await me(u)).avatarUrl).toBe(current.url);
      // Another person's photo is untouched.
      expect(await ctx.prisma.mediaAsset.findUnique({ where: { id: foreign.id } })).not.toBeNull();
    });

    it('an AVATAR attaches nowhere else', async () => {
      const u = await signup();
      const a = await photo(u);
      const post = await ctx.http
        .post('/api/v1/posts')
        .set(auth(u))
        .set('Idempotency-Key', randomUUID())
        .send({ text: 'x', mediaIds: [a.id] });
      expect(post.status).toBe(400);
    });

    it('removing goes back to no photo, deletes the asset and is idempotent', async () => {
      const u = await signup();
      const a = await photo(u);
      await putAvatar(u, { mediaId: a.id });
      const res = await deleteAvatar(u);
      expect(res.status).toBe(204);
      expect((await me(u)).avatarUrl).toBeNull();
      expect(await ctx.prisma.mediaAsset.findUnique({ where: { id: a.id } })).toBeNull();
      expect(storage.objects.has(keyOf(a.url))).toBe(false);
      expect((await deleteAvatar(u)).status).toBe(204);
      expect((await audits(u.id, 'user.avatar.update')).map((r) => r.metadata)).toEqual([
        { avatar: 'set' },
        { avatar: 'removed' },
      ]);
    });

    it('removes a URL that has no asset (accounts seeded with one)', async () => {
      const u = await signup();
      await withMigrationClient((c) =>
        c.userProfile.update({
          where: { userId: u.id },
          data: { avatarUrl: 'https://cdn.example.test/old.png' },
        }),
      );
      expect((await deleteAvatar(u)).status).toBe(204);
      expect((await me(u)).avatarUrl).toBeNull();
    });

    it('the database refuses an asset without a URL', async () => {
      const u = await signup();
      const a = await photo(u);
      await expect(
        withMigrationClient((c) =>
          c.userProfile.update({ where: { userId: u.id }, data: { avatarMediaId: a.id, avatarUrl: null } }),
        ),
      ).rejects.toThrow(/user_profiles_avatar_media_has_url/);
    });

    it('deleting the account deletes the photo row with it', async () => {
      const u = await signup();
      const a = await photo(u);
      await putAvatar(u, { mediaId: a.id });
      await withMigrationClient((c) => c.user.delete({ where: { id: u.id } }));
      expect(await ctx.prisma.mediaAsset.findUnique({ where: { id: a.id } })).toBeNull();
    });

    it('needs a session', async () => {
      expect((await ctx.http.put('/api/v1/me/avatar').send({ mediaId: randomUUID() })).status).toBe(401);
      expect((await ctx.http.delete('/api/v1/me/avatar')).status).toBe(401);
    });
  });

  describe('post videos of at most 90 s', () => {
    const poster = async (u: TestUser) => {
      const id = await uploadBytes(u, 'VIDEO_POSTER', await image(540, 960), 'image/jpeg');
      const done = await complete(u, id);
      expect(done.status).toBe(200);
      return done.body.id as string;
    };
    const video = async (u: TestUser, kind: 'POST_VIDEO' | 'REEL_VIDEO', durationMs: number) => {
      const uploadId = await uploadBytes(u, kind, mp4({ durationMs }), 'video/mp4');
      const res = await complete(u, uploadId, { posterId: await poster(u) });
      expectContract(res, 'completeMediaUpload');
      return res;
    };
    const createPost = (u: TestUser, body: unknown) =>
      ctx.http
        .post('/api/v1/posts')
        .set(auth(u))
        .set('Idempotency-Key', randomUUID())
        .send(body as object);

    it('takes 90 s (+ padding, reported 90 000) and refuses 91 s; reels stay at 60 s', async () => {
      const u = await signup();
      const ok = await video(u, 'POST_VIDEO', 90_000);
      expect(ok.status).toBe(200);
      expect(ok.body.durationMs).toBe(90_000);
      const padded = await video(u, 'POST_VIDEO', 90_400);
      expect(padded.status).toBe(200);
      expect(padded.body.durationMs).toBe(90_000);
      for (const ms of [91_000, 120_000, 180_000]) {
        const res = await video(u, 'POST_VIDEO', ms);
        expect(res.status, String(ms)).toBe(422);
        expect(res.body.error.code).toBe('MEDIA_INVALID');
      }
      expect((await video(u, 'REEL_VIDEO', 61_000)).status).toBe(422);
      const post = await createPost(u, { mediaIds: [ok.body.id] });
      expect(post.status).toBe(201);
    });

    it('keeps longer videos stored before (NOT VALID), but no longer attaches an unattached one', async () => {
      const u = await signup();
      const attached = await video(u, 'POST_VIDEO', 30_000);
      const loose = await video(u, 'POST_VIDEO', 30_000);
      const post = await createPost(u, { mediaIds: [attached.body.id] });
      expect(post.status).toBe(201);
      // Rows as D162 stored them (up to 180 s), then the migration's check added again as it ships.
      const sql = readFileSync(MIGRATION, 'utf8');
      const addCheck = sql
        .split('\n')
        .find((l) => l.includes('ADD CONSTRAINT "media_assets_post_video_90s"'))!;
      expect(addCheck).toMatch(/NOT VALID;$/);
      await withMigrationClient(async (c) => {
        await c.$executeRawUnsafe('ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_post_video_90s"');
        try {
          await c.mediaAsset.updateMany({
            where: { id: { in: [attached.body.id, loose.body.id] } },
            data: { durationMs: 150_000 },
          });
        } finally {
          await c.$executeRawUnsafe(addCheck.replace(/;$/, ''));
        }
      });
      const checks = await ctx.prisma.$queryRaw<{ convalidated: boolean }[]>`
        SELECT convalidated FROM pg_constraint WHERE conname = 'media_assets_post_video_90s'`;
      expect(checks).toEqual([{ convalidated: false }]);

      // The stored post still reads with its 150 s video.
      const read = await ctx.http.get(`/api/v1/posts/${post.body.id}`).set(auth(u));
      expect(read.status).toBe(200);
      expectContract(read, 'getPost');
      expect(read.body.media[0].durationMs).toBe(150_000);

      // The unattached one cannot be attached (the API refuses before any UPDATE).
      const refused = await createPost(u, { mediaIds: [loose.body.id] });
      expect(refused.status).toBe(400);
      expect(refused.body.error.details).toEqual([{ field: 'mediaIds', issue: 'invalid_value' }]);

      // The database holds new rows and updates to 90 s.
      await expect(
        withMigrationClient((c) =>
          c.mediaAsset.update({ where: { id: loose.body.id }, data: { attachedAt: new Date() } }),
        ),
      ).rejects.toThrow(/media_assets_post_video_90s/);
    });
  });
});

describe('D168 with uploads off', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ MEDIA_UPLOADS_ENABLED: 'false' });
  });
  afterAll(async () => ctx?.close());

  it('setting a photo → 503 MEDIA_UPLOADS_UNAVAILABLE; removing and the name still work', async () => {
    const { res } = await registerVerified(ctx);
    const token = res.body.tokens.accessToken as string;
    const put = await ctx.http
      .put('/api/v1/me/avatar')
      .set({ Authorization: `Bearer ${token}` })
      .send({ mediaId: randomUUID() });
    expect(put.status).toBe(503);
    expect(put.body.error.code).toBe('MEDIA_UPLOADS_UNAVAILABLE');
    expectContract(put, 'setMyAvatar');
    const del = await ctx.http.delete('/api/v1/me/avatar').set({ Authorization: `Bearer ${token}` });
    expect(del.status).toBe(204);
    const name = await ctx.http
      .patch('/api/v1/me')
      .set({ Authorization: `Bearer ${token}` })
      .send({ displayName: 'Hala' });
    expect(name.status).toBe(200);
    expect(name.body.displayName).toBe('Hala');
  });
});

describe('D168 avatar rate limit', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ MEDIA_UPLOADS_ENABLED: 'false', RATE_LIMIT_AVATAR_USER: '2/3600' });
  });
  afterAll(async () => ctx?.close());

  it('PUT and DELETE share one bucket of the configured size', async () => {
    const { res } = await registerVerified(ctx);
    const h = { Authorization: `Bearer ${res.body.tokens.accessToken as string}` };
    expect((await ctx.http.delete('/api/v1/me/avatar').set(h)).status).toBe(204);
    expect((await ctx.http.put('/api/v1/me/avatar').set(h).send({ mediaId: randomUUID() })).status).toBe(503);
    const limited = await ctx.http.delete('/api/v1/me/avatar').set(h);
    expect(limited.status).toBe(429);
    expectContract(limited, 'removeMyAvatar');
  });
});
