/**
 * KL-080 / CP-019 (D107, owner 2026-10-26): the bag and profile cards (openapi v1.22-live DRAFT,
 * CONVENTIONS §10.22, §10.5, §4, §7), end to end against PostgreSQL + Redis with the API as the
 * DML-only runtime role.
 *
 * The catalogue is re-seeded from `BAG_CATALOGUE` (the test database is truncated per suite).
 * `bag-admin` runs as on the server: a child process with the migration role. The backfill for
 * accounts that existed before the bag is the migration's own statement, read from
 * `migration.sql` and run with the migration role.
 */
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { BAG_CATALOGUE } from '../src/modules/bag/bag.catalogue.js';
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

/** Runs `pnpm bag:admin …` as on the server (migration role, a child process). */
function bagAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'bag:admin', ...args], {
      cwd: fileURLToPath(new URL('..', import.meta.url)),
      env: process.env,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { status: 0, out };
  } catch (err) {
    const e = err as { status: number; stderr: string };
    return { status: e.status, out: e.stderr };
  }
}

/** The migration's backfill statement, exactly as deployed. */
const BACKFILL_SQL = (() => {
  const sql = readFileSync(
    new URL('../prisma/migrations/20261111090000_bag/migration.sql', import.meta.url),
    'utf8',
  );
  const match = /-- BEGIN bag-backfill\n([\s\S]*?)-- END bag-backfill/.exec(sql);
  if (!match?.[1]) throw new Error('backfill markers not found in the migration');
  return match[1].trim().replace(/;$/, '');
})();

describe('CP-019 contract coverage', () => {
  it('openapi v1.22-live declares the bag operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'listBagCatalogue GET /api/v1/bag/catalogue',
      'getMyBag GET /api/v1/me/bag',
      'setMyBagEquipped PUT /api/v1/me/bag/equipped',
    ]) {
      expect(ids).toContain(op);
    }
    // v1.48-social (D171) adds the fourth, `sendMyBagItem` (covered by d171-bag-v2).
    expect(operations().filter((o) => o.spec.tags && (o.spec.tags as string[]).includes('bag'))).toHaveLength(
      4,
    );
  });
});

