import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import { giftCherries } from '../economy/economy-math.js';
import { allRecipientsDirect, liveShareBpsOf } from './live-gifts.service.js';

/**
 * v1.106-social (D341, CONVENTIONS §10.140, owner): a normal gift whose recipients are all direct hosts / creators (no
 * agency) — a host's 70 %, a creator's (in a creator's live) 75 %; quips, lucky and custom keep their own rules.
 */
const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  // Generated per run: never commit a secret-like literal (gitleaks).
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'https://kabso.example/',
};
const cherries = (bps: number) => giftCherries(1_000_000n, bps, 10);

describe('D341 the direct share', () => {
  const config = loadConfig(base);

  it('defaults to the owner’s 70 % (direct host) and 75 % (direct creator)', () => {
    expect(config.gifts.directHostShareBps).toBe(7_000);
    expect(config.gifts.directCreatorShareBps).toBe(7_500);
  });

  it('1 000 000 coins: direct host 7 000 000, direct creator 7 500 000; in an agency 6 500 000 / 7 000 000', () => {
    expect(cherries(liveShareBpsOf(config, 'POPULAR', false, true))).toBe(7_000_000n);
    expect(cherries(liveShareBpsOf(config, 'POPULAR', true, true))).toBe(7_500_000n);
    expect(cherries(liveShareBpsOf(config, 'POPULAR', false, false))).toBe(6_500_000n);
    expect(cherries(liveShareBpsOf(config, 'POPULAR', true, false))).toBe(7_000_000n);
    // The fourth argument defaults to «not direct» (the D295 behaviour).
    expect(liveShareBpsOf(config, 'POPULAR', false)).toBe(6_500);
  });

  it('applies to every normal category (EVENT, FUN, one added in the panel), never to quips', () => {
    for (const c of ['EVENT', 'FUN', 'NEW_PANEL_CATEGORY']) {
      expect(liveShareBpsOf(config, c, false, true)).toBe(7_000);
      expect(liveShareBpsOf(config, c, true, true)).toBe(7_500);
    }
    expect(liveShareBpsOf(config, 'QUIPS', false, true)).toBe(5_000);
    expect(liveShareBpsOf(config, 'QUIPS', true, true)).toBe(6_000);
  });

  it('never pays a direct recipient less than the share it replaces', () => {
    const c = loadConfig({
      ...base,
      GIFT_HOST_SHARE_PERCENTS: 'POPULAR:65,EVENT:80,FUN:65,QUIPS:50',
      GIFT_CREATOR_SHARE_PERCENT: '78',
    });
    expect(liveShareBpsOf(c, 'EVENT', false, true)).toBe(8_000);
    expect(liveShareBpsOf(c, 'POPULAR', false, true)).toBe(7_000);
    expect(liveShareBpsOf(c, 'POPULAR', true, true)).toBe(7_800);
  });

  it('is configurable and validated (a percentage of 0–100, two decimals at most)', () => {
    const c = loadConfig({
      ...base,
      GIFT_DIRECT_HOST_SHARE_PERCENT: '72.5',
      GIFT_DIRECT_CREATOR_SHARE_PERCENT: '100',
    });
    expect(c.gifts.directHostShareBps).toBe(7_250);
    expect(c.gifts.directCreatorShareBps).toBe(10_000);
    for (const bad of ['lots', '-1', '101', '70.555', '']) {
      expect(() => loadConfig({ ...base, GIFT_DIRECT_HOST_SHARE_PERCENT: bad })).toThrow(
        /GIFT_DIRECT_HOST_SHARE_PERCENT/,
      );
      expect(() => loadConfig({ ...base, GIFT_DIRECT_CREATOR_SHARE_PERCENT: bad })).toThrow(
        /GIFT_DIRECT_CREATOR_SHARE_PERCENT/,
      );
    }
  });

  it('a send to nobody is never direct (no query)', async () => {
    const db = {
      $queryRaw: () => {
        throw new Error('not expected');
      },
    } as unknown as Parameters<typeof allRecipientsDirect>[0];
    expect(await allRecipientsDirect(db, [])).toBe(false);
  });

  it('is direct only when every distinct recipient is a direct host', async () => {
    const db = (direct: number) =>
      ({ $queryRaw: () => Promise.resolve([{ direct }]) }) as unknown as Parameters<
        typeof allRecipientsDirect
      >[0];
    const a = '0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011';
    const b = '0192f1d0-2222-7aaa-8bbb-0c0d0e0f1011';
    expect(await allRecipientsDirect(db(2), [a, b])).toBe(true);
    expect(await allRecipientsDirect(db(1), [a, b])).toBe(false);
    expect(await allRecipientsDirect(db(1), [a, a])).toBe(true);
  });
});
