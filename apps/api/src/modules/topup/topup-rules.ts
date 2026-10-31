/**
 * Card top-ups on the Kabso website (v1.59-social, D190, CONVENTIONS §10.53): the pure rules — the statement the
 * buyer accepts, the reversal a purchase owes after refunds / fraud warnings / disputes, the FIFO attribution of a
 * purchase's coins to what they paid for, the dispute evidence and its receipt PDF. No I/O, no Nest.
 */

/** The statement accepted before every checkout (owner, verbatim), with its English version. */
export const TOPUP_TERMS = {
  ar: 'العملات رقمية وغير قابلة للاسترداد',
  en: 'Coins are digital and non-refundable',
} as const;

export type TopupLocale = keyof typeof TOPUP_TERMS;

export interface TopupPackage {
  readonly id: string;
  readonly coins: number;
  readonly priceMinor: number;
}

/** The server's package for an id; null for anything else (the client never sends a price). */
export function findPackage(packages: readonly TopupPackage[], id: string): TopupPackage | null {
  return packages.find((p) => p.id === id) ?? null;
}

/** What a purchase owes back, from the order's stored Stripe facts. */
export interface ReversalFacts {
  readonly coins: bigint;
  readonly amountMinor: number;
  /** Cumulative refunded amount (Stripe's `charge.amount_refunded`). */
  readonly refundedMinor: number;
  /** An early-fraud warning: the purchase is refunded in full by us, so every coin goes back at once. */
  readonly fraudWarning: boolean;
  /** The dispute's Stripe status, or null without a dispute. */
  readonly disputeStatus: string | null;
  readonly disputeAmountMinor: number;
}

/**
 * Whether an open or lost dispute takes its coins back. A won dispute gives them back; an inquiry closed without a
 * chargeback (`warning_closed`) and a dispute Stripe prevented do too.
 */
export function disputeHoldsCoins(status: string | null): boolean {
  if (status === null) return false;
  return !['won', 'warning_closed', 'prevented'].includes(status);
}

const ceilDiv = (a: bigint, b: bigint): bigint => (a + b - 1n) / b;

/**
 * The coins taken back now: all of them after an early-fraud warning; else the refunded share plus the disputed
 * share (each rounded up: a buyer never keeps coins for money they got back), at most the purchase.
 */
export function targetReversal(f: ReversalFacts): bigint {
  if (f.coins <= 0n || f.amountMinor <= 0) return 0n;
  if (f.fraudWarning) return f.coins;
  const amount = BigInt(f.amountMinor);
  const share = (minor: number): bigint =>
    minor <= 0 ? 0n : ceilDiv(f.coins * BigInt(Math.min(minor, f.amountMinor)), amount);
  const refund = share(f.refundedMinor);
  const dispute = disputeHoldsCoins(f.disputeStatus) ? share(f.disputeAmountMinor) : 0n;
  const total = refund + dispute;
  return total > f.coins ? f.coins : total;
}

/** A coin-ledger row after the purchase's credit, in ledger order. */
export interface LedgerRow {
  readonly id: string;
  readonly reason: string;
  readonly delta: bigint;
  readonly referenceId: string;
  readonly createdAt: Date;
}

/** Spending paid (in part) with the purchase's coins. */
export interface FundedSpend {
  readonly ledgerId: string;
  readonly reason: string;
  readonly referenceId: string;
  /** The coins of this spend that came from the purchase. */
  readonly coins: bigint;
  readonly at: Date;
}

/** Ledger reasons that are not spending (reversals and restorations of website purchases). */
const NOT_SPENDING = new Set(['CARD_TOPUP_REVERSAL', 'CARD_TOPUP_RESTORE']);

/** The gift reasons whose reference is a `live_gifts` send (host cherries were credited from it). */
export const GIFT_SPEND_REASONS = new Set(['LIVE_GIFT', 'LUCKY_GIFT', 'DM_GIFT']);

/**
 * FIFO attribution (owner rule): the coins the buyer held before the purchase (`opening`) are spent first, then the
 * purchase's coins; coins credited later queue behind them. A negative opening balance (a debt) is paid by the
 * purchase first. Returns each later spend that used purchased coins, and the purchased coins never spent.
 */
