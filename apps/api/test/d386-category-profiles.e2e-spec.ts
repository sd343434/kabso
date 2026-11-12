/**
 * D386 (owner 2026-11-12; contract v1.138-social, CONVENTIONS §10.175): a profile page per account category. End to end
 * against PostgreSQL + Redis. Covers: the 13 new categories (and clearing one), the Me / PublicProfile shapes
 * (`categoryVerified`, `categoryLocked`), «طلب توثيق الفئة» (required, one open, cancel, a change of category cancels
 * it, approve / reject from the panel with audit and notifications, already verified, the daily limit), the panel's
 * VERIFY / UNVERIFY / CLEAR / LOCK / UNLOCK (capabilities, CSRF, one's own account, no-op, audit, notify, the lock's
 * 403), a Kabso Team account (no category, no section), and the featured section (verified only, the automatic pick
 * per section, the presenter's schedule, pins: at most 6, own posts only, order, a deleted or hidden post dropped,
 * privacy and blocks).
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { expectContract, operations } from './helpers/openapi.js';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });

const NEW_CATEGORIES = [
  'QURAN_RECITER',
  'STORYTELLER',
  'WRITER',
  'JOURNALIST',
  'PHOTOGRAPHER',
  'ACTOR',
  'COMEDIAN',
  'CALLIGRAPHER',
  'DESIGNER',
  'CHEF',
  'TEACHER',
  'DJ',
  'TRAVELER',
];

interface User extends Person {
  username: string;
}

describe('D386 contract coverage', () => {
  it('openapi v1.138-social declares the category-profile operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'getUserFeatured GET /api/v1/users/{username}/featured',
      'listMyFeaturedPins GET /api/v1/me/featured-pins',
      'setMyFeaturedPins PUT /api/v1/me/featured-pins',
      'pinFeaturedPost PUT /api/v1/me/featured-pins/{postId}',
      'unpinFeaturedPost DELETE /api/v1/me/featured-pins/{postId}',
      'getMyCategoryVerification GET /api/v1/me/category-verification',
      'requestCategoryVerification POST /api/v1/me/category-verification',
      'cancelCategoryVerification DELETE /api/v1/me/category-verification',
      'getAdminUserCategory GET /api/v1/admin/users/{userId}/category',
      'controlAdminUserCategory POST /api/v1/admin/users/{userId}/category',
      'listAdminCategoryRequests GET /api/v1/admin/category-requests',
      'approveAdminCategoryRequest POST /api/v1/admin/category-requests/{requestId}/approve',
      'rejectAdminCategoryRequest POST /api/v1/admin/category-requests/{requestId}/reject',
    ]) {
      expect(ids).toContain(op);
    }
    const ours = operations().filter(
      (o) => typeof o.spec.description === 'string' && o.spec.description.startsWith('(v1.138-social, D386'),
    );
    expect(ours.map((o) => o.operationId).sort()).toEqual(
      [
        'getAdminUserCategory',
        'controlAdminUserCategory',
        'listAdminCategoryRequests',
        'approveAdminCategoryRequest',
        'rejectAdminCategoryRequest',
      ].sort(),
    );
  });
});

describe('D386 category profiles', { timeout: 600_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let mod: Admin;
  let finance: Admin;

  const user = async (): Promise<User> => {
    const person = await p.signup();
    vi.useRealTimers();
    const me = await ctx.http.get('/api/v1/me').set(auth(person));
    return { ...person, username: me.body.username as string };
  };
  const me = async (u: User) => {
    const r = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(r.status).toBe(200);
    expectContract(r, 'getMe');
    return r.body as { category: string | null; categoryVerified: boolean; categoryLocked: boolean };
  };
  const setCategory = (u: User, category: string | null) =>
    ctx.http.patch('/api/v1/me').set(auth(u)).send({ category });
  const profile = async (viewer: User, target: User) => {
    const r = await ctx.http.get(`/api/v1/users/${target.username}`).set(auth(viewer));
    expect(r.status).toBe(200);
    expectContract(r, 'getPublicProfile');
    return r.body as { category: string | null; categoryVerified: boolean };
  };
  const status = async (u: User) => {
    const r = await ctx.http.get('/api/v1/me/category-verification').set(auth(u));
    expect(r.status).toBe(200);
    expectContract(r, 'getMyCategoryVerification');
    return r.body as {
      category: string | null;
      verified: boolean;
      locked: boolean;
      request: { id: string; status: string; category: string; rejectReason: string | null } | null;
    };
  };
  const ask = (u: User, body?: object) =>
    ctx.http
      .post('/api/v1/me/category-verification')
      .set(auth(u))
      .send(body ?? {});
  const control = (a: Admin, target: User, action: string, reason = 'D386 test') =>
    p.send(a, 'post', `/admin/users/${target.id}/category`, { action, reason });
  const notes = async (u: User) => {
    const r = await ctx.http.get('/api/v1/notifications').set(auth(u));
    expect(r.status).toBe(200);
    expectContract(r, 'listNotifications');
    return (r.body.data as { type: string }[]).map((n) => n.type);
  };
  const audits = (action: string, targetId: string) =>
    ctx.prisma.auditLog.findMany({ where: { action, targetId }, orderBy: { createdAt: 'asc' } });
  const featured = (viewer: User, target: User) =>
    ctx.http.get(`/api/v1/users/${target.username}/featured`).set(auth(viewer));

  let seq = 0;
  /** A published post; `media` adds one asset of that kind (stored directly: the media pipeline is not under test). */
  const post = async (
    u: User,
    opts: { text?: string; media?: 'POST_IMAGE' | 'POST_VIDEO' | 'REEL_VIDEO'; views?: number } = {},
  ) => {
    seq += 1;
    const publishedAt = new Date(Date.now() - 3_600_000 + seq * 1000);
    const row = await ctx.prisma.post.create({
      data: {
        authorId: u.id,
        text: opts.text ?? `post ${seq}`,
        format: opts.media === 'REEL_VIDEO' ? 'REEL' : 'POST',
        status: 'PUBLISHED',
        publishedAt,
        viewCount: opts.views ?? 0,
      },
    });
    if (opts.media) {
      const asset = await ctx.prisma.mediaAsset.create({
        data: {
          ownerId: u.id,
          kind: opts.media,
          width: 1080,
          height: 1920,
          durationMs: opts.media === 'POST_IMAGE' ? null : 12_000,
          largeKey: `media/${randomUUID()}/large`,
          thumbKey: `media/${randomUUID()}/thumb.webp`,
          posterKey: opts.media === 'POST_IMAGE' ? null : `media/${randomUUID()}/poster.webp`,
          byteSize: 1000,
          attachedAt: new Date(),
        },
      });
      await ctx.prisma.postMedia.create({ data: { postId: row.id, mediaAssetId: asset.id, position: 0 } });
    }
    return row.id;
  };
  const verify = async (u: User, category: string) => {
    expect((await setCategory(u, category)).status).toBe(200);
    const r = await control(owner, u, 'VERIFY');
    expect(r.status, JSON.stringify(r.body)).toBe(200);
  };

  beforeAll(async () => {
    ctx = await createTestApp({
      ADMIN_TOTP_KEY: ADMIN_KEY,
      JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      // The posts' media URLs (the rows are stored directly; nothing is uploaded).
      MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
    });
    owner = await p.makeAdmin(['OWNER']);
    mod = await p.makeAdmin(['MODERATION']);
    finance = await p.makeAdmin(['FINANCE']);
    vi.useRealTimers();
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('accepts the 13 new categories and clears one; Me and PublicProfile carry the new fields', async () => {
    const u = await user();
    const viewer = await user();
    expect(await me(u)).toMatchObject({ category: null, categoryVerified: false, categoryLocked: false });
    for (const category of NEW_CATEGORIES) {
      const r = await setCategory(u, category);
      expect(r.status, JSON.stringify(r.body)).toBe(200);
      expectContract(r, 'updateMe');
      expect(r.body).toMatchObject({ category, categoryVerified: false, categoryLocked: false });
      expect(await profile(viewer, u)).toMatchObject({ category, categoryVerified: false });
    }
    const bad = await setCategory(u, 'ASTRONAUT');
    expect(bad.status).toBe(400);
    expect(bad.body.error.details).toEqual([{ field: 'category', issue: 'invalid_value' }]);
    const cleared = await setCategory(u, null);
    expect(cleared.status).toBe(200);
    expect(cleared.body).toMatchObject({ category: null, categoryVerified: false });
  });

  it('«طلب توثيق الفئة»: required, one open, cancel, a change cancels it, approve verifies (audit + notify)', async () => {
    const u = await user();
    const viewer = await user();
    expect(await status(u)).toEqual({ category: null, verified: false, locked: false, request: null });
    const none = await ask(u);
    expect(none.status).toBe(400);
    expectContract(none, 'requestCategoryVerification');
    expect(none.body.error.details).toEqual([{ field: 'category', issue: 'required' }]);

    expect((await setCategory(u, 'POET')).status).toBe(200);
    const tooLong = await ask(u, { note: 'x'.repeat(301) });
    expect(tooLong.status).toBe(400);
    expect(tooLong.body.error.details).toEqual([{ field: 'note', issue: 'too_long' }]);
    const extra = await ask(u, { note: 'hi', category: 'SINGER' });
    expect(extra.status).toBe(400);

    const made = await ask(u, { note: '  ديواني على الرابط  ' });
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    expectContract(made, 'requestCategoryVerification');
    expect(made.body).toMatchObject({
      category: 'POET',
      verified: false,
      request: { category: 'POET', status: 'PENDING', decidedAt: null, rejectReason: null },
    });
    const again = await ask(u);
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('CATEGORY_VERIFICATION_PENDING');
    expect(await ctx.prisma.categoryRequest.findFirstOrThrow({ where: { userId: u.id } })).toMatchObject({
      note: 'ديواني على الرابط',
    });

    const cancelled = await ctx.http.delete('/api/v1/me/category-verification').set(auth(u));
    expect(cancelled.status).toBe(200);
    expectContract(cancelled, 'cancelCategoryVerification');
    expect(cancelled.body.request).toMatchObject({ status: 'CANCELLED' });
    expect((await ctx.http.delete('/api/v1/me/category-verification').set(auth(u))).status).toBe(200);

    // A change of category cancels the open request.
    expect((await ask(u)).status).toBe(201);
    expect((await setCategory(u, 'WRITER')).status).toBe(200);
    const afterChange = await status(u);
    expect(afterChange.request).toMatchObject({ category: 'POET', status: 'CANCELLED' });
    expect(
      await ctx.prisma.categoryRequest.count({ where: { userId: u.id, cancelReason: 'category_changed' } }),
    ).toBe(1);

    // The panel's queue lists it; approving verifies the category.
    const open = await ask(u);
    expect(open.status).toBe(201);
    const list = await p.send(mod, 'get', `/admin/category-requests?status=PENDING&q=${u.email}`);
    expect(list.status, JSON.stringify(list.body)).toBe(200);
    expectContract(list, 'listAdminCategoryRequests');
    expect(list.body.data).toHaveLength(1);
    expect(list.body.data[0]).toMatchObject({
      category: 'WRITER',
      currentCategory: 'WRITER',
      status: 'PENDING',
    });
    const id = list.body.data[0].id as string;
    // FINANCE reads but cannot decide; no CSRF header → 403.
    expect((await p.send(finance, 'get', '/admin/category-requests')).status).toBe(200);
    expect((await p.send(finance, 'post', `/admin/category-requests/${id}/approve`)).status).toBe(403);
    const noCsrf = await ctx.http
      .post(`/api/v1/admin/category-requests/${id}/approve`)
      .set('Cookie', mod.cookie);
    expect(noCsrf.status).toBe(403);

    const approved = await p.send(mod, 'post', `/admin/category-requests/${id}/approve`);
    expect(approved.status, JSON.stringify(approved.body)).toBe(200);
    expectContract(approved, 'approveAdminCategoryRequest');
    expect(approved.body).toMatchObject({ status: 'APPROVED', category: 'WRITER' });
    expect((await p.send(mod, 'post', `/admin/category-requests/${id}/approve`)).status).toBe(409);
    expect(await me(u)).toMatchObject({ category: 'WRITER', categoryVerified: true });
    expect(await profile(viewer, u)).toMatchObject({ category: 'WRITER', categoryVerified: true });
    expect(await notes(u)).toContain('CATEGORY_VERIFIED');
    expect((await audits('category.request.approve', id)).map((a) => a.metadata)).toEqual([
      { userId: u.id, category: 'WRITER', via: 'panel' },
    ]);
    const already = await ask(u);
    expect(already.status).toBe(400);
    expect(already.body.error.details).toEqual([{ field: 'category', issue: 'already_verified' }]);

    // Changing the category clears the verification; the same value keeps it.
    expect((await setCategory(u, 'WRITER')).body).toMatchObject({ categoryVerified: true });
    expect((await setCategory(u, 'JOURNALIST')).body).toMatchObject({ categoryVerified: false });
    expect(await profile(viewer, u)).toMatchObject({ category: 'JOURNALIST', categoryVerified: false });
  });

  it('rejecting shows the reason to the person, who may ask again', async () => {
    const u = await user();
    expect((await setCategory(u, 'CHEF')).status).toBe(200);
    expect((await ask(u)).status).toBe(201);
    const id = (await status(u)).request!.id;
    const empty = await p.send(owner, 'post', `/admin/category-requests/${id}/reject`, { reason: '' });
    expect(empty.status).toBe(400);
    const rejected = await p.send(owner, 'post', `/admin/category-requests/${id}/reject`, {
      reason: 'أرفق رابطاً لأعمالك',
    });
    expect(rejected.status, JSON.stringify(rejected.body)).toBe(200);
    expectContract(rejected, 'rejectAdminCategoryRequest');
    expect((await status(u)).request).toMatchObject({
      status: 'REJECTED',
      rejectReason: 'أرفق رابطاً لأعمالك',
    });
    expect(await notes(u)).toContain('CATEGORY_REVIEWED');
    expect((await audits('category.request.reject', id))[0]?.metadata).toMatchObject({
      reason: 'أرفق رابطاً لأعمالك',
      via: 'panel',
    });
    expect((await ask(u)).status).toBe(201);
  });

  it('the panel verifies, unverifies, clears, locks and unlocks (audited, notified, no-op silent)', async () => {
    const u = await user();
    const noCategory = await control(mod, u, 'VERIFY');
    expect(noCategory.status).toBe(409);
    expect(noCategory.body.error).toMatchObject({
      code: 'ADMIN_ACTION_REFUSED',
      details: [{ field: 'category', issue: 'no_category' }],
    });
    expect((await setCategory(u, 'SINGER')).status).toBe(200);
    expect((await ask(u)).status).toBe(201);

    const view = await p.send(finance, 'get', `/admin/users/${u.id}/category`);
    expect(view.status).toBe(200);
    expectContract(view, 'getAdminUserCategory');
    expect(view.body).toMatchObject({
      category: 'SINGER',
      verified: false,
      locked: false,
      kabsoTeam: false,
      request: { status: 'PENDING' },
    });
    expect((await control(finance, u, 'VERIFY')).status).toBe(403);
    expect((await p.send(mod, 'post', `/admin/users/${u.id}/category`, { action: 'VERIFY' })).status).toBe(
      400,
    );
    expect((await control(mod, u, 'PROMOTE')).status).toBe(400);

    const verified = await control(mod, u, 'VERIFY', 'known singer');
    expect(verified.status, JSON.stringify(verified.body)).toBe(200);
    expectContract(verified, 'controlAdminUserCategory');
    expect(verified.body).toMatchObject({
      category: 'SINGER',
      verified: true,
      request: { status: 'APPROVED' },
    });
    expect(verified.body.verifiedBy).toMatchObject({ id: mod.id });
    // The same action again changes nothing (no audit, no notification).
    expect((await control(mod, u, 'VERIFY')).status).toBe(200);
    expect(await audits('admin.user.category', u.id)).toHaveLength(1);

    const locked = await control(mod, u, 'LOCK');
    expect(locked.body).toMatchObject({ locked: true });
    expect(await me(u)).toMatchObject({ categoryLocked: true, categoryVerified: true });
    const refused = await ctx.http
      .patch('/api/v1/me')
      .set(auth(u))
      .send({ category: 'POET', bio: 'new bio' });
    expect(refused.status).toBe(403);
    expectContract(refused, 'updateMe');
    expect(refused.body.error.code).toBe('ACCOUNT_CATEGORY_LOCKED');
    expect((await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: u.id } })).bio).toBeNull();
    expect((await setCategory(u, 'SINGER')).status).toBe(200);
    expect((await setCategory(u, null)).status).toBe(403);
    expect((await status(u)).locked).toBe(true);

    expect((await control(mod, u, 'UNVERIFY')).body).toMatchObject({ verified: false });
    expect((await control(mod, u, 'UNLOCK')).body).toMatchObject({ locked: false });
    expect((await ask(u)).status).toBe(201);
    const cleared = await control(owner, u, 'CLEAR', 'not a singer');
    expect(cleared.body).toMatchObject({ category: null, verified: false, request: { status: 'CANCELLED' } });
    expect(await me(u)).toMatchObject({ category: null, categoryVerified: false, categoryLocked: false });

    const rows = await audits('admin.user.category', u.id);
    expect(rows.map((r) => (r.metadata as { action: string }).action)).toEqual([
      'VERIFY',
      'LOCK',
      'UNVERIFY',
      'UNLOCK',
      'CLEAR',
    ]);
    expect(rows[4]?.metadata).toMatchObject({
      reason: 'not a singer',
      before: { category: 'SINGER', verified: false, locked: false },
      after: { category: null, verified: false, locked: false },
      via: 'panel',
    });
    const types = await notes(u);
    expect(types.filter((t) => t === 'CATEGORY_VERIFIED')).toHaveLength(1);
    expect(types.filter((t) => t === 'CATEGORY_REVIEWED')).toHaveLength(4);

    // Never on one's own account; a panel admin's account only by an OWNER.
    expect(
      (await p.send(mod, 'post', `/admin/users/${mod.id}/category`, { action: 'LOCK', reason: 'x' })).status,
    ).toBe(409);
    expect(
      (await p.send(mod, 'post', `/admin/users/${owner.id}/category`, { action: 'LOCK', reason: 'x' }))
        .status,
    ).toBe(403);
    expect(
      (await p.send(mod, 'post', `/admin/users/${randomUUID()}/category`, { action: 'LOCK', reason: 'x' }))
        .status,
    ).toBe(404);
  });

  it('a Kabso Team account shows no category: not verified, no request, no section', async () => {
    const staff = await user();
    expect((await setCategory(staff, 'POET')).status).toBe(200);
    expect((await control(owner, staff, 'VERIFY')).status).toBe(200);
    const viewer = await user();
    expect(await profile(viewer, staff)).toMatchObject({ category: 'POET', categoryVerified: true });
    await withMigrationClient((db) =>
      db.$transaction((tx) => grantRoleIn(tx, staff.email, 'SUPPORT' as never)),
    );
    vi.useRealTimers();
    expect(await profile(viewer, staff)).toMatchObject({ category: null, categoryVerified: false });
    expect(await me(staff)).toMatchObject({ category: null, categoryVerified: false });
    expect(await status(staff)).toMatchObject({ category: null, verified: false });
    const asked = await ask(staff);
    expect(asked.status).toBe(400);
    expect(asked.body.error.details).toEqual([{ field: 'category', issue: 'required' }]);
    await post(staff, { text: 'a poem' });
    const f = await featured(viewer, staff);
    expect(f.status).toBe(200);
    expect(f.body).toEqual({ section: null, source: 'NONE', items: [], schedule: [] });
    const adminView = await p.send(owner, 'get', `/admin/users/${staff.id}/category`);
    expect(adminView.body).toMatchObject({ category: 'POET', kabsoTeam: true });
  });

  it('the featured section: verified only, the automatic pick per section, the presenter schedule', async () => {
    const viewer = await user();
    const singer = await user();
    const video = await post(singer, { media: 'POST_VIDEO' });
    await post(singer, { text: 'words only' });
    await post(singer, { media: 'POST_IMAGE' });
    const reel = await post(singer, { media: 'REEL_VIDEO' });
    // Unverified: nothing.
    expect((await setCategory(singer, 'SINGER')).status).toBe(200);
    const before = await featured(viewer, singer);
    expect(before.status).toBe(200);
    expectContract(before, 'getUserFeatured');
    expect(before.body).toEqual({ section: null, source: 'NONE', items: [], schedule: [] });
    await verify(singer, 'SINGER');
    const works = await featured(viewer, singer);
    expectContract(works, 'getUserFeatured');
    expect(works.body).toMatchObject({ section: 'WORKS', source: 'AUTO', schedule: [] });
    expect(works.body.items.map((i: { id: string }) => i.id)).toEqual([reel, video]);

    // POET: text-only posts; GALLERY: pictures; MOST_VIEWED: reels by views; REPORTS: posts.
    const poet = await user();
    const poem = await post(poet, { text: 'قصيدة' });
    await post(poet, { media: 'POST_IMAGE' });
    await verify(poet, 'POET');
    expect((await featured(viewer, poet)).body).toMatchObject({ section: 'POEMS', source: 'AUTO' });
    expect((await featured(viewer, poet)).body.items.map((i: { id: string }) => i.id)).toEqual([poem]);

    const photographer = await user();
    const photo = await post(photographer, { media: 'POST_IMAGE' });
    await post(photographer, { text: 'no picture' });
    await verify(photographer, 'PHOTOGRAPHER');
    const gallery = await featured(viewer, photographer);
    expect(gallery.body.section).toBe('GALLERY');
    expect(gallery.body.items.map((i: { id: string }) => i.id)).toEqual([photo]);

    const creator = await user();
    const low = await post(creator, { media: 'REEL_VIDEO', views: 5 });
    const high = await post(creator, { media: 'REEL_VIDEO', views: 900 });
    await post(creator, { media: 'POST_VIDEO', views: 5000 });
    await verify(creator, 'COMEDIAN');
    const top = await featured(viewer, creator);
    expect(top.body.section).toBe('MOST_VIEWED');
    expect(top.body.items.map((i: { id: string }) => i.id)).toEqual([high, low]);

    // An empty section: NONE. PUBLIC_FIGURE: no section even when verified.
    const reciter = await user();
    await verify(reciter, 'QURAN_RECITER');
    expect((await featured(viewer, reciter)).body).toEqual({
      section: 'RECITATIONS',
      source: 'NONE',
      items: [],
      schedule: [],
    });
    const figure = await user();
    await post(figure, { text: 'hello' });
    await verify(figure, 'PUBLIC_FIGURE');
    expect((await featured(viewer, figure)).body).toEqual({
      section: null,
      source: 'NONE',
      items: [],
      schedule: [],
    });

    // PRESENTER: the upcoming schedule (soonest first, not the past ones).
    const presenter = await user();
    await verify(presenter, 'PRESENTER');
    const soon = new Date(Date.now() + 3_600_000);
    const later = new Date(Date.now() + 7_200_000);
    await ctx.prisma.liveScheduleSlot.createMany({
      data: [
        {
          hostUserId: presenter.id,
          title: 'الحلقة الثانية',
          startsAt: later,
          mode: 'PODCAST',
          podcastTopic: 'tech',
        },
        { hostUserId: presenter.id, title: 'الحلقة الأولى', startsAt: soon },
        { hostUserId: presenter.id, title: 'مضت', startsAt: new Date(Date.now() - 60_000) },
      ],
    });
    const program = await featured(viewer, presenter);
    expectContract(program, 'getUserFeatured');
    expect(program.body).toMatchObject({ section: 'PROGRAM', source: 'AUTO', items: [] });
    expect(program.body.schedule.map((s: { title: string }) => s.title)).toEqual([
      'الحلقة الأولى',
      'الحلقة الثانية',
    ]);
    expect(program.body.schedule[1]).toMatchObject({ mode: 'PODCAST', podcastTopic: 'tech' });
  });

  it('pins: at most 6, own posts only, in order, reorder and clear, a deleted or hidden post dropped', async () => {
    const viewer = await user();
    const u = await user();
    const other = await user();
    await verify(u, 'DJ');
    const ids: string[] = [];
    for (let i = 0; i < 7; i++) ids.push(await post(u, { text: `pin ${i}` }));
    const theirs = await post(other, { text: 'not yours' });

    const empty = await ctx.http.get('/api/v1/me/featured-pins').set(auth(u));
    expect(empty.status).toBe(200);
    expectContract(empty, 'listMyFeaturedPins');
    expect(empty.body).toEqual({ postIds: [], max: 6 });

    for (let i = 0; i < 6; i++) {
      const r = await ctx.http.put(`/api/v1/me/featured-pins/${ids[i]}`).set(auth(u));
      expect(r.status, JSON.stringify(r.body)).toBe(200);
      expectContract(r, 'pinFeaturedPost');
    }
    // Idempotent: keeps its place.
    expect((await ctx.http.put(`/api/v1/me/featured-pins/${ids[0]}`).set(auth(u))).body.postIds).toEqual(
      ids.slice(0, 6),
    );
    const seventh = await ctx.http.put(`/api/v1/me/featured-pins/${ids[6]}`).set(auth(u));
    expect(seventh.status).toBe(409);
    expectContract(seventh, 'pinFeaturedPost');
    expect(seventh.body.error).toMatchObject({
      code: 'FEATURED_PIN_LIMIT',
      details: [{ field: 'pins', issue: 'too_many' }],
    });
    expect((await ctx.http.put(`/api/v1/me/featured-pins/${theirs}`).set(auth(u))).status).toBe(404);
    expect((await ctx.http.put('/api/v1/me/featured-pins/not-a-uuid').set(auth(u))).status).toBe(404);

    // The section shows the pins in order (PINNED), not the automatic pick.
    const shown = await featured(viewer, u);
    expect(shown.body).toMatchObject({ section: 'WORKS', source: 'PINNED' });
    expect(shown.body.items.map((i: { id: string }) => i.id)).toEqual(ids.slice(0, 6));

    // Reorder, too many, someone else's, repeated.
    const order = [ids[5]!, ids[0]!, ids[3]!];
    const set = await ctx.http.put('/api/v1/me/featured-pins').set(auth(u)).send({ postIds: order });
    expect(set.status, JSON.stringify(set.body)).toBe(200);
    expectContract(set, 'setMyFeaturedPins');
    expect(set.body.postIds).toEqual(order);
    const many = await ctx.http.put('/api/v1/me/featured-pins').set(auth(u)).send({ postIds: ids });
    expect(many.status).toBe(400);
    expect(many.body.error.details).toEqual([{ field: 'postIds', issue: 'too_many' }]);
    const foreign = await ctx.http
      .put('/api/v1/me/featured-pins')
      .set(auth(u))
      .send({ postIds: [ids[0], theirs] });
    expect(foreign.body.error.details).toEqual([{ field: 'postIds.1', issue: 'invalid_value' }]);
    const twice = await ctx.http
      .put('/api/v1/me/featured-pins')
      .set(auth(u))
      .send({ postIds: [ids[0], ids[0]] });
    expect(twice.body.error.details).toEqual([{ field: 'postIds.1', issue: 'invalid_value' }]);
    expect((await ctx.http.put('/api/v1/me/featured-pins').set(auth(u)).send({ postIds: 'x' })).status).toBe(
      400,
    );

    // Unpin keeps the others' order; unpinning again changes nothing.
    const un = await ctx.http.delete(`/api/v1/me/featured-pins/${ids[0]}`).set(auth(u));
    expect(un.status).toBe(200);
    expectContract(un, 'unpinFeaturedPost');
    expect(un.body.postIds).toEqual([ids[5], ids[3]]);
    expect((await ctx.http.delete(`/api/v1/me/featured-pins/${ids[0]}`).set(auth(u))).body.postIds).toEqual([
      ids[5],
      ids[3],
    ]);

    // A deleted post and a post the team hid are dropped (readers never see them; the next read prunes them).
    expect((await ctx.http.delete(`/api/v1/posts/${ids[5]}`).set(auth(u))).status).toBe(204);
    expect((await featured(viewer, u)).body.items.map((i: { id: string }) => i.id)).toEqual([ids[3]]);
    await ctx.prisma.post.update({ where: { id: ids[3]! }, data: { moderation: 'REMOVED' } });
    // No pin left, and a DJ's automatic pick takes videos only: nothing to show.
    const gone = await featured(viewer, u);
    expect(gone.body).toMatchObject({ section: 'WORKS', source: 'NONE', items: [] });
    expect((await ctx.http.get('/api/v1/me/featured-pins').set(auth(u))).body.postIds).toEqual([]);
    expect(await ctx.prisma.profileFeaturedPin.count({ where: { userId: u.id } })).toBe(0);

    // Clear.
    expect((await ctx.http.put(`/api/v1/me/featured-pins/${ids[1]}`).set(auth(u))).status).toBe(200);
    const cleared = await ctx.http.put('/api/v1/me/featured-pins').set(auth(u)).send({ postIds: [] });
    expect(cleared.body).toEqual({ postIds: [], max: 6 });
  });

  it('privacy and blocks: a private account not followed and a block either way answer 404', async () => {
    const owner2 = await user();
    const stranger = await user();
    const fan = await user();
    const blocked = await user();
    await verify(owner2, 'ARTIST');
    const art = await post(owner2, { media: 'POST_IMAGE' });
    expect((await ctx.http.put(`/api/v1/users/${owner2.username}/follow`).set(auth(fan))).status).toBe(200);
    expect(
      (await ctx.http.patch('/api/v1/me/privacy').set(auth(owner2)).send({ isPrivate: true })).status,
    ).toBe(200);
    const hidden = await featured(stranger, owner2);
    expect(hidden.status).toBe(404);
    expectContract(hidden, 'getUserFeatured');
    const seen = await featured(fan, owner2);
    expect(seen.status).toBe(200);
    expect(seen.body.items.map((i: { id: string }) => i.id)).toEqual([art]);
    expect((await featured(owner2, owner2)).body.items).toHaveLength(1);
    expect((await ctx.http.put(`/api/v1/users/${blocked.username}/block`).set(auth(owner2))).status).toBe(
      200,
    );
    expect((await featured(blocked, owner2)).status).toBe(404);
    expect((await ctx.http.get('/api/v1/users/nobody_here_386/featured').set(auth(fan))).status).toBe(404);
  });
});

describe('D386 the daily limit of «طلب توثيق الفئة»', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  afterAll(async () => ctx?.close());

  it('answers 429 past RATE_LIMIT_CATEGORY_REQUEST_USER', async () => {
    ctx = await createTestApp({ RATE_LIMIT_CATEGORY_REQUEST_USER: '2/86400' });
    const p = panel(() => ctx);
    const u = await p.signup();
    vi.useRealTimers();
    expect((await ctx.http.patch('/api/v1/me').set(auth(u)).send({ category: 'DJ' })).status).toBe(200);
    expect((await ctx.http.post('/api/v1/me/category-verification').set(auth(u)).send({})).status).toBe(201);
    expect((await ctx.http.post('/api/v1/me/category-verification').set(auth(u)).send({})).status).toBe(409);
    const limited = await ctx.http.post('/api/v1/me/category-verification').set(auth(u)).send({});
    expect(limited.status).toBe(429);
    expectContract(limited, 'requestCategoryVerification');
  });
});
