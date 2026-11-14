import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { addBoostCardsIn } from '../live/live-boosts.js';
import { dateValue, programWindowsIn } from '../programs/programs-time.js';
import { VIP_ROCKET_STAGES } from './vip-catalogue.js';
import { vipPerkHeldIn } from './vip-gift-perks.js';

/** `VipMonthlyRockets` (v1.134-social, D381, §10.171.4): this month's MONTHLY_ROCKETS grant. */
export interface VipMonthlyRocketsDto {
  /** The month, `YYYY-MM-01` (`LIVE_RANKINGS_TIME_ZONE`). */
  month: string;
  /** The rocket stage 1–4 (D233) and its length in minutes. */
  stage: number;
  minutes: number;
  count: number;
  grantedAt: string;
  /** The next month's start (the next grant), ISO. */
  nextAt: string;
}

/** The stage number of a MONTHLY_ROCKETS value's `stage` (STAGE_1 … STAGE_4), or null. */
export function rocketStageNumber(stage: unknown): number | null {
  const i = VIP_ROCKET_STAGES.indexOf(stage as (typeof VIP_ROCKET_STAGES)[number]);
  return i < 0 ? null : i + 1;
}

/**
 * v1.134-social (D381, §10.171.4) MONTHLY_ROCKETS «صاروخ شهري»: on the member's first read of a calendar month
 * (`GET /me/vip`, `GET /live/boosts/offers`; the programs' clock `LIVE_RANKINGS_TIME_ZONE`, D99) while the perk is held
 * with a value, adds `count` traffic cards of the stage's length (`LIVE_BOOST_PRICES`' Nth length, D233) to
 * `live_boost_cards` — once per member and month (`vip_rocket_grants`' key; a concurrent read inserts nothing) — and
 * audits it (`vip.monthly_rockets.grant`). A month in which the perk was not held is not granted later. Returns this
 * month's grant (made now or earlier), or null when there is none.
 */
export async function grantVipMonthlyRocketsIn(
  tx: Prisma.TransactionClient,
  userId: string,
  now: Date,
  opts: { readonly timeZone: string; readonly stageMinutes: readonly number[] },
): Promise<VipMonthlyRocketsDto | null> {
  const { month } = await programWindowsIn(tx, now, opts.timeZone);
  const day = dateValue(month.date);
  const dto = (r: {
    stage: number;
    minutes: number;
    count: number;
    grantedAt: Date;
  }): VipMonthlyRocketsDto => ({
    month: month.date,
    stage: r.stage,
    minutes: r.minutes,
    count: r.count,
    grantedAt: r.grantedAt.toISOString(),
    nextAt: month.end.toISOString(),
  });
  const before = await tx.vipRocketGrant.findUnique({ where: { userId_month: { userId, month: day } } });
  if (before) return dto(before);
  const held = await vipPerkHeldIn(tx, userId, 'MONTHLY_ROCKETS', now);
  const value = held?.value as { count?: unknown; stage?: unknown } | null | undefined;
  if (!value || typeof value !== 'object') return null;
  const count = value.count;
  const stage = rocketStageNumber(value.stage);
  const minutes = stage === null ? undefined : opts.stageMinutes[stage - 1];
  if (
    typeof count !== 'number' ||
    !Number.isInteger(count) ||
    count < 1 ||
    stage === null ||
    minutes === undefined
  )
    return null;
  const membership = await tx.vipMembership.findUnique({ where: { userId }, select: { tierId: true } });
  const inserted = await tx.$queryRaw<{ granted_at: Date }[]>`
    INSERT INTO vip_rocket_grants (user_id, month, tier_id, stage, minutes, count, granted_at)
    VALUES (${userId}::uuid, ${month.date}::date, ${membership?.tierId ?? null}::uuid, ${stage}, ${minutes}, ${count},
            ${now.toISOString()}::timestamptz)
    ON CONFLICT (user_id, month) DO NOTHING
    RETURNING granted_at`;
  if (inserted.length === 0) {
    const raced = await tx.vipRocketGrant.findUnique({ where: { userId_month: { userId, month: day } } });
    return raced ? dto(raced) : null;
  }
  const held2 = await addBoostCardsIn(tx, userId, minutes, count);
  await tx.auditLog.create({
    data: {
      actorUserId: null,
      action: AuditAction.VIP_MONTHLY_ROCKETS_GRANT,
      targetType: 'user',
      targetId: userId,
      metadata: {
        month: month.date,
        tierId: membership?.tierId ?? null,
        stage,
        minutes,
        count,
        // null: the holder already had the most cards of that length (BOOST_CARDS_MAX); the month is still used.
        cardsAfter: held2,
      },
    },
  });
  return dto({ stage, minutes, count, grantedAt: inserted[0]!.granted_at });
}
