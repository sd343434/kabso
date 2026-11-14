/**
 * D121 (owner: "I can't see who follows me and whom I follow"): `GET /users/{username}/followers`
 * and `GET /users/{username}/following` (openapi v1.25.2-live DRAFT, CONVENTIONS §10.6), and the
 * profile counts that agree with them (ACTIVE accounts only), end to end. D125 (v1.26.1-live): the
 * lists' search (`q`) and order (`order`), and `DELETE /me/followers/{username}`.
 */
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('KL-086 follow lists (D121)', () => {
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  /** `a` follows `b`, the follow dated `minutesAgo` minutes back (a stable order). */
  const follow = async (a: TestUser, b: TestUser, minutesAgo = 0) => {
    const res = await ctx.http.put(`/api/v1/users/${b.username}/follow`).set(auth(a));
    expect(res.status).toBe(200);
    await ctx.prisma.follow.update({
      where: { followerId_followeeId: { followerId: a.id, followeeId: b.id } },
      data: { createdAt: new Date(Date.UTC(2026, 9, 1) - minutesAgo * 60_000) },
    });
  };
  const followers = (reader: TestUser, username: string, query: Record<string, string | number> = {}) =>
    ctx.http
      .get(`/api/v1/users/${encodeURIComponent(username)}/followers`)
      .query(query)
      .set(auth(reader));
  const following = (reader: TestUser, username: string, query: Record<string, string | number> = {}) =>
    ctx.http
      .get(`/api/v1/users/${encodeURIComponent(username)}/following`)
      .query(query)
      .set(auth(reader));
  const names = (res: request.Response) =>
    res.body.data.map((u: { username: string }) => u.username) as string[];
  const profile = (reader: TestUser, u: TestUser) =>
    ctx.http.get(`/api/v1/users/${u.username}`).set(auth(reader));
  const expectError = (res: request.Response, status: number, code: string) => {
    expect(res.status).toBe(status);
    expect(res.body.error.code).toBe(code);
  };

  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => ctx?.close());

  it('lists followers and following newest first, paged, with the reader’s relation', async () => {
    const [star, a, b, c, me] = [
      await signup(),
      await signup(),
      await signup(),
      await signup(),
      await signup(),
    ];
    await follow(a, star, 30);
    await follow(b, star, 20);
    await follow(me, star, 10);
    await follow(c, star, 5);
    await follow(star, a, 3);
    await follow(star, b, 2);
    await follow(me, b, 1);
    await follow(c, me, 1);

    const first = await followers(me, star.username, { limit: 2 });
    expect(first.status).toBe(200);
    expectContract(first, 'listUserFollowers');
    expect(names(first)).toEqual([c.username, me.username]);
    expect(first.body.page.hasMore).toBe(true);
    expect(first.body.data[0]).toEqual({
      id: c.id,
      username: c.username,
      displayName: expect.any(String),
      avatarUrl: null,
      isSelf: false,
      isPrivate: false,
      followedByMe: false,
      // v1.47-social (D175): no pending follow request.
      requestedByMe: false,
      followsMe: true,
    });
    expect(first.body.data[1]).toMatchObject({
      id: me.id,
      isSelf: true,
      followedByMe: false,
      followsMe: false,
    });

    const second = await followers(me, star.username, { limit: 2, cursor: first.body.page.nextCursor });
    expectContract(second, 'listUserFollowers');
    expect(names(second)).toEqual([b.username, a.username]);
    expect(second.body.data[0]).toMatchObject({ followedByMe: true, followsMe: false });
    expect(second.body.page).toEqual({ nextCursor: null, hasMore: false });

    const theirs = await following(me, star.username);
    expect(theirs.status).toBe(200);
    expectContract(theirs, 'listUserFollowing');
    expect(names(theirs)).toEqual([b.username, a.username]);
    expect(theirs.body.data[0]).toMatchObject({ followedByMe: true });

    // My own lists, and the counts agree with them.
    expect(names(await following(me, me.username))).toEqual([b.username, star.username]);
    expect(names(await followers(me, me.username))).toEqual([c.username]);
    expect((await profile(me, star)).body).toMatchObject({ followerCount: 4, followingCount: 2 });

    // Empty lists.
    const empty = await followers(me, c.username);
    expect(empty.body).toEqual({ data: [], page: { nextCursor: null, hasMore: false } });
  });

  it('leaves suspended and deleted accounts out of the lists and the counts', async () => {
    const [star, gone, kept, reader] = [await signup(), await signup(), await signup(), await signup()];
    await follow(gone, star, 2);
    await follow(kept, star, 1);
    await follow(star, gone, 1);
    await ctx.prisma.user.update({ where: { id: gone.id }, data: { status: 'SUSPENDED' } });
    expect(names(await followers(reader, star.username))).toEqual([kept.username]);
    expect((await following(reader, star.username)).body.data).toEqual([]);
    expect((await profile(reader, star)).body).toMatchObject({ followerCount: 1, followingCount: 0 });
    // The rows are kept (suspension is reversible) and count again once the account is back.
    await ctx.prisma.user.update({ where: { id: gone.id }, data: { status: 'ACTIVE' } });
    expect(names(await followers(reader, star.username))).toEqual([kept.username, gone.username]);
    const back = await ctx.http.put(`/api/v1/users/${star.username}/follow`).set(auth(reader));
    expect(back.body).toEqual({ isFollowing: true, isRequested: false, followerCount: 3 });
  });

  it('hides people the reader has a block with, and 404s across a block with the user', async () => {
    const [star, blocker, blocked, reader, other] = [
      await signup(),
      await signup(),
      await signup(),
      await signup(),
      await signup(),
    ];
    await follow(blocker, star, 3);
    await follow(blocked, star, 2);
    await follow(other, star, 1);
    await follow(star, blocked, 1);
    // `blocker` blocked the reader; the reader blocked `blocked`.
    expect((await ctx.http.put(`/api/v1/users/${reader.username}/block`).set(auth(blocker))).status).toBe(
      200,
    );
    expect((await ctx.http.put(`/api/v1/users/${blocked.username}/block`).set(auth(reader))).status).toBe(
      200,
    );
    expect(names(await followers(reader, star.username))).toEqual([other.username]);
    expect((await following(reader, star.username)).body.data).toEqual([]);
    // Everyone else still sees them, and the count is the same for everyone (documented).
    expect(names(await followers(other, star.username))).toEqual([
      other.username,
      blocked.username,
      blocker.username,
    ]);
    expect((await profile(reader, star)).body.followerCount).toBe(3);

    // Across a block with the listed user itself, either way: the same 404 as an unknown user.
    for (const [who, target] of [
      [reader, blocked],
      [blocked, reader],
      [reader, blocker],
    ] as const) {
      const res = await followers(who, target.username);
      expectContract(res, 'listUserFollowers');
      expectError(res, 404, 'NOT_FOUND');
      expectError(await following(who, target.username), 404, 'NOT_FOUND');
    }
  });

  it('404 for unknown, malformed, suspended and deleted users', async () => {
    const [reader, suspended, deleted] = [await signup(), await signup(), await signup()];
    await ctx.prisma.user.update({ where: { id: suspended.id }, data: { status: 'SUSPENDED' } });
    await ctx.prisma.user.update({ where: { id: deleted.id }, data: { status: 'DELETED' } });
    for (const name of ['nobody_here_x', 'Bad Name!', 'a\u0000b', suspended.username, deleted.username]) {
      const res = await following(reader, name);
      expectContract(res, 'listUserFollowing');
      expectError(res, 404, 'NOT_FOUND');
    }
  });

  it('a private account’s lists are its own and its followers’ only (403 otherwise)', async () => {
    const [priv, fan, stranger] = [await signup(), await signup(), await signup()];
    await follow(fan, priv, 1);
    await ctx.prisma.userSettings.update({ where: { userId: priv.id }, data: { isPrivate: true } });
    const refused = await followers(stranger, priv.username);
    expectContract(refused, 'listUserFollowers');
    expectError(refused, 403, 'AUTH_FORBIDDEN');
    expectError(await following(stranger, priv.username), 403, 'AUTH_FORBIDDEN');
    expect(names(await followers(fan, priv.username))).toEqual([fan.username]);
    expect(names(await followers(priv, priv.username))).toEqual([fan.username]);
    // A private account in someone's list is marked, so the app does not offer Follow.
    const fans = await following(stranger, fan.username);
    expect(fans.body.data).toEqual([
      expect.objectContaining({ id: priv.id, isPrivate: true, followedByMe: false }),
    ]);
  });

  it('rejects bad cursors and limits (400), including a cursor of another list, user or reader', async () => {
    const [star, a, b, reader, other] = [
      await signup(),
      await signup(),
      await signup(),
      await signup(),
      await signup(),
    ];
    await follow(a, star, 2);
    await follow(b, star, 1);
    await follow(star, a, 1);
    await follow(star, b, 2);
    const cursor = (await followers(reader, star.username, { limit: 1 })).body.page.nextCursor as string;
    expect(cursor).toEqual(expect.any(String));
    for (const res of [
      await followers(reader, star.username, { cursor: 'garbage' }),
      await following(reader, star.username, { cursor }),
      await followers(other, star.username, { cursor }),
      await followers(reader, a.username, { cursor }),
    ]) {
      expectError(res, 400, 'VALIDATION_FAILED');
      expect(res.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    for (const limit of [0, 51, 'x']) {
      const res = await followers(reader, star.username, { limit });
      expectContract(res, 'listUserFollowers');
      expectError(res, 400, 'VALIDATION_FAILED');
    }
    expect((await ctx.http.get(`/api/v1/users/${star.username}/followers`)).status).toBe(401);
  });

  describe('D125 search, order and removing a follower', () => {
    /** Sets the profile names of `u` (usernames are lowercase, §6). */
    const rename = async (u: TestUser, username: string, displayName: string) => {
      await ctx.prisma.userProfile.update({ where: { userId: u.id }, data: { username, displayName } });
      return { ...u, username };
    };
    // Starts with a digit so a tag can never extend a probe such as `omar_x` into a real prefix.
    const tag = () => `0${Math.random().toString(36).slice(2, 8)}`;

    it('q keeps a case-insensitive prefix of the username or the display name', async () => {
      const t = tag();
      const star = await rename(await signup(), `star_${t}`, 'Star');
      const reader = await signup();
      const sara = await rename(await signup(), `sara_${t}`, 'Sara K');
      const omar = await rename(await signup(), `omar_${t}`, 'Saleh Omar');
      const lina = await rename(await signup(), `lina_${t}`, 'لينا');
      const under = await rename(await signup(), `xa1b_${t}`, 'Under');
      await follow(sara, star, 4);
      await follow(omar, star, 3);
      await follow(lina, star, 2);
      await follow(under, star, 1);
      await follow(star, sara, 1);
      await follow(star, lina, 2);

      const sa = await followers(reader, star.username, { q: '  SA ' });
      expect(sa.status).toBe(200);
      expectContract(sa, 'listUserFollowers');
      // `sara_…` by username, `Saleh Omar` by display name; newest follow first.
      expect(names(sa)).toEqual([omar.username, sara.username]);
      expect(names(await followers(reader, star.username, { q: 'لي' }))).toEqual([lina.username]);
      // A prefix, not a substring; LIKE wildcards are plain characters.
      expect((await followers(reader, star.username, { q: 'omar_x' })).body.data).toEqual([]);
      expect((await followers(reader, star.username, { q: 'ara' })).body.data).toEqual([]);
      expect((await followers(reader, star.username, { q: 'x_' })).body.data).toEqual([]);
      expect((await followers(reader, star.username, { q: '%' })).body.data).toEqual([]);
      expect((await followers(reader, star.username, { q: '\\' })).body.data).toEqual([]);
      expect(names(await followers(reader, star.username, { q: 'xa1b_' }))).toEqual([under.username]);
      const theirs = await following(reader, star.username, { q: 'L' });
      expectContract(theirs, 'listUserFollowing');
      expect(names(theirs)).toEqual([lina.username]);

      // Paged with a cursor bound to the search.
      const first = await followers(reader, star.username, { q: 'sa', limit: 1 });
      expect(names(first)).toEqual([omar.username]);
      const cursor = first.body.page.nextCursor as string;
      const second = await followers(reader, star.username, { q: 'SA', limit: 1, cursor });
      expect(names(second)).toEqual([sara.username]);
      expect(second.body.page).toEqual({ nextCursor: null, hasMore: false });
      for (const res of [
        await followers(reader, star.username, { q: 'sar', limit: 1, cursor }),
        await followers(reader, star.username, { limit: 1, cursor }),
      ]) {
        expectError(res, 400, 'VALIDATION_FAILED');
        expect(res.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
      }
      for (const q of ['', '   ', 'x'.repeat(31)]) {
        const res = await followers(reader, star.username, { q });
        expectContract(res, 'listUserFollowers');
        expectError(res, 400, 'VALIDATION_FAILED');
        expect(res.body.error.details[0].field).toBe('q');
      }
      expect(names(await followers(reader, star.username, { q: 'x'.repeat(30) }))).toEqual([]);
    });

    it('order=oldest lists the oldest follow first, paged, the cursor bound to the order', async () => {
      const [star, a, b, c, reader] = [
        await signup(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      await follow(a, star, 30);
      await follow(b, star, 20);
      await follow(c, star, 10);
      await follow(star, c, 5);
      await follow(star, a, 1);
      const first = await followers(reader, star.username, { order: 'oldest', limit: 2 });
      expectContract(first, 'listUserFollowers');
      expect(names(first)).toEqual([a.username, b.username]);
      const cursor = first.body.page.nextCursor as string;
      const second = await followers(reader, star.username, { order: 'oldest', limit: 2, cursor });
      expect(names(second)).toEqual([c.username]);
      expect(second.body.page.hasMore).toBe(false);
      expect(names(await followers(reader, star.username, { order: 'newest' }))).toEqual([
        c.username,
        b.username,
        a.username,
      ]);
      expect(names(await following(reader, star.username, { order: 'oldest' }))).toEqual([
        c.username,
        a.username,
      ]);
      // The default list's cursor is not one of the oldest-first list, and back.
      const newest = (await followers(reader, star.username, { limit: 1 })).body.page.nextCursor as string;
      for (const res of [
        await followers(reader, star.username, { order: 'oldest', cursor: newest }),
        await followers(reader, star.username, { order: 'newest', cursor }),
      ]) {
        expectError(res, 400, 'VALIDATION_FAILED');
        expect(res.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
      }
      // The explicit default keeps the D121 cursor.
      expect(
        names(await followers(reader, star.username, { order: 'newest', limit: 1, cursor: newest })),
      ).toEqual([b.username]);
      const bad = await following(reader, star.username, { order: 'random' });
      expectContract(bad, 'listUserFollowing');
      expectError(bad, 400, 'VALIDATION_FAILED');
      expect(bad.body.error.details[0].field).toBe('order');
    });

    it('DELETE /me/followers/{username} removes a follower, idempotent, counts and notification updated', async () => {
      const [me, fan, other, stranger] = [await signup(), await signup(), await signup(), await signup()];
      await follow(fan, me, 2);
      await follow(other, me, 1);
      await follow(me, fan, 1);
      const notes = () => ctx.prisma.notification.count({ where: { recipientId: me.id, type: 'FOLLOW' } });
      const notesBefore = await notes();
      expect(notesBefore).toBeGreaterThan(0);
      const remove = (who: TestUser, username: string) =>
        ctx.http.delete(`/api/v1/me/followers/${encodeURIComponent(username)}`).set(auth(who));

      const res = await remove(me, fan.username);
      expect(res.status).toBe(200);
      expectContract(res, 'removeMyFollower');
      expect(res.body).toEqual({ followsMe: false, followerCount: 1 });
      expect(names(await followers(me, me.username))).toEqual([other.username]);
      expect((await profile(stranger, me)).body).toMatchObject({ followerCount: 1, followingCount: 1 });
      // Only that edge: I still follow them, and they see it.
      expect(names(await following(me, me.username))).toEqual([fan.username]);
      expect((await following(fan, fan.username)).body.data).toEqual([]);
      expect(await notes()).toBeLessThan(notesBefore);

      // Idempotent: not a follower (any more) → 200, nothing changes.
      const again = await remove(me, fan.username);
      expect(again.status).toBe(200);
      expect(again.body).toEqual({ followsMe: false, followerCount: 1 });
      expect((await remove(me, stranger.username)).body).toEqual({ followsMe: false, followerCount: 1 });

      // A public account: they may follow again.
      expect((await ctx.http.put(`/api/v1/users/${me.username}/follow`).set(auth(fan))).body).toEqual({
        isFollowing: true,
        isRequested: false,
        followerCount: 2,
      });
      // A private account: a removed follower comes back only through a follow request (v1.47-social,
      // D175; it was 403 before follow requests existed).
      await ctx.prisma.userSettings.update({ where: { userId: me.id }, data: { isPrivate: true } });
      expect((await remove(me, other.username)).body).toEqual({ followsMe: false, followerCount: 1 });
      expect((await ctx.http.put(`/api/v1/users/${me.username}/follow`).set(auth(other))).body).toEqual({
        isFollowing: false,
        isRequested: true,
        followerCount: 1,
      });
    });

    it('DELETE /me/followers/{username}: 404 unknown / malformed / suspended, 400 self, 401', async () => {
      const [me, gone] = [await signup(), await signup()];
      await follow(gone, me, 1);
      await ctx.prisma.user.update({ where: { id: gone.id }, data: { status: 'SUSPENDED' } });
      for (const name of ['nobody_here_x', 'Bad Name!', gone.username]) {
        const res = await ctx.http.delete(`/api/v1/me/followers/${encodeURIComponent(name)}`).set(auth(me));
        expectContract(res, 'removeMyFollower');
        expectError(res, 404, 'NOT_FOUND');
      }
      const self = await ctx.http.delete(`/api/v1/me/followers/${me.username}`).set(auth(me));
      expectContract(self, 'removeMyFollower');
      expectError(self, 400, 'VALIDATION_FAILED');
      expect(self.body.error.details).toEqual([{ field: 'username', issue: 'invalid_value' }]);
      expect((await ctx.http.delete(`/api/v1/me/followers/${gone.username}`)).status).toBe(401);
    });
  });
});
