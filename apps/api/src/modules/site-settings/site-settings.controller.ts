import { Body, Controller, Get, Put, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import { Public } from '../auth/public.decorator.js';
import {
  updateCameraFxSchema,
  type CameraFxSettingsDto,
  type UpdateCameraFxInput,
} from './camera-fx.rules.js';
import {
  SITE_SETTINGS_CACHE_CONTROL,
  updateSiteSettingsSchema,
  type SiteSettingsDto,
  type UpdateSiteSettingsInput,
} from './site-settings.rules.js';
import { SiteSettingsService } from './site-settings.service.js';

/** `GET /site/settings`: what the public website shows (read at every load; cached 60 s). */
@Public()
@Controller('site')
export class SiteSettingsController {
  constructor(private readonly settings: SiteSettingsService) {}

  @Get('settings')
  async get(@Res({ passthrough: true }) res: Response): Promise<SiteSettingsDto> {
    res.setHeader('Cache-Control', SITE_SETTINGS_CACHE_CONTROL);
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

/**
 * v1.49-live (D228): `GET|PUT /admin/camera-fx` — the OWNER's switch of the app's camera effects engine (DeepAR or
 * the free ML Kit + MediaPipe engine), read by the app in `LiveConfig.cameraFxEngine` (audited).
 */
@Public()
@Controller('admin/camera-fx')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminCameraFxController {
  constructor(private readonly settings: SiteSettingsService) {}

  @Get()
  @RequireCapability('site.settings')
  get(): Promise<CameraFxSettingsDto> {
    return this.settings.getCameraFx();
  }

  @Put()
  @RequireCapability('site.settings')
  put(
    @Body(new ZodValidationPipe(updateCameraFxSchema)) body: UpdateCameraFxInput,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<CameraFxSettingsDto> {
    return this.settings.updateCameraFx(body, {
      userId: admin.userId,
      ip: admin.ip,
      requestId: admin.requestId,
    });
  }
}
