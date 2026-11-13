import { describe, expect, it } from 'vitest';
import { usernameSchema } from '../auth/auth.schemas.js';
import { isCoinName } from './special-usernames.js';
import { isReservedUsername, isValidUsername, normalizeEmail, normalizeUsername } from './username.js';

describe('username validation', () => {
  // v1.28-live (D146): the stored / lookup shape is 1–30 (grandfathered and premium names).
  it.each(['7', 'ab', 'abc', 'a.b', 'a_b', 'user.name_99', '123', 'a'.repeat(30)])('accepts %s', (name) => {
    expect(isValidUsername(name)).toBe(true);
    expect(usernameSchema.safeParse(name).success).toBe(true);
  });

  it.each([
    ['one separator', '_'],
    ['too long', 'a'.repeat(31)],
    ['uppercase', 'Alice'],
    ['leading dot', '.abc'],
    ['trailing underscore', 'abc_'],
    ['space', 'ab c'],
    ['dash', 'ab-c'],
    ['arabic', 'مستخدم'],
    ['empty', ''],
  ])('rejects %s', (_label, name) => {
    expect(isValidUsername(name)).toBe(false);
    expect(usernameSchema.safeParse(name).success).toBe(false);
  });
});

describe('normalization', () => {
  it('lowercases and trims usernames for lookup', () => {
    expect(normalizeUsername('  Alice.B ')).toBe('alice.b');
  });

  it('lowercases and trims emails', () => {
    expect(normalizeEmail('  Foo.Bar@Example.COM ')).toBe('foo.bar@example.com');
  });
});

describe('reserved usernames', () => {
  it.each(['admin', 'kabso', 'support', 'api', 'live', 'ADMIN', 'ad.min', 'sup_port'])(
    'reserves %s',
    (name) => {
      expect(isReservedUsername(name)).toBe(true);
    },
  );

  it('does not reserve ordinary names', () => {
    expect(isReservedUsername('alice')).toBe(false);
    expect(isReservedUsername('administrator_fan')).toBe(false);
  });

  // v1.54-social (D185, §10.48.1): `coin` + digits is the recharge agents' special username.
  it.each(['coin0001', 'coin7', 'coin123456', 'coin_0007', 'co.in0007', 'COIN0001'])(
    'reserves %s',
    (name) => {
      expect(isReservedUsername(name)).toBe(true);
      expect(isCoinName(name)).toBe(true);
    },
  );

  it.each(['coin', 'coins7', 'coin7a', 'bitcoin7', 'coin7x8'])('does not treat %s as a coin name', (name) => {
    expect(isCoinName(name)).toBe(false);
    expect(isReservedUsername(name)).toBe(false);
  });
});
