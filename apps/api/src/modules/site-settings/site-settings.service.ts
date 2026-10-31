import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import type { ErrorDetail } from '../../common/errors/error-codes.js';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import {
  DEFAULT_SITE_SETTINGS,
  normalizeSocial,
  SETTING_KEYS,
  SOCIAL_KEYS,
  storedSocial,
  type SiteSettingsDto,
  type SocialKey,
} from './site-settings.rules.js';

export interface SiteSettingsUpdate {
  readonly socials?: Partial<Record<SocialKey, string | null>> | undefined;
  readonly topupEnabled?: boolean | undefined;
}

export interface SiteSettingsActor {
  readonly userId: string;
  readonly ip: string | null;
  readonly requestId: string | null;
}

/**
 * D192 (contract v1.61-social, CONVENTIONS §10.55): the public website's settings — the footer's social links and
 * whether the header shows «شحن العملات». Owns `site_settings`. Read by the website (`GET /site/settings`), written
 * only through `PUT /admin/site-settings` (permission `SITE_SETTINGS`; D191's admin panel calls it), each change
 * audited in the same transaction with the values before and after.
 */
@Injectable()
export class SiteSettingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async get(): Promise<SiteSettingsDto> {
    const rows = await this.prisma.siteSetting.findMany();
    return fromRows(rows);
  }

  /** Validates every field first (all or nothing), then writes the changed keys and the audit row. */
  async update(input: SiteSettingsUpdate, actor: SiteSettingsActor): Promise<SiteSettingsDto> {
    const writes = new Map<string, string | boolean | null>();
    const issues: ErrorDetail[] = [];
    for (const key of SOCIAL_KEYS) {
      const raw = input.socials?.[key];
      if (raw === undefined) continue;
      const value = normalizeSocial(key, raw);
      if (value === undefined) issues.push({ field: `socials.${key}`, issue: 'invalid_value' });
      else writes.set(SETTING_KEYS[key], value);
    }
    if (issues.length > 0) throw AppException.validation(issues);
    if (input.topupEnabled !== undefined) writes.set(SETTING_KEYS.topupEnabled, input.topupEnabled);

    return this.prisma.$transaction(async (tx) => {
      const before = fromRows(await tx.siteSetting.findMany());
      for (const [key, value] of writes) {
        if (value === null) {
          await tx.siteSetting.deleteMany({ where: { key } });
        } else {
          await tx.siteSetting.upsert({
            where: { key },
            create: { key, value, updatedById: actor.userId },
            update: { value, updatedById: actor.userId },
          });
        }
      }
      const after = fromRows(await tx.siteSetting.findMany());
      if (JSON.stringify(before) !== JSON.stringify(after)) {
        await this.audit.recordIn(tx, {
          action: AuditAction.SITE_SETTINGS_UPDATE,
          actorUserId: actor.userId,
          targetType: 'site_settings',
          targetId: 'website',
          metadata: { before: toJson(before), after: toJson(after) },
          ip: actor.ip,
          requestId: actor.requestId,
        });
      }
      return after;
    });
  }
}

function fromRows(rows: readonly { key: string; value: unknown }[]): SiteSettingsDto {
  const map = new Map(rows.map((r) => [r.key, r.value]));
  return {
    socials: {
      instagram: storedSocial('instagram', map.get(SETTING_KEYS.instagram)),
      tiktok: storedSocial('tiktok', map.get(SETTING_KEYS.tiktok)),
      whatsapp: storedSocial('whatsapp', map.get(SETTING_KEYS.whatsapp)),
    },
    topupEnabled: map.get(SETTING_KEYS.topupEnabled) === true || DEFAULT_SITE_SETTINGS.topupEnabled,
  };
}

function toJson(s: SiteSettingsDto): { socials: Record<string, string | null>; topupEnabled: boolean } {
  return { socials: { ...s.socials }, topupEnabled: s.topupEnabled };
}
