import { auditBy, SYSTEM_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type {
  Ambassador,
  AmbassadorCommission,
  Prisma,
  PrismaClient,
} from '../../generated/prisma/client.js';
import { grantBagItemByAdminIn } from '../bag/bag-admin-rules.js';
import { creditAmbassadorCommissionIn, reverseAmbassadorCommissionIn } from '../economy/cherry-ledger.js';
import { uuidv7 } from '../levels/uuidv7.js';
// D387: the shared «any panel role» check (the OWNER included), §10.179.2.
import { isPanelStaff } from '../live/live-staff.js';
import { Notifier } from '../notifications/notifier.js';
import { grantVipIn } from '../programs/gift-events.js';
import { creditIn } from '../wallet/wallet-ledger.js';
import {
  ambassadorMonth,
  capCommission,
  commissionCherries,
  levelAfterMonth,
  levelIndex,
  metLevelIndex,
  parseLevels,
  previousMonth,
  rewardReference,
  type AmbassadorLevel,
  type AmbassadorReward,
} from './ambassador-rules.js';

/**
 * «برنامج سفراء Kabso» (v1.141-social, D390, CONVENTIONS §10.179): the database rules, shared by the API (the
 * referral hooks, the recharge hooks, the sweeper, the panel). No Nest dependency.
 *
 * Built on D217 (the invite code, the referral row and its fraud rules) and the recharge hooks every top-up path
 * already calls (`referralRechargeIn`): a referral whose inviter is an ambassador takes the ambassador track
 * (`ambassador_referrals`) and earns no D217 inviter reward; each qualifying top-up of the referred person makes one
 * held commission; the sweeper activates referrals, credits or voids due commissions and evaluates the months.
 */

type Tx = Prisma.TransactionClient;
type Db = Tx | PrismaClient;
const DAY_MS = 86_400_000;

/**
 * The programme's month clock (LIVE_RANKINGS_TIME_ZONE, the boards' and D285's): set once by the module from the
 * config, so the recharge hooks — called with no config by four recharge paths — file each commission in the right
 * month. UTC until set (the CLIs).
 */
let monthZone = 'UTC';
export function setAmbassadorTimeZone(zone: string): void {
  monthZone = zone;
}
export function ambassadorTimeZone(): string {
  return monthZone;
}

/** A refusal by a team rule (the panel answers 409 ADMIN_ACTION_REFUSED with `issue`). */
export class AmbassadorAdminError extends Error {
  constructor(
    message: string,
    readonly issue: string,
  ) {
    super(message);
  }
}

export interface AmbassadorSettingsValue {
  readonly enabled: boolean;
  readonly attributionWindowDays: number;
  readonly holdDays: number;
  readonly minActiveDays: number;
  readonly minActiveTopupCoins: bigint;
  readonly monthlyCapCherries: bigint;
  readonly velocityMaxPerDay: number;
  readonly ipClusterMax: number;
  readonly ipClusterWindowDays: number;
  readonly levels: readonly AmbassadorLevel[];
  readonly updatedAt: Date;
  readonly updatedById: string | null;
}

export type AmbassadorSettingsPatch = Partial<
  Omit<AmbassadorSettingsValue, 'updatedAt' | 'updatedById' | 'levels'> & { levels: AmbassadorLevel[] }
>;

/** The settings row (id 1, inserted by the migration); a missing row reads as switched off. */
export async function ambassadorSettingsIn(db: Db): Promise<AmbassadorSettingsValue> {
  const row = await db.ambassadorSettings.findUnique({ where: { id: 1 } });
  if (!row) {
    return {
      enabled: false,
      attributionWindowDays: 60,
      holdDays: 14,
      minActiveDays: 3,
      minActiveTopupCoins: 100_000n,
      monthlyCapCherries: 50_000_000n,
      velocityMaxPerDay: 30,
      ipClusterMax: 3,
      ipClusterWindowDays: 30,
      levels: [],
      updatedAt: new Date(0),
      updatedById: null,
    };
  }
  return { ...row, levels: parseLevels(row.levels) };
}

/** The settings as JSON for the audit rows. */
export function ambassadorSettingsJson(s: AmbassadorSettingsValue): Prisma.InputJsonObject {
  return {
    enabled: s.enabled,
    attributionWindowDays: s.attributionWindowDays,
    holdDays: s.holdDays,
    minActiveDays: s.minActiveDays,
    minActiveTopupCoins: Number(s.minActiveTopupCoins),
    monthlyCapCherries: Number(s.monthlyCapCherries),
    velocityMaxPerDay: s.velocityMaxPerDay,
    ipClusterMax: s.ipClusterMax,
    ipClusterWindowDays: s.ipClusterWindowDays,
    levels: s.levels,
  };
}

/** Changes the settings (panel: OWNER with the code again), audited with before and after. */
export async function updateAmbassadorSettingsIn(
  tx: Tx,
  patch: AmbassadorSettingsPatch,
  reason: string,
  now: Date,
  by: AdminVia,
): Promise<AmbassadorSettingsValue> {
  await tx.$executeRaw`SELECT 1 FROM ambassador_settings WHERE id = 1 FOR UPDATE`;
  const before = await ambassadorSettingsIn(tx);
  const { levels, ...rest } = patch;
  const data: Prisma.AmbassadorSettingsUncheckedUpdateInput = {
    ...rest,
    ...(levels !== undefined ? { levels: levels } : {}),
    updatedAt: now,
    updatedById: by.actorUserId,
  };
  await tx.ambassadorSettings.upsert({
    where: { id: 1 },
    create: { id: 1, ...(data as Prisma.AmbassadorSettingsUncheckedCreateInput) },
    update: data,
  });
  const after = await ambassadorSettingsIn(tx);
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.AMBASSADOR_SETTINGS_UPDATE,
      targetType: 'ambassador_settings',
      targetId: '1',
      metadata: {
        via: by.via,
        reason,
        before: ambassadorSettingsJson(before),
        after: ambassadorSettingsJson(after),
      },
    },
  });
  return after;
}

