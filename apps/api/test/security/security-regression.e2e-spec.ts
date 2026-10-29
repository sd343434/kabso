/**
 * KL-007 security regression tests (A7). Each test pins a control that the Phase 1 review
 * verified as effective, so a later change cannot silently remove it. Defects found by the
 * review are described in docs/security/KL-007_PHASE1_REVIEW.md, not encoded here.
 */
import { createHash, randomBytes } from 'node:crypto';
import 'reflect-metadata';
import { RequestMethod } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { Redis } from 'ioredis';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { AppModule } from '../../src/app.module.js';
import { configureApp } from '../../src/app.setup.js';
import { ConfigValidationError, loadConfig } from '../../src/config/app-config.js';
import { AuthController } from '../../src/modules/auth/auth.controller.js';
import { IS_OPTIONAL_AUTH_KEY, IS_PUBLIC_KEY } from '../../src/modules/auth/public.decorator.js';
import { HealthController } from '../../src/modules/health/health.controller.js';
import { HomeController } from '../../src/modules/home/home.controller.js';
import { MAIL_SENDER } from '../../src/modules/mail/mail-sender.js';
import { UsersController } from '../../src/modules/users/users.controller.js';
import {
  AdminLiveController,
  LiveController,
  LiveMediaWebhookController,
} from '../../src/modules/live/live.controller.js';
import { FollowsController } from '../../src/modules/social/follows.controller.js';
import { PublicProfileController } from '../../src/modules/users/profiles/public-profile.controller.js';
import {
  buildTestConfig,
  CapturingMailSender,
  createTestApp,
  newUser,
  registerVerified,
  type TestContext,
} from '../helpers/test-app.js';

const PATH_METADATA = 'path';
const METHOD_METADATA = 'method';

/** The only routes that may be reachable without an access token (CONVENTIONS §6, openapi). */
const PUBLIC_ALLOWLIST = [
  'GET /health/live',
  'GET /health/ready',
  'POST /api/v1/auth/register',
  // Contract v1.2 (KL-019): verify-first registration adds two public routes.
  'POST /api/v1/auth/register/verify',
  'POST /api/v1/auth/register/resend',
  'POST /api/v1/auth/login',
  'POST /api/v1/auth/refresh',
  'POST /api/v1/auth/email/verify',
  'POST /api/v1/auth/password/forgot',
  'POST /api/v1/auth/password/reset',
  'GET /api/v1/users/username-availability',
  // CP-010: the media server's webhook; its signature over the raw body is the authentication
  // (pinned below: an unsigned or wrongly signed call is 401).
  'POST /internal/livekit/webhook',
].sort();

/**
 * CP-010 (D93): the only routes that also serve guests (`@OptionalAuth()`): without an
 * `Authorization` header they answer; with an invalid token they are 401 like every route.
 */
const OPTIONAL_AUTH_ALLOWLIST = [
  'GET /api/v1/live/config',
  'GET /api/v1/live/rooms',
  'GET /api/v1/live/rooms/:roomId',
  'POST /api/v1/live/rooms/:roomId/media-token',
  // CP-011: who is on which seat (guests read it like the room).
  'GET /api/v1/live/rooms/:roomId/seats',
  // CP-013: the last chat messages (guests read them when the room allows guests).
  'GET /api/v1/live/rooms/:roomId/chat',
  // CP-014: the Contribution list (guests read it when the room allows guests).
  'GET /api/v1/live/rooms/:roomId/contributors',
  // v1.20-live (D105): one person's points in a live (same access as the list).
  'GET /api/v1/live/rooms/:roomId/contributors/:username',
  // CP-016 A: the public popularity board (guests read it like the hub, per IP).
  'GET /api/v1/live/rankings',
  // v1.23.2-live (D109): who is watching (guests read it when the room allows guests).
  'GET /api/v1/live/rooms/:roomId/viewers',
  // v1.33-live (D154b): the featured («مميز») lives of the hub, read like the hub.
  'GET /api/v1/live/boosts/active',
  // v1.36-live (D154e): a live's program (guests read it like the room).
  'GET /api/v1/live/rooms/:roomId/program',
  // v1.37-live (D154h): the stickers on a live (guests see them like the picture).
  'GET /api/v1/live/rooms/:roomId/stickers',
  // v1.38-live (D154i): what the live watches together (guests follow it like the picture).
  'GET /api/v1/live/rooms/:roomId/watch',
  // v1.39-live (D166): the in-room promo banners (`placement=room`; `home` stays 401 without a
  // token), so a guest watching a live sees them too.
  'GET /api/v1/home/banners',
].sort();

