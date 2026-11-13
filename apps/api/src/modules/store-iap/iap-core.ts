import type { IapEnvironment, IapProduct, IapPurchase, Prisma } from '../../generated/prisma/client.js';
import { SYSTEM_VIA } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { banDevicesIn, devicesOfUserIn } from '../auth/device-bans.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { recordRechargeIn, type RechargeCreditRules } from '../recharge/recharge-badges.js';
import { referralRechargeIn } from '../referrals/referral-core.js';
import { ambassadorTopupReversedIn } from '../ambassadors/ambassador-core.js';
import { fifoAttribution } from '../topup/topup-rules.js';
import { endSessionsIn } from '../users/account-control.js';
import { creditIn, reverseStoreIapIn } from '../wallet/wallet-ledger.js';
import {
  earnRechargePointsIn,
  movePointsIn,
  reversalReference,
} from '../recharge-points/recharge-points-ledger.js';
import { consumptionPercentage, type IapPlatformName } from './iap-rules.js';

/**
 * v1.110-social (D345, CONVENTIONS §10.144): the database steps of store purchases, each inside the caller's
 * transaction. Every change writes its audit row in the same transaction; the automatic steps have no actor.
 */

type Tx = Prisma.TransactionClient;

/** `sessions.revoked_reason` of the sessions a refund ban ends. */
export const STORE_REFUND_REVOKED_REASON = 'STORE_REFUND_BANNED';
/** The most devices one refund bans (newest first): every device seen for the account in practice. */
export const STORE_REFUND_MAX_DEVICES = 100;

export interface IapSettingsView {
  readonly oncePerAccountDevice: boolean;
  readonly voidedPolledUntil: Date | null;
  readonly voidedLastRunAt: Date | null;
  readonly voidedLastError: string | null;
  readonly updatedAt: Date;
}

/** The one settings row (made when missing). */
export async function iapSettingsIn(db: Pick<Tx, 'iapSettings'>): Promise<IapSettingsView> {
  const row =
    (await db.iapSettings.findUnique({ where: { id: 1 } })) ??
    (await db.iapSettings.upsert({ where: { id: 1 }, create: { id: 1 }, update: {} }));
  return row;
}

/** Whether the once-per-account+device rule refuses another purchase (an account or a device already bought). */
export async function onceLimitReachedIn(
  tx: Pick<Tx, 'iapPurchase'>,
  userId: string,
  deviceHash: string | null,
): Promise<boolean> {
  const hit = await tx.iapPurchase.findFirst({
    where: {
      status: { in: ['CREDITED', 'REFUNDED'] },
      OR: [{ userId }, ...(deviceHash ? [{ deviceHash }] : [])],
    },
    select: { id: true },
  });
  return hit !== null;
}

export interface PurchaseFacts {
  readonly userId: string;
  readonly platform: IapPlatformName;
  readonly product: IapProduct;
  readonly transactionId: string;
  readonly originalTransactionId: string | null;
  readonly purchaseToken: string | null;
  readonly purchaseTokenHash: string | null;
  readonly environment: IapEnvironment;
  readonly deviceHash: string | null;
  readonly priceMilli: bigint | null;
  readonly currency: string | null;
  readonly purchasedAt: Date;
  readonly consent: { readonly version: string; readonly shareData: boolean; readonly locale: string | null };
  /** Not credited (the once-per-account+device rule on Google): the reason. */
  readonly reject: string | null;
  /** Credited although the once rule was hit (Apple). */
  readonly limitExceeded: boolean;
}

export interface RecordedPurchase {
  readonly purchase: IapPurchase;
  /** The balance after the credit (null when not credited). */
  readonly balance: bigint | null;
}

/**
 * Stores a verified purchase and, unless rejected, credits its coins once (`STORE_IAP`, reference: the purchase) with
 * the D187 recharge-badge and D217 first-recharge hooks. The unique keys (store + transaction, store + token hash, the
 * ledger's reason + reference) make a concurrent second verification fail and roll back.
 */