/** Banned, deleted (or being deleted) or locked by the team (D208 LOCK) — as D217's `accountHealthIn`. */
export async function healthIn(
  db: Db,
  userId: string,
  now: Date,
): Promise<'OK' | 'BANNED' | 'DELETED' | 'FLAGGED'> {
  const user = await db.user.findUnique({ where: { id: userId }, select: { status: true } });
  if (!user || user.status === 'DELETED' || user.status === 'PENDING_DELETION') return 'DELETED';
  if (user.status !== 'ACTIVE') return 'BANNED';
  const lock = await db.accountRestriction.count({
    where: { userId, kind: 'LOCK', liftedAt: null, startsAt: { lte: now }, endsAt: { gt: now } },
  });
  return lock > 0 ? 'FLAGGED' : 'OK';
}

/** Why `userId` cannot become an ambassador now (null: they can). */
export type AmbassadorRefusal = 'ACCOUNT_NOT_ACTIVE' | 'STAFF' | 'AMBASSADOR' | 'ENDED' | 'PENDING';

export async function eligibilityIn(db: Db, userId: string, now: Date): Promise<AmbassadorRefusal | null> {
  if ((await healthIn(db, userId, now)) !== 'OK') return 'ACCOUNT_NOT_ACTIVE';
  if (await isPanelStaff(db, userId)) return 'STAFF';
  const amb = await db.ambassador.findUnique({ where: { userId }, select: { status: true } });
  // D390 follow-up (§10.179.11): an ENDED member may not apply again — only the OWNER re-appoints.
  if (amb) return amb.status === 'ENDED' ? 'ENDED' : 'AMBASSADOR';
  if ((await db.ambassadorApplication.count({ where: { userId, status: 'PENDING' } })) > 0) return 'PENDING';
  return null;
}

async function flagIn(
  tx: Tx,
  ambassadorId: string,
  kind: 'VELOCITY' | 'IP_CLUSTER' | 'SELF_PAYMENT',
  detail: Prisma.InputJsonObject,
  now: Date,
): Promise<void> {
  await tx.ambassadorFlag.create({
    data: { id: uuidv7(now.getTime()), ambassadorUserId: ambassadorId, kind, detail, createdAt: now },
  });
  const changed = await tx.ambassador.updateMany({
    where: { userId: ambassadorId, underReview: false },
    data: { underReview: true, reviewReason: kind, reviewAt: now },
  });
  await tx.auditLog.create({
    data: {
      action: AuditAction.AMBASSADOR_REVIEW_FLAG,
      targetType: 'ambassador',
      targetId: ambassadorId,
      metadata: { via: 'system', kind, ...detail, underReviewNow: changed.count > 0 },
    },
  });
}

/**
 * The precedence hook (§10.179.3), inside D217's `attachReferralIn` for a referral that passed D217's fraud rules:
 * when the programme is on and the inviter is an ambassador (ACTIVE or FROZEN) who is not Kabso Team, the referral
 * takes the ambassador track — an `ambassador_referrals` row — and the caller makes NO D217 inviter reward. The
 * ambassador's own fraud limits run here: more than `ipClusterMax` referrals from one IP within `ipClusterWindowDays`
 * make this one VOID `IP_CLUSTER` and flag the ambassador; more than `velocityMaxPerDay` in 24 hours flag the
 * ambassador (the referral still counts, the payouts wait for the review). Returns whether the track was taken.
 */
export async function ambassadorTrackIn(
  tx: Tx,
  input: { referralId: string; inviterId: string; inviteeId: string; ip: string | null; now: Date },
): Promise<boolean> {
  const settings = await ambassadorSettingsIn(tx);
  if (!settings.enabled) return false;
  const [amb] = await tx.$queryRaw<{ user_id: string }[]>`
    SELECT user_id::text AS user_id FROM ambassadors
     WHERE user_id = ${input.inviterId}::uuid AND status <> 'ENDED' FOR UPDATE`;
  if (!amb) return false;
  if (await isPanelStaff(tx, input.inviterId)) return false;
  const now = input.now;
  const invitee = await tx.user.findUniqueOrThrow({
    where: { id: input.inviteeId },
    select: { createdAt: true },
  });
  const windowUntil = new Date(invitee.createdAt.getTime() + settings.attributionWindowDays * DAY_MS);
  let voidReason: string | null = null;
  if (input.ip !== null && settings.ipClusterMax > 0) {
    const same = await tx.ambassadorReferral.count({
      where: {
        ambassadorUserId: input.inviterId,
        inviteeIp: input.ip,
        createdAt: { gt: new Date(now.getTime() - settings.ipClusterWindowDays * DAY_MS) },
      },
    });
    if (same >= settings.ipClusterMax) voidReason = 'IP_CLUSTER';
  }
  await tx.ambassadorReferral.create({
    data: {
      referralId: input.referralId,
      ambassadorUserId: input.inviterId,
      inviteeUserId: input.inviteeId,
      windowUntil,
      inviteeIp: input.ip,
      createdAt: now,
      ...(voidReason ? { status: 'VOID', voidedAt: now, voidReason } : {}),
    },
  });
  await tx.auditLog.create({
    data: {
      action: AuditAction.AMBASSADOR_REFERRAL_ATTACH,
      targetType: 'referral',
      targetId: input.referralId,
      metadata: {
        via: 'system',
        ambassador: input.inviterId,
        invitee: input.inviteeId,
        windowUntil: windowUntil.toISOString(),
        ...(voidReason ? { status: 'VOID', reason: voidReason } : { status: 'PENDING' }),
      },
    },
  });
  if (voidReason) {
    await flagIn(
      tx,
      input.inviterId,
      'IP_CLUSTER',
      { referral: input.referralId, max: settings.ipClusterMax },
      now,
    );
  }
  if (settings.velocityMaxPerDay > 0) {
    const day = await tx.ambassadorReferral.count({
      where: { ambassadorUserId: input.inviterId, createdAt: { gt: new Date(now.getTime() - DAY_MS) } },
    });
    if (day > settings.velocityMaxPerDay) {
      await flagIn(tx, input.inviterId, 'VELOCITY', { last24h: day, max: settings.velocityMaxPerDay }, now);
    }
  }
  return true;
}