interface RouteInfo {
  readonly key: string;
  readonly method: string;
  readonly path: string;
  readonly isPublic: boolean;
  readonly isOptional: boolean;
}

function join(...parts: string[]): string {
  return `/${parts
    .flatMap((p) => p.split('/'))
    .filter(Boolean)
    .join('/')}`;
}

/** Reads every route declared on the given controllers from Nest's decorator metadata. */
function declaredRoutes(controllers: readonly (abstract new (...args: never[]) => unknown)[]): RouteInfo[] {
  const routes: RouteInfo[] = [];
  for (const controller of controllers) {
    const base = (Reflect.getMetadata(PATH_METADATA, controller) as string | undefined) ?? '';
    const classPublic = Reflect.getMetadata(IS_PUBLIC_KEY, controller) === true;
    const proto = controller.prototype as Record<string, unknown>;
    for (const name of Object.getOwnPropertyNames(proto)) {
      const handler = proto[name];
      if (name === 'constructor' || typeof handler !== 'function') continue;
      const sub = Reflect.getMetadata(PATH_METADATA, handler) as string | undefined;
      const methodId = Reflect.getMetadata(METHOD_METADATA, handler) as RequestMethod | undefined;
      if (sub === undefined || methodId === undefined) continue;
      const method = RequestMethod[methodId];
      const unversioned = controller === HealthController || controller === LiveMediaWebhookController;
      const path = unversioned ? join(base, sub) : join('api/v1', base, sub);
      const isPublic = classPublic || Reflect.getMetadata(IS_PUBLIC_KEY, handler) === true;
      const isOptional = Reflect.getMetadata(IS_OPTIONAL_AUTH_KEY, handler) === true;
      routes.push({ key: `${method} ${path}`, method, path, isPublic, isOptional });
    }
  }
  return routes;
}

const CONTROLLERS = [
  AuthController,
  UsersController,
  HealthController,
  // Contract v1.3 (KL-037): every new route requires a token.
  LiveController,
  FollowsController,
  PublicProfileController,
  // CP-010 (KL-063): admin hosting permission and the media server's webhook.
  AdminLiveController,
  LiveMediaWebhookController,
  // v1.39-live (D166): the promo banners (guests read the in-room ones).
  HomeController,
] as const;

