/**
 * D367 (owner 2026-11-11, «في صفحة الموظفين يظهر تصنيف مثل شاعر، يجب إلغاؤه من صفحة المشرفين»; contract v1.124-social,
 * CONVENTIONS §10.160), end to end against PostgreSQL + Redis:
 *
 *  - a Kabso Team account (any panel role — a limited staff member, the founder / OWNER too) answers `category: null` on
 *    `Me` (GET and PATCH) and on its public profile, for itself and for visitors;
 *  - the stored category is kept: it shows again once the role is revoked;
 *  - a regular account keeps its category exactly as before.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { grantRoleIn, revokeRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  token: string;
}

describe('D367 a Kabso Team profile shows no account category', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  let ipCounter = 40;
  const nextIp = () => {
    ipCounter += 1;
    return `198.51.${Math.floor(ipCounter / 250)}.${(ipCounter % 250) + 1}`;
  };
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });

  const signup = async (): Promise<TestUser> => {
    const payload = newUser();
    const email = String(payload.email).trim().toLowerCase();
    const before = ctx.mail.sent.length;
    const ip = nextIp();
    const res = await ctx.http.post('/api/v1/auth/register').set('X-Forwarded-For', ip).send(payload);
    expect(res.status, JSON.stringify(res.body)).toBe(202);
    const mail = await ctx.mail.waitFor(email, 'code', before);
    const ok = await ctx.http
      .post('/api/v1/auth/register/verify')
      .set('X-Forwarded-For', ip)
      .send({ email, code: mail.code });
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    return {
      id: ok.body.user.id as string,
      username: ok.body.user.username as string,
      email,
      token: ok.body.tokens.accessToken as string,
    };
  };
  const grant = (p: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, p.email, role as never)));
  const revoke = (p: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => revokeRoleIn(tx, p.email, role as never)));
  const me = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMe');
    return res.body as { category: string | null; staffId?: string };
  };
  const patchCategory = async (u: TestUser, category: string) => {
    const res = await ctx.http.patch('/api/v1/me').set(auth(u)).send({ category });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'updateMe');
    return res.body as { category: string | null };
  };
  const profile = async (viewer: TestUser, of: TestUser) => {
    const res = await ctx.http.get(`/api/v1/users/${of.username}`).set(auth(viewer));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body as { category: string | null; kabsoTeam?: true };
  };

  let owner: TestUser;
  let moderator: TestUser;
  let regular: TestUser;
  let viewer: TestUser;

  beforeAll(async () => {
    ctx = await createTestApp({ TRUST_PROXY: 'loopback' });
    owner = await signup();
    moderator = await signup();
    regular = await signup();
    viewer = await signup();
    // Each one chose «شاعر» while a regular account.
    for (const u of [owner, moderator, regular])
      expect((await patchCategory(u, 'POET')).category).toBe('POET');
    await grant(owner, 'OWNER');
    await grant(moderator, 'MODERATION');
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('a staff member and the founder: null on Me and on the profile, for themselves and for visitors', async () => {
    for (const u of [moderator, owner]) {
      expect((await me(u)).category).toBeNull();
      expect((await profile(viewer, u)).category).toBeNull();
      expect((await profile(u, u)).category).toBeNull();
    }
    // PATCH /me answers the same Me (the stored value changes; it is never shown while staff).
    expect((await patchCategory(moderator, 'SINGER')).category).toBeNull();
    expect((await profile(viewer, moderator)).kabsoTeam).toBe(true);
  });

  it('a regular account keeps its category exactly as before', async () => {
    expect((await me(regular)).category).toBe('POET');
    expect((await profile(viewer, regular)).category).toBe('POET');
    expect((await profile(moderator, regular)).category).toBe('POET');
  });

  it('the stored category is kept and shows again once the role is revoked', async () => {
    await revoke(moderator, 'MODERATION');
    expect((await me(moderator)).category).toBe('SINGER');
    expect((await profile(viewer, moderator)).category).toBe('SINGER');
  });
});
