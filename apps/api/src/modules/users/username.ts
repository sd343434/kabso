/** CONVENTIONS §6 username format: 3–30 chars, lowercase, no leading/trailing `.`/`_`. */
export const USERNAME_PATTERN = /^[a-z0-9](?:[a-z0-9._]{1,28}[a-z0-9])?$/;
export const USERNAME_MIN_LENGTH = 3;
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
