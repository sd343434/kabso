import { inspect } from 'node:util';
import Stripe from 'stripe';
import { describe, expect, it } from 'vitest';
import { AdminSecretBox } from '../admin-panel/admin-crypto.js';
import { verifyStripeEventWithAny, type StripeApi } from '../topup/stripe-api.js';
import {
  AAD,
  fingerprintOf,
  maskedOf,
  newPaymentSecretBox,
  resolvePaymentSettings,
  Secret,
  updatePaymentSettingsSchema,
  webhookSecretsAt,
  WEBHOOK_SECRET_GRACE_MS,
  type PaymentSettingsRow,
  type ResolveEnv,
} from './payment-settings.rules.js';
import { PAYMENT_SETTINGS_CACHE_MS, PaymentSettingsStore } from './payment-settings.store.js';

// Made-up values in the shape of Stripe's (never real keys; joined at run time so no scanner mistakes them).
const fake = (...parts: string[]) => parts.join('_');
const ADMIN_KEY = 'unit-admin-totp-key-0123456789-abcdefghijklmnop';
const PANEL_SK = fake('rk', 'live', 'unitPanelKey000000000000AbCd');
const PANEL_WH = fake('whsec', 'unitPanelWebhook0000000000WxYz');
const ENV_SK = fake('sk', 'test', 'unitEnvKey00000000000000Env1');
const ENV_WH = fake('whsec', 'unitEnvWebhook000000000000Env2');
const NOW = new Date('2026-11-01T10:00:00Z');

const env = (over: Partial<ResolveEnv['topup']> = {}, production = false): ResolveEnv => ({
  production,
  topup: {
    stripe: {
      secretKey: ENV_SK,
      webhookSecret: ENV_WH,
      publicBaseUrl: 'https://api.example.test',
      testMode: true,
    },
    publicBaseUrl: 'https://api.example.test',
    allowTestKeysInProduction: false,
    bankTransfer: { enabled: true, type: 'us_bank_transfer' },
    statementDescriptorSuffix: 'ENV',
    disputeAutoSubmit: true,
    appLinkEnabled: true,
    ...over,
  },
});

function rowWith(box: AdminSecretBox, over: Partial<PaymentSettingsRow> = {}): PaymentSettingsRow {
  return {
    secretKeyEnc: box.seal(PANEL_SK, AAD.secretKey),
    secretKeyPrefix: 'rk_live',
    secretKeyLast4: 'AbCd',
    secretKeySetById: null,
    secretKeySetAt: NOW,
    webhookSecretEnc: box.seal(PANEL_WH, AAD.webhookSecret),
    webhookSecretLast4: 'WxYz',
    webhookSecretSetById: null,
    webhookSecretSetAt: NOW,
    previousWebhookSecretEnc: null,
    previousWebhookSecretUntil: null,
    publishableKey: null,
    bankTransferEnabled: null,
    statementDescriptorSuffix: null,
    disputeAutoSubmit: null,
    appLinkEnabled: null,
    updatedAt: NOW,
    ...over,
  };
}

describe('D196 sealing the panel keys', () => {
  const box = newPaymentSecretBox(ADMIN_KEY)!;

  it('round-trips with the right key and column; fails with another key, column or the TOTP key', () => {
    const sealed = box.seal(PANEL_SK, AAD.secretKey);
    expect(sealed).toMatch(/^v1\./);
    expect(sealed).not.toContain(PANEL_SK);
    expect(sealed).not.toContain('AbCd');
    expect(box.open(sealed, AAD.secretKey)).toBe(PANEL_SK);
    // Another ADMIN_TOTP_KEY: unreadable.
    expect(newPaymentSecretBox(`${ADMIN_KEY}-other`)!.open(sealed, AAD.secretKey)).toBeNull();
    // The same source with the TOTP secrets' info string is another key (HKDF `admin-totp/v1`).
    expect(new AdminSecretBox(ADMIN_KEY).open(sealed, AAD.secretKey)).toBeNull();
    // Moved to another column: unreadable.
    expect(box.open(sealed, AAD.webhookSecret)).toBeNull();
    // Tampered with: unreadable.
    const parts = sealed.split('.');
    parts[3] = Buffer.from('x'.repeat(20)).toString('base64url');
    expect(box.open(parts.join('.'), AAD.secretKey)).toBeNull();
    // A fresh IV each time.
    expect(box.seal(PANEL_SK, AAD.secretKey)).not.toBe(sealed);
  });

  it('the TOTP box without aad still opens what it sealed before D196', () => {
    const totp = new AdminSecretBox(ADMIN_KEY);
    expect(totp.open(totp.seal('JBSWY3DPEHPK3PXP'))).toBe('JBSWY3DPEHPK3PXP');
  });

  it('no ADMIN_TOTP_KEY: no box (the section is 503)', () => {
    expect(newPaymentSecretBox(null)).toBeNull();
  });
});

