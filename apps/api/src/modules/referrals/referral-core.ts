import { createHash } from 'node:crypto';
import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type {
  Prisma,
  PrismaClient,
  ReferralReward,
  ReferralRewardKind,
  ReferralStatus,
} from '../../generated/prisma/client.js';
import { creditReferralCherriesIn, reverseReferralCherriesIn } from '../economy/cherry-ledger.js';
import { Notifier } from '../notifications/notifier.js';
import { uuidv7 } from '../levels/uuidv7.js';
import {
  canonicalEmail,
  firstRechargeCherries,
  milestonesJson,
  newReferralCode,
  parseMilestones,
  type ReferralRejectReason,
  type ReferralSettingsPatch,
  type ReferralSettingsValue,
} from './referral-rules.js';

/**
 * «دعوة الأصدقاء» (v1.74-social, D217, CONVENTIONS §10.71): the database rules, shared by the API (sign-up, the
 * later code, the recharge hook, the sweeper, the panel) and the `referral-admin` CLI — no Nest dependency.
 *
 * Flow: a code applied at sign-up (`attachReferralIn`, source SIGNUP) or later (source LATER, within
 * `applyWindowDays` of the account's creation, once) makes a referral — REJECTED at once by a fraud rule (no reward),
 * else PENDING with its sign-up rewards PENDING until `holdHours`. The invitee's first recharge on any path
 * (`referralRechargeIn`) adds a FIRST_RECHARGE reward, held as well. The sweeper (`sweepReferrals`) qualifies each due
 * referral after re-checking both accounts (or voids it), credits each due reward (`REFERRAL_REWARD`, reference = the
 * reward) or voids it, and gives each milestone bonus the inviter's qualified friends reached. Every step is audited.
 */

type Tx = Prisma.TransactionClient;
type Db = Tx | PrismaClient;
const HOUR_MS = 3_600_000;
const DAY_MS = 86_400_000;

/** A refusal by a team rule (approve / void / settings); the panel answers it as ADMIN_ACTION_REFUSED. */
export class ReferralAdminError extends Error {}

export interface ReferralSettingsRow extends ReferralSettingsValue {
  readonly updatedAt: Date;
  readonly updatedById: string | null;
}

/** The settings row (id 1; the migration inserts it — a missing row reads as the defaults, switched off). */
export async function referralSettingsIn(db: Db): Promise<ReferralSettingsRow> {
  const row = await db.referralSettings.findUnique({ where: { id: 1 } });
  if (!row) {
    return {
      enabled: false,
      inviterSignupCherries: 0n,
      inviteeSignupCherries: 0n,
      firstRechargeBps: 0,
      milestones: [],
      dailySignupCap: 0,
      holdHours: 24,
      applyWindowDays: 7,
      selfIpWindowHours: 24,
      updatedAt: new Date(0),
      updatedById: null,
    };
  }
  return {
    enabled: row.enabled,
    inviterSignupCherries: row.inviterSignupCherries,
    inviteeSignupCherries: row.inviteeSignupCherries,
    firstRechargeBps: row.firstRechargeBps,
    milestones: parseMilestones(row.milestones),
    dailySignupCap: row.dailySignupCap,
    holdHours: row.holdHours,
    applyWindowDays: row.applyWindowDays,
    selfIpWindowHours: row.selfIpWindowHours,
    updatedAt: row.updatedAt,
    updatedById: row.updatedById,
  };
}

/** The settings as JSON for audit rows and the CLI. */
export function settingsJson(s: ReferralSettingsValue): Prisma.InputJsonObject {
  return {
    enabled: s.enabled,
    inviterSignupCherries: Number(s.inviterSignupCherries),
    inviteeSignupCherries: Number(s.inviteeSignupCherries),
    firstRechargeBps: s.firstRechargeBps,
    milestones: milestonesJson(s.milestones),
    dailySignupCap: s.dailySignupCap,
    holdHours: s.holdHours,
    applyWindowDays: s.applyWindowDays,
    selfIpWindowHours: s.selfIpWindowHours,
  };
}

