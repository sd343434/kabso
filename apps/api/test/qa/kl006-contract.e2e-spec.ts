// KL-006 (A6, QA) regression tests for gaps found in the independent Phase 1 verification.
// Black-box style: everything goes through HTTP against real PostgreSQL + Redis, and every
// success body is checked against docs/contracts/openapi.yaml with *exact* key sets.
import 'reflect-metadata';
import { createHmac, randomBytes } from 'node:crypto';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { AppModule } from '../../src/app.module.js';
import { configureApp } from '../../src/app.setup.js';
import { MAIL_SENDER } from '../../src/modules/mail/mail-sender.js';
import {
  buildTestConfig,
  CapturingMailSender,
  createTestApp,
  newUser,
  registerVerified,
  type TestContext,
} from '../helpers/test-app.js';

const ISO_Z = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

const ME_REQUIRED = [
  'id',
  'email',
  'emailVerified',
  'username',
  'displayName',
  'locale',
  'role',
  'isPrivate',
  'createdAt',
  // CP-010 (D93): the hosting permission.
  'canHost',
  // CP-015 (D98): the host's live cover (nullable, always present).
  'liveCoverUrl',
  // D133 (v1.27.1-live): the caller's own country (nullable, always present).
  'country',
  // D175 (v1.47-social): gender (nullable), its visibility, the category (nullable) and the links.
  'gender',
  'showGender',
  'category',
  'links',
];
const ME_OPTIONAL = ['bio', 'avatarUrl'];
const TOKEN_PAIR = ['accessToken', 'accessTokenExpiresAt', 'refreshToken', 'refreshTokenExpiresAt'];
const SESSION_REQUIRED = ['id', 'current', 'createdAt', 'lastUsedAt'];
const SESSION_OPTIONAL = ['deviceName', 'platform', 'appVersion', 'ipCountry'];

/** Asserts `obj` has every required key, and no key outside required ∪ optional. */
function expectExactKeys(obj: unknown, required: string[], optional: string[] = []): void {
  expect(obj).toBeTypeOf('object');
  const keys = Object.keys(obj as object);
  expect(keys).toEqual(expect.arrayContaining(required));
  for (const key of keys) expect([...required, ...optional]).toContain(key);
}

function expectMe(me: Record<string, unknown>): void {
  expectExactKeys(me, ME_REQUIRED, ME_OPTIONAL);
  expect(me.id).toMatch(UUID);
  expect(me.createdAt).toMatch(ISO_Z);
  expect(['ar', 'en']).toContain(me.locale);
  expect(['USER', 'ADMIN']).toContain(me.role);
}

function expectTokenPair(tokens: Record<string, unknown>): void {
  expectExactKeys(tokens, TOKEN_PAIR);
  expect(tokens.accessTokenExpiresAt).toMatch(ISO_Z);
  expect(tokens.refreshTokenExpiresAt).toMatch(ISO_Z);
}

function expectEnvelope(res: request.Response, status: number, code: string): void {
  expect(res.status).toBe(status);
  expectExactKeys(res.body, ['error']);
  expectExactKeys(res.body.error, ['code', 'message', 'requestId'], ['details']);
  expect(res.body.error.code).toBe(code);
  expect(res.body.error.requestId).toBe(res.headers['x-request-id']);
  expect(res.text).not.toMatch(/node_modules|at \S+:\d+:\d+/);
}

