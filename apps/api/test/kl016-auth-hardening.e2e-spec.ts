/**
 * KL-016 (contract v1.2): SEC-022 refresh reuse across the last 10 rotated secrets and SEC-023
 * failed-only account bucket with a recent-success source bypass. SEC-003a is a config rule
 * (unit-tested in app-config.spec.ts).
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

describe('SEC-022 refresh reuse across the rotation history', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
  });

  afterAll(async () => {
    await ctx?.close();
  });

  async function session() {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      refreshToken: res.body.tokens.refreshToken as string,
      sessionId: (res.body.tokens.refreshToken as string).split('.')[0]!,
    };
  }

  const refresh = (refreshToken: string) => ctx.http.post('/api/v1/auth/refresh').send({ refreshToken });

  it('two-rotation thief: a stolen token replayed after two victim rotations revokes the session', async () => {
    const { refreshToken: stolen, sessionId } = await session();
    // The victim keeps using the app: two rotations.
    const v1 = await refresh(stolen);
    const v2 = await refresh(v1.body.refreshToken);
    expect(v2.status).toBe(200);

    // The thief replays the stolen (now two-rotations-old) token.
    const thief = await refresh(stolen);
    expect(thief.status).toBe(401);
    expect(thief.body.error.code).toBe('AUTH_REFRESH_INVALID');

    // The whole session is dead: the victim must sign in again, and the thief got nothing.
    expect((await ctx.http.get('/api/v1/me').set(bearer(v2.body.accessToken))).status).toBe(401);
    expect((await refresh(v2.body.refreshToken)).status).toBe(401);
    const row = await ctx.prisma.session.findUniqueOrThrow({ where: { id: sessionId } });
    expect(row.revokedReason).toBe('REFRESH_REUSE');
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'auth.refresh.reuse', targetId: sessionId },
    });
    expect(audit.metadata).toMatchObject({ matchedPrevious: false, rotationsAgo: 2 });
  });

  it('thief rotates first: the victim presenting the old token kills the thief session', async () => {
    const { refreshToken: stolen, sessionId } = await session();
    const thief1 = await refresh(stolen);
    const thief2 = await refresh(thief1.body.refreshToken);
    expect(thief2.status).toBe(200);
    // The victim's app still holds the original token.
    expect((await refresh(stolen)).status).toBe(401);
    expect((await ctx.http.get('/api/v1/me').set(bearer(thief2.body.accessToken))).status).toBe(401);
    const row = await ctx.prisma.session.findUniqueOrThrow({ where: { id: sessionId } });
    expect(row.revokedReason).toBe('REFRESH_REUSE');
  });

  it('keeps exactly the last 10 rotated hashes; older or never-issued secrets do not revoke', async () => {
    const { refreshToken: first, sessionId } = await session();
    const issued = [first];
    for (let i = 0; i < 11; i += 1) {
      const res = await refresh(issued[issued.length - 1]!);
      expect(res.status).toBe(200);
      issued.push(res.body.refreshToken as string);
    }
    const row = await ctx.prisma.session.findUniqueOrThrow({ where: { id: sessionId } });
    expect(row.rotatedRefreshTokenHashes).toHaveLength(10);

    // `first` is 11 rotations old: outside the history → plain 401, session kept.
    const ancient = await refresh(first);
    expect(ancient.status).toBe(401);
    // Never issued for this session (built from the public sid) → plain 401, session kept.
    const forged = await refresh(`${sessionId}.${'Q'.repeat(43)}`);
    expect(forged.status).toBe(401);
    const live = await ctx.prisma.session.findUniqueOrThrow({ where: { id: sessionId } });
    expect(live.revokedAt).toBeNull();
    const current = issued[issued.length - 1]!;
    const ok = await refresh(current);
    expect(ok.status).toBe(200);

    // issued[3] is 9 rotations old now (inside the 10-entry history) → reuse → revoke.
    expect((await refresh(issued[3]!)).status).toBe(401);
    const revoked = await ctx.prisma.session.findUniqueOrThrow({ where: { id: sessionId } });
    expect(revoked.revokedReason).toBe('REFRESH_REUSE');
  });
});

describe('SEC-023 failed-only account bucket with recent-success bypass', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ TRUST_PROXY: 'loopback', RATE_LIMIT_LOGIN_ACCOUNT: '3/900' });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  const login = (identifier: string, password: string, ip: string) =>
    ctx.http.post('/api/v1/auth/login').set('X-Forwarded-For', ip).send({ identifier, password });

  it('counts failed attempts only (successful logins do not consume the account bucket)', async () => {
    const { payload } = await registerVerified(ctx);
    for (let i = 1; i <= 5; i += 1) {
      expect((await login(payload.email, payload.password, `198.51.100.${i}`)).status).toBe(200);
    }
    const statuses: number[] = [];
    for (let i = 1; i <= 4; i += 1) {
      statuses.push((await login(payload.username, 'wrong password!!', `203.0.113.${i}`)).status);
    }
    // 3 failures allowed, the 4th attempt from an untrusted source is limited.
    expect(statuses).toEqual([401, 401, 401, 429]);
  });

  it('the owner is not locked out from a source with a recent successful login', async () => {
    const { payload } = await registerVerified(ctx);
    // The owner logs in from home (IPv6; the whole /64 becomes a trusted source).
    expect((await login(payload.email, payload.password, '2001:db8:aa:bb::10')).status).toBe(200);

    // An attacker exhausts the account bucket from elsewhere.
    for (let i = 1; i <= 3; i += 1) {
      expect((await login(payload.email, 'guess guess guess', `192.0.2.${i}`)).status).toBe(401);
    }
    const attacker = await login(payload.email, payload.password, '192.0.2.99');
    expect(attacker.status).toBe(429);
    expect(attacker.body.error.code).toBe('RATE_LIMITED');

    // The owner, from another address in the same /64, still gets in.
    expect((await login(payload.username, payload.password, '2001:db8:aa:bb::77')).status).toBe(200);
    // ...and a wrong password from the owner's source is still evaluated (401, not 429).
    expect((await login(payload.username, 'typo typo typo', '2001:db8:aa:bb::77')).status).toBe(401);
  });

  it('recent-success keys are HMACed in Redis (no raw IPs or ids)', async () => {
    const { payload, res } = await registerVerified(ctx);
    expect((await login(payload.email, payload.password, '198.51.100.250')).status).toBe(200);
    const { Redis } = await import('ioredis');
    const redis = new Redis(ctx.config.redis.url, { lazyConnect: true, maxRetriesPerRequest: 1 });
    await redis.connect();
    try {
      const keys = await redis.keys(`${ctx.config.redis.keyPrefix}rl:login:recent_success:*`);
      expect(keys.length).toBeGreaterThan(0);
      const userId = res.body.user.id as string;
      for (const key of keys) expect(key).not.toMatch(/198\.51\.100|2001:db8/);
      for (const key of keys) expect(key).not.toContain(userId);
      const ttl = await redis.ttl(keys[0]!);
      expect(ttl).toBeGreaterThan(29 * 24 * 3600);
    } finally {
      redis.disconnect();
    }
  });
});
