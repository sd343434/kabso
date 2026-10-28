/**
 * CONVENTIONS §6 stored username shape: 1–30 chars, lowercase, no leading/trailing `.`/`_`.
 * v1.28-live (D146): widened from 3–30 so 1–2 character premium usernames work everywhere; new
 * regular usernames follow the stricter rule of `premium-username-rules.ts` (6–30, letters and
 * digits). Existing names keep passing (grandfathered).
 */
export const USERNAME_PATTERN = /^[a-z0-9](?:[a-z0-9._]{0,28}[a-z0-9])?$/;
export const USERNAME_MIN_LENGTH = 1;
export const USERNAME_MAX_LENGTH = 30;

/**
 * Reserved names (rejected with USERNAME_TAKEN). Compared after removing `.` and `_`, so
 * `ad.min` or `support_` variants are reserved too.
 */
const RESERVED = new Set([
  'about',
  'abuse',
  'account',
  'accounts',
  'admin',
  'administrator',
  'api',
  'app',
  'auth',
  'billing',
  'blog',
  'contact',
  'dashboard',
  'dev',
  'developer',
  'docs',
  'explore',
  'help',
  'home',
  'info',
  'kabso',
  'kabsolive',
  'legal',
  'live',
  'login',
  'logout',
  'me',
  'mod',
  'moderator',
  'news',
  'null',
  'official',
  'owner',
  'payments',
  'privacy',
  'register',
  'root',
  'security',
  'settings',
  'signin',
  'signup',
  'staff',
  'status',
  'support',
  'system',
  'team',
  'terms',
  'undefined',
  'user',
  'users',
  'wallet',
  'www',
]);

/** Lowercases and trims (used for login lookups; registration requires canonical input). */
export function normalizeUsername(raw: string): string {
  return raw.trim().toLowerCase();
}

export function isValidUsername(username: string): boolean {
  return (
    username.length >= USERNAME_MIN_LENGTH &&
    username.length <= USERNAME_MAX_LENGTH &&
    USERNAME_PATTERN.test(username)
  );
}

export function isReservedUsername(username: string): boolean {
  const lowered = username.toLowerCase();
  return RESERVED.has(lowered) || RESERVED.has(lowered.replace(/[._]/g, ''));
}

/** Emails are compared and stored trimmed + lowercased (CONVENTIONS §6). */
export function normalizeEmail(raw: string): string {
  return raw.trim().toLowerCase();
}
