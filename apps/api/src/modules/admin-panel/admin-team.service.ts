import { Inject, Injectable, Logger } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { LiveStaffAssignmentService } from '../live/live-staff-assignment.service.js';
import { normalizeUsername } from '../users/username.js';
import { formatStaffId } from '../users/staff-ids.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import { PANEL_ROLES, type PanelRole } from './admin-permissions.js';
import { AdminRoleError, grantRoleIn, resetSecondFactorIn, revokeRoleIn } from './admin-roles.js';
import { AUDIT_ROW, auditRowDto } from './admin-people.service.js';
import { dayBound, tableResult, window, type TableQuery } from './admin-tables.js';
import { refused, viaOf } from './admin-users.service.js';
import { LiveMediaService } from '../live/live-media.service.js';
import { isStaffRegion, sortRegions, staffRegionCatalog } from '../live/staff-regions.js';
import { REGION_STAFF_ROLES } from '../live/live-staff.js';
import type { TeamRegionsBody } from './admin-v2.schemas.js';
import { syncTeamAvatarsIn, teamAvatarUrl } from '../live/staff-avatar.js';
import { emptyRecruitCounts, recruitCountsOf } from '../recruits/recruit-core.js';

export interface AuditQuery extends TableQuery {
  readonly actor?: string | undefined;
  readonly action?: string | undefined;
  readonly targetType?: string | undefined;
  readonly targetId?: string | undefined;
  readonly from?: string | undefined;
  readonly to?: string | undefined;
}

/** `grantAdminTeamRole` (D271: `account` = email or username; D197's `email` still accepted). */
export interface TeamGrantBody {
  readonly account?: string | undefined;
  readonly email?: string | undefined;
  readonly role: PanelRole;
  readonly reason: string;
  readonly totpCode: string;
}

async function rule<T>(step: () => Promise<T>): Promise<T> {
  try {
    return await step();
  } catch (err) {
    if (err instanceof AdminRoleError) throw refused(err.message, err.issue, 'rule');
    throw err;
  }
}

/**
 * «السجل والفريق» in the panel v2 (v1.65-social, D197, CONVENTIONS §10.60.6), OWNER only: the audit-log viewer
 * (filters: actor, action, target, dates; each row's before/after) with its CSV, and the team — the panel admins,
 * granting and revoking a role and resetting an authenticator with the `admin-admin` rules themselves
 * (admin-roles.ts, through `kabso_admin_panel_role`), each with the authenticator code again and a reason. The CLI
 * stays (the first OWNER is still bootstrapped there).
 *
 * v1.66-live (D271, CONVENTIONS §10.96.5) «الموظفون والصلاحيات»: the list also shows each one's shift «في المناوبة»;
 * a grant finds the account by email or username and answers who it is (the panel's next steps for the new staff
 * member); a revoke that ends a shift hands that person's lives on at once. The code is checked before any rule.
 */
@Injectable()
export class AdminTeamService {
  private readonly logger = new Logger(AdminTeamService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly auth: AdminAuthService,
    private readonly assignments: LiveStaffAssignmentService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly media: LiveMediaService,
  ) {}

  /**
   * v1.72-live (D283, §10.96.10): at the start, every limited staff account wears the team picture at this API's
   * URL (a CLI grant, a changed `API_PUBLIC_URL`) and everyone else has their own photo. Best effort.
   */
  async onModuleInit(): Promise<void> {
    try {
      await syncTeamAvatarsIn(
        this.prisma,
        null,
        teamAvatarUrl({ API_PUBLIC_URL: this.config.kyc.publicApiBaseUrl }),
      );
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not sync the Kabso Team pictures');
    }
  }

  /** Every audit action the code writes (the viewer's filter list). */
  actions(): { data: string[] } {
    return { data: [...new Set(Object.values(AuditAction) as string[])].sort() };
  }

