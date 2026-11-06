import type { GiftBadge, ItemBadge } from '../../generated/prisma/client.js';
import type { ErrorDetail } from '../../common/errors/error-codes.js';

/**
 * v1.79-live (D289, CONVENTIONS §10.102): the badges of a gift or a store item — a set, one icon each everywhere (the gift
 * box, the store, the item's details, the panel). Pure rules shared by the gifts, the store and their panel pages (no
 * Nest dependencies).
 *
 * - SOUND «بمؤثرات صوتية» and NO_SOUND «بدون مؤثرات صوتية» exclude each other (400 `ITEM_BADGES_INVALID`).
 * - NEW «جديد» ends 14 days after it is set unless the owner gives another date; LIMITED «لفترة محدودة» and SEASONAL
 *   «موسمي» need the owner's date. After its end a badge simply stops showing; the item stays listed and on sale. The end
 *   is compared at read time (no sweeper): the stored set is the owner's, what is shown is what is still running.
 * - The others (MOST_WANTED, FEATURED, FULLSCREEN, EXCLUSIVE) have no end.
 */

/** Every badge in the display priority: a small tile shows the first one or two of what is running. */
export const ITEM_BADGE_PRIORITY = [
  'LIMITED',
  'NEW',
  'SEASONAL',
  'EXCLUSIVE',
  'MOST_WANTED',
  'FEATURED',
  'FULLSCREEN',
  'SOUND',
  'NO_SOUND',
] as const satisfies readonly ItemBadge[];

export const ITEM_BADGES: readonly ItemBadge[] = ITEM_BADGE_PRIORITY;
/** The badges with an end. */
export const TIMED_BADGES: readonly ItemBadge[] = ['NEW', 'LIMITED', 'SEASONAL'];
/** «جديد» without a date: 14 days from when it is set (owner). */
export const NEW_BADGE_DAYS = 14;
/** The latest end the panel may set: a year ahead (a longer «season» is not one). */
export const BADGE_MAX_DAYS = 366;
const DAY_MS = 86_400_000;
/**
 * A full-screen effect, told from its frame: portrait at least 1.5 × as tall as wide (a phone screen is 16:9 … 19.5:9;
 * a centred effect is about square). The panel pre-selects «شاشة كاملة» then; the owner can change it.
 */
export const FULLSCREEN_MIN_ASPECT = 1.5;

/** One badge as the panel sends it: `until` only for NEW (optional), LIMITED and SEASONAL (required). */
export interface ItemBadgeInput {
  readonly code: ItemBadge;
  readonly until?: string | null | undefined;
}

/** One stored badge: its end (timed ones; SEASONAL may lack one only when migrated from EVENT). */
export interface ItemBadgeSetting {
  readonly code: ItemBadge;
  readonly until: Date | null;
}

/** The stored columns (gifts and store items have the same four). */
export interface ItemBadgeColumns {
  readonly badges: ItemBadge[];
  readonly badgeNewUntil: Date | null;
  readonly badgeLimitedUntil: Date | null;
  readonly badgeSeasonalUntil: Date | null;
}

/** `ItemBadge` on the wire: a running badge and its end (null: none). */
export interface ItemBadgeDto {
  code: ItemBadge;
  until: string | null;
}

/** `AdminItemBadge`: a stored badge, its end and whether it still shows. */
export interface AdminItemBadgeDto extends ItemBadgeDto {
  active: boolean;
}

const rank = (code: ItemBadge) => ITEM_BADGE_PRIORITY.indexOf(code);

function byPriority<T extends { code: ItemBadge }>(list: readonly T[]): T[] {
  return [...list].sort((a, b) => rank(a.code) - rank(b.code));
}

/**
 * Checks the panel's badges and fixes their ends at `now`. Problems as `ErrorDetail`s (empty: valid):
 * `badges` `duplicate_value` | `sound_exclusive`; `badges[i].until` `until_required` | `until_not_allowed` |
 * `invalid_format` | `until_past` | `until_too_far`.
 */
export function resolveItemBadges(
  input: readonly ItemBadgeInput[],
  now: Date,
): { settings: ItemBadgeSetting[]; problems: ErrorDetail[] } {
  const problems: ErrorDetail[] = [];
  const codes = input.map((b) => b.code);
  if (new Set(codes).size !== codes.length) problems.push({ field: 'badges', issue: 'duplicate_value' });
  if (codes.includes('SOUND') && codes.includes('NO_SOUND')) {
    problems.push({ field: 'badges', issue: 'sound_exclusive' });
  }
  const settings: ItemBadgeSetting[] = [];
  input.forEach((b, i) => {
    const field = `badges[${String(i)}].until`;
    const timed = TIMED_BADGES.includes(b.code);
    const given = b.until !== undefined && b.until !== null;
    if (!timed) {
      if (given) problems.push({ field, issue: 'until_not_allowed' });
      settings.push({ code: b.code, until: null });
      return;
    }
    if (!given) {
      if (b.code === 'NEW')
        settings.push({ code: b.code, until: new Date(now.getTime() + NEW_BADGE_DAYS * DAY_MS) });
      else problems.push({ field, issue: 'until_required' });
      return;
    }
    const until = new Date(b.until);
    if (Number.isNaN(until.getTime())) {
      problems.push({ field, issue: 'invalid_format' });
    } else if (until.getTime() <= now.getTime()) {
      problems.push({ field, issue: 'until_past' });
    } else if (until.getTime() > now.getTime() + BADGE_MAX_DAYS * DAY_MS) {
      problems.push({ field, issue: 'until_too_far' });
    } else {
      settings.push({ code: b.code, until });
    }
  });
  return { settings: byPriority(settings), problems };
}

