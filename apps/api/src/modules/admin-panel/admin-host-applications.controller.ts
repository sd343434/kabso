import { Body, Controller, Get, HttpCode, Param, Post, Query, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { Public } from '../auth/public.decorator.js';
import type { AdminContext } from './admin-auth.service.js';
import {
  AdminHostApplicationsService,
  type HostApplicationsQuery,
} from './admin-host-applications.service.js';
import { pathUuid } from './admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from './admin-session.guard.js';
import { sendTable, tableQuery } from './admin-tables.js';
import { reasonBody } from './admin-v2.schemas.js';

/** Every cookie-authenticated panel route: per-IP limit instead of the public default (§10.54.2). */
const PANEL_LIMIT = RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true });

/** v1.73-social (D209): the list's filters (the panel v2 table shape, §10.60.1). */
export const hostApplicationsQuery = tableQuery(['createdAt', 'decidedAt'], 'createdAt')
  .extend({ status: z.enum(['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED']).optional() })
  .strict();

/**
 * «طلبات المضيفين» (v1.73-social, D209, CONVENTIONS §10.68): the applications «كن مضيفاً مع الإدارة» under the
 * hosts group of the panel. `hosts.applications` (OWNER, SUPPORT, MODERATION) reads the list and an application
 * (audited); `hosts.applications.photos` (OWNER, SUPPORT) the ID pictures (audited per view);
 * `hosts.applications.decide` (OWNER, SUPPORT) approves or rejects with a reason — the CSRF header, no authenticator
 * code again (no money moves).
 */
@Public()
@Controller('admin')
@PANEL_LIMIT
@UseGuards(AdminSessionGuard)
export class AdminHostApplicationsController {
  constructor(private readonly applications: AdminHostApplicationsService) {}

  @Get('host-applications')
  @RequireCapability('hosts.applications')
  async list(
    @Query(new ZodValidationPipe(hostApplicationsQuery)) q: HostApplicationsQuery,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.applications.table(q, admin));
  }

  @Get('host-applications/:applicationId')
  @RequireCapability('hosts.applications')
  detail(@Param('applicationId') id: string, @CurrentAdmin() admin: AdminContext) {
    return this.applications.detail(pathUuid(id), admin);
  }

  @Get('host-applications/:applicationId/photos/:which')
  @RequireCapability('hosts.applications.photos')
  async photo(
    @Param('applicationId') id: string,
    @Param('which') which: string,
    @CurrentAdmin() admin: AdminContext,
    @Res() res: Response,
  ): Promise<void> {
    if (which !== 'photo' && which !== 'selfie') throw new AppException(ErrorCode.NOT_FOUND);
    const bytes = await this.applications.photo(pathUuid(id), which, admin);
    res.setHeader('Content-Type', 'image/webp');
    res.setHeader('Cache-Control', 'private, no-store');
    res.setHeader('Content-Disposition', 'inline');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.status(200).end(bytes);
  }

  @Post('host-applications/:applicationId/approve')
  @HttpCode(200)
  @RequireCapability('hosts.applications.decide')
  approve(@Param('applicationId') id: string, @CurrentAdmin() admin: AdminContext) {
    return this.applications.approve(pathUuid(id), admin);
  }

  @Post('host-applications/:applicationId/reject')
  @HttpCode(200)
  @RequireCapability('hosts.applications.decide')
  reject(
    @Param('applicationId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.applications.reject(pathUuid(id), body.reason, admin);
  }
}
