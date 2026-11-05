import { Body, Controller, Get, HttpCode, Module, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { AuthContext } from '../../common/http/request-context.js';
import { byIp, byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { Clock } from '../../common/time/clock.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { AdminAuthService, type AdminContext } from '../admin-panel/admin-auth.service.js';
import { PANEL_ROLES } from '../admin-panel/admin-permissions.js';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import { pathUuid } from '../admin-panel/admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import { refused, viaOf } from '../admin-panel/admin-users.service.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { Public } from '../auth/public.decorator.js';
import {
  approveCreatorApplicationIn,
  CreatorApplicationError,
  CreatorApplicationsService,
  rejectCreatorApplicationIn,
} from '../creator/creator-applications.js';
import { EconomyModule } from '../economy/economy.module.js';
import { formatStaffId } from '../users/staff-ids.js';
import {
  RecruitError,
  emptyRecruitCounts,
  reassignRecruitIn,
  recruitCountsOf,
  recruitSettingsDto,
  recruitSettingsIn,
  updateRecruitSettingsIn,
} from './recruit-core.js';
import { MAX_RECRUIT_BPS, RECRUIT_TYPES, unitsToUsd, type RecruitType } from './recruit-math.js';
import { RecruitCommissionSweeper, RecruitsService } from './recruits.service.js';

/**
 * v1.75-live (D285, CONVENTIONS §10.96.13): recruitment by staff in the app — the forms' live check of the recruiter
 * field (any signed-in user; per-user default limit) and the recruiter's own «استقطاباتي» / «أرباحي» in the staff
 * Me tab (MODERATION / BD only).
 */
@Controller()
export class RecruitsController {
  constructor(private readonly recruits: RecruitsService) {}

  @Get('staff-recruiters/lookup')
  lookup(@Query() query: unknown) {
    return this.recruits.lookup(query);
  }

  @Get('me/staff/recruits')
  mine(@CurrentAuth() auth: AuthContext, @Query() query: unknown) {
    return this.recruits.myRecruits(auth.userId, query);
  }

  @Get('me/staff/earnings')
  earnings(@CurrentAuth() auth: AuthContext) {
    return this.recruits.myEarnings(auth.userId);
  }
}

/** «انضم كصانع محتوى» (v1.75-live, D285): the caller's creator programme application. */
@Controller('me/creator-application')
export class CreatorApplicationController {
  constructor(private readonly applications: CreatorApplicationsService) {}

  @Get()
  mine(@CurrentAuth() auth: AuthContext) {
    return this.applications.mine(auth.userId);
  }

  @Post()
  @HttpCode(201)
  @RateLimit({ bucket: 'creator:apply', rule: 'hostApplyUser', key: byUserId })
  apply(@CurrentAuth() auth: AuthContext, @Body() body: unknown) {
    return this.applications.apply(auth.userId, body);
  }

  @Post('cancel')
  @HttpCode(200)
  cancel(@CurrentAuth() auth: AuthContext) {
    return this.applications.cancel(auth.userId);
  }
}

const PANEL_LIMIT = RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true });
const reason = z.string().trim().min(1).max(500);
const totpCode = z.string().regex(/^[0-9]{6}$/);
const listQuery = z.strictObject({
  recruiter: z.uuid().optional(),
  type: z.enum(RECRUIT_TYPES).optional(),
});
const reassignBody = z.strictObject({ recruiter: z.string().trim().min(1).max(64), reason, totpCode });
const bps = z.number().int().min(0).max(MAX_RECRUIT_BPS);
const settingsBody = z
  .strictObject({
    host: bps.optional(),
    agency: bps.optional(),
    rechargeAgent: bps.optional(),
    creator: bps.optional(),
    reason,
    totpCode,
  })
  .refine((v) => [v.host, v.agency, v.rechargeAgent, v.creator].some((x) => x !== undefined), {
    message: 'at least one share',
  });
const statusQuery = z.strictObject({ status: z.enum(['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED']).optional() });

/**
 * The panel (v1.75-live, D285): «استقطاباتي» (`recruits.mine`: MODERATION, BD — the caller's own recruits only), the
 * OWNER's «الاستقطاب» (`recruits.view` / `recruits.manage`: every staff member's recruits, each recruit's profit and
 * the commissions paid, the reassignment and the shares — the code again and a reason), and «طلبات صناع المحتوى»
 * (`creators.applications` / `creators.decide`: OWNER, SUPPORT).
 */
