import { Body, Controller, Get, HttpCode, Param, Patch, Post, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { reasonSchema } from '../admin-panel/admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import { Public } from '../auth/public.decorator.js';
import { FxRatesService } from './fx-rates.service.js';
import { FxSettingsService, type AdminFxSettingsDto } from './fx-settings.service.js';
import {
  clearFxSettingsSchema,
  testFxSettingsSchema,
  updateFxSettingsSchema,
  type ClearFxSettingsInput,
  type FxTestReport,
  type TestFxSettingsInput,
  type UpdateFxSettingsInput,
} from './fx.rules.js';

function pathCurrency(value: string): string {
  if (!/^[A-Za-z]{3}$/.test(value)) throw new AppException(ErrorCode.NOT_FOUND);
  return value.toUpperCase();
}

/**
 * v1.81-social (D245, CONVENTIONS §10.85): the panel's exchange-rate actions behind the cookie session + CSRF — the
 * OWNER's «مزوّد أسعار الصرف» (`/admin/fx-settings`, `fx.settings`; the key's last 4 only, `no-store`) and, for the rate
 * editors (`recharge.rates`), «تحديث الآن» and the acceptance of a held value. The rates table itself is
 * `listAdminRechargeExchangeRates` (D204's path).
 */
@Public()
@Controller('admin')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminFxController {
  constructor(
    private readonly settings: FxSettingsService,
    private readonly rates: FxRatesService,
  ) {}

  @Get('fx-settings')
  @RequireCapability('fx.settings')
  get(@Res({ passthrough: true }) res: Response): Promise<AdminFxSettingsDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.view();
  }

  @Patch('fx-settings')
  @RequireCapability('fx.settings')
  update(
    @Body(new ZodValidationPipe(updateFxSettingsSchema)) body: UpdateFxSettingsInput,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<AdminFxSettingsDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.update(body, admin);
  }

  @Post('fx-settings/test')
  @HttpCode(200)
  @RequireCapability('fx.settings')
  test(
    @Body(new ZodValidationPipe(testFxSettingsSchema)) body: TestFxSettingsInput,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<FxTestReport> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.test(body, admin);
  }

  @Post('fx-settings/clear')
  @HttpCode(200)
  @RequireCapability('fx.settings')
  clear(
    @Body(new ZodValidationPipe(clearFxSettingsSchema)) body: ClearFxSettingsInput,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<AdminFxSettingsDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.clear(body, admin);
  }

  @Post('fx/refresh')
  @HttpCode(200)
  @RequireCapability('recharge.rates')
  refresh(@CurrentAdmin() admin: AdminContext) {
    return this.rates.refresh({ actorUserId: admin.userId, ip: admin.ip, requestId: admin.requestId });
  }

  @Post('fx/held/:currency/accept')
  @HttpCode(200)
  @RequireCapability('recharge.rates')
  acceptHeld(
    @Param('currency') currency: string,
    @Body(new ZodValidationPipe(reasonSchema)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.rates.acceptHeld(pathCurrency(currency), body.reason, {
      actorUserId: admin.userId,
      ip: admin.ip,
      requestId: admin.requestId,
    });
  }
}
