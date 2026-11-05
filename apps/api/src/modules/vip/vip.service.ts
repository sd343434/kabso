import { createHash, randomUUID } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import type { Prisma, VipTier, VipTierPerk } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { dateValue, programWindowsIn } from '../programs/programs-time.js';
import { creditIn, debitIn } from '../wallet/wallet-ledger.js';
import { wearVipItemsIn } from './vip-bag.js';
import { vipHoldsPerkIn, vipPerkAmountIn } from './vip-perks.js';
import { PROFILE_VISITORS_DAYS, PROFILE_VISITORS_MAX } from './profile-visits.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import {
  planVipPurchase,
  VIP_MAX_AHEAD_DAYS,
  VIP_RENEWAL_GRACE_DAYS,
  vipActive,
  vipDiscounted,
  vipRenewalApplies,
  vipDaysLeft,
  vipPerkAvailable,
  type VipPurchaseKind,
} from './vip-rules.js';
import { refuseLimitedStaff } from '../live/live-staff.js';

type Tx = Prisma.TransactionClient;

/** An Idempotency-Key is remembered for 24 hours (§3, like premium usernames). */
const IDEMPOTENCY_MS = 24 * 3600_000;

// ---- Response shapes (openapi v1.82-social, D252) ---------------------------------------------------------------------

/** `VipPerk`: a perk in the reader's language. `available`: the app really does it today. */
export interface VipPerkDto {
  code: string;
  title: string;
  description: string | null;
  available: boolean;
  /** The perk's own art (SVGA + still) and its intrinsic size; null when none set. */
  animation: string | null;
  still: string | null;
  artWidth: number | null;
  artHeight: number | null;
  /** D258: the perk's number for this tier (bullets / coins a day, level speed-up %); null otherwise. */
  amount: number | null;
}

/** `VipTier`: a tier on sale, in the panel's order. */
export interface VipTierDto {
  id: string;
  code: string;
  name: string;
  /** 1 … n among the tiers on sale, in order. */
  level: number;
  color: string;
  /** v1.83-social (D258): the special text colour (CHAT_NAME_COLOR), or null. */
  nameColor: string | null;
  /** v1.83-social (D258, §10.94.12): percent off a renewal (0 = none) and the renewal's price. */
  renewalDiscountPercent: number;
  renewPriceCoins: number;
  /** The tier BADGE (central crest): an SVGA animation and a still (asset path or https URL). */
  badgeAnimation: string | null;
  badgeStill: string | null;
  priceCoins: number;
  durationDays: number;
  perks: VipPerkDto[];
}

/** `VipTierList`. */
export interface VipTierListDto {
  data: VipTierDto[];
  maxAheadDays: number;
}

/** `VipMembership`: the caller's active membership. */
export interface VipMembershipDto {
  tier: {
    id: string;
    code: string;
    name: string;
    color: string;
    badgeAnimation: string | null;
    badgeStill: string | null;
    onSale: boolean;
  };
  startedAt: string;
  expiresAt: string;
  daysLeft: number;
}

/** v1.83-social (D258, §10.94.5): `VipDailyCoins` — the member's daily coins today. */
export interface VipDailyCoinsDto {
  /** Coins a day (DAILY_COINS, with inheritance). */
  amount: number;
  claimedToday: boolean;
  /** The next day's start (when the next claim opens), ISO. */
  nextAt: string;
}

/** `MyVip`. */
export interface MyVipDto {
  membership: VipMembershipDto | null;
  /**
   * v1.83-social (D258, §10.94.12): while buying the caller's tier again earns its renewal discount (the membership
   * is active or ended at most 7 days ago, the tier on sale, a discount set): the tier, the price to send and until
   * when it holds.
   */
  renewal?: { tierId: string; priceCoins: number; discountPercent: number; until: string };
  /** v1.83-social (D258): present while the member holds DAILY_COINS with an amount. */
  dailyCoins?: VipDailyCoinsDto;
}

/** v1.83-social (D258): `VipDailyCoinsClaim`. */
/** v1.83-social (D258, §10.94.9): one visitor of the caller's profile. */
export interface ProfileVisitorDto {
  user: UserSummaryDto;
  lastVisitedAt: string;
  visits: number;
}

/** `ProfileVisitorList`: a server-bounded list (no `page`). */
export interface ProfileVisitorListDto {
  data: ProfileVisitorDto[];
  total: number;
}

