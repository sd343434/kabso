import { Body, Controller, Get, Put, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import { Public } from '../auth/public.decorator.js';
import {
  updateSiteSettingsSchema,
  type SiteSettingsDto,
  type UpdateSiteSettingsInput,
} from './site-settings.rules.js';
import { SiteSettingsService } from './site-settings.service.js';

/** `GET /site/settings`: what the public website shows (D192 reads it at load; cached briefly). */
@Public()
@Controller('site')
export class SiteSettingsController {
  constructor(private readonly settings: SiteSettingsService) {}

  @Get('settings')
  async get(@Res({ passthrough: true }) res: Response): Promise<SiteSettingsDto> {
    res.setHeader('Cache-Control', 'public, max-age=60');
    return this.settings.get();
  }
}

/** `GET|PUT /admin/site-settings`: the OWNER edits them from the panel «إعدادات الموقع» (audited). */
@Public()
@Controller('admin/site-settings')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminSiteSettingsController {
  constructor(private readonly settings: SiteSettingsService) {}

  @Get()
  @RequireCapability('site.settings')
  get(): Promise<SiteSettingsDto> {
    return this.settings.get();
  }

  @Put()
  @RequireCapability('site.settings')
  put(
    @Body(new ZodValidationPipe(updateSiteSettingsSchema)) body: UpdateSiteSettingsInput,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<SiteSettingsDto> {
    return this.settings.update(body, { userId: admin.userId, ip: admin.ip, requestId: admin.requestId });
  }
}
