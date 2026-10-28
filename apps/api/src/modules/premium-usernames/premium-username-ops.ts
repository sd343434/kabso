/**
 * The premium-username operations that write (D146, CONVENTIONS §10.32), shared by the API and the
 * `premium-admin` CLI. No Nest dependencies: every function works inside the caller's transaction.
 */
import { randomInt } from 'node:crypto';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { isValidUsername } from '../users/username.js';
import { isCodeReservedPremium, premiumTierOf, type PremiumTier } from './premium-username-rules.js';

type Db = Prisma.TransactionClient;

export const DAY_MS = 24 * 3600_000;

/** What a username is for the caller (`PremiumUsernameStatus.status`). */
export type PremiumNameState =
  | 'AVAILABLE'
  | 'NOT_FOR_SALE'
  | 'TAKEN'
  | 'HELD'
  | 'YOURS'
  | 'YOURS_GRACE'
  | 'RESERVED'
  | 'REGULAR'
  | 'INVALID';

export interface PremiumNameInfo {
  readonly username: string;
  readonly tier: PremiumTier | null;
  readonly state: PremiumNameState;
  /** The monthly price now (AVAILABLE, YOURS, YOURS_GRACE), else null. */
  readonly priceCoins: bigint | null;
  /** HELD / YOURS_GRACE: when the grace period ends. */
  readonly heldUntil: Date | null;
  /** The lease holding the name (ACTIVE or GRACE), if any. */
  readonly lease: LeaseRow | null;
}

export interface LeaseRow {
  id: string;
  userId: string;
  username: string;
  tier: PremiumTier;
  source: 'RENT' | 'GRANT';
  status: 'ACTIVE' | 'GRACE' | 'ENDED';
  regularUsername: string;
  startedAt: Date;
  expiresAt: Date | null;
  graceUntil: Date | null;
  remindedDays: number | null;
}

/** Serializes every write about one name (rent, grant, change) across instances. */
export async function lockName(tx: Db, name: string): Promise<void> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:premium-name'), hashtext(${name}))`;
}

/** Serializes every premium write of one user. */
export async function lockUser(tx: Db, userId: string): Promise<void> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:premium-user'), hashtext(${userId}))`;
}

/** True when the owner's list or the code reserves `name` (never rented). */
export async function isReservedPremium(db: Db, name: string): Promise<boolean> {
  if (isCodeReservedPremium(name)) return true;
  return (await db.premiumUsernameReserved.count({ where: { name } })) > 0;
}

/** The monthly price of `name` now: its own price, else its tier's; null when not on sale. */
export async function priceOf(db: Db, name: string, tier: PremiumTier): Promise<bigint | null> {
  const own = await db.premiumUsernameNamePrice.findUnique({ where: { username: name } });
  if (own) return own.monthlyCoins;
  const byTier = await db.premiumUsernameTierPrice.findUnique({ where: { tier } });
  return byTier?.monthlyCoins ?? null;
}

/** The lease that holds `name` now (ACTIVE or GRACE), if any. */
export async function holdingLease(db: Db, name: string): Promise<LeaseRow | null> {
  return db.premiumUsernameLease.findFirst({
    where: { username: name, status: { in: ['ACTIVE', 'GRACE'] } },
  });
}

/** The caller's ACTIVE lease, if any. */
export async function activeLeaseOf(db: Db, userId: string): Promise<LeaseRow | null> {
  return db.premiumUsernameLease.findFirst({ where: { userId, status: 'ACTIVE' } });
}

/**
 * True when another account uses `name`, a live pending registration holds it, or it is the
 * regular username an ACTIVE lease keeps for its renter (except `exceptUserId`'s own).
 */
export async function nameInUse(
  db: Db,
  name: string,
  exceptUserId: string | null,
  now: Date,
): Promise<boolean> {
  const [profiles, pending, held] = await Promise.all([
    db.userProfile.count({
      where: { username: name, ...(exceptUserId ? { userId: { not: exceptUserId } } : {}) },
    }),
    db.pendingRegistration.count({ where: { username: name, expiresAt: { gt: now } } }),
    db.premiumUsernameLease.count({
      where: {
        regularUsername: name,
        status: 'ACTIVE',
        ...(exceptUserId ? { userId: { not: exceptUserId } } : {}),
      },
    }),
  ]);
  return profiles + pending + held > 0;
}