describe('D196 masking', () => {
  it('shows only the type, the mode and the last 4 characters', () => {
    expect(fingerprintOf(PANEL_SK)).toEqual({ kind: 'restricted', mode: 'live', last4: 'AbCd' });
    expect(fingerprintOf(ENV_SK)).toEqual({ kind: 'secret', mode: 'test', last4: 'Env1' });
    expect(fingerprintOf(PANEL_WH)).toEqual({ kind: 'webhook', mode: null, last4: 'WxYz' });
    expect(maskedOf(PANEL_SK)).toBe('rk_live_…AbCd');
    expect(maskedOf(PANEL_WH)).toBe('whsec_…WxYz');
    expect(maskedOf(null)).toBeNull();
  });
});

describe('D196 secrets are never serialised', () => {
  it('Secret hides its value from JSON, strings and util.inspect', () => {
    const s = new Secret(PANEL_SK);
    expect(s.reveal()).toBe(PANEL_SK);
    expect(JSON.stringify({ s })).toBe('{"s":"[redacted]"}');
    expect(String(s)).toBe('[redacted]');
    expect('' + s.toString()).toBe('[redacted]');
    expect(inspect({ s })).not.toContain(PANEL_SK);
    expect(Object.keys(s)).toEqual([]);
  });

  it('the resolved settings can be logged whole without a secret', () => {
    const box = newPaymentSecretBox(ADMIN_KEY)!;
    const r = resolvePaymentSettings(
      rowWith(box, {
        previousWebhookSecretEnc: box.seal(ENV_WH, AAD.previousWebhookSecret),
        previousWebhookSecretUntil: new Date(NOW.getTime() + 60_000),
      }),
      env(),
      box,
      NOW,
    );
    for (const text of [JSON.stringify(r), inspect(r, { depth: 10 })]) {
      for (const secret of [PANEL_SK, PANEL_WH, ENV_WH]) expect(text).not.toContain(secret);
    }
  });

  it('the panel write schema refuses unknown fields and malformed keys', () => {
    const base = { totpCode: '123456', reason: 'rotate' };
    expect(updatePaymentSettingsSchema.safeParse({ ...base, secretKey: PANEL_SK }).success).toBe(true);
    expect(
      updatePaymentSettingsSchema.safeParse({ ...base, secretKey: fake('pk', 'live', 'abcdefgh123') })
        .success,
    ).toBe(false);
    expect(
      updatePaymentSettingsSchema.safeParse({ ...base, webhookSecret: fake('sk', 'live', 'abcdefgh123') })
        .success,
    ).toBe(false);
    expect(updatePaymentSettingsSchema.safeParse({ ...base, foo: 1, appLinkEnabled: true }).success).toBe(
      false,
    );
    expect(updatePaymentSettingsSchema.safeParse(base).success).toBe(false); // nothing to change
    expect(updatePaymentSettingsSchema.safeParse({ secretKey: PANEL_SK, reason: 'x' }).success).toBe(false);
    expect(updatePaymentSettingsSchema.safeParse({ secretKey: PANEL_SK, totpCode: '123456' }).success).toBe(
      false,
    );
  });
});

