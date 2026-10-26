import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import type { Medal } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { UsersService } from '../users/users.service.js';

/** `Medal`: a catalogue entry with the caller's award time (null when not earned). */
export interface MedalDto {
  code: string;
  name: string;
  description: string;
  iconKey: string;
  sortOrder: number;
  awardedAt: string | null;
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
}

/** `UserMedalList`. */
export interface UserMedalListDto {
  data: UserMedalDto[];
  owned: number;
  total: number;
}

/** `ProfileMedal`: a medal as the profile shows it. */
export interface ProfileMedalDto {
  code: string;
  name: string;
  iconKey: string;
}

/** `ProfileMedals`: on the public profile (§10.5, §10.21). */
export interface ProfileMedalsDto {
  owned: number;
  total: number;
  latest: ProfileMedalDto[];
  /** The medals the user chose to show, in their order (≤ 6; empty until they choose). */
  showcase: ProfileMedalDto[];
}

/** `MedalShowcase`. */
export interface MedalShowcaseDto {
  showcase: ProfileMedalDto[];
}

/** The most medals a profile shows (owner, D106 amendment). */
export const MEDAL_SHOWCASE_MAX = 6;

/** `SetMedalShowcaseRequest` (strict): 0–6 distinct medal codes, in display order. */
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
  ) {}

  /** `GET /medals`: every medal in catalogue order, with the caller's award times. */
  async catalogue(callerId: string, lang: ContentLanguage): Promise<MedalCatalogueDto> {
    const [medals, mine] = await Promise.all([
      this.prisma.medal.findMany({ orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }] }),
      this.prisma.userMedal.findMany({
        where: { userId: callerId },
        select: { medalCode: true, awardedAt: true },
      }),
    ]);
    const owned = new Map(mine.map((m) => [m.medalCode, m.awardedAt]));
    return {
      data: medals.map((m) => ({
        code: m.code,
        ...localized(m, lang),
        iconKey: m.iconKey,
        sortOrder: m.sortOrder,
        awardedAt: owned.get(m.code)?.toISOString() ?? null,
      })),
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
        where: { userId: user.id },
        orderBy: [{ awardedAt: 'desc' }, { medal: { sortOrder: 'desc' } }],
        include: { medal: true },
      }),
      this.prisma.medal.count(),
    ]);
    return {
      data: rows.map((r) => ({
        code: r.medalCode,
        ...localized(r.medal, lang),
        iconKey: r.medal.iconKey,
        awardedAt: r.awardedAt.toISOString(),
      })),
      owned: rows.length,
      total,
    };
  }

  /** The medal summary of a public profile. */
  async profileMedals(userId: string, lang: ContentLanguage): Promise<ProfileMedalsDto> {
    const [owned, total, latest, showcase] = await Promise.all([
      this.prisma.userMedal.count({ where: { userId } }),
      this.prisma.medal.count(),
      this.prisma.userMedal.findMany({
        where: { userId },
        orderBy: [{ awardedAt: 'desc' }, { medal: { sortOrder: 'desc' } }],
        take: PROFILE_LATEST_MEDALS,
        include: { medal: true },
      }),
      this.showcaseOf(userId, lang),
    ]);
    return {
      owned,
      total,
      latest: latest.map((r) => ({
        code: r.medalCode,
        name: localized(r.medal, lang).name,
        iconKey: r.medal.iconKey,
      })),
      showcase,
    };
  }

  private async showcaseOf(userId: string, lang: ContentLanguage): Promise<ProfileMedalDto[]> {
    const rows = await this.prisma.userMedal.findMany({
      where: { userId, showcasePosition: { not: null } },
      orderBy: { showcasePosition: 'asc' },
      include: { medal: true },
    });
    return rows.map((r) => ({
      code: r.medalCode,
      name: localized(r.medal, lang).name,
      iconKey: r.medal.iconKey,
    }));
  }

  /** `GET /me/medals/showcase`. */
  async myShowcase(callerId: string, lang: ContentLanguage): Promise<MedalShowcaseDto> {
    return { showcase: await this.showcaseOf(callerId, lang) };
  }

  /**
   * `PUT /me/medals/showcase {medalCodes}` (owner, D106 amendment): replaces the medals shown on
   * the caller's profile, in this order. 400: more than 6, duplicates, or not strings; 409
   * MEDAL_NOT_UNLOCKED: a code the caller has not earned (unknown codes too). An empty list shows
   * none. One transaction.
   */
  async setShowcase(callerId: string, body: unknown, lang: ContentLanguage): Promise<MedalShowcaseDto> {
    const parsed = setMedalShowcaseSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const codes = parsed.data.medalCodes;
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