function b64url(value: object): string {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

/** HS256 JWT signed with `secret` (or an unsigned `alg: none` token). */
function jwt(payload: object, secret: string | null): string {
  const head = b64url({ alg: secret === null ? 'none' : 'HS256', typ: 'JWT' });
  const body = b64url(payload);
  if (secret === null) return `${head}.${body}.`;
  const sig = createHmac('sha256', secret).update(`${head}.${body}`).digest('base64url');
  return `${head}.${body}.${sig}`;
}

function claimsOf(accessToken: string): Record<string, unknown> {
  return JSON.parse(Buffer.from(accessToken.split('.')[1]!, 'base64url').toString()) as Record<
    string,
    unknown
  >;
}

const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

describe('KL-006 contract checks', () => {
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
    return { payload, body: res.body as { user: Record<string, unknown>; tokens: Record<string, string> } };
  }

  describe('success shapes match openapi.yaml exactly', () => {
    it('register, login, refresh, me, sessions, username-availability', async () => {
      const { payload, body } = await register();
      expectExactKeys(body, ['user', 'tokens']);
      expectMe(body.user);
      expectTokenPair(body.tokens);

      const login = await ctx.http
        .post('/api/v1/auth/login')
        .send({ identifier: payload.email, password: payload.password });
      expect(login.status).toBe(200);
      expect(login.headers['content-type']).toBe('application/json; charset=utf-8');
      expectExactKeys(login.body, ['user', 'tokens']);
      expectMe(login.body.user);
      expectTokenPair(login.body.tokens);

      const refreshed = await ctx.http
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: login.body.tokens.refreshToken });
      expect(refreshed.status).toBe(200);
      expectTokenPair(refreshed.body);

      const me = await ctx.http.get('/api/v1/me').set(bearer(refreshed.body.accessToken));
      expect(me.status).toBe(200);
      expectMe(me.body);

      const sessions = await ctx.http.get('/api/v1/auth/sessions').set(bearer(refreshed.body.accessToken));
      expect(sessions.status).toBe(200);
      expectExactKeys(sessions.body, ['data']);
      expect(sessions.body.data).toHaveLength(2);
      for (const s of sessions.body.data) {
        expectExactKeys(s, SESSION_REQUIRED, SESSION_OPTIONAL);
        expect(s.id).toMatch(UUID);
        expect(s.createdAt).toMatch(ISO_Z);
        expect(s.lastUsedAt).toMatch(ISO_Z);
        expect(s.ipCountry).toBeNull();
      }

      const availability = await ctx.http
        .get('/api/v1/users/username-availability')
        .query({ username: payload.username });
      expect(availability.status).toBe(200);
      expectExactKeys(availability.body, ['username', 'available']);
    });

    it('access JWT carries exactly the CONVENTIONS §6 claims', async () => {
      const { body } = await register();
      const [rawHeader] = body.tokens.accessToken!.split('.');
      expect(JSON.parse(Buffer.from(rawHeader!, 'base64url').toString())).toMatchObject({ alg: 'HS256' });
      const claims = claimsOf(body.tokens.accessToken!);
      expect(Object.keys(claims).sort()).toEqual(['aud', 'exp', 'iat', 'iss', 'sid', 'sub', 'typ']);
      expect(claims).toMatchObject({
        sub: body.user.id,
        typ: 'access',
        iss: 'kabso-api',
        aud: 'kabso-mobile',
      });
      expect((claims.exp as number) - (claims.iat as number)).toBe(900);
      expect(claims.sid).toBe(body.tokens.refreshToken!.split('.')[0]);
    });
  });

  describe('registration input handling', () => {
    it('Arabic, emoji and accented display names round-trip intact (trimmed)', async () => {
      const name = 'عبد الله ✨ Ünïcødé 😀';
      const { body } = await register({ displayName: `  ${name}  `, locale: 'ar' });
      expect(body.user.displayName).toBe(name);
      expect(body.user.locale).toBe('ar');
      const me = await ctx.http.get('/api/v1/me').set(bearer(body.tokens.accessToken!));
      expect(me.body.displayName).toBe(name);
    });

    it('50 Arabic characters are accepted; 51 characters are too_long', async () => {
      await register({ displayName: 'ب'.repeat(50) });
      const res = await ctx.http.post('/api/v1/auth/register').send(newUser({ displayName: 'x'.repeat(51) }));
      expectEnvelope(res, 400, 'VALIDATION_FAILED');
      expect(res.body.error.details).toEqual([{ field: 'displayName', issue: 'too_long' }]);
    });

    it('whitespace-only and control-character display names are rejected', async () => {
      const blank = await ctx.http.post('/api/v1/auth/register').send(newUser({ displayName: '   ' }));
      expectEnvelope(blank, 400, 'VALIDATION_FAILED');
      // Contract v1.2.4 (QA-010): whitespace-only is invalid_format (was too_short).
      expect(blank.body.error.details).toEqual([{ field: 'displayName', issue: 'invalid_format' }]);

      const control = await ctx.http.post('/api/v1/auth/register').send(newUser({ displayName: 'a\u0000b' }));
      expectEnvelope(control, 400, 'VALIDATION_FAILED');
      expect(control.body.error.details).toEqual([{ field: 'displayName', issue: 'invalid_format' }]);
    });

    it('an otherwise valid username with uppercase letters is 400 invalid_format (not normalized)', async () => {
      const res = await ctx.http.post('/api/v1/auth/register').send(newUser({ username: 'ValidButUpper' }));
      expectEnvelope(res, 400, 'VALIDATION_FAILED');
      expect(res.body.error.details).toEqual([{ field: 'username', issue: 'invalid_format' }]);

      const availability = await ctx.http
        .get('/api/v1/users/username-availability')
        .query({ username: 'ValidButUpper' });
      expectEnvelope(availability, 400, 'VALIDATION_FAILED');
    });

    it('invalid locale and device.platform are reported with dotted paths', async () => {
      const res = await ctx.http
        .post('/api/v1/auth/register')
        .send(newUser({ locale: 'fr', device: { platform: 'windows' } }));
      expectEnvelope(res, 400, 'VALIDATION_FAILED');
      expect(res.body.error.details).toEqual(
        expect.arrayContaining([
          { field: 'locale', issue: 'invalid_value' },
          { field: 'device.platform', issue: 'invalid_value' },
        ]),
      );
    });
  });

  describe('login identifier', () => {
    it('accepts the username in any case and with surrounding spaces', async () => {
      const { payload, body } = await register();
      for (const identifier of [payload.username.toUpperCase(), `  ${payload.username}  `]) {
        const res = await ctx.http
          .post('/api/v1/auth/login')
          .send({ identifier, password: payload.password });
        expect(res.status).toBe(200);
        expect(res.body.user.id).toBe(body.user.id);
      }
    });

    it('a suspended account with a wrong password gets 401, not 403 (no status oracle)', async () => {
      const { payload, body } = await register();
      await ctx.prisma.user.update({ where: { id: body.user.id as string }, data: { status: 'SUSPENDED' } });
      const res = await ctx.http
        .post('/api/v1/auth/login')
        .send({ identifier: payload.email, password: 'definitely wrong' });
      expectEnvelope(res, 401, 'AUTH_INVALID_CREDENTIALS');
    });
  });

  describe('body-level errors (CONVENTIONS §4: 400, never 413/415)', () => {
    it.each([
      ['text/plain', JSON.stringify({ identifier: 'abc', password: 'x' })],
      ['application/x-www-form-urlencoded', 'identifier=abc&password=x'],
    ])('wrong content type %s → 400 with field ""', async (type, raw) => {
      const res = await ctx.http.post('/api/v1/auth/login').set('Content-Type', type).send(raw);
      expectEnvelope(res, 400, 'VALIDATION_FAILED');
      expect(res.body.error.details?.[0]?.field).toBe('');
    });

    it.each([
      ['an array', '[1,2]'],
      ['a string (strict JSON parser)', '"text"'],
      ['an empty body', ''],
    ])('a JSON body that is %s → 400 VALIDATION_FAILED', async (_name, raw) => {
      const res = await ctx.http.post('/api/v1/auth/login').set('Content-Type', 'application/json').send(raw);
      expectEnvelope(res, 400, 'VALIDATION_FAILED');
    });

    it('a 64-character X-Request-Id is echoed into the header and the envelope', async () => {
      const id = 'q'.repeat(64);
      const res = await ctx.http.post('/api/v1/auth/login').set('X-Request-Id', id).send({});
      expect(res.headers['x-request-id']).toBe(id);
      expectEnvelope(res, 400, 'VALIDATION_FAILED');
      expect(res.body.error.requestId).toBe(id);
    });

    it('an unsupported method on a known path uses the envelope', async () => {
      const res = await ctx.http.put('/api/v1/me').send({});
      expectEnvelope(res, 404, 'NOT_FOUND');
    });
  });

  describe('access token attacks → 401 AUTH_UNAUTHENTICATED', () => {
    it('rejects forged, expired, mis-scoped and non-access tokens at the guard', async () => {
      const { body } = await register();
      const other = await register();
      const claims = claimsOf(body.tokens.accessToken!);
      const secret = ctx.config.jwt.accessSecret;
      const now = Math.floor(Date.now() / 1000);
      const forged: Record<string, string> = {
        'alg none': jwt(claims, null),
        'alg none with a dummy signature': `${jwt(claims, null)}c2ln`,
        expired: jwt({ ...claims, iat: now - 2000, exp: now - 1000 }, secret),
        'foreign key': jwt(claims, randomBytes(48).toString('base64')),
        'wrong aud': jwt({ ...claims, aud: 'someone-else' }, secret),
        'wrong iss': jwt({ ...claims, iss: 'evil' }, secret),
        'typ refresh': jwt({ ...claims, typ: 'refresh' }, secret),
        'unknown session id': jwt({ ...claims, sid: '0192f1c2-0000-7000-8000-000000000000' }, secret),
        "another user's sub with my sid": jwt({ ...claims, sub: other.body.user.id }, secret),
        'refresh token used as bearer': body.tokens.refreshToken!,
        garbage: 'garbage',
      };
      const baseline = await ctx.http.get('/api/v1/me').set(bearer(body.tokens.accessToken!));
      expect(baseline.status).toBe(200);
      for (const [name, token] of Object.entries(forged)) {
        const res = await ctx.http.get('/api/v1/me').set(bearer(token));
        expect({ name, status: res.status }).toEqual({ name, status: 401 });
        expectEnvelope(res, 401, 'AUTH_UNAUTHENTICATED');
      }
    });
  });

  describe('refresh token formats', () => {
    it.each([
      ['too short', 'abc'],
      ['too long', 'x'.repeat(201)],
    ])('%s → 400 VALIDATION_FAILED', async (_name, refreshToken) => {
      const res = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken });
      expectEnvelope(res, 400, 'VALIDATION_FAILED');
    });

    it.each([
      ['no separator', 'a'.repeat(40)],
      ['non-uuid session id', `nope.${'a'.repeat(43)}`],
      ['two separators', `0192f1c2-0000-7000-8000-000000000000.${'a'.repeat(20)}.${'b'.repeat(20)}`],
      ['non-ascii secret', `0192f1c2-0000-7000-8000-000000000000.${'é'.repeat(43)}`],
    ])('%s → 401 AUTH_REFRESH_INVALID', async (_name, refreshToken) => {
      const res = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken });
      expectEnvelope(res, 401, 'AUTH_REFRESH_INVALID');
    });
  });

  describe('two independent sessions of one user', () => {
    it('revoking one leaves the other fully working (access and refresh)', async () => {
      const { payload } = await register();
      const login = (name: string) =>
        ctx.http.post('/api/v1/auth/login').send({
          identifier: payload.email,
          password: payload.password,
          device: { name, platform: 'ios' },
        });
      const a = await login('Phone A');
      const b = await login('Phone B');
      const sidA = a.body.tokens.refreshToken.split('.')[0] as string;
      const sidB = b.body.tokens.refreshToken.split('.')[0] as string;
      expect(sidA).not.toBe(sidB);

      const revoke = await ctx.http
        .delete(`/api/v1/auth/sessions/${sidA}`)
        .set(bearer(b.body.tokens.accessToken));
      expect(revoke.status).toBe(204);
      expect(revoke.text).toBe('');

      expectEnvelope(
        await ctx.http.get('/api/v1/me').set(bearer(a.body.tokens.accessToken)),
        401,
        'AUTH_UNAUTHENTICATED',
      );
      expectEnvelope(
        await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: a.body.tokens.refreshToken }),
        401,
        'AUTH_REFRESH_INVALID',
      );

      expect((await ctx.http.get('/api/v1/me').set(bearer(b.body.tokens.accessToken))).status).toBe(200);
      const rotated = await ctx.http
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: b.body.tokens.refreshToken });
      expect(rotated.status).toBe(200);
      const list = await ctx.http.get('/api/v1/auth/sessions').set(bearer(rotated.body.accessToken));
      const ids = (list.body.data as { id: string }[]).map((s) => s.id);
      expect(ids).toContain(sidB);
      expect(ids).not.toContain(sidA);
    });

    it('revoking the current session by an upper-case id ends it immediately', async () => {
      const { body } = await register();
      const sid = body.tokens.refreshToken!.split('.')[0]!;
      const res = await ctx.http
        .delete(`/api/v1/auth/sessions/${sid.toUpperCase()}`)
        .set(bearer(body.tokens.accessToken!));
      expect(res.status).toBe(204);
      expect((await ctx.http.get('/api/v1/me').set(bearer(body.tokens.accessToken!))).status).toBe(401);
    });
  });

  describe('logout', () => {
    it('a second logout with the same token is 401 and the refresh token is dead', async () => {
      const { body } = await register();
      expect((await ctx.http.post('/api/v1/auth/logout').set(bearer(body.tokens.accessToken!))).status).toBe(
        204,
      );
      expectEnvelope(
        await ctx.http.post('/api/v1/auth/logout').set(bearer(body.tokens.accessToken!)),
        401,
        'AUTH_UNAUTHENTICATED',
      );
      expectEnvelope(
        await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: body.tokens.refreshToken }),
        401,
        'AUTH_REFRESH_INVALID',
      );
    });
  });

  describe('password reset token expiry', () => {
    it('an expired reset token → 410 TOKEN_EXPIRED and the password is unchanged', async () => {
      const { payload } = await register();
      await ctx.http.post('/api/v1/auth/password/forgot').send({ email: payload.email });
      const mail = await ctx.mail.waitFor(payload.email, 'reset');
      await ctx.prisma.verificationToken.updateMany({
        where: { purpose: 'PASSWORD_RESET' },
        data: { expiresAt: new Date(Date.now() - 1000) },
      });
      const res = await ctx.http
        .post('/api/v1/auth/password/reset')
        .send({ token: mail.token, newPassword: 'a different passphrase' });
      expectEnvelope(res, 410, 'TOKEN_EXPIRED');
      const login = await ctx.http
        .post('/api/v1/auth/login')
        .send({ identifier: payload.email, password: payload.password });
      expect(login.status).toBe(200);
    });
  });
});

