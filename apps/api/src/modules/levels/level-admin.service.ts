import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import type { LevelCategoryCode, LevelReconciliationMode, Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { loadAllCategories, loadCategory } from './level-catalog.js';
import type { AdminActor } from './level-config.service.js';
import { LevelEventsService } from './level-events.service.js';
import { LevelProgressService, NegativeTotalError } from './level-progress.service.js';
import {
  eventDto,
  runDto,
  type AdminPointsEntryDto,
  type LevelReconciliationRunDto,
  type LevelSourceEventDto,
} from './levels.dto.js';
import { LevelsQueryService, type AdminUserLevelsDto } from './levels-query.service.js';

export interface AdjustmentInput {
  readonly category: LevelCategoryCode;
  readonly pointsDelta: bigint;
  readonly reason: string;
  /** v1.46-levels (D169): a deduction marked as fraud — the only one that lowers the level. */
  readonly fraud: boolean;
}

export interface AdjustmentResultDto {
  entry: AdminPointsEntryDto;
  levels: AdminUserLevelsDto;
}

/** PENDING events older than this are reported as stuck by reconciliation. */
const STALE_PENDING_MS = 10 * 60 * 1000;
const MAX_RUN_ERRORS = 50;

/**
 * Admin operations on users and the event inbox (CP-005 §7; the brief's
 * LevelAdministrationService and LevelReconciliationService). Every mutation is audited and
 * appends to the ledger; history is never rewritten.
 */
@Injectable()
export class LevelAdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly progress: LevelProgressService,
    private readonly events: LevelEventsService,
    private readonly query: LevelsQueryService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
  ) {}

  private async requireUser(userId: string): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { id: true } });
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
  }

  /** Rebuilds one category's state for a user from the ledger (repairs drift; never edits entries). */
  async recalculate(userId: string, code: LevelCategoryCode, actor: AdminActor): Promise<AdminUserLevelsDto> {
    await this.requireUser(userId);
    await this.prisma.$transaction(async (tx) => {
      const category = await loadCategory(tx, code, 'share');
      const before = await tx.userLevelState.findUnique({
        where: { userId_categoryId: { userId, categoryId: category.id } },
      });
      const changed = await this.progress.rebuild(tx, category, userId, 'RECALCULATED');
      const after = await tx.userLevelState.findUniqueOrThrow({
        where: { userId_categoryId: { userId, categoryId: category.id } },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.LEVELS_USER_RECALCULATE,
        actorUserId: actor.userId,
        targetType: 'user',
        targetId: userId,
        metadata: {
          category: code,
          changed,
          before: before ? { points: before.totalPoints.toString(), level: before.currentLevel } : null,
          after: { points: after.totalPoints.toString(), level: after.currentLevel },
        },
        ip: actor.ip,
        requestId: actor.requestId,
      });
    });
    return this.query.adminUser(userId);
  }

  /**
   * A manual ADJUSTMENT entry (reason and Idempotency-Key required). The same key with the same
   * request replays the first result; with a different request it is IDEMPOTENCY_CONFLICT.
   */
  async adjust(
    userId: string,
    input: AdjustmentInput,
    key: string,
    actor: AdminActor,
  ): Promise<AdjustmentResultDto> {
    await this.requireUser(userId);
    const replay = async (): Promise<AdjustmentResultDto | null> => {
      const existing = await this.prisma.pointsLedgerEntry.findUnique({
        where: { idempotencyKey: key },
        include: { category: { select: { code: true } } },
      });
      if (!existing) return null;
      const same =
        existing.userId === userId &&
        existing.category.code === input.category &&
        existing.pointsDelta === input.pointsDelta &&
        existing.reason === input.reason &&
        existing.fraud === input.fraud &&
        existing.sourceType === 'ADMIN';
      if (!same) throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
      return {
        entry: await this.query.adminEntry(existing, existing.category.code),
        levels: await this.query.adminUser(userId),
      };
    };
    const first = await replay();
    if (first) return first;

    let created: Awaited<ReturnType<LevelProgressService['apply']>>;
    try {
      created = await this.prisma.$transaction(async (tx) => {
        const category = await loadCategory(tx, input.category, 'share');
        const result = await this.progress.apply(tx, category, {
          userId,
          entryType: 'ADJUSTMENT',
          sourceType: 'ADMIN',
          pointsDelta: input.pointsDelta,
          idempotencyKey: key,
          reason: input.reason,
          fraud: input.fraud,
          createdById: actor.userId,
        });
        if (result.kind === 'applied') {
          await this.audit.recordIn(tx, {
            action: AuditAction.LEVELS_USER_ADJUST,
            actorUserId: actor.userId,
            targetType: 'user',
            targetId: userId,
            metadata: {
              category: input.category,
              entryId: result.entry.id,
              pointsDelta: input.pointsDelta.toString(),
              reason: input.reason,
              fraud: input.fraud,
              before: {
                points: (result.state.totalPoints - input.pointsDelta).toString(),
                level: result.state.previousLevel,
              },
              after: { points: result.state.totalPoints.toString(), level: result.state.currentLevel },
            },
            ip: actor.ip,
            requestId: actor.requestId,
          });
        }
        return result;
      });
    } catch (err) {
      if (err instanceof NegativeTotalError) {
        throw new AppException(ErrorCode.LEVEL_CONFIG_INVALID, undefined, [
          { field: 'pointsDelta', issue: 'total_below_zero' },
        ]);
      }
      throw err;
    }
    if (created.kind !== 'applied') {
      // A concurrent request with the same key won the insert.
      const again = await replay();
      if (again) return again;
      throw new Error('adjustment neither applied nor found');
    }
    return {
      entry: await this.query.adminEntry(created.entry, input.category),
      levels: await this.query.adminUser(userId),
    };
  }

  /** Re-processes one event (FAILED or PENDING). Safe to repeat. */
  async retryEvent(eventId: string, actor: AdminActor): Promise<LevelSourceEventDto> {
    const before = await this.prisma.levelSourceEvent.findUnique({ where: { id: eventId } });
    if (!before) throw new AppException(ErrorCode.NOT_FOUND);
    const after = await this.events.process(eventId);
    await this.audit.record({
      action: AuditAction.LEVELS_EVENT_RETRY,
      actorUserId: actor.userId,
      targetType: 'level_event',
      targetId: eventId,
      metadata: { before: before.status, after: after.status, attempts: after.attempts },
      ip: actor.ip,
      requestId: actor.requestId,
    });
    return eventDto(after);
  }

  /**
   * Compares every state with its ledger (Σ deltas, Σ EARN) and inspects the inbox. DRY_RUN only
   * reports; REPAIR rebuilds mismatched states and retries FAILED and stale PENDING events.
   */
  async reconcile(
    mode: LevelReconciliationMode,
    code: LevelCategoryCode | null,
    actor: AdminActor,
  ): Promise<LevelReconciliationRunDto> {
    const run = await this.prisma.levelReconciliationRun.create({
      data: { mode, category: code, initiatedById: actor.userId },
    });
    const errors: string[] = [];
    const counts = {
      eventsInspected: 0,
      statesInspected: 0,
      failedEvents: 0,
      unprocessedEvents: 0,
      stateMismatches: 0,
      corrected: 0,
    };
    let status: 'COMPLETED' | 'FAILED' = 'COMPLETED';
    try {
      const categories = (await loadAllCategories(this.prisma)).filter(
        (c) => code === null || c.code === code,
      );
      for (const category of categories) {
        const mismatches = await this.prisma.$queryRaw<{ user_id: string }[]>`
          SELECT s.user_id
            FROM user_level_states s
            LEFT JOIN (
              SELECT user_id,
                     SUM(points_delta)::bigint AS total,
                     COALESCE(SUM(points_delta) FILTER (WHERE entry_type = 'EARN'), 0)::bigint AS lifetime
                FROM points_ledger
               WHERE category_id = ${category.id}::uuid
               GROUP BY user_id
            ) l ON l.user_id = s.user_id
           WHERE s.category_id = ${category.id}::uuid
             AND (s.total_points <> GREATEST(COALESCE(l.total, 0), 0)
                  OR s.lifetime_earned_points <> COALESCE(l.lifetime, 0))
           ORDER BY s.user_id`;
        counts.statesInspected += await this.prisma.userLevelState.count({
          where: { categoryId: category.id },
        });
        counts.stateMismatches += mismatches.length;
        if (mode === 'REPAIR') {
          for (const { user_id: userId } of mismatches) {
            try {
              const fixed = await this.prisma.$transaction(async (tx) => {
                const locked = await loadCategory(tx, category.code, 'share');
                return this.progress.rebuild(tx, locked, userId, 'RECALCULATED');
              });
              if (fixed) counts.corrected++;
            } catch (err) {
              errors.push(`state:${category.code}:${userId}:${err instanceof Error ? err.message : 'error'}`);
            }
          }
        }
      }

      const staleBefore = new Date(this.clock.now().getTime() - STALE_PENDING_MS);
      const inspect = await this.prisma.levelSourceEvent.findMany({
        where: {
          OR: [{ status: 'FAILED' }, { status: 'PENDING', receivedAt: { lt: staleBefore } }],
        },
        orderBy: [{ receivedAt: 'asc' }, { id: 'asc' }],
        take: 1000,
      });
      counts.eventsInspected = await this.prisma.levelSourceEvent.count();
      counts.failedEvents = inspect.filter((e) => e.status === 'FAILED').length;
      counts.unprocessedEvents = inspect.length - counts.failedEvents;
      if (mode === 'REPAIR') {
        for (const event of inspect) {
          const after = await this.events.process(event.id);
          if (after.status === 'PROCESSED' || after.status === 'SKIPPED') counts.corrected++;
          else errors.push(`event:${event.id}:${after.lastError ?? after.status}`);
        }
      }
    } catch (err) {
      status = 'FAILED';
      errors.push(`run:${err instanceof Error ? err.message : 'error'}`);
    }

    const finished = await this.prisma.$transaction(async (tx: Prisma.TransactionClient) => {
      const row = await tx.levelReconciliationRun.update({
        where: { id: run.id },
        data: { ...counts, status, completedAt: this.clock.now(), errors: errors.slice(0, MAX_RUN_ERRORS) },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.LEVELS_RECONCILIATION_RUN,
        actorUserId: actor.userId,
        targetType: 'level_reconciliation',
        targetId: run.id,
        metadata: { mode, category: code, status, ...counts },
        ip: actor.ip,
        requestId: actor.requestId,
      });
      return row;
    });
    return runDto(finished);
  }
}
