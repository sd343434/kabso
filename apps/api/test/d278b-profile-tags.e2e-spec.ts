/**
 * D278b (v1.85-social, CONVENTIONS §10.99): the profile tags «منشنات» — set with `PATCH /me` (the whole set,
 * 0–10, each one line of 1–24 code points), read in `Me.tags` and `PublicProfile.tags` (also on a private
 * account's profile), audited by field name only, with the database CHECK as a backstop. End to end against
 * PostgreSQL + Redis with the API as the DML-only runtime role; every response checked against openapi.
 */
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

describe('D278b profile tags', () => {
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx, {});
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
    return res.body as { tags: string[] };
  };
  const profile = async (viewer: TestUser, of: TestUser) => {
    const res = await ctx.http.get(`/api/v1/users/${of.username}`).set(auth(viewer));
    expect(res.status).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body as { tags: string[] };
  };
  const details = (res: request.Response) => res.body.error?.details as { field: string; issue: string }[];

  beforeAll(async () => {
    ctx = await createTestApp({});
  });
  afterAll(async () => ctx?.close());

  it('a new account has none; the whole set is replaced in order, shown to others, and [] clears it', async () => {
    const u = await signup();
    const other = await signup();
    expect((await me(u)).tags).toEqual([]);
    const ten = [' صانعة محتوى ', 'Gamer', '10👑', ...Array.from({ length: 7 }, (_, i) => `tag ${i}`)];
    const res = await patchMe(u, { tags: ten });
    expect(res.status).toBe(200);
    expect(res.body.tags).toEqual(['صانعة محتوى', 'Gamer', '10👑', ...ten.slice(3)]);
    expect((await profile(other, u)).tags).toEqual(res.body.tags);
    // A private account's tags stay visible (as the links, §10.47).
    expect((await ctx.http.patch('/api/v1/me/privacy').set(auth(u)).send({ isPrivate: true })).status).toBe(
      200,
    );
    expect((await profile(other, u)).tags).toHaveLength(10);
    // Other fields leave the tags alone.
    await patchMe(u, { bio: 'hi' });
    expect((await me(u)).tags).toHaveLength(10);
    expect((await patchMe(u, { tags: ['Gamer'] })).body.tags).toEqual(['Gamer']);
    expect((await patchMe(u, { tags: [] })).body.tags).toEqual([]);
    // Audited by name only, never the values.
    const rows = await ctx.prisma.auditLog.findMany({
      where: { actorUserId: u.id, action: 'user.profile.update' },
      orderBy: { createdAt: 'asc' },
    });
    const withTags = rows.filter((r) => (r.metadata as { fields: string[] }).fields.includes('tags'));
    expect(withTags).toHaveLength(3);
    expect(JSON.stringify(withTags)).not.toContain('Gamer');
  });

  it('refuses bad tags with field details; nothing changes', async () => {
    const u = await signup();
    await patchMe(u, { tags: ['keep'] });
    const cases: [unknown, string, string][] = [
      [[''], 'tags.0', 'too_short'],
      [['   '], 'tags.0', 'too_short'],
      [['a'.repeat(25)], 'tags.0', 'too_long'],
      [['a\nb'], 'tags.0', 'too_long'],
      [['bad‮turn'], 'tags.0', 'invalid_format'],
      [['Gamer', 'GAMER'], 'tags.1', 'invalid_value'],
      [Array.from({ length: 11 }, (_, i) => `t${i}`), 'tags', 'too_many'],
    ];
    for (const [tags, field, issue] of cases) {
      const res = await patchMe(u, { tags });
      expect({ tags, status: res.status, details: details(res) }).toEqual({
        tags,
        status: 400,
        details: [{ field, issue }],
      });
    }
    expect((await me(u)).tags).toEqual(['keep']);
  });

  it('the database refuses an eleventh tag (CHECK backstop)', async () => {
    const u = await signup();
    await withMigrationClient(async (c) => {
      await expect(
        c.userProfile.update({
          where: { userId: u.id },
          data: { tags: Array.from({ length: 11 }, (_, i) => `t${i}`) },
        }),
      ).rejects.toThrow();
    });
  });
});
