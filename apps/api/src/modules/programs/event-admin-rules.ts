import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { EventMetric, Prisma } from '../../generated/prisma/client.js';
import type { EventPrize } from './programs-rules.js';

type Tx = Prisma.TransactionClient;

/** A refused event change (the CLI prints it and exits 1; the panel answers 409). Nothing changed. */
export class EventAdminError extends Error {}

export const EVENT_METRICS: readonly EventMetric[] = [
  'GIFT_COINS_RECEIVED',
  'GIFT_COINS_SENT',
  'LIVE_MINUTES',
  'TAPS_RECEIVED',
  'NEW_FOLLOWERS',
];

/** The calendar tones (CHECK `events_style`). */
export const EVENT_TONES = ['RED', 'GOLD', 'TEAL', 'BLUE', 'PINK', 'AMBER'] as const;

export interface EventInput {
  readonly titleAr: string;
  readonly titleEn: string;
  readonly rulesAr: string;
  readonly rulesEn: string;
  readonly startsAt: Date;
  readonly endsAt: Date | null;
  readonly permanent: boolean;
  readonly metric: EventMetric;
  readonly audience: 'EVERYONE' | 'HOSTS';
  readonly regions: readonly string[];
  readonly featured: boolean;
  readonly bannerUrl: string | null;
  readonly prizes: readonly EventPrize[];
  readonly summaryAr: string | null;
  readonly summaryEn: string | null;
  readonly tone: string | null;
}

/**
 * `event-admin create` (v1.44-social, D166, §10.41), shared with the admin panel (v1.65-social, D197, CONVENTIONS
 * §10.60.4): the event row and its `event.create` audit row in the caller's transaction. The caller parsed the
 * input; the cross-field rules are checked here.
 */
export async function createEventByAdminIn(
  tx: Tx,
  input: EventInput,
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
): Promise<{ id: string }> {
  if (input.endsAt === null && !input.permanent) {
    throw new EventAdminError('Give an end time, or make the event permanent.');
  }
  if (input.endsAt !== null && input.endsAt <= input.startsAt)
    throw new EventAdminError('The end must be after the start.');
  const regions = [...new Set(input.regions)];
  const row = await tx.event.create({
    data: {
      titleAr: input.titleAr,
      titleEn: input.titleEn,
      rulesAr: input.rulesAr,
      rulesEn: input.rulesEn,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      permanent: input.permanent,
      metric: input.metric,
      audience: input.audience,
      regions,
      featured: input.featured,
      bannerUrl: input.bannerUrl,
      prizes: input.prizes.map((p) => ({ ...p })),
      summaryAr: input.summaryAr,
      summaryEn: input.summaryEn,
      tone: input.tone,
    },
    select: { id: true },
  });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.EVENT_CREATE,
      targetType: 'event',
      targetId: row.id,
      metadata: {
        metric: input.metric,
        audience: input.audience,
        permanent: input.permanent,
        regions,
        prizes: input.prizes.length,
        ...(reason ? { reason } : {}),
        via: by.via,
      },
    },
  });
  return row;
}

export type EventChange = 'end' | 'hold' | 'release';

/**
 * `event-admin end|hold|release`: ends a running event now (the sweeper then freezes it), or stops / resumes the
 * automatic prize payout. Returns false when an `end` changes nothing (already ended).
 */
export async function changeEventByAdminIn(
  tx: Tx,
  eventId: string,
  command: EventChange,
  now: Date,
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
): Promise<boolean> {
  const event = await tx.event.findUnique({ where: { id: eventId } });
  if (!event) throw new EventAdminError(`No event ${eventId}.`);
  if (command === 'end') {
    if (now < event.startsAt) throw new EventAdminError('This event has not started; nothing to end.');
    if (event.endsAt !== null && event.endsAt <= now) return false;
  } else if (event.paidAt !== null) {
    throw new EventAdminError('The prizes of this event are already settled.');
  }
  await tx.event.update({
    where: { id: event.id },
    data: command === 'end' ? { endsAt: now } : { payoutHold: command === 'hold' },
  });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action:
        command === 'end'
          ? AuditAction.EVENT_END
          : command === 'hold'
            ? AuditAction.EVENT_HOLD
            : AuditAction.EVENT_RELEASE,
      targetType: 'event',
      targetId: event.id,
      metadata: {
        ...(command === 'end'
          ? { before: event.endsAt?.toISOString() ?? null, after: now.toISOString() }
          : { before: event.payoutHold, after: command === 'hold' }),
        ...(reason ? { reason } : {}),
        via: by.via,
      },
    },
  });
  return true;
}

/** An event's state for lists (the CLI's `list` words). */
export function eventState(
  e: { startsAt: Date; endsAt: Date | null; paidAt: Date | null; frozenAt: Date | null; payoutHold: boolean },
  now: Date,
): 'UPCOMING' | 'RUNNING' | 'PAID' | 'HELD' | 'IN_REVIEW' | 'ENDED' {
  if (now < e.startsAt) return 'UPCOMING';
  if (e.endsAt === null || now < e.endsAt) return 'RUNNING';
  if (e.paidAt) return 'PAID';
  if (e.frozenAt) return e.payoutHold ? 'HELD' : 'IN_REVIEW';
  return 'ENDED';
}
