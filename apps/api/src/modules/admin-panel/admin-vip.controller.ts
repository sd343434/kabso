import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { z } from 'zod';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { Public } from '../auth/public.decorator.js';
import {
  VipAdminService,
  type AdminVipTierDto,
  type AdminVipTierListDto,
  type AdminVipUploadDto,
} from '../vip/vip-admin.service.js';
import { VIP_CODE_PATTERN } from '../vip/vip-rules.js';
import {
  createVipTierBody,
  reorderVipTiersBody,
  updateVipTierBody,
  vipReasonBody,
  type CreateVipTierBody,
  type UpdateVipTierBody,
} from '../vip/vip.schemas.js';
import type { AdminContext } from './admin-auth.service.js';
import { pathUuid } from './admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from './admin-session.guard.js';
import { viaOf } from './admin-users.service.js';

/** v1.83-social (D258): the upload's kind and the tier's code (the files' folder). D374: + `video` (MP4). */
const vipUploadQuery = z.strictObject({
  kind: z.enum(['animation', 'still', 'video']),
  tier: z.string().regex(VIP_CODE_PATTERN),
});

/** The raw-bytes path of {@link AdminVipController.upload} (app.setup's raw body parser). */
export const VIP_UPLOAD_PATH = '/api/v1/admin/vip/uploads';

/**
 * «VIP» in the panel (v1.82-social, D252, CONVENTIONS §10.93.4): `catalog.view` (OWNER, SUPPORT, FINANCE) reads the
 * tiers; `catalog.manage` (OWNER) adds, changes, orders and switches them on / off — each with a reason, audited
 * `vip.tier.*`. Every write also needs the CSRF header (the guard).
 */
@Public()
@Controller('admin/vip')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminVipController {
  constructor(private readonly vip: VipAdminService) {}

  /**
   * v1.83-social (D258, §10.94.6): one file of a tier's badge or perk art — an SVGA 2.x animation or a PNG / WebP
   * still — the raw bytes (`application/octet-stream`, at most 26 MB); the URL goes into the tier's form. D374: or an
   * MP4 (`kind=video`, ≤ 8 MB, ≤ 15 s, H.264).
   */
  @Post('uploads')
  @HttpCode(201)
  @RequireCapability('catalog.manage')
  upload(
    @Query(new ZodValidationPipe(vipUploadQuery)) q: z.output<typeof vipUploadQuery>,
    @Req() req: Request,
  ): Promise<AdminVipUploadDto> {
    return this.vip.upload(q.kind, q.tier, req.body);
  }

  @Get('tiers')
  @RequireCapability('catalog.view')
  list(): Promise<AdminVipTierListDto> {
    return this.vip.list();
  }

  @Post('tiers')
  @HttpCode(201)
  @RequireCapability('catalog.manage')
  create(
    @Body(new ZodValidationPipe(createVipTierBody)) body: CreateVipTierBody,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminVipTierDto> {
    return this.vip.create(body, viaOf(admin));
  }

  @Patch('tiers/:tierId')
  @RequireCapability('catalog.manage')
  update(
    @Param('tierId') tierId: string,
    @Body(new ZodValidationPipe(updateVipTierBody)) body: UpdateVipTierBody,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminVipTierDto> {
    return this.vip.update(pathUuid(tierId), body, viaOf(admin));
  }

  @Post('tiers/:tierId/enable')
  @HttpCode(200)
  @RequireCapability('catalog.manage')
  enable(
    @Param('tierId') tierId: string,
    @Body(new ZodValidationPipe(vipReasonBody)) body: z.output<typeof vipReasonBody>,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminVipTierDto> {
    return this.vip.setEnabled(pathUuid(tierId), true, body.reason, viaOf(admin));
  }

  @Post('tiers/:tierId/disable')
  @HttpCode(200)
  @RequireCapability('catalog.manage')
  disable(
    @Param('tierId') tierId: string,
    @Body(new ZodValidationPipe(vipReasonBody)) body: z.output<typeof vipReasonBody>,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminVipTierDto> {
    return this.vip.setEnabled(pathUuid(tierId), false, body.reason, viaOf(admin));
  }

  @Put('tier-order')
  @RequireCapability('catalog.manage')
  reorder(
    @Body(new ZodValidationPipe(reorderVipTiersBody)) body: z.output<typeof reorderVipTiersBody>,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminVipTierListDto> {
    return this.vip.reorder(body.tierIds, body.reason, viaOf(admin));
  }
}
