import { eventGiftListedWhere } from '../programs/gift-events.js';
import { Inject, Injectable } from '@nestjs/common';
import { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
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
import {
  catalogueVersion,
  CUSTOM_CATEGORY,
  QUIPS_CATEGORY,
  type GiftCategoryCode,
} from './gift-catalogue.js';
import { activeItemBadges, legacyGiftBadge, type ItemBadgeDto } from './item-badges.js';
import {
  globalStripsDefaultsOf,
  luckyMultipliersOf,
  readGlobalStrips,
} from '../site-settings/global-strips.rules.js';

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
  /** Deprecated v1.79-live (D289): an older app's single badge, from the running `badges`. */
  badge: GiftBadge;
  /** v1.79-live (D289, §10.102): the badges running now, in display priority. */
  badges: ItemBadgeDto[];
  tag: GiftTagDto | null;
  /** v1.32-live (D154): set exactly for a QUIPS gift. */
  quip: GiftQuipDto | null;
  /** v1.43-live (D195): the PK booster this gift activates (shown in the «PK» tab during a PK only). */
  pkBooster: PkBoosterKind | null;
  /**
   * v1.100-social (D312, §10.118): a CUSTOM gift's owner «صاحب الهدية» (name and avatar on the gift); absent for every
   * other gift.
   */
  owner?: GiftOwnerDto;
}

/** `GiftOwner` (v1.100-social, D312): who a custom gift belongs to, as the gift panel shows it. */
export interface GiftOwnerDto {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
}

/** The owner columns the catalogue reads with a gift. */
export const GIFT_OWNER_INCLUDE = {
  owner: {
    select: { id: true, profile: { select: { username: true, displayName: true, avatarUrl: true } } },
  },
} as const;

type GiftOwnerRow = {
  owner?: {
    id: string;
    profile: { username: string; displayName: string; avatarUrl: string | null } | null;
  } | null;
};

/** The owner of a gift read with {@link GIFT_OWNER_INCLUDE}, or undefined. */
export function giftOwnerDto(gift: GiftOwnerRow): GiftOwnerDto | undefined {
  const o = gift.owner;
  if (!o?.profile) return undefined;
  return {
    id: o.id,
    username: o.profile.username,
    displayName: o.profile.displayName,
    avatarUrl: o.profile.avatarUrl,
  };
}

/** `GiftCatalogue`. */
/** v1.89-live (D318): how long the lucky chat threshold is cached (as the strips', D305). */
const LUCKY_CHAT_CACHE_MS = 30_000;

