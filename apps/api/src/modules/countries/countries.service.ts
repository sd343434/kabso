import { Injectable } from '@nestjs/common';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { COUNTRY_DATA } from './data/countries.generated.js';

/** `Country` (openapi v1.4): the code and its name in the resolved language. */
export interface CountryDto {
  code: string;
  name: string;
}

/** CONVENTIONS §11.7: ISO 3166-1 alpha-2, uppercase. Membership in the list is a separate check. */
export const COUNTRY_CODE_PATTERN = /^[A-Z]{2}$/;

const NAMES: ReadonlyMap<string, { readonly en: string; readonly ar: string }> = new Map(
  COUNTRY_DATA.map(([code, en, ar]) => [code, { en, ar }]),
);

function sortedFor(lang: ContentLanguage): readonly CountryDto[] {
  // ICU collation for the locale (Node ships full ICU); code as a stable tiebreak.
  const collator = new Intl.Collator(lang, { sensitivity: 'base' });
  return COUNTRY_DATA.map(([code, en, ar]) => ({ code, name: lang === 'en' ? en : ar })).sort(
    (a, b) => collator.compare(a.name, b.name) || (a.code < b.code ? -1 : 1),
  );
}

const SORTED: Readonly<Record<ContentLanguage, readonly CountryDto[]>> = {
  ar: sortedFor('ar'),
  en: sortedFor('en'),
};

/** True when `code` is one of the vendored, selectable countries (CONVENTIONS §11.7). */
export function isListedCountry(code: string): boolean {
  return NAMES.has(code);
}

/** Localized name of a listed country (CLDR 48 default name), else null. */
export function countryName(code: string, lang: ContentLanguage): string | null {
  const names = NAMES.get(code);
  if (!names) return null;
  return lang === 'en' ? names.en : names.ar;
}

/** Number of selectable countries (249 in v1.4). */
export const COUNTRY_COUNT = NAMES.size;

/**
 * The vendored country list (CONVENTIONS §11.7): static per server release, no provider, no
 * database. Countries are only ever what the user chose; nothing here infers one.
 */
@Injectable()
export class CountriesService {
  /** `GET /countries`: every selectable country, sorted by the localized name (ICU collation). */
  list(lang: ContentLanguage): CountryDto[] {
    return SORTED[lang].map((c) => ({ ...c }));
  }

  isListed(code: string): boolean {
    return isListedCountry(code);
  }

  name(code: string, lang: ContentLanguage): string | null {
    return countryName(code, lang);
  }
}