describe('D196 the source of truth', () => {
  const box = newPaymentSecretBox(ADMIN_KEY)!;

  it('the panel keys override the env keys; options override when set', () => {
    const r = resolvePaymentSettings(
      rowWith(box, { bankTransferEnabled: false, statementDescriptorSuffix: '', disputeAutoSubmit: false }),
      env(),
      box,
      NOW,
    );
    expect(r.stripe?.source).toBe('panel');
    expect(r.stripe?.secretKey.reveal()).toBe(PANEL_SK);
    expect(r.stripe?.webhookSecret.reveal()).toBe(PANEL_WH);
    expect(r.stripe?.testMode).toBe(false);
    expect(r.stripe?.publicBaseUrl).toBe('https://api.example.test');
    expect(r.options).toEqual({
      bankTransfer: { enabled: false, type: 'us_bank_transfer' },
      statementDescriptorSuffix: null,
      disputeAutoSubmit: false,
      appLinkEnabled: true,
    });
  });

  it('no panel keys: the env keys; neither: off', () => {
    const empty = rowWith(box, {
      secretKeyEnc: null,
      secretKeyPrefix: null,
      secretKeyLast4: null,
      webhookSecretEnc: null,
      webhookSecretLast4: null,
    });
    expect(resolvePaymentSettings(empty, env(), box, NOW).stripe?.source).toBe('env');
    expect(resolvePaymentSettings(null, env(), box, NOW).stripe?.secretKey.reveal()).toBe(ENV_SK);
    expect(resolvePaymentSettings(null, env(), box, NOW).options.statementDescriptorSuffix).toBe('ENV');
    expect(resolvePaymentSettings(empty, env({ stripe: null }), box, NOW).stripe).toBeNull();
  });

  it('panel keys sealed with another ADMIN_TOTP_KEY fall back to env (and say why)', () => {
    const other = newPaymentSecretBox(`${ADMIN_KEY}-old`)!;
    const r = resolvePaymentSettings(rowWith(other), env(), box, NOW);
    expect(r.stripe?.source).toBe('env');
    expect(r.panelKeysIgnored).toBe('unreadable');
    expect(resolvePaymentSettings(rowWith(box), env(), null, NOW).stripe?.source).toBe('env');
  });

  it('production ignores a panel TEST key unless STRIPE_ALLOW_TEST_KEYS_IN_PRODUCTION', () => {
    const test = rowWith(box, {
      secretKeyEnc: box.seal(fake('sk', 'test', 'unitPanelTest00000000000Tst1'), AAD.secretKey),
      secretKeyPrefix: 'sk_test',
    });
    const prod = resolvePaymentSettings(test, env({ stripe: null }, true), box, NOW);
    expect(prod.stripe).toBeNull();
    expect(prod.panelKeysIgnored).toBe('test_key_in_production');
    expect(
      resolvePaymentSettings(test, env({ stripe: null, allowTestKeysInProduction: true }, true), box, NOW)
        .stripe?.testMode,
    ).toBe(true);
    expect(resolvePaymentSettings(test, env({ stripe: null }), box, NOW).stripe?.source).toBe('panel');
  });

  it('panel keys without TOPUP_PUBLIC_BASE_URL leave top-ups off', () => {
    expect(
      resolvePaymentSettings(rowWith(box), env({ stripe: null, publicBaseUrl: null }), box, NOW).stripe,
    ).toBeNull();
  });
});

