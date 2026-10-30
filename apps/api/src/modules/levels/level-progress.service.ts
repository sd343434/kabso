import { Injectable } from '@nestjs/common';
import { Clock } from '../../common/time/clock.js';
import type {
  LevelTransitionReason,
  PointsEntryType,
  PointsLedgerEntry,
  PointsSourceType,
  Prisma,
} from '../../generated/prisma/client.js';
import { grantLevelRewardsIn } from '../bag/bag-grants.js';
import { awardCharmMedalsIn } from '../medals/medal-awards.js';
import type { LoadedCategory } from './level-catalog.js';
import { progressFor } from './level-math.js';
import { addPoints, formatMultiplier } from './points-math.js';
import { supportFramesFor } from './support-tiers.js';
import { uuidv7 } from './uuidv7.js';

type Tx = Prisma.TransactionClient;

interface StateRow {
  id: string;
  total_points: bigint;
  lifetime_earned_points: bigint;
  current_level: number | null;
  version_id: string | null;
}

export interface EntryInput {
  readonly userId: string;
  readonly entryType: PointsEntryType;
  readonly sourceType: PointsSourceType;
  /** Positive for EARN; negative for REVERSAL (the amount to take back); any non-zero for ADJUSTMENT. */
  readonly pointsDelta: bigint;
  readonly sourceTransactionId?: string | null;
  readonly sourceValue?: bigint | null;
  readonly multiplierUsed?: bigint | null;
  readonly idempotencyKey?: string | null;
  readonly reversalOfEntryId?: string | null;
  readonly reason?: string | null;
  readonly createdById?: string | null;
  /** History reason when the level changes (default from the entry type). */
  readonly transitionReason?: LevelTransitionReason;
}

export interface StateAfter {
  readonly totalPoints: bigint;
  readonly lifetimeEarnedPoints: bigint;
  readonly currentLevel: number | null;
  readonly previousLevel: number | null;
}

export type ApplyResult =
  | { readonly kind: 'applied'; readonly entry: PointsLedgerEntry; readonly state: StateAfter }
  | { readonly kind: 'duplicate' }
  | { readonly kind: 'nothing_left' };

/** Thrown when an entry would take a total below zero (manual adjustments only). */
export class NegativeTotalError extends Error {}

const DEFAULT_REASON: Readonly<Record<PointsEntryType, LevelTransitionReason>> = {
  EARN: 'EARNED',
  REVERSAL: 'REVERSED',
  ADJUSTMENT: 'ADJUSTED',
};

/**
 * Points ledger + level state (CP-005 §6; the brief's PointsLedgerService, LevelCalculationService
 * and LevelProgressService). Every write runs inside the caller's transaction:
 *
 * 1. the user's state row is created if missing and locked (`FOR UPDATE`), so concurrent entries
 *    for the same user and category serialize;
 * 2. the ledger row is inserted with `ON CONFLICT DO NOTHING` — the partial unique indexes
 *    (one EARN and one REVERSAL per source and category; one row per idempotency key) turn a
 *    duplicate delivery into a no-op instead of a second credit;
 * 3. total, lifetime and level are updated, and a history row is written when the level changes.
 */
@Injectable()
export class LevelProgressService {
  constructor(private readonly clock: Clock) {}

  private async lockState(tx: Tx, userId: string, categoryId: string): Promise<StateRow> {
    // D148 (fewer round trips): one statement creates the row when missing and locks it either way
    // (ON CONFLICT DO UPDATE locks the existing row like SELECT … FOR UPDATE; the no-op SET changes
    // nothing). Was an INSERT … DO NOTHING then a SELECT … FOR UPDATE.
    const rows = await tx.$queryRaw<StateRow[]>`
      INSERT INTO user_level_states (id, user_id, category_id, updated_at)
      VALUES (${uuidv7()}::uuid, ${userId}::uuid, ${categoryId}::uuid, now())
      ON CONFLICT (user_id, category_id) DO UPDATE SET updated_at = user_level_states.updated_at
      RETURNING id, total_points, lifetime_earned_points, current_level, version_id`;
    const row = rows[0];
    if (!row) throw new Error('user_level_states row missing after insert');
    return row;
  }

