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
import { inCoinDebtIn } from '../wallet/wallet-ledger.js';
import {
  isVipOnlyBagCategory,
  VIP_BAG_PERKS,
  vipBagCode,
  vipBagIn,
  vipBagPerkIn,
  vipBagPerkOf,
  vipNotWorn,
  vipOffPerksAfter,
  type VipBag,
  type VipBagEntry,
  type VipBagPerk,
  type VipOnlyBagCategory,
} from '../vip/vip-bag.js';
import { addItemTimeIn, catalogueItemIn, lockItemHoldersIn } from './bag-grants.js';
import {
  BAG_CATEGORIES,
  BAG_DAY_MS,
  isTransferable,
  type BagCategory,
  type BagItemSource,
} from './bag.catalogue.js';
import type { BagQuery, EquipBody, SendBody } from './bag.schemas.js';
import { assertNotRestricted } from '../users/account-control.js';
import {
  STORE_ART_SELECT,
  storeArtDto,
  storeWearOf,
  type StoreArtDto,
  type StoreWearDto,
} from '../store/store-rules.js';
import { refuseLimitedStaff } from '../live/live-staff.js';

/** `BagCatalogueItem`. */
export interface BagCatalogueItemDto {
  code: string;
  category: BagCategory;
  name: string;
  assetKey: string;
  sortOrder: number;
  free: boolean;
  /** D270 (§10.98): a store item's hosted art (absent for a bundled item: `assetKey`). */
  art?: StoreArtDto;
}

/** `BagCatalogue`. */
export interface BagCatalogueDto {
  data: BagCatalogueItemDto[];
}

/** v1.65-live (D264, §10.97): `BagItemVip` — where a VIP item comes from and its art. */
export interface BagItemVipDto {
  /** `VipTier.code` of the membership (the item may be inherited from a lower tier). */
  tier: string;
  tierName: string;
  color: string;
  /** The VIP perk code (AVATAR_FRAME, PROFILE_CARD, CHAT_BUBBLE, ENTRY_BANNER, ENTRY_EFFECT, MIC_WAVE). */
  perk: string;
  animation: string | null;
  still: string | null;
}

/** `BagItem`: an item the caller owns. */
export interface BagOwnedItemDto {
  code: string;
  category: BagCategory | VipOnlyBagCategory;
  name: string;
  assetKey: string;
  acquiredAt: string;
  /** v1.65-live (D264): `VIP` — a VIP member's tier item (derived from the membership; `vip` present). */
  source: BagItemSource | 'VIP';
  equipped: boolean;
  /** v1.48-social (D171): null = permanent. */
  expiresAt: string | null;
  /** v1.48-social (D171): the giver of a GIFT, when ACTIVE and no block either way. */
  giftedBy: UserSummaryDto | null;
  /** v1.48-social (D171): free items are not. */
  transferable: boolean;
  /** v1.65-live (D264): only on a `VIP` item. */
  vip?: BagItemVipDto;
  /** D270 (§10.98): a store item's hosted art (absent for a bundled item). */
  art?: StoreArtDto;
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
  /** D270 (§10.98): a store item's hosted art. */
  art?: StoreArtDto;
}

/** `BagEquipped`: what the caller wears in one category (null: nothing). */
export interface BagEquippedDto {
  category: BagCategory | VipOnlyBagCategory;
  equipped: BagEquippedItemDto | null;
}

/** `ProfileCard` on the public profile (§10.5). */
export interface ProfileCardDto {
  code: string;
  assetKey: string;
}

/** `BagTransfer` (v1.48-social, D171). */
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

/** Owned rows that have not expired at `now` (§10.45). */
function liveWhere(now: Date): Prisma.UserBagItemWhereInput {
  return { OR: [{ expiresAt: null }, { expiresAt: { gt: now } }] };
}

const OWNED_INCLUDE = {
  item: { include: { storeItem: { select: STORE_ART_SELECT } } },
  giftedBy: { select: { ...USER_SUMMARY_SELECT, status: true } },
} as const satisfies Prisma.UserBagItemInclude;
type OwnedRow = Prisma.UserBagItemGetPayload<{ include: typeof OWNED_INCLUDE }>;

const SWEEP_BATCH = 5000;

/** v1.65-live (D264): the categories in display order (stored first, then the VIP-only ones). */
const CATEGORY_ORDER: readonly string[] = [...new Set([...BAG_CATEGORIES, ...Object.values(VIP_BAG_PERKS)])];

