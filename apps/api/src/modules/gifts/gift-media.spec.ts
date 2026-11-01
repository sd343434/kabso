import { readFileSync } from 'node:fs';
import sharp from 'sharp';
import { describe, expect, it } from 'vitest';
import { mp3 } from '../../../test/helpers/mp3.js';
import { mp4 } from '../../../test/helpers/mp4.js';
import {
  GIFT_ANIMATION_OBJECT_KEY_PATTERN,
  GIFT_AUDIO_OBJECT_KEY_PATTERN,
  GiftArtError,
  giftAudioFile,
  giftCategoryIconFile,
  giftVideoFile,
  panelGiftImageFile,
} from './gift-art.js';
import { giftMediaProblem, GIFT_CATEGORY_CODE_PATTERN } from './gift-catalogue.js';
import { GIFT_CATEGORY_ICON_KEY_PATTERN, giftCategoryFieldProblems } from './gift-categories.js';

const migration = readFileSync(
  new URL('../../../prisma/migrations/20270127090000_gift_categories/migration.sql', import.meta.url),
  'utf8',
);

const png = (w: number, h: number) =>
  sharp({ create: { width: w, height: h, channels: 4, background: { r: 20, g: 140, b: 90, alpha: 1 } } })
    .png()
    .toBuffer();

