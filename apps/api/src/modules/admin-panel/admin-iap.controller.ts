import { Body, Controller, Get, HttpCode, Param, Patch, Post, Query, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { Public } from '../auth/public.decorator.js';
import {
  iapProductCreateBody,
  iapProductUpdateBody,
  iapSettingsBody,
  iapUnbanBody,
  type IapProductCreateBody,
  type IapProductUpdateBody,
  type IapUnbanBody,
} from '../store-iap/iap.schemas.js';
import type { AdminContext } from './admin-auth.service.js';
import { AdminIapService } from './admin-iap.service.js';
import { pathUuid } from './admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from './admin-session.guard.js';
import { sendTable, tableQuery, type TableQuery } from './admin-tables.js';

const purchasesQuery = tableQuery(['createdAt', 'coins'], 'createdAt')
  .extend({
    platform: z.enum(['GOOGLE_PLAY', 'APP_STORE']).optional(),
    status: z.enum(['CREDITED', 'REJECTED', 'REFUNDED']).optional(),
    environment: z.enum(['PRODUCTION', 'SANDBOX']).optional(),
  })
  .strict();
const bansQuery = tableQuery(['createdAt'], 'createdAt')
  .extend({
    status: z.enum(['ACTIVE', 'LIFTED']).optional(),
  })
  .strict();

/**
 * v1.110-social (D345, CONVENTIONS §10.144.6): «مشتريات المتجر» in the panel. `store_iap.view` reads; `store_iap.manage`
 * (OWNER) changes the catalogue and the switch and polls Google now; `store_iap.unban` (OWNER) lifts a refund ban.
 */
@Public()
@Controller('admin/store-iap')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminIapController {
  constructor(private readonly iap: AdminIapService) {}

  @Get('overview')
  @RequireCapability('store_iap.view')
  overview() {
    return this.iap.overview();
  }

  @Patch('settings')
  @RequireCapability('store_iap.manage')
  settings(
    @Body(new ZodValidationPipe(iapSettingsBody)) body: { oncePerAccountDevice: boolean; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.iap.updateSettings(body.oncePerAccountDevice, body.reason, admin);
  }

  @Get('products')
  @RequireCapability('store_iap.view')
  products() {
    return this.iap.products();
  }

  @Post('products')
  @HttpCode(201)
  @RequireCapability('store_iap.manage')
  createProduct(
    @Body(new ZodValidationPipe(iapProductCreateBody)) body: IapProductCreateBody,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.iap.createProduct(body, admin);
  }

  @Patch('products/:productId')
  @RequireCapability('store_iap.manage')
  updateProduct(
    @Param('productId') id: string,
    @Body(new ZodValidationPipe(iapProductUpdateBody)) body: IapProductUpdateBody,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.iap.updateProduct(pathUuid(id), body, admin);
  }

  @Get('purchases')
  @RequireCapability('store_iap.view')
  async purchases(
    @Query(new ZodValidationPipe(purchasesQuery)) q: z.output<typeof purchasesQuery>,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.iap.purchases(q as TableQuery & typeof q, admin));
  }

  @Get('refund-bans')
  @RequireCapability('store_iap.view')
  async refundBans(
    @Query(new ZodValidationPipe(bansQuery)) q: z.output<typeof bansQuery>,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.iap.refundBans(q as TableQuery & typeof q, admin));
  }

  @Post('refund-bans/:banId/unban')
  @HttpCode(200)
  @RequireCapability('store_iap.unban')
  unban(
    @Param('banId') id: string,
    @Body(new ZodValidationPipe(iapUnbanBody)) body: IapUnbanBody,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.iap.unban(pathUuid(id), body, admin);
  }

  @Post('google/voided-sync')
  @HttpCode(200)
  @RequireCapability('store_iap.manage')
  sync(@CurrentAdmin() admin: AdminContext) {
    return this.iap.syncVoided(admin);
  }
}
