import { randomBytes } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { Prisma, type LiveModerationKind } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { banDevicesIn, DeviceBanError, devicesOfUserIn, liftDeviceBanIn } from '../auth/device-bans.js';
import { LiveMediaService, type StaffMediaAccessDto } from '../live/live-media.service.js';
import { LIVE_TX_OPTIONS, LiveRoomsService } from '../live/live-rooms.service.js';
import { AccountControlError, MAX_RESTRICTION_DAYS, restrictIn } from '../users/account-control.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import { isPanelRole } from './admin-permissions.js';
import { tableResult, window, type TableQuery } from './admin-tables.js';
import { refused, viaOf } from './admin-users.service.js';

type Tx = Prisma.TransactionClient;

const HOUR_MS = 3_600_000;
/** The live chat lines shown before each report (CONVENTIONS §10.91.3). */
export const REPORT_CHAT_LINES = 5;
/** The live chat feed of the watch view: the last 50 lines. */
export const WATCH_CHAT_LINES = 50;
const REPORTS_MAX = 50;

export type ModerateAction = Exclude<LiveModerationKind, 'DISMISS'>;

export interface ModerateBody {
  action: ModerateAction;
  reason: string;
  hours?: number | undefined;
  until?: string | undefined;
  permanent?: boolean | undefined;
  totpCode?: string | undefined;
}

import { openLiveReportsByRoom } from '../live/live-reports.js';

export { openLiveReportsByRoom };

/** The `reports` rows of a live (the room's, and its host's as a user since it started). */
function liveReportsWhere(room: {
  id: string;
  hostUserId: string;
  startedAt: Date;
}): Prisma.ReportWhereInput {
  return {
    OR: [
      { targetLiveRoomId: room.id },
      { targetType: 'USER', targetUserId: room.hostUserId, createdAt: { gte: room.startedAt } },
    ],
  };
}

const person = {
  select: { id: true, profile: { select: { username: true, displayName: true, avatarUrl: true } } },
};
type PersonRow = {
  id: string;
  profile: { username: string; displayName: string; avatarUrl: string | null } | null;
} | null;
function personOf(u: PersonRow) {
  return u
    ? {
        id: u.id,
        username: u.profile?.username ?? '',
        displayName: u.profile?.displayName ?? '',
        avatarUrl: u.profile?.avatarUrl ?? null,
      }
    : null;
}

/**
 * «مراقبة البث» — live moderation from the panel (v1.60-live, D250, CONVENTIONS §10.91; owner 2026-11-02: «يمكن أن يكون
 * موظف يراقب اللايفات من خلال اللوحة، وفي حال شخص قام بالإبلاغ عن لايف يظهر في خانة لايفات مبلّغ عنها … يغلق البث أو
 * عمل حظر مؤقت أو حظر جهاز، ويضع في صندوق سبب ليصل إشعار للمضيف بالسبب»):
 *
 *  - **Watch** (`lives.watch`): a hidden, subscribe-only observer token per media room (both rooms of a PK), audited
 *    `admin.live.watch` with the purpose (a card's muted preview or the watch view); never a viewer.
 *  - **Reported lives** (`lives.reports`): the LIVE rooms with open reports — on the room (`LIVE_ROOM`) or on its host
 *    as a user since the live started (older apps report the host) — their counts (the red dots), a live's reports
 *    with the reporter and the chat lines just before each report, and the live's chat feed.
 *  - **Actions** (`lives.moderate`; a device ban also `devices.ban` and the authenticator code again), always with a
 *    reason the host is told (one `LIVE_MODERATED` notification, push + in-app): END the live; NO_LIVE «منع من البث» or
 *    SUSPEND «تعليق الحساب» for a while (D208's NO_LIVE / LOCK restriction, ended by the clock); DEVICE_BAN «حظر جهاز»
 *    (every device seen for the account, for a while or for good). Each one ends the live, closes its open reports
 *    as ACTIONED and is audited `admin.live.moderate`. DISMISS «تمت المراجعة — لا مخالفة» closes them as DISMISSED.
 *  - **Device bans** (`devices.ban`): the list and lifting one (a reason; audited).
 */
@Injectable()
export class AdminLiveModerationService {
  private readonly logger = new Logger(AdminLiveModerationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly rooms: LiveRoomsService,
    private readonly media: LiveMediaService,
    private readonly adminAuth: AdminAuthService,
  ) {}

  // ---- reported lives ------------------------------------------------------------------------------------------