describe('D196 webhook: the previous secret for 10 minutes after a rotation', () => {
  const box = newPaymentSecretBox(ADMIN_KEY)!;
  const payload = JSON.stringify({ id: 'evt_unit_1', object: 'event', type: 'checkout.session.expired' });
  const signed = (secret: string) =>
    Stripe.webhooks.generateTestHeaderString({ payload, secret, timestamp: Math.floor(Date.now() / 1000) });

  it('accepts the current and, during the grace only, the previous secret', () => {
    const until = new Date(NOW.getTime() + WEBHOOK_SECRET_GRACE_MS);
    const r = resolvePaymentSettings(
      rowWith(box, {
        previousWebhookSecretEnc: box.seal(ENV_WH, AAD.previousWebhookSecret),
        previousWebhookSecretUntil: until,
      }),
      env(),
      box,
      NOW,
    );
    const keys = r.stripe!;
    expect(keys.previousUntil).toEqual(until);
    const during = webhookSecretsAt(keys, new Date(NOW.getTime() + 9 * 60_000));
    expect(during).toEqual([PANEL_WH, ENV_WH]);
    const body = Buffer.from(payload);
    expect(verifyStripeEventWithAny(body, signed(PANEL_WH), during).id).toBe('evt_unit_1');
    expect(verifyStripeEventWithAny(body, signed(ENV_WH), during).id).toBe('evt_unit_1');
    expect(() =>
      verifyStripeEventWithAny(body, signed(fake('whsec', 'unitSomeoneElse00000000000000')), during),
    ).toThrow();
    // After 10 minutes only the current secret.
    const after = webhookSecretsAt(keys, new Date(until.getTime() + 1));
    expect(after).toEqual([PANEL_WH]);
    expect(() => verifyStripeEventWithAny(body, signed(ENV_WH), after)).toThrow();
    // An expired previous secret is not even opened.
    const late = resolvePaymentSettings(
      rowWith(box, {
        previousWebhookSecretEnc: box.seal(ENV_WH, AAD.previousWebhookSecret),
        previousWebhookSecretUntil: new Date(NOW.getTime() - 1),
      }),
      env(),
      box,
      NOW,
    );
    expect(late.stripe?.previousWebhookSecret).toBeNull();
  });
});

describe('D196 the Stripe client follows the key without a restart', () => {
  it('re-reads the row after a change and creates a new client for a new key', async () => {
    const box = newPaymentSecretBox(ADMIN_KEY)!;
    let row: PaymentSettingsRow | null = null;
    let reads = 0;
    const prisma = {
      paymentSettings: {
        findUnique: async () => {
          reads += 1;
          return row;
        },
      },
    };
    let now = NOW.getTime();
    const clock = { now: () => new Date(now) };
    const made: string[] = [];
    const factory = (key: string) => {
      made.push(maskedOf(key)!);
      return { key } as unknown as StripeApi;
    };
    const config = {
      env: 'test',
      adminPanel: { totpKey: ADMIN_KEY },
      topup: env().topup,
    };
    const store = new PaymentSettingsStore(prisma as never, clock, config as never, factory);

    const a = await store.active();
    expect(a.stripe?.source).toBe('env');
    const envClient = a.api;
    expect((await store.active()).api).toBe(envClient); // same key: same client, cached read
    expect(reads).toBe(1);

    // The OWNER saves panel keys: this instance at once (invalidate)…
    row = rowWith(box);
    store.invalidate();
    const b = await store.active();
    expect(b.stripe?.source).toBe('panel');
    expect(b.api).not.toBe(envClient);
    expect(made).toEqual(['sk_test_…Env1', 'rk_live_…AbCd']);

    // …another instance within the cache time, without invalidate.
    row = rowWith(box, {
      secretKeyEnc: box.seal(fake('rk', 'live', 'unitRotatedKey0000000000New9'), AAD.secretKey),
    });
    expect((await store.active()).api).toBe(b.api);
    now += PAYMENT_SETTINGS_CACHE_MS;
    const c = await store.active();
    expect(c.api).not.toBe(b.api);
    expect(made.at(-1)).toBe('rk_live_…New9');

    // Cleared in the panel: back to the env key.
    row = null;
    store.invalidate();
    expect((await store.active()).stripe?.source).toBe('env');
    expect(made.at(-1)).toBe('sk_test_…Env1');
  });
});

describe('D196 logs', () => {
  it('free text in logs has Stripe secrets masked', async () => {
    const { redactText } = await import('../../logging/redact-text.js');
    const text = redactText(`failed with ${PANEL_SK} and ${ENV_WH} for x`);
    expect(text).not.toContain(PANEL_SK);
    expect(text).not.toContain(ENV_WH);
  });
});