/** Changes the settings (panel: FINANCE / OWNER with the code again; CLI), audited with before and after. */
export async function updateReferralSettingsIn(
  tx: Tx,
  patch: ReferralSettingsPatch,
  reason: string,
  now: Date,
  by: AdminVia = CLI_VIA,
): Promise<ReferralSettingsRow> {
  await tx.$executeRaw`SELECT 1 FROM referral_settings WHERE id = 1 FOR UPDATE`;
  const before = await referralSettingsIn(tx);
  const data: Prisma.ReferralSettingsUncheckedUpdateInput = {
    ...(patch.enabled !== undefined ? { enabled: patch.enabled } : {}),
    ...(patch.inviterSignupCherries !== undefined
      ? { inviterSignupCherries: patch.inviterSignupCherries }
      : {}),
    ...(patch.inviteeSignupCherries !== undefined
      ? { inviteeSignupCherries: patch.inviteeSignupCherries }
      : {}),
    ...(patch.firstRechargeBps !== undefined ? { firstRechargeBps: patch.firstRechargeBps } : {}),
    ...(patch.milestones !== undefined
      ? {
          milestones: milestonesJson(
            patch.milestones.map((m) => ({ friends: m.friends, cherries: m.cherries })),
          ),
        }
      : {}),
    ...(patch.dailySignupCap !== undefined ? { dailySignupCap: patch.dailySignupCap } : {}),
    ...(patch.holdHours !== undefined ? { holdHours: patch.holdHours } : {}),
    ...(patch.applyWindowDays !== undefined ? { applyWindowDays: patch.applyWindowDays } : {}),
    ...(patch.selfIpWindowHours !== undefined ? { selfIpWindowHours: patch.selfIpWindowHours } : {}),
    updatedAt: now,
    updatedById: by.actorUserId,
  };
  await tx.referralSettings.upsert({
    where: { id: 1 },
    create: { id: 1, ...(data as Prisma.ReferralSettingsUncheckedCreateInput) },
    update: data,
  });
  const after = await referralSettingsIn(tx);
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.REFERRAL_SETTINGS_UPDATE,
      targetType: 'referral_settings',
      targetId: '1',
      metadata: { via: by.via, reason, before: settingsJson(before), after: settingsJson(after) },
    },
  });
  return after;
}

/** The person's invite code, made on first use (stable afterwards; a collision tries a new one). */
export async function ensureReferralCodeIn(db: PrismaClient, userId: string): Promise<string> {
  const existing = await db.referralCode.findUnique({ where: { userId }, select: { code: true } });
  if (existing) return existing.code;
  for (let attempt = 0; attempt < 8; attempt++) {
    const code = newReferralCode();
    const rows = await db.$queryRaw<{ code: string }[]>`
      INSERT INTO referral_codes (user_id, code, created_at) VALUES (${userId}::uuid, ${code}, now())
      ON CONFLICT DO NOTHING
      RETURNING code`;
    if (rows[0]) return rows[0].code;
    const mine = await db.referralCode.findUnique({ where: { userId }, select: { code: true } });
    if (mine) return mine.code;
  }
  throw new Error('Could not make a unique invite code');
}

/** Why an account cannot earn or be counted now: banned, deleted (or being deleted) or locked by the team. */
export type AccountHealth = 'OK' | 'BANNED' | 'DELETED' | 'FLAGGED';

export async function accountHealthIn(db: Db, userId: string, now: Date): Promise<AccountHealth> {
  const user = await db.user.findUnique({ where: { id: userId }, select: { status: true } });
  if (!user || user.status === 'DELETED' || user.status === 'PENDING_DELETION') return 'DELETED';
  if (user.status !== 'ACTIVE') return 'BANNED';
  const lock = await db.accountRestriction.count({
    where: { userId, kind: 'LOCK', liftedAt: null, startsAt: { lte: now }, endsAt: { gt: now } },
  });
  return lock > 0 ? 'FLAGGED' : 'OK';
}

export interface AttachInput {
  readonly inviteeUserId: string;
  /** Normalized (`normalizeReferralCode`). */
  readonly code: string;
  readonly source: 'SIGNUP' | 'LATER';
  readonly installId: string | null;
  readonly ip: string | null;
  readonly email: string;
  readonly now: Date;
  readonly requestId?: string | null;
}

export type AttachResult =
  | { readonly kind: 'ATTACHED' | 'REJECTED'; readonly referralId: string; readonly status: ReferralStatus }
  | { readonly kind: 'DISABLED' | 'UNKNOWN_CODE' | 'OWN_CODE' | 'ALREADY' };

/**
 * Applies an invite code for `inviteeUserId` inside the caller's transaction. The inviter's code row is locked, so
 * one inviter's attaches (and the daily cap) are serialized. Fraud rules, in order (the first that matches rejects
 * the referral; nothing is paid): the same mailbox as the inviter (`SELF_EMAIL`), the inviter's own install id
 * (`SELF_DEVICE`), the inviter's IP within `selfIpWindowHours` (`SELF_IP`), an install id or a mailbox already
 * referred by anyone (`DUPLICATE_DEVICE`, `DUPLICATE_EMAIL`).
 */
