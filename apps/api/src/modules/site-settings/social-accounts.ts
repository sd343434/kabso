import { z } from 'zod';

/**
 * v1.139-social (D387, CONVENTIONS §10.176.5): the app's official social media accounts «حساباتنا الرسمية» — the
 * rules shared by the service and the tests. **Links only**: there is no field for a password, token or key, and none
 * may be added (the repository is public, D40).
 */
export const SOCIAL_PLATFORMS = [
  'INSTAGRAM',
  'TIKTOK',
  'X',
  'FACEBOOK',
  'YOUTUBE',
  'SNAPCHAT',
  'TELEGRAM',
  'WHATSAPP',
  'THREADS',
  'LINKEDIN',
  'DISCORD',
  'OTHER',
] as const;
export type SocialPlatform = (typeof SOCIAL_PLATFORMS)[number];

/** At most this many accounts (409 `social_accounts_full`). */
export const SOCIAL_ACCOUNTS_MAX = 20;

/**
 * An https URL with a host and no user name or password part, at most 512 characters, else null. Returned as the URL
 * parser normalises it (lower-case scheme and host).
 */
export function normalizeSocialUrl(raw: string): string | null {
  const value = raw.trim();
  if (value.length < 9 || value.length > 512) return null;
  if (!/^https:\/\//i.test(value)) return null;
  // No white space or control characters anywhere (the parser would quietly drop some).
  // eslint-disable-next-line no-control-regex
  if (/[\s\u0000-\u001f\u007f]/.test(value)) return null;
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    return null;
  }
  if (url.protocol !== 'https:' || url.hostname === '' || url.username !== '' || url.password !== '') return null;
  const out = url.toString();
  return out.length > 512 ? null : out;
}

/** A handle: 1–64 characters after trimming, no control characters. */
// eslint-disable-next-line no-control-regex
const handle = z.string().trim().min(1).max(64).regex(/^[^\u0000-\u001f\u007f]+$/);

export const socialAccountBody = z.strictObject({
  platform: z.enum(SOCIAL_PLATFORMS),
  handle,
  url: z.string().min(1).max(512),
});
export type SocialAccountInput = z.infer<typeof socialAccountBody>;

export const socialAccountOrderBody = z.strictObject({
  ids: z.array(z.uuid()).max(SOCIAL_ACCOUNTS_MAX),
});
