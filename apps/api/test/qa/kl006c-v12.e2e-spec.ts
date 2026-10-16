// KL-006c (A6, QA): contract v1.2 / v1.2.1 / v1.2.2 regression tests that complement
// kl019-registration.e2e-spec.ts: header-level identity of the register 202, the full
// displayName boundary / confusable matrix (PP-21), and email-locale rules (PP-22).
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createTestApp, newUser, registerVerified, settle, type TestContext } from '../helpers/test-app.js';

let ctx: TestContext;

beforeAll(async () => {
  ctx = await createTestApp();
});

afterAll(async () => {
  await ctx?.close();
});

const PENDING = '{"status":"verification_pending"}';

/** Response headers that may legitimately differ between two requests. */
const VOLATILE = new Set(['x-request-id', 'date', 'etag', 'connection', 'keep-alive']);

function stableHeaders(headers: Record<string, string>): Record<string, string> {
  return Object.fromEntries(Object.entries(headers).filter(([k]) => !VOLATILE.has(k)));
}

describe('PP-02 register: new vs existing email are indistinguishable', () => {
  it('same status, body and headers; no tokens; no EMAIL_TAKEN', async () => {
    const owner = await registerVerified(ctx);
    expect(owner.res.status).toBe(201);
    const fresh = await ctx.http.post('/api/v1/auth/register').send(newUser());
    const dup = await ctx.http
      .post('/api/v1/auth/register')
      .send(newUser({ email: String(owner.payload.email).toUpperCase() }));
    expect([fresh.status, dup.status]).toEqual([202, 202]);
    expect(fresh.text).toBe(PENDING);
    expect(dup.text).toBe(PENDING);
    expect(stableHeaders(dup.headers as Record<string, string>)).toEqual(
      stableHeaders(fresh.headers as Record<string, string>),
    );
    expect(fresh.text + dup.text).not.toMatch(/token|EMAIL_TAKEN/i);
  });

  it('resend: unknown, existing and pending emails all get the identical 202', async () => {
    const owner = await registerVerified(ctx);
    const pending = newUser();
    await ctx.http.post('/api/v1/auth/register').send(pending);
    const bodies = await Promise.all(
      [`nobody${Date.now()}@example.com`, owner.payload.email, pending.email].map((email) =>
        ctx.http.post('/api/v1/auth/register/resend').send({ email }),
      ),
    );
    for (const r of bodies) {
      expect(r.status).toBe(202);
      expect(r.text).toBe(PENDING);
    }
  });
});

