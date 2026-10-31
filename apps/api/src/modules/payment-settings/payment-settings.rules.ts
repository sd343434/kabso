import { inspect } from 'node:util';
import { z } from 'zod';
import type { AppConfig } from '../../config/app-config.js';
import { AdminSecretBox } from '../admin-panel/admin-crypto.js';

/**
 * v1.64-social (D196, CONVENTIONS §10.53.1): the Stripe keys and options the OWNER enters in the admin panel
 * «الدفع (Stripe)» — the pure rules (no I/O): the key shapes, the masked fingerprint, the encryption, how the panel's
 * row and the server environment resolve into the settings top-ups run with, and the webhook's previous-secret grace.
 */

/** HKDF info of the key that seals the panel's Stripe secrets (a different key from the TOTP secrets'). */
export const PAYMENT_SETTINGS_KEY_INFO = 'payment-settings/v1';
/** Additional data binding each sealed value to its column. */
export const AAD = {
  secretKey: 'payment_settings.secret_key',
  webhookSecret: 'payment_settings.webhook_secret',
  previousWebhookSecret: 'payment_settings.previous_webhook_secret',
} as const;
/** After a webhook secret changes, the previous one still verifies for 10 minutes (in-flight deliveries). */
export const WEBHOOK_SECRET_GRACE_MS = 10 * 60 * 1000;

/** The events the Stripe webhook destination must send (DEPLOYMENT §5.29 step 8; `TopupService.applyIn`). */
export const STRIPE_WEBHOOK_EVENTS = [
  'checkout.session.completed',
  'checkout.session.async_payment_succeeded',
  'checkout.session.async_payment_failed',
  'checkout.session.expired',
  'charge.refunded',
  'radar.early_fraud_warning.created',
  'charge.dispute.created',
  'charge.dispute.closed',
] as const;
export const STRIPE_WEBHOOK_PATH = '/api/v1/payments/stripe/webhook';

export const SECRET_KEY_PATTERN = /^(sk|rk)_(test|live)_[A-Za-z0-9_]{8,250}$/;
export const WEBHOOK_SECRET_PATTERN = /^whsec_[A-Za-z0-9+/=_]{8,250}$/;
export const PUBLISHABLE_KEY_PATTERN = /^pk_(test|live)_[A-Za-z0-9_]{8,250}$/;
export const DESCRIPTOR_SUFFIX_PATTERN = /^[A-Za-z0-9 ]{1,10}$/;

/**
 * A secret value that never leaves by accident: JSON, string conversion and `util.inspect` (what loggers use) all
 * give `[redacted]`. Only {@link Secret.reveal} returns the value, where a Stripe call needs it.
 */
export class Secret {
  readonly #value: string;
  constructor(value: string) {
    this.#value = value;
  }
  reveal(): string {
    return this.#value;
  }
  toJSON(): string {
    return '[redacted]';
  }
  toString(): string {
    return '[redacted]';
  }
  [inspect.custom](): string {
    return '[redacted]';
  }
}

export type KeyMode = 'live' | 'test';
export type KeyKind = 'secret' | 'restricted' | 'webhook';
export type KeySource = 'panel' | 'env';

/** `PaymentKeyFingerprint`: all the panel ever shows of a secret. */
export interface KeyFingerprint {
  readonly kind: KeyKind;
  readonly mode: KeyMode | null;
  readonly last4: string;
}

export function modeOf(key: string): KeyMode | null {
  const m = /^(?:sk|rk|pk)_(test|live)_/.exec(key);
  return m ? (m[1] as KeyMode) : null;
}

export function isTestKey(key: string): boolean {
  return modeOf(key) === 'test';
}

/** The type and the last 4 characters (nothing else of the secret). */
export function fingerprintOf(key: string): KeyFingerprint {
  const kind: KeyKind = key.startsWith('whsec_')
    ? 'webhook'
    : key.startsWith('rk_')
      ? 'restricted'
      : 'secret';
  return { kind, mode: kind === 'webhook' ? null : modeOf(key), last4: key.slice(-4) };
}

/** The one string form audit rows carry: `rk_live_…AbCd`, `whsec_…wxYz` (never more). */
export function maskedOf(key: string | null): string | null {
  if (key === null) return null;
  const prefix = /^(?:(?:sk|rk|pk)_(?:test|live)_|whsec_)/.exec(key)?.[0] ?? '';
  return `${prefix}…${key.slice(-4)}`;
}

