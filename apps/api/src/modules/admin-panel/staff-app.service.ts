import { Inject, Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { LiveChatService } from '../live/live-chat.service.js';
import { LiveKicksService } from '../live/live-kicks.service.js';
import { WATCH_STAFF_ROLES } from '../live/live-staff.js';
import { openLiveReportsByRoom } from '../live/live-reports.js';
import { AdminAuthService, type AdminContext, type AdminMeta } from './admin-auth.service.js';
import type { Capability } from './admin-permissions.js';
import { refused } from './admin-users.service.js';
import {
  countriesOfRegions,
  isStaffRegion,
  regionOfCountry,
  type StaffRegion,
} from '../live/staff-regions.js';

/**
 * The capabilities the app's staff tools use (a subset of the panel's table, §10.54.1): the app shows only these, and
 * each staff route checks its own on every request.
 */
export const STAFF_APP_CAPABILITIES = [
  'lives.watch',
  'lives.watch.hidden',
  'lives.reports',
  'lives.moderate',
  'devices.ban',
  // v1.78-live (D288, §10.101): «بلاغات» — the shared report queue and «تم حله».
  'reports.view',
  'reports.resolve',
  // v1.93-social (D296, §10.109): the actions from a report — the panel's own capabilities.
  'reports.act',
  'users.restrict',
  'users.lock',
  'users.ban',
  // Owner (2026-11-06): the permanent deletions from a report too (no code since D288).
  'users.content',
  'users.delete',
  // v1.97-social (D303, §10.114.7): «الفعاليات» — create / edit gift events and hold their payout.
  'events.manage',
  // v1.116-social (D355, §10.151): «واتساب» — the shared WhatsApp inbox and its quick replies.
  'support.whatsapp',
  'support.whatsapp.manage',
  // v1.120-social (D360, §10.155): VIEW — «مشاهدة فقط» (the inbox read only). The three come from the person's level.
  'support.whatsapp.view',
] as const satisfies readonly Capability[];

/** `StaffStatus` (v1.68-live, D273). */
export interface StaffStatusDto {
  /** Holds a watch role now (OWNER, MODERATION, SUPPORT): listed as «فريق كابسو» in every live. */
  isStaff: boolean;
  /** Holds any panel role now (FINANCE too): nobody acts on the account from the app. */
  protected: boolean;
  roles: string[];
  capabilities: string[];
  /** The panel authenticator is set up (the step-up needs it; else «enrol at admin.<domain>»). */
  authenticatorEnrolled: boolean;
  /** The admin account is locked after wrong codes until then (null: not locked). */
  lockedUntil: string | null;
  /** DEPRECATED v1.76-live (D286): always set for watch staff (no step-up any more); older apps read it as unlocked. */
  stepUp: { expiresAt: string } | null;
  onShift: boolean;
}

/** `StaffLive` (D273): one of «بثوثي» — a live assigned to the caller. */
export interface StaffLiveDto {
  roomId: string;
  title: string;
  host: { username: string; displayName: string; avatarUrl: string | null };
  viewerCount: number;
  startedAt: string;
  openReports: number;
  /** When it was assigned to the caller; null (v1.72-live, `scope=regions`) for a live in their regions held by another. */
  assignedAt: string | null;
  /** v1.72-live (D283): the host's country (ISO alpha-2) and its staff region, or null. */
  hostCountry: string | null;
  region: StaffRegion | null;
}

const STAFF_LIVE_ROOM = {
  select: {
    id: true,
    title: true,
    viewerCount: true,
    startedAt: true,
    host: {
      select: {
        profile: { select: { username: true, displayName: true, avatarUrl: true, countryCode: true } },
      },
    },
  },
} as const;

/**
 * v1.68-live (D273, CONVENTIONS §10.96.6; owner: «نفس صلاحيات اللوحة من الهاتف»): the staff tools in the app — the
 * status, the (deprecated, D286) step-up with the panel authenticator code, and the live
 * actions that are not the panel's own rule functions (removing a chat message, a chat mute, a kick: the room's rules
 * run with the staff member as «فريق كابسو»). The panel's rules (moderate, dismiss, reports, the shift) are called by
 * the controller with an `AdminContext` of `via: app`.
 */
@Injectable()
export class StaffAppService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    private readonly adminAuth: AdminAuthService,
    private readonly chat: LiveChatService,
    private readonly kicks: LiveKicksService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** `GET /staff/me`: any signed-in user (a non-staff account reads `isStaff` false and nothing else). */
  async status(userId: string, sessionId: string): Promise<StaffStatusDto> {
    const { roles, capabilities } = await this.adminAuth.accessOf(userId);
    if (roles.length === 0) {
      return {
        isStaff: false,
        protected: false,
        roles: [],
        capabilities: [],
        authenticatorEnrolled: false,
        lockedUntil: null,
        stepUp: null,
        onShift: false,
      };
    }
    const caps = capabilities.filter((c) => (STAFF_APP_CAPABILITIES as readonly string[]).includes(c));
    const isStaff = roles.some((r) => (WATCH_STAFF_ROLES as readonly string[]).includes(r));
    const now = this.clock.now();
    const [second, shift] = await Promise.all([
      this.adminAuth.secondFactorState(userId),
      this.prisma.adminShift.findUnique({ where: { userId }, select: { onShift: true } }),
    ]);
    // DEPRECATED v1.76-live (D286): the tools need no step-up — `stepUp` is always set for watch staff (a rolling
    // `STAFF_APP_GRANT_SECONDS` ahead, bound to nothing), so an app before D286 shows its tools without asking.
    void sessionId;
    const standing = new Date(now.getTime() + this.config.adminPanel.staffAppGrantSeconds * 1000);
    return {
      isStaff,
      protected: true,
      roles: [...roles].sort(),
      capabilities: caps,
      authenticatorEnrolled: second.enrolled,
      lockedUntil: second.lockedUntil?.toISOString() ?? null,
      stepUp: isStaff ? { expiresAt: standing.toISOString() } : null,
      onShift: isStaff && shift?.onShift === true,
    };
  }

  /**
   * `POST /staff/step-up`: a watch staff member's panel authenticator code (the panel's rule: single use, a wrong one
   * counts towards the same lockout, which ends every panel session and app grant). A new grant replaces this
   * session's previous one; audited `admin.app.step_up`.
   */
  async stepUp(
    userId: string,
    sessionId: string,
    code: string,
    meta: AdminMeta,
  ): Promise<{ expiresAt: string }> {
    const roles = await this.adminAuth.rolesOf(userId);
    if (!roles.some((r) => (WATCH_STAFF_ROLES as readonly string[]).includes(r))) {
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    }
    await this.adminAuth.stepUpCode(userId, code, meta);
    const now = this.clock.now();
    const expiresAt = new Date(now.getTime() + this.config.adminPanel.staffAppGrantSeconds * 1000);
    await this.prisma.$transaction(async (tx) => {
      await tx.adminAppGrant.updateMany({
        where: { userId, sessionId, revokedAt: null },
        data: { revokedAt: now, revokedReason: 'REPLACED' },
      });
      await tx.adminAppGrant.create({
        data: { userId, sessionId, createdAt: now, expiresAt, ip: meta.ip?.slice(0, 64) ?? null },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.ADMIN_APP_STEP_UP,
        actorUserId: userId,
        targetType: 'session',
        targetId: sessionId,
        metadata: { expiresAt: expiresAt.toISOString(), roles: [...roles].sort(), via: 'app' },
        ip: meta.ip,
        requestId: meta.requestId,
      });
    });
    return { expiresAt: expiresAt.toISOString() };
  }

  /** `DELETE /staff/step-up`: «إنهاء» — this session's grant ends (idempotent; audited when one ended). */
  async endStepUp(userId: string, sessionId: string, meta: AdminMeta): Promise<void> {
    const ended = await this.prisma.adminAppGrant.updateMany({
      where: { userId, sessionId, revokedAt: null },
      data: { revokedAt: this.clock.now(), revokedReason: 'ENDED' },
    });
    if (ended.count === 0) return;
    await this.audit.record({
      action: AuditAction.ADMIN_APP_STEP_UP_END,
      actorUserId: userId,
      targetType: 'session',
      targetId: sessionId,
      metadata: { reason: 'ENDED', via: 'app' },
      ip: meta.ip,
      requestId: meta.requestId,
    });
  }

  /** `GET /staff/lives`: «بثوثي» — the LIVE rooms assigned to the caller, most reported first, then the oldest. */
  async myLives(
    ctx: AdminContext,
    scope: 'assigned' | 'regions' = 'assigned',
  ): Promise<{ data: StaffLiveDto[] }> {
    const room = STAFF_LIVE_ROOM;
    // v1.72-live (D283, §10.96.11): `regions` — every live on air whose host's country is in my regions (assigned
    // to anyone; `assignedAt` null when not to me), at most 200, the reported first.
    const rows =
      scope === 'regions'
        ? await this.livesInMyRegions(ctx.userId, room)
        : await this.prisma.liveRoomAssignment.findMany({
            where: { adminId: ctx.userId, room: { status: 'LIVE' } },
            select: { assignedAt: true, room },
          });
    const reports = await openLiveReportsByRoom(
      this.prisma,
      rows.map((r) => r.room.id),
    );
    const data = rows.map((r) => ({
      roomId: r.room.id,
      title: r.room.title,
      host: {
        username: r.room.host.profile?.username ?? '',
        displayName: r.room.host.profile?.displayName ?? '',
        avatarUrl: r.room.host.profile?.avatarUrl ?? null,
      },
      viewerCount: r.room.viewerCount,
      startedAt: r.room.startedAt.toISOString(),
      openReports: reports.get(r.room.id) ?? 0,
      assignedAt: r.assignedAt?.toISOString() ?? null,
      hostCountry: r.room.host.profile?.countryCode ?? null,
      region: regionOfCountry(r.room.host.profile?.countryCode),
    }));
    data.sort(
      (a, b) =>
        b.openReports - a.openReports ||
        a.startedAt.localeCompare(b.startedAt) ||
        a.roomId.localeCompare(b.roomId),
    );
    return { data };
  }

  private async livesInMyRegions(adminId: string, room: typeof STAFF_LIVE_ROOM) {
    const mine = await this.prisma.adminStaffRegion.findMany({
      where: { userId: adminId },
      select: { region: true },
    });
    const countries = countriesOfRegions(mine.map((r) => r.region).filter(isStaffRegion));
    if (countries.length === 0) return [];
    const lives = await this.prisma.liveRoom.findMany({
      where: { status: 'LIVE', host: { profile: { countryCode: { in: countries } } } },
      orderBy: [{ startedAt: 'asc' }, { id: 'asc' }],
      take: 200,
      select: { ...room.select, assignment: { select: { adminId: true, assignedAt: true } } },
    });
    return lives.map(({ assignment, ...rest }) => ({
      assignedAt: assignment?.adminId === adminId ? assignment.assignedAt : null,
      room: rest,
    }));
  }

  /** Closes the open reports on one user (or message) of this live as ACTIONED with the reason; returns how many. */
  private async closeTargetReports(
    roomId: string,
    where: { userId?: string; messageId?: string },
    reason: string,
    ctx: AdminContext,
  ): Promise<number> {
    const now = this.clock.now();
    const out = await this.prisma.report.updateMany({
      where: {
        status: 'OPEN',
        OR: [
          ...(where.userId
            ? [{ targetType: 'USER' as const, targetUserId: where.userId, contextLiveRoomId: roomId }]
            : []),
          ...(where.messageId ? [{ targetLiveChatMessageId: where.messageId }] : []),
        ],
      },
      data: { status: 'ACTIONED', resolvedAt: now, resolvedById: ctx.userId, resolutionNote: reason },
    });
    return out.count;
  }

  /** `POST /staff/lives/{roomId}/chat/{messageId}/remove` (`lives.moderate`): audited `admin.live.chat_remove`. */
  async removeMessage(roomId: string, messageId: string, reason: string, ctx: AdminContext) {
    const out = await this.chat.removeAsStaff(roomId, messageId, ctx.userId);
    const reportsClosed = await this.closeTargetReports(
      roomId,
      { messageId: messageId.toLowerCase() },
      reason,
      ctx,
    );
    await this.audit.record({
      action: AuditAction.ADMIN_LIVE_CHAT_REMOVE,
      actorUserId: ctx.userId,
      targetType: 'live_chat_message',
      targetId: messageId.toLowerCase(),
      metadata: { roomId, authorId: out.authorId, deleted: out.deleted, reason, reportsClosed, via: 'app' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return { removed: out.deleted, reportsClosed };
  }

  /** `POST /staff/lives/{roomId}/chat-mutes` (`lives.moderate`): audited `admin.live.chat_mute`. Never the host. */
  async muteInChat(roomId: string, username: string, muted: boolean, reason: string, ctx: AdminContext) {
    const out = await this.chat.muteAsStaff(roomId, username.replace(/^@/, ''), ctx.userId, muted);
    if (out.userId === out.hostUserId) throw refused('The host cannot be muted in their own live.');
    if (out.userId === ctx.userId) throw refused('You cannot do this to yourself.');
    await this.audit.record({
      action: AuditAction.ADMIN_LIVE_CHAT_MUTE,
      actorUserId: ctx.userId,
      targetType: 'user',
      targetId: out.userId,
      metadata: { roomId, muted, changed: out.changed, reason, via: 'app' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return { muted, changed: out.changed };
  }

  /** `POST /staff/lives/{roomId}/kicks` (`lives.moderate`): the room's kick as «فريق كابسو» (audited `live.kick`). */
  async kick(roomId: string, username: string, reason: string, ctx: AdminContext) {
    const out = await this.kicks.kick(
      ctx.userId,
      roomId,
      { username: username.replace(/^@/, '') },
      { ip: ctx.ip, requestId: ctx.requestId },
      { reason },
    );
    const reportsClosed = await this.closeTargetReports(roomId, { userId: out.kick.user.id }, reason, ctx);
    return { created: out.created, kick: out.kick, reportsClosed };
  }
}
