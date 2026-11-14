import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { RevokedReason, SessionsService } from '../auth/sessions.service.js';
import type { AdminContext } from './admin-auth.service.js';
import { isPanelRole } from './admin-permissions.js';
import { tableResult, window, type TableQuery } from './admin-tables.js';
import { refused } from './admin-users.service.js';

export interface UsersTableQuery extends TableQuery {
  readonly status?: 'ACTIVE' | 'SUSPENDED' | 'DELETED' | undefined;
  readonly role?: 'USER' | 'ADMIN' | undefined;
}

const USER_ROW = {
  id: true,
  email: true,
  status: true,
  role: true,
  createdAt: true,
  lastActiveAt: true,
  profile: { select: { username: true, displayName: true, avatarUrl: true, countryCode: true } },
} as const;

/** One audit row as the panel shows it (also the audit viewer's row). */
export const AUDIT_ROW = {
  id: true,
  action: true,
  targetType: true,
  targetId: true,
  metadata: true,
  ip: true,
  createdAt: true,
  actor: { select: { id: true, profile: { select: { username: true, displayName: true } } } },
} as const;

type AuditRow = Prisma.AuditLogGetPayload<{ select: typeof AUDIT_ROW }>;

export function auditRowDto(r: AuditRow) {
  return {
    id: r.id,
    action: r.action,
    targetType: r.targetType,
    targetId: r.targetId,
    metadata: (r.metadata ?? {}) as Record<string, unknown>,
    ip: r.ip,
    createdAt: r.createdAt.toISOString(),
    actor: r.actor
      ? {
          id: r.actor.id,
          username: r.actor.profile?.username ?? '',
          displayName: r.actor.profile?.displayName ?? '',
        }
      : null,
  };
}

/**
 * The users section of the panel v2 (v1.65-social, D197, CONVENTIONS §10.60.1–2): the users table (server-side
 * pages, sort, filters, CSV), and a user's page tabs — the paged coin / cherry ledger, the posts, the audit rows
 * about the user, and the app sessions (devices) with «sign out» (the app's own session rule, audited with the
 * reason). Read-only except the sign-out.
 */
