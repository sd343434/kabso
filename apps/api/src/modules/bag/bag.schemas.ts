import { z } from 'zod';
import { BAG_CATEGORIES, type BagCategory } from './bag.catalogue.js';

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
