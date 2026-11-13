import { Body, Controller, Delete, Get, HttpCode, Param, Post, Put, Query, Req } from '@nestjs/common';
import { clientIp, type AppRequest } from '../../common/http/request-context.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { byIp, byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { OptionalAuth } from '../auth/public.decorator.js';
import {
  LivePkService,
  type PkCandidateDto,
  type PkHostProfileDto,
  type PkSettingsDto,
  type PkInviteDto,
  type PkMatchDto,
  type PkMediaAccessDto,
  type PkRandomResultDto,
  type PkStateDto,
} from './live-pk.service.js';

function callerOf(req: AppRequest): string | null {
  return req.auth?.userId ?? null;
}

function requireCaller(req: AppRequest): string {
  const id = callerOf(req);
  if (id === null) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
  return id;
}

/** v1.43-live (§7): PK invitations, 30 / 10 min per user (replaces the default). */
const PK_INVITE = {
  bucket: 'live:pk:invite',
  rule: 'livePkInviteUser',
  key: byUserId,
  replacesDefault: true,
} as const;
/** v1.43-live (§7): every other PK action, 300 / 10 min per user (replaces the default). */
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
 * PK 1 v 1 (v1.43-live DRAFT, D195, CONVENTIONS §10.58, CP-038). Host routes take the host's own
 * room in the path; the state, the media token and the host profile are readable by viewers (and
 * guests where the room allows them).
 */
@Controller('live')
export class LivePkController {
  constructor(private readonly pk: LivePkService) {}

