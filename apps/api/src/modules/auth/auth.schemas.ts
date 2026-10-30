import { z } from 'zod';
import { isCountryCode } from '../users/country.js';
import { regularUsernameIssue } from '../premium-usernames/premium-username-rules.js';
import { USERNAME_MAX_LENGTH, USERNAME_MIN_LENGTH, USERNAME_PATTERN } from '../users/username.js';
import { normalizeDisplayName, rawDisplayNameIssue } from '../users/display-name.js';
import { normalizeContentText, type ContentTextLimits } from '../posts/content-text.js';
import { passwordPolicyIssue } from './password-policy.js';
import { ACCOUNT_CATEGORIES, GENDERS, profileLinksSchema } from '../users/profile-fields.js';

// Request schemas mirror docs/contracts/openapi.yaml. All objects are strict
// (`additionalProperties: false`): unknown fields fail with `unknown_field`.

/**
 * Characters refused in free text (CONVENTIONS §6, SEC-008): C0/C1 controls and DEL, bidi
 * embedding/override (U+202A–U+202E) and isolate (U+2066–U+2069) controls, zero-width
 * characters (U+200B–U+200D, U+2060, U+FEFF).
 */
export const UNSAFE_TEXT_CHARS =
  // eslint-disable-next-line no-control-regex -- intentionally matching control characters
  /[\u0000-\u001f\u007f-\u009f\u200b-\u200d\u2060\u202a-\u202e\u2066-\u2069\ufeff]/;

/** Trimmed free-text field that rejects {@link UNSAFE_TEXT_CHARS} with `invalid_format`. */
export const safeText = (min: number, max: number) =>
  z
    .string()
    .trim()
    .min(min)
    .max(max)
    .refine((v) => !UNSAFE_TEXT_CHARS.test(v), {
      message: 'contains control, bidi or zero-width characters',
      params: { issue: 'invalid_format' },
    });

/** Passwords are compared and hashed in Unicode NFC (CONVENTIONS §6, SEC-016). */
export function normalizePassword(password: string): string {
  return password.normalize('NFC');
}

export const emailSchema = z.string().trim().toLowerCase().max(254).pipe(z.email());

export const passwordSchema = z
  .string()
  .transform(normalizePassword)
  .superRefine((value, ctx) => {
    const issue = passwordPolicyIssue(value);
    if (issue) ctx.addIssue({ code: 'custom', message: `password ${issue}`, params: { issue } });
  });

export const usernameSchema = z
  .string()
  .min(USERNAME_MIN_LENGTH)
  .max(USERNAME_MAX_LENGTH)
  .regex(USERNAME_PATTERN);

/**
 * v1.28-live (D146): a new regular username (registration, `PUT /me/username`): 6–30 of a–z, 0–9
 * and `_`, a letter and a digit, not premium. The first issue is reported on the field
 * (`premium`, `too_short`, `too_long`, `invalid_format`, `letters_and_digits`).
 */
export const regularUsernameSchema = z
  .string()
  .max(64)
  .superRefine((value, ctx) => {
    const issue = regularUsernameIssue(value);
    if (issue) ctx.addIssue({ code: 'custom', message: `username ${issue}`, params: { issue } });
  });

export const localeSchema = z.enum(['ar', 'en']);

export const deviceInfoSchema = z.strictObject({
  name: safeText(0, 100).optional(),
  platform: z.enum(['android', 'ios', 'web', 'other']).optional(),
  appVersion: safeText(0, 32).optional(),
});

/**
 * displayName (contract v1.2 §6): NFC + trim, 1–50 graphemes / ≤ 100 code points, joiner
 * placement, zalgo and content rules. Reserved terms need server configuration and are checked
 * by the registration service (`reserved_term`).
 */
export const displayNameSchema = z
  .string()
  .max(1000)
  .superRefine((raw, ctx) => {
    const issue = rawDisplayNameIssue(raw, []);
    if (issue) ctx.addIssue({ code: 'custom', message: `displayName ${issue}`, params: { issue } });
  })
  .transform(normalizeDisplayName);

