import { describe, expect, it } from 'vitest';
import { envSchema } from '../../config/env.schema.js';
import { boostOptions, placeBoost, replanWaiting, slotsFreeAt, type PlannedBoost } from './live-boosts.js';

const T0 = new Date('2026-10-28T12:00:00.000Z');
const at = (min: number) => new Date(T0.getTime() + min * 60_000);
const b = (id: string, slot: number, from: number, to: number): PlannedBoost => ({
  id,
  slot,
  startsAt: at(from),
  endsAt: at(to),
});

describe('traffic cards (v1.33-live, D154b)', () => {
  it("the owner's prices save 10 / 17 / 25 % against the 10-minute card", () => {
    const prices = envSchema.shape.LIVE_BOOST_PRICES.parse(undefined);
    expect(prices).toEqual([
      { minutes: 10, coins: 10_000 },
      { minutes: 20, coins: 18_000 },
      { minutes: 30, coins: 25_000 },
      { minutes: 60, coins: 45_000 },
    ]);
    expect(boostOptions(prices)).toEqual([
      { minutes: 10, priceCoins: 10_000, savePercent: 0 },
      { minutes: 20, priceCoins: 18_000, savePercent: 10 },
      { minutes: 30, priceCoins: 25_000, savePercent: 17 },
      { minutes: 60, priceCoins: 45_000, savePercent: 25 },
    ]);
    expect(envSchema.shape.LIVE_BOOST_PRICES.parse(' 60:1, 5:2 ')).toEqual([
      { minutes: 5, coins: 2 },
      { minutes: 60, coins: 1 },
    ]);
    for (const bad of ['10:0', '0:5', '10:5,10:6', 'ten:5', '1441:5', '']) {
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
