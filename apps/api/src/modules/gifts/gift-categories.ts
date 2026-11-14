import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { GiftCategory, Prisma } from '../../generated/prisma/client.js';
import { GIFT_CATEGORY_CODE_PATTERN } from './gift-catalogue.js';

/**
 * v1.46-live / v1.71-social (D207, owner 2026-10-31, CONVENTIONS §10.66): the gift categories — the gift panel's
 * tabs — managed in the admin panel («الهدايا» → «التصنيفات», capability `gifts.categories`) and with `gift-admin
 * category-*`. Shared by both (no Nest dependencies); every change runs in the caller's transaction and writes its
 * audit row with `via`, the actor and the reason.
 *
 * Rules: a new category is NORMAL (the special LUCKY and QUIPS exist once each, seeded); `code` never changes; a
 * special category may be renamed, reordered and given an icon, never disabled or deleted; a category with gifts in
 * it is deleted only by moving its gifts to another NORMAL category first, in the same transaction.
 */

type Tx = Prisma.TransactionClient;

/** Names: 1–30 characters after trimming (`gift_categories_names`, like a tag chip). */
export const GIFT_CATEGORY_NAME_MAX = 30;
export const GIFT_CATEGORY_SORT_MAX = 1_000_000;
/** `gift_categories_icon_key_format`. */
export const GIFT_CATEGORY_ICON_KEY_PATTERN =
  /^media\/gift-categories\/[A-Z][A-Z0-9_]{0,39}\/[0-9a-f]{32}\.(png|webp)$/;

/** A refused category change; the message says why (for the operator). `reason` tells the panel which one. */
export class GiftCategoryError extends Error {
  constructor(
    message: string,
    readonly reason: 'exists' | 'special' | 'not_empty' | 'bad_target' | 'invalid',
    readonly giftCount = 0,
  ) {
    super(message);
  }
}

export interface GiftCategoryFields {
  readonly nameAr: string;
  readonly nameEn: string;
  readonly sortOrder: number;
  readonly iconObjectKey?: string | null;
}

/** Every problem with a category's fields (empty: valid). Partial input checks only what is given. */
export function giftCategoryFieldProblems(fields: Partial<GiftCategoryFields> & { code?: string }): string[] {
  const problems: string[] = [];
  if (fields.code !== undefined && !GIFT_CATEGORY_CODE_PATTERN.test(fields.code)) {
    problems.push('code must be 1–40 characters: A-Z, 0-9 and _, starting with a letter');
  }
  for (const [key, value] of [
    ['nameAr', fields.nameAr],
    ['nameEn', fields.nameEn],
  ] as const) {
    if (value !== undefined && (value.trim().length === 0 || value.trim().length > GIFT_CATEGORY_NAME_MAX)) {
      problems.push(`${key} must be 1–${String(GIFT_CATEGORY_NAME_MAX)} characters`);
    }
  }
  if (
    fields.sortOrder !== undefined &&
    (!Number.isInteger(fields.sortOrder) || fields.sortOrder < 0 || fields.sortOrder > GIFT_CATEGORY_SORT_MAX)
  ) {
    problems.push(`sortOrder must be a whole number from 0 to ${String(GIFT_CATEGORY_SORT_MAX)}`);
  }
  if (
    fields.iconObjectKey !== undefined &&
    fields.iconObjectKey !== null &&
    !GIFT_CATEGORY_ICON_KEY_PATTERN.test(fields.iconObjectKey)
  ) {
    problems.push('icon must be an uploaded category icon');
  }
  return problems;
}

function assertValid(fields: Partial<GiftCategoryFields> & { code?: string }): void {
  const problems = giftCategoryFieldProblems(fields);
  if (problems.length > 0) throw new GiftCategoryError(problems.join('; '), 'invalid');
}

/** The categories in tab order (sort order, then code), each with how many gifts it holds (enabled or not). */
export async function giftCategoriesWithCounts(
  db: Pick<Tx, 'giftCategory' | 'gift'>,
): Promise<(GiftCategory & { gifts: number; enabledGifts: number })[]> {
  const [rows, counts, enabledCounts] = await Promise.all([
    db.giftCategory.findMany({ orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }] }),
    db.gift.groupBy({ by: ['category'], _count: true }),
    db.gift.groupBy({ by: ['category'], where: { enabled: true }, _count: true }),
  ]);
  const all = new Map(counts.map((c) => [c.category, c._count]));
  const on = new Map(enabledCounts.map((c) => [c.category, c._count]));
  return rows.map((r) => ({ ...r, gifts: all.get(r.code) ?? 0, enabledGifts: on.get(r.code) ?? 0 }));
}

/** Adds a NORMAL category (enabled unless `enabled: false`). Throws `exists` when the code is taken. */
export async function addGiftCategoryIn(
  tx: Tx,
  code: string,
  fields: GiftCategoryFields & { enabled?: boolean },
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
): Promise<GiftCategory> {
  assertValid({ ...fields, code });
  const inserted = await tx.giftCategory.createManyAndReturn({
    data: [
      {
        code,
        kind: 'NORMAL',
        nameAr: fields.nameAr.trim(),
        nameEn: fields.nameEn.trim(),
        sortOrder: fields.sortOrder,
        enabled: fields.enabled ?? true,
        iconObjectKey: fields.iconObjectKey ?? null,
      },
    ],
    skipDuplicates: true,
  });
  const row = inserted[0];
  if (!row) throw new GiftCategoryError(`A gift category ${code} exists already.`, 'exists');
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.GIFT_CATEGORY_ADD,
      targetType: 'gift_category',
      targetId: code,
      metadata: {
        nameAr: row.nameAr,
        nameEn: row.nameEn,
        sortOrder: row.sortOrder,
        enabled: row.enabled,
        iconObjectKey: row.iconObjectKey,
        ...(reason ? { reason } : {}),
        via: by.via,
      },
    },
  });
  return row;
}

