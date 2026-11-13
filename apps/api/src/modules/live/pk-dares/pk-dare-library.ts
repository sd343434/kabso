/**
 * v1.50-live (D229, CONVENTIONS §10.80): the «PK أحكام» library and settings on the database — shared by the admin
 * panel «أحكام PK», the `pk-dares-admin` CLI and the PK service (no Nest dependencies). Every write is checked with
 * the hard safety rules and the duplicate check (`pk-dare-rules.ts`) and audited by the caller's transaction.
 */
import type { Prisma, PrismaClient } from '../../../generated/prisma/client.js';
import { AuditAction } from '../../../common/audit/audit.service.js';
import { uuidv7 } from '../../levels/uuidv7.js';
import {
  checkDareSafety,
  findDuplicates,
  type PkDareCategory,
  type PkDareImport,
  type PkDareLevel,
  type PkDareViolation,
} from './pk-dare-rules.js';

type Db = Prisma.TransactionClient | PrismaClient;

export class PkDareLibraryError extends Error {
  constructor(
    message: string,
    readonly issues: readonly { field: string; issue: string }[] = [],
  ) {
    super(message);
  }
}

/** Who writes (the panel admin or the CLI) — for the audit row and `created_by_id`. */
export interface PkDareActor {
  readonly userId: string | null;
  readonly via: 'panel' | 'cli';
  readonly ip?: string | null;
  readonly requestId?: string | null;
}

export interface PkDareSettingsRow {
  winPoints: number;
  drawPoints: number;
  lossPoints: number;
  refusePoints: number;
  /** v1.67-live (D276): a host who withdrew from a DARES battle (FORFEIT, DISCONNECT, AWAY) instead of the loss's. */
  forfeitPoints: number;
  decideSeconds: number;
  reportsToDisable: number;
  updatedAt: Date;
  updatedById: string | null;
}

const DEFAULT_SETTINGS: Omit<PkDareSettingsRow, 'updatedAt' | 'updatedById'> = {
  winPoints: 3,
  drawPoints: 1,
  lossPoints: 0,
  refusePoints: -3,
  forfeitPoints: -3,
  decideSeconds: 30,
  reportsToDisable: 5,
};

/** The settings row (the defaults when the row is missing, e.g. a database restored without it). */
export async function pkDareSettingsIn(db: Db): Promise<PkDareSettingsRow> {
  const row = await db.pkDareSettings.findUnique({ where: { id: 1 } });
  return row ?? { ...DEFAULT_SETTINGS, updatedAt: new Date(0), updatedById: null };
}

export type PkDareSettingsPatch = Partial<Omit<PkDareSettingsRow, 'updatedAt' | 'updatedById'>>;

/** Updates the settings (audited `pk_dare.settings.update` with before / after and the reason). */
export async function updatePkDareSettingsIn(
  tx: Prisma.TransactionClient,
  patch: PkDareSettingsPatch,
  reason: string,
  actor: PkDareActor,
  now: Date,
): Promise<PkDareSettingsRow> {
  const before = await pkDareSettingsIn(tx);
  const after = await tx.pkDareSettings.upsert({
    where: { id: 1 },
    create: { id: 1, ...DEFAULT_SETTINGS, ...patch, updatedAt: now, updatedById: actor.userId },
    update: { ...patch, updatedAt: now, updatedById: actor.userId },
  });
  const pick = (s: PkDareSettingsRow) => ({
    winPoints: s.winPoints,
    drawPoints: s.drawPoints,
    lossPoints: s.lossPoints,
    refusePoints: s.refusePoints,
    forfeitPoints: s.forfeitPoints,
    decideSeconds: s.decideSeconds,
    reportsToDisable: s.reportsToDisable,
  });
  await audit(tx, AuditAction.PK_DARE_SETTINGS_UPDATE, actor, 'pk_dare_settings', '1', {
    before: pick(before),
    after: pick(after),
    reason,
  });
  return after;
}

async function audit(
  tx: Prisma.TransactionClient,
  action: AuditAction,
  actor: PkDareActor,
  targetType: string,
  targetId: string,
  metadata: Record<string, unknown>,
): Promise<void> {
  await tx.auditLog.create({
    data: {
      action,
      actorUserId: actor.userId,
      targetType,
      targetId,
      metadata: { ...metadata, via: actor.via },
      ip: actor.ip?.slice(0, 64) ?? null,
      requestId: actor.requestId ?? null,
    },
  });
}

