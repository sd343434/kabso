import 'reflect-metadata';
import { randomBytes } from 'node:crypto';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { Redis } from 'ioredis';
import request from 'supertest';
import { AppModule } from '../../src/app.module.js';
import { configureApp } from '../../src/app.setup.js';
import { loadConfig, type AppConfig } from '../../src/config/app-config.js';
import { MAIL_SENDER, type MailSender, type TokenMail } from '../../src/modules/mail/mail-sender.js';
import { PrismaService } from '../../src/prisma/prisma.service.js';

export interface CapturedMail extends TokenMail {
  readonly kind: 'verify' | 'reset';
}

/** Test double for the MailSender port: records messages so tests can read the tokens. */
export class CapturingMailSender implements MailSender {
  readonly sent: CapturedMail[] = [];

  sendEmailVerification(mail: TokenMail): Promise<void> {
    this.sent.push({ ...mail, kind: 'verify' });
    return Promise.resolve();
  }

  sendPasswordReset(mail: TokenMail): Promise<void> {
    this.sent.push({ ...mail, kind: 'reset' });
    return Promise.resolve();
  }

  last(to: string, kind: CapturedMail['kind']): CapturedMail | undefined {
    return [...this.sent].reverse().find((m) => m.to === to && m.kind === kind);
  }

  /** Polls for a mail (forgot-password is processed after the 202 is sent). */
  async waitFor(to: string, kind: CapturedMail['kind'], timeoutMs = 3000): Promise<CapturedMail> {
    const deadline = Date.now() + timeoutMs;
    for (;;) {
      const mail = this.last(to, kind);
      if (mail) return mail;
      if (Date.now() > deadline) throw new Error(`No ${kind} mail for ${to}`);
      await new Promise((r) => setTimeout(r, 20));
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
    ...overrides,
  });
}

/** Removes every table row (the e2e database is dedicated to tests). */
export async function resetDatabase(prisma: PrismaService): Promise<void> {
  await prisma.$executeRawUnsafe(
    'TRUNCATE TABLE audit_logs, verification_tokens, sessions, user_settings, user_profiles, users CASCADE',
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

export async function createTestApp(overrides: Record<string, string> = {}): Promise<TestContext> {
  const config = buildTestConfig(overrides);
  const mail = new CapturingMailSender();
  const moduleRef = await Test.createTestingModule({ imports: [AppModule.register(config)] })
    .overrideProvider(MAIL_SENDER)
    .useValue(mail)
    .compile();
  const app = moduleRef.createNestApplication<NestExpressApplication>({ bodyParser: false });
  configureApp(app, config);
  await app.init();
  const prisma = app.get(PrismaService);
  await resetDatabase(prisma);

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
