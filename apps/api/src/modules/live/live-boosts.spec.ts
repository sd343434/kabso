import { describe, expect, it } from 'vitest';
import { envSchema } from '../../config/env.schema.js';
import {
  boostOptions,
  boostStages,
  placeBoost,
  replanWaiting,
  slotsFreeAt,
  type PlannedBoost,
} from './live-boosts.js';

const T0 = new Date('2026-10-28T12:00:00.000Z');
const at = (min: number) => new Date(T0.getTime() + min * 60_000);
const b = (id: string, slot: number, from: number, to: number): PlannedBoost => ({
  id,
  slot,
  startsAt: at(from),
  endsAt: at(to),
});

describe('traffic cards (v1.33-live, D154b)', () => {
  it("D233: the owner's rocket prices are 4 stages of 10 / 20 / 30 / 60 minutes, and they save nothing", () => {
    const prices = envSchema.shape.LIVE_BOOST_PRICES.parse(undefined);
    expect(prices).toEqual([
      { minutes: 10, coins: 200_000 },
      { minutes: 20, coins: 550_000 },
      { minutes: 30, coins: 1_500_000 },
      { minutes: 60, coins: 3_500_000 },
    ]);
    // Per minute 20 000 / 27 500 / 50 000 / 58 333: a longer rocket is dearer per minute, so no «وفّر».
    expect(boostOptions(boostStages(prices))).toEqual([
      { stage: 1, minutes: 10, priceCoins: 200_000, savePercent: 0 },
      { stage: 2, minutes: 20, priceCoins: 550_000, savePercent: 0 },
      { stage: 3, minutes: 30, priceCoins: 1_500_000, savePercent: 0 },
      { stage: 4, minutes: 60, priceCoins: 3_500_000, savePercent: 0 },
    ]);
  });

  it('D154b savings stay right while they are true (the old prices: 10 / 17 / 25 %)', () => {
    const old = envSchema.shape.LIVE_BOOST_PRICES.parse('10:10000,20:18000,30:25000,60:45000');
    expect(boostOptions(boostStages(old)).map((o) => o.savePercent)).toEqual([0, 10, 17, 25]);
  });

  it("the panel's price of a stage wins over the config's; the length is always the config's", () => {
    const prices = envSchema.shape.LIVE_BOOST_PRICES.parse(undefined);
    expect(boostStages(prices, new Map([[3, 1_200_000]]))).toEqual([
      { stage: 1, minutes: 10, coins: 200_000 },
      { stage: 2, minutes: 20, coins: 550_000 },
      { stage: 3, minutes: 30, coins: 1_200_000 },
      { stage: 4, minutes: 60, coins: 3_500_000 },
    ]);
  });

  it('the config holds exactly 4 lengths (the stages), sorted, distinct, in range', () => {
    expect(envSchema.shape.LIVE_BOOST_PRICES.parse(' 60:4, 5:1,20:2 ,30:3')).toEqual([
      { minutes: 5, coins: 1 },
      { minutes: 20, coins: 2 },
      { minutes: 30, coins: 3 },
      { minutes: 60, coins: 4 },
    ]);
    for (const bad of [
      '10:0,20:1,30:1,60:1',
      '0:5,20:1,30:1,60:1',
      '10:5,10:6,30:1,60:1',
      'ten:5,20:1,30:1,60:1',
      '1441:5,20:1,30:1,60:1',
      '10:1,20:2,30:3',
      '10:1,20:2,30:3,60:4,90:5',
      '',
    ]) {
      expect(envSchema.shape.LIVE_BOOST_PRICES.safeParse(bad).success, bad).toBe(false);
    }
  });

  it('a card takes the slot that frees first; with every slot busy it waits for the earliest', () => {
    expect(placeBoost(slotsFreeAt(T0, 3, []), 10)).toEqual({ slot: 0, startsAt: T0, endsAt: at(10) });
    const busy = [b('a', 0, 0, 30), b('b', 1, 0, 10), b('c', 2, 0, 20)];
    expect(placeBoost(slotsFreeAt(T0, 3, busy), 60)).toEqual({ slot: 1, startsAt: at(10), endsAt: at(70) });
    // A card that ended before now leaves its slot free now.
    expect(placeBoost(slotsFreeAt(T0, 1, [b('old', 0, -30, -10)]), 10).startsAt).toEqual(T0);
  });

  it('planning again after a card is removed never makes a waiting card start later', () => {
    // 2 slots: a (0–30) and b (0–10) run; c waits for b (10–40), d for a (30–40).
    const running = [b('a', 0, 0, 30), b('b', 1, 0, 10)];
    const waiting = [
      { ...b('c', 1, 10, 40), minutes: 30 },
      { ...b('d', 0, 30, 40), minutes: 10 },
    ];
    const same = replanWaiting(T0, 2, running, waiting);
    expect(same.get('c')).toEqual({ slot: 1, startsAt: at(10), endsAt: at(40) });
    expect(same.get('d')).toEqual({ slot: 0, startsAt: at(30), endsAt: at(40) });
    // a's live ended now: a is cut, c and d move up.
    const cut = replanWaiting(T0, 2, [b('a', 0, 0, 0), running[1]!], waiting);
    expect(cut.get('c')).toEqual({ slot: 0, startsAt: T0, endsAt: at(30) });
    expect(cut.get('d')).toEqual({ slot: 1, startsAt: at(10), endsAt: at(20) });
    // c cancelled: d starts when b ends.
    const gone = replanWaiting(T0, 2, running, [waiting[1]!]);
    expect(gone.get('d')!.startsAt).toEqual(at(10));
  });
});
