import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { normalizeDisplayName, textHygieneIssue } from '../users/display-name.js';
import type { RequestMeta } from './live-rooms.service.js';

/** At most this many upcoming slots per host (CONVENTIONS §10.16). */
export const LIVE_SCHEDULE_MAX = 10;
/** A slot's title: 1–60 code points after normalization. */
export const LIVE_SCHEDULE_TITLE_MAX = 60;
/** A slot starts at least this far ahead… */
export const LIVE_SCHEDULE_MIN_LEAD_MS = 15 * 60_000;
/** …and at most this far ahead. */
export const LIVE_SCHEDULE_MAX_LEAD_MS = 30 * 24 * 3600_000;
/** Followers are reminded this long before the start. */
export const LIVE_SCHEDULE_REMIND_BEFORE_MS = 15 * 60_000;
/** Slots (and their reminders) are deleted this long after their start. */
export const LIVE_SCHEDULE_RETENTION_MS = 30 * 24 * 3600_000;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SWEEP_BATCH = 5000;
/** Slots reminded per sweeper run (each in its own transaction). */
const REMIND_BATCH = 50;

export const createLiveScheduleSlotSchema = z.strictObject({
  title: z
    .string()
    .max(240)
    .superRefine((raw, ctx) => {
      const value = normalizeDisplayName(raw);
      const issue =
        raw.length > 0 && value.length === 0
          ? 'invalid_format'
          : textHygieneIssue(value, {
              maxGraphemes: LIVE_SCHEDULE_TITLE_MAX,
              maxCodePoints: LIVE_SCHEDULE_TITLE_MAX,
            });
      if (issue) ctx.addIssue({ code: 'custom', message: `title ${issue}`, params: { issue } });
    })
    .transform(normalizeDisplayName),
  startsAt: z.iso.datetime({ offset: true }),
});

/** `LiveScheduleSlot` (openapi v1.14-live). */
export interface LiveScheduleSlotDto {
  id: string;
  title: string;
  startsAt: string;
  createdAt: string;
}

function toDto(row: { id: string; title: string; startsAt: Date; createdAt: Date }): LiveScheduleSlotDto {
  return {
    id: row.id,
    title: row.title,
    startsAt: row.startsAt.toISOString(),
    createdAt: row.createdAt.toISOString(),
  };
}

/**
 * The live schedule (CP-016 C, CONVENTIONS §10.16): a host announces upcoming lives; 15 minutes
 * before each start the live sweeper reminds the host's followers once (`LIVE_SCHEDULED_SOON`).
 * A slot is only an announcement: going live is not tied to it.
 */
