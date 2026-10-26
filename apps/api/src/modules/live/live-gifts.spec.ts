import { describe, expect, it } from 'vitest';
import { comboFor, giftAmounts, recipientsKey, type PreviousSend } from './live-gifts.js';
import { liveGiftSendSchema } from './live.schemas.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';

describe('live gift amounts (CP-020)', () => {
  it('multiplies price, quantity and recipients; 100 score points a coin', () => {
    expect(giftAmounts(10, 1, 1)).toEqual({
      perRecipientCoins: 10,
      totalCoins: 10,
      bagUnits: 1,
      scorePoints: 1000,
    });
    expect(giftAmounts(5, 66, 3)).toEqual({
      perRecipientCoins: 330,
      totalCoins: 990,
      bagUnits: 198,
      scorePoints: 99_000,
    });
  });

  it('stays exact at the largest send (price 1 000 000 × 9 999 × 25)', () => {
    const a = giftAmounts(1_000_000, 9_999, 25);
    expect(a.totalCoins).toBe(249_975_000_000);
    expect(a.scorePoints).toBe(24_997_500_000_000);
    expect(Number.isSafeInteger(a.scorePoints)).toBe(true);
  });
});

describe('live gift combos (CP-020)', () => {
  const t0 = new Date('2026-10-26T12:00:00.000Z');
  const at = (ms: number) => new Date(t0.getTime() + ms);
  const prev: PreviousSend = {
    giftCode: 'rose',
    recipientsKey: 'a,b',
    comboId: 'combo-1',
    comboCount: 2,
    comboQuantity: 20n,
    createdAt: t0,
  };
  const send = { id: 'new', giftCode: 'rose', recipientsKey: 'a,b', quantity: 10 };

  it('starts a combo without a previous send', () => {
    expect(comboFor(null, send, t0, 5000)).toEqual({ id: 'new', count: 1, quantity: 10n });
  });

  it('continues it for the same gift to the same recipients within the window (inclusive)', () => {
    expect(comboFor(prev, send, at(5000), 5000)).toEqual({ id: 'combo-1', count: 3, quantity: 30n });
    // A clock that went backwards counts as no time passed.
    expect(comboFor(prev, send, at(-3000), 5000)).toEqual({ id: 'combo-1', count: 3, quantity: 30n });
  });

  it('starts a new one after the window, for another gift or other recipients', () => {
    expect(comboFor(prev, send, at(5001), 5000).count).toBe(1);
    expect(comboFor(prev, { ...send, giftCode: 'car' }, at(1), 5000).id).toBe('new');
    expect(comboFor(prev, { ...send, recipientsKey: 'a' }, at(1), 5000).id).toBe('new');
  });

  it('keys recipients regardless of their order', () => {
    expect(recipientsKey(['b', 'a', 'c'])).toBe('a,b,c');
    expect(recipientsKey(['c', 'a', 'b'])).toBe(recipientsKey(['a', 'b', 'c']));
  });
});

describe('LiveGiftSendRequest (CP-020)', () => {
  const schema = liveGiftSendSchema([1, 10, 66]);
  const ok = {
    giftCode: 'rose',
    quantity: 10,
    recipients: ['host1', 'guest2'],
    source: 'COINS',
    clientId: '0192f1c2-0000-7000-8000-000000000001',
  };
  const issues = (body: unknown) => {
    const r = schema.safeParse(body, { reportInput: true });
    return r.success ? [] : zodErrorToDetails(r.error);
  };

  it('accepts a valid body (COINS or BAG)', () => {
    expect(schema.parse(ok)).toEqual(ok);
    expect(schema.parse({ ...ok, source: 'BAG' }).source).toBe('BAG');
  });

  it('refuses a quantity outside the configured set', () => {
    expect(issues({ ...ok, quantity: 2 })).toEqual([{ field: 'quantity', issue: 'invalid_value' }]);
    expect(issues({ ...ok, quantity: 1.5 })[0]?.field).toBe('quantity');
    expect(issues({ ...ok, quantity: '10' })).toEqual([{ field: 'quantity', issue: 'invalid_type' }]);
  });

  it('needs 1–25 distinct recipients', () => {
    expect(issues({ ...ok, recipients: [] })).toEqual([{ field: 'recipients', issue: 'too_few' }]);
    expect(issues({ ...ok, recipients: Array.from({ length: 26 }, (_, i) => `u${String(i)}`) })).toEqual([
      { field: 'recipients', issue: 'too_many' },
    ]);
    expect(
      schema.safeParse({ ...ok, recipients: Array.from({ length: 25 }, (_, i) => `u${String(i)}`) }).success,
    ).toBe(true);
    expect(issues({ ...ok, recipients: ['a1b', 'A1B'] })).toEqual([
      { field: 'recipients', issue: 'invalid_value' },
    ]);
  });

  it('requires every field and refuses unknown ones', () => {
    for (const field of ['giftCode', 'quantity', 'recipients', 'source', 'clientId']) {
      const body: Record<string, unknown> = { ...ok };
      delete body[field];
      expect(issues(body)).toEqual([{ field, issue: 'required' }]);
    }
    expect(issues({ ...ok, source: 'FREE' })).toEqual([{ field: 'source', issue: 'invalid_value' }]);
    expect(issues({ ...ok, extra: 1 })).toEqual([{ field: 'extra', issue: 'unknown_field' }]);
    expect(issues({ ...ok, clientId: 'x' })).toEqual([{ field: 'clientId', issue: 'invalid_format' }]);
  });
});
