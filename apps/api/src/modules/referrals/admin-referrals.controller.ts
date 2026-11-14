import { Body, Controller, Get, HttpCode, Param, Post, Put, Query, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { reasonCodeBody } from '../admin-panel/admin-control.schemas.js';
import { pathUuid } from '../admin-panel/admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import { sendTable, tableQuery } from '../admin-panel/admin-tables.js';
import { Public } from '../auth/public.decorator.js';
import { AdminReferralsService, type ReferralsQuery } from './admin-referrals.service.js';
import { adminReferralSettingsBody, patchOf, type AdminReferralSettingsBody } from './referral-rules.js';

/** v1.74-social (D217): the list's filters (the panel v2 table shape, §10.60.1). */
export const referralsQuery = tableQuery(['createdAt', 'holdUntil'], 'createdAt')
  .extend({ status: z.enum(['PENDING', 'QUALIFIED', 'REJECTED', 'VOID']).optional() })
  .strict();

/**
 * «الدعوات» (v1.74-social, D217, CONVENTIONS §10.71): `referrals.view` (OWNER, SUPPORT, FINANCE) reads the list, a
 * referral (audited) and the settings; `referrals.decide` (OWNER, FINANCE) approves or voids with a reason and the
 * authenticator code again; `referrals.settings` (OWNER, FINANCE) changes the amounts and rules with the code again.
 * Every write also needs the CSRF header (the session guard).
 */
@Public()
@Controller('admin')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminReferralsController {
  constructor(private readonly referrals: AdminReferralsService) {}

  @Get('referrals')
  @RequireCapability('referrals.view')
  async list(
    @Query(new ZodValidationPipe(referralsQuery)) q: ReferralsQuery,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.referrals.table(q, admin));
  }

  @Get('referrals/:referralId')
  @RequireCapability('referrals.view')
  detail(@Param('referralId') id: string, @CurrentAdmin() admin: AdminContext) {
    return this.referrals.detail(pathUuid(id), admin);
  }

  @Post('referrals/:referralId/approve')
  @HttpCode(200)
  @RequireCapability('referrals.decide')
  approve(
    @Param('referralId') id: string,
    @Body(new ZodValidationPipe(reasonCodeBody)) body: { reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.referrals.approve(pathUuid(id), body, admin);
  }

  @Post('referrals/:referralId/void')
  @HttpCode(200)
  @RequireCapability('referrals.decide')
  void(
    @Param('referralId') id: string,
    @Body(new ZodValidationPipe(reasonCodeBody)) body: { reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.referrals.voidReferral(pathUuid(id), body, admin);
  }

  @Get('referral-settings')
  @RequireCapability('referrals.view')
  settings() {
    return this.referrals.settings();
  }

  @Put('referral-settings')
  @RequireCapability('referrals.settings')
  updateSettings(
    @Body(new ZodValidationPipe(adminReferralSettingsBody)) body: AdminReferralSettingsBody,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.referrals.updateSettings(
      { patch: patchOf(body), reason: body.reason, totpCode: body.totpCode },
      admin,
    );
  }
}