describe('KL-007 security regression', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
  });

  afterAll(async () => {
    await ctx?.close();
  });

  const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

  // Contract v1.2: an account (and tokens) exists only after register → register/verify.
  async function register(overrides: Partial<Record<string, unknown>> = {}) {
    const { payload, res } = await registerVerified(ctx, overrides);
    expect(res.status).toBe(201);
    return { payload, body: res.body };
  }

  describe('guard coverage', () => {
    it('only the allow-listed routes are @Public', () => {
      const routes = declaredRoutes(CONTROLLERS);
      expect(routes.length).toBeGreaterThanOrEqual(14);
      expect(
        routes
          .filter((r) => r.isPublic)
          .map((r) => r.key)
          .sort(),
      ).toEqual(PUBLIC_ALLOWLIST);
    });

    it('only the allow-listed routes also serve guests (@OptionalAuth)', () => {
      expect(
        declaredRoutes(CONTROLLERS)
          .filter((r) => r.isOptional)
          .map((r) => r.key)
          .sort(),
      ).toEqual(OPTIONAL_AUTH_ALLOWLIST);
    });

    it('guest routes still refuse an invalid token (401), and the webhook an unsigned call', async () => {
      for (const route of declaredRoutes(CONTROLLERS).filter((r) => r.isOptional)) {
        const path = route.path.replace(/:[A-Za-z]+/g, '0192f1c2-0000-7000-8000-000000000000');
        const res = await ctx.http[route.method.toLowerCase() as 'get' | 'post'](path)
          .set('Authorization', 'Bearer not.a.token')
          .send({});
        expect({ route: route.key, status: res.status }).toEqual({ route: route.key, status: 401 });
      }
      const webhook = await ctx.http
        .post('/internal/livekit/webhook')
        .set('Content-Type', 'application/webhook+json')
        .send('{"event":"room_finished","room":{"name":"x"}}');
      expect(webhook.status).toBe(401);
    });

    it('every non-public route answers 401 AUTH_UNAUTHENTICATED without a token', async () => {
      const protectedRoutes = declaredRoutes(CONTROLLERS).filter((r) => !r.isPublic && !r.isOptional);
      expect(protectedRoutes.length).toBeGreaterThanOrEqual(5);
      for (const route of protectedRoutes) {
        const path = route.path.replace(/:[A-Za-z]+/g, '0192f1c2-0000-7000-8000-000000000000');
        const res = await ctx.http[route.method.toLowerCase() as 'get' | 'post' | 'put' | 'delete'](
          path,
        ).send({});
        expect({ route: route.key, status: res.status, code: res.body?.error?.code }).toEqual({
          route: route.key,
          status: 401,
          code: 'AUTH_UNAUTHENTICATED',
        });
      }
    });
  });

  describe('access JWT verification', () => {
    const b64 = (v: object) => Buffer.from(JSON.stringify(v)).toString('base64url');

    it('rejects alg=none, a foreign key, wrong iss/aud/typ, and expired tokens', async () => {
      const { body } = await register();
      const [, payloadPart] = body.tokens.accessToken.split('.');
      const claims = JSON.parse(Buffer.from(payloadPart, 'base64url').toString()) as Record<string, unknown>;
      const jwt = new JwtService({});
      const secret = ctx.config.jwt.accessSecret;
      const sign = (payload: Record<string, unknown>, key = secret) =>
        jwt.sign(payload, { secret: key, algorithm: 'HS256' });
      const now = Math.floor(Date.now() / 1000);
      const good = { ...claims, iat: now, exp: now + 600 };

      const candidates = {
        algNone: `${b64({ alg: 'none', typ: 'JWT' })}.${payloadPart}.`,
        foreignKey: sign(good, randomBytes(48).toString('base64url')),
        wrongIss: sign({ ...good, iss: 'someone-else' }),
        wrongAud: sign({ ...good, aud: 'kabso-web' }),
        refreshTyp: sign({ ...good, typ: 'refresh' }),
        expired: sign({ ...good, iat: now - 1000, exp: now - 10 }),
      };
      // Sanity check: the same claims signed correctly are accepted.
      expect((await ctx.http.get('/api/v1/me').set(bearer(sign(good)))).status).toBe(200);
      for (const [name, token] of Object.entries(candidates)) {
        const res = await ctx.http.get('/api/v1/me').set(bearer(token));
        expect({ name, status: res.status }).toEqual({ name, status: 401 });
      }
    });

    it('binds sub to sid: a validly signed token naming another user on my session is refused', async () => {
      const alice = await register();
      const bob = await register();
      const aliceClaims = JSON.parse(
        Buffer.from(alice.body.tokens.accessToken.split('.')[1], 'base64url').toString(),
      ) as Record<string, unknown>;
      const forged = new JwtService({}).sign(
        { ...aliceClaims, sub: bob.body.user.id },
        { secret: ctx.config.jwt.accessSecret, algorithm: 'HS256' },
      );
      const res = await ctx.http.get('/api/v1/me').set(bearer(forged));
      expect(res.status).toBe(401);
    });
  });

  describe('secrets at rest', () => {
    it('stores only SHA-256 digests of refresh and verification secrets', async () => {
      const { body } = await register();
      const [sessionId, secret] = body.tokens.refreshToken.split('.');
      const session = await ctx.prisma.session.findUniqueOrThrow({ where: { id: sessionId } });
      expect(session.refreshTokenHash).toBe(createHash('sha256').update(secret).digest('hex'));
      expect(JSON.stringify(session)).not.toContain(secret);

      // v1.2: accounts are created verified, so issue an email-verification token explicitly
      // (the flow remains for future address changes) to check how it is stored.
      await ctx.prisma.user.update({ where: { id: body.user.id }, data: { emailVerifiedAt: null } });
      const before = ctx.mail.sent.length;
      expect(
        (await ctx.http.post('/api/v1/auth/email/resend').set(bearer(body.tokens.accessToken))).status,
      ).toBe(202);
      const mail = await ctx.mail.waitFor(body.user.email, 'verify', before);
      const rows = await ctx.prisma.verificationToken.findMany({ where: { userId: body.user.id } });
      expect(rows).toHaveLength(1);
      expect(rows[0]!.tokenHash).toBe(createHash('sha256').update(mail.token).digest('hex'));
      expect(JSON.stringify(rows)).not.toContain(mail.token);

      const user = await ctx.prisma.user.findUniqueOrThrow({ where: { id: body.user.id } });
      expect(user.passwordHash).toMatch(/^\$argon2id\$v=19\$m=19456,p=1,t=2\$/);
    });

    it('audit rows never contain passwords, tokens or the raw login identifier', async () => {
      const { payload, body } = await register();
      await ctx.http
        .post('/api/v1/auth/login')
        .send({ identifier: payload.email, password: 'wrong password 123' });
      await ctx.http
        .post('/api/v1/auth/login')
        .send({ identifier: payload.email, password: payload.password });
      const rows = await ctx.prisma.auditLog.findMany({ where: { actorUserId: body.user.id } });
      expect(rows.length).toBeGreaterThanOrEqual(3);
      const dump = JSON.stringify(rows);
      expect(dump).not.toContain(payload.password);
      expect(dump).not.toContain(payload.email);
      expect(dump).not.toContain(body.tokens.refreshToken.split('.')[1]);
      expect(dump).not.toContain(body.tokens.accessToken);
    });
  });

  describe('authorization', () => {
    it("cannot revoke another user's session (404) and the victim's session stays live", async () => {
      const victim = await register();
      const attacker = await register();
      const victimSession = victim.body.tokens.refreshToken.split('.')[0];
      const res = await ctx.http
        .delete(`/api/v1/auth/sessions/${victimSession}`)
        .set(bearer(attacker.body.tokens.accessToken));
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
      expect((await ctx.http.get('/api/v1/me').set(bearer(victim.body.tokens.accessToken))).status).toBe(200);

      const list = await ctx.http.get('/api/v1/auth/sessions').set(bearer(attacker.body.tokens.accessToken));
      expect(list.body.data.map((s: { id: string }) => s.id)).not.toContain(victimSession);
    });
  });

  describe('input handling', () => {
    it('never reflects an X-Request-Id outside [A-Za-z0-9._-]{1,64}', async () => {
      for (const bad of ['a b', 'a\tb', 'x'.repeat(65), 'abc%0d%0aSet-Cookie:x=1', '<script>']) {
        const res = await ctx.http.get('/health/live').set('X-Request-Id', bad);
        expect(res.headers['x-request-id']).toMatch(/^[0-9a-f-]{36}$/);
        expect(res.headers['set-cookie']).toBeUndefined();
      }
    });

    it('rejects control, bidi and zero-width characters in device fields and displayName (SEC-008)', async () => {
      const { payload } = await register();
      for (const device of [{ name: 'evil\n\u001b[31mred' }, { name: 'a‮b' }, { appVersion: '1.0\u0000' }]) {
        const res = await ctx.http
          .post('/api/v1/auth/login')
          .send({ identifier: payload.email, password: payload.password, device });
        expect(res.status).toBe(400);
        expect(res.body.error.details[0].issue).toBe('invalid_format');
      }
      for (const displayName of ['admin‮gnp.exe', 'Kab​so Official']) {
        const res = await ctx.http.post('/api/v1/auth/register').send(newUser({ displayName }));
        expect(res.status).toBe(400);
      }
      const arabic = await ctx.http.post('/api/v1/auth/register').send(newUser({ displayName: 'محمد علي' }));
      expect(arabic.status).toBe(202); // v1.2: register answers 202 (verify-first)
    });

    it('rejects __proto__ and other unknown keys in strict bodies', async () => {
      const res = await ctx.http
        .post('/api/v1/auth/login')
        .set('Content-Type', 'application/json')
        .send('{"identifier":"someone","password":"x","__proto__":{"isAdmin":true}}');
      expect(res.status).toBe(400);
      expect(res.body.error.details).toEqual([{ field: '__proto__', issue: 'unknown_field' }]);
    });
  });
});

