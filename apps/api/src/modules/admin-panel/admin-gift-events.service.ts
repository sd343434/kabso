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
  EVENT_BOARD_KINDS,
  GIFT_EVENT_LIMITS,
  parseBundle,
  parsePrizeLines,
  updateGiftEventIn,
  type GiftEventInput,
} from '../programs/gift-events.js';
import { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import { MediaService } from '../media/media.service.js';
import { BannerError, storeBannerImage } from '../home/home-banners.js';
import {
  checkEventImage,
  checkEventOverlay,
  checkEventVideo,
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
      const checked = kind === 'overlay' ? checkEventOverlay(body) : await checkEventImage(kind, body);
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

  /** Every art key the body names must be an uploaded object (409 otherwise). */
  private async assertArt(body: GiftEventInput): Promise<void> {
    for (const key of [body.backgroundKey, body.backgroundPosterKey, body.titleKey, body.overlayKey]) {
      if (key && !(await this.storage.head(key))) throw refused(`Upload ${key} first (it is not stored).`);
    }
  }

  /** `AdminEventOptions`: what an event can use — gifts, bag items, VIP tiers, the board kinds and the limits. */
  async options() {
    const base = this.storageSettings.current().publicBaseUrl;
    const [gifts, items, tiers] = await Promise.all([
      this.prisma.gift.findMany({ orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }] }),
      this.prisma.bagItem.findMany({ orderBy: [{ category: 'asc' }, { sortOrder: 'asc' }] }),
      this.prisma.vipTier.findMany({ orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] }),
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
      gifts: gifts.map((g) => ({
        code: g.code,
        nameAr: g.nameAr,
        nameEn: g.nameEn,
        priceCoins: g.priceCoins,
        assetKey: g.assetKey,
        imageUrl: giftArtUrl(base, g.imageObjectKey),
        enabled: g.enabled,
      })),
      bagItems: items.map((i) => ({
        code: i.code,
        category: i.category,
        nameAr: i.nameAr,
        nameEn: i.nameEn,
        assetKey: i.assetKey,
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
        startsAt: e.startsAt.toISOString(),
        endsAt: e.endsAt?.toISOString() ?? null,
        state: eventState(e, now),
        payoutHold: e.payoutHold,
        editable: e.metric === 'EVENT_GIFTS' && e.frozenAt === null && (e.endsAt === null || e.endsAt > now),
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
      },
    });
    if (!e || e.metric !== 'EVENT_GIFTS') throw new AppException(ErrorCode.NOT_FOUND);
    const now = this.clock.now();
    const results = await this.prisma.eventResult.findMany({
      where: { eventId: id },
      orderBy: [{ board: 'asc' }, { rank: 'asc' }],
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
      structureLocked: e.startsAt <= now,
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
        startsAt: e.startsAt.toISOString(),
        endsAt: e.endsAt?.toISOString() ?? null,
        timeZone: e.timeZone,
        audience: e.audience,
        regions: e.regions.map((r) => r.trim()),
        featured: e.featured,
        backgroundKey: e.backgroundKey,
        backgroundPosterKey: e.backgroundPosterKey,
        titleKey: e.titleKey,
        overlayKey: e.overlayKey,
        gifts: e.gifts.map((g) => ({
          giftCode: g.giftCode,
          pointsPerCoin: g.pointsPerCoin,
          pointsPerGift: g.pointsPerGift,
        })),
        boards: e.boards.map((b) => ({
          kind: b.kind,
          minPoints: Number(b.minPoints),
          prizes: parsePrizeLines(b.prizes),
        })),
      },
      results: results.map((r) => ({
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

  async create(body: GiftEventInput, ctx: AdminContext) {
    await this.assertArt(body);
    return rule(() =>
      this.prisma.$transaction((tx) => createGiftEventIn(tx, body, this.clock.now(), viaOf(ctx))),
    );
  }

  async update(id: string, body: GiftEventInput, ctx: AdminContext) {
    await this.assertArt(body);
    return rule(() =>
      this.prisma.$transaction((tx) => updateGiftEventIn(tx, id, body, this.clock.now(), viaOf(ctx))),
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
  kind: z.enum(['banner', 'banner_video', 'background', 'background_video', 'title', 'overlay', 'badge']),
});
