/**
 * v1.50-live (D229, CONVENTIONS §10.80): «PK أحكام» inside a PK transaction — the server's draw, the per-host history
 * of dares seen (a bitmap over `pk_dares.seq_no`) and the PK points (one `pk_point_events` row per match, host and
 * kind, so a retry never counts twice). No Nest dependencies (the PK service and the tests use it).
 */
import { randomInt } from 'node:crypto';
import type { Prisma } from '../../../generated/prisma/client.js';
import { AuditAction } from '../../../common/audit/audit.service.js';
import { awardPkMedalsIn } from '../../medals/medal-awards.js';
import { PK_DARE_LEVELS, type PkDareLevel } from './pk-dare-rules.js';

type Tx = Prisma.TransactionClient;

export type PkPointKind = 'WIN' | 'DRAW' | 'LOSS' | 'DARE_REFUSED';

/**
 * Writes one PK points event and its record change (idempotent by match, host and kind). `counter`: the record column
 * that grows by one with it. Returns false when that event was already written.
 */
export async function addPkPointsIn(
  tx: Tx,
  input: {
    matchId: string;
    hostId: string;
    kind: PkPointKind;
    points: number;
    counter: 'wins' | 'losses' | 'draws' | 'dares_refused';
    now: Date;
  },
): Promise<boolean> {
  const at = input.now.toISOString();
  const inserted = await tx.$executeRaw`
    INSERT INTO pk_point_events (match_id, host_id, kind, points, created_at)
    VALUES (${input.matchId}::uuid, ${input.hostId}::uuid, ${input.kind}, ${input.points}, ${at}::timestamptz)
    ON CONFLICT DO NOTHING`;
  if (inserted === 0) return false;
  const one = (c: string) => (input.counter === c ? 1 : 0);
  const [record] = await tx.$queryRaw<{ points: number }[]>`
    INSERT INTO pk_host_records (host_id, wins, losses, draws, points, dares_done, dares_refused, updated_at)
    VALUES (${input.hostId}::uuid, ${one('wins')}, ${one('losses')}, ${one('draws')}, ${input.points}, 0,
            ${one('dares_refused')}, ${at}::timestamptz)
    ON CONFLICT (host_id) DO UPDATE
       SET wins = pk_host_records.wins + EXCLUDED.wins, losses = pk_host_records.losses + EXCLUDED.losses,
           draws = pk_host_records.draws + EXCLUDED.draws, points = pk_host_records.points + EXCLUDED.points,
           dares_refused = pk_host_records.dares_refused + EXCLUDED.dares_refused,
           updated_at = EXCLUDED.updated_at
    RETURNING points`;
  // D300 «لاعب الأحكام»: the medal follows the new total in this transaction (a level never goes down).
  if (record && input.points > 0) await awardPkMedalsIn(tx, input.hostId, record.points, input.now);
  await tx.auditLog.create({
    data: {
      action: AuditAction.LIVE_PK_POINTS,
      actorUserId: null,
      targetType: 'pk_match',
      targetId: input.matchId,
      metadata: { host: input.hostId, kind: input.kind, points: input.points },
    },
  });
  return true;
}

/** A dare done: the loser's «dares done» grows by one (the caller's status change guards it). */
export async function addPkDareDoneIn(tx: Tx, hostId: string, now: Date): Promise<void> {
  await tx.$executeRaw`
    INSERT INTO pk_host_records (host_id, wins, losses, draws, points, dares_done, dares_refused, updated_at)
    VALUES (${hostId}::uuid, 0, 0, 0, 0, 1, 0, ${now.toISOString()}::timestamptz)
    ON CONFLICT (host_id) DO UPDATE
       SET dares_done = pk_host_records.dares_done + 1, updated_at = EXCLUDED.updated_at`;
}

/** Makes the hosts' history rows exist and hold a bit for every dare number; locks them (sorted). */
async function seenRowsIn(tx: Tx, hostIds: readonly string[], now: Date): Promise<void> {
  const [max] = await tx.$queryRaw<{ n: number }[]>`SELECT COALESCE(max(seq_no), 0)::int AS n FROM pk_dares`;
  const bytes = Math.floor((max?.n ?? 0) / 8) + 1;
  for (const id of [...new Set(hostIds)].sort()) {
    await tx.$executeRaw`
      INSERT INTO pk_dare_seen (host_id, bits, seen, cycles, updated_at)
      VALUES (${id}::uuid, decode(repeat('00', ${bytes}::int), 'hex'), 0, 0, ${now.toISOString()}::timestamptz)
      ON CONFLICT (host_id) DO UPDATE
         SET bits = CASE WHEN octet_length(pk_dare_seen.bits) < ${bytes}::int
                         THEN pk_dare_seen.bits || decode(repeat('00', ${bytes}::int - octet_length(pk_dare_seen.bits)), 'hex')
                         ELSE pk_dare_seen.bits END`;
    await tx.$queryRaw`SELECT 1 FROM pk_dare_seen WHERE host_id = ${id}::uuid FOR UPDATE`;
  }
}

