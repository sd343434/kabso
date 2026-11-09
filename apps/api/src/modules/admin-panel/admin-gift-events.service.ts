import { Inject, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { giftArtUrl } from '../gifts/gift-art.js';
import {
  changeEventByAdminIn,
  EventAdminError,
  eventState,
  type EventChange,
} from '../programs/event-admin-rules.js';
import {
  createGiftEventIn,
  EVENT_AUDIENCES,
  EVENT_BOARD_KINDS,
  EVENT_COUNTED_GIFTS,
  EVENT_RECURRENCES,
  EVENT_SCORINGS,
  GIFT_EVENT_LIMITS,
  lifecycleIn,
  parseBundle,
  parsePrizeLines,
  PRIZE_ITEM_TYPES,
  updateGiftEventIn,
  type EventLifecycleCommand,
  type GiftEventInput,
} from '../programs/gift-events.js';
import { createLaunchFestivalDraftIn } from '../programs/launch-festival.js';
import { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import { MediaService } from '../media/media.service.js';
import { BannerError, storeBannerImage } from '../home/home-banners.js';
import {
  checkEventImage,
  checkEventLottieTitle,
  checkEventOverlay,
  checkEventOverlayVideo,
  checkEventVideo,
  isMp4,
  EVENT_MEDIA_SPECS,
  EventMediaError,
  storeEventArt,
  type EventMediaKind,
} from '../programs/event-media.js';
import { EVENT_ART_KEYS, EVENT_BADGE_CODE } from '../programs/gift-events.js';
import { auditBy } from '../../common/audit/admin-actor.js';
import { z } from 'zod';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { AdminContext } from './admin-auth.service.js';
import { refused, viaOf } from './admin-users.service.js';

async function rule<T>(step: () => Promise<T>): Promise<T> {
  try {
    return await step();
  } catch (err) {
    if (err instanceof EventAdminError) throw refused(err.message);
    throw err;
  }
}

/**
 * v1.97-social (D303, CONVENTIONS §10.114.7): gift events from the admin panel (`/admin/gift-events`) and from the app's
 * staff tools (`/staff/gift-events`) — the same rules (`gift-events.ts`), audited with `via` panel or app. The capability
 * `events.manage` (OWNER by default) guards every write in both.
 */
@Injectable()
export class AdminGiftEventsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly storageSettings: StorageSettingsStore,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    private readonly media: MediaService,
  ) {}

  private url(key: string | null): string | null {
    return giftArtUrl(this.storageSettings.current().publicBaseUrl, key);
  }

  /**
   * v1.97-social (D303 follow-ups, §10.114.9): one piece of an event's art, raw bytes, checked against the published
   * spec (`EVENT_MEDIA_SPECS`) — 409 `ADMIN_ACTION_REFUSED` with `{field: 'file', issue}` and a clear message otherwise.
   * `banner` / `banner_video` become a HOME banner's picture / video (`createAdminBanner` with `eventId` names them);
   * the rest are stored under `media/events/…` and named in the event (`backgroundKey` …) or a badge (`imageKey`).
   */
  async upload(kind: EventMediaKind, body: unknown, ctx: AdminContext) {
    if (!Buffer.isBuffer(body) || body.length === 0) throw refused('The file is empty.');
    const spec = EVENT_MEDIA_SPECS[kind];
    try {
      if (kind === 'banner') {
        const checked = await checkEventImage('banner', body);
        const asset = await storeBannerImage(this.prisma, this.storage, ctx.userId, checked.body, 'HOME');
        return {
          kind,
          mediaId: asset.id,
          key: null,
          url: this.url(asset.largeKey),
          width: asset.width,
          height: asset.height,
          animated: asset.animated,
          durationMs: checked.durationMs,
          spec,
        };
      }
      if (kind === 'banner_video') {
        const checked = await checkEventVideo('banner_video', body);
        const asset = await this.media.storeRawVideo(ctx.userId, body, 'BANNER_VIDEO');
        return {
          kind,
          mediaId: asset.id,
          key: null,
          url: this.url(asset.largeKey),
          width: checked.info.width,
          height: checked.info.height,
          animated: true,
          durationMs: checked.info.durationMs,
          spec,
        };
      }
      if (kind === 'background_video') {
        const checked = await checkEventVideo('background_video', body);
        const key = await storeEventArt(this.storage, kind, {
          body,
          contentType: checked.contentType,
          ext: checked.ext,
        });
        return {
          kind,
          mediaId: null,
          key,
          url: this.url(key),
          width: checked.info.width,
          height: checked.info.height,
          animated: true,
          durationMs: checked.info.durationMs,
          spec,
        };
      }
      // v1.101-social (D325): an overlay may be an alpha MP4; a title may be a Lottie JSON.
      const json = body.subarray(0, 64).toString('utf8').trimStart().startsWith('{');
      const checked =
        kind === 'overlay'
          ? isMp4(body)
            ? await checkEventOverlayVideo(body)
            : checkEventOverlay(body)
          : kind === 'title' && json
            ? checkEventLottieTitle(body)
            : await checkEventImage(kind, body);
      const key = await storeEventArt(this.storage, kind, checked);
      return {
        kind,
        mediaId: null,
        key,
        url: this.url(key),
        width: checked.width,
        height: checked.height,
        animated: checked.animated,
        durationMs: checked.durationMs,
        spec,
      };
    } catch (err) {
      if (err instanceof EventMediaError) throw refused(err.message, err.issue, 'file');
      if (err instanceof BannerError) throw refused(err.message, err.issue, 'file');
      throw err;
    }
  }

  /** v1.97-social (D303 follow-up): makes a reusable event badge «وسام فعالية» (audited `event.badge.create`). */
  async createBadge(body: EventBadgeInput, ctx: AdminContext) {
    const levels = [...body.levels].sort((a, b) => a.level - b.level);
    if (new Set(levels.map((l) => l.level)).size !== levels.length) throw refused('A level is listed twice.');
    for (const l of levels) {
      if (!(await this.storage.head(l.imageKey)))
        throw refused(`Upload the art of level ${String(l.level)} first.`);
    }
    const exists = await this.prisma.eventBadge.findUnique({ where: { code: body.code } });
    if (exists) throw refused(`The medal ${body.code} exists.`);
    await this.prisma.$transaction(async (tx) => {
      await tx.eventBadge.create({
        data: {
          code: body.code,
          nameAr: body.nameAr,
          nameEn: body.nameEn,
          createdById: ctx.userId,
          levels: { create: levels.map((l) => ({ level: l.level, imageKey: l.imageKey })) },
        },
      });
      await tx.auditLog.create({
        data: {
          ...auditBy(viaOf(ctx)),
          action: 'event.badge.create',
          targetType: 'event_badge',
          targetId: body.code,
          metadata: { levels: levels.map((l) => l.level), reason: body.reason, via: viaOf(ctx).via },
        },
      });
    });
    return {
      code: body.code,
      nameAr: body.nameAr,
      nameEn: body.nameEn,
      levels: levels.map((l) => ({ level: l.level, imageUrl: this.url(l.imageKey) })),
    };
  }

  /** Every art key the body names must be an uploaded object (409 otherwise); v1.101-social: the prizes' pictures too. */
  private async assertArt(body: GiftEventInput): Promise<void> {
    const displays = [
      ...body.boards.flatMap((b) => b.prizes.flatMap((l) => l.items)),
      ...body.milestones.flatMap((m) => m.prizes),
    ].map((i) => (i as { displayKey?: string | null }).displayKey ?? null);
    for (const key of [
      body.backgroundKey,
      body.backgroundPosterKey,
      body.titleKey,
      body.overlayKey,
      ...new Set(displays),
    ]) {
      if (key && !(await this.storage.head(key))) throw refused(`Upload ${key} first (it is not stored).`);
    }
  }

  /**
   * `AdminEventOptions`: what an event can use — gifts, bag items, VIP tiers, the board kinds and the limits.
   * v1.101-social (D325): with `eventId`, that event's own exclusive gifts and items too (another event's never), the
   * gift categories an event gift may go in, and the v2 choices.
   */
  async options(eventId?: string) {
    const base = this.storageSettings.current().publicBaseUrl;
    const own = eventId ? [{ eventId: null }, { eventId }] : [{ eventId: null }];
    const [gifts, items, tiers, categories] = await Promise.all([
      // v1.103-social (D338): an archived («محذوفة») gift is offered only to the event that lists it already.
      this.prisma.gift.findMany({
        where: {
          OR: own,
          AND: [
            {
              OR: [{ archivedAt: null }, ...(eventId ? [{ eventGifts: { some: { eventId } } }] : [])],
            },
          ],
        },
        orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
      }),
      this.prisma.bagItem.findMany({
        where: { OR: [{ storeItem: null }, { storeItem: { OR: own } }] },
        include: { storeItem: { select: { eventId: true, still: true, animation: true } } },
        orderBy: [{ category: 'asc' }, { sortOrder: 'asc' }],
      }),
      this.prisma.vipTier.findMany({ orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] }),
      this.prisma.giftCategory.findMany({
        where: { kind: 'NORMAL', code: { notIn: ['LUCKY', 'QUIPS', 'CUSTOM'] } },
        orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
      }),
    ]);
    const badges = await this.prisma.eventBadge.findMany({
      orderBy: { createdAt: 'desc' },
      include: { levels: { orderBy: { level: 'asc' } } },
    });
    return {
      timeZone: this.config.live.rankingsTimeZone,
      boardKinds: [...EVENT_BOARD_KINDS],
      // D303 follow-ups: the art specs (one source of truth) and the reusable badges.
      specs: Object.values(EVENT_MEDIA_SPECS),
      badges: badges.map((b) => ({
        code: b.code,
        nameAr: b.nameAr,
        nameEn: b.nameEn,
        levels: b.levels.map((l) => ({ level: l.level, imageUrl: this.url(l.imageKey) })),
      })),
      limits: { ...GIFT_EVENT_LIMITS },
      // v1.101-social (D325): the v2 choices.
      audiences: [...EVENT_AUDIENCES],
      recurrences: [...EVENT_RECURRENCES],
      scorings: [...EVENT_SCORINGS],
      countedGifts: [...EVENT_COUNTED_GIFTS],
      prizeTypes: [...PRIZE_ITEM_TYPES],
      giftCategories: categories.map((c) => ({ code: c.code, nameAr: c.nameAr, nameEn: c.nameEn })),
      gifts: gifts.map((g) => ({
        code: g.code,
        nameAr: g.nameAr,
        nameEn: g.nameEn,
        priceCoins: g.priceCoins,
        assetKey: g.assetKey,
        imageUrl: giftArtUrl(base, g.imageObjectKey),
        enabled: g.enabled,
        eventId: g.eventId,
        fullscreen: g.badges.includes('FULLSCREEN'),
        hasEffect: g.animationObjectKey !== null,
      })),
      bagItems: items.map((i) => ({
        code: i.code,
        category: i.category,
        nameAr: i.nameAr,
        nameEn: i.nameEn,
        assetKey: i.assetKey,
        eventId: i.storeItem?.eventId ?? null,
        stillUrl: i.storeItem?.still ?? null,
      })),
      vipTiers: tiers.map((t) => ({
        code: t.code,
        nameAr: t.nameAr,
        nameEn: t.nameEn,
        color: t.color,
        enabled: t.enabled,
      })),
    };
  }

  /** `AdminEventList` for the app's «الفعاليات» tool (the panel keeps `GET /admin/events`). */
  async list() {
    const now = this.clock.now();
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
        startsAt: e.startsAt?.toISOString() ?? null,
        endsAt: e.endsAt?.toISOString() ?? null,
        state: eventState(e, now),
        payoutHold: e.payoutHold,
        editable: e.metric === 'EVENT_GIFTS' && e.frozenAt === null && (e.endsAt === null || e.endsAt > now),
        status: e.status,
        recurrence: e.recurrence,
      })),
    };
  }

  /** `AdminGiftEvent`: the form of a gift event (the body of an edit, without `reason`), its state and results. */
  async get(id: string) {
    const e = await this.prisma.event.findUnique({
      where: { id },
      include: {
        gifts: { orderBy: { sortOrder: 'asc' } },
        boards: { orderBy: { sortOrder: 'asc' } },
        milestones: { orderBy: { sortOrder: 'asc' }, include: { _count: { select: { grants: true } } } },
        periods: { orderBy: { period: 'asc' } },
        ownGifts: { orderBy: { sortOrder: 'asc' } },
        ownItems: { orderBy: { sortOrder: 'asc' } },
        bannerMedia: true,
      },
    });
    if (!e || e.metric !== 'EVENT_GIFTS') throw new AppException(ErrorCode.NOT_FOUND);
    const now = this.clock.now();
    const results = await this.prisma.eventResult.findMany({
      where: { eventId: id },
      orderBy: [{ period: 'desc' }, { board: 'asc' }, { rank: 'asc' }],
      include: {
        user: { select: { profile: { select: { username: true, displayName: true } } } },
        payouts: { select: { userId: true, status: true, granted: true } },
      },
    });
    return {
      id: e.id,
      state: eventState(e, now),
      payoutHold: e.payoutHold,
      frozenAt: e.frozenAt?.toISOString() ?? null,
      paidAt: e.paidAt?.toISOString() ?? null,
      structureLocked: e.status === 'PUBLISHED' && e.startsAt !== null && e.startsAt <= now,
      // v1.102-social (D334): content creators count as hosts (HOSTS audience) — false on the events made before it.
      creatorsAsHosts: e.creatorsAsHosts,
      artUrls: {
        background: this.url(e.backgroundKey),
        backgroundPoster: this.url(e.backgroundPosterKey),
        title: this.url(e.titleKey),
        overlay: this.url(e.overlayKey),
      },
      form: {
        titleAr: e.titleAr,
        titleEn: e.titleEn,
        rulesAr: e.rulesAr,
        rulesEn: e.rulesEn,
        summaryAr: e.summaryAr,
        summaryEn: e.summaryEn,
        tone: e.tone,
        bannerUrl: e.bannerUrl,
        startsAt: e.startsAt?.toISOString() ?? null,
        endsAt: e.endsAt?.toISOString() ?? null,
        timeZone: e.timeZone,
        // v1.101-social (D325).
        status: e.status,
        permanent: e.permanent,
        recurrence: e.recurrence,
        scoring: e.scoring,
        countedGifts: e.countedGifts,
        bannerMediaId: e.bannerMediaId,
        audience: e.audience,
        regions: e.regions.map((r) => r.trim()),
        featured: e.featured,
        backgroundKey: e.backgroundKey,
        backgroundPosterKey: e.backgroundPosterKey,
        titleKey: e.titleKey,
        overlayKey: e.overlayKey,
        gifts: e.gifts.map((g) => ({
          giftCode: g.giftCode,
          pointsPerCoin: Number(g.pointsPerCoin),
          pointsPerGift: g.pointsPerGift,
        })),
        boards: e.boards.map((b) => ({
          kind: b.kind,
          minPoints: Number(b.minPoints),
          prizes: parsePrizeLines(b.prizes),
          // v1.102-social (D334): «عدد المعروضين».
          shown: b.shown,
        })),
        milestones: e.milestones.map((m) => ({
          board: m.board,
          points: Number(m.points),
          prizes: parseBundle(m.prizes),
        })),
      },
      // v1.101-social (D325): the current period, the frozen ones, the event's own gifts and items, the banner.
      period: e.period,
      periodStartsAt: e.periodStartsAt?.toISOString() ?? null,
      periodEndsAt: e.periodEndsAt?.toISOString() ?? null,
      periods: e.periods.map((p) => ({
        period: p.period,
        startsAt: p.startsAt.toISOString(),
        endsAt: p.endsAt.toISOString(),
        frozenAt: p.frozenAt.toISOString(),
      })),
      milestoneGrants: e.milestones.reduce((n, m) => n + m._count.grants, 0),
      bannerImageUrl: e.bannerMedia ? this.url(e.bannerMedia.largeKey) : null,
      ownGifts: e.ownGifts.map((g) => ({
        code: g.code,
        nameAr: g.nameAr,
        nameEn: g.nameEn,
        priceCoins: g.priceCoins,
        imageUrl: this.url(g.imageObjectKey),
        hasEffect: g.animationObjectKey !== null,
        fullscreen: g.badges.includes('FULLSCREEN'),
      })),
      ownItems: e.ownItems.map((i) => ({
        id: i.id,
        code: i.bagCode,
        kind: i.kind,
        nameAr: i.nameAr,
        nameEn: i.nameEn,
        still: i.still,
        animation: i.animation,
      })),
      results: results.map((r) => ({
        period: r.period,
        board: r.board,
        rank: r.rank,
        username: r.user.profile?.username ?? null,
        displayName: r.user.profile?.displayName ?? null,
        agencyId: r.agencyId,
        coupleId: r.coupleId,
        partnerId: r.partnerId,
        score: Number(r.score),
        prize: parseBundle(r.prize),
        prizeStatus: r.prizeStatus,
        payouts: r.payouts.map((p) => ({ userId: p.userId, status: p.status, granted: p.granted })),
      })),
    };
  }

  private get zone(): string {
    return this.config.live.rankingsTimeZone;
  }

  async create(body: GiftEventInput, ctx: AdminContext) {
    await this.assertArt(body);
    return rule(() =>
      this.prisma.$transaction((tx) => createGiftEventIn(tx, body, this.clock.now(), viaOf(ctx), this.zone)),
    );
  }

  async update(id: string, body: GiftEventInput, ctx: AdminContext) {
    await this.assertArt(body);
    return rule(() =>
      this.prisma.$transaction((tx) =>
        updateGiftEventIn(tx, id, body, this.clock.now(), viaOf(ctx), this.zone),
      ),
    );
  }

  /** v1.101-social (D325): «مهرجان انطلاقة Kabso» as a draft with its four exclusive gifts (launch-festival.ts). */
  async launchFestival(body: { reason: string; category?: string | undefined }, ctx: AdminContext) {
    return rule(() =>
      this.prisma.$transaction((tx) =>
        createLaunchFestivalDraftIn(tx, viaOf(ctx), this.clock.now(), body.reason, this.zone, body.category),
      ),
    );
  }

  /** v1.101-social (D325): publish / unpublish / discard (a draft). */
  async lifecycle(id: string, command: EventLifecycleCommand, reason: string, ctx: AdminContext) {
    return rule(() =>
      this.prisma.$transaction((tx) =>
        lifecycleIn(tx, id, command, reason, this.clock.now(), viaOf(ctx), this.zone),
      ),
    );
  }

  /** end / hold / release from the app (the panel's `POST /admin/events/{id}/{command}` rule). */
  async change(id: string, command: EventChange, reason: string, ctx: AdminContext) {
    const changed = await rule(() =>
      this.prisma.$transaction((tx) =>
        changeEventByAdminIn(tx, id, command, this.clock.now(), viaOf(ctx), reason),
      ),
    );
    return { id, changed };
  }
}

