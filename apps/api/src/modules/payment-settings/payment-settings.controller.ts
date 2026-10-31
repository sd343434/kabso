import { Body, Controller, Get, HttpCode, Patch, Post, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import { Public } from '../auth/public.decorator.js';
import {
  clearPaymentKeysSchema,
  testPaymentKeySchema,
  updatePaymentSettingsSchema,
  type ClearPaymentKeysInput,
  type TestPaymentKeyInput,
  type UpdatePaymentSettingsInput,
} from './payment-settings.rules.js';
import {
  PaymentSettingsService,
  type AdminPaymentSettingsDto,
  type PaymentKeyCheckDto,
} from './payment-settings.service.js';

/**
 * `/admin/payment-settings`: the OWNER's «الدفع (Stripe)» section (v1.64-social, D196, CONVENTIONS §10.53.1) behind
 * the panel's cookie session + CSRF. Responses carry fingerprints only (`no-store`).
 */
@Public()
@Controller('admin/payment-settings')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminPaymentSettingsController {
  constructor(private readonly settings: PaymentSettingsService) {}

  @Get()
  @RequireCapability('payments.settings')
  get(@Res({ passthrough: true }) res: Response): Promise<AdminPaymentSettingsDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.view();
  }

  @Patch()
  @RequireCapability('payments.settings')
  update(
    @Body(new ZodValidationPipe(updatePaymentSettingsSchema)) body: UpdatePaymentSettingsInput,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<AdminPaymentSettingsDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.update(body, admin);
  }

  @Post('test')
  @HttpCode(200)
  @RequireCapability('payments.settings')
  test(
    @Body(new ZodValidationPipe(testPaymentKeySchema)) body: TestPaymentKeyInput,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<PaymentKeyCheckDto> {
    return this.settings.test(body, admin);
  }

  @Post('clear-keys')
  @HttpCode(200)
  @RequireCapability('payments.settings')
  clear(
    @Body(new ZodValidationPipe(clearPaymentKeysSchema)) body: ClearPaymentKeysInput,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<AdminPaymentSettingsDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.clear(body, admin);
  }
}
