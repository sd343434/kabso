import { describe, expect, it } from 'vitest';
import { registerSchema } from '../auth/auth.schemas.js';
import { isValidUsername } from '../users/username.js';
import {
  isCodeReservedPremium,
  premiumTierOf,
  regularUsernameIssue,
  suggestionCandidates,
} from './premium-username-rules.js';

describe("premium tiers (D146, the owner's four medals)", () => {
  it.each([
    ['7', 'LEGEND'],
    ['ab', 'LEGEND'],
    ['777', 'LEGEND'],
    ['a1b', 'LEGEND'],
    ['7777', 'RUBY'],
    ['aaaa', 'RUBY'],
    ['777777', 'RUBY'],
    ['aaaaaaaa', 'RUBY'],
    ['sara', 'GOLD'],
    ['ab12', 'GOLD'],
    ['12345', 'GOLD'],
    ['123456', 'GOLD'],
    ['654321', 'GOLD'],
    ['abcdef', 'GOLD'],
    ['123321', 'GOLD'],
    ['1ab2ba1', 'GOLD'],
    ['123123', 'GOLD'],
    ['abcabc', 'GOLD'],
    ['ali777', 'GOLD'],
    ['aaa777', 'GOLD'],
    ['112233', 'SILVER'],
    ['888991', 'GOLD'],
    ['kabsoo', 'SILVER'],
    ['layla', 'GOLD'],
    ['laylaa', 'SILVER'],
  ])('%s is %s', (name, tier) => {
    expect(premiumTierOf(name)).toBe(tier);
  });

  it.each(['sara22', 'abc123', 'a_b', 'ab.c', 'aa77x1', 'Abc', '', 'a'.repeat(31), 'user12x'])(
    '%s is not premium',
    (name) => {
      expect(premiumTierOf(name)).toBeNull();
    },
  );
});

describe('regular username rule (D146)', () => {
  it.each([
    ['abc', 'premium'],
    ['abcdef', 'premium'],
    ['123456', 'premium'],
    ['aaa777', 'premium'],
    ['ali777', 'premium'],
    ['ab_1', 'too_short'],
    ['a_b', 'too_short'],
    ['abc_def', 'letters_and_digits'],
    ['123_456', 'letters_and_digits'],
    ['Abc123', 'invalid_format'],
    ['abc.12', 'invalid_format'],
    ['_abc12', 'invalid_format'],
    ['abc12_', 'invalid_format'],
    ['abc-12', 'invalid_format'],
    [`a1${'b'.repeat(29)}`, 'too_long'],
  ])('%s → %s', (name, issue) => {
    expect(regularUsernameIssue(name)).toBe(issue);
  });

  it.each(['abc123', 'sara_2026', 'user1x', 'a1b2c3', `a1${'bc'.repeat(14)}`])(
    '%s is a regular username',
    (name) => {
      expect(regularUsernameIssue(name)).toBeNull();
      expect(isValidUsername(name)).toBe(true);
    },
  );

  it('registration reports the rule issue on `username`', () => {
    const base = { email: 'a@b.co', password: 'correct horse battery staple', displayName: 'A' };
    const bad = registerSchema.safeParse({ ...base, username: 'abcdef' });
    expect(bad.success).toBe(false);
    expect(bad.error?.issues[0]).toMatchObject({ path: ['username'], params: { issue: 'premium' } });
    expect(registerSchema.safeParse({ ...base, username: 'abc123' }).success).toBe(true);
  });

  it('the stored shape accepts 1–2 character premium names and grandfathered names', () => {
    for (const name of ['7', 'ab', 'old.nm', 'abc', 'abcdef']) expect(isValidUsername(name)).toBe(true);
    for (const name of ['', '_a', 'a_', 'A', 'a'.repeat(31)]) expect(isValidUsername(name)).toBe(false);
  });
});

describe('reserved and suggestions', () => {
  it('reserves the v1.0 names and anything containing kabso', () => {
    for (const name of ['admin', 'support', 'official', 'staff', 'moderator', 'kabso', 'kabso1', 'mykabso']) {
      expect(isCodeReservedPremium(name)).toBe(true);
    }
    expect(isCodeReservedPremium('7777')).toBe(false);
  });

  it('suggests premium, unreserved, unique names with the popular ones first', () => {
    const names = suggestionCandidates();
    expect(new Set(names).size).toBe(names.length);
    expect(names.slice(0, 3)).toEqual(['7', '8', '9']);
    for (const n of names) {
      expect(premiumTierOf(n)).not.toBeNull();
      expect(isCodeReservedPremium(n)).toBe(false);
    }
    for (const n of ['777777', '123456', '654321', '1221', 'abc', 'zzz']) expect(names).toContain(n);
  });
});
