import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { productionSecretProblem } from './secret-strength.js';

describe('productionSecretProblem (SEC-005)', () => {
  it.each([
    // The three values the KL-007 review showed were accepted before the fix.
    ['alphabet (24 bytes)', 'abcdefghijklmnopqrstuvwxyzABCDEF'],
    ['typed passphrase', 'kabso-live-production-jwt-key-2026!'],
    ['digit run', '0123456789012345678901234567890123'],
    // Long enough to decode to ≥ 32 bytes but not random.
    ['repeated char', 'a'.repeat(48)],
    ['long alphabet', 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'],
    ['long digit run', '01234567890123456789012345678901234567890123456789'],
    ['placeholder', 'change-me-generate-with-openssl-rand-base64-48'],
    ['too short random', randomBytes(24).toString('base64url')],
    ['non-base64 chars', `${randomBytes(40).toString('base64url')}!`],
  ])('rejects %s', (_label, value) => {
    expect(productionSecretProblem(value)).not.toBeNull();
  });

  it('accepts generator output (base64, base64url, hex) without false rejections', () => {
    for (let i = 0; i < 300; i += 1) {
      expect(productionSecretProblem(randomBytes(48).toString('base64url'))).toBeNull();
      expect(productionSecretProblem(randomBytes(32).toString('base64'))).toBeNull();
      expect(productionSecretProblem(randomBytes(32).toString('hex'))).toBeNull();
    }
  });
});
