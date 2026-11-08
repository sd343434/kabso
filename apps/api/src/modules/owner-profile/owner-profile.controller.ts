import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  Module,
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
import { byIp, byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { Public } from '../auth/public.decorator.js';
import { MediaModule } from '../media/media.module.js';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { UsersModule } from '../users/users.module.js';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { PostsModule } from '../posts/posts.module.js';
import { OwnerAnnouncementsService } from './owner-announcements.service.js';
import { OwnerFeedbackService } from './owner-feedback.service.js';
import { OwnerProfileService, type OwnerMeta } from './owner-profile.service.js';
import { appActor, OwnerProfitService, panelActor } from './owner-profit.service.js';

const meta = (req: AppRequest): OwnerMeta => ({ ip: clientIp(req), requestId: getRequestId(req) });
const PROFILE_LIMIT = {
  bucket: 'users:profile',
  rule: 'profileUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/**
 * v1.95-social (D301, CONVENTIONS §10.112): the app owner's profile «صفحة صاحب البرنامج» in the app — the cover videos,
 * «رحلة Kabso», «لوحة المؤسس» (owner only: 403 `OWNER_ONLY`), and «اقترح ميزة / أبلغ عن موظف» (anyone ACTIVE).
 * «رسمي» and «إعلانات رسمية» live in the posts module.
 */
@Controller()
export class OwnerProfileController {
  constructor(
    private readonly owner: OwnerProfileService,
    private readonly feedback: OwnerFeedbackService,
    private readonly announcements: OwnerAnnouncementsService,
    private readonly profitService: OwnerProfitService,
  ) {}

  /**
   * D301 follow-up (§10.112.7): a bilingual official announcement (owner only), with the `Idempotency-Key` of
   * `POST /posts`; everyone is told once, after the request.
   */
  @Post('owner/announcements')
  @HttpCode(201)
  createAnnouncement(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Headers('idempotency-key') rawKey: string | undefined,
    @Body() body: unknown,
  ) {
    const key = z.uuid().safeParse(rawKey ?? '');
    if (!key.success) {
      throw AppException.validation([
        { field: 'Idempotency-Key', issue: rawKey ? 'invalid_value' : 'required' },
      ]);
    }
    return this.announcements.create(auth.userId, key.data, body, meta(req));
  }

  @Patch('owner/announcements/:postId')
  @HttpCode(200)
  updateAnnouncement(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('postId') postId: string,
    @Body() body: unknown,
  ) {
    return this.announcements.update(auth.userId, postId, body, meta(req));
  }

  @Put('me/cover-video/:lang')
  @HttpCode(200)
  setCoverVideo(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('lang') lang: string,
    @Body() body: unknown,
  ) {
    return this.owner.setCoverVideo(auth.userId, lang, body, meta(req));
  }

  @Delete('me/cover-video/:lang')
  @HttpCode(200)
  removeCoverVideo(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest, @Param('lang') lang: string) {
    return this.owner.removeCoverVideo(auth.userId, lang, meta(req));
  }

  @Get('users/:username/journey')
  @RateLimit(PROFILE_LIMIT)
  journey(@Param('username') username: string) {
    return this.owner.journeyOf(username);
  }

  @Post('owner/journey')
  @HttpCode(201)
  createMilestone(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest, @Body() body: unknown) {
    return this.owner.createMilestone(auth.userId, body, meta(req));
  }

  @Put('owner/journey/order')
  @HttpCode(200)
  reorder(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest, @Body() body: unknown) {
    return this.owner.reorder(auth.userId, body, meta(req));
  }

  @Patch('owner/journey/:milestoneId')
  @HttpCode(200)
  updateMilestone(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('milestoneId') id: string,
    @Body() body: unknown,
  ) {
    return this.owner.updateMilestone(auth.userId, id, body, meta(req));
  }

  @Delete('owner/journey/:milestoneId')
  @HttpCode(204)
  async deleteMilestone(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('milestoneId') id: string,
  ): Promise<void> {
    await this.owner.deleteMilestone(auth.userId, id, meta(req));
  }

  /** §10.112.9: the founder pinned at the top of search (every signed-in caller; null when blocked or none). */
  @Get('search/featured')
  featured(@CurrentAuth() auth: AuthContext) {
    return this.owner.featured(auth.userId);
  }

  @Get('owner/dashboard')
  dashboard(@CurrentAuth() auth: AuthContext) {
    return this.owner.dashboard(auth.userId);
  }

  /** D301 follow-up (§10.112.10): «الربح» — the day (default today) and its month, before and after every share. */
  @Get('owner/profit')
  profit(@CurrentAuth() auth: AuthContext, @Query() query: unknown) {
    return this.profitService.profit(auth.userId, query);
  }

  @Get('owner/fixed-costs')
  fixedCosts(@CurrentAuth() auth: AuthContext) {
    return this.profitService.listCostsFor(auth.userId);
  }

  @Post('owner/fixed-costs')
  @HttpCode(201)
  createFixedCost(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest, @Body() body: unknown) {
    return this.profitService.createCost(appActor(auth.userId, meta(req)), body);
  }

  @Patch('owner/fixed-costs/:costId')
  @HttpCode(200)
  updateFixedCost(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('costId') id: string,
    @Body() body: unknown,
  ) {
    return this.profitService.updateCost(appActor(auth.userId, meta(req)), id, body);
  }

  @Delete('owner/fixed-costs/:costId')
  @HttpCode(204)
  async deleteFixedCost(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('costId') id: string,
  ): Promise<void> {
    await this.profitService.deleteCost(appActor(auth.userId, meta(req)), id);
  }

  @Post('owner/feedback')
  @HttpCode(201)
  createFeedback(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest, @Body() body: unknown) {
    return this.feedback.create(auth.userId, body, meta(req));
  }

  @Get('owner/feedback/staff')
  feedbackStaff(@Query() query: unknown) {
    return this.feedback.staff(query);
  }
}

/**
 * v1.95-social (D301, §10.112.5): «صندوق المؤسس» in the panel — `owner.inbox`, OWNER only (staff never see reports
 * about staff). Views and status changes are audited (`via: panel`).
 */
@Public()
@Controller('admin/owner-inbox')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminOwnerInboxController {
  constructor(private readonly feedback: OwnerFeedbackService) {}

  @Get()
  @RequireCapability('owner.inbox')
  list(@Query() query: unknown) {
    return this.feedback.list(query);
  }

  @Get(':feedbackId')
  @RequireCapability('owner.inbox')
  detail(@CurrentAdmin() admin: AdminContext, @Param('feedbackId') id: string) {
    return this.feedback.detail(admin, id);
  }

  @Put(':feedbackId/status')
  @RequireCapability('owner.inbox')
  status(@CurrentAdmin() admin: AdminContext, @Param('feedbackId') id: string, @Body() body: unknown) {
    return this.feedback.setStatus(admin, id, body);
  }

  @Delete(':feedbackId')
  @HttpCode(204)
  @RequireCapability('owner.inbox')
  async remove(@CurrentAdmin() admin: AdminContext, @Param('feedbackId') id: string): Promise<void> {
    await this.feedback.remove(admin, id);
  }

  @Get(':feedbackId/images/:index')
  @RequireCapability('owner.inbox')
  async image(
    @Param('feedbackId') id: string,
    @Param('index') index: string,
    @Res() res: Response,
  ): Promise<void> {
    const bytes = await this.feedback.image(id, index);
    res.setHeader('Content-Type', 'image/webp');
    res.setHeader('Cache-Control', 'private, no-store');
    res.setHeader('Content-Disposition', 'inline');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.status(200).end(bytes);
  }
}

/**
 * D301 follow-up (§10.112.10): the fixed monthly costs of «الربح» in the panel — `owner.costs`, OWNER only; every change
 * audited (`via: panel`).
 */
@Public()
@Controller('admin/owner-fixed-costs')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminOwnerFixedCostsController {
  constructor(private readonly profit: OwnerProfitService) {}

  @Get()
  @RequireCapability('owner.costs')
  list() {
    return this.profit.listCosts();
  }

  @Post()
  @HttpCode(201)
  @RequireCapability('owner.costs')
  create(@CurrentAdmin() admin: AdminContext, @Body() body: unknown) {
    return this.profit.createCost(panelActor(admin), body);
  }

  @Patch(':costId')
  @RequireCapability('owner.costs')
  update(@CurrentAdmin() admin: AdminContext, @Param('costId') id: string, @Body() body: unknown) {
    return this.profit.updateCost(panelActor(admin), id, body);
  }

  @Delete(':costId')
  @HttpCode(204)
  @RequireCapability('owner.costs')
  async remove(@CurrentAdmin() admin: AdminContext, @Param('costId') id: string): Promise<void> {
    await this.profit.deleteCost(panelActor(admin), id);
  }
}

/** v1.95-social (D301): the app owner's profile «صفحة صاحب البرنامج». */
@Module({
  imports: [AdminPanelModule, MediaModule, NotificationsModule, UsersModule, PostsModule],
  controllers: [OwnerProfileController, AdminOwnerInboxController, AdminOwnerFixedCostsController],
  providers: [OwnerProfileService, OwnerFeedbackService, OwnerAnnouncementsService, OwnerProfitService],
})
export class OwnerProfileModule {}