/**
 * D390 follow-up (§10.179.9): the public badge — the person's level while the programme is on and the membership is
 * ACTIVE (never FROZEN or ENDED, which stay private), else null. Read by the public profile and the person card.
 */
export async function ambassadorBadgeIn(db: Db, userId: string): Promise<string | null> {
  const amb = await db.ambassador.findUnique({ where: { userId }, select: { status: true, level: true } });
  if (amb?.status !== 'ACTIVE') return null;
  const settings = await ambassadorSettingsIn(db);
  if (!settings.enabled) return null;
  return settings.levels[levelIndex(settings.levels, amb.level)]?.code ?? null;
}

/** Whether `inviterId`'s referral `referralId` is on the ambassador track (D217 skips its own rewards). */
export async function isAmbassadorReferralIn(db: Db, referralId: string): Promise<boolean> {
  return (await db.ambassadorReferral.count({ where: { referralId } })) > 0;
}

/**
 * The same payment identity as the ambassador (§10.179.7): the ambassador (or their employee) sold the coins (an
 * agent's sale or a recharge order of the ambassador's own agency), or a store purchase came from one of the
 * ambassador's phones (D223's device hash). A website card top-up carries no card identity yet (open decision).
 */
async function selfPaymentIn(
  tx: Tx,
  ambassadorId: string,
  reason: RechargeReason,
  reference: string,
): Promise<boolean> {
  if (reason === 'RECHARGE_PURCHASE') {
    const sale = await tx.rechargeSale.findUnique({
      where: { id: reference },
      select: { agentUserId: true, sellerUserId: true },
    });
    return sale !== null && (sale.agentUserId === ambassadorId || sale.sellerUserId === ambassadorId);
  }
  if (reason === 'RECHARGE_ORDER') {
    const order = await tx.rechargeOrder.findUnique({
      where: { id: reference },
      select: { agentUserId: true },
    });
    return order !== null && order.agentUserId === ambassadorId;
  }
  if (reason === 'STORE_IAP') {
    const purchase = await tx.iapPurchase.findUnique({
      where: { id: reference },
      select: { deviceHash: true },
    });
    if (!purchase?.deviceHash) return false;
    return (await tx.session.count({ where: { userId: ambassadorId, deviceHash: purchase.deviceHash } })) > 0;
  }
  return false;
}

export type RechargeReason = 'CARD_TOPUP' | 'RECHARGE_PURCHASE' | 'RECHARGE_ORDER' | 'STORE_IAP';

/**
 * The commission hook (§10.179.5), in every recharge's transaction (through D217's `referralRechargeIn`): when the
 * buyer is an ambassador-track referral inside its attribution window and the programme is on, one commission row of
 * floor(coins × CHERRIES_PER_COIN × the level's bps / 10 000) cherries, trimmed to the month's cap, held `holdDays`.
 * Once per recharge (unique). The same payment identity as the ambassador: VOID `SELF_PAYMENT` and a flag.
 */
export async function ambassadorTopupIn(
  tx: Tx,
  input: { userId: string; coins: bigint; reason: RechargeReason; reference: string; now: Date },
  cherriesPerCoin: number,
  timeZone: string,
): Promise<string | null> {
  const ref = await tx.ambassadorReferral.findUnique({ where: { inviteeUserId: input.userId } });
  if (!ref || ref.status === 'VOID' || input.now > ref.windowUntil) return null;
  const settings = await ambassadorSettingsIn(tx);
  if (!settings.enabled || settings.levels.length === 0) return null;
  const amb = await tx.ambassador.findUnique({ where: { userId: ref.ambassadorUserId } });
  // D390 follow-up (§10.179.11): an ended membership earns nothing more (the referral keeps its track).
  if (!amb || amb.status === 'ENDED') return null;
  const now = input.now;
  const level = settings.levels[levelIndex(settings.levels, amb.level)]!;
  const month = ambassadorMonth(now, timeZone);
  const gross = commissionCherries(input.coins, cherriesPerCoin, level.commissionBps);
  let voidReason: string | null = null;
  let cherries = gross;
  let capped = 0n;
  if (await isPanelStaff(tx, amb.userId)) voidReason = 'STAFF';
  else if (await selfPaymentIn(tx, amb.userId, input.reason, input.reference)) voidReason = 'SELF_PAYMENT';
  else {
    // The month's cap, serialized per ambassador by the row lock.
    await tx.$executeRaw`SELECT 1 FROM ambassadors WHERE user_id = ${amb.userId}::uuid FOR UPDATE`;
    const [used] = await tx.$queryRaw<{ c: bigint }[]>`
      SELECT COALESCE(sum(cherries), 0)::bigint AS c FROM ambassador_commissions
       WHERE ambassador_user_id = ${amb.userId}::uuid AND month = ${month} AND status IN ('PENDING', 'CREDITED')`;
    const cap = capCommission(gross, used?.c ?? 0n, settings.monthlyCapCherries);
    cherries = cap.cherries;
    capped = cap.capped;
    if (cherries === 0n) voidReason = gross === 0n ? 'ZERO' : 'MONTHLY_CAP';
  }
  const id = uuidv7(now.getTime());
  const rows = await tx.$executeRaw`
    INSERT INTO ambassador_commissions (id, ambassador_user_id, invitee_user_id, referral_id, recharge_reason,
                                        recharge_reference, coins, level, rate_bps, cherries, capped_cherries, month,
                                        status, hold_until, created_at, voided_at, void_reason)
    VALUES (${id}::uuid, ${amb.userId}::uuid, ${input.userId}::uuid, ${ref.referralId}::uuid, ${input.reason},
            ${input.reference}, ${input.coins}, ${level.code}, ${level.commissionBps}, ${cherries}, ${capped}, ${month},
            ${voidReason ? 'VOID' : 'PENDING'}::ambassador_commission_status,
            ${new Date(now.getTime() + settings.holdDays * DAY_MS)}, ${now},
            ${voidReason ? now : null}, ${voidReason})
    ON CONFLICT (recharge_reason, recharge_reference) DO NOTHING`;
  if (rows === 0) return null;
  await tx.auditLog.create({
    data: {
      action: voidReason ? AuditAction.AMBASSADOR_COMMISSION_VOID : AuditAction.AMBASSADOR_COMMISSION_CREATE,
      targetType: 'ambassador_commission',
      targetId: id,
      metadata: {
        via: 'system',
        ambassador: amb.userId,
        invitee: input.userId,
        coins: Number(input.coins),
        level: level.code,
        rateBps: level.commissionBps,
        cherries: Number(cherries),
        capped: Number(capped),
        recharge: input.reason,
        reference: input.reference,
        ...(voidReason ? { reason: voidReason } : {}),
      },
    },
  });
  if (voidReason === 'SELF_PAYMENT') {
    await flagIn(tx, amb.userId, 'SELF_PAYMENT', { commission: id, recharge: input.reason }, now);
  }
  return id;
}