/** The stored row (`payment_settings`, id 1), as Prisma returns it. */
export interface PaymentSettingsRow {
  readonly secretKeyEnc: string | null;
  readonly secretKeyPrefix: string | null;
  readonly secretKeyLast4: string | null;
  readonly secretKeySetById: string | null;
  readonly secretKeySetAt: Date | null;
  readonly webhookSecretEnc: string | null;
  readonly webhookSecretLast4: string | null;
  readonly webhookSecretSetById: string | null;
  readonly webhookSecretSetAt: Date | null;
  readonly previousWebhookSecretEnc: string | null;
  readonly previousWebhookSecretUntil: Date | null;
  readonly publishableKey: string | null;
  readonly bankTransferEnabled: boolean | null;
  readonly statementDescriptorSuffix: string | null;
  readonly disputeAutoSubmit: boolean | null;
  readonly appLinkEnabled: boolean | null;
  readonly updatedAt: Date;
}

/** The options top-ups run with (the panel's value, else the server's). */
export interface TopupOptions {
  readonly bankTransfer: { readonly enabled: boolean; readonly type: string };
  readonly statementDescriptorSuffix: string | null;
  readonly disputeAutoSubmit: boolean;
  readonly appLinkEnabled: boolean;
}

/** The keys top-ups run with. Secrets are {@link Secret}s: this object can be logged or serialised safely. */
export interface ResolvedStripeKeys {
  readonly source: KeySource;
  readonly secretKey: Secret;
  readonly webhookSecret: Secret;
  /** Still accepted by the webhook until `previousUntil` (after a rotation or a clear). */
  readonly previousWebhookSecret: Secret | null;
  readonly previousUntil: Date | null;
  readonly publicBaseUrl: string;
  readonly testMode: boolean;
}

export interface ResolvedPaymentSettings {
  /** Null: card top-ups are off (503 TOPUP_UNAVAILABLE). */
  readonly stripe: ResolvedStripeKeys | null;
  readonly options: TopupOptions;
  readonly publishableKey: string | null;
  /** The panel's keys exist but cannot be used (another ADMIN_TOTP_KEY, or a test key in production). */
  readonly panelKeysIgnored: 'unreadable' | 'test_key_in_production' | null;
}

export interface ResolveEnv {
  readonly production: boolean;
  readonly topup: Pick<
    AppConfig['topup'],
    | 'stripe'
    | 'publicBaseUrl'
    | 'allowTestKeysInProduction'
    | 'bankTransfer'
    | 'statementDescriptorSuffix'
    | 'disputeAutoSubmit'
    | 'appLinkEnabled'
  >;
}

export function newPaymentSecretBox(adminTotpKey: string | null): AdminSecretBox | null {
  return adminTotpKey ? new AdminSecretBox(adminTotpKey, PAYMENT_SETTINGS_KEY_INFO) : null;
}

/** Test keys are allowed outside production, and in production only with the env switch. */
export function testKeysAllowed(
  env: Pick<ResolveEnv, 'production'> & { allowTestKeysInProduction: boolean },
) {
  return !env.production || env.allowTestKeysInProduction;
}

/**
 * The source of truth (owner D196): the panel's keys when both are stored and readable, else the env keys, else
 * none. The base URL is the server's (infrastructure). Options: the panel's value when set, else the env's.
 */