async function pickIn(
  tx: Tx,
  level: PkDareLevel,
  loser: string,
  winner: string,
  both: boolean,
  exclude: readonly number[],
): Promise<{ id: string; seq_no: number } | null> {
  const [row] = await tx.$queryRaw<{ id: string; seq_no: number }[]>`
    SELECT d.id::text AS id, d.seq_no
      FROM pk_dares d
      JOIN pk_dare_seen l ON l.host_id = ${loser}::uuid
      JOIN pk_dare_seen w ON w.host_id = ${winner}::uuid
     WHERE d.active AND d.level = ${level}::pk_dare_level
       AND get_bit(l.bits, d.seq_no) = 0
       AND (NOT ${both} OR get_bit(w.bits, d.seq_no) = 0)
       AND NOT (d.seq_no = ANY(${[...exclude, -1]}::int[]))
     ORDER BY random() LIMIT 1`;
  return row ?? null;
}

/**
 * The server's draw (owner D229): one active dare per level (EASY, MEDIUM, HARD), each one neither host has been
 * shown yet; when none is left for the loser at a level, one the winner saw is allowed; when the loser has seen every
 * active dare of a level, the loser's history starts again (a new cycle). Then one of the three is drawn (crypto
 * random, uniform) — the cards' animation only reveals it at `revealAt`. The three are marked seen for both hosts.
 * Returns null (no dare) when a level has no active dare at all. Audited `live.pk.dare.draw`.
 */
export async function drawPkDareIn(
  tx: Tx,
  input: {
    matchId: string;
    loserSide: 'A' | 'B';
    loserHostId: string;
    winnerHostId: string;
    now: Date;
    drawSeconds: number;
    decideSeconds: number;
    /** Tests: the drawn card (0–2); else crypto random. */
    pick?: () => number;
  },
): Promise<{ optionIds: string[]; drawn: number; revealAt: Date; decideBy: Date } | null> {
  const loser = input.loserHostId;
  const winner = input.winnerHostId;
  await seenRowsIn(tx, [loser, winner], input.now);
  const picks: { id: string; seq_no: number }[] = [];
  for (const level of PK_DARE_LEVELS) {
    const exclude = picks.map((p) => p.seq_no);
    let row =
      (await pickIn(tx, level, loser, winner, true, exclude)) ??
      (await pickIn(tx, level, loser, winner, false, exclude));
    if (!row) {
      // The loser has seen every active dare of this level: a new cycle for them.
      const [any] = await tx.$queryRaw<{ n: number }[]>`
        SELECT count(*)::int AS n FROM pk_dares WHERE active AND level = ${level}::pk_dare_level`;
      if (!any || any.n === 0) return null;
      await tx.$executeRaw`
        UPDATE pk_dare_seen SET bits = decode(repeat('00', octet_length(bits)), 'hex'), seen = 0, cycles = cycles + 1
         WHERE host_id = ${loser}::uuid`;
      for (const p of picks) {
        await tx.$executeRaw`UPDATE pk_dare_seen SET bits = set_bit(bits, ${p.seq_no}, 1) WHERE host_id = ${loser}::uuid`;
      }
      row = await pickIn(tx, level, loser, winner, false, exclude);
      if (!row) return null;
    }
    picks.push(row);
  }
  for (const host of [...new Set([loser, winner])]) {
    for (const p of picks) {
      await tx.$executeRaw`
        UPDATE pk_dare_seen SET bits = set_bit(bits, ${p.seq_no}, 1),
               seen = seen + (1 - get_bit(bits, ${p.seq_no})), updated_at = ${input.now.toISOString()}::timestamptz
         WHERE host_id = ${host}::uuid`;
    }
  }
  const drawn = input.pick ? input.pick() : randomInt(3);
  if (!Number.isInteger(drawn) || drawn < 0 || drawn > 2) throw new Error('drawn out of range');
  const optionIds = picks.map((p) => p.id);
  const revealAt = new Date(input.now.getTime() + input.drawSeconds * 1000);
  const decideBy = new Date(revealAt.getTime() + input.decideSeconds * 1000);
  await tx.$executeRaw`
    INSERT INTO pk_match_dares (match_id, loser_side, loser_host_id, winner_host_id, option_ids, drawn, dare_id,
                                status, reveal_at, decide_by, created_at)
    VALUES (${input.matchId}::uuid, ${input.loserSide}::pk_side, ${loser}::uuid, ${winner}::uuid,
            ${optionIds}::uuid[], ${drawn}, ${optionIds[drawn]!}::uuid, 'DECIDING', ${revealAt.toISOString()}::timestamptz,
            ${decideBy.toISOString()}::timestamptz, ${input.now.toISOString()}::timestamptz)
    ON CONFLICT (match_id) DO NOTHING`;
  await tx.auditLog.create({
    data: {
      action: AuditAction.LIVE_PK_DARE_DRAW,
      actorUserId: null,
      targetType: 'pk_match',
      targetId: input.matchId,
      metadata: {
        options: optionIds,
        drawn,
        dareId: optionIds[drawn]!,
        loser,
        winner,
        level: PK_DARE_LEVELS[drawn],
      },
    },
  });
  return { optionIds, drawn, revealAt, decideBy };
}
