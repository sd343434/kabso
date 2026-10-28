import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  catalogueVersion,
  compareGifts,
  GIFT_CATEGORIES,
  GIFT_CODE_PATTERN,
  GIFT_TAG_CODE_PATTERN,
  giftFieldProblems,
  giftQuipProblem,
  giftTagProblem,
} from './gift-catalogue.js';

const migration = readFileSync(
  new URL('../../../prisma/migrations/20261112100000_live_gifts/migration.sql', import.meta.url),
  'utf8',
);

const quipsEnumMigration = readFileSync(
  new URL('../../../prisma/migrations/20261204090000_quips_enums/migration.sql', import.meta.url),
  'utf8',
);
const quipsMigration = readFileSync(
  new URL('../../../prisma/migrations/20261204100000_quips/migration.sql', import.meta.url),
  'utf8',
);

const luckyMigration = readFileSync(
  new URL('../../../prisma/migrations/20261127090000_lucky_gifts_enums/migration.sql', import.meta.url),
  'utf8',
);
const tagMigration = readFileSync(
  new URL('../../../prisma/migrations/20261116090000_gift_tags/migration.sql', import.meta.url),
  'utf8',
);

const rose = {
  code: 'rose',
  category: 'POPULAR' as const,
  nameAr: 'وردة',
  nameEn: 'Rose',
  priceCoins: 1,
  assetKey: 'gift_rose',
  animationKey: null,
  sortOrder: 10,
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

describe('gift catalogue (CP-020)', () => {
  it('the migration seeds no gift (the owner supplies the art; an empty catalogue is valid)', () => {
    expect(migration).not.toMatch(/INSERT INTO "?gifts"?/i);
    expect(migration).not.toMatch(/INSERT INTO "?user_gift_stock"?/i);
  });

  it('the migration enums list the tabs and the code CHECK matches the API pattern', () => {
    expect(migration).toContain(`CREATE TYPE "gift_category" AS ENUM ('POPULAR', 'EVENT', 'FUN')`);
    // v1.27-live (D132): LUCKY is appended by its own migration (enum order = tab order).
    expect(luckyMigration).toContain(`ALTER TYPE "gift_category" ADD VALUE 'LUCKY';`);
    // v1.32-live (D154): QUIPS likewise, after LUCKY.
    expect(quipsEnumMigration).toContain(`ALTER TYPE "gift_category" ADD VALUE 'QUIPS';`);
    expect(GIFT_CATEGORIES).toEqual(['POPULAR', 'EVENT', 'FUN', 'LUCKY', 'QUIPS']);
    expect(migration).toContain(`CHECK (code ~ '${GIFT_CODE_PATTERN.source}')`);
  });

  it('checks the admin fields', () => {
    expect(giftFieldProblems(rose)).toEqual([]);
    expect(giftFieldProblems({})).toEqual([]);
    expect(giftFieldProblems({ priceCoins: 0 })).toHaveLength(1);
    expect(giftFieldProblems({ priceCoins: 1_000_001 })).toHaveLength(1);
    expect(giftFieldProblems({ priceCoins: 1.5 })).toHaveLength(1);
    expect(giftFieldProblems({ nameAr: '   ' })).toHaveLength(1);
    expect(giftFieldProblems({ nameEn: 'x'.repeat(61) })).toHaveLength(1);
    expect(giftFieldProblems({ assetKey: 'bad key' })).toHaveLength(1);
    expect(giftFieldProblems({ animationKey: null })).toEqual([]);
    expect(giftFieldProblems({ animationKey: 'fx/rose.svga' })).toEqual([]);
    expect(giftFieldProblems({ category: 'HATS' as never, badge: 'HOT' as never })).toHaveLength(2);
    expect(giftFieldProblems({ sortOrder: -1 })).toHaveLength(1);
  });

  it('checks the quip fields (v1.32-live, D154): a sound exactly for QUIPS, free only for QUIPS', () => {
    const quip = { category: 'QUIPS' as const, priceCoins: 99, soundKey: 'kabi/ghazal_01', soundMs: 4360 };
    expect(giftFieldProblems({ ...quip, quipText: 'إيه الجمال ده!' })).toEqual([]);
    expect(giftFieldProblems({ category: 'QUIPS', priceCoins: 0 })).toEqual([]);
    expect(giftFieldProblems({ priceCoins: -1, category: 'QUIPS' })).toHaveLength(1);
    expect(giftFieldProblems({ soundKey: 'bad key' })).toHaveLength(1);
    expect(giftFieldProblems({ soundMs: 199 })).toHaveLength(1);
    expect(giftFieldProblems({ soundMs: 15_001 })).toHaveLength(1);
    expect(giftFieldProblems({ quipText: '  ' })).toHaveLength(1);
    expect(giftQuipProblem({ ...quip, quipText: null })).toBeNull();
    expect(giftQuipProblem({ ...quip, priceCoins: 0, quipText: null })).toBeNull();
    expect(giftQuipProblem({ ...quip, soundMs: null })).not.toBeNull();
    expect(giftQuipProblem({ ...rose, soundKey: 'room/clap', soundMs: 2040 })).not.toBeNull();
    expect(giftQuipProblem({ ...rose, quipText: 'hi' })).not.toBeNull();
    expect(giftQuipProblem({ ...rose, priceCoins: 0 })).not.toBeNull();
    expect(giftQuipProblem(rose)).toBeNull();
  });

  it('the quips migration keeps the API rules (free only for QUIPS, sound fields only for QUIPS)', () => {
    expect(quipsMigration).toContain(`(price_coins = 0 AND category::text = 'QUIPS')`);
    expect(quipsMigration).toContain(`sound_ms BETWEEN 200 AND 15000`);
    expect(quipsMigration).toContain(`'^[A-Za-z0-9][A-Za-z0-9_./-]{0,79}$'`);
    expect(quipsMigration).toContain('"host_share_bps" SET NOT NULL');
  });

  it('checks the optional tag (v1.24.3-live): code shape, names 1–30, all three or none', () => {
    expect(
      giftFieldProblems({ tagCode: 'treasure_box', tagNameAr: 'صندوق', tagNameEn: 'Treasure Box' }),
    ).toEqual([]);
    expect(giftFieldProblems({ tagCode: null, tagNameAr: null, tagNameEn: null })).toEqual([]);
    expect(giftFieldProblems({ tagCode: 'Bad-Tag' })).toHaveLength(1);
    expect(giftFieldProblems({ tagNameAr: '  ' })).toHaveLength(1);
    expect(giftFieldProblems({ tagNameEn: 'x'.repeat(31) })).toHaveLength(1);
    expect(giftTagProblem(rose)).toBeNull();
    expect(giftTagProblem({ tagCode: 'glory', tagNameAr: 'مجد', tagNameEn: 'Glory' })).toBeNull();
    expect(giftTagProblem({ tagCode: 'glory', tagNameAr: null, tagNameEn: 'Glory' })).not.toBeNull();
    expect(giftTagProblem({ tagCode: null, tagNameAr: 'مجد', tagNameEn: null })).not.toBeNull();
  });

  it('the tag migration adds nullable columns and CHECKs matching the API rules', () => {
    expect(tagMigration).toContain('ADD COLUMN "tag_code" VARCHAR(40)');
    expect(tagMigration).toContain('ADD COLUMN "tag_name_ar" VARCHAR(30)');
    expect(tagMigration).toContain('ADD COLUMN "tag_name_en" VARCHAR(30)');
    // The columns are nullable with no default (the CHECKs below may say `IS NOT NULL`).
    const addColumns = /ALTER TABLE "gifts" ADD COLUMN[^;]*;/.exec(tagMigration)?.[0] ?? '';
    expect(addColumns).toContain('tag_name_en');
    expect(addColumns).not.toMatch(/NOT NULL|DEFAULT/);
    expect(tagMigration).not.toMatch(/UPDATE "gifts"|DROP /);
    expect(tagMigration).toContain(`CHECK (tag_code ~ '${GIFT_TAG_CODE_PATTERN.source}')`);
    expect(tagMigration).toContain('"gifts_tag_complete"');
  });

  it('orders by tab, then sort order, then code', () => {
    const list = [
      { ...rose, code: 'b', category: 'FUN' as const, sortOrder: 1 },
      { ...rose, code: 'c', category: 'POPULAR' as const, sortOrder: 2 },
      { ...rose, code: 'a', category: 'POPULAR' as const, sortOrder: 2 },
      { ...rose, code: 'd', category: 'EVENT' as const, sortOrder: 0 },
    ].sort(compareGifts);
    expect(list.map((g) => g.code)).toEqual(['a', 'c', 'd', 'b']);
  });

  it('versions the catalogue by content (any field, quantities, combo window), not by language', () => {
    const v = catalogueVersion([rose], [1, 10], 5);
    expect(v).toMatch(/^[0-9a-f]{16}$/);
    expect(catalogueVersion([rose], [1, 10], 5)).toBe(v);
    expect(catalogueVersion([{ ...rose, priceCoins: 2 }], [1, 10], 5)).not.toBe(v);
    expect(catalogueVersion([{ ...rose, nameAr: 'ورد' }], [1, 10], 5)).not.toBe(v);
    expect(catalogueVersion([rose], [1, 10, 66], 5)).not.toBe(v);
    expect(catalogueVersion([rose], [1, 10], 3)).not.toBe(v);
    expect(catalogueVersion([], [1, 10], 5)).not.toBe(v);
    const tagged = { ...rose, tagCode: 'glory', tagNameAr: 'مجد', tagNameEn: 'Glory' };
    expect(catalogueVersion([tagged], [1, 10], 5)).not.toBe(v);
    expect(catalogueVersion([{ ...tagged, tagNameEn: 'Glory!' }], [1, 10], 5)).not.toBe(
      catalogueVersion([tagged], [1, 10], 5),
    );
    // v1.26.2-live: hosted art moves the version; a gift without it keeps its old hash part.
    const key = `media/gifts/rose/${'a'.repeat(32)}`;
    expect(catalogueVersion([{ ...rose, imageObjectKey: `${key}.png` }], [1, 10], 5)).not.toBe(v);
    expect(catalogueVersion([{ ...rose, animationObjectKey: `${key}.svga` }], [1, 10], 5)).not.toBe(v);
    // v1.32-live: a quip's sound and text move it too.
    const quip = { ...rose, category: 'QUIPS' as const, soundKey: 'room/clap', soundMs: 2040 };
    expect(catalogueVersion([quip], [1, 10], 5)).not.toBe(v);
    expect(catalogueVersion([{ ...quip, quipText: 'x' }], [1, 10], 5)).not.toBe(
      catalogueVersion([quip], [1, 10], 5),
    );
  });
});
