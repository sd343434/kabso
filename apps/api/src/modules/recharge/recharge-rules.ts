import { z } from 'zod';

/**
 * Recharge agents (v1.54-social, D185, CONVENTIONS §10.48): the pure rules — the code, the owner's price
 * tiers, the cherry → coin conversion and weekly hours in a time zone. No I/O: shared by the API, the
 * `recharge-admin` CLI and the tests.
 */

/** `coin0001`: `coin` and the activation number, at least four digits (owner). */
export function agentCode(number: number): string {
  if (!Number.isInteger(number) || number < 1) throw new RangeError('A code number is a positive integer');
  return `coin${String(number).padStart(4, '0')}`;
}

const CODE = /^coin[0-9]{4,}$/;

/** A code as typed (any case, spaces around), or null when it cannot be one. */
export function normalizeAgentCode(raw: string): string | null {
  const code = raw.trim().toLowerCase();
  return CODE.test(code) ? code : null;
}

export interface PriceTier {
  readonly minCoins: number;
  readonly minorPerMillion: number;
}

export interface TopUpPrice {
  /** The tier's name: `STANDARD`, then `FROM_<minCoins>` (e.g. `FROM_100M`). */
  readonly tier: string;
  readonly minorPerMillion: number;
  /** coins × price / 1 000 000, rounded half up to a minor unit. */
  readonly expectedMinor: bigint;
}

function tierName(minCoins: number): string {
  if (minCoins === 0) return 'STANDARD';
  if (minCoins % 1_000_000 === 0) return `FROM_${String(minCoins / 1_000_000)}M`;
  return `FROM_${String(minCoins)}`;
}

/** The owner's wholesale price for a top-up of `coins` (the highest tier whose minimum it reaches). */
export function topUpPrice(coins: bigint, tiers: readonly PriceTier[]): TopUpPrice {
  if (coins <= 0n) throw new RangeError('A top-up is positive');
  let chosen = tiers[0]!;
  for (const t of tiers) if (coins >= BigInt(t.minCoins)) chosen = t;
  const numerator = coins * BigInt(chosen.minorPerMillion);
  const expectedMinor = (numerator + 500_000n) / 1_000_000n;
  return { tier: tierName(chosen.minCoins), minorPerMillion: chosen.minorPerMillion, expectedMinor };
}

/** USD as typed by an admin (`360`, `360.5`, `360.00`) in minor units, or null. */
export function parseMoneyMinor(raw: string): bigint | null {
  const m = /^([0-9]{1,13})(?:\.([0-9]{1,2}))?$/.exec(raw.trim());
  if (!m) return null;
  return BigInt(m[1]!) * 100n + BigInt((m[2] ?? '').padEnd(2, '0'));
}

/** The coins an agent's stock gets for `cherries`: floor(cherries × coins / unit). */
export function cherriesToCoins(cherries: bigint, rate: { cherries: number; coins: number }): bigint {
  return (cherries * BigInt(rate.coins)) / BigInt(rate.cherries);
}

/** What the agent pays the host for `cherries` at CHERRY_PAYOUT_RATE (minor units, rounded down). */
export function cherriesPayoutMinor(cherries: bigint, rateCherries: number, rateMinor: number): bigint {
  return (cherries * BigInt(rateMinor)) / BigInt(rateCherries);
}

/** Whether `cherries` is a valid sale: at least `min` and a multiple of `step`. */
export function validCherryAmount(cherries: bigint, min: number, step: number): boolean {
  return cherries >= BigInt(min) && cherries % BigInt(step) === 0n;
}

// ---- Weekly hours ------------------------------------------------------------------------------------

export interface WeeklySlot {
  readonly days: number[];
  readonly start: string;
  readonly end: string;
}

const HHMM = /^([01][0-9]|2[0-3]):[0-5][0-9]$/;
const HHMM_END = /^(([01][0-9]|2[0-3]):[0-5][0-9]|24:00)$/;

export function minutesOf(hhmm: string): number {
  const [h, m] = hhmm.split(':');
  return Number(h) * 60 + Number(m);
}

/** Whether `zone` is an IANA time zone this runtime knows. */
export function isTimeZone(zone: string): boolean {
  if (zone.length === 0 || zone.length > 64) return false;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: zone });
    return true;
  } catch {
    return false;
  }
}

export const weeklySlotSchema = z
  .strictObject({
    days: z
      .array(z.number().int().min(1).max(7))
      .min(1)
      .max(7)
      .refine((d) => new Set(d).size === d.length, { message: 'days must be distinct' }),
    start: z.string().regex(HHMM),
    end: z.string().regex(HHMM_END),
  })
  .refine((s) => minutesOf(s.end) > minutesOf(s.start), {
    message: 'end must be after start',
    path: ['end'],
  });

export const timeZoneSchema = z.string().max(64).refine(isTimeZone, { message: 'unknown time zone' });

