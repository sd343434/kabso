import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { AuditAction, AuditService, type AuditEntry } from '../../common/audit/audit.service.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { AdminPermission } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { openLiveReportsByRoom } from './live-reports.js';
import { REGION_STAFF_ROLES } from './live-staff.js';
import { isStaffRegion, regionOfCountry, type StaffRegion } from './staff-regions.js';

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
  /** v1.72-live (D283): the regions this MODERATION / SUPPORT staff member is responsible for. */
  regions: ReadonlySet<StaffRegion>;
}

/**
 * v1.72-live (D283, CONVENTIONS §10.96.11): the staff a live goes to, from `pool` (already filtered by the D260 rules:
 * never one's own live, a reported live to someone who may act): those whose region covers the host's country first;
 * nobody there (or a country in no region) → the whole pool. Then the D260 load order (fewest lives, assigned least
 * recently, earliest shift). Exported for the unit tests.
 */
export function pickStaffFor<T extends Omit<StaffRow, 'canAct'>>(
  pool: readonly T[],
  hostCountry: string | null,
): T | undefined {
  const region = regionOfCountry(hostCountry);
  const local = region === null ? [] : pool.filter((s) => s.regions.has(region));
  return [...(local.length > 0 ? local : pool)].sort(
    (a, b) =>
      a.load - b.load ||
      a.lastAssignedAt - b.lastAssignedAt ||
      a.since.getTime() - b.since.getTime() ||
      a.id.localeCompare(b.id),
  )[0];
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
      // v1.76-live (D286): idle automatic shifts go off first, so the sweep hands their lives on.
      this.inFlight = this.offIdle()
        .catch((err: unknown) => {
          this.logger.warn({ error: safeErrorLog(err) }, 'Automatic shift switch-off failed');
        })
        .then(() => this.assignPending('sweep'))
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
              staffRegions: { select: { region: true } },
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
        // Regions count only while the person holds MODERATION or SUPPORT (an OWNER-only account has none).
        regions: new Set(
          s.user.adminPermissions.some((p) =>
            (REGION_STAFF_ROLES as readonly string[]).includes(p.permission),
          )
            ? s.user.staffRegions.map((r) => r.region).filter(isStaffRegion)
            : [],
        ),
      }));
      const result: AssignmentResult = { assigned: [], released };
      if (staff.length === 0) return result;
      const byId = new Map(staff.map((s) => [s.id, s]));
      const anyActor = staff.some((s) => s.canAct);

      const lives = (
        await tx.liveRoom.findMany({
          where: { status: 'LIVE' },
          select: {
            id: true,
            hostUserId: true,
            startedAt: true,
            assignment: { select: { adminId: true } },
            host: { select: { profile: { select: { countryCode: true } } } },
          },
        })
      ).map(({ host, ...live }) => ({ ...live, hostCountry: host.profile?.countryCode ?? null }));
      const reports = await openLiveReportsByRoom(tx);
      // 3. A reported live watched by someone who may not act moves to someone who may (when one is on shift).
      const pending: {
        id: string;
        hostUserId: string;
        hostCountry: string | null;
        startedAt: Date;
        previous: string | null;
      }[] = [];
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
        // v1.72-live (D283): the host's region first, then by load.
        const pick = pickStaffFor(pool, live.hostCountry);
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

  // ---- v1.76-live (D286, §10.96.14): the automatic shift ----------------------------------------------------------

  /**
   * Staff work by `userId` (owner: «عندما يقوم المشرف بالعمل يتم تفعيل زر مناوبة»): entering a live as staff (visible
   * or hidden, app or panel), a staff tool, or «بثوثي». A watch staff member (OWNER / MODERATION / SUPPORT — never
   * FINANCE or BD) who is off shift goes ON shift (`started_via = auto`), an assignment pass runs at once (reason
   * `shift_on`, as by hand) and it is audited `admin.shift.on` {assigned, via: auto, trigger, from}. On shift
   * already: only the activity time moves (at most once a minute). Returns whether the shift was switched on.
   * Idempotent under concurrency (a conditional write: one caller wins, one audit row).
   */
  async staffWork(
    userId: string,
    trigger: StaffWorkTrigger,
    from: 'app' | 'panel',
    meta: { ip?: string | null | undefined; requestId?: string | null | undefined } = {},
  ): Promise<boolean> {
    const now = this.clock.now();
    const switched = await this.prisma.$transaction(async (tx) => {
      const watch = await tx.userAdminPermission.count({
        where: {
          userId,
          permission: { in: [...WATCH_ROLES] },
          user: { role: 'ADMIN', status: 'ACTIVE' },
        },
      });
      if (watch === 0) return false;
      const row = await tx.adminShift.findUnique({
        where: { userId },
        select: { onShift: true, lastActivityAt: true },
      });
      if (row?.onShift) {
        const last = row.lastActivityAt?.getTime() ?? 0;
        if (now.getTime() - last >= ACTIVITY_WRITE_EVERY_MS) {
          await tx.adminShift.updateMany({ where: { userId, onShift: true }, data: { lastActivityAt: now } });
        }
        return false;
      }
      if (row) {
        const won = await tx.adminShift.updateMany({
          where: { userId, onShift: false },
          data: { onShift: true, since: now, startedVia: 'auto', lastActivityAt: now },
        });
        return won.count === 1;
      }
      const created = await tx.$executeRaw`
        INSERT INTO admin_shifts (user_id, on_shift, since, updated_at, started_via, last_activity_at)
        VALUES (${userId}::uuid, true, ${now}, ${now}, 'auto', ${now})
        ON CONFLICT (user_id) DO NOTHING`;
      return created === 1;
    });
    if (!switched) return false;
    const pass = await this.assignPending('shift_on');
    await this.audit.record({
      action: AuditAction.ADMIN_SHIFT_ON,
      actorUserId: userId,
      targetType: 'user',
      targetId: userId,
      metadata: {
        assigned: pass.assigned.filter((a) => a.adminId === userId).length,
        via: 'auto',
        trigger,
        from,
      },
      ip: meta.ip ?? null,
      requestId: meta.requestId ?? null,
    });
    return true;
  }

  /** {@link staffWork} that never fails its caller (a live join must not fail on the shift). */
  async staffWorkBestEffort(
    userId: string,
    trigger: StaffWorkTrigger,
    from: 'app' | 'panel',
    meta: { ip?: string | null | undefined; requestId?: string | null | undefined } = {},
  ): Promise<void> {
    try {
      await this.staffWork(userId, trigger, from, meta);
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not record staff work for the automatic shift');
    }
  }

  /**
   * The idle switch-off (at the sweeper's cadence): a shift switched on AUTOMATICALLY goes off after
   * `STAFF_SHIFT_IDLE_OFF_SECONDS` (2 h) without staff work, unless the person is in a live as visible staff right now
   * (a `live_room_staff_watchers` row). Audited `admin.shift.off` {released, via: auto, reason: idle, idleSeconds};
   * their lives are handed on by an assignment pass (reason `shift_off`). A shift switched on by hand (`panel` /
   * `app`) never goes off by itself. Returns the ids switched off.
   */
  async offIdle(): Promise<string[]> {
    const idle = this.config.adminPanel.staffShiftIdleOffSeconds;
    if (idle <= 0) return [];
    const now = this.clock.now();
    const cutoff = new Date(now.getTime() - idle * 1000);
    const rows = await this.prisma.$queryRaw<{ user_id: string; released: number }[]>`
      WITH off AS (
        UPDATE admin_shifts s SET on_shift = false, since = ${now}, updated_at = ${now}
         WHERE s.on_shift AND s.started_via = 'auto'
           AND COALESCE(s.last_activity_at, s.since) < ${cutoff}
           AND NOT EXISTS (SELECT 1 FROM live_room_staff_watchers w WHERE w.admin_id = s.user_id)
        RETURNING s.user_id)
      SELECT off.user_id::text AS user_id,
             (SELECT COUNT(*)::int FROM live_room_assignments a WHERE a.admin_id = off.user_id) AS released
        FROM off`;
    if (rows.length === 0) return [];
    await this.assignPending('shift_off');
    await this.prisma.$transaction(async (tx) =>
      this.audit.recordManyIn(
        tx,
        rows.map((r) => ({
          action: AuditAction.ADMIN_SHIFT_OFF,
          actorUserId: r.user_id,
          targetType: 'user',
          targetId: r.user_id,
          metadata: { released: r.released, via: 'auto', reason: 'idle', idleSeconds: idle },
        })),
      ),
    );
    return rows.map((r) => r.user_id);
  }
}

/** v1.76-live (D286): what counted as staff work (audit metadata `trigger`). */
export type StaffWorkTrigger = 'live_join' | 'staff_tool' | 'my_lives';

/** The activity time is written at most this often for someone already on shift. */
const ACTIVITY_WRITE_EVERY_MS = 60_000;