export async function attachReferralIn(tx: Tx, input: AttachInput): Promise<AttachResult> {
  const settings = await referralSettingsIn(tx);
  if (!settings.enabled) return { kind: 'DISABLED' };
  const [owner] = await tx.$queryRaw<{ user_id: string; status: string; email: string }[]>`
    SELECT c.user_id::text AS user_id, u.status::text AS status, u.email
      FROM referral_codes c JOIN users u ON u.id = c.user_id
     WHERE c.code = ${input.code}
       FOR UPDATE OF c`;
  if (!owner || owner.status !== 'ACTIVE') return { kind: 'UNKNOWN_CODE' };
  const inviterId = owner.user_id;
  if (inviterId === input.inviteeUserId) return { kind: 'OWN_CODE' };
  if ((await tx.referral.count({ where: { inviteeUserId: input.inviteeUserId } })) > 0)
    return { kind: 'ALREADY' };

  const now = input.now;
  const email = canonicalEmail(input.email);
  const emailHash = createHash('sha256').update(email).digest('hex');
  const ip = input.ip?.slice(0, 64) ?? null;
  const installId = input.installId;
  let reject: ReferralRejectReason | null = null;
  if (canonicalEmail(owner.email) === email) reject = 'SELF_EMAIL';
  if (reject === null && installId !== null) {
    const own = await tx.session.count({ where: { userId: inviterId, installId } });
    const ownReferral = await tx.referral.count({
      where: { inviteeUserId: inviterId, inviteeInstallId: installId },
    });
    if (own + ownReferral > 0) reject = 'SELF_DEVICE';
  }
  if (reject === null && ip !== null && settings.selfIpWindowHours > 0) {
    const since = new Date(now.getTime() - settings.selfIpWindowHours * HOUR_MS);
    const same = await tx.session.count({ where: { userId: inviterId, ip, lastUsedAt: { gte: since } } });
    if (same > 0) reject = 'SELF_IP';
  }
  if (reject === null && installId !== null) {
    if ((await tx.referral.count({ where: { inviteeInstallId: installId } })) > 0)
      reject = 'DUPLICATE_DEVICE';
  }
  if (reject === null && (await tx.referral.count({ where: { inviteeEmailHash: emailHash } })) > 0) {
    reject = 'DUPLICATE_EMAIL';
  }

  const referralId = uuidv7();
  const holdUntil = new Date(now.getTime() + settings.holdHours * HOUR_MS);
  // A later code after a recharge: the first recharge already happened (no FIRST_RECHARGE reward).
  const [recharged] = await tx.$queryRaw<{ at: Date | null }[]>`
    SELECT min(created_at) AS at FROM wallet_ledger
     WHERE user_id = ${input.inviteeUserId}::uuid AND reason IN ('CARD_TOPUP', 'RECHARGE_PURCHASE', 'RECHARGE_ORDER')`;
  await tx.referral.create({
    data: {
      id: referralId,
      inviterUserId: inviterId,
      inviteeUserId: input.inviteeUserId,
      code: input.code,
      source: input.source,
      status: reject === null ? 'PENDING' : 'REJECTED',
      rejectReason: reject,
      inviteeInstallId: installId,
      inviteeIp: ip,
      inviteeEmailHash: emailHash,
      holdUntil,
      firstRechargeAt: recharged?.at ?? null,
      createdAt: now,
    },
  });
  const rewards: { kind: ReferralRewardKind; userId: string; cherries: bigint; voidReason?: string }[] = [];
  if (reject === null) {
    if (settings.inviterSignupCherries > 0n) {
      let capped = false;
      if (settings.dailySignupCap > 0) {
        const recent = await tx.referralReward.count({
          where: {
            userId: inviterId,
            kind: 'SIGNUP_INVITER',
            status: { not: 'VOID' },
            createdAt: { gt: new Date(now.getTime() - DAY_MS) },
          },
        });
        capped = recent >= settings.dailySignupCap;
      }
      rewards.push({
        kind: 'SIGNUP_INVITER',
        userId: inviterId,
        cherries: settings.inviterSignupCherries,
        ...(capped ? { voidReason: 'DAILY_CAP' } : {}),
      });
    }
    if (settings.inviteeSignupCherries > 0n) {
      rewards.push({
        kind: 'SIGNUP_INVITEE',
        userId: input.inviteeUserId,
        cherries: settings.inviteeSignupCherries,
      });
    }
  }
  for (const r of rewards) {
    const id = uuidv7();
    await tx.referralReward.create({
      data: {
        id,
        referralId,
        userId: r.userId,
        kind: r.kind,
        cherries: r.cherries,
        holdUntil,
        createdAt: now,
        ...(r.voidReason ? { status: 'VOID', voidedAt: now, voidReason: r.voidReason } : {}),
      },
    });
    await tx.auditLog.create({
      data: {
        action: r.voidReason ? AuditAction.REFERRAL_REWARD_VOID : AuditAction.REFERRAL_REWARD_CREATE,
        targetType: 'referral_reward',
        targetId: id,
        requestId: input.requestId ?? null,
        metadata: {
          referral: referralId,
          user: r.userId,
          kind: r.kind,
          cherries: Number(r.cherries),
          holdUntil: holdUntil.toISOString(),
          ...(r.voidReason ? { reason: r.voidReason } : {}),
        },
      },
    });
  }
  await tx.auditLog.create({
    data: {
      actorUserId: input.inviteeUserId,
      action: AuditAction.REFERRAL_ATTACH,
      targetType: 'referral',
      targetId: referralId,
      ip,
      requestId: input.requestId ?? null,
      metadata: {
        inviter: inviterId,
        invitee: input.inviteeUserId,
        source: input.source,
        status: reject === null ? 'PENDING' : 'REJECTED',
        rejectReason: reject,
        installId: installId !== null,
      },
    },
  });
  return reject === null
    ? { kind: 'ATTACHED', referralId, status: 'PENDING' }
    : { kind: 'REJECTED', referralId, status: 'REJECTED' };
}

