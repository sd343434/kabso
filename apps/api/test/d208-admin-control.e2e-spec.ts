/**
 * D208 (owner 2026-10-31: «اجعله يملك صلاحية لكل شيء مثل قفل حساب شخص او حظره او تغير كلمة المرور»; contract
 * v1.72-social, CONVENTIONS §10.67): the admin panel's account controls — every route's capability per role, the
 * authenticator code again where destructive or money, an audit row per change with the actor, the IP, `via: panel`,
 * the reason and before / after, the user's notification, and the user-side effect (a locked account cannot sign in
 * and can again after the end; restrictions refuse what they name; a temporary password must be replaced at sign-in;
 * …). The `control-admin` CLI runs the same rules. End to end against PostgreSQL + Redis.
 */
import { execFile } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { promisify } from 'node:util';
import type request from 'supertest';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { CAPABILITIES, PANEL_ROLES, type Capability } from '../src/modules/admin-panel/admin-permissions.js';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { sweepSpecialUsernames } from '../src/modules/users/special-usernames.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const run = promisify(execFile);
const cli = (args: string[]) =>
  run('node', ['--import', 'tsx', 'src/cli/control-admin.ts', ...args], {
    env: { ...process.env, DOTENV_CONFIG_QUIET: 'true' },
  });

const COOKIE = '__Host-kabso_admin';
const DAY = 86_400_000;

interface Person {
  readonly id: string;
  readonly email: string;
  password: string;
  readonly username: string;
  token: string;
}
interface Admin extends Person {
  secret: string;
  cookie: string;
  csrf: string;
}

const D208_OPS = [
  'getAdminUserControl',
  'lockAdminUser',
  'unlockAdminUser',
  'restrictAdminUser',
  'liftAdminUserRestriction',
  'sendAdminUserPasswordResetLink',
  'setAdminUserTemporaryPassword',
  'requireAdminUserPasswordChange',
  'changeAdminUserEmail',
  'resendAdminUserVerification',
  'editAdminUserProfile',
  'listAdminUserContent',
  'adjustAdminUserBalance',
  'requestAdminUserDeletion',
  'cancelAdminUserDeletion',
  'moderateAdminContent',
];

describe('D208 contract coverage', () => {
  it('openapi v1.72-social declares the account controls, each with the admin session (and CSRF on changes)', () => {
    const mine = operations().filter((o) =>
      (typeof o.spec.description === 'string' ? o.spec.description : '').startsWith('(v1.72-social, D208'),
    );
    expect(mine.map((o) => o.operationId).sort()).toEqual([...D208_OPS].sort());
    for (const o of mine) {
      expect(o.spec.security).toEqual([{ adminSession: [] }]);
      if (o.method !== 'get') expect(JSON.stringify(o.spec.parameters), o.operationId).toContain('AdminCsrf');
    }
  });
});

