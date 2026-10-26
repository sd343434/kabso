import { Inject, Injectable } from '@nestjs/common';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Gift, GiftBadge, GiftCategory } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { catalogueVersion, GIFT_CATEGORIES } from './gift-catalogue.js';

/**
 * A send within this many seconds of the sender's previous send of the same gift to the same
 * recipients in the same live continues its combo (CONVENTIONS §10.23).
 */
export const LIVE_GIFT_COMBO_WINDOW_SECONDS = 5;
/** At most this many recipients per send: the host and 24 seats (§10.9). */
export const LIVE_GIFT_MAX_RECIPIENTS = 25;

/** `Gift` (openapi v1.23-live). */
export interface GiftDto {
  code: string;
  category: GiftCategory;
  name: string;
  priceCoins: number;
  assetKey: string;
  animationKey: string | null;
  sortOrder: number;
  badge: GiftBadge;
}

/** `GiftCatalogue`. */
export interface GiftCatalogueDto {
  version: string;
  categories: GiftCategory[];
  quantities: number[];
  maxRecipients: number;
  comboWindowSeconds: number;
  data: GiftDto[];
}

/** `GiftBagItem`: a gift the caller holds. */
export interface GiftBagItemDto extends GiftDto {
  quantity: number;
}

/** `GiftBag`. */
export interface GiftBagDto {
  data: GiftBagItemDto[];
}

export function giftName(gift: Pick<Gift, 'nameAr' | 'nameEn'>, lang: ContentLanguage): string {
  return lang === 'ar' ? gift.nameAr : gift.nameEn;
}

export function giftDto(gift: Gift, lang: ContentLanguage): GiftDto {
  return {
    code: gift.code,
    category: gift.category,
    name: giftName(gift, lang),
    priceCoins: gift.priceCoins,
    assetKey: gift.assetKey,
    animationKey: gift.animationKey,
    sortOrder: gift.sortOrder,
    badge: gift.badge,
  };
}

const CATALOGUE_ORDER = [{ category: 'asc' }, { sortOrder: 'asc' }, { code: 'asc' }] as const;

/**
 * Live gifts: the catalogue and the gift bag (CP-020, D108, CONVENTIONS §10.23). The catalogue is
 * written only by the `gift-admin` CLI; sending is `LiveGiftsService` (live module). Both lists are
 * small and server-bounded, so they are returned whole (§5).
 */
@Injectable()
export class GiftsService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** The quantities a send may use (`LIVE_GIFT_QUANTITIES`), ascending. */
  get quantities(): readonly number[] {
    return this.config.gifts.quantities;
  }

  /** `GET /gifts/catalogue`: enabled gifts by tab, then sort order, then code. */
  async catalogue(lang: ContentLanguage): Promise<GiftCatalogueDto> {
    const gifts = await this.prisma.gift.findMany({
      where: { enabled: true },
      orderBy: [...CATALOGUE_ORDER],
    });
    const quantities = [...this.quantities];
    return {
      version: catalogueVersion(gifts, quantities, LIVE_GIFT_COMBO_WINDOW_SECONDS),
      categories: [...GIFT_CATEGORIES],
      quantities,
      maxRecipients: LIVE_GIFT_MAX_RECIPIENTS,
      comboWindowSeconds: LIVE_GIFT_COMBO_WINDOW_SECONDS,
      data: gifts.map((g) => giftDto(g, lang)),
    };
  }

  /** `GET /me/gifts/bag`: the caller's enabled gifts with a quantity above 0, in catalogue order. */
  async bag(userId: string, lang: ContentLanguage): Promise<GiftBagDto> {
    const rows = await this.prisma.userGiftStock.findMany({
      where: { userId, quantity: { gt: 0 }, gift: { enabled: true } },
      include: { gift: true },
      orderBy: [{ gift: { category: 'asc' } }, { gift: { sortOrder: 'asc' } }, { giftCode: 'asc' }],
    });
    return { data: rows.map((r) => ({ ...giftDto(r.gift, lang), quantity: r.quantity })) };
  }
}