/** `EventBadgeInput` (D303 follow-up). */
export const eventBadgeInputSchema = z.strictObject({
  code: z.string().regex(EVENT_BADGE_CODE),
  nameAr: z.string().trim().min(1).max(40),
  nameEn: z.string().trim().min(1).max(40),
  /** Owner: a medal may have levels (1 … 10), each its own art (the `badge` spec). */
  levels: z
    .array(
      z.strictObject({
        level: z.number().int().min(1).max(10),
        imageKey: z.string().regex(EVENT_ART_KEYS.badge),
      }),
    )
    .min(1)
    .max(10),
  reason: z.string().trim().min(3).max(500),
});
export type EventBadgeInput = z.infer<typeof eventBadgeInputSchema>;

export const eventUploadQuery = z.strictObject({
  kind: z.enum([
    'banner',
    'banner_video',
    'background',
    'background_video',
    'title',
    'overlay',
    'badge',
    'prize',
  ]),
});

/** v1.101-social (D325): `GET /admin/event-options?eventId=`. */
/** v1.101-social (D325): `POST /admin/gift-events/launch-festival`. */
export const launchFestivalBody = z.strictObject({
  reason: z.string().trim().min(3).max(500),
  category: z
    .string()
    .regex(/^[A-Z0-9_]{1,40}$/)
    .optional(),
});

export const eventOptionsQuery = z.strictObject({ eventId: z.uuid().optional() });
