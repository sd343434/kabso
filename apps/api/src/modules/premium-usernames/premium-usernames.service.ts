import { createHash } from 'node:crypto';
import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { Notifier } from '../notifications/notifier.js';
import { activeSpecialOf } from '../users/special-usernames.js';
import { isReservedUsername, normalizeUsername } from '../users/username.js';
import { UsersService, violatedUniqueIndex, type MeDto } from '../users/users.service.js';
import { debitIn } from '../wallet/wallet-ledger.js';
import {
  activeLeaseOf,
  applyPremiumIn,
  DAY_MS,
  endLeaseIn,
  lockName,
  lockUser,
  nameInfo,
  nameInUse,
  revertProfileIn,
  type LeaseRow,
  type PremiumNameInfo,
  type PremiumNameState,
} from './premium-username-ops.js';
import {
  PREMIUM_TIERS,
  premiumTierOf,
  regularUsernameIssue,
  suggestionCandidates,
  type PremiumTier,
} from './premium-username-rules.js';

type Tx = Prisma.TransactionClient;

/** An Idempotency-Key is remembered for 24 hours (§3, like posts). */
const IDEMPOTENCY_MS = 24 * 3600_000;
const SWEEP_BATCH = 200;
const MAX_SUGGESTIONS = 30;

// ---- Response shapes (openapi v1.28-live, D146) -------------------------------------------------

/** `PremiumUsernameStatus`. */
export interface PremiumUsernameStatusDto {
  username: string;
  tier: PremiumTier | null;
  status: PremiumNameState;
  priceCoins: number | null;
  periodDays: number;
  heldUntil: string | null;
}

/** `PremiumUsernameStore`. */
export interface PremiumUsernameStoreDto {
  periodDays: number;
  graceDays: number;
  tiers: { tier: PremiumTier; priceCoins: number | null }[];
  suggestions: PremiumUsernameStatusDto[];
}

/** `MyPremiumUsername`. */
export interface MyPremiumUsernameDto {
  username: string;
  tier: PremiumTier;
  status: 'ACTIVE' | 'GRACE';
  source: 'RENT' | 'GRANT';
  startedAt: string;
  expiresAt: string | null;
  graceUntil: string | null;
  regularUsername: string;
  renewPriceCoins: number | null;
  canRenew: boolean;
  periodDays: number;
}

/** `PremiumUsernameRental` (201 / replay 200). */
export interface PremiumUsernameRentalDto {
  premium: MyPremiumUsernameDto;
  coins: number;
}

export const rentSchema = z.strictObject({
  username: z.string().min(1).max(64),
  priceCoins: z.number().int().min(1).max(Number.MAX_SAFE_INTEGER),
});

export const changeUsernameSchema = z.strictObject({ username: z.string().min(1).max(64) });

export const storeQuerySchema = z.strictObject({
  tier: z.enum(['LEGEND', 'RUBY', 'GOLD', 'SILVER']).optional(),
});

function unavailable(): AppException {
  return new AppException(ErrorCode.PREMIUM_USERNAME_UNAVAILABLE);
}

/**
 * Premium usernames (يوزر مميز, owner D146, CONVENTIONS §10.32): monthly rental with coins, admin
 * grants (CLI), expiry with a grace period, and the new rule for regular usernames
 * (`PUT /me/username`). Owns `premium_username_*`; writes `user_profiles.username` /
 * `premium_tier` (documented exception, §8).
 */
