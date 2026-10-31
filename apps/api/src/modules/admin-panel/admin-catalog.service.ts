import { Inject, Injectable, Logger } from '@nestjs/common';
import { AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { GiftBadge, GiftCategory, EventMetric } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { BagAdminError, grantBagItemByAdminIn, revokeBagItemByAdminIn } from '../bag/bag-admin-rules.js';
import { HOST_FRAME_CODES } from '../bag/bag.catalogue.js';
import { addGiftByAdminIn, setGiftEnabledByAdminIn, updateGiftByAdminIn } from '../gifts/gift-admin-rules.js';
import { giftArtUrl } from '../gifts/gift-art.js';
import {
  compareGifts,
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
    if (err instanceof GiftFieldsError || err instanceof BagAdminError || err instanceof EventAdminError) {
      throw refused(err.message);
    }
    throw err;
  }
}

export interface GiftInput {
  category?: GiftCategory | undefined;
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
}

/** The fields given (undefined = not given), as the catalogue's `Partial<GiftFields>`. */
function given(input: GiftInput): Partial<GiftFields> {
  return Object.fromEntries(Object.entries(input).filter(([, v]) => v !== undefined));
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
  ) {}

  private usd(coins: number): string {
    return ((coins * this.config.economy.coinRetailUsdPerMillion) / 1_000_000).toFixed(2);
  }

  // ---- gifts ----------------------------------------------------------------------------------------------------

  async gifts() {
    const [rows, sends] = await Promise.all([
      this.prisma.gift.findMany(),
      this.prisma.liveGift.groupBy({ by: ['giftCode'], _count: true, _sum: { totalCoins: true } }),
    ]);
    const used = new Map(sends.map((s) => [s.giftCode, s]));
    const base = this.config.media.publicBaseUrl;
    return {
      coinRetailUsdPerMillion: this.config.economy.coinRetailUsdPerMillion,
      data: rows.sort(compareGifts).map((g) => ({
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

  async createGift(code: string, input: GiftInput & { reason: string }, ctx: AdminContext) {
    const { reason, ...rest } = input;
    const fields: GiftFields = {
      category: rest.category!,
      nameAr: rest.nameAr!,
      nameEn: rest.nameEn!,
      priceCoins: rest.priceCoins!,
      assetKey: rest.assetKey!,
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
    const base = this.config.media.publicBaseUrl;
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
