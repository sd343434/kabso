import { readFileSync } from 'node:fs';
import { deflateSync } from 'node:zlib';
import { describe, expect, it } from 'vitest';
import { mp4 } from '../../../test/helpers/mp4.js';
import { giftAnimationFile, giftVideoFile, svgaMovieInfo } from './gift-art.js';
import { catalogueVersion } from './gift-catalogue.js';
import {
  activeItemBadges,
  adminItemBadges,
  applyLegacyGiftBadge,
  applyLegacyIsNew,
  badgeColumns,
  badgeSettingsOf,
  ITEM_BADGE_PRIORITY,
  legacyGiftBadge,
  looksFullscreen,
  resolveItemBadges,
} from './item-badges.js';
import { storeAnimationFile } from '../store/store-art.js';

const NOW = new Date('2027-03-23T09:00:00.000Z');
const DAY = 86_400_000;
const at = (days: number) => new Date(NOW.getTime() + days * DAY);

/** A protobuf varint. */
const v = (n: number) => {
  const out: number[] = [];
  do {
    out.push((n & 0x7f) | (n > 0x7f ? 0x80 : 0));
    n = Math.floor(n / 128);
  } while (n > 0);
  return Buffer.from(out);
};
const field = (n: number, payload: Buffer) => Buffer.concat([v(n * 8 + 2), v(payload.length), payload]);
const float = (n: number, value: number) => {
  const b = Buffer.alloc(4);
  b.writeFloatLE(value);
  return Buffer.concat([v(n * 8 + 5), b]);
};
/** zlib(MovieEntity { version, params { viewBox w × h }, audios? }). */
const svga = (w: number, h: number, audio: boolean) =>
  deflateSync(
    Buffer.concat([
      field(1, Buffer.from('2.0.0')),
      field(2, Buffer.concat([float(1, w), float(2, h)])),
      ...(audio ? [field(5, field(1, Buffer.from('sound_1')))] : []),
    ]),
  );

describe('item badges (v1.79-live, D289, §10.102)', () => {
  it('has nine badges in the documented display priority', () => {
    expect(ITEM_BADGE_PRIORITY).toEqual([
      'LIMITED',
      'NEW',
      'SEASONAL',
      'EXCLUSIVE',
      'MOST_WANTED',
      'FEATURED',
      'FULLSCREEN',
      'SOUND',
      'NO_SOUND',
    ]);
  });

  it('refuses the two sound badges together and repeated badges', () => {
    expect(resolveItemBadges([{ code: 'SOUND' }, { code: 'NO_SOUND' }], NOW).problems).toEqual([
      { field: 'badges', issue: 'sound_exclusive' },
    ]);
    expect(resolveItemBadges([{ code: 'FEATURED' }, { code: 'FEATURED' }], NOW).problems).toEqual([
      { field: 'badges', issue: 'duplicate_value' },
    ]);
    expect(resolveItemBadges([{ code: 'SOUND' }], NOW).problems).toEqual([]);
    expect(resolveItemBadges([{ code: 'NO_SOUND' }], NOW).problems).toEqual([]);
  });

  it('gives «جديد» 14 days by default or the owner date; LIMITED and SEASONAL need a date', () => {
    const r = resolveItemBadges(
      [
        { code: 'SOUND' },
        { code: 'NEW' },
        { code: 'LIMITED', until: at(3).toISOString() },
        { code: 'SEASONAL', until: at(40).toISOString() },
      ],
      NOW,
    );
    expect(r.problems).toEqual([]);
    expect(r.settings).toEqual([
      { code: 'LIMITED', until: at(3) },
      { code: 'NEW', until: at(14) },
      { code: 'SEASONAL', until: at(40) },
      { code: 'SOUND', until: null },
    ]);
    expect(resolveItemBadges([{ code: 'NEW', until: at(5).toISOString() }], NOW).settings).toEqual([
      { code: 'NEW', until: at(5) },
    ]);
    expect(resolveItemBadges([{ code: 'LIMITED' }, { code: 'SEASONAL', until: null }], NOW).problems).toEqual(
      [
        { field: 'badges[0].until', issue: 'until_required' },
        { field: 'badges[1].until', issue: 'until_required' },
      ],
    );
  });

  it('refuses an end on an untimed badge, a past end and one more than a year ahead', () => {
    expect(
      resolveItemBadges(
        [
          { code: 'EXCLUSIVE', until: at(3).toISOString() },
          { code: 'LIMITED', until: NOW.toISOString() },
          { code: 'SEASONAL', until: at(367).toISOString() },
        ],
        NOW,
      ).problems,
    ).toEqual([
      { field: 'badges[0].until', issue: 'until_not_allowed' },
      { field: 'badges[1].until', issue: 'until_past' },
      { field: 'badges[2].until', issue: 'until_too_far' },
    ]);
  });

  it('shows a timed badge until its end only; the stored set stays for the panel', () => {
    const row = badgeColumns([
      { code: 'NEW', until: at(14) },
      { code: 'LIMITED', until: at(2) },
      { code: 'MOST_WANTED', until: null },
    ]);
    expect(row.badges).toEqual(['LIMITED', 'NEW', 'MOST_WANTED']);
    expect(activeItemBadges(row, NOW).map((b) => b.code)).toEqual(['LIMITED', 'NEW', 'MOST_WANTED']);
    expect(activeItemBadges(row, at(2)).map((b) => b.code)).toEqual(['NEW', 'MOST_WANTED']);
    expect(activeItemBadges(row, at(15)).map((b) => b.code)).toEqual(['MOST_WANTED']);
    expect(adminItemBadges(row, at(15))).toEqual([
      { code: 'LIMITED', until: at(2).toISOString(), active: false },
      { code: 'NEW', until: at(14).toISOString(), active: false },
      { code: 'MOST_WANTED', until: null, active: true },
    ]);
    // A «موسمي» migrated from EVENT (no end) shows until the owner sets one.
    expect(activeItemBadges(badgeColumns([{ code: 'SEASONAL', until: null }]), at(999))).toEqual([
      { code: 'SEASONAL', until: null },
    ]);
  });

  it('keeps the deprecated single values in step', () => {
    expect(legacyGiftBadge(['SOUND', 'NEW', 'SEASONAL'])).toBe('NEW');
    expect(legacyGiftBadge(['SEASONAL'])).toBe('EVENT');
    expect(legacyGiftBadge(['FEATURED'])).toBe('NONE');
    const current = [
      { code: 'SOUND' as const, until: null },
      { code: 'SEASONAL' as const, until: at(9) },
    ];
    expect(applyLegacyGiftBadge(current, 'NEW', NOW)).toEqual([
      { code: 'NEW', until: at(14) },
      { code: 'SOUND', until: null },
    ]);
    expect(applyLegacyGiftBadge(current, 'EVENT', NOW)).toEqual(current.slice().reverse());
    expect(applyLegacyGiftBadge(current, 'NONE', NOW)).toEqual([{ code: 'SOUND', until: null }]);
    expect(applyLegacyIsNew([{ code: 'NEW', until: at(3) }], true, NOW)).toEqual([
      { code: 'NEW', until: at(3) },
    ]);
    expect(applyLegacyIsNew([{ code: 'NEW', until: at(3) }], false, NOW)).toEqual([]);
    expect(badgeSettingsOf(badgeColumns(current))).toEqual([
      { code: 'SEASONAL', until: at(9) },
      { code: 'SOUND', until: null },
    ]);
  });

  it('changes the catalogue version when a badge ends, and not for a gift without badges', () => {
    const gift = {
      code: 'rose',
      category: 'POPULAR',
      nameAr: 'وردة',
      nameEn: 'Rose',
      priceCoins: 1,
      assetKey: 'gift_rose',
      animationKey: null,
      sortOrder: 1,
      badge: 'NONE' as const,
      tagCode: null,
      tagNameAr: null,
      tagNameEn: null,
      imageObjectKey: null,
      animationObjectKey: null,
      soundKey: null,
      soundMs: null,
      quipText: null,
    };
    const plain = catalogueVersion([gift], [1], 5, undefined, NOW);
    expect(catalogueVersion([{ ...gift, ...badgeColumns([]) }], [1], 5, undefined, NOW)).toBe(plain);
    const timed = { ...gift, ...badgeColumns([{ code: 'NEW', until: at(14) }]) };
    const before = catalogueVersion([timed], [1], 5, undefined, NOW);
    expect(before).not.toBe(plain);
    expect(catalogueVersion([timed], [1], 5, undefined, at(13))).toBe(before);
    expect(catalogueVersion([timed], [1], 5, undefined, at(14))).toBe(plain);
  });
});