  async auditTable(q: AuditQuery, ctx: AdminContext) {
    const zone = this.config.adminPanel.dashboardTimeZone;
    let actorUserId: string | undefined;
    if (q.actor) {
      const raw = q.actor.trim();
      if (/^[0-9a-f-]{36}$/i.test(raw)) actorUserId = raw.toLowerCase();
      else {
        const p = await this.prisma.userProfile.findUnique({
          where: { username: normalizeUsername(raw).replace(/^@/, '') },
          select: { userId: true },
        });
        // An unknown actor matches nothing (not everything).
        actorUserId = p?.userId ?? '00000000-0000-0000-0000-000000000000';
      }
    }
    const gte = dayBound(q.from, false, zone);
    const lt = dayBound(q.to, true, zone);
    const where: Prisma.AuditLogWhereInput = {
      ...(actorUserId ? { actorUserId } : {}),
      ...(q.action ? { action: { startsWith: q.action } } : {}),
      ...(q.targetType ? { targetType: q.targetType } : {}),
      ...(q.targetId ? { targetId: q.targetId.trim() } : {}),
      ...(gte || lt ? { createdAt: { ...(gte ? { gte } : {}), ...(lt ? { lt } : {}) } } : {}),
    };
    const [rows, total] = await Promise.all([
      this.prisma.auditLog.findMany({
        where,
        orderBy: [{ createdAt: q.order }, { id: q.order }],
        ...window(q),
        select: AUDIT_ROW,
      }),
      this.prisma.auditLog.count({ where }),
    ]);
    const data = rows.map(auditRowDto);
    return tableResult(
      this.audit,
      ctx,
      'audit',
      q,
      data,
      total,
      [
        ['id', (r) => r.id],
        ['created_at', (r) => r.createdAt],
        ['action', (r) => r.action],
        ['actor', (r) => r.actor?.username ?? ''],
        ['target_type', (r) => r.targetType],
        ['target_id', (r) => r.targetId],
        ['ip', (r) => r.ip],
        ['metadata', (r) => JSON.stringify(r.metadata)],
      ],
      {
        actor: q.actor ?? null,
        action: q.action ?? null,
        targetType: q.targetType ?? null,
        targetId: q.targetId ?? null,
        from: q.from ?? null,
        to: q.to ?? null,
      },
    );
  }

  // ---- team ---------------------------------------------------------------------------------------------------

  async team(now = new Date()) {
    const rows = await this.prisma.user.findMany({
      where: { adminPermissions: { some: { permission: { in: [...PANEL_ROLES] } } } },
      orderBy: { createdAt: 'asc' },
      select: {
        id: true,
        email: true,
        status: true,
        role: true,
        profile: { select: { username: true, displayName: true, avatarUrl: true } },
        adminPermissions: { select: { permission: true, grantedAt: true } },
        adminCredential: { select: { totpEnrolledAt: true, lockedUntil: true } },
        adminSessions: {
          where: { stage: 'ACTIVE' },
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: { createdAt: true },
        },
        adminShift: { select: { onShift: true, since: true } },
        staffRegions: { select: { region: true } },
        staffNumber: { select: { number: true } },
      },
    });
    const recruitCounts = await recruitCountsOf(
      this.prisma,
      rows.map((u) => u.id),
    );
    return {
      data: rows.map((u) => ({
        id: u.id,
        email: u.email,
        username: u.profile?.username ?? '',
        displayName: u.profile?.displayName ?? '',
        avatarUrl: u.profile?.avatarUrl ?? null,
        status: u.status,
        roles: u.adminPermissions
          .map((p) => p.permission as string)
          .filter((p): p is PanelRole => (PANEL_ROLES as readonly string[]).includes(p)),
        totpEnrolled: (u.adminCredential?.totpEnrolledAt ?? null) !== null,
        lockedUntil:
          u.adminCredential?.lockedUntil && u.adminCredential.lockedUntil > now
            ? u.adminCredential.lockedUntil.toISOString()
            : null,
        lastSignInAt: u.adminSessions[0]?.createdAt.toISOString() ?? null,
        onShift: u.adminShift?.onShift ?? false,
        shiftSince: u.adminShift?.onShift ? u.adminShift.since.toISOString() : null,
        // v1.72-live (D283, §10.96.11): the regions of a MODERATION / SUPPORT staff member (catalogue order).
        regions: sortRegions(u.staffRegions.map((r) => r.region).filter(isStaffRegion)),
        // v1.73-live (D283c, §10.96.12): the official staff ID «Kabso01» (given with the first panel role).
        staffId: u.staffNumber ? formatStaffId(u.staffNumber.number) : null,
        // v1.75-live (D285, §10.96.13): how many recruits the person has, by type.
        recruits: recruitCounts.get(u.id) ?? emptyRecruitCounts(),
      })),
    };
  }

  /** v1.72-live (D283, §10.96.11): the regions and their countries (`AdminStaffRegionCatalog`). */
  regionCatalog() {
    return staffRegionCatalog();
  }

