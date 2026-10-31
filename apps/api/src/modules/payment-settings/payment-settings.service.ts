import { Inject, Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { AdminSecretBox } from '../admin-panel/admin-crypto.js';
import { AdminAuthService, type AdminContext } from '../admin-panel/admin-auth.service.js';
import { StripeUnreachableError } from '../topup/stripe-api.js';
import {
  AAD,
  fingerprintOf,
  isTestKey,
  maskedOf,
  modeOf,
  resolvePaymentSettings,
  STRIPE_WEBHOOK_EVENTS,
  STRIPE_WEBHOOK_PATH,
  testKeysAllowed,
  WEBHOOK_SECRET_GRACE_MS,
  type ClearPaymentKeysInput,
  type KeyFingerprint,
  type KeyMode,
  type PaymentSettingsRow,
  type TestPaymentKeyInput,
  type UpdatePaymentSettingsInput,
} from './payment-settings.rules.js';
import { PaymentSettingsStore } from './payment-settings.store.js';

/** `PaymentKeyInfo`. */
export interface PaymentKeyInfoDto extends KeyFingerprint {
  source: 'panel' | 'env';
  setBy: { id: string; displayName: string } | null;
  setAt: string | null;
}

interface PaymentOptionsDto {
  bankTransferEnabled: boolean | null;
  statementDescriptorSuffix: string | null;
  disputeAutoSubmit: boolean | null;
  appLinkEnabled: boolean | null;
}

/** `AdminPaymentSettings` (openapi v1.64-social): never a secret, only fingerprints. */
export interface AdminPaymentSettingsDto {
  source: 'panel' | 'env' | 'none';
  configured: boolean;
  mode: KeyMode | null;
  secretKey: PaymentKeyInfoDto | null;
  webhookSecret: PaymentKeyInfoDto | null;
  previousWebhookSecretValidUntil: string | null;
  panelKeys: { secretKey: PaymentKeyInfoDto; webhookSecret: PaymentKeyInfoDto } | null;
  envKeys: { secretKey: PaymentKeyInfoDto; webhookSecret: PaymentKeyInfoDto } | null;
  panelKeysIgnored: 'unreadable' | 'test_key_in_production' | null;
  publishableKey: string | null;
  options: PaymentOptionsDto;
  effective: {
    bankTransferEnabled: boolean;
    statementDescriptorSuffix: string | null;
    disputeAutoSubmit: boolean;
    appLinkEnabled: boolean;
  };
  publicBaseUrl: string | null;
  webhookUrl: string | null;
  webhookEvents: string[];
  testKeysAllowed: boolean;
  connectionTestSkippable: boolean;
}

/** `PaymentKeyCheck`. */
export interface PaymentKeyCheckDto extends KeyFingerprint {
  ok: true;
  restricted: boolean;
}

type Refusal =
  | 'stripe_rejected'
  | 'test_key_in_production'
  | 'connection_test_required'
  | 'mode_mismatch'
  | 'nothing_to_clear';

const REFUSAL_MESSAGE: Record<Refusal, string> = {
  stripe_rejected: 'Stripe refused this key (wrong, revoked or expired). Nothing was saved.',
  test_key_in_production:
    'A Stripe TEST key is refused in production (STRIPE_ALLOW_TEST_KEYS_IN_PRODUCTION is not set on the server).',
  connection_test_required:
    'The key must be tested with Stripe before it is saved (skipping is only for a test key outside production).',
  mode_mismatch: 'The publishable key and the secret key must both be live or both be test.',
  nothing_to_clear: 'No Stripe keys are saved in the panel.',
};

function refuse(issue: Refusal, field: string): AppException {
  return new AppException(ErrorCode.ADMIN_ACTION_REFUSED, REFUSAL_MESSAGE[issue], [{ field, issue }]);
}

/** The masked summary an audit row carries for the panel's stored state (never a secret). */
function summaryOf(row: PaymentSettingsRow | null) {
  return {
    secretKey:
      row?.secretKeyPrefix && row.secretKeyLast4 ? `${row.secretKeyPrefix}_…${row.secretKeyLast4}` : null,
    webhookSecret: row?.webhookSecretLast4 ? `whsec_…${row.webhookSecretLast4}` : null,
    publishableKey: maskedOf(row?.publishableKey ?? null),
    bankTransferEnabled: row?.bankTransferEnabled ?? null,
    statementDescriptorSuffix: row?.statementDescriptorSuffix ?? null,
    disputeAutoSubmit: row?.disputeAutoSubmit ?? null,
    appLinkEnabled: row?.appLinkEnabled ?? null,
  };
}

/**
 * The OWNER's «الدفع (Stripe)» section (v1.64-social, D196, CONVENTIONS §10.53.1). Owns `payment_settings`: the
 * Stripe secret (or restricted) key and the webhook signing secret, sealed AES-256-GCM with a key derived from
 * ADMIN_TOTP_KEY (`payment-settings/v1`) and never returned or logged; the optional publishable key; and the
 * top-up options. Every change needs the authenticator code again and a reason, and is audited with masked
 * fingerprints only. A new secret key is tried on Stripe (`balance.retrieve`) before it is saved.
 */
@Injectable()
export class PaymentSettingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly auth: AdminAuthService,
    private readonly store: PaymentSettingsStore,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private get production(): boolean {
    return this.config.env === 'production';
  }

  private box(): AdminSecretBox {
    const box = this.store.secretBox();
    if (!box) throw new AppException(ErrorCode.ADMIN_PANEL_UNAVAILABLE);
    return box;
  }

  private testKeysAllowed(): boolean {
    return testKeysAllowed({
      production: this.production,
      allowTestKeysInProduction: this.config.topup.allowTestKeysInProduction,
    });
  }

  async view(): Promise<AdminPaymentSettingsDto> {
    const box = this.box();
    const now = this.clock.now();
    const row = await this.prisma.paymentSettings.findUnique({ where: { id: 1 } });
    const t = this.config.topup;
    const r = resolvePaymentSettings(row, { production: this.production, topup: t }, box, now);
    const ids = [row?.secretKeySetById, row?.webhookSecretSetById].filter((x): x is string => !!x);
    const people = new Map(
      (
        await this.prisma.user.findMany({
          where: { id: { in: ids } },
          select: { id: true, profile: { select: { displayName: true } } },
        })
      ).map((u) => [u.id, { id: u.id, displayName: u.profile?.displayName ?? '' }]),
    );
    const panelKeys =
      row?.secretKeyPrefix && row.secretKeyLast4 && row.webhookSecretLast4
        ? {
            secretKey: {
              kind: row.secretKeyPrefix.startsWith('rk') ? ('restricted' as const) : ('secret' as const),
              mode: modeOf(`${row.secretKeyPrefix}_`),
              last4: row.secretKeyLast4,
              source: 'panel' as const,
              setBy: (row.secretKeySetById && people.get(row.secretKeySetById)) || null,
              setAt: row.secretKeySetAt?.toISOString() ?? null,
            },
            webhookSecret: {
              kind: 'webhook' as const,
              mode: null,
              last4: row.webhookSecretLast4,
              source: 'panel' as const,
              setBy: (row.webhookSecretSetById && people.get(row.webhookSecretSetById)) || null,
              setAt: row.webhookSecretSetAt?.toISOString() ?? null,
            },
          }
        : null;
    const envKey = (key: string): PaymentKeyInfoDto => ({
      ...fingerprintOf(key),
      source: 'env',
      setBy: null,
      setAt: null,
    });
    const envKeys = t.stripe
      ? { secretKey: envKey(t.stripe.secretKey), webhookSecret: envKey(t.stripe.webhookSecret) }
      : null;
    const used = r.stripe?.source === 'panel' ? panelKeys : r.stripe?.source === 'env' ? envKeys : null;
    return {
      source: r.stripe?.source ?? 'none',
      configured: r.stripe !== null,
      mode: r.stripe ? (r.stripe.testMode ? 'test' : 'live') : null,
      secretKey: used?.secretKey ?? null,
      webhookSecret: used?.webhookSecret ?? null,
      previousWebhookSecretValidUntil: r.stripe?.previousUntil?.toISOString() ?? null,
      panelKeys,
      envKeys,
      panelKeysIgnored: r.panelKeysIgnored,
      publishableKey: r.publishableKey,
      options: {
        bankTransferEnabled: row?.bankTransferEnabled ?? null,
        statementDescriptorSuffix: row?.statementDescriptorSuffix ?? null,
        disputeAutoSubmit: row?.disputeAutoSubmit ?? null,
        appLinkEnabled: row?.appLinkEnabled ?? null,
      },
      effective: {
        bankTransferEnabled: r.options.bankTransfer.enabled,
        statementDescriptorSuffix: r.options.statementDescriptorSuffix,
        disputeAutoSubmit: r.options.disputeAutoSubmit,
        appLinkEnabled: r.options.appLinkEnabled,
      },
      publicBaseUrl: t.publicBaseUrl,
      webhookUrl: t.publicBaseUrl ? `${t.publicBaseUrl}${STRIPE_WEBHOOK_PATH}` : null,
      webhookEvents: [...STRIPE_WEBHOOK_EVENTS],
      testKeysAllowed: this.testKeysAllowed(),
      connectionTestSkippable: !this.production,
    };
  }

  /** «اختبار الاتصال»: asks Stripe with this key; nothing is saved. Audited with the fingerprint and the outcome. */
  async test(input: TestPaymentKeyInput, ctx: AdminContext): Promise<PaymentKeyCheckDto> {
    this.box();
    if (isTestKey(input.secretKey) && !this.testKeysAllowed()) {
      throw refuse('test_key_in_production', 'secretKey');
    }
    const result = await this.check(input.secretKey);
    await this.audit.record({
      action: AuditAction.PAYMENT_SETTINGS_TEST,
      actorUserId: ctx.userId,
      targetType: 'payment_settings',
      metadata: { key: maskedOf(input.secretKey), result: result.ok ? 'ok' : 'rejected', via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    if (!result.ok) throw refuse('stripe_rejected', 'secretKey');
    return { ok: true, ...fingerprintOf(input.secretKey), restricted: result.restricted };
  }

  private async check(secretKey: string) {
    try {
      return await this.store.probe(secretKey).checkKey();
    } catch (err) {
      if (err instanceof StripeUnreachableError) {
        throw new AppException(
          ErrorCode.SERVICE_UNAVAILABLE,
          'Stripe could not be reached. Nothing was saved.',
        );
      }
      throw err;
    }
  }

  /** Saves what the body names (TOTP again + reason). A new secret key must pass the Stripe test first. */
  async update(input: UpdatePaymentSettingsInput, ctx: AdminContext): Promise<AdminPaymentSettingsDto> {
    const box = this.box();
    await this.auth.reauthenticate(ctx, input.totpCode);
    // The first keys come as a pair (one without the other would take payments that are never credited); checked
    // again under the row lock below, and here before Stripe is asked anything.
    const pairRequired = async (db: Pick<Prisma.TransactionClient, 'paymentSettings'>) => {
      const stored = await db.paymentSettings.findUnique({
        where: { id: 1 },
        select: { secretKeyEnc: true },
      });
      if (!stored?.secretKeyEnc && (input.secretKey === undefined) !== (input.webhookSecret === undefined)) {
        const missing = input.secretKey === undefined ? 'secretKey' : 'webhookSecret';
        throw AppException.validation([{ field: missing, issue: 'required' }]);
      }
    };
    await pairRequired(this.prisma);
    let checked: 'stripe' | 'skipped' | null = null;
    if (input.secretKey !== undefined) {
      const test = isTestKey(input.secretKey);
      if (test && !this.testKeysAllowed()) throw refuse('test_key_in_production', 'secretKey');
      if (input.skipConnectionTest) {
        if (this.production || !test) throw refuse('connection_test_required', 'skipConnectionTest');
        checked = 'skipped';
      } else {
        const result = await this.check(input.secretKey);
        if (!result.ok) throw refuse('stripe_rejected', 'secretKey');
        checked = 'stripe';
      }
    }
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`INSERT INTO payment_settings (id, updated_at) VALUES (1, ${now}) ON CONFLICT (id) DO NOTHING`;
      await tx.$queryRaw`SELECT id FROM payment_settings WHERE id = 1 FOR UPDATE`;
      await pairRequired(tx);
      const row = await tx.paymentSettings.findUniqueOrThrow({ where: { id: 1 } });
      const hasPanelKeys = row.secretKeyEnc !== null;
      const current = resolvePaymentSettings(
        row,
        { production: this.production, topup: this.config.topup },
        box,
        now,
      );
      const secretMode = input.secretKey
        ? modeOf(input.secretKey)
        : hasPanelKeys && row.secretKeyPrefix
          ? modeOf(`${row.secretKeyPrefix}_`)
          : current.stripe
            ? current.stripe.testMode
              ? 'test'
              : 'live'
            : null;
      const publishable = input.publishableKey === undefined ? row.publishableKey : input.publishableKey;
      if (publishable && secretMode && modeOf(publishable) !== secretMode) {
        throw refuse('mode_mismatch', 'publishableKey');
      }
      const data: Prisma.PaymentSettingsUncheckedUpdateInput = { updatedAt: now, updatedById: ctx.userId };
      if (input.secretKey !== undefined) {
        Object.assign(data, {
          secretKeyEnc: box.seal(input.secretKey, AAD.secretKey),
          secretKeyPrefix: input.secretKey.slice(0, 7),
          secretKeyLast4: input.secretKey.slice(-4),
          secretKeySetAt: now,
          secretKeySetById: ctx.userId,
        });
      }
      if (input.webhookSecret !== undefined) {
        Object.assign(data, {
          webhookSecretEnc: box.seal(input.webhookSecret, AAD.webhookSecret),
          webhookSecretLast4: input.webhookSecret.slice(-4),
          webhookSecretSetAt: now,
          webhookSecretSetById: ctx.userId,
        });
        // Rotation: the secret in use until now still verifies for 10 minutes (deliveries already signed).
        const old = current.stripe?.webhookSecret.reveal();
        if (old && old !== input.webhookSecret) {
          Object.assign(data, {
            previousWebhookSecretEnc: box.seal(old, AAD.previousWebhookSecret),
            previousWebhookSecretUntil: new Date(now.getTime() + WEBHOOK_SECRET_GRACE_MS),
          });
        }
      }
      for (const k of [
        'publishableKey',
        'bankTransferEnabled',
        'statementDescriptorSuffix',
        'disputeAutoSubmit',
        'appLinkEnabled',
      ] as const) {
        if (input[k] !== undefined) Object.assign(data, { [k]: input[k] });
      }
      const after = await tx.paymentSettings.update({ where: { id: 1 }, data });
      const before = summaryOf(row);
      const afterSummary = summaryOf(after);
      await this.audit.recordIn(tx, {
        action: AuditAction.PAYMENT_SETTINGS_UPDATE,
        actorUserId: ctx.userId,
        targetType: 'payment_settings',
        metadata: {
          before,
          after: afterSummary,
          changed: (Object.keys(afterSummary) as (keyof typeof before)[]).filter(
            (k) =>
              before[k] !== afterSummary[k] ||
              (k === 'secretKey' && input.secretKey !== undefined) ||
              (k === 'webhookSecret' && input.webhookSecret !== undefined),
          ),
          ...(checked ? { connectionTest: checked } : {}),
          reason: input.reason,
          via: 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    this.store.invalidate();
    return this.view();
  }

  /** Removes the panel's keys (TOTP again + reason): the server's env keys apply again, or top-ups are off (503). */
  async clear(input: ClearPaymentKeysInput, ctx: AdminContext): Promise<AdminPaymentSettingsDto> {
    const box = this.box();
    await this.auth.reauthenticate(ctx, input.totpCode);
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM payment_settings WHERE id = 1 FOR UPDATE`;
      const row = await tx.paymentSettings.findUnique({ where: { id: 1 } });
      if (!row?.secretKeyEnc) throw refuse('nothing_to_clear', 'secretKey');
      const current = resolvePaymentSettings(
        row,
        { production: this.production, topup: this.config.topup },
        box,
        now,
      );
      const old = current.stripe?.source === 'panel' ? current.stripe.webhookSecret.reveal() : null;
      const after = await tx.paymentSettings.update({
        where: { id: 1 },
        data: {
          secretKeyEnc: null,
          secretKeyPrefix: null,
          secretKeyLast4: null,
          secretKeySetAt: null,
          secretKeySetById: null,
          webhookSecretEnc: null,
          webhookSecretLast4: null,
          webhookSecretSetAt: null,
          webhookSecretSetById: null,
          ...(old
            ? {
                previousWebhookSecretEnc: box.seal(old, AAD.previousWebhookSecret),
                previousWebhookSecretUntil: new Date(now.getTime() + WEBHOOK_SECRET_GRACE_MS),
              }
            : {}),
          updatedAt: now,
          updatedById: ctx.userId,
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.PAYMENT_SETTINGS_CLEAR,
        actorUserId: ctx.userId,
        targetType: 'payment_settings',
        metadata: {
          before: summaryOf(row),
          after: summaryOf(after),
          fallback: this.config.topup.stripe ? 'env' : 'none',
          reason: input.reason,
          via: 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    this.store.invalidate();
    return this.view();
  }
}
