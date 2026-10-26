import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { charmMedalsFor, liveHoursMedalsFor, MEDAL_CATALOGUE } from './medals.catalogue.js';

const migration = readFileSync(
  new URL('../../../prisma/migrations/20261110100000_families_cp_medals/migration.sql', import.meta.url),
  'utf8',
);

describe('medal catalogue (CP-018)', () => {
  it('matches the rows the migration seeds', () => {
    for (const m of MEDAL_CATALOGUE) {
      const row = `('${m.code}', '${m.nameAr}', '${m.nameEn}', '${m.descriptionAr}', '${m.descriptionEn}', '${m.iconKey}', ${String(m.sortOrder)})`;
      expect(migration).toContain(row);
    }
    expect(migration.match(/^ {2}\('/gm)?.length).toBe(MEDAL_CATALOGUE.length);
  });

  it('has unique codes and sort orders', () => {
    expect(new Set(MEDAL_CATALOGUE.map((m) => m.code)).size).toBe(MEDAL_CATALOGUE.length);
    expect(new Set(MEDAL_CATALOGUE.map((m) => m.sortOrder)).size).toBe(MEDAL_CATALOGUE.length);
  });

  it('gives charm and live-hours medals at their thresholds', () => {
    expect(charmMedalsFor(null)).toEqual([]);
    expect(charmMedalsFor(9)).toEqual([]);
    expect(charmMedalsFor(10)).toEqual(['CHARM_10']);
    expect(charmMedalsFor(100)).toEqual(['CHARM_10', 'CHARM_50', 'CHARM_100']);
    expect(liveHoursMedalsFor(9.99)).toEqual([]);
    expect(liveHoursMedalsFor(10)).toEqual(['LIVE_HOURS_10']);
    expect(liveHoursMedalsFor(150)).toEqual(['LIVE_HOURS_10', 'LIVE_HOURS_100']);
  });
});
