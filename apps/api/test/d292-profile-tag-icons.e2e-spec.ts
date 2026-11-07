/**
 * D292 (v1.91-social, CONVENTIONS §10.106): an icon per profile tag, chosen by the person — set with `PATCH /me`
 * `tagIcons` (one per tag, only with `tags`), read in `Me.tagIcons` and `PublicProfile.tagIcons`; an older app that
 * sends only `tags` keeps each tag's icon by its text; audited by field name only; the database CHECKs as backstop.
 * End to end against PostgreSQL + Redis with the API as the DML-only runtime role; every response checked against
 * openapi.
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

interface Tagged {
  tags: string[];
  tagIcons: string[];
}

describe('D292 profile tag icons', () => {
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
  const me = async (u: TestUser): Promise<Tagged> => {
    const res = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMe');
    return res.body as Tagged;
  };
  const profile = async (viewer: TestUser, of: TestUser): Promise<Tagged> => {
    const res = await ctx.http.get(`/api/v1/users/${of.username}`).set(auth(viewer));
    expect(res.status).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body as Tagged;
  };
  const details = (res: request.Response) => res.body.error?.details as { field: string; issue: string }[];

  beforeAll(async () => {
    ctx = await createTestApp({});
  });
  afterAll(async () => ctx?.close());

  it('sets tags with icons, reads them back on Me and on the public profile, audited by name only', async () => {
    const u = await signup();
    const other = await signup();
    expect(await me(u)).toMatchObject({ tags: [], tagIcons: [] });
    const res = await patchMe(u, {
      tags: ['صانع محتوى', 'السعودية', 'Gamer', 'Plain'],
      tagIcons: ['crown', 'flag:sa', 'gamepad', null],
    });
    expect(res.status).toBe(200);
    expect(res.body.tags).toEqual(['صانع محتوى', 'السعودية', 'Gamer', 'Plain']);
    expect(res.body.tagIcons).toEqual(['crown', 'flag:SA', 'gamepad', 'default']);
    expect(await me(u)).toMatchObject({ tagIcons: ['crown', 'flag:SA', 'gamepad', 'default'] });
    expect(await profile(other, u)).toMatchObject({
      tags: ['صانع محتوى', 'السعودية', 'Gamer', 'Plain'],
      tagIcons: ['crown', 'flag:SA', 'gamepad', 'default'],
    });
    // Every icon of the closed set is accepted.
    const all = ['default', 'crown', 'fire', 'trophy', 'gamepad', 'music', 'mic', 'moon', 'heart', 'star'];
    const ten = all.map((_, i) => `t${i}`);
    expect((await patchMe(u, { tags: ten, tagIcons: all })).body.tagIcons).toEqual(all);
    const rest = ['gem', 'camera', 'book', 'sport', 'palette', 'globe'];
    expect((await patchMe(u, { tags: rest.map((_, i) => `r${i}`), tagIcons: rest })).body.tagIcons).toEqual(
      rest,
    );
    // Same icons, same tags: no audit row; changed icons only: `tagIcons` alone.
    await patchMe(u, { tags: ['a', 'b'], tagIcons: ['star', 'moon'] });
    await patchMe(u, { tags: ['a', 'b'], tagIcons: ['star', 'moon'] });
    await patchMe(u, { tags: ['a', 'b'], tagIcons: ['heart', 'moon'] });
    const rows = await ctx.prisma.auditLog.findMany({
      where: { actorUserId: u.id, action: 'user.profile.update' },
      orderBy: { createdAt: 'asc' },
    });
    const fields = rows.map((r) => (r.metadata as { fields: string[] }).fields);
    expect(fields.at(-1)).toEqual(['tagIcons']);
    expect(fields.filter((f) => f.includes('tagIcons'))).toHaveLength(5);
    expect(JSON.stringify(rows)).not.toContain('heart');
    expect(JSON.stringify(rows)).not.toContain('flag:SA');
  });

  it('an older app sending only tags keeps each tag icon by its text; a new tag is default', async () => {
    const u = await signup();
    await patchMe(u, { tags: ['Music', 'Games', 'Saudi'], tagIcons: ['music', 'gamepad', 'flag:SA'] });
    // Reordered, one renamed in case, one dropped, one new.
    const res = await patchMe(u, { tags: ['saudi', 'New', 'MUSIC'] });
    expect(res.status).toBe(200);
    expect(res.body.tags).toEqual(['saudi', 'New', 'MUSIC']);
    expect(res.body.tagIcons).toEqual(['flag:SA', 'default', 'music']);
    // Other fields leave tags and icons alone.
    await patchMe(u, { bio: 'hi' });
    expect((await me(u)).tagIcons).toEqual(['flag:SA', 'default', 'music']);
    // [] clears both.
    expect((await patchMe(u, { tags: [] })).body).toMatchObject({ tags: [], tagIcons: [] });
  });

  it('rows from before v1.91-social (no icons stored) read as default for every tag', async () => {
    const u = await signup();
    await withMigrationClient(async (c) => {
      await c.userProfile.update({ where: { userId: u.id }, data: { tags: ['old', 'ones'], tagIcons: [] } });
    });
    expect(await me(u)).toMatchObject({ tags: ['old', 'ones'], tagIcons: ['default', 'default'] });
  });

  it('refuses unknown icons and a length mismatch with field details; nothing changes', async () => {
    const u = await signup();
    await patchMe(u, { tags: ['keep'], tagIcons: ['star'] });
    const cases: [unknown, string, string][] = [
      [{ tags: ['x'], tagIcons: ['rocket'] }, 'tagIcons.0', 'invalid_value'],
      [{ tags: ['x'], tagIcons: ['flag'] }, 'tagIcons.0', 'invalid_value'],
      [{ tags: ['x'], tagIcons: ['flag:ZZ'] }, 'tagIcons.0', 'invalid_value'],
      [{ tags: ['x'], tagIcons: ['flag:SAU'] }, 'tagIcons.0', 'invalid_value'],
      [{ tags: ['x'], tagIcons: ['👑'] }, 'tagIcons.0', 'invalid_value'],
      [{ tags: ['x', 'y'], tagIcons: ['star', 'CROWN'] }, 'tagIcons.1', 'invalid_value'],
      [{ tags: ['x', 'y'], tagIcons: ['star'] }, 'tagIcons', 'invalid_value'],
      [{ tags: ['x'], tagIcons: ['star', 'moon'] }, 'tagIcons', 'invalid_value'],
      [{ tagIcons: ['star'] }, 'tagIcons', 'invalid_value'],
    ];
    for (const [body, field, issue] of cases) {
      const res = await patchMe(u, body);
      expect({ body, status: res.status, details: details(res) }).toEqual({
        body,
        status: 400,
        details: [{ field, issue }],
      });
    }
    expect(await me(u)).toMatchObject({ tags: ['keep'], tagIcons: ['star'] });
  });

  it('the 10-tag limit is unchanged', async () => {
    const u = await signup();
    const eleven = Array.from({ length: 11 }, (_, i) => `t${i}`);
    const res = await patchMe(u, { tags: eleven, tagIcons: eleven.map(() => 'star') });
    expect(res.status).toBe(400);
    expect(details(res)).toContainEqual({ field: 'tags', issue: 'too_many' });
  });

  it('the database refuses a length mismatch and an unknown icon (CHECK backstops)', async () => {
    const u = await signup();
    await withMigrationClient(async (c) => {
      await expect(
        c.userProfile.update({ where: { userId: u.id }, data: { tags: ['a', 'b'], tagIcons: ['star'] } }),
      ).rejects.toThrow();
      await expect(
        c.userProfile.update({ where: { userId: u.id }, data: { tags: ['a'], tagIcons: ['rocket'] } }),
      ).rejects.toThrow();
      await expect(
        c.userProfile.update({ where: { userId: u.id }, data: { tags: ['a'], tagIcons: ['flag:sa'] } }),
      ).rejects.toThrow();
    });
  });
});