/**
 * The refund / chargeback hook (§10.179.5), in the reversal's transaction (a website top-up taken back, a store
 * refund): the top-up's commission — PENDING → VOID `RECHARGE_REVERSED`; CREDITED → REVERSED with one
 * `AMBASSADOR_COMMISSION_REVERSAL` row (the balance may go below 0). Nothing else changes; idempotent.
 */
export async function ambassadorTopupReversedIn(
  tx: Tx,
  reason: RechargeReason,
  reference: string,
  now: Date,
): Promise<'VOID' | 'REVERSED' | null> {
  const [locked] = await tx.$queryRaw<{ id: string }[]>`
    SELECT id::text AS id FROM ambassador_commissions
     WHERE recharge_reason = ${reason} AND recharge_reference = ${reference}
       AND status IN ('PENDING', 'CREDITED') FOR UPDATE`;
  if (!locked) return null;
  const c = await tx.ambassadorCommission.findUniqueOrThrow({ where: { id: locked.id } });
  if (c.status === 'PENDING') {
    await voidCommissionIn(tx, c, 'RECHARGE_REVERSED', now);
    return 'VOID';
  }
  await reverseCommissionIn(tx, c, now);
  return 'REVERSED';
}

async function voidCommissionIn(tx: Tx, c: AmbassadorCommission, reason: string, now: Date): Promise<void> {
  await tx.ambassadorCommission.update({
    where: { id: c.id },
    data: { status: 'VOID', voidedAt: now, voidReason: reason },
  });
  await tx.auditLog.create({
    data: {
      action: AuditAction.AMBASSADOR_COMMISSION_VOID,
      targetType: 'ambassador_commission',
      targetId: c.id,
      metadata: { via: 'system', ambassador: c.ambassadorUserId, cherries: Number(c.cherries), reason },
    },
  });
}

async function reverseCommissionIn(tx: Tx, c: AmbassadorCommission, now: Date): Promise<void> {
  const back = await reverseAmbassadorCommissionIn(tx, c.ambassadorUserId, c.cherries, c.id, now);
  await tx.ambassadorCommission.update({
    where: { id: c.id },
    data: { status: 'REVERSED', reversedAt: now, reversalShortfall: back.shortfall },
  });
  await tx.auditLog.create({
    data: {
      action: AuditAction.AMBASSADOR_COMMISSION_REVERSE,
      targetType: 'ambassador_commission',
      targetId: c.id,
      metadata: {
        via: 'system',
        ambassador: c.ambassadorUserId,
        cherries: Number(c.cherries),
        shortfall: Number(back.shortfall),
        balanceAfter: Number(back.balanceAfter),
      },
    },
  });
}

/** Whether the top-up behind `c` was taken back (a refund, a fraud warning, a dispute, a store refund). */
async function topupReversedIn(tx: Tx, c: AmbassadorCommission): Promise<boolean> {
  if (c.rechargeReason === 'CARD_TOPUP') {
    const order = await tx.topupOrder.findUnique({
      where: { id: c.rechargeReference },
      select: { coinsReversed: true },
    });
    return !order || order.coinsReversed > 0n;
  }
  if (c.rechargeReason === 'STORE_IAP') {
    const p = await tx.iapPurchase.findUnique({
      where: { id: c.rechargeReference },
      select: { status: true },
    });
    return !p || p.status === 'REFUNDED';
  }
  return false;
}

/** The coins that make a referral active: its top-ups that were not refunded and not the ambassador's own money. */
async function qualifyingCoinsIn(tx: Tx, referralId: string): Promise<bigint> {
  const [row] = await tx.$queryRaw<{ c: bigint }[]>`
    SELECT COALESCE(sum(coins), 0)::bigint AS c FROM ambassador_commissions
     WHERE referral_id = ${referralId}::uuid
       AND (status IN ('PENDING', 'CREDITED') OR void_reason IN ('MONTHLY_CAP', 'ZERO'))`;
  return row?.c ?? 0n;
}

