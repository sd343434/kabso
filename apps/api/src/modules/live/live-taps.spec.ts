import { describe, expect, it } from 'vitest';
import { acceptedTaps, MAX_TAPS_PER_ROOM, TAPS_PER_SECOND } from './live-taps.js';

const NOW = new Date('2026-10-23T12:00:00.000Z');
const ago = (ms: number) => new Date(NOW.getTime() - ms);

describe('CP-012 tap counting (CONVENTIONS §10.10)', () => {
  it('counts the first batch in a room up to 10', () => {
    expect(acceptedTaps({ count: 1, isHost: false, tapper: null, now: NOW })).toBe(1);
    expect(acceptedTaps({ count: 10, isHost: false, tapper: null, now: NOW })).toBe(10);
    expect(acceptedTaps({ count: 50, isHost: false, tapper: null, now: NOW })).toBe(TAPS_PER_SECOND);
  });

  it('adds at most floor(10 × seconds since the last counted batch), at most count', () => {
    const at = (ms: number, count = 50) =>
      acceptedTaps({ count, isHost: false, tapper: { counted: 10, lastBatchAt: ago(ms) }, now: NOW });
    expect(at(0)).toBe(0);
    expect(at(99)).toBe(0);
    expect(at(100)).toBe(1);
    expect(at(250)).toBe(2);
    expect(at(999)).toBe(9);
    expect(at(1000)).toBe(10);
    expect(at(1500)).toBe(15);
    expect(at(5000)).toBe(50);
    expect(at(60_000)).toBe(50); // never more than the batch
    expect(at(60_000, 7)).toBe(7);
    expect(at(2000, 3)).toBe(3);
  });

  it('treats a clock that went backwards as no time passed', () => {
    const later = new Date(NOW.getTime() + 5000);
    expect(
      acceptedTaps({ count: 5, isHost: false, tapper: { counted: 1, lastBatchAt: later }, now: NOW }),
    ).toBe(0);
  });

  it('never lets a caller pass 10 000 counted taps in a room', () => {
    const state = (counted: number) => ({ counted, lastBatchAt: ago(10_000) });
    expect(acceptedTaps({ count: 50, isHost: false, tapper: state(9_990), now: NOW })).toBe(10);
    expect(acceptedTaps({ count: 50, isHost: false, tapper: state(9_999), now: NOW })).toBe(1);
    expect(acceptedTaps({ count: 50, isHost: false, tapper: state(MAX_TAPS_PER_ROOM), now: NOW })).toBe(0);
  });

  it("counts the host's own taps as 0", () => {
    expect(acceptedTaps({ count: 10, isHost: true, tapper: null, now: NOW })).toBe(0);
    expect(
      acceptedTaps({ count: 10, isHost: true, tapper: { counted: 0, lastBatchAt: ago(9000) }, now: NOW }),
    ).toBe(0);
  });
});