/**
 * What `name` is for `callerId` (null: nobody signed in). Order: INVALID / REGULAR (not a premium
 * shape) → the holding lease (YOURS, YOURS_GRACE, TAKEN, HELD) → RESERVED → TAKEN (another account,
 * a pending registration or a held regular name) → NOT_FOR_SALE (no price) → AVAILABLE.
 */
export async function nameInfo(
  db: Db,
  name: string,
  callerId: string | null,
  now: Date,
): Promise<PremiumNameInfo> {
  const base = { username: name, priceCoins: null, heldUntil: null, lease: null };
  if (!isValidUsername(name)) return { ...base, tier: null, state: 'INVALID' };
  const tier = premiumTierOf(name);
  if (tier === null) return { ...base, tier: null, state: 'REGULAR' };
  const lease = await holdingLease(db, name);
  if (lease) {
    const mine = callerId !== null && lease.userId === callerId;
    if (lease.status === 'ACTIVE') {
      return mine
        ? { ...base, tier, lease, state: 'YOURS', priceCoins: await priceOf(db, name, tier) }
        : { ...base, tier, lease, state: 'TAKEN' };
    }
    return mine
      ? {
          ...base,
          tier,
          lease,
          state: 'YOURS_GRACE',
          heldUntil: lease.graceUntil,
          priceCoins: await priceOf(db, name, tier),
        }
      : { ...base, tier, lease, state: 'HELD', heldUntil: lease.graceUntil };
  }
  if (await isReservedPremium(db, name)) return { ...base, tier, state: 'RESERVED' };
  if (await nameInUse(db, name, null, now)) return { ...base, tier, state: 'TAKEN' };
  const price = await priceOf(db, name, tier);
  return price === null
    ? { ...base, tier, state: 'NOT_FOR_SALE' }
    : { ...base, tier, state: 'AVAILABLE', priceCoins: price };
}

/**
 * Sets the user's public username (and the denormalised badge tier) inside the caller's
 * transaction. Returns false when another account took `username` meanwhile.
 */
async function setProfileName(
  tx: Db,
  userId: string,
  username: string,
  tier: PremiumTier | null,
): Promise<boolean> {
  const taken = await tx.userProfile.count({ where: { username, userId: { not: userId } } });
  if (taken > 0) return false;
  await tx.userProfile.update({ where: { userId }, data: { username, premiumTier: tier } });
  return true;
}

/**
 * Puts the user back on `lease.regularUsername` (the username they had before). Should another
 * account have taken it (it is held while the lease is ACTIVE, so only a race can do this), a free
 * variant `<name><4 digits>` is used and returned.
 */
export async function revertProfileIn(
  tx: Db,
  lease: Pick<LeaseRow, 'userId' | 'username' | 'regularUsername'>,
): Promise<string> {
  const profile = await tx.userProfile.findUnique({
    where: { userId: lease.userId },
    select: { username: true },
  });
  // The user is not on the premium name any more (an admin changed it): leave it, clear the badge.
  if (!profile || profile.username !== lease.username) {
    if (profile)
      await tx.userProfile.update({ where: { userId: lease.userId }, data: { premiumTier: null } });
    return profile?.username ?? lease.regularUsername;
  }
  if (await setProfileName(tx, lease.userId, lease.regularUsername, null)) return lease.regularUsername;
  const stem = lease.regularUsername.slice(0, 25).replace(/[._]+$/, '');
  for (let i = 0; i < 20; i += 1) {
    const candidate = `${stem}${String(randomInt(1000, 10000))}`;
    if (await setProfileName(tx, lease.userId, candidate, null)) return candidate;
  }
  throw new Error(`No free username to revert user ${lease.userId} to`);
}

/** Puts the user on the lease's premium name. False when another account holds it. */
export function applyPremiumIn(
  tx: Db,
  userId: string,
  username: string,
  tier: PremiumTier,
): Promise<boolean> {
  return setProfileName(tx, userId, username, tier);
}

/**
 * Ends a lease now (RELEASED by its holder, REVOKED by an admin, GRACE_OVER by the sweeper): an
 * ACTIVE one puts its user back on the regular username first. The name returns to the pool.
 */