/** One PENDING referral: ACTIVE (§10.179.4), VOID, or left for later. */
async function settleReferralIn(
  tx: Tx,
  referralId: string,
  settings: AmbassadorSettingsValue,
  now: Date,
  timeZone: string,
): Promise<'ACTIVE' | 'VOID' | null> {
  const [locked] = await tx.$queryRaw<{ id: string }[]>`
    SELECT referral_id::text AS id FROM ambassador_referrals
     WHERE referral_id = ${referralId}::uuid AND status = 'PENDING' FOR UPDATE SKIP LOCKED`;
  if (!locked) return null;
  const ref = await tx.ambassadorReferral.findUniqueOrThrow({ where: { referralId } });
  const health = await healthIn(tx, ref.inviteeUserId, now);
  let voidReason: string | null = health !== 'OK' ? `INVITEE_${health}` : null;
  if (voidReason === null) {
    const invitee = await tx.user.findUniqueOrThrow({
      where: { id: ref.inviteeUserId },
      select: { createdAt: true },
    });
    const oldEnough = now.getTime() - invitee.createdAt.getTime() >= settings.minActiveDays * DAY_MS;
    const coins = await qualifyingCoinsIn(tx, referralId);
    if (oldEnough && coins >= settings.minActiveTopupCoins && coins > 0n) {
      const month = ambassadorMonth(now, timeZone);
      await tx.ambassadorReferral.update({
        where: { referralId },
        data: { status: 'ACTIVE', activeAt: now, activeMonth: month },
      });
      await tx.auditLog.create({
        data: {
          action: AuditAction.AMBASSADOR_REFERRAL_ACTIVE,
          targetType: 'referral',
          targetId: referralId,
          metadata: { via: 'system', ambassador: ref.ambassadorUserId, coins: Number(coins), month },
        },
      });
      return 'ACTIVE';
    }
    if (now > ref.windowUntil) voidReason = 'NOT_ACTIVE';
  }
  if (voidReason === null) return null;
  await tx.ambassadorReferral.update({
    where: { referralId },
    data: { status: 'VOID', voidedAt: now, voidReason },
  });
  for (const c of await tx.ambassadorCommission.findMany({ where: { referralId, status: 'PENDING' } })) {
    await voidCommissionIn(tx, c, 'REFERRAL_VOID', now);
  }
  await tx.auditLog.create({
    data: {
      action: AuditAction.AMBASSADOR_REFERRAL_VOID,
      targetType: 'referral',
      targetId: referralId,
      metadata: { via: 'system', ambassador: ref.ambassadorUserId, reason: voidReason },
    },
  });
  return 'VOID';
}

/** Whether payouts to this ambassador are held now (frozen by the OWNER or under review). */
function held(amb: Ambassador): boolean {
  return amb.status === 'FROZEN' || amb.underReview;
}

/** One due commission: CREDITED, VOID, or left PENDING (held, or its referral not active yet). */
async function settleCommissionIn(tx: Tx, id: string, now: Date): Promise<'CREDITED' | 'VOID' | null> {
  const [locked] = await tx.$queryRaw<{ id: string }[]>`
    SELECT id::text AS id FROM ambassador_commissions
     WHERE id = ${id}::uuid AND status = 'PENDING' AND hold_until <= ${now} FOR UPDATE SKIP LOCKED`;
  if (!locked) return null;
  const c = await tx.ambassadorCommission.findUniqueOrThrow({ where: { id } });
  const amb = await tx.ambassador.findUnique({ where: { userId: c.ambassadorUserId } });
  const voidWith = async (reason: string) => {
    await voidCommissionIn(tx, c, reason, now);
    return 'VOID' as const;
  };
  if (!amb) return voidWith('NOT_AMBASSADOR');
  if (amb.status === 'ENDED') return voidWith('MEMBERSHIP_ENDED');
  if (await topupReversedIn(tx, c)) return voidWith('RECHARGE_REVERSED');
  const ref = await tx.ambassadorReferral.findUnique({ where: { referralId: c.referralId } });
  if (!ref || ref.status === 'VOID') return voidWith('REFERRAL_VOID');
  if (await isPanelStaff(tx, amb.userId)) return voidWith('STAFF');
  const health = await healthIn(tx, amb.userId, now);
  if (health === 'BANNED' || health === 'DELETED') return voidWith(`AMBASSADOR_${health}`);
  // Held: frozen, under review, locked by the team, or the friend is not active yet.
  if (held(amb) || health !== 'OK' || ref.status !== 'ACTIVE') return null;
  await creditAmbassadorCommissionIn(tx, amb.userId, c.cherries, c.id, now);
  await tx.ambassadorCommission.update({ where: { id }, data: { status: 'CREDITED', creditedAt: now } });
  await tx.auditLog.create({
    data: {
      action: AuditAction.AMBASSADOR_COMMISSION_CREDIT,
      targetType: 'ambassador_commission',
      targetId: id,
      metadata: { via: 'system', ambassador: amb.userId, cherries: Number(c.cherries), month: c.month },
    },
  });
  return 'CREDITED';
}

/** Gives a month's target reward (coins, VIP days or a bag item). Audited; the person is notified. */
async function grantRewardIn(
  tx: Tx,
  userId: string,
  month: string,
  reward: AmbassadorReward,
  now: Date,
): Promise<void> {
  switch (reward.kind) {
    case 'NONE':
      return;
    case 'COINS':
      await creditIn(tx, userId, BigInt(reward.amount), 'AMBASSADOR_REWARD', rewardReference(userId, month));
      break;
    case 'VIP_DAYS':
      await grantVipIn(tx, userId, reward.vipTier, reward.amount, now);
      break;
    case 'BAG_ITEM':
      await grantBagItemByAdminIn(
        tx,
        userId,
        reward.itemCode,
        reward.amount,
        SYSTEM_VIA,
        `ambassador ${month}`,
        now,
      );
      break;
  }
  await tx.ambassadorMonth.update({
    where: { ambassadorUserId_month: { ambassadorUserId: userId, month } },
    data: { rewardStatus: 'GRANTED', grantedAt: now },
  });
  await tx.auditLog.create({
    data: {
      action: AuditAction.AMBASSADOR_REWARD_GRANT,
      targetType: 'ambassador',
      targetId: userId,
      metadata: { via: 'system', month, reward: reward },
    },
  });
  await new Notifier().system(tx, { type: 'AMBASSADOR_REWARD_GRANTED', recipientId: userId });
}

