import { createHash } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import {
  formatRefreshToken,
  generateSecret,
  hashesEqual,
  isWellFormedSecret,
  parseRefreshToken,
  sha256Hex,
} from './tokens.js';

const SID = '0192f1c2-3b4a-7c5d-8e6f-0123456789ab';

describe('generateSecret', () => {
  it('produces 32 random bytes as 43-char base64url', () => {
    const a = generateSecret();
    const b = generateSecret();
    expect(a).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(Buffer.from(a, 'base64url')).toHaveLength(32);
    expect(a).not.toBe(b);
    expect(isWellFormedSecret(a)).toBe(true);
  });
});

describe('sha256Hex / hashesEqual', () => {
  it('matches node crypto SHA-256 hex', () => {
    expect(sha256Hex('abc')).toBe(createHash('sha256').update('abc').digest('hex'));
    expect(sha256Hex('abc')).toHaveLength(64);
  });

  it('compares digests in constant time and rejects mismatches/empties', () => {
    const h = sha256Hex('x');
    expect(hashesEqual(h, sha256Hex('x'))).toBe(true);
    expect(hashesEqual(h, sha256Hex('y'))).toBe(false);
    expect(hashesEqual(h, h.slice(0, 62))).toBe(false);
    expect(hashesEqual('', '')).toBe(false);
  });
});

describe('refresh token format', () => {
  it('round-trips <sessionId>.<secret>', () => {
    const secret = generateSecret();
    const token = formatRefreshToken(SID, secret);
    expect(token).toBe(`${SID}.${secret}`);
    expect(parseRefreshToken(token)).toEqual({ sessionId: SID, secret });
  });

  it('normalizes the session id to lowercase', () => {
    const secret = generateSecret();
    expect(parseRefreshToken(`${SID.toUpperCase()}.${secret}`)?.sessionId).toBe(SID);
  });

  it.each([
    ['empty', ''],
    ['no dot', `${SID}${generateSecret()}`],
    ['two dots', `${SID}.${generateSecret()}.x`],
    ['bad uuid', `not-a-uuid.${generateSecret()}`],
    ['short secret', `${SID}.abc`],
    ['bad secret chars', `${SID}.${'+'.repeat(43)}`],
    ['leading dot', `.${generateSecret()}`],
  ])('rejects %s', (_label, token) => {
    expect(parseRefreshToken(token)).toBeNull();
  });
});
