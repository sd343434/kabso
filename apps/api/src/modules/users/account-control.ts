import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { AccountRestrictionKind, Prisma } from '../../generated/prisma/client.js';
import { dayStart } from '../recharge/recharge-rules.js';
import { MAX_COINS } from '../wallet/wallet-ledger.js';

/**
 * The account controls «تحكم كامل» (v1.72-social, D208, CONVENTIONS §10.67), shared by the admin panel, the
 * `control-admin` CLI, the enforcement points and the tests (no Nest dependencies, like `account-deletion`).
 *
 *  - **Locks and restrictions** (`account_restrictions`): LOCK refuses sign-in until `ends_at` (403 ACCOUNT_LOCKED
 *    with the end and the reason) and ends every session when it starts; CHAT_MUTE / NO_LIVE / NO_GIFTS / NO_POSTING
 *    refuse those actions (403 ACCOUNT_RESTRICTED with the kind and the end). They end by themselves at `ends_at`
 *    (no sweeper: "active" is read with the clock) or early when lifted. A new one of the same kind replaces the open
 *    one. They are separate from the permanent ban (users.status SUSPENDED, D191): a lock never changes the status,
 *    so a ban and a lock may overlap; unbanning leaves a lock running and unlocking leaves a ban in force.
 *  - **Forced password change** (`users.password_change_required_at`): the next sign-in with the right password
 *    answers 403 PASSWORD_CHANGE_REQUIRED until it sends `newPassword`.
 *  - **Balance adjustments** (`admin_balance_adjustments` + an `ADMIN_ADJUSTMENT` ledger row): never below 0 unless
 *    `allowNegative` (reversals), within the per-admin daily cap.
 *
 * Every change writes its audit row (actor, IP, `via`, reason, before / after) in the caller's transaction.
 */

type Tx = Prisma.TransactionClient;
type Db = Pick<Tx, 'accountRestriction'>;

export const RESTRICTION_KINDS = [
  'CHAT_MUTE',
  'NO_LIVE',
  'NO_GIFTS',
  'NO_POSTING',
] as const satisfies readonly AccountRestrictionKind[];
export type RestrictionKind = (typeof RESTRICTION_KINDS)[number];

/** The quick durations the panel offers (days); any end date up to {@link MAX_RESTRICTION_DAYS} is accepted too. */
export const QUICK_DAYS = [1, 3, 7, 30] as const;
export const MAX_RESTRICTION_DAYS = 365;
const DAY_MS = 86_400_000;

/** Why a control was refused (the panel answers 409 ADMIN_ACTION_REFUSED with the message; the CLI prints it). */
export class AccountControlError extends Error {
  constructor(
    readonly issue: string,
    message: string,
  ) {
    super(message);
  }
}

export interface RestrictionView {
  readonly id: string;
  readonly kind: AccountRestrictionKind;
  readonly reason: string;
  readonly startsAt: Date;
  readonly endsAt: Date;
  readonly via: string;
  readonly createdById: string | null;
  readonly liftedAt: Date | null;
  readonly liftedById: string | null;
  readonly liftReason: string | null;
  readonly createdAt: Date;
}

/** The end of a lock or restriction: `days` from now, or the given date (in the future, at most a year away). */
export function restrictionEnd(
  now: Date,
  input: { days?: number | undefined; until?: Date | undefined },
): Date {
  const end =
    input.until !== undefined
      ? input.until
      : input.days !== undefined
        ? new Date(now.getTime() + input.days * DAY_MS)
        : null;
  if (!end || Number.isNaN(end.getTime()))
    throw new AccountControlError('end', 'Give a number of days or an end date.');
  if (end.getTime() <= now.getTime()) throw new AccountControlError('end', 'The end must be in the future.');
  if (end.getTime() - now.getTime() > MAX_RESTRICTION_DAYS * DAY_MS) {
    throw new AccountControlError('end', `At most ${MAX_RESTRICTION_DAYS} days.`);
  }
  return end;
}

const ACTIVE = (now: Date) => ({ liftedAt: null, startsAt: { lte: now }, endsAt: { gt: now } });

/** The active lock or restriction of `kind`, if any (the one that ends last). */
export function activeRestrictionOf(
  db: Db,
  userId: string,
  kind: AccountRestrictionKind,
  now: Date = new Date(),
): Promise<RestrictionView | null> {
  return db.accountRestriction.findFirst({
    where: { userId, kind, ...ACTIVE(now) },
    orderBy: { endsAt: 'desc' },
  });
}

/** Every active lock and restriction of `userId`, soonest end first. */
export function activeRestrictionsOf(
  db: Db,
  userId: string,
  now: Date = new Date(),
): Promise<RestrictionView[]> {
  return db.accountRestriction.findMany({
    where: { userId, ...ACTIVE(now) },
    orderBy: [{ endsAt: 'asc' }, { id: 'asc' }],
  });
}

