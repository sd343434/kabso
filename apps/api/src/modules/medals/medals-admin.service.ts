import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { sortRequirements } from './medal-requirements.js';
import {
  BINARY_MEDAL_METRICS,
  MEDAL_MAX_LEVELS,
  MEDAL_MAX_THRESHOLD,
  REQUIREMENT_METRICS,
  type MedalCategoryCode,
  type MedalMetricCode,
  type RequirementMetricCode,
} from './medals.catalogue.js';

/** `AdminMedalLevel` (v1.81-live, D291, §10.104.4). */
export interface AdminMedalLevelDto {
  level: number;
  threshold: number;
  nameAr: string | null;
  nameEn: string | null;
  iconUrl: string | null;
  /** D291: the level's art bundled in the app, or null. */
  iconAsset: string | null;
  /** People whose level is exactly this one. */
  holders: number;
  /** D300 (§10.111): a multi-requirement level's thresholds (followers, likes, views); empty otherwise. */
  requirements: AdminMedalRequirementDto[];
}

/** `MedalLevelRequirement` (D300). */
export interface AdminMedalRequirementDto {
  metric: RequirementMetricCode;
  threshold: number;
}

/** `AdminMedal`. */
export interface AdminMedalDto {
  code: string;
  nameAr: string;
  nameEn: string;
  iconKey: string;
  sortOrder: number;
  category: MedalCategoryCode;
  metric: MedalMetricCode | null;
  /** D291: a name-side icon, not a wearable medal any more (read-only here). */
  retired: boolean;
  /** People who hold the medal at any level. */
  holders: number;
  levels: AdminMedalLevelDto[];
}

/** `AdminMedalList`. */
export interface AdminMedalListDto {
  data: AdminMedalDto[];
}

const optionalName = z
  .string()
  .trim()
  .min(1)
  .max(60)
  .nullish()
  .transform((v) => v ?? null);

/** `AdminMedalInput` (strict): the medal's tab and its whole levels list, lowest first, with a reason and the code. */
export const adminMedalBody = z.strictObject({
  category: z.enum(['ACHIEVEMENT', 'ACTIVITY']),
  levels: z
    .array(
      z.strictObject({
        threshold: z.number().int().min(1).max(MEDAL_MAX_THRESHOLD),
        nameAr: optionalName,
        nameEn: optionalName,
        iconUrl: z
          .string()
          .trim()
          .max(500)
          .regex(/^https:\/\/[^\s]+$/)
          .nullish()
          .transform((v) => v ?? null),
        iconAsset: z
          .string()
          .regex(/^[a-z0-9_]{1,60}$/)
          .nullish()
          .transform((v) => v ?? null),
        // D300 (§10.111): a multi-requirement level's thresholds, one per metric; only for a medal on
        // ALL_REQUIREMENTS (checked in `update`).
        requirements: z
          .array(
            z.strictObject({
              metric: z.enum(REQUIREMENT_METRICS as [RequirementMetricCode, ...RequirementMetricCode[]]),
              threshold: z.number().int().min(1).max(MEDAL_MAX_THRESHOLD),
            }),
          )
          .max(REQUIREMENT_METRICS.length)
          .optional()
          .transform((v) => v ?? []),
      }),
    )
    .min(1)
    .max(MEDAL_MAX_LEVELS)
    .refine((ls) => ls.every((l, i) => i === 0 || l.threshold > ls[i - 1]!.threshold), {
      message: 'each level needs more than the one before',
      params: { issue: 'invalid_value' },
    }),
  reason: z.string().trim().min(1).max(500),
  totpCode: z.string().regex(/^[0-9]{6}$/),
});
export type AdminMedalBody = z.output<typeof adminMedalBody>;

type Db = Pick<Prisma.TransactionClient, 'medal' | 'userMedal'>;

/**
 * D300 (§10.111): a medal on `ALL_REQUIREMENTS` needs on every level one threshold per metric of the same set (1 … 3
 * of followers, likes, views), each strictly rising from level to level, and each level's `threshold` equal to its
 * number (the composite value is the level reached); any other medal takes no requirements. Else 400 `levels`.
 */
function checkRequirements(metric: MedalMetricCode | null, levels: AdminMedalBody['levels']): void {
  if (metric !== 'ALL_REQUIREMENTS') {
    if (levels.some((l) => l.requirements.length > 0)) {
      throw invalidLevels('only a multi-requirement medal takes requirements');
    }
    return;
  }
  const first = levels[0]!.requirements.map((r) => r.metric);
  for (const [i, l] of levels.entries()) {
    const metrics = l.requirements.map((r) => r.metric);
    if (l.threshold !== i + 1) {
      throw invalidLevels(
        `level ${String(i + 1)} of a multi-requirement medal has threshold ${String(i + 1)}`,
      );
    }
    if (
      metrics.length === 0 ||
      new Set(metrics).size !== metrics.length ||
      metrics.length !== first.length ||
      !metrics.every((m) => first.includes(m))
    ) {
      throw invalidLevels(
        'every level needs one threshold per requirement, the same requirements on every level',
      );
    }
    if (i > 0) {
      const prev = levels[i - 1]!.requirements;
      for (const r of l.requirements) {
        if (r.threshold <= prev.find((p) => p.metric === r.metric)!.threshold) {
          throw invalidLevels('each requirement needs more than the level before');
        }
      }
    }
  }
}

