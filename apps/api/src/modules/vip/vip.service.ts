import { createHash, randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import type { Prisma, VipTier, VipTierPerk } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { debitIn } from '../wallet/wallet-ledger.js';
import {
  planVipPurchase,
  VIP_MAX_AHEAD_DAYS,
  vipActive,
  vipDaysLeft,
  vipPerkAvailable,
  type VipPurchaseKind,
} from './vip-rules.js';

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
}

/** `VipTier`: a tier on sale, in the panel's order. */
export interface VipTierDto {
  id: string;
  code: string;
  name: string;
  /** 1 … n among the tiers on sale, in order. */
  level: number;
  color: string;
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

/** `MyVip`. */
export interface MyVipDto {
  membership: VipMembershipDto | null;
}

/** `VipPurchaseResult`. */
export interface VipPurchaseResultDto {
  kind: VipPurchaseKind;
  priceCoins: number;
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
 * «شراء VIP» for the person (v1.82-social, D252, CONVENTIONS §10.92): the tiers on sale with their perks, the caller's
 * membership, and buying (new, renew, upgrade) with coins — one transaction per purchase, serialized per person, the
 * coins taken with a `VIP_PURCHASE` ledger row whose reference is the purchase.
 */
@Injectable()
export class VipService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly users: UsersService,
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
    if (!m || !vipActive(m.expiresAt, now)) return { membership: null };
    return { membership: membershipDto(lang, m, m.tier, now) };
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
    try {
      const result = await this.prisma.$transaction(async (tx) => {
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
        if (tier.priceCoins !== BigInt(body.priceCoins)) throw new AppException(ErrorCode.VIP_PRICE_CHANGED);
        const purchaseId = randomUUID();
        const change = await debitIn(tx, userId, tier.priceCoins, 'VIP_PURCHASE', purchaseId);
        if (!change) throw new AppException(ErrorCode.INSUFFICIENT_COINS);
        const active = held !== null && vipActive(held.expiresAt, now);
        await tx.vipPurchase.create({
          data: {
            id: purchaseId,
            userId,
            tierId: tier.id,
            kind: plan.kind,
            priceCoins: tier.priceCoins,
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
          update: { tierId: tier.id, startedAt: plan.startedAt, expiresAt: plan.expiresAt },
        });
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
              priceCoins: Number(tier.priceCoins),
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
          priceCoins: Number(tier.priceCoins),
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
      durationDays: purchase.durationDays,
      membership,
      coins: Number(purchase.coinsAfter),
    };
  }
}
