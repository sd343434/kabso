import { Body, Controller, Get, HttpCode, Param, Post, Req } from '@nestjs/common';
import { clientIp, type AppRequest, type AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import {
  MediaService,
  type MediaConfigDto,
  type MediaUploadDto,
  type MediaUploadTicketDto,
} from './media.service.js';

/** Image uploads (contract v1.4, CONVENTIONS §11). Every route needs a token. */
@Controller('media')
export class MediaController {
  constructor(private readonly media: MediaService) {}

  /** Default per-user bucket (CONVENTIONS §7). */
  @Get('config')
  config(): MediaConfigDto {
    return this.media.getConfig();
  }

  /**
   * Declare an upload. The hour and day buckets are counted by the guard, before the
   * MEDIA_UPLOADS_ENABLED check (§7); the body is validated by the service after that check
   * (openapi check order), so no validation pipe here.
   */
  @Post('uploads')
  @HttpCode(201)
  @RateLimit(
    { bucket: 'media:upload:h', rule: 'mediaUploadHourUser', key: byUserId, replacesDefault: true },
    { bucket: 'media:upload:d', rule: 'mediaUploadDayUser', key: byUserId, replacesDefault: true },
  )
  createUpload(@CurrentAuth() auth: AuthContext, @Body() body: unknown): Promise<MediaUploadTicketDto> {
    return this.media.createUpload(auth.userId, body);
  }

  /** Owner only (404 otherwise); works while uploads are disabled. Default per-user bucket. */
  @Get('uploads/:uploadId')
  getUpload(@CurrentAuth() auth: AuthContext, @Param('uploadId') uploadId: string): Promise<MediaUploadDto> {
    return this.media.getUpload(auth.userId, uploadId);
  }

  /** No request body. Idempotent repeats count against the bucket too (§7). */
  @Post('uploads/:uploadId/complete')
  @HttpCode(200)
  @RateLimit({ bucket: 'media:complete', rule: 'mediaCompleteUser', key: byUserId, replacesDefault: true })
  complete(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('uploadId') uploadId: string,
  ): Promise<MediaUploadDto> {
    return this.media.completeUpload(auth.userId, uploadId, {
      ip: clientIp(req),
      requestId: getRequestId(req),
    });
  }
}