describe('KL-007 rate limiting', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_REGISTER_IP: '2/3600', TRUST_PROXY: 'false' });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('ignores X-Forwarded-For when TRUST_PROXY=false (no per-IP bypass by header spoofing)', async () => {
    const statuses: number[] = [];
    for (let i = 1; i <= 3; i += 1) {
      const res = await ctx.http
        .post('/api/v1/auth/register')
        .set('X-Forwarded-For', `203.0.113.${i}`)
        .send(newUser());
      statuses.push(res.status);
    }
    expect(statuses).toEqual([202, 202, 429]); // v1.2: register answers 202 (verify-first)
  });

  it('stores only hashed subjects in Redis keys (no emails or identifiers)', async () => {
    await ctx.http.post('/api/v1/auth/password/forgot').send({ email: 'Someone.Secret@Example.com' });
    await ctx.http.post('/api/v1/auth/login').send({ identifier: 'secret_username', password: 'whatever!!' });
    const redis = new Redis(ctx.config.redis.url, { lazyConnect: true, maxRetriesPerRequest: 1 });
    await redis.connect();
    try {
      const keys = await redis.keys(`${ctx.config.redis.keyPrefix}*`);
      expect(keys.length).toBeGreaterThan(0);
      for (const key of keys) {
        expect(key.toLowerCase()).not.toMatch(/someone|example|secret_username|127\.0\.0\.1|::ffff/);
      }
    } finally {
      redis.disconnect();
    }
  });
});

