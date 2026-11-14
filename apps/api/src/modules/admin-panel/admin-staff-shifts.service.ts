import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { Clock } from '../../common/time/clock.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import {
  LiveStaffAssignmentService,
  WATCH_ROLES,
  type StaffWorkTrigger,
} from '../live/live-staff-assignment.service.js';
import type { AdminContext } from './admin-auth.service.js';
import { isPanelRole } from './admin-permissions.js';

/** `AdminShift` (D260): the signed-in staff member's shift and the lives assigned to them now. */
export interface AdminShiftDto {
  onShift: boolean;
  since: string | null;
  assignedLives: number;
}

/**
 * v1.64-live (D260, CONVENTIONS §10.96): the shift «في المناوبة» of the panel's watch staff (OWNER / MODERATION /
 * SUPPORT) — switched by each staff member for themself (audited); going on shift takes a share of the lives not yet
 * assigned, going off shift hands one's lives to the others. OWNER sees everyone's shift and load.
 */
@Injectable()
export class AdminStaffShiftsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    private readonly assignments: LiveStaffAssignmentService,
  ) {}

  /** `GET /admin/me/shift`. */
  async mine(ctx: AdminContext): Promise<AdminShiftDto> {
    const [shift, assignedLives] = await Promise.all([
      this.prisma.adminShift.findUnique({ where: { userId: ctx.userId } }),
      this.prisma.liveRoomAssignment.count({
        where: { adminId: ctx.userId, room: { status: 'LIVE' } },
      }),
    ]);
    return {
      onShift: shift?.onShift ?? false,
      since: shift ? shift.since.toISOString() : null,
      assignedLives,
    };
  }

  /** `PUT /admin/me/shift`: idempotent; a change is audited and runs an assignment pass. */
  async set(onShift: boolean, ctx: AdminContext): Promise<AdminShiftDto> {
    const before = await this.prisma.adminShift.findUnique({ where: { userId: ctx.userId } });
    // v1.76-live (D286, §10.96.14): a switch by hand is `panel` / `app` (never goes off by itself); turning ON by hand
    // a shift that staff work had switched on makes it a manual one (no audit: the shift itself does not change).
    const via = ctx.via ?? 'panel';
    if (before?.onShift === true && onShift && before.startedVia === 'auto') {
      await this.prisma.adminShift.updateMany({
        where: { userId: ctx.userId, onShift: true },
        data: { startedVia: via, lastActivityAt: this.clock.now() },
      });
    }
    if ((before?.onShift ?? false) !== onShift) {
      const held = await this.prisma.liveRoomAssignment.count({ where: { adminId: ctx.userId } });
      const now = this.clock.now();
      await this.prisma.adminShift.upsert({
        where: { userId: ctx.userId },
        create: { userId: ctx.userId, onShift, since: now, startedVia: via, lastActivityAt: now },
        update: { onShift, since: now, startedVia: via, lastActivityAt: now },
      });
      const pass = await this.assignments.assignPending(onShift ? 'shift_on' : 'shift_off');
      await this.audit.record({
        action: onShift ? AuditAction.ADMIN_SHIFT_ON : AuditAction.ADMIN_SHIFT_OFF,
        actorUserId: ctx.userId,
        targetType: 'user',
        targetId: ctx.userId,
        metadata: onShift
          ? {
              assigned: pass.assigned.filter((a) => a.adminId === ctx.userId).length,
              via: ctx.via ?? 'panel',
            }
          : { released: held, via: ctx.via ?? 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    }
    return this.mine(ctx);
  }

  /**
   * v1.76-live (D286, §10.96.14): staff work in the panel — a visible or hidden WATCH of a live, «بثوثي»
   * (`listAdminLives?assigned=me`), a live's reports, an action on a live (moderate, dismiss, end) — switches the
   * shift on like the app's (best effort; never fails the request). Audited `admin.shift.on` {via: auto, from: panel}.
   */
  async work(ctx: AdminContext, trigger: StaffWorkTrigger): Promise<void> {
    await this.assignments.staffWorkBestEffort(ctx.userId, trigger, ctx.via === 'app' ? 'app' : 'panel', {
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
  }

  /** `GET /admin/shifts` (OWNER): every watch staff member, on shift first, with their load. */
  async list() {
    const people = await this.prisma.user.findMany({
      where: {
        role: 'ADMIN',
        status: 'ACTIVE',
        adminPermissions: { some: { permission: { in: [...WATCH_ROLES] } } },
      },
      select: {
        id: true,
        profile: { select: { username: true, displayName: true, avatarUrl: true } },
        adminPermissions: { select: { permission: true } },
        adminShift: { select: { onShift: true, since: true } },
        _count: { select: { liveAssignments: { where: { room: { status: 'LIVE' } } } } },
      },
    });
    const data = people.map((u) => ({
      user: {
        id: u.id,
        username: u.profile?.username ?? '',
        displayName: u.profile?.displayName ?? '',
        avatarUrl: u.profile?.avatarUrl ?? null,
      },
      roles: u.adminPermissions
        .map((p) => p.permission)
        .filter(isPanelRole)
        .sort(),
      onShift: u.adminShift?.onShift ?? false,
      since: u.adminShift ? u.adminShift.since.toISOString() : null,
      assignedLives: u._count.liveAssignments,
    }));
    data.sort(
      (a, b) =>
        Number(b.onShift) - Number(a.onShift) ||
        b.assignedLives - a.assignedLives ||
        a.user.username.localeCompare(b.user.username),
    );
    return {
      data,
      onShift: data.filter((d) => d.onShift).length,
      unassignedLives: await this.prisma.liveRoom.count({ where: { status: 'LIVE', assignment: null } }),
    };
  }
}