/** Changes names / order / icon; the changed keys (empty: nothing changed), or null when there is no such category. */
export async function updateGiftCategoryIn(
  tx: Tx,
  code: string,
  fields: Partial<GiftCategoryFields>,
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
): Promise<string[] | null> {
  assertValid(fields);
  const before = await tx.giftCategory.findUnique({ where: { code } });
  if (!before) return null;
  const data = {
    ...(fields.nameAr !== undefined ? { nameAr: fields.nameAr.trim() } : {}),
    ...(fields.nameEn !== undefined ? { nameEn: fields.nameEn.trim() } : {}),
    ...(fields.sortOrder !== undefined ? { sortOrder: fields.sortOrder } : {}),
    ...(fields.iconObjectKey !== undefined ? { iconObjectKey: fields.iconObjectKey } : {}),
  };
  const changes: Record<string, { from: string | number | null; to: string | number | null }> = {};
  for (const [key, to] of Object.entries(data) as [keyof typeof data, string | number | null][]) {
    if (before[key] !== to) changes[key] = { from: before[key] ?? null, to };
  }
  if (Object.keys(changes).length === 0) return [];
  await tx.giftCategory.update({ where: { code }, data });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.GIFT_CATEGORY_UPDATE,
      targetType: 'gift_category',
      targetId: code,
      metadata: { changes, kind: before.kind, ...(reason ? { reason } : {}), via: by.via },
    },
  });
  return Object.keys(changes);
}

/**
 * Enables or disables a NORMAL category (a disabled one is not a tab and its gifts are neither listed nor sendable);
 * whether it changed, or null when there is no such category. A special category refuses (`special`).
 */
export async function setGiftCategoryEnabledIn(
  tx: Tx,
  code: string,
  enabled: boolean,
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
): Promise<boolean | null> {
  const row = await tx.giftCategory.findUnique({ where: { code } });
  if (!row) return null;
  if (row.kind !== 'NORMAL') {
    throw new GiftCategoryError(
      `${code} is a special category (${row.kind}); it can be renamed or reordered, not turned off.`,
      'special',
    );
  }
  if (row.enabled === enabled) return false;
  await tx.giftCategory.update({ where: { code }, data: { enabled } });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: enabled ? AuditAction.GIFT_CATEGORY_ENABLE : AuditAction.GIFT_CATEGORY_DISABLE,
      targetType: 'gift_category',
      targetId: code,
      metadata: {
        before: enabled ? 'disabled' : 'enabled',
        after: enabled ? 'enabled' : 'disabled',
        ...(reason ? { reason } : {}),
        via: by.via,
      },
    },
  });
  return true;
}

/**
 * Deletes a NORMAL category. With gifts in it, refused (`not_empty`, with the count) unless `moveTo` names another
 * NORMAL category: its gifts move there first (one audited delete row lists them), in this transaction. Returns the
 * codes of the moved gifts, or null when there is no such category. The category row is locked first, so a gift
 * added to it meanwhile waits and then fails on the FK instead of being orphaned.
 */
export async function deleteGiftCategoryIn(
  tx: Tx,
  code: string,
  moveTo: string | null,
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
): Promise<{ moved: string[] } | null> {
  const locked = await tx.$queryRaw<{ kind: string; icon_object_key: string | null }[]>`
    SELECT kind::text AS kind, icon_object_key FROM gift_categories WHERE code = ${code} FOR UPDATE`;
  const row = locked[0];
  if (!row) return null;
  if (row.kind !== 'NORMAL') {
    throw new GiftCategoryError(
      `${code} is a special category (${row.kind}); it cannot be deleted.`,
      'special',
    );
  }
  const gifts = await tx.gift.findMany({
    where: { category: code },
    select: { code: true },
    orderBy: { code: 'asc' },
  });
  if (gifts.length > 0 && moveTo === null) {
    throw new GiftCategoryError(
      `${code} has ${String(gifts.length)} gift(s); move them to another category first.`,
      'not_empty',
      gifts.length,
    );
  }
  if (gifts.length > 0 && moveTo !== null) {
    if (moveTo === code) throw new GiftCategoryError('Move the gifts to another category.', 'bad_target');
    const target = await tx.giftCategory.findUnique({ where: { code: moveTo } });
    if (!target) throw new GiftCategoryError(`There is no gift category ${moveTo}.`, 'bad_target');
    if (target.kind !== 'NORMAL') {
      throw new GiftCategoryError(
        `Gifts cannot be moved into the special category ${moveTo} (${target.kind}).`,
        'bad_target',
      );
    }
    await tx.gift.updateMany({ where: { category: code }, data: { category: moveTo } });
  }
  await tx.giftCategory.delete({ where: { code } });
  const moved = gifts.map((g) => g.code);
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.GIFT_CATEGORY_DELETE,
      targetType: 'gift_category',
      targetId: code,
      metadata: {
        movedTo: moved.length > 0 ? moveTo : null,
        movedGifts: moved,
        iconObjectKey: row.icon_object_key,
        ...(reason ? { reason } : {}),
        via: by.via,
      },
    },
  });
  return { moved };
}
