import { Inject, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { cpGiftPresetFor, cpNextTier, cpTierName } from '../couples/couples.constants.js';
import { CouplesService, type CpCoupleDto } from '../couples/couples.service.js';
import { addCpPointsIn } from '../couples/cp-points.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { isUuid } from '../live/live.schemas.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import { findOwnCouple, findVisibleCouple, type VisibleCoupleRow } from './cp-couple-visibility.js';
import {
  CP_PRIVILEGES,
  cpHasPrivilege,
  cpPrivilegeName,
  cpPrivilegesFor,
  type CpPrivilegeCode,
} from './cp-privileges.js';
import {
  CP_RANKING_MAX,
  CP_TASKS,
  type CpRankingPeriod,
  type CpTaskCode,
  type CpTaskDef,
} from './cp-space.constants.js';
import type { CpPageQuery, CpRankingsQuery } from './cp-space.schemas.js';

type Tx = Prisma.TransactionClient;
type Db = Pick<Tx, '$queryRaw'>;

// ---- Response shapes (openapi v1.24-live, CP-021) ----------------------------------------------

/** `CpTask`. */
export interface CpTaskDto {
  code: CpTaskCode;
  name: string;
  description: string;
  /** CP points the claim adds. */
  reward: number;
  progress: number;
  target: number;
  completed: boolean;
  claimed: boolean;
}

/** `CpTasks`: today's tasks of the caller's couple. */
export interface CpTasksDto {
  /** The CP day (`YYYY-MM-DD` in `timeZone`). */
  day: string;
  timeZone: string;
  startsAt: string;
  /** When the tasks reset (the next 00:00 in `timeZone`). */
  resetsAt: string;
  checkedIn: { me: boolean; partner: boolean };
  tasks: CpTaskDto[];
}

/** `CpTaskClaimResult`. */
export interface CpTaskClaimResultDto {
  task: CpTaskDto;
  cp: CpCoupleDto;
}

/** `CpPrivilege`. */
export interface CpPrivilegeDto {
  code: CpPrivilegeCode;
  name: string;
  unlockLevel: number;
  unlocked: boolean;
  iconKey: string;
}

/** `CpPrivileges`. */
export interface CpPrivilegesDto {
  /** The caller's CP level, or null when not paired (then nothing is unlocked). */
  level: number | null;
  privileges: CpPrivilegeDto[];
}

/** `CpCouplePublic`: a couple's CP space as anyone may read it. */
export interface CpCouplePublicDto {
  id: string;
  /** Both partners, by user id. */
  partners: [UserSummaryDto, UserSummaryDto];
  since: string;
  days: number;
  points: number;
  level: number;
  levelName: string;
  nextLevelName: string | null;
  pointsToNext: number | null;
  privileges: CpPrivilegeCode[];
  /** The reader is one of the partners. */
  mine: boolean;
}

/** `CpGiftWallEntry`. */
export interface CpGiftWallEntryDto {
  id: string;
  amount: number;
  /** The preset's code (`CpConfig.gifts`), or null for an amount no longer offered. */
  giftCode: string | null;
  sender: UserSummaryDto;
  receiver: UserSummaryDto;
  createdAt: string;
}

/** `CpGiftWall`. */
export interface CpGiftWallDto extends PageDto<CpGiftWallEntryDto> {
  totals: { gifts: number; coins: number };
}

/** `CpRankingEntry`. */
export interface CpRankingEntryDto {
  rank: number;
  coupleId: string;
  partners: [UserSummaryDto, UserSummaryDto];
  level: number;
  levelName: string;
  points: number;
}

/** `CpRankings`. */
export interface CpRankingsDto extends PageDto<CpRankingEntryDto> {
  period: CpRankingPeriod;
  /** The CP week's window (`WEEK`), null for `ALL`. */
  startsAt: string | null;
  endsAt: string | null;
  /** The caller's couple (rank null with 0 points); null when not paired. */
  me: { coupleId: string; rank: number | null; points: number } | null;
}

const DAY_MS = 24 * 3600_000;

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

function badCursor(): AppException {
  return AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
}

/**
 * The CP space (CP-021, owner D112, CONVENTIONS §10.24): daily CP tasks and their claims, CP
 * privileges, the public couple page, the CP gift wall and the couples ranking. Confessions are in
 * {@link CpConfessionsService}. The CP day and week follow `LIVE_RANKINGS_TIME_ZONE` (the app's one
 * region, §10.15; default UTC).
 */
@Injectable()
export class CpSpaceService {
  private readonly cursors: SocialCursorCodec;

  constructor(
    private readonly prisma: PrismaService,
    private readonly couples: CouplesService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  private get zone(): string {
    return this.config.live.rankingsTimeZone;
  }

  /** The CP day of `now`: its date and window (UTC instants). */
  private async cpDayIn(db: Db, now: Date): Promise<{ day: string; start: Date; end: Date }> {
    const tz = this.zone;
    const [w] = await db.$queryRaw<{ day: string; start: Date; end: Date }[]>`
      SELECT to_char((${now}::timestamptz AT TIME ZONE ${tz}::text)::date, 'YYYY-MM-DD') AS day,
             (((${now}::timestamptz AT TIME ZONE ${tz}::text)::date)::timestamp AT TIME ZONE ${tz}::text) AS start,
             ((((${now}::timestamptz AT TIME ZONE ${tz}::text)::date) + 1)::timestamp
                AT TIME ZONE ${tz}::text) AS "end"`;
    return w!;
  }

  /** The CP week of `now` (Monday 00:00 in the CP zone, ISO week). */
  private async cpWeek(now: Date): Promise<{ start: Date; end: Date }> {
    const tz = this.zone;
    const [w] = await this.prisma.$queryRaw<{ start: Date; end: Date }[]>`
      SELECT (date_trunc('week', ${now}::timestamptz AT TIME ZONE ${tz}::text) AT TIME ZONE ${tz}::text) AS start,
             ((date_trunc('week', ${now}::timestamptz AT TIME ZONE ${tz}::text) + interval '7 days')
                AT TIME ZONE ${tz}::text) AS "end"`;
    return w!;
  }

  private async summaries(ids: readonly string[]): Promise<Map<string, UserSummaryDto>> {
    const rows = await this.prisma.user.findMany({
      where: { id: { in: [...new Set(ids)] } },
      select: USER_SUMMARY_SELECT,
    });
    return new Map(rows.map((r) => [r.id, userSummary(r)]));
  }

  // ---------------------------------------------------------------------------------------------
  // Daily tasks

  /** How far each task is for `couple` in the CP day `window`. */
  private async progressIn(
    db: Db,
    couple: VisibleCoupleRow,
    window: { day: string; start: Date; end: Date },
  ): Promise<{ progress: Record<CpTaskCode, number>; checkedIn: string[] }> {
    const from = couple.since > window.start ? couple.since : window.start;
    const [row] = await db.$queryRaw<{ checked_in: string[]; gift: boolean; chat: boolean }[]>`
      SELECT
        ARRAY(SELECT user_id::text FROM cp_check_ins
               WHERE couple_id = ${couple.id}::uuid AND day = ${window.day}::date) AS checked_in,
        EXISTS (SELECT 1 FROM cp_gifts
                 WHERE couple_id = ${couple.id}::uuid
                   AND created_at >= ${window.start}::timestamptz AND created_at < ${window.end}::timestamptz) AS gift,
        EXISTS (SELECT 1 FROM live_chat_messages m1
                 WHERE m1.user_id = ${couple.user_a_id}::uuid AND m1.deleted_at IS NULL
                   AND m1.created_at >= ${from}::timestamptz AND m1.created_at < ${window.end}::timestamptz
                   AND EXISTS (SELECT 1 FROM live_chat_messages m2
                                WHERE m2.room_id = m1.room_id AND m2.user_id = ${couple.user_b_id}::uuid
                                  AND m2.deleted_at IS NULL
                                  AND m2.created_at >= ${from}::timestamptz
                                  AND m2.created_at < ${window.end}::timestamptz)) AS chat`;
    const checkedIn = row?.checked_in ?? [];
    return {
      checkedIn,
      progress: {
        CHECK_IN: checkedIn.length,
        SEND_GIFT: row?.gift ? 1 : 0,
        CHAT_TOGETHER: row?.chat ? 1 : 0,
      },
    };
  }

  private taskDto(def: CpTaskDef, progress: number, claimed: boolean, lang: ContentLanguage): CpTaskDto {
    return {
      code: def.code,
      name: lang === 'ar' ? def.nameAr : def.nameEn,
      description: lang === 'ar' ? def.descriptionAr : def.descriptionEn,
      reward: def.reward,
      progress: Math.min(progress, def.target),
      target: def.target,
      completed: progress >= def.target,
      claimed,
    };
  }

  /** `GET /cp/me/tasks`: today's tasks of the caller's couple (409 CP_NOT_PAIRED). */
  async tasks(callerId: string, lang: ContentLanguage): Promise<CpTasksDto> {
    const couple = await findOwnCouple(this.prisma, callerId);
    if (!couple) throw new AppException(ErrorCode.CP_NOT_PAIRED);
    const window = await this.cpDayIn(this.prisma, this.clock.now());
    const { progress, checkedIn } = await this.progressIn(this.prisma, couple, window);
    const claims = await this.prisma.cpTaskClaim.findMany({
      where: { coupleId: couple.id, day: new Date(`${window.day}T00:00:00.000Z`) },
      select: { taskCode: true },
    });
    const claimed = new Set(claims.map((c) => c.taskCode));
    return {
      day: window.day,
      timeZone: this.zone,
      startsAt: window.start.toISOString(),
      resetsAt: window.end.toISOString(),
      checkedIn: { me: checkedIn.includes(callerId), partner: checkedIn.includes(couple.partner_id) },
      tasks: CP_TASKS.map((def) => this.taskDto(def, progress[def.code], claimed.has(def.code), lang)),
    };
  }

  /**
   * `POST /cp/me/check-in`: the caller checked in on the CP space today (once per partner and CP
   * day). 201 when this call checked in, 200 when already done today; 409 CP_NOT_PAIRED.
   */
  async checkIn(callerId: string, lang: ContentLanguage): Promise<{ created: boolean; result: CpTasksDto }> {
    const couple = await findOwnCouple(this.prisma, callerId);
    if (!couple) throw new AppException(ErrorCode.CP_NOT_PAIRED);
    const now = this.clock.now();
    const window = await this.cpDayIn(this.prisma, now);
    const written = await this.prisma.cpCheckIn.createMany({
      data: [
        {
          coupleId: couple.id,
          day: new Date(`${window.day}T00:00:00.000Z`),
          userId: callerId,
          createdAt: now,
        },
      ],
      skipDuplicates: true,
    });
    return { created: written.count > 0, result: await this.tasks(callerId, lang) };
  }

  /**
   * `POST /cp/me/tasks/{code}/claim`. Order: 404 (unknown code) → 409 CP_NOT_PAIRED → already
   * claimed today by either partner → 200 (nothing added again) → 409 CP_TASK_NOT_COMPLETED → 201.
   * The claim and the couple's points (ledger TASK, tier, D111 seat version) are one transaction
   * with the couple locked, so two partners claiming at once add the reward once.
   */
  async claim(
    callerId: string,
    rawCode: string,
    lang: ContentLanguage,
  ): Promise<{ created: boolean; result: CpTaskClaimResultDto }> {
    const def = CP_TASKS.find((t) => t.code === rawCode);
    if (!def) throw notFound();
    const now = this.clock.now();
    let created: boolean;
    try {
      created = await this.prisma.$transaction(async (tx) => {
        const couple = await findOwnCouple(tx, callerId, true);
        if (!couple) throw new AppException(ErrorCode.CP_NOT_PAIRED);
        const window = await this.cpDayIn(tx, now);
        const day = new Date(`${window.day}T00:00:00.000Z`);
        const existing = await tx.cpTaskClaim.findUnique({
          where: { coupleId_day_taskCode: { coupleId: couple.id, day, taskCode: def.code } },
          select: { id: true },
        });
        if (existing) return false;
        const { progress } = await this.progressIn(tx, couple, window);
        if (progress[def.code] < def.target) throw new AppException(ErrorCode.CP_TASK_NOT_COMPLETED);
        const claim = await tx.cpTaskClaim.create({
          data: {
            coupleId: couple.id,
            day,
            taskCode: def.code,
            points: def.reward,
            claimedById: callerId,
            createdAt: now,
          },
          select: { id: true },
        });
        await addCpPointsIn(tx, {
          coupleId: couple.id,
          points: def.reward,
          source: 'TASK',
          referenceId: claim.id,
          at: now,
        });
        return true;
      });
    } catch (err) {
      const index = violatedUniqueIndex(err);
      if (index === null || !index.includes('cp_task_claims_once')) throw err;
      created = false;
    }
    const tasks = await this.tasks(callerId, lang);
    const cp = (await this.couples.mine(callerId, lang)).cp;
    if (!cp) throw new AppException(ErrorCode.CP_NOT_PAIRED);
    return { created, result: { task: tasks.tasks.find((t) => t.code === def.code)!, cp } };
  }

  // ---------------------------------------------------------------------------------------------
  // Privileges

  private privilegeDtos(level: number | null, lang: ContentLanguage): CpPrivilegeDto[] {
    return CP_PRIVILEGES.map((p) => ({
      code: p.code,
      name: cpPrivilegeName(p, lang),
      unlockLevel: p.unlockLevel,
      unlocked: level !== null && level >= p.unlockLevel,
      iconKey: p.iconKey,
    }));
  }

  /** `GET /cp/me/privileges`: the five privileges with `unlocked` for the caller's couple. */
  async privileges(callerId: string, lang: ContentLanguage): Promise<CpPrivilegesDto> {
    const couple = await findOwnCouple(this.prisma, callerId);
    const level = couple?.level ?? null;
    return { level, privileges: this.privilegeDtos(level, lang) };
  }

  // ---------------------------------------------------------------------------------------------
  // The public couple page

  private async visibleOr404(readerId: string, coupleId: string): Promise<VisibleCoupleRow> {
    if (!isUuid(coupleId)) throw notFound();
    const couple = await findVisibleCouple(this.prisma, coupleId.toLowerCase(), readerId);
    if (!couple) throw notFound();
    return couple;
  }

  /** `GET /cp/couples/{coupleId}`: a couple's CP space, read-only for others (404 when hidden). */
  async couple(readerId: string, coupleId: string, lang: ContentLanguage): Promise<CpCouplePublicDto> {
    const c = await this.visibleOr404(readerId, coupleId);
    const users = await this.summaries([c.user_a_id, c.user_b_id]);
    const points = Number(c.points);
    const next = cpNextTier(c.level);
    return {
      id: c.id,
      partners: [users.get(c.user_a_id)!, users.get(c.user_b_id)!],
      since: c.since.toISOString(),
      days: Math.floor((this.clock.now().getTime() - c.since.getTime()) / DAY_MS) + 1,
      points,
      level: c.level,
      levelName: cpTierName(c.level, lang),
      nextLevelName: next ? cpTierName(next.level, lang) : null,
      pointsToNext: next ? Math.max(0, next.minPoints - points) : null,
      privileges: cpPrivilegesFor(c.level),
      mine: readerId === c.user_a_id || readerId === c.user_b_id,
    };
  }

  // ---------------------------------------------------------------------------------------------
  // The CP gift wall

  /**
   * `GET /cp/couples/{coupleId}/gift-wall`: the couple's CP gifts, newest first, with totals.
   * 404 like the couple page; then 403 CP_PRIVILEGE_LOCKED for a reader who is not a partner while
   * the couple has not unlocked GIFT_WALL (the partners always read their own).
   */
  async giftWall(readerId: string, coupleId: string, query: CpPageQuery): Promise<CpGiftWallDto> {
    const c = await this.visibleOr404(readerId, coupleId);
    const mine = readerId === c.user_a_id || readerId === c.user_b_id;
    if (!mine && !cpHasPrivilege(c.level, 'GIFT_WALL')) throw new AppException(ErrorCode.CP_PRIVILEGE_LOCKED);
    const scope = `cp-gift-wall:${c.id}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw badCursor();
    }
    const rows = await this.prisma.cpGift.findMany({
      where: {
        coupleId: c.id,
        ...(after
          ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
      select: { id: true, amount: true, senderId: true, receiverId: true, createdAt: true },
    });
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];
    const users = await this.summaries([c.user_a_id, c.user_b_id]);
    const totals = await this.prisma.cpGift.aggregate({
      where: { coupleId: c.id },
      _count: { _all: true },
      _sum: { amount: true },
    });
    return {
      data: page.map((g) => ({
        id: g.id,
        amount: g.amount,
        giftCode: cpGiftPresetFor(g.amount)?.code ?? null,
        sender: users.get(g.senderId)!,
        receiver: users.get(g.receiverId)!,
        createdAt: g.createdAt.toISOString(),
      })),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
      totals: { gifts: totals._count._all, coins: totals._sum.amount ?? 0 },
    };
  }

  // ---------------------------------------------------------------------------------------------
  // The couples ranking

  /**
   * `GET /cp/rankings?period=WEEK|ALL`: ongoing couples by the CP points they gained this CP week
   * (`cp_points_ledger`) or in all (`cp_couples.points`), highest first, ties by couple id; only
   * couples with points, both partners ACTIVE, and none with a block either way between the reader
   * and a partner. At most {@link CP_RANKING_MAX} couples, paged. `me` is the caller's couple.
   */
  async rankings(readerId: string, query: CpRankingsQuery, lang: ContentLanguage): Promise<CpRankingsDto> {
    const period = query.period;
    const window = period === 'WEEK' ? await this.cpWeek(this.clock.now()) : null;
    const scope = `cp-rankings:${period}:${window ? window.start.getTime() : 0}:${readerId}`;
    let offset = 0;
    if (query.cursor !== undefined) {
      const after = this.cursors.decode(query.cursor, scope);
      if (!after || after.n === undefined) throw badCursor();
      offset = after.n;
    }
    const take = Math.max(0, Math.min(query.limit, CP_RANKING_MAX - offset));
    const gains = window
      ? Prisma.sql`SELECT couple_id, SUM(points)::bigint AS points FROM cp_points_ledger
                    WHERE created_at >= ${window.start}::timestamptz AND created_at < ${window.end}::timestamptz
                    GROUP BY couple_id`
      : Prisma.sql`SELECT id AS couple_id, points FROM cp_couples WHERE ended_at IS NULL`;
    const ranked = Prisma.sql`
      SELECT c.id, c.user_a_id, c.user_b_id, c.level, g.points
        FROM (${gains}) g
        JOIN cp_couples c ON c.id = g.couple_id AND c.ended_at IS NULL
        JOIN users ua ON ua.id = c.user_a_id AND ua.status = 'ACTIVE'
        JOIN users ub ON ub.id = c.user_b_id AND ub.status = 'ACTIVE'
       WHERE g.points > 0
         AND (${readerId}::uuid IN (c.user_a_id, c.user_b_id) OR NOT EXISTS (
               SELECT 1 FROM user_blocks b
                WHERE (b.blocker_id = ${readerId}::uuid AND b.blocked_id IN (c.user_a_id, c.user_b_id))
                   OR (b.blocked_id = ${readerId}::uuid AND b.blocker_id IN (c.user_a_id, c.user_b_id))))`;
    const rows =
      take === 0
        ? []
        : await this.prisma.$queryRaw<
            { id: string; user_a_id: string; user_b_id: string; level: number; points: bigint }[]
          >`
            SELECT r.id::text AS id, r.user_a_id::text AS user_a_id, r.user_b_id::text AS user_b_id,
                   r.level, r.points
              FROM (${ranked}) r
             ORDER BY r.points DESC, r.id
             LIMIT ${take + 1} OFFSET ${offset}`;
    const more = rows.length > take && offset + take < CP_RANKING_MAX;
    const page = rows.slice(0, take);
    const users = await this.summaries(page.flatMap((r) => [r.user_a_id, r.user_b_id]));
    const last = page[page.length - 1];

    let me: CpRankingsDto['me'] = null;
    const own = await findOwnCouple(this.prisma, readerId);
    if (own) {
      const [mine] = await this.prisma.$queryRaw<{ points: bigint | null; ahead: bigint }[]>`
        WITH r AS (${ranked})
        SELECT (SELECT points FROM r WHERE id = ${own.id}::uuid) AS points,
               (SELECT count(*) FROM r
                 WHERE points > (SELECT points FROM r WHERE id = ${own.id}::uuid)
                    OR (points = (SELECT points FROM r WHERE id = ${own.id}::uuid) AND id < ${own.id}::uuid)) AS ahead`;
      const points = mine?.points ?? null;
      me = {
        coupleId: own.id,
        rank: points === null ? null : Number(mine!.ahead) + 1,
        points: points === null ? 0 : Number(points),
      };
    }

    return {
      period,
      startsAt: window ? window.start.toISOString() : null,
      endsAt: window ? window.end.toISOString() : null,
      data: page.map((r, i) => ({
        rank: offset + i + 1,
        coupleId: r.id,
        partners: [users.get(r.user_a_id)!, users.get(r.user_b_id)!],
        level: r.level,
        levelName: cpTierName(r.level, lang),
        points: Number(r.points),
      })),
      page: {
        hasMore: more,
        nextCursor:
          more && last
            ? this.cursors.encode(scope, {
                at: window ? window.start : new Date(0),
                id: last.id,
                n: offset + page.length,
              })
            : null,
      },
      me,
    };
  }
}