describe('CP-019 the bag and profile cards', { timeout: 120_000 }, () => {
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).toLowerCase(),
      token: res.body.tokens.accessToken as string,
    };
  };
  const bag = async (u: TestUser, lang = 'en') => {
    const res = await ctx.http
      .get('/api/v1/me/bag')
      .query({ category: 'PROFILE_CARD' })
      .set(auth(u))
      .set('Accept-Language', lang);
    expect(res.status).toBe(200);
    expectContract(res, 'getMyBag');
    return res.body.data as {
      code: string;
      category: string;
      name: string;
      assetKey: string;
      acquiredAt: string;
      source: string;
      equipped: boolean;
    }[];
  };
  const worn = async (u: TestUser): Promise<string[]> =>
    (await bag(u)).filter((i) => i.equipped).map((i) => i.code);
  const equip = (u: TestUser, body: unknown) =>
    ctx.http
      .put('/api/v1/me/bag/equipped')
      .set(auth(u))
      .send(body as object);
  const profileCard = async (reader: TestUser, u: TestUser) => {
    const res = await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(reader));
    expect(res.status).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body.profileCard as { code: string; assetKey: string } | null;
  };

  beforeAll(async () => {
    ctx = await createTestApp();
    await ctx.prisma.bagItem.createMany({ data: BAG_CATALOGUE.map((i) => ({ ...i })) });
  });
  afterAll(async () => ctx?.close());

  it("the catalogue lists the four profile cards (then D169's 21 support frames), localized, and filters by category", async () => {
    const u = await signup();
    const en = await ctx.http.get('/api/v1/bag/catalogue').set(auth(u)).set('Accept-Language', 'en');
    expect(en.status).toBe(200);
    expectContract(en, 'listBagCatalogue');
    // v1.46-levels (D169): the 21 support tier frames follow, category AVATAR_FRAME.
    expect(en.body.data).toHaveLength(25);
    expect(
      (en.body.data as { category: string }[]).slice(4).every((i) => i.category === 'AVATAR_FRAME'),
    ).toBe(true);
    expect(en.body.data.slice(0, 4)).toEqual([
      {
        code: 'bunny_royal',
        category: 'PROFILE_CARD',
        name: 'Royal Bunny',
        assetKey: 'header_bunny_royal',
        sortOrder: 10,
        free: true,
      },
      {
        code: 'kabi_royal',
        category: 'PROFILE_CARD',
        name: 'Royal Kabi',
        assetKey: 'header_kabi_royal',
        sortOrder: 20,
        free: false,
      },
      {
        code: 'golden_stags',
        category: 'PROFILE_CARD',
        name: 'Golden Stags',
        assetKey: 'header_golden_stags',
        sortOrder: 30,
        free: false,
      },
      {
        code: 'emerald_wings',
        category: 'PROFILE_CARD',
        name: 'Emerald Wings',
        assetKey: 'header_emerald_wings',
        sortOrder: 40,
        free: false,
      },
    ]);
    const ar = await ctx.http
      .get('/api/v1/bag/catalogue?category=PROFILE_CARD')
      .set(auth(u))
      .set('Accept-Language', 'ar');
    expect(ar.status).toBe(200);
    expect((ar.body.data as { name: string }[]).map((i) => i.name)).toEqual([
      'الأرنب الملكي',
      'كابي الملكي',
      'الغزلان الذهبية',
      'الأجنحة الزمردية',
    ]);
    const bad = await ctx.http.get('/api/v1/bag/catalogue?category=HATS').set(auth(u));
    expect(bad.status).toBe(400);
    expectContract(bad, 'listBagCatalogue');
    expect(bad.body.error.details).toEqual([{ field: 'category', issue: 'invalid_value' }]);
    expect((await ctx.http.get('/api/v1/me/bag?category=HATS').set(auth(u))).status).toBe(400);
    expect((await ctx.http.get('/api/v1/bag/catalogue')).status).toBe(401);
    expect((await ctx.http.get('/api/v1/me/bag')).status).toBe(401);
  });

  it('a new account owns bunny_royal and wears it; its profile shows it', async () => {
    const u = await signup();
    const items = await bag(u);
    expect(items).toHaveLength(1);
    expect(items[0]).toMatchObject({
      code: 'bunny_royal',
      category: 'PROFILE_CARD',
      name: 'Royal Bunny',
      assetKey: 'header_bunny_royal',
      source: 'FREE_SIGNUP',
      equipped: true,
    });
    expect((await bag(u, 'ar'))[0]!.name).toBe('الأرنب الملكي');
    // Without a category: every category (only PROFILE_CARD today).
    const all = await ctx.http.get('/api/v1/me/bag').set(auth(u));
    expect(all.status).toBe(200);
    expect(all.body.data).toHaveLength(1);
    const reader = await signup();
    expect(await profileCard(reader, u)).toEqual({ code: 'bunny_royal', assetKey: 'header_bunny_royal' });
    expect(await profileCard(u, u)).toEqual({ code: 'bunny_royal', assetKey: 'header_bunny_royal' });
  });

  it('taking it off stays off: idempotent, never put back on (not by a grant either)', async () => {
    const u = await signup();
    const reader = await signup();
    const off = await equip(u, { category: 'PROFILE_CARD', code: null });
    expect(off.status).toBe(200);
    expectContract(off, 'setMyBagEquipped');
    expect(off.body).toEqual({ category: 'PROFILE_CARD', equipped: null });
    const again = await equip(u, { category: 'PROFILE_CARD', code: null });
    expect(again.status).toBe(200);
    expect(again.body).toEqual({ category: 'PROFILE_CARD', equipped: null });
    expect(await worn(u)).toEqual([]);
    expect((await bag(u)).map((i) => i.code)).toEqual(['bunny_royal']);
    expect(await profileCard(reader, u)).toBeNull();
    // Granting another item does not change what is worn (here: nothing).
    expect(bagAdmin('grant', u.email, 'golden_stags').status).toBe(0);
    expect(await worn(u)).toEqual([]);
    expect(await profileCard(reader, u)).toBeNull();
    // The user puts it back on themselves.
    const on = await equip(u, { category: 'PROFILE_CARD', code: 'bunny_royal' });
    expect(on.status).toBe(200);
    expect(on.body).toEqual({
      category: 'PROFILE_CARD',
      equipped: { code: 'bunny_royal', name: 'Royal Bunny', assetKey: 'header_bunny_royal' },
    });
    const same = await equip(u, { category: 'PROFILE_CARD', code: 'bunny_royal' });
    expect(same.status).toBe(200);
    expect(same.body).toEqual(on.body);
    expect(await worn(u)).toEqual(['bunny_royal']);
  });

  it('wearing an item one does not own (or that does not exist) → 409, nothing changes; bad bodies → 400', async () => {
    const u = await signup();
    for (const code of ['kabi_royal', 'no_such_item']) {
      const res = await equip(u, { category: 'PROFILE_CARD', code });
      expect(res.status).toBe(409);
      expectContract(res, 'setMyBagEquipped');
      expect(res.body.error.code).toBe('BAG_ITEM_NOT_OWNED');
    }
    expect(await worn(u)).toEqual(['bunny_royal']);
    const cases: [unknown, { field: string; issue: string }][] = [
      [{ category: 'PROFILE_CARD' }, { field: 'code', issue: 'required' }],
      // A missing enum reads as `invalid_value` (the shared zod pipe; §4).
      [{ code: 'bunny_royal' }, { field: 'category', issue: 'invalid_value' }],
      [
        { category: 'HATS', code: 'bunny_royal' },
        { field: 'category', issue: 'invalid_value' },
      ],
      [
        { category: 'PROFILE_CARD', code: '' },
        { field: 'code', issue: 'too_short' },
      ],
      [
        { category: 'PROFILE_CARD', code: 7 },
        { field: 'code', issue: 'invalid_type' },
      ],
      [
        { category: 'PROFILE_CARD', code: null, extra: 1 },
        { field: 'extra', issue: 'unknown_field' },
      ],
    ];
    for (const [body, detail] of cases) {
      const res = await equip(u, body);
      expect(res.status, JSON.stringify(body)).toBe(400);
      expectContract(res, 'setMyBagEquipped');
      expect(res.body.error.details, JSON.stringify(body)).toContainEqual(detail);
    }
    expect(
      (await ctx.http.put('/api/v1/me/bag/equipped').send({ category: 'PROFILE_CARD', code: null })).status,
    ).toBe(401);
    expect(await worn(u)).toEqual(['bunny_royal']);
  });

  it('bag-admin grants, lists and revokes (audited); a granted item can be worn and shows on the profile', async () => {
    const u = await signup();
    const reader = await signup();
    const granted = bagAdmin('grant', u.email, 'emerald_wings');
    expect(granted).toEqual({ status: 0, out: `${u.email}: +emerald_wings.\n` });
    // Granting does not change what is worn.
    expect(await worn(u)).toEqual(['bunny_royal']);
    const items = await bag(u);
    expect(items.map((i) => [i.code, i.source, i.equipped])).toEqual([
      ['bunny_royal', 'FREE_SIGNUP', true],
      ['emerald_wings', 'ADMIN', false],
    ]);
    expect(bagAdmin('grant', u.email, 'emerald_wings')).toEqual({
      status: 0,
      out: `${u.email} already owns emerald_wings; nothing changed.\n`,
    });

    const on = await equip(u, { category: 'PROFILE_CARD', code: 'emerald_wings' });
    expect(on.status).toBe(200);
    expect(on.body.equipped).toEqual({
      code: 'emerald_wings',
      name: 'Emerald Wings',
      assetKey: 'header_emerald_wings',
    });
    expect(await worn(u)).toEqual(['emerald_wings']);
    expect(await profileCard(reader, u)).toEqual({ code: 'emerald_wings', assetKey: 'header_emerald_wings' });

    const listed = bagAdmin('list', u.email);
    expect(listed.status).toBe(0);
    expect(listed.out).toMatch(
      /^ {2}PROFILE_CARD bunny_royal \(FREE_SIGNUP, .+\)\n\* PROFILE_CARD emerald_wings \(ADMIN, .+\)\n$/,
    );

    // Taking back the worn item: the user wears nothing (bunny_royal is not put back on).
    expect(bagAdmin('revoke', u.email, 'emerald_wings')).toEqual({
      status: 0,
      out: `${u.email}: -emerald_wings (was worn; now wears nothing there).\n`,
    });
    expect(await worn(u)).toEqual([]);
    expect(await profileCard(reader, u)).toBeNull();
    expect((await equip(u, { category: 'PROFILE_CARD', code: 'emerald_wings' })).status).toBe(409);

    const audits = await ctx.prisma.auditLog.findMany({
      where: { targetId: u.id, action: { in: ['bag.grant', 'bag.revoke'] } },
      orderBy: { createdAt: 'asc' },
    });
    expect(audits.map((a) => [a.action, a.metadata])).toEqual([
      ['bag.grant', { item: 'emerald_wings', category: 'PROFILE_CARD', via: 'cli' }],
      ['bag.revoke', { item: 'emerald_wings', wasEquipped: true, via: 'cli' }],
    ]);

    expect(bagAdmin('revoke', u.email, 'emerald_wings').status).toBe(1);
    expect(bagAdmin('grant', u.email, 'no_such_item').status).toBe(1);
    expect(bagAdmin('grant', 'nobody@example.com', 'kabi_royal').status).toBe(1);
    expect(bagAdmin('list').status).toBe(1);
    expect(bagAdmin('nope', u.email).status).toBe(1);
  });

  it('concurrent equips leave exactly one item worn', async () => {
    const u = await signup();
    for (const code of ['kabi_royal', 'golden_stags', 'emerald_wings']) {
      await ctx.prisma.userBagItem.create({
        data: { userId: u.id, itemCode: code, category: 'PROFILE_CARD', source: 'ADMIN' },
      });
    }
    const codes = ['bunny_royal', 'kabi_royal', 'golden_stags', 'emerald_wings', null];
    const results = await Promise.all(
      [...codes, ...codes].map((code) => equip(u, { category: 'PROFILE_CARD', code })),
    );
    for (const r of results) expect(r.status, JSON.stringify(r.body)).toBe(200);
    expect((await worn(u)).length).toBeLessThanOrEqual(1);
  });

  it('the migration backfill gives accounts made before the bag bunny_royal, worn, once', async () => {
    // Accounts created before the feature: no bag rows (made directly, not through signup).
    const make = async (name: string, deleted = false) =>
      ctx.prisma.user.create({
        data: {
          email: `${name}-${Date.now().toString(36)}@example.com`,
          passwordHash: 'x',
          ...(deleted ? { status: 'DELETED' as const, deletedAt: new Date() } : {}),
          profile: {
            create: { username: `${name}${Date.now().toString(36)}`, displayName: 'Old', locale: 'ar' },
          },
          settings: { create: {} },
        },
        include: { profile: true },
      });
    const old = await make('old');
    const gone = await make('gone', true);
    // Someone who took it off after signup is never dressed again by the backfill.
    const tookOff = await signup();
    expect((await equip(tookOff, { category: 'PROFILE_CARD', code: null })).status).toBe(200);
    expect(await ctx.prisma.userBagItem.count({ where: { userId: old.id } })).toBe(0);

    const first = await withMigrationClient((client) => client.$executeRawUnsafe(BACKFILL_SQL));
    expect(first).toBeGreaterThanOrEqual(1);
    const rows = await ctx.prisma.userBagItem.findMany({ where: { userId: old.id } });
    expect(rows.map((r) => [r.itemCode, r.source, r.equipped])).toEqual([['bunny_royal', 'BACKFILL', true]]);
    expect(await ctx.prisma.userBagItem.count({ where: { userId: gone.id } })).toBe(0);
    expect(await worn(tookOff)).toEqual([]);

    const reader = await signup();
    const res = await ctx.http.get(`/api/v1/users/${old.profile!.username}`).set(auth(reader));
    expect(res.status).toBe(200);
    expect(res.body.profileCard).toEqual({ code: 'bunny_royal', assetKey: 'header_bunny_royal' });

    // Idempotent: a second run gives nothing.
    expect(await withMigrationClient((client) => client.$executeRawUnsafe(BACKFILL_SQL))).toBe(0);
  });
});
