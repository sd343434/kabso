/**
 * KL-019 verify-first registration and KL-018 locale (contract v1.2 §6/§7).
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { ARGON2_BACKEND, type Argon2Backend } from '../src/modules/auth/password-hasher.service.js';
import { RegistrationService } from '../src/modules/auth/registration.service.js';
import { createTestApp, newUser, registerVerified, settle, type TestContext } from './helpers/test-app.js';

const PENDING = { status: 'verification_pending' };
const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

function expectTokenInvalid(res: { status: number; body: unknown }) {
  expect(res.status).toBe(422);
  expect(res.body).toEqual({
    error: { code: 'TOKEN_INVALID', message: 'Token is invalid.', requestId: 'same-request-id' },
  });
}

describe('KL-019 verify-first registration', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
  });

  afterAll(async () => {
    await ctx?.close();
  });

  const register = (body: object, headers: Record<string, string> = {}) =>
    ctx.http.post('/api/v1/auth/register').set(headers).send(body);
  const verify = (email: string, code: string) =>
    ctx.http
      .post('/api/v1/auth/register/verify')
      .set('X-Request-Id', 'same-request-id')
      .send({ email, code });

  it('answers a new and an existing email with the same 202 body and no tokens', async () => {
    const existing = await registerVerified(ctx);
    expect(existing.res.status).toBe(201);

    const fresh = await register(newUser());
    const dup = await register(newUser({ email: existing.payload.email }));
    for (const res of [fresh, dup]) {
      expect(res.status).toBe(202);
      expect(res.body).toEqual(PENDING);
      expect(Object.keys(res.headers)).not.toContain('set-cookie');
      expect(JSON.stringify(res.body)).not.toMatch(/token/i);
    }
    expect(dup.headers['content-type']).toBe(fresh.headers['content-type']);
  });

  it('sends the account owner a notice (account locale) and creates no pending row', async () => {
    const owner = await registerVerified(ctx, { locale: 'ar' });
    const before = ctx.mail.sent.length;
    const res = await register(newUser({ email: owner.payload.email, locale: 'en' }), {
      'Accept-Language': 'en',
    });
    expect(res.status).toBe(202);
    const notice = await ctx.mail.waitFor(owner.payload.email, 'account_exists', before);
    expect(notice.locale).toBe('ar'); // account's stored locale, not the request's
    await settle(ctx);
    expect(ctx.mail.last(owner.payload.email, 'code', before)).toBeUndefined();
    expect(await ctx.prisma.pendingRegistration.count({ where: { email: owner.payload.email } })).toBe(0);
    const audit = await ctx.prisma.auditLog.count({
      where: { action: 'auth.registration.existing_email_notice', targetId: owner.res.body.user.id },
    });
    expect(audit).toBe(1);

    // At most one notice per hour per account.
    await register(newUser({ email: owner.payload.email }));
    await settle(ctx);
    expect(ctx.mail.count(owner.payload.email, 'account_exists')).toBe(1);
  });

  it('keeps one live pending per email: a replacement invalidates the old code and frees the old username', async () => {
    const first = newUser();
    const before = ctx.mail.sent.length;
    expect((await register(first)).status).toBe(202);
    const oldCode = (await ctx.mail.waitFor(first.email, 'code', before)).code;

    const between = ctx.mail.sent.length;
    const second = newUser({ email: first.email });
    expect((await register(second)).status).toBe(202);
    const newCode = (await ctx.mail.waitFor(first.email, 'code', between)).code;
    await settle(ctx);

    const rows = await ctx.prisma.pendingRegistration.findMany({ where: { email: first.email } });
    expect(rows).toHaveLength(1);
    expect(rows[0]!.username).toBe(second.username);
    const replaced = await ctx.prisma.auditLog.count({
      where: { action: 'auth.registration.replaced', targetId: rows[0]!.id },
    });
    expect(replaced).toBe(1);

    // The old username is released.
    const availability = await ctx.http
      .get('/api/v1/users/username-availability')
      .query({ username: first.username });
    expect(availability.body).toEqual({ username: first.username, available: true });

    if (oldCode !== newCode) expectTokenInvalid(await verify(first.email, oldCode));
    const ok = await verify(first.email, newCode);
    expect(ok.status).toBe(201);
    expect(ok.body.user.username).toBe(second.username);
  });

  it('a username held by a live pending registration counts as taken (availability and register)', async () => {
    const holder = newUser();
    expect((await register(holder)).status).toBe(202);
    await settle(ctx);

    const availability = await ctx.http
      .get('/api/v1/users/username-availability')
      .query({ username: holder.username });
    expect(availability.body).toEqual({ username: holder.username, available: false });

    const clash = await register(newUser({ username: holder.username }));
    expect(clash.status).toBe(409);
    expect(clash.body.error.code).toBe('USERNAME_TAKEN');

    // Once the pending registration expires the reservation is gone.
    await ctx.prisma.pendingRegistration.updateMany({
      where: { email: holder.email },
      data: { expiresAt: new Date(Date.now() - 1000) },
    });
    const later = await ctx.http
      .get('/api/v1/users/username-availability')
      .query({ username: holder.username });
    expect(later.body.available).toBe(true);
    expect((await register(newUser({ username: holder.username }))).status).toBe(202);
  });

  it('verify success creates exactly one verified user and deletes the pending row', async () => {
    const payload = newUser({ locale: 'ar' });
    const before = ctx.mail.sent.length;
    await register(payload);
    const mail = await ctx.mail.waitFor(payload.email, 'code', before);
    expect(mail.code).toMatch(/^[0-9]{8}$/);
    const pending = await ctx.prisma.pendingRegistration.findUniqueOrThrow({
      where: { email: payload.email },
    });
    // The code is stored as a keyed HMAC, never in clear text.
    expect(pending.codeHash).toMatch(/^[0-9a-f]{64}$/);
    expect(JSON.stringify(pending)).not.toContain(mail.code);

    const res = await verify(payload.email, mail.code);
    expect(res.status).toBe(201);
    expect(Object.keys(res.body).sort()).toEqual(['tokens', 'user']);
    expect(res.body.user).toMatchObject({ email: payload.email, emailVerified: true, locale: 'ar' });

    const users = await ctx.prisma.user.findMany({ where: { email: payload.email } });
    expect(users).toHaveLength(1);
    expect(users[0]!.emailVerifiedAt).toBeInstanceOf(Date);
    expect(await ctx.prisma.pendingRegistration.count({ where: { email: payload.email } })).toBe(0);
    const me = await ctx.http.get('/api/v1/me').set(bearer(res.body.tokens.accessToken));
    expect(me.status).toBe(200);
    // Second use of the same code: the pending row is gone.
    expectTokenInvalid(await verify(payload.email, mail.code));
  });

  it('wrong, expired, unknown and exhausted codes all give the identical 422', async () => {
    // Unknown email (nothing pending).
    expectTokenInvalid(await verify('nobody-pending@example.com', '12345678'));

    // Wrong code.
    const wrong = newUser();
    let before = ctx.mail.sent.length;
    await register(wrong);
    const wrongCode = (await ctx.mail.waitFor(wrong.email, 'code', before)).code;
    const bad = wrongCode === '00000000' ? '00000001' : '00000000';
    expectTokenInvalid(await verify(wrong.email, bad));

    // Expired.
    const expired = newUser();
    before = ctx.mail.sent.length;
    await register(expired);
    const expiredCode = (await ctx.mail.waitFor(expired.email, 'code', before)).code;
    await ctx.prisma.pendingRegistration.updateMany({
      where: { email: expired.email },
      data: { expiresAt: new Date(Date.now() - 1000) },
    });
    expectTokenInvalid(await verify(expired.email, expiredCode));
    expect(await ctx.prisma.pendingRegistration.count({ where: { email: expired.email } })).toBe(0);

    // Exhausted: 5 wrong attempts delete the pending row; the right code then fails too.
    const exhausted = newUser();
    before = ctx.mail.sent.length;
    await register(exhausted);
    const rightCode = (await ctx.mail.waitFor(exhausted.email, 'code', before)).code;
    const other = rightCode === '11111111' ? '22222222' : '11111111';
    for (let i = 0; i < 5; i += 1) expectTokenInvalid(await verify(exhausted.email, other));
    expect(await ctx.prisma.pendingRegistration.count({ where: { email: exhausted.email } })).toBe(0);
    expectTokenInvalid(await verify(exhausted.email, rightCode));
    expect(await ctx.prisma.user.count({ where: { email: exhausted.email } })).toBe(0);

    // Internal reasons are audited, never returned.
    const reasons = (
      await ctx.prisma.auditLog.findMany({ where: { action: 'auth.registration.verify_failed' } })
    ).map((a) => (a.metadata as { reason: string }).reason);
    expect(new Set(reasons)).toEqual(new Set(['no_live_pending', 'wrong_code', 'attempts_exhausted']));
  });

  it('never checks more than 5 codes per pending registration, even concurrently', async () => {
    const payload = newUser();
    const before = ctx.mail.sent.length;
    await register(payload);
    const code = (await ctx.mail.waitFor(payload.email, 'code', before)).code;
    const guesses = Array.from({ length: 12 }, (_, i) =>
      String((Number(code) + i + 1) % 1e8).padStart(8, '0'),
    );
    const results = await Promise.all(guesses.map((g) => verify(payload.email, g)));
    for (const res of results) expectTokenInvalid(res);
    expect(await ctx.prisma.pendingRegistration.count({ where: { email: payload.email } })).toBe(0);
  });

  it('concurrent verifies of one pending registration create exactly one user', async () => {
    const payload = newUser();
    const before = ctx.mail.sent.length;
    await register(payload);
    const code = (await ctx.mail.waitFor(payload.email, 'code', before)).code;
    const results = await Promise.all(Array.from({ length: 4 }, () => verify(payload.email, code)));
    const statuses = results.map((r) => r.status).sort();
    expect(statuses).toEqual([201, 422, 422, 422]);
    for (const res of results.filter((r) => r.status === 422)) expectTokenInvalid(res);
    expect(await ctx.prisma.user.count({ where: { email: payload.email } })).toBe(1);
  });

  it('an email registered between register and verify → 422 and the owner gets the notice', async () => {
    const first = newUser();
    const second = newUser({ email: first.email });
    let before = ctx.mail.sent.length;
    await register(first);
    const firstCode = (await ctx.mail.waitFor(first.email, 'code', before)).code;
    // Simulate the address becoming an account by another path while this pending is live:
    // create the account directly, then try to verify.
    const created = await ctx.http
      .post('/api/v1/auth/register/verify')
      .send({ email: first.email, code: firstCode });
    expect(created.status).toBe(201);
    before = ctx.mail.sent.length;
    // A new pending for the same (now registered) address cannot be created via register, so
    // insert one the way a race would leave it.
    const registration = ctx.app.get(RegistrationService);
    const lateCode = '24681357';
    await ctx.prisma.pendingRegistration.create({
      data: {
        email: first.email,
        username: second.username,
        displayName: 'Late',
        locale: 'en',
        passwordHash: 'x',
        codeHash: registration.codeHash(first.email, lateCode),
        expiresAt: new Date(Date.now() + 60_000),
      },
    });
    expectTokenInvalid(await verify(first.email, lateCode));
    await ctx.mail.waitFor(first.email, 'account_exists', before);
    expect(await ctx.prisma.user.count({ where: { email: first.email } })).toBe(1);
    expect(await ctx.prisma.pendingRegistration.count({ where: { email: first.email } })).toBe(0);
    const reason = await ctx.prisma.auditLog.findFirst({
      where: {
        action: 'auth.registration.verify_failed',
        metadata: { equals: { reason: 'email_registered' } },
      },
    });
    expect(reason).not.toBeNull();
  });

  it('the cleanup job deletes expired pending registrations (and only those)', async () => {
    const live = newUser();
    const stale = newUser();
    await register(live);
    await register(stale);
    await settle(ctx);
    await ctx.prisma.pendingRegistration.updateMany({
      where: { email: stale.email },
      data: { expiresAt: new Date(Date.now() - 1000) },
    });
    const removed = await ctx.app.get(RegistrationService).deleteExpired();
    expect(removed).toBeGreaterThanOrEqual(1);
    expect(await ctx.prisma.pendingRegistration.count({ where: { email: stale.email } })).toBe(0);
    expect(await ctx.prisma.pendingRegistration.count({ where: { email: live.email } })).toBe(1);
  });

  it('unverified registrants cannot log in', async () => {
    const payload = newUser();
    await register(payload);
    await settle(ctx);
    for (const identifier of [payload.email, payload.username]) {
      const res = await ctx.http.post('/api/v1/auth/login').send({ identifier, password: payload.password });
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('AUTH_INVALID_CREDENTIALS');
    }
  });

  it('resend rotates the code (old code invalid) and is always 202', async () => {
    const payload = newUser({ locale: 'ar' });
    let before = ctx.mail.sent.length;
    await register(payload);
    const oldCode = (await ctx.mail.waitFor(payload.email, 'code', before)).code;

    before = ctx.mail.sent.length;
    const resend = await ctx.http.post('/api/v1/auth/register/resend').send({ email: payload.email });
    expect(resend.status).toBe(202);
    expect(resend.body).toEqual(PENDING);
    const newMail = await ctx.mail.waitFor(payload.email, 'code', before);
    expect(newMail.locale).toBe('ar'); // no Accept-Language: falls back to the pending locale

    const unknown = await ctx.http.post('/api/v1/auth/register/resend').send({ email: 'none@example.com' });
    expect(unknown.status).toBe(202);
    expect(unknown.body).toEqual(PENDING);

    if (oldCode !== newMail.code) expectTokenInvalid(await verify(payload.email, oldCode));
    expect((await verify(payload.email, newMail.code)).status).toBe(201);
  });

  it('validates verify and resend bodies strictly', async () => {
    const bad = await ctx.http.post('/api/v1/auth/register/verify').send({ email: 'a@b.co', code: '1234' });
    expect(bad.status).toBe(400);
    expect(bad.body.error.details).toEqual([{ field: 'code', issue: 'invalid_format' }]);
    const extra = await ctx.http
      .post('/api/v1/auth/register/resend')
      .send({ email: 'a@b.co', username: 'x' });
    expect(extra.status).toBe(400);
    expect(extra.body.error.details).toEqual([{ field: 'username', issue: 'unknown_field' }]);
  });

  it('rejects reserved display names with reserved_term', async () => {
    // v1.2.3: a Latin word with a Cyrillic а ("Kаbso") is now a mixed-script invalid_format at the
    // schema stage (tested below); spaced homoglyphs still reach the reserved-term check.
    for (const displayName of [
      'K а b s o',
      'الدعم الرسمي',
      'Official Support',
      'TheKabso',
      'kabso_official',
    ]) {
      const res = await register(newUser({ displayName }));
      expect(res.status).toBe(400);
      expect(res.body.error.details).toEqual([{ field: 'displayName', issue: 'reserved_term' }]);
    }
  });

  it('rejects a mixed-script homoglyph word with invalid_format (v1.2.3)', async () => {
    const res = await register(newUser({ displayName: 'Kаbso' }));
    expect(res.status).toBe(400);
    expect(res.body.error.details).toEqual([{ field: 'displayName', issue: 'invalid_format' }]);
  });

  // Contract v1.2.1: reserved terms only as whole words (or brand prefix/suffix).
  it('accepts reserved terms inside ordinary words and emoji-only names end to end', async () => {
    for (const displayName of ['Badminton Club', 'Supporter', String.fromCodePoint(0x1f600)]) {
      const { res } = await registerVerified(ctx, { displayName });
      expect(res.status).toBe(201);
      expect(res.body.user.displayName).toBe(displayName);
    }
    const symbols = await register(newUser({ displayName: '...' }));
    expect(symbols.status).toBe(400);
    expect(symbols.body.error.details).toEqual([{ field: 'displayName', issue: 'invalid_format' }]);
  });

  it('accepts Persian names with ZWNJ and emoji ZWJ sequences end to end', async () => {
    const persian = `می${String.fromCharCode(0x200c)}خواهم`;
    const { res } = await registerVerified(ctx, { displayName: persian });
    expect(res.status).toBe(201);
    expect(res.body.user.displayName).toBe(persian);
  });

  describe('code mail locale (KL-018)', () => {
    it('uses the body locale, then Accept-Language, else Arabic', async () => {
      const cases: [Record<string, unknown>, Record<string, string>, string][] = [
        [{ locale: 'en' }, { 'Accept-Language': 'ar' }, 'en'],
        [{ locale: undefined }, { 'Accept-Language': 'en-GB,en;q=0.9' }, 'en'],
        [{ locale: undefined }, { 'Accept-Language': 'fr' }, 'ar'],
        [{ locale: undefined }, {}, 'ar'],
      ];
      for (const [overrides, headers, expected] of cases) {
        const payload = newUser(overrides);
        const before = ctx.mail.sent.length;
        expect((await register(payload, headers)).status).toBe(202);
        expect((await ctx.mail.waitFor(payload.email, 'code', before)).locale).toBe(expected);
      }
    });
  });

  describe('PATCH /me (KL-018)', () => {
    it('persists the locale and returns Me; account mails then use it', async () => {
      const { payload, res } = await registerVerified(ctx, { locale: 'ar' });
      const token = res.body.tokens.accessToken as string;
      const patched = await ctx.http.patch('/api/v1/me').set(bearer(token)).send({ locale: 'en' });
      expect(patched.status).toBe(200);
      expect(patched.body).toMatchObject({ id: res.body.user.id, locale: 'en' });
      expect((await ctx.http.get('/api/v1/me').set(bearer(token))).body.locale).toBe('en');

      const before = ctx.mail.sent.length;
      await ctx.http.post('/api/v1/auth/password/forgot').send({ email: payload.email });
      expect((await ctx.mail.waitFor(payload.email, 'reset', before)).locale).toBe('en');
    });

    it('is strict, authenticated and validated', async () => {
      const { res } = await registerVerified(ctx);
      const token = res.body.tokens.accessToken as string;
      expect((await ctx.http.patch('/api/v1/me').send({ locale: 'en' })).status).toBe(401);
      const invalid = await ctx.http.patch('/api/v1/me').set(bearer(token)).send({ locale: 'fr' });
      expect(invalid.status).toBe(400);
      expect(invalid.body.error.details).toEqual([{ field: 'locale', issue: 'invalid_value' }]);
      // v1.45-social (D168) made `displayName` and `bio` editable here; the photo has its own
      // endpoint, so `avatarUrl` stays an unknown field.
      const extra = await ctx.http
        .patch('/api/v1/me')
        .set(bearer(token))
        .send({ locale: 'en', avatarUrl: 'https://example.test/a.png' });
      expect(extra.status).toBe(400);
      expect(extra.body.error.details).toEqual([{ field: 'avatarUrl', issue: 'unknown_field' }]);
    });
  });
});

describe('KL-019 / KL-018 rate limits (CONVENTIONS §7 v1.2)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({
      RATE_LIMIT_REGISTER_EMAIL: '3/3600',
      RATE_LIMIT_REGISTER_VERIFY_IP: '10/900',
      RATE_LIMIT_REGISTER_RESEND_EMAIL: '3/3600',
      RATE_LIMIT_REGISTER_RESEND_IP: '10/3600',
      RATE_LIMIT_UPDATE_ME_USER: '30/3600',
    });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  function expectLimited(res: {
    status: number;
    body: { error: { code: string } };
    headers: Record<string, string>;
  }) {
    expect(res.status).toBe(429);
    expect(res.body.error.code).toBe('RATE_LIMITED');
    expect(Number(res.headers['retry-after'])).toBeGreaterThan(0);
  }

  it('register: 3 / hour per email (any case)', async () => {
    const email = `limit-${Date.now()}@example.com`;
    for (const spelling of [email, email.toUpperCase(), ` ${email} `]) {
      expect((await ctx.http.post('/api/v1/auth/register').send(newUser({ email: spelling }))).status).toBe(
        202,
      );
    }
    expectLimited(await ctx.http.post('/api/v1/auth/register').send(newUser({ email })));
  });

  it('register/verify: 10 / 15 min per IP', async () => {
    for (let i = 0; i < 10; i += 1) {
      const res = await ctx.http
        .post('/api/v1/auth/register/verify')
        .send({ email: `v${i}@example.com`, code: '12345678' });
      expect(res.status).toBe(422);
    }
    expectLimited(
      await ctx.http.post('/api/v1/auth/register/verify').send({ email: 'v@example.com', code: '12345678' }),
    );
  });

  it('register/resend: 3 / hour per email', async () => {
    const email = `resend-${Date.now()}@example.com`;
    for (let i = 0; i < 3; i += 1) {
      expect((await ctx.http.post('/api/v1/auth/register/resend').send({ email })).status).toBe(202);
    }
    expectLimited(await ctx.http.post('/api/v1/auth/register/resend').send({ email }));
  });
});

describe('KL-018 PATCH /me rate limit (CONVENTIONS §7 v1.2)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_UPDATE_ME_USER: '30/3600' });
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('PATCH /me: 30 / hour per user', async () => {
    const { res } = await registerVerified(ctx);
    const auth = bearer(res.body.tokens.accessToken as string);
    for (let i = 0; i < 30; i += 1) {
      expect(
        (
          await ctx.http
            .patch('/api/v1/me')
            .set(auth)
            .send({ locale: i % 2 ? 'ar' : 'en' })
        ).status,
      ).toBe(200);
    }
    const limited = await ctx.http.patch('/api/v1/me').set(auth).send({ locale: 'en' });
    expect(limited.status).toBe(429);
    expect(limited.body.error.code).toBe('RATE_LIMITED');
    expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
  });
});

describe('KL-019 register timing parity (fake Argon2)', () => {
  class CountingArgon2 implements Argon2Backend {
    hashes = 0;
    verifies = 0;
    hash(password: string): Promise<string> {
      this.hashes += 1;
      return Promise.resolve(`fake$${password}`);
    }
    verify(hash: string, password: string): Promise<boolean> {
      this.verifies += 1;
      return Promise.resolve(hash === `fake$${password}`);
    }
    needsRehash(): boolean {
      return false;
    }
  }

  const argon2 = new CountingArgon2();
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({}, [{ token: ARGON2_BACKEND, value: argon2 }]);
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('new and existing emails cost exactly one Argon2 hash each and take comparable time', async () => {
    const owner = await registerVerified(ctx);
    expect(owner.res.status).toBe(201);
    await settle(ctx);

    const timeOne = async (email: string | undefined) => {
      const payload = newUser(email ? { email } : {});
      const hashesBefore = argon2.hashes;
      const start = process.hrtime.bigint();
      const res = await ctx.http.post('/api/v1/auth/register').send(payload);
      const elapsedMs = Number(process.hrtime.bigint() - start) / 1e6;
      expect(res.status).toBe(202);
      expect(res.body).toEqual(PENDING);
      expect(argon2.hashes - hashesBefore).toBe(1);
      return elapsedMs;
    };

    // Warm-up, then interleave the two branches to cancel drift.
    await timeOne(undefined);
    await timeOne(owner.payload.email);
    const fresh: number[] = [];
    const existing: number[] = [];
    for (let i = 0; i < 40; i += 1) {
      // Alternate which branch goes first so ordering effects cancel out.
      if (i % 2 === 0) {
        fresh.push(await timeOne(undefined));
        existing.push(await timeOne(owner.payload.email));
      } else {
        existing.push(await timeOne(owner.payload.email));
        fresh.push(await timeOne(undefined));
      }
    }
    // 10 % trimmed mean: robust to GC pauses / scheduler outliers on shared CI machines.
    const mean = (xs: number[]) => {
      const sorted = [...xs].sort((a, b) => a - b);
      const cut = Math.floor(sorted.length * 0.1);
      const kept = sorted.slice(cut, sorted.length - cut);
      return kept.reduce((a, b) => a + b, 0) / kept.length;
    };
    const meanFresh = mean(fresh);
    const meanExisting = mean(existing);
    // Tolerance: 3 ms or 25 % of the slower mean, whichever is larger (local CI noise).
    const tolerance = Math.max(3, 0.25 * Math.max(meanFresh, meanExisting));
    expect(Math.abs(meanFresh - meanExisting)).toBeLessThanOrEqual(tolerance);
    process.stderr.write(
      `register timing (10% trimmed mean, n=40 each): new ${meanFresh.toFixed(2)} ms vs existing ${meanExisting.toFixed(2)} ms ` +
        `(tolerance ${tolerance.toFixed(2)} ms)\n`,
    );
  });
});
