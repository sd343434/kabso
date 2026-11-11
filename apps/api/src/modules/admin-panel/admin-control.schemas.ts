import { z } from 'zod';
import { bioSchema, displayNameSchema, emailSchema } from '../auth/auth.schemas.js';
import { isCountryCode } from '../users/country.js';
import { GENDERS } from '../users/profile-fields.js';
import { MAX_RESTRICTION_DAYS, RESTRICTION_KINDS } from '../users/account-control.js';

/**
 * Request bodies of the account controls (v1.72-social, D208, CONVENTIONS §10.67; openapi tag `admin-panel`). Every
 * change carries a reason; a destructive or money action the authenticator code again (`totpCode`).
 */

const reason = z.string().trim().min(1).max(500);
const totpCode = z.string().regex(/^[0-9]{6}$/);

/** Either a number of days (1, 3, 7, 30 … up to a year) or an end date-time. */
const duration = {
  days: z.number().int().min(1).max(MAX_RESTRICTION_DAYS).optional(),
  until: z.iso.datetime({ offset: true }).optional(),
};
function oneEnd(v: { days?: number | undefined; until?: string | undefined }) {
  return (v.days === undefined) !== (v.until === undefined);
}

export const lockBody = z
  .strictObject({ ...duration, reason })
  .refine(oneEnd, { message: 'exactly one of days or until', path: ['days'] });

export const restrictBody = z
  .strictObject({ kind: z.enum(RESTRICTION_KINDS), ...duration, reason })
  .refine(oneEnd, { message: 'exactly one of days or until', path: ['days'] });

export const liftBody = z.strictObject({ kind: z.enum(['LOCK', ...RESTRICTION_KINDS]), reason });

export const reasonOnlyBody = z.strictObject({ reason });
export const reasonCodeBody = z.strictObject({ reason, totpCode });
/**
 * v1.78-live (D288, owner «يلغي»): deleting a post or a story for good no longer needs the authenticator code;
 * `totpCode` is still accepted (and ignored) so a panel built before D288 keeps working.
 */
export const contentDeleteBody = z.strictObject({ reason, totpCode: totpCode.optional() });
/**
 * v1.78-live (D288, owner: «نعم» — the code goes from account deletion too): starting an account's deletion needs the
 * reason only; `totpCode` is still accepted (and ignored) so a panel built before D288 keeps working.
 */
export const deletionRequestBody = contentDeleteBody;

export const requireChangeBody = z.strictObject({
  reason,
  /** End every session now (default true), so the next sign-in comes at once. */
  endSessions: z.boolean().default(true),
});

export const profileEditBody = z
  .strictObject({
    displayName: displayNameSchema.optional(),
    /** The new regular username (the D146 rule, canonical: lower case). */
    username: z.string().min(1).max(64).optional(),
    bio: bioSchema.optional(),
    country: z
      .string()
      .transform((v) => v.toUpperCase())
      .refine(isCountryCode, { params: { issue: 'invalid_value' } })
      .nullable()
      .optional(),
    gender: z.enum(GENDERS).optional(),
    reason,
  })
  .refine(
    (v) =>
      v.displayName !== undefined ||
      v.username !== undefined ||
      v.bio !== undefined ||
      v.country !== undefined ||
      v.gender !== undefined,
    { message: 'nothing to change', path: ['body'], params: { issue: 'required' } },
  );

export const emailChangeBody = z.strictObject({
  email: emailSchema,
  /** OWNER only: mark the new address verified instead of sending a verification link to it. */
  markVerified: z.boolean().default(false),
  reason,
  totpCode,
});

export const CONTENT_TYPES = ['post', 'story', 'comment'] as const;
export type ContentType = (typeof CONTENT_TYPES)[number];

export const adjustBody = z.strictObject({
  currency: z.enum(['COINS', 'CHERRIES']),
  direction: z.enum(['CREDIT', 'DEBIT']),
  /** Whole units as a decimal string (1 … 10^9). */
  amount: z.string().regex(/^[1-9][0-9]{0,9}$/),
  /** OWNER only: a debit may take the balance below 0 (a reversal). */
  allowNegative: z.boolean().default(false),
  reason,
  totpCode,
});

/**
 * v1.126-social (D370, §10.162): `AdminRechargePointsAdjustRequest` — like a coin adjustment (TOTP, reason; a debit
 * below 0 only with `allowNegative`, OWNER).
 */
export const rechargePointsAdjustBody = z.strictObject({
  direction: z.enum(['CREDIT', 'DEBIT']),
  /** Whole points as a decimal string (1 … 10^12). */
  amount: z.string().regex(/^[1-9][0-9]{0,12}$/),
  allowNegative: z.boolean().default(false),
  reason,
  totpCode,
});

export const userContentQuery = z.strictObject({
  kind: z.enum(['stories', 'comments']),
  page: z.coerce.number().int().min(1).max(10_000).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(10),
});
