import { z } from 'zod';
import { USERNAME_MAX_LENGTH, USERNAME_MIN_LENGTH, USERNAME_PATTERN } from '../users/username.js';
import { passwordPolicyIssue } from './password-policy.js';

// Request schemas mirror docs/contracts/openapi.yaml. All objects are strict
// (`additionalProperties: false`): unknown fields fail with `unknown_field`.

// eslint-disable-next-line no-control-regex -- intentionally matching control characters
const CONTROL_CHARS = /[\u0000-\u001f\u007f]/;

export const emailSchema = z.string().trim().toLowerCase().max(254).pipe(z.email());

export const passwordSchema = z.string().superRefine((value, ctx) => {
  const issue = passwordPolicyIssue(value);
  if (issue) ctx.addIssue({ code: 'custom', message: `password ${issue}`, params: { issue } });
});

export const usernameSchema = z
  .string()
  .min(USERNAME_MIN_LENGTH)
  .max(USERNAME_MAX_LENGTH)
  .regex(USERNAME_PATTERN);

export const localeSchema = z.enum(['ar', 'en']);

export const deviceInfoSchema = z.strictObject({
  name: z.string().trim().max(100).optional(),
  platform: z.enum(['android', 'ios', 'web', 'other']).optional(),
  appVersion: z.string().trim().max(32).optional(),
});

export const registerSchema = z.strictObject({
  email: emailSchema,
  password: passwordSchema,
  username: usernameSchema,
  displayName: z
    .string()
    .trim()
    .min(1)
    .max(50)
    .refine((v) => !CONTROL_CHARS.test(v), { params: { issue: 'invalid_format' } }),
  locale: localeSchema.optional(),
  device: deviceInfoSchema.optional(),
});
export type RegisterInput = z.output<typeof registerSchema>;

export const loginSchema = z.strictObject({
  identifier: z.string().trim().min(3).max(254),
  password: z.string().min(1).max(128),
  device: deviceInfoSchema.optional(),
});
export type LoginInput = z.output<typeof loginSchema>;

const opaqueToken = z.string().min(10).max(200);

export const refreshSchema = z.strictObject({ refreshToken: opaqueToken });
export const verifyEmailSchema = z.strictObject({ token: opaqueToken });
export const forgotPasswordSchema = z.strictObject({ email: emailSchema });
export const resetPasswordSchema = z.strictObject({ token: opaqueToken, newPassword: passwordSchema });

export type DeviceInfo = z.output<typeof deviceInfoSchema>;
