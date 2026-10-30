import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { BagItem, Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { Notifier } from '../notifications/notifier.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { blockedEitherWayIn, lockUserPairIn } from '../social/pair-lock.js';
import { UsersService } from '../users/users.service.js';
import { addItemTimeIn, catalogueItemIn, lockItemHoldersIn } from './bag-grants.js';
import { BAG_DAY_MS, type BagCategory, type BagItemSource } from './bag.catalogue.js';
import type { BagQuery, EquipBody, SendBody } from './bag.schemas.js';

/** `BagCatalogueItem`. */
export interface BagCatalogueItemDto {
  code: string;
  category: BagCategory;
  name: string;
  assetKey: string;
  sortOrder: number;
  free: boolean;
}

/** `BagCatalogue`. */
export interface BagCatalogueDto {
  data: BagCatalogueItemDto[];
}

/** `BagItem`: an item the caller owns. */
export interface BagOwnedItemDto {
  code: string;
  category: BagCategory;
  name: string;
  assetKey: string;
  acquiredAt: string;
  source: BagItemSource;
  equipped: boolean;
  /** v1.46-live (D171): null = permanent. */
  expiresAt: string | null;
  /** v1.46-live (D171): the giver of a GIFT, when ACTIVE and no block either way. */
  giftedBy: UserSummaryDto | null;
  /** v1.46-live (D171): free items are not. */
  transferable: boolean;
}

/** `Bag`. */
export interface BagDto {
  data: BagOwnedItemDto[];
}

/** `BagEquippedItem`. */
export interface BagEquippedItemDto {
  code: string;
  name: string;
  assetKey: string;
}

/** `BagEquipped`: what the caller wears in one category (null: nothing). */
export interface BagEquippedDto {
  category: BagCategory;
  equipped: BagEquippedItemDto | null;
}

/** `ProfileCard` on the public profile (§10.5). */
export interface ProfileCardDto {
  code: string;
  assetKey: string;
}

/** `BagTransfer` (v1.46-live, D171). */
export interface BagTransferDto {
  id: string;
  code: string;
  category: BagCategory;
  name: string;
  recipient: UserSummaryDto;
  whole: boolean;
  durationSeconds: number | null;
  remaining: BagOwnedItemDto | null;
}

function nameOf(item: Pick<BagItem, 'nameAr' | 'nameEn'>, lang: ContentLanguage): string {
  return lang === 'ar' ? item.nameAr : item.nameEn;
}

/** Owned rows that have not expired at `now` (§10.41). */
function liveWhere(now: Date): Prisma.UserBagItemWhereInput {
  return { OR: [{ expiresAt: null }, { expiresAt: { gt: now } }] };
}

const OWNED_INCLUDE = {
  item: true,
  giftedBy: { select: { ...USER_SUMMARY_SELECT, status: true } },
} as const satisfies Prisma.UserBagItemInclude;
type OwnedRow = Prisma.UserBagItemGetPayload<{ include: typeof OWNED_INCLUDE }>;

const SWEEP_BATCH = 5000;

/**
 * The bag (الحقيبة, CP-019, owner D107, CONVENTIONS §10.22; v1.46-live D171, §10.41): the
 * catalogue, what a user owns now (never an expired item) and what they wear, and sending an item
 * — whole or some days of it — to another user. Free items are given at signup by
 * `grantFreeItemsIn` (users module, same transaction as the account); others by `bag-admin grant`
 * or a send. The catalogue is small and server-bounded, so lists are returned whole (§5). A
 * sweeper deletes expired rows (reads filter them anyway).
 */
@Injectable()
export class BagService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(BagService.name);
  private sweepTimer: NodeJS.Timeout | undefined;
  private sweepInFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly notifier: Notifier,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.bag.sweepIntervalSeconds > 0) this.scheduleSweep();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.sweepTimer) clearTimeout(this.sweepTimer);
    await this.sweepInFlight?.catch(() => undefined);
  }

  /** `GET /bag/catalogue`: every item (of the category), by category then sort order. */
  async catalogue(query: BagQuery, lang: ContentLanguage): Promise<BagCatalogueDto> {
    const items = await this.prisma.bagItem.findMany({
      where: query.category ? { category: query.category } : {},
      orderBy: [{ category: 'asc' }, { sortOrder: 'asc' }, { code: 'asc' }],
    });
    return {
      data: items.map((i) => ({
        code: i.code,
        category: i.category,
        name: nameOf(i, lang),
        assetKey: i.assetKey,
        sortOrder: i.sortOrder,
        free: i.free,
      })),
    };
  }

  /** `GET /me/bag`: the caller's items owned now (of the category), in catalogue order. */
  async mine(callerId: string, query: BagQuery, lang: ContentLanguage): Promise<BagDto> {
    const rows = await this.prisma.userBagItem.findMany({
      where: {
        userId: callerId,
        ...(query.category ? { category: query.category } : {}),
        ...liveWhere(this.clock.now()),
      },
      include: OWNED_INCLUDE,
      orderBy: [{ category: 'asc' }, { item: { sortOrder: 'asc' } }, { itemCode: 'asc' }],
    });
    const visible = await this.visibleGivers(callerId, rows);
    return { data: rows.map((r) => this.ownedDto(r, lang, visible)) };
  }

  /** Givers among `rows` the caller may see: ACTIVE and no block either way (§10.41). */
  private async visibleGivers(callerId: string, rows: readonly OwnedRow[]): Promise<Set<string>> {
    const ids = [
      ...new Set(rows.flatMap((r) => (r.giftedBy && r.giftedBy.status === 'ACTIVE' ? [r.giftedBy.id] : []))),
    ];
    if (ids.length === 0) return new Set();
    const blocks = await this.prisma.userBlock.findMany({
      where: {
        OR: [
          { blockerId: callerId, blockedId: { in: ids } },
          { blockedId: callerId, blockerId: { in: ids } },
        ],
      },
      select: { blockerId: true, blockedId: true },
    });
    const hidden = new Set(blocks.map((b) => (b.blockerId === callerId ? b.blockedId : b.blockerId)));
    return new Set(ids.filter((id) => !hidden.has(id)));
  }

  private ownedDto(row: OwnedRow, lang: ContentLanguage, visibleGivers: Set<string>): BagOwnedItemDto {
    return {
      code: row.itemCode,
      category: row.category,
      name: nameOf(row.item, lang),
      assetKey: row.item.assetKey,
      acquiredAt: row.acquiredAt.toISOString(),
      source: row.source,
      equipped: row.equipped,
      expiresAt: row.expiresAt?.toISOString() ?? null,
      giftedBy: row.giftedBy && visibleGivers.has(row.giftedBy.id) ? userSummary(row.giftedBy) : null,
      transferable: !row.item.free,
    };
  }

  /**
   * `PUT /me/bag/equipped {category, code}`: wears `code` (taking off what was worn in that
   * category) or, with `code: null`, wears nothing. Idempotent. 409 BAG_ITEM_NOT_OWNED: the caller
   * does not own `code` in that category (an unknown or expired code too); nothing changes then.
   * The caller's expired rows of the category are deleted first (they are gone, §10.41); the
   * remaining rows are locked in `item_code` order (a fixed order: no deadlock between concurrent
   * calls), so concurrent calls apply one after the other.
   */
  async equip(callerId: string, body: EquipBody, lang: ContentLanguage): Promise<BagEquippedDto> {
    const { category, code } = body;
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`
        DELETE FROM user_bag_items
         WHERE user_id = ${callerId}::uuid AND category = ${category}::bag_category AND expires_at <= ${now}`;
      const rows = await tx.$queryRaw<{ item_code: string; equipped: boolean }[]>`
        SELECT item_code, equipped FROM user_bag_items
         WHERE user_id = ${callerId}::uuid AND category = ${category}::bag_category
         ORDER BY item_code
         FOR UPDATE`;
      if (code !== null && !rows.some((r) => r.item_code === code)) {
        throw new AppException(ErrorCode.BAG_ITEM_NOT_OWNED);
      }
      const worn = rows.find((r) => r.equipped)?.item_code ?? null;
      if (worn === code) return;
      if (worn !== null) {
        await tx.userBagItem.update({
          where: { userId_itemCode: { userId: callerId, itemCode: worn } },
          data: { equipped: false },
        });
      }
      if (code !== null) {
        await tx.userBagItem.update({
          where: { userId_itemCode: { userId: callerId, itemCode: code } },
          data: { equipped: true },
        });
      }
    });
    return this.equipped(callerId, category, lang);
  }

  /** What the user wears in `category` now (an expired item is not worn). */
  async equipped(userId: string, category: BagCategory, lang: ContentLanguage): Promise<BagEquippedDto> {
    const row = await this.prisma.userBagItem.findFirst({
      where: { userId, category, equipped: true, ...liveWhere(this.clock.now()) },
      include: { item: true },
    });
    return {
      category,
      equipped: row
        ? { code: row.itemCode, name: nameOf(row.item, lang), assetKey: row.item.assetKey }
        : null,
    };
  }

  /** `PublicProfile.profileCard`: the PROFILE_CARD the user wears now, or null. */
  async profileCard(userId: string): Promise<ProfileCardDto | null> {
    const row = await this.prisma.userBagItem.findFirst({
      where: { userId, category: 'PROFILE_CARD', equipped: true, ...liveWhere(this.clock.now()) },
      select: { itemCode: true, item: { select: { assetKey: true } } },
    });
    return row ? { code: row.itemCode, assetKey: row.item.assetKey } : null;
  }

  /**
   * `POST /me/bag/transfers {code, username, days?}` (v1.46-live, D171, §10.41): sends the whole
   * item (`days` absent / null) or `days × 24 h` of its remaining time to `username`. Order: 404
   * (no ACTIVE account with that username, or a block either way); 400 `username` /
   * `invalid_value` (oneself); 409 BAG_ITEM_NOT_OWNED (not owned, expired or unknown);
   * BAG_ITEM_NOT_TRANSFERABLE (a free item); BAG_SEND_PERMANENT_WHOLE_ONLY;
   * BAG_SEND_EXCEEDS_REMAINING; BAG_RECIPIENT_HAS_PERMANENT. One transaction: the user pair is
   * locked (as follows and blocks do), then both holders of the item in a fixed order, so
   * concurrent sends of one item never give away more than the caller has. The recipient's
   * notification and the ledger row are in the same transaction.
   */
  async send(callerId: string, body: SendBody, lang: ContentLanguage): Promise<BagTransferDto> {
    const now = this.clock.now();
    const sent = await this.prisma.$transaction(async (tx) => {
      const target = await this.users.lockActiveByUsername(tx, body.username);
      if (!target) throw new AppException(ErrorCode.NOT_FOUND);
      if (target.id === callerId) throw AppException.validation([{ field: 'username', issue: 'invalid_value' }]);
      await lockUserPairIn(tx, callerId, target.id);
      if (await blockedEitherWayIn(tx, callerId, target.id)) throw new AppException(ErrorCode.NOT_FOUND);
      const item = await catalogueItemIn(tx, body.code);
      if (!item) throw new AppException(ErrorCode.BAG_ITEM_NOT_OWNED);
      await lockItemHoldersIn(tx, item.code, [callerId, target.id]);
      const [mine] = await tx.$queryRaw<{ expires_at: Date | null; free: boolean }[]>`
        SELECT o.expires_at, i.free FROM user_bag_items o JOIN bag_items i ON i.code = o.item_code
         WHERE o.user_id = ${callerId}::uuid AND o.item_code = ${item.code}
           FOR UPDATE OF o`;
      if (!mine || (mine.expires_at !== null && mine.expires_at <= now)) {
        throw new AppException(ErrorCode.BAG_ITEM_NOT_OWNED);
      }
      if (mine.free) throw new AppException(ErrorCode.BAG_ITEM_NOT_TRANSFERABLE);
      const whole = body.days === undefined || body.days === null;
      let durationMs: number | null;
      if (whole) {
        durationMs = mine.expires_at === null ? null : mine.expires_at.getTime() - now.getTime();
      } else {
        if (mine.expires_at === null) throw new AppException(ErrorCode.BAG_SEND_PERMANENT_WHOLE_ONLY);
        durationMs = body.days! * BAG_DAY_MS;
        if (durationMs >= mine.expires_at.getTime() - now.getTime()) {
          throw new AppException(ErrorCode.BAG_SEND_EXCEEDS_REMAINING);
        }
      }
      const received = await addItemTimeIn(tx, {
        userId: target.id,
        item,
        source: 'GIFT',
        giftedById: callerId,
        durationMs,
        now,
      });
      if (received.kind === 'permanent') throw new AppException(ErrorCode.BAG_RECIPIENT_HAS_PERMANENT);
      let senderExpiresAt: Date | null = null;
      if (whole) {
        await tx.$executeRaw`DELETE FROM user_bag_items WHERE user_id = ${callerId}::uuid AND item_code = ${item.code}`;
      } else {
        senderExpiresAt = new Date(mine.expires_at!.getTime() - durationMs!);
        await tx.$executeRaw`
          UPDATE user_bag_items SET expires_at = ${senderExpiresAt}
           WHERE user_id = ${callerId}::uuid AND item_code = ${item.code}`;
      }
      const transfer = await tx.bagTransfer.create({
        data: {
          senderId: callerId,
          recipientId: target.id,
          itemCode: item.code,
          category: item.category,
          whole,
          durationMs: durationMs === null ? null : BigInt(durationMs),
          senderExpiresAt,
          recipientExpiresAt: received.expiresAt,
          createdAt: now,
        },
        select: { id: true },
      });
      await this.notifier.notify(tx, {
        type: 'BAG_ITEM_RECEIVED',
        recipientId: target.id,
        actorId: callerId,
        bagItemCode: item.code,
      });
      return { id: transfer.id, recipientId: target.id, item, whole, durationMs };
    });
    const [catalogue, recipient, remaining] = await Promise.all([
      this.prisma.bagItem.findUniqueOrThrow({ where: { code: sent.item.code } }),
      this.prisma.user.findUniqueOrThrow({ where: { id: sent.recipientId }, select: USER_SUMMARY_SELECT }),
      sent.whole
        ? Promise.resolve(null)
        : this.prisma.userBagItem.findUnique({
            where: { userId_itemCode: { userId: callerId, itemCode: sent.item.code } },
            include: OWNED_INCLUDE,
          }),
    ]);
    const visible = remaining ? await this.visibleGivers(callerId, [remaining]) : new Set<string>();
    return {
      id: sent.id,
      code: sent.item.code,
      category: sent.item.category,
      name: nameOf(catalogue, lang),
      recipient: userSummary(recipient),
      whole: sent.whole,
      durationSeconds: sent.durationMs === null ? null : Math.max(1, Math.floor(sent.durationMs / 1000)),
      remaining: remaining ? this.ownedDto(remaining, lang, visible) : null,
    };
  }

  // ---- Sweeper: expired items ------------------------------------------------------------------

  /** Deletes the rows of items expired at `now` (a worn one with them); returns how many. */
  async sweep(now: Date = this.clock.now()): Promise<number> {
    let total = 0;
    for (;;) {
      const n = await this.prisma.$executeRaw`
        DELETE FROM user_bag_items
         WHERE (user_id, item_code) IN (
           SELECT user_id, item_code FROM user_bag_items
            WHERE expires_at IS NOT NULL AND expires_at <= ${now}
            LIMIT ${SWEEP_BATCH})`;
      total += n;
      if (n < SWEEP_BATCH) return total;
    }
  }

  private scheduleSweep(): void {
    this.sweepTimer = setTimeout(() => {
      this.sweepInFlight = this.sweep()
        .then(() => undefined)
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Bag sweep failed');
        })
        .finally(() => {
          this.sweepInFlight = null;
          this.scheduleSweep();
        });
    }, this.config.bag.sweepIntervalSeconds * 1000);
    this.sweepTimer.unref();
  }
}
