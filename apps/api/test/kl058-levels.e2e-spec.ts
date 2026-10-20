/**
 * KL-058: four independent level systems (openapi v1.4-levels DRAFT, CP-005), end to end against
 * PostgreSQL + Redis with the API running as the DML-only runtime role.
 *
 * No gifts/wallet/games module exists, so producers are simulated by calling
 * `LevelEventsService.ingest` directly — exactly what those modules will do — with a test
 * SourceTransactionVerifier that accepts only transactions the test has "committed". The
 * production verifier (UnavailableSourceVerifier) is checked separately: it refuses everything.
 * Every response of a levels operation is checked against openapi.yaml (`expectContract`).
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LevelEventsService } from '../src/modules/levels/level-events.service.js';
import type { LevelSourceEventInput } from '../src/modules/levels/level-qualification.js';
import {
  LEVEL_SOURCE_VERIFIER,
  UnavailableSourceVerifier,
  type SourceTransactionVerifier,
  type VerificationResult,
} from '../src/modules/levels/source-verifier.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly email: string;
  readonly username: string;
  readonly token: string;
}

type Code = 'ATTRACTIVENESS' | 'SUPPORT' | 'WIZARD' | 'GAMING';

/** Stands in for the gifts/games ledgers: only "committed" transactions verify. */
class CommittedSources implements SourceTransactionVerifier {
  readonly committed = new Set<string>();
  verify(event: LevelSourceEventInput): Promise<VerificationResult> {
    return Promise.resolve(
      this.committed.has(`${event.type}:${event.sourceTransactionId}`)
        ? { ok: true }
        : { ok: false, reason: 'not_committed' },
    );
  }
}

const SEED: readonly [Code, string, string][] = [
  ['ATTRACTIVENESS', 'مستوى الجاذبية', 'Attractiveness'],
  ['SUPPORT', 'مستوى الدعم', 'Support'],
  ['WIZARD', 'مستوى الساحر', 'Wizard'],
  ['GAMING', 'مستوى اللعب', 'Gaming'],
];

/** The migration seeds the categories; resetDatabase() truncates them, so tests seed them again. */
async function seedCategories(ctx: TestContext): Promise<void> {
  for (const [code, nameAr, nameEn] of SEED) {
    await ctx.prisma.levelCategory.create({
      data: { code, nameAr, nameEn, descriptionAr: `وصف ${nameAr}`, descriptionEn: `About ${nameEn}` },
    });
  }
}

async function signup(ctx: TestContext): Promise<TestUser> {
  const { res, payload } = await registerVerified(ctx);
  expect(res.status).toBe(201);
  return {
    id: res.body.user.id,
    email: String(payload.email).toLowerCase(),
    username: res.body.user.username,
    token: res.body.tokens.accessToken,
  };
}

/** `pnpm levels:admin …` as an operator would run it (migration role). */
function levelsAdmin(...args: string[]): string {
  return execFileSync('pnpm', ['-s', 'levels:admin', ...args], {
    cwd: fileURLToPath(new URL('..', import.meta.url)),
    env: process.env,
    encoding: 'utf8',
  });
}

const bearer = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });

function expectError(
  res: { status: number; body: { error?: { code?: string } } },
  status: number,
  code: string,
) {
  expect({ status: res.status, code: res.body.error?.code }).toEqual({ status, code });
}

const LADDER = [
  { levelNumber: 1, nameAr: 'مبتدئ', nameEn: 'Starter', requiredPoints: '0', iconKey: 'tier_01' },
  { levelNumber: 2, nameAr: 'برونزي', nameEn: 'Bronze', requiredPoints: '100', iconKey: 'tier_02' },
  { levelNumber: 3, nameAr: 'فضي', nameEn: 'Silver', requiredPoints: '500', iconKey: 'tier_03' },
  { levelNumber: 4, nameAr: 'ذهبي', nameEn: 'Gold', requiredPoints: '1000', iconKey: null },
];

describe('KL-058 contract coverage', () => {
  it('openapi v1.4-levels declares exactly the 25 operations implemented here', () => {
    const ops = operations()
      .filter((o) => /^\/api\/v1\/((admin\/)?levels\/|users\/\{username\}\/levels)/.test(o.path))
      .map((o) => o.operationId)
      .sort();
    expect(ops).toEqual(
      [
        'getMyLevels',
        'listMyLevelHistory',
        'listMyPointsHistory',
        'getMyLevel',
        'listAdminLevelCategories',
        'getAdminLevelCategory',
        'updateAdminLevelCategory',
        'listAdminLevelVersions',
        'createAdminLevelVersion',
        'getAdminLevelVersion',
        'replaceAdminLevelVersion',
        'validateAdminLevelVersion',
        'previewAdminLevelVersion',
        'publishAdminLevelVersion',
        'getAdminUserLevels',
        'recalculateAdminUserLevel',
        'createAdminLevelAdjustment',
        'listAdminLevelReconciliations',
        'startAdminLevelReconciliation',
        'getAdminLevelReconciliation',
        'listAdminLevelEvents',
        'retryAdminLevelEvent',
        'getAdminLevelReports',
        'listAdminLevelAuditLogs',
        'getUserLevels',
      ].sort(),
    );
  });
});

