import { Body, Controller, Get, HttpCode, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { Public } from '../auth/public.decorator.js';
import type { AdminContext } from './admin-auth.service.js';
import { pathUuid } from './admin-panel.schemas.js';
import { AdminRoleHomesService } from './admin-role-homes.service.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from './admin-session.guard.js';
import {
  COMPENSATION_KINDS,
  COMPENSATION_STATUSES,
  StaffCompensationsService,
} from './staff-compensations.service.js';
import { StaffScheduleService } from './staff-schedule.service.js';

const reason = z.string().trim().min(1).max(500);
const totp = z.string().regex(/^[0-9]{6}$/);

export const scheduleSlotBody = z.strictObject({
  userId: z.uuid(),
  weekday: z.number().int().min(1).max(7),
  startMinute: z.number().int().min(0).max(1439),
  endMinute: z.number().int().min(1).max(1440),
  reason,
});
export const reasonBody = z.strictObject({ reason });

export const compensationSettingsBody = z.strictObject({
  dailyLimitCoins: z.number().int().min(0).max(1_000_000_000),
  perGrantMaxCoins: z.number().int().min(0).max(1_000_000_000),
  reason,
  totpCode: totp,
});
export const compensationBody = z.strictObject({
  user: z.string().trim().min(1).max(254),
  kind: z.enum(COMPENSATION_KINDS),
  coins: z.number().int().min(1).max(1_000_000_000).optional(),
  days: z.number().int().min(1).max(365).optional(),
  tierCode: z.string().trim().min(1).max(40).optional(),
  itemCode: z.string().trim().min(1).max(40).optional(),
  reason: z.string().trim().min(3).max(500),
  totpCode: totp,
});
export const approveBody = z.strictObject({ note: z.string().trim().max(500).optional(), totpCode: totp });
export const compensationsQuery = z.strictObject({
  status: z.enum(COMPENSATION_STATUSES).optional(),
  page: z.coerce.number().int().min(1).max(100_000).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(25),
});

/**
 * v1.139-social (D387, CONVENTIONS §10.176): the operations roles' panel routes — the role homes, the 24/7 shift
 * schedule and the VIP_CARE compensations. Same cookie session, CSRF header, rate limit and per-request capability check
 * as every panel route (§10.54).
 */
@Public()
@Controller('admin')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminOpsController {
  constructor(
    private readonly homes: AdminRoleHomesService,
    private readonly schedule: StaffScheduleService,
    private readonly compensations: StaffCompensationsService,
  ) {}

  // ---- the role homes (§10.176.3) ------------------------------------------------------------------------------

  @Get('role-homes/live-ops')
  @RequireCapability('home.live_ops')
  liveOpsHome() {
    return this.homes.liveOps();
  }

  @Get('role-homes/talent')
  @RequireCapability('home.talent')
  talentHome() {
    return this.homes.talent();
  }

  @Get('role-homes/trust-safety')
  @RequireCapability('home.trust_safety')
  trustSafetyHome() {
    return this.homes.trustSafety();
  }

  @Get('role-homes/vip-care')
  @RequireCapability('home.vip_care')
  vipCareHome(@CurrentAdmin() admin: AdminContext) {
    return this.homes.vipCare(admin);
  }

  @Get('role-homes/community')
  @RequireCapability('home.community')
  communityHome() {
    return this.homes.community();
  }

  // ---- the shift schedule (§10.176.6) ------------------------------------------------------------------------------

  @Get('staff-schedule')
  @RequireCapability('staff.schedule.view')
  getSchedule(@CurrentAdmin() admin: AdminContext) {
    return this.schedule.schedule(admin);
  }

  @Post('staff-schedule')
  @HttpCode(201)
  @RequireCapability('staff.schedule.manage')
  createSlot(
    @Body(new ZodValidationPipe(scheduleSlotBody)) body: z.infer<typeof scheduleSlotBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.schedule.create(body, admin);
  }

  @Put('staff-schedule/:slotId')
  @RequireCapability('staff.schedule.manage')
  updateSlot(
    @Param('slotId') slotId: string,
    @Body(new ZodValidationPipe(scheduleSlotBody)) body: z.infer<typeof scheduleSlotBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.schedule.update(pathUuid(slotId), body, admin);
  }

  @Post('staff-schedule/:slotId/remove')
  @HttpCode(200)
  @RequireCapability('staff.schedule.manage')
  removeSlot(
    @Param('slotId') slotId: string,
    @Body(new ZodValidationPipe(reasonBody)) body: z.infer<typeof reasonBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.schedule.remove(pathUuid(slotId), body.reason, admin);
  }

  // ---- compensations (§10.176.4) ---------------------------------------------------------------------------------

  @Get('compensations/settings')
  @RequireCapability('compensation.grant')
  compensationSettings(@CurrentAdmin() admin: AdminContext) {
    return this.compensations.settings(admin);
  }

  @Put('compensations/settings')
  @RequireCapability('compensation.settings')
  updateCompensationSettings(
    @Body(new ZodValidationPipe(compensationSettingsBody)) body: z.infer<typeof compensationSettingsBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.compensations.updateSettings(body, admin);
  }

  @Get('compensations')
  @RequireCapability('compensation.grant')
  listCompensations(
    @Query(new ZodValidationPipe(compensationsQuery)) q: z.output<typeof compensationsQuery>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.compensations.list(q, admin);
  }

  @Post('compensations')
  @HttpCode(201)
  @RequireCapability('compensation.grant')
  createCompensation(
    @Body(new ZodValidationPipe(compensationBody)) body: z.infer<typeof compensationBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.compensations.create(body, admin);
  }

  @Post('compensations/:compensationId/approve')
  @HttpCode(200)
  @RequireCapability('compensation.approve')
  approveCompensation(
    @Param('compensationId') id: string,
    @Body(new ZodValidationPipe(approveBody)) body: z.infer<typeof approveBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.compensations.approve(pathUuid(id), body, admin);
  }

  @Post('compensations/:compensationId/reject')
  @HttpCode(200)
  @RequireCapability('compensation.approve')
  rejectCompensation(
    @Param('compensationId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: z.infer<typeof reasonBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.compensations.reject(pathUuid(id), body.reason, admin);
  }
}
