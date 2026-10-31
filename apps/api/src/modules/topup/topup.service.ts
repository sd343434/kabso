import { Inject, Injectable, Logger } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma, TopupOrder } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { STRIPE_API, verifyStripeEvent, type Stripe, type StripeApi } from './stripe-api.js';
import {
  attributionIn,
  closeCaseIn,
  creditOrderIn,
  freezeBuyerIn,
  KABSO_INITIATED,
  liftFreezeIfClearIn,
  lockOrderIn,
  openCaseIn,
  reconcileOrderIn,
} from './topup-core.js';
import { buildEvidence, findPackage, simplePdf, TOPUP_TERMS, type TopupLocale } from './topup-rules.js';

/** `TopupPackages` (openapi v1.59-social). */
export interface TopupPackagesDto {
  currency: string;
  packages: { id: string; coins: number; priceMinor: number }[];
  bankTransfer: boolean;
  terms: { version: string; ar: string; en: string };
}

/** `TopupCheckout`. */
export interface TopupCheckoutDto {
  orderId: string;
  checkoutUrl: string;
  expiresAt: string;
}

/** `TopupOrder`. */
export interface TopupOrderDto {
  id: string;
  packageId: string;
  coins: number;
  amountMinor: number;
  currency: string;
  status: TopupOrder['status'];
  credited: boolean;
  coinsReversed: number;
  createdAt: string;
  creditedAt: string | null;
}

/** `TopupMe`. */
export interface TopupMeDto {
  coins: number;
  frozen: boolean;
}

export interface RequestInfo {
  readonly ip: string | null;
  readonly userAgent: string | null;
  readonly requestId: string | null;
}

const checkoutSchema = z.strictObject({
  packageId: z.string().min(1).max(32),
  termsAccepted: z.literal(true),
  termsVersion: z.string().min(1).max(32),
  locale: z.enum(['ar', 'en']).default('ar'),
});

/** A Stripe API call to make after the event's database step committed. */
type FollowUp =
  { kind: 'auto_refund'; orderId: string } | { kind: 'dispute_evidence'; orderId: string; disputeId: string };

const idOf = (v: string | { id: string } | null | undefined): string | null =>
  v === null || v === undefined ? null : typeof v === 'string' ? v : v.id;

/**
 * Card top-ups on the Kabso website through Stripe Checkout (v1.59-social, D190, CONVENTIONS §10.53). The website
 * records the terms acceptance and creates the session; the coins come ONLY from the signed webhook
 * (`checkout.session.completed` paid, or a bank transfer's `async_payment_succeeded`), exactly once per order.
 * Refunds, early-fraud warnings and disputes take the coins back (the balance may go below 0), freeze the buyer
 * from card purchases and open an admin case with the FIFO gift attribution; host cherries are never taken back
 * automatically. Every Stripe event is applied once (its id).
 */
@Injectable()
export class TopupService {
  private readonly logger = new Logger(TopupService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(STRIPE_API) private readonly stripe: StripeApi | null,
  ) {}

  /** The Stripe settings, or 503 TOPUP_UNAVAILABLE (keys missing). */
  private enabled(): NonNullable<AppConfig['topup']['stripe']> & { api: StripeApi } {
    const s = this.config.topup.stripe;
    if (!s || !this.stripe) throw new AppException(ErrorCode.TOPUP_UNAVAILABLE);
    return { ...s, api: this.stripe };
  }

  packages(): TopupPackagesDto {
    this.enabled();
    const t = this.config.topup;
    return {
      currency: t.currency,
      packages: t.packages.map((p) => ({ ...p })),
      bankTransfer: t.bankTransfer.enabled,
      terms: { version: t.termsVersion, ar: TOPUP_TERMS.ar, en: TOPUP_TERMS.en },
    };
  }

  /** The app's «الشحن من الموقع» link (store policy; off by default), or null. */
  websiteUrl(): string | null {
    const s = this.config.topup.stripe;
    return this.config.topup.appLinkEnabled && s ? `${s.publicBaseUrl}/topup` : null;
  }

  async me(userId: string): Promise<TopupMeDto> {
    this.enabled();
    const [wallet, freeze] = await Promise.all([
      this.prisma.wallet.findUnique({ where: { userId }, select: { coins: true } }),
      this.prisma.topupFreeze.findUnique({ where: { userId }, select: { userId: true } }),
    ]);
    return { coins: Number(wallet?.coins ?? 0n), frozen: freeze !== null };
  }

