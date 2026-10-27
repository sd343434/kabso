import { Inject, Injectable } from '@nestjs/common';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Gift, GiftBadge, GiftCategory } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { giftArtUrl } from './gift-art.js';
import { catalogueVersion, GIFT_CATEGORIES } from './gift-catalogue.js';

/**
 * A send within this many seconds of the sender's previous send of the same gift to the same
 * recipients in the same live continues its combo (CONVENTIONS §10.23).
 */
export const LIVE_GIFT_COMBO_WINDOW_SECONDS = 5;
/** At most this many recipients per send: the host and 24 seats (§10.9). */
export const LIVE_GIFT_MAX_RECIPIENTS = 25;

/** `GiftTag` (v1.24.3-live): a gift's sub-category, its name in the reader's language. */
export interface GiftTagDto {
  code: string;
  name: string;
}

/** The hosted art of a gift (v1.26.2-live, D126): public URLs, null when there is none. */
export interface GiftArtDto {
  imageUrl: string | null;
  animationUrl: string | null;
  /** The SVGA's size in bytes when `animationUrl` is set (the app decides whether to prefetch). */
  animationBytes: number | null;
}

/** `Gift` (openapi v1.23-live; `tag` v1.24.3-live; hosted art v1.26.2-live). */
export interface GiftDto extends GiftArtDto {
  code: string;
  category: GiftCategory;
  name: string;
  priceCoins: number;
  assetKey: string;
  animationKey: string | null;
  sortOrder: number;
  badge: GiftBadge;
  tag: GiftTagDto | null;
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

/** The gift's tag in `lang`, or null (none, or an incomplete row the CHECK forbids anyway). */
export function giftTagDto(
  gift: Pick<Gift, 'tagCode' | 'tagNameAr' | 'tagNameEn'>,
  lang: ContentLanguage,
): GiftTagDto | null {
  const name = lang === 'ar' ? gift.tagNameAr : gift.tagNameEn;
  if (gift.tagCode === null || name === null) return null;
  return { code: gift.tagCode, name };
}

/**
 * A gift's hosted art as public URLs under `MEDIA_PUBLIC_BASE_URL` (all null without that setting:
 * the app then uses its bundled files). `animationBytes` only with an `animationUrl`.
 */
export function giftArtDto(
  gift: Pick<Gift, 'imageObjectKey' | 'animationObjectKey' | 'animationBytes'>,
  publicBaseUrl: string | undefined,
): GiftArtDto {
  const animationUrl = giftArtUrl(publicBaseUrl, gift.animationObjectKey);
  return {
    imageUrl: giftArtUrl(publicBaseUrl, gift.imageObjectKey),
    animationUrl,
    animationBytes: animationUrl === null ? null : gift.animationBytes,
  };
}

export function giftDto(gift: Gift, lang: ContentLanguage, publicBaseUrl: string | undefined): GiftDto {
  return {
    code: gift.code,
    category: gift.category,
    name: giftName(gift, lang),
    priceCoins: gift.priceCoins,
    assetKey: gift.assetKey,
    animationKey: gift.animationKey,
    ...giftArtDto(gift, publicBaseUrl),
    sortOrder: gift.sortOrder,
    badge: gift.badge,
    tag: giftTagDto(gift, lang),
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

  /** Where the hosted gift art is served (`MEDIA_PUBLIC_BASE_URL`), or undefined. */
  get publicBaseUrl(): string | undefined {
    return this.config.media.publicBaseUrl;
  }

  /** The quantities a send may use (`LIVE_GIFT_QUANTITIES`), ascending. */
  get quantities(): readonly number[] {
    return this.config.gifts.quantities;
  }

  /**
   * The tabs listed now: v1.27-live (D132) `LUCKY` only while lucky gifts are on, so a gift of it is
   * neither listed nor sendable while they are off.
   */
  get listedCategories(): readonly GiftCategory[] {
    return this.config.lucky.enabled ? GIFT_CATEGORIES : GIFT_CATEGORIES.filter((c) => c !== 'LUCKY');
  }

  /** `GET /gifts/catalogue`: enabled gifts by tab, then sort order, then code. */
  async catalogue(lang: ContentLanguage): Promise<GiftCatalogueDto> {
    const categories = [...this.listedCategories];
    const gifts = await this.prisma.gift.findMany({
      where: { enabled: true, category: { in: categories } },
      orderBy: [...CATALOGUE_ORDER],
    });
    const quantities = [...this.quantities];
    return {
      version: catalogueVersion(gifts, quantities, LIVE_GIFT_COMBO_WINDOW_SECONDS, categories),
      categories,
      quantities,
      maxRecipients: LIVE_GIFT_MAX_RECIPIENTS,
      comboWindowSeconds: LIVE_GIFT_COMBO_WINDOW_SECONDS,
      data: gifts.map((g) => giftDto(g, lang, this.publicBaseUrl)),
    };
  }

  /** `GET /me/gifts/bag`: the caller's enabled gifts with a quantity above 0, in catalogue order. */
  async bag(userId: string, lang: ContentLanguage): Promise<GiftBagDto> {
    const rows = await this.prisma.userGiftStock.findMany({
      where: {
        userId,
        quantity: { gt: 0 },
        gift: { enabled: true, category: { in: [...this.listedCategories] } },
      },
      include: { gift: true },
      orderBy: [{ gift: { category: 'asc' } }, { gift: { sortOrder: 'asc' } }, { giftCode: 'asc' }],
    });
    return {
      data: rows.map((r) => ({ ...giftDto(r.gift, lang, this.publicBaseUrl), quantity: r.quantity })),
    };
  }
}