/** The coin ledger reasons of a recharge (a website top-up, an agent's sale, a recharge order). */
export type RechargeLedgerReason = 'CARD_TOPUP' | 'RECHARGE_PURCHASE' | 'RECHARGE_ORDER';

/**
 * The first-recharge hook, in the recharge's transaction (all three paths call it right after crediting the coins).
 * The invitee's first recharge marks the referral (once: a conditional UPDATE); when the referral is PENDING or
 * QUALIFIED and the programme is on, the inviter gets a FIRST_RECHARGE reward of floor(coins × CHERRIES_PER_COIN ×
 * `firstRechargeBps` / 10 000) cherries, held `holdHours`. Not a referred person, or not the first recharge: nothing.
 */
export async function referralRechargeIn(
  tx: Tx,
  input: { userId: string; coins: bigint; reason: RechargeLedgerReason; reference: string; now: Date },
  cherriesPerCoin: number,
): Promise<string | null> {
  const [ref] = await tx.$queryRaw<{ id: string; inviter: string; status: ReferralStatus }[]>`
    UPDATE referrals SET first_recharge_at = ${input.now}
     WHERE invitee_user_id = ${input.userId}::uuid AND first_recharge_at IS NULL
    RETURNING id::text AS id, inviter_user_id::text AS inviter, status::text AS status`;
  if (!ref || (ref.status !== 'PENDING' && ref.status !== 'QUALIFIED')) return null;
  const settings = await referralSettingsIn(tx);
  if (!settings.enabled) return null;
  const cherries = firstRechargeCherries(input.coins, cherriesPerCoin, settings.firstRechargeBps);
  if (cherries <= 0n) return null;
  const id = uuidv7();
  const holdUntil = new Date(input.now.getTime() + settings.holdHours * HOUR_MS);
  await tx.referralReward.create({
    data: {
      id,
      referralId: ref.id,
      userId: ref.inviter,
      kind: 'FIRST_RECHARGE',
      cherries,
      holdUntil,
      baseCoins: input.coins,
      rateBps: settings.firstRechargeBps,
      rechargeReason: input.reason,
      rechargeReference: input.reference,
      createdAt: input.now,
    },
  });
  await tx.auditLog.create({
    data: {
      action: AuditAction.REFERRAL_REWARD_CREATE,
      targetType: 'referral_reward',
      targetId: id,
      metadata: {
        referral: ref.id,
        user: ref.inviter,
        kind: 'FIRST_RECHARGE',
        cherries: Number(cherries),
        coins: Number(input.coins),
        rateBps: settings.firstRechargeBps,
        recharge: input.reason,
        reference: input.reference,
        holdUntil: holdUntil.toISOString(),
      },
    },
  });
  return id;
}

async function creditRewardIn(tx: Tx, reward: ReferralReward, now: Date, by: AdminVia | null): Promise<void> {
  await creditReferralCherriesIn(tx, reward.userId, reward.cherries, reward.id, now);
  await tx.referralReward.update({
    where: { id: reward.id },
    data: { status: 'CREDITED', creditedAt: now, voidedAt: null },
  });
  await tx.auditLog.create({
    data: {
      ...(by ? auditBy(by) : {}),
      action: AuditAction.REFERRAL_REWARD_CREDIT,
      targetType: 'referral_reward',
      targetId: reward.id,
      metadata: {
        user: reward.userId,
        kind: reward.kind,
        cherries: Number(reward.cherries),
        referral: reward.referralId,
        ...(by ? { via: by.via } : { via: 'sweeper' }),
      },
    },
  });
}

