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
import {
  defaultWhatsAppLevel,
  effectiveWhatsAppLevel,
  isPanelRole,
  PANEL_ROLES,
  whatsAppLevelRank,
  type PanelRole,
  type WhatsAppLevel,
} from './admin-permissions.js';
import { releaseAssignedIn, setWhatsAppLevelOf } from '../whatsapp/whatsapp-access.js';
import {
  setDepartmentsOf,
  sortDepartments,
  teamDepartmentsOf,
  type WaDepartment,
} from '../whatsapp/whatsapp-departments.js';
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

/** `setAdminTeamWhatsApp` (v1.120-social, D360): a level, or null to go back to the roles' default. */
export interface TeamWhatsAppBody {
  readonly level: WhatsAppLevel | null;
  readonly reason: string;
  readonly totpCode: string;
}

/** `setAdminTeamWhatsAppDepartments` (v1.122-social, D364): the departments, [] to go back to the default (GENERAL). */
export interface TeamWaDepartmentsBody {
  readonly departments: readonly WaDepartment[];
  readonly reason: string;
  readonly totpCode: string;
}

/** `AdminTeamWhatsApp` (D360, §10.155): the level that applies, the one set (null: none) and the roles' default. */
export function teamWhatsAppOf(roles: readonly string[], set: WhatsAppLevel | null) {
  const owner = roles.includes('OWNER');
  return {
    level: effectiveWhatsAppLevel(roles, set),
    setLevel: owner ? null : set,
    defaultLevel: owner ? ('MANAGE' as const) : defaultWhatsAppLevel(roles),
    /** An OWNER is always MANAGE (no level can be set). */
    locked: owner,
  };
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
    const [recruitCounts, waLevels, waDepartments] = await Promise.all([
      recruitCountsOf(
        this.prisma,
        rows.map((u) => u.id),
      ),
      this.prisma.waStaffAccess.findMany({
        where: { userId: { in: rows.map((u) => u.id) } },
        select: { userId: true, level: true },
      }),
      setDepartmentsOf(
        this.prisma,
        rows.map((u) => u.id),
      ),
    ]);
    const waSet = new Map(waLevels.map((w) => [w.userId, w.level]));
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
        // v1.120-social (D360, §10.155): the person's WhatsApp level «مستوى واتساب».
        whatsapp: teamWhatsAppOf(
          u.adminPermissions.map((p) => p.permission as string).filter(isPanelRole),
          waSet.get(u.id) ?? null,
        ),
        // v1.122-social (D364, §10.157.1): the person's WhatsApp departments «الأقسام» (GENERAL when none is set).
        whatsappDepartments: teamDepartmentsOf(waDepartments.get(u.id)),
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

  /**
   * v1.120-social (D360, CONVENTIONS §10.155) `setAdminTeamWhatsApp`: `team.manage` sets a staff member's WhatsApp level
   * (NONE / VIEW / REPLY / MANAGE), or null to go back to the roles' default — the code again and a reason, like the
   * other team changes. Refused for an account on no team role (`team_not_member`) and for an OWNER, who is always
   * MANAGE (`team_whatsapp_owner`). Lowering below REPLY releases every conversation still assigned to the person
   * (RELEASE in each one's history; §10.155.4). Audited `admin.team.whatsapp` {before, after, setBefore, setAfter,
   * released, reason}. Applies on the person's next request (every guard reads it).
   */
  async setWhatsApp(userId: string, body: TeamWhatsAppBody, ctx: AdminContext) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const now = new Date();
    return this.prisma.$transaction(async (tx) => {
      // The person's row locked (two changes apply one after the other; a claim or a transfer to them waits).
      await tx.$queryRaw`SELECT 1 FROM users WHERE id = ${userId}::uuid FOR NO KEY UPDATE`;
      const roles = (
        await tx.userAdminPermission.findMany({ where: { userId }, select: { permission: true } })
      )
        .map((p) => p.permission as string)
        .filter(isPanelRole);
      if (roles.length === 0) throw refused('The account is not on the team.', 'team_not_member', 'rule');
      if (roles.includes('OWNER')) {
        throw refused('An OWNER always has the MANAGE WhatsApp level.', 'team_whatsapp_owner', 'rule');
      }
      const setBefore = await setWhatsAppLevelOf(tx, userId);
      const before = effectiveWhatsAppLevel(roles, setBefore);
      if (body.level === null) {
        await tx.waStaffAccess.deleteMany({ where: { userId } });
      } else {
        await tx.waStaffAccess.upsert({
          where: { userId },
          create: { userId, level: body.level, setById: ctx.userId, createdAt: now, updatedAt: now },
          update: { level: body.level, setById: ctx.userId, updatedAt: now },
        });
      }
      const after = effectiveWhatsAppLevel(roles, body.level);
      const released =
        whatsAppLevelRank(after) < whatsAppLevelRank('REPLY')
          ? await releaseAssignedIn(tx, userId, ctx.userId, now)
          : [];
      await this.audit.recordIn(tx, {
        action: AuditAction.WHATSAPP_LEVEL,
        actorUserId: ctx.userId,
        targetType: 'user',
        targetId: userId,
        metadata: {
          before,
          after,
          setBefore,
          setAfter: body.level,
          released: released.length,
          conversations: released.slice(0, 100),
          reason: body.reason,
          via: ctx.via ?? 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
      return { userId, before, whatsapp: teamWhatsAppOf(roles, body.level), released: released.length };
    });
  }

  /**
   * v1.122-social (D364, CONVENTIONS §10.157.1) `setAdminTeamWhatsAppDepartments`: `team.manage` sets the departments a
   * staff member answers for (one or more of the five; [] = back to the default GENERAL) — the code again and a reason,
   * like the level. Refused for an account on no team role (`team_not_member`) and for someone below REPLY now
   * (`team_departments_level`: a viewer is never a transfer target). Under the lock of the person's `users` row (a
   * transfer to them waits). Conversations already assigned to them stay (a department only routes new transfers).
   * Audited `admin.team.whatsapp_departments` {before, after, setBefore, setAfter, reason, via}.
   */
  async setWaDepartments(userId: string, body: TeamWaDepartmentsBody, ctx: AdminContext) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const now = new Date();
    const wanted = sortDepartments(body.departments);
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT 1 FROM users WHERE id = ${userId}::uuid FOR NO KEY UPDATE`;
      const roles = (
        await tx.userAdminPermission.findMany({ where: { userId }, select: { permission: true } })
      )
        .map((p) => p.permission as string)
        .filter(isPanelRole);
      if (roles.length === 0) throw refused('The account is not on the team.', 'team_not_member', 'rule');
      const level = effectiveWhatsAppLevel(roles, await setWhatsAppLevelOf(tx, userId));
      if (whatsAppLevelRank(level) < whatsAppLevelRank('REPLY')) {
        throw refused(
          'Departments are for staff at the REPLY WhatsApp level or above.',
          'team_departments_level',
          'rule',
        );
      }
      const setBefore = (await setDepartmentsOf(tx, [userId])).get(userId) ?? [];
      await tx.waStaffDepartment.deleteMany({ where: { userId } });
      if (wanted.length > 0) {
        await tx.waStaffDepartment.createMany({
          data: wanted.map((department) => ({ userId, department, setById: ctx.userId, createdAt: now })),
        });
      }
      const before = teamDepartmentsOf(setBefore);
      const after = teamDepartmentsOf(wanted);
      await this.audit.recordIn(tx, {
        action: AuditAction.WHATSAPP_DEPARTMENTS,
        actorUserId: ctx.userId,
        targetType: 'user',
        targetId: userId,
        metadata: {
          before: before.departments,
          after: after.departments,
          setBefore,
          setAfter: wanted,
          reason: body.reason,
          via: ctx.via ?? 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
      return { userId, before: before.departments, whatsappDepartments: after };
    });
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
      this.prisma.$transaction(async (tx) => {
        const setBefore = await setWhatsAppLevelOf(tx, userId);
        const held = (
          await tx.userAdminPermission.findMany({ where: { userId }, select: { permission: true } })
        )
          .map((p) => p.permission as string)
          .filter(isPanelRole);
        const out = await revokeRoleIn(tx, userId, body.role, viaOf(ctx), { reason: body.reason });
        // v1.120-social (D360, §10.155.4): a revoke can lower the WhatsApp level too (e.g. SUPPORT gone → NONE): the
        // person's assigned conversations go back to the queue, as when the level is lowered; off the team
        // entirely, the level set for them goes (a later grant starts from the roles' default).
        const before = effectiveWhatsAppLevel(held, setBefore);
        const after = effectiveWhatsAppLevel(out.left, out.left.length === 0 ? null : setBefore);
        const now = new Date();
        const released =
          whatsAppLevelRank(after) < whatsAppLevelRank('REPLY')
            ? await releaseAssignedIn(tx, userId, ctx.userId, now)
            : [];
        const dropped = out.left.length === 0 && setBefore !== null;
        if (dropped) await tx.waStaffAccess.deleteMany({ where: { userId } });
        // v1.122-social (D364): off the team, the departments go too (a later grant starts from GENERAL).
        const departmentsDropped =
          out.left.length === 0 ? (await tx.waStaffDepartment.deleteMany({ where: { userId } })).count : 0;
        if (released.length > 0 || dropped || departmentsDropped > 0) {
          await this.audit.recordIn(tx, {
            action: AuditAction.WHATSAPP_LEVEL,
            actorUserId: ctx.userId,
            targetType: 'user',
            targetId: userId,
            metadata: {
              before,
              after,
              setBefore,
              setAfter: dropped ? null : setBefore,
              released: released.length,
              conversations: released.slice(0, 100),
              reason: body.reason,
              cause: 'role_revoked',
              departmentsDropped,
              via: ctx.via ?? 'panel',
            },
            ip: ctx.ip,
            requestId: ctx.requestId,
          });
        }
        return out;
      }),
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
