/**
 * v1.131-social (D378, owner 2026-11-11, CONVENTIONS §10.168): the rules of the VIP identity perks that the server
 * keeps — the animated signature's text, the golden ID's numbers and classes, and which premium usernames the
 * PREMIUM_USERNAME perk lets a member claim. Pure (no Nest or database dependency; unit-tested in
 * `vip-identity.spec.ts`).
 */

import { VIP_GOLDEN_ID_CLASSES, VIP_PREMIUM_USERNAME_TIERS } from './vip-catalogue.js';

export type VipGoldenIdClass = (typeof VIP_GOLDEN_ID_CLASSES)[number];
export type VipPremiumClass = (typeof VIP_PREMIUM_USERNAME_TIERS)[number];

/** ANIMATED_SIGNATURE: 1 … 24 characters (code points), one line. */
export const VIP_SIGNATURE_MAX = 24;

/** A golden ID kept for its holder this many days after the membership (or the perk) ended. */
export const VIP_GOLDEN_ID_GRACE_DAYS = 7;

/** At most this many free numbers are offered to a holder at once, and added to the stock in one save. */
export const VIP_GOLDEN_ID_OFFER_MAX = 60;
export const VIP_GOLDEN_ID_ADD_MAX = 100;

/** A golden ID: 2 … 8 digits, never a leading 0. */
export const VIP_GOLDEN_ID_PATTERN = /^[1-9][0-9]{1,7}$/;

/** Line breaks, other control characters and invisible format characters (bidi controls, zero-width). */
// eslint-disable-next-line no-control-regex
const NOT_SHOWN = /[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2060-\u2069\uFEFF]/u;

/**
 * The signature as stored (NFC, trimmed, inner spaces collapsed), or the issue that keeps it out: `too_short` (empty
 * after trimming), `too_long` (over 24 characters), `invalid_format` (a line break, a control or an invisible format
 * character). Blocked words are the caller's check (they need the database).
 */
export function vipSignatureOf(raw: string): { ok: true; text: string } | { ok: false; issue: string } {
  if (NOT_SHOWN.test(raw)) return { ok: false, issue: 'invalid_format' };
  const text = raw.normalize('NFC').trim().replace(/\s+/gu, ' ');
  const length = [...text].length;
  if (length === 0) return { ok: false, issue: 'too_short' };
  if (length > VIP_SIGNATURE_MAX) return { ok: false, issue: 'too_long' };
  return { ok: true, text };
}

/**
 * The class of a golden ID, or null when [number] is not one: REPEATED — one digit repeated (2 … 8 long: `88`,
 * `777`, `8888`); otherwise by length THREE_DIGIT (`123`), FOUR_DIGIT (`2026`), FIVE_DIGIT (`12345`). Other lengths
 * are not golden IDs.
 */
export function vipGoldenIdClassOf(number: string): VipGoldenIdClass | null {
  if (!VIP_GOLDEN_ID_PATTERN.test(number)) return null;
  if (/^(\d)\1+$/.test(number)) return 'REPEATED';
  switch (number.length) {
    case 3:
      return 'THREE_DIGIT';
    case 4:
      return 'FOUR_DIGIT';
    case 5:
      return 'FIVE_DIGIT';
    default:
      return null;
  }
}

/** The perk value as a golden ID class, or null (not set, or not a class). */
export function vipGoldenIdClassValue(value: unknown): VipGoldenIdClass | null {
  return typeof value === 'string' && (VIP_GOLDEN_ID_CLASSES as readonly string[]).includes(value)
    ? (value as VipGoldenIdClass)
    : null;
}

/** The perk value as a premium username medal, or null (not set, or not a medal). */
export function vipPremiumClassValue(value: unknown): VipPremiumClass | null {
  return typeof value === 'string' && (VIP_PREMIUM_USERNAME_TIERS as readonly string[]).includes(value)
    ? (value as VipPremiumClass)
    : null;
}

/** The medals from the highest: LEGEND > RUBY > GOLD > SILVER (D146). */
const MEDAL_RANK: Readonly<Record<VipPremiumClass, number>> = { LEGEND: 4, RUBY: 3, GOLD: 2, SILVER: 1 };

/**
 * Whether the PREMIUM_USERNAME perk of class [perkClass] lets a member claim a name of medal [nameTier]: the class set
 * on the perk or any lower one (a GOLD perk also claims SILVER names).
 */
export function vipPremiumClaimAllows(perkClass: VipPremiumClass, nameTier: VipPremiumClass): boolean {
  return MEDAL_RANK[nameTier] <= MEDAL_RANK[perkClass];
}