describe('D208 admin account controls', { timeout: 900_000 }, () => {
  const storage = new MemoryObjectStorage();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  const nextCode = (secret: string) => {
    advance(30_000);
    return totpCode(secret, clock);
  };

  const signup = async (): Promise<Person> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      email: payload.email,
      password: payload.password,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const p = await signup();
    await withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: p.email, password: p.password });
    const pending = cookieOf(res);
    const csrf = res.body.csrfToken as string;
    const enrol = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf);
    const secret = enrol.body.secret as string;
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: nextCode(secret) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { ...p, secret, cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  /** Panel sessions idle out after ADMIN_SESSION_IDLE_SECONDS; after a long clock jump, sign in again. */
  const relogin = async (...admins: Admin[]) => {
    for (const a of admins) {
      const res = await ctx.http
        .post('/api/v1/admin/auth/login')
        .send({ email: a.email, password: a.password });
      const v = await ctx.http
        .post('/api/v1/admin/auth/totp/verify')
        .set('Cookie', cookieOf(res))
        .set('X-CSRF-Token', res.body.csrfToken as string)
        .send({ code: nextCode(a.secret) });
      expect(v.status, JSON.stringify(v.body)).toBe(200);
      a.cookie = cookieOf(v);
      a.csrf = v.body.csrfToken as string;
    }
  };
  const get = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const send = (method: 'post' | 'patch', a: Admin, path: string, body: object = {}) =>
    ctx.http[method](`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);
  const post = (a: Admin, path: string, body: object = {}) => send('post', a, path, body);
  const appLogin = (identifier: string, password: string, extra: object = {}) =>
    ctx.http.post('/api/v1/auth/login').send({ identifier, password, ...extra });
  const bearer = (p: Person) => ({ Authorization: `Bearer ${p.token}` });
  const lastAudit = async (action: string, targetId?: string) => {
    const rows = await ctx.prisma.auditLog.findMany({
      where: { action, ...(targetId ? { targetId } : {}) },
      orderBy: { createdAt: 'asc' },
    });
    expect(rows.length, action).toBeGreaterThan(0);
    return rows[rows.length - 1]!;
  };
  const expectPanelAudit = async (action: string, targetId: string, actor: Admin, reason: string) => {
    const row = await lastAudit(action, targetId);
    expect(row.actorUserId).toBe(actor.id);
    expect(row.ip).toBeTruthy();
    const meta = row.metadata as Record<string, unknown>;
    expect(meta.via).toBe('panel');
    expect(JSON.stringify(meta)).toContain(reason);
    return meta;
  };
  const notifications = async (p: Person) => {
    const res = await ctx.http.get('/api/v1/notifications').set(bearer(p));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    return res.body.data as { type: string; target: Record<string, unknown> | null }[];
  };
  const fresh = async (p: Person) => {
    const res = await appLogin(p.email, p.password);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    p.token = res.body.tokens.accessToken as string;
  };

  let owner: Admin;
  let moderator: Admin;
  let support: Admin;
  let finance: Admin;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        LIVE_HOSTING_ENABLED: 'true',
        ADMIN_ADJUST_DAILY_CAP_COINS: '5000',
        ADMIN_ADJUST_DAILY_CAP_CHERRIES: '5000',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
        SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS: '0',
      },
      [
        { token: OBJECT_STORAGE, value: storage },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
    owner = await makeAdmin(['OWNER']);
    moderator = await makeAdmin(['MODERATION']);
    support = await makeAdmin(['SUPPORT']);
    finance = await makeAdmin(['FINANCE']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });
  afterEach(() => vi.setSystemTime(clock));

  it('every role gets exactly its D208 capabilities, server-side (403 before validation)', async () => {
    const target = await signup();
    const u = `/admin/users/${target.id}`;
    const ROUTES: [Capability, 'get' | 'post' | 'patch', string][] = [
      ['users.control_view', 'get', `${u}/control`],
      ['users.lock', 'post', `${u}/lock`],
      ['users.lock', 'post', `${u}/unlock`],
      ['users.restrict', 'post', `${u}/restrictions`],
      ['users.restrict', 'post', `${u}/restrictions/lift`],
      ['users.password', 'post', `${u}/password/reset-link`],
      ['users.password', 'post', `${u}/password/temporary`],
      ['users.password', 'post', `${u}/password/require-change`],
      ['users.email', 'post', `${u}/email`],
      ['users.email', 'post', `${u}/email/resend-verification`],
      ['users.profile_edit', 'patch', `${u}/profile`],
      ['users.content', 'post', `/admin/content/post/${randomUUID()}/hide`],
      ['users.balance_adjust', 'post', `${u}/balance-adjustments`],
      ['users.delete', 'post', `${u}/deletion`],
      ['users.delete', 'post', `${u}/deletion/cancel`],
    ];
    const byRole: Record<string, Admin> = {
      OWNER: owner,
      MODERATION: moderator,
      SUPPORT: support,
      FINANCE: finance,
    };
    for (const role of PANEL_ROLES) {
      const a = byRole[role]!;
      const me = await get(a, '/admin/auth/session');
      for (const [cap, method, path] of ROUTES) {
        const allowed = (CAPABILITIES[cap] as readonly string[]).includes(role);
        const res = method === 'get' ? await get(a, path) : await send(method, a, path, {});
        if (allowed) {
          // Past the guard: the empty body is refused by validation (or the read answers).
          expect(res.status, `${role} ${cap} ${path}`).toBe(method === 'get' ? 200 : 400);
        } else {
          expect(res.status, `${role} ${cap} ${path}`).toBe(403);
          expect(res.body.error.code).toBe('AUTH_FORBIDDEN');
        }
        expect(me.body.capabilities.includes(cap), `${role} ${cap}`).toBe(allowed);
      }
    }
    // A change without the CSRF header is refused too.
    const noCsrf = await ctx.http
      .post(`/api/v1${u}/lock`)
      .set('Cookie', owner.cookie)
      .send({ days: 1, reason: 'x' });
    expect(noCsrf.status).toBe(403);
    expect(noCsrf.body.error.code).toBe('ADMIN_CSRF_INVALID');
  });

  it('locks an account for a while: sign-in refused with the end and reason, sessions ended, unlocked early and by time', async () => {
    const p = await signup();
    expect((await ctx.http.get('/api/v1/me').set(bearer(p))).status).toBe(200);
    const reason = 'Lock test: spam reports under review';
    const locked = await post(support, `/admin/users/${p.id}/lock`, { days: 1, reason });
    expect(locked.status, JSON.stringify(locked.body)).toBe(200);
    expectContract(locked, 'lockAdminUser');
    expect(locked.body.restriction.kind).toBe('LOCK');
    expect(locked.body.sessions).toBeGreaterThanOrEqual(1);
    const meta = await expectPanelAudit('admin.user.lock', p.id, support, reason);
    expect(meta.before).toBeNull();
    expect((meta.after as { kind: string }).kind).toBe('LOCK');
    // Every session ended: the old token no longer works.
    expect((await ctx.http.get('/api/v1/me').set(bearer(p))).status).toBe(401);
    // Sign-in: refused with the end and the reason — only after the right password.
    const refused = await appLogin(p.email, p.password);
    expect(refused.status).toBe(403);
    expect(refused.body.error.code).toBe('ACCOUNT_LOCKED');
    const details = refused.body.error.details as { field: string; issue: string }[];
    expect(details.find((d) => d.field === 'lockedUntil')?.issue).toBe(locked.body.restriction.endsAt);
    expect(details.find((d) => d.field === 'reason')?.issue).toBe(reason);
    const wrong = await appLogin(p.email, 'not the password at all');
    expect(wrong.status).toBe(401);
    // The state the panel shows.
    const state = await get(moderator, `/admin/users/${p.id}/control`);
    expect(state.status).toBe(200);
    expectContract(state, 'getAdminUserControl');
    expect(state.body.lock.kind).toBe('LOCK');
    expect(state.body.status).toBe('ACTIVE');
    // Unlock early → sign-in works; the person was told twice.
    const unlocked = await post(support, `/admin/users/${p.id}/unlock`, { reason: 'Reviewed: not spam' });
    expect(unlocked.status).toBe(200);
    expectContract(unlocked, 'unlockAdminUser');
    await expectPanelAudit('admin.user.unlock', p.id, support, 'Reviewed: not spam');
    expect((await post(support, `/admin/users/${p.id}/unlock`, { reason: 'again' })).status).toBe(409);
    await fresh(p);
    const types = (await notifications(p)).map((n) => n.type);
    expect(types).toContain('ACCOUNT_RESTRICTED');
    expect(types).toContain('ACCOUNT_RESTRICTION_LIFTED');
    const n = (await notifications(p)).find((x) => x.type === 'ACCOUNT_RESTRICTED')!;
    expect(n.target).toMatchObject({ type: 'ACCOUNT_RESTRICTION', restriction: 'LOCK', text: reason });
    // A lock that ends by itself: until a date 2 hours away; after it, sign-in works without anyone acting.
    const until = new Date(clock + 2 * 3600_000).toISOString();
    expect((await post(moderator, `/admin/users/${p.id}/lock`, { until, reason: 'two hours' })).status).toBe(
      200,
    );
    expect((await appLogin(p.email, p.password)).status).toBe(403);
    advance(2 * 3600_000 + 60_000);
    await fresh(p);
    // Not on oneself, not on a panel admin unless OWNER, not on a banned account (the ban is separate).
    expect((await post(support, `/admin/users/${support.id}/lock`, { days: 1, reason: 'x' })).status).toBe(
      409,
    );
    expect((await post(support, `/admin/users/${moderator.id}/lock`, { days: 1, reason: 'x' })).status).toBe(
      403,
    );
    expect(
      (
        await post(owner, `/admin/users/${p.id}/ban`, {
          reason: 'ban test',
          totpCode: nextCode(owner.secret),
        })
      ).status,
    ).toBe(200);
    const onBanned = await post(owner, `/admin/users/${p.id}/lock`, { days: 3, reason: 'x' });
    expect(onBanned.status).toBe(409);
    expect(onBanned.body.error.code).toBe('ADMIN_ACTION_REFUSED');
    expect((await post(owner, `/admin/users/${p.id}/unban`, { reason: 'unban test' })).status).toBe(200);
    // Validation: exactly one of days / until; not in the past; at most a year.
    const u = `/admin/users/${p.id}/lock`;
    expect((await post(owner, u, { reason: 'x' })).status).toBe(400);
    expect((await post(owner, u, { days: 1, until, reason: 'x' })).status).toBe(400);
    expect((await post(owner, u, { days: 400, reason: 'x' })).status).toBe(400);
    expect((await post(owner, u, { until: new Date(clock - 1000).toISOString(), reason: 'x' })).status).toBe(
      409,
    );
  });

  it('restrictions refuse what they name until lifted or ended, and the person is told the end', async () => {
    const p = await signup();
    const q = await signup();
    const created = await ctx.http
      .post('/api/v1/posts')
      .set(bearer(q))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'a post to comment on' });
    expect(created.status).toBe(201);
    const postId = created.body.id as string;
    const comment = () =>
      ctx.http.post(`/api/v1/posts/${postId}/comments`).set(bearer(p)).send({ text: 'hello there' });
    expect((await comment()).status).toBe(201);

    // CHAT_MUTE: comments and direct messages.
    const mute = await post(moderator, `/admin/users/${p.id}/restrictions`, {
      kind: 'CHAT_MUTE',
      days: 3,
      reason: 'Insults in comments',
    });
    expect(mute.status, JSON.stringify(mute.body)).toBe(200);
    expectContract(mute, 'restrictAdminUser');
    await expectPanelAudit('admin.user.restrict', p.id, moderator, 'Insults in comments');
    const muted = await comment();
    expect(muted.status).toBe(403);
    expect(muted.body.error.code).toBe('ACCOUNT_RESTRICTED');
    expect(muted.body.error.details).toEqual([
      { field: 'restriction', issue: 'CHAT_MUTE' },
      { field: 'until', issue: mute.body.restriction.endsAt },
    ]);
    const dm = await ctx.http
      .post('/api/v1/dm/messages')
      .set(bearer(p))
      .send({ to: q.username, kind: 'TEXT', text: 'hi', clientId: randomUUID() });
    expect(dm.status).toBe(403);
    expect(dm.body.error.code).toBe('ACCOUNT_RESTRICTED');
    // Still signed in (a restriction is not a lock).
    expect((await ctx.http.get('/api/v1/me').set(bearer(p))).status).toBe(200);
    const told = (await notifications(p)).find((n) => n.type === 'ACCOUNT_RESTRICTED')!;
    expect(told.target).toMatchObject({ restriction: 'CHAT_MUTE', endsAt: mute.body.restriction.endsAt });
    // A LOCK is not lifted here; lifting the mute lets comments through.
    expect(
      (await post(moderator, `/admin/users/${p.id}/restrictions/lift`, { kind: 'LOCK', reason: 'x' })).status,
    ).toBe(400);
    const lifted = await post(moderator, `/admin/users/${p.id}/restrictions/lift`, {
      kind: 'CHAT_MUTE',
      reason: 'Apologised',
    });
    expect(lifted.status).toBe(200);
    expectContract(lifted, 'liftAdminUserRestriction');
    await expectPanelAudit('admin.user.restriction_lift', p.id, moderator, 'Apologised');
    expect((await comment()).status).toBe(201);

    // NO_POSTING: posts (and reels / stories).
    expect(
      (await post(owner, `/admin/users/${p.id}/restrictions`, { kind: 'NO_POSTING', days: 1, reason: 'np' }))
        .status,
    ).toBe(200);
    const noPost = await ctx.http
      .post('/api/v1/posts')
      .set(bearer(p))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'should be refused' });
    expect(noPost.status).toBe(403);
    expect(noPost.body.error.details[0]).toEqual({ field: 'restriction', issue: 'NO_POSTING' });
    // A new one of the same kind replaces the open one.
    const again = await post(owner, `/admin/users/${p.id}/restrictions`, {
      kind: 'NO_POSTING',
      days: 7,
      reason: 'np2',
    });
    expect(again.status).toBe(200);
    expect(again.body.replaced.kind).toBe('NO_POSTING');
    // It ends by itself after 7 days.
    advance(7 * DAY + 60_000);
    await fresh(p);
    await relogin(owner, moderator, support, finance);
    const ok = await ctx.http
      .post('/api/v1/posts')
      .set(bearer(p))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'allowed again' });
    expect(ok.status).toBe(201);

    // NO_GIFTS: a bag transfer (refused before the item is looked up).
    expect(
      (
        await post(moderator, `/admin/users/${p.id}/restrictions`, {
          kind: 'NO_GIFTS',
          days: 1,
          reason: 'ng',
        })
      ).status,
    ).toBe(200);
    const bag = await ctx.http
      .post('/api/v1/me/bag/transfers')
      .set(bearer(p))
      .send({ code: 'no-such-item', username: q.username });
    expect(bag.status).toBe(403);
    expect(bag.body.error.details[0]).toEqual({ field: 'restriction', issue: 'NO_GIFTS' });

    // NO_LIVE: going live (checked right after the hosting permission).
    await ctx.prisma.liveHost.create({ data: { userId: p.id, source: 'ADMIN' } });
    const before = await ctx.http.post('/api/v1/live/rooms').set(bearer(p)).send({});
    expect(before.status).toBe(400);
    expect(
      (
        await post(moderator, `/admin/users/${p.id}/restrictions`, {
          kind: 'NO_LIVE',
          days: 30,
          reason: 'nl',
        })
      ).status,
    ).toBe(200);
    const live = await ctx.http.post('/api/v1/live/rooms').set(bearer(p)).send({});
    expect(live.status).toBe(403);
    expect(live.body.error.details[0]).toEqual({ field: 'restriction', issue: 'NO_LIVE' });
    const state = await get(finance, `/admin/users/${p.id}/control`);
    expect(state.body.restrictions.map((r: { kind: string }) => r.kind).sort()).toEqual([
      'NO_GIFTS',
      'NO_LIVE',
    ]);
    expect(state.body.history.length).toBeGreaterThanOrEqual(5);
  });

  it('password: the reset email, a temporary password shown once and replaced at sign-in, a forced change', async () => {
    const p = await signup();
    // (a) the existing reset email; the admin never gets the link.
    ctx.mail.sent.length = 0;
    const link = await post(support, `/admin/users/${p.id}/password/reset-link`, {
      reason: 'User asked by email',
    });
    expect(link.status).toBe(200);
    expectContract(link, 'sendAdminUserPasswordResetLink');
    expect(JSON.stringify(link.body)).not.toContain('token');
    expect(ctx.mail.sent.some((m) => m.kind === 'reset' && m.to === p.email)).toBe(true);
    await expectPanelAudit('admin.user.password_reset_link', p.id, support, 'User asked by email');
    // (b) a temporary password: the code again.
    const bad = await post(support, `/admin/users/${p.id}/password/temporary`, {
      reason: 'Lost access',
      totpCode: '000000',
    });
    expect(bad.status).toBe(403);
    expect(bad.body.error.code).toBe('ADMIN_TOTP_INVALID');
    const temp = await post(support, `/admin/users/${p.id}/password/temporary`, {
      reason: 'Lost access',
      totpCode: nextCode(support.secret),
    });
    expect(temp.status, JSON.stringify(temp.body)).toBe(200);
    expectContract(temp, 'setAdminUserTemporaryPassword');
    expect(temp.headers['cache-control']).toBe('no-store');
    const password = temp.body.temporaryPassword as string;
    expect(password).toMatch(/^[A-Za-z0-9]{4}(-[A-Za-z0-9]{4}){3}$/);
    const meta = await expectPanelAudit('admin.user.password_temporary', p.id, support, 'Lost access');
    expect(JSON.stringify(meta)).not.toContain(password);
    expect((await ctx.http.get('/api/v1/me').set(bearer(p))).status).toBe(401);
    expect((await appLogin(p.email, p.password)).status).toBe(401);
    const must = await appLogin(p.email, password);
    expect(must.status).toBe(403);
    expect(must.body.error.code).toBe('PASSWORD_CHANGE_REQUIRED');
    const same = await appLogin(p.email, password, { newPassword: password });
    expect(same.status).toBe(400);
    const changed = await appLogin(p.email, password, { newPassword: 'a brand new pass 2026' });
    expect(changed.status, JSON.stringify(changed.body)).toBe(200);
    expect((await lastAudit('auth.password.changed_at_sign_in', p.id)).actorUserId).toBe(p.id);
    expect((await appLogin(p.email, 'a brand new pass 2026')).status).toBe(200);
    p.password = 'a brand new pass 2026';
    // (c) a forced change at the next sign-in (signed out now by default).
    await fresh(p);
    const force = await post(owner, `/admin/users/${p.id}/password/require-change`, {
      reason: 'Leaked list',
    });
    expect(force.status).toBe(200);
    expectContract(force, 'requireAdminUserPasswordChange');
    await expectPanelAudit('admin.user.password_require_change', p.id, owner, 'Leaked list');
    expect((await ctx.http.get('/api/v1/me').set(bearer(p))).status).toBe(401);
    expect((await appLogin(p.email, p.password)).body.error.code).toBe('PASSWORD_CHANGE_REQUIRED');
    expect((await get(owner, `/admin/users/${p.id}/control`)).body.password.changeRequired).toBe(true);
    expect((await appLogin(p.email, p.password, { newPassword: 'another new pass 2026' })).status).toBe(200);
    expect((await get(owner, `/admin/users/${p.id}/control`)).body.password.changeRequired).toBe(false);
  });

  it('email: changed with a verification to the new address (or marked verified by an OWNER), resend', async () => {
    const p = await signup();
    const other = await signup();
    const newEmail = `new-${randomUUID().slice(0, 8)}@example.test`;
    // markVerified is OWNER only.
    const notOwner = await post(support, `/admin/users/${p.id}/email`, {
      email: newEmail,
      markVerified: true,
      reason: 'x',
      totpCode: nextCode(support.secret),
    });
    expect(notOwner.status).toBe(403);
    const taken = await post(support, `/admin/users/${p.id}/email`, {
      email: other.email,
      reason: 'x',
      totpCode: nextCode(support.secret),
    });
    expect(taken.status).toBe(409);
    ctx.mail.sent.length = 0;
    const changed = await post(support, `/admin/users/${p.id}/email`, {
      email: newEmail,
      reason: 'Old mailbox closed',
      totpCode: nextCode(support.secret),
    });
    expect(changed.status, JSON.stringify(changed.body)).toBe(200);
    expectContract(changed, 'changeAdminUserEmail');
    expect(changed.body).toEqual({ email: newEmail, verified: false, verificationSent: true });
    expect(ctx.mail.sent.some((m) => m.kind === 'verify' && m.to === newEmail)).toBe(true);
    const meta = await expectPanelAudit('admin.user.email_change', p.id, support, 'Old mailbox closed');
    expect(JSON.stringify(meta)).not.toContain(newEmail);
    expect((await appLogin(newEmail, p.password)).status).toBe(200);
    // Resend, then an OWNER marks a new address verified.
    ctx.mail.sent.length = 0;
    const resend = await post(support, `/admin/users/${p.id}/email/resend-verification`, {
      reason: 'Not received',
    });
    expect(resend.status).toBe(200);
    expectContract(resend, 'resendAdminUserVerification');
    expect(ctx.mail.sent.some((m) => m.kind === 'verify' && m.to === newEmail)).toBe(true);
    const verified = `ok-${randomUUID().slice(0, 8)}@example.test`;
    const byOwner = await post(owner, `/admin/users/${p.id}/email`, {
      email: verified,
      markVerified: true,
      reason: 'Checked by phone',
      totpCode: nextCode(owner.secret),
    });
    expect(byOwner.body).toEqual({ email: verified, verified: true, verificationSent: false });
    expect(
      (await post(owner, `/admin/users/${p.id}/email/resend-verification`, { reason: 'x' })).status,
    ).toBe(409);
  });

  it('profile: name, username (D146 rule), bio, country, gender — audited before / after, the person told', async () => {
    const p = await signup();
    const other = await signup();
    const name = `edited_${Math.floor(Math.random() * 1e6)}x`;
    const edit = await send('patch', moderator, `/admin/users/${p.id}/profile`, {
      displayName: 'Edited Name',
      username: name,
      bio: 'A new bio',
      country: 'jo',
      gender: 'FEMALE',
      reason: 'Offensive name',
    });
    expect(edit.status, JSON.stringify(edit.body)).toBe(200);
    expectContract(edit, 'editAdminUserProfile');
    expect([...edit.body.changed].sort()).toEqual(['bio', 'country', 'displayName', 'gender', 'username']);
    const meta = await expectPanelAudit('admin.user.profile_edit', p.id, moderator, 'Offensive name');
    expect((meta.before as Record<string, string>).username).toBe(p.username);
    expect((meta.after as Record<string, string>).username).toBe(name);
    const profile = await ctx.http.get(`/api/v1/users/${name}`).set(bearer(other));
    expect(profile.status).toBe(200);
    expect(profile.body.displayName).toBe('Edited Name');
    expect((await notifications(p)).map((n) => n.type)).toContain('PROFILE_EDITED_BY_TEAM');
    // The old username stays held for p for ADMIN_USERNAME_RENAME_HOLD_DAYS (30): nobody else may take it, old links
    // still lead to p, and p may take it back (owner 2026-10-31).
    expect(meta.oldUsernameHeldUntil).toBe(new Date(clock + 30 * DAY).toISOString());
    const changeName = (who: Person, username: string) =>
      ctx.http.put('/api/v1/me/username').set(bearer(who)).send({ username });
    const grab = await changeName(other, p.username);
    expect(grab.status).toBe(409);
    expect(grab.body.error.code).toBe('USERNAME_TAKEN');
    expect(
      (await ctx.http.get(`/api/v1/users/username-availability?username=${p.username}`)).body.available,
    ).toBe(false);
    expect((await ctx.http.get(`/api/v1/users/${p.username}`).set(bearer(other))).body.username).toBe(name);
    const back = await changeName(p, p.username);
    expect(back.status, JSON.stringify(back.body)).toBe(200);
    expect(back.body.username).toBe(p.username);
    // Renamed again by the team: the same hold is extended (no second row).
    const name2 = `again_${Math.floor(Math.random() * 1e6)}y`;
    expect(
      (await send('patch', moderator, `/admin/users/${p.id}/profile`, { username: name2, reason: 'again' }))
        .status,
    ).toBe(200);
    expect(await ctx.prisma.specialUsername.count({ where: { userId: p.id, username: p.username } })).toBe(1);
    expect((await changeName(other, p.username)).status).toBe(409);
    // After the hold the sweeper releases it and anyone may take it.
    advance(31 * DAY);
    await sweepSpecialUsernames(ctx.prisma, new Date(clock), 30);
    await fresh(other);
    const freed = await changeName(other, p.username);
    expect(freed.status, JSON.stringify(freed.body)).toBe(200);
    await relogin(owner, moderator, support, finance);
    // The username rules: another account's (p's old one, now other's) → 409; a premium shape → 400; nothing → 400.
    const taken = await send('patch', support, `/admin/users/${p.id}/profile`, {
      username: p.username,
      reason: 'x',
    });
    expect(taken.status).toBe(409);
    expect(taken.body.error.code).toBe('USERNAME_TAKEN');
    expect(
      (await send('patch', support, `/admin/users/${p.id}/profile`, { username: 'abc', reason: 'x' })).status,
    ).toBe(400);
    expect((await send('patch', support, `/admin/users/${p.id}/profile`, { reason: 'x' })).status).toBe(400);
  });

  it('content: hide / restore / delete a post (code again), remove a comment — reports closed, the author told', async () => {
    const author = await signup();
    const reader = await signup();
    const created = await ctx.http
      .post('/api/v1/posts')
      .set(bearer(author))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'content to moderate' });
    const postId = created.body.id as string;
    const report = await ctx.http
      .post('/api/v1/reports')
      .set(bearer(reader))
      .send({ targetType: 'POST', targetId: postId, reason: 'SPAM' });
    expect(report.status, JSON.stringify(report.body)).toBe(201);
    const hide = await post(moderator, `/admin/content/post/${postId}/hide`, { reason: 'Spam link' });
    expect(hide.status, JSON.stringify(hide.body)).toBe(200);
    expectContract(hide, 'moderateAdminContent');
    expect(hide.body).toEqual({ state: 'REMOVED', reportsClosed: 1 });
    await expectPanelAudit('admin.content.hide', postId, moderator, 'Spam link');
    expect((await ctx.http.get(`/api/v1/posts/${postId}`).set(bearer(reader))).status).toBe(404);
    expect((await notifications(author)).map((n) => n.type)).toContain('CONTENT_REMOVED');
    const restore = await post(moderator, `/admin/content/post/${postId}/restore`, {
      reason: 'Appeal accepted',
    });
    expect(restore.body.state).toBe('VISIBLE');
    expect((await ctx.http.get(`/api/v1/posts/${postId}`).set(bearer(reader))).status).toBe(200);
    expect((await post(moderator, `/admin/content/post/${postId}/delete`, { reason: 'x' })).status).toBe(400);
    const del = await post(moderator, `/admin/content/post/${postId}/delete`, {
      reason: 'Repeated spam',
      totpCode: nextCode(moderator.secret),
    });
    expect(del.status).toBe(200);
    expect(del.body.state).toBe('DELETED');
    expect((await post(moderator, `/admin/content/post/${postId}/restore`, { reason: 'x' })).status).toBe(
      409,
    );
    // A comment on another post is removed (cannot be restored), listed in the user's content tab.
    const other = await ctx.http
      .post('/api/v1/posts')
      .set(bearer(reader))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'second post' });
    const c = await ctx.http
      .post(`/api/v1/posts/${other.body.id as string}/comments`)
      .set(bearer(author))
      .send({ text: 'a rude comment' });
    const commentId = c.body.id as string;
    const listed = await get(support, `/admin/users/${author.id}/content?kind=comments`);
    expect(listed.status).toBe(200);
    expectContract(listed, 'listAdminUserContent');
    expect(listed.body.data[0]).toMatchObject({ id: commentId, state: 'VISIBLE' });
    expect(
      (await post(moderator, `/admin/content/comment/${commentId}/restore`, { reason: 'x' })).status,
    ).toBe(409);
    expect(
      (await post(moderator, `/admin/content/comment/${commentId}/hide`, { reason: 'Rude' })).body.state,
    ).toBe('DELETED');
    expect((await get(support, `/admin/users/${author.id}/content?kind=comments`)).body.data[0].state).toBe(
      'DELETED',
    );
    expect((await post(moderator, `/admin/content/story/${randomUUID()}/hide`, { reason: 'x' })).status).toBe(
      404,
    );
    expect((await post(moderator, `/admin/content/video/${randomUUID()}/hide`, { reason: 'x' })).status).toBe(
      404,
    );
  });

  it('balance: credit / debit with ADMIN_ADJUSTMENT, never below 0 unless OWNER allows, the daily cap per admin', async () => {
    const p = await signup();
    const path = `/admin/users/${p.id}/balance-adjustments`;
    const body = (extra: object) => ({ reason: 'Compensation for a failed purchase', ...extra });
    expect((await post(moderator, path, body({}))).status).toBe(403);
    const credit = await post(
      finance,
      path,
      body({ currency: 'COINS', direction: 'CREDIT', amount: '3000', totpCode: nextCode(finance.secret) }),
    );
    expect(credit.status, JSON.stringify(credit.body)).toBe(200);
    expectContract(credit, 'adjustAdminUserBalance');
    expect(credit.body).toMatchObject({
      currency: 'COINS',
      delta: 3000,
      before: 0,
      after: 3000,
      usedToday: 3000,
    });
    const ledger = await ctx.prisma.walletLedgerEntry.findFirstOrThrow({
      where: { userId: p.id, reason: 'ADMIN_ADJUSTMENT' },
    });
    expect(ledger.referenceId).toBe(credit.body.adjustmentId);
    expect(Number(ledger.balanceAfter)).toBe(3000);
    const meta = await expectPanelAudit('admin.balance.adjust', p.id, finance, 'Compensation');
    expect(meta).toMatchObject({ currency: 'COINS', delta: '3000', before: '0', after: '3000' });
    const told = (await notifications(p)).find((n) => n.type === 'BALANCE_ADJUSTED')!;
    expect(told.target).toMatchObject({ type: 'BALANCE_ADJUSTMENT', currency: 'COINS', amount: 3000 });
    // Never below 0 …
    const tooMuch = await post(
      finance,
      path,
      body({ currency: 'COINS', direction: 'DEBIT', amount: '4000', totpCode: nextCode(finance.secret) }),
    );
    expect(tooMuch.status).toBe(409);
    expect(tooMuch.body.error.details[0].issue).toBe('negative');
    // … unless an OWNER allows it (a reversal); FINANCE may not.
    const finNeg = await post(
      finance,
      path,
      body({
        currency: 'COINS',
        direction: 'DEBIT',
        amount: '4000',
        allowNegative: true,
        totpCode: nextCode(finance.secret),
      }),
    );
    expect(finNeg.status).toBe(403);
    const neg = await post(
      owner,
      path,
      body({
        currency: 'COINS',
        direction: 'DEBIT',
        amount: '4000',
        allowNegative: true,
        totpCode: nextCode(owner.secret),
      }),
    );
    expect(neg.status, JSON.stringify(neg.body)).toBe(200);
    expect(neg.body.after).toBe(-1000);
    // The daily cap (5 000 here): FINANCE used 3 000 + the refused ones did not count; 2 500 more passes the cap.
    const cap = await post(
      finance,
      path,
      body({ currency: 'COINS', direction: 'CREDIT', amount: '2500', totpCode: nextCode(finance.secret) }),
    );
    expect(cap.status).toBe(409);
    expect(cap.body.error.details[0].issue).toBe('daily_cap');
    // Cherries count apart.
    const cherries = await post(
      finance,
      path,
      body({ currency: 'CHERRIES', direction: 'CREDIT', amount: '100', totpCode: nextCode(finance.secret) }),
    );
    expect(cherries.status).toBe(200);
    expect(
      await ctx.prisma.cherryLedgerEntry.count({ where: { userId: p.id, reason: 'ADMIN_ADJUSTMENT' } }),
    ).toBe(1);
    const state = await get(finance, `/admin/users/${p.id}/control`);
    expect(state.body.adjustToday).toMatchObject({ coins: 3000, cherries: 100, capCoins: 5000 });
    expect(state.body.adjustments).toHaveLength(3);
    // A wrong code changes nothing.
    const wrong = await post(
      finance,
      path,
      body({ currency: 'CHERRIES', direction: 'CREDIT', amount: '1', totpCode: '000000' }),
    );
    expect(wrong.status).toBe(403);
  });

  it('deletion: the D193 grace period started by an OWNER (code again) and cancelled', async () => {
    const p = await signup();
    expect(
      (await post(support, `/admin/users/${p.id}/deletion`, { reason: 'x', totpCode: '000000' })).status,
    ).toBe(403);
    const del = await post(owner, `/admin/users/${p.id}/deletion`, {
      reason: 'Written request verified',
      totpCode: nextCode(owner.secret),
    });
    expect(del.status, JSON.stringify(del.body)).toBe(200);
    expectContract(del, 'requestAdminUserDeletion');
    const row = await lastAudit('account.deletion.requested', p.id);
    expect(row.actorUserId).toBe(owner.id);
    expect((row.metadata as Record<string, unknown>).via).toBe('panel');
    expect((await appLogin(p.email, p.password)).body.error.code).toBe('ACCOUNT_DELETION_PENDING');
    expect((await get(owner, `/admin/users/${p.id}/control`)).body.deletion).not.toBeNull();
    const again = await post(owner, `/admin/users/${p.id}/deletion`, {
      reason: 'x',
      totpCode: nextCode(owner.secret),
    });
    expect(again.status).toBe(409);
    const cancel = await post(owner, `/admin/users/${p.id}/deletion/cancel`, {
      reason: 'Changed their mind',
    });
    expect(cancel.status).toBe(200);
    expectContract(cancel, 'cancelAdminUserDeletion');
    expect((await lastAudit('account.deletion.cancelled', p.id)).actorUserId).toBe(owner.id);
    await fresh(p);
  });

  it('the user timeline shows what was done to the account and by it', async () => {
    const p = await signup();
    await fresh(p);
    await post(moderator, `/admin/users/${p.id}/restrictions`, {
      kind: 'NO_GIFTS',
      days: 1,
      reason: 'timeline',
    });
    const res = await get(owner, `/admin/users/${p.id}/audit?page=1&pageSize=50`);
    expect(res.status).toBe(200);
    const actions = (res.body.data as { action: string }[]).map((r) => r.action);
    expect(actions).toContain('admin.user.restrict');
    expect(actions).toContain('auth.login.success');
  });

  it('control-admin (CLI) runs the same rules: lock, state, unlock, restrict, lift, forced change, adjust', async () => {
    const p = await signup();
    // The CLI runs on the real clock while this suite's clock is days ahead: ends are given as dates.
    const until = (days: number) => new Date(clock + days * DAY).toISOString();
    await cli(['lock', p.email, '--until', until(3), '--reason', 'cli lock']);
    expect((await appLogin(p.email, p.password)).body.error.code).toBe('ACCOUNT_LOCKED');
    const row = await lastAudit('admin.user.lock', p.id);
    expect(row.actorUserId).toBeNull();
    expect((row.metadata as Record<string, unknown>).via).toBe('cli');
    const state = await cli(['state', p.email]);
    expect(state.stdout).toContain('LOCK until');
    await cli(['unlock', p.email, '--reason', 'cli unlock']);
    await fresh(p);
    await cli(['restrict', p.email, 'NO_POSTING', '--until', until(1), '--reason', 'cli np']);
    const noPost = await ctx.http
      .post('/api/v1/posts')
      .set(bearer(p))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'refused' });
    expect(noPost.status).toBe(403);
    await cli(['lift', p.email, 'NO_POSTING', '--reason', 'cli lift']);
    const out = await cli(['adjust', p.email, 'coins', '+250', '--reason', 'cli credit']);
    expect(out.stdout).toContain('0 → 250');
    await expect(cli(['adjust', p.email, 'coins', '-500', '--reason', 'cli debit'])).rejects.toThrow();
    await expect(cli(['lock', p.email, '--days', '1'])).rejects.toThrow();
    await cli(['require-password-change', p.email, '--reason', 'cli force']);
    expect((await appLogin(p.email, p.password)).body.error.code).toBe('PASSWORD_CHANGE_REQUIRED');
  });
});
