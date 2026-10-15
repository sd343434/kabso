/**
 * KL-011 regression tests for the KL-007 security findings (contract v1.1) and QA-001/QA-002.
 */
import { createHash, randomBytes } from 'node:crypto';
import { Redis } from 'ioredis';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { RateLimitService } from '../src/common/rate-limit/rate-limit.service.js';
import { createTestApp, newUser, type TestContext } from './helpers/test-app.js';

const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });
const NFC = 'café passphrase';
const NFD = 'café passphrase';

async function register(ctx: TestContext, overrides: Partial<Record<string, unknown>> = {}) {
  const payload = newUser(overrides);
  const res = await ctx.http.post('/api/v1/auth/register').send(payload);
  expect(res.status).toBe(201);
  return {
    payload,
    userId: res.body.user.id as string,
    accessToken: res.body.tokens.accessToken as string,
    refreshToken: res.body.tokens.refreshToken as string,
    sessionId: (res.body.tokens.refreshToken as string).split('.')[0]!,
  };
}

describe('KL-011 (default limits)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
  });

  afterAll(async () => {
    await ctx?.close();
  });

  describe('SEC-001 / QA-001: refresh revocation needs the previous secret', () => {
    it('a sid-derived garbage refresh token is refused WITHOUT revoking the session', async () => {
      const victim = await register(ctx);
      // The attacker only knows the public sid (JWT claim) and makes up a secret.
      const forged = `${victim.sessionId}.${randomBytes(32).toString('base64url')}`;
      for (let i = 0; i < 3; i += 1) {
        const res = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: forged });
        expect(res.status).toBe(401);
        expect(res.body.error.code).toBe('AUTH_REFRESH_INVALID');
      }

      const session = await ctx.prisma.session.findUniqueOrThrow({ where: { id: victim.sessionId } });
      expect(session.revokedAt).toBeNull();
      expect((await ctx.http.get('/api/v1/me').set(bearer(victim.accessToken))).status).toBe(200);
      const genuine = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: victim.refreshToken });
      expect(genuine.status).toBe(200);

      const audits = await ctx.prisma.auditLog.findMany({
        where: { action: 'auth.refresh.invalid_secret', targetId: victim.sessionId },
      });
      expect(audits).toHaveLength(3);
      expect(audits.every((a) => a.actorUserId === null)).toBe(true);
      expect(JSON.stringify(audits)).not.toContain(forged.split('.')[1]);
      const reuse = await ctx.prisma.auditLog.count({
        where: { action: 'auth.refresh.reuse', targetId: victim.sessionId },
      });
      expect(reuse).toBe(0);
    });

    it('the immediately previous secret DOES revoke the session (reuse)', async () => {
      const user = await register(ctx);
      const rotated = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: user.refreshToken });
      expect(rotated.status).toBe(200);

      const replay = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: user.refreshToken });
      expect(replay.status).toBe(401);
      expect(replay.body.error.code).toBe('AUTH_REFRESH_INVALID');

      const session = await ctx.prisma.session.findUniqueOrThrow({ where: { id: user.sessionId } });
      expect(session.revokedReason).toBe('REFRESH_REUSE');
      expect((await ctx.http.get('/api/v1/me').set(bearer(rotated.body.accessToken))).status).toBe(401);
      const audit = await ctx.prisma.auditLog.findFirstOrThrow({
        where: { action: 'auth.refresh.reuse', targetId: user.sessionId },
      });
      expect(audit.metadata).toMatchObject({ matchedPrevious: true });
    });

    it('a secret two rotations old is refused without revoking', async () => {
      const user = await register(ctx);
      const r1 = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: user.refreshToken });
      const r2 = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: r1.body.refreshToken });
      expect(r2.status).toBe(200);
      const stale = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: user.refreshToken });
      expect(stale.status).toBe(401);
      expect((await ctx.http.get('/api/v1/me').set(bearer(r2.body.accessToken))).status).toBe(200);
    });
  });

  describe('QA-002: Authorization scheme is case-insensitive', () => {
    it.each(['bearer', 'BEARER', 'Bearer', 'bEaReR'])('%s <token> → 200', async (scheme) => {
      const user = await register(ctx);
      const res = await ctx.http.get('/api/v1/me').set('Authorization', `${scheme} ${user.accessToken}`);
      expect(res.status).toBe(200);
    });

    it('other schemes are still refused', async () => {
      const user = await register(ctx);
      const res = await ctx.http.get('/api/v1/me').set('Authorization', `Basic ${user.accessToken}`);
      expect(res.status).toBe(401);
    });
  });

  describe('SEC-006: Cache-Control: no-store', () => {
    it('is set on success and error responses', async () => {
      const user = await register(ctx);
      const responses = {
        login: await ctx.http
          .post('/api/v1/auth/login')
          .send({ identifier: user.payload.email, password: user.payload.password }),
        refresh: await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: user.refreshToken }),
        me: await ctx.http.get('/api/v1/me').set(bearer(user.accessToken)),
        unauthenticated: await ctx.http.get('/api/v1/me'),
        validation: await ctx.http.post('/api/v1/auth/login').send({}),
        malformedJson: await ctx.http
          .post('/api/v1/auth/login')
          .set('Content-Type', 'application/json')
          .send('{"x":'),
        notFound: await ctx.http.get('/api/v1/does-not-exist'),
        noContent: await ctx.http.post('/api/v1/auth/password/forgot').send({ email: 'x@example.com' }),
      };
      const summary = Object.fromEntries(
        Object.entries(responses).map(([k, r]) => [k, r.headers['cache-control']]),
      );
      expect(summary).toEqual(Object.fromEntries(Object.keys(responses).map((k) => [k, 'no-store'])));
      expect(responses.login.status).toBe(200);
      expect(responses.unauthenticated.status).toBe(401);
      expect(responses.malformedJson.status).toBe(400);
    });
  });

  describe('SEC-008: unsafe characters in free text', () => {
    it.each([
      ['bidi override', 'admin‮gnp.exe'],
      ['bidi isolate', 'a⁦b'],
      ['zero-width space', 'Kab​so Official'],
      ['C1 control', 'a\u0085b'],
      ['ANSI escape', 'evil\u001b[31mred'],
    ])('rejects %s in displayName and device.name', async (_label, text) => {
      const display = await ctx.http.post('/api/v1/auth/register').send(newUser({ displayName: text }));
      expect(display.status).toBe(400);
      expect(display.body.error.details).toEqual([{ field: 'displayName', issue: 'invalid_format' }]);

      const device = await ctx.http
        .post('/api/v1/auth/register')
        .send(newUser({ device: { name: text, platform: 'android' } }));
      expect(device.status).toBe(400);
      expect(device.body.error.details).toEqual([{ field: 'device.name', issue: 'invalid_format' }]);
    });
  });

  describe('SEC-016: NFC password normalization', () => {
    it('registering with NFC and logging in with NFD (and vice versa) succeeds', async () => {
      const nfcUser = await register(ctx, { password: NFC });
      const loginNfd = await ctx.http
        .post('/api/v1/auth/login')
        .send({ identifier: nfcUser.payload.email, password: NFD });
      expect(loginNfd.status).toBe(200);

      const nfdUser = await register(ctx, { password: NFD });
      const loginNfc = await ctx.http
        .post('/api/v1/auth/login')
        .send({ identifier: nfdUser.payload.username, password: NFC });
      expect(loginNfc.status).toBe(200);
    });

    it('password reset stores the NFC form', async () => {
      const user = await register(ctx);
      await ctx.http.post('/api/v1/auth/password/forgot').send({ email: user.payload.email });
      const mail = await ctx.mail.waitFor(user.payload.email, 'reset');
      const reset = await ctx.http
        .post('/api/v1/auth/password/reset')
        .send({ token: mail.token, newPassword: NFD });
      expect(reset.status).toBe(204);
      const login = await ctx.http
        .post('/api/v1/auth/login')
        .send({ identifier: user.payload.email, password: NFC });
      expect(login.status).toBe(200);
    });
  });

  describe('SEC-010: HMAC rate-limit keys', () => {
    it('Redis keys are HMACs under the server key, not plain hashes of the subject', async () => {
      const email = `hmac-${Date.now()}@example.com`;
      await ctx.http.post('/api/v1/auth/password/forgot').send({ email });
      const limiter = ctx.app.get(RateLimitService);
      const expected = `${ctx.config.redis.keyPrefix}${limiter.keyFor('forgot:email', email)}`;
      const plain = createHash('sha256').update(email).digest('base64url').slice(0, 32);

      const redis = new Redis(ctx.config.redis.url, { lazyConnect: true, maxRetriesPerRequest: 1 });
      await redis.connect();
      try {
        const keys = await redis.keys(`${ctx.config.redis.keyPrefix}rl:forgot:email:*`);
        expect(keys).toContain(expected);
        expect(keys.some((k) => k.includes(plain))).toBe(false);
        expect(keys.some((k) => k.includes(email))).toBe(false);
      } finally {
        redis.disconnect();
      }
    });
  });
});

