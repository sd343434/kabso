import { describe, expect, it } from 'vitest';
import { isTransferable } from '../bag/bag.catalogue.js';
import { EventAdminError } from './event-admin-rules.js';
import {
  bundleCoins,
  bundleForRank,
  checkGiftEventShape,
  giftEventInputSchema,
  isTimeZone,
  parseBundle,
  parsePrizeLines,
  prizeLineProblems,
  type GiftEventInput,
  type PrizeLine,
} from './gift-events.js';

const NOW = new Date('2026-11-07T12:00:00Z');

function input(over: Partial<Record<keyof GiftEventInput, unknown>> = {}): GiftEventInput {
  return giftEventInputSchema.parse({
    titleAr: 'ملك الهدايا',
    titleEn: 'Gift King',
    startsAt: '2026-11-08T00:00:00+03:00',
    endsAt: '2026-11-15T00:00:00+03:00',
    gifts: [{ giftCode: 'rose', pointsPerCoin: 1 }],
    boards: [
      { kind: 'SENDERS', prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'COINS', amount: 10 }] }] },
    ],
    reason: 'test event',
    ...over,
  });
}

describe('D303 gift event input (shared by the panel and the app)', () => {
  it('fills the defaults and accepts every board kind and prize type', () => {
    const v = input({
      boards: [
        { kind: 'SENDERS' },
        { kind: 'RECEIVERS', minPoints: 5 },
        { kind: 'CREATORS' },
        { kind: 'AGENCIES' },
        {
          kind: 'CP',
          prizes: [
            {
              rankFrom: 1,
              rankTo: 3,
              items: [
                { type: 'COINS', amount: 1 },
                { type: 'CHERRIES', amount: 2 },
                { type: 'BAG_ITEM', itemCode: 'frame_gold', days: 7 },
                { type: 'VIP', tierCode: 'VIP_1', days: 3 },
              ],
            },
          ],
        },
      ],
    });
    expect(v).toMatchObject({ audience: 'EVERYONE', regions: [], featured: false, rulesAr: '' });
    expect(v.gifts[0]).toEqual({ giftCode: 'rose', pointsPerCoin: 1, pointsPerGift: 0 });
    expect(v.boards.map((b) => [b.kind, b.minPoints])).toEqual([
      ['SENDERS', 0],
      ['RECEIVERS', 5],
      ['CREATORS', 0],
      ['AGENCIES', 0],
      ['CP', 0],
    ]);
  });

  it('refuses shapes: no gift, too many items, a day count of 0, an unknown type or board', () => {
    const bad = (over: Partial<Record<keyof GiftEventInput, unknown>>) =>
      giftEventInputSchema.safeParse({ ...input(), ...over }).success;
    expect(bad({ gifts: [] })).toBe(false);
    expect(bad({ boards: [] })).toBe(false);
    expect(bad({ boards: [{ kind: 'FANS' }] })).toBe(false);
    expect(
      bad({
        boards: [
          {
            kind: 'SENDERS',
            prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'BAG_ITEM', itemCode: 'x', days: 0 }] }],
          },
        ],
      }),
    ).toBe(false);
    expect(
      bad({
        boards: [
          { kind: 'SENDERS', prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'MEDAL', code: 'x' }] }] },
        ],
      }),
    ).toBe(false);
    expect(
      bad({
        boards: [
          {
            kind: 'SENDERS',
            prizes: [
              {
                rankFrom: 1,
                rankTo: 1,
                items: Array.from({ length: 7 }, () => ({ type: 'COINS', amount: 1 })),
              },
            ],
          },
        ],
      }),
    ).toBe(false);
    expect(bad({ startsAt: '2026-11-08 00:00' })).toBe(false);
  });

  it('checks the cross-field rules: dates, length, lead, zone, duplicates, zero points, prize lines', () => {
    expect(checkGiftEventShape(input(), NOW)).toEqual({
      startsAt: new Date('2026-11-07T21:00:00Z'),
      endsAt: new Date('2026-11-14T21:00:00Z'),
    });
    const refused = (over: Partial<Record<keyof GiftEventInput, unknown>>) => () =>
      checkGiftEventShape(input(over), NOW);
    expect(refused({ endsAt: '2026-11-07T00:00:00Z' })).toThrow(EventAdminError);
    expect(refused({ endsAt: '2027-03-01T00:00:00Z' })).toThrow(/at most 92 days/);
    expect(refused({ startsAt: '2027-12-01T00:00:00Z', endsAt: '2027-12-02T00:00:00Z' })).toThrow(/ahead/);
    expect(refused({ timeZone: 'Nowhere/Land' })).toThrow(/time zone/);
    expect(refused({ gifts: [{ giftCode: 'rose' }, { giftCode: 'rose' }] })).toThrow(/twice/);
    expect(refused({ gifts: [{ giftCode: 'rose', pointsPerCoin: 0, pointsPerGift: 0 }] })).toThrow(
      /no points/,
    );
    expect(refused({ boards: [{ kind: 'CP' }, { kind: 'CP' }] })).toThrow(/board is listed twice/);
    expect(
      refused({
        boards: [
          {
            kind: 'SENDERS',
            prizes: [
              { rankFrom: 4, rankTo: 5, items: [{ type: 'COINS', amount: 1 }] },
              { rankFrom: 1, rankTo: 3, items: [{ type: 'COINS', amount: 1 }] },
            ],
          },
        ],
      }),
    ).toThrow(/overlap or are out of order/);
    expect(checkGiftEventShape(input({ timeZone: 'Asia/Riyadh' }), NOW).startsAt).toBeInstanceOf(Date);
  });

  it('prize lines: problems, the bundle of a rank, its coins; stored data parses or reads as none', () => {
    const lines: PrizeLine[] = [
      {
        rankFrom: 1,
        rankTo: 1,
        items: [
          { type: 'COINS', amount: 1000 },
          { type: 'VIP', tierCode: 'V', days: 30 },
        ],
      },
      {
        rankFrom: 2,
        rankTo: 3,
        items: [
          { type: 'COINS', amount: 300 },
          { type: 'COINS', amount: 1 },
        ],
      },
      { rankFrom: 6, rankTo: 10, items: [{ type: 'BAG_ITEM', itemCode: 'car', days: 3 }] },
    ];
    expect(prizeLineProblems(lines)).toEqual(['Ranks 2–3: an item is listed twice.']);
    expect(bundleForRank(lines, 1).map((i) => i.type)).toEqual(['COINS', 'VIP']);
    expect(bundleForRank(lines, 4)).toEqual([]);
    expect(bundleForRank(lines, 10)).toEqual([{ type: 'BAG_ITEM', itemCode: 'car', days: 3 }]);
    expect(bundleCoins(bundleForRank(lines, 1))).toBe(1000);
    expect(bundleCoins(bundleForRank(lines, 7))).toBe(0);
    expect(parsePrizeLines('nope')).toEqual([]);
    expect(parsePrizeLines([{ rankFrom: 1, rankTo: 1, items: [{ type: 'COINS', amount: 5 }] }])).toHaveLength(
      1,
    );
    expect(parseBundle([{ type: 'CHERRIES', amount: 5 }])).toEqual([{ type: 'CHERRIES', amount: 5 }]);
    expect(parseBundle([{ type: 'CHERRIES' }])).toEqual([]);
  });

  it('time zones and the prize items in the bag', () => {
    expect(isTimeZone('Asia/Riyadh')).toBe(true);
    expect(isTimeZone('America/Argentina/Buenos_Aires')).toBe(true);
    expect(isTimeZone('Mars/Olympus')).toBe(false);
    expect(isTimeZone("x'; DROP")).toBe(false);
    // An event prize stays with its winner (not transferable, like a level reward).
    expect(isTransferable(false, 'EVENT', new Date())).toBe(false);
    expect(isTransferable(false, 'STORE', new Date())).toBe(true);
  });
});

