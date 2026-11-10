import { isIP } from 'node:net';
import { z } from 'zod';
import { normalizeContentText, type ContentTextLimits } from '../posts/content-text.js';
import { isCountryCode } from './country.js';

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

/**
 * `ProfileLinkPlatform`: the known domains the app opens without a warning. v1.118-social (D357): `WHATSAPP` and
 * `SNAPCHAT` added (additive; an older app reads them as `OTHER`).
 */
export type ProfileLinkPlatform =
  | 'INSTAGRAM'
  | 'TIKTOK'
  | 'YOUTUBE'
  | 'FACEBOOK'
  | 'X'
  | 'WHATSAPP'
  | 'SNAPCHAT'
  | 'OTHER';

/** At most 3 links per profile. */
export const MAX_PROFILE_LINKS = 3;
/**
 * v1.118-social (D357, owner: «تحت البايو ضع اشارة السوشل ميديا مثل انستقرام وفيسبوك وواتساب وسناب شات»): the app
 * owner's profile may hold up to 7 — his 3 as everyone's plus one per social platform of his page's icon row
 * (Instagram, Facebook, WhatsApp, Snapchat). Everyone else keeps 3 (`links` / `too_many`, checked in the service,
 * which knows who the caller is).
 */
export const MAX_FOUNDER_PROFILE_LINKS = 7;
/** D357: the platforms of the founder page's icon row, in its order (the same in RTL and LTR). */
export const FOUNDER_SOCIAL_PLATFORMS = ['INSTAGRAM', 'FACEBOOK', 'WHATSAPP', 'SNAPCHAT'] as const;
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
  // v1.118-social (D357).
  ['wa.me', 'WHATSAPP'],
  ['whatsapp.com', 'WHATSAPP'],
  ['snapchat.com', 'SNAPCHAT'],
];

/**
 * D357: a bare phone number for WhatsApp (`+966 50 123 4567`, `00966501234567`, `966-50-123-4567`): 8–15 digits in
 * international form, with an optional `+` or `00` and the usual separators — normalised to `https://wa.me/<digits>`
 * (WhatsApp's own click-to-chat form; no `+`, no zeros in front). Null when `raw` is not such a number.
 */
export function whatsAppLinkOf(raw: string): string | null {
  const t = raw.trim();
  if (!/^(?:\+|00)?[0-9][0-9 ().-]*[0-9]$/.test(t)) return null;
  let digits = t.replace(/[^0-9]/g, '');
  if (t.startsWith('00')) digits = digits.slice(2);
  if (digits.startsWith('0')) return null; // a national number: the country code is needed
  if (digits.length < 8 || digits.length > 15) return null;
  return `https://wa.me/${digits}`;
}

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
  const phone = whatsAppLinkOf(raw);
  const trimmed = phone ?? raw.trim();
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
 * `UpdateMeRequest.links`: 0–3 links (an empty array clears them; D357: up to 7 for the app owner, checked by the
 * service); the same link twice → `links.<i>.url` / `invalid_value`.
 */
export const profileLinksSchema = z
  .array(profileLinkInputSchema)
  .max(MAX_FOUNDER_PROFILE_LINKS)
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

/**
 * v1.85-social (D278b, owner 2026-11-05: «منشنات يضعها الشخص معاه لغاية ١٠», CONVENTIONS §10.99): the
 * profile tags shown as chips on the profile. At most 10, in the person's order.
 */
export const MAX_PROFILE_TAGS = 10;
/** A tag: one line, 1–24 code points after normalisation, §6 hygiene. */
export const PROFILE_TAG_MAX = 24;
const TAG_LIMITS: ContentTextLimits = { maxCodePoints: PROFILE_TAG_MAX, maxLineBreaks: 0, allowEmpty: false };

const profileTagSchema = z
  .string()
  .max(240)
  .transform((raw, ctx) => {
    const result = normalizeContentText(raw, TAG_LIMITS);
    if ('issue' in result) {
      ctx.addIssue({ code: 'custom', message: `tag ${result.issue}`, params: { issue: result.issue } });
      return z.NEVER;
    }
    return result.value;
  });

