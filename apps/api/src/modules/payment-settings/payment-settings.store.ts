import { createHash } from 'node:crypto';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { AdminSecretBox } from '../admin-panel/admin-crypto.js';
import { STRIPE_API_FACTORY, type StripeApi, type StripeApiFactory } from '../topup/stripe-api.js';
import {
  newPaymentSecretBox,
  resolvePaymentSettings,
  type PaymentSettingsRow,
  type ResolvedPaymentSettings,
  type ResolvedStripeKeys,
} from './payment-settings.rules.js';

/** How long one API instance trusts what it read (another instance's change reaches it within this). */
export const PAYMENT_SETTINGS_CACHE_MS = 5_000;

/** What top-ups run with now: the settings and the Stripe client of the current key. */
export interface ActivePayments extends ResolvedPaymentSettings {
  readonly api: StripeApi | null;
}

/**
 * v1.64-social (D196, §10.53.1): the one place that answers «which Stripe keys and options now?». It reads the
 * panel's row (`payment_settings`), falls back to the server environment, and keeps one Stripe client per secret key:
 * a key saved in the panel is used by the next request (this instance at once, the others within
 * {@link PAYMENT_SETTINGS_CACHE_MS}) — no restart. The old client is dropped when the key changes.
 */
@Injectable()
export class PaymentSettingsStore {
  private readonly logger = new Logger(PaymentSettingsStore.name);
  private readonly box: AdminSecretBox | null;
  private cache: { readonly at: number; readonly value: ResolvedPaymentSettings } | null = null;
  private loading: Promise<ResolvedPaymentSettings> | null = null;
  private client: { readonly keyHash: string; readonly api: StripeApi } | null = null;
  private warned: string | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(STRIPE_API_FACTORY) private readonly factory: StripeApiFactory,
  ) {
    this.box = newPaymentSecretBox(config.adminPanel.totpKey);
  }

  /** The box that seals the panel's secrets (null without ADMIN_TOTP_KEY: the panel section is then 503). */
  secretBox(): AdminSecretBox | null {
    return this.box;
  }

  /** The current settings and client (cached briefly). */
  async active(): Promise<ActivePayments> {
    const value = await this.resolved();
    return { ...value, api: value.stripe ? this.clientFor(value.stripe) : null };
  }

  /** The settings only (no client). */
  async resolved(): Promise<ResolvedPaymentSettings> {
    const nowMs = this.clock.now().getTime();
    if (this.cache && nowMs - this.cache.at < PAYMENT_SETTINGS_CACHE_MS) return this.cache.value;
    this.loading ??= this.load().finally(() => {
      this.loading = null;
    });
    return this.loading;
  }

  /** After a change on this instance: the next read goes to the database. */
  invalidate(): void {
    this.cache = null;
  }

  /** A client for a key that is not saved (the panel's «اختبار الاتصال»); never cached. */
  probe(secretKey: string): StripeApi {
    return this.factory(secretKey);
  }

  private async load(): Promise<ResolvedPaymentSettings> {
    const now = this.clock.now();
    const row: PaymentSettingsRow | null = await this.prisma.paymentSettings.findUnique({ where: { id: 1 } });
    const value = resolvePaymentSettings(
      row,
      { production: this.config.env === 'production', topup: this.config.topup },
      this.box,
      now,
    );
    if (value.panelKeysIgnored && this.warned !== value.panelKeysIgnored) {
      this.warned = value.panelKeysIgnored;
      this.logger.warn(`The Stripe keys saved in the admin panel are not used (${value.panelKeysIgnored}).`);
    }
    this.cache = { at: now.getTime(), value };
    return value;
  }

  private clientFor(keys: ResolvedStripeKeys): StripeApi {
    const plain = keys.secretKey.reveal();
    const keyHash = createHash('sha256').update(plain).digest('hex');
    if (this.client?.keyHash !== keyHash) this.client = { keyHash, api: this.factory(plain) };
    return this.client.api;
  }
}