export interface VipDailyCoinsClaimDto {
  /** Coins credited by this call (0 when today's were already claimed). */
  coins: number;
  /** The caller's balance now. */
  balance: number;
  dailyCoins: VipDailyCoinsDto;
}

/** `VipPurchaseResult`. */
export interface VipPurchaseResultDto {
  kind: VipPurchaseKind;
  /** The coins charged (after a renewal discount). */
  priceCoins: number;
  /** v1.83-social (D258, §10.94.12): the tier's list price and the discount applied (0 = none). */
  listPriceCoins: number;
  discountPercent: number;
  durationDays: number;
  membership: VipMembershipDto;
  /** The caller's coin balance right after the purchase. */
  coins: number;
}

export function vipName(lang: ContentLanguage, row: { nameAr: string; nameEn: string }): string {
  return lang === 'ar' ? row.nameAr : row.nameEn;
}

export function vipPerkDto(lang: ContentLanguage, p: VipTierPerk): VipPerkDto {
  return {
    code: p.code,
    title: lang === 'ar' ? p.titleAr : p.titleEn,
    description: (lang === 'ar' ? p.descriptionAr : p.descriptionEn) ?? null,
    available: vipPerkAvailable(p.code),
    animation: p.animation,
    still: p.still,
    artWidth: p.artWidth,
    artHeight: p.artHeight,
    amount: p.amount,
  };
}

function membershipDto(
  lang: ContentLanguage,
  m: { startedAt: Date; expiresAt: Date },
  tier: VipTier,
  now: Date,
): VipMembershipDto {
  return {
    tier: {
      id: tier.id,
      code: tier.code,
      name: vipName(lang, tier),
      color: tier.color,
      badgeAnimation: tier.badgeAnimation,
      badgeStill: tier.badgeStill,
      onSale: tier.enabled,
    },
    startedAt: m.startedAt.toISOString(),
    expiresAt: m.expiresAt.toISOString(),
    daysLeft: vipDaysLeft(m.expiresAt, now),
  };
}

/** Serializes one person's VIP purchases (and every read of their membership inside them). */
async function lockVipUser(tx: Tx, userId: string): Promise<void> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:vip-user'), hashtext(${userId}))`;
}

/**
 * «شراء VIP» for the person (v1.82-social, D252, CONVENTIONS §10.93): the tiers on sale with their perks, the caller's
 * membership, and buying (new, renew, upgrade) with coins — one transaction per purchase, serialized per person, the
 * coins taken with a `VIP_PURCHASE` ledger row whose reference is the purchase.
 */
