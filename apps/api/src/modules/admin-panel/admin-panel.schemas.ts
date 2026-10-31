import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { isUuid } from '../live/live.schemas.js';

/** Request bodies and queries of the admin panel (v1.60-social, D191, CONVENTIONS §10.54; openapi tag `admin-panel`). */

const reason = z.string().trim().min(1).max(500);
const optionalNote = z.string().trim().min(1).max(500).optional();
/** The authenticator code re-entered for a financial action (§10.54.3). */
const totpCode = z.string().regex(/^[0-9]{6}$/);

export const adminLoginSchema = z.strictObject({
  email: z.string().trim().min(3).max(254),
  password: z.string().min(1).max(1024),
});

export const adminCodeSchema = z.strictObject({ code: z.string().regex(/^[0-9]{6}$/) });

export const adminSecondFactorSchema = z.union([
  z.strictObject({ code: z.string().regex(/^[0-9]{6}$/) }),
  z.strictObject({ recoveryCode: z.string().trim().min(10).max(16) }),
]);

export const reasonSchema = z.strictObject({ reason });

export const pageQuerySchema = z.strictObject({
  cursor: z.string().max(200).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(25),
});

export const userSearchSchema = z.strictObject({
  q: z.string().trim().min(1).max(254),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export const specialUsernameSchema = z
  .strictObject({
    username: z.string().trim().min(1).max(31),
    days: z.number().int().min(1).max(9999).optional(),
    permanent: z.literal(true).optional(),
    reason,
  })
  .refine((v) => (v.days === undefined) !== (v.permanent === undefined), {
    message: 'exactly one of days or permanent',
    path: ['days'],
  });

export const applicationsQuerySchema = pageQuerySchema.extend({
  status: z.enum(['PENDING', 'APPROVED', 'REJECTED']).optional(),
});

export const agentsQuerySchema = pageQuerySchema.extend({
  status: z.enum(['APPROVED', 'ACTIVE', 'SUSPENDED']).optional(),
});

export const topUpSchema = z.strictObject({
  /** Whole coins, as a decimal string (up to 10^12). */
  coins: z.string().regex(/^[1-9][0-9]{0,12}$/),
  /** The USD paid outside the app, e.g. `360` or `360.00`. */
  paidUsd: z.string().regex(/^[0-9]{1,10}(\.[0-9]{1,2})?$/),
  note: optionalNote,
  totpCode,
});

export const capSchema = z.strictObject({
  /** Cherries per day as a decimal string; `0` = no cap; null = the server default. */
  cap: z
    .string()
    .regex(/^(0|[1-9][0-9]{0,12})$/)
    .nullable(),
  reason,
});

export const withdrawalsQuerySchema = pageQuerySchema.extend({
  status: z.enum(['PENDING', 'PAID', 'REJECTED']).default('PENDING'),
});

export const withdrawalPaySchema = z.strictObject({
  /** The payment's reference (transfer id, receipt number …). */
  reference: z.string().trim().min(1).max(200),
  note: z.string().trim().min(1).max(280).optional(),
  totpCode,
});

export const withdrawalRejectSchema = z.strictObject({ reason, totpCode });

export const panelReportsQuerySchema = pageQuerySchema.extend({
  status: z.enum(['OPEN', 'ACTIONED', 'DISMISSED']).default('OPEN'),
});

export const panelReportActionSchema = z
  .strictObject({
    action: z.enum(['DISMISS', 'REMOVE_TARGET', 'WARN', 'BAN']),
    note: optionalNote,
  })
  .refine((v) => !(v.action === 'WARN' || v.action === 'BAN') || v.note !== undefined, {
    message: 'a reason is required to warn or ban',
    path: ['note'],
  });

/** A path id that must be a UUID (else 404, like everywhere). */
export function pathUuid(value: string): string {
  if (!isUuid(value)) throw new AppException(ErrorCode.NOT_FOUND);
  return value.toLowerCase();
}

/** Keyset cursors of the panel's lists: `{at, id}` of the last row (base64url JSON; 400 when malformed). */
export function encodeCursor(at: Date, id: string): string {
  return Buffer.from(JSON.stringify({ at: at.toISOString(), id })).toString('base64url');
}

export function decodeCursor(cursor: string | undefined): { at: Date; id: string } | null {
  if (cursor === undefined) return null;
  try {
    const v = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')) as { at?: unknown; id?: unknown };
    if (typeof v.at === 'string' && typeof v.id === 'string' && isUuid(v.id)) {
      const at = new Date(v.at);
      if (!Number.isNaN(at.getTime())) return { at, id: v.id };
    }
  } catch {
    // fall through
  }
  throw AppException.validation([{ field: 'cursor', issue: 'invalid' }]);
}

export interface Page<T> {
  data: T[];
  page: { hasMore: boolean; nextCursor: string | null };
}

/** Rows fetched with `take: limit + 1`, newest or oldest first by (createdAt, id). */
export function pageOf<R extends { createdAt: Date; id: string }, T>(
  rows: R[],
  limit: number,
  map: (r: R) => T,
): Page<T> {
  const hasMore = rows.length > limit;
  const kept = rows.slice(0, limit);
  const last = kept[kept.length - 1];
  return {
    data: kept.map(map),
    page: { hasMore, nextCursor: hasMore && last ? encodeCursor(last.createdAt, last.id) : null },
  };
}
