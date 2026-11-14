import type { Prisma } from '../../generated/prisma/client.js';
import { localClock } from '../recharge/recharge-rules.js';
import type { PrismaService } from '../../prisma/prisma.service.js';

/**
 * v1.139-social (D387, CONVENTIONS §10.176.6): the weekly shift schedule «جدول المناوبات» — pure rules and the one query
 * the reports' audit and the staff app need. A slot is a weekday (1 Monday … 7 Sunday) and minutes of the day
 * [start, end) in the app's time zone (`LIVE_RANKINGS_TIME_ZONE`, D99); «في المناوبة الآن» = a slot covers now.
 */

/** The roles that can be put on the schedule (owner: TRUST_SAFETY = MODERATION, SUPPORT, VIP_CARE). */
export const SCHEDULE_ROLES = ['MODERATION', 'SUPPORT', 'VIP_CARE'] as const;

export const WEEK_MINUTES = 7 * 1440;

export interface ScheduleSlotLike {
  readonly weekday: number;
  readonly startMinute: number;
  readonly endMinute: number;
}

/** Where `now` is in the week in `zone`. */
export function weekClock(now: Date, zone: string): { weekday: number; minute: number } {
  const c = localClock(now, zone);
  return { weekday: c.day, minute: c.minutes };
}

/** The slot covers the weekday and minute (start inclusive, end exclusive). */
export function slotCovers(slot: ScheduleSlotLike, at: { weekday: number; minute: number }): boolean {
  return slot.weekday === at.weekday && at.minute >= slot.startMinute && at.minute < slot.endMinute;
}

/** Two slots of the same weekday overlap (touching ends do not). */
export function slotsOverlap(a: ScheduleSlotLike, b: ScheduleSlotLike): boolean {
  return a.weekday === b.weekday && a.startMinute < b.endMinute && b.startMinute < a.endMinute;
}

/** The shape rule (also CHECK `staff_schedule_slots_shape`): null when valid, else the field that is wrong. */
export function slotShapeIssue(slot: ScheduleSlotLike): 'weekday' | 'startMinute' | 'endMinute' | null {
  if (!Number.isInteger(slot.weekday) || slot.weekday < 1 || slot.weekday > 7) return 'weekday';
  if (!Number.isInteger(slot.startMinute) || slot.startMinute < 0 || slot.startMinute > 1439)
    return 'startMinute';
  if (!Number.isInteger(slot.endMinute) || slot.endMinute < 1 || slot.endMinute > 1440) return 'endMinute';
  if (slot.endMinute <= slot.startMinute) return 'endMinute';
  return null;
}

/**
 * Minutes from now until the slot next starts (0 < x ≤ one week; a slot that covers now starts again next week).
 * Used to order «التالي».
 */
export function minutesUntilStart(slot: ScheduleSlotLike, at: { weekday: number; minute: number }): number {
  const nowAbs = (at.weekday - 1) * 1440 + at.minute;
  const startAbs = (slot.weekday - 1) * 1440 + slot.startMinute;
  const d = (startAbs - nowAbs + WEEK_MINUTES) % WEEK_MINUTES;
  return d === 0 ? WEEK_MINUTES : d;
}

/** The slots that start next after now (each slot once), soonest first. */
export function nextSlots<T extends ScheduleSlotLike>(
  slots: readonly T[],
  at: { weekday: number; minute: number },
  limit = 5,
): { slot: T; inMinutes: number }[] {
  return slots
    .map((slot) => ({ slot, inMinutes: minutesUntilStart(slot, at) }))
    .sort((a, b) => a.inMinutes - b.inMinutes)
    .slice(0, limit);
}

type Db = Pick<PrismaService, 'staffScheduleSlot'> | Prisma.TransactionClient;

/**
 * Whether `userId` is on the schedule now (a slot covers now in `zone`) — the reports' audit `scheduled` (§10.176.6)
 * and `StaffStatus.scheduledShift`. One indexed read of the person's slots of today.
 */
export async function scheduledNowIn(db: Db, userId: string, zone: string, now: Date): Promise<boolean> {
  const at = weekClock(now, zone);
  const n = await db.staffScheduleSlot.count({
    where: {
      userId,
      weekday: at.weekday,
      startMinute: { lte: at.minute },
      endMinute: { gt: at.minute },
    },
  });
  return n > 0;
}

/**
 * The resolver's shift for the reports' audit (§10.176.6): `scheduled` (a slot covers now) and `onShift` (scheduled, or
 * the D260 shift switch is on).
 */
export async function resolverShiftIn(
  db: Db & Pick<Prisma.TransactionClient, 'adminShift'>,
  userId: string,
  zone: string,
  now: Date,
): Promise<{ onShift: boolean; scheduled: boolean }> {
  const [scheduled, shift] = await Promise.all([
    scheduledNowIn(db, userId, zone, now),
    db.adminShift.findUnique({ where: { userId }, select: { onShift: true } }),
  ]);
  return { scheduled, onShift: scheduled || shift?.onShift === true };
}