/** One ambassador's month (§10.179.6): the stats, the level change and the target reward. Once (primary key). */
async function evaluateMonthIn(
  tx: Tx,
  userId: string,
  month: string,
  settings: AmbassadorSettingsValue,
  now: Date,
): Promise<{ levelChanged: boolean; rewarded: boolean } | null> {
  const [amb] = await tx.$queryRaw<{ user_id: string }[]>`
    SELECT user_id::text AS user_id FROM ambassadors WHERE user_id = ${userId}::uuid FOR UPDATE`;
  if (!amb) return null;
  if ((await tx.ambassadorMonth.count({ where: { ambassadorUserId: userId, month } })) > 0) return null;
  const row = await tx.ambassador.findUniqueOrThrow({ where: { userId } });
  const levels = settings.levels;
  const activeReferrals = await tx.ambassadorReferral.count({
    where: { ambassadorUserId: userId, status: 'ACTIVE', activeMonth: month },
  });
  const [sums] = await tx.$queryRaw<{ coins: bigint; cherries: bigint }[]>`
    SELECT COALESCE(sum(coins) FILTER (WHERE status IN ('PENDING', 'CREDITED') OR void_reason IN ('MONTHLY_CAP', 'ZERO')), 0)::bigint AS coins,
           COALESCE(sum(cherries) FILTER (WHERE status IN ('PENDING', 'CREDITED')), 0)::bigint AS cherries
      FROM ambassador_commissions WHERE ambassador_user_id = ${userId}::uuid AND month = ${month}`;
  const stats = { activeReferrals, topupCoins: sums?.coins ?? 0n };
  const before = levelIndex(levels, row.level);
  const met = metLevelIndex(levels, stats);
  const after = levelAfterMonth(before, met);
  const reward = levels[met]!.reward;
  const hasReward = reward.kind !== 'NONE';
  const isHeld = held(row) || (await isPanelStaff(tx, userId));
  await tx.ambassadorMonth.create({
    data: {
      ambassadorUserId: userId,
      month,
      activeReferrals,
      topupCoins: stats.topupCoins,
      commissionCherries: sums?.cherries ?? 0n,
      levelBefore: levels[before]!.code,
      levelAfter: levels[after]!.code,
      metLevel: levels[met]!.code,
      reward: hasReward ? (reward as unknown as Prisma.InputJsonObject) : undefined,
      rewardStatus: hasReward ? 'HELD' : 'NONE',
      evaluatedAt: now,
    },
  });
  await tx.auditLog.create({
    data: {
      action: AuditAction.AMBASSADOR_MONTH_EVALUATE,
      targetType: 'ambassador',
      targetId: userId,
      metadata: {
        via: 'system',
        month,
        activeReferrals,
        topupCoins: Number(stats.topupCoins),
        before: levels[before]!.code,
        met: levels[met]!.code,
        after: levels[after]!.code,
        reward: hasReward ? (isHeld ? 'HELD' : 'GRANTED') : 'NONE',
      },
    },
  });
  if (after !== before || levels[before]!.code !== row.level) {
    await tx.ambassador.update({
      where: { userId },
      data: { level: levels[after]!.code, levelChangedAt: now },
    });
    await tx.auditLog.create({
      data: {
        action: AuditAction.AMBASSADOR_LEVEL_CHANGE,
        targetType: 'ambassador',
        targetId: userId,
        metadata: { via: 'system', month, before: row.level, after: levels[after]!.code },
      },
    });
    if (after > before) await new Notifier().system(tx, { type: 'AMBASSADOR_LEVEL_UP', recipientId: userId });
  }
  if (hasReward && !isHeld) await grantRewardIn(tx, userId, month, reward, now);
  return { levelChanged: after !== before, rewarded: hasReward && !isHeld };
}

export interface AmbassadorSweep {
  readonly activated: number;
  readonly referralsVoided: number;
  readonly credited: number;
  readonly commissionsVoided: number;
  readonly monthsEvaluated: number;
  readonly rewardsGranted: number;
}

/**
 * The sweeper's step (`AMBASSADOR_SWEEP_INTERVAL_SECONDS`): the PENDING referrals (activated or voided), the due
 * commissions (credited, voided or left held), then — after a month ends — each ambassador's last month, and the
 * rewards held earlier for an ambassador who is no longer frozen or under review. Each item in its own transaction;
 * bounded batches. Nothing runs while the programme is off (everything waits, nothing is lost).
 */
export async function sweepAmbassadors(
  prisma: PrismaClient,
  now: Date,
  timeZone: string,
  batch = 200,
): Promise<AmbassadorSweep> {
  const out = {
    activated: 0,
    referralsVoided: 0,
    credited: 0,
    commissionsVoided: 0,
    monthsEvaluated: 0,
    rewardsGranted: 0,
  };
  const settings = await ambassadorSettingsIn(prisma);
  if (!settings.enabled || settings.levels.length === 0) return out;
  const pending = await prisma.ambassadorReferral.findMany({
    where: { status: 'PENDING' },
    orderBy: { createdAt: 'asc' },
    take: batch,
    select: { referralId: true },
  });
  for (const r of pending) {
    const res = await prisma.$transaction((tx) =>
      settleReferralIn(tx, r.referralId, settings, now, timeZone),
    );
    if (res === 'ACTIVE') out.activated++;
    else if (res === 'VOID') out.referralsVoided++;
  }
  const due = await prisma.ambassadorCommission.findMany({
    where: { status: 'PENDING', holdUntil: { lte: now } },
    orderBy: { holdUntil: 'asc' },
    take: batch,
    select: { id: true },
  });
  for (const c of due) {
    const res = await prisma.$transaction((tx) => settleCommissionIn(tx, c.id, now));
    if (res === 'CREDITED') out.credited++;
    else if (res === 'VOID') out.commissionsVoided++;
  }
  const current = ambassadorMonth(now, timeZone);
  const last = previousMonth(current);
  const toEvaluate = await prisma.$queryRaw<{ user_id: string }[]>`
    SELECT a.user_id::text AS user_id FROM ambassadors a
     WHERE a.status <> 'ENDED'
       AND a.activated_at < (${`${current}-01`}::date::timestamp AT TIME ZONE ${timeZone}::text)
       AND NOT EXISTS (SELECT 1 FROM ambassador_months m WHERE m.ambassador_user_id = a.user_id AND m.month = ${last})
     ORDER BY a.user_id LIMIT ${batch}`;
  for (const a of toEvaluate) {
    const res = await prisma.$transaction((tx) => evaluateMonthIn(tx, a.user_id, last, settings, now));
    if (res) {
      out.monthsEvaluated++;
      if (res.rewarded) out.rewardsGranted++;
    }
  }
  const heldRewards = await prisma.$queryRaw<{ user_id: string; month: string }[]>`
    SELECT m.ambassador_user_id::text AS user_id, m.month FROM ambassador_months m
      JOIN ambassadors a ON a.user_id = m.ambassador_user_id
     WHERE m.reward_status = 'HELD' AND a.status = 'ACTIVE' AND NOT a.under_review
     ORDER BY m.month, m.ambassador_user_id LIMIT ${batch}`;
  for (const h of heldRewards) {
    const granted = await prisma.$transaction(async (tx) => {
      const [locked] = await tx.$queryRaw<{ reward: unknown }[]>`
        SELECT reward FROM ambassador_months
         WHERE ambassador_user_id = ${h.user_id}::uuid AND month = ${h.month} AND reward_status = 'HELD' FOR UPDATE`;
      if (!locked || (await isPanelStaff(tx, h.user_id))) return false;
      await grantRewardIn(tx, h.user_id, h.month, locked.reward as AmbassadorReward, now);
      return true;
    });
    if (granted) out.rewardsGranted++;
  }
  return out;
}

