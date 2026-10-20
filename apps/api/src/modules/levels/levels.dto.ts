import type { ContentLanguage } from '../../common/http/content-language.js';
import type {
  LevelCategoryCode,
  LevelHistory,
  LevelReconciliationRun,
  LevelSourceEvent,
  PointsLedgerEntry,
  Prisma,
} from '../../generated/prisma/client.js';
import type { LevelDef, LoadedCategory } from './level-catalog.js';
import { isAvailable } from './level-catalog.js';
import { progressFor } from './level-math.js';
import { formatMultiplier, parseMultiplier } from './points-math.js';

// Response shapes of openapi v1.4-levels (DRAFT, CP-005). Amounts are decimal strings.

export interface LevelBriefDto {
  levelNumber: number;
  name: string;
  requiredPoints: string;
  iconKey: string | null;
}

export interface LevelSummaryDto {
  category: LevelCategoryCode;
  status: 'AVAILABLE' | 'UNAVAILABLE';
  name: string;
  description: string;
  points: string;
  level: LevelBriefDto | null;
  nextLevel: LevelBriefDto | null;
  pointsToNext: string | null;
  progressPercent: number | null;
  maxLevel: boolean;
  versionNumber: number | null;
}

export interface LevelDetailDto extends LevelSummaryDto {
  levels: LevelBriefDto[];
}

export interface StateSnapshot {
  readonly totalPoints: bigint;
  readonly currentLevel: number | null;
  readonly versionId: string | null;
}

export function brief(level: LevelDef, lang: ContentLanguage): LevelBriefDto {
  return {
    levelNumber: level.levelNumber,
    name: lang === 'en' ? level.nameEn : level.nameAr,
    requiredPoints: level.requiredPoints.toString(),
    iconKey: level.iconKey,
  };
}

/**
 * A user's summary for one category. The level shown is the stored one when it was computed
 * under the current version (it may be a kept level, KEEP_LEVEL); otherwise it is computed.
 */
export function summaryDto(
  category: LoadedCategory,
  state: StateSnapshot | null,
  lang: ContentLanguage,
): LevelSummaryDto {
  const points = state?.totalPoints ?? 0n;
  const base = {
    category: category.code,
    name: lang === 'en' ? category.nameEn : category.nameAr,
    description: lang === 'en' ? category.descriptionEn : category.descriptionAr,
    points: points.toString(),
  };
  if (!isAvailable(category)) {
    return {
      ...base,
      status: 'UNAVAILABLE',
      level: null,
      nextLevel: null,
      pointsToNext: null,
      progressPercent: null,
      maxLevel: false,
      versionNumber: null,
    };
  }
  const version = category.version;
  const floor = state && state.versionId === version.id ? state.currentLevel : null;
  const progress = progressFor(version.levels, points, floor);
  return {
    ...base,
    status: 'AVAILABLE',
    level: progress.current ? brief(progress.current, lang) : null,
    nextLevel: progress.next ? brief(progress.next, lang) : null,
    pointsToNext: progress.pointsToNext === null ? null : progress.pointsToNext.toString(),
    progressPercent: progress.progressPercent,
    maxLevel: progress.maxLevel,
    versionNumber: version.versionNumber,
  };
}

export function detailDto(
  category: LoadedCategory,
  state: StateSnapshot | null,
  lang: ContentLanguage,
): LevelDetailDto {
  return {
    ...summaryDto(category, state, lang),
    levels: isAvailable(category) ? category.version.levels.map((l) => brief(l, lang)) : [],
  };
}

export interface LevelTransitionDto {
  id: string;
  category: LevelCategoryCode;
  previousLevel: number | null;
  newLevel: number | null;
  points: string;
  reason: LevelHistory['reason'];
  createdAt: string;
}

export function transitionDto(row: LevelHistory, code: LevelCategoryCode): LevelTransitionDto {
  return {
    id: row.id,
    category: code,
    previousLevel: row.previousLevel,
    newLevel: row.newLevel,
    points: row.points.toString(),
    reason: row.reason,
    createdAt: row.createdAt.toISOString(),
  };
}

export interface PointsEntryDto {
  id: string;
  category: LevelCategoryCode;
  entryType: PointsLedgerEntry['entryType'];
  sourceType: PointsLedgerEntry['sourceType'];
  pointsDelta: string;
  createdAt: string;
}

/** Public fields only (no source ids, values, reasons or actors). */
export function pointsEntryDto(row: PointsLedgerEntry, code: LevelCategoryCode): PointsEntryDto {
  return {
    id: row.id,
    category: code,
    entryType: row.entryType,
    sourceType: row.sourceType,
    pointsDelta: row.pointsDelta.toString(),
    createdAt: row.createdAt.toISOString(),
  };
}

