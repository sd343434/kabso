/**
 * D175 (v1.47-social, CONVENTIONS §10.47, §10.5, §10.6, §11.7, §11.10): the profile fields gender,
 * account category and links (with link reports), private accounts with follow requests — proved
 * against every endpoint that lists or reads posts, reels and stories — and the admin removal of a
 * profile photo, end to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 * Object storage is the in-memory double; every response is checked against openapi.
 */
import { execFile } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { promisify } from 'node:util';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { removeAvatarByAdminIn } from '../src/modules/users/avatar-admin.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { mp4 } from './helpers/mp4.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  newUser,
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
  LIVE_HOSTING_ENABLED: 'true',
};

describe('D175 contract coverage', () => {
  it('openapi declares the follow-request operations', () => {
    expect(
      operations()
        .filter((o) => o.path.startsWith('/api/v1/me/follow-requests'))
        .map((o) => `${o.operationId} ${o.method.toUpperCase()}`)
        .sort(),
    ).toEqual(['acceptFollowRequest POST', 'declineFollowRequest POST', 'listFollowRequests GET']);
  });
});

describe('D175 profile fields, private accounts and follow requests', () => {
  let storage: MemoryObjectStorage;
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (overrides: Record<string, unknown> = {}): Promise<TestUser> => {
    const { res } = await registerVerified(ctx, overrides);
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
  const me = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMe');
    return res.body as Record<string, unknown>;
  };
  const profile = async (viewer: TestUser, of: TestUser) => {
    const res = await ctx.http.get(`/api/v1/users/${of.username}`).set(auth(viewer));
    expect(res.status).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body as Record<string, unknown>;
  };
  const setPrivate = async (u: TestUser, isPrivate: boolean) => {
    const res = await ctx.http.patch('/api/v1/me/privacy').set(auth(u)).send({ isPrivate });
    expect(res.status).toBe(200);
    expectContract(res, 'updatePrivacy');
    expect(res.body.isPrivate).toBe(isPrivate);
    return res;
  };
  const follow = async (u: TestUser, of: TestUser) => {
    const res = await ctx.http.put(`/api/v1/users/${of.username}/follow`).set(auth(u));
    expectContract(res, 'followUser');
    return res;
  };
  const unfollow = async (u: TestUser, of: TestUser) => {
    const res = await ctx.http.delete(`/api/v1/users/${of.username}/follow`).set(auth(u));
    expectContract(res, 'unfollowUser');
    return res;
  };
  const requests = async (u: TestUser, query: Record<string, string> = {}) => {
    const res = await ctx.http.get('/api/v1/me/follow-requests').query(query).set(auth(u));
    expectContract(res, 'listFollowRequests');
    return res;
  };
  const accept = async (u: TestUser, who: string) => {
    const res = await ctx.http.post(`/api/v1/me/follow-requests/${who}/accept`).set(auth(u));
    expectContract(res, 'acceptFollowRequest');
    return res;
  };
  const decline = async (u: TestUser, who: string) => {
    const res = await ctx.http.post(`/api/v1/me/follow-requests/${who}/decline`).set(auth(u));
    expectContract(res, 'declineFollowRequest');
    return res;
  };
  const notifications = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/notifications').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'listNotifications');
    return res.body.data as {
      type: string;
      actors: { username: string }[];
      target: { type: string; id: string } | null;
    }[];
  };
  const image = (w: number, h: number) =>
    sharp({ create: { width: w, height: h, channels: 3, background: '#a33' } })
      .jpeg()
      .toBuffer();
  const upload = async (u: TestUser, kind: string, bytes: Buffer, contentType: string) => {
    const s = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType, byteSize: bytes.length });
    expect(s.status, JSON.stringify(s.body)).toBe(201);
    expect(storage.upload(s.body.uploadUrl, bytes, contentType)).toBe(true);
    return s.body.uploadId as string;
  };
  const complete = async (u: TestUser, uploadId: string, body?: unknown) => {
    const req = ctx.http.post(`/api/v1/media/uploads/${uploadId}/complete`).set(auth(u));
    const res = await (body === undefined ? req : req.send(body as object));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    return res.body as { id: string; url: string };
  };
  const post = async (u: TestUser, text: string) => {
    const res = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ text });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const reel = async (u: TestUser, text: string) => {
    const video = await upload(u, 'REEL_VIDEO', mp4({ durationMs: 6_000 }), 'video/mp4');
    const poster = await complete(u, await upload(u, 'VIDEO_POSTER', await image(540, 960), 'image/jpeg'));
    const media = await complete(u, video, { posterId: poster.id });
    const res = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ format: 'REEL', text, mediaIds: [media.id] });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const story = async (u: TestUser) => {
    const media = await complete(u, await upload(u, 'STORY_IMAGE', await image(720, 1280), 'image/jpeg'));
    const res = await ctx.http
      .post('/api/v1/stories')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ mediaId: media.id, text: 'story' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const audits = (userId: string, action: string) =>
    ctx.prisma.auditLog.findMany({ where: { actorUserId: userId, action }, orderBy: { createdAt: 'asc' } });
  const details = (res: request.Response) => res.body.error?.details as { field: string; issue: string }[];

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
  });
  afterAll(async () => ctx?.close());

  // ---- Gender ------------------------------------------------------------------------------------

  describe('gender', () => {
    it('is required at sign-up, kept on the account and private by default', async () => {
      const { gender: _omit, ...withoutGender } = newUser();
      const missing = await ctx.http.post('/api/v1/auth/register').send(withoutGender);
      expectContract(missing, 'register');
      expect(missing.status).toBe(400);
      expect(details(missing)).toEqual([{ field: 'gender', issue: 'required' }]);
      const bad = await ctx.http.post('/api/v1/auth/register').send(newUser({ gender: 'OTHER' }));
      expect(bad.status).toBe(400);
      expect(details(bad)).toEqual([{ field: 'gender', issue: 'invalid_value' }]);

      const u = await signup({ gender: 'FEMALE' });
      expect(await me(u)).toMatchObject({ gender: 'FEMALE', showGender: false, category: null, links: [] });
      const viewer = await signup();
      expect(await profile(viewer, u)).toMatchObject({ gender: null });
    });

    it('accounts made before v1.47 have none until they choose; shown only when switched on', async () => {
      const u = await signup();
      await ctx.prisma.userProfile.update({ where: { userId: u.id }, data: { gender: null } });
      expect((await me(u)).gender).toBeNull();
      const viewer = await signup();
      const set = await patchMe(u, { gender: 'MALE', showGender: true });
      expect(set.status).toBe(200);
      expect(set.body).toMatchObject({ gender: 'MALE', showGender: true });
      expect((await profile(viewer, u)).gender).toBe('MALE');
      // «أفضّل عدم الذكر» shows nothing even when switched on.
      await patchMe(u, { gender: 'UNDISCLOSED' });
      expect((await profile(viewer, u)).gender).toBeNull();
      await patchMe(u, { gender: 'FEMALE', showGender: false });
      expect((await profile(viewer, u)).gender).toBeNull();
      // Never cleared once chosen.
      const clear = await patchMe(u, { gender: null });
      expect(clear.status).toBe(400);
      expect(details(clear)[0]!.field).toBe('gender');
      const rows = await audits(u.id, 'user.profile.update');
      expect(rows.map((r) => r.metadata)).toEqual([
        { fields: ['gender', 'showGender'] },
        { fields: ['gender'] },
        { fields: ['gender', 'showGender'] },
      ]);
      expect(JSON.stringify(rows.map((r) => r.metadata))).not.toMatch(/MALE|FEMALE/);
    });
  });

  // ---- Category ----------------------------------------------------------------------------------

  describe('account category', () => {
    it('is set, shown on the profile and cleared with null; unknown values refused', async () => {
      const u = await signup();
      const viewer = await signup();
      expect((await patchMe(u, { category: 'POET' })).body.category).toBe('POET');
      expect((await profile(viewer, u)).category).toBe('POET');
      const bad = await patchMe(u, { category: 'ASTRONAUT' });
      expect(bad.status).toBe(400);
      expect(details(bad)).toEqual([{ field: 'category', issue: 'invalid_value' }]);
      expect((await patchMe(u, { category: null })).body.category).toBeNull();
      expect((await profile(viewer, u)).category).toBeNull();
      const all = [
        'SINGER',
        'MUSICIAN',
        'POET',
        'PRESENTER',
        'GAMER',
        'CONTENT_CREATOR',
        'ATHLETE',
        'ARTIST',
        'BLOGGER',
        'PUBLIC_FIGURE',
        'OTHER',
      ];
      for (const category of all) expect((await patchMe(u, { category })).status).toBe(200);
    });
  });

  // ---- Links -------------------------------------------------------------------------------------

  describe('profile links', () => {
    it('normalises up to 3 https links, names known platforms and replaces the whole set', async () => {
      const u = await signup();
      const viewer = await signup();
      const res = await patchMe(u, {
        links: [
          { url: '  https://WWW.Instagram.com/Layla#top ', label: '  انستغرام  ' },
          { url: 'https://youtu.be/abc?t=5' },
          { url: 'https://example.com/a b'.replace(' ', '%20'), label: '' },
        ],
      });
      expect(res.status).toBe(200);
      const links = res.body.links as { id: string; url: string; label: string | null; platform: string }[];
      expect(links.map(({ url, label, platform }) => ({ url, label, platform }))).toEqual([
        { url: 'https://www.instagram.com/Layla', label: 'انستغرام', platform: 'INSTAGRAM' },
        { url: 'https://youtu.be/abc?t=5', label: null, platform: 'YOUTUBE' },
        { url: 'https://example.com/a%20b', label: null, platform: 'OTHER' },
      ]);
      expect((await profile(viewer, u)).links).toEqual(links);
      expect((await audits(u.id, 'user.profile.update')).map((r) => r.metadata)).toEqual([
        { fields: ['links'] },
      ]);
      // The same set again changes nothing (no audit row).
      await patchMe(u, {
        links: links.map((l) => ({ url: l.url, ...(l.label ? { label: l.label } : {}) })),
      });
      expect(await audits(u.id, 'user.profile.update')).toHaveLength(1);

      const platforms = await patchMe(u, {
        links: [
          { url: 'https://m.facebook.com/x' },
          { url: 'https://fb.com/x' },
          { url: 'https://twitter.com/x' },
        ],
      });
      expect(platforms.body.links.map((l: { platform: string }) => l.platform)).toEqual([
        'FACEBOOK',
        'FACEBOOK',
        'X',
      ]);
      const more = await patchMe(u, {
        links: [
          { url: 'https://x.com/a' },
          { url: 'https://www.tiktok.com/@a' },
          { url: 'https://instagram.com.evil.example/a' },
        ],
      });
      expect(more.body.links.map((l: { platform: string }) => l.platform)).toEqual(['X', 'TIKTOK', 'OTHER']);
      expect((await patchMe(u, { links: [] })).body.links).toEqual([]);
      expect(await ctx.prisma.userProfileLink.count({ where: { userId: u.id } })).toBe(0);
    });

    it('refuses unsafe links and labels with field details; nothing changes', async () => {
      const u = await signup();
      await patchMe(u, { links: [{ url: 'https://example.com' }] });
      const cases: [unknown, string, string][] = [
        [[{ url: 'http://example.com' }], 'links.0.url', 'invalid_format'],
        [[{ url: 'javascript:alert(1)' }], 'links.0.url', 'invalid_format'],
        [[{ url: 'https://user:pass@example.com' }], 'links.0.url', 'invalid_format'],
        [[{ url: 'https://user@example.com' }], 'links.0.url', 'invalid_format'],
        [[{ url: 'https://127.0.0.1/a' }], 'links.0.url', 'invalid_format'],
        [[{ url: 'https://2130706433/' }], 'links.0.url', 'invalid_format'],
        [[{ url: 'https://0x7f.1/' }], 'links.0.url', 'invalid_format'],
        [[{ url: 'https://[::1]/' }], 'links.0.url', 'invalid_format'],
        [[{ url: 'https://localhost/' }], 'links.0.url', 'invalid_format'],
        [[{ url: 'https://example.com:8443/' }], 'links.0.url', 'invalid_format'],
        [[{ url: 'https://exa mple.com/' }], 'links.0.url', 'invalid_format'],
        [[{ url: 'https://example.com/‮gnp.exe' }], 'links.0.url', 'invalid_format'],
        [[{ url: 'https://example.123/' }], 'links.0.url', 'invalid_format'],
        [[{ url: `https://example.com/${'a'.repeat(490)}` }], 'links.0.url', 'too_long'],
        [[{ url: 'https://example.com', label: 'x'.repeat(31) }], 'links.0.label', 'too_long'],
        [[{ url: 'https://example.com', label: 'a\nb' }], 'links.0.label', 'too_long'],
        [[{ url: 'https://example.com', extra: 1 }], 'links.0.extra', 'unknown_field'],
        [[{ url: 'https://a.example' }, { url: 'https://A.example/' }], 'links.1.url', 'invalid_value'],
        [
          [
            { url: 'https://a.co' },
            { url: 'https://b.co' },
            { url: 'https://c.co' },
            { url: 'https://d.co' },
          ],
          'links',
          'too_many',
        ],
      ];
      for (const [links, field, issue] of cases) {
        const res = await patchMe(u, { links });
        expect({ links, status: res.status, details: details(res) }).toEqual({
          links,
          status: 400,
          details: [{ field, issue }],
        });
      }
      expect(((await me(u)).links as { url: string }[]).map((l) => l.url)).toEqual(['https://example.com/']);
    });

    it('the database refuses a non-https link and a fourth position (CHECK backstop)', async () => {
      const u = await signup();
      await withMigrationClient(async (c) => {
        await expect(
          c.userProfileLink.create({ data: { userId: u.id, position: 0, url: 'http://example.com/' } }),
        ).rejects.toThrow();
        await expect(
          c.userProfileLink.create({ data: { userId: u.id, position: 3, url: 'https://example.com/' } }),
        ).rejects.toThrow();
      });
    });

    it('a link can be reported (snapshot kept); a moderator removes it from the profile', async () => {
      const owner = await signup();
      const reporter = await signup();
      const mod = await signup();
      await withMigrationClient(async (c) => {
        await c.user.update({ where: { id: mod.id }, data: { role: 'ADMIN' } });
        await c.userAdminPermission.create({ data: { userId: mod.id, permission: 'MODERATION' } });
      });
      const [link] = (
        await patchMe(owner, { links: [{ url: 'https://phish.example/login', label: 'Free coins' }] })
      ).body.links as { id: string }[];
      const report = (u: TestUser, targetId: string) =>
        ctx.http
          .post('/api/v1/reports')
          .set(auth(u))
          .send({ targetType: 'PROFILE_LINK', targetId, reason: 'SPAM' });
      const own = await report(owner, link!.id);
      expectContract(own, 'createReport');
      expect(own.status).toBe(400);
      expect((await report(reporter, randomUUID())).status).toBe(404);
      expect((await report(reporter, 'not-a-uuid')).status).toBe(404);
      const first = await report(reporter, link!.id);
      expectContract(first, 'createReport');
      expect(first.status).toBe(201);
      expect(first.body).toMatchObject({ targetType: 'PROFILE_LINK', targetId: link!.id, status: 'OPEN' });
      expect((await report(reporter, link!.id)).status).toBe(200);
      // A user report of the same person is separate.
      const userReport = await ctx.http
        .post('/api/v1/reports')
        .set(auth(reporter))
        .send({ targetType: 'USER', targetId: owner.username, reason: 'SPAM' });
      expect(userReport.status).toBe(201);
      const queue = await ctx.http.get('/api/v1/admin/reports?limit=50').set(auth(mod));
      expectContract(queue, 'listAdminReports');
      const row = (queue.body.data as { id: string; linkSnapshot?: unknown }[]).find(
        (r) => r.id === first.body.id,
      );
      expect(row?.linkSnapshot).toEqual({
        username: owner.username,
        url: 'https://phish.example/login',
        label: 'Free coins',
      });
      const act = await ctx.http
        .post(`/api/v1/admin/reports/${first.body.id as string}/actions`)
        .set(auth(mod))
        .send({ action: 'REMOVE_TARGET' });
      expectContract(act, 'actOnReport');
      expect(act.status).toBe(200);
      expect(act.body).toMatchObject({
        status: 'ACTIONED',
        linkSnapshot: { url: 'https://phish.example/login' },
      });
      expect((await me(owner)).links).toEqual([]);
      // The user report stays open (a separate target).
      expect((await ctx.prisma.report.findUniqueOrThrow({ where: { id: userReport.body.id } })).status).toBe(
        'OPEN',
      );
    });
  });

  // ---- Private accounts --------------------------------------------------------------------------

  describe('private accounts: content for followers only, on every endpoint', () => {
    it('a non-follower cannot read posts, reels or stories anywhere; a follower and the owner can; lives stay public', async () => {
      const owner = await signup();
      const follower = await signup();
      const stranger = await signup();
      const tag = `d175priv${Date.now().toString(36)}`;
      expect((await follow(follower, owner)).body).toMatchObject({ isFollowing: true });
      const postId = await post(owner, `secret words ${tag} #${tag}`);
      const reelId = await reel(owner, `secret reel #${tag}`);
      const storyId = await story(owner);
      // Interactions made while it was public stay possible to undo; saved before going private.
      expect((await ctx.http.put(`/api/v1/posts/${postId}/save`).set(auth(stranger))).status).toBe(200);
      await ctx.prisma.liveHost.create({ data: { userId: owner.id, source: 'ADMIN' } });
      const room = await ctx.http.post('/api/v1/live/rooms').set(auth(owner)).send({ title: 'Live' });
      expect(room.status).toBe(201);

      const res = await setPrivate(owner, true);
      expect(res.body).toMatchObject({ isPrivate: true });
      expect((await me(owner)).isPrivate).toBe(true);
      expect((await audits(owner.id, 'user.privacy.private')).map((r) => r.metadata)).toEqual([
        { isPrivate: true, requestsAccepted: 0 },
      ]);

      const get = (u: TestUser, path: string, query: Record<string, string> = {}) =>
        ctx.http.get(`/api/v1${path}`).query(query).set(auth(u));
      const ids = [postId, reelId, storyId];
      const leaks = (body: unknown) => ids.filter((id) => JSON.stringify(body).includes(id));

      // Direct reads: the honest 404 (never 403), the same as a missing item.
      for (const [op, path] of [
        ['listUserPosts', `/users/${owner.username}/posts`],
        ['listUserReposts', `/users/${owner.username}/reposts`],
        ['listUserStories', `/users/${owner.username}/stories`],
        ['getPost', `/posts/${postId}`],
        ['getPost', `/posts/${reelId}`],
        ['listComments', `/posts/${postId}/comments`],
        ['listPostLikes', `/posts/${postId}/likes`],
        ['getStory', `/stories/${storyId}`],
      ] as const) {
        const r = await get(stranger, path);
        expectContract(r, op);
        expect({ path, status: r.status, code: r.body.error?.code }).toEqual({
          path,
          status: 404,
          code: 'NOT_FOUND',
        });
      }
      // Lists: none of the three appears.
      const lists: [string, Record<string, string>][] = [
        ['/feed/posts', { tab: 'trending' }],
        ['/feed/posts', { tab: 'following' }],
        ['/feed/reels', { tab: 'trending' }],
        ['/feed/reels', { tab: 'following' }],
        ['/feed/stories', {}],
        ['/search', { q: 'secret', type: 'posts' }],
        ['/search', { q: tag, type: 'hashtags' }],
        [`/hashtags/${tag}/posts`, { sort: 'recent' }],
        [`/hashtags/${tag}/posts`, { sort: 'top' }],
        ['/search/trending-hashtags', {}],
        ['/me/saved', {}],
        ['/notifications', {}],
      ];
      for (const [path, query] of lists) {
        const r = await get(stranger, path, query);
        expect({ path, query, status: r.status, leaks: leaks(r.body) }).toEqual({
          path,
          query,
          status: 200,
          leaks: [],
        });
      }
      const tagSearch = await get(stranger, '/search', { q: tag, type: 'hashtags' });
      expect(tagSearch.body.data).toEqual([]);
      const tagPage = await get(stranger, `/hashtags/${tag}`);
      if (tagPage.status === 200) expect(tagPage.body.postCount).toBe(0);
      // Writes on the content: 404 as well.
      for (const [method, path, body] of [
        ['put', `/posts/${postId}/like`, undefined],
        ['post', `/posts/${postId}/comments`, { text: 'hi' }],
        ['put', `/posts/${postId}/repost`, undefined],
        ['post', `/posts/${postId}/shares`, {}],
        ['put', `/posts/${postId}/save`, undefined],
        ['put', `/stories/${storyId}/seen`, undefined],
        ['post', '/reports', { targetType: 'POST', targetId: postId, reason: 'SPAM' }],
        ['post', '/reports', { targetType: 'STORY', targetId: storyId, reason: 'SPAM' }],
      ] as const) {
        const req = ctx.http[method](`/api/v1${path}`).set(auth(stranger));
        const r = await (body === undefined ? req : req.send(body));
        expect({ path, status: r.status }).toEqual({ path, status: 404 });
      }
      // A view of a post one cannot see is ignored.
      const view = await ctx.http
        .post('/api/v1/views')
        .set(auth(stranger))
        .send({ items: [{ postId, watchedMs: 5000 }] });
      expect(view.status).toBeLessThan(300);
      expect(await ctx.prisma.postView.count({ where: { postId, userId: stranger.id } })).toBe(0);

      // The profile itself stays visible, with counts, links and the live; the lists are 403.
      const seen = await profile(stranger, owner);
      expect(seen).toMatchObject({
        isPrivate: true,
        isFollowing: false,
        followRequested: false,
        followerCount: 1,
      });
      expect(seen.liveRoomId).toBe(room.body.id);
      const liveRoom = await get(stranger, `/live/rooms/${room.body.id as string}`);
      expect(liveRoom.status).toBe(200);
      expect((await get(stranger, `/users/${owner.username}/followers`)).status).toBe(403);

      // The follower (and the owner) still see everything.
      for (const u of [follower, owner]) {
        const grid = await get(u, `/users/${owner.username}/posts`);
        expect(grid.status).toBe(200);
        expect((grid.body.data as { id: string }[]).map((p) => p.id).sort()).toEqual([postId, reelId].sort());
        expect((await get(u, `/stories/${storyId}`)).status).toBe(200);
        expect((await get(u, `/posts/${postId}/comments`)).status).toBe(200);
        expect(leaks((await get(u, `/hashtags/${tag}/posts`, { sort: 'recent' })).body)).toEqual([
          postId,
          reelId,
        ]);
      }
      expect(leaks((await get(follower, '/feed/posts', { tab: 'following' })).body)).toEqual([postId]);
      const tray = await get(follower, '/feed/stories');
      expect((tray.body.data as { user: { id: string } }[]).some((t) => t.user.id === owner.id)).toBe(true);
      // Search lists both formats (the reel's caption says «secret» too).
      expect(leaks((await get(follower, '/search', { q: 'secret', type: 'posts' })).body)).toEqual([
        postId,
        reelId,
      ]);

      // Going public again shows it to everyone.
      await setPrivate(owner, false);
      expect((await get(stranger, `/posts/${postId}`)).status).toBe(200);
      expect((await get(stranger, `/users/${owner.username}/stories`)).status).toBe(200);
    });

    it('a follow becomes a request: notification, list, cancel, decline, accept; counts stay visible', async () => {
      const owner = await signup();
      const asker = await signup();
      const other = await signup();
      const old = await signup();
      await follow(old, owner);
      await setPrivate(owner, true);
      const postId = await post(owner, 'for followers');

      const asked = await follow(asker, owner);
      expect(asked.status).toBe(200);
      expect(asked.body).toEqual({ isFollowing: false, isRequested: true, followerCount: 1 });
      // Idempotent: no second request or notification.
      expect((await follow(asker, owner)).body).toEqual({
        isFollowing: false,
        isRequested: true,
        followerCount: 1,
      });
      expect(await ctx.prisma.followRequest.count({ where: { targetId: owner.id } })).toBe(1);
      expect(await ctx.prisma.follow.count({ where: { followerId: asker.id, followeeId: owner.id } })).toBe(
        0,
      );
      expect(await profile(asker, owner)).toMatchObject({ followRequested: true, isFollowing: false });
      const inbox = (await notifications(owner)).filter((n) => n.type === 'FOLLOW_REQUEST');
      expect(inbox).toHaveLength(1);
      expect(inbox[0]).toMatchObject({
        actors: [{ username: asker.username }],
        target: { type: 'USER', id: asker.username },
      });
      // The old follower's follower list row shows the request of the reader.
      const list = await ctx.http.get(`/api/v1/users/${old.username}/following`).set(auth(asker));
      expect(list.status).toBe(200);
      expect(list.body.data[0]).toMatchObject({
        username: owner.username,
        isPrivate: true,
        requestedByMe: true,
      });

      const pending = await requests(owner);
      expect(pending.status).toBe(200);
      expect(pending.body).toMatchObject({ total: 1, page: { hasMore: false, nextCursor: null } });
      expect(pending.body.data[0]).toMatchObject({ user: { id: asker.id, username: asker.username } });

      // Cancel (unfollow) withdraws the request and its notification.
      expect((await unfollow(asker, owner)).body).toEqual({
        isFollowing: false,
        isRequested: false,
        followerCount: 1,
      });
      expect((await requests(owner)).body.total).toBe(0);
      expect((await notifications(owner)).filter((n) => n.type === 'FOLLOW_REQUEST')).toEqual([]);

      // Decline: gone, idempotent; the requester is not told and may ask again.
      await follow(asker, owner);
      expect((await decline(owner, asker.username)).status).toBe(204);
      expect((await decline(owner, asker.username)).status).toBe(204);
      expect((await requests(owner)).body.total).toBe(0);
      expect((await notifications(asker)).filter((n) => n.type.startsWith('FOLLOW_REQUEST'))).toEqual([]);
      expect((await profile(asker, owner)).followRequested).toBe(false);

      // Accept: the follow exists, the requester is told and now sees the posts.
      await follow(asker, owner);
      expect((await ctx.http.get(`/api/v1/posts/${postId}`).set(auth(asker))).status).toBe(404);
      const ok = await accept(owner, asker.username);
      expect(ok.status).toBe(200);
      expect(ok.body).toEqual({ followsMe: true, followerCount: 2 });
      expect((await accept(owner, asker.username)).body).toEqual({ followsMe: true, followerCount: 2 });
      expect((await ctx.http.get(`/api/v1/posts/${postId}`).set(auth(asker))).status).toBe(200);
      expect(await profile(asker, owner)).toMatchObject({
        isFollowing: true,
        followRequested: false,
        followerCount: 2,
      });
      const told = (await notifications(asker)).filter((n) => n.type === 'FOLLOW_REQUEST_ACCEPTED');
      expect(told).toHaveLength(1);
      expect(told[0]).toMatchObject({
        actors: [{ username: owner.username }],
        target: { type: 'USER', id: owner.username },
      });
      expect((await notifications(owner)).filter((n) => n.type === 'FOLLOW_REQUEST')).toEqual([]);

      // Errors: nothing pending → 409; unknown / malformed → 404; self → 400.
      const none = await accept(owner, other.username);
      expect({ status: none.status, code: none.body.error.code }).toEqual({
        status: 409,
        code: 'FOLLOW_REQUEST_NOT_PENDING',
      });
      expect((await accept(owner, 'nobody_here1')).status).toBe(404);
      expect((await decline(owner, 'Bad Name!')).status).toBe(404);
      const self = await accept(owner, owner.username);
      expect(self.status).toBe(400);
      expect(details(self)).toEqual([{ field: 'username', issue: 'invalid_value' }]);
      // Counts stay visible to everyone.
      expect(await profile(other, owner)).toMatchObject({ followerCount: 2, followingCount: 0 });
    });

    it('the request list pages newest first with a bound cursor and leaves out suspended and blocked requesters', async () => {
      const owner = await signup();
      await setPrivate(owner, true);
      const askers: TestUser[] = [];
      for (let i = 0; i < 4; i += 1) {
        const a = await signup();
        await follow(a, owner);
        askers.push(a);
      }
      const first = await requests(owner, { limit: '2' });
      expect(first.body.total).toBe(4);
      expect(first.body.data.map((r: { user: { id: string } }) => r.user.id)).toEqual([
        askers[3]!.id,
        askers[2]!.id,
      ]);
      const second = await requests(owner, { limit: '2', cursor: first.body.page.nextCursor });
      expect(second.body.data.map((r: { user: { id: string } }) => r.user.id)).toEqual([
        askers[1]!.id,
        askers[0]!.id,
      ]);
      expect(second.body.page.hasMore).toBe(false);
      const otherOwner = await signup();
      const foreign = await requests(otherOwner, { cursor: first.body.page.nextCursor });
      expect(foreign.status).toBe(400);
      // Suspended: left out (and cannot be accepted); a block deletes the requests both ways.
      await ctx.prisma.user.update({ where: { id: askers[0]!.id }, data: { status: 'SUSPENDED' } });
      expect((await accept(owner, askers[0]!.username)).status).toBe(404);
      const block = await ctx.http.put(`/api/v1/users/${askers[1]!.username}/block`).set(auth(owner));
      expect(block.status).toBe(200);
      expect(await ctx.prisma.followRequest.count({ where: { requesterId: askers[1]!.id } })).toBe(0);
      const after = await requests(owner);
      expect(after.body.total).toBe(2);
      expect(after.body.data.map((r: { user: { id: string } }) => r.user.id)).toEqual([
        askers[3]!.id,
        askers[2]!.id,
      ]);
    });

    it('switching to public accepts every pending request; existing followers stay', async () => {
      const owner = await signup();
      const old = await signup();
      await follow(old, owner);
      await setPrivate(owner, true);
      const [a, b] = [await signup(), await signup()];
      await follow(a, owner);
      await follow(b, owner);
      // Switching private again changes nothing (no audit row).
      await setPrivate(owner, true);
      await setPrivate(owner, false);
      expect((await audits(owner.id, 'user.privacy.private')).map((r) => r.metadata)).toEqual([
        { isPrivate: true, requestsAccepted: 0 },
        { isPrivate: false, requestsAccepted: 2 },
      ]);
      expect(await ctx.prisma.followRequest.count({ where: { targetId: owner.id } })).toBe(0);
      expect((await profile(a, owner)).isFollowing).toBe(true);
      expect((await profile(old, owner)).isFollowing).toBe(true);
      expect((await profile(old, owner)).followerCount).toBe(3);
      expect((await notifications(owner)).filter((n) => n.type === 'FOLLOW_REQUEST')).toEqual([]);
      // Public again: a follow is a follow.
      const c = await signup();
      expect((await follow(c, owner)).body).toEqual({
        isFollowing: true,
        isRequested: false,
        followerCount: 4,
      });
    });

    it('the privacy settings carry isPrivate; other fields still work alone', async () => {
      const u = await signup();
      const read = await ctx.http.get('/api/v1/me/privacy').set(auth(u));
      expectContract(read, 'getPrivacy');
      expect(read.body.isPrivate).toBe(false);
      const other = await ctx.http.patch('/api/v1/me/privacy').set(auth(u)).send({ whoCanMention: 'NOBODY' });
      expect(other.body).toMatchObject({ whoCanMention: 'NOBODY', isPrivate: false });
      const bad = await ctx.http.patch('/api/v1/me/privacy').set(auth(u)).send({ isPrivate: 'yes' });
      expect(bad.status).toBe(400);
      expect(details(bad).map((d) => d.field)).toEqual(['isPrivate']);
    });
  });

  // ---- Admin removal of a profile photo -----------------------------------------------------------

  describe('admin removal of a profile photo', () => {
    const run = promisify(execFile);

    it('the CLI removes the photo, deletes the asset, notifies the user and audits the reason', async () => {
      const u = await signup();
      const avatar = await complete(u, await upload(u, 'AVATAR', await image(800, 800), 'image/jpeg'));
      const set = await ctx.http.put('/api/v1/me/avatar').set(auth(u)).send({ mediaId: avatar.id });
      expect(set.status).toBe(200);
      const { stdout } = await run(
        'npx',
        ['tsx', 'src/cli/profile-admin.ts', 'remove-avatar', u.username, '--reason', 'nudity report 42'],
        {
          cwd: new URL('..', import.meta.url).pathname,
          env: { ...process.env, S3_BUCKET: '', S3_ACCESS_KEY_ID: '', S3_SECRET_ACCESS_KEY: '' },
        },
      );
      expect(stdout).toContain(`@${u.username}: photo removed.`);
      expect((await me(u)).avatarUrl).toBeNull();
      expect(await ctx.prisma.mediaAsset.count({ where: { id: avatar.id } })).toBe(0);
      const inbox = (await notifications(u)).filter((n) => n.type === 'AVATAR_REMOVED');
      expect(inbox).toHaveLength(1);
      expect(inbox[0]).toMatchObject({ actors: [], target: null });
      const audit = await ctx.prisma.auditLog.findFirstOrThrow({
        where: { action: 'admin.avatar.remove', targetId: u.id },
      });
      expect(audit.metadata).toMatchObject({
        username: u.username,
        reason: 'nudity report 42',
        hadAsset: true,
      });
      // The user may set a new photo afterwards.
      const again = await complete(u, await upload(u, 'AVATAR', await image(640, 640), 'image/jpeg'));
      expect((await ctx.http.put('/api/v1/me/avatar').set(auth(u)).send({ mediaId: again.id })).status).toBe(
        200,
      );
    });

    it('no photo changes nothing; an unknown user and a missing reason are refused', async () => {
      const u = await signup();
      const result = await withMigrationClient((c) =>
        c.$transaction((tx) => removeAvatarByAdminIn(tx, u.username, 'x')),
      );
      expect(result).toEqual({ outcome: 'no_photo', userId: u.id });
      const unknown = await withMigrationClient((c) =>
        c.$transaction((tx) => removeAvatarByAdminIn(tx, 'nobody_here9', 'x')),
      );
      expect(unknown).toEqual({ outcome: 'unknown_user' });
      expect((await notifications(u)).filter((n) => n.type === 'AVATAR_REMOVED')).toEqual([]);
      // A photo that is a plain URL (no asset) is removed too.
      await ctx.prisma.userProfile.update({
        where: { userId: u.id },
        data: { avatarUrl: 'https://media.example.test/a.webp' },
      });
      const plain = await withMigrationClient((c) =>
        c.$transaction((tx) => removeAvatarByAdminIn(tx, u.username, 'x')),
      );
      expect(plain).toEqual({ outcome: 'removed', userId: u.id, objectKeys: [] });
      const cwd = new URL('..', import.meta.url).pathname;
      await expect(
        run('npx', ['tsx', 'src/cli/profile-admin.ts', 'remove-avatar', u.username], { cwd }),
      ).rejects.toMatchObject({
        stderr: expect.stringContaining('A reason is required'),
      });
    });
  });
});

describe('D175 follow-request answers share one rate-limit bucket', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_FOLLOW_REQUEST_ANSWER_USER: '2/3600' });
  });
  afterAll(async () => ctx?.close());

  it('accept and decline count together; the third answer in the hour → 429', async () => {
    const owner = await registerVerified(ctx);
    const other = await registerVerified(ctx);
    const token = owner.res.body.tokens.accessToken as string;
    const name = other.res.body.user.username as string;
    const call = (verb: 'accept' | 'decline') =>
      ctx.http.post(`/api/v1/me/follow-requests/${name}/${verb}`).set({ Authorization: `Bearer ${token}` });
    expect((await call('decline')).status).toBe(204);
    expect((await call('accept')).status).toBe(409);
    const limited = await call('decline');
    expectContract(limited, 'declineFollowRequest');
    expect(limited.status).toBe(429);
  });
});
