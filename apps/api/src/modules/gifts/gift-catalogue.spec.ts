import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  catalogueVersion,
  compareGifts,
  GIFT_CATEGORIES,
  GIFT_CODE_PATTERN,
  GIFT_TAG_CODE_PATTERN,
  giftFieldProblems,
  giftTagProblem,
} from './gift-catalogue.js';

const migration = readFileSync(
  new URL('../../../prisma/migrations/20261112100000_live_gifts/migration.sql', import.meta.url),
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
};

describe('gift catalogue (CP-020)', () => {
  it('the migration seeds no gift (the owner supplies the art; an empty catalogue is valid)', () => {
    expect(migration).not.toMatch(/INSERT INTO "?gifts"?/i);
    expect(migration).not.toMatch(/INSERT INTO "?user_gift_stock"?/i);
  });

  it('the migration enums list the tabs and the code CHECK matches the API pattern', () => {
    expect(migration).toContain(`CREATE TYPE "gift_category" AS ENUM ('POPULAR', 'EVENT', 'FUN')`);
    expect(GIFT_CATEGORIES).toEqual(['POPULAR', 'EVENT', 'FUN']);
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
  });
});