@Injectable()
export class VipService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly users: UsersService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** `GET /vip/tiers`: the tiers switched on, in order, with their perks that are switched on. */
  async tiers(lang: ContentLanguage): Promise<VipTierListDto> {
    const rows = await this.prisma.vipTier.findMany({
      where: { enabled: true },
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
      include: { perks: { where: { enabled: true }, orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }] } },
    });
    return {
      data: rows.map((t, i) => ({
        id: t.id,
        code: t.code,
        name: vipName(lang, t),
        level: i + 1,
        color: t.color,
        nameColor: t.nameColor,
        renewalDiscountPercent: t.renewalDiscountPercent,
        renewPriceCoins: Number(vipDiscounted(t.priceCoins, t.renewalDiscountPercent)),
        badgeAnimation: t.badgeAnimation,
        badgeStill: t.badgeStill,
        priceCoins: Number(t.priceCoins),
        durationDays: t.durationDays,
        perks: t.perks.map((p) => vipPerkDto(lang, p)),
      })),
      maxAheadDays: VIP_MAX_AHEAD_DAYS,
    };
  }

  /** `GET /me/vip`: the caller's active membership (an ended one reads as none). */
  async mine(userId: string, lang: ContentLanguage): Promise<MyVipDto> {
    const now = this.clock.now();
    const m = await this.prisma.vipMembership.findUnique({ where: { userId }, include: { tier: true } });
    const renewal =
      m && m.tier.enabled && m.tier.renewalDiscountPercent > 0 && vipRenewalApplies(m, m.tierId, now)
        ? {
            tierId: m.tierId,
            priceCoins: Number(vipDiscounted(m.tier.priceCoins, m.tier.renewalDiscountPercent)),
            discountPercent: m.tier.renewalDiscountPercent,
            until: new Date(m.expiresAt.getTime() + VIP_RENEWAL_GRACE_DAYS * 86_400_000).toISOString(),
          }
        : undefined;
    if (!m || !vipActive(m.expiresAt, now)) return { membership: null, ...(renewal ? { renewal } : {}) };
    const daily = await this.dailyCoinsState(this.prisma, userId, now);
    return {
      membership: membershipDto(lang, m, m.tier, now),
      ...(renewal ? { renewal } : {}),
      ...(daily ? { dailyCoins: daily.dto } : {}),
    };
  }

  /** D258: the member's daily coins today, or null without the perk (or an amount). */
  private async dailyCoinsState(
    db: Tx | PrismaService,
    userId: string,
    now: Date,
  ): Promise<{ dto: VipDailyCoinsDto; day: string; tierId: string } | null> {
    const amount = await vipPerkAmountIn(db, userId, 'DAILY_COINS', now);
    if (amount === null) return null;
    const membership = await db.vipMembership.findUnique({ where: { userId }, select: { tierId: true } });
    if (!membership) return null;
    const { day } = await programWindowsIn(db, now, this.config.live.rankingsTimeZone);
    const claimed = await db.vipDailyCoinClaim.findUnique({
      where: { userId_day: { userId, day: dateValue(day.date) } },
      select: { id: true },
    });
    return {
      dto: { amount, claimedToday: claimed !== null, nextAt: day.end.toISOString() },
      day: day.date,
      tierId: membership.tierId,
    };
  }

  /**
   * v1.83-social (D258, §10.94.5) `POST /me/vip/daily-coins`: credits today's coins once (ledger `VIP_DAILY_COINS`,
   * reference the claim row); a second call the same day credits nothing (`coins` 0). 409 `VIP_UNAVAILABLE`
   * (`no_perk`) without an active membership holding DAILY_COINS with an amount.
   */
  async claimDailyCoins(userId: string): Promise<VipDailyCoinsClaimDto> {
    const now = this.clock.now();
    return this.prisma.$transaction(async (tx) => {
      await lockVipUser(tx, userId);
      const state = await this.dailyCoinsState(tx, userId, now);
      if (!state) {
        throw new AppException(ErrorCode.VIP_UNAVAILABLE, undefined, [{ field: 'perk', issue: 'no_perk' }]);
      }
      if (state.dto.claimedToday) {
        const wallet = await tx.wallet.findUnique({ where: { userId }, select: { coins: true } });
        return { coins: 0, balance: Number(wallet?.coins ?? 0n), dailyCoins: state.dto };
      }
      const claim = await tx.vipDailyCoinClaim.create({
        data: {
          id: randomUUID(),
          userId,
          day: dateValue(state.day),
          tierId: state.tierId,
          coins: BigInt(state.dto.amount),
        },
      });
      const credited = await creditIn(tx, userId, BigInt(state.dto.amount), 'VIP_DAILY_COINS', claim.id);
      return {
        coins: state.dto.amount,
        balance: Number(credited.coins),
        dailyCoins: { ...state.dto, claimedToday: true },
      };
    });
  }

  /**
   * v1.83-social (D258, §10.94.9) `GET /me/profile-visitors` («من زار ملفي»): who opened the caller's profile in the
   * last {@link PROFILE_VISITORS_DAYS} days, the latest visit first, at most {@link PROFILE_VISITORS_MAX} (a
   * server-bounded list, §5): only ACTIVE accounts with no block either way. `total` counts them all. 409
   * `VIP_UNAVAILABLE` (`no_perk`) without an active membership holding PROFILE_VISITORS.
   */
  async profileVisitors(userId: string): Promise<ProfileVisitorListDto> {
    const now = this.clock.now();
    if (!(await vipHoldsPerkIn(this.prisma, userId, 'PROFILE_VISITORS', now))) {
      throw new AppException(ErrorCode.VIP_UNAVAILABLE, undefined, [{ field: 'perk', issue: 'no_perk' }]);
    }
    const since = new Date(now.getTime() - PROFILE_VISITORS_DAYS * 86_400_000);
    const where = {
      ownerId: userId,
      lastVisitedAt: { gt: since },
      visitor: {
        status: 'ACTIVE' as const,
        blocking: { none: { blockedId: userId } },
        blockedBy: { none: { blockerId: userId } },
      },
    };
    const [rows, total] = await Promise.all([
      this.prisma.profileVisit.findMany({
        where,
        orderBy: [{ lastVisitedAt: 'desc' }, { visitorId: 'asc' }],
        take: PROFILE_VISITORS_MAX,
        select: { lastVisitedAt: true, visits: true, visitor: { select: USER_SUMMARY_SELECT } },
      }),
      this.prisma.profileVisit.count({ where }),
    ]);
    const data: ProfileVisitorDto[] = [];
    for (const r of rows) {
      const user = userSummary(r.visitor, now);
      if (user) data.push({ user, lastVisitedAt: r.lastVisitedAt.toISOString(), visits: r.visits });
    }
    return { data, total };
  }

  /**
   * `POST /me/vip/purchases` (`Idempotency-Key` required, validated by the controller). Order: a retry (the same key
   * within 24 h: the same body → the first result, nothing charged; another body → 409 `IDEMPOTENCY_CONFLICT`) → 404
   * unknown tier → 409 `VIP_UNAVAILABLE` (`tier_off` | `downgrade` | `renewal_limit`) → 409 `VIP_PRICE_CHANGED` → 409
   * `INSUFFICIENT_COINS`. A refused request charges and changes nothing.
   */
  async buy(
    userId: string,
    idempotencyKey: string,
    body: { tierId: string; priceCoins: number },
    lang: ContentLanguage,
  ): Promise<{ replay: boolean; result: VipPurchaseResultDto }> {
    const key = idempotencyKey.toLowerCase();
    const tierId = body.tierId.toLowerCase();
    const requestHash = createHash('sha256')
      .update(`${tierId}\n${String(body.priceCoins)}`)
      .digest('hex');
    const replay = await this.findReplay(userId, key, requestHash, lang);
    if (replay) return { replay: true, result: replay };
    // v1.72-live (D283, §10.96.10): a Kabso Team account wears the team frame and badge, never VIP.
    await refuseLimitedStaff(this.prisma, userId, 'vip');
    try {
      const result = await this.prisma.$transaction(async (tx) => {
        // Bound every lock wait in this purchase (the user row below, the
        // per-user advisory lock and the tier's FOR SHARE) under Prisma's
        // transaction timeout, so a contended lock errors and rolls back fast
        // instead of pinning the connection: a server-side lock wait outlives
        // the client-side transaction timeout, which would leave the test fork
        // (and the connection) stuck (D252b). Legitimate contention — one
        // person's serialized purchases — resolves far under this.
        await tx.$executeRawUnsafe(`SET LOCAL lock_timeout = '4s'`);
        if (!(await this.users.lockActiveById(tx, userId)))
          throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
        await lockVipUser(tx, userId);
        const now = this.clock.now();
        // An expired key may be used again.
        await tx.vipPurchase.updateMany({
          where: { userId, idempotencyKey: key, createdAt: { lt: new Date(now.getTime() - IDEMPOTENCY_MS) } },
          data: { idempotencyKey: null, requestHash: null },
        });
        // The tier row is held until the commit, so a panel change waits for this purchase (or comes first).
        const locked = await tx.$queryRaw<{ id: string }[]>`
          SELECT id::text AS id FROM vip_tiers WHERE id = ${tierId}::uuid FOR SHARE`;
        if (locked.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
        const tier = await tx.vipTier.findUniqueOrThrow({ where: { id: tierId } });
        const held = await tx.vipMembership.findUnique({ where: { userId }, include: { tier: true } });
        const plan = planVipPurchase(
          held
            ? {
                tierId: held.tierId,
                rank: held.tier.sortOrder,
                startedAt: held.startedAt,
                expiresAt: held.expiresAt,
              }
            : null,
          { id: tier.id, rank: tier.sortOrder, enabled: tier.enabled, durationDays: tier.durationDays },
          now,
        );
        if (!plan.ok) {
          throw new AppException(ErrorCode.VIP_UNAVAILABLE, undefined, [
            { field: 'tier', issue: plan.refusal },
          ]);
        }
        // D258 (§10.94.12): the same tier again while active, or within the grace after its end, earns the tier's
        // renewal discount; the price the person saw must match what is charged.
        const discount =
          plan.kind !== 'UPGRADE' && vipRenewalApplies(held, tier.id, now) ? tier.renewalDiscountPercent : 0;
        const charged = vipDiscounted(tier.priceCoins, discount);
        if (charged !== BigInt(body.priceCoins)) throw new AppException(ErrorCode.VIP_PRICE_CHANGED);
        const purchaseId = randomUUID();
        const change = await debitIn(tx, userId, charged, 'VIP_PURCHASE', purchaseId);
        if (!change) throw new AppException(ErrorCode.INSUFFICIENT_COINS);
        const active = held !== null && vipActive(held.expiresAt, now);
        await tx.vipPurchase.create({
          data: {
            id: purchaseId,
            userId,
            tierId: tier.id,
            kind: plan.kind,
            priceCoins: charged,
            listPriceCoins: tier.priceCoins,
            discountPercent: discount,
            durationDays: tier.durationDays,
            previousTierId: active ? held.tierId : null,
            previousExpiresAt: active ? held.expiresAt : null,
            expiresAt: plan.expiresAt,
            coinsAfter: change.coins,
            idempotencyKey: key,
            requestHash,
          },
        });
        const membership = await tx.vipMembership.upsert({
          where: { userId },
          create: { userId, tierId: tier.id, startedAt: plan.startedAt, expiresAt: plan.expiresAt },
          update: {
            tierId: tier.id,
            startedAt: plan.startedAt,
            expiresAt: plan.expiresAt,
            // v1.65-live (D264, §10.97): a new membership wears every tier item again (a renewal or an upgrade keeps
            // what the member took off in the bag).
            ...(plan.kind === 'NEW' ? { offPerks: [] } : {}),
          },
        });
        // D264 (owner: one worn item per kind): the tier's frame and card replace the bag's worn ones — on a new
        // membership all of them, on an upgrade or a renewal those the member did not take off.
        await wearVipItemsIn(tx, userId, tier.sortOrder, membership.offPerks);
        await tx.auditLog.create({
          data: {
            action: AuditAction.VIP_PURCHASE,
            actorUserId: userId,
            targetType: 'user',
            targetId: userId,
            metadata: {
              purchaseId,
              kind: plan.kind,
              tierId: tier.id,
              tierCode: tier.code,
              priceCoins: Number(charged),
              listPriceCoins: Number(tier.priceCoins),
              discountPercent: discount,
              durationDays: tier.durationDays,
              previousTierId: active ? held.tierId : null,
              previousExpiresAt: active ? held.expiresAt.toISOString() : null,
              expiresAt: plan.expiresAt.toISOString(),
              via: 'api',
            },
          },
        });
        return {
          kind: plan.kind,
          priceCoins: Number(charged),
          listPriceCoins: Number(tier.priceCoins),
          discountPercent: discount,
          durationDays: tier.durationDays,
          membership: membershipDto(lang, membership, tier, now),
          coins: Number(change.coins),
        };
      });
      return { replay: false, result };
    } catch (err) {
      if (violatedUniqueIndex(err) !== null) {
        // The same key won a race: answer with its result.
        const raced = await this.findReplay(userId, key, requestHash, lang);
        if (raced) return { replay: true, result: raced };
      }
      throw err;
    }
  }

  private async findReplay(
    userId: string,
    key: string,
    requestHash: string,
    lang: ContentLanguage,
  ): Promise<VipPurchaseResultDto | null> {
    const now = this.clock.now();
    const purchase = await this.prisma.vipPurchase.findFirst({
      where: { userId, idempotencyKey: key, createdAt: { gte: new Date(now.getTime() - IDEMPOTENCY_MS) } },
      include: { tier: true },
    });
    if (!purchase) return null;
    if (purchase.requestHash !== requestHash) throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
    const held = await this.prisma.vipMembership.findUnique({ where: { userId }, include: { tier: true } });
    // The membership as it is now (it may have been extended since); the purchase's own end when it ended.
    const membership =
      held && vipActive(held.expiresAt, now)
        ? membershipDto(lang, held, held.tier, now)
        : membershipDto(
            lang,
            { startedAt: purchase.createdAt, expiresAt: purchase.expiresAt },
            purchase.tier,
            now,
          );
    return {
      kind: purchase.kind,
      priceCoins: Number(purchase.priceCoins),
      listPriceCoins: Number(purchase.listPriceCoins ?? purchase.priceCoins),
      discountPercent: purchase.discountPercent,
      durationDays: purchase.durationDays,
      membership,
      coins: Number(purchase.coinsAfter),
    };
  }
}