/**
 * The medals in the admin panel (v1.81-live, D291, CONVENTIONS §10.104.4): `catalog.view` reads every medal with its
 * levels and how many people hold each level; `catalog.manage` (OWNER) replaces a medal's tab and levels with a
 * reason and the authenticator code again, audited `medals.levels.update` (before / after). Levels already reached are
 * never lowered: a list that drops a level somebody holds is refused, and new thresholds apply from the next event (or
 * `medals-admin backfill` for past activity).
 */
@Injectable()
export class MedalsAdminService {
  constructor(private readonly prisma: PrismaService) {}

  async list(db: Db = this.prisma): Promise<AdminMedalListDto> {
    const [medals, counts] = await Promise.all([
      db.medal.findMany({
        orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
        include: { levels: { orderBy: { level: 'asc' }, include: { requirements: true } } },
      }),
      db.userMedal.groupBy({ by: ['medalCode', 'level'], _count: { _all: true } }),
    ]);
    const held = new Map<string, Map<number, number>>();
    for (const c of counts) {
      const m = held.get(c.medalCode) ?? new Map<number, number>();
      m.set(c.level, c._count._all);
      held.set(c.medalCode, m);
    }
    return {
      data: medals.map((m) => {
        const byLevel = held.get(m.code) ?? new Map<number, number>();
        return {
          code: m.code,
          nameAr: m.nameAr,
          nameEn: m.nameEn,
          iconKey: m.iconKey,
          sortOrder: m.sortOrder,
          category: m.category,
          metric: m.metric,
          retired: m.retired,
          holders: [...byLevel.values()].reduce((a, b) => a + b, 0),
          levels: m.levels.map((l) => ({
            level: l.level,
            threshold: Number(l.threshold),
            nameAr: l.nameAr,
            nameEn: l.nameEn,
            iconUrl: l.iconUrl,
            iconAsset: l.iconAsset,
            holders: byLevel.get(l.level) ?? 0,
            requirements: sortRequirements(
              l.requirements.map((r) => ({
                metric: r.metric as RequirementMetricCode,
                threshold: Number(r.threshold),
              })),
            ),
          })),
        };
      }),
    };
  }

  /**
   * `PUT /admin/medals/{code}`: replaces the tab and the levels in one transaction. 404 unknown medal; 400 `levels`
   * `invalid_value`: a 0/1 metric (family, couple) or a medal without a metric with anything but one level at 1, or
   * a list shorter than the highest level somebody holds.
   */
  async update(code: string, body: AdminMedalBody, by: AdminVia): Promise<AdminMedalDto> {
    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended('medal_levels', 0))`;
      const medal = await tx.medal.findUnique({
        where: { code },
        select: { code: true, metric: true, retired: true },
      });
      if (!medal) throw new AppException(ErrorCode.NOT_FOUND);
      // D291: a retired code is a name-side icon, not a medal: nothing to edit.
      if (medal.retired) throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, 'medal_retired');
      const thresholds = body.levels.map((l) => l.threshold);
      const single = medal.metric === null || BINARY_MEDAL_METRICS.has(medal.metric);
      if (single && (thresholds.length !== 1 || thresholds[0] !== 1)) {
        throw invalidLevels('this medal is earned once: exactly one level at 1');
      }
      checkRequirements(medal.metric, body.levels);
      const top = await tx.userMedal.aggregate({ where: { medalCode: code }, _max: { level: true } });
      const highest = top._max.level ?? 0;
      if (highest > thresholds.length) {
        throw invalidLevels(`level ${String(highest)} is held by somebody; levels are never taken away`);
      }
      const before = (await this.list(tx)).data.find((m) => m.code === code)!;
      await tx.medal.update({ where: { code }, data: { category: body.category } });
      await tx.medalLevel.deleteMany({ where: { medalCode: code } });
      await tx.medalLevel.createMany({
        data: body.levels.map((l, i) => ({
          medalCode: code,
          level: i + 1,
          threshold: BigInt(l.threshold),
          nameAr: l.nameAr,
          nameEn: l.nameEn,
          iconUrl: l.iconUrl,
          iconAsset: l.iconAsset,
        })),
      });
      // D300: the requirements of each level (the levels' delete above removed the old ones).
      const requirements = body.levels.flatMap((l, i) =>
        l.requirements.map((r) => ({
          medalCode: code,
          level: i + 1,
          metric: r.metric,
          threshold: BigInt(r.threshold),
        })),
      );
      if (requirements.length > 0) await tx.medalLevelRequirement.createMany({ data: requirements });
      const after = (await this.list(tx)).data.find((m) => m.code === code)!;
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.MEDALS_LEVELS_UPDATE,
          targetType: 'medal',
          targetId: code,
          metadata: {
            via: by.via,
            reason: body.reason,
            before: { category: before.category, levels: before.levels.map(auditLevel) },
            after: { category: after.category, levels: after.levels.map(auditLevel) },
          },
        },
      });
      return after;
    });
  }
}

function auditLevel(l: AdminMedalLevelDto): Record<string, string | number | null> {
  return {
    level: l.level,
    threshold: l.threshold,
    nameAr: l.nameAr,
    nameEn: l.nameEn,
    iconUrl: l.iconUrl,
    iconAsset: l.iconAsset,
    ...(l.requirements.length > 0
      ? { requirements: l.requirements.map((r) => `${r.metric}:${String(r.threshold)}`).join(',') }
      : {}),
  };
}

function invalidLevels(message: string): AppException {
  return AppException.validation([{ field: 'levels', issue: 'invalid_value' }], message);
}