  /** The level for `total` under the category's published version and reversal policy. */
  private levelAfter(
    category: LoadedCategory,
    state: StateRow,
    total: bigint,
    entryType: PointsEntryType | null,
  ) {
    const version = category.version;
    if (!version) return state.current_level;
    const keep =
      entryType === 'REVERSAL' && version.reversalPolicy === 'KEEP_LEVEL' && state.version_id === version.id
        ? state.current_level
        : null;
    return progressFor(version.levels, total, keep).current?.levelNumber ?? null;
  }

  async apply(tx: Tx, category: LoadedCategory, input: EntryInput): Promise<ApplyResult> {
    const state = await this.lockState(tx, input.userId, category.id);
    let delta = input.pointsDelta;
    if (input.entryType === 'REVERSAL') {
      // A reversal takes back what was earned, but never below zero (an admin may have removed
      // points in between).
      const wanted = -delta;
      delta = -(wanted < state.total_points ? wanted : state.total_points);
      if (delta === 0n) return { kind: 'nothing_left' };
    }
    const total = addPoints(state.total_points, delta);
    if (total < 0n) throw new NegativeTotalError('total would go below zero');

    const version = category.version;
    const created = await tx.pointsLedgerEntry.createManyAndReturn({
      data: [
        {
          userId: input.userId,
          categoryId: category.id,
          entryType: input.entryType,
          sourceType: input.sourceType,
          sourceTransactionId: input.sourceTransactionId ?? null,
          sourceValue: input.sourceValue ?? null,
          pointsDelta: delta,
          multiplierUsed:
            input.multiplierUsed === undefined || input.multiplierUsed === null
              ? null
              : formatMultiplier(input.multiplierUsed),
          versionId: version?.id ?? null,
          idempotencyKey: input.idempotencyKey ?? null,
          reversalOfEntryId: input.reversalOfEntryId ?? null,
          reason: input.reason ?? null,
          createdById: input.createdById ?? null,
        },
      ],
      skipDuplicates: true,
    });
    const entry = created[0];
    if (!entry) return { kind: 'duplicate' };

    const lifetime =
      input.entryType === 'EARN'
        ? addPoints(state.lifetime_earned_points, delta)
        : state.lifetime_earned_points;
    const level = this.levelAfter(category, state, total, input.entryType);
    const now = this.clock.now();
    await tx.userLevelState.update({
      where: { id: state.id },
      data: {
        totalPoints: total,
        lifetimeEarnedPoints: lifetime,
        currentLevel: level,
        versionId: version?.id ?? state.version_id,
        calculatedAt: now,
        ...(input.entryType === 'EARN' ? { lastQualifiedActivityAt: now } : {}),
      },
    });
    if (level !== state.current_level) {
      await tx.levelHistory.create({
        data: {
          userId: input.userId,
          categoryId: category.id,
          previousLevel: state.current_level,
          newLevel: level,
          points: total,
          reason: input.transitionReason ?? DEFAULT_REASON[input.entryType],
          ledgerEntryId: entry.id,
          versionId: version?.id ?? null,
        },
      });
      await this.charmMedals(tx, category, input.userId, level, state.current_level);
      await this.supportFrames(tx, category, input.userId, level, state.current_level);
    }
    return {
      kind: 'applied',
      entry,
      state: {
        totalPoints: total,
        lifetimeEarnedPoints: lifetime,
        currentLevel: level,
        previousLevel: state.current_level,
      },
    };
  }

