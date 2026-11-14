import { describe, expect, it } from 'vitest';
import {
  VIP_SIGNATURE_MAX,
  vipGoldenIdClassOf,
  vipGoldenIdClassValue,
  vipPremiumClaimAllows,
  vipPremiumClassValue,
  vipSignatureOf,
} from './vip-identity.js';

/** v1.131-social (D378, CONVENTIONS §10.168): the identity perks' pure rules. */
describe('D378 VIP identity rules', () => {
  it('signature: 1–24 characters on one line, spaces collapsed, NFC', () => {
    expect(vipSignatureOf('  ملك   الليل ')).toEqual({ ok: true, text: 'ملك الليل' });
    expect(vipSignatureOf('a'.repeat(VIP_SIGNATURE_MAX))).toEqual({ ok: true, text: 'a'.repeat(24) });
    expect(vipSignatureOf('a'.repeat(VIP_SIGNATURE_MAX + 1))).toEqual({ ok: false, issue: 'too_long' });
    // Code points, not UTF-16 units: 24 emoji fit.
    expect(vipSignatureOf('🔥'.repeat(24)).ok).toBe(true);
    expect(vipSignatureOf('   ')).toEqual({ ok: false, issue: 'too_short' });
    expect(vipSignatureOf('line\nbreak')).toEqual({ ok: false, issue: 'invalid_format' });
    expect(vipSignatureOf('bidi‮trick')).toEqual({ ok: false, issue: 'invalid_format' });
    expect(vipSignatureOf('zero​width')).toEqual({ ok: false, issue: 'invalid_format' });
    expect(vipSignatureOf('é')).toEqual({ ok: true, text: 'é' });
  });

  it('golden ID classes: repeated digits first, then by length; others are not golden IDs', () => {
    expect(vipGoldenIdClassOf('8888')).toBe('REPEATED');
    expect(vipGoldenIdClassOf('77')).toBe('REPEATED');
    expect(vipGoldenIdClassOf('99999999')).toBe('REPEATED');
    expect(vipGoldenIdClassOf('123')).toBe('THREE_DIGIT');
    expect(vipGoldenIdClassOf('2026')).toBe('FOUR_DIGIT');
    expect(vipGoldenIdClassOf('12345')).toBe('FIVE_DIGIT');
    expect(vipGoldenIdClassOf('12')).toBeNull();
    expect(vipGoldenIdClassOf('123456')).toBeNull();
    expect(vipGoldenIdClassOf('0123')).toBeNull();
    expect(vipGoldenIdClassOf('12a4')).toBeNull();
    expect(vipGoldenIdClassOf('000')).toBeNull();
    expect(vipGoldenIdClassValue('FOUR_DIGIT')).toBe('FOUR_DIGIT');
    expect(vipGoldenIdClassValue('GOLD')).toBeNull();
    expect(vipGoldenIdClassValue(null)).toBeNull();
  });

  it('premium usernames: the perk class claims its medal and the lower ones', () => {
    expect(vipPremiumClaimAllows('GOLD', 'GOLD')).toBe(true);
    expect(vipPremiumClaimAllows('GOLD', 'SILVER')).toBe(true);
    expect(vipPremiumClaimAllows('GOLD', 'RUBY')).toBe(false);
    expect(vipPremiumClaimAllows('GOLD', 'LEGEND')).toBe(false);
    expect(vipPremiumClaimAllows('LEGEND', 'SILVER')).toBe(true);
    expect(vipPremiumClaimAllows('SILVER', 'GOLD')).toBe(false);
    expect(vipPremiumClassValue('RUBY')).toBe('RUBY');
    expect(vipPremiumClassValue('PLATINUM')).toBeNull();
    expect(vipPremiumClassValue(3)).toBeNull();
  });
});
