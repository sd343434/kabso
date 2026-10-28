import { describe, expect, it } from 'vitest';
import { giftFieldProblems, giftQuipProblem, giftTagProblem } from './gift-catalogue.js';
import { QUIP_GAP_MS, QUIP_PACK, QUIP_PRICES, quipSlot } from './quips.js';

describe('quips (v1.32-live, D154)', () => {
  it("the pack is the owner's 8 free sounds and 27 Kabi lines at the owner's prices", () => {
    expect(QUIP_PACK).toHaveLength(35);
    const by = (tag: string) => QUIP_PACK.filter((q) => q.tagCode === tag);
    expect(by('free')).toHaveLength(8);
    expect(by('ghazal')).toHaveLength(10);
    expect(by('funny')).toHaveLength(8);
    expect(by('tease')).toHaveLength(9);
    expect(QUIP_PRICES).toEqual({ free: 0, ghazal: 99, funny: 199, tease: 299 });
    for (const q of QUIP_PACK) {
      expect(q.priceCoins).toBe(QUIP_PRICES[q.tagCode as keyof typeof QUIP_PRICES]);
      expect(q.category).toBe('QUIPS');
      expect(giftFieldProblems(q)).toEqual([]);
      expect(giftQuipProblem(q)).toBeNull();
      expect(giftTagProblem(q)).toBeNull();
      // Every paid line has its words; the free sounds have none.
      expect(q.quipText === null).toBe(q.priceCoins === 0);
    }
    expect(new Set(QUIP_PACK.map((q) => q.code)).size).toBe(35);
    // D154 5f: tease_02's text as the owner confirmed it.
    expect(QUIP_PACK.find((q) => q.code === 'quip_tease_02')?.quipText).toBe(
      'إنت لو التركيز فلوس، كنت استلفت مننا.',
    );
    expect(QUIP_PACK.find((q) => q.code === 'quip_ghazal_10')?.soundKey).toBe('kabi/ghazal_10');
    expect(QUIP_PACK.find((q) => q.code === 'quip_clap')?.soundKey).toBe('room/clap');
  });

  it("a quip starts when the room's queue is free and keeps it busy for its length plus the gap", () => {
    const now = new Date('2026-10-28T12:00:00.000Z');
    const free = quipSlot(now, null, 4000, 60_000)!;
    expect(free.delayMs).toBe(0);
    expect(free.startsAt).toEqual(now);
    expect(free.busyUntil.getTime()).toBe(now.getTime() + 4000 + QUIP_GAP_MS);
    // A queue that freed in the past counts as free.
    expect(quipSlot(now, new Date(now.getTime() - 5000), 1000, 60_000)!.delayMs).toBe(0);
    // Behind one that is playing.
    const next = quipSlot(now, free.busyUntil, 2000, 60_000)!;
    expect(next.delayMs).toBe(4000 + QUIP_GAP_MS);
    expect(next.busyUntil.getTime()).toBe(free.busyUntil.getTime() + 2000 + QUIP_GAP_MS);
    // Exactly at the limit is accepted; past it the queue is full.
    expect(quipSlot(now, new Date(now.getTime() + 60_000), 1000, 60_000)?.delayMs).toBe(60_000);
    expect(quipSlot(now, new Date(now.getTime() + 60_001), 1000, 60_000)).toBeNull();
  });
});
