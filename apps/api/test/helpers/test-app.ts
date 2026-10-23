import { LIVE_MEDIA_PROVIDER } from '../../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './memory-live-media.js';
import 'reflect-metadata';
import { randomBytes } from 'node:crypto';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaPg } from '@prisma/adapter-pg';
import { Redis } from 'ioredis';
import request from 'supertest';
import { AppModule } from '../../src/app.module.js';
import { configureApp } from '../../src/app.setup.js';
import { loadConfig, type AppConfig } from '../../src/config/app-config.js';
import {
  MAIL_SENDER,
  type AccountExistsMail,
  type MailLocale,
  type MailSender,
  type RegistrationCodeMail,
  type TokenMail,
} from '../../src/modules/mail/mail-sender.js';
import { PrismaClient } from '../../src/generated/prisma/client.js';
import { PrismaService } from '../../src/prisma/prisma.service.js';
import { BackgroundTasks } from '../../src/common/background/background-tasks.js';

export type CapturedKind = 'verify' | 'reset' | 'code' | 'account_exists';

/** Every captured mail; fields that do not apply to a kind are empty strings. */
export interface CapturedMail {
  readonly kind: CapturedKind;
  readonly to: string;
  readonly locale: MailLocale;
  readonly token: string;
  readonly link: string;
  readonly code: string;
}

/** Test double for the MailSender port: records messages so tests can read tokens and codes. */
export class CapturingMailSender implements MailSender {
  readonly sent: CapturedMail[] = [];

  sendEmailVerification(mail: TokenMail): Promise<void> {
    this.sent.push({
      kind: 'verify',
      to: mail.to,
      locale: mail.locale,
      token: mail.token,
      link: mail.link,
      code: '',
    });
    return Promise.resolve();
  }

  sendPasswordReset(mail: TokenMail): Promise<void> {
    this.sent.push({
      kind: 'reset',
      to: mail.to,
      locale: mail.locale,
      token: mail.token,
      link: mail.link,
      code: '',
    });
    return Promise.resolve();
  }

  sendRegistrationCode(mail: RegistrationCodeMail): Promise<void> {
    this.sent.push({ kind: 'code', to: mail.to, locale: mail.locale, token: '', link: '', code: mail.code });
    return Promise.resolve();
  }

  sendAccountExistsNotice(mail: AccountExistsMail): Promise<void> {
    this.sent.push({
      kind: 'account_exists',
      to: mail.to,
      locale: mail.locale,
      token: '',
      link: '',
      code: '',
    });
    return Promise.resolve();
  }

  last(to: string, kind: CapturedKind, after = 0): CapturedMail | undefined {
    return this.sent
      .slice(after)
      .reverse()
      .find((m) => m.to === to && m.kind === kind);
  }

  count(to: string, kind: CapturedKind): number {
    return this.sent.filter((m) => m.to === to && m.kind === kind).length;
  }

  /**
   * Polls for a mail (registration, resend and forgot-password mail is sent after the response).
   * `after` ignores mails captured before that index (use `mail.sent.length` before the request).
   */
  async waitFor(to: string, kind: CapturedKind, after = 0, timeoutMs = 3000): Promise<CapturedMail> {
    const deadline = Date.now() + timeoutMs;
    for (;;) {
      const mail = this.last(to, kind, after);
      if (mail) return mail;
      if (Date.now() > deadline) throw new Error(`No ${kind} mail for ${to}`);
      await new Promise((r) => setTimeout(r, 10));
    }
  }
}

export interface TestContext {
  readonly app: NestExpressApplication;
  readonly http: ReturnType<typeof request>;
  readonly config: AppConfig;
  readonly mail: CapturingMailSender;
  readonly prisma: PrismaService;
  close(): Promise<void>;
}

const GENEROUS = '10000/900';

