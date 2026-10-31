import { Inject, Injectable, Logger } from '@nestjs/common';
import type { AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { taskCherryLockIn } from '../economy/cherry-ledger.js';
import { isUuid } from '../live/live.schemas.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import { removeAvatarByAdminIn } from '../users/avatar-admin.js';
import { AccountLifecycleService } from '../users/profiles/account-lifecycle.service.js';
import {
  endSpecialIn,
  grantSpecialIn,
  resolveUserIdByUsername,
  SpecialUsernameError,
} from '../users/special-usernames.js';
import { normalizeEmail, normalizeUsername } from '../users/username.js';
import type { AdminContext } from './admin-auth.service.js';
import { can, isPanelRole } from './admin-permissions.js';

export function viaOf(ctx: AdminContext): AdminVia {
  return { via: 'panel', actorUserId: ctx.userId, ip: ctx.ip, requestId: ctx.requestId };
}

export function refused(message: string): AppException {
  return new AppException(ErrorCode.ADMIN_ACTION_REFUSED, message);
}

export interface AdminUserRowDto {
  id: string;
  username: string;
  displayName: string;
  email: string;
  status: 'ACTIVE' | 'SUSPENDED' | 'DELETED';
  avatarUrl: string | null;
  createdAt: string;
}

export interface LedgerRowDto {
  id: string;
  delta: number;
  balanceAfter: number;
  reason: string;
  createdAt: string;
}

const ROW_SELECT = {
  id: true,
  email: true,
  status: true,
  createdAt: true,
  profile: { select: { username: true, displayName: true, avatarUrl: true } },
} as const;

type RowUser = {
  id: string;
  email: string;
  status: 'ACTIVE' | 'SUSPENDED' | 'DELETED';
  createdAt: Date;
  profile: { username: string; displayName: string; avatarUrl: string | null } | null;
};

function rowDto(u: RowUser): AdminUserRowDto {
  return {
    id: u.id,
    username: u.profile?.username ?? '',
    displayName: u.profile?.displayName ?? '',
    email: u.email,
    status: u.status,
    avatarUrl: u.profile?.avatarUrl ?? null,
    createdAt: u.createdAt.toISOString(),
  };
}

/** UTC midnight of `now` (the dashboard's «today»). */
export function utcDayStart(now: Date): Date {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

/**
 * The panel's home and users sections (v1.60-social, D191, CONVENTIONS §10.54.5): real aggregates, the user search
 * (shown, base or special username, email or id), a user's profile (audited view: it shows the base username and
 * balances), and the actions — ban/unban through AccountLifecycleService, the profile photo through `avatar-admin`
 * (the `profile-admin` rule) and special usernames through `special-usernames` (the `username-admin` rule).
 */
@Injectable()
export class AdminUsersService {
  private readonly logger = new Logger(AdminUsersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly lifecycle: AccountLifecycleService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async dashboard(now = new Date()) {
    const since = utcDayStart(now);
    const [newUsers, sold, gifts, lives, apps, withdrawals, reports] = await Promise.all([
      this.prisma.user.count({ where: { createdAt: { gte: since } } }),
      this.prisma.rechargeSale.aggregate({
        where: { createdAt: { gte: since } },
        _sum: { coins: true },
        _count: true,
      }),
      this.prisma.liveGift.aggregate({
        where: { createdAt: { gte: since } },
        _sum: { totalCoins: true },
        _count: true,
      }),
      this.prisma.liveRoom.count({ where: { status: 'LIVE' } }),
      this.prisma.rechargeAgentApplication.count({ where: { status: 'PENDING' } }),
      this.prisma.cherryWithdrawal.count({ where: { status: 'PENDING' } }),
      this.prisma.report.count({ where: { status: 'OPEN' } }),
    ]);
    return {
      since: since.toISOString(),
      today: {
        newUsers,
        agentCoinsSold: Number(sold._sum.coins ?? 0n),
        agentSales: sold._count,
        giftsSent: gifts._count,
        giftCoins: Number(gifts._sum.totalCoins ?? 0n),
      },
      livesNow: lives,
      pending: { rechargeApplications: apps, withdrawals, reports },
    };
  }

  async search(q: string, limit: number): Promise<{ data: AdminUserRowDto[] }> {
    const value = q.trim();
    if (isUuid(value)) {
      const u = await this.prisma.user.findUnique({ where: { id: value.toLowerCase() }, select: ROW_SELECT });
      return { data: u ? [rowDto(u)] : [] };
    }
    if (value.includes('@') && !value.startsWith('@')) {
      const rows = await this.prisma.user.findMany({
        where: { email: { startsWith: normalizeEmail(value) } },
        orderBy: { email: 'asc' },
        take: limit,
        select: ROW_SELECT,
      });
      return { data: rows.map(rowDto) };
    }
    const name = normalizeUsername(value).replace(/^@/, '');
    const exact = await resolveUserIdByUsername(this.prisma, name);
    const special = await this.prisma.specialUsername.findMany({
      where: { OR: [{ username: name }, { baseUsername: name }] },
      select: { userId: true },
      take: 10,
    });
    const prefix = await this.prisma.userProfile.findMany({
      where: { username: { startsWith: name } },
      orderBy: { username: 'asc' },
      take: limit,
      select: { userId: true },
    });
    const ids = [...new Set([exact, ...special.map((s) => s.userId), ...prefix.map((p) => p.userId)])].filter(
      (x): x is string => x !== null,
    );
    const users = await this.prisma.user.findMany({ where: { id: { in: ids } }, select: ROW_SELECT });
    const byId = new Map(users.map((u) => [u.id, u]));
    return {
      data: ids
        .map((id) => byId.get(id))
        .filter((u): u is NonNullable<typeof u> => u !== undefined)
        .slice(0, limit)
        .map(rowDto),
    };
  }

  /** A user's profile for the panel; every view is audited (it shows the base username and, by role, balances). */
  async detail(id: string, ctx: AdminContext) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        ...ROW_SELECT,
        role: true,
        lastActiveAt: true,
        profile: {
          select: { username: true, displayName: true, avatarUrl: true, countryCode: true, bio: true },
        },
        adminPermissions: { select: { permission: true } },
      },
    });
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    const withBalances = can(ctx.roles, 'users.balances');
    const [special, agent, agency, agencyHost, openReports, recentReports] = await Promise.all([
      this.prisma.specialUsername.findFirst({
        where: { userId: id, status: 'ACTIVE' },
        select: { username: true, baseUsername: true, source: true, expiresAt: true },
      }),
      this.prisma.rechargeAgent.findUnique({
        where: { userId: id },
        select: { status: true, code: true, stockCoins: true, dailyCherryCap: true, suspendReason: true },
      }),
      this.prisma.agency.findFirst({
        where: { ownerUserId: id },
        select: { inviteCode: true, hostCode: true, rank: true, suspendedAt: true },
      }),
      this.prisma.agencyHost.findFirst({
        where: { hostUserId: id, status: 'ACTIVE' },
        select: { status: true, agency: { select: { inviteCode: true } } },
      }),
      this.prisma.report.count({ where: { targetUserId: id, status: 'OPEN' } }),
      this.prisma.report.findMany({
        where: { targetUserId: id },
        orderBy: { createdAt: 'desc' },
        take: 10,
        select: { id: true, reason: true, status: true, createdAt: true, targetType: true },
      }),
    ]);
    let balances: { coins: number; cherries: number; lockedTaskCherries: number } | null = null;
    let ledger: { coins: LedgerRowDto[]; cherries: LedgerRowDto[] } | null = null;
    if (withBalances) {
      const [wallet, cherryWallet, lock, coins, cherries] = await Promise.all([
        this.prisma.wallet.findUnique({ where: { userId: id }, select: { coins: true } }),
        this.prisma.cherryWallet.findUnique({ where: { userId: id }, select: { cherries: true } }),
        taskCherryLockIn(this.prisma, id, this.config.economy),
        this.prisma.walletLedgerEntry.findMany({
          where: { userId: id },
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          take: 20,
        }),
        this.prisma.cherryLedgerEntry.findMany({
          where: { userId: id },
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          take: 20,
        }),
      ]);
      balances = {
        coins: Number(wallet?.coins ?? 0n),
        cherries: Number(cherryWallet?.cherries ?? 0n),
        lockedTaskCherries: Number(lock.lockedCherries),
      };
      const row = (r: {
        id: string;
        delta: bigint;
        balanceAfter: bigint;
        reason: string;
        createdAt: Date;
      }) => ({
        id: r.id,
        delta: Number(r.delta),
        balanceAfter: Number(r.balanceAfter),
        reason: r.reason,
        createdAt: r.createdAt.toISOString(),
      });
      ledger = { coins: coins.map(row), cherries: cherries.map(row) };
    }
    await this.audit.record({
      action: AuditAction.ADMIN_USER_VIEW,
      actorUserId: ctx.userId,
      targetType: 'user',
      targetId: id,
      metadata: { balances: withBalances, via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return {
      user: {
        ...rowDto(user),
        role: user.role,
        lastActiveAt: user.lastActiveAt?.toISOString() ?? null,
        countryCode: user.profile?.countryCode ?? null,
        bio: user.profile?.bio ?? null,
        baseUsername: special?.baseUsername ?? user.profile?.username ?? '',
      },
      specialUsername: special
        ? {
            username: special.username,
            source: special.source,
            expiresAt: special.expiresAt?.toISOString() ?? null,
          }
        : null,
      adminRoles:
        user.role === 'ADMIN' ? user.adminPermissions.map((p) => p.permission).filter(isPanelRole) : [],
      balances,
      ledger,
      rechargeAgent: agent
        ? {
            status: agent.status,
            code: agent.code,
            stockCoins: Number(agent.stockCoins),
            dailyCherryCap: agent.dailyCherryCap === null ? null : Number(agent.dailyCherryCap),
            suspendReason: agent.suspendReason,
          }
        : null,
      hostAgent: agency
        ? {
            inviteCode: agency.inviteCode,
            hostCode: agency.hostCode,
            rank: agency.rank,
            suspended: agency.suspendedAt !== null,
          }
        : null,
      agencyHost: agencyHost
        ? { agencyInviteCode: agencyHost.agency.inviteCode, status: agencyHost.status }
        : null,
      reports: {
        open: openReports,
        recent: recentReports.map((r) => ({
          id: r.id,
          reason: r.reason,
          status: r.status,
          targetType: r.targetType,
          createdAt: r.createdAt.toISOString(),
        })),
      },
    };
  }

  private async target(id: string, ctx: AdminContext) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        status: true,
        role: true,
        profile: { select: { username: true } },
        adminPermissions: { select: { permission: true } },
      },
    });
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    if (user.id === ctx.userId) throw refused('You cannot do this to your own account.');
    const isAdmin = user.role === 'ADMIN' && user.adminPermissions.some((p) => isPanelRole(p.permission));
    if (isAdmin && !ctx.roles.includes('OWNER')) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    return user;
  }

  /** Ban «حظر»: ACTIVE → SUSPENDED with every side effect of AccountLifecycleService (live ended, seats freed …). */
  async ban(id: string, reason: string, ctx: AdminContext): Promise<{ status: 'SUSPENDED' }> {
    await this.target(id, ctx);
    await this.prisma.$transaction(async (tx) => {
      if (!(await this.lifecycle.suspendIn(tx, id))) throw refused('The account is not ACTIVE.');
      await this.audit.recordIn(tx, {
        action: AuditAction.ADMIN_USER_BAN,
        actorUserId: ctx.userId,
        targetType: 'user',
        targetId: id,
        metadata: { reason, before: 'ACTIVE', after: 'SUSPENDED', via: 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    return { status: 'SUSPENDED' };
  }

  async unban(id: string, reason: string, ctx: AdminContext): Promise<{ status: 'ACTIVE' }> {
    await this.target(id, ctx);
    await this.prisma.$transaction(async (tx) => {
      if (!(await this.lifecycle.unsuspendIn(tx, id))) throw refused('The account is not SUSPENDED.');
      await this.audit.recordIn(tx, {
        action: AuditAction.ADMIN_USER_UNBAN,
        actorUserId: ctx.userId,
        targetType: 'user',
        targetId: id,
        metadata: { reason, before: 'SUSPENDED', after: 'ACTIVE', via: 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    return { status: 'ACTIVE' };
  }

  /** The `profile-admin remove-avatar` rule: the photo goes, the user is told, its files are deleted after. */
  async removeAvatar(id: string, reason: string, ctx: AdminContext): Promise<{ removed: boolean }> {
    const user = await this.target(id, ctx);
    const username = user.profile?.username;
    if (!username) throw new AppException(ErrorCode.NOT_FOUND);
    const result = await this.prisma.$transaction((tx) =>
      removeAvatarByAdminIn(tx, username, reason, viaOf(ctx)),
    );
    if (result.outcome === 'unknown_user') throw new AppException(ErrorCode.NOT_FOUND);
    if (result.outcome === 'no_photo') throw refused('The user has no profile photo.');
    if (result.objectKeys.length > 0) {
      try {
        await this.storage.delete(result.objectKeys);
      } catch (err) {
        // The photo is already gone from the profile; the orphaned files are only a storage cost.
        this.logger.warn({ error: safeErrorLog(err), userId: id }, 'Avatar files could not be deleted');
      }
    }
    return { removed: true };
  }

  /** The `username-admin gift` rule (ADMIN_GIFT, for N days or permanently). */
  async giftSpecial(
    id: string,
    body: { username: string; days?: number | undefined; permanent?: true | undefined; reason: string },
    ctx: AdminContext,
  ): Promise<{ username: string; baseUsername: string; expiresAt: string | null }> {
    await this.target(id, ctx);
    const now = new Date();
    const name = normalizeUsername(body.username).replace(/^@/, '');
    const expiresAt = body.days === undefined ? null : new Date(now.getTime() + body.days * 86_400_000);
    try {
      const row = await this.prisma.$transaction((tx) =>
        grantSpecialIn(
          tx,
          id,
          name,
          {
            source: 'ADMIN_GIFT',
            expiresAt,
            reason: body.reason,
            actorUserId: ctx.userId,
            via: 'panel',
            ip: ctx.ip,
          },
          now,
          this.config.specialUsernames.graceDays,
        ),
      );
      return {
        username: row.username,
        baseUsername: row.baseUsername,
        expiresAt: row.expiresAt?.toISOString() ?? null,
      };
    } catch (err) {
      if (err instanceof SpecialUsernameError) throw refused(err.message);
      throw err;
    }
  }

  /** The `username-admin revoke` rule: the own username is shown again; the special one stays reserved for them. */
  async revokeSpecial(id: string, reason: string, ctx: AdminContext): Promise<{ revoked: true }> {
    await this.target(id, ctx);
    const ended = await this.prisma.$transaction((tx) =>
      endSpecialIn(tx, id, 'REVOKED', new Date(), this.config.specialUsernames.graceDays, {
        actorUserId: ctx.userId,
        via: 'panel',
        note: reason,
        ip: ctx.ip,
      }),
    );
    if (!ended) throw refused('The user has no active special username.');
    return { revoked: true };
  }
}
