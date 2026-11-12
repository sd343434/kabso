import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import {
  VIP_GOLDEN_ID_GRACE_DAYS,
  vipGoldenIdClassValue,
  vipPremiumClaimAllows,
  vipPremiumClassValue,
  type VipPremiumClass,
} from './vip-identity.js';
import { vipPerkHoldIn } from './vip-perks.js';

type Tx = Prisma.TransactionClient;
const DAY_MS = 86_400_000;

/**
 * v1.131-social (D378, §10.168.3): when a VIP-claimed premium username of medal [tier] ends for [userId] — the end of
 * the membership while it holds PREMIUM_USERNAME of a class that allows the medal; null when it no longer does (the
 * lease then expires now and D146's grace period follows).
 */
export async function vipPremiumLeaseEndIn(
  tx: Tx,
  userId: string,
  tier: VipPremiumClass,
  now: Date,
): Promise<Date | null> {
  const hold = await vipPerkHoldIn(tx, userId, 'PREMIUM_USERNAME', now);
  const perkClass = vipPremiumClassValue(hold?.value);
  if (hold === null || perkClass === null || !vipPremiumClaimAllows(perkClass, tier)) return null;
  return hold.expiresAt;
}

/**
 * v1.131-social (D378, §10.168.4): the golden ID class [userId]'s VIP lets them hold now, and the membership's end;
 * null without GOLDEN_ID (or with no class set on it).
 */
export async function vipGoldenIdHoldIn(
  tx: Tx,
  userId: string,
  now: Date,
): Promise<{ class: string; expiresAt: Date } | null> {
  const hold = await vipPerkHoldIn(tx, userId, 'GOLDEN_ID', now);
  const cls = vipGoldenIdClassValue(hold?.value);
  return hold === null || cls === null ? null : { class: cls, expiresAt: hold.expiresAt };
}

/** Serializes every golden ID write of one holder (claim, release, sync). */
export async function lockGoldenHolderIn(tx: Tx, userId: string): Promise<void> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:golden-id-holder'), hashtext(${userId}))`;
}

/**
 * v1.131-social (D378, §10.168.6): after a VIP purchase (new, renewal, upgrade) — the member's VIP premium username and
 * golden ID follow the membership's new end at once (a golden ID in its grace comes back when the class matches
 * again). What the new tier no longer allows is left to the sweepers (the lease expires, the number goes into its
 * grace). Never fails the purchase for these.
 */
export async function syncVipIdentityIn(tx: Tx, userId: string, now: Date): Promise<void> {
  const lease = await tx.premiumUsernameLease.findFirst({
    where: { userId, status: 'ACTIVE', source: 'VIP' },
    select: { id: true, tier: true, expiresAt: true },
  });
  if (lease) {
    const end = await vipPremiumLeaseEndIn(tx, userId, lease.tier, now);
    if (end !== null && end.getTime() !== lease.expiresAt?.getTime()) {
      await tx.premiumUsernameLease.update({
        where: { id: lease.id },
        data: { expiresAt: end, remindedDays: null, updatedAt: now },
      });
    }
  }
  await syncGoldenIdIn(tx, userId, now);
}

/**
 * D378: the golden ID of [userId] in step with their VIP — HELD: the end follows the membership while the class is
 * still held, else the number goes into its grace (from the earlier of the end and now); GRACE: back to HELD when the
 * class is held again, to the stock once the grace is over. Audited on every change of state.
 */
export async function syncGoldenIdIn(tx: Tx, userId: string, now: Date): Promise<void> {
  await lockGoldenHolderIn(tx, userId);
  const row = await tx.vipGoldenId.findUnique({ where: { holderId: userId } });
  if (!row) return;
  const hold = await vipGoldenIdHoldIn(tx, userId, now);
  const matches = hold !== null && hold.class === row.class;
  if (row.state === 'HELD') {
    if (matches) {
      if (row.heldUntil?.getTime() !== hold.expiresAt.getTime()) {
        await tx.vipGoldenId.update({ where: { number: row.number }, data: { heldUntil: hold.expiresAt } });
      }
      return;
    }
    const from = row.heldUntil && row.heldUntil < now ? row.heldUntil : now;
    const graceUntil = new Date(from.getTime() + VIP_GOLDEN_ID_GRACE_DAYS * DAY_MS);
    await tx.vipGoldenId.update({ where: { number: row.number }, data: { state: 'GRACE', graceUntil } });
    await goldenAuditIn(tx, AuditAction.VIP_GOLDEN_ID_GRACE, userId, {
      number: row.number,
      class: row.class,
      graceUntil: graceUntil.toISOString(),
    });
    return;
  }
  if (row.state === 'GRACE') {
    if (matches) {
      await tx.vipGoldenId.update({
        where: { number: row.number },
        data: { state: 'HELD', heldUntil: hold.expiresAt, graceUntil: null },
      });
      await goldenAuditIn(tx, AuditAction.VIP_GOLDEN_ID_CLAIM, userId, {
        number: row.number,
        class: row.class,
        heldUntil: hold.expiresAt.toISOString(),
        restored: true,
      });
    } else if (row.graceUntil !== null && row.graceUntil <= now) {
      await freeGoldenIdIn(tx, row.number, userId, 'grace_over');
    }
  }
}

/** Returns [number] to the stock (no holder), audited `vip.golden_id.free`. */
export async function freeGoldenIdIn(tx: Tx, number: string, holderId: string | null, why: string): Promise<void> {
  await tx.vipGoldenId.update({
    where: { number },
    data: { state: 'FREE', holderId: null, heldUntil: null, graceUntil: null, claimedAt: null },
  });
  await tx.auditLog.create({
    data: {
      action: AuditAction.VIP_GOLDEN_ID_FREE,
      targetType: 'vip_golden_id',
      targetId: number,
      metadata: { number, holderId, why },
    },
  });
}

export async function goldenAuditIn(
  tx: Tx,
  action: AuditAction,
  userId: string,
  metadata: Record<string, string | boolean | null>,
): Promise<void> {
  await tx.auditLog.create({
    data: { action, actorUserId: userId, targetType: 'user', targetId: userId, metadata },
  });
}
