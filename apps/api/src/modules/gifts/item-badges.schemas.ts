import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import {
  ITEM_BADGE_PRIORITY,
  resolveItemBadges,
  type ItemBadgeInput,
  type ItemBadgeSetting,
} from './item-badges.js';

/**
 * v1.79-live (D289, §10.102): `badges` in the panel's gift and store item bodies — the whole set (an empty list takes
 * every badge off). The shape is checked here (400 `VALIDATION_FAILED`); the rules (the two sound badges, the ends)
 * by `resolveItemBadges` (400 `ITEM_BADGES_INVALID`).
 */
export const itemBadgesInput = z
  .array(
    z.strictObject({
      code: z.enum(ITEM_BADGE_PRIORITY),
      until: z.iso.datetime({ offset: true }).nullable().optional(),
    }),
  )
  .max(ITEM_BADGE_PRIORITY.length);

/**
 * v1.79-live (D289, §10.102): the panel's badges checked and their ends fixed (NEW without a date: 14 days from now);
 * 400 `ITEM_BADGES_INVALID` with the details on a broken rule (the two sound badges, a missing or past end). Absent:
 * undefined (unchanged).
 */
export function panelBadges(
  input: readonly ItemBadgeInput[] | undefined,
  now: Date,
): ItemBadgeSetting[] | undefined {
  if (input === undefined) return undefined;
  const { settings, problems } = resolveItemBadges(input, now);
  if (problems.length > 0) throw new AppException(ErrorCode.ITEM_BADGES_INVALID, undefined, problems);
  return settings;
}