@Injectable()
export class LiveScheduleService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
  ) {}

  private async requireHost(userId: string): Promise<void> {
    if ((await this.prisma.liveHost.count({ where: { userId } })) === 0) {
      throw new AppException(ErrorCode.LIVE_HOSTING_NOT_ALLOWED);
    }
  }

  /** `GET /me/live-schedule`: the upcoming slots, soonest first. */
  async list(userId: string): Promise<{ data: LiveScheduleSlotDto[] }> {
    await this.requireHost(userId);
    const rows = await this.prisma.liveScheduleSlot.findMany({
      where: { hostUserId: userId, startsAt: { gt: this.clock.now() } },
      orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
      take: LIVE_SCHEDULE_MAX,
    });
    return { data: rows.map(toDto) };
  }

  /**
   * `POST /me/live-schedule`. Order: hosting permission (403) → body → the 10-slot limit (409),
   * checked under a per-host advisory lock so two requests cannot both take the last place.
   */
  async create(userId: string, body: unknown, meta: RequestMeta): Promise<LiveScheduleSlotDto> {
    await this.requireHost(userId);
    const parsed = createLiveScheduleSlotSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { title } = parsed.data;
    const startsAt = new Date(parsed.data.startsAt);
    const now = this.clock.now();
    if (startsAt.getTime() < now.getTime() + LIVE_SCHEDULE_MIN_LEAD_MS) {
      throw AppException.validation([{ field: 'startsAt', issue: 'too_small' }]);
    }
    if (startsAt.getTime() > now.getTime() + LIVE_SCHEDULE_MAX_LEAD_MS) {
      throw AppException.validation([{ field: 'startsAt', issue: 'too_big' }]);
    }
    const row = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:live-schedule'), hashtext(${userId}))`;
      const upcoming = await tx.liveScheduleSlot.count({
        where: { hostUserId: userId, startsAt: { gt: now } },
      });
      if (upcoming >= LIVE_SCHEDULE_MAX) throw new AppException(ErrorCode.LIVE_SCHEDULE_FULL);
      const created = await tx.liveScheduleSlot.create({
        data: { hostUserId: userId, title, startsAt, createdAt: now },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_SCHEDULE_CREATE,
        actorUserId: userId,
        targetType: 'live_schedule_slot',
        targetId: created.id,
        metadata: { startsAt: created.startsAt.toISOString() },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      return created;
    });
    return toDto(row);
  }

  /** `DELETE /me/live-schedule/{slotId}`: the caller's own slot (and its reminders), else 404. */
  async remove(userId: string, slotId: string, meta: RequestMeta): Promise<void> {
    if (!UUID.test(slotId)) throw new AppException(ErrorCode.NOT_FOUND);
    const id = slotId.toLowerCase();
    await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.liveScheduleSlot.deleteMany({ where: { id, hostUserId: userId } });
      if (count === 0) throw new AppException(ErrorCode.NOT_FOUND);
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_SCHEDULE_DELETE,
        actorUserId: userId,
        targetType: 'live_schedule_slot',
        targetId: id,
        metadata: {},
        ip: meta.ip,
        requestId: meta.requestId,
      });
    });
  }

  /**
   * Live sweeper: reminds the followers of every slot due within 15 minutes and not reminded yet
   * (slots already started more than 15 minutes ago are only marked, never announced late). Each
   * slot is claimed with `FOR UPDATE SKIP LOCKED` and marked in the same transaction as its
   * notifications, so a reminder goes out exactly once even with several instances. Recipients
   * follow §11.10: ACTIVE, no block either way, not muted by the follower, `lives` not switched
   * off. Returns how many slots were handled.
   */
  async sendReminders(now: Date = this.clock.now()): Promise<number> {
    const dueBy = new Date(now.getTime() + LIVE_SCHEDULE_REMIND_BEFORE_MS);
    const lateAfter = new Date(now.getTime() - LIVE_SCHEDULE_REMIND_BEFORE_MS);
    let handled = 0;
    for (let i = 0; i < REMIND_BATCH; i += 1) {
      const done = await this.prisma.$transaction(async (tx) => {
        const [slot] = await tx.$queryRaw<{ id: string; host_user_id: string; starts_at: Date }[]>`
          SELECT id, host_user_id, starts_at FROM live_schedule_slots
           WHERE reminded_at IS NULL AND starts_at <= ${dueBy}
           ORDER BY starts_at, id
           LIMIT 1
           FOR UPDATE SKIP LOCKED`;
        if (!slot) return false;
        await tx.liveScheduleSlot.update({ where: { id: slot.id }, data: { remindedAt: now } });
        if (slot.starts_at <= lateAfter) return true;
        const followers = await tx.$queryRaw<{ id: string }[]>`
          SELECT f.follower_id AS id
            FROM follows f
            JOIN users u ON u.id = f.follower_id AND u.status = 'ACTIVE'::user_status
            JOIN users h ON h.id = ${slot.host_user_id}::uuid AND h.status = 'ACTIVE'::user_status
            LEFT JOIN notification_settings ns ON ns.user_id = f.follower_id
           WHERE f.followee_id = ${slot.host_user_id}::uuid
             AND f.follower_id <> ${slot.host_user_id}::uuid
             AND COALESCE(ns.lives, true)
             AND NOT EXISTS (SELECT 1 FROM user_blocks b
                              WHERE (b.blocker_id = f.follower_id AND b.blocked_id = ${slot.host_user_id}::uuid)
                                 OR (b.blocker_id = ${slot.host_user_id}::uuid AND b.blocked_id = f.follower_id))
             AND NOT EXISTS (SELECT 1 FROM user_mutes m
                              WHERE m.muter_id = f.follower_id AND m.muted_id = ${slot.host_user_id}::uuid)`;
        if (followers.length > 0) {
          const recipients = await tx.notification.createManyAndReturn({
            data: followers.map((f) => ({
              recipientId: f.id,
              type: 'LIVE_SCHEDULED_SOON' as const,
              liveScheduleId: slot.id,
              createdAt: now,
              updatedAt: now,
            })),
            select: { id: true },
          });
          await tx.notificationActor.createMany({
            data: recipients.map((r) => ({
              notificationId: r.id,
              actorId: slot.host_user_id,
              createdAt: now,
            })),
          });
        }
        return true;
      });
      if (!done) break;
      handled += 1;
    }
    return handled;
  }

  /** Live sweeper: deletes slots that started more than 30 days ago (with their reminders). */
  async sweepRetention(now: Date = this.clock.now()): Promise<number> {
    const cutoff = new Date(now.getTime() - LIVE_SCHEDULE_RETENTION_MS);
    let total = 0;
    for (;;) {
      const n = await this.prisma.$executeRaw`
        DELETE FROM live_schedule_slots
         WHERE id IN (SELECT id FROM live_schedule_slots WHERE starts_at < ${cutoff} LIMIT ${SWEEP_BATCH})`;
      total += n;
      if (n < SWEEP_BATCH) return total;
    }
  }
}
