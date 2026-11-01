import { createHash } from 'node:crypto';
import { Inject, Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { AdminSecretBox } from '../admin-panel/admin-crypto.js';
import { S3ObjectStorage } from '../media/s3-object-storage.js';
import {
  newStorageSecretBox,
  resolveStorageSettings,
  revealS3,
  type ResolvedStorage,
  type StorageSettingsRow,
} from './storage-settings.rules.js';

/** How long one API instance trusts what it read (another instance's change reaches it within this). */
export const STORAGE_SETTINGS_CACHE_MS = 5_000;

/**
 * v1.75-social (D222, §10.72): the one place that answers «which object storage now?» — D196's
 * `PaymentSettingsStore` pattern. It reads the panel's row (`storage_settings`), falls back to the server's `S3_*`,
 * and keeps one {@link S3ObjectStorage} (one S3 client) per settings: a change saved in the panel is used by the next
 * request (this instance at once, the others within {@link STORAGE_SETTINGS_CACHE_MS}) — no restart. A request that
 * already holds the old storage finishes on it (the old client is dropped, never destroyed mid-request).
 *
 * {@link current} is synchronous (media URLs are built in many synchronous mappers): it answers the last settings
 * read and refreshes them in the background when they are older than the cache time.
 */
@Injectable()
export class StorageSettingsStore implements OnModuleInit {
  private readonly logger = new Logger(StorageSettingsStore.name);
  private readonly box: AdminSecretBox | null;
  private cache: { readonly at: number; readonly value: ResolvedStorage } | null = null;
  private snapshot: ResolvedStorage;
  private loading: Promise<ResolvedStorage> | null = null;
  private storage: { readonly hash: string; readonly storage: S3ObjectStorage } | null = null;
  private warned: string | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.box = newStorageSecretBox(config.adminPanel.totpKey);
    // Before the first read: the env, exactly as before D222.
    this.snapshot = resolveStorageSettings(null, config, this.box);
  }

  async onModuleInit(): Promise<void> {
    await this.resolved().catch((err: unknown) => {
      this.logger.warn(`Could not read the panel's storage settings; using the server's (${String(err)}).`);
    });
  }

  /** The box that seals the panel's keys (null without ADMIN_TOTP_KEY: the panel section is then 503). */
  secretBox(): AdminSecretBox | null {
    return this.box;
  }

  /** The settings now (cached briefly). */
  async resolved(): Promise<ResolvedStorage> {
    const nowMs = this.clock.now().getTime();
    if (this.cache && nowMs - this.cache.at < STORAGE_SETTINGS_CACHE_MS) return this.cache.value;
    this.loading ??= this.load().finally(() => {
      this.loading = null;
    });
    return this.loading;
  }

  /** The last settings read, without waiting (refreshed in the background when stale). */
  current(): ResolvedStorage {
    const nowMs = this.clock.now().getTime();
    if (!this.cache || nowMs - this.cache.at >= STORAGE_SETTINGS_CACHE_MS) {
      void this.resolved().catch(() => undefined);
    }
    return this.snapshot;
  }

  /** The storage of the current settings (503 on every call when there is none). */
  async active(): Promise<S3ObjectStorage> {
    return this.storageFor(await this.resolved());
  }

  /** After a change on this instance: read again now, so the next request already sees it. */
  async reload(): Promise<ResolvedStorage> {
    this.cache = null;
    await this.loading?.catch(() => undefined);
    return this.resolved();
  }

  private async load(): Promise<ResolvedStorage> {
    const now = this.clock.now();
    const row: StorageSettingsRow | null = await this.prisma.storageSettings.findUnique({ where: { id: 1 } });
    const value = resolveStorageSettings(row, this.config, this.box);
    if (value.panelIgnored && this.warned !== value.panelIgnored) {
      this.warned = value.panelIgnored;
      this.logger.warn(`The storage keys saved in the admin panel are not used (${value.panelIgnored}).`);
    }
    if (this.snapshot.source !== value.source) {
      this.logger.log(`Media storage now from: ${value.source}.`);
    }
    this.cache = { at: now.getTime(), value };
    this.snapshot = value;
    return value;
  }

  private storageFor(value: ResolvedStorage): S3ObjectStorage {
    const plain = value.s3 ? revealS3(value.s3) : null;
    const hash = plain ? createHash('sha256').update(JSON.stringify(plain)).digest('hex') : 'none';
    if (this.storage?.hash !== hash) this.storage = { hash, storage: new S3ObjectStorage(plain) };
    return this.storage.storage;
  }
}
