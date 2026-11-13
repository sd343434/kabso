import { Inject, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { LiveRoomsService, type UserSummaryDto } from './live-rooms.service.js';

/** At most this many newcomers are listed (the most recent arrivals first). */
export const NEWCOMERS_LIST_MAX = 100;

/** `LiveNewcomers` (v1.34-live, D154c, CONVENTIONS §10.35). */
export interface LiveNewcomersDto {
  /** Accounts younger than this many days count (NEWCOMER_DAYS; owner: 30). */
  newcomerDays: number;
  data: UserSummaryDto[];
}

/**
 * The Newcomers tool «الجدد» (D154c, CONVENTIONS §10.35): for the host and the moderators of a live,
 * the signed-in people in its media session now whose account is younger than NEWCOMER_DAYS, the
 * most recent arrivals first. Only "new or not" is ever told — never the signup date. Blocked people
 * either way with the caller are left out.
 */
@Injectable()
export class LiveNewcomersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /**
   * `GET /live/rooms/{roomId}/newcomers`. Visible room (404), LIVE (409 LIVE_ROOM_ENDED), the host or
   * a moderator of this live (403 AUTH_FORBIDDEN).
   */
  async list(callerId: string, roomId: string): Promise<LiveNewcomersDto> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    if (
      callerId !== row.host_user_id &&
      (await this.prisma.liveRoomModerator.count({ where: { roomId: row.id, userId: callerId } })) === 0
    ) {
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    }
    const days = this.config.newcomerDays;
    const since = new Date(this.clock.now().getTime() - days * 86_400_000);
    const viewers = await this.prisma.liveRoomViewer.findMany({
      where: {
        roomId: row.id,
        userId: { not: null },
        user: {
          id: { not: row.host_user_id },
          status: 'ACTIVE',
          createdAt: { gt: since },
          blocking: { none: { blockedId: callerId } },
          blockedBy: { none: { blockerId: callerId } },
        },
      },
      orderBy: [{ joinedAt: 'desc' }, { identity: 'desc' }],
      take: NEWCOMERS_LIST_MAX,
      select: { user: { select: USER_SUMMARY_SELECT } },
    });
    return {
      newcomerDays: days,
      data: viewers.flatMap((v) => (v.user ? [userSummary(v.user)] : [])),
    };
  }
}