async function voidRewardIn(tx: Tx, reward: ReferralReward, reason: string, now: Date, by: AdminVia | null) {
  await tx.referralReward.update({
    where: { id: reward.id },
    data: { status: 'VOID', voidedAt: now, voidReason: reason },
  });
  await tx.auditLog.create({
    data: {
      ...(by ? auditBy(by) : {}),
      action: AuditAction.REFERRAL_REWARD_VOID,
      targetType: 'referral_reward',
      targetId: reward.id,
      metadata: {
        user: reward.userId,
        kind: reward.kind,
        cherries: Number(reward.cherries),
        referral: reward.referralId,
        reason,
        ...(by ? { via: by.via } : { via: 'sweeper' }),
      },
    },
  });
}

/**
 * The milestone bonuses `inviterId` has reached and not been given (qualified friends ≥ the threshold), credited at
 * once (the friends behind them already passed their hold). Only while the programme is on and the inviter is in good
 * standing; a later qualification catches up. Returns the cherries credited.
 */
export async function milestonesIn(tx: Tx, inviterId: string, now: Date): Promise<bigint> {
  const settings = await referralSettingsIn(tx);
  if (!settings.enabled || settings.milestones.length === 0) return 0n;
  if ((await accountHealthIn(tx, inviterId, now)) !== 'OK') return 0n;
  const qualified = await tx.referral.count({ where: { inviterUserId: inviterId, status: 'QUALIFIED' } });
  const given = new Set(
    (
      await tx.referralReward.findMany({
        where: { userId: inviterId, kind: 'MILESTONE', status: { not: 'REVERSED' } },
        select: { milestoneFriends: true },
      })
    ).map((r) => r.milestoneFriends),
  );
  let total = 0n;
  for (const m of settings.milestones) {
    if (m.friends > qualified || given.has(m.friends)) continue;
    const reward = await tx.referralReward.create({
      data: {
        id: uuidv7(),
        userId: inviterId,
        kind: 'MILESTONE',
        cherries: m.cherries,
        holdUntil: now,
        milestoneFriends: m.friends,
        createdAt: now,
      },
    });
    await tx.auditLog.create({
      data: {
        action: AuditAction.REFERRAL_REWARD_CREATE,
        targetType: 'referral_reward',
        targetId: reward.id,
        metadata: {
          user: inviterId,
          kind: 'MILESTONE',
          friends: m.friends,
          qualified,
          cherries: Number(m.cherries),
        },
      },
    });
    await creditRewardIn(tx, reward, now, null);
    total += m.cherries;
  }
  return total;
}

const HEALTH_REASON: Record<Exclude<AccountHealth, 'OK'>, string> = {
  BANNED: 'BANNED',
  DELETED: 'DELETED',
  FLAGGED: 'FLAGGED',
};

/** One due referral: qualified after re-checking both accounts, or voided (its pending rewards too). */
async function settleReferralIn(tx: Tx, referralId: string, now: Date): Promise<'QUALIFIED' | 'VOID' | null> {
  const [locked] = await tx.$queryRaw<{ id: string }[]>`
    SELECT id::text AS id FROM referrals
     WHERE id = ${referralId}::uuid AND status = 'PENDING' AND hold_until <= ${now}
       FOR UPDATE SKIP LOCKED`;
  if (!locked) return null;
  const referral = await tx.referral.findUniqueOrThrow({ where: { id: referralId } });
  const invitee = await accountHealthIn(tx, referral.inviteeUserId, now);
  const inviter = await accountHealthIn(tx, referral.inviterUserId, now);
  if (invitee !== 'OK' || inviter !== 'OK') {
    const reason =
      invitee !== 'OK'
        ? `INVITEE_${HEALTH_REASON[invitee]}`
        : `INVITER_${HEALTH_REASON[inviter as Exclude<AccountHealth, 'OK'>]}`;
    await tx.referral.update({
      where: { id: referralId },
      data: { status: 'VOID', voidedAt: now, voidReason: reason },
    });
    for (const r of await tx.referralReward.findMany({ where: { referralId, status: 'PENDING' } })) {
      await voidRewardIn(tx, r, reason, now, null);
    }
    await tx.auditLog.create({
      data: {
        action: AuditAction.REFERRAL_VOID,
        targetType: 'referral',
        targetId: referralId,
        metadata: {
          via: 'sweeper',
          reason,
          inviter: referral.inviterUserId,
          invitee: referral.inviteeUserId,
        },
      },
    });
    return 'VOID';
  }
  await tx.referral.update({ where: { id: referralId }, data: { status: 'QUALIFIED', qualifiedAt: now } });
  await tx.auditLog.create({
    data: {
      action: AuditAction.REFERRAL_QUALIFY,
      targetType: 'referral',
      targetId: referralId,
      metadata: { via: 'sweeper', inviter: referral.inviterUserId, invitee: referral.inviteeUserId },
    },
  });
  return 'QUALIFIED';
}

