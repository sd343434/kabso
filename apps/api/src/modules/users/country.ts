/**
 * v1.27.1-live (D133, CONVENTIONS §10.28): a user's own country, ISO 3166-1 alpha-2. The ICU region
 * names bundled with Node decide which two-letter codes are real regions; groupings that are not
 * countries (the EU, the UN, the eurozone, "outlying Oceania", "unknown region") are refused, and
 * XK (a user-assigned code) is excluded by default as the owner decided for the country list (D45).
 */
const NOT_COUNTRIES = new Set(['ZZ', 'EU', 'EZ', 'UN', 'QO', 'XK']);
const names = new Intl.DisplayNames(['en'], { type: 'region', fallback: 'code' });

/** `code` (upper case) is a known country or territory code. */
export function isCountryCode(code: string): boolean {
  if (!/^[A-Z]{2}$/.test(code) || NOT_COUNTRIES.has(code)) return false;
  try {
    return names.of(code) !== code;
  } catch {
    return false;
  }
}
