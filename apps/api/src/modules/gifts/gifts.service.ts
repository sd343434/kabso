import { Inject, Injectable } from '@nestjs/common';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type {
  Gift,
  GiftAnimationFormat,
  GiftBadge,
  GiftCategory,
  GiftCategoryKind,
  GiftVideoAlpha,
  PkBoosterKind,
} from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { giftArtUrl } from './gift-art.js';
import { catalogueVersion, QUIPS_CATEGORY, type GiftCategoryCode } from './gift-catalogue.js';

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
  /** The effect's size in bytes when `animationUrl` is set (the app decides whether to prefetch). */
  animationBytes: number | null;
  /** v1.46-live (D207): `animationUrl`'s format (SVGA or MP4), null exactly when it is. */
  animationFormat: GiftAnimationFormat | null;
  /** v1.46-live (D207): an MP4's transparency (NONE or SIDE_BY_SIDE), null for SVGA and without an effect. */
  animationAlpha: GiftVideoAlpha | null;
  /** v1.46-live (D207): the hosted MP3 sound played with the effect (or alone), its size and length, or null. */
  audioUrl: string | null;
  audioBytes: number | null;
  audioDurationMs: number | null;
}

/** `GiftCategoryTab` (v1.46-live, D207): a tab of the gift panel, in the reader's language. */
export interface GiftCategoryTabDto {
  code: GiftCategoryCode;
  kind: GiftCategoryKind;
  name: string;
  iconUrl: string | null;
}

/** `GiftQuip` (v1.32-live, D154): a QUIPS gift's sound and its line of text. */
export interface GiftQuipDto {
  /** The app's bundled sound. */
  soundKey: string;
  durationMs: number;
  /** The words of the line (shown as a chat bubble while it plays), or null: a sound without words. */
  text: string | null;
}

/** `Gift` (openapi v1.23-live; `tag` v1.24.3-live; hosted art v1.26.2-live; `quip` v1.32-live). */
export interface GiftDto extends GiftArtDto {
  code: string;
  category: GiftCategoryCode;
  name: string;
  priceCoins: number;
  assetKey: string;
  animationKey: string | null;
  sortOrder: number;
  badge: GiftBadge;
  tag: GiftTagDto | null;
  /** v1.32-live (D154): set exactly for a QUIPS gift. */
  quip: GiftQuipDto | null;
  /** v1.43-live (D195): the PK booster this gift activates (shown in the «PK» tab during a PK only). */
  pkBooster: PkBoosterKind | null;
}

/** `GiftCatalogue`. */
export interface GiftCatalogueDto {
  version: string;
  /** The tab codes in order (kept for apps before v1.46-live). */
  categories: GiftCategoryCode[];
  /** v1.46-live (D207): the tabs with their names and icons, in order. */
  tabs: GiftCategoryTabDto[];
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
  gift: Pick<Gift, 'imageObjectKey' | 'animationObjectKey' | 'animationBytes'> &
    Partial<Pick<Gift, 'animationFormat' | 'animationAlpha' | 'audioObjectKey' | 'audioBytes' | 'audioMs'>>,
  publicBaseUrl: string | undefined,
): GiftArtDto {
  const animationUrl = giftArtUrl(publicBaseUrl, gift.animationObjectKey);
  const audioUrl = giftArtUrl(publicBaseUrl, gift.audioObjectKey ?? null);
  const format = animationUrl === null ? null : (gift.animationFormat ?? 'SVGA');
  return {
    imageUrl: giftArtUrl(publicBaseUrl, gift.imageObjectKey),
    animationUrl,
    animationBytes: animationUrl === null ? null : gift.animationBytes,
    animationFormat: format,
    animationAlpha: format === 'MP4' ? (gift.animationAlpha ?? 'NONE') : null,
    audioUrl,
    audioBytes: audioUrl === null ? null : (gift.audioBytes ?? null),
    audioDurationMs: audioUrl === null ? null : (gift.audioMs ?? null),
  };
}

/** A category as a tab in `lang`. */
export function giftCategoryTabDto(
  row: Pick<GiftCategory, 'code' | 'kind' | 'nameAr' | 'nameEn' | 'iconObjectKey'>,
  lang: ContentLanguage,
  publicBaseUrl: string | undefined,
): GiftCategoryTabDto {
  return {
    code: row.code,
    kind: row.kind,
    name: lang === 'ar' ? row.nameAr : row.nameEn,
    iconUrl: giftArtUrl(publicBaseUrl, row.iconObjectKey),
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
    quip:
      gift.soundKey === null || gift.soundMs === null
        ? null
        : { soundKey: gift.soundKey, durationMs: gift.soundMs, text: gift.quipText },
    pkBooster: gift.pkBooster,
  };
}

/** v1.46-live (D207): by the category's tab order, then the gift's sort order and code. */
const CATALOGUE_ORDER = [
  { categoryRef: { sortOrder: 'asc' } },
  { category: 'asc' },
  { sortOrder: 'asc' },
  { code: 'asc' },
] as const;

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
   * The tabs listed now, in order: v1.46-live (D207) the enabled `gift_categories`; v1.27-live (D132) the LUCKY one
   * only while lucky gifts are on, so a gift of it is neither listed nor sendable while they are off.
   */
  async listedCategories(): Promise<GiftCategory[]> {
    const rows = await this.prisma.giftCategory.findMany({
      where: { enabled: true, ...(this.config.lucky.enabled ? {} : { kind: { not: 'LUCKY' } }) },
      orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
    });
    return rows;
  }

  /** `GET /gifts/catalogue`: enabled gifts of the listed tabs, by tab, then sort order, then code. */
  async catalogue(lang: ContentLanguage): Promise<GiftCatalogueDto> {
    const tabs = await this.listedCategories();
    const categories = tabs.map((t) => t.code);
    const gifts = await this.prisma.gift.findMany({
      where: { enabled: true, category: { in: categories } },
      orderBy: [...CATALOGUE_ORDER],
    });
    const quantities = [...this.quantities];
    return {
      version: catalogueVersion(gifts, quantities, LIVE_GIFT_COMBO_WINDOW_SECONDS, tabs),
      categories,
      tabs: tabs.map((t) => giftCategoryTabDto(t, lang, this.publicBaseUrl)),
      quantities,
      maxRecipients: LIVE_GIFT_MAX_RECIPIENTS,
      comboWindowSeconds: LIVE_GIFT_COMBO_WINDOW_SECONDS,
      data: gifts.map((g) => giftDto(g, lang, this.publicBaseUrl)),
    };
  }

  /** `GET /me/gifts/bag`: the caller's enabled gifts with a quantity above 0, in catalogue order. */
  async bag(userId: string, lang: ContentLanguage): Promise<GiftBagDto> {
    const listed = (await this.listedCategories()).map((t) => t.code);
    const rows = await this.prisma.userGiftStock.findMany({
      where: {
        userId,
        quantity: { gt: 0 },
        // v1.32-live (D154): quips are sent with coins only, so never listed in the bag.
        gift: { enabled: true, category: { in: listed.filter((c) => c !== QUIPS_CATEGORY) } },
      },
      include: { gift: true },
      orderBy: [
        { gift: { categoryRef: { sortOrder: 'asc' } } },
        { gift: { category: 'asc' } },
        { gift: { sortOrder: 'asc' } },
        { giftCode: 'asc' },
      ],
    });
    return {
      data: rows.map((r) => ({ ...giftDto(r.gift, lang, this.publicBaseUrl), quantity: r.quantity })),
    };
  }
}
