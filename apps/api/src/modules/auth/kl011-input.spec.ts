import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import { type AppException } from '../../common/errors/app-exception.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { loginSchema, passwordSchema, registerSchema } from './auth.schemas.js';
import { PasswordHasher } from './password-hasher.service.js';

const NFC = 'café passphrase';
// Same text in decomposed form (e + U+0301 COMBINING ACUTE ACCENT); differs byte-wise from NFC.
const NFD = NFC.normalize('NFD');

function details(fn: () => unknown) {
  try {
    fn();
  } catch (err) {
    return (err as AppException).details;
  }
  throw new Error('expected validation to fail');
}

describe('free-text character policy (SEC-008, CONVENTIONS §6)', () => {
  const register = new ZodValidationPipe(registerSchema);
  const base = { email: 'a@b.co', password: 'password1', username: 'abc123' };

  it.each([
    ['RLO bidi override', 'admin‮gnp.exe'],
    ['LRE embedding', 'a‪b'],
    ['FSI isolate', 'a⁨b'],
    ['PDI isolate', 'a⁩b'],
    ['zero-width space', 'Kab​so Official'],
    ['word joiner', 'a⁠b'],
    ['BOM inside', 'a﻿b'],
    ['C0 newline', 'a\nb'],
    ['ESC', 'evil\u001b[31mred'],
    ['DEL', 'a\u007fb'],
    ['C1 NEL', 'a\u0085b'],
    ['C1 CSI', 'a\u009bb'],
  ])('rejects %s in displayName and device.name', (_label, text) => {
    expect(details(() => register.transform({ ...base, displayName: text }))).toEqual([
      { field: 'displayName', issue: 'invalid_format' },
    ]);
    expect(details(() => register.transform({ ...base, displayName: 'ok', device: { name: text } }))).toEqual(
      [{ field: 'device.name', issue: 'invalid_format' }],
    );
    expect(
      details(() =>
        new ZodValidationPipe(loginSchema).transform({
          identifier: 'abc',
          password: 'x',
          device: { name: text },
        }),
      ),
    ).toEqual([{ field: 'device.name', issue: 'invalid_format' }]);
  });

  // Contract v1.2 (KL-017): ZWJ/ZWNJ are allowed in displayName between two letters, but every
  // zero-width character stays banned in device.* fields.
  it('allows a well-placed ZWJ in displayName but rejects it in device.name', () => {
    const zwj = 'a\u200db';
    expect(register.transform({ ...base, displayName: zwj })).toMatchObject({ displayName: zwj });
    expect(details(() => register.transform({ ...base, displayName: 'ok', device: { name: zwj } }))).toEqual([
      { field: 'device.name', issue: 'invalid_format' },
    ]);
  });

  it('accepts Arabic, emoji and ordinary punctuation', () => {
    expect(
      register.transform({ ...base, displayName: 'سارة 🎤 — O’Neil', device: { name: 'Pixel 9 Pro' } }),
    ).toMatchObject({
      displayName: 'سارة 🎤 — O’Neil',
    });
  });
});

describe('password NFC normalization (SEC-016)', () => {
  it('normalizes request passwords to NFC before policy checks', () => {
    expect(passwordSchema.parse(NFD)).toBe(NFC);
    expect(new ZodValidationPipe(loginSchema).transform({ identifier: 'abc', password: NFD }).password).toBe(
      NFC,
    );
    // 128 NFC code points spelled in NFD (256 code units) is still within the limit.
    expect(passwordSchema.safeParse('é'.repeat(128)).success).toBe(true);
    expect(passwordSchema.safeParse('é'.repeat(129)).success).toBe(false);
  });

  it('hashes and verifies in NFC, so NFC and NFD spellings are the same password', async () => {
    const hasher = new PasswordHasher(
      loadConfig({
        DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
        REDIS_URL: 'redis://localhost:6379',
        JWT_ACCESS_SECRET: 'x'.repeat(32),
        APP_PUBLIC_URL: 'http://localhost:3000',
      }),
    );
    const fromNfd = await hasher.hash(NFD);
    expect(await hasher.verify(fromNfd, NFC)).toBe(true);
    const fromNfc = await hasher.hash(NFC);
    expect(await hasher.verify(fromNfc, NFD)).toBe(true);
    expect(await hasher.verify(fromNfc, 'cafe passphrase')).toBe(false);
  });
});
