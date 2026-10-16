import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { UsersService } from '../src/modules/users/users.service.js';
import { createTestApp, newUser, registerVerified, settle, type TestContext } from './helpers/test-app.js';

const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

let ctx: TestContext;

beforeAll(async () => {
  ctx = await createTestApp();
});

afterAll(async () => {
  await ctx?.close();
});

// Contract v1.2: an account (and tokens) exists only after register → register/verify.
async function register(overrides: Partial<Record<string, unknown>> = {}) {
  const { payload, res } = await registerVerified(ctx, overrides);
  expect(res.status).toBe(201);
  return { payload, body: res.body as AuthBody };
}

interface AuthBody {
  user: Record<string, unknown> & { id: string; email: string; username: string };
  tokens: {
    accessToken: string;
    accessTokenExpiresAt: string;
    refreshToken: string;
    refreshTokenExpiresAt: string;
  };
}

const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

describe('POST /auth/register', () => {
  // v1.2: register → 202 (no tokens), register/verify → 201 AuthResponse with a verified email.
  it('register → 202, verify → creates the account and returns AuthResponse', async () => {
    const payload = newUser({ email: '  Mixed.Case@Example.COM ', username: 'mixed.case_user' });
    const pending = await ctx.http.post('/api/v1/auth/register').send(payload);
    expect(pending.status).toBe(202);
    expect(pending.body).toEqual({ status: 'verification_pending' });
    const codeMail = await ctx.mail.waitFor('mixed.case@example.com', 'code');
    const res = await ctx.http
      .post('/api/v1/auth/register/verify')
      .send({ email: 'Mixed.Case@Example.COM', code: codeMail.code, device: payload.device });

    expect(res.status).toBe(201);
    expect(Object.keys(res.body).sort()).toEqual(['tokens', 'user']);
    expect(res.body.user).toEqual({
      id: expect.stringMatching(UUID),
      email: 'mixed.case@example.com',
      emailVerified: true,
      username: 'mixed.case_user',
      displayName: 'Test User',
      bio: null,
      avatarUrl: null,
      // v1.4
      avatarThumbUrl: null,
      avatarModeration: null,
      country: null,
      locale: 'en',
      role: 'USER',
      isPrivate: false,
      createdAt: expect.stringMatching(ISO),
    });
    const { tokens } = res.body as AuthBody;
    expect(tokens.accessToken.split('.')).toHaveLength(3);
    expect(tokens.refreshToken).toMatch(/^[0-9a-f-]{36}\.[A-Za-z0-9_-]{43}$/);
    expect(tokens.accessTokenExpiresAt).toMatch(ISO);
    expect(tokens.refreshTokenExpiresAt).toMatch(ISO);
    const accessTtl = Date.parse(tokens.accessTokenExpiresAt) - Date.now();
    expect(accessTtl).toBeGreaterThan(14 * 60 * 1000);
    expect(accessTtl).toBeLessThanOrEqual(15 * 60 * 1000);

    // No email-verification token mail: the address was proven by the code.
    await settle(ctx);
    expect(ctx.mail.last('mixed.case@example.com', 'verify')).toBeUndefined();

    // Profile + settings + session were written in the same transaction.
    const stored = await ctx.prisma.user.findUniqueOrThrow({
      where: { id: res.body.user.id },
      include: { profile: true, settings: true, sessions: true },
    });
    expect(stored.passwordHash.startsWith('$argon2id$')).toBe(true);
    expect(stored.sessions).toHaveLength(1);
    expect(stored.sessions[0]?.deviceName).toBe('Pixel 9');
    expect(stored.sessions[0]?.platform).toBe('android');
    expect(stored.sessions[0]?.refreshTokenHash).toHaveLength(64);
    expect(tokens.refreshToken).not.toContain(stored.sessions[0]?.refreshTokenHash);
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { action: 'auth.registration.verified', actorUserId: stored.id },
    });
    expect(audit).not.toBeNull();
  });

  it('rejects invalid fields with VALIDATION_FAILED details', async () => {
    const res = await ctx.http
      .post('/api/v1/auth/register')
      .set('X-Request-Id', 'test-req-123')
      .send({ email: 'not-an-email', password: 'short', username: 'Bad Name', displayName: '' });

    expect(res.status).toBe(400);
    expect(res.headers['x-request-id']).toBe('test-req-123');
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
    expect(res.body.error.requestId).toBe('test-req-123');
    expect(res.body.error.details).toEqual(
      expect.arrayContaining([
        { field: 'email', issue: 'invalid_email' },
        { field: 'password', issue: 'too_short' },
        { field: 'username', issue: 'invalid_format' },
        { field: 'displayName', issue: 'too_short' },
      ]),
    );
  });

  it('reports missing fields as required', async () => {
    const res = await ctx.http.post('/api/v1/auth/register').send({});
    expect(res.status).toBe(400);
    expect(res.body.error.details).toEqual(
      expect.arrayContaining([
        { field: 'email', issue: 'required' },
        { field: 'password', issue: 'required' },
        { field: 'username', issue: 'required' },
        { field: 'displayName', issue: 'required' },
      ]),
    );
  });

  it('rejects unknown fields (strict bodies), including nested ones', async () => {
    const res = await ctx.http
      .post('/api/v1/auth/register')
      .send({ ...newUser(), role: 'ADMIN', device: { name: 'x', rooted: true } });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
    expect(res.body.error.details).toEqual(
      expect.arrayContaining([
        { field: 'role', issue: 'unknown_field' },
        { field: 'device.rooted', issue: 'unknown_field' },
      ]),
    );
  });

  // v1.2 (B9): a registered email (any case) is never revealed — same 202, the owner is notified.
  it('answers a duplicate email (case-insensitive) with the same 202 and notifies the owner', async () => {
    const { payload } = await register();
    const before = ctx.mail.sent.length;
    const res = await ctx.http
      .post('/api/v1/auth/register')
      .send(newUser({ email: payload.email.toUpperCase() }));
    expect(res.status).toBe(202);
    expect(res.body).toEqual({ status: 'verification_pending' });
    await ctx.mail.waitFor(payload.email, 'account_exists', before);
    expect(await ctx.prisma.pendingRegistration.count({ where: { email: payload.email } })).toBe(0);
  });

  it('rejects a duplicate username with USERNAME_TAKEN', async () => {
    const { payload } = await register();
    const res = await ctx.http.post('/api/v1/auth/register').send(newUser({ username: payload.username }));
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('USERNAME_TAKEN');
  });

  // v1.2: concurrent registrations for one email never reveal anything and leave one live pending.
  it('concurrent registrations for one email all get 202 and leave exactly one pending row', async () => {
    const base = newUser();
    const results = await Promise.all(
      [0, 1, 2].map((i) =>
        ctx.http.post('/api/v1/auth/register').send({ ...base, username: `${base.username}x${i}` }),
      ),
    );
    expect(results.map((r) => r.status)).toEqual([202, 202, 202]);
    await settle(ctx);
    expect(await ctx.prisma.pendingRegistration.count({ where: { email: base.email } })).toBe(1);
  });

  it('translates database unique violations (race path) to EMAIL_TAKEN / USERNAME_TAKEN', async () => {
    const { payload } = await register();
    const users = ctx.app.get(UsersService);
    const attempt = (email: string, username: string) =>
      ctx.prisma.$transaction((tx) =>
        users.createAccount(tx, { email, username, passwordHash: 'x', displayName: 'Race', locale: 'ar' }),
      );
    await expect(attempt(payload.email, 'fresh_name_1')).rejects.toMatchObject({ code: 'EMAIL_TAKEN' });
    await expect(attempt('fresh1@example.com', payload.username)).rejects.toMatchObject({
      code: 'USERNAME_TAKEN',
    });
  });

  it('enforces the username format in the database (CHECK constraint)', async () => {
    const { body } = await register();
    await expect(
      ctx.prisma.userProfile.update({ where: { userId: body.user.id }, data: { username: 'Bad Name' } }),
    ).rejects.toThrow();
  });

  it('rejects reserved usernames with USERNAME_TAKEN', async () => {
    for (const username of ['admin', 'kabso', 'sup.port']) {
      const res = await ctx.http.post('/api/v1/auth/register').send(newUser({ username }));
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('USERNAME_TAKEN');
    }
  });
});