// ---- The team's actions ------------------------------------------------------------------------------------------

async function audit(
  tx: Tx,
  action: AuditAction,
  targetType: string,
  targetId: string,
  metadata: Prisma.InputJsonObject,
  by: AdminVia,
): Promise<void> {
  await tx.auditLog.create({
    data: { ...auditBy(by), action, targetType, targetId, metadata: { ...metadata, via: by.via } },
  });
}

async function makeAmbassadorIn(
  tx: Tx,
  input: {
    userId: string;
    source: 'APPLICATION' | 'APPOINTED';
    applicationId: string | null;
    country: string | null;
  },
  now: Date,
  by: AdminVia,
): Promise<void> {
  const settings = await ambassadorSettingsIn(tx);
  await tx.ambassador.create({
    data: {
      userId: input.userId,
      level: settings.levels[0]?.code ?? 'BRONZE',
      source: input.source,
      applicationId: input.applicationId,
      appointedById: input.source === 'APPOINTED' ? by.actorUserId : null,
      country: input.country,
      activatedAt: now,
      levelChangedAt: now,
    },
  });
  await new Notifier().system(tx, { type: 'AMBASSADOR_APPLICATION_APPROVED', recipientId: input.userId });
}

async function lockPendingApplication(tx: Tx, id: string) {
  const [app] = await tx.$queryRaw<{ id: string; status: string }[]>`
    SELECT id::text AS id, status::text AS status FROM ambassador_applications WHERE id = ${id}::uuid FOR UPDATE`;
  if (!app) throw new AmbassadorAdminError(`No application ${id}.`, 'not_found');
  if (app.status !== 'PENDING')
    throw new AmbassadorAdminError(`The application is ${app.status}.`, 'not_pending');
  return tx.ambassadorApplication.findUniqueOrThrow({ where: { id } });
}

/** Approve: the person becomes an ambassador at the first level (notified, audited). */
export async function approveAmbassadorApplicationIn(
  tx: Tx,
  id: string,
  now: Date,
  by: AdminVia,
): Promise<string> {
  const app = await lockPendingApplication(tx, id);
  if ((await healthIn(tx, app.userId, now)) !== 'OK')
    throw new AmbassadorAdminError('The account is not ACTIVE.', 'account_not_active');
  if (await isPanelStaff(tx, app.userId)) throw new AmbassadorAdminError('A Kabso Team account.', 'staff');
  if ((await tx.ambassador.count({ where: { userId: app.userId } })) > 0)
    throw new AmbassadorAdminError('Already an ambassador.', 'already_ambassador');
  await tx.ambassadorApplication.update({
    where: { id },
    data: { status: 'APPROVED', decidedAt: now, decidedById: by.actorUserId },
  });
  await makeAmbassadorIn(
    tx,
    { userId: app.userId, source: 'APPLICATION', applicationId: id, country: app.country },
    now,
    by,
  );
  await audit(
    tx,
    AuditAction.AMBASSADOR_APPLICATION_APPROVE,
    'ambassador_application',
    id,
    { user: app.userId },
    by,
  );
  return app.userId;
}

export async function rejectAmbassadorApplicationIn(
  tx: Tx,
  id: string,
  reason: string,
  now: Date,
  by: AdminVia,
): Promise<string> {
  const app = await lockPendingApplication(tx, id);
  await tx.ambassadorApplication.update({
    where: { id },
    data: { status: 'REJECTED', decidedAt: now, decidedById: by.actorUserId, rejectReason: reason },
  });
  await new Notifier().system(tx, { type: 'AMBASSADOR_APPLICATION_REJECTED', recipientId: app.userId });
  await audit(
    tx,
    AuditAction.AMBASSADOR_APPLICATION_REJECT,
    'ambassador_application',
    id,
    { user: app.userId, reason },
    by,
  );
  return app.userId;
}

/** The team appoints an ambassador directly (a pending application of theirs is closed as CANCELLED). */
export async function appointAmbassadorIn(
  tx: Tx,
  userId: string,
  input: { reason: string; country: string | null },
  now: Date,
  by: AdminVia,
): Promise<void> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:ambassador'), hashtext(${userId}))`;
  const refusal = await eligibilityIn(tx, userId, now);
  if (refusal === 'ACCOUNT_NOT_ACTIVE')
    throw new AmbassadorAdminError('The account is not ACTIVE.', 'account_not_active');
  if (refusal === 'STAFF') throw new AmbassadorAdminError('A Kabso Team account.', 'staff');
  if (refusal === 'AMBASSADOR')
    throw new AmbassadorAdminError('Already an ambassador.', 'already_ambassador');
  await tx.ambassadorApplication.updateMany({
    where: { userId, status: 'PENDING' },
    data: { status: 'CANCELLED', decidedAt: now, decidedById: by.actorUserId },
  });
  if (refusal === 'ENDED') {
    // D390 follow-up (§10.179.11): the OWNER's re-appointment of an ended member (`ambassadors.manage` is enough to
    // appoint, but only the OWNER may end, so a re-appointment is always a deliberate decision). A fresh start: the
    // first level, ACTIVE, the end cleared, the review flag kept.
    const settings = await ambassadorSettingsIn(tx);
    await tx.ambassador.update({
      where: { userId },
      data: {
        status: 'ACTIVE',
        level: settings.levels[0]?.code ?? 'BRONZE',
        source: 'APPOINTED',
        applicationId: null,
        appointedById: by.actorUserId,
        country: input.country,
        activatedAt: now,
        levelChangedAt: now,
        endedAt: null,
        endedReason: null,
        endedById: null,
      },
    });
    await new Notifier().system(tx, { type: 'AMBASSADOR_APPLICATION_APPROVED', recipientId: userId });
  } else {
    await makeAmbassadorIn(
      tx,
      { userId, source: 'APPOINTED', applicationId: null, country: input.country },
      now,
      by,
    );
  }
  await audit(
    tx,
    AuditAction.AMBASSADOR_APPOINT,
    'ambassador',
    userId,
    { reason: input.reason, country: input.country },
    by,
  );
}