/** ISO weekday (1 = Monday … 7 = Sunday) and minutes since midnight of `now` in `zone`. */
export function localClock(now: Date, zone: string): { day: number; minutes: number } {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: zone,
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? '';
  const day = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexOf(get('weekday')) + 1;
  return { day, minutes: Number(get('hour')) * 60 + Number(get('minute')) };
}

/** The first slot that contains `now` in `zone` (start inclusive, end exclusive), or null. */
export function slotAt<T extends WeeklySlot>(slots: readonly T[], zone: string, now: Date): T | null {
  const clock = localClock(now, zone);
  for (const s of slots) {
    if (!s.days.includes(clock.day)) continue;
    if (clock.minutes >= minutesOf(s.start) && clock.minutes < minutesOf(s.end)) return s;
  }
  return null;
}

/** The day (YYYY-MM-DD) of `now` in `zone`. */
export function dayKey(now: Date, zone: string): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: zone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

/** The instant the day of `now` started in `zone` (to within a minute; DST-safe for whole-hour offsets). */
export function dayStart(now: Date, zone: string): Date {
  const { minutes } = localClock(now, zone);
  const start = new Date(now.getTime() - minutes * 60_000 - (now.getTime() % 60_000));
  // A DST change during the day moves midnight by the change: look again from the guess.
  const again = localClock(start, zone).minutes;
  if (again === 0) return start;
  return new Date(start.getTime() - (again > 720 ? again - 1440 : again) * 60_000);
}

// ---- Application ---------------------------------------------------------------------------------------

export const E164 = /^\+[1-9][0-9]{7,14}$/;

export const PAYMENT_METHOD_TYPES = [
  'BANK_TRANSFER',
  'MOBILE_WALLET',
  'CASH',
  'CARD',
  'CRYPTO',
  'OTHER',
] as const;
export type PaymentMethodType = (typeof PAYMENT_METHOD_TYPES)[number];

const country = z
  .string()
  .regex(/^[A-Za-z]{2}$/)
  .transform((c) => c.toUpperCase());

/** A C0/C1 control, a zero-width character or a bidi control. */
function isControl(ch: string): boolean {
  const c = ch.codePointAt(0)!;
  return (
    c < 0x20 ||
    (c >= 0x7f && c <= 0x9f) ||
    (c >= 0x200b && c <= 0x200f) ||
    (c >= 0x202a && c <= 0x202e) ||
    (c >= 0x2066 && c <= 0x2069)
  );
}

/** No line breaks or bidi / zero-width controls in the free text (it is shown to admins and buyers). */
const plainText = (min: number, max: number) =>
  z
    .string()
    .trim()
    .min(min)
    .max(max)
    .refine((t) => ![...t].some(isControl), {
      message: 'control characters',
    });

export const applicationSchema = z
  .strictObject({
    fullName: plainText(8, 120).refine((n) => n.split(/\s+/u).filter((w) => w.length > 0).length >= 4, {
      message: 'four names',
    }),
    phone: z.string().regex(E164),
    whatsapp: z.literal(true),
    photoUploadId: z.uuid(),
    selfieUploadId: z.uuid(),
    locations: z
      .array(z.strictObject({ country, cities: z.array(plainText(1, 60)).min(1).max(20) }))
      .min(1)
      .max(10)
      .refine((l) => new Set(l.map((x) => x.country)).size === l.length, {
        message: 'countries must be distinct',
      }),
    paymentMethods: z
      .array(z.strictObject({ country, type: z.enum(PAYMENT_METHOD_TYPES), details: plainText(1, 200) }))
      .min(1)
      .max(30),
  })
  .refine((a) => a.paymentMethods.every((p) => a.locations.some((l) => l.country === p.country)), {
    message: 'a payment method outside the locations',
    path: ['paymentMethods'],
  });
export type ApplicationInput = z.infer<typeof applicationSchema>;

export const availabilitySchema = z.strictObject({
  timeZone: timeZoneSchema,
  slots: z
    .array(
      z
        .strictObject({
          days: z
            .array(z.number().int().min(1).max(7))
            .min(1)
            .max(7)
            .refine((d) => new Set(d).size === d.length, { message: 'days must be distinct' }),
          start: z.string().regex(HHMM),
          end: z.string().regex(HHMM_END),
          whatsapp: z.string().regex(E164),
          paymentMethod: plainText(1, 80),
        })
        .refine((s) => minutesOf(s.end) > minutesOf(s.start), {
          message: 'end must be after start',
          path: ['end'],
        }),
    )
    .max(28),
});
export type AvailabilityInput = z.infer<typeof availabilitySchema>;
export type AvailabilitySlot = AvailabilityInput['slots'][number];

export const employeeHoursSchema = z.strictObject({
  timeZone: timeZoneSchema,
  schedule: z.array(weeklySlotSchema).min(1).max(28),
});
