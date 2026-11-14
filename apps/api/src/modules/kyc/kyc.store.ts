import { createHash } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { Secret, type AdminSecretBox } from '../admin-panel/admin-crypto.js';
import { DIDIT_API_FACTORY, type DiditApi, type DiditApiFactory } from './didit-api.js';
import { documentHashKey, KYC_AAD, newKycSecretBox, type KycSettingsRow } from './kyc.rules.js';

/** How long one API instance trusts what it read (another instance's change reaches it within this). */
export const KYC_SETTINGS_CACHE_MS = 5_000;

/** The settings in use: the switch, the opened secrets (wrapped) and the workflows. */
export interface ResolvedKyc {
  readonly row: KycSettingsRow | null;
  /** On and readable: sessions can be started. */
  readonly enabled: boolean;
  readonly apiKey: Secret | null;
  readonly webhookSecret: Secret | null;
  /** The switch is on but a secret was sealed with another ADMIN_TOTP_KEY (Didit is then treated as off). */
  readonly unreadable: boolean;
}

/**
 * v1.80-kyc (D227, §10.77): the one place that answers «Didit now?» — D196 / D222's store pattern: the panel's row
 * (`kyc_settings`) only (the owner's decision: never the server environment), a 5 s cache invalidated on save, one
 * Didit client per key (a new key = a new client, no restart).
 */
@Injectable()
export class KycSettingsStore {
  private readonly box: AdminSecretBox | null;
  private readonly hashKey: Buffer | null;
  private cache: { readonly at: number; readonly value: ResolvedKyc } | null = null;
  private loading: Promise<ResolvedKyc> | null = null;
  private client: { readonly hash: string; readonly api: DiditApi } | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) config: AppConfig,
    @Inject(DIDIT_API_FACTORY) private readonly factory: DiditApiFactory,
  ) {
    this.box = newKycSecretBox(config.adminPanel.totpKey);
    this.hashKey = documentHashKey(config.adminPanel.totpKey);
  }

  /** The box that seals the panel's secrets (null without ADMIN_TOTP_KEY: the section is then 503). */
  secretBox(): AdminSecretBox | null {
    return this.box;
  }

  /** The HMAC key of document numbers (null without ADMIN_TOTP_KEY). */
  documentKey(): Buffer | null {
    return this.hashKey;
  }

  async resolved(): Promise<ResolvedKyc> {
    const nowMs = this.clock.now().getTime();
    if (this.cache && nowMs - this.cache.at < KYC_SETTINGS_CACHE_MS) return this.cache.value;
    this.loading ??= this.load().finally(() => {
      this.loading = null;
    });
    return this.loading;
  }

  /** After a change on this instance: read again now. */
  async reload(): Promise<ResolvedKyc> {
    this.cache = null;
    await this.loading?.catch(() => undefined);
    return this.resolved();
  }

  /** A Didit client for this key (one per key). */
  api(apiKey: Secret): DiditApi {
    const hash = createHash('sha256').update(apiKey.reveal()).digest('hex');
    if (this.client?.hash !== hash) this.client = { hash, api: this.factory(apiKey.reveal()) };
    return this.client.api;
  }

  /** A client for a key not saved yet («اختبار الاتصال» with a typed key). */
  apiFor(apiKey: string): DiditApi {
    return this.factory(apiKey);
  }

  private async load(): Promise<ResolvedKyc> {
    const at = this.clock.now().getTime();
    const row: KycSettingsRow | null = await this.prisma.kycSettings.findUnique({ where: { id: 1 } });
    const open = (sealed: string | null, aad: string): Secret | null => {
      if (!sealed || !this.box) return null;
      const plain = this.box.open(sealed, aad);
      return plain === null ? null : new Secret(plain);
    };
    const apiKey = open(row?.apiKeyEnc ?? null, KYC_AAD.apiKey);
    const webhookSecret = open(row?.webhookSecretEnc ?? null, KYC_AAD.webhookSecret);
    const unreadable =
      (row?.enabled ?? false) &&
      ((!!row?.apiKeyEnc && !apiKey) || (!!row?.webhookSecretEnc && !webhookSecret));
    const value: ResolvedKyc = {
      row,
      enabled: (row?.enabled ?? false) && !unreadable && apiKey !== null && this.hashKey !== null,
      apiKey,
      webhookSecret,
      unreadable,
    };
    this.cache = { at, value };
    return value;
  }
}