  /** Open reports per LIVE room (only rooms with at least one). */
  openReportsByRoom(roomIds?: readonly string[]): Promise<Map<string, number>> {
    return openLiveReportsByRoom(this.prisma, roomIds);
  }

  /** `GET /admin/live-reports/summary`: the red dots — reported lives on air and their open reports. */
  async summary() {
    const byRoom = await this.openReportsByRoom();
    let reports = 0;
    for (const n of byRoom.values()) reports += n;
    return { rooms: byRoom.size, reports };
  }

  private async room(id: string) {
    const room = await this.prisma.liveRoom.findUnique({
      where: { id },
      select: { id: true, status: true, hostUserId: true, startedAt: true, mode: true },
    });
    if (!room) throw new AppException(ErrorCode.NOT_FOUND);
    return room;
  }

  /** `GET /admin/lives/{roomId}/reports`: newest first, with the reporter (staff only) and the chat just before. */
  async reports(id: string) {
    const room = await this.room(id);
    const rows = await this.prisma.report.findMany({
      where: liveReportsWhere(room),
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: REPORTS_MAX,
      select: {
        id: true,
        targetType: true,
        reason: true,
        note: true,
        status: true,
        createdAt: true,
        resolvedAt: true,
        resolutionNote: true,
        reporter: person,
      },
    });
    const data = [];
    for (const r of rows) {
      const lines = await this.prisma.liveChatMessage.findMany({
        where: { roomId: room.id, createdAt: { lte: r.createdAt } },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: REPORT_CHAT_LINES,
        select: this.chatSelect,
      });
      data.push({
        id: r.id,
        targetType: r.targetType as 'LIVE_ROOM' | 'USER',
        reason: r.reason,
        note: r.note,
        status: r.status,
        createdAt: r.createdAt.toISOString(),
        resolvedAt: r.resolvedAt?.toISOString() ?? null,
        resolutionNote: r.resolutionNote,
        reporter: personOf(r.reporter),
        chatBefore: lines.reverse().map((l) => this.chatLine(l)),
      });
    }
    return { open: data.filter((r) => r.status === 'OPEN').length, data };
  }

  private readonly chatSelect = {
    id: true,
    kind: true,
    text: true,
    createdAt: true,
    deletedAt: true,
    authorRole: true,
    user: person,
  } satisfies Prisma.LiveChatMessageSelect;

  private chatLine(
    l: Prisma.LiveChatMessageGetPayload<{ select: AdminLiveModerationService['chatSelect'] }>,
  ) {
    return {
      id: l.id,
      kind: l.kind as string,
      text: l.text,
      createdAt: l.createdAt.toISOString(),
      deleted: l.deletedAt !== null,
      authorRole: l.authorRole as string,
      author: personOf(l.user),
    };
  }

  /** `GET /admin/lives/{roomId}/chat`: the last 50 lines, oldest first (deleted ones marked, not hidden). */
  async chat(id: string, after?: string) {
    const room = await this.room(id);
    const since = after ? new Date(after) : null;
    const lines = await this.prisma.liveChatMessage.findMany({
      where: {
        roomId: room.id,
        ...(since && !Number.isNaN(since.getTime()) ? { createdAt: { gt: since } } : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: WATCH_CHAT_LINES,
      select: this.chatSelect,
    });
    return { data: lines.reverse().map((l) => this.chatLine(l)) };
  }

  // ---- watch ---------------------------------------------------------------------------------------------------

  /** The other room of the live's open PK, if any. */
  private async pkOpponentRoom(roomId: string): Promise<string | null> {
    const match = await this.prisma.pkMatch.findFirst({
      where: { status: { not: 'CLOSED' }, OR: [{ roomAId: roomId }, { roomBId: roomId }] },
      orderBy: { createdAt: 'desc' },
      select: { roomAId: true, roomBId: true },
    });
    if (!match) return null;
    return match.roomAId === roomId ? match.roomBId : match.roomAId;
  }

  /**
   * `POST /admin/lives/{roomId}/watch-token`: observer tokens (both rooms of a PK); audited. v1.64-live (D260, §10.96):
   * a WATCH is VISIBLE by default (`team:` — listed in this live with the «فريق كابسو» badge, never counted); HIDDEN
   * (`staff:`, D250) needs `lives.watch.hidden` (OWNER / MODERATION). A PREVIEW and the PK opponent's room are hidden.
   */
  async watchToken(
    id: string,
    purpose: 'PREVIEW' | 'WATCH',
    ctx: AdminContext,
    visibility?: 'VISIBLE' | 'HIDDEN',
  ) {
    const visible = purpose === 'WATCH' && visibility !== 'HIDDEN';
    if (purpose === 'WATCH' && !visible && !ctx.capabilities.includes('lives.watch.hidden'))
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const room = await this.room(id);
    if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const nonce = randomBytes(6).toString('hex');
    const main = await this.media.staffAccess(ctx.userId, room.id, nonce, visible);
    let opponent: StaffMediaAccessDto | null = null;
    // A preview shows this room only; the watch view also gets the other side of a PK.
    const other = purpose === 'WATCH' ? await this.pkOpponentRoom(room.id) : null;
    if (other) {
      try {
        opponent = await this.media.staffAccess(ctx.userId, other, nonce);
      } catch (err) {
        if (!(err instanceof AppException)) throw err;
      }
    }
    await this.audit.record({
      action: AuditAction.ADMIN_LIVE_WATCH,
      actorUserId: ctx.userId,
      targetType: 'live_room',
      targetId: room.id,
      metadata: {
        purpose,
        visibility: visible ? 'VISIBLE' : 'HIDDEN',
        identity: main.identity,
        hostUserId: room.hostUserId,
        ...(opponent ? { opponentRoomId: opponent.roomId } : {}),
        via: 'panel',
      },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return { purpose, visibility: visible ? 'VISIBLE' : 'HIDDEN', main, opponent };
  }

  // ---- actions -------------------------------------------------------------------------------------------------

  /** The host may be acted on by this admin: never oneself; a team member only by an OWNER (D208's rule). */
  private async host(userId: string, ctx: AdminContext) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, status: true, role: true, adminPermissions: { select: { permission: true } } },
    });
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    if (user.id === ctx.userId) throw refused('You cannot do this to your own live.');
    const isAdmin = user.role === 'ADMIN' && user.adminPermissions.some((p) => isPanelRole(p.permission));
    if (isAdmin && !ctx.roles.includes('OWNER')) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    return user;
  }

