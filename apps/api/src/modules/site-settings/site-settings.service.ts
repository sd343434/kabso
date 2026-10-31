import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { PaymentSettingsStore } from '../payment-settings/payment-settings.store.js';
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
}
