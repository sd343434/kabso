import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { BAG_CATALOGUE, BAG_CATEGORIES, FREE_PROFILE_CARD } from './bag.catalogue.js';
import { equipBodySchema, bagQuerySchema } from './bag.schemas.js';

const migration = readFileSync(
  new URL('../../../prisma/migrations/20261111090000_bag/migration.sql', import.meta.url),
  'utf8',
);

describe('bag catalogue (CP-019)', () => {
  it('matches the rows the migration seeds', () => {
    for (const i of BAG_CATALOGUE) {
      const row = `('${i.code}', '${i.category}', '${i.nameAr}', '${i.nameEn}', '${i.assetKey}', ${String(i.sortOrder)}, ${String(i.free)})`;
      expect(migration).toContain(row);
    }
    expect(migration.match(/^ {2}\('/gm)?.length).toBe(BAG_CATALOGUE.length);
  });

  it('has the owner items, unique codes and sort orders, and one free profile card', () => {
    expect(BAG_CATALOGUE.map((i) => i.code)).toEqual([
      'bunny_royal',
      'kabi_royal',
      'golden_stags',
      'emerald_wings',
    ]);
    expect(new Set(BAG_CATALOGUE.map((i) => i.code)).size).toBe(BAG_CATALOGUE.length);
    expect(new Set(BAG_CATALOGUE.map((i) => i.sortOrder)).size).toBe(BAG_CATALOGUE.length);
    expect(BAG_CATALOGUE.filter((i) => i.free).map((i) => i.code)).toEqual([FREE_PROFILE_CARD]);
    for (const i of BAG_CATALOGUE) expect(BAG_CATEGORIES).toContain(i.category);
  });

  it('the migration enum lists every category', () => {
    for (const c of BAG_CATEGORIES)
      expect(migration).toMatch(new RegExp(`"bag_category" AS ENUM \\([^)]*'${c}'`));
  });
});

describe('bag request schemas (CP-019)', () => {
  it('reads an optional known category', () => {
    expect(bagQuerySchema.parse({})).toEqual({});
    expect(bagQuerySchema.parse({ category: 'PROFILE_CARD' })).toEqual({ category: 'PROFILE_CARD' });
    expect(bagQuerySchema.safeParse({ category: 'HATS' }).success).toBe(false);
    expect(bagQuerySchema.safeParse({ other: 'x' }).success).toBe(false);
  });

  it('equips a code or takes off with null; category and code are required', () => {
    expect(equipBodySchema.parse({ category: 'PROFILE_CARD', code: 'kabi_royal' })).toEqual({
      category: 'PROFILE_CARD',
      code: 'kabi_royal',
    });
    expect(equipBodySchema.parse({ category: 'PROFILE_CARD', code: null }).code).toBeNull();
    expect(equipBodySchema.safeParse({ category: 'PROFILE_CARD' }).success).toBe(false);
    expect(equipBodySchema.safeParse({ code: 'kabi_royal' }).success).toBe(false);
    expect(equipBodySchema.safeParse({ category: 'PROFILE_CARD', code: '' }).success).toBe(false);
    expect(equipBodySchema.safeParse({ category: 'PROFILE_CARD', code: 'x'.repeat(41) }).success).toBe(false);
    expect(equipBodySchema.safeParse({ category: 'PROFILE_CARD', code: null, extra: 1 }).success).toBe(false);
  });
});
