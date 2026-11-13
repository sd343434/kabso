import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import { cursorScope, LiveCursorCodec, type CursorPosition } from './live-cursor.js';
import { liveShareBpsOf } from './live-gifts.service.js';

/**
 * v1.82-live (D295, CONVENTIONS §10.108): the creator share (70 %, quips 60 %) and its configuration, and the
 * interleaved lists' cursor (both groups' positions and the last group).
 */
const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  // Generated per run: never commit a secret-like literal (gitleaks).
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'https://kabso.example/',
};

describe('D295 the creator share', () => {
  const config = loadConfig(base);
  it('defaults to the owner’s 70 % and quips 60 %; agency commission on creators on', () => {
    expect(config.gifts.creatorShareBps).toBe(7_000);
    expect(config.gifts.creatorQuipShareBps).toBe(6_000);
    expect(config.economy.creatorAgencyCommission).toBe(true);
  });
  it('a creator send takes 70 % (quips 60 %); any other send keeps the category share', () => {
    expect(liveShareBpsOf(config, 'POPULAR', true)).toBe(7_000);
    expect(liveShareBpsOf(config, 'EVENT', true)).toBe(7_000);
    expect(liveShareBpsOf(config, 'QUIPS', true)).toBe(6_000);
    expect(liveShareBpsOf(config, 'POPULAR', false)).toBe(6_500);
    expect(liveShareBpsOf(config, 'QUIPS', false)).toBe(5_000);
    // A category added in the panel: the creator rate in a creator's live, POPULAR's otherwise.
    expect(liveShareBpsOf(config, 'NEW_PANEL_CATEGORY', true)).toBe(7_000);
    expect(liveShareBpsOf(config, 'NEW_PANEL_CATEGORY', false)).toBe(6_500);
    // 1 000 000 coins × 70 % × 10 cherries = 7 000 000 cherries.
    expect((1_000_000n * BigInt(liveShareBpsOf(config, 'POPULAR', true)) * 10n) / 10_000n).toBe(7_000_000n);
  });
  it('is configurable and validated', () => {
    const c = loadConfig({
      ...base,
      GIFT_CREATOR_SHARE_PERCENT: '70.5',
      GIFT_CREATOR_QUIP_SHARE_PERCENT: '55',
      CREATOR_AGENCY_COMMISSION: 'false',
    });
    expect(c.gifts.creatorShareBps).toBe(7_050);
    expect(c.gifts.creatorQuipShareBps).toBe(5_500);
    expect(c.economy.creatorAgencyCommission).toBe(false);
    expect(() => loadConfig({ ...base, GIFT_CREATOR_SHARE_PERCENT: 'lots' })).toThrow(
      /GIFT_CREATOR_SHARE_PERCENT/,
    );
    expect(() => loadConfig({ ...base, CREATOR_AGENCY_COMMISSION: 'yes' })).toThrow(
      /CREATOR_AGENCY_COMMISSION/,
    );
  });
});

describe('D295 the interleaved lists’ cursor', () => {
  const codec = new LiveCursorCodec(randomBytes(48).toString('base64url'));
  const scope = cursorScope('new', undefined, 'guest');
  const H = '0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011';
  const C = '0192f1d0-2222-7aaa-8bbb-0c0d0e0f1012';
  const at = new Date('2027-03-29T09:00:00.000Z');
  it('carries both groups’ positions and the last group; null for a group not taken yet', () => {
    const position: CursorPosition = {
      score: 0,
      startedAt: at,
      id: C,
      merge: { host: { score: 5, startedAt: at, id: H }, creator: null, last: 'H' },
    };
    const decoded = codec.decode(codec.encode(scope, position), scope);
    expect(decoded?.merge).toEqual({ host: { score: 5, startedAt: at, id: H }, creator: null, last: 'H' });
  });
  it('an older cursor has no `merge` (the service continues both groups after its position on the interleaved lists)', () => {
    const decoded = codec.decode(codec.encode(scope, { score: 0, startedAt: at, id: H }), scope);
    expect(decoded).not.toBeNull();
    expect(decoded?.merge).toBeUndefined();
  });
});
