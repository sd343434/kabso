/**
 * KL-025: contract v1.2.6 displayName residuals from KL-007d (SEC-030, SEC-031, SEC-032),
 * end to end through POST /auth/register with the default reserved/brand terms.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createTestApp, newUser, type TestContext } from './helpers/test-app.js';

describe('displayName v1.2.6 end to end', () => {
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
    'кавѕо', // SEC-030 all-Cyrillic
    'ᴋᴀʙꜱᴏ', // SEC-030 all-Latin small capitals
    'K a b s o Team', // SEC-031
    'Kab-so Live',
    'K.a.b.s.o Fan',
    'Kab·so Live',
    'ك ا ب س و لايف',
    'كابسولة', // SEC-032 accepted residual: brand inside an Arabic word
  ])('reserves %s', async (displayName) => {
    const res = await register(displayName);
    expect(res.status).toBe(400);
    expect(res.body.error.details).toEqual([{ field: 'displayName', issue: 'reserved_term' }]);
  });

  it.each([
    'Kab Sonia',
    'Abc Kab Sonite',
    'Mary-Jane',
    'رسمي',
    'رسمي أحمد',
    'Ali٣',
    'Ahmed۲۰۲۴',
    'TOKYO東京',
    'Kim김',
  ])('accepts %s', async (displayName) => {
    const res = await register(displayName);
    expect(res.status).toBe(202);
  });

  it.each(['Kаbso', 'ADΜIN'])(
    'still rejects Latin mixed with Cyrillic/Greek in one word (%#)',
    async (displayName) => {
      const res = await register(displayName);
      expect(res.status).toBe(400);
      expect(res.body.error.details).toEqual([{ field: 'displayName', issue: 'invalid_format' }]);
    },
  );
});
