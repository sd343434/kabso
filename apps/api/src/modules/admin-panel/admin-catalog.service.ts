import { Inject, Injectable, Logger } from '@nestjs/common';
import { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
import { AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { GiftBadge, EventMetric } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { BagAdminError, grantBagItemByAdminIn, revokeBagItemByAdminIn } from '../bag/bag-admin-rules.js';
import { HOST_FRAME_CODES } from '../bag/bag.catalogue.js';
import { addGiftByAdminIn, setGiftEnabledByAdminIn, updateGiftByAdminIn } from '../gifts/gift-admin-rules.js';
import {
  GiftArtError,
  giftAnimationFile,
  giftArtUrl,
  giftAudioFile,
  giftCategoryIconFile,
  GIFT_ANIMATION_MAX_BYTES,
  GIFT_AUDIO_MAX_BYTES,
  giftVideoFile,
  panelGiftImageFile,
  uploadGiftArt,
} from '../gifts/gift-art.js';
import {
  addGiftCategoryIn,
  deleteGiftCategoryIn,
  GiftCategoryError,
  giftCategoriesWithCounts,
  setGiftCategoryEnabledIn,
  updateGiftCategoryIn,
} from '../gifts/gift-categories.js';
import {
  compareGifts,
  GIFT_CATEGORY_CODE_PATTERN,
  GIFT_CODE_PATTERN,
  giftFieldProblems,
  GiftFieldsError,
  type GiftFields,
} from '../gifts/gift-catalogue.js';
import { activeBannerWhere, BANNER_ORDER, removeBannerIn, setBannerEnabledIn } from '../home/home-banners.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import {
  changeEventByAdminIn,
  createEventByAdminIn,
  EventAdminError,
  eventState,
  type EventChange,
} from '../programs/event-admin-rules.js';
import { parsePrizeText } from '../programs/programs-rules.js';
import type { AdminContext } from './admin-auth.service.js';
import { refused, viaOf } from './admin-users.service.js';

async function rule<T>(step: () => Promise<T>): Promise<T> {
  try {
    return await step();
  } catch (err) {
    if (
      err instanceof GiftFieldsError ||
      err instanceof GiftCategoryError ||
      err instanceof GiftArtError ||
      err instanceof BagAdminError ||
      err instanceof EventAdminError
    ) {
      throw refused(err.message);
    }
    throw err;
  }
}

export interface GiftInput {
  category?: string | undefined;
  nameAr?: string | undefined;
  nameEn?: string | undefined;
  priceCoins?: number | undefined;
  assetKey?: string | undefined;
  animationKey?: string | null | undefined;
  sortOrder?: number | undefined;
  badge?: GiftBadge | undefined;
  tagCode?: string | null | undefined;
  tagNameAr?: string | null | undefined;
  tagNameEn?: string | null | undefined;
  soundKey?: string | null | undefined;
  soundMs?: number | null | undefined;
  quipText?: string | null | undefined;
  /** v1.71-social (D207): uploaded files (`POST /admin/gift-uploads`); null removes. */
  imageObjectKey?: string | null | undefined;
  animationObjectKey?: string | null | undefined;
  animationAlpha?: 'NONE' | 'SIDE_BY_SIDE' | undefined;
  audioObjectKey?: string | null | undefined;
}

export interface GiftCategoryInput {
  nameAr?: string | undefined;
  nameEn?: string | undefined;
  sortOrder?: number | undefined;
  enabled?: boolean | undefined;
  iconObjectKey?: string | null | undefined;
}

export type GiftUploadKind = 'image' | 'animation' | 'sound' | 'icon';

/** The fields given (undefined = not given), as the catalogue's `Partial<GiftFields>`. */
function given(input: GiftInput): Partial<GiftFields> {
  const {
    imageObjectKey: _i,
    animationObjectKey: _a,
    animationAlpha: _al,
    audioObjectKey: _s,
    ...rest
  } = input;
  return Object.fromEntries(Object.entries(rest).filter(([, v]) => v !== undefined));
}

/**
 * «الهدايا والعناصر» in the panel v2 (v1.65-social, D197, CONVENTIONS §10.60.4): the gift catalogue (price, bundled
 * image / animation keys, the LUCKY category, badge, sub-category tag; hosted art stays with `gift-admin --image`),
 * bag items (frames and profile cards) given to or taken from a user, the home / room / tasks / wallet banners
 * (on, off, removed; new ones need a picture upload: `banner-admin add`) and the Event Center's events — each change
 * through the CLI's own rule (gift-admin-rules, bag-admin-rules, home-banners, event-admin-rules), audited with
 * `via: panel` and the reason.
 */
@Injectable()
export class AdminCatalogService {
  private readonly logger = new Logger(AdminCatalogService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly storageSettings: StorageSettingsStore,
  ) {}

  private usd(coins: number): string {
    return ((coins * this.config.economy.coinRetailUsdPerMillion) / 1_000_000).toFixed(2);
  }

  // ---- gifts ----------------------------------------------------------------------------------------------------

  async gifts() {
    const [rows, sends, tabs] = await Promise.all([
      this.prisma.gift.findMany(),
      this.prisma.liveGift.groupBy({ by: ['giftCode'], _count: true, _sum: { totalCoins: true } }),
      this.prisma.giftCategory.findMany({ orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }] }),
    ]);
    const used = new Map(sends.map((s) => [s.giftCode, s]));
    const storage = await this.storageSettings.resolved();
    const base = storage.publicBaseUrl;
    const order = tabs.map((t) => t.code);
    return {
      coinRetailUsdPerMillion: this.config.economy.coinRetailUsdPerMillion,
      // v1.71-social (D207): the categories (for the form's choice), in tab order.
      categories: tabs.map((t) => ({
        code: t.code,
        kind: t.kind,
        nameAr: t.nameAr,
        nameEn: t.nameEn,
        enabled: t.enabled,
      })),
      // v1.71-social (D207): whether uploads can be stored (S3 settings present) and shown (public URL set).
      // v1.75-social (D222): the panel's «التخزين» when it is on, else the server's S3_*.
      uploads: {
        storage: storage.s3 !== null,
        publicUrls: base !== undefined,
      },
      data: rows
        .sort((a, b) => compareGifts(a, b, order))
        .map((g) => ({
          code: g.code,
          category: g.category,
          nameAr: g.nameAr,
          nameEn: g.nameEn,
          priceCoins: g.priceCoins,
          priceUsd: this.usd(g.priceCoins),
          assetKey: g.assetKey,
          animationKey: g.animationKey,
          imageUrl: giftArtUrl(base, g.imageObjectKey),
          hostedAnimation: g.animationObjectKey !== null,
          imageObjectKey: g.imageObjectKey,
          animationObjectKey: g.animationObjectKey,
          animationUrl: giftArtUrl(base, g.animationObjectKey),
          animationFormat: g.animationObjectKey === null ? null : (g.animationFormat ?? 'SVGA'),
          animationAlpha: g.animationAlpha,
          animationBytes: g.animationBytes,
          audioObjectKey: g.audioObjectKey,
          audioUrl: giftArtUrl(base, g.audioObjectKey),
          audioMs: g.audioMs,
          sortOrder: g.sortOrder,
          badge: g.badge,
          lucky: g.category === 'LUCKY',
          tagCode: g.tagCode,
          tagNameAr: g.tagNameAr,
          tagNameEn: g.tagNameEn,
          soundKey: g.soundKey,
          soundMs: g.soundMs,
          quipText: g.quipText,
          enabled: g.enabled,
          sends: used.get(g.code)?._count ?? 0,
          coinsSpent: Number(used.get(g.code)?._sum.totalCoins ?? 0n),
        })),
    };
  }

  /**
   * v1.71-social (D207): the gift fields set by uploaded files named in a create / update body — each key must be
   * one `POST /admin/gift-uploads` answered for this gift (its folder) and exist in storage; the effect's format
   * comes from its extension and its size from storage, the sound's length from re-reading it. null removes.
   */
  private async mediaFields(code: string, input: GiftInput): Promise<Partial<GiftFields>> {
    const fields: { -readonly [K in keyof GiftFields]?: GiftFields[K] } = {};
    const folder = `media/gifts/${code}/`;
    const own = (key: string) => {
      if (!key.startsWith(folder)) throw refused('That file was uploaded for another gift.');
    };
    const missing = () => refused('The uploaded file is not in storage any more; upload it again.');
    if (input.imageObjectKey !== undefined) {
      if (input.imageObjectKey !== null) {
        own(input.imageObjectKey);
        if (!(await this.storage.head(input.imageObjectKey))) throw missing();
      }
      fields.imageObjectKey = input.imageObjectKey;
    }
    if (input.animationObjectKey !== undefined) {
      if (input.animationObjectKey === null) {
        Object.assign(fields, {
          animationObjectKey: null,
          animationBytes: null,
          animationFormat: null,
          animationAlpha: null,
        });
      } else {
        own(input.animationObjectKey);
        const head = await this.storage.head(input.animationObjectKey);
        if (!head) throw missing();
        const mp4 = input.animationObjectKey.endsWith('.mp4');
        if (mp4 && input.animationAlpha === undefined) {
          throw refused('Choose the MP4 transparency (none or side-by-side).');
        }
        if (!mp4 && input.animationAlpha !== undefined)
          throw refused('Only an MP4 effect has a transparency.');
        Object.assign(fields, {
          animationObjectKey: input.animationObjectKey,
          animationBytes: head.size,
          animationFormat: mp4 ? 'MP4' : 'SVGA',
          animationAlpha: mp4 ? input.animationAlpha : null,
        });
      }
    } else if (input.animationAlpha !== undefined) {
      // Only the transparency of the gift's current MP4 changes.
      fields.animationAlpha = input.animationAlpha;
    }
    if (input.audioObjectKey !== undefined) {
      if (input.audioObjectKey === null) {
        Object.assign(fields, { audioObjectKey: null, audioBytes: null, audioMs: null });
      } else {
        own(input.audioObjectKey);
        const body = await this.storage.get(input.audioObjectKey, GIFT_AUDIO_MAX_BYTES);
        if (!body) throw missing();
        const file = giftAudioFile(code, body);
        Object.assign(fields, {
          audioObjectKey: input.audioObjectKey,
          audioBytes: file.size,
          audioMs: file.durationMs,
        });
      }
    }
    return fields;
  }

  /**
   * v1.71-social (D207): checks one uploaded file (the body's bytes) for `kind` and stores it at its content-addressed
   * key; answers the key, its public URL (null without MEDIA_PUBLIC_BASE_URL) and what was read from it. Nothing is
   * stored for a refused file (409 with the reason); without storage settings 503. The gift / category change that
   * names the key is the audited step.
   */
  async upload(kind: GiftUploadKind, code: string, body: unknown) {
    if (!Buffer.isBuffer(body) || body.length === 0) throw refused('The file is empty.');
    const pattern = kind === 'icon' ? GIFT_CATEGORY_CODE_PATTERN : GIFT_CODE_PATTERN;
    if (!pattern.test(code)) {
      throw AppException.validation([{ field: 'code', issue: 'invalid_format' }]);
    }
    const base = this.storageSettings.current().publicBaseUrl;
    try {
      switch (kind) {
        case 'image': {
          const file = await panelGiftImageFile(code, body);
          await uploadGiftArt(this.storage, file);
          return {
            kind,
            key: file.key,
            url: giftArtUrl(base, file.key),
            bytes: file.size,
            contentType: file.contentType,
            width: file.width,
            height: file.height,
          };
        }
        case 'icon': {
          const file = await giftCategoryIconFile(code, body);
          await uploadGiftArt(this.storage, file);
          return {
            kind,
            key: file.key,
            url: giftArtUrl(base, file.key),
            bytes: file.size,
            contentType: file.contentType,
            width: file.width,
            height: file.height,
          };
        }
        case 'sound': {
          const file = giftAudioFile(code, body);
          await uploadGiftArt(this.storage, file);
          return {
            kind,
            key: file.key,
            url: giftArtUrl(base, file.key),
            bytes: file.size,
            contentType: file.contentType,
            durationMs: file.durationMs,
          };
        }
        case 'animation': {
          if (body.length >= 8 && body.toString('latin1', 4, 8) === 'ftyp') {
            const file = await giftVideoFile(code, body);
            await uploadGiftArt(this.storage, file);
            return {
              kind,
              key: file.key,
              url: giftArtUrl(base, file.key),
              bytes: file.size,
              contentType: file.contentType,
              format: 'MP4' as const,
              width: file.width,
              height: file.height,
              durationMs: file.durationMs,
              detectedAlpha: file.detectedAlpha,
            };
          }
          const file = giftAnimationFile(code, body);
          await uploadGiftArt(this.storage, file);
          return {
            kind,
            key: file.key,
            url: giftArtUrl(base, file.key),
            bytes: file.size,
            contentType: file.contentType,
            format: 'SVGA' as const,
          };
        }
      }
    } catch (err) {
      if (err instanceof GiftArtError) throw refused(err.message);
      throw err;
    }
  }

  /**
   * v1.71-social (D207): a stored gift file's bytes and type, for the panel's preview from its own origin (the panel's
   * CSP allows media only from 'self'; the canvas that composites a side-by-side MP4 needs same-origin pixels).
   */
  async file(key: string): Promise<{ body: Buffer; contentType: string }> {
    const body = await this.storage.get(key, GIFT_ANIMATION_MAX_BYTES);
    if (!body) throw new AppException(ErrorCode.NOT_FOUND);
    const ext = key.slice(key.lastIndexOf('.') + 1);
    const contentType =
      { png: 'image/png', webp: 'image/webp', mp4: 'video/mp4', mp3: 'audio/mpeg' }[ext] ??
      'application/octet-stream';
    return { body, contentType };
  }

  // ---- gift categories (v1.71-social, D207, §10.66) ----------------------------------------------------------

  async giftCategories() {
    const rows = await giftCategoriesWithCounts(this.prisma);
    const base = this.storageSettings.current().publicBaseUrl;
    return {
      data: rows.map((c) => ({
        code: c.code,
        kind: c.kind,
        nameAr: c.nameAr,
        nameEn: c.nameEn,
        sortOrder: c.sortOrder,
        enabled: c.enabled,
        iconObjectKey: c.iconObjectKey,
        iconUrl: giftArtUrl(base, c.iconObjectKey),
        gifts: c.gifts,
        enabledGifts: c.enabledGifts,
        special: c.kind !== 'NORMAL',
      })),
    };
  }

  private async iconOk(code: string, key: string | null | undefined): Promise<void> {
    if (key === undefined || key === null) return;
    if (!key.startsWith(`media/gift-categories/${code}/`))
      throw refused('That icon was uploaded for another category.');
    if (!(await this.storage.head(key)))
      throw refused('The uploaded icon is not in storage any more; upload it again.');
  }

  async createGiftCategory(code: string, input: GiftCategoryInput & { reason: string }, ctx: AdminContext) {
    await this.iconOk(code, input.iconObjectKey);
    const row = await rule(() =>
      this.prisma.$transaction((tx) =>
        addGiftCategoryIn(
          tx,
          code,
          {
            nameAr: input.nameAr!,
            nameEn: input.nameEn!,
            sortOrder: input.sortOrder ?? 0,
            ...(input.enabled !== undefined ? { enabled: input.enabled } : {}),
            iconObjectKey: input.iconObjectKey ?? null,
          },
          viaOf(ctx),
          input.reason,
        ),
      ),
    );
    return { code: row.code, created: true };
  }

  async updateGiftCategory(code: string, input: GiftCategoryInput & { reason: string }, ctx: AdminContext) {
    await this.iconOk(code, input.iconObjectKey);
    const { reason, enabled: _e, ...rest } = input;
    const fields = Object.fromEntries(Object.entries(rest).filter(([, v]) => v !== undefined));
    const changed = await rule(() =>
      this.prisma.$transaction((tx) => updateGiftCategoryIn(tx, code, fields, viaOf(ctx), reason)),
    );
    if (changed === null) throw new AppException(ErrorCode.NOT_FOUND);
    return { code, changed };
  }

  async setGiftCategoryEnabled(code: string, enabled: boolean, reason: string, ctx: AdminContext) {
    const changed = await rule(() =>
      this.prisma.$transaction((tx) => setGiftCategoryEnabledIn(tx, code, enabled, viaOf(ctx), reason)),
    );
    if (changed === null) throw new AppException(ErrorCode.NOT_FOUND);
    return { code, enabled, changed };
  }

  async removeGiftCategory(code: string, moveTo: string | null, reason: string, ctx: AdminContext) {
    const done = await rule(() =>
      this.prisma.$transaction((tx) => deleteGiftCategoryIn(tx, code, moveTo, viaOf(ctx), reason)),
    );
    if (done === null) throw new AppException(ErrorCode.NOT_FOUND);
    return { code, removed: true, movedTo: done.moved.length > 0 ? moveTo : null, movedGifts: done.moved };
  }

  async createGift(code: string, input: GiftInput & { reason: string }, ctx: AdminContext) {
    const { reason, ...rest } = input;
    const fields: GiftFields = {
      category: rest.category!,
      nameAr: rest.nameAr!,
      nameEn: rest.nameEn!,
      priceCoins: rest.priceCoins!,
      // v1.71-social (D207): without a bundled key the gift's code (the app then shows the hosted image).
      assetKey: rest.assetKey ?? code,
      animationKey: rest.animationKey ?? null,
      sortOrder: rest.sortOrder ?? 0,
      badge: rest.badge ?? 'NONE',
      tagCode: rest.tagCode ?? null,
      tagNameAr: rest.tagNameAr ?? null,
      tagNameEn: rest.tagNameEn ?? null,
      soundKey: rest.soundKey ?? null,
      soundMs: rest.soundMs ?? null,
      quipText: rest.quipText ?? null,
    };
    const problems = giftFieldProblems(fields);
    if (problems.length > 0) throw refused(problems.join('; '));
    if (!rest.imageObjectKey) throw refused('The gift needs its picture «صورة الهدية».');
    Object.assign(fields, await rule(() => this.mediaFields(code, rest)));
    const created = await rule(() =>
      this.prisma.$transaction((tx) => addGiftByAdminIn(tx, code, fields, viaOf(ctx), reason)),
    );
    if (!created) throw refused(`A gift ${code} exists already.`);
    return { code, created: true };
  }

  async updateGift(code: string, input: GiftInput & { reason: string }, ctx: AdminContext) {
    const { reason, ...rest } = input;
    const fields = given(rest);
    const problems = giftFieldProblems(fields);
    if (problems.length > 0) throw refused(problems.join('; '));
    if (rest.imageObjectKey === null)
      throw refused('The gift needs its picture «صورة الهدية»; replace it instead.');
    Object.assign(fields, await rule(() => this.mediaFields(code, rest)));
    const changed = await rule(() =>
      this.prisma.$transaction((tx) => updateGiftByAdminIn(tx, code, fields, viaOf(ctx), reason)),
    );
    if (changed === null) throw new AppException(ErrorCode.NOT_FOUND);
    return { code, changed };
  }

  async setGiftEnabled(code: string, enabled: boolean, reason: string, ctx: AdminContext) {
    const changed = await this.prisma.$transaction((tx) =>
      setGiftEnabledByAdminIn(tx, code, enabled, viaOf(ctx), reason),
    );
    if (changed === null) throw new AppException(ErrorCode.NOT_FOUND);
    return { code, enabled, changed };
  }

  // ---- bag items --------------------------------------------------------------------------------------------------

  async bagItems() {
    const [items, holders] = await Promise.all([
      this.prisma.bagItem.findMany({ orderBy: [{ category: 'asc' }, { sortOrder: 'asc' }, { code: 'asc' }] }),
      this.prisma.userBagItem.groupBy({ by: ['itemCode'], _count: true }),
    ]);
    const count = new Map(holders.map((h) => [h.itemCode, h._count]));
    const hostFrames = new Set<string>(Object.values(HOST_FRAME_CODES));
    return {
      data: items.map((i) => ({
        code: i.code,
        category: i.category,
        nameAr: i.nameAr,
        nameEn: i.nameEn,
        assetKey: i.assetKey,
        free: i.free,
        automatic: hostFrames.has(i.code),
        holders: count.get(i.code) ?? 0,
      })),
    };
  }

  async userBag(userId: string) {
    if (!(await this.prisma.user.findUnique({ where: { id: userId }, select: { id: true } }))) {
      throw new AppException(ErrorCode.NOT_FOUND);
    }
    const rows = await this.prisma.userBagItem.findMany({
      where: { userId },
      include: { item: { select: { nameAr: true, nameEn: true, sortOrder: true } } },
      orderBy: [{ category: 'asc' }, { item: { sortOrder: 'asc' } }, { itemCode: 'asc' }],
    });
    const now = new Date();
    return {
      data: rows.map((r) => ({
        code: r.itemCode,
        category: r.category,
        nameAr: r.item.nameAr,
        nameEn: r.item.nameEn,
        equipped: r.equipped,
        source: r.source,
        acquiredAt: r.acquiredAt.toISOString(),
        expiresAt: r.expiresAt?.toISOString() ?? null,
        expired: r.expiresAt !== null && r.expiresAt <= now,
      })),
    };
  }

  private async bagTarget(userId: string, ctx: AdminContext) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, deletedAt: true },
    });
    if (!user || user.deletedAt !== null) throw new AppException(ErrorCode.NOT_FOUND);
    if (user.id === ctx.userId) throw refused('You cannot do this to your own account.');
  }

  async grantBagItem(
    userId: string,
    body: { code: string; days: number | null; reason: string },
    ctx: AdminContext,
  ) {
    await this.bagTarget(userId, ctx);
    const outcome = await rule(() =>
      this.prisma.$transaction((tx) =>
        grantBagItemByAdminIn(tx, userId, body.code, body.days, viaOf(ctx), body.reason),
      ),
    );
    return {
      outcome: outcome.kind,
      expiresAt: outcome.kind === 'permanent' ? null : (outcome.expiresAt?.toISOString() ?? null),
    };
  }

  async revokeBagItem(userId: string, body: { code: string; reason: string }, ctx: AdminContext) {
    await this.bagTarget(userId, ctx);
    const r = await rule(() =>
      this.prisma.$transaction((tx) =>
        revokeBagItemByAdminIn(tx, userId, body.code, viaOf(ctx), body.reason),
      ),
    );
    return { revoked: true, wasEquipped: r.wasEquipped };
  }

  // ---- banners ----------------------------------------------------------------------------------------------------

  async banners(now = new Date()) {
    const [rows, active] = await Promise.all([
      this.prisma.homeBanner.findMany({ orderBy: BANNER_ORDER, include: { media: true } }),
      this.prisma.homeBanner.findMany({ where: activeBannerWhere(now), select: { id: true } }),
    ]);
    const on = new Set(active.map((b) => b.id));
    const base = this.storageSettings.current().publicBaseUrl;
    return {
      data: rows.map((b) => ({
        id: b.id,
        placement: b.placement,
        titleAr: b.titleAr,
        titleEn: b.titleEn,
        link: b.link,
        startsAt: b.startsAt.toISOString(),
        endsAt: b.endsAt?.toISOString() ?? null,
        sortOrder: b.sortOrder,
        enabled: b.enabled,
        showing: on.has(b.id),
        imageUrl: giftArtUrl(base, b.media.thumbKey ?? b.media.largeKey),
      })),
    };
  }

  async setBannerEnabled(id: string, enabled: boolean, reason: string, ctx: AdminContext) {
    const changed = await this.prisma.$transaction((tx) =>
      setBannerEnabledIn(tx, id, enabled, viaOf(ctx), reason),
    );
    if (changed === null) throw new AppException(ErrorCode.NOT_FOUND);
    return { id, enabled, changed };
  }

  async removeBanner(id: string, reason: string, ctx: AdminContext) {
    const keys = await this.prisma.$transaction((tx) => removeBannerIn(tx, id, viaOf(ctx), reason));
    if (keys === null) throw new AppException(ErrorCode.NOT_FOUND);
    try {
      await this.storage.delete(keys);
    } catch (err) {
      // The banner is gone; the orphaned picture is only a storage cost (as the CLI reports it).
      this.logger.warn({ error: safeErrorLog(err), bannerId: id }, 'Banner picture could not be deleted');
    }
    return { removed: true };
  }

  // ---- events -----------------------------------------------------------------------------------------------------

  async events(now = new Date()) {
    const rows = await this.prisma.event.findMany({
      orderBy: [{ startsAt: 'desc' }, { id: 'asc' }],
      take: 200,
    });
    return {
      data: rows.map((e) => ({
        id: e.id,
        titleAr: e.titleAr,
        titleEn: e.titleEn,
        metric: e.metric,
        audience: e.audience,
        startsAt: e.startsAt.toISOString(),
        endsAt: e.endsAt?.toISOString() ?? null,
        permanent: e.permanent,
        featured: e.featured,
        regions: e.regions,
        prizes: Array.isArray(e.prizes) ? e.prizes.length : 0,
        tone: e.tone,
        state: eventState(e, now),
        payoutHold: e.payoutHold,
      })),
    };
  }

  async createEvent(
    body: {
      titleAr: string;
      titleEn: string;
      rulesAr?: string | undefined;
      rulesEn?: string | undefined;
      startsAt: string;
      endsAt?: string | null | undefined;
      permanent?: boolean | undefined;
      metric: EventMetric;
      audience?: 'EVERYONE' | 'HOSTS' | undefined;
      regions?: string[] | undefined;
      featured?: boolean | undefined;
      bannerUrl?: string | null | undefined;
      prizes?: string | undefined;
      summaryAr?: string | null | undefined;
      summaryEn?: string | null | undefined;
      tone?: string | null | undefined;
      reason: string;
    },
    ctx: AdminContext,
  ) {
    const prizes = parsePrizeText(body.prizes ?? '');
    if (prizes === null)
      throw refused('Prizes are like 1:5000,2:3000,3-10:500 (ranks 1–100 in order, coins each).');
    const row = await rule(() =>
      this.prisma.$transaction((tx) =>
        createEventByAdminIn(
          tx,
          {
            titleAr: body.titleAr,
            titleEn: body.titleEn,
            rulesAr: body.rulesAr ?? '',
            rulesEn: body.rulesEn ?? '',
            startsAt: new Date(body.startsAt),
            endsAt: body.endsAt ? new Date(body.endsAt) : null,
            permanent: body.permanent === true,
            metric: body.metric,
            audience: body.audience ?? 'EVERYONE',
            regions: (body.regions ?? []).map((r) => r.toUpperCase()),
            featured: body.featured === true,
            bannerUrl: body.bannerUrl ?? null,
            prizes,
            summaryAr: body.summaryAr || null,
            summaryEn: body.summaryEn || null,
            tone: body.tone ?? null,
          },
          viaOf(ctx),
          body.reason,
        ),
      ),
    );
    return { id: row.id };
  }

  async changeEvent(id: string, command: EventChange, reason: string, ctx: AdminContext) {
    const changed = await rule(() =>
      this.prisma.$transaction((tx) => changeEventByAdminIn(tx, id, command, new Date(), viaOf(ctx), reason)),
    );
    return { id, changed };
  }
}
