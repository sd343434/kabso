import type { Prisma } from '../../generated/prisma/client.js';

/**
 * v1.90-live (D320, CONVENTIONS §10.124; owner: «الأغنى» — users ranked by the coins they SENT as gifts): the coin value
 * of a gift send (`total_coins`: unit price × quantity × recipients; a lucky, custom or bag send at its coin value —
 * the sum of the two medal metrics `GIFTS_SENT_COINS` + `LUCKY_GIFTS_SENT_COINS`, §10.104.7 / §10.104.9) added to the
 * sender's hourly (UTC hour) and monthly (local month in `timeZone`, LIVE_RANKINGS_TIME_ZONE) rows, in the send's own
 * transaction (once per send). No Nest dependencies.
 */

type Tx = Prisma.TransactionClient;

export async function addGiftCoinsSentIn(
  tx: Tx,
  userId: string,
  coins: bigint,
  at: Date,
  timeZone: string,
): Promise<void> {
  if (coins <= 0n) return;
  await tx.$executeRaw`
    INSERT INTO gift_coins_sent_hourly (user_id, hour_start, coins)
    VALUES (${userId}::uuid, date_trunc('hour', ${at}::timestamptz), ${coins})
    ON CONFLICT (user_id, hour_start) DO UPDATE SET coins = gift_coins_sent_hourly.coins + EXCLUDED.coins`;
  await tx.$executeRaw`
    INSERT INTO gift_coins_sent_monthly (user_id, month_start, coins)
    VALUES (${userId}::uuid,
            (date_trunc('month', ${at}::timestamptz AT TIME ZONE ${timeZone}::text) AT TIME ZONE ${timeZone}::text),
            ${coins})
    ON CONFLICT (user_id, month_start) DO UPDATE SET coins = gift_coins_sent_monthly.coins + EXCLUDED.coins`;
}

/**
 * A reversed send (`reverseGiftCherriesIn`) leaves the board: its coins come off the sender's hour and month of the
 * SEND (never below 0). The month row is the latest one starting at or before the send — the zone it was written in —
 * so no zone is needed here.
 */
export async function takeBackGiftCoinsSentIn(
  tx: Tx,
  userId: string,
  coins: bigint,
  sentAt: Date,
): Promise<void> {
  if (coins <= 0n) return;
  await tx.$executeRaw`
    UPDATE gift_coins_sent_hourly SET coins = GREATEST(coins - ${coins}, 0)
     WHERE user_id = ${userId}::uuid AND hour_start = date_trunc('hour', ${sentAt}::timestamptz)`;
  await tx.$executeRaw`
    UPDATE gift_coins_sent_monthly SET coins = GREATEST(coins - ${coins}, 0)
     WHERE user_id = ${userId}::uuid
       AND month_start = (SELECT max(month_start) FROM gift_coins_sent_monthly
                           WHERE user_id = ${userId}::uuid AND month_start <= ${sentAt}::timestamptz)`;
}