@Public()
@Controller('admin')
@PANEL_LIMIT
@UseGuards(AdminSessionGuard)
export class AdminRecruitsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly recruits: RecruitsService,
    private readonly creators: CreatorApplicationsService,
    private readonly auth: AdminAuthService,
    private readonly clock: Clock,
  ) {}

  @Get('recruits/mine')
  @RequireCapability('recruits.mine')
  async mine(@CurrentAdmin() admin: AdminContext) {
    const data = await this.recruits.recruits(admin.userId, undefined);
    const counts = { ...emptyRecruitCounts() };
    for (const r of data) {
      counts[r.type] += 1;
      counts.total += 1;
    }
    const [sum] = await this.prisma.$queryRaw<{ cherries: bigint }[]>`
      SELECT COALESCE(sum(cherries), 0)::bigint AS cherries FROM staff_recruit_commissions
       WHERE recruiter_user_id = ${admin.userId}::uuid`;
    return {
      counts,
      commissionCherries: Number(sum?.cherries ?? 0n),
      bps: recruitSettingsDto(await recruitSettingsIn(this.prisma)).bps,
      data: data.map(({ recruiter: _r, reassignedAt: _at, ...r }) => r),
    };
  }

  @Get('recruits/mine/:recruitmentId/commissions')
  @RequireCapability('recruits.mine')
  async mineCommissions(@Param('recruitmentId') id: string, @CurrentAdmin() admin: AdminContext) {
    const row = await this.prisma.staffRecruitment.findUnique({ where: { id: pathUuid(id) } });
    // Staff see only their own recruits.
    if (!row || row.recruiterUserId !== admin.userId) throw new AppException(ErrorCode.NOT_FOUND);
    const all = await this.recruits.commissionsOf(row.id);
    return { data: all.filter((c) => c.recruiter.id === admin.userId) };
  }

  @Get('recruits')
  @RequireCapability('recruits.view')
  async list(@Query(new ZodValidationPipe(listQuery)) q: z.infer<typeof listQuery>) {
    return { data: await this.recruits.recruits(q.recruiter ?? null, q.type) };
  }

  /** Per staff member: the recruits by type, the profit they generated and the commissions paid. */
  @Get('recruits/staff')
  @RequireCapability('recruits.view')
  async staff() {
    const people = await this.prisma.user.findMany({
      where: {
        OR: [
          { adminPermissions: { some: { permission: { in: [...PANEL_ROLES] } } } },
          { recruitsMade: { some: {} } },
        ],
      },
      orderBy: { createdAt: 'asc' },
      select: {
        id: true,
        status: true,
        profile: { select: { username: true, displayName: true, avatarUrl: true } },
        staffNumber: { select: { number: true } },
        adminPermissions: { select: { permission: true } },
      },
    });
    const ids = people.map((p) => p.id);
    const counts = await recruitCountsOf(this.prisma, ids);
    const sums = ids.length
      ? await this.prisma.$queryRaw<{ id: string; cherries: bigint; profit: unknown }[]>`
          SELECT r.recruiter_user_id::text AS id,
                 COALESCE((SELECT sum(c.cherries) FROM staff_recruit_commissions c
                            WHERE c.recruiter_user_id = r.recruiter_user_id), 0)::bigint AS cherries,
                 COALESCE(sum((SELECT sum(c2.profit_units) FROM staff_recruit_commissions c2
                                WHERE c2.recruitment_id = r.id)), 0) AS profit
            FROM staff_recruitments r
           WHERE r.recruiter_user_id = ANY(${ids}::uuid[])
           GROUP BY r.recruiter_user_id`
      : [];
    const sumBy = new Map(sums.map((s) => [s.id, s]));
    const e = this.recruits.economy();
    return {
      data: people.map((p) => {
        const s = sumBy.get(p.id);
        const roles = p.adminPermissions.map((x) => x.permission as string);
        return {
          userId: p.id,
          username: p.profile?.username ?? '',
          displayName: p.profile?.displayName ?? '',
          avatarUrl: p.profile?.avatarUrl ?? null,
          staffId: p.staffNumber ? formatStaffId(p.staffNumber.number) : null,
          status: p.status,
          roles: roles.filter((r) => (PANEL_ROLES as readonly string[]).includes(r)),
          canRecruit: p.status === 'ACTIVE' && (roles.includes('MODERATION') || roles.includes('BD')),
          recruits: counts.get(p.id) ?? emptyRecruitCounts(),
          commissionCherries: Number(s?.cherries ?? 0n),
          profitUsd: unitsToUsd(BigInt(String(s?.profit ?? '0')), e),
        };
      }),
    };
  }

  @Get('recruits/settings')
  @RequireCapability('recruits.view')
  async settings() {
    return recruitSettingsDto(await recruitSettingsIn(this.prisma));
  }

  @Put('recruits/settings')
  @RequireCapability('recruits.manage')
  async updateSettings(
    @Body(new ZodValidationPipe(settingsBody)) body: z.infer<typeof settingsBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    await this.auth.reauthenticate(admin, body.totpCode);
    const patch: Partial<Record<RecruitType, number>> = {
      ...(body.host !== undefined ? { HOST: body.host } : {}),
      ...(body.agency !== undefined ? { AGENCY: body.agency } : {}),
      ...(body.rechargeAgent !== undefined ? { RECHARGE_AGENT: body.rechargeAgent } : {}),
      ...(body.creator !== undefined ? { CREATOR: body.creator } : {}),
    };
    const row = await this.prisma.$transaction((tx) =>
      updateRecruitSettingsIn(tx, patch, body.reason, viaOf(admin), this.clock.now()),
    );
    return recruitSettingsDto(row);
  }

  @Get('recruits/:recruitmentId/commissions')
  @RequireCapability('recruits.view')
  async commissions(@Param('recruitmentId') id: string) {
    return { data: await this.recruits.commissionsOf(pathUuid(id)) };
  }

  @Post('recruits/:recruitmentId/reassign')
  @HttpCode(200)
  @RequireCapability('recruits.manage')
  async reassign(
    @Param('recruitmentId') id: string,
    @Body(new ZodValidationPipe(reassignBody)) body: z.infer<typeof reassignBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    await this.auth.reauthenticate(admin, body.totpCode);
    const recruitmentId = pathUuid(id);
    try {
      await this.prisma.$transaction((tx) =>
        reassignRecruitIn(tx, recruitmentId, body.recruiter, body.reason, viaOf(admin), this.clock.now()),
      );
    } catch (err) {
      if (err instanceof RecruitError) {
        if (err.issue === 'recruit_not_found') throw new AppException(ErrorCode.NOT_FOUND);
        throw refused(err.message, err.issue, 'recruiter');
      }
      throw err;
    }
    const [row] = (await this.recruits.recruits(null, undefined)).filter((r) => r.id === recruitmentId);
    return row;
  }

  @Get('creator-applications')
  @RequireCapability('creators.applications')
  creatorApplications(@Query(new ZodValidationPipe(statusQuery)) q: z.infer<typeof statusQuery>) {
    return this.creators.panelList(q.status);
  }

  @Post('creator-applications/:applicationId/approve')
  @HttpCode(200)
  @RequireCapability('creators.decide')
  async approveCreator(@Param('applicationId') id: string, @CurrentAdmin() admin: AdminContext) {
    try {
      const out = await this.prisma.$transaction((tx) =>
        approveCreatorApplicationIn(tx, pathUuid(id), this.clock.now(), viaOf(admin)),
      );
      return { status: 'APPROVED' as const, recruitmentId: out.recruitmentId };
    } catch (err) {
      if (err instanceof CreatorApplicationError) throw refused(err.message);
      throw err;
    }
  }

  @Post('creator-applications/:applicationId/reject')
  @HttpCode(200)
  @RequireCapability('creators.decide')
  async rejectCreator(
    @Param('applicationId') id: string,
    @Body(new ZodValidationPipe(z.strictObject({ reason }))) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    try {
      await this.prisma.$transaction((tx) =>
        rejectCreatorApplicationIn(tx, pathUuid(id), body.reason, this.clock.now(), viaOf(admin)),
      );
      return { status: 'REJECTED' as const };
    } catch (err) {
      if (err instanceof CreatorApplicationError) throw refused(err.message);
      throw err;
    }
  }
}

/** v1.75-live (D285): recruitment by staff and the creator programme. */
@Module({
  imports: [AdminPanelModule, EconomyModule],
  controllers: [RecruitsController, CreatorApplicationController, AdminRecruitsController],
  providers: [RecruitsService, RecruitCommissionSweeper, CreatorApplicationsService],
  exports: [RecruitsService],
})
export class RecruitsModule {}
