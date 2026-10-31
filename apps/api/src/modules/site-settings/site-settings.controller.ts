import { Body, Controller, Get, Put, Req, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { clientIp, type AppRequest, type AuthContext } from '../../common/http/request-context.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { Public } from '../auth/public.decorator.js';
import { AdminGuard, RequireAdminPermission } from '../levels/admin.guard.js';
import { SITE_SETTINGS_CACHE_CONTROL, type SiteSettingsDto } from './site-settings.rules.js';
import { SiteSettingsService, type SiteSettingsUpdate } from './site-settings.service.js';

const socialValue = z.string().max(200).nullable().optional();

export const updateSiteSettingsSchema = z.strictObject({
  socials: z.strictObject({ instagram: socialValue, tiktok: socialValue, whatsapp: socialValue }).optional(),
  topupEnabled: z.boolean().optional(),
});

/**
 * `GET /site/settings` (D192, v1.61-social, §10.55): public — the website reads its social links and the top-up
 * switch at load. Rate limited by the public per-IP default; `Cache-Control: public, max-age=60`.
 */
@Controller('site')
export class SiteSettingsController {
  constructor(private readonly settings: SiteSettingsService) {}

  @Public()
  @Get('settings')
  async get(@Res({ passthrough: true }) res: Response): Promise<SiteSettingsDto> {
    res.setHeader('Cache-Control', SITE_SETTINGS_CACHE_CONTROL);
    return this.settings.get();
  }
}

/**
 * `PUT /admin/site-settings` (D192): `role = ADMIN` with the `SITE_SETTINGS` permission (the owner's; D191's admin
 * panel maps OWNER onto it). Partial: only the fields sent change; a social link `null` or `""` removes it. 200 with
 * the settings after the change; audited `site.settings.update` (before/after) when something changed.
 */
@Controller('admin/site-settings')
@UseGuards(AdminGuard)
export class AdminSiteSettingsController {
  constructor(private readonly settings: SiteSettingsService) {}

  @Put()
  @RequireAdminPermission('SITE_SETTINGS')
  async update(
    @Body(new ZodValidationPipe(updateSiteSettingsSchema)) body: SiteSettingsUpdate,
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
  ): Promise<SiteSettingsDto> {
    if (body.socials === undefined && body.topupEnabled === undefined) {
      throw AppException.validation([{ field: '', issue: 'required' }]);
    }
    return this.settings.update(body, {
      userId: auth.userId,
      ip: clientIp(req),
      requestId: getRequestId(req),
    });
  }
}