describe('GET /users/username-availability', () => {
  it('reports taken, free, reserved and malformed names', async () => {
    const { payload } = await register();
    const taken = await ctx.http
      .get('/api/v1/users/username-availability')
      .query({ username: payload.username });
    expect(taken.status).toBe(200);
    expect(taken.body).toEqual({ username: payload.username, available: false });

    const free = await ctx.http
      .get('/api/v1/users/username-availability')
      .query({ username: 'free_name_42' });
    expect(free.body).toEqual({ username: 'free_name_42', available: true });

    const reserved = await ctx.http.get('/api/v1/users/username-availability').query({ username: 'support' });
    expect(reserved.body).toEqual({ username: 'support', available: false });

    const malformed = await ctx.http.get('/api/v1/users/username-availability').query({ username: '_x' });
    expect(malformed.status).toBe(400);
    expect(malformed.body.error.code).toBe('VALIDATION_FAILED');
  });
});

describe('POST /auth/login', () => {
  it('logs in by email (any case) and by username', async () => {
    const { payload, body } = await register();

    const byEmail = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: payload.email.toUpperCase(), password: payload.password });
    expect(byEmail.status).toBe(200);
    expect(byEmail.body.user.id).toBe(body.user.id);
    expect(byEmail.body.tokens.refreshToken).toBeTypeOf('string');

    const byUsername = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: payload.username, password: payload.password, device: { platform: 'ios' } });
    expect(byUsername.status).toBe(200);
    expect(byUsername.body.user.username).toBe(payload.username);
  });

  it('returns an identical 401 for unknown user and wrong password', async () => {
    const { payload } = await register();
    const wrong = await ctx.http
      .post('/api/v1/auth/login')
      .set('X-Request-Id', 'same-id')
      .send({ identifier: payload.email, password: 'wrong password!!' });
    const unknown = await ctx.http
      .post('/api/v1/auth/login')
      .set('X-Request-Id', 'same-id')
      .send({ identifier: 'nobody@example.com', password: 'wrong password!!' });

    expect(wrong.status).toBe(401);
    expect(unknown.status).toBe(401);
    expect(wrong.body).toEqual(unknown.body);
    expect(wrong.body.error.code).toBe('AUTH_INVALID_CREDENTIALS');
  });

  it('refuses suspended accounts with 403 ACCOUNT_SUSPENDED', async () => {
    const { payload, body } = await register();
    await ctx.prisma.user.update({ where: { id: body.user.id }, data: { status: 'SUSPENDED' } });
    const res = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: payload.email, password: payload.password });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ACCOUNT_SUSPENDED');

    // Suspension also takes effect immediately for existing access and refresh tokens.
    const me = await ctx.http.get('/api/v1/me').set(bearer(body.tokens.accessToken));
    expect(me.status).toBe(401);
    const refresh = await ctx.http
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: body.tokens.refreshToken });
    expect(refresh.status).toBe(403);
    expect(refresh.body.error.code).toBe('ACCOUNT_SUSPENDED');
  });

  it('records login success and failure in the audit log', async () => {
    const { payload, body } = await register();
    await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: payload.username, password: 'nope-nope-nope' });
    await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: payload.username, password: payload.password });
    const actions = (
      await ctx.prisma.auditLog.findMany({
        where: { actorUserId: body.user.id },
        orderBy: { createdAt: 'asc' },
      })
    ).map((a) => a.action);
    // v1.2: the account is created by register/verify.
    expect(actions).toEqual(['auth.registration.verified', 'auth.login.failure', 'auth.login.success']);
  });
});