export async function endLeaseIn(
  tx: Db,
  lease: LeaseRow,
  reason: 'RELEASED' | 'REVOKED' | 'GRACE_OVER',
  now: Date,
  actorUserId: string | null,
  via: 'api' | 'cli' | 'sweeper',
): Promise<{ revertedTo: string | null }> {
  const revertedTo = lease.status === 'ACTIVE' ? await revertProfileIn(tx, lease) : null;
  await tx.premiumUsernameLease.update({
    where: { id: lease.id },
    data: { status: 'ENDED', endedAt: now, endReason: reason, graceUntil: null, updatedAt: now },
  });
  await tx.auditLog.create({
    data: {
      action:
        reason === 'REVOKED'
          ? AuditAction.PREMIUM_USERNAME_REVOKE
          : reason === 'RELEASED'
            ? AuditAction.PREMIUM_USERNAME_RELEASE
            : AuditAction.PREMIUM_USERNAME_GRACE_END,
      actorUserId,
      targetType: 'user',
      targetId: lease.userId,
      metadata: {
        leaseId: lease.id,
        username: lease.username,
        tier: lease.tier,
        previousStatus: lease.status,
        revertedTo,
        via,
      },
    },
  });
  return { revertedTo };
}

/**
 * Admin grant (`premium-admin grant`): `username` becomes the user's username until `expiresAt`
 * (null: no end), with no charge. Refuses a name held by another user or used by another account;
 * an ACTIVE lease of the same user for another name is ended first only with `replace`.
 */
export async function grantIn(
  tx: Db,
  input: { userId: string; username: string; expiresAt: Date | null; replace: boolean; now: Date },
): Promise<{ ok: true; lease: LeaseRow } | { ok: false; reason: string }> {
  const { userId, username, now } = input;
  const tier = premiumTierOf(username);
  if (tier === null)
    return { ok: false, reason: `${username} is not a premium username (use a regular change).` };
  await lockName(tx, username);
  await lockUser(tx, userId);
  const holder = await holdingLease(tx, username);
  if (holder && holder.userId !== userId) {
    return {
      ok: false,
      reason: `${username} is ${holder.status === 'ACTIVE' ? 'rented by' : 'held for'} another user.`,
    };
  }
  if (await nameInUse(tx, username, userId, now))
    return { ok: false, reason: `${username} is used by another account.` };
  const active = await activeLeaseOf(tx, userId);
  if (active && active.username !== username) {
    if (!input.replace)
      return { ok: false, reason: `The user already has @${active.username}; pass --replace.` };
    await endLeaseIn(tx, active, 'REVOKED', now, null, 'cli');
  }
  const profile = await tx.userProfile.findUniqueOrThrow({ where: { userId }, select: { username: true } });
  let lease: LeaseRow;
  if (holder) {
    // The user's own lease (ACTIVE: change its end; GRACE: back to ACTIVE).
    const regular = holder.status === 'ACTIVE' ? holder.regularUsername : profile.username;
    lease = await tx.premiumUsernameLease.update({
      where: { id: holder.id },
      data: {
        status: 'ACTIVE',
        source: 'GRANT',
        expiresAt: input.expiresAt,
        graceUntil: null,
        remindedDays: null,
        regularUsername: regular,
        updatedAt: now,
      },
    });
  } else {
    lease = await tx.premiumUsernameLease.create({
      data: {
        userId,
        username,
        tier,
        source: 'GRANT',
        status: 'ACTIVE',
        regularUsername: active && active.username !== username ? active.regularUsername : profile.username,
        startedAt: now,
        expiresAt: input.expiresAt,
      },
    });
  }
  if (!(await applyPremiumIn(tx, userId, username, tier)))
    return { ok: false, reason: `${username} is used by another account.` };
  await tx.auditLog.create({
    data: {
      action: AuditAction.PREMIUM_USERNAME_GRANT,
      targetType: 'user',
      targetId: userId,
      metadata: {
        leaseId: lease.id,
        username,
        tier,
        expiresAt: input.expiresAt?.toISOString() ?? null,
        regularUsername: lease.regularUsername,
        via: 'cli',
      },
    },
  });
  return { ok: true, lease };
}