export interface AdminPointsEntryDto extends PointsEntryDto {
  sourceTransactionId: string | null;
  sourceValue: string | null;
  multiplierUsed: string | null;
  versionNumber: number | null;
  reason: string | null;
  createdBy: string | null;
}

function decimalText(value: Prisma.Decimal | null): string | null {
  if (value === null) return null;
  const scaled = parseMultiplier(value.toFixed(6));
  return scaled === null ? null : formatMultiplier(scaled);
}

export function adminPointsEntryDto(
  row: PointsLedgerEntry,
  code: LevelCategoryCode,
  versionNumbers: ReadonlyMap<string, number>,
): AdminPointsEntryDto {
  return {
    ...pointsEntryDto(row, code),
    sourceTransactionId: row.sourceTransactionId,
    sourceValue: row.sourceValue === null ? null : row.sourceValue.toString(),
    multiplierUsed: decimalText(row.multiplierUsed),
    versionNumber: row.versionId ? (versionNumbers.get(row.versionId) ?? null) : null,
    reason: row.reason,
    createdBy: row.createdById,
  };
}

const versionInclude = {
  category: { select: { code: true } },
  levels: { orderBy: { levelNumber: 'asc' } },
} as const satisfies Prisma.LevelCategoryVersionInclude;

export type VersionRow = Prisma.LevelCategoryVersionGetPayload<{ include: typeof versionInclude }>;
export const VERSION_INCLUDE = versionInclude;

export interface AdminLevelVersionDto {
  id: string;
  category: LevelCategoryCode;
  versionNumber: number;
  status: VersionRow['status'];
  multiplier: string | null;
  valueUnit: VersionRow['valueUnit'];
  reversalPolicy: VersionRow['reversalPolicy'];
  luckyGiftsCountAsSupport: boolean;
  levels: {
    levelNumber: number;
    nameAr: string;
    nameEn: string;
    requiredPoints: string;
    iconKey: string | null;
  }[];
  createdAt: string;
  createdBy: string | null;
  publishedAt: string | null;
  publishedBy: string | null;
}

export function versionDto(row: VersionRow): AdminLevelVersionDto {
  return {
    id: row.id,
    category: row.category.code,
    versionNumber: row.versionNumber,
    status: row.status,
    multiplier: decimalText(row.multiplier),
    valueUnit: row.valueUnit,
    reversalPolicy: row.reversalPolicy,
    luckyGiftsCountAsSupport: row.luckyGiftsCountAsSupport,
    levels: row.levels.map((l) => ({
      levelNumber: l.levelNumber,
      nameAr: l.nameAr,
      nameEn: l.nameEn,
      requiredPoints: l.requiredPoints.toString(),
      iconKey: l.iconKey,
    })),
    createdAt: row.createdAt.toISOString(),
    createdBy: row.createdById,
    publishedAt: row.publishedAt?.toISOString() ?? null,
    publishedBy: row.publishedById,
  };
}

export interface LevelReconciliationRunDto {
  id: string;
  category: LevelCategoryCode | null;
  mode: LevelReconciliationRun['mode'];
  status: LevelReconciliationRun['status'];
  startedAt: string;
  completedAt: string | null;
  eventsInspected: number;
  statesInspected: number;
  failedEvents: number;
  unprocessedEvents: number;
  stateMismatches: number;
  corrected: number;
  errors: string[];
  initiatedBy: string | null;
}

export function runDto(row: LevelReconciliationRun): LevelReconciliationRunDto {
  return {
    id: row.id,
    category: row.category,
    mode: row.mode,
    status: row.status,
    startedAt: row.startedAt.toISOString(),
    completedAt: row.completedAt?.toISOString() ?? null,
    eventsInspected: row.eventsInspected,
    statesInspected: row.statesInspected,
    failedEvents: row.failedEvents,
    unprocessedEvents: row.unprocessedEvents,
    stateMismatches: row.stateMismatches,
    corrected: row.corrected,
    errors: Array.isArray(row.errors) ? row.errors.map(String).slice(0, 50) : [],
    initiatedBy: row.initiatedById,
  };
}

export interface LevelSourceEventDto {
  id: string;
  type: LevelSourceEvent['type'];
  sourceTransactionId: string;
  status: LevelSourceEvent['status'];
  attempts: number;
  lastError: string | null;
  receivedAt: string;
  processedAt: string | null;
}

export function eventDto(row: LevelSourceEvent): LevelSourceEventDto {
  return {
    id: row.id,
    type: row.type,
    sourceTransactionId: row.sourceTransactionId,
    status: row.status,
    attempts: row.attempts,
    lastError: row.lastError,
    receivedAt: row.receivedAt.toISOString(),
    processedAt: row.processedAt?.toISOString() ?? null,
  };
}

export interface PageDto<T> {
  data: T[];
  page: { nextCursor: string | null; hasMore: boolean };
}
