import { Inject, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type {
  LevelCategoryCode,
  LevelEventStatus,
  PointsLedgerEntry,
  Prisma,
} from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { loadAllCategories, loadCategory, type LoadedCategory } from './level-catalog.js';
import {
  adminPointsEntryDto,
  detailDto,
  eventDto,
  pointsEntryDto,
  runDto,
  summaryDto,
  transitionDto,
  type AdminPointsEntryDto,
  type LevelDetailDto,
  type LevelReconciliationRunDto,
  type LevelSourceEventDto,
  type LevelSummaryDto,
  type LevelTransitionDto,
  type PageDto,
  type PointsEntryDto,
  type StateSnapshot,
} from './levels.dto.js';
import { ADMIN_RECENT_ROWS } from './levels.constants.js';
import { LevelsCursorCodec, type KeysetPosition } from './levels-cursor.js';
import { formatMultiplier } from './points-math.js';

export interface PageQuery {
  readonly cursor?: string | undefined;
  readonly limit: number;
}

export interface AdminUserLevelStateDto extends LevelSummaryDto {
  lifetimeEarnedPoints: string;
  recentEntries: AdminPointsEntryDto[];
  recentTransitions: LevelTransitionDto[];
}

export interface AdminUserLevelsDto {
  userId: string;
  data: AdminUserLevelStateDto[];
}

export interface LevelCategoryReportDto {
  category: LevelCategoryCode;
  enabled: boolean;
  publishedVersionNumber: number | null;
  levelCount: number | null;
  multiplier: string | null;
  valueUnit: 'COIN' | null;
  usersPerLevel: { levelNumber: number; users: number }[];
  recentLevelUps: (LevelTransitionDto & { userId: string })[];
  lastReconciliation: LevelReconciliationRunDto | null;
}

/** `PublicLevel`: what others see on a profile — the level, never points. */
export interface PublicLevelDto {
  category: LevelCategoryCode;
  status: 'AVAILABLE' | 'UNAVAILABLE';
  name: string;
  level: LevelSummaryDto['level'];
}

export interface LevelAuditLogDto {
  id: string;
  action: string;
  actorUserId: string | null;
  targetType: string | null;
  targetId: string | null;
  metadata: Record<string, unknown> | null;
  createdAt: string;
}

const RECENT_LEVEL_UPS = 10;

/** `(createdAt, id) < position`, newest first. */
function before(position: KeysetPosition | null, field: 'createdAt' | 'receivedAt' | 'startedAt') {
  if (!position) return {};
  return {
    OR: [{ [field]: { lt: position.createdAt } }, { [field]: position.createdAt, id: { lt: position.id } }],
  };
}

function page<R extends { id: string }, T>(
  rows: R[],
  limit: number,
  map: (row: R) => T,
  at: (row: R) => Date,
  next: (position: KeysetPosition) => string,
): PageDto<T> {
  const hasMore = rows.length > limit;
  const shown = rows.slice(0, limit);
  const last = shown.at(-1);
  return {
    data: shown.map(map),
    page: { nextCursor: hasMore && last ? next({ createdAt: at(last), id: last.id }) : null, hasMore },
  };
}

function snapshot(
  row: { totalPoints: bigint; currentLevel: number | null; versionId: string | null } | undefined,
): StateSnapshot | null {
  return row
    ? { totalPoints: row.totalPoints, currentLevel: row.currentLevel, versionId: row.versionId }
    : null;
}

/**
 * Read side of the levels (CP-005 §7): the caller's summaries, ladder and histories, and the admin
 * views (a user's states, reports, events, reconciliation runs, the levels audit log).
 */
@Injectable()
export class LevelsQueryService {
  private readonly cursors: LevelsCursorCodec;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(APP_CONFIG) config: AppConfig,
  ) {
    this.cursors = new LevelsCursorCodec(config.live.cursorKey);
  }

  private position(cursor: string | undefined, scope: string): KeysetPosition | null {
    if (cursor === undefined) return null;
    const position = this.cursors.decode(cursor, scope);
    if (!position) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    return position;
  }

  private async states(userId: string) {
    const rows = await this.prisma.userLevelState.findMany({ where: { userId } });
    return new Map(rows.map((r) => [r.categoryId, r]));
  }

  async mySummaries(userId: string, lang: ContentLanguage): Promise<LevelSummaryDto[]> {
    const [categories, states] = await Promise.all([loadAllCategories(this.prisma), this.states(userId)]);
    return categories.map((c) => summaryDto(c, snapshot(states.get(c.id)), lang));
  }

  /** Another user's levels for their profile (CP-005 §9.1, 7). */
  async publicLevels(userId: string, lang: ContentLanguage): Promise<PublicLevelDto[]> {
    return (await this.mySummaries(userId, lang)).map((s) => ({
      category: s.category,
      status: s.status,
      name: s.name,
      level: s.level,
    }));
  }

  async myDetail(userId: string, code: LevelCategoryCode, lang: ContentLanguage): Promise<LevelDetailDto> {
    const category = await loadCategory(this.prisma, code);
    const state = await this.prisma.userLevelState.findUnique({
      where: { userId_categoryId: { userId, categoryId: category.id } },
    });
    return detailDto(category, snapshot(state ?? undefined), lang);
  }

  private async categoryCodes(): Promise<Map<string, LevelCategoryCode>> {
    const rows = await this.prisma.levelCategory.findMany({ select: { id: true, code: true } });
    return new Map(rows.map((r) => [r.id, r.code]));
  }

  async myHistory(
    userId: string,
    code: LevelCategoryCode | undefined,
    query: PageQuery,
  ): Promise<PageDto<LevelTransitionDto>> {
    const scope = `history:${userId}:${code ?? '*'}`;
    const position = this.position(query.cursor, scope);
    const codes = await this.categoryCodes();
    const rows = await this.prisma.levelHistory.findMany({
      where: { userId, ...(code ? { category: { code } } : {}), ...before(position, 'createdAt') },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
    });
    return page(
      rows,
      query.limit,
      (r) => transitionDto(r, codes.get(r.categoryId) ?? 'ATTRACTIVENESS'),
      (r) => r.createdAt,
      (p) => this.cursors.encode(scope, p),
    );
  }

  async myPoints(
    userId: string,
    code: LevelCategoryCode | undefined,
    query: PageQuery,
  ): Promise<PageDto<PointsEntryDto>> {
    const scope = `points:${userId}:${code ?? '*'}`;
    const position = this.position(query.cursor, scope);
    const codes = await this.categoryCodes();
    const rows = await this.prisma.pointsLedgerEntry.findMany({
      where: { userId, ...(code ? { category: { code } } : {}), ...before(position, 'createdAt') },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
    });
    return page(
      rows,
      query.limit,
      (r) => pointsEntryDto(r, codes.get(r.categoryId) ?? 'ATTRACTIVENESS'),
      (r) => r.createdAt,
      (p) => this.cursors.encode(scope, p),
    );
  }

  private async versionNumbers(entries: readonly PointsLedgerEntry[]): Promise<Map<string, number>> {
    const ids = [...new Set(entries.map((e) => e.versionId).filter((id): id is string => id !== null))];
    if (ids.length === 0) return new Map();
    const rows = await this.prisma.levelCategoryVersion.findMany({
      where: { id: { in: ids } },
      select: { id: true, versionNumber: true },
    });
    return new Map(rows.map((r) => [r.id, r.versionNumber]));
  }

  /** The admin view of one user (404 when the user does not exist). */
  async adminUser(userId: string, lang: ContentLanguage = 'en'): Promise<AdminUserLevelsDto> {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { id: true } });
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    const [categories, states] = await Promise.all([loadAllCategories(this.prisma), this.states(userId)]);
    const data = await Promise.all(
      categories.map(async (c) => {
        const [entries, transitions] = await Promise.all([
          this.prisma.pointsLedgerEntry.findMany({
            where: { userId, categoryId: c.id },
            orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
            take: ADMIN_RECENT_ROWS,
          }),
          this.prisma.levelHistory.findMany({
            where: { userId, categoryId: c.id },
            orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
            take: ADMIN_RECENT_ROWS,
          }),
        ]);
        const numbers = await this.versionNumbers(entries);
        const state = states.get(c.id);
        return {
          ...summaryDto(c, snapshot(state), lang),
          lifetimeEarnedPoints: (state?.lifetimeEarnedPoints ?? 0n).toString(),
          recentEntries: entries.map((e) => adminPointsEntryDto(e, c.code, numbers)),
          recentTransitions: transitions.map((t) => transitionDto(t, c.code)),
        };
      }),
    );
    return { userId, data };
  }

  async adminEntry(entry: PointsLedgerEntry, code: LevelCategoryCode): Promise<AdminPointsEntryDto> {
    return adminPointsEntryDto(entry, code, await this.versionNumbers([entry]));
  }

  private async report(category: LoadedCategory): Promise<LevelCategoryReportDto> {
    const version = category.version;
    const [distribution, ups, lastRun] = await Promise.all([
      version
        ? this.prisma.userLevelState.groupBy({
            by: ['currentLevel'],
            where: { categoryId: category.id, versionId: version.id, currentLevel: { not: null } },
            _count: { _all: true },
          })
        : Promise.resolve([]),
      this.prisma.$queryRaw<
        {
          id: string;
          user_id: string;
          previous_level: number | null;
          new_level: number | null;
          points: bigint;
          reason: Prisma.LevelHistoryGetPayload<object>['reason'];
          created_at: Date;
        }[]
      >`
        SELECT id, user_id, previous_level, new_level, points, reason, created_at
          FROM level_history
         WHERE category_id = ${category.id}::uuid
           AND new_level IS NOT NULL
           AND (previous_level IS NULL OR new_level > previous_level)
         ORDER BY created_at DESC, id DESC
         LIMIT ${RECENT_LEVEL_UPS}`,
      this.prisma.levelReconciliationRun.findFirst({
        where: { OR: [{ category: category.code }, { category: null }] },
        orderBy: [{ startedAt: 'desc' }, { id: 'desc' }],
      }),
    ]);
    const counts = new Map(distribution.map((d) => [d.currentLevel ?? 0, d._count._all]));
    return {
      category: category.code,
      enabled: category.enabled,
      publishedVersionNumber: version?.versionNumber ?? null,
      levelCount: version ? version.levels.length : null,
      multiplier: version ? formatMultiplier(version.multiplier) : null,
      valueUnit: version?.valueUnit ?? null,
      usersPerLevel: version
        ? version.levels.map((l) => ({ levelNumber: l.levelNumber, users: counts.get(l.levelNumber) ?? 0 }))
        : [],
      recentLevelUps: ups.map((u) => ({
        id: u.id,
        userId: u.user_id,
        category: category.code,
        previousLevel: u.previous_level,
        newLevel: u.new_level,
        points: u.points.toString(),
        reason: u.reason,
        createdAt: u.created_at.toISOString(),
      })),
      lastReconciliation: lastRun ? runDto(lastRun) : null,
    };
  }

  async reports(): Promise<LevelCategoryReportDto[]> {
    const categories = await loadAllCategories(this.prisma);
    return Promise.all(categories.map((c) => this.report(c)));
  }

  async events(
    status: LevelEventStatus | undefined,
    query: PageQuery,
  ): Promise<PageDto<LevelSourceEventDto>> {
    const scope = `events:${status ?? '*'}`;
    const position = this.position(query.cursor, scope);
    const rows = await this.prisma.levelSourceEvent.findMany({
      where: { ...(status ? { status } : {}), ...before(position, 'receivedAt') },
      orderBy: [{ receivedAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
    });
    return page(
      rows,
      query.limit,
      eventDto,
      (r) => r.receivedAt,
      (p) => this.cursors.encode(scope, p),
    );
  }

  async runs(query: PageQuery): Promise<PageDto<LevelReconciliationRunDto>> {
    const scope = 'runs';
    const position = this.position(query.cursor, scope);
    const rows = await this.prisma.levelReconciliationRun.findMany({
      where: before(position, 'startedAt'),
      orderBy: [{ startedAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
    });
    return page(
      rows,
      query.limit,
      runDto,
      (r) => r.startedAt,
      (p) => this.cursors.encode(scope, p),
    );
  }

  async run(id: string): Promise<LevelReconciliationRunDto> {
    const row = await this.prisma.levelReconciliationRun.findUnique({ where: { id } });
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    return runDto(row);
  }

  async auditLogs(query: PageQuery): Promise<PageDto<LevelAuditLogDto>> {
    const scope = 'audit';
    const position = this.position(query.cursor, scope);
    const rows = await this.prisma.auditLog.findMany({
      where: { action: { startsWith: 'levels.' }, ...before(position, 'createdAt') },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
    });
    return page(
      rows,
      query.limit,
      (r) => ({
        id: r.id,
        action: r.action,
        actorUserId: r.actorUserId,
        targetType: r.targetType,
        targetId: r.targetId,
        metadata:
          r.metadata !== null && typeof r.metadata === 'object' && !Array.isArray(r.metadata)
            ? (r.metadata as Record<string, unknown>)
            : null,
        createdAt: r.createdAt.toISOString(),
      }),
      (r) => r.createdAt,
      (p) => this.cursors.encode(scope, p),
    );
  }
}