describe('KL-006 rate limits not covered by the KL-002 suite (CONVENTIONS §7)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({
      RATE_LIMIT_REGISTER_IP: '2/3600',
      RATE_LIMIT_REFRESH_SESSION: '2/900',
      RATE_LIMIT_EMAIL_RESEND_USER: '1/3600',
      RATE_LIMIT_PUBLIC_IP: '2/900',
      RATE_LIMIT_LOGIN_IP: '3/900',
    });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  function expectLimited(res: request.Response, maxSeconds: number): void {
    expectEnvelope(res, 429, 'RATE_LIMITED');
    const retryAfter = Number(res.headers['retry-after']);
    expect(Number.isInteger(retryAfter)).toBe(true);
    expect(retryAfter).toBeGreaterThan(0);
    expect(retryAfter).toBeLessThanOrEqual(maxSeconds);
  }

  it('register per IP, refresh per session, resend per user, public routes per IP, login per IP', async () => {
    // v1.2: register answers 202; tokens come from register/verify (its own per-IP bucket).
    const firstUser = newUser();
    expect((await ctx.http.post('/api/v1/auth/register').send(firstUser)).status).toBe(202);
    expect((await ctx.http.post('/api/v1/auth/register').send(newUser())).status).toBe(202);
    expectLimited(await ctx.http.post('/api/v1/auth/register').send(newUser()), 3600);
    const codeMail = await ctx.mail.waitFor(firstUser.email, 'code');
    const first = await ctx.http
      .post('/api/v1/auth/register/verify')
      .send({ email: firstUser.email, code: codeMail.code });
    expect(first.status).toBe(201);

    let refreshToken = first.body.tokens.refreshToken as string;
    for (let i = 0; i < 2; i++) {
      const res = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken });
      expect(res.status).toBe(200);
      refreshToken = res.body.refreshToken as string;
    }
    expectLimited(await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken }), 900);

    const access = first.body.tokens.accessToken as string;
    expect((await ctx.http.post('/api/v1/auth/email/resend').set(bearer(access))).status).toBe(202);
    expectLimited(await ctx.http.post('/api/v1/auth/email/resend').set(bearer(access)), 3600);

    const check = () =>
      ctx.http.get('/api/v1/users/username-availability').query({ username: 'someone_free' });
    expect((await check()).status).toBe(200);
    expect((await check()).status).toBe(200);
    expectLimited(await check(), 900);

    for (let i = 0; i < 3; i++) {
      const res = await ctx.http
        .post('/api/v1/auth/login')
        .send({ identifier: `nobody${i}@example.com`, password: 'whatever-123' });
      expect(res.status).toBe(401);
    }
    expectLimited(
      await ctx.http
        .post('/api/v1/auth/login')
        .send({ identifier: 'fresh@example.com', password: 'whatever-123' }),
      900,
    );
  });
});

