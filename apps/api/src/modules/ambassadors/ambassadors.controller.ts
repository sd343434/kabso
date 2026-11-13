import { Body, Controller, Get, HttpCode, Module, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction } from '../../common/audit/audit.service.js';
import { auditBy } from '../../common/audit/admin-actor.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { AuthContext } from '../../common/http/request-context.js';
import { byIp, byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { Clock } from '../../common/time/clock.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import type { Ambassador } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { AdminAuthService, type AdminContext } from '../admin-panel/admin-auth.service.js';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import { pathUuid } from '../admin-panel/admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import { refused, viaOf } from '../admin-panel/admin-users.service.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { Public } from '../auth/public.decorator.js';
import { uuidv7 } from '../levels/uuidv7.js';
import {
  AmbassadorAdminError,
  ambassadorSettingsIn,
  appointAmbassadorIn,
  approveAmbassadorApplicationIn,
  clearAmbassadorReviewIn,
  rejectAmbassadorApplicationIn,
  setAmbassadorFrozenIn,
  updateAmbassadorSettingsIn,
  type AmbassadorSettingsPatch,
} from './ambassador-core.js';
import { ambassadorLevelSchema, ambassadorMonth, levelsProblem } from './ambassador-rules.js';
import { AmbassadorSweeper, AmbassadorsService, applicationDto, settingsDto } from './ambassadors.service.js';

/** «برنامج سفراء Kabso» (v1.140-social, D390, §10.179): the app's programme page, application and dashboard. */
@Controller('ambassadors')
export class AmbassadorsController {
  constructor(private readonly ambassadors: AmbassadorsService) {}

  @Get('programme')
  programme(@CurrentAuth() auth: AuthContext) {
    return this.ambassadors.programme(auth.userId);
  }

  @Post('applications')
  @HttpCode(201)
  @RateLimit({ bucket: 'ambassador:apply', rule: 'hostApplyUser', key: byUserId })
  apply(@CurrentAuth() auth: AuthContext, @Body() body: unknown) {
    return this.ambassadors.apply(auth.userId, body);
  }

  @Get('me')
  dashboard(@CurrentAuth() auth: AuthContext) {
    return this.ambassadors.dashboard(auth.userId);
  }
}

const PANEL_LIMIT = RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true });
const reason = z.string().trim().min(1).max(500);
const totpCode = z.string().regex(/^[0-9]{6}$/);
const country = z.string().regex(/^[A-Z]{2}$/);
const listQuery = z.strictObject({
  status: z.enum(['ACTIVE', 'FROZEN', 'REVIEW']).optional(),
  q: z.string().trim().max(64).optional(),
});
const applicationsQuery = z.strictObject({
  status: z.enum(['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED']).optional(),
});
const appointBody = z.strictObject({
  username: z.string().trim().min(1).max(64),
  reason,
  country: country.optional(),
});
const reasonBody = z.strictObject({ reason });
const codeBody = z.strictObject({ reason, totpCode });
const count = z.number().int().min(0);
const settingsBody = z.strictObject({
  enabled: z.boolean().optional(),
  attributionWindowDays: z.number().int().min(1).max(3650).optional(),
  holdDays: z.number().int().min(0).max(365).optional(),
  minActiveDays: z.number().int().min(0).max(365).optional(),
  minActiveTopupCoins: count.max(Number.MAX_SAFE_INTEGER).optional(),
  monthlyCapCherries: count.max(Number.MAX_SAFE_INTEGER).optional(),
  velocityMaxPerDay: count.max(100_000).optional(),
  ipClusterMax: count.max(100_000).optional(),
  ipClusterWindowDays: z.number().int().min(1).max(365).optional(),
  levels: z.array(ambassadorLevelSchema).min(1).max(10).optional(),
  reason,
  totpCode,
});
const campaignBody = z
  .strictObject({
    title: z.string().trim().min(1).max(120),
    country: country.nullable().optional(),
    startsOn: z.iso.date(),
    endsOn: z.iso.date(),
    notes: z.string().trim().max(2000).optional(),
    ambassadors: z.array(z.uuid()).max(200).optional(),
  })
  .refine((v) => v.endsOn >= v.startsOn, { message: 'endsOn before startsOn', path: ['endsOn'] });

type AmbassadorRow = Ambassador & {
  username: string;
  display_name: string;
  avatar_url: string | null;
};

function adminError(err: unknown): never {
  if (err instanceof AmbassadorAdminError) {
    if (err.issue === 'not_found') throw new AppException(ErrorCode.NOT_FOUND);
    throw refused(err.message, err.issue, 'ambassador');
  }
  throw err;
}

