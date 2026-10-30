import { z } from 'zod';
import { BAG_CATEGORIES, BAG_MAX_DAYS, type BagCategory } from './bag.catalogue.js';

const categorySchema = z.enum(BAG_CATEGORIES as [BagCategory, ...BagCategory[]]);

/** `GET /bag/catalogue` and `GET /me/bag`: `?category=` (optional; all categories when absent). */
export const bagQuerySchema = z.strictObject({
  category: categorySchema.optional(),
});
export type BagQuery = z.output<typeof bagQuerySchema>;

/** `PUT /me/bag/equipped` (strict): `{category, code}`; `code: null` takes the item off. */
export const equipBodySchema = z.strictObject({
  category: categorySchema,
  code: z.string().min(1).max(40).nullable(),
});
export type EquipBody = z.output<typeof equipBodySchema>;

/**
 * `POST /me/bag/transfers` (strict, v1.48-social, D171): `{code, username, days?}`; `days` absent or
 * null sends the whole item.
 */
export const sendBodySchema = z.strictObject({
  code: z.string().min(1).max(40),
  username: z.string().min(1).max(30),
  days: z.number().int().min(1).max(BAG_MAX_DAYS).nullable().optional(),
});
export type SendBody = z.output<typeof sendBodySchema>;
