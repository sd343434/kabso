import { Body, Controller, Get, Headers, HttpCode, Param, Post, Put, Req, Res } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { clientIp, type AppRequest, type AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { MeDto } from '../users/users.service.js';
import {
  buyStatusPackBody,
  setStatusEmojiBody,
  statusPackIdPath,
  type BuyStatusPackBody,
  type SetStatusEmojiBody,
} from './status-emoji.schemas.js';
import {
  StatusEmojiService,
  type StatusPackListDto,
  type StatusPackPurchaseDto,
} from './status-emoji.service.js';

const idempotencyKeySchema = z.uuid();

/**
 * «الحالة» (contract v1.130-social draft, D376, CONVENTIONS §10.167): the caller's status emoji and «متجر الحالة».
 * Every route needs a signed-in caller.
 */
@Controller()
export class StatusEmojiController {
  constructor(private readonly status: StatusEmojiService) {}

  /** Set or clear the status. 30 / hour per user (bucket `me:status`, the `updateMe` rule), audited. */
  @Put('me/status')
  @HttpCode(200)
  @RateLimit({ bucket: 'me:status', rule: 'updateMeUser', key: byUserId, replacesDefault: true })
  async setStatus(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body(new ZodValidationPipe(setStatusEmojiBody)) body: SetStatusEmojiBody,
  ): Promise<MeDto> {
    return this.status.setStatus(auth.userId, body.statusEmojiId, {
      ip: clientIp(req),
      requestId: getRequestId(req),
    });
  }

  /** The packs on sale, their prices, the caller's ends and coins. Per-user default rate limit. */
  @Get('status-packs')
  async packs(@CurrentAuth() auth: AuthContext): Promise<StatusPackListDto> {
    return this.status.packs(auth.userId);
  }

  /** Buy (201), or a retry with the same `Idempotency-Key` (200). 30 / hour per user (bucket `status:buy`). */
  @Post('status-packs/:packId/purchases')
  @RateLimit({ bucket: 'status:buy', rule: 'bagSendUser', key: byUserId, replacesDefault: true })
  async buy(
    @CurrentAuth() auth: AuthContext,
    @Param('packId') rawPackId: string,
    @Headers('idempotency-key') rawKey: string | undefined,
    @Body(new ZodValidationPipe(buyStatusPackBody)) body: BuyStatusPackBody,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StatusPackPurchaseDto> {
    const packId = statusPackIdPath.safeParse(rawPackId);
    if (!packId.success) throw new AppException(ErrorCode.NOT_FOUND);
    if (rawKey === undefined || rawKey === '') {
      throw AppException.validation([{ field: 'Idempotency-Key', issue: 'required' }]);
    }
    const key = idempotencyKeySchema.safeParse(rawKey);
    if (!key.success) throw AppException.validation([{ field: 'Idempotency-Key', issue: 'invalid_format' }]);
    const { replay, result } = await this.status.buy(auth.userId, packId.data, key.data, body);
    res.status(replay ? 200 : 201);
    return result;
  }
}