/**
 * The panel «السفراء» (v1.140-social, D390, §10.179.8): `ambassadors.view` (the list, an ambassador's performance, the
 * applications, the campaigns), `ambassadors.manage` (decide applications, appoint, campaigns) and the OWNER's
 * `ambassadors.settings` (the settings with the code again, freeze / unfreeze, clear a review, every money total —
 * null for anyone else).
 */
@Public()
@Controller('admin')
@PANEL_LIMIT
@UseGuards(AdminSessionGuard)
export class AdminAmbassadorsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ambassadors: AmbassadorsService,
    private readonly auth: AdminAuthService,
    private readonly clock: Clock,
  ) {}

  private money(admin: AdminContext): boolean {
    return admin.capabilities.includes('ambassadors.settings');
  }

  private async rows(where: { userId?: string; status?: string; q?: string }): Promise<AmbassadorRow[]> {
    const q = where.q ? `%${where.q.replace(/^@/, '').toLowerCase()}%` : null;
    const rows = await this.prisma.$queryRaw<{ user_id: string }[]>`
      SELECT a.user_id::text AS user_id FROM ambassadors a JOIN user_profiles p ON p.user_id = a.user_id
       WHERE (${where.userId ?? null}::uuid IS NULL OR a.user_id = ${where.userId ?? null}::uuid)
         AND (${where.status ?? null}::text IS NULL
              OR (${where.status ?? null}::text = 'REVIEW' AND a.under_review)
              OR a.status::text = ${where.status ?? null}::text)
         AND (${q}::text IS NULL OR p.username LIKE ${q}::text OR lower(p.display_name) LIKE ${q}::text)
       ORDER BY a.activated_at DESC LIMIT 200`;
    const ids = rows.map((r) => r.user_id);
    const [ambs, profiles] = await Promise.all([
      this.prisma.ambassador.findMany({ where: { userId: { in: ids } } }),
      this.prisma.userProfile.findMany({
        where: { userId: { in: ids } },
        select: { userId: true, username: true, displayName: true, avatarUrl: true },
      }),
    ]);
    const byId = new Map(ambs.map((a) => [a.userId, a]));
    const prof = new Map(profiles.map((p) => [p.userId, p]));
    return ids.map((id) => ({
      ...byId.get(id)!,
      username: prof.get(id)?.username ?? '',
      display_name: prof.get(id)?.displayName ?? '',
      avatar_url: prof.get(id)?.avatarUrl ?? null,
    }));
  }

  private async rowDto(a: AmbassadorRow, money: boolean) {
    const month = ambassadorMonth(this.clock.now(), this.ambassadors.zone);
    const [counts, stats, sums] = await Promise.all([
      this.ambassadors.referralCounts(a.userId),
      this.ambassadors.monthStats(a.userId, month),
      this.ambassadors.commissionSums(a.userId, a),
    ]);
    return {
      user: { id: a.userId, username: a.username, displayName: a.display_name, avatarUrl: a.avatar_url },
      status: a.status,
      level: a.level,
      source: a.source as 'APPLICATION' | 'APPOINTED',
      country: a.country,
      activatedAt: a.activatedAt.toISOString(),
      underReview: a.underReview,
      reviewReason: a.reviewReason,
      frozenReason: a.frozenReason,
      referrals: counts,
      month: { month, activeReferrals: stats.activeReferrals, topupCoins: Number(stats.topupCoins) },
      // D387 rule: revenue and payouts are the OWNER's.
      commissions: money
        ? {
            pendingCherries: Number(sums.pending),
            heldCherries: Number(sums.held),
            paidCherries: Number(sums.paid),
            reversedCherries: Number(sums.reversed),
          }
        : null,
    };
  }

  @Get('ambassadors')
  @RequireCapability('ambassadors.view')
  async list(
    @Query(new ZodValidationPipe(listQuery)) q: z.infer<typeof listQuery>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    const rows = await this.rows({ status: q.status, q: q.q });
    const money = this.money(admin);
    return { data: await Promise.all(rows.map((r) => this.rowDto(r, money))) };
  }

  @Get('ambassadors/:userId')
  @RequireCapability('ambassadors.view')
  async detail(@Param('userId') id: string, @CurrentAdmin() admin: AdminContext) {
    const userId = pathUuid(id);
    const [row] = await this.rows({ userId });
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    const money = this.money(admin);
    const [flags, months, referrals, commissions, campaigns] = await Promise.all([
      this.prisma.ambassadorFlag.findMany({
        where: { ambassadorUserId: userId },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      this.prisma.ambassadorMonth.findMany({
        where: { ambassadorUserId: userId },
        orderBy: { month: 'desc' },
        take: 12,
      }),
      this.prisma.ambassadorReferral.findMany({
        where: { ambassadorUserId: userId },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      this.prisma.ambassadorCommission.findMany({
        where: { ambassadorUserId: userId },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: 50,
      }),
      this.prisma.ambassadorCampaign.findMany({
        where: { members: { some: { userId } } },
        orderBy: { startsOn: 'desc' },
        take: 20,
      }),
    ]);
    const invitees = await this.prisma.userProfile.findMany({
      where: { userId: { in: referrals.map((r) => r.inviteeUserId) } },
      select: { userId: true, username: true, displayName: true },
    });
    const inv = new Map(invitees.map((p) => [p.userId, p]));
    await this.prisma.auditLog.create({
      data: {
        ...auditBy(viaOf(admin)),
        action: AuditAction.AMBASSADOR_VIEW,
        targetType: 'ambassador',
        targetId: userId,
        metadata: { via: 'panel', money },
      },
    });
    return {
      ...(await this.rowDto(row, money)),
      flags: flags.map((f) => ({
        id: f.id,
        kind: f.kind as 'VELOCITY' | 'IP_CLUSTER' | 'SELF_PAYMENT',
        createdAt: f.createdAt.toISOString(),
        clearedAt: f.clearedAt?.toISOString() ?? null,
      })),
      months: months.map((m) => ({
        month: m.month,
        activeReferrals: m.activeReferrals,
        topupCoins: Number(m.topupCoins),
        commissionCherries: money ? Number(m.commissionCherries) : null,
        levelBefore: m.levelBefore,
        levelAfter: m.levelAfter,
        metLevel: m.metLevel,
        rewardStatus: m.rewardStatus as 'NONE' | 'GRANTED' | 'HELD',
      })),
      referralList: referrals.map((r) => ({
        invitee: {
          id: r.inviteeUserId,
          username: inv.get(r.inviteeUserId)?.username ?? '',
          displayName: inv.get(r.inviteeUserId)?.displayName ?? '',
        },
        status: r.status,
        voidReason: r.voidReason,
        createdAt: r.createdAt.toISOString(),
        activeAt: r.activeAt?.toISOString() ?? null,
      })),
      commissionList: commissions.map((c) => ({
        id: c.id,
        createdAt: c.createdAt.toISOString(),
        recharge: c.rechargeReason,
        coins: Number(c.coins),
        level: c.level,
        rateBps: c.rateBps,
        cherries: money ? Number(c.cherries) : null,
        status: c.status,
        voidReason: c.voidReason,
        holdUntil: c.holdUntil.toISOString(),
      })),
      campaigns: campaigns.map((c) => ({ id: c.id, title: c.title })),
    };
  }

  @Post('ambassadors')
  @HttpCode(201)
  @RequireCapability('ambassadors.manage')
  async appoint(
    @Body(new ZodValidationPipe(appointBody)) body: z.infer<typeof appointBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    const profile = await this.prisma.userProfile.findUnique({
      where: { username: body.username.replace(/^@/, '').toLowerCase() },
      select: { userId: true },
    });
    if (!profile) throw refused('No account with that username.', 'user_not_found', 'ambassador');
    try {
      await this.prisma.$transaction((tx) =>
        appointAmbassadorIn(
          tx,
          profile.userId,
          { reason: body.reason, country: body.country ?? null },
          this.clock.now(),
          viaOf(admin),
        ),
      );
    } catch (err) {
      adminError(err);
    }
    const [row] = await this.rows({ userId: profile.userId });
    return this.rowDto(row!, this.money(admin));
  }

  @Post('ambassadors/:userId/freeze')
  @HttpCode(200)
  @RequireCapability('ambassadors.settings')
  async freeze(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: z.infer<typeof reasonBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.setFrozen(pathUuid(id), true, body.reason, admin);
  }

  @Post('ambassadors/:userId/unfreeze')
  @HttpCode(200)
  @RequireCapability('ambassadors.settings')
  async unfreeze(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(codeBody)) body: z.infer<typeof codeBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    await this.auth.reauthenticate(admin, body.totpCode);
    return this.setFrozen(pathUuid(id), false, body.reason, admin);
  }

  private async setFrozen(userId: string, frozen: boolean, why: string, admin: AdminContext) {
    let changed = false;
    try {
      changed = await this.prisma.$transaction((tx) =>
        setAmbassadorFrozenIn(tx, userId, frozen, why, this.clock.now(), viaOf(admin)),
      );
    } catch (err) {
      adminError(err);
    }
    const [row] = await this.rows({ userId });
    return { changed, ambassador: await this.rowDto(row!, true) };
  }

  @Post('ambassadors/:userId/clear-review')
  @HttpCode(200)
  @RequireCapability('ambassadors.settings')
  async clearReview(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(codeBody)) body: z.infer<typeof codeBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    await this.auth.reauthenticate(admin, body.totpCode);
    const userId = pathUuid(id);
    let changed = false;
    try {
      changed = await this.prisma.$transaction((tx) =>
        clearAmbassadorReviewIn(tx, userId, body.reason, this.clock.now(), viaOf(admin)),
      );
    } catch (err) {
      adminError(err);
    }
    const [row] = await this.rows({ userId });
    return { changed, ambassador: await this.rowDto(row!, true) };
  }

  @Get('ambassador-applications')
  @RequireCapability('ambassadors.view')
  async applications(@Query(new ZodValidationPipe(applicationsQuery)) q: z.infer<typeof applicationsQuery>) {
    const apps = await this.prisma.ambassadorApplication.findMany({
      where: q.status ? { status: q.status } : {},
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: 200,
    });
    const users = await this.prisma.userProfile.findMany({
      where: { userId: { in: [...new Set(apps.map((a) => a.userId))] } },
      select: { userId: true, username: true, displayName: true, avatarUrl: true },
    });
    const byId = new Map(users.map((u) => [u.userId, u]));
    const creators = new Set(
      (
        await this.prisma.creatorMember.findMany({
          where: { userId: { in: apps.map((a) => a.userId) } },
          select: { userId: true },
        })
      ).map((c) => c.userId),
    );
    return {
      data: apps.map((a) => ({
        ...applicationDto(a),
        user: {
          id: a.userId,
          username: byId.get(a.userId)?.username ?? '',
          displayName: byId.get(a.userId)?.displayName ?? '',
          avatarUrl: byId.get(a.userId)?.avatarUrl ?? null,
        },
        // A creator may also be an ambassador (§10.179.2): the panel shows it.
        creator: creators.has(a.userId),
      })),
    };
  }

  @Post('ambassador-applications/:applicationId/approve')
  @HttpCode(200)
  @RequireCapability('ambassadors.manage')
  async approve(@Param('applicationId') id: string, @CurrentAdmin() admin: AdminContext) {
    try {
      const userId = await this.prisma.$transaction((tx) =>
        approveAmbassadorApplicationIn(tx, pathUuid(id), this.clock.now(), viaOf(admin)),
      );
      return { status: 'APPROVED' as const, userId };
    } catch (err) {
      adminError(err);
    }
  }

  @Post('ambassador-applications/:applicationId/reject')
  @HttpCode(200)
  @RequireCapability('ambassadors.manage')
  async reject(
    @Param('applicationId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: z.infer<typeof reasonBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    try {
      const userId = await this.prisma.$transaction((tx) =>
        rejectAmbassadorApplicationIn(tx, pathUuid(id), body.reason, this.clock.now(), viaOf(admin)),
      );
      return { status: 'REJECTED' as const, userId };
    } catch (err) {
      adminError(err);
    }
  }

  @Get('ambassador-settings')
  @RequireCapability('ambassadors.settings')
  async settings() {
    return settingsDto(await ambassadorSettingsIn(this.prisma));
  }

  @Put('ambassador-settings')
  @RequireCapability('ambassadors.settings')
  async updateSettings(
    @Body(new ZodValidationPipe(settingsBody)) body: z.infer<typeof settingsBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    await this.auth.reauthenticate(admin, body.totpCode);
    const { reason: why, totpCode: _code, minActiveTopupCoins, monthlyCapCherries, ...rest } = body;
    if (rest.levels) {
      const problem = levelsProblem(rest.levels);
      if (problem) throw AppException.validation([{ field: 'levels', issue: 'invalid_value' }]);
    }
    const patch: AmbassadorSettingsPatch = {
      ...rest,
      ...(minActiveTopupCoins !== undefined ? { minActiveTopupCoins: BigInt(minActiveTopupCoins) } : {}),
      ...(monthlyCapCherries !== undefined ? { monthlyCapCherries: BigInt(monthlyCapCherries) } : {}),
    };
    const after = await this.prisma.$transaction((tx) =>
      updateAmbassadorSettingsIn(tx, patch, why, this.clock.now(), viaOf(admin)),
    );
    return settingsDto(after);
  }

  // ---- campaigns and events --------------------------------------------------------------------------------------

  private async campaignDto(id: string) {
    const c = await this.prisma.ambassadorCampaign.findUniqueOrThrow({
      where: { id },
      include: { members: true },
    });
    const people = await this.prisma.userProfile.findMany({
      where: { userId: { in: c.members.map((m) => m.userId) } },
      select: { userId: true, username: true, displayName: true },
    });
    return {
      id: c.id,
      title: c.title,
      country: c.country,
      startsOn: c.startsOn.toISOString().slice(0, 10),
      endsOn: c.endsOn.toISOString().slice(0, 10),
      notes: c.notes,
      ambassadors: people
        .map((p) => ({ id: p.userId, username: p.username, displayName: p.displayName }))
        .sort((a, b) => a.username.localeCompare(b.username)),
      createdAt: c.createdAt.toISOString(),
      updatedAt: c.updatedAt.toISOString(),
    };
  }

  @Get('ambassador-campaigns')
  @RequireCapability('ambassadors.view')
  async campaigns() {
    const rows = await this.prisma.ambassadorCampaign.findMany({
      orderBy: [{ startsOn: 'desc' }, { id: 'desc' }],
      take: 200,
      select: { id: true },
    });
    return { data: await Promise.all(rows.map((r) => this.campaignDto(r.id))) };
  }

  private async checkMembers(ids: readonly string[]): Promise<void> {
    if (ids.length === 0) return;
    const n = await this.prisma.ambassador.count({ where: { userId: { in: [...new Set(ids)] } } });
    if (n !== new Set(ids).size)
      throw AppException.validation([{ field: 'ambassadors', issue: 'invalid_value' }]);
  }

  @Post('ambassador-campaigns')
  @HttpCode(201)
  @RequireCapability('ambassadors.manage')
  async createCampaign(
    @Body(new ZodValidationPipe(campaignBody)) body: z.infer<typeof campaignBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    await this.checkMembers(body.ambassadors ?? []);
    const now = this.clock.now();
    const id = uuidv7(now.getTime());
    const by = viaOf(admin);
    await this.prisma.$transaction(async (tx) => {
      await tx.ambassadorCampaign.create({
        data: {
          id,
          title: body.title,
          country: body.country ?? null,
          startsOn: new Date(`${body.startsOn}T00:00:00.000Z`),
          endsOn: new Date(`${body.endsOn}T00:00:00.000Z`),
          notes: body.notes ?? '',
          createdById: admin.userId,
          createdAt: now,
          updatedAt: now,
          members: { create: [...new Set(body.ambassadors ?? [])].map((userId) => ({ userId })) },
        },
      });
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.AMBASSADOR_CAMPAIGN_CREATE,
          targetType: 'ambassador_campaign',
          targetId: id,
          metadata: { via: by.via, title: body.title, ambassadors: (body.ambassadors ?? []).length },
        },
      });
    });
    return this.campaignDto(id);
  }

  @Put('ambassador-campaigns/:campaignId')
  @RequireCapability('ambassadors.manage')
  async updateCampaign(
    @Param('campaignId') raw: string,
    @Body(new ZodValidationPipe(campaignBody)) body: z.infer<typeof campaignBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    const id = pathUuid(raw);
    if ((await this.prisma.ambassadorCampaign.count({ where: { id } })) === 0) {
      throw new AppException(ErrorCode.NOT_FOUND);
    }
    await this.checkMembers(body.ambassadors ?? []);
    const by = viaOf(admin);
    await this.prisma.$transaction(async (tx) => {
      await tx.ambassadorCampaign.update({
        where: { id },
        data: {
          title: body.title,
          country: body.country ?? null,
          startsOn: new Date(`${body.startsOn}T00:00:00.000Z`),
          endsOn: new Date(`${body.endsOn}T00:00:00.000Z`),
          notes: body.notes ?? '',
          updatedAt: this.clock.now(),
        },
      });
      await tx.ambassadorCampaignMember.deleteMany({ where: { campaignId: id } });
      await tx.ambassadorCampaignMember.createMany({
        data: [...new Set(body.ambassadors ?? [])].map((userId) => ({ campaignId: id, userId })),
      });
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.AMBASSADOR_CAMPAIGN_UPDATE,
          targetType: 'ambassador_campaign',
          targetId: id,
          metadata: { via: by.via, title: body.title, ambassadors: (body.ambassadors ?? []).length },
        },
      });
    });
    return this.campaignDto(id);
  }
}

/** v1.140-social (D390): «برنامج سفراء Kabso». The recharge and referral hooks are in `ambassador-core.ts`. */
@Module({
  imports: [AdminPanelModule],
  controllers: [AmbassadorsController, AdminAmbassadorsController],
  providers: [AmbassadorsService, AmbassadorSweeper],
  exports: [AmbassadorSweeper],
})
export class AmbassadorsModule {}
