import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  Put,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { z } from 'zod';
import { clientIp, type AppRequest } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { AuthContext } from '../../common/http/request-context.js';
import type { AdminContext } from './admin-auth.service.js';
import { moderateBody, reasonBody } from './admin-live-moderation.controller.js';
import { AdminLiveModerationService, type ModerateBody } from './admin-live-moderation.service.js';
import { pathUuid } from './admin-panel.schemas.js';
import { AdminModerationService } from './admin-moderation.service.js';
import { AdminStaffShiftsService } from './admin-staff-shifts.service.js';
import {
  resolveReportSchema,
  sharedReportsQuerySchema,
  type SharedReportsQuery,
} from '../safety/safety.schemas.js';
import { CurrentStaff, NotStaffWork, StaffAppGuard, StaffCapability } from './staff-app.guard.js';
import { StaffAppService } from './staff-app.service.js';
import {
  AdminGiftEventsService,
  eventBadgeInputSchema,
  eventUploadQuery,
  type EventBadgeInput,
} from './admin-gift-events.service.js';
import type { EventMediaKind } from '../programs/event-media.js';

/** v1.97-social (D303 follow-ups): the app editor's art upload (raw bytes, app.setup). */
export const STAFF_EVENT_UPLOAD_PATH = '/api/v1/staff/event-uploads';
import { giftEventInputSchema, type GiftEventInput } from '../programs/gift-events.js';
import {
  StaffReportActionsService,
  staffReportActionSchema,
  type StaffReportActionInput,
} from './staff-report-actions.service.js';
import { teamAvatarPng } from '../live/staff-avatar.js';
import { Public } from '../auth/public.decorator.js';

/** Every staff route: per user, instead of the default (§7). */
const STAFF_LIMIT = {
  bucket: 'staff:user',
  rule: 'staffAppUser',
  key: byUserId,
  replacesDefault: true,
} as const;

const reason = z.string().trim().min(1).max(500);
const username = z
  .string()
  .trim()
  .min(1)
  .max(40)
  .transform((u) => u.replace(/^@/, ''));
const stepUpBody = z.strictObject({ code: z.string().regex(/^[0-9]{6}$/) });
const shiftBody = z.strictObject({ onShift: z.boolean() });
/** v1.72-live (D283, §10.96.11): «بثوثي» — the lives assigned to me (default) or every live in my regions. */
const livesScopeQuery = z.strictObject({ scope: z.enum(['assigned', 'regions']).optional() });
const kickBody = z.strictObject({ username, reason });
const muteBody = z.strictObject({ username, reason, muted: z.boolean().default(true) });

function meta(req: AppRequest) {
  return { ip: clientIp(req), requestId: getRequestId(req) };
}

/**
 * v1.68-live (D273, CONVENTIONS §10.96.6; owner: «بعض الموظفين ليس لديهم لابتوب»): «أدوات فريق كابسو» — the panel's live
 * moderation from the phone, for the staff's own app account (a normal user session, bearer). Each route names the
 * panel's capability and the guard checks role and capability on every request; the panel's rule functions run
 * unchanged and audit `via: app`. v1.76-live (D286): no step-up code any more (only the permanent device ban still
 * asks for the authenticator code, in its body), and staff work switches the shift on (§10.96.14).
 */
/**
 * v1.72-live (D283, §10.96.10): the Kabso Team's fixed picture (public, cached a day) — the `avatar_url` of every
 * limited staff account.
 */
@Public()
@Controller('staff')
export class StaffTeamAvatarController {
  @Get('team-avatar.png')
  avatar(@Res() res: Response): void {
    const png = teamAvatarPng();
    if (!png) throw new AppException(ErrorCode.NOT_FOUND);
    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Cache-Control', 'public, max-age=86400');
    res.send(png);
  }
}

/** v1.97-social (D303): the reason of an event's end / hold / release from the app. */
export const EVENT_REASON_BODY = z.strictObject({ reason: z.string().trim().min(3).max(500) });

@Controller('staff')
export class StaffAppController {
  constructor(
    private readonly staff: StaffAppService,
    private readonly moderation: AdminLiveModerationService,
    private readonly shifts: AdminStaffShiftsService,
    private readonly reportsQueue: AdminModerationService,
    private readonly reportActions: StaffReportActionsService,
    private readonly giftEvents: AdminGiftEventsService,
  ) {}

  // ---- status and step-up (no step-up needed) -------------------------------------------------

  @Get('me')
  @RateLimit(STAFF_LIMIT)
  me(@CurrentAuth() auth: AuthContext) {
    return this.staff.status(auth.userId, auth.sessionId);
  }

