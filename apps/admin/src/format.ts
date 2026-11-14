import type { Lang } from './i18n';

/** Numbers and dates in the panel's language (Latin digits in both: ids, amounts and codes are copied around). */
export function formatNumber(value: number, lang: Lang): string {
  return new Intl.NumberFormat(lang === 'ar' ? 'ar-u-nu-latn' : 'en-US').format(value);
}

/** Minor units (cents) as money, e.g. 36000 → "$360.00". */
export function formatMoney(minor: number, currency: string, lang: Lang): string {
  return new Intl.NumberFormat(lang === 'ar' ? 'ar-u-nu-latn' : 'en-US', {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
  }).format(minor / 100);
}

export function formatDate(iso: string | null, lang: Lang): string {
  if (!iso) return '—';
  return new Intl.DateTimeFormat(lang === 'ar' ? 'ar-u-nu-latn' : 'en-GB', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(iso));
}
