import { Inject, Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { AdminPermission, Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { formatStaffId } from '../users/staff-ids.js';
import type { AdminContext } from './admin-auth.service.js';
import { isPanelRole } from './admin-permissions.js';
import { refused } from './admin-users.service.js';
import {
  nextSlots,
  SCHEDULE_ROLES,
  slotCovers,
  slotShapeIssue,
  slotsOverlap,
  weekClock,
  type ScheduleSlotLike,
} from './staff-schedule.js';

type Tx = Prisma.TransactionClient;

/** `AdminShiftPerson` (§10.176.6). */
export interface ShiftPersonDto {
  userId: string;
  staffId: string | null;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  roles: string[];
}

/** `AdminShiftNow`. */
export interface ShiftNowDto {
  timeZone: string;
  onShiftNow: ShiftPersonDto[];
  next: {
    person: ShiftPersonDto;
    startsAt: string;
    weekday: number;
    startMinute: number;
    endMinute: number;
  }[];
}

/** `AdminStaffSchedule`. */
export interface StaffScheduleDto {
  timeZone: string;
  now: { weekday: number; minute: number };
  slots: {
    id: string;
    person: ShiftPersonDto;
    weekday: number;
    startMinute: number;
    endMinute: number;
    onShiftNow: boolean;
  }[];
  shift: ShiftNowDto;
  me: { onShiftNow: boolean };
}

export interface SlotInput extends ScheduleSlotLike {
  readonly userId: string;
  readonly reason: string;
}

const SLOT_SELECT = {
  id: true,
  userId: true,
  weekday: true,
  startMinute: true,
  endMinute: true,
  user: {
    select: {
      id: true,
      role: true,
      status: true,
      profile: { select: { username: true, displayName: true, avatarUrl: true } },
      staffNumber: { select: { number: true } },
      adminPermissions: { select: { permission: true } },
    },
  },
} as const;

type SlotRow = Prisma.StaffScheduleSlotGetPayload<{ select: typeof SLOT_SELECT }>;

function personOf(u: SlotRow['user']): ShiftPersonDto {
  return {
    userId: u.id,
    staffId: u.staffNumber ? formatStaffId(u.staffNumber.number) : null,
    username: u.profile?.username ?? '',
    displayName: u.profile?.displayName ?? '',
    avatarUrl: u.profile?.avatarUrl ?? null,
    roles: u.adminPermissions.map((p) => p.permission as string).filter(isPanelRole).sort(),
  };
}

/** Still schedulable now: an ACTIVE admin holding MODERATION, SUPPORT or VIP_CARE. */
function schedulable(u: { role: string; status: string; adminPermissions: { permission: AdminPermission }[] }) {
  return (
    u.role === 'ADMIN' &&
    u.status === 'ACTIVE' &&
    u.adminPermissions.some((p) => (SCHEDULE_ROLES as readonly string[]).includes(p.permission))
  );
}

/**
 * v1.139-social (D387, CONVENTIONS §10.176.6): the 24/7 shift schedule «جدول المناوبات» — read by the people it schedules
 * (`staff.schedule.view`), set by the OWNER (`staff.schedule.manage`) with a reason, each change audited. Times are in
 * `LIVE_RANKINGS_TIME_ZONE` (D99). A person who no longer holds a schedulable role is left out (their slots are also
 * removed when the role is revoked, `admin-roles.ts`).
 */
@Injectable()
export class StaffScheduleService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  get zone(): string {
    return this.config.live.rankingsTimeZone;
  }

  private async rows(db: Tx | PrismaService = this.prisma): Promise<SlotRow[]> {
    const rows = await db.staffScheduleSlot.findMany({
      select: SLOT_SELECT,
      orderBy: [{ weekday: 'asc' }, { startMinute: 'asc' }, { id: 'asc' }],
    });
    return rows.filter((r) => schedulable(r.user));
  }

  /** Who is on shift now and whose slots start next (the role homes and the schedule). */
  shiftOf(rows: readonly SlotRow[], now: Date): ShiftNowDto {
    const at = weekClock(now, this.zone);
    const on = new Map<string, ShiftPersonDto>();
    for (const r of rows) if (slotCovers(r, at)) on.set(r.userId, personOf(r.user));
    return {
      timeZone: this.zone,
      onShiftNow: [...on.values()],
      next: nextSlots(rows, at).map(({ slot, inMinutes }) => {
        // The start instant: now, back to the start of the current minute, plus the minutes until the slot starts.
        const base = now.getTime() - (now.getTime() % 60_000);
        return {
          person: personOf(slot.user),
          startsAt: new Date(base + inMinutes * 60_000).toISOString(),
          weekday: slot.weekday,
          startMinute: slot.startMinute,
          endMinute: slot.endMinute,
        };
      }),
    };
  }

  async shiftNow(): Promise<ShiftNowDto> {
    return this.shiftOf(await this.rows(), this.clock.now());
  }

  /** `getAdminStaffSchedule`. */
  async schedule(ctx: AdminContext, db: Tx | PrismaService = this.prisma): Promise<StaffScheduleDto> {
    const now = this.clock.now();
    const rows = await this.rows(db);
    const at = weekClock(now, this.zone);
    return {
      timeZone: this.zone,
      now: at,
      slots: rows.map((r) => ({
        id: r.id,
        person: personOf(r.user),
        weekday: r.weekday,
        startMinute: r.startMinute,
        endMinute: r.endMinute,
        onShiftNow: slotCovers(r, at),
      })),
      shift: this.shiftOf(rows, now),
      me: { onShiftNow: rows.some((r) => r.userId === ctx.userId && slotCovers(r, at)) },
    };
  }

  /** The person (locked) and the rules of a slot: the shape, a schedulable role, no overlap with their other slots. */
  private async check(tx: Tx, input: SlotInput, exceptId: string | null): Promise<void> {
    const shape = slotShapeIssue(input);
    if (shape) {
      throw new AppException(ErrorCode.VALIDATION_FAILED, undefined, [{ field: shape, issue: 'invalid_value' }]);
    }
    // One change per person at a time (the overlap check below reads their slots).
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:staff-schedule'), hashtext(${input.userId}))`;
    const user = await tx.user.findUnique({
      where: { id: input.userId },
      select: { role: true, status: true, adminPermissions: { select: { permission: true } } },
    });
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    if (!schedulable(user)) {
      throw refused('Only an active MODERATION, SUPPORT or VIP_CARE staff member can be scheduled.', 'schedule_role', 'rule');
    }
    const others = await tx.staffScheduleSlot.findMany({
      where: { userId: input.userId, weekday: input.weekday, ...(exceptId ? { id: { not: exceptId } } : {}) },
      select: { weekday: true, startMinute: true, endMinute: true },
    });
    if (others.some((o) => slotsOverlap(o, input))) {
      throw refused('Another slot of this person overlaps.', 'schedule_overlap', 'rule');
    }
  }

  private auditIn(tx: Tx, ctx: AdminContext, action: AuditAction, slotId: string, metadata: Record<string, unknown>) {
    return this.audit.recordIn(tx, {
      action,
      actorUserId: ctx.userId,
      targetType: 'staff_schedule_slot',
      targetId: slotId,
      metadata: { ...metadata, via: ctx.via ?? 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
  }

  /** `createAdminStaffScheduleSlot`. */
  async create(input: SlotInput, ctx: AdminContext): Promise<StaffScheduleDto> {
    return this.prisma.$transaction(async (tx) => {
      await this.check(tx, input, null);
      const slot = await tx.staffScheduleSlot.create({
        data: {
          userId: input.userId,
          weekday: input.weekday,
          startMinute: input.startMinute,
          endMinute: input.endMinute,
          createdById: ctx.userId,
        },
        select: { id: true },
      });
      await this.auditIn(tx, ctx, AuditAction.STAFF_SCHEDULE_CREATE, slot.id, {
        userId: input.userId,
        weekday: input.weekday,
        startMinute: input.startMinute,
        endMinute: input.endMinute,
        timeZone: this.zone,
        reason: input.reason,
      });
      return this.schedule(ctx, tx);
    });
  }

  /** `updateAdminStaffScheduleSlot`. */
  async update(slotId: string, input: SlotInput, ctx: AdminContext): Promise<StaffScheduleDto> {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.staffScheduleSlot.findUnique({ where: { id: slotId } });
      if (!before) throw new AppException(ErrorCode.NOT_FOUND);
      await this.check(tx, input, slotId);
      await tx.staffScheduleSlot.update({
        where: { id: slotId },
        data: {
          userId: input.userId,
          weekday: input.weekday,
          startMinute: input.startMinute,
          endMinute: input.endMinute,
        },
      });
      const shape = (s: SlotInput | typeof before) => ({
        userId: s.userId,
        weekday: s.weekday,
        startMinute: s.startMinute,
        endMinute: s.endMinute,
      });
      await this.auditIn(tx, ctx, AuditAction.STAFF_SCHEDULE_UPDATE, slotId, {
        before: shape(before),
        after: shape(input),
        timeZone: this.zone,
        reason: input.reason,
      });
      return this.schedule(ctx, tx);
    });
  }

  /** `deleteAdminStaffScheduleSlot`. */
  async remove(slotId: string, reason: string, ctx: AdminContext): Promise<StaffScheduleDto> {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.staffScheduleSlot.findUnique({ where: { id: slotId } });
      if (!before) throw new AppException(ErrorCode.NOT_FOUND);
      await tx.staffScheduleSlot.delete({ where: { id: slotId } });
      await this.auditIn(tx, ctx, AuditAction.STAFF_SCHEDULE_DELETE, slotId, {
        userId: before.userId,
        weekday: before.weekday,
        startMinute: before.startMinute,
        endMinute: before.endMinute,
        timeZone: this.zone,
        reason,
      });
      return this.schedule(ctx, tx);
    });
  }
}
