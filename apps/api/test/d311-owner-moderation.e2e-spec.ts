/**
 * D311 (owner 2026-11-08: «يمكنه حذف او حظر او تحذير اي شخص»; no code, no password — a confirmation only; contract
 * v1.99-social, CONVENTIONS §10.117): «إجراءات المؤسس» — `POST /owner/users/{userId}/actions`. The app owner only (a staff
 * member of any other role and a plain user → 403 OWNER_ONLY); never on himself or another OWNER; WARN / SUSPEND (N days)
 * / BAN / DELETE_ACCOUNT (the D193 deletion with its grace period) reuse the panel's rules, audited with `via: app` and
 * `owner.moderation.action`; a retry with the same clientId returns the first result.
 */
import { randomUUID } from 'node:crypto';
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
  readonly password: string;
  readonly token: string;
}

describe('D311 founder moderation actions in the app', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  let owner: TestUser;
  let owner2: TestUser;
  let moderator: TestUser;
  let plain: TestUser;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).trim().toLowerCase(),
      password: payload.password,
      token: res.body.tokens.accessToken as string,
    };
  };
  const grant = (u: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, u.email, role as never)));
  const act = (as: TestUser, target: string, body: Record<string, unknown>) =>
    ctx.http
      .post(`/api/v1/owner/users/${target}/actions`)
      .set(auth(as))
      .send({ clientId: randomUUID(), ...body });
  const codeOf = (res: { body: { error?: { code?: string } } }) => res.body.error?.code;
  const auditOf = (targetId: string, action: string) =>
    ctx.prisma.auditLog.findMany({ where: { targetId, action }, orderBy: { createdAt: 'asc' } });

  beforeAll(async () => {
    ctx = await createTestApp({
      ACCOUNT_DELETION_GRACE_DAYS: '30',
      RATE_LIMIT_OWNER_MODERATION_USER: '1000/900',
    });
    [owner, owner2, moderator, plain] = [await signup(), await signup(), await signup(), await signup()];
    await grant(owner, 'OWNER');
    await grant(owner2, 'OWNER');
    await grant(moderator, 'MODERATION');
  });
  afterAll(async () => ctx?.close());

  it('refuses everyone but the app owner with 403 OWNER_ONLY (other staff roles included)', async () => {
    const target = await signup();
    for (const who of [plain, moderator]) {
      for (const action of ['WARN', 'BAN', 'DELETE_ACCOUNT']) {
        const res = await act(who, target.id, { action, reason: 'nope' });
        expect(res.status, JSON.stringify(res.body)).toBe(403);
        expectContract(res, 'createOwnerModerationAction');
        expect(codeOf(res)).toBe('OWNER_ONLY');
      }
      const temp = await act(who, target.id, { action: 'SUSPEND', reason: 'nope', days: 3 });
      expect(codeOf(temp)).toBe('OWNER_ONLY');
    }
    // Nothing happened to the target.
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: target.id } })).status).toBe('ACTIVE');
    expect(await ctx.prisma.ownerModerationAction.count({ where: { targetId: target.id } })).toBe(0);
    const anon = await ctx.http.post(`/api/v1/owner/users/${target.id}/actions`).send({});
    expect(anon.status).toBe(401);
  });

  it('never acts on the owner himself or on another OWNER; validates the body; unknown → 404', async () => {
    const self = await act(owner, owner.id, { action: 'WARN', reason: 'x' });
    expect(self.status, JSON.stringify(self.body)).toBe(409);
    expectContract(self, 'createOwnerModerationAction');
    expect(codeOf(self)).toBe('ADMIN_ACTION_REFUSED');
    expect(self.body.error.details).toEqual([{ field: 'rule', issue: 'self' }]);
    const other = await act(owner, owner2.id, { action: 'BAN', reason: 'x' });
    expect(other.status).toBe(409);
    expect(other.body.error.details).toEqual([{ field: 'rule', issue: 'owner_target' }]);
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: owner2.id } })).status).toBe('ACTIVE');

    const target = await signup();
    for (const [body, field, issue] of [
      [{ action: 'SUSPEND', reason: 'x' }, 'days', 'required'],
      [{ action: 'WARN', reason: 'x', days: 3 }, 'days', 'invalid_value'],
      [{ action: 'SUSPEND', reason: 'x', days: 366 }, 'days', 'too_big'],
      [{ action: 'WARN', reason: '   ' }, 'reason', 'too_short'],
      [{ action: 'KICK', reason: 'x' }, 'action', 'invalid_value'],
    ] as const) {
      const res = await act(owner, target.id, body);
      expect(res.status, JSON.stringify(res.body)).toBe(400);
      expect(res.body.error.details).toContainEqual(expect.objectContaining({ field, issue }));
    }
    expect((await act(owner, randomUUID(), { action: 'WARN', reason: 'x' })).status).toBe(404);
    expect((await act(owner, 'not-a-uuid', { action: 'WARN', reason: 'x' })).status).toBe(404);
  });

  it('WARN: the person is told; audited with the reason and via app; a retry returns the first result', async () => {
    const target = await signup();
    const clientId = randomUUID();
    const first = await act(owner, target.id, { action: 'WARN', reason: 'سب وشتم', clientId });
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    expectContract(first, 'createOwnerModerationAction');
    expect(first.body).toMatchObject({
      action: 'WARN',
      target: { id: target.id, username: target.username },
      reason: 'سب وشتم',
      days: null,
      endsAt: null,
      purgeAfter: null,
      replayed: false,
    });
    const again = await act(owner, target.id, { action: 'WARN', reason: 'سب وشتم', clientId });
    expect(again.status).toBe(200);
    expectContract(again, 'createOwnerModerationAction');
    expect(again.body).toMatchObject({ id: first.body.id, replayed: true });
    // Once only: one notification, one action row, one of each audit row.
    expect(
      await ctx.prisma.notification.count({ where: { recipientId: target.id, type: 'MODERATION_WARNING' } }),
    ).toBe(1);
    expect(await ctx.prisma.ownerModerationAction.count({ where: { targetId: target.id } })).toBe(1);
    const [warn] = await auditOf(target.id, 'admin.user.warn');
    expect(warn).toMatchObject({ actorUserId: owner.id });
    expect(warn!.metadata).toMatchObject({ reason: 'سب وشتم', via: 'app', owner: true });
    const rows = await auditOf(target.id, 'owner.moderation.action');
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ actorUserId: owner.id, targetType: 'user' });
    expect(rows[0]!.metadata).toMatchObject({
      action: 'WARN',
      reason: 'سب وشتم',
      via: 'app',
      actionId: first.body.id,
    });
    // The account itself is untouched.
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: target.id } })).status).toBe('ACTIVE');
  });

  it('SUSPEND: a LOCK of N days (sessions revoked, told), audited; the person cannot sign in until it ends', async () => {
    const target = await signup();
    const res = await act(owner, target.id, { action: 'SUSPEND', reason: 'spam', days: 7 });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'createOwnerModerationAction');
    expect(res.body).toMatchObject({ action: 'SUSPEND', days: 7, purgeAfter: null });
    const endsAt = new Date(res.body.endsAt as string).getTime();
    expect(Math.abs(endsAt - (Date.now() + 7 * 86_400_000))).toBeLessThan(120_000);
    const restriction = await ctx.prisma.accountRestriction.findFirst({
      where: { userId: target.id, kind: 'LOCK', liftedAt: null },
    });
    expect(restriction).not.toBeNull();
    expect((await auditOf(target.id, 'admin.user.lock'))[0]!.metadata).toMatchObject({ via: 'app' });
    expect((await auditOf(target.id, 'owner.moderation.action'))[0]!.metadata).toMatchObject({
      action: 'SUSPEND',
      days: 7,
      reason: 'spam',
    });
    // Sessions revoked: the old token no longer works.
    const me = await ctx.http.get('/api/v1/me').set(auth(target));
    expect(me.status).toBe(401);
  });

  it('BAN: the panel ban (SUSPENDED), audited; a second ban of the same account is refused', async () => {
    const target = await signup();
    const res = await act(owner, target.id, { action: 'BAN', reason: 'احتيال' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'createOwnerModerationAction');
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: target.id } })).status).toBe('SUSPENDED');
    expect((await auditOf(target.id, 'admin.user.ban'))[0]!.metadata).toMatchObject({
      reason: 'احتيال',
      before: 'ACTIVE',
      after: 'SUSPENDED',
      via: 'app',
    });
    const twice = await act(owner, target.id, { action: 'BAN', reason: 'again' });
    expect(twice.status).toBe(409);
    expect(codeOf(twice)).toBe('ADMIN_ACTION_REFUSED');
    expect(await ctx.prisma.ownerModerationAction.count({ where: { targetId: target.id } })).toBe(1);
  });

  it('DELETE_ACCOUNT: the D193 deletion enters its grace period (cancellable), audited via app', async () => {
    const target = await signup();
    const res = await act(owner, target.id, { action: 'DELETE_ACCOUNT', reason: 'طلب قانوني' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'createOwnerModerationAction');
    const user = await ctx.prisma.user.findUniqueOrThrow({ where: { id: target.id } });
    expect(user.status).toBe('PENDING_DELETION');
    const request = await ctx.prisma.accountDeletionRequest.findFirstOrThrow({
      where: { userId: target.id },
    });
    expect(request.requestedVia).toBe('ADMIN');
    expect(request.purgeAfter.toISOString()).toBe(res.body.purgeAfter);
    const grace = request.purgeAfter.getTime() - request.requestedAt.getTime();
    expect(grace).toBe(30 * 86_400_000);
    const requested = await auditOf(target.id, 'account.deletion.requested');
    expect(requested).toHaveLength(1);
    expect(requested[0]!.actorUserId).toBe(owner.id);
    expect(requested[0]!.metadata).toMatchObject({ via: 'app' });
    expect((await auditOf(target.id, 'owner.moderation.action'))[0]!.metadata).toMatchObject({
      action: 'DELETE_ACCOUNT',
      reason: 'طلب قانوني',
      purgeAfter: res.body.purgeAfter,
    });
    // Still cancellable within the grace period: the person signs in with cancelDeletion and is ACTIVE again.
    const back = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: target.email, password: target.password, cancelDeletion: true });
    expect(back.status, JSON.stringify(back.body)).toBe(200);
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: target.id } })).status).toBe('ACTIVE');
    // A deletion already pending is refused (another account).
    const other = await signup();
    expect((await act(owner, other.id, { action: 'DELETE_ACCOUNT', reason: 'x' })).status).toBe(201);
    const twice = await act(owner, other.id, { action: 'DELETE_ACCOUNT', reason: 'x' });
    expect(twice.status).toBe(409);
  });

  it('is rate-limited per owner (a retry with the same clientId is not counted)', async () => {
    const app = await createTestApp({ RATE_LIMIT_OWNER_MODERATION_USER: '2/900' });
    const saved = ctx;
    ctx = app;
    try {
      const o = await signup();
      await grant(o, 'OWNER');
      const t = await signup();
      const clientId = randomUUID();
      expect((await act(o, t.id, { action: 'WARN', reason: 'a', clientId })).status).toBe(201);
      expect((await act(o, t.id, { action: 'WARN', reason: 'a', clientId })).status).toBe(200);
      expect((await act(o, t.id, { action: 'WARN', reason: 'b' })).status).toBe(201);
      const limited = await act(o, t.id, { action: 'WARN', reason: 'c' });
      expect(limited.status).toBe(429);
      expect(codeOf(limited)).toBe('RATE_LIMITED');
    } finally {
      ctx = saved;
      await app.close();
    }
  });
});
