import { Body, Controller, Get, HttpCode, Param, Post, Put, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { Public } from '../auth/public.decorator.js';
import type { AdminContext } from './admin-auth.service.js';
import { reasonCodeBody } from './admin-control.schemas.js';
import { AdminDeviceSignupsService } from './admin-device-signups.service.js';
import { pathUuid } from './admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from './admin-session.guard.js';

/** Every cookie-authenticated panel route: per-IP limit instead of the public default (§10.54.2). */
const PANEL_LIMIT = RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true });

const exceptionBody = z.strictObject({
  maxAccounts: z.number().int().min(1).max(100),
  reason: z.string().trim().min(1).max(500),
  totpCode: z.string().regex(/^[0-9]{6}$/),
});

/**
 * v1.78-social (D223, CONVENTIONS §10.75): the user page's «الجهاز» — the accounts made on the account's sign-up device
 * (`users.device_view`: OWNER, SUPPORT; audited) and the OWNER's exception for that device (`users.device_exception`;
 * a reason and the authenticator code again; audited).
 */
@Public()
@Controller('admin')
@PANEL_LIMIT
@UseGuards(AdminSessionGuard)
export class AdminDeviceSignupsController {
  constructor(private readonly devices: AdminDeviceSignupsService) {}

  @Get('users/:userId/device-signups')
  @RequireCapability('users.device_view')
  get(@Param('userId') id: string, @CurrentAdmin() admin: AdminContext) {
    return this.devices.get(pathUuid(id), admin);
  }

  @Put('users/:userId/device-signups/exception')
  @RequireCapability('users.device_exception')
  grant(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(exceptionBody)) body: z.infer<typeof exceptionBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.devices.grant(pathUuid(id), body, admin);
  }

  @Post('users/:userId/device-signups/exception/remove')
  @HttpCode(200)
  @RequireCapability('users.device_exception')
  remove(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(reasonCodeBody)) body: { reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.devices.remove(pathUuid(id), body, admin);
  }
}
