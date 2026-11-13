import { z } from 'zod';
import { PAYMENT_METHOD_TYPES } from './recharge-rules.js';

/**
 * Recharge orders with escrow «طلبات الشحن» (v1.69-social, D204, CONVENTIONS §10.64): the pure rules — the price of
 * an order (retail USD and the local amount at the admin's rate), the statuses and who may do what in each. No I/O:
 * shared by the API, the `recharge-admin` CLI, the panel and the tests.
 */

export const ORDER_STATUSES = [
  'REQUESTED',
  'AWAITING_PAYMENT',
  'PAID',
  'DISPUTED',
  'COMPLETED',
  'COMPLETED_BY_ADMIN',
  'REFUNDED_TO_AGENT',
  'CANCELLED',
  'EXPIRED',
] as const;
export type OrderStatus = (typeof ORDER_STATUSES)[number];

/** The statuses of an open order (one per buyer–agent pair). */
export const OPEN_STATUSES: readonly OrderStatus[] = ['REQUESTED', 'AWAITING_PAYMENT', 'PAID', 'DISPUTED'];
/** The statuses in which the agent's coins are frozen for the order. */
export const HELD_STATUSES: readonly OrderStatus[] = ['AWAITING_PAYMENT', 'PAID', 'DISPUTED'];

export function isOpen(status: string): boolean {
  return (OPEN_STATUSES as readonly string[]).includes(status);
}

/** USD (the retail price per 1 000 000 coins, e.g. 12.5) in 1/10 000 of a dollar per million coins. */
export function retailMicroPerMillion(usdPerMillion: number): bigint {
  return BigInt(Math.round(usdPerMillion * 10_000));
}

/** coins × retail, in US cents, rounded half up. `perMillion` from {@link retailMicroPerMillion}. */
export function usdMinorOf(coins: bigint, perMillion: bigint): bigint {
  if (coins <= 0n) throw new RangeError('An order is positive');
  // cents = coins × (perMillion / 10 000 USD) / 1 000 000 × 100 = coins × perMillion / 100 000 000.
  return (coins * perMillion + 50_000_000n) / 100_000_000n;
}

/** An admin's rate as typed (`50.5`, `3.75`, `1460`): units per 1 USD × 1 000 000, or null. */
export function parseRateMicro(raw: string): bigint | null {
  const m = /^([0-9]{1,9})(?:\.([0-9]{1,6}))?$/.exec(raw.trim());
  if (!m) return null;
  const micro = BigInt(m[1]!) * 1_000_000n + BigInt((m[2] ?? '').padEnd(6, '0'));
  return micro > 0n ? micro : null;
}

/** `50500000` → `"50.5"` (no trailing zeros). */
export function formatRate(micro: bigint): string {
  const whole = micro / 1_000_000n;
  const frac = (micro % 1_000_000n).toString().padStart(6, '0').replace(/0+$/, '');
  return frac === '' ? whole.toString() : `${whole.toString()}.${frac}`;
}

/** The local amount in minor units of a currency with `digits` decimals, rounded half up. */
export function localMinorOf(usdMinor: bigint, rateMicro: bigint, digits: number): bigint {
  const scale = 10n ** BigInt(digits);
  // local = usdMinor / 100 × rateMicro / 1 000 000, in 1/scale units.
  const denominator = 100_000_000n;
  return (usdMinor * rateMicro * scale + denominator / 2n) / denominator;
}

/** `62500` with 2 digits → `"625.00"`. */
export function formatMinor(minor: bigint, digits: number): string {
  if (digits === 0) return minor.toString();
  const scale = 10n ** BigInt(digits);
  return `${(minor / scale).toString()}.${(minor % scale).toString().padStart(digits, '0')}`;
}

export interface Quote {
  readonly coins: bigint;
  readonly usdMinor: bigint;
  readonly local: { currency: string; rateMicro: bigint; digits: number; minor: bigint } | null;
}

export function quote(
  coins: bigint,
  usdPerMillion: number,
  rate: { currency: string; rateMicro: bigint; digits: number } | null,
): Quote {
  const usdMinor = usdMinorOf(coins, retailMicroPerMillion(usdPerMillion));
  return {
    coins,
    usdMinor,
    local: rate ? { ...rate, minor: localMinorOf(usdMinor, rate.rateMicro, rate.digits) } : null,
  };
}

// ---- Who may do what --------------------------------------------------------------------------------------------

export type Side = 'BUYER' | 'AGENT';

export type OrderAction =
  'SEND_DETAILS' | 'ACK_NOTICE' | 'MARK_PAID' | 'CONFIRM' | 'DISPUTE' | 'CANCEL' | 'MESSAGE';

export interface OrderState {
  readonly status: OrderStatus;
  readonly noticeAckAt: Date | null;
  readonly paidAt: Date | null;
}

/** When the buyer may open a dispute on a PAID order (`paidAt` + the wait, owner: 15 minutes). */
export function disputeOpensAt(paidAt: Date, afterMinutes: number): Date {
  return new Date(paidAt.getTime() + afterMinutes * 60_000);
}

