import { Body, Controller, Param, Post, Res } from '@nestjs/common';
import type { Response } from 'express';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { ContentGiftsService, type ContentGiftResultDto } from './content-gifts.service.js';

/** «هدية الدعم» (contract v1.127-social draft, D372, CONVENTIONS §10.164). */
@Controller()
export class ContentGiftsController {
  constructor(private readonly contentGifts: ContentGiftsService) {}

  /**
   * `sendContentGift`: 201 new, 200 a retry with the same `clientId`. Rate limits as a live gift (§7): every send in
   * the shared `live:gift:any` bucket here (replacing the default), then a normal gift's `live:gift` in the pipeline.
   */
  @Post('posts/:postId/gifts')
  @RateLimit({ bucket: 'live:gift:any', rule: 'liveGiftAnyUser', key: byUserId, replacesDefault: true })
  async send(
    @CurrentAuth() auth: AuthContext,
    @Param('postId') postId: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<ContentGiftResultDto> {
    const { created, result } = await this.contentGifts.send(auth.userId, postId, body);
    res.status(created ? 201 : 200);
    return result;
  }
}
