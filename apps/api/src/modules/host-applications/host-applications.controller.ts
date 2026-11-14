import { Body, Controller, Get, Headers, Post, Res } from '@nestjs/common';
import type { Response } from 'express';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { HostApplicationsService, type MyHostingApplicationDto } from './host-applications.service.js';

/**
 * «كن مضيفاً مع الإدارة» (v1.73-social, D209, CONVENTIONS §10.68; tag `agency`): the caller's application to host
 * directly with the Kabso team. Reads and the cancel use the per-user default rate limit; a submit also counts in
 * `host:apply` (5 / 24 h per user, refused attempts count).
 */
@Controller('me/hosting-application')
export class HostApplicationsController {
  constructor(private readonly applications: HostApplicationsService) {}

  @Get()
  mine(@CurrentAuth() auth: AuthContext): Promise<MyHostingApplicationDto> {
    return this.applications.mine(auth.userId);
  }

  /** 201 submitted now, 200 the same Idempotency-Key and body again. */
  @Post()
  @RateLimit({ bucket: 'host:apply', rule: 'hostApplyUser', key: byUserId })
  async apply(
    @CurrentAuth() auth: AuthContext,
    @Headers('idempotency-key') key: string | undefined,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<MyHostingApplicationDto> {
    const { created, result } = await this.applications.apply(auth.userId, key, body);
    res.status(created ? 201 : 200);
    return result;
  }

  @Post('cancel')
  async cancel(
    @CurrentAuth() auth: AuthContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<MyHostingApplicationDto> {
    const result = await this.applications.cancel(auth.userId);
    res.status(200);
    return result;
  }
}