@Injectable()
export class AdminPeopleService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly sessions: SessionsService,
  ) {}

  async table(q: UsersTableQuery, ctx: AdminContext) {
    const text = q.q?.replace(/^@/, '').toLowerCase();
    const where: Prisma.UserWhereInput = {
      ...(q.status ? { status: q.status } : {}),
      ...(q.role ? { role: q.role } : {}),
      ...(text
        ? {
            OR: [
              { email: { startsWith: text } },
              { profile: { username: { startsWith: text } } },
              { profile: { displayName: { contains: q.q!, mode: 'insensitive' } } },
              ...(/^[0-9a-f-]{36}$/.test(text) ? [{ id: text }] : []),
            ],
          }
        : {}),
    };
    const dir = q.order;
    const orderBy: Prisma.UserOrderByWithRelationInput[] =
      q.sort === 'username'
        ? [{ profile: { username: dir } }, { id: dir }]
        : q.sort === 'email'
          ? [{ email: dir }]
          : q.sort === 'lastActiveAt'
            ? [{ lastActiveAt: { sort: dir, nulls: 'last' } }, { id: dir }]
            : [{ createdAt: dir }, { id: dir }];
    const [rows, total] = await Promise.all([
      this.prisma.user.findMany({ where, orderBy, ...window(q), select: USER_ROW }),
      this.prisma.user.count({ where }),
    ]);
    const data = rows.map((u) => ({
      id: u.id,
      username: u.profile?.username ?? '',
      displayName: u.profile?.displayName ?? '',
      email: u.email,
      status: u.status,
      role: u.role,
      avatarUrl: u.profile?.avatarUrl ?? null,
      countryCode: u.profile?.countryCode ?? null,
      createdAt: u.createdAt.toISOString(),
      lastActiveAt: u.lastActiveAt?.toISOString() ?? null,
    }));
    return tableResult(
      this.audit,
      ctx,
      'users',
      q,
      data,
      total,
      [
        ['id', (r) => r.id],
        ['username', (r) => r.username],
        ['display_name', (r) => r.displayName],
        ['email', (r) => r.email],
        ['status', (r) => r.status],
        ['role', (r) => r.role],
        ['country', (r) => r.countryCode],
        ['created_at', (r) => r.createdAt],
        ['last_active_at', (r) => r.lastActiveAt],
      ],
      { status: q.status ?? null, role: q.role ?? null },
    );
  }

  private async exists(id: string): Promise<void> {
    if (!(await this.prisma.user.findUnique({ where: { id }, select: { id: true } }))) {
      throw new AppException(ErrorCode.NOT_FOUND);
    }
  }

  /** The coin or cherry ledger of a user, newest first, by pages. */
  async ledger(id: string, kind: 'coins' | 'cherries' | 'recharge_points', page: number, pageSize: number) {
    await this.exists(id);
    if (kind === 'recharge_points') {
      // v1.126-social (D370, §10.163): «نقاط الشحن».
      const where = { userId: id };
      const [rows, total] = await Promise.all([
        this.prisma.rechargePointsEntry.findMany({
          where,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          skip: (page - 1) * pageSize,
          take: pageSize,
          select: { id: true, delta: true, balanceAfter: true, reason: true, createdAt: true },
        }),
        this.prisma.rechargePointsEntry.count({ where }),
      ]);
      return {
        data: rows.map((r) => ({
          id: r.id,
          delta: Number(r.delta),
          balanceAfter: Number(r.balanceAfter),
          reason: r.reason,
          createdAt: r.createdAt.toISOString(),
        })),
        total,
        page,
        pageSize,
      };
    }
    const args = {
      where: { userId: id },
      orderBy: [{ createdAt: 'desc' as const }, { id: 'desc' as const }],
      skip: (page - 1) * pageSize,
      take: pageSize,
      select: { id: true, delta: true, balanceAfter: true, reason: true, createdAt: true },
    };
    const [rows, total] =
      kind === 'coins'
        ? await Promise.all([
            this.prisma.walletLedgerEntry.findMany(args),
            this.prisma.walletLedgerEntry.count({ where: { userId: id } }),
          ])
        : await Promise.all([
            this.prisma.cherryLedgerEntry.findMany(args),
            this.prisma.cherryLedgerEntry.count({ where: { userId: id } }),
          ]);
    return {
      data: rows.map((r) => ({
        id: r.id,
        delta: Number(r.delta),
        balanceAfter: Number(r.balanceAfter),
        reason: r.reason,
        createdAt: r.createdAt.toISOString(),
      })),
      total,
      page,
      pageSize,
    };
  }

  /** The user's posts (any state), newest first. */
  async posts(id: string, page: number, pageSize: number) {
    await this.exists(id);
    const where = { authorId: id };
    const [rows, total] = await Promise.all([
      this.prisma.post.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * pageSize,
        take: pageSize,
        select: {
          id: true,
          text: true,
          format: true,
          status: true,
          moderation: true,
          likeCount: true,
          commentCount: true,
          viewCount: true,
          createdAt: true,
          deletedAt: true,
          _count: { select: { media: true } },
        },
      }),
      this.prisma.post.count({ where }),
    ]);
    return {
      data: rows.map((p) => ({
        id: p.id,
        text: p.text.length > 280 ? `${p.text.slice(0, 280)}…` : p.text,
        format: p.format,
        status: p.status,
        moderation: p.moderation,
        media: p._count.media,
        likes: p.likeCount,
        comments: p.commentCount,
        views: p.viewCount,
        deleted: p.deletedAt !== null,
        createdAt: p.createdAt.toISOString(),
      })),
      total,
      page,
      pageSize,
    };
  }

  /**
   * The user's timeline: the audit rows whose target is this user, and (v1.72-social, D208) the rows this account did
   * itself (sign-ins, its own changes …) and the team's actions on its content (`targetType` post / story / comment
   * with `metadata.authorId`), newest first.
   */
  async auditOf(id: string, page: number, pageSize: number) {
    const where: Prisma.AuditLogWhereInput = {
      OR: [
        { targetType: 'user', targetId: id },
        { actorUserId: id },
        { targetType: { in: ['post', 'story', 'comment'] }, metadata: { path: ['authorId'], equals: id } },
      ],
    };
    const [rows, total] = await Promise.all([
      this.prisma.auditLog.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * pageSize,
        take: pageSize,
        select: AUDIT_ROW,
      }),
      this.prisma.auditLog.count({ where }),
    ]);
    return { data: rows.map(auditRowDto), total, page, pageSize };
  }

  /** The user's signed-in app sessions (devices). */
  async sessionsOf(id: string, now = new Date()) {
    await this.exists(id);
    const rows = await this.prisma.session.findMany({
      where: { userId: id, revokedAt: null, expiresAt: { gt: now }, absoluteExpiresAt: { gt: now } },
      orderBy: [{ lastUsedAt: 'desc' }, { id: 'desc' }],
      take: 50,
      select: {
        id: true,
        deviceName: true,
        platform: true,
        appVersion: true,
        ip: true,
        createdAt: true,
        lastUsedAt: true,
      },
    });
    return {
      data: rows.map((s) => ({
        id: s.id,
        deviceName: s.deviceName,
        platform: s.platform,
        appVersion: s.appVersion,
        ip: s.ip,
        createdAt: s.createdAt.toISOString(),
        lastUsedAt: s.lastUsedAt.toISOString(),
      })),
    };
  }

  /**
   * Signs a user out of one app session or of all (the app's own revocation: the refresh token dies, the push token
   * goes). A panel admin's account only by an OWNER; never one's own. Audited with the reason.
   */
  async revokeSessions(id: string, sessionId: string | undefined, reason: string, ctx: AdminContext) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: { id: true, role: true, adminPermissions: { select: { permission: true } } },
    });
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    if (user.id === ctx.userId) throw refused('You cannot do this to your own account.');
    const isAdmin = user.role === 'ADMIN' && user.adminPermissions.some((p) => isPanelRole(p.permission));
    if (isAdmin && !ctx.roles.includes('OWNER')) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const now = new Date();
    let revoked: number;
    if (sessionId) {
      revoked = (await this.sessions.revoke(id, sessionId, RevokedReason.ADMIN_REVOKED, now)) ? 1 : 0;
      if (revoked === 0) throw new AppException(ErrorCode.NOT_FOUND);
    } else {
      revoked = await this.sessions.revokeAllForUser(this.prisma, id, RevokedReason.ADMIN_REVOKED, now);
    }
    await this.audit.record({
      action: AuditAction.ADMIN_USER_SESSIONS_REVOKE,
      actorUserId: ctx.userId,
      targetType: 'user',
      targetId: id,
      metadata: { sessions: revoked, sessionId: sessionId ?? null, all: !sessionId, reason, via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return { revoked };
  }
}
