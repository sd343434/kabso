/**
 * D357 (owner 2026-11-10, contract v1.118-social, CONVENTIONS §10.153): the founder's public count of «اقترح ميزة /
 * أبلغ» submissions, end to end against PostgreSQL + Redis:
 *
 *  - `PublicProfile.founderFeedbackCount` / `Me.founderFeedbackCount` only on the app owner's profile (0 included),
 *    the same number for every viewer, never on anyone else's profile or Me;
 *  - both kinds counted (a suggestion and a staff report), one combined number;
 *  - cached (a stale cached value is served) and dropped by a new submission and by the panel's deletion;
 *  - never who sent them or what they say (only the number is added to the profile).
 */
import type { Redis } from 'ioredis';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import type { AdminContext } from '../src/modules/admin-panel/admin-auth.service.js';
import { FOUNDER_FEEDBACK_COUNT_CACHE_KEY } from '../src/modules/owner-profile/owner-core.js';
import { OwnerFeedbackService } from '../src/modules/owner-profile/owner-feedback.service.js';
import { REDIS } from '../src/redis/redis.module.js';
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

describe('D357 founderFeedbackCount', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  let redis: Redis;
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
  const feedback = (u: TestUser, body: object) =>
    ctx.http.post('/api/v1/owner/feedback').set(auth(u)).send(body);
  const countSeenBy = async (viewer: TestUser): Promise<unknown> => {
    const res = await get(viewer, `/users/${owner.username}`);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body.founderFeedbackCount;
  };

  let owner: TestUser;
  let alice: TestUser;
  let bob: TestUser;
  let moderator: TestUser;

  beforeAll(async () => {
    ctx = await createTestApp({
      RATE_LIMIT_PROFILE_USER: '100000/900',
      RATE_LIMIT_AUTHENTICATED_USER: '100000/900',
    });
    redis = ctx.app.get<Redis>(REDIS);
    owner = await signup();
    alice = await signup();
    bob = await signup();
    moderator = await signup();
    await grant(owner, 'OWNER');
    await grant(moderator, 'MODERATION');
    await ctx.prisma.ownerFeedback.deleteMany({});
    await redis.del(FOUNDER_FEEDBACK_COUNT_CACHE_KEY);
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('0 on the founder profile and his Me; absent on everyone else', async () => {
    expect(await countSeenBy(alice)).toBe(0);
    const me = await get(owner, '/me');
    expectContract(me, 'getMe');
    expect(me.body.founderFeedbackCount).toBe(0);
    for (const [viewer, who] of [
      [owner, alice],
      [alice, moderator],
      [alice, alice],
    ] as const) {
      const res = await get(viewer, `/users/${who.username}`);
      expect(res.status).toBe(200);
      expect(res.body.founderFeedbackCount).toBeUndefined();
    }
    expect((await get(alice, '/me')).body.founderFeedbackCount).toBeUndefined();
    expect((await get(moderator, '/me')).body.founderFeedbackCount).toBeUndefined();
  });

  it('counts suggestions and staff reports as one number, the same for every viewer', async () => {
    expect((await feedback(alice, { kind: 'FEATURE', text: 'بث مشترك' })).status).toBe(201);
    expect((await feedback(alice, { kind: 'FEATURE', text: 'وضع ليلي' })).status).toBe(201);
    const report = await feedback(bob, {
      kind: 'STAFF_REPORT',
      staffUserId: moderator.id,
      category: 'RUDENESS',
      text: 'سرية',
    });
    expect(report.status, JSON.stringify(report.body)).toBe(201);
    for (const viewer of [alice, bob, moderator, owner]) expect(await countSeenBy(viewer)).toBe(3);
    expect((await get(owner, '/me')).body.founderFeedbackCount).toBe(3);
    // Only the number: no sender, text or kind leaks onto the profile.
    const body = JSON.stringify((await get(alice, `/users/${owner.username}`)).body);
    for (const leak of ['بث مشترك', 'سرية', 'RUDENESS', 'STAFF_REPORT', bob.id])
      expect(body).not.toContain(leak);
  });

  it('serves the cached value; a new submission and a deletion drop it', async () => {
    await redis.set(FOUNDER_FEEDBACK_COUNT_CACHE_KEY, '99', 'EX', 60);
    expect(await countSeenBy(alice)).toBe(99);
    expect((await feedback(bob, { kind: 'FEATURE', text: 'هدايا جديدة' })).status).toBe(201);
    expect(await countSeenBy(alice)).toBe(4);
    expect(await redis.get(FOUNDER_FEEDBACK_COUNT_CACHE_KEY)).toBe('4');

    const first = await ctx.prisma.ownerFeedback.findFirstOrThrow({ orderBy: { createdAt: 'asc' } });
    const admin: AdminContext = {
      sessionId: 'e2e',
      userId: owner.id,
      stage: 'ACTIVE',
      roles: ['OWNER'] as never,
      capabilities: [] as never,
      ip: null,
      requestId: null,
    };
    await ctx.app.get(OwnerFeedbackService).remove(admin, first.id);
    expect(await countSeenBy(alice)).toBe(3);
  });
});