  /** The end of a temporary action: `hours` from now or `until` (future, at most a year away). */
  private endOf(now: Date, body: ModerateBody): Date {
    const end =
      body.until !== undefined
        ? new Date(body.until)
        : body.hours !== undefined
          ? new Date(now.getTime() + body.hours * HOUR_MS)
          : null;
    if (!end || Number.isNaN(end.getTime()))
      throw AppException.validation([{ field: 'hours', issue: 'required' }]);
    if (end.getTime() <= now.getTime())
      throw AppException.validation([{ field: 'until', issue: 'invalid_value' }]);
    if (end.getTime() - now.getTime() > MAX_RESTRICTION_DAYS * 24 * HOUR_MS) {
      throw AppException.validation([{ field: 'until', issue: 'too_far' }]);
    }
    return end;
  }

  /** Closes the live's open reports (ACTIONED or DISMISSED) with the reason; returns how many. */
  private async closeReportsIn(
    tx: Tx,
    room: { id: string; hostUserId: string; startedAt: Date },
    status: 'ACTIONED' | 'DISMISSED',
    note: string,
    ctx: AdminContext,
    now: Date,
  ): Promise<number> {
    const closed = await tx.report.updateMany({
      where: { ...liveReportsWhere(room), status: 'OPEN' },
      data: { status, resolvedAt: now, resolvedById: ctx.userId, resolutionNote: note },
    });
    return closed.count;
  }