describe('KL-058 default verifier', () => {
  it('refuses every event, so nothing can be awarded from unverified data', async () => {
    const verifier: SourceTransactionVerifier = new UnavailableSourceVerifier();
    await expect(
      verifier.verify({
        type: 'GAME_SPEND_COMMITTED',
        sourceTransactionId: 'x',
        userId: randomUUID(),
        value: 10n,
      }),
    ).resolves.toEqual({ ok: false, reason: 'source_unavailable' });
  });
});

describe('KL-058 levels', () => {
  const sources = new CommittedSources();
  let ctx: TestContext;
  let events: LevelEventsService;
  let admin: TestUser;
  let alice: TestUser;
  let bob: TestUser;

  /** Commits a source transaction (as the producer would) and delivers its event. */
  const deliver = async (event: LevelSourceEventInput) => {
    sources.committed.add(`${event.type}:${event.sourceTransactionId}`);
    return events.ingest(event);
  };
  const gift = (from: TestUser, to: TestUser, value: bigint, lucky = false, id = randomUUID()) =>
    deliver({
      type: 'GIFT_COMMITTED',
      sourceTransactionId: id,
      senderUserId: from.id,
      recipientUserId: to.id,
      value,
      lucky,
    });

  const points = async (user: TestUser): Promise<Record<Code, { points: string; level: number | null }>> => {
    const res = await ctx.http.get('/api/v1/levels/me').set(bearer(user));
    expect(res.status).toBe(200);
    expectContract(res, 'getMyLevels');
    return Object.fromEntries(
      (res.body.data as { category: Code; points: string; level: { levelNumber: number } | null }[]).map(
        (s) => [s.category, { points: s.points, level: s.level?.levelNumber ?? null }],
      ),
    ) as Record<Code, { points: string; level: number | null }>;
  };

  const adminCall = (method: 'get' | 'post' | 'put' | 'patch', path: string) =>
    ctx.http[method](`/api/v1/admin/levels${path}`).set(bearer(admin));

  /** Creates, fills and publishes a version; returns its id. */
  const publish = async (
    category: Code,
    settings: Partial<{ multiplier: string; reversalPolicy: string; luckyGiftsCountAsSupport: boolean }> = {},
    recalculation = 'PRESERVE_POINTS',
  ): Promise<string> => {
    const created = await adminCall('post', `/categories/${category.toLowerCase()}/versions`).send({});
    expect(created.status).toBe(201);
    expectContract(created, 'createAdminLevelVersion');
    const id = created.body.id as string;
    const put = await adminCall('put', `/versions/${id}`).send({
      multiplier: settings.multiplier ?? '1',
      valueUnit: 'COIN',
      reversalPolicy: settings.reversalPolicy ?? 'REVERSE_POINTS',
      luckyGiftsCountAsSupport: settings.luckyGiftsCountAsSupport ?? false,
      levels: LADDER,
    });
    expect(put.status).toBe(200);
    expectContract(put, 'replaceAdminLevelVersion');
    const pub = await adminCall('post', `/versions/${id}/publish`).send({ recalculation });
    expect(pub.status).toBe(200);
    expectContract(pub, 'publishAdminLevelVersion');
    expect(pub.body.status).toBe('PUBLISHED');
    return id;
  };

  beforeAll(async () => {
    ctx = await createTestApp({}, [{ token: LEVEL_SOURCE_VERIFIER, value: sources }]);
    ctx.app.getHttpServer().setMaxListeners(64);
    events = ctx.app.get(LevelEventsService);
    await seedCategories(ctx);
    [admin, alice, bob] = [await signup(ctx), await signup(ctx), await signup(ctx)];
    await ctx.prisma.user.update({ where: { id: admin.id }, data: { role: 'ADMIN' } });
    levelsAdmin('grant', admin.email, 'ALL');
  });

  afterAll(async () => {
    await ctx?.close();
  });

  describe('access', () => {
    it('needs a token everywhere and role ADMIN for admin routes', async () => {
      expectError(await ctx.http.get('/api/v1/levels/me'), 401, 'AUTH_UNAUTHENTICATED');
      expectError(await ctx.http.get('/api/v1/admin/levels/categories'), 401, 'AUTH_UNAUTHENTICATED');
      for (const [method, path] of [
        ['get', '/categories'],
        ['patch', '/categories/support'],
        ['post', '/categories/support/versions'],
        ['post', `/users/${alice.id}/adjustments`],
        ['post', '/reconciliation'],
        ['get', '/audit-logs'],
      ] as const) {
        const res = await ctx.http[method](`/api/v1/admin/levels${path}`).set(bearer(alice)).send({});
        expectError(res, 403, 'AUTH_FORBIDDEN');
      }
    });

    it('each admin route needs its own permission (CP-005 §9.8)', async () => {
      const viewer = await signup(ctx);
      await ctx.prisma.user.update({ where: { id: viewer.id }, data: { role: 'ADMIN' } });
      const as = (u: TestUser, method: 'get' | 'post' | 'patch', path: string) =>
        ctx.http[method](`/api/v1/admin/levels${path}`).set(bearer(u)).send({});
      // Role ADMIN alone is not enough.
      expectError(await as(viewer, 'get', '/categories'), 403, 'AUTH_FORBIDDEN');
      levelsAdmin('grant', viewer.email, 'LEVELS_VIEW');
      expect(levelsAdmin('list', viewer.email).trim()).toBe('LEVELS_VIEW');
      expect((await as(viewer, 'get', '/categories')).status).toBe(200);
      expect((await as(viewer, 'get', '/reports')).status).toBe(200);
      expectError(await as(viewer, 'post', '/categories/support/versions'), 403, 'AUTH_FORBIDDEN');
      expectError(await as(viewer, 'post', `/users/${alice.id}/adjustments`), 403, 'AUTH_FORBIDDEN');
      expectError(await as(viewer, 'post', '/reconciliation'), 403, 'AUTH_FORBIDDEN');
      levelsAdmin('grant', viewer.email, 'LEVELS_EDIT');
      // Editing names is EDIT; switching a category on or off is PUBLISH.
      const rename = await ctx.http
        .patch('/api/v1/admin/levels/categories/support')
        .set(bearer(viewer))
        .send({ nameEn: 'Support' });
      expect(rename.status).toBe(200);
      const enable = await ctx.http
        .patch('/api/v1/admin/levels/categories/support')
        .set(bearer(viewer))
        .send({ enabled: false });
      expectError(enable, 403, 'AUTH_FORBIDDEN');
      // Revoking applies at once; demotion too.
      levelsAdmin('revoke', viewer.email, 'ALL');
      expectError(await as(viewer, 'get', '/categories'), 403, 'AUTH_FORBIDDEN');
      levelsAdmin('grant', viewer.email, 'LEVELS_VIEW');
      await ctx.prisma.user.update({ where: { id: viewer.id }, data: { role: 'USER' } });
      expectError(await as(viewer, 'get', '/categories'), 403, 'AUTH_FORBIDDEN');
      // The CLI refuses non-admins; the API's runtime role cannot grant.
      expect(() => levelsAdmin('grant', alice.email, 'ALL')).toThrow();
      await expect(
        ctx.prisma.userAdminPermission.create({ data: { userId: alice.id, permission: 'LEVELS_PUBLISH' } }),
      ).rejects.toThrow();
      const log = await ctx.http.get('/api/v1/admin/levels/audit-logs?limit=50').set(bearer(admin));
      expect(log.body.data.map((l: { action: string }) => l.action)).toEqual(
        expect.arrayContaining(['levels.permission.grant', 'levels.permission.revoke']),
      );
    });

    it('has no endpoint that lets a client submit points, levels or events', async () => {
      for (const path of ['/api/v1/levels/me', '/api/v1/levels/me/support', '/api/v1/levels/events']) {
        const res = await ctx.http.post(path).set(bearer(alice)).send({ points: '999999' });
        expect(res.status).toBe(404);
      }
    });
  });

  describe('before configuration', () => {
    it('lists four UNAVAILABLE categories in order, localized', async () => {
      const res = await ctx.http.get('/api/v1/levels/me').set(bearer(alice)).set('Accept-Language', 'ar');
      expect(res.status).toBe(200);
      expectContract(res, 'getMyLevels');
      expect(res.body.data.map((s: { category: string }) => s.category)).toEqual([
        'ATTRACTIVENESS',
        'SUPPORT',
        'WIZARD',
        'GAMING',
      ]);
      expect(res.body.data[1]).toMatchObject({
        status: 'UNAVAILABLE',
        name: 'مستوى الدعم',
        points: '0',
        level: null,
      });
    });

    it('ignores activity for unavailable categories (recorded as SKIPPED, no points)', async () => {
      const result = await gift(alice, bob, 500n);
      expect(result.event.status).toBe('SKIPPED');
      expect((await points(bob)).ATTRACTIVENESS.points).toBe('0');
    });

    it('cannot enable a category with no published version', async () => {
      const res = await adminCall('patch', '/categories/support').send({ enabled: true });
      expectError(res, 422, 'LEVEL_CONFIG_INVALID');
    });
  });

  describe('configuration', () => {
    it('validates drafts and refuses to publish an invalid one', async () => {
      const created = await adminCall('post', '/categories/attractiveness/versions').send({});
      expect(created.status).toBe(201);
      const id = created.body.id as string;
      const bad = await adminCall('put', `/versions/${id}`).send({
        multiplier: '1',
        valueUnit: 'COIN',
        reversalPolicy: 'REVERSE_POINTS',
        luckyGiftsCountAsSupport: true,
        levels: [
          { levelNumber: 1, nameAr: 'أ', nameEn: 'A', requiredPoints: '10', iconKey: null },
          { levelNumber: 3, nameAr: 'ب', nameEn: 'B', requiredPoints: '5', iconKey: null },
        ],
      });
      expect(bad.status).toBe(200);
      const check = await adminCall('post', `/versions/${id}/validate`).send();
      expect(check.status).toBe(200);
      expectContract(check, 'validateAdminLevelVersion');
      expect(check.body.valid).toBe(false);
      const issues = check.body.issues.map((i: { issue: string }) => i.issue);
      expect(issues).toEqual(expect.arrayContaining(['must_be_zero', 'not_sequential', 'not_applicable']));
      expectError(
        await adminCall('post', `/versions/${id}/publish`).send({ recalculation: 'PRESERVE_POINTS' }),
        422,
        'LEVEL_CONFIG_INVALID',
      );
      expectError(await adminCall('get', `/versions/${id}/preview`), 422, 'LEVEL_CONFIG_INVALID');
    });

    it('rejects malformed input with VALIDATION_FAILED', async () => {
      const created = await adminCall('post', '/categories/attractiveness/versions').send({});
      const id = created.body.id as string;
      for (const body of [
        { multiplier: '1.1234567', valueUnit: 'COIN', reversalPolicy: 'REVERSE_POINTS', levels: [] },
        { multiplier: '-1', valueUnit: 'COIN', reversalPolicy: 'REVERSE_POINTS', levels: [] },
        { multiplier: '1', valueUnit: 'USD', reversalPolicy: 'REVERSE_POINTS', levels: [] },
        { multiplier: '1', valueUnit: 'COIN', reversalPolicy: 'REVERSE_POINTS', levels: [], extra: 1 },
      ]) {
        expectError(await adminCall('put', `/versions/${id}`).send(body), 400, 'VALIDATION_FAILED');
      }
    });

    it('publishes the four categories and enables them', async () => {
      await publish('ATTRACTIVENESS');
      await publish('SUPPORT');
      await publish('WIZARD');
      await publish('GAMING', { multiplier: '0.5' });
      for (const slug of ['attractiveness', 'support', 'wizard', 'gaming']) {
        const res = await adminCall('patch', `/categories/${slug}`).send({ enabled: true });
        expect(res.status).toBe(200);
        expectContract(res, 'updateAdminLevelCategory');
        expect(res.body.enabled).toBe(true);
      }
      const list = await adminCall('get', '/categories');
      expect(list.status).toBe(200);
      expectContract(list, 'listAdminLevelCategories');
      expect(
        list.body.data.map((c: { published: { multiplier: string } }) => c.published.multiplier),
      ).toEqual(['1', '1', '1', '0.5']);
    });

    it('never edits a published version', async () => {
      const versions = await adminCall('get', '/categories/support/versions');
      expect(versions.status).toBe(200);
      expectContract(versions, 'listAdminLevelVersions');
      const published = versions.body.data.find((v: { status: string }) => v.status === 'PUBLISHED');
      const put = await adminCall('put', `/versions/${published.id}`).send({
        multiplier: '9',
        valueUnit: 'COIN',
        reversalPolicy: 'REVERSE_POINTS',
        levels: LADDER,
      });
      expectError(put, 409, 'LEVEL_VERSION_NOT_DRAFT');
      const get = await adminCall('get', `/versions/${published.id}`);
      expectContract(get, 'getAdminLevelVersion');
      expect(get.body.multiplier).toBe('1');
      expectError(await adminCall('get', '/versions/not-a-uuid'), 404, 'NOT_FOUND');
      expectError(await adminCall('get', `/versions/${randomUUID()}`), 404, 'NOT_FOUND');
    });
  });

  describe('activity mapping (CP-005 §5)', () => {
    it('normal gift: recipient Attractiveness, sender Support; nothing else', async () => {
      const [a0, b0] = [await points(alice), await points(bob)];
      const result = await gift(alice, bob, 150n);
      expect(result.event.status).toBe('PROCESSED');
      const [a1, b1] = [await points(alice), await points(bob)];
      expect(BigInt(b1.ATTRACTIVENESS.points) - BigInt(b0.ATTRACTIVENESS.points)).toBe(150n);
      expect(BigInt(a1.SUPPORT.points) - BigInt(a0.SUPPORT.points)).toBe(150n);
      expect(a1.ATTRACTIVENESS).toEqual(a0.ATTRACTIVENESS);
      expect(b1.SUPPORT).toEqual(b0.SUPPORT);
      expect(a1.WIZARD).toEqual(a0.WIZARD);
      expect(a1.GAMING).toEqual(a0.GAMING);
      expect(a1.SUPPORT.level).toBe(2);
    });

    it('lucky gift: recipient Attractiveness, sender Wizard; Support only when the policy says so', async () => {
      const [a0, b0] = [await points(alice), await points(bob)];
      await gift(alice, bob, 200n, true);
      const [a1, b1] = [await points(alice), await points(bob)];
      expect(BigInt(b1.ATTRACTIVENESS.points) - BigInt(b0.ATTRACTIVENESS.points)).toBe(200n);
      expect(BigInt(a1.WIZARD.points) - BigInt(a0.WIZARD.points)).toBe(200n);
      expect(a1.SUPPORT).toEqual(a0.SUPPORT);

      await publish('SUPPORT', { luckyGiftsCountAsSupport: true });
      await gift(alice, bob, 40n, true);
      const a2 = await points(alice);
      expect(BigInt(a2.SUPPORT.points) - BigInt(a1.SUPPORT.points)).toBe(40n);
      expect(BigInt(a2.WIZARD.points) - BigInt(a1.WIZARD.points)).toBe(40n);
      await publish('SUPPORT');
    });

    it('game spend: Gaming only, floor(value × 0.5)', async () => {
      const a0 = await points(alice);
      await deliver({
        type: 'GAME_SPEND_COMMITTED',
        sourceTransactionId: randomUUID(),
        userId: alice.id,
        value: 301n,
      });
      const a1 = await points(alice);
      expect(BigInt(a1.GAMING.points) - BigInt(a0.GAMING.points)).toBe(150n);
      expect({ ...a1, GAMING: null }).toEqual({ ...a0, GAMING: null });
    });

    it('a value that rounds to zero and a gift to oneself earn nothing', async () => {
      const small = await deliver({
        type: 'GAME_SPEND_COMMITTED',
        sourceTransactionId: randomUUID(),
        userId: bob.id,
        value: 1n,
      });
      expect(small.event.status).toBe('SKIPPED');
      const before = await points(alice);
      const self = await gift(alice, alice, 1000n);
      expect(self.event.status).toBe('SKIPPED');
      expect(self.event.lastError).toContain('self_gift');
      expect(await points(alice)).toEqual(before);
    });

    it('an unverified transaction earns nothing until it verifies, then a retry credits it once', async () => {
      const before = await points(bob);
      const id = randomUUID();
      const event = {
        type: 'GIFT_COMMITTED',
        sourceTransactionId: id,
        senderUserId: alice.id,
        recipientUserId: bob.id,
        value: 70n,
        lucky: false,
      } as const;
      const first = await events.ingest(event);
      expect(first.event.status).toBe('FAILED');
      expect(await points(bob)).toEqual(before);

      const failed = await adminCall('get', '/events?status=FAILED');
      expect(failed.status).toBe(200);
      expectContract(failed, 'listAdminLevelEvents');
      expect(failed.body.data.some((e: { id: string }) => e.id === first.event.id)).toBe(true);

      sources.committed.add(`GIFT_COMMITTED:${id}`);
      const retry = await adminCall('post', `/events/${first.event.id}/retry`).send();
      expect(retry.status).toBe(200);
      expectContract(retry, 'retryAdminLevelEvent');
      expect(retry.body.status).toBe('PROCESSED');
      const again = await adminCall('post', `/events/${first.event.id}/retry`).send();
      expect(again.body.status).toBe('PROCESSED');
      expect(BigInt((await points(bob)).ATTRACTIVENESS.points) - BigInt(before.ATTRACTIVENESS.points)).toBe(
        70n,
      );
    });
  });

  describe('idempotency and concurrency', () => {
    it('a redelivered event is a duplicate and credits nothing', async () => {
      const id = randomUUID();
      await gift(alice, bob, 30n, false, id);
      const before = await points(bob);
      const again = await gift(alice, bob, 30n, false, id);
      expect(again.duplicate).toBe(true);
      expect(await points(bob)).toEqual(before);
    });

    it('twelve parallel deliveries of one event credit it exactly once', async () => {
      const before = await points(bob);
      const id = randomUUID();
      sources.committed.add(`GIFT_COMMITTED:${id}`);
      const event = {
        type: 'GIFT_COMMITTED',
        sourceTransactionId: id,
        senderUserId: alice.id,
        recipientUserId: bob.id,
        value: 25n,
        lucky: false,
      } as const;
      await Promise.all(Array.from({ length: 12 }, () => events.ingest(event)));
      expect(BigInt((await points(bob)).ATTRACTIVENESS.points) - BigInt(before.ATTRACTIVENESS.points)).toBe(
        25n,
      );
      const entries = await ctx.prisma.pointsLedgerEntry.count({ where: { sourceTransactionId: id } });
      expect(entries).toBe(2);
    });

    it('parallel distinct events for one user all count (no lost update)', async () => {
      const before = await points(bob);
      await Promise.all(Array.from({ length: 10 }, () => gift(alice, bob, 11n)));
      expect(BigInt((await points(bob)).ATTRACTIVENESS.points) - BigInt(before.ATTRACTIVENESS.points)).toBe(
        110n,
      );
    });
  });

  describe('reversals', () => {
    it('REVERSE_POINTS takes back exactly what the gift earned, once', async () => {
      const id = randomUUID();
      const [a0, b0] = [await points(alice), await points(bob)];
      await gift(alice, bob, 120n, false, id);
      const reversed = await deliver({ type: 'GIFT_REVERSED', sourceTransactionId: id });
      expect(reversed.event.status).toBe('PROCESSED');
      expect(await points(alice)).toEqual(a0);
      expect(await points(bob)).toEqual(b0);
      const again = await deliver({ type: 'GIFT_REVERSED', sourceTransactionId: id });
      expect(again.duplicate).toBe(true);
      expect(await points(bob)).toEqual(b0);
    });

    it('a reversal of an unknown transaction fails (retryable) and changes nothing', async () => {
      const result = await deliver({ type: 'GAME_SPEND_REVERSED', sourceTransactionId: randomUUID() });
      expect(result.event.status).toBe('FAILED');
      expect(result.event.lastError).toContain('original_not_found');
    });

    it('KEEP_LEVEL subtracts points but never lowers the shown level', async () => {
      const carol = await signup(ctx);
      await publish('WIZARD', { reversalPolicy: 'KEEP_LEVEL' });
      const id = randomUUID();
      await gift(alice, carol, 50n, true);
      await gift(carol, bob, 600n, true, id);
      expect((await points(carol)).WIZARD).toEqual({ points: '600', level: 3 });
      await deliver({ type: 'GIFT_REVERSED', sourceTransactionId: id });
      expect((await points(carol)).WIZARD).toEqual({ points: '0', level: 3 });
      await publish('WIZARD');
    });
  });

  describe('user endpoints', () => {
    it('detail shows the ladder and progress; unknown category is 404', async () => {
      const res = await ctx.http
        .get('/api/v1/levels/me/support')
        .set(bearer(alice))
        .set('Accept-Language', 'en');
      expect(res.status).toBe(200);
      expectContract(res, 'getMyLevel');
      expect(res.body.levels.map((l: { name: string }) => l.name)).toEqual([
        'Starter',
        'Bronze',
        'Silver',
        'Gold',
      ]);
      expect(res.body.status).toBe('AVAILABLE');
      expectError(await ctx.http.get('/api/v1/levels/me/SUPPORT').set(bearer(alice)), 404, 'NOT_FOUND');
      expectError(await ctx.http.get('/api/v1/levels/me/charm').set(bearer(alice)), 404, 'NOT_FOUND');
    });

    it('points history pages with signed cursors and public fields only', async () => {
      const first = await ctx.http
        .get('/api/v1/levels/me/points-history?category=attractiveness&limit=2')
        .set(bearer(bob));
      expect(first.status).toBe(200);
      expectContract(first, 'listMyPointsHistory');
      expect(first.body.data).toHaveLength(2);
      expect(first.body.page.hasMore).toBe(true);
      expect(first.body.data[0]).not.toHaveProperty('sourceTransactionId');
      const second = await ctx.http
        .get(
          `/api/v1/levels/me/points-history?category=attractiveness&limit=2&cursor=${first.body.page.nextCursor}`,
        )
        .set(bearer(bob));
      expect(second.status).toBe(200);
      expectContract(second, 'listMyPointsHistory');
      const ids = new Set([...first.body.data, ...second.body.data].map((e: { id: string }) => e.id));
      expect(ids.size).toBe(4);
      // A cursor is bound to its list and caller.
      const foreign = await ctx.http
        .get(`/api/v1/levels/me/points-history?limit=2&cursor=${first.body.page.nextCursor}`)
        .set(bearer(bob));
      expectError(foreign, 400, 'VALIDATION_FAILED');
      expectError(
        await ctx.http
          .get(`/api/v1/levels/me/points-history?cursor=${first.body.page.nextCursor}`)
          .set(bearer(alice)),
        400,
        'VALIDATION_FAILED',
      );
      expectError(
        await ctx.http.get('/api/v1/levels/me/points-history?category=charm').set(bearer(bob)),
        400,
        'VALIDATION_FAILED',
      );
    });

    it('level history lists transitions', async () => {
      const res = await ctx.http.get('/api/v1/levels/me/history?category=support').set(bearer(alice));
      expect(res.status).toBe(200);
      expectContract(res, 'listMyLevelHistory');
      expect(res.body.data.length).toBeGreaterThan(0);
      expect(res.body.data.every((t: { category: string }) => t.category === 'SUPPORT')).toBe(true);
    });
  });

  describe('admin users', () => {
    it('shows a user’s four states with ledger detail', async () => {
      const res = await adminCall('get', `/users/${bob.id}`);
      expect(res.status).toBe(200);
      expectContract(res, 'getAdminUserLevels');
      expect(res.body.data[0].recentEntries[0]).toHaveProperty('sourceTransactionId');
      expectError(await adminCall('get', `/users/${randomUUID()}`), 404, 'NOT_FOUND');
    });

    it('manual adjustments: reason and key required, replayed, conflicts, never below zero, audited', async () => {
      const path = `/users/${bob.id}/adjustments`;
      const body = { category: 'GAMING', pointsDelta: '1000', reason: 'Compensation for incident 42' };
      expectError(await adminCall('post', path).send(body), 400, 'VALIDATION_FAILED');
      expectError(
        await adminCall('post', path).set('Idempotency-Key', 'nope').send(body),
        400,
        'VALIDATION_FAILED',
      );
      expectError(
        await adminCall('post', path)
          .set('Idempotency-Key', randomUUID())
          .send({ ...body, reason: 'x' }),
        400,
        'VALIDATION_FAILED',
      );
      const key = randomUUID();
      const before = await points(bob);
      const first = await adminCall('post', path).set('Idempotency-Key', key).send(body);
      expect(first.status).toBe(200);
      expectContract(first, 'createAdminLevelAdjustment');
      expect(first.body.entry).toMatchObject({
        entryType: 'ADJUSTMENT',
        sourceType: 'ADMIN',
        pointsDelta: '1000',
      });
      const replay = await adminCall('post', path).set('Idempotency-Key', key).send(body);
      expect(replay.status).toBe(200);
      expect(replay.body.entry.id).toBe(first.body.entry.id);
      expect(BigInt((await points(bob)).GAMING.points) - BigInt(before.GAMING.points)).toBe(1000n);
      expectError(
        await adminCall('post', path)
          .set('Idempotency-Key', key)
          .send({ ...body, pointsDelta: '5' }),
        409,
        'IDEMPOTENCY_CONFLICT',
      );
      expectError(
        await adminCall('post', path)
          .set('Idempotency-Key', randomUUID())
          .send({ ...body, pointsDelta: '-999999' }),
        422,
        'LEVEL_CONFIG_INVALID',
      );
      const log = await adminCall('get', '/audit-logs?limit=50');
      expect(log.status).toBe(200);
      expectContract(log, 'listAdminLevelAuditLogs');
      const adjust = log.body.data.find((l: { action: string }) => l.action === 'levels.user.adjust');
      expect(adjust).toMatchObject({ actorUserId: admin.id, targetId: bob.id });
      expect(adjust.metadata).toMatchObject({ pointsDelta: '1000', reason: body.reason });
      expect(log.body.data.every((l: { action: string }) => l.action.startsWith('levels.'))).toBe(true);
    });

    it('recalculate rebuilds a state from the ledger', async () => {
      await withMigrationClient((db) =>
        db.$executeRawUnsafe(
          `UPDATE user_level_states s SET total_points = 7 FROM level_categories c
            WHERE s.category_id = c.id AND c.code = 'SUPPORT' AND s.user_id = '${alice.id}'`,
        ),
      );
      expect((await points(alice)).SUPPORT.points).toBe('7');
      const res = await adminCall('post', `/users/${alice.id}/recalculate`).send({ category: 'SUPPORT' });
      expect(res.status).toBe(200);
      expectContract(res, 'recalculateAdminUserLevel');
      const sum = await ctx.prisma.pointsLedgerEntry.aggregate({
        where: { userId: alice.id, category: { code: 'SUPPORT' } },
        _sum: { pointsDelta: true },
      });
      expect((await points(alice)).SUPPORT.points).toBe(String(sum._sum.pointsDelta));
    });
  });

  describe('versions and recalculation', () => {
    it('preview, then RECOMPUTE_FROM_LEDGER rebuilds totals with the new multiplier', async () => {
      const before = await points(bob);
      const created = await adminCall('post', '/categories/attractiveness/versions').send({});
      const id = created.body.id as string;
      await adminCall('put', `/versions/${id}`).send({
        multiplier: '2',
        valueUnit: 'COIN',
        reversalPolicy: 'REVERSE_POINTS',
        levels: LADDER,
      });
      const preview = await adminCall('get', `/versions/${id}/preview?recalculation=RECOMPUTE_FROM_LEDGER`);
      expect(preview.status).toBe(200);
      expectContract(preview, 'previewAdminLevelVersion');
      expect(preview.body.totalUsers).toBeGreaterThan(0);
      const pub = await adminCall('post', `/versions/${id}/publish`).send({
        recalculation: 'RECOMPUTE_FROM_LEDGER',
      });
      expect(pub.status).toBe(200);
      expect((await points(bob)).ATTRACTIVENESS.points).toBe(
        String(BigInt(before.ATTRACTIVENESS.points) * 2n),
      );
      const config = await ctx.prisma.pointsLedgerEntry.count({
        where: { userId: bob.id, sourceType: 'CONFIG' },
      });
      expect(config).toBe(1);
      // Back to multiplier 1 (the ledger keeps both adjustments; history is never rewritten).
      await publish('ATTRACTIVENESS', {}, 'RECOMPUTE_FROM_LEDGER');
      expect(await points(bob)).toEqual(before);
    });
  });

  describe('reconciliation and reports', () => {
    it('DRY_RUN reports a drifted state, REPAIR fixes it', async () => {
      await withMigrationClient((db) =>
        db.$executeRawUnsafe(
          `UPDATE user_level_states s SET total_points = total_points + 5 FROM level_categories c
            WHERE s.category_id = c.id AND c.code = 'ATTRACTIVENESS' AND s.user_id = '${bob.id}'`,
        ),
      );
      const dry = await adminCall('post', '/reconciliation').send({
        mode: 'DRY_RUN',
        category: 'ATTRACTIVENESS',
      });
      expect(dry.status).toBe(200);
      expectContract(dry, 'startAdminLevelReconciliation');
      expect(dry.body).toMatchObject({ status: 'COMPLETED', stateMismatches: 1, corrected: 0 });
      const repair = await adminCall('post', '/reconciliation').send({
        mode: 'REPAIR',
        category: 'ATTRACTIVENESS',
      });
      expect(repair.body).toMatchObject({ status: 'COMPLETED', stateMismatches: 1 });
      expect(repair.body.corrected).toBeGreaterThanOrEqual(1);
      const after = await adminCall('post', '/reconciliation').send({
        mode: 'DRY_RUN',
        category: 'ATTRACTIVENESS',
      });
      expect(after.body.stateMismatches).toBe(0);

      const list = await adminCall('get', '/reconciliation?limit=2');
      expect(list.status).toBe(200);
      expectContract(list, 'listAdminLevelReconciliations');
      expect(list.body.page.hasMore).toBe(true);
      const one = await adminCall('get', `/reconciliation/${repair.body.id}`);
      expectContract(one, 'getAdminLevelReconciliation');
      expectError(await adminCall('get', `/reconciliation/${randomUUID()}`), 404, 'NOT_FOUND');
    });

    it('reports show the distribution per category', async () => {
      const res = await adminCall('get', '/reports');
      expect(res.status).toBe(200);
      expectContract(res, 'getAdminLevelReports');
      expect(res.body.data).toHaveLength(4);
      const total = res.body.data[0].usersPerLevel.reduce(
        (n: number, l: { users: number }) => n + l.users,
        0,
      );
      expect(total).toBeGreaterThan(0);
      const one = await adminCall('get', '/categories/gaming');
      expectContract(one, 'getAdminLevelCategory');
    });
  });

  describe('profiles (CP-005 §9.1, 7)', () => {
    it("another user's levels: levels only, never points", async () => {
      const res = await ctx.http.get(`/api/v1/users/${bob.username}/levels`).set(bearer(alice));
      expect(res.status).toBe(200);
      expectContract(res, 'getUserLevels');
      expect(res.body.data).toHaveLength(4);
      expect(res.body.data[0]).not.toHaveProperty('points');
      const mine = await points(bob);
      expect(res.body.data[0].level?.levelNumber ?? null).toBe(mine.ATTRACTIVENESS.level);
      expectError(
        await ctx.http.get('/api/v1/users/no_such_user_x/levels').set(bearer(alice)),
        404,
        'NOT_FOUND',
      );
      expectError(await ctx.http.get('/api/v1/users/BAD-NAME/levels').set(bearer(alice)), 404, 'NOT_FOUND');
      expectError(await ctx.http.get(`/api/v1/users/${bob.username}/levels`), 401, 'AUTH_UNAUTHENTICATED');
    });
  });

  describe('owner ladder preset (CP-005 §9.1)', () => {
    it('draft-preset writes four valid drafts at ×0.1 and publishes nothing', async () => {
      const before = await adminCall('get', '/categories');
      const out = levelsAdmin('draft-preset', admin.email);
      const ids = [...out.matchAll(/draft v\d+ ([0-9a-f-]{36})/g)].map((m) => m[1]!);
      expect(ids).toHaveLength(4);
      for (const id of ids) {
        const v = await adminCall('get', `/versions/${id}`);
        expectContract(v, 'getAdminLevelVersion');
        expect(v.body).toMatchObject({ status: 'DRAFT', multiplier: '0.1', valueUnit: 'COIN' });
        expect(v.body.levels).toHaveLength(100);
        expect(v.body.levels[99]).toMatchObject({
          levelNumber: 100,
          requiredPoints: '546090',
          nameEn: 'Legend',
        });
        const check = await adminCall('post', `/versions/${id}/validate`).send();
        expect(check.body).toEqual({ valid: true, issues: [] });
      }
      // Nothing published or switched: the categories are as they were.
      const after = await adminCall('get', '/categories');
      expect(
        after.body.data.map((c: { published: { id: string } | null; enabled: boolean }) => [
          c.published?.id,
          c.enabled,
        ]),
      ).toEqual(
        before.body.data.map((c: { published: { id: string } | null; enabled: boolean }) => [
          c.published?.id,
          c.enabled,
        ]),
      );
    });
  });

  describe('data integrity', () => {
    it('the ledger and level history are append-only for the runtime role', async () => {
      await expect(
        ctx.prisma.$executeRawUnsafe('UPDATE points_ledger SET points_delta = 1'),
      ).rejects.toThrow();
      await expect(ctx.prisma.$executeRawUnsafe('DELETE FROM level_history')).rejects.toThrow();
    });

    it('a disabled category stops crediting but keeps the stored points', async () => {
      const before = await points(bob);
      await adminCall('patch', '/categories/attractiveness').send({ enabled: false });
      await gift(alice, bob, 100n);
      const after = await points(bob);
      expect(after.ATTRACTIVENESS).toEqual({ points: before.ATTRACTIVENESS.points, level: null });
      await adminCall('patch', '/categories/attractiveness').send({ enabled: true });
      expect((await points(bob)).ATTRACTIVENESS.points).toBe(before.ATTRACTIVENESS.points);
    });
  });
});
