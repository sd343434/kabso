/**
 * KL-007d security regression tests (A7) for the KL-024 fixes (contract v1.2.3–v1.2.5). Each test
 * pins a fix the re-test verified. Residual findings are described in
 * docs/security/KL-007_PHASE1_REVIEW.md §8, not encoded here.
 */
import { randomBytes } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { ConfigValidationError, loadConfig } from '../../src/config/app-config.js';
import { rawDisplayNameIssue } from '../../src/modules/users/display-name.js';
import { createTestApp, newUser, registerVerified, settle, type TestContext } from '../helpers/test-app.js';

const TERMS = [
  'kabso',
  'admin',
  'administrator',
  'support',
  'official',
  'moderator',
  'كابسو',
  'الدعم',
  'رسمي',
  'الإدارة',
];
const BRANDS = ['kabso', 'كابسو'];

describe('KL-007d SEC-024: reserved terms after the confusables rework', () => {
  const issue = (raw: string) => rawDisplayNameIssue(raw, TERMS, BRANDS);

  it.each([
    ['Greek Mu', 'ADΜIN'],
    ['Cyrillic Em', 'ADМIN'],
    ['Greek Beta', 'KAΒSO'],
    ['Greek Nu', 'ADMIΝ'],
    ['Greek sigma', 'kabsσ'],
    ['Armenian oh', 'kabsօ'],
    ['Coptic o', 'kabsⲟ'],
    ['Lao zero', 'kabs໐'],
    ['small capital K', 'ᴋabso'],
    ['small capital S', 'kabꜱo'],
    ['Cherokee K', 'ᏦABSO'],
    ['Lisu K', 'ꓗABSO'],
    ['Arabic U+06C6', 'كابسۆ'],
    ['Arabic U+063B', 'ػابسو'],
    ['brand inside a word', 'TheKabsoTeam'],
    ['Arabic brand inside a word', 'فريقكابسوالرسمي'],
    ['all-Cyrillic capitals', 'КАВЅО'],
    ['all-Cherokee', 'ᏦᎪᏴᏚᎾ'],
    ['math bold', '\u{1D40A}\u{1D41A}\u{1D41B}\u{1D42C}\u{1D428}'],
    ['digit one for i', 'Adm1n'],
  ])('rejects the %s spoof', (_label, raw) => {
    expect(issue(raw)).not.toBeNull();
  });

  it.each([
    ['LRM', 'abc‎def'],
    ['RLM', 'abc‏def'],
    ['ALM', 'abc؜def'],
  ])('rejects the bidi mark %s with invalid_format', (_label, raw) => {
    expect(issue(raw)).toBe('invalid_format');
  });

  it.each([
    'Sara سارة',
    'محمد علي',
    'Zoë Đorđević',
    'Işık Yılmaz',
    'Nguyễn Văn An',
    'Γιώργος',
    'Алексей Смирнов',
    '田中さん',
    '김민수',
    'राम कुमार',
    'שרה',
    'می‌خواهم',
    'Kab Sonia',
    'Badminton Club',
    'Supporter',
    'Stafford',
    'مشرف',
    'DJ Ахмед',
    'Ali🔥',
    'Jean-Luc',
  ])('accepts the legitimate name %s', (raw) => {
    expect(issue(raw)).toBeNull();
  });
});

describe('KL-007d registration fixes (SEC-025/026/027)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_REGISTER_VERIFY_EMAIL: '15/86400' });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('SEC-025: a username held by a pending registration is 409 even for the same email', async () => {
    const pending = newUser();
    expect((await ctx.http.post('/api/v1/auth/register').send(pending)).status).toBe(202);
    await settle(ctx);
    const sameEmail = await ctx.http
      .post('/api/v1/auth/register')
      .send(newUser({ email: pending.email, username: pending.username }));
    const otherEmail = await ctx.http
      .post('/api/v1/auth/register')
      .send(newUser({ username: pending.username }));
    expect(sameEmail.status).toBe(409);
    expect(otherEmail.status).toBe(409);
    expect(JSON.stringify({ ...sameEmail.body.error, requestId: 0 })).toBe(
      JSON.stringify({ ...otherEmail.body.error, requestId: 0 }),
    );
  });

  it('SEC-026: resend never extends a pending registration past created_at + 2 h', async () => {
    const pending = newUser();
    await ctx.http.post('/api/v1/auth/register').send(pending);
    await settle(ctx);
    const createdAt = new Date(Date.now() - 115 * 60_000);
    await ctx.prisma.pendingRegistration.update({ where: { email: pending.email }, data: { createdAt } });
    await ctx.http.post('/api/v1/auth/register/resend').send({ email: pending.email });
    await settle(ctx);
    const row = await ctx.prisma.pendingRegistration.findUniqueOrThrow({ where: { email: pending.email } });
    expect(row.expiresAt.getTime()).toBeLessThanOrEqual(createdAt.getTime() + 2 * 3600_000);
  });

  it('SEC-026: at most 10 code checks per pending registration across resends', async () => {
    const pending = newUser();
    await ctx.http.post('/api/v1/auth/register').send(pending);
    await settle(ctx);
    const wrong = (i: number) => `9${String(i).padStart(7, '0')}`;
    for (let round = 0; round < 3; round += 1) {
      for (let i = 0; i < 4; i += 1) {
        await ctx.http
          .post('/api/v1/auth/register/verify')
          .send({ email: pending.email, code: wrong(round * 10 + i) });
      }
      const before = ctx.mail.sent.length;
      await ctx.http.post('/api/v1/auth/register/resend').send({ email: pending.email });
      await settle(ctx);
      if (round === 2) {
        // The pending registration is gone after 10 checks: resend sends nothing, and even a
        // correct code from the last mail cannot verify any more.
        expect(ctx.mail.sent.length).toBe(before);
      }
    }
    const last = ctx.mail.last(String(pending.email), 'code');
    const res = await ctx.http
      .post('/api/v1/auth/register/verify')
      .send({ email: pending.email, code: last?.code });
    expect(res.status).toBe(422);
    expect(await ctx.prisma.user.count({ where: { email: pending.email } })).toBe(0);
  });

  it('SEC-027: at most 15 verify attempts per email per day, across IPs', async () => {
    const pending = newUser();
    await ctx.http.post('/api/v1/auth/register').send(pending);
    await settle(ctx);
    const statuses: number[] = [];
    for (let i = 0; i < 17; i += 1) {
      const res = await ctx.http
        .post('/api/v1/auth/register/verify')
        .send({ email: pending.email, code: `7${String(i).padStart(7, '0')}` });
      statuses.push(res.status);
    }
    expect(statuses.filter((s) => s === 429)).toHaveLength(2);
    expect(statuses.slice(0, 15).every((s) => s === 422)).toBe(true);
  });
});

