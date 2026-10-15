import { describe, expect, it } from 'vitest';
import { passwordSchema } from './auth.schemas.js';
import { PASSWORD_MAX_LENGTH, PASSWORD_MIN_LENGTH, passwordPolicyIssue } from './password-policy.js';

describe('passwordPolicyIssue', () => {
  it('enforces 8–128 characters (CONVENTIONS §6)', () => {
    expect(PASSWORD_MIN_LENGTH).toBe(8);
    expect(PASSWORD_MAX_LENGTH).toBe(128);
    expect(passwordPolicyIssue('1234567')).toBe('too_short');
    expect(passwordPolicyIssue('12345678')).toBeNull();
    expect(passwordPolicyIssue('x'.repeat(128))).toBeNull();
    expect(passwordPolicyIssue('x'.repeat(129))).toBe('too_long');
  });

  it('counts Unicode code points, not UTF-16 units', () => {
    // 4 emoji = 8 UTF-16 units but only 4 characters.
    expect(passwordPolicyIssue('😀😀😀😀')).toBe('too_short');
    expect(passwordPolicyIssue('كلمةسرطويلة')).toBeNull();
    expect(passwordPolicyIssue('😀'.repeat(128))).toBeNull();
  });

  it('is applied by the request schema with stable issue names', () => {
    const short = passwordSchema.safeParse('short');
    expect(short.success).toBe(false);
    expect(short.error?.issues[0]).toMatchObject({ code: 'custom', params: { issue: 'too_short' } });
    expect(passwordSchema.safeParse('long enough').success).toBe(true);
    expect(passwordSchema.safeParse(12345678).success).toBe(false);
  });
});
