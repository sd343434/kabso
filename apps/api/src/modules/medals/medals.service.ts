import { giftArtUrl } from '../gifts/gift-art.js';
import { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import type { Medal, MedalLevel, MedalLevelRequirement, Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { UsersService } from '../users/users.service.js';
import {
  creatorRequirementValuesIn,
  sortRequirements,
  ZERO_REQUIREMENT_VALUES,
  type RequirementValues,
} from './medal-requirements.js';
import { CREATOR_ONLY_METRICS, isRequirementMetric, levelByRequirements } from './medals.catalogue.js';

/** `MedalLevel` (v1.81-live, D291): one level of a medal — reached when the medal's metric is at least `threshold`. */
export interface MedalLevelDto {
  level: number;
  threshold: number;
  /** This level's own name in the caller's language, or null (the medal's name with the numeral). */
  name: string | null;
  /** This level's own hosted art, or null. */
  iconUrl: string | null;
  /** D291: this level's art bundled in the app (an asset key), or null (the medal's art). */
  iconAsset: string | null;
  /**
   * D300 (§10.111): a multi-requirement level's thresholds — all of them together reach it (followers, likes, views);
   * empty for a single-metric medal.
   */
  requirements: MedalLevelRequirementDto[];
}

/** `MedalLevelRequirement` (D300): one threshold of a multi-requirement level. */
export interface MedalLevelRequirementDto {
  metric: string;
  threshold: number;
}

/** `MedalRequirementProgress` (D300): the caller's value of one requirement and the next level's target. */
export interface MedalRequirementProgressDto {
  metric: string;
  value: number;
  /** The next level's threshold of this metric; null at the top level. */
  next: number | null;
}

/** `MedalProgress` (v1.81-live, D291): the caller's metric now and the next level's threshold (null at the top). */
export interface MedalProgressDto {
  value: number;
  next: number | null;
  /**
   * D300 (§10.111): a multi-requirement medal's requirements — each value now against the next level's threshold
   * (the top level's thresholds with `next` null at the top); empty for a single-metric medal.
   */
  requirements: MedalRequirementProgressDto[];
}

/** `Medal`: a catalogue entry with the caller's award time (null when not earned). */
export interface MedalDto {
  code: string;
  name: string;
  description: string;
  iconKey: string;
  sortOrder: number;
  awardedAt: string | null;
  /** v1.81-live (D291): the page's tab. */
  category: 'ACHIEVEMENT' | 'ACTIVITY';
  /** v1.81-live (D291): what the levels count (the app words the thresholds with it); null = no levels. */
  metric: string | null;
  /** v1.81-live (D291): the caller's level, 0 when not earned. */
  level: number;
  /** v1.81-live (D291): how many levels the medal has (≥ 1). */
  maxLevel: number;
  /** v1.81-live (D291): every level, lowest first (empty for a medal without levels: one implied level). */
  levels: MedalLevelDto[];
  progress: MedalProgressDto;
  /** v1.81-live (D291): the art of the level shown (the caller's, else level 1), or null (the app's art). */
  iconUrl: string | null;
  /** D291: the bundled art key of the level shown, or null (the app draws `iconKey`). */
  iconAsset: string | null;
  /** v1.81-live (D291): 1 … 5 when the caller wears it (the showcase, in order), else null. */
  showcasePosition: number | null;
  /**
   * D300 (§10.111): false when the medal is for content creators and the caller is not one now — they neither earn
   * nor progress (a level already reached is kept); true otherwise.
   */
  eligible: boolean;
}

/** `MedalCatalogue`. */
export interface MedalCatalogueDto {
  data: MedalDto[];
  total: number;
  owned: number;
}

/** `UserMedal`. */
export interface UserMedalDto {
  code: string;
  name: string;
  description: string;
  iconKey: string;
  awardedAt: string;
  /** v1.81-live (D291). */
  category: 'ACHIEVEMENT' | 'ACTIVITY';
  level: number;
  maxLevel: number;
  iconUrl: string | null;
  iconAsset: string | null;
}

/** v1.97-social (D303 follow-up, §10.114.8): an event badge «وسام فعالية» held now (shown with the medals). */
export interface EventBadgeHeldDto {
  code: string;
  name: string;
  /** The level held (its own art). */
  level: number;
  imageUrl: string | null;
  /** Null = permanent «دائم». */
  expiresAt: string | null;
}

/** `UserMedalList`. */
export interface UserMedalListDto {
  data: UserMedalDto[];
  owned: number;
  total: number;
  /** v1.97-social (D303 follow-up): the event badges held now (soonest end last). */
  eventBadges: EventBadgeHeldDto[];
}

/** `ProfileMedal`: a medal as the profile shows it. */
export interface ProfileMedalDto {
  code: string;
  name: string;
  iconKey: string;
  /** v1.81-live (D291): the holder's level (≥ 1); the app draws the numeral on the art. */
  level: number;
  /** v1.81-live (D291): that level's own art, or null. */
  iconUrl: string | null;
  /** D291: that level's bundled art key, or null. */
  iconAsset: string | null;
}

/** `ProfileMedals`: on the public profile (§10.5, §10.21). */
export interface ProfileMedalsDto {
  owned: number;
  total: number;
  latest: ProfileMedalDto[];
  /** The medals the user chose to show, in their order (≤ 6; empty until they choose). */
  showcase: ProfileMedalDto[];
  /** v1.97-social (D303 follow-up): the event badges held now, shown before the medals. */
  eventBadges: EventBadgeHeldDto[];
}

/** `MedalShowcase`. */
export interface MedalShowcaseDto {
  showcase: ProfileMedalDto[];
}

/**
 * The most medals a profile shows: 5 (owner, D269 «اجعل الميداليات حدها ٥» — D258 made it 3, was 6 before). An
 * older showcase of more keeps its first 5 on every read (trimmed on read; the rows keep their positions until the
 * person saves a new one).
 */
export const MEDAL_SHOWCASE_MAX = 5;

/** `SetMedalShowcaseRequest` (strict): 0–5 distinct medal codes, in display order. */
export const setMedalShowcaseSchema = z.strictObject({
  medalCodes: z
    .array(z.string().min(1).max(40))
    // A refinement rather than .max(): the §4 vocabulary says `too_big` (the pipe maps an array
    // .max() to `too_many`).
    .refine((codes) => codes.length <= MEDAL_SHOWCASE_MAX, {
      message: 'too_big',
      params: { issue: 'too_big' },
      abort: true,
    })
    .refine((codes) => new Set(codes).size === codes.length, {
      message: 'invalid_value',
      params: { issue: 'invalid_value' },
    }),
});

/** The newest medals shown on a profile. */
export const PROFILE_LATEST_MEDALS = 3;

function localized(medal: Medal, lang: ContentLanguage): { name: string; description: string } {
  return lang === 'ar'
    ? { name: medal.nameAr, description: medal.descriptionAr }
    : { name: medal.nameEn, description: medal.descriptionEn };
}

type MedalWithLevels = Medal & { levels: (MedalLevel & { requirements: MedalLevelRequirement[] })[] };

function profileMedalOf(
  row: { medalCode: string; level: number; medal: MedalWithLevels },
  lang: ContentLanguage,
): ProfileMedalDto {
  return {
    code: row.medalCode,
    name: localized(row.medal, lang).name,
    iconKey: row.medal.iconKey,
    level: Math.max(1, row.level),
    iconUrl: iconUrlOf(row.medal, row.level),
    iconAsset: iconAssetOf(row.medal, row.level),
  };
}

const WITH_LEVELS = {
  levels: { orderBy: { level: 'asc' }, include: { requirements: true } },
} as const satisfies Prisma.MedalInclude;

/** D300: a level's requirements, followers / likes / views order. */
function requirementsOf(level: MedalWithLevels['levels'][number]): MedalLevelRequirementDto[] {
  return sortRequirements(
    level.requirements.map((r) => ({ metric: r.metric, threshold: Number(r.threshold) })),
  );
}

/** D300: the medal is a multi-requirement one only content creators earn. */
function forCreatorsOnly(medal: MedalWithLevels): boolean {
  return medal.levels.some((l) =>
    l.requirements.some((r) => isRequirementMetric(r.metric) && CREATOR_ONLY_METRICS.has(r.metric)),
  );
}

function levelsOf(medal: MedalWithLevels, lang: ContentLanguage): MedalLevelDto[] {
  return medal.levels.map((l) => ({
    level: l.level,
    threshold: Number(l.threshold),
    name: (lang === 'ar' ? l.nameAr : l.nameEn) ?? null,
    iconUrl: l.iconUrl,
    iconAsset: l.iconAsset,
    requirements: requirementsOf(l),
  }));
}

/** The art URL of `level` (level 1's for 0), or null. */
function iconUrlOf(medal: MedalWithLevels, level: number): string | null {
  const shown = Math.max(1, level);
  return medal.levels.find((l) => l.level === shown)?.iconUrl ?? null;
}

/** D291: the bundled art key of `level` (level 1's for 0), or null. */
function iconAssetOf(medal: MedalWithLevels, level: number): string | null {
  const shown = Math.max(1, level);
  return medal.levels.find((l) => l.level === shown)?.iconAsset ?? null;
}

/** A medal without level rows has one implied level. */
function maxLevelOf(medal: MedalWithLevels): number {
  return Math.max(1, medal.levels.length);
}

/** Each metric's value for one person now (the medals page's progress, D291). */
async function metricValuesOf(db: PrismaService, userId: string): Promise<Record<string, number>> {
  const [row] = await db.$queryRaw<
    {
      lives: number;
      hours: number;
      charm: number | null;
      family: boolean;
      cp: boolean;
      bullets: number;
      gifts: bigint | null;
      lucky: bigint | null;
      pk: number | null;
    }[]
  >`
    SELECT
      (SELECT count(*)::int FROM live_rooms
        WHERE host_user_id = ${userId}::uuid AND status = 'ENDED' AND ended_at IS NOT NULL) AS lives,
      (SELECT coalesce(sum(extract(epoch FROM (ended_at - started_at))) / 3600, 0)::float8 FROM live_rooms
        WHERE host_user_id = ${userId}::uuid AND status = 'ENDED' AND ended_at IS NOT NULL) AS hours,
      (SELECT s.current_level FROM user_level_states s JOIN level_categories c ON c.id = s.category_id
        WHERE s.user_id = ${userId}::uuid AND c.code = 'ATTRACTIVENESS') AS charm,
      EXISTS (SELECT 1 FROM family_members WHERE user_id = ${userId}::uuid) AS family,
      EXISTS (SELECT 1 FROM cp_couples WHERE user_a_id = ${userId}::uuid OR user_b_id = ${userId}::uuid) AS cp,
      (SELECT count(*)::int FROM live_bullets WHERE user_id = ${userId}::uuid) AS bullets,
      (SELECT value FROM medal_metric_totals
        WHERE user_id = ${userId}::uuid AND metric = 'GIFTS_SENT_COINS') AS gifts,
      (SELECT value FROM medal_metric_totals
        WHERE user_id = ${userId}::uuid AND metric = 'LUCKY_GIFTS_SENT_COINS') AS lucky,
      (SELECT dares_points FROM pk_host_records WHERE host_id = ${userId}::uuid) AS pk`;
  return {
    LIVES_HOSTED: row?.lives ?? 0,
    LIVE_HOURS: Math.floor(row?.hours ?? 0),
    CHARM_LEVEL: row?.charm ?? 0,
    FAMILY_JOINED: row?.family ? 1 : 0,
    CP_FORMED: row?.cp ? 1 : 0,
    BULLETS_SENT: row?.bullets ?? 0,
    GIFTS_SENT_COINS: Number(row?.gifts ?? 0n),
    LUCKY_GIFTS_SENT_COINS: Number(row?.lucky ?? 0n),
    // D300 «لاعب الأحكام»: «PK أحكام» points now (shown from 0; the total itself may be below 0).
    PK_DARES_POINTS: Math.max(0, row?.pk ?? 0),
  };
}

/**
 * Medals (الميداليات, CP-018, owner D106, CONVENTIONS §10.21): the catalogue and who earned what.
 * Awarding happens where the events happen (medal-awards.ts); this service only reads. The
 * catalogue is small and server-bounded, so lists are returned whole (§5).
 */
@Injectable()
export class MedalsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly storageSettings: StorageSettingsStore,
  ) {}

  /** v1.97-social (D303 follow-up): the event badges `userId` holds now (an ended one is never shown). */
  async eventBadgesOf(userId: string, lang: ContentLanguage): Promise<EventBadgeHeldDto[]> {
    const rows = await this.prisma.userEventBadge.findMany({
      where: { userId, OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }] },
      orderBy: [{ expiresAt: 'desc' }, { badgeCode: 'asc' }],
      include: { badge: { include: { levels: true } } },
    });
    const base = this.storageSettings.current().publicBaseUrl;
    return rows.map((r) => ({
      code: r.badgeCode,
      name: lang === 'ar' ? r.badge.nameAr : r.badge.nameEn,
      level: r.level,
      imageUrl: giftArtUrl(base, r.badge.levels.find((l) => l.level === r.level)?.imageKey ?? null),
      expiresAt: r.expiresAt?.toISOString() ?? null,
    }));
  }

  /** `GET /medals`: every medal in catalogue order, with the caller's award times. */
  async catalogue(callerId: string, lang: ContentLanguage): Promise<MedalCatalogueDto> {
    const [medals, mine, values] = await Promise.all([
      this.prisma.medal.findMany({
        where: { retired: false },
        orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
        include: WITH_LEVELS,
      }),
      this.prisma.userMedal.findMany({
        where: { userId: callerId, medal: { retired: false } },
        select: { medalCode: true, awardedAt: true, level: true, showcasePosition: true },
      }),
      metricValuesOf(this.prisma, callerId),
    ]);
    const owned = new Map(mine.map((m) => [m.medalCode, m]));
    // D300: a content creator's requirement values (counted only when a multi-requirement medal exists; a
    // non-creator has none — they neither earn nor progress).
    const creator = medals.some((m) => m.metric === 'ALL_REQUIREMENTS')
      ? ((await creatorRequirementValuesIn(this.prisma, [callerId])).get(callerId) ?? null)
      : null;
    // The worn ones as the showcase reads them (its first 5, in order; D269).
    const worn = mine
      .filter((m) => m.showcasePosition !== null)
      .sort((a, b) => a.showcasePosition! - b.showcasePosition!)
      .slice(0, MEDAL_SHOWCASE_MAX)
      .map((m) => m.medalCode);
    return {
      data: medals.map((m) => {
        const held = owned.get(m.code);
        const level = held ? Math.max(1, held.level) : 0;
        const levels = levelsOf(m, lang);
        const multi = m.metric === 'ALL_REQUIREMENTS';
        const eligible = !forCreatorsOnly(m) || creator !== null;
        const reqValues: RequirementValues = eligible && creator ? creator : ZERO_REQUIREMENT_VALUES;
        const value = multi
          ? levelByRequirements(
              m.levels.map((l) => ({
                requirements: requirementsOf(l).flatMap((r) =>
                  isRequirementMetric(r.metric) ? [{ metric: r.metric, threshold: r.threshold }] : [],
                ),
              })),
              reqValues,
            )
          : m.metric
            ? (values[m.metric] ?? 0)
            : held
              ? 1
              : 0;
        const position = worn.indexOf(m.code);
        const target = levels.find((l) => l.level === level + 1) ?? null;
        const top = levels[levels.length - 1];
        return {
          code: m.code,
          ...localized(m, lang),
          iconKey: m.iconKey,
          sortOrder: m.sortOrder,
          awardedAt: held?.awardedAt.toISOString() ?? null,
          category: m.category,
          metric: m.metric,
          level,
          maxLevel: maxLevelOf(m),
          levels,
          progress: {
            value,
            next: target?.threshold ?? null,
            // D300: each requirement now against the next level's target (the top level's at the top).
            requirements: multi
              ? ((target ?? top)?.requirements.map((r) => ({
                  metric: r.metric,
                  value: isRequirementMetric(r.metric) ? reqValues[r.metric] : 0,
                  next: target ? r.threshold : null,
                })) ?? [])
              : [],
          },
          iconUrl: iconUrlOf(m, level),
          iconAsset: iconAssetOf(m, level),
          showcasePosition: position < 0 ? null : position + 1,
          eligible,
        };
      }),
      total: medals.length,
      owned: owned.size,
    };
  }

  /** `GET /users/{username}/medals`: the user's medals, newest first (404 like the profile). */
  async ofUser(username: string, lang: ContentLanguage): Promise<UserMedalListDto> {
    const user = await this.users.findActivePublicUser(username);
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    const [rows, total] = await Promise.all([
      this.prisma.userMedal.findMany({
        where: { userId: user.id, medal: { retired: false } },
        orderBy: [{ awardedAt: 'desc' }, { medal: { sortOrder: 'desc' } }],
        include: { medal: { include: WITH_LEVELS } },
      }),
      this.prisma.medal.count({ where: { retired: false } }),
    ]);
    return {
      data: rows.map((r) => ({
        code: r.medalCode,
        ...localized(r.medal, lang),
        iconKey: r.medal.iconKey,
        awardedAt: r.awardedAt.toISOString(),
        category: r.medal.category,
        level: Math.max(1, r.level),
        maxLevel: maxLevelOf(r.medal),
        iconUrl: iconUrlOf(r.medal, r.level),
        iconAsset: iconAssetOf(r.medal, r.level),
      })),
      owned: rows.length,
      total,
      eventBadges: await this.eventBadgesOf(user.id, lang),
    };
  }

  /** The medal summary of a public profile. */
  async profileMedals(userId: string, lang: ContentLanguage): Promise<ProfileMedalsDto> {
    const [owned, total, latest, showcase] = await Promise.all([
      this.prisma.userMedal.count({ where: { userId, medal: { retired: false } } }),
      this.prisma.medal.count({ where: { retired: false } }),
      this.prisma.userMedal.findMany({
        where: { userId, medal: { retired: false } },
        orderBy: [{ awardedAt: 'desc' }, { medal: { sortOrder: 'desc' } }],
        take: PROFILE_LATEST_MEDALS,
        include: { medal: { include: WITH_LEVELS } },
      }),
      this.showcaseOf(userId, lang),
    ]);
    return {
      owned,
      total,
      latest: latest.map((r) => profileMedalOf(r, lang)),
      showcase,
      eventBadges: await this.eventBadgesOf(userId, lang),
    };
  }

  private async showcaseOf(userId: string, lang: ContentLanguage): Promise<ProfileMedalDto[]> {
    const rows = await this.prisma.userMedal.findMany({
      where: { userId, showcasePosition: { not: null }, medal: { retired: false } },
      orderBy: { showcasePosition: 'asc' },
      include: { medal: { include: WITH_LEVELS } },
      take: MEDAL_SHOWCASE_MAX,
    });
    return rows.map((r) => profileMedalOf(r, lang));
  }

  /** `GET /me/medals/showcase`. */
  async myShowcase(callerId: string, lang: ContentLanguage): Promise<MedalShowcaseDto> {
    return { showcase: await this.showcaseOf(callerId, lang) };
  }

  /**
   * `PUT /me/medals/showcase {medalCodes}` (owner, D106 amendment): replaces the medals shown on
   * the caller's profile, in this order. 400: more than 3 (D258), duplicates, or not strings; 409
   * MEDAL_NOT_UNLOCKED: a code the caller has not earned (unknown codes too). An empty list shows
   * none. One transaction.
   */
  async setShowcase(callerId: string, body: unknown, lang: ContentLanguage): Promise<MedalShowcaseDto> {
    const parsed = setMedalShowcaseSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const codes = parsed.data.medalCodes;
    // D291: a retired code (a name-side icon, not a wearable medal) → 400 `medalCodes` / `invalid_value`.
    if (codes.length > 0) {
      const retired = await this.prisma.medal.count({ where: { code: { in: codes }, retired: true } });
      if (retired > 0) throw AppException.validation([{ field: 'medalCodes', issue: 'invalid_value' }]);
    }
    await this.prisma.$transaction(async (tx) => {
      const owned = await tx.$queryRaw<{ medal_code: string }[]>`
        SELECT medal_code FROM user_medals WHERE user_id = ${callerId}::uuid FOR UPDATE`;
      const mine = new Set(owned.map((r) => r.medal_code));
      if (codes.some((code) => !mine.has(code))) throw new AppException(ErrorCode.MEDAL_NOT_UNLOCKED);
      await tx.userMedal.updateMany({ where: { userId: callerId }, data: { showcasePosition: null } });
      for (const [i, code] of codes.entries()) {
        await tx.userMedal.update({
          where: { userId_medalCode: { userId: callerId, medalCode: code } },
          data: { showcasePosition: i + 1 },
        });
      }
    });
    return this.myShowcase(callerId, lang);
  }
}
