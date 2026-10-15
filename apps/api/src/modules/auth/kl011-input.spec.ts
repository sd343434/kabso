import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { loginSchema, passwordSchema, registerSchema } from './auth.schemas.js';
import { PasswordHasher } from './password-hasher.service.js';

const NFC = 'café passphrase';
const NFD = 'café passphrase';

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
  const base = { email: 'a@b.co', password: 'password1', username: 'abc' };

  it.each([
    ['RLO bidi override', 'admin‮gnp.exe'],
    ['LRE embedding', 'a‪b'],
    ['FSI isolate', 'a⁨b'],
    ['PDI isolate', 'a⁩b'],
    ['zero-width space', 'Kab​so Official'],
    ['zero-width joiner', 'a‍b'],
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

describe('Argon2 concurrency cap (SEC-002)', () => {
  it('sheds load with 503 SERVICE_UNAVAILABLE + Retry-After when saturated', async () => {
    const hasher = new PasswordHasher(
      loadConfig({
        DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
        REDIS_URL: 'redis://localhost:6379',
        JWT_ACCESS_SECRET: 'x'.repeat(32),
        APP_PUBLIC_URL: 'http://localhost:3000',
        ARGON2_MAX_CONCURRENCY: '1',
        ARGON2_MAX_QUEUE: '1',
      }),
    );
    const running = hasher.hash('first password');
    const queued = hasher.hash('second password');
    expect(hasher.load).toEqual({ active: 1, queued: 1 });
    let refused: unknown;
    try {
      await hasher.verifyAgainstDummy('third password');
    } catch (err) {
      refused = err;
    }
    expect(refused).toBeInstanceOf(AppException);
    expect(refused).toMatchObject({
      code: 'SERVICE_UNAVAILABLE',
      status: 503,
      headers: { 'Retry-After': '1' },
    });
    await Promise.all([running, queued]);
    expect(hasher.load).toEqual({ active: 0, queued: 0 });
  });
});
