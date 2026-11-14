import { randomInt } from 'node:crypto';
import type { LuckyRng } from './lucky-odds.js';

/**
 * v1.27-live (D132): the source of lucky draws. Production uses {@link CRYPTO_LUCKY_RNG} (the
 * operating system's CSPRNG through `crypto.randomInt`, never `Math.random`). There is no setting,
 * header or route that replaces it: only a test module can override the provider (e2e specs inject
 * a scripted sequence), so nothing reachable in production can choose an outcome.
 */
export const LUCKY_RNG = Symbol('LUCKY_RNG');

export const CRYPTO_LUCKY_RNG: LuckyRng = Object.freeze({
  int(maxExclusive: number): number {
    return randomInt(0, maxExclusive);
  },
});