describe('GET /me', () => {
  it('returns the current user with a valid token', async () => {
    const { body } = await register();
    const res = await ctx.http.get('/api/v1/me').set(bearer(body.tokens.accessToken));
    expect(res.status).toBe(200);
    expect(res.body).toEqual(body.user);
  });

  it('returns 401 AUTH_UNAUTHENTICATED without or with a bad token', async () => {
    const none = await ctx.http.get('/api/v1/me');
    expect(none.status).toBe(401);
    expect(none.body.error.code).toBe('AUTH_UNAUTHENTICATED');
    expect(none.body.error.requestId).toBe(none.headers['x-request-id']);

    const { body } = await register();
    const tampered = `${body.tokens.accessToken.slice(0, -2)}xx`;
    const bad = await ctx.http.get('/api/v1/me').set(bearer(tampered));
    expect(bad.status).toBe(401);
    expect(bad.body.error.code).toBe('AUTH_UNAUTHENTICATED');
  });
});

describe('POST /auth/refresh', () => {
  it('rotates: returns a new pair and the old refresh token stops working', async () => {
    const { body } = await register();
    const first = await ctx.http
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: body.tokens.refreshToken });
    expect(first.status).toBe(200);
    expect(Object.keys(first.body).sort()).toEqual([
      'accessToken',
      'accessTokenExpiresAt',
      'refreshToken',
      'refreshTokenExpiresAt',
    ]);
    expect(first.body.refreshToken).not.toBe(body.tokens.refreshToken);
    expect(first.body.refreshToken.split('.')[0]).toBe(body.tokens.refreshToken.split('.')[0]);

    const me = await ctx.http.get('/api/v1/me').set(bearer(first.body.accessToken));
    expect(me.status).toBe(200);

    const replay = await ctx.http
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: body.tokens.refreshToken });
    expect(replay.status).toBe(401);
    expect(replay.body.error.code).toBe('AUTH_REFRESH_INVALID');
  });

  it('detects reuse: replaying a rotated token revokes the whole session', async () => {
    const { body } = await register();
    const rotated = await ctx.http
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: body.tokens.refreshToken });
    expect(rotated.status).toBe(200);

    const reuse = await ctx.http
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: body.tokens.refreshToken });
    expect(reuse.status).toBe(401);
    expect(reuse.body.error.code).toBe('AUTH_REFRESH_INVALID');

    // The legitimately rotated tokens are now dead too.
    const me = await ctx.http.get('/api/v1/me').set(bearer(rotated.body.accessToken));
    expect(me.status).toBe(401);
    const next = await ctx.http
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: rotated.body.refreshToken });
    expect(next.status).toBe(401);

    const sessionId = body.tokens.refreshToken.split('.')[0];
    const session = await ctx.prisma.session.findUniqueOrThrow({ where: { id: sessionId } });
    expect(session.revokedReason).toBe('REFRESH_REUSE');
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { action: 'auth.refresh.reuse', targetId: sessionId },
    });
    expect(audit?.metadata).toMatchObject({ matchedPrevious: true });
  });

  it('lets exactly one of several concurrent refreshes with the same token succeed', async () => {
    const { body } = await register();
    const results = await Promise.all(
      Array.from({ length: 5 }, () =>
        ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: body.tokens.refreshToken }),
      ),
    );
    const ok = results.filter((r) => r.status === 200);
    expect(ok).toHaveLength(1);
    for (const r of results.filter((x) => x.status !== 200)) {
      expect(r.status).toBe(401);
      expect(r.body.error.code).toBe('AUTH_REFRESH_INVALID');
    }
  });

  it('rejects malformed, unknown and expired refresh tokens', async () => {
    const malformed = await ctx.http
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: 'garbage-token-value' });
    expect(malformed.status).toBe(401);
    expect(malformed.body.error.code).toBe('AUTH_REFRESH_INVALID');

    const unknown = await ctx.http
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: `0192f1c2-0000-7000-8000-000000000000.${'A'.repeat(43)}` });
    expect(unknown.status).toBe(401);

    const { body } = await register();
    const sessionId = body.tokens.refreshToken.split('.')[0];
    await ctx.prisma.session.update({
      where: { id: sessionId },
      data: { expiresAt: new Date(Date.now() - 1000) },
    });
    const expired = await ctx.http
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: body.tokens.refreshToken });
    expect(expired.status).toBe(401);
    expect(expired.body.error.code).toBe('AUTH_REFRESH_INVALID');
  });
});