/**
 * The enforcement point (live chat, bullets, comments, direct messages, going live, gifts, posts, reels, stories):
 * 403 ACCOUNT_RESTRICTED `[{restriction: kind}, {until: ISO}]` while the caller has an active `kind`.
 */
export async function assertNotRestricted(
  db: Db,
  userId: string,
  kind: RestrictionKind,
  now: Date = new Date(),
): Promise<void> {
  const row = await activeRestrictionOf(db, userId, kind, now);
  if (!row) return;
  throw new AppException(ErrorCode.ACCOUNT_RESTRICTED, undefined, [
    { field: 'restriction', issue: kind },
    { field: 'until', issue: row.endsAt.toISOString() },
  ]);
}

/** Every session of `userId` ends, with its push token (the app's own revocation, inside the transaction). */
export async function endSessionsIn(tx: Tx, userId: string, reason: string, now: Date): Promise<number> {
  const result = await tx.session.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: now, revokedReason: reason },
  });
  await tx.deviceToken.deleteMany({ where: { userId } });
  return result.count;
}

/** The session revocation reasons of D208 (`sessions.revoked_reason`). */
export const LOCK_REVOKED_REASON = 'ADMIN_LOCKED';
export const PASSWORD_REVOKED_REASON = 'ADMIN_PASSWORD';

async function lockUserRow(tx: Tx, userId: string) {
  const [row] = await tx.$queryRaw<{ id: string; status: string }[]>`
    SELECT id::text AS id, status::text AS status FROM users WHERE id = ${userId}::uuid FOR UPDATE`;
  return row ?? null;
}

function view(r: RestrictionView) {
  return { id: r.id, kind: r.kind, endsAt: r.endsAt.toISOString() };
}

/**
 * Locks («قفل») or restricts `userId` until `endsAt`, inside the caller's transaction. Refused for a DELETED account
 * (a lock also for a SUSPENDED or PENDING_DELETION one: it cannot sign in anyway). An open one of the same kind is
 * replaced (lifted with «replaced»). A LOCK ends every session. The person gets an ACCOUNT_RESTRICTED notification
 * (seen after a lock ends). The caller ends a current live (NO_LIVE, LOCK) where it can (the panel).
 */
export async function restrictIn(
  tx: Tx,
  userId: string,
  kind: AccountRestrictionKind,
  endsAt: Date,
  reason: string,
  by: AdminVia,
  now: Date = new Date(),
): Promise<{ restriction: RestrictionView; replaced: RestrictionView | null; sessions: number }> {
  const user = await lockUserRow(tx, userId);
  if (!user || user.status === 'DELETED') throw new AccountControlError('not_found', 'No such account.');
  if (kind === 'LOCK' && user.status !== 'ACTIVE') {
    throw new AccountControlError('status', `The account is ${user.status}; a lock needs an ACTIVE account.`);
  }
  if (endsAt.getTime() <= now.getTime())
    throw new AccountControlError('end', 'The end must be in the future.');
  const replaced = await activeRestrictionOf(tx, userId, kind, now);
  // Any open row of this kind (active or not started) is closed: one open row per kind.
  await tx.accountRestriction.updateMany({
    where: { userId, kind, liftedAt: null, endsAt: { gt: now } },
    data: { liftedAt: now, liftedById: by.actorUserId, liftReason: 'replaced' },
  });
  const restriction = await tx.accountRestriction.create({
    data: {
      userId,
      kind,
      reason,
      startsAt: now,
      endsAt,
      createdById: by.actorUserId,
      via: by.via,
    },
  });
  const sessions = kind === 'LOCK' ? await endSessionsIn(tx, userId, LOCK_REVOKED_REASON, now) : 0;
  await tx.notification.create({
    data: {
      recipientId: userId,
      type: 'ACCOUNT_RESTRICTED',
      accountRestrictionId: restriction.id,
      createdAt: now,
      updatedAt: now,
    },
  });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: kind === 'LOCK' ? AuditAction.ADMIN_USER_LOCK : AuditAction.ADMIN_USER_RESTRICT,
      targetType: 'user',
      targetId: userId,
      metadata: {
        kind,
        reason,
        endsAt: endsAt.toISOString(),
        before: replaced ? view(replaced) : null,
        after: view(restriction),
        ...(kind === 'LOCK' ? { sessions } : {}),
        via: by.via,
      },
    },
  });
  return { restriction, replaced, sessions };
}

/**
 * Ends a lock or restriction early (unlock), inside the caller's transaction: the active one of `kind`. The person
 * gets ACCOUNT_RESTRICTION_LIFTED. Refused when none is active.
 */
