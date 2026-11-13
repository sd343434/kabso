import { Body, Controller, Get, HttpCode, Param, Post } from '@nestjs/common';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { MediaService, type MediaAssetDto, type MediaUploadDto } from './media.service.js';

/** Media upload (contract v1.5-social draft, CONVENTIONS §11.1). Every route needs a token. */
@Controller('media')
export class MediaController {
  constructor(private readonly media: MediaService) {}

  /**
   * The body is validated by the service after the MEDIA_UPLOADS_ENABLED check (openapi check
   * order); the per-user bucket is counted first by the guard.
   */
  @Post('uploads')
  @HttpCode(201)
  @RateLimit({ bucket: 'media:upload', rule: 'mediaUploadUser', key: byUserId, replacesDefault: true })
  createUpload(@CurrentAuth() auth: AuthContext, @Body() body: unknown): Promise<MediaUploadDto> {
    return this.media.createUpload(auth.userId, body);
  }

  @Post('uploads/:uploadId/complete')
  @HttpCode(200)
  completeUpload(
    @CurrentAuth() auth: AuthContext,
    @Param('uploadId') uploadId: string,
    @Body() body: unknown,
  ): Promise<MediaAssetDto> {
    // v1.41-social (D162): `{posterId}` for a video; validated by the service after the slot.
    return this.media.completeUpload(auth.userId, uploadId, body);
  }

  @Get(':mediaId')
  getMedia(@CurrentAuth() auth: AuthContext, @Param('mediaId') mediaId: string): Promise<MediaAssetDto> {
    return this.media.getMedia(auth.userId, mediaId);
  }
}