export async function recordPurchaseIn(
  tx: Tx,
  facts: PurchaseFacts,
  badges: RechargeCreditRules,
  now: Date,
): Promise<RecordedPurchase> {
  const id = uuidv7();
  const credited = facts.reject === null;
  const purchase = await tx.iapPurchase.create({
    data: {
      id,
      userId: facts.userId,
      platform: facts.platform,
      storeProductId: facts.product.id,
      productId: facts.product.productId,
      coins: facts.product.coins,
      transactionId: facts.transactionId,
      originalTransactionId: facts.originalTransactionId,
      purchaseToken: facts.purchaseToken,
      purchaseTokenHash: facts.purchaseTokenHash,
      environment: facts.environment,
      status: credited ? 'CREDITED' : 'REJECTED',
      rejectReason: facts.reject,
      deviceHash: facts.deviceHash,
      priceMilli: facts.priceMilli,
      currency: facts.currency,
      purchasedAt: facts.purchasedAt,
      creditedAt: credited ? now : null,
      consentVersion: facts.consent.version,
      consentAt: now,
      consentShareData: facts.consent.shareData,
      consentLocale: facts.consent.locale,
      createdAt: now,
      updatedAt: now,
    },
  });
  if (!credited) {
    await tx.auditLog.create({
      data: {
        actorUserId: facts.userId,
        action: AuditAction.STORE_IAP_REJECT,
        targetType: 'iap_purchase',
        targetId: id,
        metadata: { platform: facts.platform, product: facts.product.productId, reason: facts.reject },
      },
    });
    return { purchase, balance: null };
  }
  const change = await creditIn(tx, facts.userId, facts.product.coins, 'STORE_IAP', id);
  await recordRechargeIn(
    tx,
    { userId: facts.userId, coins: facts.product.coins, source: 'STORE_IAP', now },
    badges,
  );
  // v1.126-social (D370, §10.163): one recharge point per coin, once per purchase.
  await earnRechargePointsIn(tx, {
    userId: facts.userId,
    coins: facts.product.coins,
    reason: 'RECHARGE_STORE',
    referenceId: id,
  });
  await referralRechargeIn(
    tx,
    { userId: facts.userId, coins: facts.product.coins, reason: 'STORE_IAP', reference: id, now },
    badges.cherriesPerCoin,
  );
  await tx.auditLog.create({
    data: {
      actorUserId: facts.userId,
      action: AuditAction.STORE_IAP_CREDIT,
      targetType: 'iap_purchase',
      targetId: id,
      metadata: {
        platform: facts.platform,
        product: facts.product.productId,
        coins: Number(facts.product.coins),
        balance: Number(change.coins),
        environment: facts.environment,
        consentVersion: facts.consent.version,
        shareData: facts.consent.shareData,
        ...(facts.limitExceeded ? { limitExceeded: true } : {}),
      },
    },
  });
  return { purchase, balance: change.coins };
}

/** Locks and reads a purchase (the row lock serializes a refund against a consumption request or a second void). */
export async function lockPurchaseIn(tx: Tx, id: string): Promise<IapPurchase | null> {
  const rows = await tx.$queryRaw<{ id: string }[]>`
    SELECT id::text AS id FROM iap_purchases WHERE id = ${id}::uuid FOR UPDATE`;
  if (rows.length === 0) return null;
  return tx.iapPurchase.findUnique({ where: { id } });
}

/** The purchase's coins never spent (FIFO: the coins held before it go first, §10.53). */
export async function unspentOfIn(
  tx: Tx,
  purchase: IapPurchase,
): Promise<{ unspent: bigint; spends: number }> {
  const credit = await tx.walletLedgerEntry.findUnique({
    where: { reason_referenceId: { reason: 'STORE_IAP', referenceId: purchase.id } },
  });
  if (!credit) return { unspent: purchase.coins, spends: 0 };
  const later = await tx.$queryRaw<
    { id: string; reason: string; delta: bigint; reference_id: string; created_at: Date }[]
  >`
    SELECT id::text AS id, reason::text AS reason, delta, reference_id, created_at
      FROM wallet_ledger
     WHERE user_id = ${purchase.userId}::uuid AND (created_at, id) > (${credit.createdAt}, ${credit.id}::uuid)
     ORDER BY created_at, id
     LIMIT 20000`;
  const { spends, unspent } = fifoAttribution(
    credit.balanceAfter - credit.delta,
    purchase.coins,
    later.map((r) => ({
      id: r.id,
      reason: r.reason,
      delta: r.delta,
      referenceId: r.reference_id,
      createdAt: r.created_at,
    })),
  );
  return { unspent, spends: spends.length };
}

/** The consumption percentage of a purchase now (milliunits). */
export async function consumptionOfIn(tx: Tx, purchase: IapPurchase): Promise<number> {
  const { unspent } = await unspentOfIn(tx, purchase);
  return consumptionPercentage(purchase.coins, unspent);
}

export interface RefundInput {
  /** `GOOGLE_VOIDED` (the API or an RTDN-triggered poll), `APPLE_REFUND`. */
  readonly source: string;
  readonly refundedAt: Date;
  readonly reasonText: string;
  /** False for a void the team itself made (Google `voidedSource` developer): coins back, no ban. */
  readonly ban: boolean;
  readonly detail: Record<string, string | number | boolean | null>;
}

export interface RefundResult {
  readonly applied: boolean;
  readonly coins: bigint;
  readonly balance: bigint | null;
  readonly accountBanned: boolean;
  readonly devicesBanned: number;
}

