/**
 * KL-007c security regression tests (A7) for contract v1.2 / v1.2.2. They pin controls the review
 * verified as effective. Open defects are described in docs/security/KL-007_PHASE1_REVIEW.md §7.
 */
import { createHash } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { displayNameIssue, normalizeDisplayName } from '../../src/modules/users/display-name.js';
import { createTestApp, newUser, registerVerified, settle, type TestContext } from '../helpers/test-app.js';

describe('KL-007c verify-first registration', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
  });

  afterAll(async () => {
    await ctx?.close();
  });

  const STRIP = /^(date|x-request-id|etag|content-length)$/i;
  const stableHeaders = (h: Record<string, string>) =>
    Object.fromEntries(Object.entries(h).filter(([k]) => !STRIP.test(k)));

  it('register answers byte-identically for a registered and an unregistered email', async () => {
    const { payload } = await registerVerified(ctx);
    const existing = await ctx.http
      .post('/api/v1/auth/register')
      .send(newUser({ email: String(payload.email).toUpperCase() }));
    const fresh = await ctx.http.post('/api/v1/auth/register').send(newUser());
    expect(existing.status).toBe(202);
    expect(fresh.status).toBe(202);
    expect(existing.text).toBe(fresh.text);
    expect(existing.text).toBe('{"status":"verification_pending"}');
    expect(stableHeaders(existing.headers)).toEqual(stableHeaders(fresh.headers));
    expect(existing.headers['etag']).toBe(fresh.headers['etag']);
    await settle(ctx);
  });

  it('every verify failure is the same 422 TOKEN_INVALID body', async () => {
    const { payload } = await registerVerified(ctx);
    const pending = newUser();
    await ctx.http.post('/api/v1/auth/register').send(pending);
    await settle(ctx);
    const bodies = new Set<string>();
    for (const body of [
      { email: 'never-seen@example.com', code: '12345678' },
      { email: payload.email, code: '12345678' },
      { email: pending.email, code: '00000000' },
    ]) {
      const res = await ctx.http.post('/api/v1/auth/register/verify').send(body);
      expect(res.status).toBe(422);
      bodies.add(JSON.stringify({ ...res.body.error, requestId: undefined }));
    }
    expect([...bodies]).toEqual([JSON.stringify({ code: 'TOKEN_INVALID', message: 'Token is invalid.' })]);
  });

  it('stores the code only as a keyed HMAC (not the code, not a plain SHA-256)', async () => {
    const payload = newUser();
    const before = ctx.mail.sent.length;
    await ctx.http.post('/api/v1/auth/register').send(payload);
    const mail = await ctx.mail.waitFor(String(payload.email), 'code', before);
    expect(mail.code).toMatch(/^[0-9]{8}$/);
    const row = await ctx.prisma.pendingRegistration.findUniqueOrThrow({ where: { email: payload.email } });
    const dump = JSON.stringify(row);
    expect(dump).not.toContain(mail.code);
    const sha = (v: string) => createHash('sha256').update(v).digest('hex');
    expect(row.codeHash).not.toBe(sha(mail.code));
    expect(row.codeHash).not.toBe(sha(`${payload.email}\n${mail.code}`));
  });

  it('40 concurrent wrong codes check at most 5 codes and then the correct code no longer works', async () => {
    const payload = newUser();
    const before = ctx.mail.sent.length;
    await ctx.http.post('/api/v1/auth/register').send(payload);
    const mail = await ctx.mail.waitFor(String(payload.email), 'code', before);
    const { id: pendingId } = await ctx.prisma.pendingRegistration.findUniqueOrThrow({
      where: { email: payload.email },
      select: { id: true },
    });
    const wrong = (i: number) => String((Number(mail.code) + 1 + i) % 1e8).padStart(8, '0');
    const results = await Promise.all(
      Array.from({ length: 40 }, (_, i) =>
        ctx.http.post('/api/v1/auth/register/verify').send({ email: payload.email, code: wrong(i) }),
      ),
    );
    expect(results.every((r) => r.status === 422)).toBe(true);
    const reasonCount = (reason: string) =>
      ctx.prisma.auditLog.count({
        where: {
          action: 'auth.registration.verify_failed',
          targetId: pendingId,
          metadata: { path: ['reason'], equals: reason },
        },
      });
    const checked = await reasonCount('wrong_code');
    const exhausted = await reasonCount('attempts_exhausted');
    // At most 5 comparisons per pending registration (wrong_code + attempts_exhausted ≤ 5 here).
    expect(checked + exhausted).toBeLessThanOrEqual(5);
    const late = await ctx.http
      .post('/api/v1/auth/register/verify')
      .send({ email: payload.email, code: mail.code });
    expect(late.status).toBe(422);
    expect(await ctx.prisma.user.count({ where: { email: payload.email } })).toBe(0);
  });

  it('10 concurrent verifies with the correct code create exactly one account', async () => {
    const payload = newUser();
    const before = ctx.mail.sent.length;
    await ctx.http.post('/api/v1/auth/register').send(payload);
    const mail = await ctx.mail.waitFor(String(payload.email), 'code', before);
    const results = await Promise.all(
      Array.from({ length: 10 }, () =>
        ctx.http.post('/api/v1/auth/register/verify').send({ email: payload.email, code: mail.code }),
      ),
    );
    expect(results.filter((r) => r.status === 201)).toHaveLength(1);
    expect(results.filter((r) => r.status !== 201).every((r) => r.status === 422)).toBe(true);
    expect(await ctx.prisma.user.count({ where: { email: payload.email } })).toBe(1);
  });

  it('PATCH /me requires a token and accepts only {locale}', async () => {
    const { res } = await registerVerified(ctx);
    const token = res.body.tokens.accessToken as string;
    expect((await ctx.http.patch('/api/v1/me').send({ locale: 'ar' })).status).toBe(401);
    for (const body of [
      { locale: 'en', role: 'ADMIN' },
      { locale: 'en', email: 'other@example.com' },
      { locale: 'en', username: 'root' },
      { locale: 'en', displayName: 'Admin' },
      { locale: 'fr' },
    ]) {
      const r = await ctx.http.patch('/api/v1/me').set('Authorization', `Bearer ${token}`).send(body);
      expect(r.status).toBe(400);
    }
    const ok = await ctx.http
      .patch('/api/v1/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ locale: 'ar' });
    expect(ok.status).toBe(200);
    expect(ok.body.locale).toBe('ar');
    expect(ok.body.role).toBe('USER');
  });

  it('SEC-022: a secret rotated 10 refreshes ago still revokes the session', async () => {
    const { res } = await registerVerified(ctx);
    const rt0 = res.body.tokens.refreshToken as string;
    let current = rt0;
    for (let i = 0; i < 10; i += 1) {
      const r = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: current });
      expect(r.status).toBe(200);
      current = r.body.refreshToken;
    }
    expect((await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: rt0 })).status).toBe(401);
    const session = await ctx.prisma.session.findUniqueOrThrow({ where: { id: rt0.split('.')[0] } });
    expect(session.revokedReason).toBe('REFRESH_REUSE');
    expect((await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: current })).status).toBe(401);
  });
});

