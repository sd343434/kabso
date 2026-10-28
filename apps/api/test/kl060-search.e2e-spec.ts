/**
 * KL-060 group 5: hashtag pages and search (openapi v1.5-social DRAFT, CONVENTIONS §11.6), end to
 * end. The e2e database keeps earlier runs' rows, so every tag and word here is unique per run.
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

describe('KL-060 hashtags and search', () => {
  let ctx: TestContext;
  const run = randomUUID().replace(/-/g, '').slice(0, 10);
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const post = async (u: TestUser, text: string): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ text });
    expect(res.status).toBe(201);
    return res.body.id as string;
  };
  const ids = (res: request.Response) => res.body.data.map((p: { id: string }) => p.id) as string[];
  const search = (u: TestUser, q: string, type: string, extra = '') =>
    ctx.http.get(`/api/v1/search?q=${encodeURIComponent(q)}&type=${type}${extra}`).set(auth(u));

  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => ctx?.close());

  describe('hashtags', () => {
    it('a hashtag page: visible post count, recent and top, any case, hidden posts left out', async () => {
      const [a, b, me, priv] = [await signup(), await signup(), await signup(), await signup()];
      const tag = `tag${run}`;
      const p1 = await post(a, `first #${tag}`);
      const p2 = await post(b, `second #${tag.toUpperCase()}`);
      const p3 = await post(a, `third #${tag}`);
      await post(priv, `private #${tag}`);
      await withMigrationClient((c) =>
        c.userSettings.update({ where: { userId: priv.id }, data: { isPrivate: true } }),
      );
      for (const fan of [await signup(), await signup()])
        await ctx.http.put(`/api/v1/posts/${p1}/like`).set(auth(fan));

      const page = await ctx.http.get(`/api/v1/hashtags/${tag.toUpperCase()}`).set(auth(me));
      expect(page.status).toBe(200);
      expectContract(page, 'getHashtag');
      expect(page.body).toEqual({ tag, postCount: 3 });

      const recent = await ctx.http.get(`/api/v1/hashtags/${tag}/posts?limit=2`).set(auth(me));
      expect(recent.status).toBe(200);
      expectContract(recent, 'listHashtagPosts');
      expect(ids(recent)).toEqual([p3, p2]);
      const more = await ctx.http
        .get(`/api/v1/hashtags/${tag}/posts?limit=2&cursor=${recent.body.page.nextCursor}`)
        .set(auth(me));
      expect(ids(more)).toEqual([p1]);

      const top = await ctx.http.get(`/api/v1/hashtags/${tag}/posts?sort=top`).set(auth(me));
      expectContract(top, 'listHashtagPosts');
      expect(ids(top)[0]).toBe(p1);
      expect(ids(top)).toHaveLength(3);
      // A cursor of one list is refused by the other.
      const wrong = await ctx.http
        .get(`/api/v1/hashtags/${tag}/posts?sort=top&cursor=${recent.body.page.nextCursor}`)
        .set(auth(me));
      expect(wrong.status).toBe(400);
      expectContract(wrong, 'listHashtagPosts');

      // Hiding a post removes it from the page and the count.
      await withMigrationClient((c) => c.postHide.create({ data: { userId: me.id, postId: p2 } }));
      expect((await ctx.http.get(`/api/v1/hashtags/${tag}`).set(auth(me))).body.postCount).toBe(2);
      expect(ids(await ctx.http.get(`/api/v1/hashtags/${tag}/posts`).set(auth(me)))).toEqual([p3, p1]);
    });

    it('unknown or malformed tags are 404; bad sort is 400', async () => {
      const me = await signup();
      for (const t of [`none${run}`, encodeURIComponent('bad tag'), '___']) {
        const res = await ctx.http.get(`/api/v1/hashtags/${t}`).set(auth(me));
        expect(res.status, t).toBe(404);
        expectContract(res, 'getHashtag');
      }
      const tag = `sorts${run}`;
      await post(me, `#${tag}`);
      const bad = await ctx.http.get(`/api/v1/hashtags/${tag}/posts?sort=hot`).set(auth(me));
      expect(bad.status).toBe(400);
    });
  });

  describe('search', () => {
    it('users: prefix on username and display name, exact first, blocked never shown', async () => {
      const [me, blocker] = [await signup(), await signup()];
      const names = [`s${run}a`, `s${run}`, `s${run}b`];
      const users: TestUser[] = [];
      for (const name of names) {
        const u = await signup();
        await withMigrationClient((c) =>
          c.userProfile.update({ where: { userId: u.id }, data: { username: name } }),
        );
        users.push({ ...u, username: name });
      }
      await withMigrationClient((c) =>
        c.userProfile.update({ where: { userId: blocker.id }, data: { displayName: `S${run} Blocker` } }),
      );
      // users[2] has followers, so it ranks before users[0] after the exact match.
      await withMigrationClient((c) =>
        c.follow.create({ data: { followerId: me.id, followeeId: users[2]!.id } }),
      );
      await withMigrationClient((c) =>
        c.userBlock.create({ data: { blockerId: blocker.id, blockedId: me.id } }),
      );

      const res = await search(me, `@S${run}`, 'users');
      expect(res.status).toBe(200);
      expectContract(res, 'search');
      expect(res.body.type).toBe('users');
      expect(res.body.data.map((u: { id: string }) => u.id)).toEqual([
        users[1]!.id,
        users[2]!.id,
        users[0]!.id,
      ]);
      expect(res.body.data[0]).toEqual({
        id: users[1]!.id,
        username: names[1],
        displayName: expect.any(String),
        avatarUrl: null,
      });
      const p1 = await search(me, `s${run}`, 'users', '&limit=2');
      const p2 = await search(me, `s${run}`, 'users', `&limit=2&cursor=${p1.body.page.nextCursor}`);
      expect([...p1.body.data, ...p2.body.data]).toHaveLength(3);
      expect(p2.body.page.hasMore).toBe(false);
      // The blocker searching sees nobody blocked either (they blocked me).
      const theirs = await search(blocker, `s${run}`, 'users');
      expect(theirs.body.data.map((u: { id: string }) => u.id)).not.toContain(me.id);
      // A wildcard is literal.
      expect((await search(me, `s${run.slice(0, 3)}%`, 'users')).body.data).toEqual([]);
    });

    it('D142: a letters-and-digits username (as "nabulsi001") is found — no posts, any case, @, prefix, own account', async () => {
      // The owner's device check: an account with no posts and no followers, named like
      // "nabulsi001" (letters then digits), searched by itself and by someone else.
      const [owner, other] = [await signup(), await signup()];
      const name = `n${run}001`;
      await withMigrationClient((c) =>
        c.userProfile.update({ where: { userId: owner.id }, data: { username: name } }),
      );
      for (const [who, q] of [
        [other, name],
        [other, `@${name}`],
        [other, name.toUpperCase()],
        [other, ` ${name} `],
        [other, name.slice(0, 1)],
        [other, name.slice(0, -1)],
        [owner, name],
      ] as const) {
        const res = await search(who, q, 'users');
        expect(res.status).toBe(200);
        expect(ids(res)).toContain(owner.id);
      }
      // Exact match first.
      expect(ids(await search(other, name, 'users'))[0]).toBe(owner.id);
      // Not a substring match: the middle of a username finds nothing.
      expect(ids(await search(other, name.slice(1), 'users'))).not.toContain(owner.id);
    });

    it('hashtags: prefix, exact first, with visible counts', async () => {
      const me = await signup();
      await post(me, `#h${run} #h${run}x #h${run}x`);
      await post(me, `#h${run}x`);
      const res = await search(me, `#H${run}`, 'hashtags');
      expect(res.status).toBe(200);
      expectContract(res, 'search');
      expect(res.body).toMatchObject({
        type: 'hashtags',
        data: [
          { tag: `h${run}`, postCount: 1 },
          { tag: `h${run}x`, postCount: 2 },
        ],
      });
    });

    it('posts: caption word prefixes, newest first, visible only', async () => {
      const [me, a, priv] = [await signup(), await signup(), await signup()];
      const word = `w${run}`;
      const old = await post(a, `hello ${word}alpha world`);
      const recent = await post(a, `${word}beta مرحبا`);
      await post(priv, `${word} secret`);
      await withMigrationClient((c) =>
        c.userSettings.update({ where: { userId: priv.id }, data: { isPrivate: true } }),
      );
      const res = await search(me, word, 'posts');
      expect(res.status).toBe(200);
      expectContract(res, 'search');
      expect(ids(res)).toEqual([recent, old]);
      expect(ids(await search(me, `${word}al wor`, 'posts'))).toEqual([old]);
      expect(ids(await search(me, `${word} مرح`, 'posts'))).toEqual([recent]);
      // Operators are not syntax.
      expect((await search(me, `${word} & !|:*`, 'posts')).status).toBe(200);
      expect(ids(await search(me, '!!!', 'posts'))).toEqual([]);
    });

    it('validates q and type', async () => {
      const me = await signup();
      const cases: [string, string, string][] = [
        ['', 'users', 'q'],
        ['@', 'users', 'q'],
        ['x'.repeat(65), 'users', 'q'],
        ['a\u0000b', 'users', 'q'],
        ['ok', 'people', 'type'],
      ];
      for (const [q, type, field] of cases) {
        const res = await search(me, q, type);
        expect(res.status, q).toBe(400);
        expect(res.body.error.details[0].field, q).toBe(field);
        expectContract(res, 'search');
      }
    });
  });
});
