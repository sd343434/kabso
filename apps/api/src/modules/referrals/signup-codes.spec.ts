import { describe, expect, it } from 'vitest';
import { emailMarkKey, emailMarkOf, parseSignupCode, signupCodeInput } from './signup-codes.js';

describe('D343 sign-up code «رمز الدعوة أو رمز المشرف»', () => {
  it('reads an invite code (spaces, dashes, lower case, a link)', () => {
    expect(parseSignupCode(' k7qm-4p2x ')).toEqual({ kind: 'INVITE', code: 'K7QM4P2X' });
    expect(parseSignupCode('https://kabsolive.com/i/K7QM4P2X')).toEqual({ kind: 'INVITE', code: 'K7QM4P2X' });
    expect(parseSignupCode('https://kabsolive.com/i/k7qm4p2x/?x=1')).toEqual({
      kind: 'INVITE',
      code: 'K7QM4P2X',
    });
  });

  it('reads a supervisor staff ID in its display form (any case, @, leading zeros, a link)', () => {
    expect(parseSignupCode('Kabso07')).toEqual({ kind: 'SUPERVISOR', code: 'Kabso07', number: 7 });
    expect(parseSignupCode('@KABSO7')).toEqual({ kind: 'SUPERVISOR', code: 'Kabso07', number: 7 });
    expect(parseSignupCode('kabso 120')).toEqual({ kind: 'SUPERVISOR', code: 'Kabso120', number: 120 });
    expect(parseSignupCode('https://kabsolive.com/i/Kabso07')).toMatchObject({
      kind: 'SUPERVISOR',
      number: 7,
    });
    // The primary OWNER's plain «Kabso» parses (number 0) and is refused by the database rule (not a recruiter).
    expect(parseSignupCode('Kabso')).toMatchObject({ kind: 'SUPERVISOR', number: 0 });
  });

  it('an invite code never reads as a staff ID (the alphabet has no O) and junk is refused', () => {
    expect(parseSignupCode('KABS2345')?.kind).toBe('INVITE');
    expect(parseSignupCode('!!')).toBeNull();
    expect(parseSignupCode('@user.name')).toBeNull();
    expect(parseSignupCode('ABC')).toBeNull();
    expect(signupCodeInput.safeParse('kabso07').data).toBe('Kabso07');
    expect(signupCodeInput.safeParse('x'.repeat(201)).success).toBe(false);
  });

  it('the mailbox mark is keyed and follows the alias folding of the referral checks', () => {
    const key = emailMarkKey('a'.repeat(48));
    const other = emailMarkKey('b'.repeat(48));
    const mark = emailMarkOf(key, 'Ali.Hassan+promo@gmail.com');
    expect(mark).toMatch(/^[0-9a-f]{64}$/);
    expect(emailMarkOf(key, 'alihassan@googlemail.com')).toBe(mark);
    expect(emailMarkOf(other, 'alihassan@gmail.com')).not.toBe(mark);
    expect(emailMarkOf(key, 'ali.hassan@example.com')).not.toBe(emailMarkOf(key, 'alihassan@example.com'));
  });
});
