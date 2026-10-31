import { z } from 'zod';

/**
 * The public website's settings (v1.60-social, D191 + D192, CONVENTIONS §10.54.6): the footer's social links and the
 * `topupEnabled` switch of the «شحن العملات» link. Every link is stored and served as a full https URL on its own
 * host, or null (the site hides the icon).
 */
export interface SiteSettingsDto {
  socials: { instagram: string | null; tiktok: string | null; whatsapp: string | null };
  topupEnabled: boolean;
}

export const SITE_SETTINGS_DEFAULTS: SiteSettingsDto = {
  socials: { instagram: null, tiktok: null, whatsapp: null },
  topupEnabled: false,
};

function httpsOn(hosts: readonly string[], path: RegExp) {
  return (raw: string): string | null => {
    let url: URL;
    try {
      url = new URL(raw.trim());
    } catch {
      return null;
    }
    if (url.protocol !== 'https:' || url.username || url.password || url.port) return null;
    const host = url.hostname.toLowerCase();
    if (!hosts.includes(host) || !path.test(url.pathname)) return null;
    return `https://${host}${url.pathname.replace(/\/+$/, '')}`;
  };
}

/** `https://instagram.com/<name>` (also www.). */
export const instagramUrl = httpsOn(['instagram.com', 'www.instagram.com'], /^\/[A-Za-z0-9._]{1,30}\/?$/);
/** `https://www.tiktok.com/@<name>`. */
export const tiktokUrl = httpsOn(['tiktok.com', 'www.tiktok.com'], /^\/@[A-Za-z0-9._]{2,24}\/?$/);

/** A WhatsApp number (`+9665…`, digits, or `https://wa.me/9665…`) → `https://wa.me/<8–15 digits>`. */
export function whatsappUrl(raw: string): string | null {
  const v = raw.trim();
  const m =
    /^https:\/\/wa\.me\/([0-9]{8,15})\/?$/.exec(v) ?? /^\+?([0-9]{8,15})$/.exec(v.replace(/[\s()-]/g, ''));
  if (!m?.[1] || m[1].startsWith('0')) return null;
  return `https://wa.me/${m[1]}`;
}

const link = (normalize: (v: string) => string | null, issue: string) =>
  z
    .string()
    .max(200)
    .nullable()
    .transform((v, ctx) => {
      if (v === null || v.trim() === '') return null;
      const out = normalize(v);
      if (out === null) {
        ctx.addIssue({ code: 'custom', message: issue });
        return z.NEVER;
      }
      return out;
    });

/** `PUT /admin/site-settings` (the whole document; an empty link clears it). */
export const updateSiteSettingsSchema = z.strictObject({
  socials: z.strictObject({
    instagram: link(instagramUrl, 'an https://instagram.com/<name> link'),
    tiktok: link(tiktokUrl, 'an https://www.tiktok.com/@<name> link'),
    whatsapp: link(
      whatsappUrl,
      'a WhatsApp number in international form (+…) or an https://wa.me/<number> link',
    ),
  }),
  topupEnabled: z.boolean(),
  reason: z.string().trim().min(1).max(500).optional(),
});
export type UpdateSiteSettingsInput = z.output<typeof updateSiteSettingsSchema>;
