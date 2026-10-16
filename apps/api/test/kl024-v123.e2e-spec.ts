/**
 * KL-024: contract v1.2.3 / v1.2.4 fixes (KL-007c SEC-023 race, SEC-024, SEC-025, SEC-026,
 * SEC-027; QA-010/012). Config-level rules (SEC-003a, SEC-029) are unit-tested.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { ARGON2_BACKEND, type Argon2Backend } from '../src/modules/auth/password-hasher.service.js';
import { createTestApp, newUser, registerVerified, settle, type TestContext } from './helpers/test-app.js';

const cp = (...points: number[]) => String.fromCodePoint(...points);

describe('SEC-025 / SEC-026 pending registrations', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
  });

  afterAll(async () => {
    await ctx?.close();
  });

  const register = (body: object) => ctx.http.post('/api/v1/auth/register').send(body);
  const verify = (email: string, code: string) =>
    ctx.http.post('/api/v1/auth/register/verify').send({ email, code });

  async function pending(overrides: Partial<Record<string, unknown>> = {}) {
    const payload = newUser(overrides);
    const before = ctx.mail.sent.length;
    expect((await register(payload)).status).toBe(202);
    const code = (await ctx.mail.waitFor(String(payload.email), 'code', before)).code;
    return { payload, code };
  }

  it('SEC-025: a username held by a live pending gets the identical 409 for every email, incl. its own', async () => {
    const { payload } = await pending();
    const sameEmail = await register({ ...newUser(), email: payload.email, username: payload.username });
    const otherEmail = await register({ ...newUser(), username: payload.username });
    for (const res of [sameEmail, otherEmail]) {
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('USERNAME_TAKEN');
    }
    expect({ ...sameEmail.body.error, requestId: 'x' }).toEqual({ ...otherEmail.body.error, requestId: 'x' });
    // The holder's pending registration was not replaced: its code still works.
    await settle(ctx);
    const row = await ctx.prisma.pendingRegistration.findUniqueOrThrow({ where: { email: payload.email } });
    expect(row.username).toBe(payload.username);
  });

  it('SEC-026: resend never extends a pending registration past 2 h from creation', async () => {
    const { payload } = await pending();
    const createdAt = new Date(Date.now() - (2 * 3600 - 10 * 60) * 1000); // 1 h 50 min ago
    await ctx.prisma.pendingRegistration.update({ where: { email: payload.email }, data: { createdAt } });

    const before = ctx.mail.sent.length;
    expect((await ctx.http.post('/api/v1/auth/register/resend').send({ email: payload.email })).status).toBe(
      202,
    );
    await ctx.mail.waitFor(payload.email, 'code', before);
    const row = await ctx.prisma.pendingRegistration.findUniqueOrThrow({ where: { email: payload.email } });
    expect(row.expiresAt.getTime()).toBeLessThanOrEqual(createdAt.getTime() + 2 * 3600 * 1000);
    expect(row.expiresAt.getTime()).toBeLessThan(Date.now() + 11 * 60 * 1000);

    // Past the absolute lifetime, resend sends nothing and the code no longer verifies.
    await ctx.prisma.pendingRegistration.update({
      where: { email: payload.email },
      data: { createdAt: new Date(Date.now() - 3 * 3600 * 1000), expiresAt: new Date(Date.now() - 1000) },
    });
    const later = ctx.mail.sent.length;
    await ctx.http.post('/api/v1/auth/register/resend').send({ email: payload.email });
    await settle(ctx);
    expect(ctx.mail.sent.length).toBe(later);
  });

  it('SEC-026: at most 10 code checks per pending registration across resends', async () => {
    const { payload } = await pending();
    let latest = '';
    for (let round = 0; round < 3; round += 1) {
      const before = ctx.mail.sent.length;
      await ctx.http.post('/api/v1/auth/register/resend').send({ email: payload.email });
      latest = (await ctx.mail.waitFor(payload.email, 'code', before)).code;
      const wrong = latest === '00000000' ? '00000001' : '00000000';
      for (let i = 0; i < 4; i += 1) expect((await verify(payload.email, wrong)).status).toBe(422);
    }
    // 12 checks were requested; only 10 were possible, then the row was deleted.
    expect(await ctx.prisma.pendingRegistration.count({ where: { email: payload.email } })).toBe(0);
    expect((await verify(payload.email, latest)).status).toBe(422);
    expect(await ctx.prisma.user.count({ where: { email: payload.email } })).toBe(0);
  });
});

describe('SEC-027 verify budget per email', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_REGISTER_VERIFY_EMAIL: '15/86400' });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('allows 15 verify calls per email per day, then 429 (any case)', async () => {
    const email = `budget-${Date.now()}@example.com`;
    for (let i = 0; i < 15; i += 1) {
      const res = await ctx.http
        .post('/api/v1/auth/register/verify')
        .send({ email: i % 2 ? email.toUpperCase() : email, code: '12345678' });
      expect(res.status).toBe(422);
    }
    const limited = await ctx.http.post('/api/v1/auth/register/verify').send({ email, code: '12345678' });
    expect(limited.status).toBe(429);
    expect(limited.body.error.code).toBe('RATE_LIMITED');
    expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
    // Another email is unaffected.
    const other = await ctx.http
      .post('/api/v1/auth/register/verify')
      .send({ email: `other-${email}`, code: '12345678' });
    expect(other.status).toBe(422);
  });
});

describe('SEC-023 race: account bucket reserved before the Argon2 check', () => {
  class CountingArgon2 implements Argon2Backend {
    verifies = 0;
    hash(password: string): Promise<string> {
      return Promise.resolve(`fake$${password}`);
    }
    async verify(hash: string, password: string): Promise<boolean> {
      this.verifies += 1;
      await new Promise((resolve) => setTimeout(resolve, 5));
      return hash === `fake$${password}`;
    }
    needsRehash(): boolean {
      return false;
    }
  }

  const argon2 = new CountingArgon2();
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ TRUST_PROXY: 'loopback', RATE_LIMIT_LOGIN_ACCOUNT: '20/900' }, [
      { token: ARGON2_BACKEND, value: argon2 },
    ]);
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('60 parallel wrong passwords from 60 IPs → at most 20 Argon2 verifications', async () => {
    const { payload, res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    const before = argon2.verifies;
    const results = await Promise.all(
      Array.from({ length: 60 }, (_, i) =>
        ctx.http
          .post('/api/v1/auth/login')
          .set('X-Forwarded-For', `198.18.${Math.floor(i / 250)}.${(i % 250) + 1}`)
          .send({ identifier: payload.email, password: 'wrong password!!' }),
      ),
    );
    const checked = argon2.verifies - before;
    expect(checked).toBeLessThanOrEqual(20);
    const statuses = results.map((r) => r.status);
    expect(statuses.filter((s) => s === 401)).toHaveLength(checked);
    expect(statuses.filter((s) => s === 429)).toHaveLength(60 - checked);
  });

  it('a successful login refunds its reserved slot', async () => {
    const { payload } = await registerVerified(ctx);
    // 20 correct logins from 20 new sources: each reserves and refunds, none is a failure.
    for (let i = 1; i <= 20; i += 1) {
      const ok = await ctx.http
        .post('/api/v1/auth/login')
        .set('X-Forwarded-For', `198.19.0.${i}`)
        .send({ identifier: payload.email, password: payload.password });
      expect(ok.status).toBe(200);
    }
    // The account bucket is still empty: 20 failures from new sources are all evaluated.
    const statuses: number[] = [];
    for (let i = 1; i <= 21; i += 1) {
      const res = await ctx.http
        .post('/api/v1/auth/login')
        .set('X-Forwarded-For', `198.19.1.${i}`)
        .send({ identifier: payload.email, password: 'wrong password!!' });
      statuses.push(res.status);
    }
    expect(statuses.filter((s) => s === 401)).toHaveLength(20);
    expect(statuses[20]).toBe(429);
  });
});

describe('displayName v1.2.3 / v1.2.4 end to end', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
  });

  afterAll(async () => {
    await ctx?.close();
  });

  const register = (displayName: string) =>
    ctx.http.post('/api/v1/auth/register').send(newUser({ displayName }));

  it.each([
    `AD${cp(0x39c)}IN`,
    `AD${cp(0x41c)}IN`,
    `KA${cp(0x392)}SO`,
    `ADMI${cp(0x39d)}`,
    `kabs${cp(0x3c3)}`,
    `kabs${cp(0x585)}`,
    `${cp(0x1d0b)}abso`,
    `kab${cp(0xa731)}o`,
    `${cp(0x13e6)}ABSO`,
    `${cp(0xa4d7)}ABSO`,
    `كابس${cp(0x6c6)}`,
    `${cp(0x63b)}ابسو`,
  ])('refuses A7 bypass %s', async (displayName) => {
    const res = await register(displayName);
    expect(res.status).toBe(400);
    expect(['reserved_term', 'invalid_format']).toContain(res.body.error.details[0].issue);
  });

  it.each(['TheKabsoTeam', 'فريقكابسوالرسمي'])('refuses the brand inside a word: %s', async (displayName) => {
    const res = await register(displayName);
    expect(res.status).toBe(400);
    expect(res.body.error.details).toEqual([{ field: 'displayName', issue: 'reserved_term' }]);
  });

  it.each([`Sara${cp(0x200e)}`, `سارة${cp(0x200f)} علي`, `علي${cp(0x61c)}`])(
    'refuses bidi marks LRM/RLM/ALM (%#)',
    async (displayName) => {
      const res = await register(displayName);
      expect(res.status).toBe(400);
      expect(res.body.error.details).toEqual([{ field: 'displayName', issue: 'invalid_format' }]);
    },
  );

  it('QA-010: a whitespace-only name is invalid_format', async () => {
    const res = await register('   ');
    expect(res.status).toBe(400);
    expect(res.body.error.details).toEqual([{ field: 'displayName', issue: 'invalid_format' }]);
  });

  it.each([
    'Staff Sergeant',
    'مشرف علي',
    'Sara سارة',
    `می${cp(0x200c)}خواهم`,
    'مُحَمَّد',
    'Zoë Ünïcødé',
    'ڕۆژان ئەحمەد',
    'شاہد آفریدی',
  ])('accepts legitimate name %s', async (displayName) => {
    const res = await register(displayName);
    expect(res.status).toBe(202);
  });
});
