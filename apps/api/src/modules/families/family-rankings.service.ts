import { Inject, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { PageDto } from '../posts/post-views.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { FAMILY_RANKING_MAX, type FamilyRankingBoard } from './families.constants.js';
import type { FamilyRankingsQuery } from './families.schemas.js';
import { card, FAMILY_SELECT, type FamilyCardDto } from './families.service.js';
import { familyWindow, type FamilyWindow } from './family-views.js';
import { isUuid } from '../live/live.schemas.js';

/** `FamilyRankingEntry` (v1.25-live). */
export interface FamilyRankingEntryDto {
  rank: number;
  family: FamilyCardDto;
  /** `PRESTIGE`: family points gained in the month; `ACTIVE`: members active this week. */
  score: number;
}

/** `FamilyRankings` (v1.25-live). */
export interface FamilyRankingsDto extends PageDto<FamilyRankingEntryDto> {
  board: FamilyRankingBoard;
  startsAt: string;
  endsAt: string;
  /** The caller's family (rank null with a score of 0); null when the caller has none. */
  me: { family: FamilyCardDto; rank: number | null; score: number } | null;
}

/** One board's place of a family (`FamilyStanding`). */
export interface FamilyBoardStandingDto {
  rank: number | null;
  score: number;
  startsAt: string;
  endsAt: string;
}

/** `FamilyStanding` (v1.25-live): a family's place on both boards. */
export interface FamilyStandingDto {
  familyId: string;
  prestige: FamilyBoardStandingDto;
  active: FamilyBoardStandingDto;
}

/**
 * The family boards (CP-022, owner D116, CONVENTIONS §10.25), one region for everyone (the
 * window follows LIVE_RANKINGS_TIME_ZONE like the other rankings):
 * - `PRESTIGE` (هيبة العائلة): family points gained in the current calendar month, from
 *   `family_points_ledger` (every coin a member spent while in the family, §10.21).
 * - `ACTIVE` (الأكثر نشاطاً): how many of the family's members (ACTIVE accounts) were active in the
 *   app during the current week (Monday 00:00), from `users.last_active_at`; members who turned
 *   off `showActivityStatus` are not counted (a count must not reveal them).
 * Families with a score of 0 are not listed; ties go to the family with more points overall, then
 * by id. At most {@link FAMILY_RANKING_MAX} families, paged; disbanded families never appear.
 */
@Injectable()
export class FamilyRankingsService {
  private readonly cursors: SocialCursorCodec;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  private window(board: FamilyRankingBoard): Promise<FamilyWindow> {
    return familyWindow(
      this.prisma,
      board === 'PRESTIGE' ? 'month' : 'week',
      this.config.live.rankingsTimeZone,
      this.clock.now(),
    );
  }

  /** The board's scores (family_id, score > 0, points), as a subquery. */
  private scores(board: FamilyRankingBoard, w: FamilyWindow): Prisma.Sql {
    const raw =
      board === 'PRESTIGE'
        ? Prisma.sql`SELECT family_id, SUM(points)::bigint AS score FROM family_points_ledger
                      WHERE created_at >= ${w.start}::timestamptz AND created_at < ${w.end}::timestamptz
                      GROUP BY family_id`
        : Prisma.sql`SELECT fm.family_id, COUNT(*)::bigint AS score
                       FROM family_members fm
                       JOIN users u ON u.id = fm.user_id AND u.status = 'ACTIVE'
                        AND u.last_active_at >= ${w.start}::timestamptz
                        AND u.last_active_at < ${w.end}::timestamptz
                       LEFT JOIN privacy_settings ps ON ps.user_id = fm.user_id
                      WHERE COALESCE(ps.show_activity_status, true)
                      GROUP BY fm.family_id`;
    return Prisma.sql`
      SELECT f.id, s.score, f.points,
             ROW_NUMBER() OVER (ORDER BY s.score DESC, f.points DESC, f.id) AS rank
        FROM (${raw}) s
        JOIN families f ON f.id = s.family_id AND f.disbanded_at IS NULL
       WHERE s.score > 0`;
  }

  /** The exact place and score of `familyId` on a board (rank null with 0). */
  private async placeOf(
    board: FamilyRankingBoard,
    w: FamilyWindow,
    familyId: string,
  ): Promise<{ rank: number | null; score: number }> {
    const [row] = await this.prisma.$queryRaw<{ rank: bigint; score: bigint }[]>`
      SELECT r.rank, r.score FROM (${this.scores(board, w)}) r WHERE r.id = ${familyId}::uuid`;
    return row ? { rank: Number(row.rank), score: Number(row.score) } : { rank: null, score: 0 };
  }

  /** `GET /families/rankings?board=PRESTIGE|ACTIVE` (top 100, paged; `me` is the caller's family). */
  async list(callerId: string, query: FamilyRankingsQuery): Promise<FamilyRankingsDto> {
    const board = query.board;
    const w = await this.window(board);
    const scope = `family-rankings:${board}:${w.start.getTime()}`;
    let offset = 0;
    if (query.cursor !== undefined) {
      const after = this.cursors.decode(query.cursor, scope);
      if (!after || after.n === undefined) {
        throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
      }
      offset = after.n;
    }
    const take = Math.max(0, Math.min(query.limit, FAMILY_RANKING_MAX - offset));
    const rows =
      take === 0
        ? []
        : await this.prisma.$queryRaw<{ id: string; score: bigint; rank: bigint }[]>`
            SELECT r.id::text AS id, r.score, r.rank FROM (${this.scores(board, w)}) r
             ORDER BY r.rank LIMIT ${take + 1} OFFSET ${offset}`;
    const more = rows.length > take && offset + take < FAMILY_RANKING_MAX;
    const page = rows.slice(0, take);
    const families = await this.prisma.family.findMany({
      where: { id: { in: page.map((r) => r.id) } },
      select: FAMILY_SELECT,
    });
    const byId = new Map(families.map((f) => [f.id, card(f)]));
    const last = page[page.length - 1];

    let me: FamilyRankingsDto['me'] = null;
    const mine = await this.prisma.familyMember.findUnique({
      where: { userId: callerId },
      select: { family: { select: FAMILY_SELECT } },
    });
    if (mine) me = { family: card(mine.family), ...(await this.placeOf(board, w, mine.family.id)) };

    return {
      board,
      startsAt: w.start.toISOString(),
      endsAt: w.end.toISOString(),
      data: page.flatMap((r) => {
        const family = byId.get(r.id);
        return family ? [{ rank: Number(r.rank), family, score: Number(r.score) }] : [];
      }),
      page: {
        hasMore: more,
        nextCursor:
          more && last
            ? this.cursors.encode(scope, { at: w.start, id: last.id, n: offset + page.length })
            : null,
      },
      me,
    };
  }

  /** `GET /families/{familyId}/rankings`: the family's place on both boards (404 like the family). */
  async standing(familyId: string): Promise<FamilyStandingDto> {
    if (!isUuid(familyId)) throw new AppException(ErrorCode.NOT_FOUND);
    const id = familyId.toLowerCase();
    const exists = await this.prisma.family.count({ where: { id, disbandedAt: null } });
    if (exists === 0) throw new AppException(ErrorCode.NOT_FOUND);
    const [pw, aw] = await Promise.all([this.window('PRESTIGE'), this.window('ACTIVE')]);
    const [prestige, active] = await Promise.all([
      this.placeOf('PRESTIGE', pw, id),
      this.placeOf('ACTIVE', aw, id),
    ]);
    return {
      familyId: id,
      prestige: { ...prestige, startsAt: pw.start.toISOString(), endsAt: pw.end.toISOString() },
      active: { ...active, startsAt: aw.start.toISOString(), endsAt: aw.end.toISOString() },
    };
  }
}
