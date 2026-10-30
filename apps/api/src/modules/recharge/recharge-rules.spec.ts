import { describe, expect, it } from 'vitest';
import { rechargeAgentCodeOf } from '../posts/post-views.js';
import {
  agentCode,
  applicationSchema,
  availabilitySchema,
  cherriesPayoutMinor,
  cherriesToCoins,
  dayStart,
  employeeHoursSchema,
  localClock,
  normalizeAgentCode,
  parseMoneyMinor,
  slotAt,
  topUpPrice,
  validCherryAmount,
} from './recharge-rules.js';

const TIERS = [
  { minCoins: 0, minorPerMillion: 1200 },
  { minCoins: 100_000_000, minorPerMillion: 1195 },
  { minCoins: 300_000_000, minorPerMillion: 1190 },
];

describe('D185 recharge rules', () => {
  it('codes are coin + at least four digits, never changed by case', () => {
    expect(agentCode(1)).toBe('coin0001');
    expect(agentCode(42)).toBe('coin0042');
    expect(agentCode(12345)).toBe('coin12345');
    expect(() => agentCode(0)).toThrow(RangeError);
    expect(normalizeAgentCode(' COIN0007 ')).toBe('coin0007');
    expect(normalizeAgentCode('coin7')).toBeNull();
    expect(normalizeAgentCode('agent0001')).toBeNull();
  });

  it("uses the owner's price tiers ($12, from 100M $11.95, from 300M $11.90)", () => {
    expect(topUpPrice(30_000_000n, TIERS)).toEqual({
      tier: 'STANDARD',
      minorPerMillion: 1200,
      expectedMinor: 36_000n,
    });
    expect(topUpPrice(99_999_999n, TIERS).tier).toBe('STANDARD');
    expect(topUpPrice(100_000_000n, TIERS)).toEqual({
      tier: 'FROM_100M',
      minorPerMillion: 1195,
      expectedMinor: 119_500n,
    });
    expect(topUpPrice(299_990_000n, TIERS).minorPerMillion).toBe(1195);
    expect(topUpPrice(300_000_000n, TIERS)).toEqual({
      tier: 'FROM_300M',
      minorPerMillion: 1190,
      expectedMinor: 357_000n,
    });
    // Rounded half up to a cent.
    expect(topUpPrice(10_000_001n, TIERS).expectedMinor).toBe(12_000n);
    expect(() => topUpPrice(0n, TIERS)).toThrow(RangeError);
  });

  it('parses admin USD amounts exactly', () => {
    expect(parseMoneyMinor('360')).toBe(36_000n);
    expect(parseMoneyMinor('360.5')).toBe(36_050n);
    expect(parseMoneyMinor('360.05')).toBe(36_005n);
    expect(parseMoneyMinor('-1')).toBeNull();
    expect(parseMoneyMinor('1.234')).toBeNull();
    expect(parseMoneyMinor('')).toBeNull();
  });

  it('converts cherries to stock coins with integer floor, and the host payout', () => {
    const rate = { cherries: 1_000_000, coins: 93_220 };
    expect(cherriesToCoins(1_000_000n, rate)).toBe(93_220n);
    expect(cherriesToCoins(100_000n, rate)).toBe(9_322n);
    expect(cherriesToCoins(1_234_567n, rate)).toBe(115_086n);
    expect(cherriesPayoutMinor(1_000_000n, 1_000_000, 110)).toBe(110n);
    expect(cherriesPayoutMinor(2_500_000n, 1_000_000, 110)).toBe(275n);
    expect(validCherryAmount(1_000_000n, 1_000_000, 100_000)).toBe(true);
    expect(validCherryAmount(1_100_000n, 1_000_000, 100_000)).toBe(true);
    expect(validCherryAmount(900_000n, 1_000_000, 100_000)).toBe(false);
    expect(validCherryAmount(1_050_000n, 1_000_000, 100_000)).toBe(false);
  });

  it('reads weekly hours in the employee or agent time zone', () => {
    // 2026-10-30 is a Friday (ISO 5); 10:30 UTC = 13:30 in Cairo (UTC+3 in DST off → +2/+3 both inside).
    const now = new Date('2026-10-30T10:30:00Z');
    expect(localClock(now, 'UTC')).toEqual({ day: 5, minutes: 630 });
    const slots = [
      { days: [5], start: '09:00', end: '12:00' },
      { days: [6], start: '00:00', end: '24:00' },
    ];
    expect(slotAt(slots, 'UTC', now)).toBe(slots[0]);
    expect(slotAt(slots, 'Asia/Tokyo', now)).toBeNull(); // 19:30 on Friday
    expect(slotAt(slots, 'Pacific/Kiritimati', now)).toBe(slots[1]); // 00:30 on Saturday
    // End is exclusive.
    expect(slotAt(slots, 'UTC', new Date('2026-10-30T12:00:00Z'))).toBeNull();
    expect(dayStart(now, 'UTC').toISOString()).toBe('2026-10-30T00:00:00.000Z');
  });

  it('validates applications strictly', () => {
    const ok = {
      fullName: 'محمد أحمد علي حسن',
      phone: '+201001234567',
      whatsapp: true,
      photoUploadId: '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f80',
      selfieUploadId: '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f81',
      locations: [{ country: 'eg', cities: ['Cairo'] }],
      paymentMethods: [{ country: 'EG', type: 'MOBILE_WALLET', details: 'Vodafone Cash' }],
    };
    const parsed = applicationSchema.safeParse(ok);
    expect(parsed.success).toBe(true);
    expect(parsed.data?.locations[0]?.country).toBe('EG');
    expect(applicationSchema.safeParse({ ...ok, fullName: 'Mohamed Ahmed Ali' }).success).toBe(false);
    expect(applicationSchema.safeParse({ ...ok, phone: '01001234567' }).success).toBe(false);
    expect(applicationSchema.safeParse({ ...ok, whatsapp: false }).success).toBe(false);
    expect(
      applicationSchema.safeParse({
        ...ok,
        paymentMethods: [{ country: 'SA', type: 'CASH', details: 'cash' }],
      }).success,
    ).toBe(false);
    expect(applicationSchema.safeParse({ ...ok, fullName: 'a‮b c d e f g' }).success).toBe(false);
    expect(applicationSchema.safeParse({ ...ok, extra: 1 }).success).toBe(false);
  });

  it('validates availability and hours', () => {
    const slot = {
      days: [1, 2],
      start: '10:00',
      end: '18:00',
      whatsapp: '+201001234567',
      paymentMethod: 'InstaPay',
    };
    expect(availabilitySchema.safeParse({ timeZone: 'Africa/Cairo', slots: [slot] }).success).toBe(true);
    expect(availabilitySchema.safeParse({ timeZone: 'Mars/Base', slots: [slot] }).success).toBe(false);
    expect(
      availabilitySchema.safeParse({ timeZone: 'UTC', slots: [{ ...slot, start: '18:00', end: '10:00' }] })
        .success,
    ).toBe(false);
    expect(
      employeeHoursSchema.safeParse({
        timeZone: 'UTC',
        schedule: [{ days: [7], start: '20:00', end: '24:00' }],
      }).success,
    ).toBe(true);
    expect(employeeHoursSchema.safeParse({ timeZone: 'UTC', schedule: [] }).success).toBe(false);
    expect(
      employeeHoursSchema.safeParse({
        timeZone: 'UTC',
        schedule: [{ days: [1, 1], start: '01:00', end: '02:00' }],
      }).success,
    ).toBe(false);
  });

  it('shows the badge only for an ACTIVE agent with an active account', () => {
    expect(
      rechargeAgentCodeOf({ status: 'ACTIVE', rechargeAgent: { status: 'ACTIVE', code: 'coin0001' } }),
    ).toBe('coin0001');
    expect(
      rechargeAgentCodeOf({ status: 'ACTIVE', rechargeAgent: { status: 'SUSPENDED', code: 'coin0001' } }),
    ).toBe(null);
    expect(
      rechargeAgentCodeOf({ status: 'SUSPENDED', rechargeAgent: { status: 'ACTIVE', code: 'coin0001' } }),
    ).toBe(null);
    expect(
      rechargeAgentCodeOf({ status: 'ACTIVE', rechargeAgent: { status: 'APPROVED', code: null } }),
    ).toBeNull();
    expect(rechargeAgentCodeOf({ status: 'ACTIVE', rechargeAgent: null })).toBeNull();
  });
});
