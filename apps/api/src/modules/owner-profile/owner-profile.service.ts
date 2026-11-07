import { Inject, Injectable } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { REDIS } from '../../redis/redis.module.js';
import { isUuid } from '../auth/tokens.js';
import { dayKey } from '../admin-panel/admin-stats.service.js';
import { MediaService } from '../media/media.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { userSummary, USER_SUMMARY_SELECT } from '../posts/post-views.js';
import { dayStart } from '../recharge/recharge-rules.js';
import { UsersService } from '../users/users.service.js';
import {
  assertKabsoOwner,
  COVER_VIDEO_LANGS,
  coverVideoOf,
  DASHBOARD_CACHE_KEY,
  DASHBOARD_CACHE_SECONDS,
  DASHBOARD_ONLINE_MINUTES,
  isKabsoOwner,
  JOURNEY_ICONS,
  MAX_JOURNEY_MILESTONES,
  type CoverVideoLang,
  type OwnerCoverVideoDto,
} from './owner-core.js';

type Tx = Prisma.TransactionClient;

/** Request metadata for audit records. */
export interface OwnerMeta {
  readonly ip: string | null;
  readonly requestId: string | null;
}

/** `JourneyMilestone` (§10.112.3). */
export interface JourneyMilestoneDto {
  id: string;
  titleAr: string;
  titleEn: string;
  lineAr: string | null;
  lineEn: string | null;
  year: number;
  month: number;
  icon: string;
  latest: boolean;
  position: number;
}

/** `OwnerDashboard` (§10.112.4). */
export interface OwnerDashboardDto {
  onlineNow: number;
  onlineWindowMinutes: number;
  liveRoomsNow: number;
  income: {
    day: string;
    timeZone: string;
    currency: 'USD';
    amountMinor: number;
    websiteMinor: number;
    agentsMinor: number;
    /**
     * Owner (PP-58): money Kabso received today in another currency, one line each, never converted (empty when all
     * was USD).
     */
    otherCurrencies: { currency: string; websiteMinor: number; agentsMinor: number; amountMinor: number }[];
  };
  generatedAt: string;
}

const title = z.string().trim().min(1).max(60);
/** A line: trimmed; empty (or null) means none. */
const line = z
  .string()
  .trim()
  .max(120)
  .nullable()
  .transform((v) => (v === null || v === '' ? null : v));
