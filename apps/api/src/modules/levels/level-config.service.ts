import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import type {
  LevelCategoryCode,
  LevelReversalPolicy,
  LevelValueUnit,
  Prisma,
} from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { loadAllCategories, loadCategory, type LevelDef, type LoadedCategory } from './level-catalog.js';
import { versionConfigIssues, type LevelDefinitionInput } from './level-config.rules.js';
import { levelFor } from './level-math.js';
import { LevelProgressService } from './level-progress.service.js';
import { versionDto, VERSION_INCLUDE, type AdminLevelVersionDto, type VersionRow } from './levels.dto.js';
import { LEVEL_CATEGORIES } from './levels.constants.js';
import { formatMultiplier, parseMultiplier } from './points-math.js';

export type Recalculation = 'PRESERVE_POINTS' | 'RECOMPUTE_FROM_LEDGER';

export interface AdminActor {
  readonly userId: string;
  readonly ip: string | null;
  readonly requestId: string | null;
}

export interface AdminLevelCategoryDto {
  category: LevelCategoryCode;
  nameAr: string;
  nameEn: string;
  descriptionAr: string;
  descriptionEn: string;
  enabled: boolean;
  published: AdminLevelVersionDto | null;
  draftCount: number;
  updatedAt: string;
}

export interface CategoryPatch {
  enabled?: boolean;
  nameAr?: string;
  nameEn?: string;
  descriptionAr?: string;
  descriptionEn?: string;
}

export interface VersionInput {
  multiplier: string;
  valueUnit: LevelValueUnit;
  reversalPolicy: LevelReversalPolicy;
  luckyGiftsCountAsSupport: boolean;
  levels: LevelDefinitionInput[];
}

export interface LevelPreviewDto {
  versionId: string;
  recalculation: Recalculation;
  totalUsers: number;
  usersChangingLevel: number;
  distribution: { levelNumber: number; users: number }[];
}

type Tx = Prisma.TransactionClient;

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

function definitionsOf(row: VersionRow): LevelDefinitionInput[] {
  return row.levels.map((l) => ({
    levelNumber: l.levelNumber,
    nameAr: l.nameAr,
    nameEn: l.nameEn,
    requiredPoints: l.requiredPoints,
    iconKey: l.iconKey,
  }));
}

function issuesOf(row: VersionRow) {
  return versionConfigIssues({
    category: row.category.code,
    multiplier: row.multiplier === null ? null : row.multiplier.toFixed(6),
    valueUnit: row.valueUnit,
    luckyGiftsCountAsSupport: row.luckyGiftsCountAsSupport,
    levels: definitionsOf(row),
  });
}

/**
 * Versioned category configuration (CP-005 §4; the brief's LevelConfigurationService): drafts are
 * edited freely, validated, previewed and published; a published version is never changed, and
 * every mutation is audited with before/after values.
 */