describe('D303 follow-ups: the board money, CP two-amount lines, permanent prizes, medal levels', () => {
  const line = (items: unknown[]) => [{ rankFrom: 1, rankTo: 1, items }];
  it('each board takes only its money (supporters coins; hosts, creators cherries; agencies either; CP CP_MONEY)', () => {
    const shape = (kind: string, items: unknown[]) => () =>
      checkGiftEventShape(input({ boards: [{ kind, prizes: line(items) }] }), NOW);
    expect(shape('SENDERS', [{ type: 'CHERRIES', amount: 1 }])).toThrow(/SENDERS/);
    expect(shape('RECEIVERS', [{ type: 'COINS', amount: 1 }])).toThrow(/RECEIVERS/);
    expect(shape('CREATORS', [{ type: 'COINS', amount: 1 }])).toThrow(EventAdminError);
    expect(shape('CP', [{ type: 'COINS', amount: 1 }])).toThrow(/CP/);
    expect(shape('CP', [{ type: 'CHERRIES', amount: 1 }])).toThrow(/CP/);
    expect(shape('SENDERS', [{ type: 'CP_MONEY', cherries: 1, coins: 1 }])).toThrow(/SENDERS/);
    expect(shape('AGENCIES', [{ type: 'COINS', amount: 1 }])).not.toThrow();
    expect(shape('AGENCIES', [{ type: 'CHERRIES', amount: 1 }])).not.toThrow();
    expect(shape('CP', [{ type: 'CP_MONEY', cherries: 400, coins: 0 }])).not.toThrow();
    expect(shape('RECEIVERS', [{ type: 'BAG_ITEM', itemCode: 'car', days: null }])).not.toThrow();
  });
  it('a CP money line needs one amount above 0; items and medals may be permanent, VIP never', () => {
    const ok = (item: unknown) =>
      giftEventInputSchema.safeParse({ ...input(), boards: [{ kind: 'CP', prizes: line([item]) }] }).success;
    expect(ok({ type: 'CP_MONEY', cherries: 0, coins: 0 })).toBe(false);
    expect(ok({ type: 'CP_MONEY', cherries: 0, coins: 5 })).toBe(true);
    expect(ok({ type: 'BAG_ITEM', itemCode: 'frame', days: null })).toBe(true);
    expect(ok({ type: 'BADGE', badgeCode: 'gift_king', level: 3, days: null })).toBe(true);
    expect(ok({ type: 'BADGE', badgeCode: 'gift_king', level: 11, days: 3 })).toBe(false);
    expect(ok({ type: 'VIP', tierCode: 'VIP_1', days: null })).toBe(false);
  });
});
