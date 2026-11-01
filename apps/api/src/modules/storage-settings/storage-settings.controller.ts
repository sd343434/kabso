import { Body, Controller, Get, HttpCode, Patch, Post, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import { Public } from '../auth/public.decorator.js';
import {
  clearStorageSettingsSchema,
  testStorageSettingsSchema,
  updateStorageSettingsSchema,
  type ClearStorageSettingsInput,
  type StorageTestReport,
  type TestStorageSettingsInput,
  type UpdateStorageSettingsInput,
} from './storage-settings.rules.js';
import { StorageSettingsService, type AdminStorageSettingsDto } from './storage-settings.service.js';

/**
 * `/admin/storage-settings`: the OWNER's «التخزين (R2 / S3)» section (v1.75-social, D222, CONVENTIONS §10.72) behind
 * the panel's cookie session + CSRF. Responses carry the keys' last 4 characters only (`no-store`).
 */
@Public()
@Controller('admin/storage-settings')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminStorageSettingsController {
  constructor(private readonly settings: StorageSettingsService) {}

  @Get()
  @RequireCapability('storage.settings')
  get(@Res({ passthrough: true }) res: Response): Promise<AdminStorageSettingsDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.view();
  }

  @Patch()
  @RequireCapability('storage.settings')
  update(
    @Body(new ZodValidationPipe(updateStorageSettingsSchema)) body: UpdateStorageSettingsInput,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<AdminStorageSettingsDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.update(body, admin);
  }

  @Post('test')
  @HttpCode(200)
  @RequireCapability('storage.settings')
  test(
    @Body(new ZodValidationPipe(testStorageSettingsSchema)) body: TestStorageSettingsInput,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StorageTestReport> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.test(body, admin);
  }

  @Post('clear')
  @HttpCode(200)
  @RequireCapability('storage.settings')
  clear(
    @Body(new ZodValidationPipe(clearStorageSettingsSchema)) body: ClearStorageSettingsInput,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<AdminStorageSettingsDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.clear(body, admin);
  }
}
