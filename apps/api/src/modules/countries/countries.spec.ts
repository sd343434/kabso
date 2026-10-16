import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import {
  buildCountriesModule,
  COUNTRY_SOURCE_FILES,
  parseCodes,
  // @ts-expect-error -- plain ESM build script without type declarations
} from '../../../scripts/generate-countries.mjs';
import { updateMeSchema } from '../users/me.schemas.js';
import { COUNTRY_COUNT, CountriesService, countryName, isListedCountry } from './countries.service.js';
import { CLDR_VERSION, COUNTRY_DATA, COUNTRY_SOURCE_SHA256 } from './data/countries.generated.js';

/**
 * CONVENTIONS §11.7 (contract v1.4): the vendored ISO 3166-1 alpha-2 list and the CLDR 48 ar/en
 * names, pinned by sha256 (recorded in data/README.md).
 */
const PINNED_SHA256: Record<string, string> = {
  'iso3166-1-alpha2.txt': 'd98579cc001deece6ad2dd72dc7cdaa791afc17daf08669f255e0479329cbf97',
  'cldr-48.0.0/ar/territories.json': 'b78c4a11a9ad8358048998bcda2eb49e205d5ab281f85991ed097af7b972c3d7',
  'cldr-48.0.0/en/territories.json': '158c1d575308f7e46912edbeda435c8fe2ef5dad280798231f3a432e406b1807',
};

const dataPath = (name: string) => fileURLToPath(new URL(`./data/${name}`, import.meta.url));
const files = Object.fromEntries(
  (COUNTRY_SOURCE_FILES as string[]).map((name) => [name, readFileSync(dataPath(name), 'utf8')]),
);

describe('vendored country data (CONVENTIONS §11.7)', () => {
  it.each(Object.keys(PINNED_SHA256))('%s matches the pinned sha256', (name) => {
    expect(createHash('sha256').update(files[name]!).digest('hex')).toBe(PINNED_SHA256[name]);
    expect(COUNTRY_SOURCE_SHA256[name]).toBe(PINNED_SHA256[name]);
  });

  it('is CLDR 48.0.0 (cldr-json, cldr-localenames-full)', () => {
    expect(CLDR_VERSION).toBe('48.0.0');
    for (const locale of ['ar', 'en']) {
      const json = JSON.parse(files[`cldr-48.0.0/${locale}/territories.json`]!) as {
        main: Record<string, { identity: { language: string } }>;
      };
      expect(json.main[locale]!.identity.language).toBe(locale);
    }
  });

  it('the generated table equals a fresh generation from the vendored files', () => {
    const generated = readFileSync(dataPath('countries.generated.ts'), 'utf8');
    expect(buildCountriesModule(files)).toBe(generated);
  });

  it('has the 249 officially assigned codes, uppercase, unique; XK and reserved codes excluded', () => {
    const codes = parseCodes(files['iso3166-1-alpha2.txt']!) as string[];
    expect(codes).toHaveLength(249);
    expect(COUNTRY_COUNT).toBe(249);
    expect(COUNTRY_DATA.map(([code]) => code)).toEqual(codes);
    for (const excluded of [
      'XK',
      'EU',
      'EZ',
      'UK',
      'UN',
      'ZZ',
      'QO',
      'XA',
      'XB',
      'AC',
      'CP',
      'CQ',
      'DG',
      'EA',
      'IC',
      'TA',
    ]) {
      expect(isListedCountry(excluded), excluded).toBe(false);
    }
    for (const listed of ['SA', 'EG', 'AE', 'IQ', 'MA', 'PS', 'TW', 'HK', 'AQ', 'US', 'GB']) {
      expect(isListedCountry(listed), listed).toBe(true);
    }
  });

  it('every code has a non-empty name in both locales (the build-time check)', () => {
    for (const [code, en, ar] of COUNTRY_DATA) {
      expect(en.trim().length, `${code} en`).toBeGreaterThan(0);
      expect(ar.trim().length, `${code} ar`).toBeGreaterThan(0);
      expect([...en].length).toBeLessThanOrEqual(80);
      expect([...ar].length).toBeLessThanOrEqual(80);
    }
    const build = buildCountriesModule as (files: Record<string, string>) => string;
    const parse = parseCodes as (text: string) => string[];
    expect(() => build({ ...files, 'iso3166-1-alpha2.txt': '# list\nSA\nQQ\n' })).toThrow(
      /QQ has no en name/,
    );
    expect(() => parse('sa\n')).toThrow();
  });

  it('uses the CLDR default names unchanged, never the -alt variants (D45: PS unchanged)', () => {
    const en = JSON.parse(files['cldr-48.0.0/en/territories.json']!) as {
      main: { en: { localeDisplayNames: { territories: Record<string, string> } } };
    };
    const territories = en.main.en.localeDisplayNames.territories;
    expect(countryName('PS', 'en')).toBe(territories.PS);
    expect(countryName('PS', 'en')).not.toBe(territories['PS-alt-short']);
    expect(countryName('SA', 'ar')).toBe('المملكة العربية السعودية');
    expect(countryName('EG', 'en')).toBe('Egypt');
    expect(countryName('XK', 'en')).toBeNull();
  });
});

describe('CountriesService (GET /countries)', () => {
  const service = new CountriesService();

  it('returns every country, localized and sorted by the locale collation', () => {
    for (const lang of ['ar', 'en'] as const) {
      const list = service.list(lang);
      expect(list).toHaveLength(249);
      const collator = new Intl.Collator(lang, { sensitivity: 'base' });
      for (let i = 1; i < list.length; i += 1) {
        expect(collator.compare(list[i - 1]!.name, list[i]!.name)).toBeLessThanOrEqual(0);
      }
      expect(Object.keys(list[0]!)).toEqual(['code', 'name']);
    }
    expect(service.list('en').find((c) => c.code === 'AE')!.name).toBe('United Arab Emirates');
    expect(service.list('ar').find((c) => c.code === 'EG')!.name).toBe('مصر');
    expect(service.list('en')[0]!.code).toBe('AF'); // Afghanistan
  });

  it('returns copies (callers cannot change the static list)', () => {
    service.list('en')[0]!.name = 'changed';
    expect(service.list('en')[0]!.name).toBe('Afghanistan');
  });
});

describe('PATCH /me body (openapi UpdateMeRequest v1.4)', () => {
  const parse = (body: unknown) => updateMeSchema.safeParse(body, { reportInput: true });

  it('every property optional; at least one required; v1.2 body still valid', () => {
    expect(parse({ locale: 'ar' }).success).toBe(true);
    expect(parse({ country: 'SA' }).success).toBe(true);
    expect(parse({ country: null, avatarUploadId: null }).success).toBe(true);
    expect(parse({ avatarUploadId: '0192f1e0-2222-7bbb-8ccc-0d0e0f101112' }).success).toBe(true);
    const empty = parse({});
    expect(empty.success).toBe(false);
    expect(empty.error!.issues[0]).toMatchObject({ code: 'custom', path: [], params: { issue: 'required' } });
  });

  it('malformed country → invalid_format; unknown fields are refused', () => {
    for (const country of ['sa', 'SAU', 'S', '', '12', 'S1']) {
      const result = parse({ country });
      expect(result.success, country).toBe(false);
      expect(result.error!.issues[0]!.code, country).toBe('invalid_format');
    }
    expect(parse({ country: 'SA', email: 'x' }).success).toBe(false);
    expect(parse({ avatarUploadId: 'nope' }).success).toBe(false);
    expect(parse({ avatarUrl: 'https://evil.example/x.png' }).success).toBe(false);
  });
});
