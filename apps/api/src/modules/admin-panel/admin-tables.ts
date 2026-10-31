import type { Response } from 'express';
import { z } from 'zod';
import { AuditAction, type AuditService } from '../../common/audit/audit.service.js';
import { csvDocument, type CsvValue } from '../../common/csv/csv.js';
import { dayStart } from '../recharge/recharge-rules.js';
import type { AdminContext } from './admin-auth.service.js';

/**
 * The panel v2's one table shape (v1.65-social, D197, CONVENTIONS §10.60.1): server-side pages by number (`page`,
 * `pageSize` ≤ 100) with the `total`, a whitelisted `sort` and `order`, a text `q` and per-table filters; the same
 * query with `format=csv` returns the matching rows (at most {@link CSV_MAX_ROWS}) as a CSV download, audited
 * `admin.export.csv` {table, count, filters}. The panel's one table component reads every list this way.
 */
export const CSV_MAX_ROWS = 5000;

export function tableQuery<S extends readonly [string, ...string[]]>(sorts: S, defaultSort: S[number]) {
  return z.object({
    page: z.coerce.number().int().min(1).max(100_000).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(25),
    sort: z.enum(sorts).default(defaultSort as never),
    order: z.enum(['asc', 'desc']).default('desc'),
    q: z.string().trim().max(254).optional(),
    format: z.enum(['json', 'csv']).default('json'),
  });
}

export interface TableQuery {
  readonly page: number;
  readonly pageSize: number;
  readonly sort: string;
  readonly order: 'asc' | 'desc';
  readonly q?: string | undefined;
  readonly format: 'json' | 'csv';
}

export interface TablePage<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
}

/** `skip` / `take` of a page, or of the whole export. */
export function window(q: TableQuery): { skip: number; take: number } {
  return q.format === 'csv'
    ? { skip: 0, take: CSV_MAX_ROWS }
    : { skip: (q.page - 1) * q.pageSize, take: q.pageSize };
}

export type TableResult<T> =
  | { readonly kind: 'json'; readonly body: TablePage<T> }
  | { readonly kind: 'csv'; readonly filename: string; readonly body: string };

/**
 * The answer of a table: a page, or (format=csv) the CSV of `rows` with `columns`, audited in the caller's request
 * (the export is a read of possibly personal data: the audit row names the table, the count and the filters, never
 * the rows).
 */
export async function tableResult<T>(
  audit: AuditService,
  ctx: AdminContext,
  table: string,
  q: TableQuery,
  rows: T[],
  total: number,
  columns: readonly (readonly [string, (row: T) => CsvValue])[],
  filters: Record<string, unknown> = {},
): Promise<TableResult<T>> {
  if (q.format !== 'csv')
    return { kind: 'json', body: { data: rows, total, page: q.page, pageSize: q.pageSize } };
  await audit.record({
    action: AuditAction.ADMIN_EXPORT_CSV,
    actorUserId: ctx.userId,
    targetType: 'admin_table',
    targetId: table,
    metadata: {
      table,
      count: rows.length,
      total,
      filters: { ...filters, ...(q.q ? { q: q.q } : {}), sort: q.sort, order: q.order },
      via: 'panel',
    },
    ip: ctx.ip,
    requestId: ctx.requestId,
  });
  const body = csvDocument(
    columns.map(([name]) => name),
    rows.map((r) => columns.map(([, value]) => value(r))),
  );
  const stamp = new Date().toISOString().slice(0, 10);
  return { kind: 'csv', filename: `kabso-${table}-${stamp}.csv`, body };
}

/** Sends a table result (JSON, or the CSV as an attachment that is never cached). */
export function sendTable<T>(res: Response, result: TableResult<T>): TablePage<T> | string {
  res.setHeader('Cache-Control', 'no-store');
  if (result.kind === 'json') return result.body;
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${result.filename}"`);
  res.setHeader('X-Content-Type-Options', 'nosniff');
  return result.body;
}

/** A day range filter (`from` / `to` as YYYY-MM-DD, inclusive) on top of a table query. */
export const dayRange = {
  from: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
  to: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
};

/**
 * Midnight of a YYYY-MM-DD day in `zone` (the panel's Asia/Riyadh day, ADMIN_DASHBOARD_TIME_ZONE); the end bound is
 * exclusive (the next day's midnight).
 */
export function dayBound(day: string | undefined, end: boolean, zone: string): Date | undefined {
  if (day === undefined) return undefined;
  const noon = new Date(`${day}T12:00:00.000Z`);
  if (Number.isNaN(noon.getTime())) return undefined;
  return dayStart(new Date(noon.getTime() + (end ? 86_400_000 : 0)), zone);
}