/** One due reward: credited, voided, or left for later (its referral is still in its hold). */
async function settleRewardIn(tx: Tx, rewardId: string, now: Date): Promise<'CREDITED' | 'VOID' | null> {
  const [locked] = await tx.$queryRaw<{ id: string }[]>`
    SELECT id::text AS id FROM referral_rewards
     WHERE id = ${rewardId}::uuid AND status = 'PENDING' AND hold_until <= ${now}
       FOR UPDATE SKIP LOCKED`;
  if (!locked) return null;
  const reward = await tx.referralReward.findUniqueOrThrow({ where: { id: rewardId } });
  const referral = reward.referralId
    ? await tx.referral.findUnique({ where: { id: reward.referralId } })
    : null;
  if (referral) {
    if (referral.status === 'PENDING') return null;
    if (referral.status !== 'QUALIFIED') {
      await voidRewardIn(tx, reward, 'REFERRAL_VOID', now, null);
      return 'VOID';
    }
    if (reward.kind === 'FIRST_RECHARGE') {
      const invitee = await accountHealthIn(tx, referral.inviteeUserId, now);
      if (invitee !== 'OK') {
        await voidRewardIn(tx, reward, `INVITEE_${HEALTH_REASON[invitee]}`, now, null);
        return 'VOID';
      }
      if (reward.rechargeReason === 'CARD_TOPUP' && reward.rechargeReference) {
        const order = await tx.topupOrder.findUnique({
          where: { id: reward.rechargeReference },
          select: { coinsReversed: true, status: true },
        });
        if (!order || order.coinsReversed > 0n) {
          await voidRewardIn(tx, reward, 'RECHARGE_REVERSED', now, null);
          return 'VOID';
        }
      }
    }
  }
  const health = await accountHealthIn(tx, reward.userId, now);
  if (health !== 'OK') {
    await voidRewardIn(tx, reward, HEALTH_REASON[health], now, null);
    return 'VOID';
  }
  await creditRewardIn(tx, reward, now, null);
  return 'CREDITED';
}

export interface ReferralSweep {
  readonly qualified: number;
  readonly voided: number;
  readonly credited: number;
  readonly rewardsVoided: number;
  readonly milestoneCherries: bigint;
}

/**
 * The sweeper's step (`REFERRAL_SWEEP_INTERVAL_SECONDS`; `referral-admin sweep`): the due referrals first (so their
 * sign-up rewards, due at the same time, are credited in the same run), then the due rewards, then the inviters'
 * milestones. Each item in its own transaction; bounded batches.
 */
export async function sweepReferrals(prisma: PrismaClient, now: Date, batch = 200): Promise<ReferralSweep> {
  let qualified = 0;
  let voided = 0;
  let credited = 0;
  let rewardsVoided = 0;
  let milestoneCherries = 0n;
  const inviters = new Set<string>();
  const due = await prisma.referral.findMany({
    where: { status: 'PENDING', holdUntil: { lte: now } },
    orderBy: { holdUntil: 'asc' },
    take: batch,
    select: { id: true, inviterUserId: true },
  });
  for (const r of due) {
    const result = await prisma.$transaction((tx) => settleReferralIn(tx, r.id, now));
    if (result === 'QUALIFIED') {
      qualified++;
      inviters.add(r.inviterUserId);
    } else if (result === 'VOID') voided++;
  }
  const rewards = await prisma.referralReward.findMany({
    where: { status: 'PENDING', holdUntil: { lte: now } },
    orderBy: { holdUntil: 'asc' },
    take: batch,
    select: { id: true },
  });
  for (const r of rewards) {
    const result = await prisma.$transaction((tx) => settleRewardIn(tx, r.id, now));
    if (result === 'CREDITED') credited++;
    else if (result === 'VOID') rewardsVoided++;
  }
  for (const inviter of [...inviters].sort()) {
    milestoneCherries += await prisma.$transaction((tx) => milestonesIn(tx, inviter, now));
  }
  return { qualified, voided, credited, rewardsVoided, milestoneCherries };
}

/**
 * The team approves a referral (panel: FINANCE / OWNER with the code again; CLI): a PENDING one skips its hold, a
 * REJECTED or VOID one is overruled. It becomes QUALIFIED; each of its rewards still PENDING or VOID is credited now,
 * the sign-up rewards a rejected referral never got are made at the current amounts and credited; then the inviter's
 * milestones. A QUALIFIED referral: nothing changes (`changed: false`).
 */