describe('KL-007c displayName reserved terms (verified controls)', () => {
  const terms = [
    'kabso',
    'admin',
    'administrator',
    'support',
    'official',
    'moderator',
    'staff',
    'كابسو',
    'الدعم',
    'رسمي',
    'مشرف',
    'الإدارة',
  ];
  const brands = ['kabso', 'كابسو'];
  const issue = (raw: string) => displayNameIssue(normalizeDisplayName(raw), terms, brands);

  it.each([
    ['fullwidth', 'Ｋａｂｓｏ'],
    ['Cyrillic a', 'аdmin'],
    ['spaced', 'K a b s o'],
    ['brand prefix', 'KabsoFan'],
    ['Persian keheh', 'کابسو'],
    ['tatweel', 'كـابسو'],
    ['ZWJ inside', 'كا‍بسو'],
    ['presentation forms', 'ﻛﺎﺑﺴﻮ'],
    ['rn for m', 'adrnin'],
    ['combining mark', 'Kábso'],
  ])('rejects %s', (_label, raw) => {
    expect(issue(raw)).toBe('reserved_term');
  });

  it('bounds the cost of max-size inputs (100 kB, rejected before segmentation work dominates)', () => {
    for (const raw of ['a'.repeat(100_000), `a${'́'.repeat(100_000)}`, '\u{1F468}‍'.repeat(25_000)]) {
      const started = performance.now();
      expect(issue(raw)).not.toBeNull();
      expect(performance.now() - started).toBeLessThan(250);
    }
  });
});
