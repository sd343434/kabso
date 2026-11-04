import { Injectable } from '@nestjs/common';
import { AuditService } from '../../../common/audit/audit.service.js';
import { AppException } from '../../../common/errors/app-exception.js';
import { ErrorCode } from '../../../common/errors/error-codes.js';
import { Clock } from '../../../common/time/clock.js';
import type { Prisma } from '../../../generated/prisma/client.js';
import { PrismaService } from '../../../prisma/prisma.service.js';
import type { AdminContext } from '../../admin-panel/admin-auth.service.js';
import { tableResult, window, type TableQuery } from '../../admin-panel/admin-tables.js';
import {
  PkDareLibraryError,
  clearPkDareReportsIn,
  createPkDareIn,
  importPkDaresIn,
  pkDareSettingsIn,
  pkDareStatsIn,
  updatePkDareIn,
  updatePkDareSettingsIn,
  type PkDareActor,
  type PkDareInput,
  type PkDarePatch,
  type PkDareSettingsPatch,
  type PkDareSettingsRow,
} from './pk-dare-library.js';
import { parseCsv, parseDareImport, type PkDareCategory, type PkDareLevel } from './pk-dare-rules.js';

export interface PkDaresQuery extends TableQuery {
  readonly category?: PkDareCategory | undefined;
  readonly level?: PkDareLevel | undefined;
  readonly active?: 'true' | 'false' | undefined;
  readonly reported?: 'true' | undefined;
}

const actorOf = (ctx: AdminContext): PkDareActor => ({
  userId: ctx.userId,
  via: 'panel',
  ip: ctx.ip,
  requestId: ctx.requestId,
});

/** `AdminPkDare`. */
function dareDto(d: {
  id: string;
  seqNo: number;
  code: string;
  textAr: string;
  textEn: string;
  category: string;
  level: string;
  active: boolean;
  disabledReason: string | null;
  reportCount: number;
  reportsClearedAt: Date | null;
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: d.id,
    seqNo: d.seqNo,
    code: d.code,
    textAr: d.textAr,
    textEn: d.textEn,
    category: d.category,
    level: d.level,
    requiresCamera: true,
    active: d.active,
    disabledReason: d.disabledReason,
    reportCount: d.reportCount,
    reportsClearedAt: d.reportsClearedAt?.toISOString() ?? null,
    createdBy: d.createdBy,
    createdAt: d.createdAt.toISOString(),
    updatedAt: d.updatedAt.toISOString(),
  };
}

/** `AdminPkDareSettings`. */
export function pkDareSettingsDto(s: PkDareSettingsRow) {
  return {
    winPoints: s.winPoints,
    drawPoints: s.drawPoints,
    lossPoints: s.lossPoints,
    refusePoints: s.refusePoints,
    forfeitPoints: s.forfeitPoints,
    decideSeconds: s.decideSeconds,
    reportsToDisable: s.reportsToDisable,
    updatedAt: s.updatedAt.toISOString(),
    updatedById: s.updatedById,
  };
}

/** Panel import: at most this many lines per upload (the whole seed goes through `pk-dares-admin import`). */
export const PK_DARE_PANEL_IMPORT_MAX = 2000;

/**
 * «أحكام PK» in the panel (v1.50-live, D229, CONVENTIONS §10.80): the library table (filters, search, CSV), add / edit
 * / disable, import (JSON lines or CSV), the «مُبلَّغ عنها» queue (reported first; keep = clear the reports, optionally
 * enabling again) and the PK points settings. `pk_dares.view` and `pk_dares.edit` OWNER only (D274; were OWNER / MODERATION / SUPPORT and OWNER / MODERATION).
 * Every write is audited with the reason (`pk-dare-library.ts`, the same code as `pk-dares-admin`).
 */