/** The safety rules and the duplicate check of new or edited texts against the active library. */
async function textProblems(
  db: Db,
  items: readonly { textAr: string; textEn: string }[],
  exceptId?: string,
): Promise<{ index: number; violations: PkDareViolation[] }[]> {
  const out: { index: number; violations: PkDareViolation[] }[] = [];
  items.forEach((d, index) => {
    const v = checkDareSafety(d);
    if (v.length > 0) out.push({ index, violations: v });
  });
  // A refused text is not checked for duplicates (that reads the whole library).
  if (items.length === 1 && out.length > 0) return out;
  const library = await db.pkDare.findMany({
    where: exceptId ? { id: { not: exceptId } } : {},
    select: { textAr: true, textEn: true },
  });
  for (const p of findDuplicates([...library, ...items], library.length)) {
    const index = Math.max(p.a, p.b) - library.length;
    out.push({
      index,
      violations: [
        { rule: p.exact ? 'duplicate' : 'near_duplicate', detail: `${p.lang} ${p.similarity.toFixed(2)}` },
      ],
    });
  }
  return out;
}

export interface PkDareInput {
  textAr: string;
  textEn: string;
  category: PkDareCategory;
  level: PkDareLevel;
}

/** Adds one dare (code `adm-<uuid prefix>`), audited `pk_dare.create`. Refused texts → PkDareLibraryError. */
export async function createPkDareIn(
  tx: Prisma.TransactionClient,
  input: PkDareInput,
  reason: string,
  actor: PkDareActor,
): Promise<{ id: string; code: string }> {
  const problems = await textProblems(tx, [input]);
  if (problems.length > 0) {
    throw new PkDareLibraryError(
      problems[0]!.violations.map((v) => v.rule).join(', '),
      problems[0]!.violations.map((v) => ({ field: 'text', issue: v.rule })),
    );
  }
  const id = uuidv7();
  const code = `adm-${id.replace(/-/g, '').slice(-12)}`;
  await tx.pkDare.create({
    data: { id, code, ...input, createdBy: 'ADMIN', createdById: actor.userId },
  });
  await audit(tx, AuditAction.PK_DARE_CREATE, actor, 'pk_dare', id, { after: { code, ...input }, reason });
  return { id, code };
}

export interface PkDarePatch {
  textAr?: string;
  textEn?: string;
  category?: PkDareCategory;
  level?: PkDareLevel;
  active?: boolean;
}

/** Edits / disables / enables one dare, audited `pk_dare.update` with before and after. */
export async function updatePkDareIn(
  tx: Prisma.TransactionClient,
  id: string,
  patch: PkDarePatch,
  reason: string,
  actor: PkDareActor,
  now: Date,
): Promise<void> {
  const before = await tx.pkDare.findUnique({ where: { id } });
  if (!before) throw new PkDareLibraryError('not_found');
  const textAr = patch.textAr ?? before.textAr;
  const textEn = patch.textEn ?? before.textEn;
  if (patch.textAr !== undefined || patch.textEn !== undefined) {
    const problems = await textProblems(tx, [{ textAr, textEn }], id);
    if (problems.length > 0) {
      throw new PkDareLibraryError(
        problems[0]!.violations.map((v) => v.rule).join(', '),
        problems[0]!.violations.map((v) => ({ field: 'text', issue: v.rule })),
      );
    }
  }
  const data: Prisma.PkDareUpdateInput = { ...patch, updatedAt: now };
  if (patch.active === false) data.disabledReason = 'ADMIN';
  if (patch.active === true) data.disabledReason = null;
  await tx.pkDare.update({ where: { id }, data });
  const view = (d: { textAr: string; textEn: string; category: string; level: string; active: boolean }) => ({
    textAr: d.textAr,
    textEn: d.textEn,
    category: d.category,
    level: d.level,
    active: d.active,
  });
  await audit(tx, AuditAction.PK_DARE_UPDATE, actor, 'pk_dare', id, {
    before: view(before),
    after: view({ ...before, ...patch, textAr, textEn }),
    reason,
  });
}

/** Clears a dare's reports (kept: the queue's «إبقاء»), optionally enabling it again; audited. */
export async function clearPkDareReportsIn(
  tx: Prisma.TransactionClient,
  id: string,
  enable: boolean,
  reason: string,
  actor: PkDareActor,
  now: Date,
): Promise<void> {
  const before = await tx.pkDare.findUnique({ where: { id } });
  if (!before) throw new PkDareLibraryError('not_found');
  await tx.pkDare.update({
    where: { id },
    data: {
      reportCount: 0,
      reportsClearedAt: now,
      updatedAt: now,
      ...(enable ? { active: true, disabledReason: null } : {}),
    },
  });
  await tx.pkDareReport.deleteMany({ where: { dareId: id } });
  await audit(tx, AuditAction.PK_DARE_REPORTS_CLEAR, actor, 'pk_dare', id, {
    reports: before.reportCount,
    enabled: enable,
    reason,
  });
}