describe('KL-011 per-account login limit (SEC-002 / SEC-009)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    // TRUST_PROXY=loopback lets the test present different client IPs via X-Forwarded-For.
    ctx = await createTestApp({ TRUST_PROXY: 'loopback', RATE_LIMIT_LOGIN_ACCOUNT: '4/900' });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('email and username of one account share one bucket across IPs', async () => {
    const user = await register(ctx);
    const identifiers = [
      user.payload.email,
      user.payload.username,
      user.payload.email.toUpperCase(),
      user.payload.username,
    ];
    const statuses: number[] = [];
    for (const [i, identifier] of identifiers.entries()) {
      const res = await ctx.http
        .post('/api/v1/auth/login')
        .set('X-Forwarded-For', `198.51.100.${i + 1}`)
        .send({ identifier, password: 'wrong password!!' });
      statuses.push(res.status);
    }
    expect(statuses).toEqual([401, 401, 401, 401]);

    // Fifth attempt — new IP, other spelling, even the correct password — is limited.
    const limited = await ctx.http
      .post('/api/v1/auth/login')
      .set('X-Forwarded-For', '203.0.113.200')
      .send({ identifier: user.payload.username, password: user.payload.password });
    expect(limited.status).toBe(429);
    expect(limited.body.error.code).toBe('RATE_LIMITED');
    expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
    const audit = await ctx.prisma.auditLog.count({
      where: { action: 'auth.login.rate_limited', actorUserId: user.userId },
    });
    expect(audit).toBe(1);

    // Another account is unaffected.
    const other = await register(ctx);
    const ok = await ctx.http
      .post('/api/v1/auth/login')
      .set('X-Forwarded-For', '198.51.100.1')
      .send({ identifier: other.payload.email, password: other.payload.password });
    expect(ok.status).toBe(200);
  });

  it('unknown identifiers are bucketed by normalized identifier', async () => {
    const send = (identifier: string, ip: string) =>
      ctx.http
        .post('/api/v1/auth/login')
        .set('X-Forwarded-For', ip)
        .send({ identifier, password: 'whatever-123' });
    const statuses = [
      (await send('ghost@example.com', '192.0.2.1')).status,
      (await send(' GHOST@example.com ', '192.0.2.2')).status,
      (await send('Ghost@Example.com', '192.0.2.3')).status,
      (await send('ghost@example.com', '192.0.2.4')).status,
      (await send('ghost@EXAMPLE.com', '192.0.2.5')).status,
    ];
    expect(statuses).toEqual([401, 401, 401, 401, 429]);
  });
});

