/**
 * v1.71-live (D283, CONVENTIONS §10.96.11; owner: «قم بتجزئة الاشراف كل مشرف مسؤول عن دول معينة بما يناسب»): the
 * regions a MODERATION / SUPPORT staff member is responsible for — fixed groups of countries (ISO 3166-1 alpha-2,
 * upper case), each country in at most one region. The OWNER assigns them in «الموظفون والصلاحيات»; the live
 * assignment (§10.96.2) and the report alerts (§10.96.8) prefer a staff member whose region covers the host's country
 * (`user_profiles.country_code`), and «بثوثي» / «البث الآن» can filter by them. A country in no region (or a host
 * with no country) falls back to the load rule. The names are the app's and the panel's (ar / en); the API sends
 * codes only.
 */
export const STAFF_REGIONS = {
  /** The 22 members of the Arab League. */
  ARAB_WORLD: [
    'AE', 'BH', 'DJ', 'DZ', 'EG', 'IQ', 'JO', 'KM', 'KW', 'LB', 'LY',
    'MA', 'MR', 'OM', 'PS', 'QA', 'SA', 'SD', 'SO', 'SY', 'TN', 'YE',
  ],
  GREATER_CHINA: ['CN', 'HK', 'MO', 'TW'],
  TURKEY: ['TR'],
  IRAN: ['IR'],
  SOUTH_ASIA: ['AF', 'BD', 'BT', 'IN', 'LK', 'MV', 'NP', 'PK'],
  SOUTHEAST_ASIA: ['BN', 'ID', 'KH', 'LA', 'MM', 'MY', 'PH', 'SG', 'TH', 'TL', 'VN'],
  EAST_ASIA: ['JP', 'KP', 'KR', 'MN'],
  EUROPE: [
    'AD', 'AL', 'AT', 'AX', 'BA', 'BE', 'BG', 'CH', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FO', 'FR', 'GB',
    'GG', 'GI', 'GR', 'HR', 'HU', 'IE', 'IM', 'IS', 'IT', 'JE', 'LI', 'LT', 'LU', 'LV', 'MC', 'MD', 'ME', 'MK',
    'MT', 'NL', 'NO', 'PL', 'PT', 'RO', 'RS', 'SE', 'SI', 'SJ', 'SK', 'SM', 'UA', 'VA',
  ],
  NORTH_AMERICA: ['BM', 'CA', 'GL', 'PM', 'US'],
  LATIN_AMERICA: [
    'AG', 'AI', 'AR', 'AW', 'BB', 'BL', 'BO', 'BQ', 'BR', 'BS', 'BZ', 'CL', 'CO', 'CR', 'CU', 'CW', 'DM', 'DO',
    'EC', 'FK', 'GD', 'GF', 'GP', 'GT', 'GY', 'HN', 'HT', 'JM', 'KN', 'KY', 'LC', 'MF', 'MQ', 'MS', 'MX', 'NI',
    'PA', 'PE', 'PR', 'PY', 'SR', 'SV', 'SX', 'TC', 'TT', 'UY', 'VC', 'VE', 'VG', 'VI',
  ],
  SUB_SAHARAN_AFRICA: [
    'AO', 'BF', 'BI', 'BJ', 'BW', 'CD', 'CF', 'CG', 'CI', 'CM', 'CV', 'ER', 'ET', 'GA', 'GH', 'GM', 'GN', 'GQ',
    'GW', 'KE', 'LR', 'LS', 'MG', 'ML', 'MU', 'MW', 'MZ', 'NA', 'NE', 'NG', 'RE', 'RW', 'SC', 'SH', 'SL', 'SN',
    'SS', 'ST', 'SZ', 'TD', 'TG', 'TZ', 'UG', 'YT', 'ZA', 'ZM', 'ZW',
  ],
  RUSSIA_CENTRAL_ASIA: ['AM', 'AZ', 'BY', 'GE', 'KG', 'KZ', 'RU', 'TJ', 'TM', 'UZ'],
  OCEANIA: [
    'AS', 'AU', 'CK', 'FJ', 'FM', 'GU', 'KI', 'MH', 'MP', 'NC', 'NF', 'NR', 'NU', 'NZ', 'PF', 'PG', 'PW', 'SB',
    'TK', 'TO', 'TV', 'VU', 'WF', 'WS',
  ],
} as const satisfies Record<string, readonly string[]>;

export type StaffRegion = keyof typeof STAFF_REGIONS;

/** The codes in the order the panel and the app list them. */
export const STAFF_REGION_CODES = Object.keys(STAFF_REGIONS) as StaffRegion[];

/** Arabic and English names (the panel shows both; the app has its own l10n with the same words). */
export const STAFF_REGION_NAMES: Readonly<Record<StaffRegion, { ar: string; en: string }>> = {
  ARAB_WORLD: { ar: 'الوطن العربي', en: 'Arab World' },
  GREATER_CHINA: { ar: 'الصين الكبرى', en: 'Greater China' },
  TURKEY: { ar: 'تركيا', en: 'Türkiye' },
  IRAN: { ar: 'إيران', en: 'Iran' },
  SOUTH_ASIA: { ar: 'جنوب آسيا', en: 'South Asia' },
  SOUTHEAST_ASIA: { ar: 'جنوب شرق آسيا', en: 'Southeast Asia' },
  EAST_ASIA: { ar: 'شرق آسيا', en: 'East Asia' },
  EUROPE: { ar: 'أوروبا', en: 'Europe' },
  NORTH_AMERICA: { ar: 'أمريكا الشمالية', en: 'North America' },
  LATIN_AMERICA: { ar: 'أمريكا اللاتينية', en: 'Latin America' },
  SUB_SAHARAN_AFRICA: { ar: 'أفريقيا جنوب الصحراء', en: 'Sub-Saharan Africa' },
  RUSSIA_CENTRAL_ASIA: { ar: 'روسيا وآسيا الوسطى', en: 'Russia & Central Asia' },
  OCEANIA: { ar: 'أوقيانوسيا', en: 'Oceania' },
};

const COUNTRY_REGION = new Map<string, StaffRegion>(
  STAFF_REGION_CODES.flatMap((r) => STAFF_REGIONS[r].map((c) => [c, r] as const)),
);

export function isStaffRegion(v: unknown): v is StaffRegion {
  return typeof v === 'string' && Object.hasOwn(STAFF_REGIONS, v);
}

/** The region of an ISO alpha-2 country (any case), or null (none, or a country in no region). */
export function regionOfCountry(country: string | null | undefined): StaffRegion | null {
  if (!country) return null;
  return COUNTRY_REGION.get(country.toUpperCase()) ?? null;
}

/** The countries of `regions` (for a SQL `IN`), upper case, sorted. */
export function countriesOfRegions(regions: readonly StaffRegion[]): string[] {
  return [...new Set(regions.flatMap((r) => STAFF_REGIONS[r]))].sort();
}

/** `regions` in catalogue order, without duplicates. */
export function sortRegions(regions: readonly StaffRegion[]): StaffRegion[] {
  const set = new Set(regions);
  return STAFF_REGION_CODES.filter((r) => set.has(r));
}

/** The panel's / the contract's catalogue (`AdminStaffRegionCatalog`). */
export function staffRegionCatalog() {
  return {
    data: STAFF_REGION_CODES.map((code) => ({
      code,
      nameAr: STAFF_REGION_NAMES[code].ar,
      nameEn: STAFF_REGION_NAMES[code].en,
      countries: [...STAFF_REGIONS[code]],
    })),
  };
}
