import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { clientIp, type AppRequest, type AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { AdminGuard, RequireAdminPermission } from '../levels/admin.guard.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import type { PageDto } from '../posts/post-views.js';
import { pageQuerySchema, type PageQuery } from '../posts/posts.schemas.js';
import { adminReportsQuerySchema, type AdminReportsQuery } from './safety.schemas.js';
import { SafetyService, type PrivacyDto, type ReportDto } from './safety.service.js';

const BLOCK_LIMIT = {
  bucket: 'social:block',
  rule: 'blockUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** Block, mute, hide, reports and privacy (contract v1.5-social draft, CONVENTIONS §11.7). */
@Controller()
export class SafetyController {
  constructor(private readonly safety: SafetyService) {}

  @Put('users/:username/block')
  @HttpCode(200)
  @RateLimit(BLOCK_LIMIT)
  block(
    @CurrentAuth() auth: AuthContext,
    @Param('username') username: string,
  ): Promise<{ blocked: boolean }> {
    return this.safety.block(auth.userId, username, true);
  }

  @Delete('users/:username/block')
  @HttpCode(200)
  unblock(
    @CurrentAuth() auth: AuthContext,
    @Param('username') username: string,
  ): Promise<{ blocked: boolean }> {
    return this.safety.block(auth.userId, username, false);
  }

  @Get('me/blocks')
  blocks(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<UserSummaryDto>> {
    return this.safety.blocks(auth.userId, query);
  }

  @Put('users/:username/mute')
  @HttpCode(200)
  mute(@CurrentAuth() auth: AuthContext, @Param('username') username: string): Promise<{ muted: boolean }> {
    return this.safety.mute(auth.userId, username, true);
  }

  @Delete('users/:username/mute')
  @HttpCode(200)
  unmute(@CurrentAuth() auth: AuthContext, @Param('username') username: string): Promise<{ muted: boolean }> {
    return this.safety.mute(auth.userId, username, false);
  }

  @Put('posts/:postId/hide')
  @HttpCode(204)
  async hide(@CurrentAuth() auth: AuthContext, @Param('postId') postId: string): Promise<void> {
    await this.safety.hide(auth.userId, postId, true);
  }

  @Delete('posts/:postId/hide')
  @HttpCode(204)
  async unhide(@CurrentAuth() auth: AuthContext, @Param('postId') postId: string): Promise<void> {
    await this.safety.hide(auth.userId, postId, false);
  }

  @Post('reports')
  @RateLimit({ bucket: 'social:report', rule: 'reportUser', key: byUserId, replacesDefault: true })
  async report(
    @CurrentAuth() auth: AuthContext,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<ReportDto> {
    const { report, created } = await this.safety.report(auth.userId, body);
    res.status(created ? 201 : 200);
    return report;
  }

  @Get('me/privacy')
  privacy(@CurrentAuth() auth: AuthContext): Promise<PrivacyDto> {
    return this.safety.privacy(auth.userId);
  }

  @Patch('me/privacy')
  updatePrivacy(@CurrentAuth() auth: AuthContext, @Body() body: unknown): Promise<PrivacyDto> {
    return this.safety.updatePrivacy(auth.userId, body);
  }
}

/** The report queue (permission MODERATION; every action audited). */
@Controller('admin/reports')
@UseGuards(AdminGuard)
export class AdminReportsController {
  constructor(private readonly safety: SafetyService) {}

  @Get()
  @RequireAdminPermission('MODERATION')
  list(
    @Query(new ZodValidationPipe(adminReportsQuerySchema)) query: AdminReportsQuery,
  ): Promise<PageDto<ReportDto>> {
    return this.safety.adminList(query);
  }

  @Post(':reportId/actions')
  @HttpCode(200)
  @RequireAdminPermission('MODERATION')
  act(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('reportId') reportId: string,
    @Body() body: unknown,
  ): Promise<ReportDto> {
    return this.safety.act(
      { userId: auth.userId, ip: clientIp(req), requestId: getRequestId(req) },
      reportId,
      body,
    );
  }
}
