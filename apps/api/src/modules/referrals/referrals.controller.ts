import { Body, Controller, Get, HttpCode, Post, Req, Res } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { byIp, byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { requestMeta } from '../auth/auth.controller.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { Public } from '../auth/public.decorator.js';
import { installIdSchema, referralCodeInput } from './referral-rules.js';
import { ReferralsService, type MyReferralDto, type ReferralTickerItemDto } from './referrals.service.js';

/** `ApplyReferralCodeRequest`: a code or an invite link; the app's install id (optional). */
export const applyReferralBody = z.strictObject({
  code: referralCodeInput,
  installId: installIdSchema.optional(),
});

/**
 * «دعوة الأصدقاء» (v1.74-social, D217, CONVENTIONS §10.71; tag `referrals`): the caller's page and a code entered
 * later. Reads use the per-user default rate limit; applying also counts in `referral:apply` (10 / 24 h per user,
 * refused attempts count).
 */
@Controller('me/referral')
export class ReferralsController {
  constructor(private readonly referrals: ReferralsService) {}

  @Get()
  mine(@CurrentAuth() auth: AuthContext): Promise<MyReferralDto> {
    return this.referrals.mine(auth.userId);
  }

  @Post('apply')
  @HttpCode(200)
  @RateLimit({ bucket: 'referral:apply', rule: 'referralApplyUser', key: byUserId })
  apply(
    @CurrentAuth() auth: AuthContext,
    @Body(new ZodValidationPipe(applyReferralBody)) body: z.output<typeof applyReferralBody>,
    @Req() req: AppRequest,
  ): Promise<MyReferralDto> {
    const meta = requestMeta(req);
    return this.referrals.apply(auth.userId, body.code, body.installId ?? null, {
      ip: meta.ip,
      requestId: meta.requestId,
    });
  }
}

/**
 * `GET /referrals/recent-rewards` (public): the ticker of real credited rewards with masked names; per-IP limit
 * `RATE_LIMIT_REFERRAL_TICKER_IP` (replaces the public default); cached 60 s.
 */
@Controller('referrals')
export class ReferralTickerController {
  constructor(private readonly referrals: ReferralsService) {}

  @Public()
  @Get('recent-rewards')
  @RateLimit({ bucket: 'referral:ticker', rule: 'referralTickerIp', key: byIp, replacesDefault: true })
  async ticker(@Res({ passthrough: true }) res: Response): Promise<{ data: ReferralTickerItemDto[] }> {
    res.setHeader('Cache-Control', 'public, max-age=60');
    return this.referrals.ticker();
  }
}
