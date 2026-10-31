import Stripe from 'stripe';

/**
 * v1.59-social (D190): the few Stripe API calls card top-ups make, behind one port so tests replace them (no
 * network in tests: they override {@link STRIPE_API_FACTORY}). Webhook signatures are verified with the library's own `Stripe.webhooks` (no API call).
 */
/**
 * v1.64-social (D196, §10.53.1): the keys can change at run time (the OWNER enters them in the panel), so the module
 * provides a factory and `PaymentSettingsStore` creates a client per key (a new key = a new client, no restart).
 * Tests override this token.
 */
export const STRIPE_API_FACTORY = Symbol('STRIPE_API_FACTORY');
export type StripeApiFactory = (secretKey: string) => StripeApi;

/** What Stripe answered to the panel's «اختبار الاتصال» (a harmless `balance.retrieve`). */
export type StripeKeyCheck =
  | { readonly ok: true; readonly livemode: boolean | null; readonly restricted: boolean }
  | { readonly ok: false; readonly reason: 'rejected' };

/** Stripe could not be reached (network, Stripe 5xx): the key is neither good nor bad yet. */
export class StripeUnreachableError extends Error {}

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
  /**
   * D196: checks the key with `balance.retrieve` (reads nothing the panel shows). A restricted key without the
   * balance permission is still a working key (`restricted`); an unknown, revoked or expired key is `rejected`;
   * no answer throws {@link StripeUnreachableError}.
   */
  checkKey(): Promise<StripeKeyCheck>;
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
    async checkKey() {
      try {
        const balance = await stripe.balance.retrieve(undefined, { maxNetworkRetries: 0, timeout: 10_000 });
        return { ok: true, livemode: balance.livemode, restricted: false };
      } catch (err) {
        if (err instanceof Stripe.errors.StripePermissionError)
          return { ok: true, livemode: null, restricted: true };
        if (err instanceof Stripe.errors.StripeAuthenticationError) return { ok: false, reason: 'rejected' };
        // The message of a Stripe error never carries the key; still, only the class name leaves here.
        throw new StripeUnreachableError(err instanceof Error ? err.name : 'StripeError');
      }
    },
  };
}

/** Verifies the `Stripe-Signature` header over the exact raw body; throws on a bad or stale signature. */
export function verifyStripeEvent(rawBody: Buffer, signature: string, secret: string): Stripe.Event {
  return Stripe.webhooks.constructEvent(rawBody, signature, secret, 300);
}

/**
 * D196: verifies with the current signing secret, then with the previous one while its 10-minute grace after a
 * rotation lasts (events Stripe signed before the change still verify). Throws the first error when none matches.
 */
export function verifyStripeEventWithAny(
  rawBody: Buffer,
  signature: string,
  secrets: readonly string[],
): Stripe.Event {
  let first: Error | null = null;
  for (const secret of secrets) {
    try {
      return verifyStripeEvent(rawBody, signature, secret);
    } catch (err) {
      first ??= err instanceof Error ? err : new Error('webhook signature');
    }
  }
  throw first ?? new Error('no webhook secret');
}

export type { Stripe };
