import { isIP } from 'node:net';
import { z } from 'zod';
import { normalizeContentText, type ContentTextLimits } from '../posts/content-text.js';

/**
 * v1.47-social (D175, owner 2026-10-30, CONVENTIONS §10.47): the profile fields gender, account
 * category and links. Pure rules shared by `PATCH /me`, registration and the profile reads.
 */

/** `Gender`: «ذكر / أنثى / أفضّل عدم الذكر». */
export const GENDERS = ['MALE', 'FEMALE', 'UNDISCLOSED'] as const;
export type Gender = (typeof GENDERS)[number];

/** `AccountCategory`, in the owner's order. */
export const ACCOUNT_CATEGORIES = [
  'SINGER',
  'MUSICIAN',
  'POET',
  'PRESENTER',
  'GAMER',
  'CONTENT_CREATOR',
  'ATHLETE',
  'ARTIST',
  'BLOGGER',
  'PUBLIC_FIGURE',
  'OTHER',
] as const;
export type AccountCategory = (typeof ACCOUNT_CATEGORIES)[number];

/** `ProfileLinkPlatform`: the known domains the app opens without a warning. */
export type ProfileLinkPlatform = 'INSTAGRAM' | 'TIKTOK' | 'YOUTUBE' | 'FACEBOOK' | 'X' | 'OTHER';

/** At most 3 links per profile. */
export const MAX_PROFILE_LINKS = 3;
/** A normalised link is at most 500 characters; raw input over 2 048 is refused before parsing. */
export const LINK_MAX_LENGTH = 500;
export const LINK_RAW_MAX = 2048;
/** A label: one line, ≤ 30 code points, §6 hygiene; empty → none. */
const LABEL_LIMITS: ContentTextLimits = { maxCodePoints: 30, maxLineBreaks: 0, allowEmpty: true };

/** Registrable domains of the known platforms; the host may be the domain or any subdomain of it. */
const PLATFORM_DOMAINS: ReadonlyArray<readonly [string, ProfileLinkPlatform]> = [
  ['instagram.com', 'INSTAGRAM'],
  ['tiktok.com', 'TIKTOK'],
  ['youtube.com', 'YOUTUBE'],
  ['youtu.be', 'YOUTUBE'],
  ['facebook.com', 'FACEBOOK'],
  ['fb.com', 'FACEBOOK'],
  ['x.com', 'X'],
  ['twitter.com', 'X'],
];

/** The platform of a normalised link's host (`OTHER` for every other domain). */
export function linkPlatform(url: string): ProfileLinkPlatform {
  let host: string;
  try {
    host = new URL(url).hostname;
  } catch {
    return 'OTHER';
  }
  for (const [domain, platform] of PLATFORM_DOMAINS) {
    if (host === domain || host.endsWith(`.${domain}`)) return platform;
  }
  return 'OTHER';
}

// Whitespace, controls, bidi and zero-width characters anywhere in the raw link (they could hide
// the real address from the reader).
const LINK_FORBIDDEN =
  // eslint-disable-next-line no-control-regex -- intentionally matching control characters
  /[\s\u0000-\u001f\u007f-\u009f\u00ad\u061c\u200b-\u200f\u2028-\u202e\u2060-\u2069\ufeff]/u;

/**
 * Validates and normalises one profile link (§10.47): https only; no user name or password; no
 * port; a host name (never an IP literal, `localhost` or a single label) whose last label is
 * alphabetic or `xn--`; the WHATWG serialisation (lower-case punycode host, percent-encoding) is
 * stored, without a fragment, at most {@link LINK_MAX_LENGTH} characters. Returns the issue
 * otherwise (`invalid_format`, `too_long`).
 */
export function normalizeProfileLink(
  raw: string,
): { value: string } | { issue: 'invalid_format' | 'too_long' } {
  const trimmed = raw.trim();
  if (trimmed.length === 0 || LINK_FORBIDDEN.test(trimmed)) return { issue: 'invalid_format' };
  if (!/^https:\/\//i.test(trimmed)) return { issue: 'invalid_format' };
  let url: URL;
  try {
    url = new URL(trimmed);
  } catch {
    return { issue: 'invalid_format' };
  }
  if (url.protocol !== 'https:') return { issue: 'invalid_format' };
  if (url.username !== '' || url.password !== '') return { issue: 'invalid_format' };
  if (url.port !== '') return { issue: 'invalid_format' };
  const host = url.hostname;
  if (host.startsWith('[') || isIP(host) !== 0) return { issue: 'invalid_format' };
  const labels = host.split('.');
  if (labels.length < 2 || labels.some((l) => l.length === 0 || l.length > 63))
    return { issue: 'invalid_format' };
  const tld = labels[labels.length - 1]!;
  if (!/^(?:[a-z]{2,63}|xn--[a-z0-9-]{1,59})$/.test(tld)) return { issue: 'invalid_format' };
  if (labels.some((l) => !/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/.test(l))) return { issue: 'invalid_format' };
  url.hash = '';
  const value = url.href;
  if (value.length > LINK_MAX_LENGTH) return { issue: 'too_long' };
  return { value };
}

const linkUrlSchema = z
  .string()
  .max(LINK_RAW_MAX)
  .transform((raw, ctx) => {
    const result = normalizeProfileLink(raw);
    if ('issue' in result) {
      ctx.addIssue({ code: 'custom', message: `url ${result.issue}`, params: { issue: result.issue } });
      return z.NEVER;
    }
    return result.value;
  });

const linkLabelSchema = z
  .string()
  .max(240)
  .transform((raw, ctx) => {
    const result = normalizeContentText(raw, LABEL_LIMITS);
    if ('issue' in result) {
      ctx.addIssue({ code: 'custom', message: `label ${result.issue}`, params: { issue: result.issue } });
      return z.NEVER;
    }
    return result.value === '' ? null : result.value;
  })
  .nullable();

/** `ProfileLinkInput` (strict). */
export const profileLinkInputSchema = z.strictObject({
  url: linkUrlSchema,
  label: linkLabelSchema.optional(),
});

/**
 * `UpdateMeRequest.links`: 0–3 links (an empty array clears them); the same link twice →
 * `links.<i>.url` / `invalid_value`.
 */
export const profileLinksSchema = z
  .array(profileLinkInputSchema)
  .max(MAX_PROFILE_LINKS)
  .superRefine((links, ctx) => {
    const seen = new Set<string>();
    links.forEach((link, i) => {
      if (seen.has(link.url)) {
        ctx.addIssue({
          code: 'custom',
          path: [i, 'url'],
          message: 'duplicate link',
          params: { issue: 'invalid_value' },
        });
      }
      seen.add(link.url);
    });
  });
export type ProfileLinkInput = z.output<typeof profileLinkInputSchema>;

/** `ProfileLink`. */
export interface ProfileLinkDto {
  id: string;
  url: string;
  label: string | null;
  platform: ProfileLinkPlatform;
}

export function profileLinkDto(row: { id: string; url: string; label: string | null }): ProfileLinkDto {
  return { id: row.id, url: row.url, label: row.label, platform: linkPlatform(row.url) };
}

/** The order links are read in. */
export const PROFILE_LINKS_SELECT = {
  orderBy: { position: 'asc' },
  select: { id: true, url: true, label: true },
} as const;

/** The gender a profile shows to others: only when the user chose to show it and named one. */
export function publicGender(gender: Gender | null, show: boolean): 'MALE' | 'FEMALE' | null {
  return show && (gender === 'MALE' || gender === 'FEMALE') ? gender : null;
}