describe('PP-21 displayName rules (v1.2.2), via POST /auth/register', () => {
  const fam = '👨‍👩‍👧';
  const accepted: [string, string][] = [
    ['Persian with ZWNJ', 'علی‌رضا محمدی'],
    ['Urdu', 'شاہد آفریدی'],
    ['Kurdish Sorani', 'ژیان کەریم ڕەش'],
    ['family ZWJ sequence', fam],
    ['flags', '🇸🇦🇮🇶🇪🇬'],
    ['skin tones', '👋🏽 Layla 👍🏿'],
    ['rainbow flag', '🏳️‍🌈 Sam'],
    ['emoji only', '😀😀'],
    ['exactly 50 graphemes', 'a'.repeat(50)],
    ['20 families = 20 graphemes / 100 code points', fam.repeat(20)],
    ['3 combining marks', 'á̂̃b'],
    ['Kab Sonia', 'Kab Sonia'],
    ['brand-like substrings inside ordinary words', 'Badminton Supporter'],
    ['edge U+FEFF is trimmed', '﻿Layla﻿'],
  ];
  const rejected: [string, string, string][] = [
    ['51 graphemes', 'a'.repeat(51), 'too_long'],
    ['101 code points', `${fam.repeat(20)}a`, 'too_long'],
    ['leading ZWNJ', '‌abc', 'invalid_format'],
    ['trailing ZWJ', 'abc‍', 'invalid_format'],
    ['two joiners', 'ab‌‌cd', 'invalid_format'],
    ['joiner next to a space', 'ab ‌cd', 'invalid_format'],
    ['joiners only', '‌‍', 'invalid_format'],
    ['4 combining marks (zalgo)', 'á̂̃̄b', 'invalid_format'],
    ['RLO bidi spoof', 'Layla‮gnp.exe', 'invalid_format'],
    ['bidi isolate', 'a⁧b⁩', 'invalid_format'],
    ['inner ZWSP', 'La​yla', 'invalid_format'],
    ['inner U+FEFF', 'La﻿yla', 'invalid_format'],
    ['symbols only ★★', '★★', 'invalid_format'],
    ['symbols only ©™', '©™', 'invalid_format'],
    ['punctuation only', '...', 'invalid_format'],
    ['TheKabso (brand suffix)', 'TheKabso', 'reserved_term'],
    ['KabsoFan (brand prefix)', 'KabsoFan', 'reserved_term'],
    ['Cyrillic а confusable, spaced', 'K а b s o', 'reserved_term'],
    ['fullwidth', 'ＫＡＢＳＯ', 'reserved_term'],
    ['mathematical bold', '𝐊𝐚𝐛𝐬𝐨', 'reserved_term'],
    ['ZWNJ inside the brand', 'Kab‌so', 'reserved_term'],
    ['Arabic tatweel', 'كـابسو', 'reserved_term'],
    ['Arabic spaced letters', 'ك ا ب س و', 'reserved_term'],
    ['Persian kaf', 'کابسو', 'reserved_term'],
    ['الدعم الفني', 'الدعم الفني', 'reserved_term'],
    ['Official Layla', 'Official Layla', 'reserved_term'],
  ];

  it.each(accepted)('accepts %s', async (_name, displayName) => {
    const res = await ctx.http.post('/api/v1/auth/register').send(newUser({ displayName }));
    expect({ status: res.status, body: res.body }).toEqual({
      status: 202,
      body: { status: 'verification_pending' },
    });
  });

  it.each(rejected)('rejects %s', async (_name, displayName, issue) => {
    const res = await ctx.http.post('/api/v1/auth/register').send(newUser({ displayName }));
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
    expect(res.body.error.details).toEqual([{ field: 'displayName', issue }]);
  });

  it.each([
    ['ZWNJ name', 'علی‌رضا محمدی', 'علی‌رضا محمدی'],
    ['ZWJ emoji', `${fam} Family`, `${fam} Family`],
    ['edge U+FEFF + spaces trimmed', '﻿  Layla  ﻿', 'Layla'],
    ['NFC normalization', 'éclair', 'éclair'],
  ])('stores %s intact after verify', async (_name, displayName, stored) => {
    const { res } = await registerVerified(ctx, { displayName });
    expect(res.status).toBe(201);
    expect(res.body.user.displayName).toBe(stored);
    const me = await ctx.http.get('/api/v1/me').set('Authorization', `Bearer ${res.body.tokens.accessToken}`);
    expect(me.body.displayName).toBe(stored);
  });

  it('device.name still rejects every zero-width character, including ZWJ', async () => {
    const res = await ctx.http.post('/api/v1/auth/register').send(newUser({ device: { name: 'a‍b' } }));
    expect(res.status).toBe(400);
    expect(res.body.error.details).toEqual([{ field: 'device.name', issue: 'invalid_format' }]);
  });
});

describe('PP-22 email language', () => {
  it('resend: code mail follows Accept-Language; the account keeps the pending locale', async () => {
    const payload = newUser({ locale: 'en' });
    const email = String(payload.email);
    await ctx.http.post('/api/v1/auth/register').send(payload);
    const first = await ctx.mail.waitFor(email, 'code');
    expect(first.locale).toBe('en');
    const before = ctx.mail.sent.length;
    const resend = await ctx.http
      .post('/api/v1/auth/register/resend')
      .set('Accept-Language', 'ar')
      .send({ email });
    expect(resend.status).toBe(202);
    const second = await ctx.mail.waitFor(email, 'code', before);
    expect(second.locale).toBe('ar');
    expect(second.code).not.toBe(first.code);
    const verify = await ctx.http.post('/api/v1/auth/register/verify').send({ email, code: second.code });
    expect(verify.status).toBe(201);
    expect(verify.body.user.locale).toBe('en');
  });

  it('after PATCH /me the reset mail uses the stored locale, not Accept-Language', async () => {
    const { payload, res } = await registerVerified(ctx, { locale: 'en' });
    const email = String(payload.email);
    const patch = await ctx.http
      .patch('/api/v1/me')
      .set('Authorization', `Bearer ${res.body.tokens.accessToken}`)
      .send({ locale: 'ar' });
    expect(patch.status).toBe(200);
    expect(patch.body).toEqual({ ...res.body.user, locale: 'ar' });
    await ctx.http.post('/api/v1/auth/password/forgot').set('Accept-Language', 'en').send({ email });
    await settle(ctx);
    expect(ctx.mail.last(email, 'reset')?.locale).toBe('ar');
  });
});
