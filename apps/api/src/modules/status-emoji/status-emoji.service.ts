import { createHash, randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { refuseLimitedStaff } from '../live/live-staff.js';
import { UsersService, violatedUniqueIndex, type MeDto } from '../users/users.service.js';
import { debitIn, inCoinDebtIn } from '../wallet/wallet-ledger.js';
import {
  isStoreStatusPack,
  STORE_STATUS_PACKS,
  statusEmojiKind,
  statusPackOf,
  visibleStatusEmoji,
} from './status-emoji-catalogue.js';
import type { BuyStatusPackBody } from './status-emoji.schemas.js';

type Tx = Prisma.TransactionClient;

const DAY_MS = 86_400_000;

/** A pack's end may be at most this far ahead after renewals (as the store, §10.98). */
export const STATUS_PACK_MAX_AHEAD_DAYS = 3650;

/** `StatusPackOption`. */
export interface StatusPackOptionDto {
  days: number;
  coins: number;
}

/** `StatusPack`: a pack sold in «متجر الحالة», its prices and the caller's end. */
export interface StatusPackDto {
  id: string;
  emojiIds: string[];
  options: StatusPackOptionDto[];
  /** The end of the caller's pack while held; null when not held (never bought, or ended). */
  expiresAt: string | null;
}

/** `StatusPackList`. */
export interface StatusPackListDto {
  data: StatusPackDto[];
  /** The caller's coins now. */
  coins: number;
}

/** `StatusPackPurchaseResult`. */
export interface StatusPackPurchaseDto {
  id: string;
  packId: string;
  days: number;
  price: number;
  expiresAt: string;
  extended: boolean;
  coins: number;
}

/** The new end of a pack bought for [days]: added to a pack still held, else counted from now (owner rule). */
export function statusPackExpiryAfter(held: Date | null, days: number, now: Date): Date {
  const from = held !== null && held.getTime() > now.getTime() ? held.getTime() : now.getTime();
  return new Date(from + days * DAY_MS);
}

export function statusPackRequestHash(packId: string, body: BuyStatusPackBody): string {
  return createHash('sha256')
    .update([packId, String(body.days), String(body.price)].join('\n'))
    .digest('hex');
}

/**
 * «الحالة» (D376, CONVENTIONS §10.167): the status emoji a person wears over their picture, and «متجر الحالة» — a
 * whole status pack bought with coins for a time (the price is the server's `status_pack_offers`, never the app's; a
 * renewal adds the days to what is left; an ended pack's emoji stops showing at once and is cleared by the next
 * write). One transaction per purchase, serialized per buyer, idempotent (`Idempotency-Key`), audited.
 */
@Injectable()
export class StatusEmojiService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly users: UsersService,
  ) {}

  /** `PUT /me/status`: sets (or, with null, clears) the caller's status; the updated `Me`. */
  async setStatus(
    userId: string,
    statusEmojiId: string | null,
    meta: { ip: string | null; requestId: string },
  ) {
    // v1.72-live (D283, §10.96.10): a limited Kabso Team account keeps the team's fixed look.
    await refuseLimitedStaff(this.prisma, userId, 'frame');
    if (statusEmojiId !== null && statusEmojiKind(statusEmojiId) === 'unknown') {
      throw AppException.validation([{ field: 'statusEmojiId', issue: 'invalid_value' }]);
    }
    await this.prisma.$transaction(async (tx) => {
      if (!(await this.users.lockActiveById(tx, userId)))
        throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
      const now = this.clock.now();
      const [row] = await tx.$queryRaw<{ status_emoji_id: string | null }[]>`
        SELECT status_emoji_id FROM users WHERE id = ${userId}::uuid FOR UPDATE`;
      if (statusEmojiId !== null && statusEmojiKind(statusEmojiId) === 'store') {
        const pack = statusPackOf(statusEmojiId)!;
        const held = await tx.userStatusPack.findUnique({
          where: { userId_packId: { userId, packId: pack } },
          select: { expiresAt: true },
        });
        if (!held || held.expiresAt.getTime() <= now.getTime()) {
          // 409: the app offers «متجر الحالة». Nothing changes.
          throw new AppException(ErrorCode.STORE_UNAVAILABLE, undefined, [
            { field: 'statusEmojiId', issue: 'pack_not_owned' },
          ]);
        }
      }
      const before = row?.status_emoji_id ?? null;
      if (before === statusEmojiId) return;
      await tx.user.update({ where: { id: userId }, data: { statusEmojiId } });
      await tx.auditLog.create({
        data: {
          action: AuditAction.USER_STATUS_UPDATE,
          actorUserId: userId,
          targetType: 'user',
          targetId: userId,
          ip: meta.ip,
          requestId: meta.requestId,
          metadata: { from: before, to: statusEmojiId },
        },
      });
    });
    const me = await this.users.getMe(userId);
    if (!me) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    return me satisfies MeDto;
  }

  /** `GET /status-packs`: the packs on sale (with at least one enabled price), their prices and the caller's ends. */
  async packs(userId: string): Promise<StatusPackListDto> {
    const now = this.clock.now();
    await this.clearEndedStatus(this.prisma, userId, now);
    const [offers, held, wallet] = await Promise.all([
      this.prisma.statusPackOffer.findMany({
        where: { enabled: true },
        orderBy: [{ packId: 'asc' }, { days: 'asc' }],
      }),
      this.prisma.userStatusPack.findMany({ where: { userId }, select: { packId: true, expiresAt: true } }),
      this.prisma.wallet.findUnique({ where: { userId }, select: { coins: true } }),
    ]);
    const data: StatusPackDto[] = [];
    for (const [id, emojis] of Object.entries(STORE_STATUS_PACKS)) {
      const options = offers
        .filter((o) => o.packId === id)
        .map((o) => ({ days: o.days, coins: Number(o.coins) }));
      const end = held.find((h) => h.packId === id)?.expiresAt ?? null;
      const active = end !== null && end.getTime() > now.getTime() ? end : null;
      // A pack with no price is not on sale; one the caller holds is still listed (its emojis stay usable).
      if (options.length === 0 && active === null) continue;
      data.push({
        id,
        emojiIds: emojis.map((e) => `${id}.${e}`),
        options,
        expiresAt: active?.toISOString() ?? null,
      });
    }
    return { data, coins: Number(wallet?.coins ?? 0n) };
  }

  /**
   * `POST /status-packs/{packId}/purchases`. Refusals, in order: 400 `VALIDATION_FAILED` (body, `Idempotency-Key`) →
   * 404 `NOT_FOUND` (not a pack on sale) → 409 `IDEMPOTENCY_CONFLICT` (the key with another body) → 403
   * `STAFF_ACCOUNT_LIMITED` → 403 `TOPUP_ACCOUNT_FROZEN` (coins in debt) → 409 `STORE_UNAVAILABLE` (`days` /
   * `not_priced` or `too_far`) → 409 `STORE_PRICE_CHANGED` → 409 `INSUFFICIENT_COINS`. A refusal charges nothing.
   */
  async buy(
    userId: string,
    packId: string,
    idempotencyKey: string,
    body: BuyStatusPackBody,
  ): Promise<{ replay: boolean; result: StatusPackPurchaseDto }> {
    if (!isStoreStatusPack(packId)) throw new AppException(ErrorCode.NOT_FOUND);
    const key = idempotencyKey.toLowerCase();
    const requestHash = statusPackRequestHash(packId, body);
    const replay = await this.findReplay(userId, key, requestHash);
    if (replay) return { replay: true, result: replay };
    await refuseLimitedStaff(this.prisma, userId, 'store');
    try {
      const id = await this.prisma.$transaction(async (tx) => {
        await tx.$executeRawUnsafe(`SET LOCAL lock_timeout = '4s'`);
        if (!(await this.users.lockActiveById(tx, userId)))
          throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
        // One buyer's purchases run one after another (the same lock as the store's: one wallet).
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:store-buyer'), hashtext(${userId}))`;
        const now = this.clock.now();
        if (await inCoinDebtIn(tx, userId)) throw new AppException(ErrorCode.TOPUP_ACCOUNT_FROZEN);
        const [offer] = await tx.$queryRaw<{ coins: bigint; enabled: boolean }[]>`
          SELECT coins, enabled FROM status_pack_offers
           WHERE pack_id = ${packId} AND days = ${body.days} FOR SHARE`;
        if (!offer || !offer.enabled) {
          throw new AppException(ErrorCode.STORE_UNAVAILABLE, undefined, [
            { field: 'days', issue: 'not_priced' },
          ]);
        }
        if (offer.coins !== BigInt(body.price)) throw new AppException(ErrorCode.STORE_PRICE_CHANGED);
        const [held] = await tx.$queryRaw<{ expires_at: Date }[]>`
          SELECT expires_at FROM user_status_packs
           WHERE user_id = ${userId}::uuid AND pack_id = ${packId} FOR UPDATE`;
        const heldUntil = held?.expires_at ?? null;
        const extended = heldUntil !== null && heldUntil.getTime() > now.getTime();
        const expiresAt = statusPackExpiryAfter(heldUntil, body.days, now);
        if (expiresAt.getTime() - now.getTime() > STATUS_PACK_MAX_AHEAD_DAYS * DAY_MS) {
          throw new AppException(ErrorCode.STORE_UNAVAILABLE, undefined, [
            { field: 'days', issue: 'too_far' },
          ]);
        }
        const purchaseId = randomUUID();
        const change = await debitIn(tx, userId, offer.coins, 'STATUS_PACK_PURCHASE', purchaseId);
        if (!change) throw new AppException(ErrorCode.INSUFFICIENT_COINS);
        await tx.userStatusPack.upsert({
          where: { userId_packId: { userId, packId } },
          create: { userId, packId, expiresAt },
          update: { expiresAt },
        });
        await tx.statusPackPurchase.create({
          data: {
            id: purchaseId,
            userId,
            packId,
            days: body.days,
            price: offer.coins,
            balanceAfter: change.coins,
            expiresAt,
            extended,
            idempotencyKey: key,
            requestHash,
            createdAt: now,
          },
        });
        await tx.auditLog.create({
          data: {
            action: AuditAction.STATUS_PACK_PURCHASE,
            actorUserId: userId,
            targetType: 'user',
            targetId: userId,
            metadata: {
              purchaseId,
              packId,
              days: body.days,
              price: Number(offer.coins),
              extended,
              expiresAt: expiresAt.toISOString(),
            },
          },
        });
        return purchaseId;
      });
      return { replay: false, result: await this.resultOf(userId, id) };
    } catch (err) {
      if (violatedUniqueIndex(err) !== null) {
        // The same key won a race: answer with its result.
        const raced = await this.findReplay(userId, key, requestHash);
        if (raced) return { replay: true, result: raced };
      }
      throw err;
    }
  }

  /**
   * Clears the caller's stored status when it belongs to a pack that has ended (the readers already show nothing).
   * Called on `GET /status-packs`, so the row follows soon after the end without a sweeper.
   */
  async clearEndedStatus(tx: Tx | PrismaService, userId: string, now: Date): Promise<void> {
    const user = await tx.user.findUnique({
      where: { id: userId },
      select: { statusEmojiId: true, statusPacks: { select: { packId: true, expiresAt: true } } },
    });
    const id = user?.statusEmojiId ?? null;
    if (id === null || visibleStatusEmoji(id, user?.statusPacks, now) !== null) return;
    await tx.user.updateMany({ where: { id: userId, statusEmojiId: id }, data: { statusEmojiId: null } });
  }

  private async findReplay(
    userId: string,
    key: string,
    requestHash: string,
  ): Promise<StatusPackPurchaseDto | null> {
    const purchase = await this.prisma.statusPackPurchase.findUnique({
      where: { userId_idempotencyKey: { userId, idempotencyKey: key } },
      select: { id: true, requestHash: true },
    });
    if (!purchase) return null;
    if (purchase.requestHash !== requestHash) throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
    return this.resultOf(userId, purchase.id);
  }

  /** The purchase's answer (the first one's on a replay; the coins as they are now). */
  private async resultOf(userId: string, id: string): Promise<StatusPackPurchaseDto> {
    const [p, wallet] = await Promise.all([
      this.prisma.statusPackPurchase.findUniqueOrThrow({ where: { id } }),
      this.prisma.wallet.findUnique({ where: { userId }, select: { coins: true } }),
    ]);
    return {
      id: p.id,
      packId: p.packId,
      days: p.days,
      price: Number(p.price),
      expiresAt: p.expiresAt.toISOString(),
      extended: p.extended,
      coins: Number(wallet?.coins ?? 0n),
    };
  }
}