export interface GiftCatalogueDto {
  version: string;
  /** The tab codes in order (kept for apps before v1.46-live). */
  categories: GiftCategoryCode[];
  /** v1.46-live (D207): the tabs with their names and icons, in order. */
  tabs: GiftCategoryTabDto[];
  quantities: number[];
  maxRecipients: number;
  comboWindowSeconds: number;
  /** v1.89-live (D318, §10.121): a lucky win has a chat line from this multiplier (the panel's value, else the config). */
  luckyChatMinMultiplier: number;
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

export function giftDto(
  gift: Gift & GiftOwnerRow,
  lang: ContentLanguage,
  publicBaseUrl: string | undefined,
  now = new Date(),
): GiftDto {
  const badges = activeItemBadges(gift, now);
  const owner = giftOwnerDto(gift);
  return {
    code: gift.code,
    category: gift.category,
    name: giftName(gift, lang),
    priceCoins: gift.priceCoins,
    assetKey: gift.assetKey,
    animationKey: gift.animationKey,
    ...giftArtDto(gift, publicBaseUrl),
    sortOrder: gift.sortOrder,
    badge: legacyGiftBadge(badges.map((b) => b.code)),
    badges,
    tag: giftTagDto(gift, lang),
    quip:
      gift.soundKey === null || gift.soundMs === null
        ? null
        : { soundKey: gift.soundKey, durationMs: gift.soundMs, text: gift.quipText },
    pkBooster: gift.pkBooster,
    ...(owner ? { owner } : {}),
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
    private readonly storageSettings: StorageSettingsStore,
  ) {}

  /** Where the hosted gift art is served (the panel's «التخزين» base URL when on, D222, else `MEDIA_PUBLIC_BASE_URL`). */
  get publicBaseUrl(): string | undefined {
    return this.storageSettings.current().publicBaseUrl;
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

  /**
   * `GET /gifts/catalogue`: enabled gifts of the listed tabs, by tab, then sort order, then code. v1.100-social (D312):
   * the «مُخصَّص» tab only when it holds a listed gift (an older app shows an unknown kind as a plain, empty tab).
   */
  async catalogue(lang: ContentLanguage): Promise<GiftCatalogueDto> {
    const listed = await this.listedCategories();
    const categories0 = listed.map((t) => t.code);
    const gifts = await this.prisma.gift.findMany({
      // v1.100-social (D312): a custom gift is listed while its owner is an ACTIVE account (it is not sendable otherwise).
      where: {
        enabled: true,
        category: { in: categories0 },
        OR: [{ ownerUserId: null }, { owner: { status: 'ACTIVE' } }],
        // v1.101-social (D325): an event's own gift only while its event runs.
        AND: [eventGiftListedWhere(new Date())],
      },
      include: GIFT_OWNER_INCLUDE,
      orderBy: [...CATALOGUE_ORDER],
    });
    const tabs = listed.filter((t) => t.kind !== 'CUSTOM' || gifts.some((g) => g.category === t.code));
    const categories = tabs.map((t) => t.code);
    const quantities = [...this.quantities];
    const now = new Date();
    const versioned = gifts.map((g) => {
      const o = giftOwnerDto(g);
      return { ...g, ownerShown: o ? [o.id, o.username, o.displayName, o.avatarUrl] : null };
    });
    const luckyChatMinMultiplier = await this.luckyChatMinMultiplier();
    return {
      version: catalogueVersion(
        versioned,
        quantities,
        LIVE_GIFT_COMBO_WINDOW_SECONDS,
        tabs,
        now,
        luckyChatMinMultiplier,
      ),
      categories,
      tabs: tabs.map((t) => giftCategoryTabDto(t, lang, this.publicBaseUrl)),
      quantities,
      maxRecipients: LIVE_GIFT_MAX_RECIPIENTS,
      comboWindowSeconds: LIVE_GIFT_COMBO_WINDOW_SECONDS,
      luckyChatMinMultiplier,
      data: gifts.map((g) => giftDto(g, lang, this.publicBaseUrl, now)),
    };
  }

  private luckyChat: { readonly at: number; readonly value: number } | null = null;

  /**
   * v1.89-live (D318): the lucky chat threshold — the OWNER's (`site_settings` `globalStrips`, the panel), else
   * `LUCKY_CHAT_MIN_MULTIPLIER`; cached 30 s like the strips' thresholds.
   */
  async luckyChatMinMultiplier(): Promise<number> {
    const now = Date.now();
    if (this.luckyChat && now - this.luckyChat.at < LUCKY_CHAT_CACHE_MS) return this.luckyChat.value;
    const { luckyChatMinMultiplier: value } = await readGlobalStrips(
      this.prisma,
      globalStripsDefaultsOf(this.config),
      luckyMultipliersOf(this.config),
    );
    this.luckyChat = { at: now, value };
    return value;
  }

  /** Forgets the cached lucky chat threshold (tests). */
  forgetLuckyChat(): void {
    this.luckyChat = null;
  }

  /**
   * `GET /me/gifts/bag`: the caller's enabled gifts with a quantity above 0, in catalogue order; v1.102-social (D338) and
   * an archived gift's pieces until they run out.
   */
  async bag(userId: string, lang: ContentLanguage): Promise<GiftBagDto> {
    const listed = (await this.listedCategories()).map((t) => t.code);
    const rows = await this.prisma.userGiftStock.findMany({
      where: {
        userId,
        quantity: { gt: 0 },
        // v1.32-live (D154): quips are sent with coins only, so never listed in the bag; v1.100-social (D312) nor
        // custom gifts.
        // v1.102-social (D338, §10.131): an archived gift's pieces stay listed until they are sent (owner: «مخفية الا ان
        // تنتهي من حقيبة المستخدمين ثم تحذف»); a gift only switched off is not.
        gift: {
          OR: [{ enabled: true }, { archivedAt: { not: null } }],
          category: { in: listed.filter((c) => c !== QUIPS_CATEGORY && c !== CUSTOM_CATEGORY) },
        },
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