/** v1.65-live (D264): a VIP item as a `BagItem` (its time is the membership's; never sent). */
function vipItemDto(
  bag: VipBag,
  item: VipBagEntry,
  equipped: boolean,
  lang: ContentLanguage,
): BagOwnedItemDto {
  return {
    code: vipBagCode(item.perk),
    category: item.category,
    name: lang === 'ar' ? item.titleAr : item.titleEn,
    assetKey: `vip_${item.perk.toLowerCase()}`,
    acquiredAt: bag.startedAt.toISOString(),
    source: 'VIP',
    equipped,
    expiresAt: bag.expiresAt.toISOString(),
    giftedBy: null,
    transferable: false,
    vip: {
      tier: bag.tier.code,
      tierName: lang === 'ar' ? bag.tier.nameAr : bag.tier.nameEn,
      color: bag.tier.color,
      perk: item.perk,
      animation: item.animation,
      still: item.still,
    },
  };
}

/**
 * The bag (الحقيبة, CP-019, owner D107, CONVENTIONS §10.22; v1.48-social D171, §10.45): the
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
    // v1.65-live (D264): VIP items are not in the catalogue (they come with a membership).
    if (query.category && isVipOnlyBagCategory(query.category)) return { data: [] };
    const category = query.category;
    const items = await this.prisma.bagItem.findMany({
      where: category ? { category } : {},
      include: { storeItem: { select: STORE_ART_SELECT } },
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
        ...(i.storeItem ? { art: storeArtDto(i.storeItem) } : {}),
      })),
    };
  }

  /**
   * `GET /me/bag`: the caller's items owned now (of the category), in catalogue order. v1.65-live (D264, §10.97): a VIP
   * member's tier items too (source `VIP`, first in their category), derived from the active membership.
   */
  async mine(callerId: string, query: BagQuery, lang: ContentLanguage): Promise<BagDto> {
    const now = this.clock.now();
    const category = query.category;
    const rows =
      category && isVipOnlyBagCategory(category)
        ? []
        : await this.prisma.userBagItem.findMany({
            where: {
              userId: callerId,
              ...(category ? { category } : {}),
              ...liveWhere(now),
            },
            include: OWNED_INCLUDE,
            orderBy: [{ category: 'asc' }, { item: { sortOrder: 'asc' } }, { itemCode: 'asc' }],
          });
    const visible = await this.visibleGivers(callerId, rows);
    const owned = rows.map((r) => this.ownedDto(r, lang, visible));
    const vip = await vipBagIn(this.prisma, callerId, now);
    if (!vip) return { data: owned };
    // One worn item per kind: a VIP item is worn unless taken off or a bag item of its kind is worn (that one shows).
    const bagWorn = await this.wornCategories(callerId, now);
    const notWorn = vipNotWorn(vip.off, bagWorn);
    const vipItems = vip.items
      .filter((i) => !category || i.category === category)
      .map((i) => vipItemDto(vip, i, !notWorn.includes(i.perk), lang));
    const rank = (c: string) => CATEGORY_ORDER.indexOf(c);
    // A stable order: by category, the VIP item first in its category, then the stored rows as read.
    const data = [...vipItems, ...owned]
      .map((item, i) => ({ item, i }))
      .sort((a, b) => rank(a.item.category) - rank(b.item.category) || a.i - b.i)
      .map((x) => x.item);
    return { data };
  }

  /** Givers among `rows` the caller may see: ACTIVE and no block either way (§10.45). */
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
      transferable: isTransferable(row.item.free, row.source, row.expiresAt),
      ...(row.item.storeItem ? { art: storeArtDto(row.item.storeItem) } : {}),
    };
  }

  /**
   * `PUT /me/bag/equipped {category, code}`: wears `code` (taking off what was worn in that
   * category) or, with `code: null`, wears nothing. Idempotent. 409 BAG_ITEM_NOT_OWNED: the caller
   * does not own `code` in that category (an unknown or expired code too); nothing changes then.
   * The caller's expired rows of the category are deleted first (they are gone, §10.45); the
   * remaining rows are locked in `item_code` order (a fixed order: no deadlock between concurrent
   * calls), so concurrent calls apply one after the other.
   */
  async equip(callerId: string, body: EquipBody, lang: ContentLanguage): Promise<BagEquippedDto> {
    const { code } = body;
    // v1.71-live (D283, §10.96.10; owner «لا يمكنه وضع اطار غيره ويبقى مثبت»): a Kabso Team account wears the team
    // frame, locked — no other frame (taking one off is harmless and allowed).
    if (body.category === 'AVATAR_FRAME' && code !== null)
      await refuseLimitedStaff(this.prisma, callerId, 'frame');
    const now = this.clock.now();
    // v1.65-live (D264, §10.97): a VIP item (`vip:<PERK>`), or a VIP-only category.
    const vipPerk = vipBagPerkIn(body.category);
    if (isVipOnlyBagCategory(body.category) || (code !== null && code.startsWith('vip:'))) {
      const perk = code === null ? vipPerk : vipBagPerkOf(code);
      if (perk === null || VIP_BAG_PERKS[perk] !== body.category) {
        throw new AppException(ErrorCode.BAG_ITEM_NOT_OWNED);
      }
      await this.prisma.$transaction(async (tx) => {
        const held = await this.lockVipBagIn(tx, callerId, now);
        if (code !== null && !held?.items.some((i) => i.perk === perk)) {
          throw new AppException(ErrorCode.BAG_ITEM_NOT_OWNED);
        }
        if (held) await this.setVipWornIn(tx, callerId, held, perk, code !== null);
        // One worn item per kind: wearing the VIP frame or card takes off the bag item worn of that kind.
        if (code !== null && !isVipOnlyBagCategory(body.category)) {
          await tx.userBagItem.updateMany({
            where: { userId: callerId, category: body.category, equipped: true },
            data: { equipped: false },
          });
        }
      });
      return this.equipped(callerId, body.category, lang);
    }
    const category = body.category;
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
      // v1.65-live (D264): one worn item per kind — wearing a bag item (or nothing) in a category with a VIP item takes
      // the VIP one off (a renewal or an upgrade keeps that choice).
      if (vipPerk !== null) {
        const held = await this.lockVipBagIn(tx, callerId, now);
        if (held) await this.setVipWornIn(tx, callerId, held, vipPerk, false);
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

  /** v1.65-live (D264): the stored categories in which the user wears an item now. */
  private async wornCategories(userId: string, now: Date): Promise<string[]> {
    const rows = await this.prisma.userBagItem.findMany({
      where: { userId, equipped: true, ...liveWhere(now) },
      select: { category: true },
    });
    return rows.map((r) => r.category);
  }

  /** v1.65-live (D264): locks the caller's membership row (a purchase upserts it) and reads their VIP bag. */
  private async lockVipBagIn(
    tx: Prisma.TransactionClient,
    userId: string,
    now: Date,
  ): Promise<VipBag | null> {
    await tx.$queryRaw`SELECT 1 FROM vip_memberships WHERE user_id = ${userId}::uuid FOR UPDATE`;
    return vipBagIn(tx, userId, now);
  }

  /** v1.65-live (D264): wears or takes off the VIP item of [perk] (only what the member took off is stored). */
  private async setVipWornIn(
    tx: Prisma.TransactionClient,
    userId: string,
    bag: VipBag,
    perk: VipBagPerk,
    wear: boolean,
  ): Promise<void> {
    const off = vipOffPerksAfter(bag.off, perk, wear);
    if (off.length === bag.off.length && off.every((p, i) => p === bag.off[i])) return;
    await tx.vipMembership.update({ where: { userId }, data: { offPerks: off } });
  }

  /**
   * What the user wears in `category` now (an expired item is not worn). v1.65-live (D264): a bag frame worn wins over
   * the VIP frame; otherwise the category's VIP item while not taken off.
   */
  async equipped(
    userId: string,
    category: BagCategory | VipOnlyBagCategory,
    lang: ContentLanguage,
  ): Promise<BagEquippedDto> {
    const now = this.clock.now();
    const row = isVipOnlyBagCategory(category)
      ? null
      : await this.prisma.userBagItem.findFirst({
          where: { userId, category, equipped: true, ...liveWhere(now) },
          include: { item: { include: { storeItem: { select: STORE_ART_SELECT } } } },
        });
    if (row) {
      return {
        category,
        equipped: {
          code: row.itemCode,
          name: nameOf(row.item, lang),
          assetKey: row.item.assetKey,
          ...(row.item.storeItem ? { art: storeArtDto(row.item.storeItem) } : {}),
        },
      };
    }
    const perk = vipBagPerkIn(category);
    const vip = perk === null ? null : await vipBagIn(this.prisma, userId, now);
    const item = vip?.items.find((i) => i.perk === perk && i.on);
    if (!vip || !item) return { category, equipped: null };
    const dto = vipItemDto(vip, item, true, lang);
    return { category, equipped: { code: dto.code, name: dto.name, assetKey: dto.assetKey } };
  }

  /**
   * D270 (§10.98): what the user wears now from the bag — every stored category worn (one worn item per kind: it
   * covers the VIP item of that kind) and the store items' art (`PublicProfile.wear`).
   */
  async wornNow(userId: string): Promise<{ categories: string[]; wear: StoreWearDto | null }> {
    const now = this.clock.now();
    const rows = await this.prisma.userBagItem.findMany({
      where: { userId, equipped: true, ...liveWhere(now) },
      select: {
        category: true,
        itemCode: true,
        expiresAt: true,
        item: { select: { storeItem: { select: STORE_ART_SELECT } } },
      },
    });
    return { categories: rows.map((r) => r.category), wear: storeWearOf(rows, now) };
  }

  /** `PublicProfile.profileCard`: the PROFILE_CARD the user wears now (D270: a bundled one; a store card is `wear`), or null. */
  async profileCard(userId: string): Promise<ProfileCardDto | null> {
    const row = await this.prisma.userBagItem.findFirst({
      where: {
        userId,
        category: 'PROFILE_CARD',
        equipped: true,
        item: { storeItem: { is: null } },
        ...liveWhere(this.clock.now()),
      },
      select: { itemCode: true, item: { select: { assetKey: true } } },
    });
    return row ? { code: row.itemCode, assetKey: row.item.assetKey } : null;
  }

  /** v1.55-social (D186): `PublicProfile.avatarFrame` — the AVATAR_FRAME the user wears now (D270: bundled), or null. */
  async avatarFrame(userId: string): Promise<ProfileCardDto | null> {
    const row = await this.prisma.userBagItem.findFirst({
      where: {
        userId,
        category: 'AVATAR_FRAME',
        equipped: true,
        item: { storeItem: { is: null } },
        ...liveWhere(this.clock.now()),
      },
      select: { itemCode: true, item: { select: { assetKey: true } } },
    });
    return row ? { code: row.itemCode, assetKey: row.item.assetKey } : null;
  }

  /**
   * `POST /me/bag/transfers {code, username, days?}` (v1.48-social, D171, §10.45): sends the whole
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
      if (target.id === callerId)
        throw AppException.validation([{ field: 'username', issue: 'invalid_value' }]);
      await lockUserPairIn(tx, callerId, target.id);
      if (await blockedEitherWayIn(tx, callerId, target.id)) throw new AppException(ErrorCode.NOT_FOUND);
      // v1.59-social (D190): no bag gift while the caller's coins are a debt (a reversed website purchase).
      if (await inCoinDebtIn(tx, callerId)) throw new AppException(ErrorCode.TOPUP_ACCOUNT_FROZEN);
      // v1.72-social (D208, §10.67): the team's «منع إرسال الهدايا» (a bag item sent is a gift too).
      await assertNotRestricted(tx, callerId, 'NO_GIFTS');
      const item = await catalogueItemIn(tx, body.code);
      if (!item) throw new AppException(ErrorCode.BAG_ITEM_NOT_OWNED);
      await lockItemHoldersIn(tx, item.code, [callerId, target.id]);
      const [mine] = await tx.$queryRaw<{ expires_at: Date | null; free: boolean; source: string }[]>`
        SELECT o.expires_at, i.free, o.source::text AS source FROM user_bag_items o JOIN bag_items i ON i.code = o.item_code
         WHERE o.user_id = ${callerId}::uuid AND o.item_code = ${item.code}
           FOR UPDATE OF o`;
      if (!mine || (mine.expires_at !== null && mine.expires_at <= now)) {
        throw new AppException(ErrorCode.BAG_ITEM_NOT_OWNED);
      }
      if (!isTransferable(mine.free, mine.source, mine.expires_at))
        throw new AppException(ErrorCode.BAG_ITEM_NOT_TRANSFERABLE);
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