@Injectable()
export class PremiumUsernamesService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PremiumUsernamesService.name);
  private sweepTimer: NodeJS.Timeout | undefined;
  private sweepInFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly notifier: Notifier,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private get rules(): AppConfig['premiumUsernames'] {
    return this.config.premiumUsernames;
  }

  onModuleInit(): void {
    if (this.rules.sweepIntervalSeconds > 0) this.scheduleSweep();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.sweepTimer) clearTimeout(this.sweepTimer);
    await this.sweepInFlight?.catch(() => undefined);
  }

  // ---- Reads ------------------------------------------------------------------------------------

  private toStatus(info: PremiumNameInfo): PremiumUsernameStatusDto {
    return {
      username: info.username,
      tier: info.tier,
      status: info.state,
      priceCoins: info.priceCoins === null ? null : Number(info.priceCoins),
      periodDays: this.rules.periodDays,
      heldUntil: info.heldUntil?.toISOString() ?? null,
    };
  }

  /** `GET /premium-usernames/{username}`: what that name is for the caller (never 404). */
  async status(callerId: string, raw: string): Promise<PremiumUsernameStatusDto> {
    const name = normalizeUsername(raw).replace(/^@/, '');
    return this.toStatus(await nameInfo(this.prisma, name, callerId, this.clock.now()));
  }

  /**
   * `GET /premium-usernames[?tier=]`: the tiers with their prices and up to 30 suggested names
   * that are AVAILABLE now (only tiers or names with a price; none while nothing is priced).
   */
  async store(callerId: string, tier: PremiumTier | undefined): Promise<PremiumUsernameStoreDto> {
    const prices = await this.prisma.premiumUsernameTierPrice.findMany();
    const byTier = new Map(prices.map((p) => [p.tier, p.monthlyCoins]));
    const tiers = PREMIUM_TIERS.map((t) => ({
      tier: t,
      priceCoins: byTier.has(t) ? Number(byTier.get(t)) : null,
    }));
    const named = await this.prisma.premiumUsernameNamePrice.findMany({ select: { username: true } });
    const candidates = [
      ...named.map((n) => n.username),
      ...suggestionCandidates().filter((n) => byTier.has(premiumTierOf(n)!)),
    ].filter((n, i, all) => all.indexOf(n) === i && (tier === undefined || premiumTierOf(n) === tier));
    // One query each for the names in use, held or reserved, then the price per name.
    const now = this.clock.now();
    const [profiles, leases, reserved, pending] = await Promise.all([
      this.prisma.userProfile.findMany({
        where: { username: { in: candidates } },
        select: { username: true },
      }),
      this.prisma.premiumUsernameLease.findMany({
        where: {
          OR: [
            { username: { in: candidates }, status: { in: ['ACTIVE', 'GRACE'] } },
            { regularUsername: { in: candidates }, status: 'ACTIVE' },
          ],
        },
        select: { username: true, regularUsername: true, status: true },
      }),
      this.prisma.premiumUsernameReserved.findMany({
        where: { name: { in: candidates } },
        select: { name: true },
      }),
      this.prisma.pendingRegistration.findMany({
        where: { username: { in: candidates }, expiresAt: { gt: now } },
        select: { username: true },
      }),
    ]);
    const busy = new Set<string>([
      ...profiles.map((p) => p.username),
      ...leases.flatMap((l) => [l.username, ...(l.status === 'ACTIVE' ? [l.regularUsername] : [])]),
      ...reserved.map((r) => r.name),
      ...pending.map((p) => p.username),
    ]);
    const suggestions: PremiumUsernameStatusDto[] = [];
    for (const name of candidates) {
      if (suggestions.length >= MAX_SUGGESTIONS) break;
      if (busy.has(name)) continue;
      const info = await nameInfo(this.prisma, name, callerId, now);
      if (info.state === 'AVAILABLE') suggestions.push(this.toStatus(info));
    }
    return { periodDays: this.rules.periodDays, graceDays: this.rules.graceDays, tiers, suggestions };
  }

  private async toMine(db: Tx, lease: LeaseRow, now: Date): Promise<MyPremiumUsernameDto> {
    const info = await nameInfo(db, lease.username, lease.userId, now);
    const price = info.state === 'YOURS' || info.state === 'YOURS_GRACE' ? info.priceCoins : null;
    return {
      username: lease.username,
      tier: lease.tier,
      status: lease.status === 'GRACE' ? 'GRACE' : 'ACTIVE',
      source: lease.source,
      startedAt: lease.startedAt.toISOString(),
      expiresAt: lease.expiresAt?.toISOString() ?? null,
      graceUntil: lease.status === 'GRACE' ? (lease.graceUntil?.toISOString() ?? null) : null,
      regularUsername: lease.regularUsername,
      renewPriceCoins: price === null ? null : Number(price),
      canRenew: price !== null && this.renewable(lease, now),
      periodDays: this.rules.periodDays,
    };
  }

  /** A renewal keeps the end within the prepaid limit; a grant without an end is not renewed. */
  private renewable(lease: LeaseRow, now: Date): boolean {
    if (lease.status === 'GRACE') return true;
    if (lease.expiresAt === null) return false;
    const next = lease.expiresAt.getTime() + this.rules.periodDays * DAY_MS;
    return next - now.getTime() <= this.rules.maxPrepaidDays * DAY_MS;
  }

  /**
   * `GET /me/premium-username`: the caller's ACTIVE premium username, else the one in its grace
   * period (the newest), else null.
   */
  async mine(callerId: string): Promise<{ premium: MyPremiumUsernameDto | null }> {
    const now = this.clock.now();
    const lease = (await this.prisma.premiumUsernameLease.findFirst({
      where: { userId: callerId, status: { in: ['ACTIVE', 'GRACE'] } },
      orderBy: [{ status: 'asc' }, { updatedAt: 'desc' }],
    })) as LeaseRow | null;
    return { premium: lease ? await this.toMine(this.prisma, lease, now) : null };
  }

  // ---- Rent and renew ---------------------------------------------------------------------------

  /**
   * `POST /me/premium-username/rentals` (`Idempotency-Key` required, validated by the controller).
   * Rents an AVAILABLE name, renews the caller's own (ACTIVE: the end moves by one period; GRACE:
   * a new period from now and the name is the caller's username again). One transaction: the name
   * and the user are locked, the price must still be `priceCoins`, the coins are taken
   * (`PREMIUM_USERNAME_RENT` / `_RENEW`), the lease, the username and the audit row are written.
   */
  async rent(
    callerId: string,
    idempotencyKey: string,
    body: unknown,
  ): Promise<{ replay: boolean; result: PremiumUsernameRentalDto }> {
    const parsed = rentSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const name = normalizeUsername(parsed.data.username).replace(/^@/, '');
    const key = idempotencyKey.toLowerCase();
    const requestHash = createHash('sha256')
      .update(`${name}\n${String(parsed.data.priceCoins)}`)
      .digest('hex');

    const replay = await this.findReplay(callerId, key, requestHash);
    if (replay) return { replay: true, result: replay };

    try {
      const result = await this.prisma.$transaction(async (tx) => {
        if (!(await this.users.lockActiveById(tx, callerId)))
          throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
        await lockUser(tx, callerId);
        await lockName(tx, name);
        const now = this.clock.now();
        await tx.premiumUsernamePayment.updateMany({
          where: {
            userId: callerId,
            idempotencyKey: key,
            createdAt: { lt: new Date(now.getTime() - IDEMPOTENCY_MS) },
          },
          data: { idempotencyKey: null, requestHash: null },
        });
        // v1.54-social (D185): a locked special username stays until it ends.
        if (await activeSpecialOf(tx, callerId)) throw new AppException(ErrorCode.USERNAME_LOCKED);
        const info = await nameInfo(tx, name, callerId, now);
        const price = BigInt(parsed.data.priceCoins);
        switch (info.state) {
          case 'AVAILABLE':
            return this.rentNewIn(tx, callerId, info, price, key, requestHash, now);
          case 'YOURS':
          case 'YOURS_GRACE':
            return this.renewIn(tx, callerId, info, price, key, requestHash, now);
          default:
            throw unavailable();
        }
      });
      return { replay: false, result };
    } catch (err) {
      if (violatedUniqueIndex(err) !== null) {
        // The same key won a race: replay it. Otherwise another user took the name first.
        const raced = await this.findReplay(callerId, key, requestHash);
        if (raced) return { replay: true, result: raced };
        throw unavailable();
      }
      throw err;
    }
  }

  private async findReplay(
    userId: string,
    key: string,
    requestHash: string,
  ): Promise<PremiumUsernameRentalDto | null> {
    const payment = await this.prisma.premiumUsernamePayment.findFirst({
      where: {
        userId,
        idempotencyKey: key,
        createdAt: { gte: new Date(this.clock.now().getTime() - IDEMPOTENCY_MS) },
      },
      include: { lease: true },
    });
    if (!payment) return null;
    if (payment.requestHash !== requestHash) throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
    return {
      premium: await this.toMine(this.prisma, payment.lease, this.clock.now()),
      coins: Number(payment.coinsAfter),
    };
  }

  private checkPrice(info: PremiumNameInfo, price: bigint): void {
    if (info.priceCoins === null) throw unavailable();
    if (info.priceCoins !== price) throw new AppException(ErrorCode.PREMIUM_USERNAME_PRICE_CHANGED);
  }

  private async rentNewIn(
    tx: Tx,
    userId: string,
    info: PremiumNameInfo,
    price: bigint,
    key: string,
    requestHash: string,
    now: Date,
  ): Promise<PremiumUsernameRentalDto> {
    if (await activeLeaseOf(tx, userId)) throw new AppException(ErrorCode.PREMIUM_USERNAME_ACTIVE);
    this.checkPrice(info, price);
    const tier = info.tier!;
    const profile = await tx.userProfile.findUniqueOrThrow({ where: { userId }, select: { username: true } });
    const lease = (await tx.premiumUsernameLease.create({
      data: {
        userId,
        username: info.username,
        tier,
        source: 'RENT',
        status: 'ACTIVE',
        regularUsername: profile.username,
        startedAt: now,
        expiresAt: new Date(now.getTime() + this.rules.periodDays * DAY_MS),
      },
    })) as LeaseRow;
    return this.chargeIn(tx, userId, lease, 'RENT', price, key, requestHash, now, async () => {
      if (!(await applyPremiumIn(tx, userId, info.username, tier))) throw unavailable();
    });
  }

  private async renewIn(
    tx: Tx,
    userId: string,
    info: PremiumNameInfo,
    price: bigint,
    key: string,
    requestHash: string,
    now: Date,
  ): Promise<PremiumUsernameRentalDto> {
    const old = info.lease!;
    if (!this.renewable(old, now)) throw unavailable();
    this.checkPrice(info, price);
    const period = this.rules.periodDays * DAY_MS;
    let lease: LeaseRow;
    if (old.status === 'ACTIVE') {
      lease = await tx.premiumUsernameLease.update({
        where: { id: old.id },
        data: {
          expiresAt: new Date(old.expiresAt!.getTime() + period),
          remindedDays: null,
          source: 'RENT',
          updatedAt: now,
        },
      });
      return this.chargeIn(tx, userId, lease, 'RENEW', price, key, requestHash, now, () => Promise.resolve());
    }
    // GRACE: the caller is on a regular username again; another premium name must not be active.
    if (await activeLeaseOf(tx, userId)) throw new AppException(ErrorCode.PREMIUM_USERNAME_ACTIVE);
    const profile = await tx.userProfile.findUniqueOrThrow({ where: { userId }, select: { username: true } });
    lease = await tx.premiumUsernameLease.update({
      where: { id: old.id },
      data: {
        status: 'ACTIVE',
        source: 'RENT',
        regularUsername: profile.username,
        expiresAt: new Date(now.getTime() + period),
        graceUntil: null,
        remindedDays: null,
        updatedAt: now,
      },
    });
    return this.chargeIn(tx, userId, lease, 'RENEW', price, key, requestHash, now, async () => {
      if (!(await applyPremiumIn(tx, userId, old.username, old.tier))) throw unavailable();
    });
  }

  /** Takes the coins, writes the payment and the audit row, then `apply` (the username). */
  private async chargeIn(
    tx: Tx,
    userId: string,
    lease: LeaseRow,
    kind: 'RENT' | 'RENEW',
    price: bigint,
    key: string,
    requestHash: string,
    now: Date,
    apply: () => Promise<void>,
  ): Promise<PremiumUsernameRentalDto> {
    const payment = await tx.premiumUsernamePayment.create({
      data: {
        userId,
        leaseId: lease.id,
        kind,
        username: lease.username,
        priceCoins: price,
        periodDays: this.rules.periodDays,
        idempotencyKey: key,
        requestHash,
        coinsAfter: 0n,
      },
    });
    const change = await debitIn(
      tx,
      userId,
      price,
      kind === 'RENT' ? 'PREMIUM_USERNAME_RENT' : 'PREMIUM_USERNAME_RENEW',
      payment.id,
    );
    if (!change) throw new AppException(ErrorCode.INSUFFICIENT_COINS);
    await tx.premiumUsernamePayment.update({ where: { id: payment.id }, data: { coinsAfter: change.coins } });
    await apply();
    await tx.auditLog.create({
      data: {
        action: kind === 'RENT' ? AuditAction.PREMIUM_USERNAME_RENT : AuditAction.PREMIUM_USERNAME_RENEW,
        actorUserId: userId,
        targetType: 'user',
        targetId: userId,
        metadata: {
          leaseId: lease.id,
          paymentId: payment.id,
          username: lease.username,
          tier: lease.tier,
          priceCoins: Number(price),
          expiresAt: lease.expiresAt?.toISOString() ?? null,
          regularUsername: lease.regularUsername,
          via: 'api',
        },
      },
    });
    return { premium: await this.toMine(tx, lease, now), coins: Number(change.coins) };
  }

  // ---- Release and the regular username ----------------------------------------------------------

  /** `DELETE /me/premium-username`: ends the caller's ACTIVE one now (no refund). Idempotent. */
  async release(callerId: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await lockUser(tx, callerId);
      const lease = await activeLeaseOf(tx, callerId);
      if (!lease) return;
      await lockName(tx, lease.username);
      await endLeaseIn(tx, lease, 'RELEASED', this.clock.now(), callerId, 'api');
    });
  }

  /**
   * `PUT /me/username`: a new regular username (the D146 rule). Order: 400 body and rule
   * (`premium` for a premium name: the app offers to rent it) → 409 `USERNAME_LOCKED` while a special
   * username is active (v1.54-social, D185) → 409 `PREMIUM_USERNAME_ACTIVE`
   * while a premium username is the caller's → 409 `USERNAME_TAKEN` (reserved, taken, pending or
   * held). The same name as now → 200, nothing changed.
   */
  async changeUsername(callerId: string, body: unknown): Promise<MeDto> {
    const parsed = changeUsernameSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const name = parsed.data.username;
    // Like registration: the name is sent canonical (lower case, trimmed); nothing is normalized.
    const issue = regularUsernameIssue(name);
    if (issue) throw AppException.validation([{ field: 'username', issue }]);
    const changed = await this.prisma
      .$transaction(async (tx) => {
        if (!(await this.users.lockActiveById(tx, callerId)))
          throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
        await lockUser(tx, callerId);
        await lockName(tx, name);
        const profile = await tx.userProfile.findUniqueOrThrow({
          where: { userId: callerId },
          select: { username: true },
        });
        if (profile.username === name) return false;
        if (await activeSpecialOf(tx, callerId)) throw new AppException(ErrorCode.USERNAME_LOCKED);
        if (await activeLeaseOf(tx, callerId)) throw new AppException(ErrorCode.PREMIUM_USERNAME_ACTIVE);
        const now = this.clock.now();
        if (isReservedUsername(name) || (await nameInUse(tx, name, callerId, now))) {
          throw new AppException(ErrorCode.USERNAME_TAKEN);
        }
        await tx.userProfile.update({
          where: { userId: callerId },
          data: { username: name, premiumTier: null },
        });
        await tx.auditLog.create({
          data: {
            action: AuditAction.USERNAME_CHANGE,
            actorUserId: callerId,
            targetType: 'user',
            targetId: callerId,
            metadata: { from: profile.username, to: name },
          },
        });
        return true;
      })
      .catch((err: unknown) => {
        if (violatedUniqueIndex(err) !== null) throw new AppException(ErrorCode.USERNAME_TAKEN);
        throw err;
      });
    void changed;
    const me = await this.users.getMe(callerId);
    if (!me) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    return me;
  }

  // ---- Sweeper: reminders, expiry, end of grace ----------------------------------------------------

  /**
   * One pass (each lease in its own short transaction; rows another instance holds are skipped):
   * reminders before the end (`PREMIUM_USERNAME_EXPIRING`, at most one per configured day count),
   * expiry (ACTIVE → GRACE for `graceDays`, back to the regular username,
   * `PREMIUM_USERNAME_EXPIRED`), and the end of grace (GRACE → ENDED, the name back in the pool).
   * Returns how many leases changed.
   */
  async sweep(now: Date = this.clock.now()): Promise<{ reminded: number; expired: number; ended: number }> {
    const out = { reminded: 0, expired: 0, ended: 0 };
    const reminderDays = [...this.rules.reminderDays].sort((a, b) => b - a);
    const widest = reminderDays[0] ?? 0;

    // Expiry first, so a lease past its end is never reminded.
    for (;;) {
      const due = await this.prisma.premiumUsernameLease.findMany({
        where: { status: 'ACTIVE', expiresAt: { lte: now } },
        select: { id: true },
        orderBy: { expiresAt: 'asc' },
        take: SWEEP_BATCH,
      });
      let done = 0;
      for (const { id } of due) if (await this.expireOne(id, now)) done += 1;
      out.expired += done;
      if (due.length < SWEEP_BATCH || done === 0) break;
    }
    for (;;) {
      const due = await this.prisma.premiumUsernameLease.findMany({
        where: { status: 'GRACE', graceUntil: { lte: now } },
        select: { id: true },
        orderBy: { graceUntil: 'asc' },
        take: SWEEP_BATCH,
      });
      let done = 0;
      for (const { id } of due) if (await this.endGraceOne(id, now)) done += 1;
      out.ended += done;
      if (due.length < SWEEP_BATCH || done === 0) break;
    }
    if (widest > 0) {
      const due = await this.prisma.premiumUsernameLease.findMany({
        where: { status: 'ACTIVE', expiresAt: { gt: now, lte: new Date(now.getTime() + widest * DAY_MS) } },
        select: { id: true, expiresAt: true, remindedDays: true },
        orderBy: { expiresAt: 'asc' },
        take: 5000,
      });
      for (const lease of due) {
        const left = lease.expiresAt!.getTime() - now.getTime();
        // The smallest configured count that has been reached, e.g. 1 when one day is left.
        const reached = reminderDays.filter((d) => left <= d * DAY_MS);
        const days = reached[reached.length - 1];
        if (days === undefined || (lease.remindedDays !== null && lease.remindedDays <= days)) continue;
        if (await this.remindOne(lease.id, days, now)) out.reminded += 1;
      }
    }
    return out;
  }

  private lockLeaseIn(tx: Tx, id: string, status: 'ACTIVE' | 'GRACE'): Promise<{ id: string }[]> {
    return tx.$queryRaw<{ id: string }[]>`
      SELECT id::text AS id FROM premium_username_leases
       WHERE id = ${id}::uuid AND status = ${status}::premium_username_lease_status
         FOR UPDATE SKIP LOCKED`;
  }

  private async expireOne(id: string, now: Date): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      if ((await this.lockLeaseIn(tx, id, 'ACTIVE')).length === 0) return false;
      const lease = (await tx.premiumUsernameLease.findUniqueOrThrow({ where: { id } })) as LeaseRow;
      if (lease.expiresAt === null || lease.expiresAt > now) return false;
      const revertedTo = await revertProfileIn(tx, lease);
      const graceUntil = new Date(lease.expiresAt.getTime() + this.rules.graceDays * DAY_MS);
      await tx.premiumUsernameLease.update({
        where: { id },
        data: { status: 'GRACE', graceUntil, regularUsername: revertedTo, updatedAt: now },
      });
      await this.notifier.system(tx, {
        type: 'PREMIUM_USERNAME_EXPIRED',
        recipientId: lease.userId,
        premiumLeaseId: id,
      });
      await tx.auditLog.create({
        data: {
          action: AuditAction.PREMIUM_USERNAME_EXPIRE,
          targetType: 'user',
          targetId: lease.userId,
          metadata: {
            leaseId: id,
            username: lease.username,
            tier: lease.tier,
            revertedTo,
            graceUntil: graceUntil.toISOString(),
          },
        },
      });
      return true;
    });
  }

  private async endGraceOne(id: string, now: Date): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      if ((await this.lockLeaseIn(tx, id, 'GRACE')).length === 0) return false;
      const lease = (await tx.premiumUsernameLease.findUniqueOrThrow({ where: { id } })) as LeaseRow;
      await endLeaseIn(tx, lease, 'GRACE_OVER', now, null, 'sweeper');
      return true;
    });
  }

  private async remindOne(id: string, days: number, now: Date): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      if ((await this.lockLeaseIn(tx, id, 'ACTIVE')).length === 0) return false;
      const lease = (await tx.premiumUsernameLease.findUniqueOrThrow({ where: { id } })) as LeaseRow;
      if (lease.expiresAt === null || lease.expiresAt <= now) return false;
      if (lease.remindedDays !== null && lease.remindedDays <= days) return false;
      await tx.premiumUsernameLease.update({ where: { id }, data: { remindedDays: days, updatedAt: now } });
      await this.notifier.system(tx, {
        type: 'PREMIUM_USERNAME_EXPIRING',
        recipientId: lease.userId,
        premiumLeaseId: id,
      });
      return true;
    });
  }

  private scheduleSweep(): void {
    this.sweepTimer = setTimeout(() => {
      this.sweepInFlight = this.sweep()
        .then(() => undefined)
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Premium username sweep failed');
        })
        .finally(() => {
          this.sweepInFlight = null;
          this.scheduleSweep();
        });
    }, this.rules.sweepIntervalSeconds * 1000);
    this.sweepTimer.unref();
  }
}