describe('KL-007 fail-closed rate limiting', () => {
  let app: NestExpressApplication | undefined;

  afterAll(async () => {
    await app?.close();
  });

  it('answers 503 SERVICE_UNAVAILABLE on rate-limited routes when Redis is unreachable', async () => {
    // Port 1 on loopback is never a Redis server; the API must not fall back to "no limit".
    const config = buildTestConfig({ REDIS_URL: 'redis://127.0.0.1:1/13' });
    const moduleRef = await Test.createTestingModule({ imports: [AppModule.register(config)] })
      .overrideProvider(MAIL_SENDER)
      .useValue(new CapturingMailSender())
      .compile();
    app = moduleRef.createNestApplication<NestExpressApplication>({ bodyParser: false });
    configureApp(app, config);
    await app.init();
    const http = request(app.getHttpServer());

    const login = await http.post('/api/v1/auth/login').send({ identifier: 'someone', password: 'x' });
    expect(login.status).toBe(503);
    expect(login.body.error.code).toBe('SERVICE_UNAVAILABLE');

    const availability = await http.get('/api/v1/users/username-availability?username=someone');
    expect(availability.status).toBe(503);
  });
});

describe('KL-007 production configuration guards', () => {
  const base = {
    NODE_ENV: 'production',
    DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
    REDIS_URL: 'redis://localhost:6379',
    APP_PUBLIC_URL: 'https://kabso.example',
  };

  function problems(env: Record<string, string>): string[] {
    try {
      loadConfig(env);
      return [];
    } catch (err) {
      if (err instanceof ConfigValidationError) return [...err.problems];
      throw err;
    }
  }

  it('refuses the log mail transport in production (it writes token links to logs)', () => {
    const issues = problems({ ...base, JWT_ACCESS_SECRET: randomBytes(48).toString('base64') });
    expect(issues.some((p) => p.startsWith('MAIL_TRANSPORT'))).toBe(true);
  });

  it.each([
    'change-me-generate-with-openssl-rand-base64-48',
    'replace-me-with-a-long-random-string-of-at-least-32-bytes',
    'a'.repeat(48),
    'short',
    // KL-007 re-test (SEC-005): the low-entropy values from the original PoC.
    'abcdefghijklmnopqrstuvwxyzABCDEF',
    'kabso-live-production-jwt-key-2026!',
    '0123456789012345678901234567890123',
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
  ])('refuses placeholder, short or low-entropy JWT secrets in production: %s', (secret) => {
    expect(
      problems({ ...base, JWT_ACCESS_SECRET: secret }).some((p) => p.startsWith('JWT_ACCESS_SECRET')),
    ).toBe(true);
  });

  it('accepts generator output for both keys and refuses TRUST_PROXY=true (SEC-003/005/010)', () => {
    const strong = {
      ...base,
      JWT_ACCESS_SECRET: randomBytes(48).toString('base64'),
      RATE_LIMIT_KEY_SECRET: randomBytes(48).toString('base64url'),
    };
    const only = (env: Record<string, string>) =>
      problems(env).filter((p) => !p.startsWith('MAIL_TRANSPORT'));
    expect(only(strong)).toEqual([]);
    expect(only({ ...strong, TRUST_PROXY: 'true' }).some((p) => p.startsWith('TRUST_PROXY'))).toBe(true);
    expect(only({ ...strong, TRUST_PROXY: '1' })).toEqual([]);
    const { RATE_LIMIT_KEY_SECRET: _omit, ...withoutRlKey } = strong;
    expect(only(withoutRlKey).some((p) => p.startsWith('RATE_LIMIT_KEY_SECRET'))).toBe(true);
    expect(
      only({ ...strong, RATE_LIMIT_KEY_SECRET: strong.JWT_ACCESS_SECRET }).some((p) =>
        p.startsWith('RATE_LIMIT_KEY_SECRET'),
      ),
    ).toBe(true);
  });
});
