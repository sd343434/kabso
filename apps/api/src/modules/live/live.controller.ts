import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  Param,
  Patch,
  Post,
  Put,
  Inject,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import { clientIp, type AppRequest } from '../../common/http/request-context.js';
import { byIp, byUserId, RateLimit, SkipRateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { OptionalAuth, Public } from '../auth/public.decorator.js';
import { AdminGuard, RequireAdminPermission } from '../levels/admin.guard.js';
import { pageQuerySchema, type PageQuery } from '../posts/posts.schemas.js';
import { UsersService } from '../users/users.service.js';
import { LiveCategoriesService, type LiveCategoryDto } from './live-categories.service.js';
import { LiveBulletsService, type LiveBulletResultDto } from './live-bullets.service.js';
import { LiveSeatEmojiService, type LiveSeatEmojiDto } from './live-seat-emoji.service.js';
import { LiveGiftsService, type LiveGiftResultDto } from './live-gifts.service.js';
import { LiveChatService, type LiveChatMessageDto, type LiveChatMuteDto } from './live-chat.service.js';
import { LiveBlockedWordsService, type LiveBlockedWordsDto } from './live-blocked-words.service.js';
import { LiveCoverService, type LiveCoverDto } from './live-cover.service.js';
import { LiveKicksService, type LiveKickDto } from './live-kicks.service.js';
import { LiveMediaService, type LiveMediaAccessDto, type LiveViewerDto } from './live-media.service.js';
import {
  LiveRoomsService,
  type LiveConfigDto,
  type LiveRoomDto,
  type LiveRoomPageDto,
  type RequestMeta,
} from './live-rooms.service.js';
import {
  LiveSeatsService,
  type LiveSeatInviteDto,
  type LiveSeatRequestDto,
  type LiveSeatsDto,
  type PageDto,
} from './live-seats.service.js';
import { LiveRankingsService, type LiveRankingsDto } from './live-rankings.service.js';
import { LiveScheduleService, type LiveScheduleSlotDto } from './live-schedule.service.js';
import {
  LiveTapsService,
  type LiveContributorDto,
  type LiveContributorStandingDto,
  type LiveTapsResultDto,
} from './live-taps.service.js';
import { listLiveRoomsQuerySchema, type ListLiveRoomsQuery } from './live.schemas.js';

/** The caller's user id; a guest has none (CP-010 `@OptionalAuth()` routes). */
function callerOf(req: AppRequest): string | null {
  return req.auth?.userId ?? null;
}

function requireCaller(req: AppRequest): string {
  const id = callerOf(req);
  if (id === null) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
  return id;
}

function meta(req: AppRequest): RequestMeta {
  return { ip: clientIp(req), requestId: getRequestId(req) };
}

/** Guest reads (CP-010): per IP instead of per user. */
const GUEST_READ = {
  bucket: 'live:guest:read',
  rule: 'liveGuestReadIp',
  key: byIp,
  replacesDefault: true,
  appliesTo: 'guest',
} as const;

/** CP-011 (§7): seat requests and invitations, 30 / 10 min per user (replaces the default). */
const SEAT_ASK = {
  bucket: 'live:seat:ask',
  rule: 'liveSeatAskUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** CP-011 (§7): host and moderator seat actions, 300 / hour per user (replaces the default). */
const SEAT_ACTION = {
  bucket: 'live:seat:action',
  rule: 'liveSeatActionUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/**
 * Live discovery, host lifecycle and live video (contract v1.3 + v1.6-live draft, CONVENTIONS
 * §10). Every route needs a token, except the guest reads and the media token (CP-010).
 */
@Controller('live')
export class LiveController {
  constructor(
    private readonly rooms: LiveRoomsService,
    private readonly media: LiveMediaService,
    private readonly categories: LiveCategoriesService,
    private readonly users: UsersService,
    private readonly seats: LiveSeatsService,
    private readonly taps: LiveTapsService,
    private readonly chat: LiveChatService,
    private readonly bullets: LiveBulletsService,
    private readonly seatEmoji: LiveSeatEmojiService,
    private readonly liveGifts: LiveGiftsService,
    private readonly kicks: LiveKicksService,
    private readonly rankings: LiveRankingsService,
    private readonly limiter: RateLimitService,
    @Inject(APP_CONFIG) private readonly appConfig: AppConfig,
  ) {}

  /** §10.1: `Accept-Language` (ar|en), else the caller's stored locale, else `ar` (guests too). */
  private async language(req: AppRequest): Promise<ContentLanguage> {
    const header = languageFromAcceptLanguage(req.headers['accept-language']);
    if (header) return header;
    const caller = callerOf(req);
    return caller === null ? 'ar' : this.users.getLocale(caller);
  }

  @Get('config')
  @OptionalAuth()
  @RateLimit(GUEST_READ)
  config(): LiveConfigDto {
    return this.rooms.getConfig();
  }

  @Get('categories')
  async listCategories(@Req() req: AppRequest): Promise<{ data: LiveCategoryDto[] }> {
    return { data: await this.categories.listActive(await this.language(req)) };
  }

  @Get('rooms')
  @OptionalAuth()
  @RateLimit(
    { bucket: 'live:list', rule: 'liveListUser', key: byUserId, replacesDefault: true, appliesTo: 'user' },
    GUEST_READ,
  )
  async listRooms(
    @Req() req: AppRequest,
    @Query(new ZodValidationPipe(listLiveRoomsQuerySchema)) query: ListLiveRoomsQuery,
  ): Promise<LiveRoomPageDto> {
    return this.rooms.listRooms(callerOf(req), query, await this.language(req));
  }

  /**
   * Go live. The body is validated by the service AFTER the LIVE_HOSTING_ENABLED check (openapi
   * check order), so no validation pipe here. The hour and day buckets are counted first (guard).
   */
  @Post('rooms')
  @HttpCode(201)
  @RateLimit(
    { bucket: 'live:start:h', rule: 'liveStartHourUser', key: byUserId, replacesDefault: true },
    { bucket: 'live:start:d', rule: 'liveStartDayUser', key: byUserId, replacesDefault: true },
  )
  async startRoom(@Req() req: AppRequest, @Body() body: unknown): Promise<LiveRoomDto> {
    return this.rooms.startRoom(requireCaller(req), body, await this.language(req), meta(req));
  }

  @Get('rooms/:roomId')
  @OptionalAuth()
  @RateLimit(GUEST_READ)
  async getRoom(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<LiveRoomDto> {
    return this.rooms.getRoom(roomId, await this.language(req), callerOf(req));
  }

  /**
   * CP-010: the host's guests switch; CP-011: `seatCount` and `theme`, which also count against the
   * seat-action bucket (CONVENTIONS §7). CP-014: `title`, `categorySlug` and `topic` count only
   * against this `PATCH` bucket.
   */
  @Patch('rooms/:roomId')
  @RateLimit({ bucket: 'live:update', rule: 'liveUpdateUser', key: byUserId, replacesDefault: true })
  async updateRoom(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<LiveRoomDto> {
    const host = requireCaller(req);
    // CP-013: `chatEnabled` counts there too (CONVENTIONS §7).
    if (
      typeof body === 'object' &&
      body !== null &&
      ('seatCount' in body || 'theme' in body || 'chatEnabled' in body)
    ) {
      await this.limiter.consume(SEAT_ACTION.bucket, host, this.appConfig.rateLimits.liveSeatActionUser);
    }
    const id = await this.media.updateRoom(host, roomId, body, meta(req));
    return this.rooms.getRoom(id, await this.language(req), host);
  }

  /** CP-010: access to the room's video (host, viewer or guest). */
  @Post('rooms/:roomId/media-token')
  @HttpCode(200)
  @OptionalAuth()
  @RateLimit(
    {
      bucket: 'live:media',
      rule: 'liveMediaTokenUser',
      key: byUserId,
      replacesDefault: true,
      appliesTo: 'user',
    },
    {
      bucket: 'live:media:guest',
      rule: 'liveMediaTokenGuestIp',
      key: byIp,
      replacesDefault: true,
      appliesTo: 'guest',
    },
  )
  mediaToken(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<LiveMediaAccessDto> {
    return this.media.mediaToken(callerOf(req), roomId, body);
  }

  /**
   * CP-010: who is watching now. v1.23.2-live (D109): the host and anyone else who may watch the
   * room; guests too (per IP) when the room allows guests.
   */
  @Get('rooms/:roomId/viewers')
  @OptionalAuth()
  @RateLimit(
    { bucket: 'live:list', rule: 'liveListUser', key: byUserId, replacesDefault: true, appliesTo: 'user' },
    GUEST_READ,
  )
  viewers(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<{ data: LiveViewerDto[]; page: { nextCursor: string | null; hasMore: boolean } }> {
    return this.media.viewers(callerOf(req), roomId, query);
  }

  // ---- CP-011: seats (CONVENTIONS §10.9) --------------------------------------------------------

  /** Who is on which seat; guests too (per IP), without `mine` and `pendingRequests`. */
  @Get('rooms/:roomId/seats')
  @OptionalAuth()
  @RateLimit(
    {
      bucket: 'live:seats',
      rule: 'liveSeatsReadUser',
      key: byUserId,
      replacesDefault: true,
      appliesTo: 'user',
    },
    GUEST_READ,
  )
  async getSeats(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<LiveSeatsDto> {
    return this.seats.getSeats(callerOf(req), roomId, await this.language(req));
  }

  /** A viewer asks for a seat: 201 new, 200 the pending one. */
  @Post('rooms/:roomId/seat-requests')
  @RateLimit(SEAT_ASK)
  async requestSeat(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<LiveSeatRequestDto> {
    const { created, request } = await this.seats.requestSeat(requireCaller(req), roomId, body);
    res.status(created ? 201 : 200);
    return request;
  }

  /** Host and moderators: pending requests, oldest first. */
  @Get('rooms/:roomId/seat-requests')
  listSeatRequests(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<LiveSeatRequestDto>> {
    return this.seats.listRequests(requireCaller(req), roomId, query);
  }

  @Delete('rooms/:roomId/seat-requests/me')
  @HttpCode(204)
  async cancelSeatRequest(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<void> {
    await this.seats.cancelRequest(requireCaller(req), roomId);
  }

  @Post('rooms/:roomId/seat-requests/:requestId/accept')
  @HttpCode(200)
  @RateLimit(SEAT_ACTION)
  async acceptSeatRequest(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('requestId') requestId: string,
    @Body() body: unknown,
  ): Promise<LiveSeatsDto> {
    return this.seats.acceptRequest(requireCaller(req), roomId, requestId, body, await this.language(req));
  }

  @Post('rooms/:roomId/seat-requests/:requestId/decline')
  @HttpCode(204)
  @RateLimit(SEAT_ACTION)
  async declineSeatRequest(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('requestId') requestId: string,
  ): Promise<void> {
    await this.seats.declineRequest(requireCaller(req), roomId, requestId);
  }

  @Post('rooms/:roomId/seat-invites')
  @HttpCode(201)
  @RateLimit(SEAT_ASK)
  inviteToSeat(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<LiveSeatInviteDto> {
    return this.seats.invite(requireCaller(req), roomId, body);
  }

  @Post('rooms/:roomId/seat-invites/me/accept')
  @HttpCode(200)
  async acceptSeatInvite(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<LiveSeatsDto> {
    return this.seats.acceptInvite(requireCaller(req), roomId, await this.language(req));
  }

  @Post('rooms/:roomId/seat-invites/me/decline')
  @HttpCode(204)
  async declineSeatInvite(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<void> {
    await this.seats.declineInvite(requireCaller(req), roomId);
  }

  @Post('rooms/:roomId/seats/me/leave')
  @HttpCode(204)
  async leaveSeat(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<void> {
    await this.seats.leaveSeat(requireCaller(req), roomId);
  }

  @Post('rooms/:roomId/seats/:seatIndex/mute')
  @HttpCode(200)
  @RateLimit(SEAT_ACTION)
  async muteSeat(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('seatIndex') seatIndex: string,
    @Body() body: unknown,
  ): Promise<LiveSeatsDto> {
    return this.seats.mute(requireCaller(req), roomId, seatIndex, body, await this.language(req));
  }

  @Post('rooms/:roomId/seats/:seatIndex/remove')
  @HttpCode(200)
  @RateLimit(SEAT_ACTION)
  async removeFromSeat(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('seatIndex') seatIndex: string,
  ): Promise<LiveSeatsDto> {
    return this.seats.remove(requireCaller(req), roomId, seatIndex, await this.language(req));
  }

  @Post('rooms/:roomId/seats/:seatIndex/lock')
  @HttpCode(200)
  @RateLimit(SEAT_ACTION)
  async lockSeat(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('seatIndex') seatIndex: string,
    @Body() body: unknown,
  ): Promise<LiveSeatsDto> {
    return this.seats.lock(requireCaller(req), roomId, seatIndex, body, await this.language(req));
  }

  @Put('rooms/:roomId/moderators/:username')
  @HttpCode(200)
  @RateLimit(SEAT_ACTION)
  async addModerator(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('username') username: string,
  ): Promise<LiveSeatsDto> {
    return this.seats.addModerator(requireCaller(req), roomId, username, await this.language(req));
  }

  @Delete('rooms/:roomId/moderators/:username')
  @HttpCode(200)
  @RateLimit(SEAT_ACTION)
  async removeModerator(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('username') username: string,
  ): Promise<LiveSeatsDto> {
    return this.seats.removeModerator(requireCaller(req), roomId, username, await this.language(req));
  }

  // ---- CP-012: taps and the room score (CONVENTIONS §10.10) --------------------------------------

  /** Signed-in callers only (a guest → 401); 120 / min per user, replacing the default (§7). */
  @Post('rooms/:roomId/taps')
  @HttpCode(200)
  @RateLimit({ bucket: 'live:taps', rule: 'liveTapsUser', key: byUserId, replacesDefault: true })
  tap(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<LiveTapsResultDto> {
    return this.taps.tap(requireCaller(req), roomId, body);
  }

  /**
   * CP-014 (§10.12): the Contribution list, top 50; anyone who may watch (guests per IP when the
   * room allows guests); the per-user default for signed-in readers (§7).
   */
  @Get('rooms/:roomId/contributors')
  @OptionalAuth()
  @RateLimit(GUEST_READ)
  listContributors(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
  ): Promise<{ data: LiveContributorDto[] }> {
    return this.taps.contributors(callerOf(req), roomId);
  }

  /**
   * v1.20-live (D105, §10.12): one person's points and rank in this live; the same access and rate
   * limits as the list.
   */
  @Get('rooms/:roomId/contributors/:username')
  @OptionalAuth()
  @RateLimit(GUEST_READ)
  getContributor(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('username') username: string,
  ): Promise<LiveContributorStandingDto> {
    return this.taps.contributor(callerOf(req), roomId, username);
  }

  /**
   * CP-016 A (§10.15): the popularity board of the current hour, day or week; guests too (per IP),
   * the per-user default for signed-in readers (§7).
   */
  @Get('rankings')
  @OptionalAuth()
  @RateLimit(GUEST_READ)
  listRankings(@Req() req: AppRequest, @Query() query: unknown): Promise<LiveRankingsDto> {
    return this.rankings.list(callerOf(req), query);
  }

  // ---- CP-013: room chat (CONVENTIONS §10.11) -----------------------------------------------------

  /** The last 50 messages; guests too (per IP) when the room allows guests. */
  @Get('rooms/:roomId/chat')
  @OptionalAuth()
  @RateLimit(GUEST_READ)
  listChat(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<{ data: LiveChatMessageDto[] }> {
    return this.chat.list(callerOf(req), roomId);
  }

  /**
   * Signed-in callers in the room: 201 new, 200 a retry with the same `clientId`. 20 / min per
   * user, replacing the default (§7); the 1-a-second counting rule is checked last (§10.11).
   */
  @Post('rooms/:roomId/chat')
  @RateLimit({ bucket: 'live:chat', rule: 'liveChatUser', key: byUserId, replacesDefault: true })
  async sendChat(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<LiveChatMessageDto> {
    const { created, message } = await this.chat.send(requireCaller(req), roomId, body);
    res.status(created ? 201 : 200);
    return message;
  }

  /**
   * CP-017: a bullet message to every live, 15 coins. 201 new, 200 a retry with the same
   * `clientId`. 20 / min per user, replacing the default (§7); one every 5 s is a counting rule
   * checked before the charge (§10.19).
   */
  @Post('rooms/:roomId/bullets')
  @RateLimit({ bucket: 'live:bullet', rule: 'liveChatUser', key: byUserId, replacesDefault: true })
  async sendBullet(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<LiveBulletResultDto> {
    const { created, result } = await this.bullets.send(requireCaller(req), roomId, body);
    res.status(created ? 201 : 200);
    return result;
  }

  /**
   * v1.27.5-live (D138): an emoji played once on the caller's own seat, for the whole room. 120 / min
   * per user (the taps rule, bucket `live:seat-emoji`), replacing the default (§7); one every 2 s
   * is a counting rule (§10.30).
   */
  @Post('rooms/:roomId/seat-emoji')
  @HttpCode(200)
  @RateLimit({ bucket: 'live:seat-emoji', rule: 'liveTapsUser', key: byUserId, replacesDefault: true })
  sendSeatEmoji(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<LiveSeatEmojiDto> {
    return this.seatEmoji.send(requireCaller(req), roomId, body);
  }

  /**
   * v1.23-live (CP-020): a gift to the host and/or seated people, paid with coins or from the bag.
   * 201 new, 200 a retry with the same `clientId`. 120 / min per user, replacing the default (§7).
   */
  @Post('rooms/:roomId/gifts')
  @RateLimit({ bucket: 'live:gift', rule: 'liveGiftUser', key: byUserId, replacesDefault: true })
  async sendGift(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<LiveGiftResultDto> {
    const { created, result } = await this.liveGifts.send(
      requireCaller(req),
      roomId,
      body,
      this.liveGifts.regionOf(req.headers),
    );
    res.status(created ? 201 : 200);
    return result;
  }

  /** Host and moderators: the muted users of this live, newest first. */
  @Get('rooms/:roomId/chat/mutes')
  listChatMutes(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
  ): Promise<{ data: LiveChatMuteDto[] }> {
    return this.chat.listMutes(requireCaller(req), roomId);
  }

  @Put('rooms/:roomId/chat/mutes/:username')
  @HttpCode(204)
  @RateLimit(SEAT_ACTION)
  async muteChatUser(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('username') username: string,
  ): Promise<void> {
    await this.chat.setMuted(requireCaller(req), roomId, username, true);
  }

  @Delete('rooms/:roomId/chat/mutes/:username')
  @HttpCode(204)
  @RateLimit(SEAT_ACTION)
  async unmuteChatUser(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('username') username: string,
  ): Promise<void> {
    await this.chat.setMuted(requireCaller(req), roomId, username, false);
  }

  // ---- v1.20-live (D105): kicking someone out of a live (CONVENTIONS §10.20) ---------------------

  /** Host and moderators: 201 kicked, 200 already kicked (the first kick). */
  @Post('rooms/:roomId/kicks')
  @RateLimit(SEAT_ACTION)
  async kick(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<LiveKickDto> {
    const { created, kick } = await this.kicks.kick(requireCaller(req), roomId, body, meta(req));
    res.status(created ? 201 : 200);
    return kick;
  }

  /** Host and moderators: the kicked users of this live, newest first. */
  @Get('rooms/:roomId/kicks')
  listKicks(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<{ data: LiveKickDto[] }> {
    return this.kicks.list(requireCaller(req), roomId);
  }

  @Delete('rooms/:roomId/kicks/:username')
  @HttpCode(204)
  @RateLimit(SEAT_ACTION)
  async unkick(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('username') username: string,
  ): Promise<void> {
    await this.kicks.unkick(requireCaller(req), roomId, username, meta(req));
  }

  /** The author, the host or a moderator; deleting one's own message counts there too (§7). */
  @Delete('rooms/:roomId/chat/:messageId')
  @HttpCode(204)
  @RateLimit(SEAT_ACTION)
  async deleteChatMessage(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('messageId') messageId: string,
  ): Promise<void> {
    await this.chat.remove(requireCaller(req), roomId, messageId);
  }

  @Post('rooms/:roomId/heartbeat')
  @HttpCode(204)
  @RateLimit({ bucket: 'live:heartbeat', rule: 'liveHeartbeatUser', key: byUserId, replacesDefault: true })
  async heartbeat(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<void> {
    await this.rooms.heartbeat(requireCaller(req), roomId);
  }

  @Post('rooms/:roomId/end')
  @HttpCode(200)
  @RateLimit({ bucket: 'live:end', rule: 'liveEndUser', key: byUserId, replacesDefault: true })
  async endRoom(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<LiveRoomDto> {
    const room = await this.rooms.endRoom(requireCaller(req), roomId, await this.language(req), meta(req));
    // CP-010: the media session closes for everyone (idempotent; the sweeper repeats it).
    await this.media.closeMedia(room.id);
    return room;
  }
}

/** CP-010: the hosting permission (admins with LIVE_HOSTS; audited). */
/** CP-015: the host's live cover, reused by every live (CONVENTIONS §10.13); 30 / hour / user. */
const LIVE_COVER = {
  bucket: 'live:cover',
  rule: 'liveCoverUser',
  key: byUserId,
  replacesDefault: true,
} as const;

@Controller('me/live-cover')
export class LiveCoverController {
  constructor(private readonly covers: LiveCoverService) {}

  @Put()
  @HttpCode(200)
  @RateLimit(LIVE_COVER)
  async setCover(@Req() req: AppRequest, @Body() body: unknown): Promise<LiveCoverDto> {
    return this.covers.setCover(requireCaller(req), body, meta(req));
  }

  @Delete()
  @HttpCode(204)
  @RateLimit(LIVE_COVER)
  async removeCover(@Req() req: AppRequest): Promise<void> {
    await this.covers.removeCover(requireCaller(req), meta(req));
  }
}

/** CP-016 B: the host's blocked words (CONVENTIONS §10.14); `PUT` 30 / hour / user. */
@Controller('me/live-blocked-words')
export class LiveBlockedWordsController {
  constructor(private readonly words: LiveBlockedWordsService) {}

  @Get()
  async get(@Req() req: AppRequest): Promise<LiveBlockedWordsDto> {
    return this.words.get(requireCaller(req));
  }

  @Put()
  @HttpCode(200)
  @RateLimit({
    bucket: 'live:blocked-words',
    rule: 'liveBlockedWordsUser',
    key: byUserId,
    replacesDefault: true,
  })
  async set(@Req() req: AppRequest, @Body() body: unknown): Promise<LiveBlockedWordsDto> {
    return this.words.set(requireCaller(req), body, meta(req));
  }
}

/** CP-016 C: the host's live schedule (CONVENTIONS §10.16); `POST` and `DELETE` 30 / hour / user. */
const LIVE_SCHEDULE = {
  bucket: 'live:schedule',
  rule: 'liveScheduleUser',
  key: byUserId,
  replacesDefault: true,
} as const;

@Controller('me/live-schedule')
export class LiveScheduleController {
  constructor(private readonly schedule: LiveScheduleService) {}

  @Get()
  async list(@Req() req: AppRequest): Promise<{ data: LiveScheduleSlotDto[] }> {
    return this.schedule.list(requireCaller(req));
  }

  @Post()
  @HttpCode(201)
  @RateLimit(LIVE_SCHEDULE)
  async create(@Req() req: AppRequest, @Body() body: unknown): Promise<LiveScheduleSlotDto> {
    return this.schedule.create(requireCaller(req), body, meta(req));
  }

  @Delete(':slotId')
  @HttpCode(204)
  @RateLimit(LIVE_SCHEDULE)
  async remove(@Req() req: AppRequest, @Param('slotId') slotId: string): Promise<void> {
    await this.schedule.remove(requireCaller(req), slotId, meta(req));
  }
}

@Controller('admin/live')
@UseGuards(AdminGuard)
export class AdminLiveController {
  constructor(private readonly media: LiveMediaService) {}

  @Put('hosts/:username')
  @HttpCode(204)
  @RequireAdminPermission('LIVE_HOSTS')
  async grant(@Req() req: AppRequest, @Param('username') username: string): Promise<void> {
    await this.media.grantHost(requireCaller(req), username, meta(req));
  }

  @Delete('hosts/:username')
  @HttpCode(204)
  @RequireAdminPermission('LIVE_HOSTS')
  async revoke(@Req() req: AppRequest, @Param('username') username: string): Promise<void> {
    await this.media.revokeHost(requireCaller(req), username, meta(req));
  }
}

/**
 * CP-010: the media server's signed webhook (`POST /internal/livekit/webhook`, outside
 * `/api/v1`; not public API). The signature over the raw body is the authentication.
 */
@Controller('internal/livekit')
export class LiveMediaWebhookController {
  constructor(private readonly media: LiveMediaService) {}

  @Post('webhook')
  @HttpCode(200)
  @Public()
  @SkipRateLimit()
  async webhook(
    @Req() req: AppRequest,
    @Headers('authorization') authorization: string | undefined,
  ): Promise<{ ok: true }> {
    const body: unknown = req.body;
    if (!Buffer.isBuffer(body)) throw AppException.validation([{ field: 'body', issue: 'invalid_type' }]);
    await this.media.webhook(body.toString('utf8'), authorization);
    return { ok: true };
  }
}
