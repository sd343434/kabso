/**
 * D357 follow-ups (owner 2026-11-10, contract v1.118-social, CONVENTIONS §10.47 / §10.105 / §10.153), end to end
 * against PostgreSQL + Redis:
 *
 *  - «ازيلها»: the app owner shows NO verification badge — `verification` is null on his /me, his public profile and
 *    in search; a stored OWNER row (an older server's) is never sent once removed;
 *  - «تحت البايو ضع اشارة السوشل ميديا…»: his social row comes from his profile links — up to 7 for him (3 for
 *    everyone else, `links` / `too_many`), `WHATSAPP` (wa.me, whatsapp.com, or a bare phone number → wa.me) and
 *    `SNAPCHAT` (snapchat.com) named by host, https only as every link.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
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
  readonly email: string;
  readonly token: string;
}

describe('D357 founder socials and no OWNER seal', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });

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
  const get = (u: TestUser, path: string) => ctx.http.get(`/api/v1${path}`).set(auth(u));
  const patchMe = (u: TestUser, body: object) => ctx.http.patch('/api/v1/me').set(auth(u)).send(body);
  const details = (res: { body: { error?: { details?: unknown } } }) => res.body.error?.details;

  let owner: TestUser;
  let alice: TestUser;

  beforeAll(async () => {
    ctx = await createTestApp({
      RATE_LIMIT_PROFILE_USER: '100000/900',
      RATE_LIMIT_AUTHENTICATED_USER: '100000/900',
    });
    owner = await signup();
    alice = await signup();
    await grant(owner, 'OWNER');
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('the app owner has no verification badge anywhere (owner: «ازيلها»)', async () => {
    const me = await get(owner, '/me');
    expectContract(me, 'getMe');
    expect(me.body.verification).toBeNull();
    const pub = await get(alice, `/users/${owner.username}`);
    expect(pub.status).toBe(200);
    expectContract(pub, 'getPublicProfile');
    expect(pub.body.kabsoOwner).toBe(true);
    expect(pub.body.verification ?? null).toBeNull();
    expect(await ctx.prisma.userVerificationBadge.findUnique({ where: { userId: owner.id } })).toBeNull();
    // Holding a staff role too gives him no STAFF seal either.
    await grant(owner, 'SUPPORT');
    expect((await get(owner, '/me')).body.verification).toBeNull();
    expect(JSON.stringify((await get(alice, `/users/${owner.username}`)).body)).not.toContain('"OWNER"');
  });

  it('his four socials (and his other links): up to 7, named by host; a phone number becomes wa.me', async () => {
    const links = [
      { url: 'https://www.instagram.com/kabso.test' },
      { url: 'https://www.facebook.com/kabso.test' },
      { url: '+966 50 123 4567' },
      { url: 'https://www.snapchat.com/add/kabso.test' },
      { url: 'https://example.com/press' },
      { url: 'https://www.tiktok.com/@kabso.test' },
      { url: 'https://x.com/kabso_test' },
    ];
    const res = await patchMe(owner, { links });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'updateMe');
    const pub = await get(alice, `/users/${owner.username}`);
    expectContract(pub, 'getPublicProfile');
    expect(
      (pub.body.links as { url: string; platform: string }[]).map(({ url, platform }) => [url, platform]),
    ).toEqual([
      ['https://www.instagram.com/kabso.test', 'INSTAGRAM'],
      ['https://www.facebook.com/kabso.test', 'FACEBOOK'],
      ['https://wa.me/966501234567', 'WHATSAPP'],
      ['https://www.snapchat.com/add/kabso.test', 'SNAPCHAT'],
      ['https://example.com/press', 'OTHER'],
      ['https://www.tiktok.com/@kabso.test', 'TIKTOK'],
      ['https://x.com/kabso_test', 'X'],
    ]);
    // An empty set hides the row: no links at all.
    expect((await patchMe(owner, { links: [] })).body.links).toEqual([]);
    expect((await get(alice, `/users/${owner.username}`)).body.links).toEqual([]);
  });

  it('refuses an 8th link for him, a 4th for anyone else, and non-https or national-number socials', async () => {
    const eight = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'].map((h) => ({ url: `https://${h}.example` }));
    const tooMany = await patchMe(owner, { links: eight });
    expect([tooMany.status, details(tooMany)]).toEqual([400, [{ field: 'links', issue: 'too_many' }]]);
    const four = eight.slice(0, 4);
    const notOwner = await patchMe(alice, { links: four });
    expect([notOwner.status, details(notOwner)]).toEqual([400, [{ field: 'links', issue: 'too_many' }]]);
    expect((await patchMe(alice, { links: four.slice(0, 3) })).status).toBe(200);
    // A regular user may also use the new platforms and the phone form (within 3).
    const wa = await patchMe(alice, {
      links: [{ url: '00966501234567' }, { url: 'https://snapchat.com/add/x' }],
    });
    expect(wa.status, JSON.stringify(wa.body)).toBe(200);
    expect((wa.body.links as { platform: string }[]).map((l) => l.platform)).toEqual([
      'WHATSAPP',
      'SNAPCHAT',
    ]);
    for (const url of ['http://instagram.com/kabso', 'snapchat.com/add/kabso', '0501234567', 'wa.me/1234']) {
      const res = await patchMe(owner, { links: [{ url }] });
      expect([url, res.status, details(res)]).toEqual([
        url,
        400,
        [{ field: 'links.0.url', issue: 'invalid_format' }],
      ]);
    }
  });
});