describe('gift media from the panel (v1.46-live, D207)', () => {
  it('«صورة الهدية»: a square PNG / WebP, ≥ 128 px, ≤ 512 KB', async () => {
    const ok = await panelGiftImageFile('rose', await png(256, 256));
    expect(ok).toMatchObject({ contentType: 'image/png', width: 256, height: 256 });
    expect(ok.key).toMatch(/^media\/gifts\/rose\/[0-9a-f]{32}\.png$/);
    await expect(panelGiftImageFile('rose', await png(100, 100))).rejects.toThrow('128');
    await expect(panelGiftImageFile('rose', await png(256, 200))).rejects.toThrow('square');
    await expect(panelGiftImageFile('rose', Buffer.alloc(512 * 1024 + 1, 1))).rejects.toThrow('512 KB');
    const jpeg = await sharp(await png(256, 256))
      .jpeg()
      .toBuffer();
    await expect(panelGiftImageFile('rose', jpeg)).rejects.toThrow('PNG or WebP');
  });

  it('a category icon: square, 32 … 512 px, under media/gift-categories/<CODE>/', async () => {
    const icon = await giftCategoryIconFile('SPORTS', await png(64, 64));
    expect(icon.key).toMatch(GIFT_CATEGORY_ICON_KEY_PATTERN);
    await expect(giftCategoryIconFile('SPORTS', await png(16, 16))).rejects.toThrow(GiftArtError);
    await expect(giftCategoryIconFile('SPORTS', await png(600, 600))).rejects.toThrow('512');
  });

  it('an MP4 effect of each kind: a plain video (NONE) and a side-by-side alpha one (width ≈ 2 × height)', async () => {
    const plain = await giftVideoFile('rose', mp4({ durationMs: 4000, width: 720, height: 1280 }));
    expect(plain).toMatchObject({
      width: 720,
      height: 1280,
      durationMs: 4000,
      codec: 'avc1',
      detectedAlpha: 'NONE',
    });
    expect(plain.key).toMatch(GIFT_ANIMATION_OBJECT_KEY_PATTERN);
    expect(plain.key).toMatch(/\.mp4$/);
    expect(plain.contentType).toBe('video/mp4');
    const sbs = await giftVideoFile('rose', mp4({ durationMs: 3000, width: 1440, height: 720 }));
    expect(sbs.detectedAlpha).toBe('SIDE_BY_SIDE');
    // A landscape plain video (16:9 < 1.8) stays NONE.
    expect(
      (await giftVideoFile('rose', mp4({ durationMs: 3000, width: 1280, height: 720 }))).detectedAlpha,
    ).toBe('NONE');
  });

  it('refuses an MP4 that is not H.264, too long, too large, QuickTime or not a video', async () => {
    await expect(giftVideoFile('g', mp4({ durationMs: 3000, codec: 'hvc1' }))).rejects.toThrow('H.264');
    await expect(giftVideoFile('g', mp4({ durationMs: 3000, codec: 'mp4v' }))).rejects.toThrow('H.264');
    await expect(giftVideoFile('g', mp4({ durationMs: 16_000 }))).rejects.toThrow('15');
    // 15.4 s (encoder padding) is accepted and reported as 15 s.
    expect((await giftVideoFile('g', mp4({ durationMs: 15_400 }))).durationMs).toBe(15_000);
    await expect(giftVideoFile('g', mp4({ durationMs: 3000, dataBytes: 8 * 1024 * 1024 }))).rejects.toThrow(
      '8 MB',
    );
    await expect(giftVideoFile('g', mp4({ durationMs: 3000, brand: 'qt  ' }))).rejects.toThrow('MP4');
    await expect(giftVideoFile('g', mp4({ durationMs: 3000, noVideo: true }))).rejects.toThrow('MP4');
    await expect(giftVideoFile('g', Buffer.from('not a video at all'))).rejects.toThrow(GiftArtError);
  });

  it('an MP3 sound: frames to the end (ID3 allowed), 100 ms … 15 s, ≤ 1 MB', () => {
    const sound = giftAudioFile('rose', mp3({ durationMs: 2000, id3Bytes: 300 }));
    expect(sound.durationMs).toBeGreaterThan(1950);
    expect(sound.durationMs).toBeLessThan(2050);
    expect(sound.key).toMatch(GIFT_AUDIO_OBJECT_KEY_PATTERN);
    expect(sound.contentType).toBe('audio/mpeg');
    // An ID3v1 tag (128 bytes) after the frames is fine; a lot of other data is not.
    expect(() => giftAudioFile('g', mp3({ durationMs: 1000, trailingBytes: 128 }))).not.toThrow();
    expect(() => giftAudioFile('g', mp3({ durationMs: 1000, trailingBytes: 20_000 }))).toThrow('clean MP3');
    expect(() => giftAudioFile('g', mp3({ durationMs: 16_000 }))).toThrow('15 s');
    expect(() => giftAudioFile('g', Buffer.alloc(1024 * 1024 + 1, 0xff))).toThrow('1 MB');
    expect(() => giftAudioFile('g', Buffer.from('ID3 but not really an mp3 file'))).toThrow('MP3');
    expect(() => giftAudioFile('g', Buffer.alloc(0))).toThrow('empty');
  });

  it('the effect format goes with the key, the transparency with an MP4, the sound never on QUIPS', () => {
    const key = `media/gifts/rose/${'a'.repeat(32)}`;
    expect(giftMediaProblem({ category: 'POPULAR' })).toBeNull();
    expect(
      giftMediaProblem({
        category: 'POPULAR',
        animationObjectKey: `${key}.mp4`,
        animationFormat: 'MP4',
        animationAlpha: 'NONE',
      }),
    ).toBeNull();
    expect(
      giftMediaProblem({
        category: 'POPULAR',
        animationObjectKey: `${key}.mp4`,
        animationFormat: 'MP4',
        animationAlpha: null,
      }),
    ).toMatch('transparency');
    expect(
      giftMediaProblem({
        category: 'POPULAR',
        animationObjectKey: `${key}.svga`,
        animationFormat: 'SVGA',
        animationAlpha: 'NONE',
      }),
    ).toMatch('transparency');
    expect(
      giftMediaProblem({
        category: 'POPULAR',
        animationObjectKey: `${key}.svga`,
        animationFormat: 'MP4',
        animationAlpha: 'NONE',
      }),
    ).toMatch('not an MP4');
    const sound = { audioObjectKey: `${key}.mp3`, audioBytes: 100, audioMs: 1000 };
    expect(giftMediaProblem({ category: 'FUN', ...sound })).toBeNull();
    expect(giftMediaProblem({ category: 'QUIPS', ...sound })).toMatch('QUIPS');
    expect(giftMediaProblem({ category: 'FUN', ...sound, audioMs: null })).toMatch('size and length');
  });

  it('category fields and codes', () => {
    expect(GIFT_CATEGORY_CODE_PATTERN.test('SPORTS_2')).toBe(true);
    expect(GIFT_CATEGORY_CODE_PATTERN.test('sports')).toBe(false);
    expect(GIFT_CATEGORY_CODE_PATTERN.test('2SPORTS')).toBe(false);
    expect(
      giftCategoryFieldProblems({ code: 'SPORTS', nameAr: 'رياضة', nameEn: 'Sports', sortOrder: 60 }),
    ).toEqual([]);
    expect(giftCategoryFieldProblems({ nameAr: ' ', nameEn: 'x'.repeat(31), sortOrder: -1 })).toHaveLength(3);
    expect(giftCategoryFieldProblems({ iconObjectKey: 'media/gifts/rose/x.png' })).toHaveLength(1);
  });

  it('the migration seeds the five tabs with the app names and keeps the special kinds unique', () => {
    for (const row of [
      `('POPULAR', 'NORMAL', 'شائعة', 'Popular', 10)`,
      `('EVENT', 'NORMAL', 'مناسبات', 'Events', 20)`,
      `('FUN', 'NORMAL', 'مرح', 'Fun', 30)`,
      `('LUCKY', 'LUCKY', 'الحظ', 'Lucky', 40)`,
      `('QUIPS', 'QUIPS', 'إفيهات', 'Quips', 50)`,
    ]) {
      expect(migration).toContain(row);
    }
    expect(migration).toContain(`CHECK (code ~ '${GIFT_CATEGORY_CODE_PATTERN.source}')`);
    expect(migration).toContain(`CHECK (kind = 'NORMAL' OR code = kind::text)`);
    expect(migration).toContain(`ON "gift_categories" ("kind") WHERE "kind" <> 'NORMAL'`);
    expect(migration).toContain('ON DELETE RESTRICT ON UPDATE RESTRICT');
    expect(migration).toContain(
      `UPDATE "gifts" SET "animation_format" = 'SVGA' WHERE "animation_object_key" IS NOT NULL`,
    );
  });
});