/** OWNER: freeze (every payout and reward held) or unfreeze. Changes nothing when already so. */
export async function setAmbassadorFrozenIn(
  tx: Tx,
  userId: string,
  frozen: boolean,
  reason: string,
  now: Date,
  by: AdminVia,
): Promise<boolean> {
  const [row] = await tx.$queryRaw<{ status: string }[]>`
    SELECT status::text AS status FROM ambassadors WHERE user_id = ${userId}::uuid FOR UPDATE`;
  if (!row) throw new AmbassadorAdminError('Not an ambassador.', 'not_found');
  if (row.status === 'ENDED') throw new AmbassadorAdminError('The membership has ended.', 'ended');
  if ((row.status === 'FROZEN') === frozen) return false;
  await tx.ambassador.update({
    where: { userId },
    data: frozen
      ? { status: 'FROZEN', frozenAt: now, frozenReason: reason, frozenById: by.actorUserId }
      : { status: 'ACTIVE', frozenAt: null, frozenReason: null, frozenById: null },
  });
  const [pending] = await tx.$queryRaw<{ n: bigint; c: bigint }[]>`
    SELECT count(*)::bigint AS n, COALESCE(sum(cherries), 0)::bigint AS c FROM ambassador_commissions
     WHERE ambassador_user_id = ${userId}::uuid AND status = 'PENDING'`;
  await audit(
    tx,
    frozen ? AuditAction.AMBASSADOR_FREEZE : AuditAction.AMBASSADOR_UNFREEZE,
    'ambassador',
    userId,
    { reason, pendingCommissions: Number(pending?.n ?? 0n), pendingCherries: Number(pending?.c ?? 0n) },
    by,
  );
  return true;
}

/**
 * D390 follow-up (owner «نعم», §10.179.11): «إنهاء العضوية» — OWNER only (the code again and a reason). The membership is
 * ENDED at once: no new commission, the friends keep their track (no conversion back to D217), the badge disappears.
 * Default for the money (documented, owner may choose otherwise): every PENDING commission — in its hold or held — is
 * VOID `MEMBERSHIP_ENDED`, and a month reward still HELD is VOID; credited commissions and granted rewards stay. The
 * person is notified (`AMBASSADOR_MEMBERSHIP_ENDED`); audited `ambassador.end` with the amounts. Already ENDED: nothing.
 */
export async function endAmbassadorIn(
  tx: Tx,
  userId: string,
  reason: string,
  now: Date,
  by: AdminVia,
): Promise<{ changed: boolean; voidedCommissions: number; voidedCherries: bigint; voidedRewards: number }> {
  const [row] = await tx.$queryRaw<{ status: string }[]>`
    SELECT status::text AS status FROM ambassadors WHERE user_id = ${userId}::uuid FOR UPDATE`;
  if (!row) throw new AmbassadorAdminError('Not an ambassador.', 'not_found');
  if (row.status === 'ENDED')
    return { changed: false, voidedCommissions: 0, voidedCherries: 0n, voidedRewards: 0 };
  await tx.ambassador.update({
    where: { userId },
    data: {
      status: 'ENDED',
      endedAt: now,
      endedReason: reason,
      endedById: by.actorUserId,
      frozenAt: null,
      frozenReason: null,
      frozenById: null,
    },
  });
  const pending = await tx.ambassadorCommission.findMany({
    where: { ambassadorUserId: userId, status: 'PENDING' },
  });
  let voidedCherries = 0n;
  for (const c of pending) {
    await voidCommissionIn(tx, c, 'MEMBERSHIP_ENDED', now);
    voidedCherries += c.cherries;
  }
  const rewards = await tx.ambassadorMonth.updateMany({
    where: { ambassadorUserId: userId, rewardStatus: 'HELD' },
    data: { rewardStatus: 'VOID' },
  });
  await new Notifier().system(tx, { type: 'AMBASSADOR_MEMBERSHIP_ENDED', recipientId: userId });
  await audit(
    tx,
    AuditAction.AMBASSADOR_END,
    'ambassador',
    userId,
    {
      reason,
      before: row.status,
      voidedCommissions: pending.length,
      voidedCherries: Number(voidedCherries),
      voidedRewards: rewards.count,
    },
    by,
  );
  return { changed: true, voidedCommissions: pending.length, voidedCherries, voidedRewards: rewards.count };
}

/** OWNER: the review is over — the flags cleared, the held payouts resume at the next sweep. */
export async function clearAmbassadorReviewIn(
  tx: Tx,
  userId: string,
  reason: string,
  now: Date,
  by: AdminVia,
): Promise<boolean> {
  const row = await tx.ambassador.findUnique({ where: { userId } });
  if (!row) throw new AmbassadorAdminError('Not an ambassador.', 'not_found');
  if (!row.underReview) return false;
  await tx.ambassador.update({
    where: { userId },
    data: { underReview: false, reviewReason: null, reviewAt: null },
  });
  const cleared = await tx.ambassadorFlag.updateMany({
    where: { ambassadorUserId: userId, clearedAt: null },
    data: { clearedAt: now, clearedById: by.actorUserId },
  });
  await audit(
    tx,
    AuditAction.AMBASSADOR_REVIEW_CLEAR,
    'ambassador',
    userId,
    { reason, flags: cleared.count },
    by,
  );
  return true;
}
