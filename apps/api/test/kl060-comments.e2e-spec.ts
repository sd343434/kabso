/**
 * KL-060 group 4: comments, replies, comment likes and pins (openapi v1.5-social DRAFT,
 * CONVENTIONS §11.5), end to end. Every response is checked against openapi.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { expectContract } from './helpers/openapi.js';
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

describe('KL-060 comments', () => {
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const post = async (u: TestUser, extra: object = {}): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'a post', ...extra });
    expect(res.status).toBe(201);
    return res.body.id as string;
  };
  const comment = (u: TestUser, postId: string, body: object) =>
    ctx.http.post(`/api/v1/posts/${postId}/comments`).set(auth(u)).send(body);
  const ids = (res: request.Response) => res.body.data.map((c: { id: string }) => c.id) as string[];
  const counts = async (postId: string) =>
    (await ctx.prisma.post.findUniqueOrThrow({ where: { id: postId }, select: { commentCount: true } }))
      .commentCount;

  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => ctx?.close());

  it('creates comments with linked mentions; validates text', async () => {
    const [author, fan, friend] = [await signup(), await signup(), await signup()];
    const postId = await post(author);
    const res = await comment(fan, postId, { text: `  nice!\n@${friend.username} look  ` });
    expect(res.status).toBe(201);
    expectContract(res, 'createComment');
    expect(res.body).toMatchObject({
      postId,
      text: `nice!\n@${friend.username} look`,
      parentId: null,
      likeCount: 0,
      replyCount: 0,
      pinned: false,
      canDelete: true,
      viewerHasLiked: false,
      author: { id: fan.id },
    });
    expect(res.body.mentions.map((m: { id: string }) => m.id)).toEqual([friend.id]);
    expect(await counts(postId)).toBe(1);
    const cases: [object, string, string][] = [
      [{}, 'text', 'required'],
      [{ text: '  ' }, 'text', 'too_short'],
      [{ text: 'x'.repeat(501) }, 'text', 'too_long'],
      [{ text: 'a\n\n\n\n\n\nb' }, 'text', 'too_long'],
      [{ text: 'hi', parentId: 'nope' }, 'parentId', 'invalid_format'],
      [{ text: 'hi', extra: true }, 'extra', 'unknown_field'],
      [{ text: 'hi', parentId: randomUUID() }, 'parentId', 'invalid_value'],
    ];
    for (const [body, field, issue] of cases) {
      const bad = await comment(fan, postId, body);
      expect(bad.status, JSON.stringify(body)).toBe(400);
      expect(bad.body.error.details, JSON.stringify(body)).toContainEqual({ field, issue });
      expectContract(bad, 'createComment');
    }
    const missing = await comment(fan, randomUUID(), { text: 'hi' });
    expect(missing.status).toBe(404);
    expectContract(missing, 'createComment');
  });

  it('whoCanComment and commentsEnabled: 403; the author always may; blocked: 404', async () => {
    const [author, follower, stranger] = [await signup(), await signup(), await signup()];
    await withMigrationClient((c) =>
      c.follow.create({ data: { followerId: follower.id, followeeId: author.id } }),
    );
    const followersOnly = await post(author, { settings: { whoCanComment: 'FOLLOWERS' } });
    const refused = await comment(stranger, followersOnly, { text: 'hi' });
    expect(refused.status).toBe(403);
    expect(refused.body.error.code).toBe('AUTH_FORBIDDEN');
    expectContract(refused, 'createComment');
    expect((await comment(follower, followersOnly, { text: 'hi' })).status).toBe(201);
    const nobody = await post(author, { settings: { whoCanComment: 'NOBODY' } });
    expect((await comment(follower, nobody, { text: 'hi' })).status).toBe(403);
    expect((await comment(author, nobody, { text: 'mine' })).status).toBe(201);
    const off = await post(author, { settings: { commentsEnabled: false } });
    expect((await comment(follower, off, { text: 'hi' })).status).toBe(403);
    await withMigrationClient((c) =>
      c.userBlock.create({ data: { blockerId: author.id, blockedId: stranger.id } }),
    );
    const open = await post(author);
    expect((await comment(stranger, open, { text: 'hi' })).status).toBe(404);
    expect((await ctx.http.get(`/api/v1/posts/${open}/comments`).set(auth(stranger))).status).toBe(404);
  });

  it('one level of replies; a reply to a reply attaches to the top-level comment', async () => {
    const [author, a, b] = [await signup(), await signup(), await signup()];
    const postId = await post(author);
    const top = (await comment(a, postId, { text: 'top' })).body.id as string;
    const r1 = await comment(b, postId, { text: 'reply 1', parentId: top });
    expect(r1.body.parentId).toBe(top);
    const r2 = await comment(a, postId, { text: 'reply 2', parentId: r1.body.id });
    expect(r2.body.parentId).toBe(top);
    // A parent on another post is refused.
    const other = await post(author);
    expect((await comment(a, other, { text: 'x', parentId: top })).body.error.details).toEqual([
      { field: 'parentId', issue: 'invalid_value' },
    ]);

    const list = await ctx.http.get(`/api/v1/posts/${postId}/comments`).set(auth(b));
    expectContract(list, 'listComments');
    expect(ids(list)).toEqual([top]);
    expect(list.body.data[0].replyCount).toBe(2);
    const page1 = await ctx.http.get(`/api/v1/comments/${top}/replies?limit=1`).set(auth(author));
    expect(page1.status).toBe(200);
    expectContract(page1, 'listReplies');
    expect(ids(page1)).toEqual([r1.body.id]);
    expect(page1.body.data[0].canDelete).toBe(true); // the post's author
    const page2 = await ctx.http
      .get(`/api/v1/comments/${top}/replies?limit=1&cursor=${page1.body.page.nextCursor}`)
      .set(auth(author));
    expect(ids(page2)).toEqual([r2.body.id]);
    expect(page2.body.page.hasMore).toBe(false);
    expect((await ctx.http.get(`/api/v1/comments/${r1.body.id}/replies`).set(auth(a))).status).toBe(404);
    expect(await counts(postId)).toBe(3);
  });

  it('delete: the comment’s author or the post’s author; replies go with it; counts follow', async () => {
    const [author, a, b] = [await signup(), await signup(), await signup()];
    const postId = await post(author);
    const top = (await comment(a, postId, { text: 'top' })).body.id as string;
    const reply = (await comment(b, postId, { text: 'reply', parentId: top })).body.id as string;
    const keep = (await comment(b, postId, { text: 'keep' })).body.id as string;
    const stranger = await ctx.http.delete(`/api/v1/comments/${top}`).set(auth(b));
    expect(stranger.status).toBe(404);
    expectContract(stranger, 'deleteComment');
    // The reply's author removes their reply: the parent's replyCount drops.
    expect((await ctx.http.delete(`/api/v1/comments/${reply}`).set(auth(b))).status).toBe(204);
    expect(
      (await ctx.http.get(`/api/v1/posts/${postId}/comments`).set(auth(a))).body.data[0]?.replyCount ?? 0,
    ).toBe(0);
    const again = (await comment(b, postId, { text: 'reply 2', parentId: top })).body.id as string;
    expect(await counts(postId)).toBe(3);
    // The post's author removes the top-level comment with its reply.
    const del = await ctx.http.delete(`/api/v1/comments/${top}`).set(auth(author));
    expect(del.status).toBe(204);
    expectContract(del, 'deleteComment');
    expect(await counts(postId)).toBe(1);
    expect(ids(await ctx.http.get(`/api/v1/posts/${postId}/comments`).set(auth(a)))).toEqual([keep]);
    expect((await ctx.http.put(`/api/v1/comments/${again}/like`).set(auth(a))).status).toBe(404);
    expect((await ctx.http.delete(`/api/v1/comments/${top}`).set(auth(author))).status).toBe(404);
  });

  it('likes: idempotent, race-safe; order: pinned, then likes, then newest', async () => {
    const [author, a, b, c] = [await signup(), await signup(), await signup(), await signup()];
    const postId = await post(author);
    const c1 = (await comment(a, postId, { text: 'one' })).body.id as string;
    const c2 = (await comment(b, postId, { text: 'two' })).body.id as string;
    const c3 = (await comment(c, postId, { text: 'three' })).body.id as string;
    const likes = await Promise.all(
      Array.from({ length: 4 }, () => ctx.http.put(`/api/v1/comments/${c1}/like`).set(auth(b))),
    );
    expect(likes.every((r) => r.status === 200)).toBe(true);
    expectContract(likes[0]!, 'likeComment');
    expect(likes[0]!.body).toEqual({ liked: true, likeCount: 1 });
    await ctx.http.put(`/api/v1/comments/${c1}/like`).set(auth(c));
    await ctx.http.put(`/api/v1/comments/${c2}/like`).set(auth(a));
    const unlike = await ctx.http.delete(`/api/v1/comments/${c2}/like`).set(auth(a));
    expectContract(unlike, 'unlikeComment');
    expect(unlike.body).toEqual({ liked: false, likeCount: 0 });
    await ctx.http.put(`/api/v1/comments/${c2}/like`).set(auth(c));
    // c1: 2 likes, c2: 1, c3: 0.
    expect(ids(await ctx.http.get(`/api/v1/posts/${postId}/comments`).set(auth(a)))).toEqual([c1, c2, c3]);

    // Pin (post author, top level): first, and only on the first page.
    const notMine = await ctx.http.put(`/api/v1/comments/${c3}/pin`).set(auth(a));
    expect(notMine.status).toBe(404);
    expectContract(notMine, 'pinComment');
    const pinned = await ctx.http.put(`/api/v1/comments/${c3}/pin`).set(auth(author));
    expect(pinned.status).toBe(200);
    expectContract(pinned, 'pinComment');
    expect(pinned.body.pinned).toBe(true);
    const p1 = await ctx.http.get(`/api/v1/posts/${postId}/comments?limit=2`).set(auth(a));
    expect(ids(p1)).toEqual([c3, c1]);
    const p2 = await ctx.http
      .get(`/api/v1/posts/${postId}/comments?limit=2&cursor=${p1.body.page.nextCursor}`)
      .set(auth(a));
    expect(ids(p2)).toEqual([c2]);
    // Pinning another replaces it; replies cannot be pinned.
    await ctx.http.put(`/api/v1/comments/${c2}/pin`).set(auth(author));
    expect(ids(await ctx.http.get(`/api/v1/posts/${postId}/comments`).set(auth(a)))).toEqual([c2, c1, c3]);
    const reply = (await comment(a, postId, { text: 'r', parentId: c1 })).body.id as string;
    const bad = await ctx.http.put(`/api/v1/comments/${reply}/pin`).set(auth(author));
    expect(bad.status).toBe(400);
    expect(bad.body.error.details).toEqual([{ field: 'commentId', issue: 'invalid_value' }]);
    const unpin = await ctx.http.delete(`/api/v1/comments/${c2}/pin`).set(auth(author));
    expect(unpin.status).toBe(200);
    expectContract(unpin, 'unpinComment');
    expect(unpin.body.pinned).toBe(false);
    expect(ids(await ctx.http.get(`/api/v1/posts/${postId}/comments`).set(auth(a)))).toEqual([c1, c2, c3]);
  });

  it('many users commenting and liking one comment at once: no deadlock, exact counts', async () => {
    const author = await signup();
    const postId = await post(author);
    const top = (await comment(author, postId, { text: 'top' })).body.id as string;
    const users = await Promise.all(Array.from({ length: 8 }, () => signup()));
    const res = await Promise.all(
      users.flatMap((u) => [
        ctx.http.put(`/api/v1/comments/${top}/like`).set(auth(u)),
        comment(u, postId, { text: 'reply', parentId: top }),
      ]),
    );
    expect(res.every((r) => r.status === 200 || r.status === 201)).toBe(true);
    expect(await ctx.prisma.comment.findUniqueOrThrow({ where: { id: top } })).toMatchObject({
      likeCount: 8,
      replyCount: 8,
    });
    expect(await counts(postId)).toBe(9);
  });

  it('comments by users the viewer blocked (or who blocked them) are hidden', async () => {
    const [author, troll, me] = [await signup(), await signup(), await signup()];
    const postId = await post(author);
    const t = (await comment(troll, postId, { text: 'troll' })).body.id as string;
    const m = (await comment(me, postId, { text: 'me' })).body.id as string;
    await withMigrationClient((c) => c.userBlock.create({ data: { blockerId: me.id, blockedId: troll.id } }));
    expect(ids(await ctx.http.get(`/api/v1/posts/${postId}/comments`).set(auth(me)))).toEqual([m]);
    expect(ids(await ctx.http.get(`/api/v1/posts/${postId}/comments`).set(auth(troll)))).toEqual([t]);
    expect((await ctx.http.put(`/api/v1/comments/${t}/like`).set(auth(me))).status).toBe(404);
    expect((await ctx.http.get(`/api/v1/comments/${t}/replies`).set(auth(me))).status).toBe(404);
  });
});
