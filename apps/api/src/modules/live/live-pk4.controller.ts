import { Body, Controller, Delete, Get, HttpCode, Param, Post, Query, Req } from '@nestjs/common';
import type { AppRequest } from '../../common/http/request-context.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { byIp, byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { OptionalAuth } from '../auth/public.decorator.js';
import type { PkCandidateDto } from './live-pk.service.js';
import {
  LivePk4Service,
  type Pk4LobbyDto,
  type Pk4MatchDto,
  type Pk4MediaAccessDto,
  type Pk4StateDto,
} from './live-pk4.service.js';

function callerOf(req: AppRequest): string | null {
  return req.auth?.userId ?? null;
}

function requireCaller(req: AppRequest): string {
  const id = callerOf(req);
  if (id === null) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
  return id;
}

/** §7: opening a lobby and inviting count as PK invitations (30 / 10 min per user). */
const PK_INVITE = {
  bucket: 'live:pk:invite',
  rule: 'livePkInviteUser',
  key: byUserId,
  replacesDefault: true,
} as const;
/** §7: every other host action, as PK 1 v 1 (300 / 10 min per user). */
const PK_ACTION = {
  bucket: 'live:pk:action',
  rule: 'livePkActionUser',
  key: byUserId,
  replacesDefault: true,
} as const;
const GUEST_READ = {
  bucket: 'live:guest:read',
  rule: 'liveGuestReadIp',
  key: byIp,
  replacesDefault: true,
  appliesTo: 'guest',
} as const;

/**
 * «PK رباعي» (v1.118-live DRAFT, D391, CONVENTIONS §10.180, CP-041 phase 2): PK 2 v 2 by invitation. Host routes take the
 * host's own room in the path; the state and the media tokens are readable by viewers (and guests where allowed).
 */
@Controller('live')
export class LivePk4Controller {
  constructor(private readonly pk4: LivePk4Service) {}

  @Get('rooms/:roomId/pk4')
  @OptionalAuth()
  @RateLimit(
    { bucket: 'live:list', rule: 'liveListUser', key: byUserId, replacesDefault: true, appliesTo: 'user' },
    GUEST_READ,
  )
  state(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<Pk4StateDto> {
    return this.pk4.state(callerOf(req), roomId);
  }

  @Get('rooms/:roomId/pk4/candidates')
  @RateLimit(PK_ACTION)
  candidates(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Query() query: unknown,
  ): Promise<{ data: PkCandidateDto[] }> {
    return this.pk4.candidates(requireCaller(req), roomId, query);
  }

  @Post('rooms/:roomId/pk4/lobby')
  @HttpCode(201)
  @RateLimit(PK_INVITE)
  openLobby(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<Pk4LobbyDto> {
    return this.pk4.openLobby(requireCaller(req), roomId, body);
  }

  @Delete('rooms/:roomId/pk4/lobby')
  @HttpCode(204)
  @RateLimit(PK_ACTION)
  async closeLobby(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<void> {
    await this.pk4.closeLobby(requireCaller(req), roomId);
  }

  @Post('rooms/:roomId/pk4/lobby/invites')
  @HttpCode(201)
  @RateLimit(PK_INVITE)
  invite(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<Pk4LobbyDto> {
    return this.pk4.invite(requireCaller(req), roomId, body);
  }

  @Delete('rooms/:roomId/pk4/lobby/invites/:inviteId')
  @HttpCode(204)
  @RateLimit(PK_ACTION)
  async cancelInvite(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('inviteId') inviteId: string,
  ): Promise<void> {
    await this.pk4.cancelInvite(requireCaller(req), roomId, inviteId);
  }

  @Post('rooms/:roomId/pk4/invites/:inviteId/accept')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  accept(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('inviteId') inviteId: string,
  ): Promise<Pk4StateDto> {
    return this.pk4.accept(requireCaller(req), roomId, inviteId);
  }

  @Post('rooms/:roomId/pk4/invites/:inviteId/decline')
  @HttpCode(204)
  @RateLimit(PK_ACTION)
  async decline(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('inviteId') inviteId: string,
  ): Promise<void> {
    await this.pk4.decline(requireCaller(req), roomId, inviteId);
  }

  @Post('rooms/:roomId/pk4/start')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  start(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<Pk4MatchDto> {
    return this.pk4.start(requireCaller(req), roomId);
  }

  @Post('rooms/:roomId/pk4/end')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  end(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<Pk4MatchDto> {
    return this.pk4.end(requireCaller(req), roomId);
  }

  @Post('rooms/:roomId/pk4/mute')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  mute(@Req() req: AppRequest, @Param('roomId') roomId: string, @Body() body: unknown): Promise<Pk4MatchDto> {
    return this.pk4.mute(requireCaller(req), roomId, body);
  }

  /** Watch-only tokens for the three other rooms (viewers, guests and the host). */
  @Post('rooms/:roomId/pk4/media-token')
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
  ): Promise<Pk4MediaAccessDto> {
    return this.pk4.mediaToken(callerOf(req), roomId, body);
  }
}
