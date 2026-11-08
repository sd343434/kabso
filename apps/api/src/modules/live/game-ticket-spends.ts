import type { Prisma } from '../../generated/prisma/client.js';

/**
 * v1.88-live (D315, CONVENTIONS §10.120; owner: «مجنون اللعب» — players ranked by the game tickets «التذاكر» they SPEND in
 * games). No game exists yet (D173 «الألعاب قريباً», D305's game hook): this is the documented hook the first game calls.
 * No Nest dependencies (a game module, a CLI or a test can call it).
 */

type Tx = Prisma.TransactionClient;

/** `game_ticket_spends_shape`: a game's code, like a gift's. */
export const GAME_CODE_PATTERN = /^[a-z0-9][a-z0-9_]{0,39}$/;
/** Rollup rows older than these are removed by the live sweeper (as the popularity points). */
export const GAME_SPEND_HOURLY_RETENTION_MS = 15 * 24 * 3600_000;
export const MONTHLY_RETENTION_MS = 400 * 24 * 3600_000;

export interface GameTicketSpend {
  /** The player who spent the tickets. */
  readonly userId: string;
  /** The game's code (`^[a-z0-9][a-z0-9_]{0,39}$`). */
  readonly gameCode: string;
  /** Tickets spent (> 0, whole). */
  readonly tickets: bigint;
  /** The game's own id of this spend (a round, a bet): 1–64 characters, once per game. */
  readonly reference: string;
  /** When it was spent (the boards' hour and month). */
  readonly at: Date;
}

/**
 * Records one ticket spend **inside the game's own transaction that debits the tickets** (so a rolled-back round counts
 * nothing): the ledger row (`game_ticket_spends`, once per `(gameCode, reference)` — a replay returns false and adds
 * nothing), then the player's hourly (UTC hour) and monthly (local month in `timeZone`, LIVE_RANKINGS_TIME_ZONE) rows
 * the «مجنون اللعب» board reads. Returns true when recorded.
 */
export async function recordGameTicketSpendIn(
  tx: Tx,
  spend: GameTicketSpend,
  timeZone: string,
): Promise<boolean> {
  if (spend.tickets <= 0n) throw new RangeError('A ticket spend is positive');
  if (!GAME_CODE_PATTERN.test(spend.gameCode)) throw new RangeError('A game code is a-z, 0-9 and _');
  if (spend.reference.length < 1 || spend.reference.length > 64)
    throw new RangeError('A reference is 1–64 characters');
  const inserted = await tx.$queryRaw<{ id: string }[]>`
    INSERT INTO game_ticket_spends (id, user_id, game_code, tickets, reference, created_at)
    VALUES (gen_random_uuid(), ${spend.userId}::uuid, ${spend.gameCode}, ${spend.tickets}, ${spend.reference},
            ${spend.at}::timestamptz)
    ON CONFLICT (game_code, reference) DO NOTHING
    RETURNING id::text AS id`;
  if (inserted.length === 0) return false;
  await tx.$executeRaw`
    INSERT INTO game_ticket_spends_hourly (user_id, hour_start, tickets)
    VALUES (${spend.userId}::uuid, date_trunc('hour', ${spend.at}::timestamptz), ${spend.tickets})
    ON CONFLICT (user_id, hour_start) DO UPDATE
       SET tickets = game_ticket_spends_hourly.tickets + EXCLUDED.tickets`;
  await tx.$executeRaw`
    INSERT INTO game_ticket_spends_monthly (user_id, month_start, tickets)
    VALUES (${spend.userId}::uuid,
            (date_trunc('month', ${spend.at}::timestamptz AT TIME ZONE ${timeZone}::text) AT TIME ZONE ${timeZone}::text),
            ${spend.tickets})
    ON CONFLICT (user_id, month_start) DO UPDATE
       SET tickets = game_ticket_spends_monthly.tickets + EXCLUDED.tickets`;
  return true;
}
