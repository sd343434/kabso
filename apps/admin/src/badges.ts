import type { ItemBadgeCode } from './ui/badge-icons';

/**
 * v1.79-live (D289, CONVENTIONS §10.102): the panel's badge choice for a gift or a store item — pure state functions
 * (tested in test/badges-d289.test.tsx) behind `BadgePicker`.
 *
 * - The two sound badges are one choice: ticking one clears the other, so the panel never sends both (the server
 *   answers 400 `ITEM_BADGES_INVALID` if it did).
 * - «جديد» ends 14 days after the save unless a date is set; «لفترة محدودة» and «موسمي» need a date.
 * - What an uploaded file shows (an audio track or the gift's MP3, a portrait full-screen frame) is pre-selected and
 *   marked «تلقائي»; the owner can always change it.
 * - Badges whose end passed are listed as ended (not ticked) and not sent back.
 */

export type { ItemBadgeCode };

/** The display priority (the server's order). */
export const BADGE_ORDER: readonly ItemBadgeCode[] = [
  'LIMITED',
  'NEW',
  'SEASONAL',
  'EXCLUSIVE',
  'MOST_WANTED',
  'FEATURED',
  'FULLSCREEN',
  'SOUND',
  'NO_SOUND',
];
export const TIMED: readonly ItemBadgeCode[] = ['NEW', 'LIMITED', 'SEASONAL'];
export const NEW_DAYS = 14;
export const MAX_DAYS = 366;
const DAY = 86_400_000;

/** The badge colours (fill, text) — the same in the app (CONVENTIONS §10.102.1). */
export const BADGE_COLORS: Record<ItemBadgeCode, { fill: string; ink: string; edge?: string }> = {
  LIMITED: { fill: '#E50914', ink: '#FFFFFF' },
  NEW: { fill: '#137A43', ink: '#FFFFFF' },
  SEASONAL: { fill: '#F5A623', ink: '#0B0B0D' },
  EXCLUSIVE: { fill: '#0B0B0D', ink: '#F5C451', edge: '#F5C451' },
  MOST_WANTED: { fill: '#F5C451', ink: '#0B0B0D' },
  FEATURED: { fill: '#7B4DFF', ink: '#FFFFFF' },
  FULLSCREEN: { fill: '#00796B', ink: '#FFFFFF' },
  SOUND: { fill: '#1A64BF', ink: '#FFFFFF' },
  NO_SOUND: { fill: '#666671', ink: '#FFFFFF' },
};

/** `AdminItemBadge` as the API lists it. */
export interface AdminItemBadge {
  code: ItemBadgeCode;
  until: string | null;
  active: boolean;
}

/** One row of the picker. */
export interface BadgeChoice {
  on: boolean;
  /** `YYYY-MM-DD` (the end, local midnight of that day) or '' (none / NEW's default). */
  until: string;
  /** Pre-selected from the uploaded file (shown «تلقائي» until the owner changes it). */
  auto: boolean;
  /** Stored but ended (shown «انتهت»). */
  ended: boolean;
}

export type BadgeState = Record<ItemBadgeCode, BadgeChoice>;

/** A date as the `<input type="date">` value (UTC day; the panel shows the day, the server keeps the instant). */
export function dateInput(iso: string | null): string {
  return iso ? iso.slice(0, 10) : '';
}

/** The state of a stored set (a new item: all off). */
export function badgeState(stored: readonly AdminItemBadge[] = []): BadgeState {
  const out = {} as BadgeState;
  for (const code of BADGE_ORDER) {
    const s = stored.find((b) => b.code === code);
    out[code] = {
      on: !!s && s.active,
      until: s && s.active ? dateInput(s.until) : '',
      auto: false,
      ended: !!s && !s.active,
    };
  }
  return out;
}

/** Ticks or unticks a badge; the two sound badges exclude each other. */
export function toggleBadge(state: BadgeState, code: ItemBadgeCode, on: boolean): BadgeState {
  const next: BadgeState = { ...state, [code]: { ...state[code], on, auto: false, ended: false } };
  if (on && code === 'SOUND') next.NO_SOUND = { ...next.NO_SOUND, on: false, auto: false };
  if (on && code === 'NO_SOUND') next.SOUND = { ...next.SOUND, on: false, auto: false };
  return next;
}

export function setBadgeUntil(state: BadgeState, code: ItemBadgeCode, until: string): BadgeState {
  return { ...state, [code]: { ...state[code], until, auto: false } };
}