/**
 * A store refund of a CREDITED purchase, once (§10.144.4): the coins back (`STORE_IAP_REVERSAL`, the balance may go
 * below 0), the purchase REFUNDED with the reason and the FIFO detail; with `ban`, the ACTIVE account SUSPENDED
 * (`suspendIn`: the live ends, seats are freed) and its sessions ended, the purchase's device and every device seen for
 * the account (sign-ups and the sessions' `device_hash` history) banned permanently, and the `iap_refund_bans` row. Anything else (already refunded, REJECTED): nothing.
 */
export async function refundPurchaseIn(
  tx: Tx,
  purchaseId: string,
  input: RefundInput,
  suspendIn: (tx: Tx, userId: string) => Promise<boolean>,
  now: Date,
): Promise<RefundResult> {
  const none: RefundResult = {
    applied: false,
    coins: 0n,
    balance: null,
    accountBanned: false,
    devicesBanned: 0,
  };
  const purchase = await lockPurchaseIn(tx, purchaseId);
  if (!purchase || purchase.status !== 'CREDITED') return none;
  const { unspent, spends } = await unspentOfIn(tx, purchase);
  const change = await reverseStoreIapIn(tx, purchase.userId, purchase.coins, purchase.id);
  // v1.141-social (D390, §10.179.5): a store refund voids or claws back the ambassador's commission on the purchase.
  await ambassadorTopupReversedIn(tx, 'STORE_IAP', purchase.id, now);
  // v1.126-social (D370, §10.163): the refunded purchase's points go too (the balance may go below 0) — only when it
  // earned some (purchases credited before the points existed earned none).
  const earned = await tx.rechargePointsEntry.findUnique({
    where: { reason_referenceId: { reason: 'RECHARGE_STORE', referenceId: purchase.id } },
    select: { delta: true },
  });
  if (earned) {
    await movePointsIn(
      tx,
      purchase.userId,
      -earned.delta,
      'REVERSAL',
      reversalReference('store', purchase.id),
    );
  }
  await tx.iapPurchase.update({
    where: { id: purchase.id },
    data: {
      status: 'REFUNDED',
      refundedAt: input.refundedAt.getTime() > 0 ? input.refundedAt : now,
      refundSource: input.source,
      refundReason: input.reasonText,
      refundDetail: {
        ...input.detail,
        unspentAtRefund: Number(unspent),
        spendsFromPurchase: spends,
        ban: input.ban,
      },
      coinsReversed: purchase.coins,
      updatedAt: now,
    },
  });
  let accountBanned = false;
  let devicesBanned = 0;
  if (input.ban) {
    accountBanned = await suspendIn(tx, purchase.userId);
    await endSessionsIn(tx, purchase.userId, STORE_REFUND_REVOKED_REASON, now);
    // Owner (int21, D345 #5): every device seen for the account — its sign-ups and its sessions' history
    // (`sessions.device_hash`, ended sessions included) — and the purchase's own device, not only the latter.
    const seen = await devicesOfUserIn(tx, purchase.userId, STORE_REFUND_MAX_DEVICES);
    const hashes = [...new Set([...(purchase.deviceHash ? [purchase.deviceHash.trim()] : []), ...seen])];
    const bans = await banDevicesIn(tx, {
      hashes,
      reason: input.reasonText,
      endsAt: null,
      sourceUserId: purchase.userId,
      iapPurchaseId: purchase.id,
      by: SYSTEM_VIA,
      now,
    });
    devicesBanned = bans.banIds.length;
    await tx.iapRefundBan.create({
      data: {
        userId: purchase.userId,
        purchaseId: purchase.id,
        reason: input.reasonText,
        accountBanned,
        devicesBanned,
        createdAt: now,
      },
    });
  }
  await tx.auditLog.create({
    data: {
      action: AuditAction.STORE_IAP_REFUND,
      targetType: 'iap_purchase',
      targetId: purchase.id,
      metadata: {
        user: purchase.userId,
        platform: purchase.platform,
        coins: Number(purchase.coins),
        balance: Number(change.coins),
        source: input.source,
        reason: input.reasonText,
        ban: input.ban,
        accountBanned,
        devicesBanned,
        via: 'system',
      },
    },
  });
  return { applied: true, coins: purchase.coins, balance: change.coins, accountBanned, devicesBanned };
}

/** Records a refund-like event that changes nothing (a void of an unknown or REJECTED purchase, Apple REFUND_DECLINED…). */
export async function recordRefundEventIn(
  tx: Tx,
  purchaseId: string | null,
  metadata: Record<string, string | number | boolean | null>,
): Promise<void> {
  await tx.auditLog.create({
    data: {
      action: AuditAction.STORE_IAP_REFUND_RECORDED,
      targetType: 'iap_purchase',
      targetId: purchaseId,
      metadata: { ...metadata, via: 'system' },
    },
  });
}
