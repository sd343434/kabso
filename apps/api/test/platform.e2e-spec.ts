import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

describe('platform', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('GET /health/live and /health/ready report ok', async () => {
    const live = await ctx.http.get('/health/live');
    expect(live.status).toBe(200);
    expect(live.body).toEqual({ status: 'ok' });

    const ready = await ctx.http.get('/health/ready');
    expect(ready.status).toBe(200);
    expect(ready.body).toEqual({ status: 'ok', checks: { database: 'ok', redis: 'ok' } });
  });

  it('echoes a valid inbound X-Request-Id and replaces an invalid one', async () => {
    const valid = await ctx.http.get('/health/live').set('X-Request-Id', 'client.req-42_A');
    expect(valid.headers['x-request-id']).toBe('client.req-42_A');

    const invalid = await ctx.http.get('/health/live').set('X-Request-Id', 'bad id with spaces');
    expect(invalid.headers['x-request-id']).toMatch(/^[0-9a-f-]{36}$/);

    const tooLong = await ctx.http.get('/health/live').set('X-Request-Id', 'a'.repeat(65));
    expect(tooLong.headers['x-request-id']).not.toBe('a'.repeat(65));
  });

  it('unknown routes use the error envelope with the request id', async () => {
    const res = await ctx.http.get('/api/v1/nope').set('X-Request-Id', 'rid-404');
    expect(res.status).toBe(404);
    expect(res.body).toEqual({
      error: { code: 'NOT_FOUND', message: expect.any(String), requestId: 'rid-404' },
    });
  });

  it('malformed JSON is VALIDATION_FAILED, never a stack trace', async () => {
    const res = await ctx.http
      .post('/api/v1/auth/login')
      .set('Content-Type', 'application/json')
      .set('X-Request-Id', 'rid-json')
      .send('{"identifier": ');
    expect(res.status).toBe(400);
    expect(res.body.error).toEqual({
      code: 'VALIDATION_FAILED',
      message: expect.any(String),
      details: [{ field: '', issue: 'malformed_json' }],
      requestId: 'rid-json',
    });
  });

  it('oversized bodies are rejected before parsing', async () => {
    const res = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: 'someone', password: 'x'.repeat(200_000) });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
    expect(res.body.error.details).toEqual([{ field: '', issue: 'payload_too_large' }]);
  });

  it('sets security headers', async () => {
    const res = await ctx.http.get('/health/live');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['x-powered-by']).toBeUndefined();
  });
});

describe('rate limiting', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({
      RATE_LIMIT_LOGIN_IP_ACCOUNT: '3/900',
      RATE_LIMIT_FORGOT_EMAIL: '2/3600',
      RATE_LIMIT_AUTHENTICATED_USER: '4/900',
    });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('login: 429 RATE_LIMITED with Retry-After after the per IP+identifier limit', async () => {
    const attempt = () =>
      ctx.http
        .post('/api/v1/auth/login')
        .send({ identifier: 'victim@example.com', password: 'whatever-123' });
    for (let i = 0; i < 3; i++) expect((await attempt()).status).toBe(401);

    const limited = await attempt();
    expect(limited.status).toBe(429);
    expect(limited.body.error.code).toBe('RATE_LIMITED');
    expect(limited.body.error.requestId).toBe(limited.headers['x-request-id']);
    const retryAfter = Number(limited.headers['retry-after']);
    expect(retryAfter).toBeGreaterThan(0);
    expect(retryAfter).toBeLessThanOrEqual(900);

    // A different identifier from the same IP is still allowed (per IP+identifier rule).
    const other = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: 'other@example.com', password: 'x' });
    expect(other.status).toBe(401);
  });

  it('forgot: limited per email (case-insensitive)', async () => {
    const send = (email: string) => ctx.http.post('/api/v1/auth/password/forgot').send({ email });
    expect((await send('target@example.com')).status).toBe(202);
    expect((await send('TARGET@example.com')).status).toBe(202);
    const limited = await send('target@example.com');
    expect(limited.status).toBe(429);
    expect(limited.headers['retry-after']).toBeDefined();
  });

  it('authenticated requests are limited per user', async () => {
    // v1.2: tokens come from register → register/verify.
    const { res: reg } = await registerVerified(ctx);
    expect(reg.status).toBe(201);
    const auth = { Authorization: `Bearer ${reg.body.tokens.accessToken as string}` };
    for (let i = 0; i < 4; i++) expect((await ctx.http.get('/api/v1/me').set(auth)).status).toBe(200);
    const limited = await ctx.http.get('/api/v1/me').set(auth);
    expect(limited.status).toBe(429);
    expect(limited.body.error.code).toBe('RATE_LIMITED');
  });
});
