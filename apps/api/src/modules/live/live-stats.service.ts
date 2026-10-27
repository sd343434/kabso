import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import type { LiveScoreDto, UserSummaryDto } from './live-rooms.service.js';
import { LiveRoomsService } from './live-rooms.service.js';
import { contributorsWhere } from './live-taps.service.js';
import {
  countryBreakdown,
  LIVE_STATS_TOP_SUPPORTERS,
  secondsBetween,
  type LiveViewerCountryDto,
} from './live-stats.js';

/** `LiveRoomViewerStats` (v1.27.6-live, D140). */
export interface LiveRoomViewerStatsDto {
  unique: number;
  guests: number;
  peak: number;
  atEnd: number;
  averageWatchSeconds: number;
}

/** `LiveRoomStats` (v1.27.6-live, D140, CONVENTIONS §10.31). */
export interface LiveRoomStatsDto {
  roomId: string;
  status: 'LIVE' | 'ENDED';
  startedAt: string;
  endedAt: string | null;
  durationSeconds: number;
  score: LiveScoreDto;
  hostOwnPoints: number;
  supporters: number;
  topSupporters: { user: UserSummaryDto; points: number }[];
  giftCount: number;
  chatMessages: number;
  newFollowers: number;
  viewers: LiveRoomViewerStatsDto | null;
  viewerCountries: LiveViewerCountryDto[];
}

/**
 * `GET /live/rooms/{roomId}/stats` (v1.27.6-live, D140, CONVENTIONS §10.31): the host's own
 * statistics of one live — aggregates only, never who watched from where. Reads `follows`,
 * `user_profiles` (country) and `users` (status) read-only, like the room lists
 * (DB_PHASE2_DISCOVERY §1).
 */
@Injectable()
export class LiveStatsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly clock: Clock,
  ) {}

  async stats(callerId: string, roomId: string): Promise<LiveRoomStatsDto> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.host_user_id !== callerId) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const until = row.ended_at ?? this.clock.now();
    const supportersWhere = contributorsWhere(row.id, row.host_user_id, callerId);

    const [own, supporters, top, gifts, chatMessages, newFollowers, peak] = await Promise.all([
      this.prisma.liveRoomTapper.findUnique({
        where: { roomId_userId: { roomId: row.id, userId: row.host_user_id } },
        select: { points: true },
      }),
      this.prisma.liveRoomTapper.count({ where: supportersWhere }),
      this.prisma.liveRoomTapper.findMany({
        where: supportersWhere,
        orderBy: [{ points: 'desc' }, { pointsAt: 'asc' }, { userId: 'asc' }],
        take: LIVE_STATS_TOP_SUPPORTERS,
        include: { user: { select: USER_SUMMARY_SELECT } },
      }),
      this.prisma.liveGift.aggregate({ where: { roomId: row.id }, _sum: { quantity: true } }),
      this.prisma.liveChatMessage.count({ where: { roomId: row.id, deletedAt: null } }),
      this.prisma.follow.count({
        where: {
          followeeId: row.host_user_id,
          createdAt: { gte: row.started_at, lte: until },
          follower: { status: 'ACTIVE' },
        },
      }),
      this.prisma.liveRoom.findUniqueOrThrow({ where: { id: row.id }, select: { peakViewerCount: true } }),
    ]);

    // Lives started before D140 have no audience record (`peak_viewer_count` NULL): no viewer stats.
    let viewers: LiveRoomViewerStatsDto | null = null;
    let viewerCountries: LiveViewerCountryDto[] = [];
    if (peak.peakViewerCount !== null) {
      const at = until.toISOString();
      const [audience] = await this.prisma.$queryRaw<{ unique: number; guests: number; watch_ms: bigint }[]>`
        SELECT count(*)::int AS unique,
               count(*) FILTER (WHERE a.user_id IS NULL)::int AS guests,
               COALESCE(sum(a.watch_ms + CASE WHEN a.open_since IS NULL THEN 0
                 ELSE GREATEST(0, floor(extract(epoch FROM (${at}::timestamptz - a.open_since)) * 1000))::bigint
               END), 0)::bigint AS watch_ms
          FROM live_room_audience a
         WHERE a.room_id = ${row.id}::uuid`;
      const unique = audience?.unique ?? 0;
      const countries = await this.prisma.$queryRaw<{ country: string | null; viewers: number }[]>`
        SELECT p.country_code AS country, count(*)::int AS viewers
          FROM live_room_audience a
          LEFT JOIN user_profiles p ON p.user_id = a.user_id
         WHERE a.room_id = ${row.id}::uuid
         GROUP BY p.country_code`;
      viewers = {
        unique,
        guests: audience?.guests ?? 0,
        peak: Math.max(peak.peakViewerCount, row.viewer_count),
        atEnd: row.viewer_count,
        averageWatchSeconds: unique === 0 ? 0 : Math.round(Number(audience?.watch_ms ?? 0n) / unique / 1000),
      };
      viewerCountries = countryBreakdown(countries);
    }

    return {
      roomId: row.id,
      status: row.status,
      startedAt: row.started_at.toISOString(),
      endedAt: row.ended_at?.toISOString() ?? null,
      durationSeconds: secondsBetween(row.started_at, until),
      score: {
        total: Number(row.score),
        tapPoints: Number(row.tap_points),
        supportPoints: Number(row.support_points),
      },
      hostOwnPoints: Number(own?.points ?? 0n),
      supporters,
      topSupporters: top.map((r) => ({ user: userSummary(r.user), points: Number(r.points) })),
      giftCount: gifts._sum.quantity ?? 0,
      chatMessages,
      newFollowers,
      viewers,
      viewerCountries,
    };
  }
}
