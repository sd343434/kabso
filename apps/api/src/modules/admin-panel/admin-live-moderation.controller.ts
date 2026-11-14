import { Body, Controller, Get, HttpCode, Param, Post, Put, Query, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { Public } from '../auth/public.decorator.js';
import type { AdminContext } from './admin-auth.service.js';
import { AdminLiveModerationService, type ModerateBody } from './admin-live-moderation.service.js';
import { pathUuid } from './admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from './admin-session.guard.js';
import { AdminStaffShiftsService } from './admin-staff-shifts.service.js';
import { sendTable, tableQuery, type TableQuery } from './admin-tables.js';

/** Every cookie-authenticated panel route: per-IP limit instead of the public default (§10.54.2). */
const PANEL_LIMIT = RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true });

const reason = z.string().trim().min(1).max(500);

/**
 * v1.64-live (D260): `visibility` — a WATCH is VISIBLE by default (listed with the «فريق كابسو» badge); HIDDEN needs
 * `lives.watch.hidden`. A PREVIEW (the cards' muted previews) is always hidden.
 */
const watchBody = z.strictObject({
  purpose: z.enum(['PREVIEW', 'WATCH']).default('WATCH'),
  visibility: z.enum(['VISIBLE', 'HIDDEN']).optional(),
});

/**
 * The quick durations are 1 h, 24 h, 3 d, 7 d, 30 d («مخصّص» sends `until`); any whole number of hours up to a year is
 * accepted. A device ban may be `permanent` and needs the authenticator code again.
 */
export const moderateBody = z
  .strictObject({
    // v1.68-live (D273): WARN — the host is told the reason; the live goes on.
    action: z.enum(['END', 'WARN', 'NO_LIVE', 'SUSPEND', 'DEVICE_BAN']),
    reason,
    hours: z
      .number()
      .int()
      .min(1)
      .max(365 * 24)
      .optional(),
    until: z.iso.datetime({ offset: true }).optional(),
    permanent: z.boolean().optional(),
    totpCode: z
      .string()
      .regex(/^[0-9]{6}$/)
      .optional(),
  })
  .superRefine((b, ctx) => {
    const timed = b.hours !== undefined || b.until !== undefined;
    if (b.hours !== undefined && b.until !== undefined)
      ctx.addIssue({ code: 'custom', path: ['until'], message: 'until', params: { issue: 'invalid_value' } });
    if ((b.action === 'END' || b.action === 'WARN') && (timed || b.permanent !== undefined))
      ctx.addIssue({ code: 'custom', path: ['hours'], message: 'hours', params: { issue: 'invalid_value' } });
    if ((b.action === 'NO_LIVE' || b.action === 'SUSPEND') && !timed)
      ctx.addIssue({ code: 'custom', path: ['hours'], message: 'hours', params: { issue: 'required' } });
    if ((b.action === 'NO_LIVE' || b.action === 'SUSPEND') && b.permanent !== undefined)
      ctx.addIssue({
        code: 'custom',
        path: ['permanent'],
        message: 'permanent',
        params: { issue: 'invalid_value' },
      });
    if (b.action === 'DEVICE_BAN') {
      if (b.permanent === true && timed)
        ctx.addIssue({
          code: 'custom',
          path: ['permanent'],
          message: 'permanent',
          params: { issue: 'invalid_value' },
        });
      if (b.permanent !== true && !timed)
        ctx.addIssue({ code: 'custom', path: ['hours'], message: 'hours', params: { issue: 'required' } });
      if (b.totpCode === undefined)
        ctx.addIssue({
          code: 'custom',
          path: ['totpCode'],
          message: 'totpCode',
          params: { issue: 'required' },
        });
    } else if (b.totpCode !== undefined) {
      ctx.addIssue({
        code: 'custom',
        path: ['totpCode'],
        message: 'totpCode',
        params: { issue: 'invalid_value' },
      });
    }
  });

export const reasonBody = z.strictObject({ reason });

/** v1.64-live (D260): the shift switch «في المناوبة». */
const shiftBody = z.strictObject({ onShift: z.boolean() });

const chatQuery = z.strictObject({ after: z.iso.datetime({ offset: true }).optional() });

