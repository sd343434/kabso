/**
 * D307 (owner 2026-11-08, contract v1.98-social, CONVENTIONS §10.112.11): the founder's bilingual bio, end to end
 * against PostgreSQL + Redis:
 *
 *  - `setOwnerBio` (`PUT /owner/bio`): owner only (403 `OWNER_ONLY`, nothing stored), either language or both, a
 *    language left out is kept, null or empty clears it, the ordinary bio's limits (300 code points, 4 line breaks);
 *  - the read: `PublicProfile.ownerBio` and `Me.ownerBio` only for the owner and only with a language; never on
 *    anyone else's profile; a revoked owner's text stays stored but is no longer shown;
 *  - the audit `owner.bio.update` names the languages, never the text, and is written only on a change.
 */
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { grantRoleIn, revokeRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly token: string;
}

describe('D307 contract coverage', () => {
  it('openapi v1.98-social declares setOwnerBio', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(expect.arrayContaining(['setOwnerBio PUT /api/v1/owner/bio']));
  });
});

describe('D307 the founder bilingual bio', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const codeOf = (res: request.Response) => (res.body as { error?: { code?: string } }).error?.code;
  const issueOf = (res: request.Response) =>
    (res.body as { error: { details?: { field: string; issue: string }[] } }).error.details?.[0];

  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).trim().toLowerCase(),
      token: res.body.tokens.accessToken as string,
    };
  };
  const grant = (u: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, u.email, role as never)));
  const revoke = (u: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => revokeRoleIn(tx, u.email, role as never)));
  const get = (u: TestUser, path: string) => ctx.http.get(`/api/v1${path}`).set(auth(u));
  const putBio = (u: TestUser, body: unknown) =>
    ctx.http
      .put('/api/v1/owner/bio')
      .set(auth(u))
      .send(body as object);
  const audits = () =>
    ctx.prisma.auditLog.findMany({
      where: { action: 'owner.bio.update' },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    });

  let owner: TestUser;
  /** A second OWNER, so the first can be revoked (the last OWNER cannot be). */
  let owner2: TestUser;
  let alice: TestUser;
  let moderator: TestUser;

  beforeAll(async () => {
    ctx = await createTestApp({
      RATE_LIMIT_PROFILE_USER: '100000/900',
      RATE_LIMIT_AUTHENTICATED_USER: '100000/900',
    });
    owner = await signup();
    owner2 = await signup();
    alice = await signup();
    moderator = await signup();
    await grant(owner, 'OWNER');
    await grant(owner2, 'OWNER');
    await grant(moderator, 'MODERATION');
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('refuses a plain user and a staff member with 403 OWNER_ONLY, nothing stored', async () => {
    for (const u of [alice, moderator]) {
      for (const body of [{ ar: 'بايو' }, { en: 'Bio' }, {}, { ar: 'x'.repeat(400) }]) {
        const res = await putBio(u, body);
        expect(res.status, JSON.stringify(res.body)).toBe(403);
        expect(codeOf(res)).toBe('OWNER_ONLY');
      }
    }
    expectContract(await putBio(alice, { ar: 'بايو' }), 'setOwnerBio');
    expect(await ctx.prisma.ownerBio.count()).toBe(0);
    expect(await audits()).toHaveLength(0);
  });

  it('before any text: no ownerBio on the profile or on Me', async () => {
    const prof = await get(alice, `/users/${owner.username}`);
    expectContract(prof, 'getPublicProfile');
    expect(prof.body.kabsoOwner).toBe(true);
    expect(prof.body.ownerBio).toBeUndefined();
    const me = await get(owner, '/me');
    expectContract(me, 'getMe');
    expect(me.body.ownerBio).toBeUndefined();
  });

  it('writes Arabic, then English (Arabic kept), trims, clears with null or empty; read on the profile and Me', async () => {
    const ar = 'مؤسس Kabso Live. اقتراحاتكم تصلني مباشرة.';
    const first = await putBio(owner, { ar: `  ${ar}  ` });
    expect(first.status, JSON.stringify(first.body)).toBe(200);
    expectContract(first, 'setOwnerBio');
    expect(first.body).toEqual({ ar });

    const en = 'Founder of Kabso Live. Your ideas reach me directly.';
    const second = await putBio(owner, { en });
    expect(second.status).toBe(200);
    expect(second.body).toEqual({ ar, en });

    for (const viewer of [alice, moderator]) {
      const prof = await get(viewer, `/users/${owner.username}`);
      expect(prof.status).toBe(200);
      expectContract(prof, 'getPublicProfile');
      // Both languages always: the app picks by its own language.
      expect(prof.body.ownerBio).toEqual({ ar, en });
    }
    const me = await get(owner, '/me');
    expectContract(me, 'getMe');
    expect(me.body.ownerBio).toEqual({ ar, en });
    // The ordinary bio is untouched.
    expect(me.body.bio ?? null).toBeNull();

    // Never on anyone else's profile, nor their Me.
    expect((await get(owner, `/users/${alice.username}`)).body.ownerBio).toBeUndefined();
    expect((await get(alice, '/me')).body.ownerBio).toBeUndefined();

    // The same text again changes nothing (no audit).
    const before = (await audits()).length;
    expect((await putBio(owner, { ar, en })).status).toBe(200);
    expect(await audits()).toHaveLength(before);

    const cleared = await putBio(owner, { ar: null });
    expect(cleared.status).toBe(200);
    expect(cleared.body).toEqual({ en });
    const emptied = await putBio(owner, { en: '   ' });
    expect(emptied.status).toBe(200);
    expect(emptied.body).toEqual({});
    expect((await get(alice, `/users/${owner.username}`)).body.ownerBio).toBeUndefined();

    const rows = await audits();
    expect(rows.map((r) => r.metadata)).toEqual([
      { langs: ['ar'] },
      { langs: ['en'] },
      { langs: ['ar'] },
      { langs: ['en'] },
    ]);
    for (const r of rows) {
      expect(r.actorUserId).toBe(owner.id);
      expect(JSON.stringify(r.metadata)).not.toContain('Kabso');
    }
  });

  it('validates like the ordinary bio: 300 code points, 4 line breaks, at least one language, no other field', async () => {
    const long = await putBio(owner, { ar: 'ب'.repeat(301) });
    expect(long.status).toBe(400);
    expect(issueOf(long)?.field).toBe('ar');
    const longEn = await putBio(owner, { en: 'e'.repeat(301) });
    expect(longEn.status).toBe(400);
    expect(issueOf(longEn)?.field).toBe('en');
    const lines = await putBio(owner, { en: 'a\nb\nc\nd\ne\nf' });
    expect(lines.status).toBe(400);
    expect(issueOf(lines)?.field).toBe('en');
    expect((await putBio(owner, {})).status).toBe(400);
    expect((await putBio(owner, { de: 'Hallo' })).status).toBe(400);
    expect((await putBio(owner, { ar: 5 })).status).toBe(400);
    // Exactly at the limits: accepted (300 code points; an emoji is one code point).
    const max = '😀'.repeat(300);
    const ok = await putBio(owner, { ar: max, en: 'a\nb\nc\nd\ne' });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expect(ok.body).toEqual({ ar: max, en: 'a\nb\nc\nd\ne' });
    const stored = await ctx.prisma.ownerBio.findUniqueOrThrow({ where: { userId: owner.id } });
    expect(stored.bioAr).toBe(max);
  });

  it('revoking OWNER hides the text at once (kept stored) and refuses the write', async () => {
    await revoke(owner, 'OWNER');
    const prof = await get(alice, `/users/${owner.username}`);
    expect(prof.body.kabsoOwner).toBeUndefined();
    expect(prof.body.ownerBio).toBeUndefined();
    expect((await get(owner, '/me')).body.ownerBio).toBeUndefined();
    const res = await putBio(owner, { ar: 'لا' });
    expect(res.status).toBe(403);
    expect(codeOf(res)).toBe('OWNER_ONLY');
    expect(await ctx.prisma.ownerBio.count({ where: { userId: owner.id } })).toBe(1);
    await grant(owner, 'OWNER');
    expect((await get(alice, `/users/${owner.username}`)).body.ownerBio?.en).toBe('a\nb\nc\nd\ne');
  });
});
