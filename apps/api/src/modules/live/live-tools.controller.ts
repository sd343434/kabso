import { Body, Controller, Delete, Get, HttpCode, Param, Post, Put, Req } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { clientIp, type AppRequest } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import type { RequestMeta } from './live-rooms.service.js';
import {
  LiveToolsService,
  type LiveRecordingDto,
  type MusicRightsDto,
  type SecondCameraAccessDto,
  type SecondCameraCodeDto,
  type SecondCameraStateDto,
} from './live-tools.service.js';

function requireCaller(req: AppRequest): string {
  const id = req.auth?.userId;
  if (!id) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
  return id;
}

function meta(req: AppRequest): RequestMeta {
  return { ip: clientIp(req), requestId: getRequestId(req) };
}

/** v1.45-live (§7): second-camera codes created, 10 / 10 min per user (replaces the default). */
const CODE = {
  bucket: 'live:cam2:code',
  rule: 'liveSecondCameraCodeUser',
  key: byUserId,
  replacesDefault: true,
} as const;
/** v1.45-live (§7): codes redeemed (right or wrong), 10 / 10 min per user (replaces the default). */
const REDEEM = {
  bucket: 'live:cam2:redeem',
  rule: 'liveSecondCameraRedeemUser',
  key: byUserId,
  replacesDefault: true,
} as const;
/** v1.45-live (§7): the other live tools calls, 120 / 10 min per user (replaces the default). */
const TOOLS = {
  bucket: 'live:tools',
  rule: 'liveToolsUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/**
 * The host's live tools (v1.45-live DRAFT, D201, CONVENTIONS §10.63): the second camera, the
 * recording indicator and the one-time music-rights notice. Signed-in callers only.
 */
@Controller()
export class LiveToolsController {
  constructor(private readonly tools: LiveToolsService) {}

  @Get('live/rooms/:roomId/second-camera')
  @RateLimit(TOOLS)
  secondCamera(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<SecondCameraStateDto> {
    return this.tools.state(requireCaller(req), roomId);
  }

  @Post('live/rooms/:roomId/second-camera/codes')
  @HttpCode(201)
  @RateLimit(CODE)
  createCode(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<SecondCameraCodeDto> {
    return this.tools.createCode(requireCaller(req), roomId, meta(req));
  }

  @Delete('live/rooms/:roomId/second-camera')
  @HttpCode(204)
  @RateLimit(TOOLS)
  async endSecondCamera(@Req() req: AppRequest, @Param('roomId') roomId: string): Promise<void> {
    await this.tools.end(requireCaller(req), roomId, meta(req));
  }

  @Put('live/rooms/:roomId/second-camera/main')
  @HttpCode(200)
  @RateLimit(TOOLS)
  setMain(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<SecondCameraStateDto> {
    return this.tools.setMain(requireCaller(req), roomId, body, meta(req));
  }

  @Post('live/second-camera/redeem')
  @HttpCode(200)
  @RateLimit(REDEEM)
  redeem(@Req() req: AppRequest, @Body() body: unknown): Promise<SecondCameraAccessDto> {
    return this.tools.redeem(requireCaller(req), body, meta(req));
  }

  @Put('live/rooms/:roomId/recording')
  @HttpCode(200)
  @RateLimit(TOOLS)
  setRecording(
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<LiveRecordingDto> {
    return this.tools.setRecording(requireCaller(req), roomId, body, meta(req));
  }

  @Get('me/live-music-rights')
  musicRights(@Req() req: AppRequest): Promise<MusicRightsDto> {
    return this.tools.musicRights(requireCaller(req));
  }

  @Put('me/live-music-rights')
  @HttpCode(200)
  @RateLimit(TOOLS)
  acceptMusicRights(@Req() req: AppRequest, @Body() body: unknown): Promise<MusicRightsDto> {
    return this.tools.acceptMusicRights(requireCaller(req), body, meta(req));
  }
}
