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
import { AdminStaffShiftsService } from './admin-staff-shifts.service.js';
import { CurrentStaff, StaffAppGuard, StaffCapability } from './staff-app.guard.js';
import { StaffAppService } from './staff-app.service.js';
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
 * moderation from the phone, for the staff's own app account. The app session is a normal user session (bearer), so
 * every tool also needs the step-up: the panel authenticator code (`POST /staff/step-up`), bound to this app session.
 * Each route names the panel's capability and the guard checks role, capability and step-up on every request; the
 * panel's rule functions run unchanged and audit `via: app`.
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

@Controller('staff')
export class StaffAppController {
  constructor(
    private readonly staff: StaffAppService,
    private readonly moderation: AdminLiveModerationService,
    private readonly shifts: AdminStaffShiftsService,
  ) {}

  // ---- status and step-up (no step-up needed) -------------------------------------------------

  @Get('me')
  @RateLimit(STAFF_LIMIT)
  me(@CurrentAuth() auth: AuthContext) {
    return this.staff.status(auth.userId, auth.sessionId);
  }

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
  shift(@CurrentStaff() ctx: AdminContext) {
    return this.shifts.mine(ctx);
  }

  @Put('shift')
  @RateLimit(STAFF_LIMIT)
  @UseGuards(StaffAppGuard)
  @StaffCapability('lives.watch')
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
}