  /** `POST /admin/lives/{roomId}/moderate`: END / NO_LIVE / SUSPEND / DEVICE_BAN with a reason (§10.91.4). */
  async moderate(id: string, body: ModerateBody, ctx: AdminContext) {
    const room = await this.room(id);
    await this.host(room.hostUserId, ctx);
    const now = new Date();
    if (body.action === 'DEVICE_BAN') {
      if (!ctx.capabilities.includes('devices.ban')) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
      if (body.permanent !== true && body.hours === undefined && body.until === undefined) {
        throw AppException.validation([{ field: 'hours', issue: 'required' }]);
      }
    }
    const endsAt =
      body.action === 'NO_LIVE' || body.action === 'SUSPEND'
        ? this.endOf(now, body)
        : body.action === 'DEVICE_BAN' && body.permanent !== true
          ? this.endOf(now, body)
          : null;
    if (body.action === 'END' && room.status !== 'LIVE') throw refused('The live is not on air.');
    // The authenticator code again for a device ban (it shuts out every account on the device), before anything.
    if (body.action === 'DEVICE_BAN') await this.adminAuth.reauthenticate(ctx, body.totpCode);

    const by = viaOf(ctx);
    let ended: string[] = [];
    let result;
    try {
      result = await this.prisma.$transaction(async (tx) => {
        let devices: string[] = [];
        if (body.action === 'DEVICE_BAN') {
          devices = await devicesOfUserIn(tx, room.hostUserId);
          if (devices.length === 0) {
            throw new AppException(
              ErrorCode.ADMIN_ACTION_REFUSED,
              'No device id is known for this account (it signed up and signs in from the website or an app older than D223).',
              [{ field: 'device', issue: 'no_device' }],
            );
          }
        }
        ended =
          body.action === 'END'
            ? await this.rooms.endByAdminIn(tx, { roomId: room.id })
            : await this.rooms.endByAdminIn(tx, { hostUserId: room.hostUserId });
        if (body.action !== 'END') await this.rooms.releaseSeatsOfUserIn(tx, room.hostUserId);
        let restrictionId: string | null = null;
        if (body.action === 'NO_LIVE' || body.action === 'SUSPEND') {
          const out = await restrictIn(
            tx,
            room.hostUserId,
            body.action === 'NO_LIVE' ? 'NO_LIVE' : 'LOCK',
            endsAt!,
            body.reason,
            by,
            now,
            { notify: false },
          );
          restrictionId = out.restriction.id;
        }
        const reportsClosed = await this.closeReportsIn(tx, room, 'ACTIONED', body.reason, ctx, now);
        const action = await tx.liveModerationAction.create({
          data: {
            roomId: room.id,
            hostUserId: room.hostUserId,
            actorId: ctx.userId,
            kind: body.action,
            reason: body.reason,
            endsAt,
            restrictionId,
            endedLive: ended.length > 0,
            reportsClosed,
            devicesBanned: devices.length,
            createdAt: now,
          },
          select: { id: true },
        });
        let sessionsEnded = 0;
        if (body.action === 'DEVICE_BAN') {
          const out = await banDevicesIn(tx, {
            hashes: devices,
            reason: body.reason,
            endsAt,
            sourceUserId: room.hostUserId,
            liveModerationId: action.id,
            by,
            now,
          });
          sessionsEnded = out.sessionsEnded;
        }
        // One notification with the reason (push + in-app), whatever the action.
        await tx.notification.create({
          data: {
            recipientId: room.hostUserId,
            type: 'LIVE_MODERATED',
            liveModerationId: action.id,
            createdAt: now,
            updatedAt: now,
          },
        });
        await this.audit.recordIn(tx, {
          action: AuditAction.ADMIN_LIVE_MODERATE,
          actorUserId: ctx.userId,
          targetType: 'live_room',
          targetId: room.id,
          metadata: {
            kind: body.action,
            reason: body.reason,
            hostUserId: room.hostUserId,
            endsAt: endsAt ? endsAt.toISOString() : null,
            endedLive: ended.length > 0,
            reportsClosed,
            devicesBanned: devices.length,
            sessionsEnded,
            restrictionId,
            liveModerationId: action.id,
            before: room.status,
            after: ended.length > 0 ? 'ENDED' : room.status,
            via: 'panel',
          },
          ip: ctx.ip,
          requestId: ctx.requestId,
        });
        return {
          id: action.id,
          kind: body.action,
          reason: body.reason,
          endsAt: endsAt ? endsAt.toISOString() : null,
          endedLive: ended.length > 0,
          reportsClosed,
          devicesBanned: devices.length,
          sessionsEnded,
        };
      }, LIVE_TX_OPTIONS);
    } catch (err) {
      if (err instanceof AccountControlError) {
        if (err.issue === 'not_found') throw new AppException(ErrorCode.NOT_FOUND);
        throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, err.message, [
          { field: '', issue: err.issue },
        ]);
      }
      throw err;
    }
    for (const roomId of ended) {
      try {
        await this.media.closeMedia(roomId);
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err), roomId }, 'Media session could not be closed');
      }
    }
    return result;
  }

  /** `POST /admin/lives/{roomId}/reports/dismiss`: «تمت المراجعة — لا مخالفة» (DISMISSED, a note; audited). */
  async dismiss(id: string, reason: string, ctx: AdminContext) {
    const room = await this.room(id);
    const now = new Date();
    return this.prisma.$transaction(async (tx) => {
      const reportsClosed = await this.closeReportsIn(tx, room, 'DISMISSED', reason, ctx, now);
      if (reportsClosed === 0) throw refused('This live has no open reports.');
      const action = await tx.liveModerationAction.create({
        data: {
          roomId: room.id,
          hostUserId: room.hostUserId,
          actorId: ctx.userId,
          kind: 'DISMISS',
          reason,
          reportsClosed,
          createdAt: now,
        },
        select: { id: true },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.ADMIN_LIVE_REPORTS_DISMISS,
        actorUserId: ctx.userId,
        targetType: 'live_room',
        targetId: room.id,
        metadata: { reason, reportsClosed, liveModerationId: action.id, via: 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
      return { id: action.id, kind: 'DISMISS' as const, reason, reportsClosed };
    });
  }

  /** `GET /admin/lives/{roomId}/moderations`: what the team did on this live, newest first. */
  async history(id: string) {
    const room = await this.room(id);
    const rows = await this.prisma.liveModerationAction.findMany({
      where: { roomId: room.id },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: 50,
      select: {
        id: true,
        kind: true,
        reason: true,
        endsAt: true,
        endedLive: true,
        reportsClosed: true,
        devicesBanned: true,
        createdAt: true,
        actor: person,
      },
    });
    return {
      data: rows.map((r) => ({
        id: r.id,
        kind: r.kind,
        reason: r.reason,
        endsAt: r.endsAt?.toISOString() ?? null,
        endedLive: r.endedLive,
        reportsClosed: r.reportsClosed,
        devicesBanned: r.devicesBanned,
        createdAt: r.createdAt.toISOString(),
        actor: personOf(r.actor),
      })),
    };
  }

  // ---- device bans ---------------------------------------------------------------------------------------------

  /** `GET /admin/device-bans`: the table (status ACTIVE | LIFTED | EXPIRED, or all). */
  async deviceBans(
    q: TableQuery & { status?: 'ACTIVE' | 'LIFTED' | 'EXPIRED' | undefined },
    ctx: AdminContext,
  ) {
    const now = new Date();
    const text = q.q?.trim().toLowerCase().replace(/^@/, '');
    const where: Prisma.DeviceBanWhereInput = {
      AND: [
        q.status === 'ACTIVE'
          ? { liftedAt: null, OR: [{ endsAt: null }, { endsAt: { gt: now } }] }
          : q.status === 'LIFTED'
            ? { liftedAt: { not: null } }
            : q.status === 'EXPIRED'
              ? { liftedAt: null, endsAt: { lte: now } }
              : {},
        text ? { sourceUser: { profile: { username: { startsWith: text } } } } : {},
      ],
    };
    const [rows, total] = await Promise.all([
      this.prisma.deviceBan.findMany({
        where,
        orderBy: [{ createdAt: q.order }, { id: q.order }],
        ...window(q),
        select: {
          id: true,
          reason: true,
          createdAt: true,
          endsAt: true,
          liftedAt: true,
          liftReason: true,
          sourceUser: person,
          createdBy: person,
          liftedBy: person,
          liveModeration: { select: { roomId: true } },
        },
      }),
      this.prisma.deviceBan.count({ where }),
    ]);
    const data = rows.map((r) => ({
      id: r.id,
      status:
        r.liftedAt !== null
          ? ('LIFTED' as const)
          : r.endsAt !== null && r.endsAt <= now
            ? ('EXPIRED' as const)
            : ('ACTIVE' as const),
      reason: r.reason,
      createdAt: r.createdAt.toISOString(),
      endsAt: r.endsAt?.toISOString() ?? null,
      liftedAt: r.liftedAt?.toISOString() ?? null,
      liftReason: r.liftReason,
      account: personOf(r.sourceUser),
      createdBy: personOf(r.createdBy),
      liftedBy: personOf(r.liftedBy),
      liveRoomId: r.liveModeration?.roomId ?? null,
    }));
    return tableResult(
      this.audit,
      ctx,
      'device_bans',
      q,
      data,
      total,
      [
        ['id', (r) => r.id],
        ['account', (r) => r.account?.username ?? ''],
        ['status', (r) => r.status],
        ['reason', (r) => r.reason],
        ['created_at', (r) => r.createdAt],
        ['ends_at', (r) => r.endsAt ?? 'permanent'],
        ['created_by', (r) => r.createdBy?.username ?? ''],
      ],
      q.status ? { status: q.status } : {},
    );
  }

  /** `POST /admin/device-bans/{banId}/lift`: a reason; audited. */
  async liftDeviceBan(id: string, reason: string, ctx: AdminContext) {
    const now = new Date();
    try {
      await this.prisma.$transaction((tx) => liftDeviceBanIn(tx, id, reason, viaOf(ctx), now));
    } catch (err) {
      if (err instanceof DeviceBanError) throw refused(err.message);
      throw err;
    }
    return { id, status: 'LIFTED' as const, liftedAt: now.toISOString() };
  }
}