/** What the files show (an upload's `hasAudio` / `fullscreen`, the gift's MP3). Undefined: not known. */
export interface BadgeDetection {
  hasEffect: boolean;
  hasAudio: boolean;
  fullscreen?: boolean | undefined;
}

/**
 * Pre-selects from what the files show: SOUND with audio, NO_SOUND for an effect without any, FULLSCREEN for a
 * full-screen frame. Only the detected badges change (marked auto); the owner's other choices stay.
 */
export function applyDetection(state: BadgeState, d: BadgeDetection): BadgeState {
  let next = state;
  const set = (code: ItemBadgeCode, on: boolean) => {
    next = { ...next, [code]: { ...next[code], on, auto: on, ended: false } };
  };
  if (d.hasAudio) {
    set('SOUND', true);
    set('NO_SOUND', false);
  } else if (d.hasEffect) {
    set('NO_SOUND', true);
    set('SOUND', false);
  }
  if (d.fullscreen !== undefined) set('FULLSCREEN', d.fullscreen);
  return next;
}

/** End of a `YYYY-MM-DD` day as an instant (23:59:59.999 UTC: the badge shows through that day). */
function endOfDay(day: string): Date {
  return new Date(`${day}T23:59:59.999Z`);
}

/** The panel's own checks before saving (the server checks again). Keys: `sound` or the code with `until_*`. */
export function badgeProblems(state: BadgeState, now: Date): string[] {
  const out: string[] = [];
  if (state.SOUND.on && state.NO_SOUND.on) out.push('sound');
  for (const code of TIMED) {
    const c = state[code];
    if (!c.on) continue;
    if (!c.until) {
      if (code !== 'NEW') out.push(`${code}:until_required`);
      continue;
    }
    const end = endOfDay(c.until);
    if (Number.isNaN(end.getTime())) out.push(`${code}:invalid`);
    else if (end.getTime() <= now.getTime()) out.push(`${code}:until_past`);
    else if (end.getTime() > now.getTime() + MAX_DAYS * DAY) out.push(`${code}:until_too_far`);
  }
  return out;
}

/** `ItemBadgeInput[]` for the request: the ticked badges in priority order, with their ends. */
export function badgesBody(state: BadgeState): { code: ItemBadgeCode; until?: string }[] {
  return BADGE_ORDER.filter((c) => state[c].on).map((code) => {
    const until = state[code].until;
    return TIMED.includes(code) && until ? { code, until: endOfDay(until).toISOString() } : { code };
  });
}

/** Whether the set to send differs from the stored one (an edit sends `badges` only then). */
export function badgesChanged(state: BadgeState, stored: readonly AdminItemBadge[]): boolean {
  const before = badgesBody(badgeState(stored));
  const after = badgesBody(state);
  const key = (l: { code: string; until?: string }[]) => l.map((b) => `${b.code}@${(b.until ?? '').slice(0, 10)}`).join(',');
  return key(before) !== key(after);
}

/** The default end the picker shows for «جديد» without a date. */
export function defaultNewUntil(now: Date): string {
  return new Date(now.getTime() + NEW_DAYS * DAY).toISOString().slice(0, 10);
}

/** Days left until `iso` (rounded up), or null. */
export function daysLeft(iso: string | null, now: Date): number | null {
  if (!iso) return null;
  return Math.max(0, Math.ceil((new Date(iso).getTime() - now.getTime()) / DAY));
}

/**
 * v1.79-live (D289): the badges' part of the body — on create the ticked ones (if any), on an edit the whole set when
 * it changed.
 */
export function badgesPart(state: BadgeState, before: { badges: AdminItemBadge[] } | null): Record<string, unknown> {
  if (before === null) {
    const list = badgesBody(state);
    return list.length > 0 ? { badges: list } : {};
  }
  return badgesChanged(state, before.badges) ? { badges: badgesBody(state) } : {};
}

/**
 * v1.79-live (D289, owner answer Q2): a «موسمي» still showing with no end — one migrated from the old EVENT badge. The
 * owner wants seasonal badges time-bound, so the lists mark these «حدد تاريخ الانتهاء» until a date is set.
 */
export function seasonalWithoutEnd(badges: readonly AdminItemBadge[]): boolean {
  return badges.some((b) => b.code === 'SEASONAL' && b.active && b.until === null);
}