@Injectable()
export class LevelConfigService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly progress: LevelProgressService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
  ) {}

  private async categoryDto(code: LevelCategoryCode): Promise<AdminLevelCategoryDto> {
    const row = await this.prisma.levelCategory.findUnique({
      where: { code },
      include: { publishedVersion: { include: VERSION_INCLUDE } },
    });
    if (!row) throw notFound();
    const draftCount = await this.prisma.levelCategoryVersion.count({
      where: { categoryId: row.id, status: 'DRAFT' },
    });
    return {
      category: row.code,
      nameAr: row.nameAr,
      nameEn: row.nameEn,
      descriptionAr: row.descriptionAr,
      descriptionEn: row.descriptionEn,
      enabled: row.isEnabled,
      published: row.publishedVersion ? versionDto(row.publishedVersion) : null,
      draftCount,
      updatedAt: row.updatedAt.toISOString(),
    };
  }

  async listCategories(): Promise<AdminLevelCategoryDto[]> {
    return Promise.all(LEVEL_CATEGORIES.map((code) => this.categoryDto(code)));
  }

  getCategory(code: LevelCategoryCode): Promise<AdminLevelCategoryDto> {
    return this.categoryDto(code);
  }

  async updateCategory(
    code: LevelCategoryCode,
    patch: CategoryPatch,
    actor: AdminActor,
  ): Promise<AdminLevelCategoryDto> {
    await this.prisma.$transaction(async (tx) => {
      const before = await tx.levelCategory.findUniqueOrThrow({ where: { code } });
      if (patch.enabled === true && before.publishedVersionId === null) {
        throw new AppException(ErrorCode.LEVEL_CONFIG_INVALID, undefined, [
          { field: 'enabled', issue: 'no_published_version' },
        ]);
      }
      const after = await tx.levelCategory.update({
        where: { code },
        data: {
          ...(patch.enabled === undefined ? {} : { isEnabled: patch.enabled }),
          ...(patch.nameAr === undefined ? {} : { nameAr: patch.nameAr }),
          ...(patch.nameEn === undefined ? {} : { nameEn: patch.nameEn }),
          ...(patch.descriptionAr === undefined ? {} : { descriptionAr: patch.descriptionAr }),
          ...(patch.descriptionEn === undefined ? {} : { descriptionEn: patch.descriptionEn }),
        },
      });
      const pick = (r: typeof before) => ({
        enabled: r.isEnabled,
        nameAr: r.nameAr,
        nameEn: r.nameEn,
        descriptionAr: r.descriptionAr,
        descriptionEn: r.descriptionEn,
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.LEVELS_CATEGORY_UPDATE,
        actorUserId: actor.userId,
        targetType: 'level_category',
        targetId: code,
        metadata: { before: pick(before), after: pick(after) },
        ip: actor.ip,
        requestId: actor.requestId,
      });
    });
    return this.categoryDto(code);
  }

  async listVersions(code: LevelCategoryCode): Promise<AdminLevelVersionDto[]> {
    const rows = await this.prisma.levelCategoryVersion.findMany({
      where: { category: { code } },
      include: VERSION_INCLUDE,
      orderBy: { versionNumber: 'desc' },
      take: 500,
    });
    return rows.map(versionDto);
  }

  private async version(id: string, db: Pick<Tx, 'levelCategoryVersion'> = this.prisma): Promise<VersionRow> {
    const row = await db.levelCategoryVersion.findUnique({ where: { id }, include: VERSION_INCLUDE });
    if (!row) throw notFound();
    return row;
  }

  async getVersion(id: string): Promise<AdminLevelVersionDto> {
    return versionDto(await this.version(id));
  }

  async createVersion(
    code: LevelCategoryCode,
    copyFrom: string | null,
    actor: AdminActor,
  ): Promise<AdminLevelVersionDto> {
    const id = await this.prisma.$transaction(async (tx) => {
      // Serializes version numbering with other creates and with publish.
      const category = await loadCategory(tx, code, 'update');
      const source = copyFrom
        ? await tx.levelCategoryVersion.findUnique({ where: { id: copyFrom }, include: VERSION_INCLUDE })
        : null;
      if (copyFrom && (!source || source.categoryId !== category.id)) throw notFound();
      const last = await tx.levelCategoryVersion.aggregate({
        where: { categoryId: category.id },
        _max: { versionNumber: true },
      });
      const created = await tx.levelCategoryVersion.create({
        data: {
          categoryId: category.id,
          versionNumber: (last._max.versionNumber ?? 0) + 1,
          status: 'DRAFT',
          multiplier: source?.multiplier ?? null,
          valueUnit: source?.valueUnit ?? null,
          reversalPolicy: source?.reversalPolicy ?? 'REVERSE_POINTS',
          luckyGiftsCountAsSupport: source?.luckyGiftsCountAsSupport ?? false,
          createdById: actor.userId,
          levels: source
            ? {
                create: source.levels.map((l) => ({
                  levelNumber: l.levelNumber,
                  nameAr: l.nameAr,
                  nameEn: l.nameEn,
                  requiredPoints: l.requiredPoints,
                  iconKey: l.iconKey,
                })),
              }
            : undefined,
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.LEVELS_VERSION_CREATE,
        actorUserId: actor.userId,
        targetType: 'level_version',
        targetId: created.id,
        metadata: { category: code, versionNumber: created.versionNumber, copyFrom: copyFrom ?? null },
        ip: actor.ip,
        requestId: actor.requestId,
      });
      return created.id;
    });
    return this.getVersion(id);
  }

  async replaceVersion(id: string, input: VersionInput, actor: AdminActor): Promise<AdminLevelVersionDto> {
    await this.prisma.$transaction(async (tx) => {
      const before = await this.version(id, tx);
      // Lock the row: a concurrent publish must see either the old or the new draft.
      await tx.$queryRaw`SELECT id FROM level_category_versions WHERE id = ${id}::uuid FOR UPDATE`;
      const current = await this.version(id, tx);
      if (current.status !== 'DRAFT') throw new AppException(ErrorCode.LEVEL_VERSION_NOT_DRAFT);
      const scaled = parseMultiplier(input.multiplier);
      if (scaled === null) throw AppException.validation([{ field: 'multiplier', issue: 'invalid_value' }]);
      const numbers = new Set(input.levels.map((l) => l.levelNumber));
      if (numbers.size !== input.levels.length) {
        throw AppException.validation([{ field: 'levels', issue: 'duplicate_level_number' }]);
      }
      await tx.levelDefinition.deleteMany({ where: { versionId: id } });
      await tx.levelCategoryVersion.update({
        where: { id },
        data: {
          multiplier: formatMultiplier(scaled),
          valueUnit: input.valueUnit,
          reversalPolicy: input.reversalPolicy,
          luckyGiftsCountAsSupport: input.luckyGiftsCountAsSupport,
          levels: { create: input.levels.map((l) => ({ ...l })) },
        },
      });
      const after = await this.version(id, tx);
      const snapshot = (v: VersionRow) => {
        const dto = versionDto(v);
        return {
          multiplier: dto.multiplier,
          valueUnit: dto.valueUnit,
          reversalPolicy: dto.reversalPolicy,
          luckyGiftsCountAsSupport: dto.luckyGiftsCountAsSupport,
          levels: dto.levels.map((l) => `${String(l.levelNumber)}:${l.requiredPoints}`),
        };
      };
      await this.audit.recordIn(tx, {
        action: AuditAction.LEVELS_VERSION_UPDATE,
        actorUserId: actor.userId,
        targetType: 'level_version',
        targetId: id,
        metadata: { before: snapshot(before), after: snapshot(after) },
        ip: actor.ip,
        requestId: actor.requestId,
      });
    });
    return this.getVersion(id);
  }

  async validateVersion(id: string): Promise<{ valid: boolean; issues: { field: string; issue: string }[] }> {
    const issues = issuesOf(await this.version(id)).map((d) => ({ field: d.field, issue: d.issue }));
    return { valid: issues.length === 0, issues };
  }

  /**
   * Per user: their total under `recalculation` (PRESERVE = stored total; RECOMPUTE = rebuilt from
   * the ledger with `multiplier`, CP-005 §4) — the ledger's source values times the new multiplier
   * for every EARN not reversed, plus manual (ADMIN) adjustments.
   */
  private async targets(
    db: Pick<Tx, '$queryRaw'>,
    categoryId: string,
    recalculation: Recalculation,
    multiplier: string,
  ): Promise<Map<string, { total: bigint; current: number | null }>> {
    const states = await db.$queryRaw<
      { user_id: string; total_points: bigint; current_level: number | null }[]
    >`
      SELECT user_id, total_points, current_level FROM user_level_states WHERE category_id = ${categoryId}::uuid`;
    const result = new Map(
      states.map((s) => [s.user_id, { total: s.total_points, current: s.current_level }]),
    );
    if (recalculation === 'PRESERVE_POINTS') return result;
    const rebuilt = await db.$queryRaw<{ user_id: string; target: bigint | null }[]>`
      SELECT e.user_id,
             (COALESCE(SUM(floor(e.source_value::numeric * ${multiplier}::numeric))
                FILTER (WHERE e.entry_type = 'EARN' AND r.id IS NULL), 0)
              + COALESCE(SUM(e.points_delta) FILTER (WHERE e.source_type = 'ADMIN'), 0))::bigint AS target
        FROM points_ledger e
        LEFT JOIN points_ledger r ON r.reversal_of_entry_id = e.id
       WHERE e.category_id = ${categoryId}::uuid
       GROUP BY e.user_id`;
    for (const row of rebuilt) {
      const target = row.target ?? 0n;
      const prior = result.get(row.user_id);
      result.set(row.user_id, { total: target < 0n ? 0n : target, current: prior?.current ?? null });
    }
    return result;
  }

  async previewVersion(id: string, recalculation: Recalculation): Promise<LevelPreviewDto> {
    const row = await this.version(id);
    const issues = issuesOf(row);
    if (issues.length > 0) throw new AppException(ErrorCode.LEVEL_CONFIG_INVALID, undefined, issues);
    const levels: LevelDef[] = row.levels.map((l) => ({ ...l }));
    const users = await this.targets(
      this.prisma,
      row.categoryId,
      recalculation,
      row.multiplier?.toFixed(6) ?? '0',
    );
    const counts = new Map<number, number>(levels.map((l) => [l.levelNumber, 0]));
    let changing = 0;
    for (const { total, current } of users.values()) {
      const level = levelFor(levels, total)?.levelNumber ?? null;
      if (level !== null) counts.set(level, (counts.get(level) ?? 0) + 1);
      if (level !== current) changing++;
    }
    return {
      versionId: id,
      recalculation,
      totalUsers: users.size,
      usersChangingLevel: changing,
      distribution: [...counts.entries()].map(([levelNumber, n]) => ({ levelNumber, users: n })),
    };
  }

  /**
   * Publishes a valid draft: the previous published version is archived, the category points at
   * the new one, and every user of the category is re-evaluated (and, with
   * RECOMPUTE_FROM_LEDGER, brought to the rebuilt total through CONFIG adjustment entries) — all
   * in one transaction, under the category's row lock.
   */
  async publishVersion(
    id: string,
    recalculation: Recalculation,
    actor: AdminActor,
  ): Promise<AdminLevelVersionDto> {
    await this.prisma.$transaction(
      async (tx) => {
        const draft = await this.version(id, tx);
        const before: LoadedCategory = await loadCategory(tx, draft.category.code, 'update');
        const row = await this.version(id, tx);
        if (row.status !== 'DRAFT') throw new AppException(ErrorCode.LEVEL_VERSION_NOT_DRAFT);
        const issues = issuesOf(row);
        if (issues.length > 0) throw new AppException(ErrorCode.LEVEL_CONFIG_INVALID, undefined, issues);

        const now = this.clock.now();
        if (before.version) {
          await tx.levelCategoryVersion.update({
            where: { id: before.version.id },
            data: { status: 'ARCHIVED' },
          });
        }
        await tx.levelCategoryVersion.update({
          where: { id },
          data: { status: 'PUBLISHED', publishedAt: now, publishedById: actor.userId },
        });
        await tx.levelCategory.update({ where: { id: before.id }, data: { publishedVersionId: id } });
        const category = await loadCategory(tx, row.category.code);
        const version = category.version;
        if (!version) throw new Error('published version did not load');

        const users = await this.targets(tx, category.id, recalculation, row.multiplier?.toFixed(6) ?? '0');
        const ordered = [...users.entries()].sort(([a], [b]) => a.localeCompare(b));
        let adjusted = 0;
        let changed = 0;
        for (const [userId, { total }] of ordered) {
          if (recalculation === 'RECOMPUTE_FROM_LEDGER') {
            const state = await tx.userLevelState.findUniqueOrThrow({
              where: { userId_categoryId: { userId, categoryId: category.id } },
              select: { totalPoints: true },
            });
            const delta = total - state.totalPoints;
            if (delta !== 0n) {
              const result = await this.progress.apply(tx, category, {
                userId,
                entryType: 'ADJUSTMENT',
                sourceType: 'CONFIG',
                pointsDelta: delta,
                transitionReason: 'CONFIG_PUBLISHED',
                createdById: actor.userId,
              });
              if (result.kind === 'applied') {
                adjusted++;
                if (result.state.currentLevel !== result.state.previousLevel) changed++;
                continue;
              }
            }
          }
          if (await this.progress.reevaluate(tx, category, userId, 'CONFIG_PUBLISHED')) changed++;
        }
        await this.audit.recordIn(tx, {
          action: AuditAction.LEVELS_VERSION_PUBLISH,
          actorUserId: actor.userId,
          targetType: 'level_version',
          targetId: id,
          metadata: {
            category: category.code,
            versionNumber: version.versionNumber,
            previousVersionNumber: before.version?.versionNumber ?? null,
            recalculation,
            users: users.size,
            adjusted,
            levelChanges: changed,
          },
          ip: actor.ip,
          requestId: actor.requestId,
        });
      },
      { timeout: 120_000 },
    );
    return this.getVersion(id);
  }

  /** Loaded categories (for the query and admin services). */
  loadAll(): Promise<LoadedCategory[]> {
    return loadAllCategories(this.prisma);
  }
}
