import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  BAG_CATALOGUE,
  BAG_CATEGORIES,
  FREE_PROFILE_CARD,
  HOST_FRAME_CODES,
  isTransferable,
} from './bag.catalogue.js';
import { equipBodySchema, bagQuerySchema } from './bag.schemas.js';

const read = (name: string) =>
  readFileSync(new URL(`../../../prisma/migrations/${name}/migration.sql`, import.meta.url), 'utf8');
/** The bag (D107), the support tier frames (D169) and the active-host frames (D186) seed the catalogue. */
const migration = [
  read('20261111090000_bag'),
  read('20261215090000_support_frames_enums'),
  read('20261215100000_support_frames'),
  read('20270102100000_host_frames'),
].join('\n');

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
      ...Array.from({ length: 21 }, (_, i) => `support_frame_${String(i + 1).padStart(2, '0')}`),
      'host_frame_blue',
      'host_frame_pink',
    ]);
    expect(new Set(BAG_CATALOGUE.map((i) => i.code)).size).toBe(BAG_CATALOGUE.length);
    for (const c of BAG_CATEGORIES) {
      const inCategory = BAG_CATALOGUE.filter((i) => i.category === c);
      expect(new Set(inCategory.map((i) => i.sortOrder)).size).toBe(inCategory.length);
    }
    expect(BAG_CATALOGUE.filter((i) => i.free).map((i) => i.code)).toEqual([FREE_PROFILE_CARD]);
    for (const i of BAG_CATALOGUE) expect(BAG_CATEGORIES).toContain(i.category);
  });

  it('the migration enum lists every category', () => {
    for (const c of BAG_CATEGORIES)
      expect(migration).toMatch(
        new RegExp(`"bag_category" AS ENUM \\([^)]*'${c}'|ALTER TYPE "bag_category" ADD VALUE '${c}'`),
      );
  });
});

describe('active-host frames (D186)', () => {
  it('are avatar frames named by style, and HOST_ACTIVE items are never transferable', () => {
    expect(HOST_FRAME_CODES).toEqual({ BLUE: 'host_frame_blue', PINK: 'host_frame_pink' });
    for (const code of Object.values(HOST_FRAME_CODES)) {
      const item = BAG_CATALOGUE.find((i) => i.code === code)!;
      expect(item).toMatchObject({ category: 'AVATAR_FRAME', assetKey: code, free: false });
    }
    expect(isTransferable(false, 'HOST_ACTIVE')).toBe(false);
    expect(isTransferable(false, 'LEVEL_REWARD')).toBe(false);
    expect(isTransferable(false, 'GIFT')).toBe(true);
  });
});

describe('bag request schemas (CP-019)', () => {
  it('reads an optional known category', () => {
    expect(bagQuerySchema.parse({})).toEqual({});
    expect(bagQuerySchema.parse({ category: 'PROFILE_CARD' })).toEqual({ category: 'PROFILE_CARD' });
    expect(bagQuerySchema.parse({ category: 'AVATAR_FRAME' })).toEqual({ category: 'AVATAR_FRAME' });
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