export const registerSchema = z.strictObject({
  email: emailSchema,
  password: passwordSchema,
  username: regularUsernameSchema,
  displayName: displayNameSchema,
  // v1.47-social (D175): required (owner: chosen at sign-up; `UNDISCLOSED` = «أفضّل عدم الذكر»).
  gender: z.string().pipe(z.enum(GENDERS)),
  locale: localeSchema.optional(),
  device: deviceInfoSchema.optional(),
});
export type RegisterInput = z.output<typeof registerSchema>;

export const loginSchema = z.strictObject({
  // v1.28-live (D146): 1-character premium usernames sign in too.
  identifier: z.string().trim().min(1).max(254),
  // Length is checked in code points after NFC, so an NFD spelling of a valid password passes.
  password: z
    .string()
    .min(1)
    .max(512)
    .transform(normalizePassword)
    .refine((v) => [...v].length <= 128, { params: { issue: 'too_long' } }),
  device: deviceInfoSchema.optional(),
});
export type LoginInput = z.output<typeof loginSchema>;

const opaqueToken = z.string().min(10).max(200);

export const refreshSchema = z.strictObject({ refreshToken: opaqueToken });
export const verifyEmailSchema = z.strictObject({ token: opaqueToken });
export const forgotPasswordSchema = z.strictObject({ email: emailSchema });

/** 8-digit numeric registration code (contract v1.2 §6). */
export const registrationCodeSchema = z.string().regex(/^[0-9]{8}$/);

export const registerVerifySchema = z.strictObject({
  email: emailSchema,
  code: registrationCodeSchema,
  device: deviceInfoSchema.optional(),
});
export type RegisterVerifyInput = z.output<typeof registerVerifySchema>;

export const registerResendSchema = z.strictObject({ email: emailSchema });

/** v1.45-social (D168, CONVENTIONS §10.42): a bio — ≤ 300 code points, ≤ 4 line breaks, §6 hygiene. */
export const BIO_LIMITS: ContentTextLimits = { maxCodePoints: 300, maxLineBreaks: 4, allowEmpty: true };
/** Raw input bound checked before any normalisation work. */
export const BIO_RAW_MAX = 1200;

/** A bio after normalisation; an empty result is null (cleared). */
export const bioSchema = z
  .string()
  .max(BIO_RAW_MAX)
  .transform((raw, ctx) => {
    const result = normalizeContentText(raw, BIO_LIMITS);
    if ('issue' in result) {
      ctx.addIssue({ code: 'custom', message: `bio ${result.issue}`, params: { issue: result.issue } });
      return z.NEVER;
    }
    return result.value.length === 0 ? null : result.value;
  })
  .nullable();

/**
 * `PATCH /me`: v1.2 `locale`; v1.27.1-live (D133) `country` (ISO 3166-1 alpha-2, any case,
 * stored upper case; null clears it); v1.45-social (D168) `displayName` (the §6 registration rules;
 * reserved terms are checked by the service) and `bio` (null or empty clears it); v1.47-social (D175)
 * `gender`, `showGender`, `category` and `links`. At least one.
 */
export const updateMeSchema = z
  .strictObject({
    locale: localeSchema.optional(),
    country: z
      .string()
      .transform((v) => v.toUpperCase())
      .refine(isCountryCode, { params: { issue: 'invalid_value' } })
      .nullable()
      .optional(),
    displayName: displayNameSchema.optional(),
    bio: bioSchema.optional(),
    // v1.47-social (D175, CONVENTIONS §10.47): gender (never cleared once chosen), whether others see
    // it, the account category (null clears it) and the links (the whole set; [] clears them).
    gender: z.enum(GENDERS).optional(),
    showGender: z.boolean().optional(),
    category: z.enum(ACCOUNT_CATEGORIES).nullable().optional(),
    links: profileLinksSchema.optional(),
  })
  .superRefine((body, ctx) => {
    if (Object.values(body).every((v) => v === undefined)) {
      ctx.addIssue({
        code: 'custom',
        path: ['body'],
        params: { issue: 'required' },
        message: 'nothing to update',
      });
    }
  });
export const resetPasswordSchema = z.strictObject({ token: opaqueToken, newPassword: passwordSchema });

export type DeviceInfo = z.output<typeof deviceInfoSchema>;
