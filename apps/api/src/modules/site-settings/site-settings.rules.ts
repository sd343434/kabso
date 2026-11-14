import { z } from 'zod';

/**
 * The public website's settings (D191 + D192, one module; CONVENTIONS §10.54.6, used by the website of §10.55): the
 * footer's social links and the `topupEnabled` switch of the «شحن العملات» link. Kept free of Nest and Prisma so the
 * unit tests share one definition.
 *
 * One stored and served form for every link — a full https URL, or null (the site hides the icon):
 * `https://www.instagram.com/<handle>`, `https://www.tiktok.com/@<handle>`, `https://wa.me/<digits>`. Anything else
 * is refused (`invalid_value`), so the website never links to a host it does not expect. The website
 * (`infra/deploy/site/assets/common.js`) accepts exactly these shapes; the panel (`apps/admin`) sends what the owner
 * typed and shows what the server stored.
 */

export const SOCIAL_KEYS = ['instagram', 'tiktok', 'whatsapp'] as const;
export type SocialKey = (typeof SOCIAL_KEYS)[number];

/** The stored keys of `site_settings` (the migration's CHECK lists the same two). */
export const SETTING_KEYS = { socials: 'socials', topupEnabled: 'topupEnabled' } as const;

export interface SiteSettingsDto {
  socials: { instagram: string | null; tiktok: string | null; whatsapp: string | null };
  topupEnabled: boolean;
}

export const SITE_SETTINGS_DEFAULTS: SiteSettingsDto = {
  socials: { instagram: null, tiktok: null, whatsapp: null },
  topupEnabled: false,
};

/** `Cache-Control` of `GET /site/settings`: the website reads it at every load. */
export const SITE_SETTINGS_CACHE_CONTROL = 'public, max-age=60';

const MAX_INPUT = 200;

/** Parses an absolute https URL on one of `hosts`; null when it is not one. */
function httpsUrl(input: string, hosts: readonly string[]): URL | null {
  let url: URL;
  try {
    url = new URL(input);
  } catch {
    return null;
  }
  if (url.protocol !== 'https:' || url.username !== '' || url.password !== '' || url.port !== '') return null;
  if (!hosts.includes(url.hostname.toLowerCase())) return null;
  return url;
}

/** The path's segments without empty ones (a trailing slash is allowed). */
function segments(url: URL): string[] {
  return url.pathname.split('/').filter((s) => s !== '');
}

const INSTAGRAM_HANDLE = /^(?!.*\.\.)[A-Za-z0-9._]{1,30}$/;
const TIKTOK_HANDLE = /^[A-Za-z0-9._]{2,24}$/;
const PHONE_DIGITS = /^[1-9][0-9]{7,14}$/;

/** `https://(www.)instagram.com/<handle>` → `https://www.instagram.com/<handle>`; else null. */
export function normalizeInstagram(input: string): string | null {
  const url = httpsUrl(input.trim(), ['instagram.com', 'www.instagram.com']);
  if (!url) return null;
  const parts = segments(url);
  if (parts.length !== 1 || !INSTAGRAM_HANDLE.test(parts[0]!)) return null;
  return `https://www.instagram.com/${parts[0]}`;
}

/** `https://(www.)tiktok.com/@<handle>` → `https://www.tiktok.com/@<handle>`; else null. */
export function normalizeTiktok(input: string): string | null {
  const url = httpsUrl(input.trim(), ['tiktok.com', 'www.tiktok.com']);
  if (!url) return null;
  const parts = segments(url);
  if (parts.length !== 1 || !parts[0]!.startsWith('@')) return null;
  const handle = parts[0]!.slice(1);
  if (!TIKTOK_HANDLE.test(handle)) return null;
  return `https://www.tiktok.com/@${handle}`;
}

/**
 * WhatsApp is a number: `https://wa.me/<digits>` or the number itself in international form (`+966500000000`,
 * spaces, dashes and brackets allowed) → `https://wa.me/<digits>` (8–15 digits, no leading 0); else null.
 */
export function normalizeWhatsapp(input: string): string | null {
  const trimmed = input.trim();
  let digits: string;
  if (/^\+?[0-9][0-9 ()-]*$/.test(trimmed)) {
    digits = trimmed.replace(/[^0-9]/g, '');
  } else {
    const url = httpsUrl(trimmed, ['wa.me']);
    if (!url || url.search !== '' || url.hash !== '') return null;
    const parts = segments(url);
    if (parts.length !== 1) return null;
    digits = parts[0]!;
  }
  return PHONE_DIGITS.test(digits) ? `https://wa.me/${digits}` : null;
}

const NORMALIZERS: Record<SocialKey, (input: string) => string | null> = {
  instagram: normalizeInstagram,
  tiktok: normalizeTiktok,
  whatsapp: normalizeWhatsapp,
};

/**
 * A social link from the request: a string to normalize, `null` or `''` to remove it (→ null). `undefined`: the
 * value is not a valid link for that network.
 */
export function normalizeSocial(key: SocialKey, input: string | null): string | null | undefined {
  if (input === null || input.trim() === '') return null;
  if (input.length > MAX_INPUT) return undefined;
  return NORMALIZERS[key](input) ?? undefined;
}

/**
 * A stored value read back (a row written by hand or by an older rule is re-checked: a link that no longer
 * passes is not shown).
 */
export function storedSocial(key: SocialKey, value: unknown): string | null {
  if (typeof value !== 'string') return null;
  return normalizeSocial(key, value) ?? null;
}

const link = (key: SocialKey) =>
  z
    .string()
    .max(MAX_INPUT)
    .nullable()
    .transform((v, ctx) => {
      const out = normalizeSocial(key, v);
      if (out === undefined) {
        ctx.addIssue({
          code: 'custom',
          message: 'not a link of the expected form',
          params: { issue: 'invalid_value' },
        });
        return z.NEVER;
      }
      return out;
    });

/** `PUT /admin/site-settings` (the whole document; an empty link clears it; `reason` goes to the audit row). */
export const updateSiteSettingsSchema = z.strictObject({
  socials: z.strictObject({
    instagram: link('instagram'),
    tiktok: link('tiktok'),
    whatsapp: link('whatsapp'),
  }),
  topupEnabled: z.boolean(),
  reason: z.string().trim().min(1).max(500).optional(),
});
export type UpdateSiteSettingsInput = z.output<typeof updateSiteSettingsSchema>;
