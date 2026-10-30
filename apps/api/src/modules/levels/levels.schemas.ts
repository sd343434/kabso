import { z } from 'zod';
import { LEVEL_CATEGORIES, LEVEL_CATEGORY_SLUGS, MAX_LEVELS } from './levels.constants.js';

// Request schemas of openapi v1.4-levels (DRAFT, CP-005). Strict objects: unknown fields fail
// with `unknown_field`.

const limitSchema = z
  .string()
  .regex(/^\d{1,4}$/)
  .transform(Number)
  .pipe(z.number().int().min(1).max(50));

const pageFields = {
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
};

export const pageQuerySchema = z.strictObject(pageFields);

export const myLevelsListQuerySchema = z.strictObject({
  category: z.enum(LEVEL_CATEGORY_SLUGS).optional(),
  ...pageFields,
});
export type MyLevelsListQuery = z.output<typeof myLevelsListQuerySchema>;

export const eventsQuerySchema = z.strictObject({
  status: z.enum(['PENDING', 'PROCESSED', 'SKIPPED', 'FAILED']).optional(),
  ...pageFields,
});

const categoryCode = z.string().pipe(z.enum(LEVEL_CATEGORIES));
const recalculation = z.string().pipe(z.enum(['PRESERVE_POINTS', 'RECOMPUTE_FROM_LEDGER']));
const POINTS = /^(0|[1-9][0-9]{0,18})$/;
const MAX_BIGINT = 9_223_372_036_854_775_807n;

const pointsAmount = z
  .string()
  .regex(POINTS)
  .refine((v) => BigInt(v) <= MAX_BIGINT, { params: { issue: 'too_big' } })
  .transform((v) => BigInt(v));

export const updateCategorySchema = z
  .strictObject({
    enabled: z.boolean().optional(),
    nameAr: z.string().trim().min(1).max(40).optional(),
    nameEn: z.string().trim().min(1).max(40).optional(),
    descriptionAr: z.string().trim().min(1).max(200).optional(),
    descriptionEn: z.string().trim().min(1).max(200).optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { params: { issue: 'required' } });

export const createVersionSchema = z.strictObject({
  copyFromVersionId: z.uuid().nullable().optional(),
});

export const versionInputSchema = z.strictObject({
  multiplier: z.string().regex(/^(0|[1-9][0-9]{0,6})(\.[0-9]{1,6})?$/),
  valueUnit: z.string().pipe(z.enum(['COIN'])),
  reversalPolicy: z.string().pipe(z.enum(['REVERSE_POINTS', 'KEEP_LEVEL'])),
  luckyGiftsCountAsSupport: z
    .boolean()
    .optional()
    .transform((v) => v ?? false),
  levels: z
    .array(
      z.strictObject({
        levelNumber: z.number().int().min(1).max(MAX_LEVELS),
        nameAr: z.string().trim().min(1).max(40),
        nameEn: z.string().trim().min(1).max(40),
        requiredPoints: pointsAmount,
        iconKey: z
          .string()
          .regex(/^[a-z0-9_]{1,64}$/)
          .nullable(),
      }),
    )
    .max(MAX_LEVELS),
});
export type VersionInputBody = z.output<typeof versionInputSchema>;

export const previewQuerySchema = z.strictObject({
  recalculation: recalculation.optional().transform((v) => v ?? 'PRESERVE_POINTS'),
});

export const publishSchema = z.strictObject({ recalculation });

export const recalculateSchema = z.strictObject({ category: categoryCode });

export const adjustmentSchema = z
  .strictObject({
    category: categoryCode,
    pointsDelta: z
      .string()
      .regex(/^-?[1-9][0-9]{0,18}$/)
      .refine((v) => BigInt(v) <= MAX_BIGINT && BigInt(v) >= -MAX_BIGINT, { params: { issue: 'too_big' } })
      .transform((v) => BigInt(v)),
    reason: z.string().trim().min(3).max(500),
    /** v1.46-levels (owner D169): marks a deduction as fraud — the only one that lowers the level. */
    fraud: z.boolean().default(false),
  })
  .refine((b) => !b.fraud || b.pointsDelta < 0n, {
    path: ['fraud'],
    params: { issue: 'fraud_needs_deduction' },
  });

export const reconciliationSchema = z.strictObject({
  mode: z.string().pipe(z.enum(['DRY_RUN', 'REPAIR'])),
  category: categoryCode
    .nullable()
    .optional()
    .transform((v) => v ?? null),
});

export const idempotencyKeySchema = z.uuid();
