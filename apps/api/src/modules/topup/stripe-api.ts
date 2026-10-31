import Stripe from 'stripe';

/**
 * v1.59-social (D190): the few Stripe API calls card top-ups make, behind one port so tests replace them (no
 * network in tests). Webhook signatures are verified with the library's own `Stripe.webhooks` (no API call).
 */
export const STRIPE_API = Symbol('STRIPE_API');

export interface StripeApi {
  createCheckoutSession(
    params: Stripe.Checkout.SessionCreateParams,
    idempotencyKey: string,
  ): Promise<{ id: string; url: string | null; expires_at: number }>;
  createRefund(
    params: Stripe.RefundCreateParams,
    idempotencyKey: string,
  ): Promise<{ id: string; status: string | null }>;
  updateDispute(id: string, params: Stripe.DisputeUpdateParams): Promise<{ id: string; status: string }>;
  uploadEvidenceFile(name: string, data: Buffer): Promise<{ id: string }>;
  createCustomer(params: Stripe.CustomerCreateParams, idempotencyKey: string): Promise<{ id: string }>;
}

/** The real client (`maxNetworkRetries` with Stripe's idempotency keys); null when top-ups are off. */
export function createStripeApi(secretKey: string): StripeApi {
  const stripe = new Stripe(secretKey, {
    maxNetworkRetries: 2,
    timeout: 20_000,
    appInfo: { name: 'kabso-api' },
  });
  return {
    async createCheckoutSession(params, idempotencyKey) {
      const s = await stripe.checkout.sessions.create(params, { idempotencyKey });
      return { id: s.id, url: s.url, expires_at: s.expires_at };
    },
    async createRefund(params, idempotencyKey) {
      const r = await stripe.refunds.create(params, { idempotencyKey });
      return { id: r.id, status: r.status };
    },
    async updateDispute(id, params) {
      const d = await stripe.disputes.update(id, params);
      return { id: d.id, status: d.status };
    },
    async uploadEvidenceFile(name, data) {
      const f = await stripe.files.create({
        purpose: 'dispute_evidence',
        file: { data, name, type: 'application/pdf' },
      });
      return { id: f.id };
    },
    async createCustomer(params, idempotencyKey) {
      const c = await stripe.customers.create(params, { idempotencyKey });
      return { id: c.id };
    },
  };
}

/** Verifies the `Stripe-Signature` header over the exact raw body; throws on a bad or stale signature. */
export function verifyStripeEvent(rawBody: Buffer, signature: string, secret: string): Stripe.Event {
  return Stripe.webhooks.constructEvent(rawBody, signature, secret, 300);
}

export type { Stripe };
