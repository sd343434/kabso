import { Body, Controller, Delete, Get, HttpCode, Param, Post, Put, Req } from '@nestjs/common';
import { type AppRequest } from '../../common/http/request-context.js';
import { byIp, byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { OptionalAuth } from '../auth/public.decorator.js';
import { LiveLudoService, type LiveLudoGameDto } from './live-ludo.service.js';

function requireCaller(req: AppRequest): string {
  const id = req.auth?.userId ?? null;
  if (id === null) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
  return id;
}

/** Guest reads (CP-010): per IP instead of per user (the live room's reads). */
const GUEST_READ = {
  bucket: 'live:guest:read',
  rule: 'liveGuestReadIp',
  key: byIp,
  replacesDefault: true,
  appliesTo: 'guest',
} as const;

/** §7 (D168): the host's game actions — open, start, end, remove a player (the seat actions' rule). */
const LUDO_HOST = {
  bucket: 'live:ludo:host',
  rule: 'liveSeatActionUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** §7 (D168): taking and leaving a seat (the seat requests' rule). */
const LUDO_SEAT = {
  bucket: 'live:ludo:seat',
  rule: 'liveSeatAskUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** §7 (D168): rolls and moves (the taps rule). */
const LUDO_PLAY = {
  bucket: 'live:ludo:play',
  rule: 'liveTapsUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** D168 (v1.45-live, CONVENTIONS §10.42): Ludo inside a live room. */
@Controller('live')
export class LiveLudoController {
  constructor(private readonly ludo: LiveLudoService) {}

  /** The room's open game (anyone who can see the room, guests too). */
  @Get('rooms/:roomId/ludo')
  @OptionalAuth()
  @RateLimit(GUEST_READ)
  get(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<{ game: LiveLudoGameDto | null }> {
    return this.ludo.get(req.auth?.userId ?? null, roomId);
  }

  /** The host opens a game (its lobby). */
  @Post('rooms/:roomId/ludo')
  @RateLimit(LUDO_HOST)
  create(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<LiveLudoGameDto> {
    return this.ludo.create(requireCaller(req), roomId, body);
  }

  /** Someone in the room takes a free seat of the lobby. */
  @Put('rooms/:roomId/ludo/seats/:seat')
  @RateLimit(LUDO_SEAT)
  takeSeat(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('seat') seat: string,
  ): Promise<LiveLudoGameDto> {
    return this.ludo.takeSeat(requireCaller(req), roomId, seat);
  }

  /** The seat's player leaves, or the host removes them (AUTO once the game started). */
  @Delete('rooms/:roomId/ludo/seats/:seat')
  @RateLimit(LUDO_SEAT)
  leaveSeat(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('seat') seat: string,
  ): Promise<LiveLudoGameDto> {
    return this.ludo.leaveSeat(requireCaller(req), roomId, seat);
  }

  /** The host starts the game. */
  @Post('rooms/:roomId/ludo/start')
  @HttpCode(200)
  @RateLimit(LUDO_HOST)
  start(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<LiveLudoGameDto> {
    return this.ludo.start(requireCaller(req), roomId, body);
  }

  /** The player whose turn it is rolls the server's die. */
  @Post('rooms/:roomId/ludo/roll')
  @HttpCode(200)
  @RateLimit(LUDO_PLAY)
  roll(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<LiveLudoGameDto> {
    return this.ludo.roll(requireCaller(req), roomId, body);
  }

  /** The player moves one of their pieces by the rolled number. */
  @Post('rooms/:roomId/ludo/move')
  @HttpCode(200)
  @RateLimit(LUDO_PLAY)
  move(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<LiveLudoGameDto> {
    return this.ludo.move(requireCaller(req), roomId, body);
  }

  /** The host ends the game. */
  @Post('rooms/:roomId/ludo/end')
  @HttpCode(200)
  @RateLimit(LUDO_HOST)
  end(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<LiveLudoGameDto> {
    return this.ludo.end(requireCaller(req), roomId);
  }
}
