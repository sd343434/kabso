import { describe, expect, it } from 'vitest';
import { notificationBody } from '../push/push-texts.js';
import {
  allowedActions,
  createOrderSchema,
  disputeOpensAt,
  formatMinor,
  formatRate,
  localMinorOf,
  orderMessageSchema,
  parseRateMicro,
  quote,
  retailMicroPerMillion,
  usdMinorOf,
} from './recharge-order-rules.js';

/** D204 (§10.64): the pure rules of recharge orders. */
describe('D204 recharge order prices', () => {
  it('prices coins at the retail price in cents, rounded half up', () => {
    const per = retailMicroPerMillion(12.5);
    expect(usdMinorOf(1_000_000n, per)).toBe(1250n);
    expect(usdMinorOf(100_000n, per)).toBe(125n);
    expect(usdMinorOf(10_000n, per)).toBe(13n);
    expect(usdMinorOf(1n, per)).toBe(0n);
    expect(usdMinorOf(1_000_000_000n, retailMicroPerMillion(9.9999))).toBe(1_000_000n - 10n);
    expect(() => usdMinorOf(0n, per)).toThrow(RangeError);
  });

  it('converts at the admin rate in the currency decimals', () => {
    expect(parseRateMicro('50.5')).toBe(50_500_000n);
    expect(parseRateMicro(' 3.75 ')).toBe(3_750_000n);
    for (const bad of ['', '0', '0.000000', '-1', '1e3', '1.1234567', 'abc'])
      expect(parseRateMicro(bad)).toBeNull();
    expect(formatRate(50_500_000n)).toBe('50.5');
    expect(formatRate(1_310_000_000n)).toBe('1310');
    expect(localMinorOf(1250n, 50_500_000n, 2)).toBe(63_125n);
    expect(localMinorOf(1250n, 307_000n, 3)).toBe(3838n); // 3.8375 KWD → 3.838
    expect(localMinorOf(1250n, 1_310_000_000n, 0)).toBe(16_375n);
    expect(formatMinor(63_125n, 2)).toBe('631.25');
    expect(formatMinor(5n, 3)).toBe('0.005');
    expect(formatMinor(16_375n, 0)).toBe('16375');
    expect(quote(2_000_000n, 12.5, null)).toEqual({ coins: 2_000_000n, usdMinor: 2500n, local: null });
    expect(quote(2_000_000n, 12.5, { currency: 'SAR', rateMicro: 3_750_000n, digits: 2 }).local).toEqual({
      currency: 'SAR',
      rateMicro: 3_750_000n,
      digits: 2,
      minor: 9375n,
    });
  });
});

describe('D204 who may do what', () => {
  const at = new Date('2026-11-01T10:00:00Z');
  const rules = { disputeAfterMinutes: 15 };
  const state = (status: string, extra: Partial<{ noticeAckAt: Date; paidAt: Date }> = {}) => ({
    status: status as never,
    noticeAckAt: extra.noticeAckAt ?? null,
    paidAt: extra.paidAt ?? null,
  });

  it('follows the owner flow per side and status', () => {
    expect(allowedActions(state('REQUESTED'), 'AGENT', at, rules)).toEqual([
      'MESSAGE',
      'SEND_DETAILS',
      'CANCEL',
    ]);
    expect(allowedActions(state('REQUESTED'), 'BUYER', at, rules)).toEqual(['MESSAGE', 'CANCEL']);
    expect(allowedActions(state('AWAITING_PAYMENT'), 'BUYER', at, rules)).toEqual([
      'MESSAGE',
      'ACK_NOTICE',
      'CANCEL',
    ]);
    expect(allowedActions(state('AWAITING_PAYMENT', { noticeAckAt: at }), 'BUYER', at, rules)).toEqual([
      'MESSAGE',
      'MARK_PAID',
      'CANCEL',
    ]);
    expect(allowedActions(state('AWAITING_PAYMENT'), 'AGENT', at, rules)).toEqual(['MESSAGE']);
    const paid = state('PAID', { paidAt: at });
    expect(allowedActions(paid, 'AGENT', at, rules)).toEqual(['MESSAGE', 'CONFIRM', 'DISPUTE']);
    expect(allowedActions(paid, 'BUYER', new Date(at.getTime() + 14 * 60_000), rules)).toEqual(['MESSAGE']);
    expect(allowedActions(paid, 'BUYER', disputeOpensAt(at, 15), rules)).toEqual(['MESSAGE', 'DISPUTE']);
    expect(allowedActions(state('DISPUTED', { paidAt: at }), 'BUYER', at, rules)).toEqual(['MESSAGE']);
    for (const s of ['CANCELLED', 'EXPIRED'])
      expect(allowedActions(state(s), 'BUYER', at, rules)).toEqual([]);
    expect(allowedActions(state('COMPLETED'), 'AGENT', at, rules)).toEqual(['MESSAGE']);
  });

  it('validates the bodies', () => {
    expect(
      createOrderSchema.safeParse({ agentCode: 'coin0001', country: 'eg', coins: 1000, paymentType: 'CASH' })
        .data?.country,
    ).toBe('EG');
    expect(
      createOrderSchema.safeParse({ agentCode: 'coin0001', country: 'EG', coins: 1, paymentType: 'GOLD' })
        .success,
    ).toBe(false);
    expect(orderMessageSchema.safeParse({ text: '  سطر\r\nسطر  ' }).data).toEqual({ text: 'سطر\nسطر' });
    expect(orderMessageSchema.safeParse({}).success).toBe(false);
    expect(
      orderMessageSchema.safeParse({ text: 'a', imageUploadId: '01a1b79f-efb5-7318-bc1c-19aee96dd1fd' })
        .success,
    ).toBe(false);
    expect(orderMessageSchema.safeParse({ text: 'a‮b' }).success).toBe(false);
  });

  it('words every order push in both languages', () => {
    for (const event of [
      'CREATED',
      'DETAILS_SENT',
      'PAID',
      'COMPLETED',
      'DISPUTED',
      'EXPIRED',
      'MESSAGE',
      null,
    ]) {
      for (const locale of ['ar', 'en'] as const) {
        const body = notificationBody(
          {
            type: 'RECHARGE_ORDER_UPDATE',
            actorName: null,
            actorCount: 0,
            targetType: 'RECHARGE_ORDER',
            targetId: 'x',
            targetText: event,
          },
          locale,
        );
        expect(body).toBeTruthy();
      }
    }
  });
});
