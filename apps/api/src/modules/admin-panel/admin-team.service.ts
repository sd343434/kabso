import { Inject, Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { normalizeUsername } from '../users/username.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import { PANEL_ROLES, type PanelRole } from './admin-permissions.js';
import { AdminRoleError, grantRoleIn, resetSecondFactorIn, revokeRoleIn } from './admin-roles.js';
import { AUDIT_ROW, auditRowDto } from './admin-people.service.js';
import { dayBound, tableResult, window, type TableQuery } from './admin-tables.js';
import { refused, viaOf } from './admin-users.service.js';

export interface AuditQuery extends TableQuery {
  readonly actor?: string | undefined;
  readonly action?: string | undefined;
  readonly targetType?: string | undefined;
  readonly targetId?: string | undefined;
  readonly from?: string | undefined;
  readonly to?: string | undefined;
}

async function rule<T>(step: () => Promise<T>): Promise<T> {
  try {
    return await step();
  } catch (err) {
    if (err instanceof AdminRoleError) throw refused(err.message);
    throw err;
  }
}

/**
 * «السجل والفريق» in the panel v2 (v1.65-social, D197, CONVENTIONS §10.60.6), OWNER only: the audit-log viewer
 * (filters: actor, action, target, dates; each row's before/after) with its CSV, and the team — the panel admins,
 * granting and revoking a role and resetting an authenticator with the `admin-admin` rules themselves
 * (admin-roles.ts, through `kabso_admin_panel_role`), each with the authenticator code again and a reason. The CLI
 * stays (the first OWNER is still bootstrapped there).
 */
@Injectable()
export class AdminTeamService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly auth: AdminAuthService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

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
      },
    });
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
      })),
    };
  }

  async grant(body: { email: string; role: PanelRole; reason: string; totpCode: string }, ctx: AdminContext) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const r = await rule(() =>
      this.prisma.$transaction((tx) =>
        grantRoleIn(tx, body.email, body.role, viaOf(ctx), { reason: body.reason }),
      ),
    );
    return { userId: r.userId, role: body.role, madeAdmin: r.madeAdmin, already: r.already };
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
    return { userId: r.userId, left: r.left };
  }

  async resetTotp(userId: string, body: { reason: string; totpCode: string }, ctx: AdminContext) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    if (
      !(await this.prisma.userAdminPermission.count({
        where: { userId, permission: { in: [...PANEL_ROLES] } },
      }))
    ) {
      throw refused('The account is not on the team.');
    }
    await rule(() =>
      this.prisma.$transaction((tx) => resetSecondFactorIn(tx, userId, viaOf(ctx), { reason: body.reason })),
    );
    return { reset: true };
  }
}
