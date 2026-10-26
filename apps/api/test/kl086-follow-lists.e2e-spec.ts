/**
 * D121 (owner: "I can't see who follows me and whom I follow"): `GET /users/{username}/followers`
 * and `GET /users/{username}/following` (openapi v1.25.2-live DRAFT, CONVENTIONS §10.6), and the
 * profile counts that agree with them (ACTIVE accounts only), end to end.
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
    expect(back.body).toEqual({ isFollowing: true, followerCount: 3 });
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
});
