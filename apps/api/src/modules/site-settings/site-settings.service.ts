import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import {
  SITE_SETTINGS_DEFAULTS,
  type SiteSettingsDto,
  type UpdateSiteSettingsInput,
} from './site-settings.rules.js';

export interface SiteSettingsActor {
  readonly userId: string;
  readonly ip: string | null;
  readonly requestId: string | null;
}

/** Owns `site_settings` (v1.60-social, D191/D192, §10.54.6): one row per key, defaults when absent. */
@Injectable()
export class SiteSettingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async get(db: Pick<Prisma.TransactionClient, 'siteSetting'> = this.prisma): Promise<SiteSettingsDto> {
    const rows = await db.siteSetting.findMany({ where: { key: { in: ['socials', 'topupEnabled'] } } });
    const byKey = new Map(rows.map((r) => [r.key, r.value]));
    const socials = (byKey.get('socials') ?? {}) as Partial<SiteSettingsDto['socials']>;
    const str = (v: unknown) => (typeof v === 'string' && v !== '' ? v : null);
    return {
      socials: {
        instagram: str(socials.instagram) ?? SITE_SETTINGS_DEFAULTS.socials.instagram,
        tiktok: str(socials.tiktok) ?? SITE_SETTINGS_DEFAULTS.socials.tiktok,
        whatsapp: str(socials.whatsapp) ?? SITE_SETTINGS_DEFAULTS.socials.whatsapp,
      },
      topupEnabled: byKey.get('topupEnabled') === true,
    };
  }

  /** The OWNER's change from the panel: both keys in one transaction with an audit row (before and after). */
  async update(input: UpdateSiteSettingsInput, actor: SiteSettingsActor): Promise<SiteSettingsDto> {
    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('site_settings'))`;
      const before = await this.get(tx);
      const after: SiteSettingsDto = { socials: input.socials, topupEnabled: input.topupEnabled };
      for (const [key, value] of [
        ['socials', after.socials],
        ['topupEnabled', after.topupEnabled],
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
