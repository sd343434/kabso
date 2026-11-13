import { describe, expect, it } from 'vitest';
import { pickStaffFor } from './live-staff-assignment.service.js';
import { limitedRoleOf } from './live-staff.js';
import { isTeamAvatarUrl, teamAvatarPng, teamAvatarUrl } from './staff-avatar.js';
import {
  STAFF_REGION_CODES,
  STAFF_REGIONS,
  countriesOfRegions,
  regionOfCountry,
  sortRegions,
  staffRegionCatalog,
  type StaffRegion,
} from './staff-regions.js';

describe('D283 staff regions', () => {
  it('13 regions; every country in at most one; ISO alpha-2 upper case', () => {
    expect(STAFF_REGION_CODES).toHaveLength(13);
    const all = STAFF_REGION_CODES.flatMap((r) => [...STAFF_REGIONS[r]]);
    expect(new Set(all).size).toBe(all.length);
    for (const c of all) expect(c).toMatch(/^[A-Z]{2}$/);
  });

  it('the Arab World is the 22 Arab League members', () => {
    expect(STAFF_REGIONS.ARAB_WORLD).toHaveLength(22);
    for (const c of ['SA', 'EG', 'IQ', 'MA', 'PS', 'KM', 'DJ', 'SO', 'MR']) {
      expect(regionOfCountry(c)).toBe('ARAB_WORLD');
    }
  });

  it('maps countries (any case) to regions; unknown or none → null', () => {
    expect(regionOfCountry('cn')).toBe('GREATER_CHINA');
    expect(regionOfCountry('TW')).toBe('GREATER_CHINA');
    expect(regionOfCountry('TR')).toBe('TURKEY');
    expect(regionOfCountry('IR')).toBe('IRAN');
    expect(regionOfCountry('PK')).toBe('SOUTH_ASIA');
    expect(regionOfCountry('ID')).toBe('SOUTHEAST_ASIA');
    expect(regionOfCountry('JP')).toBe('EAST_ASIA');
    expect(regionOfCountry('DE')).toBe('EUROPE');
    expect(regionOfCountry('US')).toBe('NORTH_AMERICA');
    expect(regionOfCountry('MX')).toBe('LATIN_AMERICA');
    expect(regionOfCountry('NG')).toBe('SUB_SAHARAN_AFRICA');
    expect(regionOfCountry('RU')).toBe('RUSSIA_CENTRAL_ASIA');
    expect(regionOfCountry('AU')).toBe('OCEANIA');
    expect(regionOfCountry('IL')).toBeNull();
    expect(regionOfCountry(null)).toBeNull();
    expect(regionOfCountry('')).toBeNull();
  });

  it('sorts into catalogue order and lists countries', () => {
    expect(sortRegions(['OCEANIA', 'ARAB_WORLD', 'OCEANIA'])).toEqual(['ARAB_WORLD', 'OCEANIA']);
    expect(countriesOfRegions(['GREATER_CHINA', 'TURKEY'])).toEqual(['CN', 'HK', 'MO', 'TR', 'TW']);
    const cat = staffRegionCatalog();
    expect(cat.data[0]).toMatchObject({ code: 'ARAB_WORLD', nameAr: 'الوطن العربي', nameEn: 'Arab World' });
  });
});

describe('D283 limited staff role', () => {
  it('MODERATION, else SUPPORT, else FINANCE; never with OWNER', () => {
    expect(limitedRoleOf(['SUPPORT', 'MODERATION'])).toBe('MODERATION');
    expect(limitedRoleOf(['FINANCE', 'SUPPORT'])).toBe('SUPPORT');
    expect(limitedRoleOf(['FINANCE'])).toBe('FINANCE');
    expect(limitedRoleOf(['OWNER', 'MODERATION'])).toBeNull();
    expect(limitedRoleOf(['OWNER'])).toBeNull();
    expect(limitedRoleOf([])).toBeNull();
  });
});

describe('D283 assignment by region', () => {
  const staff = (id: string, load: number, regions: StaffRegion[] = [], since = 0) => ({
    id,
    load,
    lastAssignedAt: 0,
    since: new Date(since),
    regions: new Set(regions),
  });

  it('the host country’s region first, even when busier', () => {
    const pool = [staff('a', 0), staff('b', 3, ['ARAB_WORLD']), staff('c', 5, ['ARAB_WORLD'])];
    expect(pickStaffFor(pool, 'SA')?.id).toBe('b');
  });

  it('nobody of the region on shift → by load (as D260)', () => {
    const pool = [staff('a', 2, ['EUROPE']), staff('b', 1, ['TURKEY'])];
    expect(pickStaffFor(pool, 'EG')?.id).toBe('b');
  });

  it('a host with no country, or one in no region → by load', () => {
    const pool = [staff('a', 2, ['ARAB_WORLD']), staff('b', 1)];
    expect(pickStaffFor(pool, null)?.id).toBe('b');
    expect(pickStaffFor(pool, 'IL')?.id).toBe('b');
  });

  it('an empty pool → nobody', () => {
    expect(pickStaffFor([], 'SA')).toBeUndefined();
  });
});

describe('D283 the team picture', () => {
  it('the URL from API_PUBLIC_URL; recognised by its path from any origin', () => {
    expect(teamAvatarUrl({ API_PUBLIC_URL: 'https://api.staging.example/' })).toBe(
      'https://api.staging.example/api/v1/staff/team-avatar.png',
    );
    expect(teamAvatarUrl({})).toBe('https://api.kabsolive.com/api/v1/staff/team-avatar.png');
    expect(isTeamAvatarUrl('https://x.example/api/v1/staff/team-avatar.png')).toBe(true);
    expect(isTeamAvatarUrl('https://cdn.example/avatars/1.jpg')).toBe(false);
    expect(isTeamAvatarUrl('not a url')).toBe(false);
    expect(isTeamAvatarUrl(null)).toBe(false);
  });

  it('the bundled PNG is found', () => {
    const png = teamAvatarPng();
    expect(png).not.toBeNull();
    expect(png!.subarray(1, 4).toString('latin1')).toBe('PNG');
  });
});
