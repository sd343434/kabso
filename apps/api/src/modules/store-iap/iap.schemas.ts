import { z } from 'zod';
import { deviceInfoSchema } from '../auth/auth.schemas.js';

/** v1.110-social (D345, CONVENTIONS §10.144): request schemas (strict, mirroring openapi). */

export const appPlatformSchema = z.enum(['ANDROID', 'IOS']);
export const productIdSchema = z.string().regex(/^[A-Za-z0-9._]{1,150}$/);

export const iapCatalogQuery = z.strictObject({ platform: appPlatformSchema });

export const iapConsentSchema = z.strictObject({
  /** «أوافق على سياسة عدم الاسترداد» ticked. */
  accepted: z.literal(true),
  version: z.string().min(1).max(32),
  /** «أوافق على مشاركة بيانات الاستخدام مع Apple/Google عند طلب استرداد» (part of the same consent). */
  shareConsumptionData: z.boolean(),
});

export const verifyIapSchema = z
  .strictObject({
    platform: appPlatformSchema,
    productId: productIdSchema,
    purchaseToken: z.string().min(1).max(4096).optional(),
    signedTransaction: z.string().min(1).max(64_000).optional(),
    consent: iapConsentSchema,
    device: deviceInfoSchema.optional(),
  })
  .superRefine((v, ctx) => {
    if (v.platform === 'ANDROID' && (v.purchaseToken === undefined || v.signedTransaction !== undefined)) {
      ctx.addIssue({ code: 'custom', path: ['purchaseToken'], message: 'required on ANDROID (and only it)' });
    }
    if (v.platform === 'IOS' && (v.signedTransaction === undefined || v.purchaseToken !== undefined)) {
      ctx.addIssue({ code: 'custom', path: ['signedTransaction'], message: 'required on IOS (and only it)' });
    }
  });
export type VerifyIapInput = z.output<typeof verifyIapSchema>;

export const appleNotificationSchema = z.object({ signedPayload: z.string().min(1).max(200_000) });

export const googleRtdnSchema = z.object({
  message: z.object({
    data: z.string().max(100_000).optional(),
    messageId: z.string().min(1).max(200).optional(),
    message_id: z.string().min(1).max(200).optional(),
  }),
  subscription: z.string().max(500).optional(),
});

// ---- the panel --------------------------------------------------------------------------------------------------

const reason = z.string().trim().min(1).max(500);

export const iapProductCreateBody = z.strictObject({
  platform: z.enum(['GOOGLE_PLAY', 'APP_STORE']),
  productId: productIdSchema,
  coins: z.number().int().min(1).max(1_000_000_000_000),
  referenceUsdCents: z.number().int().min(1).max(100_000_000).nullable().optional(),
  sortOrder: z.number().int().min(-100_000).max(100_000).optional(),
  enabled: z.boolean().optional(),
  reason,
});
export type IapProductCreateBody = z.output<typeof iapProductCreateBody>;

export const iapProductUpdateBody = z
  .strictObject({
    coins: z.number().int().min(1).max(1_000_000_000_000).optional(),
    referenceUsdCents: z.number().int().min(1).max(100_000_000).nullable().optional(),
    sortOrder: z.number().int().min(-100_000).max(100_000).optional(),
    enabled: z.boolean().optional(),
    reason,
  })
  .refine((v) => Object.keys(v).some((k) => k !== 'reason'), { message: 'nothing to change' });
export type IapProductUpdateBody = z.output<typeof iapProductUpdateBody>;

export const iapSettingsBody = z.strictObject({ oncePerAccountDevice: z.boolean(), reason });

export const iapUnbanBody = z
  .strictObject({
    account: z.boolean(),
    device: z.boolean(),
    reason,
    totpCode: z
      .string()
      .regex(/^[0-9]{6}$/)
      .optional(),
  })
  .refine((v) => v.account || v.device, { message: 'account or device' });
export type IapUnbanBody = z.output<typeof iapUnbanBody>;