export function resolvePaymentSettings(
  row: PaymentSettingsRow | null,
  env: ResolveEnv,
  box: AdminSecretBox | null,
  now: Date,
): ResolvedPaymentSettings {
  const t = env.topup;
  const options: TopupOptions = {
    bankTransfer: {
      enabled: row?.bankTransferEnabled ?? t.bankTransfer.enabled,
      type: t.bankTransfer.type,
    },
    statementDescriptorSuffix:
      row?.statementDescriptorSuffix === null || row?.statementDescriptorSuffix === undefined
        ? t.statementDescriptorSuffix
        : row.statementDescriptorSuffix === ''
          ? null
          : row.statementDescriptorSuffix,
    disputeAutoSubmit: row?.disputeAutoSubmit ?? t.disputeAutoSubmit,
    appLinkEnabled: row?.appLinkEnabled ?? t.appLinkEnabled,
  };
  const previousPlain =
    row?.previousWebhookSecretEnc &&
    row.previousWebhookSecretUntil &&
    row.previousWebhookSecretUntil > now &&
    box
      ? box.open(row.previousWebhookSecretEnc, AAD.previousWebhookSecret)
      : null;
  const previous = previousPlain
    ? { previousWebhookSecret: new Secret(previousPlain), previousUntil: row!.previousWebhookSecretUntil }
    : { previousWebhookSecret: null, previousUntil: null };

  let panelKeysIgnored: ResolvedPaymentSettings['panelKeysIgnored'] = null;
  let stripe: ResolvedStripeKeys | null = null;
  if (row?.secretKeyEnc && row.webhookSecretEnc) {
    const sk = box?.open(row.secretKeyEnc, AAD.secretKey) ?? null;
    const wh = box?.open(row.webhookSecretEnc, AAD.webhookSecret) ?? null;
    if (sk === null || wh === null) panelKeysIgnored = 'unreadable';
    else if (isTestKey(sk) && !testKeysAllowed({ production: env.production, ...t })) {
      panelKeysIgnored = 'test_key_in_production';
    } else if (t.publicBaseUrl !== null) {
      stripe = {
        source: 'panel',
        secretKey: new Secret(sk),
        webhookSecret: new Secret(wh),
        ...previous,
        publicBaseUrl: t.publicBaseUrl,
        testMode: isTestKey(sk),
      };
    }
  }
  // Panel keys without TOPUP_PUBLIC_BASE_URL leave top-ups off (env keys need it too, so there is no fallback).
  // Unusable panel keys (another ADMIN_TOTP_KEY, a test key in production) fall back to the env keys.
  if (!stripe && t.stripe) {
    stripe = {
      source: 'env',
      secretKey: new Secret(t.stripe.secretKey),
      webhookSecret: new Secret(t.stripe.webhookSecret),
      ...previous,
      publicBaseUrl: t.stripe.publicBaseUrl,
      testMode: t.stripe.testMode,
    };
  }
  return { stripe, options, publishableKey: row?.publishableKey ?? null, panelKeysIgnored };
}

/** The secrets the webhook accepts now: the current one, then the previous one during its grace. */
export function webhookSecretsAt(keys: ResolvedStripeKeys, now: Date): string[] {
  const out = [keys.webhookSecret.reveal()];
  if (keys.previousWebhookSecret && keys.previousUntil && keys.previousUntil > now) {
    const prev = keys.previousWebhookSecret.reveal();
    if (prev !== out[0]) out.push(prev);
  }
  return out;
}

// ---- the panel's write ------------------------------------------------------------------------------------------

const totpCode = z.string().regex(/^[0-9]{6}$/);
const reason = z.string().trim().min(1).max(500);

/**
 * `UpdateAdminPaymentSettingsRequest`: only the fields sent change; null puts an option back to the server's value
 * (`statementDescriptorSuffix: ""` = explicitly none). Every change needs the code again and a reason.
 */
export const updatePaymentSettingsSchema = z
  .strictObject({
    secretKey: z.string().trim().regex(SECRET_KEY_PATTERN).optional(),
    webhookSecret: z.string().trim().regex(WEBHOOK_SECRET_PATTERN).optional(),
    publishableKey: z.string().trim().regex(PUBLISHABLE_KEY_PATTERN).nullable().optional(),
    bankTransferEnabled: z.boolean().nullable().optional(),
    statementDescriptorSuffix: z
      .string()
      .trim()
      .refine((v) => v === '' || DESCRIPTOR_SUFFIX_PATTERN.test(v), 'invalid_value')
      .nullable()
      .optional(),
    disputeAutoSubmit: z.boolean().nullable().optional(),
    appLinkEnabled: z.boolean().nullable().optional(),
    /** Only for a TEST key and only when NODE_ENV is not production: save without asking Stripe. */
    skipConnectionTest: z.boolean().optional(),
    totpCode,
    reason,
  })
  .refine(
    (b) =>
      [
        'secretKey',
        'webhookSecret',
        'publishableKey',
        'bankTransferEnabled',
        'statementDescriptorSuffix',
        'disputeAutoSubmit',
        'appLinkEnabled',
      ].some((k) => (b as Record<string, unknown>)[k] !== undefined),
    { message: 'nothing to change', path: ['secretKey'] },
  );
export type UpdatePaymentSettingsInput = z.infer<typeof updatePaymentSettingsSchema>;

export const clearPaymentKeysSchema = z.strictObject({ totpCode, reason });
export type ClearPaymentKeysInput = z.infer<typeof clearPaymentKeysSchema>;

export const testPaymentKeySchema = z.strictObject({
  secretKey: z.string().trim().regex(SECRET_KEY_PATTERN),
});
export type TestPaymentKeyInput = z.infer<typeof testPaymentKeySchema>;