describe('badge detection from the uploaded files (v1.79-live, D289)', () => {
  it('reads an MP4 sound track and a portrait full-screen frame', async () => {
    const loud = await giftVideoFile('fx', mp4({ durationMs: 3000, width: 720, height: 1280 }));
    expect(loud).toMatchObject({ hasAudio: true, width: 720, height: 1280 });
    const quiet = await giftVideoFile('fx', mp4({ durationMs: 3000, width: 720, height: 720, sound: false }));
    expect(quiet.hasAudio).toBe(false);
    expect(looksFullscreen(720, 1280)).toBe(true);
    expect(looksFullscreen(720, 720)).toBe(false);
    expect(looksFullscreen(null, 1280)).toBe(false);
    // A side-by-side file is twice as wide as its picture.
    const sbs = await storeAnimationFile(mp4({ durationMs: 3000, width: 2560, height: 1280, sound: false }));
    expect(sbs).toMatchObject({ width: 1280, hasAudio: false, fullscreen: false });
    const squarish = await storeAnimationFile(mp4({ durationMs: 3000, width: 1500, height: 1600 }));
    expect(squarish).toMatchObject({ width: 1500, hasAudio: true, fullscreen: false });
    const portrait = await storeAnimationFile(mp4({ durationMs: 3000, width: 1440, height: 2560 }));
    expect(portrait).toMatchObject({ width: 1440, fullscreen: true });
  });

  it("reads an SVGA's viewBox and its audios", async () => {
    expect(giftAnimationFile('fx', svga(750, 1334, true))).toMatchObject({
      width: 750,
      height: 1334,
      hasAudio: true,
    });
    expect(giftAnimationFile('fx', svga(400, 400, false))).toMatchObject({
      width: 400,
      height: 400,
      hasAudio: false,
    });
    expect(await storeAnimationFile(svga(750, 1334, false))).toMatchObject({
      hasAudio: false,
      fullscreen: true,
    });
    // A movie with only a version: unknown frame, silent.
    expect(svgaMovieInfo(Buffer.concat([field(1, Buffer.from('2.0.0'))]))).toEqual({
      width: null,
      height: null,
      hasAudio: false,
    });
  });

  it('the migration maps NEW to 14 days, EVENT to «موسمي» and adds the CHECKs', () => {
    const sql = readFileSync(
      new URL('../../../prisma/migrations/20270323090000_item_badges/migration.sql', import.meta.url),
      'utf8',
    );
    expect(sql).toContain(`"badge_new_until" = now() + interval '14 days'`);
    expect(sql).toContain(`SET "badges" = ARRAY['SEASONAL']::"item_badge"[] WHERE "badge" = 'EVENT'`);
    for (const check of ['gifts_badges_sound', 'store_items_badges_sound', 'gifts_badge_limited_until']) {
      expect(sql).toContain(check);
    }
  });
});
