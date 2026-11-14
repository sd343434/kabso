import { Body, Controller, Get, HttpCode, Param, Post, Query, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { Public } from '../auth/public.decorator.js';
import type { AdminContext } from './admin-auth.service.js';
import {
  AdminCategoriesService,
  type CategoryAction,
  type CategoryRequestsQuery,
} from './admin-categories.service.js';
import { pathUuid } from './admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from './admin-session.guard.js';
import { sendTable, tableQuery } from './admin-tables.js';
import { reasonBody } from './admin-v2.schemas.js';

/** Every cookie-authenticated panel route: per-IP limit instead of the public default (§10.54.2). */
const PANEL_LIMIT = RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true });

export const categoryControlBody = z.strictObject({
  action: z.enum(['VERIFY', 'UNVERIFY', 'CLEAR', 'LOCK', 'UNLOCK']),
  reason: z.string().trim().min(1).max(500),
});

export const categoryRequestsQuery = tableQuery(['createdAt', 'decidedAt'], 'createdAt')
  .extend({ status: z.enum(['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED']).optional() })
  .strict();

/**
 * v1.138-social (D386, CONVENTIONS §10.175.5): the account category in the panel and «طلبات توثيق الفئة». Reading is
 * `users.control_view`; every change `users.profile_edit` with the CSRF header and a reason (no authenticator code:
 * no money moves).
 */
@Public()
@Controller('admin')
@PANEL_LIMIT
@UseGuards(AdminSessionGuard)
export class AdminCategoriesController {
  constructor(private readonly categories: AdminCategoriesService) {}

  @Get('users/:userId/category')
  @RequireCapability('users.control_view')
  state(@Param('userId') id: string) {
    return this.categories.state(pathUuid(id));
  }

  @Post('users/:userId/category')
  @HttpCode(200)
  @RequireCapability('users.profile_edit')
  control(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(categoryControlBody)) body: { action: CategoryAction; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.categories.control(pathUuid(id), body.action, body.reason, admin);
  }

  @Get('category-requests')
  @RequireCapability('users.control_view')
  async list(
    @Query(new ZodValidationPipe(categoryRequestsQuery)) q: CategoryRequestsQuery,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.categories.table(q, admin));
  }

  @Post('category-requests/:requestId/approve')
  @HttpCode(200)
  @RequireCapability('users.profile_edit')
  approve(@Param('requestId') id: string, @CurrentAdmin() admin: AdminContext) {
    return this.categories.approve(pathUuid(id), admin);
  }

  @Post('category-requests/:requestId/reject')
  @HttpCode(200)
  @RequireCapability('users.profile_edit')
  reject(
    @Param('requestId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.categories.reject(pathUuid(id), body.reason, admin);
  }
}