/** The stored settings of a row (in priority order). */
export function badgeSettingsOf(row: ItemBadgeColumns): ItemBadgeSetting[] {
  return byPriority(
    row.badges.map((code) => ({
      code,
      until:
        code === 'NEW'
          ? row.badgeNewUntil
          : code === 'LIMITED'
            ? row.badgeLimitedUntil
            : code === 'SEASONAL'
              ? row.badgeSeasonalUntil
              : null,
    })),
  );
}

/** The columns for a set of settings. */
export function badgeColumns(settings: readonly ItemBadgeSetting[]): ItemBadgeColumns {
  const until = (code: ItemBadge) => settings.find((s) => s.code === code)?.until ?? null;
  return {
    badges: byPriority(settings).map((s) => s.code),
    badgeNewUntil: until('NEW'),
    badgeLimitedUntil: until('LIMITED'),
    badgeSeasonalUntil: until('SEASONAL'),
  };
}

/** Whether a stored badge still shows at `now` (a timed one until its end; no end: always). */
export function badgeRunning(setting: ItemBadgeSetting, now: Date): boolean {
  return setting.until === null || setting.until.getTime() > now.getTime();
}

/** The running badges at `now`, in priority order (what the apps show). */
export function activeItemBadges(row: ItemBadgeColumns, now: Date): ItemBadgeDto[] {
  return badgeSettingsOf(row)
    .filter((s) => badgeRunning(s, now))
    .map((s) => ({ code: s.code, until: s.until?.toISOString() ?? null }));
}

/** Every stored badge with whether it still shows (the panel). */
export function adminItemBadges(row: ItemBadgeColumns, now: Date): AdminItemBadgeDto[] {
  return badgeSettingsOf(row).map((s) => ({
    code: s.code,
    until: s.until?.toISOString() ?? null,
    active: badgeRunning(s, now),
  }));
}

/** The deprecated single value of a set (an older app's `Gift.badge`): NEW, else EVENT for «موسمي», else NONE. */
export function legacyGiftBadge(codes: readonly ItemBadge[]): GiftBadge {
  if (codes.includes('NEW')) return 'NEW';
  if (codes.includes('SEASONAL')) return 'EVENT';
  return 'NONE';
}

/**
 * The set after an older client's single value (the `gift-admin --badge` flag, a panel before D289): NONE takes off
 * «جديد» and «موسمي», NEW sets «جديد» (keeping a running end, else 14 days) instead of «موسمي», EVENT sets «موسمي» (keeping
 * its end, else none) instead of «جديد». The other badges stay.
 */
export function applyLegacyGiftBadge(
  current: readonly ItemBadgeSetting[],
  legacy: GiftBadge,
  now: Date,
): ItemBadgeSetting[] {
  const rest = current.filter((s) => s.code !== 'NEW' && s.code !== 'SEASONAL');
  const kept = (code: ItemBadge) => current.find((s) => s.code === code && badgeRunning(s, now));
  if (legacy === 'NEW') {
    rest.push(kept('NEW') ?? { code: 'NEW', until: new Date(now.getTime() + NEW_BADGE_DAYS * DAY_MS) });
  } else if (legacy === 'EVENT') {
    rest.push(kept('SEASONAL') ?? { code: 'SEASONAL', until: null });
  }
  return byPriority(rest);
}

/** The set after the store's deprecated `isNew` switch: true sets «جديد» (keeping a running end), false takes it off. */
export function applyLegacyIsNew(
  current: readonly ItemBadgeSetting[],
  isNew: boolean,
  now: Date,
): ItemBadgeSetting[] {
  const rest = current.filter((s) => s.code !== 'NEW');
  if (isNew) {
    const kept = current.find((s) => s.code === 'NEW' && badgeRunning(s, now));
    rest.push(kept ?? { code: 'NEW', until: new Date(now.getTime() + NEW_BADGE_DAYS * DAY_MS) });
  }
  return byPriority(rest);
}

/** A stable text of a set (audit before / after, the catalogue version). */
export function badgeText(settings: readonly ItemBadgeSetting[]): string {
  return byPriority(settings)
    .map((s) => (s.until ? `${s.code}@${s.until.toISOString()}` : s.code))
    .join(',');
}

/** «شاشة كاملة» from an effect's frame size (null when unknown). */
export function looksFullscreen(
  width: number | null | undefined,
  height: number | null | undefined,
): boolean {
  return !!width && !!height && height >= width * FULLSCREEN_MIN_ASPECT;
}