export async function approveReferralIn(
  tx: Tx,
  referralId: string,
  reason: string,
  now: Date,
  by: AdminVia = CLI_VIA,
): Promise<{ changed: boolean; credited: bigint }> {
  const [locked] = await tx.$queryRaw<{ status: ReferralStatus }[]>`
    SELECT status::text AS status FROM referrals WHERE id = ${referralId}::uuid FOR UPDATE`;
  if (!locked) throw new ReferralAdminError(`No referral ${referralId}.`);
  if (locked.status === 'QUALIFIED') return { changed: false, credited: 0n };
  const referral = await tx.referral.findUniqueOrThrow({ where: { id: referralId } });
  const settings = await referralSettingsIn(tx);
  await tx.referral.update({
    where: { id: referralId },
    data: {
      status: 'QUALIFIED',
      qualifiedAt: now,
      voidedAt: null,
      voidReason: null,
      decidedById: by.actorUserId,
    },
  });
  // A REVERSED reward (taken back by an earlier void) is not credited again: a new row of its kind is made.
  const all = await tx.referralReward.findMany({ where: { referralId } });
  const existing = all.filter((r) => r.status !== 'REVERSED');
  const kinds = new Set(existing.map((r) => r.kind));
  const missing: { kind: ReferralRewardKind; userId: string; cherries: bigint; base?: ReferralReward }[] = [];
  for (const old of all) {
    if (old.status !== 'REVERSED' || kinds.has(old.kind)) continue;
    kinds.add(old.kind);
    missing.push({ kind: old.kind, userId: old.userId, cherries: old.cherries, base: old });
  }
  if (!kinds.has('SIGNUP_INVITER') && settings.inviterSignupCherries > 0n) {
    missing.push({
      kind: 'SIGNUP_INVITER',
      userId: referral.inviterUserId,
      cherries: settings.inviterSignupCherries,
    });
  }
  if (!kinds.has('SIGNUP_INVITEE') && settings.inviteeSignupCherries > 0n) {
    missing.push({
      kind: 'SIGNUP_INVITEE',
      userId: referral.inviteeUserId,
      cherries: settings.inviteeSignupCherries,
    });
  }
  const toCredit: ReferralReward[] = existing.filter((r) => r.status !== 'CREDITED');
  for (const m of missing) {
    toCredit.push(
      await tx.referralReward.create({
        data: {
          id: uuidv7(),
          referralId,
          userId: m.userId,
          kind: m.kind,
          cherries: m.cherries,
          holdUntil: now,
          ...(m.base?.kind === 'FIRST_RECHARGE'
            ? {
                baseCoins: m.base.baseCoins,
                rateBps: m.base.rateBps,
                rechargeReason: m.base.rechargeReason,
                rechargeReference: m.base.rechargeReference,
              }
            : {}),
          createdAt: now,
        },
      }),
    );
  }
  let credited = 0n;
  for (const r of toCredit) {
    await creditRewardIn(tx, r, now, by);
    credited += r.cherries;
  }
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.REFERRAL_APPROVE,
      targetType: 'referral',
      targetId: referralId,
      metadata: {
        via: by.via,
        reason,
        before: locked.status,
        rejectReason: referral.rejectReason,
        voidReason: referral.voidReason,
        credited: Number(credited),
      },
    },
  });
  credited += await milestonesIn(tx, referral.inviterUserId, now);
  return { changed: true, credited };
}

/** One credited reward the claw-back takes back, and what it leaves. */
export interface ClawbackItem {
  readonly rewardId: string;
  readonly userId: string;
  readonly kind: ReferralRewardKind;
  readonly cherries: bigint;
}

/** What voiding a referral takes back (the panel shows it before the team confirms). */
export interface ClawbackPlan {
  readonly items: readonly ClawbackItem[];
  readonly cherries: bigint;
  /** Per person: the amount, the balance now and the part it does not cover (a debt). */
  readonly people: readonly { userId: string; cherries: bigint; balance: bigint; shortfall: bigint }[];
  readonly shortfall: bigint;
}

/**
 * The claw-back of voiding `referralId` (owner 2026-11-01): every reward of the referral already CREDITED (to the
 * inviter, and to the friend when `inviteeSignupCherries` > 0), plus — when the referral is QUALIFIED — each milestone
 * bonus the inviter no longer reaches without this friend (one qualified friend fewer). A VOID referral: nothing.
 */