export function fifoAttribution(
  opening: bigint,
  purchased: bigint,
  later: readonly LedgerRow[],
): { spends: FundedSpend[]; unspent: bigint } {
  let older = opening > 0n ? opening : 0n;
  let left = opening < 0n ? purchased + opening : purchased;
  if (left < 0n) left = 0n;
  const spends: FundedSpend[] = [];
  for (const row of later) {
    if (left === 0n) break;
    if (row.delta >= 0n || NOT_SPENDING.has(row.reason)) continue;
    const spent = -row.delta;
    const fromOlder = spent < older ? spent : older;
    older -= fromOlder;
    const rest = spent - fromOlder;
    const fromPurchase = rest < left ? rest : left;
    left -= fromPurchase;
    if (fromPurchase > 0n) {
      spends.push({
        ledgerId: row.id,
        reason: row.reason,
        referenceId: row.referenceId,
        coins: fromPurchase,
        at: row.createdAt,
      });
    }
  }
  return { spends, unspent: left };
}

/** What the dispute evidence is built from — the BUYER's own data only, never another user's. */
export interface EvidenceInput {
  readonly order: {
    readonly id: string;
    readonly coins: bigint;
    readonly amountMinor: number;
    readonly currency: string;
    readonly createdAt: Date;
    readonly creditedAt: Date | null;
    readonly paymentIntentId: string | null;
    readonly paymentMethodType: string | null;
  };
  readonly buyer: { readonly email: string; readonly displayName: string; readonly username: string };
  readonly terms: {
    readonly version: string;
    readonly text: string;
    readonly locale: string;
    readonly acceptedAt: Date;
    readonly ip: string | null;
    readonly userAgent: string | null;
  };
  /** The buyer's sign-ins (sessions): when, from which IP and device. */
  readonly logins: readonly {
    readonly at: Date;
    readonly lastUsedAt: Date;
    readonly ip: string | null;
    readonly userAgent: string | null;
    readonly device: string | null;
  }[];
  /** What the purchase's coins paid for (FIFO), without any recipient. */
  readonly spends: readonly { readonly at: Date; readonly what: string; readonly coins: bigint }[];
  readonly unspentCoins: bigint;
  readonly statementDescriptor: string;
}

/** The Stripe `DisputeUpdateParams.evidence` text fields (the receipt file id is added by the caller). */
export interface DisputeEvidenceText {
  access_activity_log: string;
  customer_email_address: string;
  customer_name: string;
  customer_purchase_ip?: string;
  product_description: string;
  refund_policy: string;
  refund_policy_disclosure: string;
  service_date: string;
  uncategorized_text: string;
}

const MAX_TEXT = 19_000;

function money(minor: number, currency: string): string {
  return `${(minor / 100).toFixed(2)} ${currency.toUpperCase()}`;
}

function iso(d: Date): string {
  return d.toISOString().replace('.000Z', 'Z');
}

function clip(text: string): string {
  return text.length <= MAX_TEXT ? text : `${text.slice(0, MAX_TEXT - 20)}\n… (truncated)`;
}