  /**
   * Rebuilds a user's state from the ledger (Σ deltas; lifetime = Σ EARN deltas) and
   * re-evaluates the level under the published version. Returns whether anything changed.
   */
  async rebuild(
    tx: Tx,
    category: LoadedCategory,
    userId: string,
    reason: LevelTransitionReason,
  ): Promise<boolean> {
    const state = await this.lockState(tx, userId, category.id);
    const sums = await tx.$queryRaw<{ total: bigint | null; lifetime: bigint | null }[]>`
      SELECT SUM(points_delta)::bigint AS total,
             (SUM(points_delta) FILTER (WHERE entry_type = 'EARN'))::bigint AS lifetime
        FROM points_ledger
       WHERE user_id = ${userId}::uuid AND category_id = ${category.id}::uuid`;
    const total = sums[0]?.total ?? 0n;
    const lifetime = sums[0]?.lifetime ?? 0n;
    const clampedTotal = total < 0n ? 0n : total;
    return this.writeState(tx, category, userId, state, clampedTotal, lifetime, reason, null);
  }

  /** Re-evaluates the level for the current total (a new version was published). */
  async reevaluate(
    tx: Tx,
    category: LoadedCategory,
    userId: string,
    reason: LevelTransitionReason,
  ): Promise<boolean> {
    const state = await this.lockState(tx, userId, category.id);
    return this.writeState(
      tx,
      category,
      userId,
      state,
      state.total_points,
      state.lifetime_earned_points,
      reason,
      null,
    );
  }

  private async writeState(
    tx: Tx,
    category: LoadedCategory,
    userId: string,
    state: StateRow,
    total: bigint,
    lifetime: bigint,
    reason: LevelTransitionReason,
    ledgerEntryId: string | null,
  ): Promise<boolean> {
    const version = category.version;
    const keep =
      version?.reversalPolicy === 'KEEP_LEVEL' && state.version_id === version.id
        ? state.current_level
        : null;
    const level = version
      ? (progressFor(version.levels, total, keep).current?.levelNumber ?? null)
      : state.current_level;
    const changed =
      total !== state.total_points ||
      lifetime !== state.lifetime_earned_points ||
      level !== state.current_level ||
      (version?.id ?? state.version_id) !== state.version_id;
    if (!changed) return false;
    await tx.userLevelState.update({
      where: { id: state.id },
      data: {
        totalPoints: total,
        lifetimeEarnedPoints: lifetime,
        currentLevel: level,
        versionId: version?.id ?? state.version_id,
        calculatedAt: this.clock.now(),
      },
    });
    if (level !== state.current_level) {
      await tx.levelHistory.create({
        data: {
          userId,
          categoryId: category.id,
          previousLevel: state.current_level,
          newLevel: level,
          points: total,
          reason,
          ledgerEntryId,
          versionId: version?.id ?? null,
        },
      });
      await this.charmMedals(tx, category, userId, level, state.current_level);
      await this.supportFrames(tx, category, userId, level, state.current_level);
    }
    return true;
  }

  /**
   * v1.21-live (CP-018, §10.21): a charm (`ATTRACTIVENESS`) level that went up to 10, 50 or 100
   * awards the charm medals, in the same transaction.
   */
  private async charmMedals(
    tx: Tx,
    category: LoadedCategory,
    userId: string,
    level: number | null,
    previous: number | null,
  ): Promise<void> {
    if (category.code !== 'ATTRACTIVENESS' || level === null || level <= (previous ?? 0)) return;
    await awardCharmMedalsIn(tx, userId, level);
  }

  /**
   * v1.43-levels (D169, §10.22): a support (`SUPPORT`) level that went up gives the avatar frame
   * of every support tier reached so far that the user does not own yet (bag `AVATAR_FRAME`,
   * source LEVEL_REWARD, not worn), in the same transaction. Frames are kept for good: a level
   * that goes down (a reversal, a new version) takes nothing back.
   */
  private async supportFrames(
    tx: Tx,
    category: LoadedCategory,
    userId: string,
    level: number | null,
    previous: number | null,
  ): Promise<void> {
    if (category.code !== 'SUPPORT' || level === null || level <= (previous ?? 0)) return;
    await grantLevelRewardsIn(tx, userId, supportFramesFor(level));
  }
}