export async function clawbackPlanIn(db: Db, referralId: string): Promise<ClawbackPlan> {
  const referral = await db.referral.findUnique({ where: { id: referralId } });
  if (!referral || referral.status === 'VOID') return { items: [], cherries: 0n, people: [], shortfall: 0n };
  const credited = await db.referralReward.findMany({
    where: { referralId, status: 'CREDITED' },
    orderBy: { createdAt: 'asc' },
  });
  const milestones =
    referral.status === 'QUALIFIED'
      ? await db.referralReward.findMany({
          where: {
            userId: referral.inviterUserId,
            kind: 'MILESTONE',
            status: 'CREDITED',
            milestoneFriends: {
              gt:
                (await db.referral.count({
                  where: { inviterUserId: referral.inviterUserId, status: 'QUALIFIED' },
                })) - 1,
            },
          },
          orderBy: { milestoneFriends: 'asc' },
        })
      : [];
  const items = [...credited, ...milestones].map((r) => ({
    rewardId: r.id,
    userId: r.userId,
    kind: r.kind,
    cherries: r.cherries,
  }));
  const perUser = new Map<string, bigint>();
  for (const i of items) perUser.set(i.userId, (perUser.get(i.userId) ?? 0n) + i.cherries);
  const ids = [...perUser.keys()].sort();
  const wallets = await db.cherryWallet.findMany({
    where: { userId: { in: ids } },
    select: { userId: true, cherries: true },
  });
  const balanceOf = new Map(wallets.map((w) => [w.userId, w.cherries]));
  const people = ids.map((userId) => {
    const cherries = perUser.get(userId)!;
    const balance = balanceOf.get(userId) ?? 0n;
    const covered = balance > 0n ? (balance < cherries ? balance : cherries) : 0n;
    return { userId, cherries, balance, shortfall: cherries - covered };
  });
  return {
    items,
    cherries: items.reduce((t, i) => t + i.cherries, 0n),
    people,
    shortfall: people.reduce((t, p) => t + p.shortfall, 0n),
  };
}

/**
 * The team voids a referral (panel: FINANCE / OWNER with the code again; CLI): its PENDING rewards are voided, and
 * the cherries already credited are taken back at once (owner 2026-11-01; `clawbackPlanIn`): each reward becomes
 * REVERSED with one `REFERRAL_REVERSAL` ledger row (reference = the reward, so never twice). A balance that does not
 * cover it goes below 0 — the shortfall is recorded on the reward and in the audit, and withdrawals are refused until
 * it is earned back. Each person who lost cherries gets `REFERRAL_REWARD_REVERSED`. A VOID referral: nothing changes.
 */
export async function voidReferralIn(
  tx: Tx,
  referralId: string,
  reason: string,
  now: Date,
  by: AdminVia = CLI_VIA,
): Promise<{ changed: boolean; voidedRewards: number; reversedCherries: bigint; shortfall: bigint }> {
  const [locked] = await tx.$queryRaw<{ status: ReferralStatus }[]>`
    SELECT status::text AS status FROM referrals WHERE id = ${referralId}::uuid FOR UPDATE`;
  if (!locked) throw new ReferralAdminError(`No referral ${referralId}.`);
  if (locked.status === 'VOID') {
    return { changed: false, voidedRewards: 0, reversedCherries: 0n, shortfall: 0n };
  }
  const plan = await clawbackPlanIn(tx, referralId);
  await tx.referral.update({
    where: { id: referralId },
    data: { status: 'VOID', voidedAt: now, voidReason: reason.slice(0, 500), decidedById: by.actorUserId },
  });
  const pending = await tx.referralReward.findMany({ where: { referralId, status: 'PENDING' } });
  for (const r of pending) await voidRewardIn(tx, r, 'REFERRAL_VOID', now, by);
  let shortfall = 0n;
  const losers = new Set<string>();
  for (const item of plan.items) {
    const back = await reverseReferralCherriesIn(tx, item.userId, item.cherries, item.rewardId, now);
    shortfall += back.shortfall;
    losers.add(item.userId);
    await tx.referralReward.update({
      where: { id: item.rewardId },
      data: { status: 'REVERSED', reversedAt: now, reversalShortfall: back.shortfall },
    });
    await tx.auditLog.create({
      data: {
        ...auditBy(by),
        action: AuditAction.REFERRAL_REWARD_REVERSE,
        targetType: 'referral_reward',
        targetId: item.rewardId,
        metadata: {
          via: by.via,
          referral: referralId,
          user: item.userId,
          kind: item.kind,
          cherries: Number(item.cherries),
          shortfall: Number(back.shortfall),
          balanceAfter: Number(back.balanceAfter),
        },
      },
    });
  }
  const notifier = new Notifier();
  for (const userId of [...losers].sort()) {
    await notifier.system(tx, { type: 'REFERRAL_REWARD_REVERSED', recipientId: userId });
  }
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.REFERRAL_VOID,
      targetType: 'referral',
      targetId: referralId,
      metadata: {
        via: by.via,
        reason,
        before: locked.status,
        voidedRewards: pending.length,
        reversedRewards: plan.items.length,
        reversedCherries: Number(plan.cherries),
        shortfall: Number(shortfall),
      },
    },
  });
  return { changed: true, voidedRewards: pending.length, reversedCherries: plan.cherries, shortfall };
}
