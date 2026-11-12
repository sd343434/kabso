import { Body, Controller, Delete, Get, HttpCode, Param, Post, Put, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { pathUuid } from '../admin-panel/admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import { Public } from '../auth/public.decorator.js';
import { SITE_SETTINGS_CACHE_CONTROL } from './site-settings.rules.js';
import {
  socialAccountBody,
  socialAccountOrderBody,
  type SocialAccountInput,
} from './social-accounts.js';
import { SocialAccountsService } from './social-accounts.service.js';

/** v1.139-social (D387, §10.176.5): `GET /social-accounts` — the app's official accounts, public (cached 60 s). */
@Public()
@Controller('social-accounts')
export class OfficialSocialAccountsController {
  constructor(private readonly accounts: SocialAccountsService) {}

  @Get()
  async list(@Res({ passthrough: true }) res: Response) {
    res.setHeader('Cache-Control', SITE_SETTINGS_CACHE_CONTROL);
    return this.accounts.publicList();
  }
}

/** v1.139-social (D387, §10.176.5): «حساباتنا الرسمية» in the panel (`social.accounts`: OWNER, COMMUNITY; audited). */
@Public()
@Controller('admin/social-accounts')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminSocialAccountsController {
  constructor(private readonly accounts: SocialAccountsService) {}

  @Get()
  @RequireCapability('social.accounts')
  list() {
    return this.accounts.adminList();
  }

  @Post()
  @HttpCode(201)
  @RequireCapability('social.accounts')
  create(
    @Body(new ZodValidationPipe(socialAccountBody)) body: SocialAccountInput,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.accounts.create(body, admin);
  }

  @Put('order')
  @RequireCapability('social.accounts')
  reorder(
    @Body(new ZodValidationPipe(socialAccountOrderBody)) body: { ids: string[] },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.accounts.reorder(body.ids, admin);
  }

  @Put(':accountId')
  @RequireCapability('social.accounts')
  update(
    @Param('accountId') id: string,
    @Body(new ZodValidationPipe(socialAccountBody)) body: SocialAccountInput,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.accounts.update(pathUuid(id), body, admin);
  }

  @Delete(':accountId')
  @RequireCapability('social.accounts')
  remove(@Param('accountId') id: string, @CurrentAdmin() admin: AdminContext) {
    return this.accounts.remove(pathUuid(id), admin);
  }
}