  /**
   * v1.72-live (D283, §10.96.11) `setAdminTeamRegions`: the OWNER sets the whole set of regions a MODERATION / SUPPORT
   * staff member is responsible for (the OWNER's code again and a reason, like the other team changes). Refused for
   * anyone holding neither (`team_regions_role`). Audited `admin.team.regions` {before, regions, reason}. The next
   * assignment pass uses them (a live already assigned stays where it is).
   */
  async setRegions(userId: string, body: TeamRegionsBody, ctx: AdminContext) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const regions = sortRegions(body.regions);
    const before = await this.prisma.$transaction(async (tx) => {
      // The person's row locked so two OWNERs' changes apply one after the other.
      await tx.$queryRaw`SELECT 1 FROM users WHERE id = ${userId}::uuid FOR NO KEY UPDATE`;
      const holds = await tx.userAdminPermission.count({
        where: { userId, permission: { in: [...REGION_STAFF_ROLES] } },
      });
      if (holds === 0) {
        throw refused('Regions are for MODERATION, SUPPORT and BD staff.', 'team_regions_role', 'rule');
      }
      const old = await tx.adminStaffRegion.findMany({ where: { userId }, select: { region: true } });
      await tx.adminStaffRegion.deleteMany({ where: { userId } });
      if (regions.length > 0) {
        await tx.adminStaffRegion.createMany({ data: regions.map((region) => ({ userId, region })) });
      }
      const prior = sortRegions(old.map((r) => r.region).filter(isStaffRegion));
      await this.audit.recordIn(tx, {
        action: AuditAction.ADMIN_TEAM_REGIONS,
        actorUserId: ctx.userId,
        targetType: 'user',
        targetId: userId,
        metadata: { before: prior, regions, reason: body.reason, via: ctx.via ?? 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
      return prior;
    });
    return { userId, regions, before };
  }

  async grant(body: TeamGrantBody, ctx: AdminContext) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const who = body.account ?? body.email ?? '';
    const r = await rule(() =>
      this.prisma.$transaction((tx) => grantRoleIn(tx, who, body.role, viaOf(ctx), { reason: body.reason })),
    );
    const u = await this.prisma.user.findUniqueOrThrow({
      where: { id: r.userId },
      select: {
        email: true,
        profile: { select: { username: true, displayName: true } },
        adminCredential: { select: { totpEnrolledAt: true } },
      },
    });
    return {
      userId: r.userId,
      role: body.role,
      madeAdmin: r.madeAdmin,
      already: r.already,
      // v1.73-live (D283c, §10.96.12): the staff ID the person shows (kept from an earlier grant if any).
      staffId: r.staffId,
      account: {
        email: u.email,
        username: u.profile?.username ?? '',
        displayName: u.profile?.displayName ?? '',
        totpEnrolled: (u.adminCredential?.totpEnrolledAt ?? null) !== null,
      },
    };
  }

  async revoke(
    userId: string,
    body: { role: PanelRole; reason: string; totpCode: string },
    ctx: AdminContext,
  ) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const r = await rule(() =>
      this.prisma.$transaction((tx) =>
        revokeRoleIn(tx, userId, body.role, viaOf(ctx), { reason: body.reason }),
      ),
    );
    if (r.watchLost) {
      // v1.68-live (D273): no watch role left — no longer «فريق كابسو» in any live (best effort; the
      // reconciliation repeats it for the visible watches).
      await this.media.dropStaffPresence(r.userId).catch((err: unknown) => {
        this.logger.warn(
          { error: safeErrorLog(err) },
          'Could not end the live presence of a revoked staff member',
        );
      });
    }
    if (r.shiftEnded) {
      // Their lives go to the others on shift now, not at the next sweep (best effort: the sweep retries).
      await this.assignments.assignPending('shift_off').catch((err: unknown) => {
        this.logger.warn(
          { error: safeErrorLog(err) },
          'Could not hand on the lives of a revoked staff member',
        );
      });
    }
    return { userId: r.userId, left: r.left, shiftEnded: r.shiftEnded };
  }

  async resetTotp(userId: string, body: { reason: string; totpCode: string }, ctx: AdminContext) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    if (
      !(await this.prisma.userAdminPermission.count({
        where: { userId, permission: { in: [...PANEL_ROLES] } },
      }))
    ) {
      throw refused('The account is not on the team.', 'team_not_member', 'rule');
    }
    await rule(() =>
      this.prisma.$transaction((tx) => resetSecondFactorIn(tx, userId, viaOf(ctx), { reason: body.reason })),
    );
    return { reset: true };
  }
}