export interface PkDareImportResult {
  received: number;
  inserted: number;
  /** A code already in the library (left as it is: an admin's edit is never overwritten). */
  existing: number;
  rejected: { line: number; code: string | null; issues: string[] }[];
}

/**
 * Imports dares (the seed file or a panel upload) — idempotent by `code`: a code already present is left as it is.
 * Every new line must pass the safety rules and not duplicate the library or an earlier line; refused lines are
 * reported, never inserted. `dryRun`: nothing written. Audited `pk_dare.import` (counts only).
 */
export async function importPkDaresIn(
  tx: Prisma.TransactionClient,
  items: readonly (PkDareImport | { line: number; error: string })[],
  opts: { dryRun: boolean; reason: string; actor: PkDareActor; createdBy: 'SEED' | 'ADMIN' },
): Promise<PkDareImportResult> {
  const result: PkDareImportResult = { received: items.length, inserted: 0, existing: 0, rejected: [] };
  const valid: (PkDareImport & { line: number })[] = [];
  items.forEach((it, i) => {
    if ('error' in it) result.rejected.push({ line: it.line, code: null, issues: [it.error] });
    else valid.push({ ...it, line: i + 1 });
  });
  const codes = new Set(
    (
      await tx.pkDare.findMany({
        where: { code: { in: valid.map((v) => v.code) } },
        select: { code: true },
      })
    ).map((r) => r.code),
  );
  const fresh = valid.filter((v) => {
    if (codes.has(v.code)) {
      result.existing += 1;
      return false;
    }
    return true;
  });
  const seenCodes = new Set<string>();
  const unique = fresh.filter((v) => {
    if (seenCodes.has(v.code)) {
      result.rejected.push({ line: v.line, code: v.code, issues: ['duplicate code'] });
      return false;
    }
    seenCodes.add(v.code);
    return true;
  });
  const problems = await textProblems(tx, unique);
  const bad = new Map<number, string[]>();
  for (const p of problems)
    bad.set(p.index, [...(bad.get(p.index) ?? []), ...p.violations.map((v) => v.rule)]);
  const ok = unique.filter((v, i) => {
    const issues = bad.get(i);
    if (issues) result.rejected.push({ line: v.line, code: v.code, issues: [...new Set(issues)] });
    return !issues;
  });
  if (!opts.dryRun) {
    for (let i = 0; i < ok.length; i += 1000) {
      const chunk = ok.slice(i, i + 1000);
      const res = await tx.pkDare.createMany({
        data: chunk.map((d) => ({
          id: uuidv7(),
          code: d.code,
          textAr: d.textAr,
          textEn: d.textEn,
          category: d.category,
          level: d.level,
          createdBy: opts.createdBy,
          createdById: opts.actor.userId,
        })),
        skipDuplicates: true,
      });
      result.inserted += res.count;
    }
    await audit(tx, AuditAction.PK_DARE_IMPORT, opts.actor, 'pk_dares', 'import', {
      received: result.received,
      inserted: result.inserted,
      existing: result.existing,
      rejected: result.rejected.length,
      reason: opts.reason,
    });
  }
  result.rejected.sort((a, b) => a.line - b.line);
  return result;
}

/** Counts per level and category, active / disabled / reported. */
export async function pkDareStatsIn(db: Db): Promise<{
  total: number;
  active: number;
  disabled: number;
  reported: number;
  byLevel: Record<string, number>;
  byCategory: Record<string, number>;
}> {
  const [total, active, reported, levels, categories] = await Promise.all([
    db.pkDare.count(),
    db.pkDare.count({ where: { active: true } }),
    db.pkDare.count({ where: { reportCount: { gt: 0 } } }),
    db.pkDare.groupBy({ by: ['level'], where: { active: true }, _count: { _all: true } }),
    db.pkDare.groupBy({ by: ['category'], where: { active: true }, _count: { _all: true } }),
  ]);
  return {
    total,
    active,
    disabled: total - active,
    reported,
    byLevel: Object.fromEntries(levels.map((l) => [l.level, l._count._all])),
    byCategory: Object.fromEntries(categories.map((c) => [c.category, c._count._all])),
  };
}