/**
 * `UpdateMeRequest.tags`: 0–10 tags, the whole set in order (an empty array clears them); the same tag
 * twice (ignoring case) → `tags.<i>` / `invalid_value`.
 */
export const profileTagsSchema = z
  .array(profileTagSchema)
  .max(MAX_PROFILE_TAGS)
  .superRefine((tags, ctx) => {
    const seen = new Set<string>();
    tags.forEach((tag, i) => {
      const key = tag.toLocaleLowerCase('en');
      if (seen.has(key)) {
        ctx.addIssue({
          code: 'custom',
          path: [i],
          message: 'duplicate tag',
          params: { issue: 'invalid_value' },
        });
      }
      seen.add(key);
    });
  });

/** The tags as read: the stored order, at most {@link MAX_PROFILE_TAGS} (the CHECK keeps them so). */
export function profileTagsOf(tags: readonly string[] | null | undefined): string[] {
  return (tags ?? []).slice(0, MAX_PROFILE_TAGS);
}

/**
 * v1.91-social (D292, owner 2026-11-06, CONVENTIONS §10.106): the icon the person chose for each tag, from a closed
 * set the app draws with its own icons (never emoji). `flag` carries a country: `flag:SA` (ISO 3166-1 alpha-2,
 * stored upper case; the app draws its bundled flag art). `default` is the plain chip.
 */
export const PROFILE_TAG_ICONS = [
  'default',
  'crown',
  'flag',
  'fire',
  'trophy',
  'gamepad',
  'music',
  'mic',
  'moon',
  'heart',
  'star',
  'gem',
  'camera',
  'book',
  'sport',
  'palette',
  'globe',
] as const;
export const DEFAULT_PROFILE_TAG_ICON = 'default';
const FLAG_ICON = /^flag:([A-Za-z]{2})$/;

/**
 * One `UpdateMeRequest.tagIcons` entry: a key of {@link PROFILE_TAG_ICONS} other than `flag`, or `flag:<country>`;
 * null means `default`. Anything else → `tagIcons.<i>` / `invalid_value`.
 */
const profileTagIconSchema = z
  .string()
  .max(24)
  .nullable()
  .transform((raw, ctx) => {
    if (raw === null) return DEFAULT_PROFILE_TAG_ICON;
    const flag = FLAG_ICON.exec(raw);
    if (flag) {
      const code = flag[1]!.toUpperCase();
      if (isCountryCode(code)) return `flag:${code}`;
    } else if (raw !== 'flag' && (PROFILE_TAG_ICONS as readonly string[]).includes(raw)) {
      return raw;
    }
    ctx.addIssue({ code: 'custom', message: 'unknown tag icon', params: { issue: 'invalid_value' } });
    return z.NEVER;
  });

/** `UpdateMeRequest.tagIcons`: one entry per tag of `tags` (the same length; checked with `tags`). */
export const profileTagIconsSchema = z.array(profileTagIconSchema).max(MAX_PROFILE_TAGS);

/** The icon of each tag as read: one per tag, `default` where none was chosen (rows before v1.91-social). */
export function profileTagIconsOf(
  tags: readonly string[] | null | undefined,
  icons: readonly string[] | null | undefined,
): string[] {
  return profileTagsOf(tags).map((_, i) => icons?.[i] ?? DEFAULT_PROFILE_TAG_ICON);
}

/**
 * The icons to store with `tags` when a request sets `tags` without `tagIcons` (an app before v1.91-social): each
 * tag keeps the icon it had (the same text, ignoring case), a new one is `default`.
 */
export function keptProfileTagIcons(
  tags: readonly string[],
  beforeTags: readonly string[],
  beforeIcons: readonly string[],
): string[] {
  const byText = new Map<string, string>();
  beforeTags.forEach((tag, i) => {
    const key = tag.toLocaleLowerCase('en');
    if (!byText.has(key)) byText.set(key, beforeIcons[i] ?? DEFAULT_PROFILE_TAG_ICON);
  });
  return tags.map((tag) => byText.get(tag.toLocaleLowerCase('en')) ?? DEFAULT_PROFILE_TAG_ICON);
}