const milestoneFields = {
  titleAr: title,
  titleEn: title,
  lineAr: line.optional(),
  lineEn: line.optional(),
  year: z.number().int().min(2020).max(2100),
  month: z.number().int().min(1).max(12),
  icon: z.enum(JOURNEY_ICONS),
  latest: z.boolean().optional(),
};
export const createMilestoneSchema = z.strictObject(milestoneFields);
export const updateMilestoneSchema = z
  .strictObject({
    titleAr: title.optional(),
    titleEn: title.optional(),
    lineAr: line.optional(),
    lineEn: line.optional(),
    year: milestoneFields.year.optional(),
    month: milestoneFields.month.optional(),
    icon: milestoneFields.icon.optional(),
    latest: z.boolean().optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { params: { issue: 'required' } });
export const reorderSchema = z.strictObject({
  ids: z.array(z.string().refine(isUuid)).max(MAX_JOURNEY_MILESTONES),
});
const setVideoSchema = z.strictObject({
  mediaId: z.string().refine(isUuid, { params: { issue: 'invalid_value' } }),
});

function parse<T extends z.ZodType>(schema: T, body: unknown): z.output<T> {
  const parsed = schema.safeParse(body ?? {});
  if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
  return parsed.data;
}

function toMilestoneDto(row: {
  id: string;
  titleAr: string;
  titleEn: string;
  lineAr: string | null;
  lineEn: string | null;
  year: number;
  month: number;
  icon: string;
  latest: boolean;
  position: number;
}): JourneyMilestoneDto {
  return {
    id: row.id,
    titleAr: row.titleAr,
    titleEn: row.titleEn,
    lineAr: row.lineAr,
    lineEn: row.lineEn,
    year: row.year,
    month: row.month,
    icon: row.icon,
    latest: row.latest,
    position: row.position,
  };
}

/**
 * v1.95-social (D301, CONVENTIONS §10.112): the app owner's profile «صفحة صاحب البرنامج» — the bilingual cover video,
 * «رحلة Kabso» and «لوحة المؤسس». Every change is the owner's own (403 `OWNER_ONLY` for anyone else) and audited.
 */
@Injectable()
export class OwnerProfileService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly users: UsersService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private readonly urlOf = (key: string): string => this.media.largeUrl({ largeKey: key });

  // ---- the cover video (§10.112.1) ----------------------------------------------------------------------------------

  private langOf(raw: string): CoverVideoLang {
    const lang = (COVER_VIDEO_LANGS as readonly string[]).find((l) => l === raw);
    if (!lang) throw new AppException(ErrorCode.NOT_FOUND);
    return lang as CoverVideoLang;
  }

  async coverVideo(userId: string): Promise<OwnerCoverVideoDto> {
    return coverVideoOf(this.prisma, userId, this.urlOf);
  }

  /** `PUT /me/cover-video/{lang}`: the caller's READY, unattached PROFILE_COVER_VIDEO replaces that language's video. */
  async setCoverVideo(
    userId: string,
    rawLang: string,
    body: unknown,
    meta: OwnerMeta,
  ): Promise<OwnerCoverVideoDto> {
    const lang = this.langOf(rawLang);
    await assertKabsoOwner(this.prisma, userId);
    await this.media.assertEnabled();
    const mediaId = parse(setVideoSchema, body).mediaId.toLowerCase();
    const oldKeys = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:owner-cover'), hashtext(${userId}::text))`;
      const old = await tx.ownerCoverVideo.findUnique({
        where: { userId_lang: { userId, lang } },
        select: { mediaId: true },
      });
      if (old?.mediaId === mediaId) return [];
      const claimed = await this.media.claimAssetsIn(tx, userId, [mediaId], 'PROFILE_COVER_VIDEO');
      if (!claimed) throw AppException.validation([{ field: 'mediaId', issue: 'invalid_value' }]);
      await tx.ownerCoverVideo.upsert({
        where: { userId_lang: { userId, lang } },
        create: { userId, lang, mediaId },
        update: { mediaId, setAt: this.clock.now() },
      });
      const keys = old ? await this.deleteAssetIn(tx, old.mediaId) : [];
      await this.audit.recordIn(tx, {
        action: AuditAction.OWNER_COVER_VIDEO_SET,
        actorUserId: userId,
        targetType: 'user',
        targetId: userId,
        metadata: { lang },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      return keys;
    });
    await this.media.deleteObjects(oldKeys);
    return this.coverVideo(userId);
  }

  /** `DELETE /me/cover-video/{lang}`: idempotent; works while uploads are off. */
  async removeCoverVideo(userId: string, rawLang: string, meta: OwnerMeta): Promise<OwnerCoverVideoDto> {
    const lang = this.langOf(rawLang);
    await assertKabsoOwner(this.prisma, userId);
    const oldKeys = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:owner-cover'), hashtext(${userId}::text))`;
      const old = await tx.ownerCoverVideo.findUnique({
        where: { userId_lang: { userId, lang } },
        select: { mediaId: true },
      });
      if (!old) return [];
      await tx.ownerCoverVideo.delete({ where: { userId_lang: { userId, lang } } });
      const keys = await this.deleteAssetIn(tx, old.mediaId);
      await this.audit.recordIn(tx, {
        action: AuditAction.OWNER_COVER_VIDEO_REMOVE,
        actorUserId: userId,
        targetType: 'user',
        targetId: userId,
        metadata: { lang },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      return keys;
    });
    await this.media.deleteObjects(oldKeys);
    return this.coverVideo(userId);
  }

  /** Deletes a replaced video's asset row; returns its object keys (deleted after commit). */
  private async deleteAssetIn(tx: Tx, mediaId: string): Promise<string[]> {
    const gone = await tx.mediaAsset.delete({
      where: { id: mediaId },
      select: { largeKey: true, thumbKey: true, posterKey: true },
    });
    return [gone.largeKey, gone.thumbKey, ...(gone.posterKey ? [gone.posterKey] : [])];
  }

  // ---- «رحلة Kabso» (§10.112.3) -------------------------------------------------------------------------------------

  /** `GET /users/{username}/journey`: in order; empty unless the user is the app owner; 404 like the profile. */
  async journeyOf(username: string): Promise<{ data: JourneyMilestoneDto[] }> {
    const user = await this.users.findActivePublicUser(username);
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    if (!(await isKabsoOwner(this.prisma, user.id))) return { data: [] };
    return { data: await this.milestones(this.prisma, user.id) };
  }

  private async milestones(db: Tx | PrismaService, ownerId: string): Promise<JourneyMilestoneDto[]> {
    const rows = await db.ownerJourneyMilestone.findMany({
      where: { ownerId },
      orderBy: [{ position: 'asc' }, { createdAt: 'asc' }],
    });
    return rows.map(toMilestoneDto);
  }

  /** Serializes one owner's journey changes (positions, the 30 limit, «الأحدث»). */
  private async lockJourney(tx: Tx, ownerId: string): Promise<void> {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:owner-journey'), hashtext(${ownerId}::text))`;
  }

  async createMilestone(ownerId: string, body: unknown, meta: OwnerMeta): Promise<JourneyMilestoneDto> {
    await assertKabsoOwner(this.prisma, ownerId);
    const input = parse(createMilestoneSchema, body);
    return this.prisma.$transaction(async (tx) => {
      await this.lockJourney(tx, ownerId);
      const count = await tx.ownerJourneyMilestone.count({ where: { ownerId } });
      if (count >= MAX_JOURNEY_MILESTONES) throw new AppException(ErrorCode.OWNER_JOURNEY_LIMIT);
      if (input.latest)
        await tx.ownerJourneyMilestone.updateMany({ where: { ownerId }, data: { latest: false } });
      const row = await tx.ownerJourneyMilestone.create({
        data: {
          ownerId,
          titleAr: input.titleAr,
          titleEn: input.titleEn,
          lineAr: input.lineAr ?? null,
          lineEn: input.lineEn ?? null,
          year: input.year,
          month: input.month,
          icon: input.icon,
          latest: input.latest ?? false,
          position: count,
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.OWNER_JOURNEY_CREATE,
        actorUserId: ownerId,
        targetType: 'owner_journey_milestone',
        targetId: row.id,
        ip: meta.ip,
        requestId: meta.requestId,
      });
      return toMilestoneDto(row);
    });
  }

  async updateMilestone(
    ownerId: string,
    milestoneId: string,
    body: unknown,
    meta: OwnerMeta,
  ): Promise<JourneyMilestoneDto> {
    await assertKabsoOwner(this.prisma, ownerId);
    const input = parse(updateMilestoneSchema, body);
    if (!isUuid(milestoneId)) throw new AppException(ErrorCode.NOT_FOUND);
    const id = milestoneId.toLowerCase();
    return this.prisma.$transaction(async (tx) => {
      await this.lockJourney(tx, ownerId);
      const found = await tx.ownerJourneyMilestone.findFirst({
        where: { id, ownerId },
        select: { id: true },
      });
      if (!found) throw new AppException(ErrorCode.NOT_FOUND);
      if (input.latest) {
        await tx.ownerJourneyMilestone.updateMany({
          where: { ownerId, id: { not: id } },
          data: { latest: false },
        });
      }
      const row = await tx.ownerJourneyMilestone.update({
        where: { id },
        data: {
          ...(input.titleAr !== undefined ? { titleAr: input.titleAr } : {}),
          ...(input.titleEn !== undefined ? { titleEn: input.titleEn } : {}),
          ...(input.lineAr !== undefined ? { lineAr: input.lineAr } : {}),
          ...(input.lineEn !== undefined ? { lineEn: input.lineEn } : {}),
          ...(input.year !== undefined ? { year: input.year } : {}),
          ...(input.month !== undefined ? { month: input.month } : {}),
          ...(input.icon !== undefined ? { icon: input.icon } : {}),
          ...(input.latest !== undefined ? { latest: input.latest } : {}),
          updatedAt: this.clock.now(),
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.OWNER_JOURNEY_UPDATE,
        actorUserId: ownerId,
        targetType: 'owner_journey_milestone',
        targetId: id,
        metadata: { fields: Object.keys(input) },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      return toMilestoneDto(row);
    });
  }

  async deleteMilestone(ownerId: string, milestoneId: string, meta: OwnerMeta): Promise<void> {
    await assertKabsoOwner(this.prisma, ownerId);
    if (!isUuid(milestoneId)) throw new AppException(ErrorCode.NOT_FOUND);
    const id = milestoneId.toLowerCase();
    await this.prisma.$transaction(async (tx) => {
      await this.lockJourney(tx, ownerId);
      const gone = await tx.ownerJourneyMilestone.deleteMany({ where: { id, ownerId } });
      if (gone.count === 0) throw new AppException(ErrorCode.NOT_FOUND);
      await this.renumberIn(
        tx,
        ownerId,
        (await this.milestones(tx, ownerId)).map((m) => m.id),
      );
      await this.audit.recordIn(tx, {
        action: AuditAction.OWNER_JOURNEY_DELETE,
        actorUserId: ownerId,
        targetType: 'owner_journey_milestone',
        targetId: id,
        ip: meta.ip,
        requestId: meta.requestId,
      });
    });
  }

  /** `PUT /owner/journey/order`: `ids` must be exactly the owner's milestones, each once. */
  async reorder(ownerId: string, body: unknown, meta: OwnerMeta): Promise<{ data: JourneyMilestoneDto[] }> {
    await assertKabsoOwner(this.prisma, ownerId);
    const ids = parse(reorderSchema, body).ids.map((i) => i.toLowerCase());
    return this.prisma.$transaction(async (tx) => {
      await this.lockJourney(tx, ownerId);
      const current = await this.milestones(tx, ownerId);
      const known = new Set(current.map((m) => m.id));
      if (ids.length !== known.size || new Set(ids).size !== ids.length || ids.some((i) => !known.has(i))) {
        throw AppException.validation([{ field: 'ids', issue: 'invalid_value' }]);
      }
      await this.renumberIn(tx, ownerId, ids);
      await this.audit.recordIn(tx, {
        action: AuditAction.OWNER_JOURNEY_REORDER,
        actorUserId: ownerId,
        targetType: 'user',
        targetId: ownerId,
        metadata: { count: ids.length },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      return { data: await this.milestones(tx, ownerId) };
    });
  }

  private async renumberIn(tx: Tx, ownerId: string, ids: readonly string[]): Promise<void> {
    for (const [position, id] of ids.entries()) {
      await tx.ownerJourneyMilestone.updateMany({ where: { id, ownerId }, data: { position } });
    }
  }

  // ---- «في البحث تظهر صفحة مؤسس البرنامج دائماً» (§10.112.9) ------------------------------------------------------

  /**
   * `GET /search/featured`: the app owner pinned at the top of search — the primary ACTIVE OWNER (the staff ID «Kabso»,
   * else the earliest grant), as a `UserSummary` with whether the caller follows him. Null when there is no ACTIVE owner
   * or a block stands either way. Never a hard-coded account.
   */
  async featured(
    viewerId: string,
  ): Promise<{ owner: (UserSummaryDto & { isFollowing: boolean; isSelf: boolean }) | null }> {
    const [row] = await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT u.id::text AS id
        FROM user_admin_permissions p
        JOIN users u ON u.id = p.user_id AND u.status = 'ACTIVE'::user_status
        LEFT JOIN staff_ids s ON s.user_id = u.id
       WHERE p.permission = 'OWNER'::admin_permission
       ORDER BY (s.number = 0) DESC NULLS LAST, p.granted_at, u.id
       LIMIT 1`;
    if (!row) return { owner: null };
    const isSelf = row.id === viewerId;
    if (!isSelf) {
      const blocks = await this.prisma.userBlock.count({
        where: {
          OR: [
            { blockerId: viewerId, blockedId: row.id },
            { blockerId: row.id, blockedId: viewerId },
          ],
        },
      });
      if (blocks > 0) return { owner: null };
    }
    const [user, follow] = await Promise.all([
      this.prisma.user.findUniqueOrThrow({ where: { id: row.id }, select: USER_SUMMARY_SELECT }),
      isSelf
        ? Promise.resolve(null)
        : this.prisma.follow.findUnique({
            where: { followerId_followeeId: { followerId: viewerId, followeeId: row.id } },
            select: { followerId: true },
          }),
    ]);
    return { owner: { ...userSummary(user), isFollowing: follow !== null, isSelf } };
  }

  // ---- «لوحة المؤسس» (§10.112.4) ------------------------------------------------------------------------------------

  /** `GET /owner/dashboard`: owner only; one value cached 60 s for every owner (never in a public response). */
  async dashboard(userId: string): Promise<OwnerDashboardDto> {
    await assertKabsoOwner(this.prisma, userId);
    const cached = await this.redis.get(DASHBOARD_CACHE_KEY).catch(() => null);
    if (cached) return JSON.parse(cached) as OwnerDashboardDto;
    const fresh = await this.computeDashboard(this.clock.now());
    await this.redis
      .set(DASHBOARD_CACHE_KEY, JSON.stringify(fresh), 'EX', DASHBOARD_CACHE_SECONDS)
      .catch(() => undefined);
    return fresh;
  }

  /** The numbers at `now` (exported through the service for the tests). */
  async computeDashboard(now: Date): Promise<OwnerDashboardDto> {
    const zone = this.config.adminPanel.dashboardTimeZone;
    const since = dayStart(now, zone);
    const onlineFrom = new Date(now.getTime() - DASHBOARD_ONLINE_MINUTES * 60_000);
    const [onlineNow, liveRoomsNow, web, agents] = await Promise.all([
      this.prisma.user.count({ where: { status: 'ACTIVE', lastActiveAt: { gt: onlineFrom } } }),
      this.prisma.liveRoom.count({ where: { status: 'LIVE' } }),
      // Owner (PP-58, «كيف له دخل!!»): only money Kabso itself receives — the store's card top-ups (less refunds) and
      // what agents pay Kabso for their coin stock (`recharge-admin topup`, D185). An agent's resale to users
      // (`recharge_sales`, in local currency) is the agent's money, never counted.
      this.prisma.$queryRaw<{ currency: string; n: bigint | null }[]>`
        SELECT upper(currency) AS currency, sum(amount_minor - refunded_minor) AS n FROM topup_orders
         WHERE credited_at IS NOT NULL AND credited_at >= ${since} GROUP BY 1`,
      this.prisma.$queryRaw<{ currency: string; n: bigint | null }[]>`
        SELECT upper(currency) AS currency, sum(paid_minor) AS n FROM recharge_topups
         WHERE created_at >= ${since} GROUP BY 1`,
    ]);
    const byCurrency = new Map<string, { websiteMinor: number; agentsMinor: number }>();
    const add = (rows: { currency: string; n: bigint | null }[], key: 'websiteMinor' | 'agentsMinor') => {
      for (const r of rows) {
        const line = byCurrency.get(r.currency) ?? { websiteMinor: 0, agentsMinor: 0 };
        line[key] += Math.max(Number(r.n ?? 0), 0);
        byCurrency.set(r.currency, line);
      }
    };
    add(web, 'websiteMinor');
    add(agents, 'agentsMinor');
    const usd = byCurrency.get('USD') ?? { websiteMinor: 0, agentsMinor: 0 };
    const { websiteMinor, agentsMinor } = usd;
    const otherCurrencies = [...byCurrency.entries()]
      .filter(([c, l]) => c !== 'USD' && l.websiteMinor + l.agentsMinor > 0)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([currency, l]) => ({ currency, ...l, amountMinor: l.websiteMinor + l.agentsMinor }));
    return {
      onlineNow,
      onlineWindowMinutes: DASHBOARD_ONLINE_MINUTES,
      liveRoomsNow,
      income: {
        day: dayKey(now, zone),
        timeZone: zone,
        currency: 'USD',
        amountMinor: websiteMinor + agentsMinor,
        websiteMinor,
        agentsMinor,
        otherCurrencies,
      },
      generatedAt: now.toISOString(),
    };
  }
}
