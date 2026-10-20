/**
 * KL-060 group 3: feeds (Following, Trending snapshot) and interactions — likes and likers, saves,
 * reposts, outside shares and views (openapi v1.5-social DRAFT, CONVENTIONS §11.2–§11.4), end to
 * end against PostgreSQL + Redis. Every response is checked against openapi.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import type { Redis } from 'ioredis';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { REDIS } from '../src/redis/redis.module.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';
import { expectContract } from './helpers/openapi.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('KL-060 feeds and interactions', () => {
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const post = async (u: TestUser, text: string, extra: object = {}): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ text, ...extra });
    expect(res.status).toBe(201);
    return res.body.id as string;
  };
  const follow = (follower: TestUser, followee: TestUser) =>
    withMigrationClient((c) =>
      c.follow.create({ data: { followerId: follower.id, followeeId: followee.id } }),
    );
  const ids = (res: request.Response) => res.body.data.map((p: { id: string }) => p.id) as string[];
  const getPost = (u: TestUser, id: string) => ctx.http.get(`/api/v1/posts/${id}`).set(auth(u));

  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => ctx?.close());

  describe('likes', () => {
    it('like and unlike are idempotent, race-safe and keep the count exact', async () => {
      const [author, fan] = [await signup(), await signup()];
      const id = await post(author, 'like me');
      const liked = await ctx.http.put(`/api/v1/posts/${id}/like`).set(auth(fan));
      expect(liked.status).toBe(200);
      expectContract(liked, 'likePost');
      expect(liked.body).toEqual({ liked: true, likeCount: 1 });
      const again = await Promise.all(
        Array.from({ length: 5 }, () => ctx.http.put(`/api/v1/posts/${id}/like`).set(auth(fan))),
      );
      expect(again.every((r) => r.body.likeCount === 1)).toBe(true);
      expect((await getPost(fan, id)).body).toMatchObject({ likeCount: 1, viewerHasLiked: true });
      const unliked = await ctx.http.delete(`/api/v1/posts/${id}/like`).set(auth(fan));
      expectContract(unliked, 'unlikePost');
      expect(unliked.body).toEqual({ liked: false, likeCount: 0 });
      expect((await ctx.http.delete(`/api/v1/posts/${id}/like`).set(auth(fan))).body.likeCount).toBe(0);
      expect(await ctx.prisma.post.findUniqueOrThrow({ where: { id } })).toMatchObject({ likeCount: 0 });
    });

    it('many users liking one post at once: no deadlock, exact count', async () => {
      const author = await signup();
      const id = await post(author, 'hot post');
      const fans = await Promise.all(Array.from({ length: 8 }, () => signup()));
      const res = await Promise.all(fans.map((f) => ctx.http.put(`/api/v1/posts/${id}/like`).set(auth(f))));
      expect(res.map((r) => r.status)).toEqual(fans.map(() => 200));
      const shares = await Promise.all(
        fans.map((f) => ctx.http.post(`/api/v1/posts/${id}/shares`).set(auth(f))),
      );
      expect(shares.map((r) => r.status)).toEqual(fans.map(() => 200));
      expect(await ctx.prisma.post.findUniqueOrThrow({ where: { id } })).toMatchObject({
        likeCount: 8,
        shareCount: 8,
      });
    });

    it('invisible posts cannot be liked; a hidden count is null for others', async () => {
      const [author, fan] = [await signup(), await signup()];
      const draft = await post(author, 'draft', { status: 'DRAFT' });
      expect((await ctx.http.put(`/api/v1/posts/${draft}/like`).set(auth(author))).status).toBe(404);
      const missing = await ctx.http.put(`/api/v1/posts/${randomUUID()}/like`).set(auth(fan));
      expect(missing.status).toBe(404);
      expectContract(missing, 'likePost');
      const hidden = await post(author, 'hidden count', { settings: { hideLikeCount: true } });
      expect((await ctx.http.put(`/api/v1/posts/${hidden}/like`).set(auth(fan))).body).toEqual({
        liked: true,
        likeCount: null,
      });
      expect((await ctx.http.put(`/api/v1/posts/${hidden}/like`).set(auth(author))).body).toEqual({
        liked: true,
        likeCount: 2,
      });
    });

    it('likers: newest first, paged; blocked and hidden-count rules', async () => {
      const author = await signup();
      const id = await post(author, 'popular');
      const fans: TestUser[] = [];
      for (let i = 0; i < 3; i += 1) {
        const fan = await signup();
        fans.push(fan);
        await ctx.http.put(`/api/v1/posts/${id}/like`).set(auth(fan));
      }
      const first = await ctx.http.get(`/api/v1/posts/${id}/likes?limit=2`).set(auth(author));
      expect(first.status).toBe(200);
      expectContract(first, 'listPostLikes');
      expect(first.body.data.map((u: { id: string }) => u.id)).toEqual([fans[2]!.id, fans[1]!.id]);
      const second = await ctx.http
        .get(`/api/v1/posts/${id}/likes?limit=2&cursor=${first.body.page.nextCursor}`)
        .set(auth(author));
      expect(second.body.data.map((u: { id: string }) => u.id)).toEqual([fans[0]!.id]);
      expect(second.body.page).toEqual({ hasMore: false, nextCursor: null });
      // A liker who blocked the viewer is not listed to them.
      const viewer = await signup();
      await withMigrationClient((c) =>
        c.userBlock.create({ data: { blockerId: fans[1]!.id, blockedId: viewer.id } }),
      );
      const seen = await ctx.http.get(`/api/v1/posts/${id}/likes`).set(auth(viewer));
      expect(seen.body.data.map((u: { id: string }) => u.id)).toEqual([fans[2]!.id, fans[0]!.id]);
      // Hidden count: the author only.
      await ctx.http
        .patch(`/api/v1/posts/${id}`)
        .set(auth(author))
        .send({ settings: { hideLikeCount: true } });
      const forbidden = await ctx.http.get(`/api/v1/posts/${id}/likes`).set(auth(viewer));
      expect(forbidden.status).toBe(403);
      expect(forbidden.body.error.code).toBe('AUTH_FORBIDDEN');
      expectContract(forbidden, 'listPostLikes');
      expect((await ctx.http.get(`/api/v1/posts/${id}/likes`).set(auth(author))).body.data).toHaveLength(3);
    });
  });

  describe('saves', () => {
    it('saves are private, idempotent and listed newest first; invisible posts drop out', async () => {
      const [author, me] = [await signup(), await signup()];
      const a = await post(author, 'save a');
      const b = await post(author, 'save b');
      const saved = await ctx.http.put(`/api/v1/posts/${a}/save`).set(auth(me));
      expect(saved.status).toBe(200);
      expectContract(saved, 'savePost');
      expect(saved.body).toEqual({ saved: true });
      await ctx.http.put(`/api/v1/posts/${a}/save`).set(auth(me));
      await ctx.http.put(`/api/v1/posts/${b}/save`).set(auth(me));
      const list = await ctx.http.get('/api/v1/me/saved').set(auth(me));
      expect(list.status).toBe(200);
      expectContract(list, 'listSavedPosts');
      expect(ids(list)).toEqual([b, a]);
      expect(list.body.data[0].viewerHasSaved).toBe(true);
      expect(await ctx.prisma.post.findUniqueOrThrow({ where: { id: a } })).toMatchObject({ saveCount: 1 });
      await ctx.http.delete(`/api/v1/posts/${a}`).set(auth(author));
      expect(ids(await ctx.http.get('/api/v1/me/saved').set(auth(me)))).toEqual([b]);
      const unsave = await ctx.http.delete(`/api/v1/posts/${b}/save`).set(auth(me));
      expectContract(unsave, 'unsavePost');
      expect(unsave.body).toEqual({ saved: false });
      expect(ids(await ctx.http.get('/api/v1/me/saved').set(auth(me)))).toEqual([]);
      // Saves are the caller's own: another user's list is empty.
      expect(ids(await ctx.http.get('/api/v1/me/saved').set(auth(author)))).toEqual([]);
    });
  });

  describe('reposts and the Following feed', () => {
    it('Following: followed posts and reposts newest first, once each, with repostedBy', async () => {
      const [me, friend, other, stranger] = [await signup(), await signup(), await signup(), await signup()];
      await follow(me, friend);
      await follow(me, other);
      const p1 = await post(friend, 'friend 1');
      const p2 = await post(stranger, 'stranger');
      const p3 = await post(other, 'other');
      await post(stranger, 'never seen');
      // friend reposts the stranger's post, then other reposts it too: it appears once (newest).
      const rp = await ctx.http.put(`/api/v1/posts/${p2}/repost`).set(auth(friend));
      expect(rp.status).toBe(200);
      expectContract(rp, 'repostPost');
      expect(rp.body).toEqual({ reposted: true, repostCount: 1 });
      expect((await ctx.http.put(`/api/v1/posts/${p2}/repost`).set(auth(friend))).body.repostCount).toBe(1);
      await ctx.http.put(`/api/v1/posts/${p2}/repost`).set(auth(other));

      const feed = await ctx.http.get('/api/v1/feed/posts?tab=following').set(auth(me));
      expect(feed.status).toBe(200);
      expectContract(feed, 'listFeedPosts');
      expect(ids(feed)).toEqual([p2, p3, p1]);
      expect(feed.body.data[0].repostedBy.id).toBe(other.id);
      expect(feed.body.data[1].repostedBy).toBeNull();

      // Paging never repeats.
      const page1 = await ctx.http.get('/api/v1/feed/posts?tab=following&limit=2').set(auth(me));
      const page2 = await ctx.http
        .get(`/api/v1/feed/posts?tab=following&limit=2&cursor=${page1.body.page.nextCursor}`)
        .set(auth(me));
      expect([...ids(page1), ...ids(page2)]).toEqual([p2, p3, p1]);

      // Muting `other` drops its posts and its repost (friend's repost entry remains).
      await withMigrationClient((c) => c.userMute.create({ data: { muterId: me.id, mutedId: other.id } }));
      const muted = await ctx.http.get('/api/v1/feed/posts?tab=following').set(auth(me));
      expect(ids(muted)).toEqual([p2, p1]);
      expect(muted.body.data[0].repostedBy.id).toBe(friend.id);
      // Hiding a post drops it; undoing the repost drops the repost entry.
      await withMigrationClient((c) => c.postHide.create({ data: { userId: me.id, postId: p1 } }));
      const unrepost = await ctx.http.delete(`/api/v1/posts/${p2}/repost`).set(auth(friend));
      expectContract(unrepost, 'unrepostPost');
      expect(unrepost.body).toEqual({ reposted: false, repostCount: 1 });
      expect(ids(await ctx.http.get('/api/v1/feed/posts?tab=following').set(auth(me)))).toEqual([]);
    });

    it('own and private posts cannot be reposted; reposts tab follows visibility', async () => {
      const [me, priv, pub, viewer] = [await signup(), await signup(), await signup(), await signup()];
      const own = await post(me, 'mine');
      const bad = await ctx.http.put(`/api/v1/posts/${own}/repost`).set(auth(me));
      expect(bad.status).toBe(400);
      expect(bad.body.error.details).toEqual([{ field: 'postId', issue: 'invalid_value' }]);
      expectContract(bad, 'repostPost');
      const secret = await post(priv, 'secret');
      await withMigrationClient(async (c) => {
        await c.userSettings.update({ where: { userId: priv.id }, data: { isPrivate: true } });
        await c.follow.create({ data: { followerId: me.id, followeeId: priv.id } });
      });
      expect((await ctx.http.put(`/api/v1/posts/${secret}/repost`).set(auth(me))).status).toBe(400);
      const open = await post(pub, 'public');
      await ctx.http.put(`/api/v1/posts/${open}/repost`).set(auth(me));
      const tab = await ctx.http.get(`/api/v1/users/${me.username}/reposts`).set(auth(viewer));
      expect(tab.status).toBe(200);
      expectContract(tab, 'listUserReposts');
      expect(ids(tab)).toEqual([open]);
      expect(tab.body.data[0].repostedBy.id).toBe(me.id);
      // A viewer blocked by the original author does not see it there.
      await withMigrationClient((c) =>
        c.userBlock.create({ data: { blockerId: pub.id, blockedId: viewer.id } }),
      );
      expect(ids(await ctx.http.get(`/api/v1/users/${me.username}/reposts`).set(auth(viewer)))).toEqual([]);
      const none = await ctx.http.get('/api/v1/users/no_such_user_q/reposts').set(auth(viewer));
      expect(none.status).toBe(404);
      expectContract(none, 'listUserReposts');
    });
  });

  describe('trending', () => {
    it('ranks by score, freezes a snapshot per caller, and spreads authors', async () => {
      const [me, a, b, c] = [await signup(), await signup(), await signup(), await signup()];
      const low = await post(a, 'trend low');
      const high = await post(b, 'trend high');
      const mine = await post(me, 'my own is never trending for me');
      const fans = [await signup(), await signup(), await signup()];
      for (const fan of fans) await ctx.http.put(`/api/v1/posts/${high}/like`).set(auth(fan));
      const c1 = await post(c, 'c one');
      const c2 = await post(c, 'c two');
      const c3 = await post(c, 'c three');

      const all: string[] = [];
      let cursor: string | null = null;
      let first: request.Response | null = null;
      for (let i = 0; i < 200; i += 1) {
        const res: request.Response = await ctx.http
          .get(`/api/v1/feed/posts?tab=trending&limit=50${cursor ? `&cursor=${cursor}` : ''}`)
          .set(auth(me));
        expect(res.status).toBe(200);
        expectContract(res, 'listFeedPosts');
        first ??= res;
        all.push(...ids(res));
        cursor = res.body.page.nextCursor;
        if (!res.body.page.hasMore) break;
      }
      expect(new Set(all).size).toBe(all.length);
      expect(all).not.toContain(mine);
      // The e2e database keeps earlier runs' posts: `low` may fall outside the 500-entry snapshot.
      expect(all).toContain(high);
      if (all.includes(low)) expect(all.indexOf(high)).toBeLessThan(all.indexOf(low));
      // c's three posts: at most two within any 10 consecutive entries.
      const cPositions = [c1, c2, c3]
        .map((id) => all.indexOf(id))
        .filter((i) => i >= 0)
        .sort((x, y) => x - y);
      if (cPositions.length === 3) expect(cPositions[2]! - cPositions[0]!).toBeGreaterThanOrEqual(10);

      // A new post after the snapshot does not shift later pages; a cursor is the caller's own.
      const firstPage = await ctx.http.get('/api/v1/feed/posts?tab=trending&limit=1').set(auth(me));
      expect(firstPage.body.page.hasMore).toBe(true);
      await post(a, 'brand new');
      const next = await ctx.http
        .get(`/api/v1/feed/posts?tab=trending&limit=1&cursor=${firstPage.body.page.nextCursor}`)
        .set(auth(me));
      expect(ids(next)).toEqual([all[1]]);
      const foreign = await ctx.http
        .get(`/api/v1/feed/posts?tab=trending&limit=1&cursor=${firstPage.body.page.nextCursor}`)
        .set(auth(a));
      expect(foreign.status).toBe(400);
      expect(foreign.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
      // An expired snapshot is 400 too.
      const keys = await ctx.app.get<Redis>(REDIS).keys('*social:trending:*');
      await Promise.all(
        keys.map((k) => ctx.app.get<Redis>(REDIS).del(k.replace(/^.*?(social:trending:)/, '$1'))),
      );
      const expired = await ctx.http
        .get(`/api/v1/feed/posts?tab=trending&limit=1&cursor=${firstPage.body.page.nextCursor}`)
        .set(auth(me));
      expect(expired.status).toBe(400);
      expectContract(expired, 'listFeedPosts');
    });

    it('validates the tab', async () => {
      const me = await signup();
      for (const q of ['', '?tab=forYou', '?tab=following&limit=51', '?tab=following&x=1']) {
        const res = await ctx.http.get(`/api/v1/feed/posts${q}`).set(auth(me));
        expect(res.status, q).toBe(400);
        expectContract(res, 'listFeedPosts');
      }
    });
  });

  describe('shares and views', () => {
    it('a share counts once per user and UTC day', async () => {
      const [author, fan] = [await signup(), await signup()];
      const id = await post(author, 'share me');
      const first = await ctx.http.post(`/api/v1/posts/${id}/shares`).set(auth(fan));
      expect(first.status).toBe(200);
      expectContract(first, 'countPostShare');
      expect(first.body).toEqual({ shareCount: 1 });
      expect((await ctx.http.post(`/api/v1/posts/${id}/shares`).set(auth(fan))).body).toEqual({
        shareCount: 1,
      });
      expect((await ctx.http.post(`/api/v1/posts/${id}/shares`).set(auth(author))).body).toEqual({
        shareCount: 2,
      });
      expect((await ctx.http.post(`/api/v1/posts/${randomUUID()}/shares`).set(auth(fan))).status).toBe(404);
    });

    it('views: ≥ 1 s, not the author, visible only, once per 24 h', async () => {
      const [author, fan, priv] = [await signup(), await signup(), await signup()];
      const id = await post(author, 'watch me');
      const secret = await post(priv, 'secret');
      await withMigrationClient((c) =>
        c.userSettings.update({ where: { userId: priv.id }, data: { isPrivate: true } }),
      );
      const send = (u: TestUser, items: unknown) =>
        ctx.http.post('/api/v1/views').set(auth(u)).send({ items });
      const res = await send(fan, [
        { postId: id, watchedMs: 1500 },
        { postId: id, watchedMs: 3000 },
        { postId: secret, watchedMs: 5000 },
        { postId: randomUUID(), watchedMs: 5000 },
      ]);
      expect(res.status).toBe(204);
      expectContract(res, 'recordViews');
      await send(fan, [{ postId: id, watchedMs: 2000 }]);
      await send(author, [{ postId: id, watchedMs: 2000 }]);
      await send(await signup(), [{ postId: id, watchedMs: 999 }]);
      const count = async (postId: string) =>
        (await ctx.prisma.post.findUniqueOrThrow({ where: { id: postId } })).viewCount;
      expect(await count(id)).toBe(1);
      expect(await count(secret)).toBe(0);
      // After 24 hours the same viewer counts again.
      await withMigrationClient((c) =>
        c.postView.update({
          where: { postId_userId: { postId: id, userId: fan.id } },
          data: { viewedAt: new Date(Date.now() - 25 * 3600_000) },
        }),
      );
      await send(fan, [{ postId: id, watchedMs: 2000 }]);
      expect(await count(id)).toBe(2);
      for (const bad of [
        [],
        Array.from({ length: 51 }, () => ({ postId: id, watchedMs: 1 })),
        [{ postId: 'x', watchedMs: 1 }],
      ]) {
        const r = await send(fan, bad);
        expect(r.status).toBe(400);
        expectContract(r, 'recordViews');
      }
    });
  });
});

describe('KL-060 like rate limit (§11.8)', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_LIKE_USER: '3/900' });
  });
  afterAll(async () => ctx?.close());

  it('PUT and DELETE like share one per-user bucket', async () => {
    const { res: a } = await registerVerified(ctx);
    const { res: b } = await registerVerified(ctx);
    const created = await ctx.http
      .post('/api/v1/posts')
      .set('Authorization', `Bearer ${a.body.tokens.accessToken}`)
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'limited' });
    const fan = { Authorization: `Bearer ${b.body.tokens.accessToken}` };
    const url = `/api/v1/posts/${created.body.id}/like`;
    expect((await ctx.http.put(url).set(fan)).status).toBe(200);
    expect((await ctx.http.delete(url).set(fan)).status).toBe(200);
    expect((await ctx.http.put(url).set(fan)).status).toBe(200);
    const limited = await ctx.http.delete(url).set(fan);
    expect(limited.status).toBe(429);
    expectContract(limited, 'unlikePost');
    // Another user has their own bucket.
    expect(
      (await ctx.http.put(url).set({ Authorization: `Bearer ${a.body.tokens.accessToken}` })).status,
    ).toBe(200);
  });
});
