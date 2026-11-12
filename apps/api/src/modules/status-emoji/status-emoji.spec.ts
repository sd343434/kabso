import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import {
  allStatusEmojiIds,
  FREE_STATUS_PACKS,
  isStoreStatusPack,
  STATUS_EMOJI_ID_MAX,
  statusEmojiKind,
  statusPackOf,
  visibleStatusEmoji,
} from './status-emoji-catalogue.js';
import { setStatusEmojiBody, buyStatusPackBody } from './status-emoji.schemas.js';
import { statusPackExpiryAfter, statusPackRequestHash } from './status-emoji.service.js';

const DAY = 86_400_000;
const repo = (path: string) => fileURLToPath(new URL(`../../../../../${path}`, import.meta.url));

describe('D376 status emoji catalogue', () => {
  it('has the owner pack sizes: 142 Kabso + 24 «عام» free, 27 «المميزة»', () => {
    const { free, store } = allStatusEmojiIds();
    const kabso = Object.entries(FREE_STATUS_PACKS)
      .filter(([p]) => p !== 'noto')
      .reduce((n, [, ids]) => n + ids.length, 0);
    expect(kabso).toBe(142);
    expect(FREE_STATUS_PACKS.noto).toHaveLength(24);
    expect(free).toHaveLength(166);
    expect(store).toHaveLength(27);
    expect(new Set([...free, ...store]).size).toBe(193);
  });

  it('every id fits the database CHECK and the contract pattern', () => {
    const pattern = /^[a-z][a-z0-9]{0,23}\.[a-z0-9_]{1,39}$/;
    for (const id of [...allStatusEmojiIds().free, ...allStatusEmojiIds().store]) {
      expect(id, id).toMatch(pattern);
      expect(id.length).toBeLessThanOrEqual(STATUS_EMOJI_ID_MAX);
    }
  });

  it('mirrors the app: the Kabso packs of kabi_emoji.dart and the ids of status_catalogue.dart', () => {
    const emojiDart = readFileSync(repo('apps/mobile/lib/features/emoji/kabi_emoji.dart'), 'utf8');
    for (const [pack, ids] of Object.entries(FREE_STATUS_PACKS)) {
      if (pack === 'noto') continue;
      const block = new RegExp(`\\n  ${pack}\\('[a-z]+', \\[([^\\]]*)\\]`).exec(emojiDart);
      expect(block, pack).not.toBeNull();
      const appIds = [...block![1]!.matchAll(/'([a-z]+)'/g)].map((m) => m[1]);
      expect(appIds, pack).toEqual([...ids]);
    }
    const catalogue = readFileSync(repo('apps/mobile/lib/features/status/status_catalogue.dart'), 'utf8');
    const appStatusIds = [...catalogue.matchAll(/StatusEmojiSpec\(\s*'([a-z0-9_.]+)'/g)].map((m) => m[1]);
    const serverNonKabso = [...FREE_STATUS_PACKS.noto!.map((e) => `noto.${e}`), ...allStatusEmojiIds().store];
    expect(appStatusIds.sort()).toEqual(serverNonKabso.sort());
  });

  it('classifies ids and packs', () => {
    expect(statusEmojiKind('kabi.crown')).toBe('free');
    expect(statusEmojiKind('flags.jo')).toBe('free');
    expect(statusEmojiKind('noto.fire')).toBe('free');
    expect(statusEmojiKind('premium.eagle')).toBe('store');
    expect(statusEmojiKind('premium.parrot')).toBe('unknown');
    expect(statusEmojiKind('kabi.nope')).toBe('unknown');
    expect(statusEmojiKind('')).toBe('unknown');
    expect(statusPackOf('premium.eagle')).toBe('premium');
    expect(statusPackOf('nodot')).toBeNull();
    expect(statusPackOf('.x')).toBeNull();
    expect(isStoreStatusPack('premium')).toBe(true);
    expect(isStoreStatusPack('kabi')).toBe(false);
    expect(isStoreStatusPack('__proto__')).toBe(false);
  });

  it('shows a store emoji only while its pack is held; a free one always; unknown never', () => {
    const now = new Date('2027-05-05T10:00:00Z');
    const held = [{ packId: 'premium', expiresAt: new Date(now.getTime() + 1) }];
    const ended = [{ packId: 'premium', expiresAt: now }];
    expect(visibleStatusEmoji('kabi.crown', undefined, now)).toBe('kabi.crown');
    expect(visibleStatusEmoji('premium.owl', held, now)).toBe('premium.owl');
    expect(visibleStatusEmoji('premium.owl', ended, now)).toBeNull();
    expect(visibleStatusEmoji('premium.owl', undefined, now)).toBeNull();
    expect(
      visibleStatusEmoji('premium.owl', [{ packId: 'other', expiresAt: new Date(now.getTime() + DAY) }], now),
    ).toBeNull();
    expect(visibleStatusEmoji('gone.id', held, now)).toBeNull();
    expect(visibleStatusEmoji(null, held, now)).toBeNull();
  });
});

describe('D376 status pack purchase rules', () => {
  const now = new Date('2027-05-05T10:00:00Z');

  it('a renewal adds the days to what is left; after the end it counts from now', () => {
    expect(statusPackExpiryAfter(null, 30, now).getTime()).toBe(now.getTime() + 30 * DAY);
    const left20 = new Date(now.getTime() + 20 * DAY);
    expect(statusPackExpiryAfter(left20, 30, now).getTime()).toBe(now.getTime() + 50 * DAY);
    const past = new Date(now.getTime() - 5 * DAY);
    expect(statusPackExpiryAfter(past, 30, now).getTime()).toBe(now.getTime() + 30 * DAY);
    expect(statusPackExpiryAfter(now, 30, now).getTime()).toBe(now.getTime() + 30 * DAY);
  });

  it('the request hash depends on the pack, the days and the price', () => {
    const a = statusPackRequestHash('premium', { days: 30, price: 100000 });
    expect(a).toMatch(/^[0-9a-f]{64}$/);
    expect(statusPackRequestHash('premium', { days: 30, price: 100000 })).toBe(a);
    expect(statusPackRequestHash('premium', { days: 7, price: 100000 })).not.toBe(a);
    expect(statusPackRequestHash('premium', { days: 30, price: 1 })).not.toBe(a);
    expect(statusPackRequestHash('other', { days: 30, price: 100000 })).not.toBe(a);
  });

  it('validates the request bodies', () => {
    expect(setStatusEmojiBody.safeParse({ statusEmojiId: 'kabi.crown' }).success).toBe(true);
    expect(setStatusEmojiBody.safeParse({ statusEmojiId: null }).success).toBe(true);
    expect(setStatusEmojiBody.safeParse({}).success).toBe(false);
    expect(setStatusEmojiBody.safeParse({ statusEmojiId: '' }).success).toBe(false);
    expect(setStatusEmojiBody.safeParse({ statusEmojiId: 'x'.repeat(65) }).success).toBe(false);
    expect(setStatusEmojiBody.safeParse({ statusEmojiId: null, extra: 1 }).success).toBe(false);
    expect(buyStatusPackBody.safeParse({ days: 30, price: 100000 }).success).toBe(true);
    expect(buyStatusPackBody.safeParse({ days: 0, price: 100000 }).success).toBe(false);
    expect(buyStatusPackBody.safeParse({ days: 30, price: 0 }).success).toBe(false);
    expect(buyStatusPackBody.safeParse({ days: 30.5, price: 100000 }).success).toBe(false);
    expect(buyStatusPackBody.safeParse({ days: 30 }).success).toBe(false);
  });
});