const deviceBansQuery = tableQuery(['createdAt'], 'createdAt')
  .extend({ status: z.enum(['ACTIVE', 'LIFTED', 'EXPIRED']).optional() })
  .strict();

/**
 * v1.60-live (D250, CONVENTIONS §10.91): «مراقبة البث» — watch a live as a hidden observer, the reported lives and a
 * live's reports and chat, the team's actions on a live with a reason (end, a ban from going live, a suspension, a
 * device ban; dismiss the reports), and the device-ban list. Cookie session + CSRF on every write; one capability each.
 */
@Public()
@Controller('admin')
@PANEL_LIMIT
@UseGuards(AdminSessionGuard)
export class AdminLiveModerationController {
  constructor(
    private readonly moderation: AdminLiveModerationService,
    private readonly shifts: AdminStaffShiftsService,
  ) {}

  // ---- v1.64-live (D260, §10.96): the shift «في المناوبة» -------------------------------------------------------

  @Get('me/shift')
  @RequireCapability('lives.watch')
  myShift(@CurrentAdmin() admin: AdminContext) {
    return this.shifts.mine(admin);
  }

  @Put('me/shift')
  @RequireCapability('lives.watch')
  setMyShift(
    @Body(new ZodValidationPipe(shiftBody)) body: z.infer<typeof shiftBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.shifts.set(body.onShift, admin);
  }

  @Get('shifts')
  @RequireCapability('staff.shifts')
  allShifts() {
    return this.shifts.list();
  }

  @Get('live-reports/summary')
  @RequireCapability('lives.reports')
  summary() {
    return this.moderation.summary();
  }

  @Post('lives/:roomId/watch-token')
  @HttpCode(200)
  @RequireCapability('lives.watch')
  async watchToken(
    @Param('roomId') id: string,
    @Body(new ZodValidationPipe(watchBody)) body: z.infer<typeof watchBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    const out = await this.moderation.watchToken(pathUuid(id), body.purpose, admin, body.visibility);
    // v1.76-live (D286, §10.96.14): watching a live (not the cards' muted previews) is staff work.
    if (body.purpose === 'WATCH') await this.shifts.work(admin, 'live_join');
    return out;
  }

  @Get('lives/:roomId/chat')
  @RequireCapability('lives.watch')
  chat(@Param('roomId') id: string, @Query(new ZodValidationPipe(chatQuery)) q: z.infer<typeof chatQuery>) {
    return this.moderation.chat(pathUuid(id), q.after);
  }

  @Get('lives/:roomId/reports')
  @RequireCapability('lives.reports')
  async reports(@Param('roomId') id: string, @CurrentAdmin() admin: AdminContext) {
    const out = await this.moderation.reports(pathUuid(id));
    await this.shifts.work(admin, 'staff_tool');
    return out;
  }

  @Get('lives/:roomId/moderations')
  @RequireCapability('lives.reports')
  history(@Param('roomId') id: string) {
    return this.moderation.history(pathUuid(id));
  }

  @Post('lives/:roomId/moderate')
  @HttpCode(200)
  @RequireCapability('lives.moderate')
  async moderate(
    @Param('roomId') id: string,
    @Body(new ZodValidationPipe(moderateBody)) body: ModerateBody,
    @CurrentAdmin() admin: AdminContext,
  ) {
    await this.shifts.work(admin, 'staff_tool');
    return this.moderation.moderate(pathUuid(id), body, admin);
  }

  @Post('lives/:roomId/reports/dismiss')
  @HttpCode(200)
  @RequireCapability('lives.moderate')
  async dismiss(
    @Param('roomId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    await this.shifts.work(admin, 'staff_tool');
    return this.moderation.dismiss(pathUuid(id), body.reason, admin);
  }

  @Get('device-bans')
  @RequireCapability('devices.ban')
  async deviceBans(
    @Query(new ZodValidationPipe(deviceBansQuery))
    q: TableQuery & { status?: 'ACTIVE' | 'LIFTED' | 'EXPIRED' },
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.moderation.deviceBans(q, admin));
  }

  @Post('device-bans/:banId/lift')
  @HttpCode(200)
  @RequireCapability('devices.ban')
  lift(
    @Param('banId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.moderation.liftDeviceBan(pathUuid(id), body.reason, admin);
  }
}
