import { randomUUID } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { addItemTimeIn, lockItemHoldersIn } from '../bag/bag-grants.js';
import { holdCherriesIn, taskCherryLockIn } from '../economy/cherry-ledger.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { Notifier } from '../notifications/notifier.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { blockedEitherWayIn, lockUserPairIn } from '../social/pair-lock.js';
import { assertNotRestricted } from '../users/account-control.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { debitIn, inCoinDebtIn } from '../wallet/wallet-ledger.js';
import {
  lowestPrice,
  sortedPrices,
  STORE_ART_SELECT,
  STORE_DAY_MS,
  STORE_IDEMPOTENCY_MS,
  STORE_KINDS,
  storeArtDto,
  storeExpiryAfter,
  storeRequestHash,
  type StoreArtDto,
  type StoreCurrency,
  type StoreKind,
} from './store-rules.js';
import type { BuyStoreItemBody, StoreItemsQuery } from './store.schemas.js';

type Tx = Prisma.TransactionClient;

/** `StorePrice`: one duration in one currency. */
export interface StorePriceDto {
  currency: StoreCurrency;
  days: number;
  amount: number;
}

/** `StoreItem`: an item on sale, in the reader's language. */
export interface StoreItemDto {
  id: string;
  /** The bag code the item has once bought. */
  code: string;
  kind: StoreKind;
  name: string;
  art: StoreArtDto;
  isNew: boolean;
  /** Every price set (coins first, then cherries; shorter first). A duration not here is not offered. */
  prices: StorePriceDto[];
  /** The lowest price per currency (the grid's «from»), null when the item has none in it. */
  fromCoins: number | null;
  fromCherries: number | null;
  /** The caller owns it until then (a purchase adds the days to it), else null. */
  ownedUntil: string | null;
}

/**
 * `StoreBalances`: the caller's coins and the cherries they may spend now. Owner (D270): «هل يُصرف كرز المهام المقفل في
 * المتجر؟ لا» — `cherries` is the balance less the task cherries still locked (§10.46.1, the amount a withdrawal may
 * take); `lockedCherries` is that locked part (0 when none).
 */
export interface StoreBalancesDto {
  coins: number;
  cherries: number;
  lockedCherries: number;
}

/** `StoreItemList`: the items on sale, in the panel's order; a server-bounded list (§5). */
export interface StoreItemListDto {
  data: StoreItemDto[];
  /** The kinds that have items on sale now, in tab order. */
  kinds: StoreKind[];
  balances: StoreBalancesDto;
}

/** `StorePurchaseResult`. */
export interface StorePurchaseResultDto {
  id: string;
  item: { id: string; code: string; kind: StoreKind; name: string; art: StoreArtDto };
  currency: StoreCurrency;
  days: number;
  price: number;
  /** The person who received it: null for oneself. */
  recipient: UserSummaryDto | null;
  /** The item's end in the recipient's bag after the purchase. */
  expiresAt: string;
  /** The recipient owned it already: the days were added to its end. */
  extended: boolean;
  balances: StoreBalancesDto;
}

type ItemWithPrices = Prisma.StoreItemGetPayload<{ include: { prices: true } }>;

function nameOf(lang: ContentLanguage, row: { nameAr: string; nameEn: string }): string {
  return lang === 'ar' ? row.nameAr : row.nameEn;
}

function pricesOf(item: ItemWithPrices): StorePriceDto[] {
  return sortedPrices(item.prices).map((p) => ({
    currency: p.currency,
    days: p.days,
    amount: Number(p.amount),
  }));
}

async function balancesIn(
  db: Tx | PrismaService,
  userId: string,
  rules: AppConfig['economy'],
): Promise<StoreBalancesDto> {
  const [wallet, cherries, lock] = await Promise.all([
    db.wallet.findUnique({ where: { userId }, select: { coins: true } }),
    db.cherryWallet.findUnique({ where: { userId }, select: { cherries: true } }),
    taskCherryLockIn(db, userId, rules),
  ]);
  const balance = cherries?.cherries ?? 0n;
  const locked = lock.lockedCherries < 0n ? 0n : lock.lockedCherries;
  const spendable = balance - locked;
  return {
    coins: Number(wallet?.coins ?? 0n),
    cherries: Number(spendable > 0n ? spendable : 0n),
    lockedCherries: Number(balance > 0n ? (locked < balance ? locked : balance) : 0n),
  };
}