describe('KL-007d SEC-023: account bucket is race-free', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    // Loopback is the trusted proxy, so X-Forwarded-For gives each attempt its own client IP
    // (and none of them is the source that verified the account, which would be trusted).
    ctx = await createTestApp({ RATE_LIMIT_LOGIN_ACCOUNT: '20/900', TRUST_PROXY: 'loopback' });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('60 parallel wrong passwords from 60 IPs check at most 20 passwords', async () => {
    const { payload, res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    const results = await Promise.all(
      Array.from({ length: 60 }, (_, i) =>
        ctx.http
          .post('/api/v1/auth/login')
          .set('X-Forwarded-For', `100.64.${Math.floor(i / 250)}.${(i % 250) + 1}`)
          .send({ identifier: payload.username, password: `wrong-${i}-pw` }),
      ),
    );
    expect(results.every((r) => [401, 429, 503].includes(r.status))).toBe(true);
    const checks = await ctx.prisma.auditLog.count({
      where: { action: 'auth.login.failure', actorUserId: res.body.user.id as string },
    });
    expect(checks).toBeGreaterThan(0);
    expect(checks).toBeLessThanOrEqual(20);
    expect(results.filter((r) => r.status === 429).length).toBeGreaterThanOrEqual(40);
  });
});

describe('KL-007d production configuration (SEC-003a, SEC-029)', () => {
  const key = () => randomBytes(48).toString('base64');
  const base = () => ({
    NODE_ENV: 'production',
    DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
    REDIS_URL: 'redis://localhost:6379',
    APP_PUBLIC_URL: 'https://kabso.example',
    JWT_ACCESS_SECRET: key(),
    RATE_LIMIT_KEY_SECRET: key(),
  });
  const problems = (env: Record<string, string>): string[] => {
    try {
      loadConfig(env);
      return [];
    } catch (err) {
      if (err instanceof ConfigValidationError)
        return err.problems.filter((p) => !p.startsWith('MAIL_TRANSPORT'));
      throw err;
    }
  };

  it.each([
    '0.0.0.0/1,128.0.0.0/1',
    '::/1,8000::/1',
    '::ffff:0:0/96',
    '::ffff:0.0.0.0/96',
    '0.0.0.0/7',
    '2000::/16',
    '4',
  ])('refuses TRUST_PROXY=%s', (value) => {
    expect(problems({ ...base(), TRUST_PROXY: value }).some((p) => p.startsWith('TRUST_PROXY'))).toBe(true);
  });

  it.each(['1', '3', '10.0.0.0/8', '2001:db8::/32', 'loopback'])('accepts TRUST_PROXY=%s', (value) => {
    expect(problems({ ...base(), TRUST_PROXY: value })).toEqual([]);
  });

  it('REGISTRATION_CODE_KEY must be strong and distinct from the other keys', () => {
    const env = base();
    expect(problems({ ...env, REGISTRATION_CODE_KEY: key() })).toEqual([]);
    for (const bad of [
      'kabso-registration-code-key-2026!!',
      env.JWT_ACCESS_SECRET,
      env.RATE_LIMIT_KEY_SECRET,
    ]) {
      expect(
        problems({ ...env, REGISTRATION_CODE_KEY: bad }).some((p) => p.startsWith('REGISTRATION_CODE_KEY')),
      ).toBe(true);
    }
  });
});