  /**
   * DEPRECATED v1.76-live (D286): the tools no longer need a step-up. Kept for the apps before D286 (they read
   * `StaffStatus.stepUp`, which is now always set for watch staff, so they never ask); still checks the code.
   */
  @Post('step-up')
  @HttpCode(200)
  @RateLimit(STAFF_LIMIT, { bucket: 'staff-step-up:user', rule: 'staffStepUpUser', key: byUserId })
  stepUp(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body(new ZodValidationPipe(stepUpBody)) body: z.infer<typeof stepUpBody>,
  ) {
    return this.staff.stepUp(auth.userId, auth.sessionId, body.code, meta(req));
  }

  @Delete('step-up')
  @HttpCode(204)
  @RateLimit(STAFF_LIMIT)
  async endStepUp(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<void> {
    await this.staff.endStepUp(auth.userId, auth.sessionId, meta(req));
  }

  // ---- the shift and «بثوثي» ------------------------------------------------------------------

  @Get('shift')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('lives.watch')
  @NotStaffWork()
  shift(@CurrentStaff() ctx: AdminContext) {
    return this.shifts.mine(ctx);
  }

  @Put('shift')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('lives.watch')
  @NotStaffWork()
  setShift(
    @CurrentStaff() ctx: AdminContext,
    @Body(new ZodValidationPipe(shiftBody)) body: z.infer<typeof shiftBody>,
  ) {
    return this.shifts.set(body.onShift, ctx);
  }

  @Get('lives')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('lives.watch')
  lives(
    @CurrentStaff() ctx: AdminContext,
    @Query(new ZodValidationPipe(livesScopeQuery)) q: z.infer<typeof livesScopeQuery>,
  ) {
    return this.staff.myLives(ctx, q.scope ?? 'assigned');
  }

  // ---- «بلاغات»: the shared report queue (v1.78-live, D288, §10.101) ---------------------------

  /** The panel's queue from the phone (OWNER, MODERATION, SUPPORT): OPEN or RESOLVED, with who resolved each. */
  @Get('reports')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('reports.view')
  sharedReports(@Query(new ZodValidationPipe(sharedReportsQuerySchema)) q: SharedReportsQuery) {
    return this.reportsQueue.list(q);
  }

  /** The «بلاغات» row's badge (not staff work: the Me tab reads it in the background). */
  @Get('reports/summary')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('reports.view')
  @NotStaffWork()
  sharedReportsSummary() {
    return this.reportsQueue.summary();
  }

  /** «تم حله» from the phone — the panel's rule (`via: app`); a second press → 409 `REPORT_ALREADY_RESOLVED`. */
  @Post('reports/:reportId/resolve')
  @HttpCode(200)
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('reports.resolve')
  resolveReport(
    @Param('reportId') id: string,
    @Body(new ZodValidationPipe(resolveReportSchema)) body: { note?: string | undefined },
    @CurrentStaff() ctx: AdminContext,
  ) {
    return this.reportsQueue.resolve(pathUuid(id), body.note, ctx);
  }

  /**
   * v1.93-social (D296, §10.109): one report opened from «بلاغات» — the reported content for the staff whatever its
   * visibility (a DM only as the report's snapshot; every DM read audited), and the actions the caller may take.
   */
  @Get('reports/:reportId')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('reports.view')
  report(@Param('reportId') id: string, @CurrentStaff() ctx: AdminContext) {
    return this.reportActions.view(pathUuid(id), ctx);
  }

  /**
   * D296 follow-up (owner: «عندما يضغط الموظف عليه تفتح الشات»): the conversation frozen with a DM report (or a person
   * reported from it), opened on a tap — every opening audited `moderation.report.dm_read`.
   */
  @Get('reports/:reportId/dm-thread')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('reports.view')
  reportDmThread(@Param('reportId') id: string, @CurrentStaff() ctx: AdminContext) {
    return this.reportActions.dmThread(pathUuid(id), ctx);
  }

  /**
   * D296: an action from the report (WARN, RESTRICT, SUSPEND, BAN, REMOVE_CONTENT) — each with its own panel capability,
   * checked in the service — which resolves the report automatically (owner); a closed report → 409.
   */
  @Post('reports/:reportId/actions')
  @HttpCode(200)
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('reports.view')
  actOnReport(
    @Param('reportId') id: string,
    @Body(new ZodValidationPipe(staffReportActionSchema)) body: StaffReportActionInput,
    @CurrentStaff() ctx: AdminContext,
  ) {
    return this.reportActions.act(pathUuid(id), body, ctx);
  }

  // ---- one live -------------------------------------------------------------------------------

  @Get('lives/:roomId/reports')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('lives.reports')
  reports(@Param('roomId') id: string) {
    return this.moderation.reports(pathUuid(id));
  }

  @Get('lives/:roomId/moderations')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('lives.reports')
  history(@Param('roomId') id: string) {
    return this.moderation.history(pathUuid(id));
  }

  @Post('lives/:roomId/moderate')
  @HttpCode(200)
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('lives.moderate')
  moderate(
    @Param('roomId') id: string,
    @Body(new ZodValidationPipe(moderateBody)) body: ModerateBody,
    @CurrentStaff() ctx: AdminContext,
  ) {
    return this.moderation.moderate(pathUuid(id), body, ctx);
  }

  @Post('lives/:roomId/reports/dismiss')
  @HttpCode(200)
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('lives.moderate')
  dismiss(
    @Param('roomId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentStaff() ctx: AdminContext,
  ) {
    return this.moderation.dismiss(pathUuid(id), body.reason, ctx);
  }

  @Post('lives/:roomId/kicks')
  @HttpCode(200)
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('lives.moderate')
  kick(
    @Param('roomId') id: string,
    @Body(new ZodValidationPipe(kickBody)) body: z.infer<typeof kickBody>,
    @CurrentStaff() ctx: AdminContext,
  ) {
    return this.staff.kick(pathUuid(id), body.username, body.reason, ctx);
  }

  @Put('lives/:roomId/chat-mutes')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('lives.moderate')
  mute(
    @Param('roomId') id: string,
    @Body(new ZodValidationPipe(muteBody)) body: z.infer<typeof muteBody>,
    @CurrentStaff() ctx: AdminContext,
  ) {
    return this.staff.muteInChat(pathUuid(id), body.username, body.muted, body.reason, ctx);
  }

  @Post('lives/:roomId/chat/:messageId/remove')
  @HttpCode(200)
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('lives.moderate')
  removeMessage(
    @Param('roomId') id: string,
    @Param('messageId') messageId: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentStaff() ctx: AdminContext,
  ) {
    return this.staff.removeMessage(pathUuid(id), pathUuid(messageId), body.reason, ctx);
  }

  // ---- «الفعاليات»: gift events from the phone (v1.97-social, D303, §10.114.7) ---------------------------------

  /** Every event with its state (newest first), for the staff tool's list. */
  @Get('events')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('events.manage')
  @NotStaffWork()
  events() {
    return this.giftEvents.list();
  }

  /** The gifts, bag items and VIP tiers an event may use, the board kinds and the limits. */
  @Get('event-options')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('events.manage')
  @NotStaffWork()
  eventOptions() {
    return this.giftEvents.options();
  }

  /** D303 follow-ups: one piece of an event's art from the phone — the panel's checks and specs. */
  @Post('event-uploads')
  @HttpCode(201)
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('events.manage')
  @NotStaffWork()
  uploadEventMedia(
    @Query(new ZodValidationPipe(eventUploadQuery)) q: { kind: EventMediaKind },
    @Req() req: AppRequest,
    @CurrentStaff() ctx: AdminContext,
  ) {
    return this.giftEvents.upload(q.kind, req.body, ctx);
  }

  @Post('event-badges')
  @HttpCode(201)
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('events.manage')
  @NotStaffWork()
  createEventBadge(
    @Body(new ZodValidationPipe(eventBadgeInputSchema)) body: EventBadgeInput,
    @CurrentStaff() ctx: AdminContext,
  ) {
    return this.giftEvents.createBadge(body, ctx);
  }

  /** Creates a gift event — the panel's rules, audited `via: app`. */
  @Post('gift-events')
  @HttpCode(201)
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('events.manage')
  @NotStaffWork()
  createGiftEvent(
    @Body(new ZodValidationPipe(giftEventInputSchema)) body: GiftEventInput,
    @CurrentStaff() ctx: AdminContext,
  ) {
    return this.giftEvents.create(body, ctx);
  }

  @Get('gift-events/:eventId')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('events.manage')
  @NotStaffWork()
  giftEvent(@Param('eventId') id: string) {
    return this.giftEvents.get(pathUuid(id));
  }

  @Put('gift-events/:eventId')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('events.manage')
  @NotStaffWork()
  updateGiftEvent(
    @Param('eventId') id: string,
    @Body(new ZodValidationPipe(giftEventInputSchema)) body: GiftEventInput,
    @CurrentStaff() ctx: AdminContext,
  ) {
    return this.giftEvents.update(pathUuid(id), body, ctx);
  }

  /** end / hold / release (the panel's `POST /admin/events/{id}/{command}`), with a reason. */
  @Post('events/:eventId/:command')
  @HttpCode(200)
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('events.manage')
  @NotStaffWork()
  changeEvent(
    @Param('eventId') id: string,
    @Param('command') command: string,
    @Body(new ZodValidationPipe(EVENT_REASON_BODY)) body: { reason: string },
    @CurrentStaff() ctx: AdminContext,
  ) {
    // v1.101-social (D325): publish / unpublish / discard a draft, the panel's rules.
    if (command === 'publish' || command === 'unpublish' || command === 'discard')
      return this.giftEvents.lifecycle(pathUuid(id), command, body.reason, ctx);
    if (command !== 'end' && command !== 'hold' && command !== 'release')
      throw new AppException(ErrorCode.NOT_FOUND);
    return this.giftEvents.change(pathUuid(id), command, body.reason, ctx);
  }
}