/** Serializes one buyer's store purchases (and every read of their balances inside them). */
async function lockBuyerIn(tx: Tx, userId: string): Promise<void> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:store-buyer'), hashtext(${userId}))`;
}

/**
 * «المتجر» for the person (D270, CONVENTIONS §10.98): the items on sale and buying one — for oneself or as a gift to
 * another person — with coins (the wallet ledger) or cherries (the cherry ledger). One transaction per purchase,
 * serialized per buyer, idempotent (`Idempotency-Key`), audited (`store.purchase`); the item lands in the recipient's
 * bag (`STORE`, or `GIFT` with the giver, who is notified as for a bag send).
 */
@Injectable()
export class StoreService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly users: UsersService,
    private readonly notifier: Notifier,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** `GET /store/items?kind=`: the items switched on with at least one price, in the panel's order. */
  async items(userId: string, query: StoreItemsQuery, lang: ContentLanguage): Promise<StoreItemListDto> {
    const now = this.clock.now();
    const rows = await this.prisma.storeItem.findMany({
      where: { enabled: true, prices: { some: {} }, ...(query.kind ? { kind: query.kind } : {}) },
      include: { prices: true },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
    });
    const owned = await this.prisma.userBagItem.findMany({
      where: {
        userId,
        itemCode: { in: rows.map((r) => r.bagCode) },
        OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
      },
      select: { itemCode: true, expiresAt: true },
    });
    const until = new Map(owned.map((o) => [o.itemCode, o.expiresAt]));
    const kinds = new Set(
      (query.kind
        ? rows
        : await this.prisma.storeItem.findMany({
            where: { enabled: true, prices: { some: {} } },
            select: { kind: true },
            distinct: ['kind'],
          })
      ).map((r) => r.kind),
    );
    return {
      data: rows.map((r) => this.itemDto(r, lang, until.get(r.bagCode))),
      kinds: STORE_KINDS.filter((k) => kinds.has(k)),
      balances: await balancesIn(this.prisma, userId, this.config.economy),
    };
  }

  private itemDto(row: ItemWithPrices, lang: ContentLanguage, owned: Date | null | undefined): StoreItemDto {
    const low = (c: StoreCurrency) => {
      const v = lowestPrice(row.prices, c);
      return v === null ? null : Number(v);
    };
    return {
      id: row.id,
      code: row.bagCode,
      kind: row.kind,
      name: nameOf(lang, row),
      art: storeArtDto(row),
      isNew: row.isNew,
      prices: pricesOf(row),
      fromCoins: low('COINS'),
      fromCherries: low('CHERRIES'),
      // A permanent copy (an admin grant) reads as owned with no end: a purchase is refused then.
      ownedUntil: owned === undefined ? null : (owned?.toISOString() ?? null),
    };
  }

  /**
   * `POST /me/store/purchases` (`Idempotency-Key` required, checked by the controller). Order: a retry (the same key
   * within 24 h: the same body → the first result, nothing charged; another body → 409 `IDEMPOTENCY_CONFLICT`) → 404
   * unknown item → for a gift: 404 (no ACTIVE account with that username, or a block either way), 400 `username`
   * `invalid_value` (oneself) → 403 `TOPUP_ACCOUNT_FROZEN` (the coin balance is below 0) → 403 `ACCOUNT_RESTRICTED`
   * (a gift while «منع إرسال الهدايا») → 409 `STORE_UNAVAILABLE` (`item_off` | `not_priced` | `owned_permanent` |
   * `too_far`) → 409 `STORE_PRICE_CHANGED` → 409 `INSUFFICIENT_COINS` / `INSUFFICIENT_CHERRIES`. A refused request
   * charges and changes nothing.
   */
  async buy(
    buyerId: string,
    idempotencyKey: string,
    body: BuyStoreItemBody,
    lang: ContentLanguage,
  ): Promise<{ replay: boolean; result: StorePurchaseResultDto }> {
    const key = idempotencyKey.toLowerCase();
    const recipientName = body.recipient ?? null;
    const requestHash = storeRequestHash({ ...body, recipient: recipientName });
    const replay = await this.findReplay(buyerId, key, requestHash, lang);
    if (replay) return { replay: true, result: replay };
    try {
      const done = await this.prisma.$transaction(async (tx) => {
        // Bound every lock wait (as VIP's purchase, D252b): contention rolls back fast.
        await tx.$executeRawUnsafe(`SET LOCAL lock_timeout = '4s'`);
        if (!(await this.users.lockActiveById(tx, buyerId))) {
          throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
        }
        await lockBuyerIn(tx, buyerId);
        const now = this.clock.now();
        // An expired key may be used again.
        await tx.storePurchase.updateMany({
          where: {
            buyerId,
            idempotencyKey: key,
            createdAt: { lt: new Date(now.getTime() - STORE_IDEMPOTENCY_MS) },
          },
          data: { idempotencyKey: null, requestHash: null },
        });
        // The item row is held until the commit, so a panel change waits for this purchase (or comes first).
        const locked = await tx.$queryRaw<{ id: string }[]>`
          SELECT id::text AS id FROM store_items WHERE id = ${body.itemId.toLowerCase()}::uuid FOR SHARE`;
        if (locked.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
        const item = await tx.storeItem.findUniqueOrThrow({
          where: { id: locked[0]!.id },
          include: { prices: true },
        });
        let recipientId = buyerId;
        if (recipientName !== null) {
          const target = await this.users.lockActiveByUsername(tx, recipientName);
          if (!target) throw new AppException(ErrorCode.NOT_FOUND);
          if (target.id === buyerId) {
            throw AppException.validation([{ field: 'recipient', issue: 'invalid_value' }]);
          }
          await lockUserPairIn(tx, buyerId, target.id);
          if (await blockedEitherWayIn(tx, buyerId, target.id)) throw new AppException(ErrorCode.NOT_FOUND);
          recipientId = target.id;
        }
        // D190 (§10.53): no spending while the coins are a debt (a reversed website purchase) — either currency.
        if (await inCoinDebtIn(tx, buyerId)) throw new AppException(ErrorCode.TOPUP_ACCOUNT_FROZEN);
        // D208 (§10.67): a store gift is a gift — the team's «منع إرسال الهدايا» refuses it.
        if (recipientId !== buyerId) await assertNotRestricted(tx, buyerId, 'NO_GIFTS');
        if (!item.enabled) throw unavailable('item', 'item_off');
        const price = item.prices.find((p) => p.currency === body.currency && p.days === body.days);
        if (!price) throw unavailable('days', 'not_priced');
        if (price.amount !== BigInt(body.price)) throw new AppException(ErrorCode.STORE_PRICE_CHANGED);

        await lockItemHoldersIn(tx, item.bagCode, [recipientId]);
        const [held] = await tx.$queryRaw<{ expires_at: Date | null }[]>`
          SELECT expires_at FROM user_bag_items
           WHERE user_id = ${recipientId}::uuid AND item_code = ${item.bagCode} FOR UPDATE`;
        const owned =
          held && (held.expires_at === null || held.expires_at > now) ? held.expires_at : undefined;
        if (owned === null) throw unavailable('item', 'owned_permanent');
        if (storeExpiryAfter(owned ?? null, body.days, now) === null) throw unavailable('days', 'too_far');

        const purchaseId = randomUUID();
        let balanceAfter: bigint;
        if (body.currency === 'COINS') {
          const change = await debitIn(tx, buyerId, price.amount, 'STORE_PURCHASE', purchaseId);
          if (!change) throw new AppException(ErrorCode.INSUFFICIENT_COINS);
          balanceAfter = change.coins;
        } else {
          // Cherries are the hosts' earnings: spending them in the store is a guarded debit of the cherry ledger. Owner
          // (D270): «هل يُصرف كرز المهام المقفل في المتجر؟ لا» — only the unlocked balance, exactly what a withdrawal may
          // take (the task-cherry lock, §10.46.1), checked in this transaction.
          const lock = await taskCherryLockIn(tx, buyerId, this.config.economy);
          const after = await holdCherriesIn(
            tx,
            buyerId,
            price.amount,
            purchaseId,
            now,
            lock.lockedCherries,
            'STORE_PURCHASE',
          );
          if (after === null) throw new AppException(ErrorCode.INSUFFICIENT_CHERRIES);
          balanceAfter = after;
        }
        const gift = recipientId !== buyerId;
        const added = await addItemTimeIn(tx, {
          userId: recipientId,
          item: { code: item.bagCode, category: item.kind },
          source: gift ? 'GIFT' : 'STORE',
          giftedById: gift ? buyerId : null,
          durationMs: body.days * STORE_DAY_MS,
          now,
        });
        if (added.kind === 'permanent' || added.expiresAt === null)
          throw unavailable('item', 'owned_permanent');
        const extended = added.kind === 'extended';
        await tx.storePurchase.create({
          data: {
            id: purchaseId,
            buyerId,
            recipientId,
            itemId: item.id,
            currency: body.currency,
            days: body.days,
            price: price.amount,
            balanceAfter,
            expiresAt: added.expiresAt,
            extended,
            idempotencyKey: key,
            requestHash,
            createdAt: now,
          },
        });
        if (gift) {
          // The recipient is told as for a bag send (D171): «X sent you …» with the item.
          await this.notifier.notify(tx, {
            type: 'BAG_ITEM_RECEIVED',
            recipientId,
            actorId: buyerId,
            bagItemCode: item.bagCode,
          });
        }
        await tx.auditLog.create({
          data: {
            action: AuditAction.STORE_PURCHASE,
            actorUserId: buyerId,
            targetType: 'user',
            targetId: recipientId,
            metadata: {
              purchaseId,
              itemId: item.id,
              code: item.bagCode,
              kind: item.kind,
              currency: body.currency,
              days: body.days,
              price: Number(price.amount),
              gift,
              recipientId,
              extended,
              expiresAt: added.expiresAt.toISOString(),
              via: 'api',
            },
          },
        });
        return { purchaseId };
      });
      const result = await this.resultOf(buyerId, done.purchaseId, lang);
      return { replay: false, result };
    } catch (err) {
      if (violatedUniqueIndex(err) !== null) {
        // The same key won a race: answer with its result.
        const raced = await this.findReplay(buyerId, key, requestHash, lang);
        if (raced) return { replay: true, result: raced };
      }
      throw err;
    }
  }

  private async findReplay(
    buyerId: string,
    key: string,
    requestHash: string,
    lang: ContentLanguage,
  ): Promise<StorePurchaseResultDto | null> {
    const now = this.clock.now();
    const purchase = await this.prisma.storePurchase.findFirst({
      where: {
        buyerId,
        idempotencyKey: key,
        createdAt: { gte: new Date(now.getTime() - STORE_IDEMPOTENCY_MS) },
      },
      select: { id: true, requestHash: true },
    });
    if (!purchase) return null;
    if (purchase.requestHash !== requestHash) throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
    return this.resultOf(buyerId, purchase.id, lang);
  }

  /** The purchase's answer (the first one's on a replay; the balances as they are now). */
  private async resultOf(
    buyerId: string,
    id: string,
    lang: ContentLanguage,
  ): Promise<StorePurchaseResultDto> {
    const p = await this.prisma.storePurchase.findUniqueOrThrow({
      where: { id },
      include: {
        item: {
          select: { id: true, bagCode: true, kind: true, nameAr: true, nameEn: true, ...STORE_ART_SELECT },
        },
        recipient: { select: USER_SUMMARY_SELECT },
      },
    });
    return {
      id: p.id,
      item: {
        id: p.item.id,
        code: p.item.bagCode,
        kind: p.item.kind,
        name: nameOf(lang, p.item),
        art: storeArtDto(p.item),
      },
      currency: p.currency,
      days: p.days,
      price: Number(p.price),
      recipient: p.recipientId === buyerId ? null : userSummary(p.recipient, this.clock.now()),
      expiresAt: p.expiresAt.toISOString(),
      extended: p.extended,
      balances: await balancesIn(this.prisma, buyerId, this.config.economy),
    };
  }
}

function unavailable(field: string, issue: string): AppException {
  return new AppException(ErrorCode.STORE_UNAVAILABLE, undefined, [{ field, issue }]);
}
