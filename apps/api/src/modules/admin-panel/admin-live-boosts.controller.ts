import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { Public } from '../auth/public.decorator.js';
import {
  adminBoostPricesBody,
  LiveBoostsService,
  type AdminBoostPricesBody,
  type AdminLiveBoostPricesDto,
} from '../live/live-boosts.service.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from './admin-session.guard.js';
import { viaOf } from './admin-users.service.js';

/**
 * «صواريخ الزيارات» (v1.51-live, D233, CONVENTIONS §10.81): the rocket stages' prices in coins. `catalog.view` reads
 * them (with the server config's price beside each); `catalog.manage` (OWNER) changes all four with a reason and the
 * authenticator code again, audited `live.boost_prices.update`. Every write also needs the CSRF header (the guard).
 */
@Public()
@Controller('admin/live-boost-prices')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminLiveBoostsController {
  constructor(
    private readonly boosts: LiveBoostsService,
    private readonly auth: AdminAuthService,
  ) {}

  @Get()
  @RequireCapability('catalog.view')
  get(): Promise<AdminLiveBoostPricesDto> {
    return this.boosts.adminPrices();
  }

  @Put()
  @RequireCapability('catalog.manage')
  async put(
    @Body(new ZodValidationPipe(adminBoostPricesBody)) body: AdminBoostPricesBody,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminLiveBoostPricesDto> {
    await this.auth.reauthenticate(admin, body.totpCode);
    return this.boosts.updatePrices(body.prices, body.reason, viaOf(admin));
  }
}
