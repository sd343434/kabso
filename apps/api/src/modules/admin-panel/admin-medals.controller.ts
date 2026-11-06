import { Body, Controller, Get, Param, Put, UseGuards } from '@nestjs/common';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { Public } from '../auth/public.decorator.js';
import {
  adminMedalBody,
  MedalsAdminService,
  type AdminMedalBody,
  type AdminMedalDto,
  type AdminMedalListDto,
} from '../medals/medals-admin.service.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from './admin-session.guard.js';
import { viaOf } from './admin-users.service.js';

/**
 * «الميداليات» in the panel (v1.81-live, D291, CONVENTIONS §10.104.4): `catalog.view` reads every medal with its
 * levels and holders; `catalog.manage` (OWNER) replaces a medal's tab and levels with a reason and the authenticator
 * code again, audited `medals.levels.update`. Every write also needs the CSRF header (the guard).
 */
@Public()
@Controller('admin/medals')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminMedalsController {
  constructor(
    private readonly medals: MedalsAdminService,
    private readonly auth: AdminAuthService,
  ) {}

  @Get()
  @RequireCapability('catalog.view')
  list(): Promise<AdminMedalListDto> {
    return this.medals.list();
  }

  @Put(':code')
  @RequireCapability('catalog.manage')
  async put(
    @Param('code') code: string,
    @Body(new ZodValidationPipe(adminMedalBody)) body: AdminMedalBody,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminMedalDto> {
    await this.auth.reauthenticate(admin, body.totpCode);
    return this.medals.update(code.slice(0, 40), body, viaOf(admin));
  }
}
