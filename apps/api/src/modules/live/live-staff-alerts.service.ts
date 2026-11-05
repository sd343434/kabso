import { Injectable, Logger } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { Clock } from '../../common/time/clock.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { ACT_ROLES, LiveStaffAssignmentService, WATCH_ROLES } from './live-staff-assignment.service.js';
import { regionOfCountry } from './staff-regions.js';

/** How the recipients of a staff alert were chosen (audit metadata). */
export type StaffAlertRoute = 'assigned' | 'actors' | 'owners';

export interface StaffAlertResult {
  roomId: string;
  route: StaffAlertRoute;
  recipients: string[];
}

/**
 * v1.68-live (D273, CONVENTIONS §10.96.8; owner: «البلاغات تصل لهاتف الموظف المسؤول»): a report on a live — the live
 * itself, its host (since it started), a message of its chat, or a user reported inside it — alerts the staff member
 * responsible for that live on their app account: one in-app `LIVE_STAFF_REPORT` row per live and staff member (a new
 * report on the same live while it is unread brings it back to the top and pushes it again), which the push
 * dispatcher sends («بلاغ جديد على بث» and the host's name — never the reporter or the reason).
 *
 * Who: the live's assigned staff member when they are on shift; else an assignment pass runs first (D260: a reported
 * live goes to OWNER / MODERATION when one is on shift) and its result decides; still nobody → every OWNER /
 * MODERATION on shift; none → every OWNER (ACTIVE ADMIN). Never the reporter, never the live's own host. Audited
 * `live.staff_report.alert` (no actor: the service decides). Best effort: never fails the report.
 */
@Injectable()
export class LiveStaffAlertsService {
  private readonly logger = new Logger(LiveStaffAlertsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    private readonly assignments: LiveStaffAssignmentService,
  ) {}

  /** The LIVE room a report is about, if any. */
  async liveOf(reportId: string): Promise<{ id: string; hostUserId: string } | null> {
    const report = await this.prisma.report.findUnique({
      where: { id: reportId },
      select: {
        targetType: true,
        targetLiveRoomId: true,
        targetUserId: true,
        contextLiveRoomId: true,
        targetLiveChatMessage: { select: { roomId: true } },
      },
    });
    if (!report) return null;
    let roomId =
      report.targetLiveRoomId ?? report.contextLiveRoomId ?? report.targetLiveChatMessage?.roomId ?? null;
    if (roomId === null && report.targetType === 'USER' && report.targetUserId !== null) {
      // The host reported as a user while on air (older apps report the host).
      roomId =
        (
          await this.prisma.liveRoom.findFirst({
            where: { hostUserId: report.targetUserId, status: 'LIVE' },
            select: { id: true },
          })
        )?.id ?? null;
    }
    if (roomId === null) return null;
    return this.prisma.liveRoom.findFirst({
      where: { id: roomId, status: 'LIVE' },
      select: { id: true, hostUserId: true },
    });
  }

  private async onShiftHolder(roomId: string): Promise<string | null> {
    const a = await this.prisma.liveRoomAssignment.findUnique({
      where: { roomId },
      select: {
        adminId: true,
        admin: {
          select: {
            role: true,
            status: true,
            adminShift: { select: { onShift: true } },
            adminPermissions: { select: { permission: true } },
          },
        },
      },
    });
    if (!a) return null;
    const u = a.admin;
    const watch = u.adminPermissions.some((p) => (WATCH_ROLES as readonly string[]).includes(p.permission));
    return u.role === 'ADMIN' && u.status === 'ACTIVE' && u.adminShift?.onShift === true && watch
      ? a.adminId
      : null;
  }

  /** Alerts the staff about a new report (see the class). Returns who was alerted, or null (not about a live). */
  async onReport(reportId: string, reporterId: string): Promise<StaffAlertResult | null> {
    const room = await this.liveOf(reportId);
    if (!room) return null;
    let route: StaffAlertRoute = 'assigned';
    let holder = await this.onShiftHolder(room.id);
    if (holder === null) {
      await this.assignments.assignPending('reported');
      holder = await this.onShiftHolder(room.id);
    }
    let recipients: string[];
    if (holder !== null) {
      recipients = [holder];
    } else {
      route = 'actors';
      const actors = await this.prisma.user.findMany({
        where: {
          role: 'ADMIN',
          status: 'ACTIVE',
          adminShift: { onShift: true },
          adminPermissions: { some: { permission: { in: [...ACT_ROLES] } } },
        },
        select: { id: true, staffRegions: { select: { region: true } } },
      });
      // v1.72-live (D283, §10.96.11): those whose region covers the host's country, when any; else all of them.
      const withRegions = actors.filter((a) => (a.staffRegions?.length ?? 0) > 0);
      const host =
        withRegions.length === 0
          ? null
          : await this.prisma.userProfile.findUnique({
              where: { userId: room.hostUserId },
              select: { countryCode: true },
            });
      const region = regionOfCountry(host?.countryCode);
      const local =
        region === null ? [] : withRegions.filter((a) => a.staffRegions.some((r) => r.region === region));
      recipients = (local.length > 0 ? local : actors).map((u) => u.id);
      if (recipients.length === 0) {
        route = 'owners';
        recipients = (
          await this.prisma.user.findMany({
            where: { role: 'ADMIN', status: 'ACTIVE', adminPermissions: { some: { permission: 'OWNER' } } },
            select: { id: true },
          })
        ).map((u) => u.id);
      }
    }
    recipients = recipients.filter((id) => id !== reporterId && id !== room.hostUserId);
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      for (const recipientId of recipients) {
        const groupKey = `LIVE_STAFF_REPORT:${room.id}`;
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:notif'), hashtext(${`${recipientId}:${groupKey}`}))`;
        const open = await tx.notification.findFirst({
          where: { recipientId, groupKey, readAt: null },
          select: { id: true },
        });
        if (open) {
          await tx.notification.update({ where: { id: open.id }, data: { updatedAt: now } });
        } else {
          await tx.notification.create({
            data: {
              recipientId,
              type: 'LIVE_STAFF_REPORT',
              liveRoomId: room.id,
              groupKey,
              createdAt: now,
              updatedAt: now,
            },
          });
        }
      }
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_STAFF_REPORT_ALERT,
        actorUserId: null,
        targetType: 'live_room',
        targetId: room.id,
        metadata: { reportId, recipients, route },
      });
    });
    return { roomId: room.id, route, recipients };
  }

  /** {@link onReport} after the reply (never fails the caller). */
  afterReport(reportId: string, reporterId: string): Promise<void> {
    return this.onReport(reportId, reporterId).then(
      () => undefined,
      (err: unknown) => {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not alert the staff about a live report');
      },
    );
  }
}