@Injectable()
export class AdminPkDaresService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
  ) {}

  private async rule<T>(step: () => Promise<T>): Promise<T> {
    try {
      return await step();
    } catch (err) {
      if (err instanceof PkDareLibraryError) {
        if (err.message === 'not_found') throw new AppException(ErrorCode.NOT_FOUND);
        if (err.issues.length > 0) throw AppException.validation([...err.issues]);
        throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, err.message);
      }
      throw err;
    }
  }

  async table(q: PkDaresQuery, ctx: AdminContext) {
    const text = q.q?.trim();
    const where: Prisma.PkDareWhereInput = {
      ...(q.category ? { category: q.category } : {}),
      ...(q.level ? { level: q.level } : {}),
      ...(q.active ? { active: q.active === 'true' } : {}),
      ...(q.reported ? { reportCount: { gt: 0 } } : {}),
      ...(text
        ? {
            OR: [
              { textAr: { contains: text, mode: 'insensitive' as const } },
              { textEn: { contains: text, mode: 'insensitive' as const } },
              { code: { startsWith: text.toLowerCase() } },
            ],
          }
        : {}),
    };
    const orderBy: Prisma.PkDareOrderByWithRelationInput[] =
      q.sort === 'reportCount'
        ? [{ reportCount: q.order }, { seqNo: 'asc' }]
        : q.sort === 'updatedAt'
          ? [{ updatedAt: q.order }, { seqNo: 'asc' }]
          : [{ seqNo: q.order }];
    const [rows, total] = await Promise.all([
      this.prisma.pkDare.findMany({ where, orderBy, ...window(q) }),
      this.prisma.pkDare.count({ where }),
    ]);
    const data = rows.map(dareDto);
    return tableResult(
      this.audit,
      ctx,
      'pk_dares',
      q,
      data,
      total,
      [
        ['code', (r) => r.code],
        ['category', (r) => r.category],
        ['level', (r) => r.level],
        ['textAr', (r) => r.textAr],
        ['textEn', (r) => r.textEn],
        ['active', (r) => String(r.active)],
        ['reportCount', (r) => r.reportCount],
      ],
      { category: q.category, level: q.level, active: q.active, reported: q.reported },
    );
  }

  async stats() {
    return pkDareStatsIn(this.prisma);
  }

  async create(input: PkDareInput & { reason: string }, ctx: AdminContext) {
    const { reason, ...dare } = input;
    const made = await this.rule(() =>
      this.prisma.$transaction((tx) => createPkDareIn(tx, dare, reason, actorOf(ctx))),
    );
    return dareDto((await this.prisma.pkDare.findUnique({ where: { id: made.id } }))!);
  }

  async update(id: string, input: PkDarePatch & { reason: string }, ctx: AdminContext) {
    const { reason, ...patch } = input;
    await this.rule(() =>
      this.prisma.$transaction((tx) => updatePkDareIn(tx, id, patch, reason, actorOf(ctx), this.clock.now())),
    );
    return dareDto((await this.prisma.pkDare.findUnique({ where: { id } }))!);
  }

  async clearReports(id: string, input: { enable: boolean; reason: string }, ctx: AdminContext) {
    await this.rule(() =>
      this.prisma.$transaction((tx) =>
        clearPkDareReportsIn(tx, id, input.enable, input.reason, actorOf(ctx), this.clock.now()),
      ),
    );
    return dareDto((await this.prisma.pkDare.findUnique({ where: { id } }))!);
  }

  /** JSON (an array, or one object per line) or CSV with a header row (code,category,level,textAr,textEn). */
  async import(
    input: { format: 'json' | 'csv'; content: string; dryRun: boolean; reason: string },
    ctx: AdminContext,
  ) {
    let raw: unknown[];
    try {
      if (input.format === 'csv') raw = parseCsv(input.content);
      else {
        const text = input.content.trim();
        raw = text.startsWith('[')
          ? (JSON.parse(text) as unknown[])
          : text
              .split('\n')
              .filter((l) => l.trim().length > 0)
              .map((l) => JSON.parse(l) as unknown);
      }
    } catch {
      throw AppException.validation([{ field: 'content', issue: 'invalid_format' }]);
    }
    if (!Array.isArray(raw) || raw.length === 0)
      throw AppException.validation([{ field: 'content', issue: 'required' }]);
    if (raw.length > PK_DARE_PANEL_IMPORT_MAX)
      throw AppException.validation([{ field: 'content', issue: 'too_long' }]);
    const items = raw.map((r, i) => {
      const parsed = parseDareImport(r);
      return typeof parsed === 'string' ? { line: i + 1, error: parsed } : parsed;
    });
    return this.prisma.$transaction(
      (tx) =>
        importPkDaresIn(tx, items, {
          dryRun: input.dryRun,
          reason: input.reason,
          actor: actorOf(ctx),
          createdBy: 'ADMIN',
        }),
      { timeout: 60_000 },
    );
  }

  async settings() {
    return pkDareSettingsDto(await pkDareSettingsIn(this.prisma));
  }

  async updateSettings(input: PkDareSettingsPatch & { reason: string }, ctx: AdminContext) {
    const { reason, ...patch } = input;
    const row = await this.prisma.$transaction((tx) =>
      updatePkDareSettingsIn(tx, patch, reason, actorOf(ctx), this.clock.now()),
    );
    return pkDareSettingsDto(row);
  }
}
