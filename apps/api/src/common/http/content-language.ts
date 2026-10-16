export type ContentLanguage = 'ar' | 'en';

/**
 * CONVENTIONS §10.1: the language of server-curated names is the primary subtag of the first
 * `Accept-Language` entry when it is `ar` or `en`; otherwise the caller's stored locale decides
 * (null here). Quality values and later entries are ignored on purpose (the client sends exactly
 * one language, §1).
 */
export function languageFromAcceptLanguage(header: string | string[] | undefined): ContentLanguage | null {
  const value = Array.isArray(header) ? header[0] : header;
  if (typeof value !== 'string') return null;
  const first = value.split(',')[0] ?? '';
  const tag = (first.split(';')[0] ?? '').trim().toLowerCase();
  const primary = tag.split('-')[0];
  return primary === 'ar' || primary === 'en' ? primary : null;
}