/** The actions `side` may take on the order now (the server checks each again under the row lock). */
export function allowedActions(
  o: OrderState,
  side: Side,
  now: Date,
  rules: { disputeAfterMinutes: number },
): OrderAction[] {
  const out: OrderAction[] = [];
  if (o.status !== 'CANCELLED' && o.status !== 'EXPIRED') out.push('MESSAGE');
  if (side === 'AGENT') {
    if (o.status === 'REQUESTED') out.push('SEND_DETAILS', 'CANCEL');
    if (o.status === 'PAID') out.push('CONFIRM', 'DISPUTE');
  } else {
    if (o.status === 'REQUESTED') out.push('CANCEL');
    if (o.status === 'AWAITING_PAYMENT') {
      out.push(o.noticeAckAt === null ? 'ACK_NOTICE' : 'MARK_PAID', 'CANCEL');
    }
    if (
      o.status === 'PAID' &&
      o.paidAt !== null &&
      now.getTime() >= disputeOpensAt(o.paidAt, rules.disputeAfterMinutes).getTime()
    ) {
      out.push('DISPUTE');
    }
  }
  return out;
}

// ---- Bodies -----------------------------------------------------------------------------------------------------

/** A C0/C1 control other than a line break, a zero-width character or a bidi control. */
function isControl(ch: string): boolean {
  const c = ch.codePointAt(0)!;
  return (
    (c < 0x20 && c !== 0x0a) ||
    (c >= 0x7f && c <= 0x9f) ||
    (c >= 0x200b && c <= 0x200f) ||
    (c >= 0x202a && c <= 0x202e) ||
    (c >= 0x2066 && c <= 0x2069)
  );
}

/** Free text shown to the other side and admins: line breaks allowed, no other control characters. */
export const orderText = (max: number) =>
  z
    .string()
    .transform((t) => t.replace(/\r\n?/g, '\n').trim())
    .pipe(
      z
        .string()
        .min(1)
        .max(max)
        .refine((t) => ![...t].some(isControl), { message: 'control characters' }),
    );

const country = z
  .string()
  .regex(/^[A-Za-z]{2}$/)
  .transform((c) => c.toUpperCase());

export const quoteQuerySchema = z.strictObject({
  agentCode: z.string().trim().min(1).max(16),
  country,
  coins: z.coerce.number().int().min(1).max(1_000_000_000_000),
});

export const createOrderSchema = z.strictObject({
  agentCode: z.string().trim().min(1).max(16),
  country,
  coins: z.number().int().min(1).max(1_000_000_000_000),
  paymentType: z.enum(PAYMENT_METHOD_TYPES),
});

export const orderMessageSchema = z
  .strictObject({
    text: orderText(1000).optional(),
    imageUploadId: z.uuid().optional(),
  })
  .refine((b) => (b.text === undefined) !== (b.imageUploadId === undefined), {
    message: 'exactly one of text and imageUploadId',
    path: ['text'],
  });

export const paymentDetailsSchema = z.strictObject({
  method: z.enum(PAYMENT_METHOD_TYPES),
  details: orderText(500),
});

export const markPaidSchema = z.strictObject({ proofUploadId: z.uuid() });

export const reasonBodySchema = z.strictObject({ reason: orderText(500).optional() });

export const ordersQuerySchema = z.strictObject({
  role: z.enum(['buyer', 'agent']).default('buyer'),
  state: z.enum(['open', 'closed', 'all']).default('all'),
  cursor: z.string().max(512).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export const messagesQuerySchema = z.strictObject({
  cursor: z.string().max(512).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

/** The resolution of a dispute by an admin (with the reason and the authenticator code). */
export const DISPUTE_OUTCOMES = ['CREDIT_BUYER', 'REFUND_AGENT'] as const;
export type DisputeOutcome = (typeof DISPUTE_OUTCOMES)[number];

/** ISO 4217 code and the decimals of the 22 Arab League currencies (D150), for the panel's defaults. */
export const ARAB_CURRENCIES: Readonly<Record<string, { currency: string; digits: number }>> = {
  DZ: { currency: 'DZD', digits: 2 },
  BH: { currency: 'BHD', digits: 3 },
  KM: { currency: 'KMF', digits: 0 },
  DJ: { currency: 'DJF', digits: 0 },
  EG: { currency: 'EGP', digits: 2 },
  IQ: { currency: 'IQD', digits: 0 },
  JO: { currency: 'JOD', digits: 3 },
  KW: { currency: 'KWD', digits: 3 },
  LB: { currency: 'LBP', digits: 0 },
  LY: { currency: 'LYD', digits: 3 },
  MR: { currency: 'MRU', digits: 2 },
  MA: { currency: 'MAD', digits: 2 },
  OM: { currency: 'OMR', digits: 3 },
  PS: { currency: 'ILS', digits: 2 },
  QA: { currency: 'QAR', digits: 2 },
  SA: { currency: 'SAR', digits: 2 },
  SO: { currency: 'SOS', digits: 0 },
  SD: { currency: 'SDG', digits: 2 },
  SY: { currency: 'SYP', digits: 0 },
  TN: { currency: 'TND', digits: 3 },
  AE: { currency: 'AED', digits: 2 },
  YE: { currency: 'YER', digits: 0 },
};

export const exchangeRateSchema = z.strictObject({
  currency: z
    .string()
    .regex(/^[A-Za-z]{3}$/)
    .transform((c) => c.toUpperCase()),
  /** Units of the currency per 1 USD, e.g. `50.5`. */
  unitsPerUsd: z.string().regex(/^[0-9]{1,9}(\.[0-9]{1,6})?$/),
  digits: z.number().int().min(0).max(3),
  reason: z.string().trim().min(1).max(500),
});
