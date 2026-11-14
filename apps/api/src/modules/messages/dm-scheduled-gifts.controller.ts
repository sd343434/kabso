import { Body, Controller, Delete, Get, Param, Post, Req, Res } from '@nestjs/common';
import type { Response } from 'express';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { UsersService } from '../users/users.service.js';
import {
  DmScheduledGiftsService,
  type VipScheduledGiftListDto,
  type VipScheduledGiftResultDto,
} from './dm-scheduled-gifts.service.js';

/** D155 (§7): the conversation writes' bucket (300 / hour per user) for scheduling and cancelling. */
const DM_WRITE = { bucket: 'dm:write', rule: 'dmWriteUser', key: byUserId, replacesDefault: true } as const;

/**
 * v1.134-social (D381, CONVENTIONS §10.171.5) SCHEDULED_GIFT «هدية مؤجلة»: schedule, list and cancel the caller's
 * gifts for later (delivered as conversation gifts). Gift names follow `Accept-Language`, else the caller's locale.
 */
@Controller('me/vip/scheduled-gifts')
export class DmScheduledGiftsController {
  constructor(
    private readonly scheduled: DmScheduledGiftsService,
    private readonly users: UsersService,
  ) {}

  private async language(req: AppRequest, auth: AuthContext): Promise<ContentLanguage> {
    return (
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId))
    );
  }

  /** Per-user default rate limit. */
  @Get()
  async list(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<VipScheduledGiftListDto> {
    return this.scheduled.list(auth.userId, await this.language(req, auth));
  }

  /** 201 new, 200 a retry with the same `clientId`. */
  @Post()
  @RateLimit(DM_WRITE)
  async create(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<VipScheduledGiftResultDto> {
    const { created, result } = await this.scheduled.create(
      auth.userId,
      body,
      await this.language(req, auth),
    );
    res.status(created ? 201 : 200);
    return result;
  }

  @Delete(':scheduledGiftId')
  @RateLimit(DM_WRITE)
  async cancel(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('scheduledGiftId') id: string,
  ): Promise<VipScheduledGiftResultDto> {
    return this.scheduled.cancel(auth.userId, id, await this.language(req, auth));
  }
}