export async function liftIn(
  tx: Tx,
  userId: string,
  kind: AccountRestrictionKind,
  reason: string,
  by: AdminVia,
  now: Date = new Date(),
): Promise<RestrictionView> {
  await lockUserRow(tx, userId);
  const active = await activeRestrictionOf(tx, userId, kind, now);
  if (!active) {
    throw new AccountControlError(
      'not_active',
      kind === 'LOCK' ? 'The account is not locked.' : `No active ${kind}.`,
    );
  }
  const lifted = await tx.accountRestriction.update({
    where: { id: active.id },
    data: { liftedAt: now, liftedById: by.actorUserId, liftReason: reason },
  });
  await tx.notification.create({
    data: {
      recipientId: userId,
      type: 'ACCOUNT_RESTRICTION_LIFTED',
      accountRestrictionId: lifted.id,
      createdAt: now,
      updatedAt: now,
    },
  });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: kind === 'LOCK' ? AuditAction.ADMIN_USER_UNLOCK : AuditAction.ADMIN_USER_RESTRICTION_LIFT,
      targetType: 'user',
      targetId: userId,
      metadata: {
        kind,
        reason,
        before: view(active),
        after: { ...view(lifted), liftedAt: now.toISOString() },
        via: by.via,
      },
    },
  });
  return lifted;
}

/**
 * «فرض تغيير كلمة المرور في الدخول القادم» (and the second half of a temporary password): the next sign-in must
 * choose a new password; with `endSessions` every session ends now (so that next sign-in happens).
 */
export async function requirePasswordChangeIn(
  tx: Tx,
  userId: string,
  reason: string,
  by: AdminVia,
  opts: { endSessions: boolean; passwordHash?: string; now?: Date },
): Promise<{ sessions: number; already: boolean }> {
  const now = opts.now ?? new Date();
  const user = await lockUserRow(tx, userId);
  if (!user || user.status === 'DELETED') throw new AccountControlError('not_found', 'No such account.');
  const before = await tx.user.findUniqueOrThrow({
    where: { id: userId },
    select: { passwordChangeRequiredAt: true },
  });
  await tx.user.update({
    where: { id: userId },
    data: {
      passwordChangeRequiredAt: now,
      ...(opts.passwordHash ? { passwordHash: opts.passwordHash } : {}),
    },
  });
  if (opts.passwordHash) {
    // A new password: every outstanding reset link stops working too.
    await tx.verificationToken.updateMany({
      where: { userId, purpose: 'PASSWORD_RESET', consumedAt: null },
      data: { consumedAt: now },
    });
  }
  const sessions =
    opts.endSessions || opts.passwordHash ? await endSessionsIn(tx, userId, PASSWORD_REVOKED_REASON, now) : 0;
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: opts.passwordHash
        ? AuditAction.ADMIN_PASSWORD_TEMPORARY
        : AuditAction.ADMIN_PASSWORD_REQUIRE_CHANGE,
      targetType: 'user',
      targetId: userId,
      metadata: {
        reason,
        sessions,
        before: { passwordChangeRequired: before.passwordChangeRequiredAt !== null },
        after: { passwordChangeRequired: true, passwordReplaced: opts.passwordHash !== undefined },
        via: by.via,
      },
    },
  });
  return { sessions, already: before.passwordChangeRequiredAt !== null };
}

// ---- balance adjustments ---------------------------------------------------------------------------------------

export type AdjustCurrency = 'COINS' | 'CHERRIES';

/** The most one adjustment moves (a typo guard, like `wallet-admin`). */
export const MAX_ADJUSTMENT = 1_000_000_000n;

export interface AdjustInput {
  readonly userId: string;
  readonly currency: AdjustCurrency;
  /** > 0 credit, < 0 debit. */
  readonly delta: bigint;
  readonly allowNegative: boolean;
  readonly reason: string;
  /** The per-admin daily cap of this currency (null = none, the CLI). */
  readonly dailyCap: bigint | null;
  /** The zone of the cap's day. */
  readonly zone: string;
}

export interface AdjustResult {
  readonly adjustmentId: string;
  readonly currency: AdjustCurrency;
  readonly delta: bigint;
  readonly before: bigint;
  readonly after: bigint;
  readonly usedToday: bigint;
}

/**
 * A coin or cherry credit / debit by the team, inside the caller's transaction: one `admin_balance_adjustments` row,
 * one `ADMIN_ADJUSTMENT` ledger row (reference = the adjustment), the BALANCE_ADJUSTED notification and the audit
 * row. A debit below 0 needs `allowNegative`; a balance above 2^53 − 1 is refused; the actor's adjustments of the day
 * (|delta| added up, this currency) may not pass `dailyCap` (serialized per actor with an advisory lock).
 */