export function buildTestConfig(overrides: Record<string, string> = {}): AppConfig {
  return loadConfig({
    NODE_ENV: 'test',
    LOG_LEVEL: 'silent',
    DATABASE_URL: process.env.DATABASE_URL,
    REDIS_URL: process.env.REDIS_URL,
    REDIS_KEY_PREFIX: `kabso-e2e:${randomBytes(6).toString('hex')}:`,
    JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
    APP_PUBLIC_URL: 'http://localhost:3000',
    MAIL_TRANSPORT: 'log',
    RATE_LIMIT_KEY_SECRET: randomBytes(48).toString('base64url'),
    ARGON2_MAX_QUEUE: '1000',
    RATE_LIMIT_LOGIN_IP_ACCOUNT: GENEROUS,
    RATE_LIMIT_LOGIN_ACCOUNT: GENEROUS,
    RATE_LIMIT_LOGIN_IP: GENEROUS,
    RATE_LIMIT_REGISTER_IP: GENEROUS,
    RATE_LIMIT_FORGOT_EMAIL: GENEROUS,
    RATE_LIMIT_FORGOT_IP: GENEROUS,
    RATE_LIMIT_REFRESH_SESSION: GENEROUS,
    RATE_LIMIT_AUTHENTICATED_USER: GENEROUS,
    RATE_LIMIT_EMAIL_RESEND_USER: GENEROUS,
    RATE_LIMIT_PUBLIC_IP: GENEROUS,
    RATE_LIMIT_REGISTER_EMAIL: GENEROUS,
    RATE_LIMIT_REGISTER_VERIFY_IP: GENEROUS,
    RATE_LIMIT_REGISTER_VERIFY_EMAIL: GENEROUS,
    RATE_LIMIT_REGISTER_RESEND_EMAIL: GENEROUS,
    RATE_LIMIT_REGISTER_RESEND_IP: GENEROUS,
    RATE_LIMIT_UPDATE_ME_USER: GENEROUS,
    // v1.3 (KL-037)
    RATE_LIMIT_LIVE_LIST_USER: GENEROUS,
    RATE_LIMIT_PROFILE_USER: GENEROUS,
    RATE_LIMIT_LIVE_START_HOUR_USER: GENEROUS,
    RATE_LIMIT_LIVE_START_DAY_USER: GENEROUS,
    RATE_LIMIT_LIVE_HEARTBEAT_USER: GENEROUS,
    RATE_LIMIT_LIVE_END_USER: GENEROUS,
    // CP-010 (KL-063)
    RATE_LIMIT_LIVE_MEDIA_TOKEN_USER: GENEROUS,
    RATE_LIMIT_LIVE_MEDIA_TOKEN_GUEST_IP: GENEROUS,
    RATE_LIMIT_LIVE_UPDATE_USER: GENEROUS,
    RATE_LIMIT_LIVE_GUEST_READ_IP: GENEROUS,
    // CP-011 (KL-064)
    RATE_LIMIT_LIVE_SEAT_ASK_USER: GENEROUS,
    RATE_LIMIT_LIVE_SEAT_ACTION_USER: GENEROUS,
    RATE_LIMIT_LIVE_SEATS_READ_USER: GENEROUS,
    // CP-012 (KL-065)
    RATE_LIMIT_LIVE_TAPS_USER: GENEROUS,
    // A LiveKit identity for signing tokens; the media server itself is the in-memory fake
    // (createTestApp) unless a spec passes the real adapter.
    LIVEKIT_URL: 'ws://127.0.0.1:7880',
    LIVEKIT_API_KEY: 'devkey',
    LIVEKIT_API_SECRET: 'secret',
    RATE_LIMIT_FOLLOW_HOUR_USER: GENEROUS,
    RATE_LIMIT_FOLLOW_DAY_USER: GENEROUS,
    // v1.5-social (KL-060)
    RATE_LIMIT_MEDIA_UPLOAD_USER: GENEROUS,
    RATE_LIMIT_POST_CREATE_HOUR_USER: GENEROUS,
    RATE_LIMIT_POST_CREATE_DAY_USER: GENEROUS,
    RATE_LIMIT_COMMENT_USER: GENEROUS,
    RATE_LIMIT_LIKE_USER: GENEROUS,
    RATE_LIMIT_REPOST_USER: GENEROUS,
    RATE_LIMIT_SHARE_USER: GENEROUS,
    RATE_LIMIT_VIEWS_USER: GENEROUS,
    RATE_LIMIT_STORY_CREATE_USER: GENEROUS,
    RATE_LIMIT_STORY_SEEN_USER: GENEROUS,
    RATE_LIMIT_NOTIFICATIONS_READ_USER: GENEROUS,
    RATE_LIMIT_FEED_USER: GENEROUS,
    RATE_LIMIT_SEARCH_USER: GENEROUS,
    RATE_LIMIT_BLOCK_USER: GENEROUS,
    RATE_LIMIT_REPORT_USER: GENEROUS,
    // No background workers in tests: specs call MediaService.sweep() / the publisher directly.
    MEDIA_SWEEP_INTERVAL_SECONDS: '0',
    POSTS_PUBLISH_INTERVAL_SECONDS: '0',
    NOTIFICATIONS_SWEEP_INTERVAL_SECONDS: '0',
    // No background sweeper in tests: specs call LiveRoomsService.sweepStale() with a fake clock.
    LIVE_SWEEP_INTERVAL_SECONDS: '0',
    ...overrides,
  });
}

/**
 * Runs `fn` with a short-lived client connected as the MIGRATION role (MIGRATION_DATABASE_URL).
 * The API under test uses the DML-only runtime role (SEC-011), which may not TRUNCATE or run DDL;
 * test fixtures that need those rights go through this client.
 */
