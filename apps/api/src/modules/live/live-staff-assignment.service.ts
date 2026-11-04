import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { AuditAction, AuditService, type AuditEntry } from '../../common/audit/audit.service.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { AdminPermission } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { openLiveReportsByRoom } from './live-reports.js';

/** v1.64-live (D260, §10.96): the panel roles that watch lives (SUPPORT watch-only, D250b). FINANCE never. */
export const WATCH_ROLES = ['OWNER', 'MODERATION', 'SUPPORT'] as const satisfies readonly AdminPermission[];
/** The roles that may act on a reported live (a reported live goes to one of them when any is on shift). */
export const ACT_ROLES = ['OWNER', 'MODERATION'] as const satisfies readonly AdminPermission[];

/** Why an assignment pass ran (audit metadata). */
export type AssignReason = 'live_start' | 'shift_on' | 'shift_off' | 'sweep' | 'reported';

interface StaffRow {
  id: string;
  since: Date;
  canAct: boolean;
  load: number;
  lastAssignedAt: number;
}

export interface AssignmentResult {
  assigned: { roomId: string; adminId: string; previousAdminId: string | null; reports: number }[];
  released: number;
}

/**
 * v1.64-live (D260, CONVENTIONS §10.96; owner 2026-11-04: «توزيع تلقائي لكل بث جديد … حسابات موظفين حقيقية»): every
 * LIVE room is assigned to one panel staff member on shift (OWNER / MODERATION / SUPPORT), spread by current load
 * (fewest assigned lives first, then the one assigned least recently), the reported lives first and to a staff
 * member who may act on them (OWNER / MODERATION) whenever one is on shift. An assignment ends with the live, and is
 * handed on when its staff member goes off shift or loses the panel role. One pass at a time (an advisory lock);
 * each new assignment is audited (`admin.live.assign`, no actor: the service decides).
 */
@Injectable()
export class LiveStaffAssignmentService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(LiveStaffAssignmentService.name);
  private timer: NodeJS.Timeout | undefined;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.live.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  /** The sweeper's cadence: newly reported lives move to a staff member who may act, ended lives are released. */
  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.assignPending('sweep')
        .catch((err: unknown) => {
          this.logger.warn({ error: safeErrorLog(err) }, 'Live staff assignment failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.live.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }

  /** Best effort after a live starts (never fails the caller). */
  afterLiveStart(): void {
    void this.assignPending('live_start').catch((err: unknown) => {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not assign a new live to a staff member');
    });
  }

  /** One assignment pass (see the class). Idempotent. */
  async assignPending(reason: AssignReason): Promise<AssignmentResult> {
    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:live-staff-assignment'))`;
      // 1. Release: ended lives, staff off shift or no longer watch staff.
      const released = await tx.$executeRaw`
        DELETE FROM live_room_assignments a
         WHERE NOT EXISTS (SELECT 1 FROM live_rooms r WHERE r.id = a.room_id AND r.status = 'LIVE'::live_room_status)
            OR NOT EXISTS (
                 SELECT 1 FROM admin_shifts s JOIN users u ON u.id = s.user_id
                  WHERE s.user_id = a.admin_id AND s.on_shift AND u.role = 'ADMIN'::user_role
                    AND u.status = 'ACTIVE'::user_status
                    AND EXISTS (SELECT 1 FROM user_admin_permissions p WHERE p.user_id = u.id
                                   AND p.permission IN ('OWNER'::admin_permission, 'MODERATION'::admin_permission, 'SUPPORT'::admin_permission)))`;
      // 2. The staff on shift and their load.
      const staffRows = await tx.adminShift.findMany({
        where: {
          onShift: true,
          user: {
            role: 'ADMIN',
            status: 'ACTIVE',
            adminPermissions: { some: { permission: { in: [...WATCH_ROLES] } } },
          },
        },
        select: {
          userId: true,
          since: true,
          user: {
            select: {
              adminPermissions: { select: { permission: true } },
              liveAssignments: { select: { roomId: true, assignedAt: true } },
            },
          },
        },
      });
      const staff: StaffRow[] = staffRows.map((s) => ({
        id: s.userId,
        since: s.since,
        canAct: s.user.adminPermissions.some((p) => (ACT_ROLES as readonly string[]).includes(p.permission)),
        load: s.user.liveAssignments.length,
        lastAssignedAt: Math.max(0, ...s.user.liveAssignments.map((a) => a.assignedAt.getTime())),
      }));
      const result: AssignmentResult = { assigned: [], released };
      if (staff.length === 0) return result;
      const byId = new Map(staff.map((s) => [s.id, s]));
      const anyActor = staff.some((s) => s.canAct);

      const lives = await tx.liveRoom.findMany({
        where: { status: 'LIVE' },
        select: { id: true, hostUserId: true, startedAt: true, assignment: { select: { adminId: true } } },
      });
      const reports = await openLiveReportsByRoom(tx);
      // 3. A reported live watched by someone who may not act moves to someone who may (when one is on shift).
      const pending: { id: string; hostUserId: string; startedAt: Date; previous: string | null }[] = [];
      for (const live of lives) {
        const current = live.assignment?.adminId ?? null;
        if (current === null) {
          pending.push({ ...live, previous: null });
          continue;
        }
        const holder = byId.get(current);
        if ((reports.get(live.id) ?? 0) > 0 && anyActor && holder && !holder.canAct) {
          await tx.liveRoomAssignment.delete({ where: { roomId: live.id } });
          holder.load -= 1;
          pending.push({ ...live, previous: current });
        }
      }
      // 4. Reported lives first (most reports), then the oldest live.
      pending.sort(
        (a, b) =>
          (reports.get(b.id) ?? 0) - (reports.get(a.id) ?? 0) ||
          a.startedAt.getTime() - b.startedAt.getTime() ||
          a.id.localeCompare(b.id),
      );
      const now = this.clock.now();
      let tick = 0;
      const entries: AuditEntry[] = [];
      for (const live of pending) {
        const n = reports.get(live.id) ?? 0;
        // Never one's own live; a reported live to someone who may act when any is on shift.
        const pool = staff.filter((s) => s.id !== live.hostUserId && (n === 0 || !anyActor || s.canAct));
        const pick = pool.sort(
          (a, b) =>
            a.load - b.load ||
            a.lastAssignedAt - b.lastAssignedAt ||
            a.since.getTime() - b.since.getTime() ||
            a.id.localeCompare(b.id),
        )[0];
        if (!pick) continue;
        // Distinct times so the round-robin order holds within one pass.
        const at = new Date(now.getTime() + tick);
        tick += 1;
        await tx.liveRoomAssignment.create({ data: { roomId: live.id, adminId: pick.id, assignedAt: at } });
        pick.load += 1;
        pick.lastAssignedAt = at.getTime();
        result.assigned.push({
          roomId: live.id,
          adminId: pick.id,
          previousAdminId: live.previous,
          reports: n,
        });
        entries.push({
          action: AuditAction.ADMIN_LIVE_ASSIGN,
          actorUserId: null,
          targetType: 'live_room',
          targetId: live.id,
          metadata: {
            adminId: pick.id,
            reason: live.previous !== null ? 'reported' : reason,
            reports: n,
            ...(live.previous !== null ? { previousAdminId: live.previous } : {}),
          },
        });
      }
      await this.audit.recordManyIn(tx, entries);
      return result;
    });
  }
}
