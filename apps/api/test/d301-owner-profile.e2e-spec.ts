/**
 * D301 (owner, contract v1.95-social, CONVENTIONS §10.112): the app owner's profile «صفحة صاحب البرنامج», end to end
 * against PostgreSQL + Redis:
 *
 *  - owner-only guards (403 `OWNER_ONLY`) on every owner operation, and a `PROFILE_COVER_VIDEO` slot;
 *  - the bilingual cover video: set / replace / remove per language, on `PublicProfile` and `Me` (the app picks by its
 *    language; with one, everyone gets that one; with none, no `coverVideo`), never on anyone else's profile;
 *  - «رحلة Kabso»: CRUD, «الأحدث» unique, order, renumbering, the 30 limit, validation, another owner's 404;
 *  - «رسمي»: mark / unmark (own published post only), `Post.official`, the list pinned first then newest;
 *  - «لوحة المؤسس»: exact numbers from seeded rows, the 60 s cache, 403 for everyone else;
 *  - «اقترح ميزة / أبلغ عن موظف»: both kinds with private pictures, validation, the 3-per-24-hours limit, the owners'
 *    notification (never the reported staff member), the panel inbox for OWNER only (staff 403), status changes, the
 *    pictures, audits;
 *  - no leak: the dashboard and the inbox never appear in public responses; revoking the role ends it all at once.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { grantRoleIn, revokeRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { DASHBOARD_CACHE_KEY } from '../src/modules/owner-profile/owner-core.js';
import { OwnerProfileService } from '../src/modules/owner-profile/owner-profile.service.js';
import { OwnerAnnouncementsService } from '../src/modules/owner-profile/owner-announcements.service.js';
import { dayStart } from '../src/modules/recharge/recharge-rules.js';
import { REDIS } from '../src/redis/redis.module.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { mp4 } from './helpers/mp4.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  settle,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';
import type { Redis } from 'ioredis';

const COOKIE = '__Host-kabso_admin';
const ZONE = 'Asia/Riyadh';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  readonly token: string;
}
interface Admin extends TestUser {
  cookie: string;
  csrf: string;
}

describe('D301 contract coverage', () => {
  it('openapi v1.95-social declares the owner operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'setMyCoverVideo PUT /api/v1/me/cover-video/{lang}',
        'removeMyCoverVideo DELETE /api/v1/me/cover-video/{lang}',
        'markPostOfficial PUT /api/v1/posts/{postId}/official',
        'unmarkPostOfficial DELETE /api/v1/posts/{postId}/official',
        'listUserOfficialPosts GET /api/v1/users/{username}/official-posts',
        'listUserJourney GET /api/v1/users/{username}/journey',
        'createOwnerJourneyMilestone POST /api/v1/owner/journey',
        'reorderOwnerJourney PUT /api/v1/owner/journey/order',
        'updateOwnerJourneyMilestone PATCH /api/v1/owner/journey/{milestoneId}',
        'deleteOwnerJourneyMilestone DELETE /api/v1/owner/journey/{milestoneId}',
        'getOwnerDashboard GET /api/v1/owner/dashboard',
        'createOwnerFeedback POST /api/v1/owner/feedback',
        'searchOwnerFeedbackStaff GET /api/v1/owner/feedback/staff',
        'listAdminOwnerInbox GET /api/v1/admin/owner-inbox',
        'getAdminOwnerInboxItem GET /api/v1/admin/owner-inbox/{feedbackId}',
        'updateAdminOwnerInboxStatus PUT /api/v1/admin/owner-inbox/{feedbackId}/status',
        'getAdminOwnerInboxImage GET /api/v1/admin/owner-inbox/{feedbackId}/images/{index}',
        'createOwnerAnnouncement POST /api/v1/owner/announcements',
        'updateOwnerAnnouncement PATCH /api/v1/owner/announcements/{postId}',
        'getSearchFeatured GET /api/v1/search/featured',
      ]),
    );
  });
});

describe('D301 the app owner profile', { timeout: 900_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const issueOf = (res: request.Response) =>
    (res.body as { error: { details?: { field: string; issue: string }[] } }).error.details?.[0];
  const codeOf = (res: request.Response) => (res.body as { error?: { code?: string } }).error?.code;

  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).trim().toLowerCase(),
      password: payload.password,
      token: res.body.tokens.accessToken as string,
    };
  };
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  const grant = (u: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, u.email, role as never)));
  const panelLogin = async (p: TestUser): Promise<Admin> => {
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: p.email, password: p.password });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    const pending = cookieOf(res);
    const csrf = res.body.csrfToken as string;
    const enrol = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf);
    const secret = enrol.body.secret as string;
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: totpCode(secret, Date.now()) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { ...p, cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const aput = (a: Admin, path: string, body: object) =>
    ctx.http.put(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);

  const get = (u: TestUser, path: string, lang?: string) => {
    const r = ctx.http.get(`/api/v1${path}`).set(auth(u));
    return lang ? r.set('Accept-Language', lang) : r;
  };
  const send = (u: TestUser, method: 'post' | 'put' | 'patch' | 'delete', path: string, body?: object) => {
    const r = ctx.http[method](`/api/v1${path}`).set(auth(u));
    return body === undefined ? r : r.send(body);
  };

  /** The app's video flow: a poster, the video's slot, complete with {posterId}. */
  const uploadVideo = async (u: TestUser, kind: string, durationMs = 12_000): Promise<string> => {
    const jpg = await sharp({ create: { width: 540, height: 960, channels: 3, background: '#a33' } })
      .jpeg()
      .toBuffer();
    const p = await send(u, 'post', '/media/uploads', {
      kind: 'VIDEO_POSTER',
      contentType: 'image/jpeg',
      byteSize: jpg.length,
    });
    expect(p.status, JSON.stringify(p.body)).toBe(201);
    expect(storage.upload(p.body.uploadUrl as string, jpg, 'image/jpeg')).toBe(true);
    const posterDone = await send(u, 'post', `/media/uploads/${p.body.uploadId as string}/complete`);
    expect(posterDone.status).toBe(200);
    const bytes = mp4({ durationMs, width: 1080, height: 1920 });
    const v = await send(u, 'post', '/media/uploads', {
      kind,
      contentType: 'video/mp4',
      byteSize: bytes.length,
    });
    expect(v.status, JSON.stringify(v.body)).toBe(201);
    expect(storage.upload(v.body.uploadUrl as string, bytes, 'video/mp4')).toBe(true);
    const done = await send(u, 'post', `/media/uploads/${v.body.uploadId as string}/complete`, {
      posterId: posterDone.body.id as string,
    });
    expect(done.status, JSON.stringify(done.body)).toBe(200);
    return done.body.id as string;
  };
  /** A pending private OWNER_FEEDBACK_IMAGE upload (never completed). */
  const feedbackImage = async (u: TestUser): Promise<string> => {
    const png = await sharp({ create: { width: 300, height: 200, channels: 3, background: '#0a0' } })
      .png()
      .toBuffer();
    const r = await send(u, 'post', '/media/uploads', {
      kind: 'OWNER_FEEDBACK_IMAGE',
      contentType: 'image/png',
      byteSize: png.length,
    });
    expect(r.status, JSON.stringify(r.body)).toBe(201);
    expect(storage.upload(r.body.uploadUrl as string, png, 'image/png')).toBe(true);
    return r.body.uploadId as string;
  };
  const post = async (u: TestUser, text: string): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ text });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const audits = (action: string) => ctx.prisma.auditLog.findMany({ where: { action } });

  let owner: TestUser;
  let owner2: TestUser;
  let moderator: TestUser;
  let support: TestUser;
  let alice: TestUser;
  let bob: TestUser;
  let carol: TestUser;

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        MEDIA_UPLOADS_ENABLED: 'true',
        S3_BUCKET: 'kabso-media-test',
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        ADMIN_DASHBOARD_TIME_ZONE: ZONE,
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        RATE_LIMIT_MEDIA_UPLOAD_USER: '100000/900',
        RATE_LIMIT_PROFILE_USER: '100000/900',
        RATE_LIMIT_AUTHENTICATED_USER: '100000/900',
      },
      [{ token: OBJECT_STORAGE, value: storage }],
    );
    owner = await signup();
    owner2 = await signup();
    moderator = await signup();
    support = await signup();
    alice = await signup();
    bob = await signup();
    carol = await signup();
    await grant(owner, 'OWNER');
    await grant(owner2, 'OWNER');
    await grant(moderator, 'MODERATION');
    await grant(support, 'SUPPORT');
  });

  afterAll(async () => {
    await ctx?.close();
  });

  describe('owner-only guards', () => {
    it('refuses every owner operation to a plain user and to a staff member with 403 OWNER_ONLY', async () => {
      const someone = randomUUID();
      const p = await post(alice, 'not official');
      for (const u of [alice, moderator]) {
        const calls: (() => request.Test)[] = [
          () => send(u, 'put', '/me/cover-video/ar', { mediaId: someone }),
          () => send(u, 'delete', '/me/cover-video/en'),
          () =>
            send(u, 'post', '/owner/journey', {
              titleAr: 'أ',
              titleEn: 'A',
              year: 2026,
              month: 1,
              icon: 'rocket',
            }),
          () => send(u, 'patch', `/owner/journey/${someone}`, { titleAr: 'ب' }),
          () => send(u, 'delete', `/owner/journey/${someone}`),
          () => send(u, 'put', '/owner/journey/order', { ids: [] }),
          () => send(u, 'put', `/posts/${p}/official`),
          () => send(u, 'delete', `/posts/${p}/official`),
          () => get(u, '/owner/dashboard'),
          () =>
            send(u, 'post', '/media/uploads', {
              kind: 'PROFILE_COVER_VIDEO',
              contentType: 'video/mp4',
              byteSize: 1000,
            }),
        ];
        for (const call of calls) {
          const res = await call();
          expect(res.status, JSON.stringify(res.body)).toBe(403);
          expect(codeOf(res)).toBe('OWNER_ONLY');
        }
      }
      expectContract(await get(alice, '/owner/dashboard'), 'getOwnerDashboard');
      expectContract(await send(alice, 'put', `/posts/${p}/official`), 'markPostOfficial');
      expect(await ctx.prisma.ownerJourneyMilestone.count()).toBe(0);
      expect((await ctx.prisma.post.findUniqueOrThrow({ where: { id: p } })).officialAt).toBeNull();
    });

    it('marks the owner on PublicProfile and Me, nobody else', async () => {
      const prof = await get(alice, `/users/${owner.username}`);
      expect(prof.status).toBe(200);
      expectContract(prof, 'getPublicProfile');
      expect(prof.body.kabsoOwner).toBe(true);
      expect(prof.body.coverVideo).toBeUndefined();
      const me = await get(owner, '/me');
      expectContract(me, 'getMe');
      expect(me.body.kabsoOwner).toBe(true);
      for (const u of [alice, moderator]) {
        const other = await get(owner, `/users/${u.username}`);
        expect(other.body.kabsoOwner).toBeUndefined();
        expect((await get(u, '/me')).body.kabsoOwner).toBeUndefined();
      }
    });
  });

  describe('the cover video «فيديو الغلاف»', () => {
    it('sets Arabic, then English, replaces and removes per language; the profile carries both, the app picks', async () => {
      const ar = await uploadVideo(owner, 'PROFILE_COVER_VIDEO');
      const set = await send(owner, 'put', '/me/cover-video/ar', { mediaId: ar });
      expect(set.status, JSON.stringify(set.body)).toBe(200);
      expectContract(set, 'setMyCoverVideo');
      expect(set.body.ar.url).toBe(`https://media.example.test/media/${ar}/video.mp4`);
      expect(set.body.ar.posterUrl).toMatch(/^https:\/\/media\.example\.test\/media\/.+\.webp$/);
      expect(set.body.ar.durationMs).toBe(12_000);
      expect(set.body.en).toBeUndefined();
      // Only Arabic: every viewer (Arabic or English app) gets that one (the app falls back to it).
      for (const lang of ['ar', 'en']) {
        const prof = await get(alice, `/users/${owner.username}`, lang);
        expectContract(prof, 'getPublicProfile');
        expect(Object.keys(prof.body.coverVideo as object)).toEqual(['ar']);
      }
      const en = await uploadVideo(owner, 'PROFILE_COVER_VIDEO', 30_000);
      const setEn = await send(owner, 'put', '/me/cover-video/en', { mediaId: en });
      expect(setEn.status).toBe(200);
      expect(Object.keys(setEn.body as object).sort()).toEqual(['ar', 'en']);
      const both = await get(bob, `/users/${owner.username}`, 'en');
      expect(both.body.coverVideo.en.url).toContain(en);
      expect(both.body.coverVideo.ar.url).toContain(ar);
      const me = await get(owner, '/me');
      expectContract(me, 'getMe');
      expect(me.body.coverVideo.en.durationMs).toBe(30_000);
      // The same video again changes nothing; a replacement deletes the old asset.
      expect((await send(owner, 'put', '/me/cover-video/ar', { mediaId: ar })).status).toBe(200);
      const ar2 = await uploadVideo(owner, 'PROFILE_COVER_VIDEO');
      expect((await send(owner, 'put', '/me/cover-video/ar', { mediaId: ar2 })).status).toBe(200);
      expect(await ctx.prisma.mediaAsset.findUnique({ where: { id: ar } })).toBeNull();
      // A used video, a reel video or a bad language: refused.
      expect(issueOf(await send(owner, 'put', '/me/cover-video/en', { mediaId: ar2 }))).toEqual({
        field: 'mediaId',
        issue: 'invalid_value',
      });
      const reel = await uploadVideo(owner, 'REEL_VIDEO');
      expect((await send(owner, 'put', '/me/cover-video/en', { mediaId: reel })).status).toBe(400);
      expect((await send(owner, 'put', '/me/cover-video/fr', { mediaId: ar2 })).status).toBe(404);
      // Remove Arabic: only English left (everyone sees English); remove again: idempotent.
      const rm = await send(owner, 'delete', '/me/cover-video/ar');
      expect(rm.status).toBe(200);
      expectContract(rm, 'removeMyCoverVideo');
      expect(Object.keys(rm.body as object)).toEqual(['en']);
      expect((await send(owner, 'delete', '/me/cover-video/ar')).status).toBe(200);
      expect(
        Object.keys((await get(alice, `/users/${owner.username}`, 'ar')).body.coverVideo as object),
      ).toEqual(['en']);
      // None: no coverVideo at all (the app shows the cover picture).
      expect((await send(owner, 'delete', '/me/cover-video/en')).status).toBe(200);
      expect((await get(alice, `/users/${owner.username}`)).body.coverVideo).toBeUndefined();
      expect((await audits('owner.cover_video.set')).length).toBe(3);
      expect((await audits('owner.cover_video.remove')).length).toBe(2);
      // Put Arabic back for the rest of the file.
      const ar3 = await uploadVideo(owner, 'PROFILE_COVER_VIDEO');
      expect((await send(owner, 'put', '/me/cover-video/ar', { mediaId: ar3 })).status).toBe(200);
    });
  });

  describe('«رحلة Kabso»', () => {
    it('creates, edits, keeps one «الأحدث», reorders, deletes and renumbers; everyone reads it in order', async () => {
      const mk = async (titleAr: string, titleEn: string, month: number, extra: object = {}) => {
        const res = await send(owner, 'post', '/owner/journey', {
          titleAr,
          titleEn,
          lineAr: 'سطر',
          lineEn: '  ',
          year: 2026,
          month,
          icon: 'rocket',
          ...extra,
        });
        expect(res.status, JSON.stringify(res.body)).toBe(201);
        expectContract(res, 'createOwnerJourneyMilestone');
        return res.body as { id: string; position: number; latest: boolean; lineEn: string | null };
      };
      const a = await mk('إطلاق كابسو لايف', 'Kabso Live launch', 1);
      const b = await mk('أول 100 ألف مستخدم', 'First 100K users', 3, { icon: 'users', latest: true });
      const c = await mk('أول وكالة', 'First agency', 5, { icon: 'agency', latest: true });
      expect([a.position, b.position, c.position]).toEqual([0, 1, 2]);
      expect(a.lineEn).toBeNull();
      const list = await get(alice, `/users/${owner.username}/journey`);
      expectContract(list, 'listUserJourney');
      const rows = list.body.data as { id: string; latest: boolean }[];
      expect(rows.map((r) => r.id)).toEqual([a.id, b.id, c.id]);
      expect(rows.filter((r) => r.latest).map((r) => r.id)).toEqual([c.id]);
      // Edit: any field; latest moves.
      const up = await send(owner, 'patch', `/owner/journey/${a.id}`, {
        titleEn: 'Launch',
        latest: true,
        icon: 'star',
      });
      expect(up.status, JSON.stringify(up.body)).toBe(200);
      expectContract(up, 'updateOwnerJourneyMilestone');
      expect(up.body).toMatchObject({
        titleEn: 'Launch',
        latest: true,
        icon: 'star',
        titleAr: 'إطلاق كابسو لايف',
      });
      expect(await ctx.prisma.ownerJourneyMilestone.count({ where: { latest: true } })).toBe(1);
      // Validation.
      const bad = await send(owner, 'post', '/owner/journey', {
        titleAr: 'x',
        titleEn: 'x',
        year: 2026,
        month: 13,
        icon: 'rocket',
      });
      expect(issueOf(bad)?.field).toBe('month');
      expect(
        issueOf(
          await send(owner, 'post', '/owner/journey', {
            titleAr: 'x',
            titleEn: 'x',
            year: 2026,
            month: 1,
            icon: 'bomb',
          }),
        )?.field,
      ).toBe('icon');
      expect(
        (
          await send(owner, 'post', '/owner/journey', {
            titleAr: ' ',
            titleEn: 'x',
            year: 2026,
            month: 1,
            icon: 'flag',
          })
        ).status,
      ).toBe(400);
      expect((await send(owner, 'patch', `/owner/journey/${a.id}`, {})).status).toBe(400);
      // Reorder: exactly the owner's ids.
      const order = await send(owner, 'put', '/owner/journey/order', { ids: [c.id, a.id, b.id] });
      expect(order.status, JSON.stringify(order.body)).toBe(200);
      expectContract(order, 'reorderOwnerJourney');
      expect((order.body.data as { id: string; position: number }[]).map((r) => [r.id, r.position])).toEqual([
        [c.id, 0],
        [a.id, 1],
        [b.id, 2],
      ]);
      expect(issueOf(await send(owner, 'put', '/owner/journey/order', { ids: [c.id, a.id] }))).toEqual({
        field: 'ids',
        issue: 'invalid_value',
      });
      expect((await send(owner, 'put', '/owner/journey/order', { ids: [c.id, a.id, a.id] })).status).toBe(
        400,
      );
      // Another owner cannot touch it (404) and has an empty journey of his own.
      expect((await send(owner2, 'patch', `/owner/journey/${a.id}`, { titleAr: 'ج' })).status).toBe(404);
      expect((await send(owner2, 'delete', `/owner/journey/${a.id}`)).status).toBe(404);
      expect((await get(alice, `/users/${owner2.username}/journey`)).body.data).toEqual([]);
      // A plain user's journey is empty; an unknown user is 404.
      expect((await get(owner, `/users/${alice.username}/journey`)).body.data).toEqual([]);
      expect((await get(owner, '/users/no_such_user_d301/journey')).status).toBe(404);
      // Delete renumbers.
      const del = await send(owner, 'delete', `/owner/journey/${a.id}`);
      expect(del.status).toBe(204);
      expectContract(del, 'deleteOwnerJourneyMilestone');
      const after = (await get(bob, `/users/${owner.username}/journey`)).body.data as {
        id: string;
        position: number;
      }[];
      expect(after.map((r) => [r.id, r.position])).toEqual([
        [c.id, 0],
        [b.id, 1],
      ]);
      expect((await send(owner, 'delete', `/owner/journey/${a.id}`)).status).toBe(404);
      for (const action of ['create', 'update', 'reorder', 'delete']) {
        expect((await audits(`owner.journey.${action}`)).length).toBeGreaterThan(0);
      }
    });

    it('keeps at most 30 milestones (409 OWNER_JOURNEY_LIMIT)', async () => {
      const have = await ctx.prisma.ownerJourneyMilestone.count({ where: { ownerId: owner2.id } });
      for (let i = have; i < 30; i++) {
        const r = await send(owner2, 'post', '/owner/journey', {
          titleAr: `محطة ${String(i)}`,
          titleEn: `Step ${String(i)}`,
          year: 2027,
          month: (i % 12) + 1,
          icon: 'flag',
        });
        expect(r.status).toBe(201);
      }
      const over = await send(owner2, 'post', '/owner/journey', {
        titleAr: 'زيادة',
        titleEn: 'One more',
        year: 2027,
        month: 1,
        icon: 'flag',
      });
      expect(over.status).toBe(409);
      expect(codeOf(over)).toBe('OWNER_JOURNEY_LIMIT');
      expectContract(over, 'createOwnerJourneyMilestone');
      expect(await ctx.prisma.ownerJourneyMilestone.count({ where: { ownerId: owner2.id } })).toBe(30);
      await ctx.prisma.ownerJourneyMilestone.deleteMany({ where: { ownerId: owner2.id } });
    });
  });

  describe('«إعلانات رسمية»', () => {
    it('marks the owner’s own posts official; lists them pinned first, then newest; never another’s', async () => {
      const p1 = await post(owner, 'إطلاق الإصدار 2.0 من كابسو لايف');
      const p2 = await post(owner, 'تحديث قواعد المجتمع والإشراف');
      const p3 = await post(owner, 'شكراً لمليون مستخدم');
      const plain = await post(owner, 'منشور عادي');
      for (const id of [p1, p2, p3]) {
        const res = await send(owner, 'put', `/posts/${id}/official`);
        expect(res.status, JSON.stringify(res.body)).toBe(200);
        expectContract(res, 'markPostOfficial');
        expect(res.body.official).toBe(true);
      }
      // Idempotent (one audit row per change).
      expect((await send(owner, 'put', `/posts/${p1}/official`)).status).toBe(200);
      expect((await audits('owner.post.official')).length).toBe(3);
      // The oldest is pinned: first; then newest first.
      expect((await send(owner, 'put', `/posts/${p1}/pin`)).status).toBe(200);
      const list = await get(alice, `/users/${owner.username}/official-posts?limit=10`);
      expect(list.status, JSON.stringify(list.body)).toBe(200);
      expectContract(list, 'listUserOfficialPosts');
      expect((list.body.data as { id: string }[]).map((p) => p.id)).toEqual([p1, p3, p2]);
      // A plain post of the owner is not official (no field); the grid shows the flag.
      const grid = await get(alice, `/users/${owner.username}/posts?limit=20`);
      expectContract(grid, 'listUserPosts');
      const byId = new Map((grid.body.data as { id: string; official?: boolean }[]).map((p) => [p.id, p]));
      expect(byId.get(plain)?.official).toBeUndefined();
      expect(byId.get(p2)?.official).toBe(true);
      // Paging.
      const first = await get(alice, `/users/${owner.username}/official-posts?limit=2`);
      expect((first.body.data as { id: string }[]).map((p) => p.id)).toEqual([p1, p3]);
      const next = await get(
        alice,
        `/users/${owner.username}/official-posts?limit=2&cursor=${encodeURIComponent(first.body.page.nextCursor as string)}`,
      );
      expect((next.body.data as { id: string }[]).map((p) => p.id)).toEqual([p2]);
      // Unmark.
      const un = await send(owner, 'delete', `/posts/${p2}/official`);
      expectContract(un, 'unmarkPostOfficial');
      expect(un.body.official).toBeUndefined();
      expect(
        ((await get(bob, `/users/${owner.username}/official-posts`)).body.data as { id: string }[]).map(
          (p) => p.id,
        ),
      ).toEqual([p1, p3]);
      // Another owner cannot mark the owner's post (404: not his); a plain user's list is empty.
      expect((await send(owner2, 'put', `/posts/${p2}/official`)).status).toBe(404);
      await post(alice, 'alice');
      expect((await get(owner, `/users/${alice.username}/official-posts`)).body.data).toEqual([]);
    });
  });

  describe('«لوحة المؤسس»', () => {
    it('counts online now, lives now and today’s USD income exactly; cached 60 s; 403 for everyone else', async () => {
      const redis = ctx.app.get<Redis>(REDIS);
      const now = new Date();
      const since = dayStart(now, ZONE);
      await settle(ctx);
      // Online: alice and bob now (and a SUSPENDED account and one 10 minutes ago that do not count).
      await ctx.prisma.user.updateMany({ data: { lastActiveAt: null } });
      await ctx.prisma.user.updateMany({
        where: { id: { in: [alice.id, bob.id] } },
        data: { lastActiveAt: now },
      });
      await ctx.prisma.user.update({
        where: { id: carol.id },
        data: { lastActiveAt: new Date(now.getTime() - 10 * 60_000) },
      });
      // Lives: two LIVE, one ENDED.
      await ctx.prisma.liveRoom.create({
        data: { hostUserId: alice.id, title: 'a', lastHeartbeatAt: now, startedAt: now },
      });
      await ctx.prisma.liveRoom.create({
        data: { hostUserId: bob.id, title: 'b', lastHeartbeatAt: now, startedAt: now },
      });
      await ctx.prisma.liveRoom.create({
        data: {
          hostUserId: carol.id,
          title: 'c',
          lastHeartbeatAt: now,
          startedAt: now,
          status: 'ENDED',
          endedAt: now,
          endReason: 'HOST_ENDED',
        },
      });
      // Income: a card order today 62.50 less a 2.50 refund, one yesterday; an agent top-up today 1.25 USD, one in EUR.
      for (const [credited, amount, refunded] of [
        [now, 6250, 250],
        [new Date(since.getTime() - 3_600_000), 9900, 0],
      ] as const) {
        const terms = randomUUID();
        await ctx.prisma.topupTermsAcceptance.create({
          data: {
            id: terms,
            userId: alice.id,
            termsVersion: 't1',
            termsText: 'x',
            locale: 'ar',
            acceptedAt: now,
          },
        });
        await ctx.prisma.topupOrder.create({
          data: {
            id: randomUUID(),
            userId: alice.id,
            termsAcceptanceId: terms,
            packageId: '5000',
            coins: 5000n,
            amountMinor: amount,
            refundedMinor: refunded,
            currency: 'USD',
            paymentMethodTypes: ['card'],
            status: 'PAID',
            stripePaymentIntentId: `pi_d301_${String(amount)}`,
            creditedAt: credited,
            createdAt: credited,
          },
        });
      }
      const appId = randomUUID();
      await ctx.prisma.rechargeAgentApplication.create({
        data: { id: appId, userId: bob.id, status: 'APPROVED', decidedAt: now, purgedAt: now },
      });
      await ctx.prisma.rechargeAgent.create({
        data: {
          userId: bob.id,
          applicationId: appId,
          status: 'ACTIVE',
          code: 'coin9301',
          codeNumber: 9301,
          countries: ['SA'],
          locations: [],
          paymentTypes: [],
          activatedAt: now,
        },
      });
      for (const [paid, currency] of [
        [125n, 'USD'],
        [5000n, 'EUR'],
      ] as const) {
        await ctx.prisma.rechargeTopup.create({
          data: {
            agentUserId: bob.id,
            coins: 100_000n,
            tier: 'T1',
            pricePerMillionMinor: 1000,
            expectedMinor: paid,
            paidMinor: paid,
            currency,
            first: currency === 'USD',
            createdAt: now,
          },
        });
      }
      // Owner (PP-58, «كيف له دخل!!»): an agent's resale of coins to a user is the agent's money, never Kabso's income.
      await ctx.prisma.rechargeSale.create({
        data: {
          agentUserId: bob.id,
          sellerUserId: bob.id,
          buyerUserId: alice.id,
          clientId: randomUUID(),
          coins: 90_000n,
          createdAt: now,
        },
      });
      await redis.del(`${ctx.config.redis.keyPrefix}${DASHBOARD_CACHE_KEY}`, DASHBOARD_CACHE_KEY);
      const computed = await ctx.app.get(OwnerProfileService).computeDashboard(now);
      expect(computed).toMatchObject({
        onlineNow: 2,
        onlineWindowMinutes: 5,
        liveRoomsNow: 2,
        income: {
          currency: 'USD',
          amountMinor: 6125,
          websiteMinor: 6000,
          agentsMinor: 125,
          timeZone: ZONE,
          // Owner (PP-58): another currency is its own line, never converted.
          otherCurrencies: [{ currency: 'EUR', websiteMinor: 0, agentsMinor: 5000, amountMinor: 5000 }],
        },
      });
      const res = await get(owner, '/owner/dashboard');
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'getOwnerDashboard');
      expect(res.body).toMatchObject({ onlineNow: 2, liveRoomsNow: 2, income: { amountMinor: 6125 } });
      // Cached: a new live does not show until the value expires (one value for every owner).
      await ctx.prisma.liveRoom.create({
        data: { hostUserId: owner2.id, title: 'd', lastHeartbeatAt: now, startedAt: now },
      });
      const again = await get(owner2, '/owner/dashboard');
      expect(again.body.liveRoomsNow).toBe(2);
      expect(again.body.generatedAt).toBe(res.body.generatedAt);
      const ttl = await redis.ttl(`${ctx.config.redis.keyPrefix}${DASHBOARD_CACHE_KEY}`);
      const ttlBare = await redis.ttl(DASHBOARD_CACHE_KEY);
      expect(Math.max(ttl, ttlBare)).toBeGreaterThan(0);
      expect(Math.max(ttl, ttlBare)).toBeLessThanOrEqual(60);
      await redis.del(`${ctx.config.redis.keyPrefix}${DASHBOARD_CACHE_KEY}`, DASHBOARD_CACHE_KEY);
      expect((await get(owner, '/owner/dashboard')).body.liveRoomsNow).toBe(3);
      // Everyone else: 403, staff included.
      for (const u of [alice, moderator, support])
        expect((await get(u, '/owner/dashboard')).status).toBe(403);
    });
  });

  describe('«اقترح ميزة / أبلغ عن موظف» → «صندوق المؤسس»', () => {
    let featureId: string;
    let reportId: string;

    it('finds Kabso Team accounts by @username or staff ID, never an OWNER', async () => {
      const byName = await get(
        alice,
        `/owner/feedback/staff?q=${encodeURIComponent(`@${moderator.username.slice(0, 6)}`)}`,
      );
      expect(byName.status).toBe(200);
      expectContract(byName, 'searchOwnerFeedbackStaff');
      expect((byName.body.data as { id: string }[]).map((s) => s.id)).toContain(moderator.id);
      const all = await get(alice, '/owner/feedback/staff');
      const ids = (all.body.data as { id: string; staffId: string | null }[]).map((s) => s.id);
      expect(ids).toEqual(expect.arrayContaining([moderator.id, support.id]));
      expect(ids).not.toContain(owner.id);
      expect(ids).not.toContain(alice.id);
      const modStaffId = (all.body.data as { id: string; staffId: string }[]).find(
        (s) => s.id === moderator.id,
      )!.staffId;
      expect(modStaffId).toMatch(/^Kabso\d+$/);
      const byId = await get(alice, `/owner/feedback/staff?q=${modStaffId}`);
      expect((byId.body.data as { id: string }[]).map((s) => s.id)).toEqual([moderator.id]);
      expect((await get(alice, `/owner/feedback/staff?q=${owner.username}`)).body.data).toEqual([]);
    });

    it('takes a suggestion and a staff report with private pictures; validates; notifies only the owners', async () => {
      await ctx.prisma.notification.deleteMany({});
      const img = await feedbackImage(alice);
      // A private kind is never completed.
      expect((await send(alice, 'post', `/media/uploads/${img}/complete`)).status).toBe(404);
      const feature = await send(alice, 'post', '/owner/feedback', {
        kind: 'FEATURE',
        text: '  أريد ميزة البث المشترك  ',
        imageUploadIds: [img],
      });
      expect(feature.status, JSON.stringify(feature.body)).toBe(201);
      expectContract(feature, 'createOwnerFeedback');
      featureId = feature.body.id as string;
      // Validation: two pictures on a suggestion, a staff report without the staff member, naming an OWNER or a
      // plain user, a suggestion naming someone, 1001 characters, a picture that is not the caller's pending upload.
      const twoImgs = [await feedbackImage(bob), await feedbackImage(bob)];
      expect(
        issueOf(
          await send(bob, 'post', '/owner/feedback', { kind: 'FEATURE', text: 'x', imageUploadIds: twoImgs }),
        )?.field,
      ).toBe('imageUploadIds');
      expect(
        issueOf(
          await send(bob, 'post', '/owner/feedback', {
            kind: 'STAFF_REPORT',
            text: 'x',
            category: 'RUDENESS',
          }),
        )?.field,
      ).toBe('staffUserId');
      for (const target of [owner.id, alice.id]) {
        expect(
          issueOf(
            await send(bob, 'post', '/owner/feedback', {
              kind: 'STAFF_REPORT',
              staffUserId: target,
              category: 'RUDENESS',
              text: 'x',
            }),
          ),
        ).toEqual({ field: 'staffUserId', issue: 'invalid_value' });
      }
      expect(
        (await send(bob, 'post', '/owner/feedback', { kind: 'FEATURE', text: 'x', category: 'OTHER' }))
          .status,
      ).toBe(400);
      expect(
        (await send(bob, 'post', '/owner/feedback', { kind: 'FEATURE', text: 'y'.repeat(1001) })).status,
      ).toBe(400);
      expect(
        issueOf(
          await send(bob, 'post', '/owner/feedback', { kind: 'FEATURE', text: 'x', imageUploadIds: [img] }),
        ),
      ).toEqual({
        field: 'imageUploadIds',
        issue: 'invalid_value',
      });
      expect(await ctx.prisma.ownerFeedback.count({ where: { senderId: bob.id } })).toBe(0);
      // The staff report, with two pictures.
      const evidence = [await feedbackImage(bob), await feedbackImage(bob)];
      const report = await send(bob, 'post', '/owner/feedback', {
        kind: 'STAFF_REPORT',
        staffUserId: moderator.id,
        category: 'ABUSE_OF_POWER',
        text: 'حظرني بدون سبب',
        imageUploadIds: evidence,
      });
      expect(report.status, JSON.stringify(report.body)).toBe(201);
      reportId = report.body.id as string;
      const stored = await ctx.prisma.ownerFeedback.findUniqueOrThrow({ where: { id: reportId } });
      expect(stored.imageKeys).toEqual([
        `private/owner-feedback/${reportId}/0.webp`,
        `private/owner-feedback/${reportId}/1.webp`,
      ]);
      expect(storage.objects.has(stored.imageKeys[0]!)).toBe(true);
      // Notified: the two owners only (two items each); never the moderator reported, nor the senders.
      const rows = await ctx.prisma.notification.findMany({ where: { type: 'OWNER_FEEDBACK_NEW' } });
      expect(rows.map((r) => r.recipientId).sort()).toEqual(
        [owner.id, owner.id, owner2.id, owner2.id].sort(),
      );
      const list = await get(owner, '/notifications');
      expectContract(list, 'listNotifications');
      const mine = (
        list.body.data as { type: string; target: { type: string; id: string; feedbackKind: string } }[]
      ).filter((n) => n.type === 'OWNER_FEEDBACK_NEW');
      expect(mine.map((n) => [n.target.type, n.target.id, n.target.feedbackKind])).toEqual([
        ['OWNER_FEEDBACK', reportId, 'STAFF_REPORT'],
        ['OWNER_FEEDBACK', featureId, 'FEATURE'],
      ]);
      expect(JSON.stringify(list.body)).not.toContain('حظرني');
      for (const u of [moderator, alice, bob]) {
        const theirs = await get(u, '/notifications');
        expect(JSON.stringify(theirs.body)).not.toContain('OWNER_FEEDBACK');
      }
      const audit = await audits('owner.feedback.create');
      expect(audit.length).toBe(2);
      expect(JSON.stringify(audit.map((a) => a.metadata))).not.toContain('حظرني');
    });

    it('allows 3 per account in any 24 hours (429 RATE_LIMITED with Retry-After)', async () => {
      // alice sent one; two more pass, the fourth is refused.
      for (const text of ['two', 'three']) {
        expect((await send(alice, 'post', '/owner/feedback', { kind: 'FEATURE', text })).status).toBe(201);
      }
      const fourth = await send(alice, 'post', '/owner/feedback', { kind: 'FEATURE', text: 'four' });
      expect(fourth.status).toBe(429);
      expect(codeOf(fourth)).toBe('RATE_LIMITED');
      expectContract(fourth, 'createOwnerFeedback');
      const retry = Number(fourth.headers['retry-after']);
      expect(retry).toBeGreaterThan(0);
      expect(retry).toBeLessThanOrEqual(24 * 3600);
      expect(await ctx.prisma.ownerFeedback.count({ where: { senderId: alice.id } })).toBe(3);
      // A day later (the oldest out of the window) the next one passes.
      await ctx.prisma.ownerFeedback.updateMany({
        where: { id: featureId },
        data: { createdAt: new Date(Date.now() - 25 * 3600_000) },
      });
      expect(
        (await send(alice, 'post', '/owner/feedback', { kind: 'FEATURE', text: 'next day' })).status,
      ).toBe(201);
    });

    it('shows «صندوق المؤسس» to the OWNER only; staff never see it; read / done; pictures; audited', async () => {
      const ownerPanel = await panelLogin(owner);
      const modPanel = await panelLogin(moderator);
      const supPanel = await panelLogin(support);
      for (const staff of [modPanel, supPanel]) {
        for (const path of [
          '/admin/owner-inbox',
          `/admin/owner-inbox/${reportId}`,
          `/admin/owner-inbox/${reportId}/images/0`,
        ]) {
          const res = await aget(staff, path);
          expect(res.status, path).toBe(403);
        }
        expect((await aput(staff, `/admin/owner-inbox/${reportId}/status`, { status: 'DONE' })).status).toBe(
          403,
        );
        // The session's capabilities do not include it.
        const session = await aget(staff, '/admin/auth/session');
        expect(JSON.stringify(session.body)).not.toContain('owner.inbox');
      }
      const list = await aget(ownerPanel, '/admin/owner-inbox');
      expect(list.status, JSON.stringify(list.body)).toBe(200);
      expectContract(list, 'listAdminOwnerInbox');
      expect(list.body.counts).toEqual({ NEW: 5, READ: 0, DONE: 0 });
      const first = (list.body.data as { id: string }[])[0]!;
      expect(first.id).not.toBe(featureId);
      const onlyReports = await aget(ownerPanel, '/admin/owner-inbox?kind=STAFF_REPORT');
      expect((onlyReports.body.data as { id: string }[]).map((i) => i.id)).toEqual([reportId]);
      const item = await aget(ownerPanel, `/admin/owner-inbox/${reportId}`);
      expect(item.status).toBe(200);
      expectContract(item, 'getAdminOwnerInboxItem');
      expect(item.body).toMatchObject({
        kind: 'STAFF_REPORT',
        status: 'READ',
        category: 'ABUSE_OF_POWER',
        text: 'حظرني بدون سبب',
        imageCount: 2,
        sender: { id: bob.id, username: bob.username },
        staff: { id: moderator.id },
      });
      expect(item.body.staff.staffId).toMatch(/^Kabso\d+$/);
      const pic = await aget(ownerPanel, `/admin/owner-inbox/${reportId}/images/1`);
      expect(pic.status).toBe(200);
      expect(pic.headers['content-type']).toBe('image/webp');
      expect(pic.headers['cache-control']).toBe('private, no-store');
      expect((await aget(ownerPanel, `/admin/owner-inbox/${reportId}/images/2`)).status).toBe(404);
      const done = await aput(ownerPanel, `/admin/owner-inbox/${reportId}/status`, { status: 'DONE' });
      expect(done.status, JSON.stringify(done.body)).toBe(200);
      expectContract(done, 'updateAdminOwnerInboxStatus');
      expect(done.body.status).toBe('DONE');
      expect(done.body.doneAt).not.toBeNull();
      expect(
        (await aput(ownerPanel, `/admin/owner-inbox/${reportId}/status`, { status: 'LATER' })).status,
      ).toBe(400);
      expect((await aget(ownerPanel, '/admin/owner-inbox')).body.counts).toEqual({
        NEW: 4,
        READ: 0,
        DONE: 1,
      });
      expect((await aget(ownerPanel, '/admin/owner-inbox?status=DONE')).body.data).toHaveLength(1);
      expect((await audits('admin.owner_inbox.view')).length).toBe(1);
      expect((await audits('admin.owner_inbox.status')).length).toBe(1);
      expect((await aget(ownerPanel, `/admin/owner-inbox/${randomUUID()}`)).status).toBe(404);
      // Owner (PP-58): kept until the owner deletes them — the row, its notifications and the private pictures.
      const adel = (a: Admin, path: string) =>
        ctx.http.delete(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf);
      expect((await adel(modPanel, `/admin/owner-inbox/${reportId}`)).status).toBe(403);
      const keys = (await ctx.prisma.ownerFeedback.findUniqueOrThrow({ where: { id: reportId } })).imageKeys;
      expect(keys.every((k) => storage.objects.has(k))).toBe(true);
      const del = await adel(ownerPanel, `/admin/owner-inbox/${reportId}`);
      expect(del.status).toBe(204);
      expectContract(del, 'deleteAdminOwnerInboxItem');
      expect(await ctx.prisma.ownerFeedback.findUnique({ where: { id: reportId } })).toBeNull();
      expect(keys.some((k) => storage.objects.has(k))).toBe(false);
      expect(await ctx.prisma.notification.count({ where: { ownerFeedbackId: reportId } })).toBe(0);
      const deleted = await audits('admin.owner_inbox.delete');
      expect(deleted).toHaveLength(1);
      expect(JSON.stringify(deleted[0]!.metadata)).not.toContain('حظرني');
      expect((await adel(ownerPanel, `/admin/owner-inbox/${reportId}`)).status).toBe(404);
    });
  });

  describe('bilingual announcements, first in the feed, told to everyone once (D301 follow-up)', () => {
    const announce = (u: TestUser, body: object) =>
      ctx.http
        .post('/api/v1/owner/announcements')
        .set(auth(u))
        .set('Idempotency-Key', randomUUID())
        .send(body);
    const feedIds = async (u: TestUser, tab: string) => {
      const res = await get(u, `/feed/posts?tab=${tab}&limit=20`);
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'listFeedPosts');
      return res.body.data as { id: string; text: string; official?: boolean }[];
    };
    const recipientsOf = async (postId: string) =>
      (
        await ctx.prisma.notification.findMany({
          where: { type: 'OWNER_ANNOUNCEMENT', postId },
          select: { recipientId: true },
        })
      )
        .map((r) => r.recipientId)
        .sort();
    let first: string;

    it('only the owner publishes or edits one (403 OWNER_ONLY); both captions are required', async () => {
      for (const u of [alice, moderator]) {
        const res = await announce(u, { textAr: 'أ', textEn: 'A' });
        expect(res.status).toBe(403);
        expect(codeOf(res)).toBe('OWNER_ONLY');
        expectContract(res, 'createOwnerAnnouncement');
        expect((await send(u, 'patch', `/owner/announcements/${randomUUID()}`, { textAr: 'ب' })).status).toBe(
          403,
        );
      }
      expect(issueOf(await announce(owner, { textAr: 'فقط عربي' }))?.field).toBe('textEn');
      const noKey = await ctx.http
        .post('/api/v1/owner/announcements')
        .set(auth(owner))
        .send({ textAr: 'a', textEn: 'b' });
      expect(issueOf(noKey)?.field).toBe('Idempotency-Key');
    });

    it('publishes in two languages; each viewer reads the caption of the app language (the account locale)', async () => {
      // carol is suspended: she gets nothing; alice switches her app to English.
      await ctx.prisma.user.update({ where: { id: carol.id }, data: { status: 'SUSPENDED' } });
      expect((await send(alice, 'patch', '/me', { locale: 'en' })).status).toBe(200);
      for (const u of [owner, bob, moderator]) {
        expect((await send(u, 'patch', '/me', { locale: 'ar' })).status).toBe(200);
      }
      const res = await announce(owner, {
        textAr: 'إطلاق الإصدار 2.0 من كابسو لايف',
        textEn: 'Kabso Live 2.0 is here',
      });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'createOwnerAnnouncement');
      first = res.body.id as string;
      expect(res.body).toMatchObject({
        official: true,
        text: 'إطلاق الإصدار 2.0 من كابسو لايف',
        texts: { ar: 'إطلاق الإصدار 2.0 من كابسو لايف', en: 'Kabso Live 2.0 is here' },
      });
      const en = await get(alice, `/posts/${first}`);
      expectContract(en, 'getPost');
      expect(en.body.text).toBe('Kabso Live 2.0 is here');
      expect((await get(bob, `/posts/${first}`)).body.text).toBe('إطلاق الإصدار 2.0 من كابسو لايف');
      expect((await audits('owner.announcement.publish')).filter((a) => a.targetId === first)).toHaveLength(
        1,
      );
    });

    it('is the first post of every posts tab, once; a newer one replaces it; un-marking removes it', async () => {
      for (const tab of ['mixed', 'following', 'trending']) {
        const ids = (await feedIds(bob, tab)).map((p) => p.id);
        expect(ids[0], tab).toBe(first);
        expect(
          ids.filter((id) => id === first),
          tab,
        ).toHaveLength(1);
      }
      // In English for an English account, at the top too.
      const top = (await feedIds(alice, 'mixed'))[0]!;
      expect(top).toMatchObject({ id: first, official: true, text: 'Kabso Live 2.0 is here' });
      // A later page never repeats it.
      const page1 = await get(bob, '/feed/posts?tab=trending&limit=1');
      if (page1.body.page.nextCursor) {
        const page2 = await get(
          bob,
          `/feed/posts?tab=trending&limit=50&cursor=${encodeURIComponent(page1.body.page.nextCursor as string)}`,
        );
        expect((page2.body.data as { id: string }[]).map((p) => p.id)).not.toContain(first);
      }
      // A newer announcement replaces it at once.
      const second = await announce(owner, {
        textAr: 'تحديث قواعد المجتمع',
        textEn: 'Community rules update',
      });
      expect(second.status).toBe(201);
      for (const tab of ['mixed', 'following', 'trending']) {
        expect((await feedIds(bob, tab))[0]!.id, tab).toBe(second.body.id);
      }
      // Un-marking it: the previous announcement is the latest official one again.
      expect((await send(owner, 'delete', `/posts/${second.body.id as string}/official`)).status).toBe(200);
      expect((await feedIds(bob, 'following'))[0]!.id).toBe(first);
      expect((await send(owner, 'put', `/posts/${second.body.id as string}/official`)).status).toBe(200);
      // A blocker of the owner never sees it.
      expect((await send(support, 'put', `/users/${owner.username}/block`)).status).toBeLessThan(300);
      expect((await feedIds(support, 'following')).map((p) => p.id)).not.toContain(second.body.id);
      expect((await send(support, 'delete', `/users/${owner.username}/block`)).status).toBeLessThan(300);
    });

    it('tells every ACTIVE account, staff included, once — in batches after the request, resumable', async () => {
      const service = ctx.app.get(OwnerAnnouncementsService);
      await service.drain();
      const expected = [owner2.id, moderator.id, support.id, alice.id, bob.id].sort();
      expect(await recipientsOf(first)).toEqual(expected);
      const job = await ctx.prisma.ownerAnnouncementFanout.findUniqueOrThrow({ where: { postId: first } });
      expect(job.doneAt).not.toBeNull();
      expect(job.recipients).toBe(expected.length);
      expect((await audits('owner.announcement.fanout_done')).some((a) => a.targetId === first)).toBe(true);
      // Resumable and idempotent: replaying the whole fan-out (small batches) writes nothing twice.
      await ctx.prisma.ownerAnnouncementFanout.update({
        where: { postId: first },
        data: { cursorUserId: null, doneAt: null, recipients: 0 },
      });
      let steps = 0;
      while ((await service.fanOutOnce(2)) !== null && steps < 20) steps += 1;
      expect(steps).toBeGreaterThanOrEqual(3);
      expect(await recipientsOf(first)).toEqual(expected);
      // Editing never notifies again; marking an already-told post official again neither.
      const before = await ctx.prisma.notification.count({ where: { type: 'OWNER_ANNOUNCEMENT' } });
      const edit = await send(owner, 'patch', `/owner/announcements/${first}`, {
        textEn: 'Kabso Live 2.0 has arrived',
      });
      expect(edit.status, JSON.stringify(edit.body)).toBe(200);
      expectContract(edit, 'updateOwnerAnnouncement');
      expect(edit.body.texts).toEqual({
        ar: 'إطلاق الإصدار 2.0 من كابسو لايف',
        en: 'Kabso Live 2.0 has arrived',
      });
      await send(owner, 'delete', `/posts/${first}/official`);
      await send(owner, 'put', `/posts/${first}/official`);
      await service.drain();
      expect(await ctx.prisma.notification.count({ where: { type: 'OWNER_ANNOUNCEMENT' } })).toBe(before);
      expect(await ctx.prisma.ownerAnnouncementFanout.count({ where: { postId: first } })).toBe(1);
      // Another owner's announcement is not his to edit.
      expect((await send(owner2, 'patch', `/owner/announcements/${first}`, { textAr: 'x' })).status).toBe(
        404,
      );
    });

    it('each recipient reads it in their language: the inbox row carries both captions', async () => {
      for (const [u, lang] of [
        [alice, 'en'],
        [moderator, 'ar'],
      ] as const) {
        const list = await get(u, '/notifications');
        expectContract(list, 'listNotifications');
        const row = (
          list.body.data as { type: string; target: { id: string; texts: { ar: string; en: string } } }[]
        ).find((n) => n.type === 'OWNER_ANNOUNCEMENT' && n.target.id === first)!;
        expect(row, lang).toBeDefined();
        expect(row.target.texts).toEqual({
          ar: 'إطلاق الإصدار 2.0 من كابسو لايف',
          en: 'Kabso Live 2.0 has arrived',
        });
      }
      expect(JSON.stringify((await get(carol, '/notifications')).body)).not.toContain('OWNER_ANNOUNCEMENT');
      await ctx.prisma.user.update({ where: { id: carol.id }, data: { status: 'ACTIVE' } });
    });
  });

  describe('the founder always in search (§10.112.9)', () => {
    it('is the primary ACTIVE owner for everyone; null across a block; never twice', async () => {
      const res = await get(alice, '/search/featured');
      expect(res.status).toBe(200);
      expectContract(res, 'getSearchFeatured');
      expect(res.body.owner).toMatchObject({ id: owner.id, username: owner.username, isSelf: false });
      expect(typeof res.body.owner.isFollowing).toBe('boolean');
      // Staff see him too; the owner himself is `isSelf`.
      expect((await get(moderator, '/search/featured')).body.owner.id).toBe(owner.id);
      expect((await get(owner, '/search/featured')).body.owner).toMatchObject({ id: owner.id, isSelf: true });
      // Following shows.
      expect((await send(bob, 'put', `/users/${owner.username}/follow`)).status).toBeLessThan(300);
      expect((await get(bob, '/search/featured')).body.owner.isFollowing).toBe(true);
      // A block either way: nothing.
      expect((await send(alice, 'put', `/users/${owner.username}/block`)).status).toBeLessThan(300);
      const blocked = await get(alice, '/search/featured');
      expectContract(blocked, 'getSearchFeatured');
      expect(blocked.body.owner).toBeNull();
      expect((await send(alice, 'delete', `/users/${owner.username}/block`)).status).toBeLessThan(300);
      expect((await send(owner, 'put', `/users/${bob.username}/block`)).status).toBeLessThan(300);
      expect((await get(bob, '/search/featured')).body.owner).toBeNull();
      expect((await send(owner, 'delete', `/users/${bob.username}/block`)).status).toBeLessThan(300);
    });
  });

  describe('no leak, and the role decides', () => {
    it('never puts the dashboard or the inbox in public responses', async () => {
      const bodies = [
        await get(alice, `/users/${owner.username}`),
        await get(owner, `/users/${owner.username}`),
        await get(owner, '/me'),
        await get(alice, `/users/${owner.username}/journey`),
        await get(alice, `/users/${owner.username}/official-posts`),
        await get(alice, `/users/${owner.username}/posts`),
      ].map((r) => JSON.stringify(r.body));
      for (const b of bodies) {
        for (const leak of [
          'onlineNow',
          'liveRoomsNow',
          'amountMinor',
          'حظرني',
          'ABUSE_OF_POWER',
          'imageKeys',
        ]) {
          expect(b).not.toContain(leak);
        }
      }
    });

    it('revoking OWNER ends the powers and the layout at once (data kept, unshown)', async () => {
      await withMigrationClient((db) => db.$transaction((tx) => revokeRoleIn(tx, owner2.email, 'OWNER')));
      expect((await get(owner2, '/owner/dashboard')).status).toBe(403);
      expect((await get(alice, `/users/${owner2.username}`)).body.kabsoOwner).toBeUndefined();
      // The first owner is unchanged.
      const prof = await get(alice, `/users/${owner.username}`);
      expect(prof.body.kabsoOwner).toBe(true);
      expect(Object.keys(prof.body.coverVideo as object)).toEqual(['ar']);
      // With no ACTIVE owner left, search features nobody.
      await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, owner2.email, 'OWNER')));
      await ctx.prisma.user.updateMany({
        where: { id: { in: [owner.id, owner2.id] } },
        data: { status: 'SUSPENDED' },
      });
      const none = await get(alice, '/search/featured');
      expect(none.body.owner).toBeNull();
      await ctx.prisma.user.updateMany({
        where: { id: { in: [owner.id, owner2.id] } },
        data: { status: 'ACTIVE' },
      });
    });
  });
});