export async function withMigrationClient<T>(fn: (client: PrismaClient) => Promise<T>): Promise<T> {
  const url = process.env.MIGRATION_DATABASE_URL;
  if (!url) throw new Error('MIGRATION_DATABASE_URL is not set (see test/global-setup.ts)');
  const client = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });
  try {
    return await fn(client);
  } finally {
    await client.$disconnect();
  }
}

/**
 * Removes every table row (the e2e database is dedicated to tests). Every application table is
 * truncated, so tables added by later migrations are covered without editing this list.
 */
export async function resetDatabase(): Promise<void> {
  await withMigrationClient((client) =>
    client.$executeRawUnsafe(`
      DO $$
      DECLARE tables text;
      BEGIN
        SELECT string_agg(format('%I.%I', schemaname, tablename), ', ') INTO tables
          FROM pg_tables
         WHERE schemaname = current_schema() AND tablename <> '_prisma_migrations';
        IF tables IS NOT NULL THEN
          EXECUTE 'TRUNCATE TABLE ' || tables || ' CASCADE';
        END IF;
      END
      $$`),
  );
}

async function deleteRedisKeys(url: string, prefix: string): Promise<void> {
  const redis = new Redis(url, { lazyConnect: true, maxRetriesPerRequest: 1 });
  await redis.connect();
  try {
    let cursor = '0';
    do {
      const [next, keys] = await redis.scan(cursor, 'MATCH', `${prefix}*`, 'COUNT', 500);
      cursor = next;
      if (keys.length > 0) await redis.del(...keys);
    } while (cursor !== '0');
  } finally {
    redis.disconnect();
  }
}

export interface ProviderOverride {
  readonly token: string | symbol | (abstract new (...args: never[]) => unknown);
  readonly value: unknown;
}

export async function createTestApp(
  overrides: Record<string, string> = {},
  providerOverrides: readonly ProviderOverride[] = [],
): Promise<TestContext> {
  const config = buildTestConfig(overrides);
  const mail = new CapturingMailSender();
  let builder = Test.createTestingModule({ imports: [AppModule.register(config)] })
    .overrideProvider(MAIL_SENDER)
    .useValue(mail);
  // CP-010: never a real media server unless a spec passes one (the in-memory fake by default).
  const overridesWithMedia = providerOverrides.some((o) => o.token === LIVE_MEDIA_PROVIDER)
    ? providerOverrides
    : [{ token: LIVE_MEDIA_PROVIDER, value: new MemoryLiveMedia() }, ...providerOverrides];
  for (const override of overridesWithMedia) {
    builder = builder.overrideProvider(override.token).useValue(override.value);
  }
  const moduleRef = await builder.compile();
  const app = moduleRef.createNestApplication<NestExpressApplication>({ bodyParser: false });
  configureApp(app, config);
  await app.init();
  const prisma = app.get(PrismaService);
  await resetDatabase();

  return {
    app,
    http: request(app.getHttpServer()),
    config,
    mail,
    prisma,
    async close() {
      await app.close();
      await deleteRedisKeys(config.redis.url, config.redis.keyPrefix);
    },
  };
}

/** Waits until every background task (post-response work such as mail) has finished. */
export async function settle(ctx: TestContext): Promise<void> {
  await ctx.app.get(BackgroundTasks).idle();
}

export interface VerifiedRegistration {
  readonly payload: ReturnType<typeof newUser>;
  /** The `POST /auth/register/verify` response (201 AuthResponse on success). */
  readonly res: request.Response;
  readonly code: string;
}

/**
 * v1.2 verify-first registration as one step: `register` (expects 202), read the emailed code,
 * `register/verify`. Returns the verify response (201 AuthResponse), i.e. what `register`
 * returned before contract v1.2.
 */
export async function registerVerified(
  ctx: TestContext,
  overrides: Partial<Record<string, unknown>> = {},
): Promise<VerifiedRegistration> {
  const payload = newUser(overrides);
  const email = String(payload.email).trim().toLowerCase();
  const before = ctx.mail.sent.length;
  const reg = await ctx.http.post('/api/v1/auth/register').send(payload);
  if (reg.status !== 202) {
    throw new Error(`register returned ${reg.status}: ${JSON.stringify(reg.body)}`);
  }
  const mail = await ctx.mail.waitFor(email, 'code', before);
  const res = await ctx.http
    .post('/api/v1/auth/register/verify')
    .send({ email, code: mail.code, ...(payload.device ? { device: payload.device } : {}) });
  return { payload, res, code: mail.code };
}

let counter = 0;

/** Unique, contract-valid registration payload. */
export function newUser(overrides: Partial<Record<string, unknown>> = {}) {
  counter += 1;
  const suffix = `${Date.now().toString(36)}${counter}`;
  return {
    email: `user${suffix}@example.com`,
    password: 'correct horse battery staple',
    username: `user${suffix}`,
    displayName: 'Test User',
    locale: 'en',
    device: { name: 'Pixel 9', platform: 'android', appVersion: '1.0.0' },
    ...overrides,
  };
}
