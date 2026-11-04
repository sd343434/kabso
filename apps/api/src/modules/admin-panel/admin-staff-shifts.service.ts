import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { Clock } from '../../common/time/clock.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { LiveStaffAssignmentService, WATCH_ROLES } from '../live/live-staff-assignment.service.js';
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
    if ((before?.onShift ?? false) !== onShift) {
      const held = await this.prisma.liveRoomAssignment.count({ where: { adminId: ctx.userId } });
      await this.prisma.adminShift.upsert({
        where: { userId: ctx.userId },
        create: { userId: ctx.userId, onShift, since: this.clock.now() },
        update: { onShift, since: this.clock.now() },
      });
      const pass = await this.assignments.assignPending(onShift ? 'shift_on' : 'shift_off');
      await this.audit.record({
        action: onShift ? AuditAction.ADMIN_SHIFT_ON : AuditAction.ADMIN_SHIFT_OFF,
        actorUserId: ctx.userId,
        targetType: 'user',
        targetId: ctx.userId,
        metadata: onShift
          ? { assigned: pass.assigned.filter((a) => a.adminId === ctx.userId).length, via: 'panel' }
          : { released: held, via: 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    }
    return this.mine(ctx);
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
