import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import type { BagItem } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { BagCategory, BagItemSource } from './bag.catalogue.js';
import type { BagQuery, EquipBody } from './bag.schemas.js';

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

function nameOf(item: Pick<BagItem, 'nameAr' | 'nameEn'>, lang: ContentLanguage): string {
  return lang === 'ar' ? item.nameAr : item.nameEn;
}

/**
 * The bag (الحقيبة, CP-019, owner D107, CONVENTIONS §10.22): the catalogue, what a user owns and
 * what they wear. Free items are given at signup by `grantFreeItemsIn` (users module, same
 * transaction as the account); others by `bag-admin grant` until a store exists. The catalogue is
 * small and server-bounded, so lists are returned whole (§5).
 */
@Injectable()
export class BagService {
  constructor(private readonly prisma: PrismaService) {}

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

  /** `GET /me/bag`: the caller's items (of the category), in catalogue order. */
  async mine(callerId: string, query: BagQuery, lang: ContentLanguage): Promise<BagDto> {
    const rows = await this.prisma.userBagItem.findMany({
      where: { userId: callerId, ...(query.category ? { category: query.category } : {}) },
      include: { item: true },
      orderBy: [{ category: 'asc' }, { item: { sortOrder: 'asc' } }, { itemCode: 'asc' }],
    });
    return {
      data: rows.map((r) => ({
        code: r.itemCode,
        category: r.category,
        name: nameOf(r.item, lang),
        assetKey: r.item.assetKey,
        acquiredAt: r.acquiredAt.toISOString(),
        source: r.source,
        equipped: r.equipped,
      })),
    };
  }

  /**
   * `PUT /me/bag/equipped {category, code}`: wears `code` (taking off what was worn in that
   * category) or, with `code: null`, wears nothing. Idempotent. 409 BAG_ITEM_NOT_OWNED: the caller
   * does not own `code` in that category (an unknown code too); nothing changes then. The caller's
   * rows of the category are locked in `item_code` order (a fixed order: no deadlock between
   * concurrent calls), so concurrent calls apply one after the other.
   */
  async equip(callerId: string, body: EquipBody, lang: ContentLanguage): Promise<BagEquippedDto> {
    const { category, code } = body;
    await this.prisma.$transaction(async (tx) => {
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

  /** What the user wears in `category`. */
  async equipped(userId: string, category: BagCategory, lang: ContentLanguage): Promise<BagEquippedDto> {
    const row = await this.prisma.userBagItem.findFirst({
      where: { userId, category, equipped: true },
      include: { item: true },
    });
    return {
      category,
      equipped: row
        ? { code: row.itemCode, name: nameOf(row.item, lang), assetKey: row.item.assetKey }
        : null,
    };
  }

  /** `PublicProfile.profileCard`: the PROFILE_CARD the user wears, or null. */
  async profileCard(userId: string): Promise<ProfileCardDto | null> {
    const row = await this.prisma.userBagItem.findFirst({
      where: { userId, category: 'PROFILE_CARD', equipped: true },
      select: { itemCode: true, item: { select: { assetKey: true } } },
    });
    return row ? { code: row.itemCode, assetKey: row.item.assetKey } : null;
  }
}
