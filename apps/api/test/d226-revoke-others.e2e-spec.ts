/**
 * v1.79-social (D226, CONVENTIONS §10.76): «تسجيل الخروج من كل الأجهزة الأخرى» — `revokeOtherSessions`
 * (`POST /auth/sessions/revoke-others`). End to end against PostgreSQL + Redis.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

const PATH = '/api/v1/auth/sessions/revoke-others';
const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

interface Tokens {
  accessToken: string;
  refreshToken: string;
}

const sid = (t: Tokens) => t.refreshToken.split('.')[0]!;

let ctx: TestContext;

beforeAll(async () => {
  ctx = await createTestApp();
});

afterAll(async () => {
  await ctx?.close();
});

/** A verified account signed in on [devices] devices (the first one from register/verify). */
async function signedIn(c: TestContext, devices: number) {
  const { payload, res } = await registerVerified(c);
  expect(res.status).toBe(201);
  const userId = (res.body as { user: { id: string } }).user.id;
  const tokens: Tokens[] = [res.body.tokens as Tokens];
  for (let i = 1; i < devices; i++) {
    const login = await c.http.post('/api/v1/auth/login').send({
      identifier: payload.email,
      password: payload.password,
      device: { name: `Phone ${i}`, platform: 'ios' },
    });
    expect(login.status).toBe(200);
    tokens.push(login.body.tokens as Tokens);
  }
  return { payload, userId, tokens };
}

describe('POST /auth/sessions/revoke-others', () => {
  it('ends only the other sessions; this one keeps working; the others get 401 (access and refresh)', async () => {
    const alice = await signedIn(ctx, 4);
    const bob = await signedIn(ctx, 1);
    const [first, second, third, current] = alice.tokens as [Tokens, Tokens, Tokens, Tokens];

    const res = await ctx.http
      .post(PATH)
      .set(bearer(current.accessToken))
      .send({ password: alice.payload.password });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ revoked: 3 });
    expectContract(res, 'revokeOtherSessions');

    // The calling session stays.
    expect((await ctx.http.get('/api/v1/me').set(bearer(current.accessToken))).status).toBe(200);
    const list = await ctx.http.get('/api/v1/auth/sessions').set(bearer(current.accessToken));
    expect(list.status).toBe(200);
    expect(list.body.data.map((s: { id: string; current: boolean }) => [s.id, s.current])).toEqual([
      [sid(current), true],
    ]);
    const refreshed = await ctx.http
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: current.refreshToken });
    expect(refreshed.status).toBe(200);

    // The others: access tokens and refresh tokens are dead at once.
    for (const t of [first, second, third]) {
      const me = await ctx.http.get('/api/v1/me').set(bearer(t.accessToken));
      expect(me.status).toBe(401);
      const refresh = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: t.refreshToken });
      expect(refresh.status).toBe(401);
      expect(refresh.body.error.code).toBe('AUTH_REFRESH_INVALID');
    }
    const rows = await ctx.prisma.session.findMany({ where: { userId: alice.userId } });
    for (const row of rows) {
      if (row.id === sid(current)) expect(row.revokedAt).toBeNull();
      else expect(row.revokedReason).toBe('USER_REVOKED');
    }

    // Someone else's sessions are untouched.
    expect((await ctx.http.get('/api/v1/me').set(bearer(bob.tokens[0]!.accessToken))).status).toBe(200);

    // Audited with the count.
    const audit = await ctx.prisma.auditLog.findMany({
      where: { actorUserId: alice.userId, action: 'auth.sessions.revoke_others' },
    });
    expect(audit).toHaveLength(1);
    expect(audit[0]?.targetId).toBe(sid(current));
    expect(audit[0]?.metadata).toEqual({ count: 3 });

    // Again: nothing left to end.
    const again = await ctx.http
      .post(PATH)
      .set(bearer(current.accessToken))
      .send({ password: alice.payload.password });
    expect(again.status).toBe(200);
    expect(again.body).toEqual({ revoked: 0 });
  });

  it("drops the other sessions' push tokens, keeps this one's", async () => {
    const carol = await signedIn(ctx, 2);
    const [other, current] = carol.tokens as [Tokens, Tokens];
    for (const t of [other, current]) {
      await ctx.prisma.deviceToken.create({
        data: {
          userId: carol.userId,
          sessionId: sid(t),
          token: `fcm-${sid(t)}`,
          platform: 'ANDROID',
          appVersion: '1.0.0',
        },
      });
    }
    const res = await ctx.http
      .post(PATH)
      .set(bearer(current.accessToken))
      .send({ password: carol.payload.password });
    expect(res.body).toEqual({ revoked: 1 });
    const tokens = await ctx.prisma.deviceToken.findMany({ where: { userId: carol.userId } });
    expect(tokens.map((t) => t.sessionId)).toEqual([sid(current)]);
  });

  it('wrong password: 403 REAUTH_FAILED, audited, nothing ended', async () => {
    const dan = await signedIn(ctx, 2);
    const [other, current] = dan.tokens as [Tokens, Tokens];
    const res = await ctx.http
      .post(PATH)
      .set(bearer(current.accessToken))
      .send({ password: 'not the password' });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('REAUTH_FAILED');
    expectContract(res, 'revokeOtherSessions');
    expect((await ctx.http.get('/api/v1/me').set(bearer(other.accessToken))).status).toBe(200);
    const audit = await ctx.prisma.auditLog.findMany({
      where: { actorUserId: dan.userId, action: 'auth.sessions.revoke_others.reauth_failed' },
    });
    expect(audit).toHaveLength(1);
  });

  it('400 for a bad body, 401 without a session', async () => {
    const eve = await signedIn(ctx, 1);
    const token = eve.tokens[0]!.accessToken;
    for (const body of [{}, { password: '' }, { password: 'x', extra: true }]) {
      const res = await ctx.http.post(PATH).set(bearer(token)).send(body);
      expect(res.status).toBe(400);
      expectContract(res, 'revokeOtherSessions');
    }
    const anonymous = await ctx.http.post(PATH).send({ password: 'whatever' });
    expect(anonymous.status).toBe(401);
    expectContract(anonymous, 'revokeOtherSessions');
  });
});

describe('rate limit (the re-authentication rule, own bucket)', () => {
  let limited: TestContext;

  beforeAll(async () => {
    await ctx.close();
    limited = await createTestApp({ RATE_LIMIT_ACCOUNT_DELETION_USER: '2/900' });
  });

  afterAll(async () => {
    await limited?.close();
    ctx = await createTestApp();
  });

  it('5 / 15 min per user by default; here 2: the third call is 429, failed passwords count', async () => {
    const frank = await signedIn(limited, 2);
    const token = frank.tokens[1]!.accessToken;
    const wrong = await limited.http.post(PATH).set(bearer(token)).send({ password: 'wrong' });
    expect(wrong.status).toBe(403);
    const right = await limited.http.post(PATH).set(bearer(token)).send({ password: frank.payload.password });
    expect(right.status).toBe(200);
    const third = await limited.http.post(PATH).set(bearer(token)).send({ password: frank.payload.password });
    expect(third.status).toBe(429);
    expect(third.body.error.code).toBe('RATE_LIMITED');
    expectContract(third, 'revokeOtherSessions');
    // Its own bucket: the account-deletion bucket (same rule) of the same user is untouched — a wrong password
    // there is still checked (403), not limited.
    const deletion = await limited.http
      .post('/api/v1/me/account-deletion')
      .set(bearer(token))
      .send({ password: 'wrong', confirmation: 'DELETE' });
    expect(deletion.status).toBe(403);
  });
});