describe('KL-011 IPv6 /64 grouping (SEC-002)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ TRUST_PROXY: 'loopback', RATE_LIMIT_REGISTER_IP: '2/3600' });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('addresses in one /64 share the per-IP bucket; another /64 does not', async () => {
    const attempt = (ip: string) =>
      ctx.http.post('/api/v1/auth/register').set('X-Forwarded-For', ip).send(newUser());
    expect((await attempt('2001:db8:1:2::1')).status).toBe(201);
    expect((await attempt('2001:db8:1:2:ffff:ffff:ffff:fffe')).status).toBe(201);
    const third = await attempt('2001:db8:1:2:abcd::99');
    expect(third.status).toBe(429);
    expect(third.body.error.code).toBe('RATE_LIMITED');
    expect((await attempt('2001:db8:1:3::1')).status).toBe(201);
  });
});

describe('KL-011 Argon2 concurrency cap (SEC-002)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ ARGON2_MAX_CONCURRENCY: '1', ARGON2_MAX_QUEUE: '0' });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('answers 503 SERVICE_UNAVAILABLE with Retry-After when hashing capacity is saturated', async () => {
    const results = await Promise.all(
      Array.from({ length: 8 }, (_, i) =>
        ctx.http
          .post('/api/v1/auth/login')
          .send({ identifier: `nobody${i}@example.com`, password: 'x'.repeat(12) }),
      ),
    );
    const statuses = results.map((r) => r.status);
    expect(statuses).toContain(401);
    const shed = results.filter((r) => r.status === 503);
    expect(shed.length).toBeGreaterThan(0);
    for (const r of shed) {
      expect(r.body.error.code).toBe('SERVICE_UNAVAILABLE');
      expect(r.headers['retry-after']).toBe('1');
    }
    expect(statuses.every((s) => s === 401 || s === 503)).toBe(true);
  });
});