  async order(userId: string, orderId: string): Promise<TopupOrderDto> {
    this.enabled();
    const order = z.uuid().safeParse(orderId).success
      ? await this.prisma.topupOrder.findUnique({ where: { id: orderId } })
      : null;
    if (!order || order.userId !== userId) throw new AppException(ErrorCode.NOT_FOUND);
    return {
      id: order.id,
      packageId: order.packageId,
      coins: Number(order.coins),
      amountMinor: order.amountMinor,
      currency: order.currency,
      status: order.status,
      credited: order.creditedAt !== null,
      coinsReversed: Number(order.coinsReversed),
      createdAt: order.createdAt.toISOString(),
      creditedAt: order.creditedAt?.toISOString() ?? null,
    };
  }

  /**
   * Records the terms acceptance (time, IP, user agent) and the order with the SERVER's price, then creates the
   * hosted Checkout session (3-D Secure always requested, receipt email, statement descriptor). 400 an unknown
   * package / terms not accepted / a stale terms version; 403 TOPUP_ACCOUNT_FROZEN; 503 TOPUP_UNAVAILABLE.
   */
  async checkout(userId: string, body: unknown, info: RequestInfo): Promise<TopupCheckoutDto> {
    const s = this.enabled();
    const parsed = checkoutSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const t = this.config.topup;
    if (input.termsVersion !== t.termsVersion) {
      throw AppException.validation([{ field: 'termsVersion', issue: 'invalid_value' }]);
    }
    const pkg = findPackage(t.packages, input.packageId);
    if (!pkg) throw AppException.validation([{ field: 'packageId', issue: 'invalid_value' }]);
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { email: true } });
    if (!user) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    if (await this.prisma.topupFreeze.findUnique({ where: { userId }, select: { userId: true } })) {
      throw new AppException(ErrorCode.TOPUP_ACCOUNT_FROZEN);
    }
    const locale: TopupLocale = input.locale;
    const methods = t.bankTransfer.enabled ? ['card', 'customer_balance'] : ['card'];
    const customer = t.bankTransfer.enabled ? await this.customerFor(userId, user.email, s.api) : null;
    const now = this.clock.now();
    const orderId = uuidv7();
    const termsId = uuidv7();
    // The acceptance is stored BEFORE the session exists (owner rule).
    await this.prisma.$transaction(async (tx) => {
      await tx.topupTermsAcceptance.create({
        data: {
          id: termsId,
          userId,
          termsVersion: t.termsVersion,
          termsText: TOPUP_TERMS[locale],
          locale,
          ip: info.ip?.slice(0, 64) ?? null,
          userAgent: info.userAgent?.slice(0, 512) ?? null,
          acceptedAt: now,
        },
      });
      await tx.topupOrder.create({
        data: {
          id: orderId,
          userId,
          termsAcceptanceId: termsId,
          packageId: pkg.id,
          coins: BigInt(pkg.coins),
          amountMinor: pkg.priceMinor,
          currency: t.currency,
          paymentMethodTypes: methods,
          createdAt: now,
          updatedAt: now,
        },
      });
    });
    const metadata = { kabso_order_id: orderId, kabso_user_id: userId };
    const params: Stripe.Checkout.SessionCreateParams = {
      mode: 'payment',
      client_reference_id: orderId,
      metadata,
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: t.currency.toLowerCase(),
            unit_amount: pkg.priceMinor,
            product_data: {
              name: `${pkg.coins.toLocaleString('en-US')} Kabso Live coins`,
              description: `${TOPUP_TERMS.en}.`,
            },
          },
        },
      ],
      // A filter on the methods the dashboard enables: card only, plus bank transfers when switched on.
      allowed_payment_method_types: methods,
      payment_method_options: {
        card: { request_three_d_secure: 'any' },
        ...(t.bankTransfer.enabled
          ? {
              customer_balance: {
                funding_type: 'bank_transfer' as const,
                bank_transfer: {
                  type: t.bankTransfer.type,
                },
              },
            }
          : {}),
      },
      payment_intent_data: {
        receipt_email: user.email,
        description: `Kabso Live coins (${pkg.coins})`,
        metadata,
        ...(t.statementDescriptorSuffix ? { statement_descriptor_suffix: t.statementDescriptorSuffix } : {}),
      },
      ...(customer ? { customer } : { customer_email: user.email }),
      success_url: `${s.publicBaseUrl}/topup/success?order=${orderId}&lang=${locale}`,
      cancel_url: `${s.publicBaseUrl}/topup/cancel?order=${orderId}&lang=${locale}`,
      locale: locale === 'en' ? 'en' : 'auto',
      expires_at: Math.floor(now.getTime() / 1000) + 30 * 60,
    };
    let session: { id: string; url: string | null; expires_at: number };
    try {
      session = await s.api.createCheckoutSession(params, `kabso-checkout-${orderId}`);
      if (!session.url) throw new Error('Checkout session without a URL');
    } catch (err) {
      this.logger.error({ error: safeErrorLog(err), order: orderId }, 'Stripe checkout session failed');
      await this.prisma.topupOrder.update({
        where: { id: orderId },
        data: { status: 'FAILED', updatedAt: now },
      });
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    }
    await this.prisma.$transaction(async (tx) => {
      await tx.topupOrder.update({ where: { id: orderId }, data: { stripeSessionId: session.id } });
      await tx.auditLog.create({
        data: {
          actorUserId: userId,
          action: AuditAction.TOPUP_CHECKOUT_CREATE,
          targetType: 'topup_order',
          targetId: orderId,
          metadata: {
            package: pkg.id,
            coins: pkg.coins,
            amountMinor: pkg.priceMinor,
            currency: t.currency,
            methods,
            terms: termsId,
            termsVersion: t.termsVersion,
          },
          ip: info.ip?.slice(0, 64) ?? null,
          requestId: info.requestId,
        },
      });
    });
    return {
      orderId,
      checkoutUrl: session.url,
      expiresAt: new Date(session.expires_at * 1000).toISOString(),
    };
  }

  /** The buyer's Stripe customer (bank transfers fund the customer's balance), created once. */
  private async customerFor(userId: string, email: string, api: StripeApi): Promise<string> {
    const found = await this.prisma.stripeCustomer.findUnique({ where: { userId } });
    if (found) return found.customerId;
    const created = await api.createCustomer(
      { email, metadata: { kabso_user_id: userId } },
      `kabso-customer-${userId}`,
    );
    await this.prisma.stripeCustomer.createMany({
      data: [{ userId, customerId: created.id }],
      skipDuplicates: true,
    });
    const row = await this.prisma.stripeCustomer.findUniqueOrThrow({ where: { userId } });
    return row.customerId;
  }

  /**
   * `POST /payments/stripe/webhook`: verifies the signature over the raw body (400 otherwise), then applies the
   * event once: its database step in one transaction keyed by the event id, then the Stripe calls it needs (an
   * automatic refund, the dispute evidence). A failed Stripe call answers 503 so Stripe retries; the database
   * step is idempotent and changes nothing the second time.
   */
  async webhook(rawBody: unknown, signature: string | undefined): Promise<{ received: true }> {
    const s = this.enabled();
    if (!Buffer.isBuffer(rawBody) || rawBody.length === 0 || !signature) {
      throw AppException.validation([{ field: 'Stripe-Signature', issue: 'invalid_value' }]);
    }
    let event: Stripe.Event;
    try {
      event = verifyStripeEvent(rawBody, signature, s.webhookSecret);
    } catch {
      this.logger.warn('Stripe webhook with a bad signature refused');
      throw AppException.validation([{ field: 'Stripe-Signature', issue: 'invalid_value' }]);
    }
    const now = this.clock.now();
    const step = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`
        INSERT INTO stripe_events (id, type, received_at) VALUES (${event.id}, ${event.type}, ${now})
        ON CONFLICT (id) DO NOTHING`;
      const [row] = await tx.$queryRaw<{ processed_at: Date | null }[]>`
        SELECT processed_at FROM stripe_events WHERE id = ${event.id} FOR UPDATE`;
      if (row?.processed_at) return null;
      const result = await this.applyIn(tx, event, now);
      await tx.stripeEvent.update({
        where: { id: event.id },
        data: {
          orderId: result.orderId,
          outcome: result.outcome,
          ...(result.followUps.length === 0 ? { processedAt: now } : {}),
        },
      });
      return result;
    });
    if (!step || step.followUps.length === 0) return { received: true };
    try {
      for (const f of step.followUps) {
        if (f.kind === 'auto_refund') await this.autoRefund(f.orderId, event.id, s.api);
        else await this.submitEvidence(f.orderId, f.disputeId, s.api);
      }
    } catch (err) {
      this.logger.error(
        { error: safeErrorLog(err), event: event.id },
        'Stripe follow-up failed; Stripe will retry',
      );
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    }
    await this.prisma.stripeEvent.update({
      where: { id: event.id },
      data: { processedAt: this.clock.now() },
    });
    return { received: true };
  }

  /** The database step of one event (inside its transaction). */
  private async applyIn(
    tx: Prisma.TransactionClient,
    event: Stripe.Event,
    now: Date,
  ): Promise<{ orderId: string | null; outcome: string; followUps: FollowUp[] }> {
    const none = (outcome: string, orderId: string | null = null) => ({ orderId, outcome, followUps: [] });
    switch (event.type) {
      case 'checkout.session.completed':
      case 'checkout.session.async_payment_succeeded':
      case 'checkout.session.async_payment_failed':
      case 'checkout.session.expired': {
        const session = event.data.object;
        const order = await this.orderForSessionIn(tx, session);
        if (!order) return this.unmatchedIn(tx, event);
        if (
          session.amount_total !== order.amountMinor ||
          session.currency?.toUpperCase() !== order.currency
        ) {
          this.logger.error(
            { order: order.id, event: event.id },
            'Stripe session amount differs from the order',
          );
          return none('amount_mismatch', order.id);
        }
        const pi = idOf(session.payment_intent);
        if (pi && order.stripePaymentIntentId !== pi) {
          await tx.topupOrder.update({ where: { id: order.id }, data: { stripePaymentIntentId: pi } });
        }
        const fresh = (await lockOrderIn(tx, order.id))!;
        if (event.type === 'checkout.session.expired') {
          if (fresh.status === 'PENDING' || fresh.status === 'AWAITING_FUNDS') {
            await this.setStatusIn(tx, fresh, 'EXPIRED', event.id, now);
          }
          return none('expired', order.id);
        }
        if (event.type === 'checkout.session.async_payment_failed') {
          if (fresh.creditedAt === null) await this.setStatusIn(tx, fresh, 'FAILED', event.id, now);
          return none('failed', order.id);
        }
        // Coins only for a paid session (a bank transfer completes unpaid first, then succeeds).
        if (session.payment_status !== 'paid') {
          if (fresh.status === 'PENDING') await this.setStatusIn(tx, fresh, 'AWAITING_FUNDS', event.id, now);
          return none('awaiting_funds', order.id);
        }
        const method =
          event.type === 'checkout.session.async_payment_succeeded' ||
          (fresh.paymentMethodTypes.length === 1 && fresh.paymentMethodTypes[0] === 'customer_balance')
            ? 'customer_balance'
            : 'card';
        const credited = await creditOrderIn(tx, fresh, now, this.config.recharge.badges, event.id, method);
        return none(credited ? 'credited' : 'already_credited', order.id);
      }
      case 'charge.refunded': {
        const charge = event.data.object;
        const order = await this.orderForPaymentIn(
          tx,
          idOf(charge.payment_intent),
          charge.id,
          charge.metadata,
        );
        if (!order) return this.unmatchedIn(tx, event);
        const refunded = Math.min(Math.max(order.refundedMinor, charge.amount_refunded), order.amountMinor);
        const fresh = await tx.topupOrder.update({
          where: { id: order.id },
          data: { refundedMinor: refunded, stripeChargeId: charge.id, updatedAt: now },
        });
        // Owner (CP-033 Q2): only a refund Kabso did NOT ask for freezes the buyer. Ours: the team's
        // (`payments-admin refund`, recorded before the call) and the automatic one after a fraud warning (that
        // warning already froze). When Stripe lists the refunds, their `kabso_initiated` metadata decides.
        const listed = charge.refunds?.data ?? [];
        const foreign =
          listed.length > 0
            ? listed
                .filter((r) => r.metadata?.[KABSO_INITIATED] !== 'true')
                .reduce((sum, r) => sum + (r.amount ?? 0), 0)
            : Math.max(
                0,
                refunded - order.teamRefundedMinor - (order.autoRefundId !== null ? order.amountMinor : 0),
              );
        const initiatedBy = foreign > 0 ? 'stripe' : 'kabso';
        const delta = await reconcileOrderIn(tx, fresh, event.id, now, null, {
          cause: 'refund',
          initiatedBy,
          reason:
            initiatedBy === 'kabso' ? (order.teamRefundReason ?? 'early_fraud_warning') : 'stripe_refund',
        });
        const reversed = await tx.topupOrder.findUniqueOrThrow({ where: { id: order.id } });
        if (refunded > 0) {
          if (foreign > 0) await freezeBuyerIn(tx, reversed, 'REFUND', now);
          // Our own refund after a fraud warning is already that warning's case.
          if (reversed.fraudWarningAt === null) await openCaseIn(tx, reversed, 'REFUND', charge.id, now);
        }
        return none(delta > 0n ? 'reversed' : 'refund_recorded', order.id);
      }
      case 'radar.early_fraud_warning.created': {
        const warning = event.data.object;
        const order = await this.orderForPaymentIn(
          tx,
          idOf(warning.payment_intent),
          idOf(warning.charge),
          null,
        );
        if (!order) return this.unmatchedIn(tx, event);
        const fresh = await tx.topupOrder.update({
          where: { id: order.id },
          data: {
            fraudWarningAt: order.fraudWarningAt ?? now,
            stripeChargeId: order.stripeChargeId ?? idOf(warning.charge),
            updatedAt: now,
          },
        });
        await reconcileOrderIn(tx, fresh, event.id, now);
        const reversed = await tx.topupOrder.findUniqueOrThrow({ where: { id: order.id } });
        await freezeBuyerIn(tx, reversed, 'EARLY_FRAUD_WARNING', now);
        await openCaseIn(tx, reversed, 'EARLY_FRAUD_WARNING', warning.id, now);
        // Refunding avoids the dispute fee; never after a dispute or a full refund.
        const refundable =
          reversed.autoRefundId === null &&
          reversed.disputeId === null &&
          reversed.refundedMinor < reversed.amountMinor &&
          reversed.creditedAt !== null;
        return {
          orderId: order.id,
          outcome: 'fraud_warning',
          followUps: refundable ? [{ kind: 'auto_refund', orderId: order.id }] : [],
        };
      }
      case 'charge.dispute.created':
      case 'charge.dispute.closed': {
        const dispute = event.data.object;
        const order = await this.orderForPaymentIn(
          tx,
          idOf(dispute.payment_intent),
          idOf(dispute.charge),
          null,
        );
        if (!order) return this.unmatchedIn(tx, event);
        const fresh = await tx.topupOrder.update({
          where: { id: order.id },
          data: {
            disputeId: dispute.id,
            disputeStatus: dispute.status,
            disputeAmountMinor: Math.min(dispute.amount, order.amountMinor),
            stripeChargeId: order.stripeChargeId ?? idOf(dispute.charge),
            updatedAt: now,
          },
        });
        const delta = await reconcileOrderIn(tx, fresh, event.id, now);
        const after = await tx.topupOrder.findUniqueOrThrow({ where: { id: order.id } });
        if (event.type === 'charge.dispute.created') {
          await freezeBuyerIn(tx, after, 'DISPUTE', now);
          await openCaseIn(tx, after, 'DISPUTE', dispute.id, now);
          const needsEvidence =
            after.evidenceSubmittedAt === null && dispute.status !== 'won' && dispute.status !== 'lost';
          return {
            orderId: order.id,
            outcome: delta > 0n ? 'dispute_reversed' : 'dispute_recorded',
            followUps: needsEvidence
              ? [{ kind: 'dispute_evidence', orderId: order.id, disputeId: dispute.id }]
              : [],
          };
        }
        const kase = await openCaseIn(tx, after, 'DISPUTE', dispute.id, now);
        if (dispute.status === 'won') {
          await closeCaseIn(tx, kase.id, now, 'Dispute won: the coins were given back.', 'won');
          await liftFreezeIfClearIn(tx, after.userId, now, 'dispute_won');
        } else {
          await tx.topupCase.update({ where: { id: kase.id }, data: { outcome: dispute.status } });
        }
        return none(
          dispute.status === 'won' ? 'dispute_won' : `dispute_${dispute.status}`.slice(0, 32),
          order.id,
        );
      }
      default:
        return none('ignored');
    }
  }

  private async setStatusIn(
    tx: Prisma.TransactionClient,
    order: TopupOrder,
    status: TopupOrder['status'],
    eventId: string,
    now: Date,
  ): Promise<void> {
    await tx.topupOrder.update({ where: { id: order.id }, data: { status, updatedAt: now } });
    await tx.auditLog.create({
      data: {
        action: AuditAction.TOPUP_STATUS,
        targetType: 'topup_order',
        targetId: order.id,
        metadata: { from: order.status, to: status, reference: eventId },
      },
    });
  }

  /** An event of a payment that is not one of ours (or not linked yet): recorded, audited, nothing else. */
  private async unmatchedIn(tx: Prisma.TransactionClient, event: Stripe.Event) {
    this.logger.warn({ event: event.id, type: event.type }, 'Stripe event for no known top-up order');
    await tx.auditLog.create({
      data: {
        action: AuditAction.TOPUP_EVENT_UNMATCHED,
        targetType: 'stripe_event',
        targetId: event.id.slice(0, 64),
        metadata: { type: event.type },
      },
    });
    return { orderId: null, outcome: 'unmatched', followUps: [] as FollowUp[] };
  }

  private async orderForSessionIn(
    tx: Prisma.TransactionClient,
    session: Stripe.Checkout.Session,
  ): Promise<TopupOrder | null> {
    const bySession = await tx.topupOrder.findUnique({ where: { stripeSessionId: session.id } });
    if (bySession) return bySession;
    // The session id is stored right after creation; the reference covers a webhook that arrives first.
    const ref = session.client_reference_id ?? session.metadata?.kabso_order_id ?? null;
    if (!ref || !z.uuid().safeParse(ref).success) return null;
    const byRef = await tx.topupOrder.findUnique({ where: { id: ref } });
    if (!byRef || (byRef.stripeSessionId !== null && byRef.stripeSessionId !== session.id)) return null;
    if (byRef.stripeSessionId === null) {
      await tx.topupOrder.update({ where: { id: byRef.id }, data: { stripeSessionId: session.id } });
    }
    return byRef;
  }

  private async orderForPaymentIn(
    tx: Prisma.TransactionClient,
    paymentIntentId: string | null,
    chargeId: string | null,
    metadata: Stripe.Metadata | null,
  ): Promise<TopupOrder | null> {
    let id: string | null = null;
    if (paymentIntentId) {
      id =
        (await tx.topupOrder.findUnique({ where: { stripePaymentIntentId: paymentIntentId } }))?.id ?? null;
    }
    if (!id && chargeId)
      id = (await tx.topupOrder.findFirst({ where: { stripeChargeId: chargeId } }))?.id ?? null;
    const ref = metadata?.kabso_order_id;
    if (!id && ref && z.uuid().safeParse(ref).success) {
      id = (await tx.topupOrder.findUnique({ where: { id: ref } }))?.id ?? null;
    }
    return id ? lockOrderIn(tx, id) : null;
  }

  /** The automatic refund after an early-fraud warning (the reversal is already done). Idempotent key per order. */
  private async autoRefund(orderId: string, eventId: string, api: StripeApi): Promise<void> {
    const order = await this.prisma.topupOrder.findUniqueOrThrow({ where: { id: orderId } });
    if (order.autoRefundId !== null || !order.stripePaymentIntentId) return;
    const refund = await api.createRefund(
      {
        payment_intent: order.stripePaymentIntentId,
        reason: 'fraudulent',
        metadata: {
          kabso_order_id: order.id,
          [KABSO_INITIATED]: 'true',
          kabso_reason: 'early_fraud_warning',
        },
      },
      `kabso-efw-refund-${order.id}`,
    );
    await this.prisma.$transaction(async (tx) => {
      await tx.topupOrder.update({ where: { id: orderId }, data: { autoRefundId: refund.id } });
      await tx.auditLog.create({
        data: {
          action: AuditAction.TOPUP_AUTO_REFUND,
          targetType: 'topup_order',
          targetId: orderId,
          metadata: { refund: refund.id, status: refund.status ?? '', event: eventId },
        },
      });
    });
  }

  /**
   * Builds and submits the dispute evidence: the buyer's own sign-ins (IPs, devices), what the purchase's coins
   * paid for (no recipient), the buyer's email, the terms acceptance and a receipt PDF. Never another user's data.
   */
  private async submitEvidence(orderId: string, disputeId: string, api: StripeApi): Promise<void> {
    const order = await this.prisma.topupOrder.findUniqueOrThrow({ where: { id: orderId } });
    if (order.evidenceSubmittedAt !== null) return;
    const [user, terms, sessions, attribution] = await Promise.all([
      this.prisma.user.findUniqueOrThrow({
        where: { id: order.userId },
        select: { email: true, profile: { select: { username: true, displayName: true } } },
      }),
      this.prisma.topupTermsAcceptance.findUniqueOrThrow({ where: { id: order.termsAcceptanceId } }),
      this.prisma.session.findMany({
        where: { userId: order.userId },
        orderBy: { createdAt: 'desc' },
        take: 100,
        select: {
          createdAt: true,
          lastUsedAt: true,
          ip: true,
          userAgent: true,
          deviceName: true,
          platform: true,
        },
      }),
      this.prisma.$transaction((tx) => attributionIn(tx, order)),
    ]);
    const where = (place: string) =>
      place === 'DM' ? 'in a direct conversation' : place === 'LIVE' ? 'in a live room' : '';
    const { evidence, receiptLines } = buildEvidence({
      order: {
        id: order.id,
        coins: order.coins,
        amountMinor: order.amountMinor,
        currency: order.currency,
        createdAt: order.createdAt,
        creditedAt: order.creditedAt,
        paymentIntentId: order.stripePaymentIntentId,
        paymentMethodType: order.paymentMethodType,
      },
      buyer: {
        email: user.email,
        displayName: user.profile?.displayName ?? '',
        username: user.profile?.username ?? '',
      },
      terms: {
        version: terms.termsVersion,
        text: terms.termsText,
        locale: terms.locale,
        acceptedAt: terms.acceptedAt,
        ip: terms.ip,
        userAgent: terms.userAgent,
      },
      logins: sessions.map((x) => ({
        at: x.createdAt,
        lastUsedAt: x.lastUsedAt,
        ip: x.ip,
        userAgent: x.userAgent,
        device: [x.deviceName, x.platform].filter((v) => v).join(' ') || null,
      })),
      spends: [
        ...attribution.gifts.map((g) => ({
          at: new Date(g.sentAt),
          what: `sent the gift "${g.giftCode ?? 'gift'}" ${where(g.place)}`.trim(),
          coins: BigInt(g.coinsFromPurchase),
        })),
        ...attribution.otherSpends.map((o) => ({
          at: new Date(o.at),
          what: `spent on ${o.reason.toLowerCase().replace(/_/g, ' ')}`,
          coins: BigInt(o.coins),
        })),
      ].sort((a, b) => a.at.getTime() - b.at.getTime()),
      unspentCoins: BigInt(attribution.unspentCoins),
      statementDescriptor: 'KABSO LIVE',
    });
    const receipt = await api.uploadEvidenceFile(`kabso-receipt-${order.id}.pdf`, simplePdf(receiptLines));
    const submit = this.config.topup.disputeAutoSubmit;
    await api.updateDispute(disputeId, {
      evidence: { ...evidence, receipt: receipt.id },
      metadata: { kabso_order_id: order.id },
      submit,
    });
    await this.prisma.$transaction(async (tx) => {
      await tx.topupOrder.update({ where: { id: orderId }, data: { evidenceSubmittedAt: this.clock.now() } });
      await tx.auditLog.create({
        data: {
          action: AuditAction.TOPUP_DISPUTE_EVIDENCE,
          targetType: 'topup_order',
          targetId: orderId,
          metadata: {
            dispute: disputeId,
            submitted: submit,
            fields: [...Object.keys(evidence), 'receipt'].sort(),
            logins: sessions.length,
            gifts: attribution.gifts.length,
          },
        },
      });
    });
  }
}
