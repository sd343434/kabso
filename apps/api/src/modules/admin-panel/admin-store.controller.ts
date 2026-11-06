import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import type { z } from 'zod';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { Public } from '../auth/public.decorator.js';
import {
  StoreAdminService,
  type AdminStoreItemDeletedDto,
  type AdminStoreItemDto,
  type AdminStoreItemListDto,
  type AdminStoreSalesDto,
  type AdminStoreUploadDto,
} from '../store/store-admin.service.js';
import {
  createStoreItemBody,
  storeOptionalReasonBody,
  storeReasonBody,
  storeSalesQuery,
  storeUploadQuery,
  updateStoreItemBody,
  type CreateStoreItemBody,
  type UpdateStoreItemBody,
} from '../store/store.schemas.js';
import type { AdminContext } from './admin-auth.service.js';
import { pathUuid } from './admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from './admin-session.guard.js';
import { viaOf } from './admin-users.service.js';

/** The raw-bytes path of {@link AdminStoreController.upload} (app.setup's raw body parser). */
export const STORE_UPLOAD_PATH = '/api/v1/admin/store/uploads';

/**
 * «المتجر» in the panel (D270, CONVENTIONS §10.98.5): `catalog.view` (OWNER, SUPPORT, FINANCE) reads the items and the
 * sales; `catalog.manage` (OWNER) uploads art, adds, changes and switches items on / off — each with a reason, audited
 * `store.item.*`. Every write also needs the CSRF header (the guard).
 */
@Public()
@Controller('admin/store')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminStoreController {
  constructor(private readonly store: StoreAdminService) {}

  /**
   * One art file: a PNG / WebP still, or an animation — an SVGA 2.x or an MP4 (told by its bytes) — the raw bytes
   * (`application/octet-stream`, at most 26 MB); the URL goes into the item's form.
   */
  @Post('uploads')
  @HttpCode(201)
  @RequireCapability('catalog.manage')
  upload(
    @Query(new ZodValidationPipe(storeUploadQuery)) q: z.output<typeof storeUploadQuery>,
    @Req() req: Request,
  ): Promise<AdminStoreUploadDto> {
    return this.store.upload(q.kind, req.body);
  }

  @Get('items')
  @RequireCapability('catalog.view')
  list(): Promise<AdminStoreItemListDto> {
    return this.store.list();
  }

  @Post('items')
  @HttpCode(201)
  @RequireCapability('catalog.manage')
  create(
    @Body(new ZodValidationPipe(createStoreItemBody)) body: CreateStoreItemBody,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminStoreItemDto> {
    return this.store.create(body, viaOf(admin));
  }

  @Patch('items/:itemId')
  @RequireCapability('catalog.manage')
  update(
    @Param('itemId') itemId: string,
    @Body(new ZodValidationPipe(updateStoreItemBody)) body: UpdateStoreItemBody,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminStoreItemDto> {
    return this.store.update(pathUuid(itemId), body, viaOf(admin));
  }

  @Post('items/:itemId/enable')
  @HttpCode(200)
  @RequireCapability('catalog.manage')
  enable(
    @Param('itemId') itemId: string,
    @Body(new ZodValidationPipe(storeReasonBody)) body: z.output<typeof storeReasonBody>,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminStoreItemDto> {
    return this.store.setEnabled(pathUuid(itemId), true, body.reason, viaOf(admin));
  }

  @Post('items/:itemId/disable')
  @HttpCode(200)
  @RequireCapability('catalog.manage')
  disable(
    @Param('itemId') itemId: string,
    @Body(new ZodValidationPipe(storeReasonBody)) body: z.output<typeof storeReasonBody>,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminStoreItemDto> {
    return this.store.setEnabled(pathUuid(itemId), false, body.reason, viaOf(admin));
  }

  /**
   * v1.79-live (D289b, §10.102.5) «حذف»: deleted for real when nobody bought or holds it, else hidden from the store
   * (kept for its owners). The reason is optional; no authenticator code (not a money action).
   */
  @Delete('items/:itemId')
  @HttpCode(200)
  @RequireCapability('catalog.manage')
  remove(
    @Param('itemId') itemId: string,
    @Body(new ZodValidationPipe(storeOptionalReasonBody)) body: z.output<typeof storeOptionalReasonBody>,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminStoreItemDeletedDto> {
    return this.store.remove(pathUuid(itemId), body.reason, viaOf(admin));
  }

  /** v1.79-live (D289b) «إرجاع للمتجر»: a hidden item back in the store. */
  @Post('items/:itemId/restore')
  @HttpCode(200)
  @RequireCapability('catalog.manage')
  restore(
    @Param('itemId') itemId: string,
    @Body(new ZodValidationPipe(storeOptionalReasonBody)) body: z.output<typeof storeOptionalReasonBody>,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminStoreItemDto> {
    return this.store.restore(pathUuid(itemId), body.reason, viaOf(admin));
  }

  /** The latest sales (≤ `limit`, 50 by default) and the totals, of one item or all. */
  @Get('sales')
  @RequireCapability('catalog.view')
  sales(
    @Query(new ZodValidationPipe(storeSalesQuery)) q: z.output<typeof storeSalesQuery>,
  ): Promise<AdminStoreSalesDto> {
    return this.store.sales(q.itemId, q.limit ?? 50);
  }
}