export async function adjustBalanceIn(
  tx: Tx,
  input: AdjustInput,
  by: AdminVia,
  now: Date = new Date(),
): Promise<AdjustResult> {
  const { userId, currency, delta } = input;
  if (delta === 0n) throw new AccountControlError('amount', 'The amount must not be 0.');
  const amount = delta < 0n ? -delta : delta;
  if (amount > MAX_ADJUSTMENT) {
    throw new AccountControlError('amount', `At most ${MAX_ADJUSTMENT.toString()} per adjustment.`);
  }
  const user = await lockUserRow(tx, userId);
  if (!user || user.status === 'DELETED') throw new AccountControlError('not_found', 'No such account.');
  let usedToday = 0n;
  if (input.dailyCap !== null) {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:admin-adjust'), hashtext(${by.actorUserId ?? 'cli'}))`;
    const since = dayStart(now, input.zone);
    const [row] = await tx.$queryRaw<{ used: bigint | null }[]>`
      SELECT sum(abs(delta))::bigint AS used FROM admin_balance_adjustments
       WHERE actor_user_id IS NOT DISTINCT FROM ${by.actorUserId}::uuid AND currency = ${currency}
         AND created_at >= ${since}::timestamptz`;
    usedToday = row?.used ?? 0n;
  }
  // The balance row, created at 0 on first use and locked.
  if (currency === 'COINS') {
    await tx.$executeRaw`INSERT INTO wallets (user_id, coins, updated_at) VALUES (${userId}::uuid, 0, now())
      ON CONFLICT (user_id) DO NOTHING`;
  } else {
    await tx.$executeRaw`INSERT INTO cherry_wallets (user_id, cherries, updated_at) VALUES (${userId}::uuid, 0, now())
      ON CONFLICT (user_id) DO NOTHING`;
  }
  const [locked] =
    currency === 'COINS'
      ? await tx.$queryRaw<
          { v: bigint }[]
        >`SELECT coins AS v FROM wallets WHERE user_id = ${userId}::uuid FOR UPDATE`
      : await tx.$queryRaw<
          { v: bigint }[]
        >`SELECT cherries AS v FROM cherry_wallets WHERE user_id = ${userId}::uuid FOR UPDATE`;
  const before = locked!.v;
  const after = before + delta;
  if (after < 0n && !input.allowNegative) {
    throw new AccountControlError(
      'negative',
      `The balance is ${before.toString()}; a debit of ${amount.toString()} would make it negative.`,
    );
  }
  if (input.dailyCap !== null && usedToday + amount > input.dailyCap) {
    throw new AccountControlError(
      'daily_cap',
      `Your daily cap for ${currency.toLowerCase()} is ${input.dailyCap.toString()}; ` +
        `${usedToday.toString()} already used today.`,
    );
  }
  if (after > MAX_COINS) throw new AccountControlError('amount', 'The balance would exceed 2^53 − 1.');
  const adjustment = await tx.adminBalanceAdjustment.create({
    data: {
      userId,
      actorUserId: by.actorUserId,
      currency,
      delta,
      balanceBefore: before,
      balanceAfter: after,
      allowNegative: input.allowNegative,
      reason: input.reason,
      via: by.via,
      createdAt: now,
    },
    select: { id: true },
  });
  if (currency === 'COINS') {
    await tx.$executeRaw`UPDATE wallets SET coins = ${after}, updated_at = now() WHERE user_id = ${userId}::uuid`;
    await tx.walletLedgerEntry.create({
      data: {
        userId,
        delta,
        balanceAfter: after,
        reason: 'ADMIN_ADJUSTMENT',
        referenceId: adjustment.id,
        createdAt: now,
      },
    });
  } else {
    await tx.$executeRaw`UPDATE cherry_wallets SET cherries = ${after}, updated_at = now() WHERE user_id = ${userId}::uuid`;
    await tx.cherryLedgerEntry.create({
      data: {
        userId,
        delta,
        balanceAfter: after,
        reason: 'ADMIN_ADJUSTMENT',
        referenceId: adjustment.id,
        createdAt: now,
      },
    });
  }
  await tx.notification.create({
    data: {
      recipientId: userId,
      type: 'BALANCE_ADJUSTED',
      balanceAdjustmentId: adjustment.id,
      createdAt: now,
      updatedAt: now,
    },
  });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.ADMIN_BALANCE_ADJUST,
      targetType: 'user',
      targetId: userId,
      metadata: {
        currency,
        delta: delta.toString(),
        before: before.toString(),
        after: after.toString(),
        allowNegative: input.allowNegative,
        adjustmentId: adjustment.id,
        reason: input.reason,
        via: by.via,
      },
    },
  });
  return { adjustmentId: adjustment.id, currency, delta, before, after, usedToday: usedToday + amount };
}