/** The evidence text (factual, the buyer's data only) and the receipt's lines. */
export function buildEvidence(input: EvidenceInput): {
  evidence: DisputeEvidenceText;
  receiptLines: string[];
} {
  const { order, buyer, terms } = input;
  const price = money(order.amountMinor, order.currency);
  const coins = order.coins.toString();
  const logins = input.logins.slice(0, 100).map((l) => {
    const device = [l.device, l.userAgent].filter((v) => v).join(' / ') || 'unknown device';
    return `- sign-in ${iso(l.at)} (last used ${iso(l.lastUsedAt)}) from IP ${l.ip ?? 'unknown'}, ${device}`;
  });
  const spends = input.spends
    .slice(0, 200)
    .map((s) => `- ${iso(s.at)}: ${s.what}, ${s.coins.toString()} coins`);
  const activity = [
    `Kabso Live account @${buyer.username} (${buyer.email}). Order ${order.id}.`,
    `Terms accepted ${iso(terms.acceptedAt)} from IP ${terms.ip ?? 'unknown'} (${terms.userAgent ?? 'unknown agent'}).`,
    `Coins credited ${order.creditedAt ? iso(order.creditedAt) : '(not credited)'}.`,
    '',
    `Account sign-ins (${input.logins.length}):`,
    ...(logins.length > 0 ? logins : ['- none recorded']),
    '',
    `Use of the purchased coins (first in, first out; ${input.spends.length} uses, ${input.unspentCoins.toString()} coins unused):`,
    ...(spends.length > 0 ? spends : ['- none: the coins were not used']),
  ].join('\n');
  const disclosure =
    `Before paying, the customer ticked the statement «${terms.text}» ("${TOPUP_TERMS.en}"), version ` +
    `${terms.version}, on the Kabso website at ${iso(terms.acceptedAt)} from IP ${terms.ip ?? 'unknown'} with ` +
    `user agent "${terms.userAgent ?? 'unknown'}". Checkout could not start without it.`;
  const evidence: DisputeEvidenceText = {
    access_activity_log: clip(activity),
    customer_email_address: buyer.email,
    customer_name: buyer.displayName,
    product_description:
      `${coins} Kabso Live coins (digital in-app currency) for ${price}, delivered instantly to the account ` +
      `@${buyer.username} on payment. Coins buy virtual gifts and features inside the Kabso Live app.`,
    refund_policy: `${TOPUP_TERMS.en} (${TOPUP_TERMS.ar}).`,
    refund_policy_disclosure: clip(disclosure),
    service_date: (order.creditedAt ?? order.createdAt).toISOString().slice(0, 10),
    uncategorized_text: clip(
      [
        `Digital goods delivered: ${coins} coins were credited to the customer's own account at ` +
          `${order.creditedAt ? iso(order.creditedAt) : 'payment'} (statement descriptor ${input.statementDescriptor}).`,
        `The customer signed in with their own password to buy; the coins were then used as listed in the ` +
          `access activity log. Recipients of gifts are other users and are not identified here.`,
        `Payment method: ${order.paymentMethodType ?? 'card'}; payment ${order.paymentIntentId ?? '(unknown)'}.`,
      ].join('\n'),
    ),
  };
  if (terms.ip) evidence.customer_purchase_ip = terms.ip;
  const receiptLines = [
    'Kabso Live - Receipt',
    '',
    `Order: ${order.id}`,
    `Date: ${iso(order.creditedAt ?? order.createdAt)}`,
    `Customer: @${buyer.username} <${buyer.email}>`,
    `Item: ${coins} Kabso Live coins (digital)`,
    `Amount paid: ${price}`,
    `Payment: ${order.paymentIntentId ?? '-'} (${order.paymentMethodType ?? 'card'})`,
    `Statement descriptor: ${input.statementDescriptor}`,
    '',
    `Terms accepted: "${TOPUP_TERMS.en}" (version ${terms.version})`,
    `  at ${iso(terms.acceptedAt)} from IP ${terms.ip ?? 'unknown'}`,
    `Coins delivered to the account: ${order.creditedAt ? iso(order.creditedAt) : 'not yet'}`,
  ];
  return { evidence, receiptLines };
}

/** Escapes a PDF literal string; non-ASCII becomes '?' (the standard Helvetica font). */
function pdfText(line: string): string {
  return line
    .replace(/[^\x20-\x7e]/g, '?')
    .replace(/\\/g, '\\\\')
    .replace(/\(/g, '\\(')
    .replace(/\)/g, '\\)');
}

/** A one-page A4 PDF of plain text lines (at most 50 lines of 95 characters). */
export function simplePdf(lines: readonly string[]): Buffer {
  const body = lines
    .slice(0, 50)
    .map((l) => `(${pdfText(l.slice(0, 95))}) Tj T*`)
    .join('\n');
  const content = `BT\n/F1 11 Tf\n50 790 Td\n15 TL\n${body}\nET`;
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    `<< /Length ${Buffer.byteLength(content, 'latin1')} >>\nstream\n${content}\nendstream`,
  ];
  let pdf = '%PDF-1.4\n';
  const offsets: number[] = [];
  objects.forEach((o, i) => {
    offsets.push(Buffer.byteLength(pdf, 'latin1'));
    pdf += `${i + 1} 0 obj\n${o}\nendobj\n`;
  });
  const xref = Buffer.byteLength(pdf, 'latin1');
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (const off of offsets) pdf += `${String(off).padStart(10, '0')} 00000 n \n`;
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(pdf, 'latin1');
}
