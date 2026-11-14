import type { Prisma } from '../../generated/prisma/client.js';
import { bumpRoomsSeatingBothIn } from '../live/live-seats.store.js';
import { cpLevelFor } from './couples.constants.js';

type Tx = Prisma.TransactionClient;

/** v1.24-live (CP-021, D112): why a couple's CP points grew (`cp_points_source`). */
export type CpPointsSource = 'GIFT' | 'TASK';

export interface CpPointsGain {
  readonly coupleId: string;
  readonly points: number;
  readonly source: CpPointsSource;
  /** The gift or task claim that gave the points (one ledger row per source and reference). */
  readonly referenceId: string;
  readonly at: Date;
}

/**
 * Records a CP points gain in the append-only `cp_points_ledger` (the couples ranking reads it),
 * inside the caller's transaction, after the caller already added the points to
 * `cp_couples.points` (the CP gift path, CONVENTIONS §10.21).
 */
export async function recordCpPointsIn(tx: Tx, gain: CpPointsGain): Promise<void> {
  await tx.cpPointsEntry.create({
    data: {
      coupleId: gain.coupleId,
      source: gain.source,
      referenceId: gain.referenceId,
      points: gain.points,
      createdAt: gain.at,
    },
  });
}

/**
 * Adds `points` CP points to an ongoing couple inside the caller's transaction: locks the couple,
 * raises its points and tier, writes the ledger row, and (D111) raises the seat version of the rooms
 * where both partners sit when the tier moved. Returns null when the couple ended (nothing written).
 */
export async function addCpPointsIn(
  tx: Tx,
  gain: CpPointsGain,
): Promise<{ points: bigint; level: number } | null> {
  const [couple] = await tx.$queryRaw<
    { points: bigint; level: number; user_a_id: string; user_b_id: string }[]
  >`SELECT points, level, user_a_id::text AS user_a_id, user_b_id::text AS user_b_id
      FROM cp_couples WHERE id = ${gain.coupleId}::uuid AND ended_at IS NULL FOR UPDATE`;
  if (!couple) return null;
  const points = couple.points + BigInt(gain.points);
  const level = cpLevelFor(points);
  await tx.cpCouple.update({ where: { id: gain.coupleId }, data: { points, level } });
  await recordCpPointsIn(tx, gain);
  if (level !== couple.level) await bumpRoomsSeatingBothIn(tx, couple.user_a_id, couple.user_b_id);
  return { points, level };
}