describe('KL-006 Redis outage: rate limiting fails closed (CONVENTIONS §7)', () => {
  let app: NestExpressApplication;
  let http: ReturnType<typeof request>;

  beforeAll(async () => {
    // Nothing listens on port 1: the Redis client never becomes ready.
    const config = buildTestConfig({ REDIS_URL: 'redis://127.0.0.1:1/14' });
    const moduleRef = await Test.createTestingModule({ imports: [AppModule.register(config)] })
      .overrideProvider(MAIL_SENDER)
      .useValue(new CapturingMailSender())
      .compile();
    app = moduleRef.createNestApplication<NestExpressApplication>({ bodyParser: false });
    configureApp(app, config);
    await app.init();
    http = request(app.getHttpServer());
  });

  afterAll(async () => {
    await app?.close();
  });

  it('liveness stays up, readiness reports redis down with 503', async () => {
    expect((await http.get('/health/live')).status).toBe(200);
    const ready = await http.get('/health/ready');
    expect(ready.status).toBe(503);
    expect(ready.body).toEqual({ status: 'down', checks: { database: 'ok', redis: 'down' } });
  });

  it('rate-limited routes answer 503 SERVICE_UNAVAILABLE instead of skipping the limit', async () => {
    const login = await http
      .post('/api/v1/auth/login')
      .send({ identifier: 'someone', password: 'whatever-123' });
    expectEnvelope(login, 503, 'SERVICE_UNAVAILABLE');
    const availability = await http.get('/api/v1/users/username-availability').query({ username: 'abc' });
    expectEnvelope(availability, 503, 'SERVICE_UNAVAILABLE');
  });
});