describe('POST /auth/logout', () => {
  it('revokes the session: the access token is rejected immediately', async () => {
    const { body } = await register();
    const out = await ctx.http.post('/api/v1/auth/logout').set(bearer(body.tokens.accessToken));
    expect(out.status).toBe(204);
    expect(out.text).toBe('');

    const me = await ctx.http.get('/api/v1/me').set(bearer(body.tokens.accessToken));
    expect(me.status).toBe(401);
    const refresh = await ctx.http
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: body.tokens.refreshToken });
    expect(refresh.status).toBe(401);
  });

  it('requires authentication', async () => {
    const res = await ctx.http.post('/api/v1/auth/logout');
    expect(res.status).toBe(401);
  });
});

describe('sessions', () => {
  it('lists active sessions newest first with the current flag', async () => {
    const { payload, body } = await register();
    const second = await ctx.http.post('/api/v1/auth/login').send({
      identifier: payload.email,
      password: payload.password,
      device: { name: 'iPhone', platform: 'ios' },
    });
    expect(second.status).toBe(200);

    const res = await ctx.http.get('/api/v1/auth/sessions').set(bearer(second.body.tokens.accessToken));
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(2);
    const [newest, oldest] = res.body.data;
    expect(newest).toEqual({
      id: second.body.tokens.refreshToken.split('.')[0],
      current: true,
      deviceName: 'iPhone',
      platform: 'ios',
      appVersion: null,
      ipCountry: null,
      createdAt: expect.stringMatching(ISO),
      lastUsedAt: expect.stringMatching(ISO),
    });
    expect(oldest.id).toBe(body.tokens.refreshToken.split('.')[0]);
    expect(oldest.current).toBe(false);
  });

  it("revokes own sessions and returns 404 for other users' sessions", async () => {
    const alice = await register();
    const bob = await register();
    const bobSessionId = bob.body.tokens.refreshToken.split('.')[0];

    const foreign = await ctx.http
      .delete(`/api/v1/auth/sessions/${bobSessionId}`)
      .set(bearer(alice.body.tokens.accessToken));
    expect(foreign.status).toBe(404);
    expect(foreign.body.error.code).toBe('NOT_FOUND');
    const bobMe = await ctx.http.get('/api/v1/me').set(bearer(bob.body.tokens.accessToken));
    expect(bobMe.status).toBe(200);

    const malformed = await ctx.http
      .delete('/api/v1/auth/sessions/not-a-uuid')
      .set(bearer(alice.body.tokens.accessToken));
    expect(malformed.status).toBe(404);

    // Alice revokes her first session from a second one.
    const second = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: alice.payload.username, password: alice.payload.password });
    const aliceFirst = alice.body.tokens.refreshToken.split('.')[0];
    const own = await ctx.http
      .delete(`/api/v1/auth/sessions/${aliceFirst}`)
      .set(bearer(second.body.tokens.accessToken));
    expect(own.status).toBe(204);
    const revokedMe = await ctx.http.get('/api/v1/me').set(bearer(alice.body.tokens.accessToken));
    expect(revokedMe.status).toBe(401);
    const again = await ctx.http
      .delete(`/api/v1/auth/sessions/${aliceFirst}`)
      .set(bearer(second.body.tokens.accessToken));
    expect(again.status).toBe(404);
  });
});
