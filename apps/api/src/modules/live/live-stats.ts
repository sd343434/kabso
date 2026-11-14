/**
 * v1.27.6-live (D140, CONVENTIONS §10.31): the pure parts of a live's statistics — the viewer
 * country breakdown and its percent rounding. No I/O; `LiveStatsService` feeds it the counts.
 */

/** Named countries shown before the rest are grouped as `OTHER`. */
export const LIVE_STATS_TOP_COUNTRIES = 5;

/** The people shown on the summary's podium. */
export const LIVE_STATS_TOP_SUPPORTERS = 3;

/** A bucket of `viewerCountries`: an ISO 3166-1 alpha-2 code, `OTHER` or `UNKNOWN`. */
export interface LiveViewerCountryDto {
  country: string;
  viewers: number;
  percent: number;
}

/**
 * `percent` of `part` in `total`, one decimal, half up (`12.25` → `12.3`); 0 when `total` is 0.
 * Each bucket is rounded on its own, so the sum may be 99.9 or 100.1 — shown as is (§10.31).
 */
export function percentOf(part: number, total: number): number {
  if (total <= 0 || part <= 0) return 0;
  // Integer math first: tenths of a percent = round(part × 1000 / total).
  return Math.round((part * 1000) / total) / 10;
}

/**
 * The country breakdown over the live's unique viewers: the top {@link LIVE_STATS_TOP_COUNTRIES}
 * countries by viewers (ties: the code, A → Z), then `OTHER` (every further country) and
 * `UNKNOWN` (guests and people without a country), each only when it has viewers. `rows` holds
 * one count per country (`null` = no country); the total is their sum.
 */
export function countryBreakdown(
  rows: readonly { country: string | null; viewers: number }[],
): LiveViewerCountryDto[] {
  const total = rows.reduce((sum, r) => sum + r.viewers, 0);
  if (total === 0) return [];
  const named = rows
    .filter((r): r is { country: string; viewers: number } => r.country !== null && r.viewers > 0)
    .map((r) => ({ country: r.country.toUpperCase(), viewers: r.viewers }))
    .sort((a, b) => b.viewers - a.viewers || (a.country < b.country ? -1 : a.country > b.country ? 1 : 0));
  const top = named.slice(0, LIVE_STATS_TOP_COUNTRIES);
  const other = named.slice(LIVE_STATS_TOP_COUNTRIES).reduce((sum, r) => sum + r.viewers, 0);
  const unknown = rows.filter((r) => r.country === null).reduce((sum, r) => sum + r.viewers, 0);
  const out: LiveViewerCountryDto[] = top.map((r) => ({ ...r, percent: percentOf(r.viewers, total) }));
  if (other > 0) out.push({ country: 'OTHER', viewers: other, percent: percentOf(other, total) });
  if (unknown > 0) out.push({ country: 'UNKNOWN', viewers: unknown, percent: percentOf(unknown, total) });
  return out;
}

/** Whole seconds between two instants, never negative. */
export function secondsBetween(from: Date, to: Date): number {
  return Math.max(0, Math.floor((to.getTime() - from.getTime()) / 1000));
}
