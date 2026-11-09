import { Inject, Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { PaymentSettingsStore } from '../payment-settings/payment-settings.store.js';
import {
  CAMERA_FX_SETTING_KEY,
  readCameraFxEngine,
  type CameraFxSettingsDto,
  type UpdateCameraFxInput,
} from './camera-fx.rules.js';
import {
  GLOBAL_STRIPS_SETTING_KEY,
  globalStripsDefaultsOf,
  luckyMultipliersOf,
  readGlobalStrips,
  type AdminGlobalStripsDto,
  type GlobalStripsSettingsDto,
  type UpdateGlobalStripsInput,
} from './global-strips.rules.js';
import {
  LEVEL_TICKER_SETTING_KEY,
  readLevelTickerMinLevel,
  type LevelTickerSettingsDto,
  type UpdateLevelTickerInput,
} from './level-ticker.rules.js';
import {
  SETTING_KEYS,
  SITE_SETTINGS_DEFAULTS,
  storedSocial,
  type SiteSettingsDto,
  type UpdateSiteSettingsInput,
} from './site-settings.rules.js';

export interface SiteSettingsActor {
  readonly userId: string;
  readonly ip: string | null;
  readonly requestId: string | null;
}

/**
 * Owns `site_settings` (D191 + D192, one module, §10.54.6): one row per key (`socials`, `topupEnabled`), defaults
 * when absent. Read by the website (`GET /site/settings`), written only by the OWNER from the panel
 * (`PUT /admin/site-settings`, cookie session + CSRF), each change audited in the same transaction (before/after).
 */
@Injectable()
export class SiteSettingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly payments: PaymentSettingsStore,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async get(db: Pick<Prisma.TransactionClient, 'siteSetting'> = this.prisma): Promise<SiteSettingsDto> {
    const rows = await db.siteSetting.findMany({
      where: { key: { in: [SETTING_KEYS.socials, SETTING_KEYS.topupEnabled] } },
    });
    const byKey = new Map(rows.map((r) => [r.key, r.value]));
    const raw = byKey.get(SETTING_KEYS.socials);
    const socials = (raw !== null && typeof raw === 'object' && !Array.isArray(raw) ? raw : {}) as Record<
      string,
      unknown
    >;
    // A row written by hand or by an older rule is re-checked: a link that no longer passes is not shown.
    return {
      socials: {
        instagram: storedSocial('instagram', socials.instagram) ?? SITE_SETTINGS_DEFAULTS.socials.instagram,
        tiktok: storedSocial('tiktok', socials.tiktok) ?? SITE_SETTINGS_DEFAULTS.socials.tiktok,
        whatsapp: storedSocial('whatsapp', socials.whatsapp) ?? SITE_SETTINGS_DEFAULTS.socials.whatsapp,
      },
      topupEnabled: byKey.get(SETTING_KEYS.topupEnabled) === true,
    };
  }

  /**
   * The OWNER's change from the panel: both keys in one transaction with an audit row (before and after).
   * v1.64-social (D196): turning `topupEnabled` on while card top-ups have no Stripe keys (panel or env) is refused
   * (409 ADMIN_ACTION_REFUSED, `topupEnabled` `stripe_keys_missing`): the website would link to a page that says
   * «الشحن بالبطاقة غير مفعّل».
   */
  async update(input: UpdateSiteSettingsInput, actor: SiteSettingsActor): Promise<SiteSettingsDto> {
    this.payments.invalidate();
    const keysReady = (await this.payments.resolved()).stripe !== null;
    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('site_settings'))`;
      const before = await this.get(tx);
      if (input.topupEnabled && !before.topupEnabled && !keysReady) {
        throw new AppException(
          ErrorCode.ADMIN_ACTION_REFUSED,
          'Card top-ups have no Stripe keys yet: enter them in «الدفع (Stripe)» first (or set them on the server).',
          [{ field: 'topupEnabled', issue: 'stripe_keys_missing' }],
        );
      }
      const after: SiteSettingsDto = { socials: input.socials, topupEnabled: input.topupEnabled };
      for (const [key, value] of [
        [SETTING_KEYS.socials, after.socials],
        [SETTING_KEYS.topupEnabled, after.topupEnabled],
      ] as const) {
        await tx.siteSetting.upsert({
          where: { key },
          create: { key, value, updatedById: actor.userId },
          update: { value, updatedById: actor.userId },
        });
      }
      await this.audit.recordIn(tx, {
        action: AuditAction.SITE_SETTINGS_UPDATE,
        actorUserId: actor.userId,
        targetType: 'site_settings',
        metadata: {
          before: before as unknown as Prisma.InputJsonObject,
          after: after as unknown as Prisma.InputJsonObject,
          ...(input.reason ? { reason: input.reason } : {}),
          via: 'panel',
        },
        ip: actor.ip,
        requestId: actor.requestId,
      });
      return after;
    });
  }

  /** D228: the camera effects engine (`LiveConfig.cameraFxEngine`). */
  async getCameraFx(
    db: Pick<Prisma.TransactionClient, 'siteSetting'> = this.prisma,
  ): Promise<CameraFxSettingsDto> {
    return { cameraFxEngine: await readCameraFxEngine(db) };
  }

  /**
   * D228: the OWNER flips the engine from the panel; audited in the same transaction as a site-settings change
   * (`site.settings.update`, `metadata.key` = `cameraFxEngine`, before and after).
   */
  async updateCameraFx(input: UpdateCameraFxInput, actor: SiteSettingsActor): Promise<CameraFxSettingsDto> {
    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('site_settings'))`;
      const before = await this.getCameraFx(tx);
      const after: CameraFxSettingsDto = { cameraFxEngine: input.cameraFxEngine };
      await tx.siteSetting.upsert({
        where: { key: CAMERA_FX_SETTING_KEY },
        create: { key: CAMERA_FX_SETTING_KEY, value: after.cameraFxEngine, updatedById: actor.userId },
        update: { value: after.cameraFxEngine, updatedById: actor.userId },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.SITE_SETTINGS_UPDATE,
        actorUserId: actor.userId,
        targetType: 'site_settings',
        metadata: {
          key: CAMERA_FX_SETTING_KEY,
          before: before.cameraFxEngine,
          after: after.cameraFxEngine,
          ...(input.reason ? { reason: input.reason } : {}),
          via: 'panel',
        },
        ip: actor.ip,
        requestId: actor.requestId,
      });
      return after;
    });
  }

  /** D254: the level from which a level-up is announced in every live (default 30). */
  async getLevelTicker(
    db: Pick<Prisma.TransactionClient, 'siteSetting'> = this.prisma,
  ): Promise<LevelTickerSettingsDto> {
    return { minLevel: await readLevelTickerMinLevel(db) };
  }

  /**
   * D254: the OWNER sets the threshold from the panel; audited in the same transaction as a site-settings change
   * (`site.settings.update`, `metadata.key` = `levelTickerMinLevel`, before and after).
   */
  async updateLevelTicker(
    input: UpdateLevelTickerInput,
    actor: SiteSettingsActor,
  ): Promise<LevelTickerSettingsDto> {
    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('site_settings'))`;
      const before = await this.getLevelTicker(tx);
      const after: LevelTickerSettingsDto = { minLevel: input.minLevel };
      await tx.siteSetting.upsert({
        where: { key: LEVEL_TICKER_SETTING_KEY },
        create: { key: LEVEL_TICKER_SETTING_KEY, value: after.minLevel, updatedById: actor.userId },
        update: { value: after.minLevel, updatedById: actor.userId },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.SITE_SETTINGS_UPDATE,
        actorUserId: actor.userId,
        targetType: 'site_settings',
        metadata: {
          key: LEVEL_TICKER_SETTING_KEY,
          before: before.minLevel,
          after: after.minLevel,
          ...(input.reason ? { reason: input.reason } : {}),
          via: 'panel',
        },
        ip: actor.ip,
        requestId: actor.requestId,
      });
      return after;
    });
  }

  /** D305: the server's configuration — the thresholds when the OWNER has set none. */
  get globalStripsDefaults(): GlobalStripsSettingsDto {
    return globalStripsDefaultsOf(this.config);
  }

  /** D318: [value] with the lucky multipliers the chat threshold may be (the panel's choice list). */
  withLuckyMultipliers(value: GlobalStripsSettingsDto): AdminGlobalStripsDto {
    return { ...value, luckyMultipliers: [...luckyMultipliersOf(this.config)] };
  }

  /** D305: the global strips' thresholds (the gift's unit price, the prize in tickets). */
  async getGlobalStrips(
    db: Pick<Prisma.TransactionClient, 'siteSetting'> = this.prisma,
  ): Promise<GlobalStripsSettingsDto> {
    return readGlobalStrips(db, this.globalStripsDefaults, luckyMultipliersOf(this.config));
  }

  /**
   * D305 (owner: «both thresholds editable in the panel»): the OWNER sets them; audited in the same transaction
   * (`site.settings.update`, `metadata.key` = `globalStrips`, before and after). The live strips read them through a
   * cache of at most 30 s (no restart).
   */
  async updateGlobalStrips(
    input: UpdateGlobalStripsInput,
    actor: SiteSettingsActor,
  ): Promise<GlobalStripsSettingsDto> {
    // v1.89-live (D318): the chat threshold is one of the lucky multipliers.
    if (
      input.luckyChatMinMultiplier !== undefined &&
      !luckyMultipliersOf(this.config).includes(input.luckyChatMinMultiplier)
    ) {
      throw AppException.validation([{ field: 'luckyChatMinMultiplier', issue: 'invalid_value' }]);
    }
    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('site_settings'))`;
      const before = await this.getGlobalStrips(tx);
      const after: GlobalStripsSettingsDto = {
        giftMinCoins: input.giftMinCoins,
        gameMinTickets: input.gameMinTickets,
        luckyChatMinMultiplier: input.luckyChatMinMultiplier ?? before.luckyChatMinMultiplier,
      };
      const value = {
        giftMinCoins: after.giftMinCoins,
        gameMinTickets: after.gameMinTickets,
        luckyChatMinMultiplier: after.luckyChatMinMultiplier,
      };
      await tx.siteSetting.upsert({
        where: { key: GLOBAL_STRIPS_SETTING_KEY },
        create: { key: GLOBAL_STRIPS_SETTING_KEY, value, updatedById: actor.userId },
        update: { value, updatedById: actor.userId },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.SITE_SETTINGS_UPDATE,
        actorUserId: actor.userId,
        targetType: 'site_settings',
        metadata: {
          key: GLOBAL_STRIPS_SETTING_KEY,
          before: { ...before },
          after: { ...after },
          ...(input.reason ? { reason: input.reason } : {}),
          via: 'panel',
        },
        ip: actor.ip,
        requestId: actor.requestId,
      });
      return after;
    });
  }
}