  /** The room's PK (snapshot after a reconnect); the host also gets the invitation and the queue. */
  @Get('rooms/:roomId/pk')
  @OptionalAuth()
  @RateLimit(
    { bucket: 'live:list', rule: 'liveListUser', key: byUserId, replacesDefault: true, appliesTo: 'user' },
    GUEST_READ,
  )
  state(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<PkStateDto> {
    return this.pk.state(callerOf(req), roomId);
  }

  /** Hosts live now whom this room's host may invite (search `q`, else suggestions). */
  @Get('rooms/:roomId/pk/candidates')
  @RateLimit(PK_ACTION)
  candidates(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Query() query: unknown,
  ): Promise<{ data: PkCandidateDto[] }> {
    return this.pk.candidates(requireCaller(req), roomId, query);
  }

  @Post('rooms/:roomId/pk/invites')
  @HttpCode(201)
  @RateLimit(PK_INVITE)
  invite(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<PkInviteDto> {
    return this.pk.invite(requireCaller(req), roomId, body);
  }

  @Delete('rooms/:roomId/pk/invites/:inviteId')
  @HttpCode(204)
  @RateLimit(PK_ACTION)
  async cancelInvite(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('inviteId') inviteId: string,
  ): Promise<void> {
    await this.pk.cancel(requireCaller(req), roomId, inviteId);
  }

  @Post('rooms/:roomId/pk/invites/:inviteId/accept')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  accept(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('inviteId') inviteId: string,
  ): Promise<PkMatchDto> {
    return this.pk.accept(requireCaller(req), roomId, inviteId);
  }

  @Post('rooms/:roomId/pk/invites/:inviteId/decline')
  @HttpCode(204)
  @RateLimit(PK_ACTION)
  async decline(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Param('inviteId') inviteId: string,
  ): Promise<void> {
    await this.pk.decline(requireCaller(req), roomId, inviteId);
  }

  /** «مطابقة عشوائية». */
  @Post('rooms/:roomId/pk/random')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  joinRandom(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<PkRandomResultDto> {
    return this.pk.joinRandom(requireCaller(req), roomId, body);
  }

  @Delete('rooms/:roomId/pk/random')
  @HttpCode(204)
  @RateLimit(PK_ACTION)
  async leaveRandom(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<void> {
    await this.pk.leaveRandom(requireCaller(req), roomId);
  }

  /** v1.44-live (D199): either host starts a CONNECTED PK (auto-start off). */
  @Post('rooms/:roomId/pk/start')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  start(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<PkMatchDto> {
    return this.pk.start(requireCaller(req), roomId);
  }

  /** Ends early: a forfeit during the battle, closes the result phase after it (D199: cancels a CONNECTED one). */
  @Post('rooms/:roomId/pk/end')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  end(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<PkMatchDto> {
    return this.pk.end(requireCaller(req), roomId);
  }

  @Post('rooms/:roomId/pk/mute-opponent')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  muteOpponent(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<PkMatchDto> {
    return this.pk.muteOpponent(requireCaller(req), roomId, body);
  }

  /** v1.55-live (D242) «جولة أخرى»: a host offers another battle with the same opponent (or accepts theirs). */
  @Post('rooms/:roomId/pk/rematch')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  offerRematch(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<PkMatchDto> {
    return this.pk.offerRematch(requireCaller(req), roomId);
  }

  /** v1.55-live (D242): the other host accepts — the new battle starts. */
  @Post('rooms/:roomId/pk/rematch/accept')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  acceptRematch(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<PkMatchDto> {
    return this.pk.acceptRematch(requireCaller(req), roomId);
  }

  /** v1.55-live (D242): the other host declines — the PK closes. */
  @Post('rooms/:roomId/pk/rematch/decline')
  @HttpCode(204)
  @RateLimit(PK_ACTION)
  declineRematch(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<void> {
    return this.pk.declineRematch(requireCaller(req), roomId);
  }

  /** v1.55-live (D242): the asking host withdraws the offer. */
  @Delete('rooms/:roomId/pk/rematch')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  cancelRematch(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<PkMatchDto> {
    return this.pk.cancelRematch(requireCaller(req), roomId);
  }

  /** v1.50-live (D229) «PK أحكام»: the losing host accepts the drawn dare («قبول»). */
  @Post('rooms/:roomId/pk/dare/accept')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  acceptDare(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<PkMatchDto> {
    return this.pk.acceptDare(requireCaller(req), roomId);
  }

  /** v1.50-live (D229): the losing host refuses it («رفض»: the refusal's PK points). */
  @Post('rooms/:roomId/pk/dare/refuse')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  refuseDare(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<PkMatchDto> {
    return this.pk.refuseDare(requireCaller(req), roomId);
  }

  /** v1.50-live (D229): the winning host's verdict during the timer («نُفّذ» / «لم يُنفّذ»). */
  @Post('rooms/:roomId/pk/dare/verdict')
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  judgeDare(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<PkMatchDto> {
    return this.pk.judgeDare(requireCaller(req), roomId, body);
  }

  /** v1.50-live (D229): a viewer or host reports one of the room's dares (⚠️). */
  @Post('rooms/:roomId/pk/dare/report')
  @HttpCode(204)
  @RateLimit({
    bucket: 'live:pk:dare-report',
    rule: 'livePkDareReportUser',
    key: byUserId,
    replacesDefault: true,
  })
  async reportDare(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<void> {
    await this.pk.reportDare(requireCaller(req), roomId, body);
  }

  /** A watch-only token for the other room of this room's PK (viewers, guests and the host). */
  @Post('rooms/:roomId/pk/media-token')
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
  ): Promise<PkMediaAccessDto> {
    return this.pk.mediaToken(callerOf(req), roomId, body);
  }

  /** A host's PK record and last matches (the profile's «PK» line). */
  @Get('pk/hosts/:username')
  @OptionalAuth()
  @RateLimit(
    { bucket: 'live:list', rule: 'liveListUser', key: byUserId, replacesDefault: true, appliesTo: 'user' },
    GUEST_READ,
  )
  hostProfile(@Req() req: AppRequest, @Param('username') username: string): Promise<PkHostProfileDto> {
    return this.pk.hostProfile(callerOf(req), username);
  }
}

/** v1.43-live: the caller's PK switch (invitations on / off) and record; v1.44-live (D199): the PK Setting page. */
@Controller('me/live-pk')
export class MyLivePkController {
  constructor(private readonly pk: LivePkService) {}

  @Get()
  get(@Req() req: AppRequest): Promise<PkSettingsDto> {
    return this.pk.mySettings(requireCaller(req));
  }

  @Put()
  @HttpCode(200)
  @RateLimit(PK_ACTION)
  set(@Req() req: AppRequest, @Body() body: unknown): Promise<PkSettingsDto> {
    return this.pk.setSettings(requireCaller(req), body, { ip: clientIp(req), requestId: getRequestId(req) });
  }
}
