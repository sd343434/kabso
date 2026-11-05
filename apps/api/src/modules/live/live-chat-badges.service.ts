import { Injectable } from '@nestjs/common';
import { Inject } from '@nestjs/common';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { limitedStaffSql } from './live-staff.js';

/** `LiveChatAuthorFamily` (v1.24.3-live, D119). */
export interface LiveChatAuthorFamilyDto {
  name: string;
  level: number;
}

/** `LiveChatAuthorBadges` (v1.24.3-live, D119): what the chat line shows under the author's name. */
export interface LiveChatAuthorBadgesDto {
  /** The author's charm (`ATTRACTIVENESS`) level; null while that category is unavailable. */
  charmLevel: number | null;
  /** The author's `SUPPORT` level; null while that category is unavailable. */
  supportLevel: number | null;
  /** The author's family (not disbanded), or null. */
  family: LiveChatAuthorFamilyDto | null;
  /**
   * v1.34-live (D154c): the author's account is younger than NEWCOMER_DAYS («جديد 🌱»). The signup
   * date itself is never sent.
   */
  newcomer: boolean;
  /**
   * v1.52-live (§10.82): the medals the author chose to show on their profile (`ProfileMedals.showcase`),
   * the first {@link LIVE_CHAT_MEDALS_MAX} in their order; empty when none were chosen (no auto-fill).
   */
  medals: LiveChatAuthorMedalDto[];
}

/** `LiveChatAuthorMedal` (v1.52-live): one showcased medal on a chat line — its code and art key. */
export interface LiveChatAuthorMedalDto {
  code: string;
  iconKey: string;
}

/** v1.52-live (owner: «تحت سطر أيقونات الليفيل تكون الميداليات حتى ٥ ميداليات»). */
export const LIVE_CHAT_MEDALS_MAX = 5; // D269 (owner): was 3 (D258), 5 before.

/** Badges are read again after this long (a level-up or a new family shows within it). */
export const LIVE_CHAT_BADGES_TTL_MS = 30_000;
/** Authors kept in memory per API instance (the oldest are dropped first). */
const MAX_CACHED_AUTHORS = 5_000;

export const NO_BADGES: LiveChatAuthorBadgesDto = Object.freeze({
  charmLevel: null,
  supportLevel: null,
  family: null,
  newcomer: false,
  medals: Object.freeze([]) as unknown as LiveChatAuthorMedalDto[],
});

/**
 * A user's level number in one category, null while the category is unavailable (not enabled or
 * no published version). The same rule as the levels read side (`summaryDto`) and the room level
 * (`ROOM_LEVEL_SQL`, §10.18): the highest level of the published ladder the points (+ carried,
 * D194) reach, or the level kept from that same version if higher. The user is `a.id` of the surrounding
 * statement (also the D199b supporters lists).
 */
export function levelSql(code: 'ATTRACTIVENESS' | 'SUPPORT'): Prisma.Sql {
  return Prisma.sql`(
         SELECT CASE WHEN lc.is_enabled AND lc.published_version_id IS NOT NULL THEN
                  GREATEST(
                    (SELECT max(ld.level_number) FROM level_definitions ld
                      WHERE ld.version_id = lc.published_version_id
                        AND ld.required_points <= COALESCE(ls.total_points, 0)
                            + CASE WHEN ls.version_id = lc.published_version_id THEN ls.carried_points ELSE 0 END),
                    CASE WHEN ls.version_id = lc.published_version_id THEN ls.current_level END)
                END
           FROM level_categories lc
           LEFT JOIN user_level_states ls ON ls.category_id = lc.id AND ls.user_id = a.id
          WHERE lc.code = ${code}::level_category_code)`;
}

interface BadgeRow {
  user_id: string;
  charm_level: number | null;
  support_level: number | null;
  family_name: string | null;
  family_level: number | null;
  newcomer: boolean | null;
  medals: LiveChatAuthorMedalDto[] | null;
  limited_staff: boolean | null;
}

/**
 * D119 (owner: "make the chat text like this"): the small badges a live chat line shows under the
 * author's name — the charm and support levels (CP-005) and the family (CP-018); v1.52-live: the
 * author's showcased medals (≤ 5, D269; 3 in D258). Read in one statement for every author of a page; reading
 * `level_*`, `user_level_states`, `family_members`, `families`, `user_medals` and `medals` here
 * is a read-only exception to module table ownership like the room level (§10.18). Cached per author for {@link LIVE_CHAT_BADGES_TTL_MS} so a busy chat costs at most one
 * read per author and 30 s.
 */
@Injectable()
export class LiveChatBadgesService {
  private readonly cache = new Map<string, { at: number; badges: LiveChatAuthorBadgesDto }>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** The badges of each of `userIds` (every id gets an entry). */
  async of(userIds: readonly string[]): Promise<Map<string, LiveChatAuthorBadgesDto>> {
    const now = this.clock.now().getTime();
    const out = new Map<string, LiveChatAuthorBadgesDto>();
    const missing: string[] = [];
    for (const id of new Set(userIds)) {
      const hit = this.cache.get(id);
      if (hit && now - hit.at < LIVE_CHAT_BADGES_TTL_MS && now >= hit.at) out.set(id, hit.badges);
      else missing.push(id);
    }
    if (missing.length === 0) return out;
    const since = new Date(now - this.config.newcomerDays * 86_400_000).toISOString();
    const rows = await this.prisma.$queryRaw<BadgeRow[]>`
      SELECT a.id::text AS user_id,
             ${levelSql('ATTRACTIVENESS')} AS charm_level,
             ${levelSql('SUPPORT')} AS support_level,
             f.name AS family_name, f.level AS family_level,
             (SELECT u.created_at > ${since}::timestamptz FROM users u WHERE u.id = a.id) AS newcomer,
             ${limitedStaffSql(Prisma.sql`a.id`)} AS limited_staff,
             (SELECT COALESCE(json_agg(json_build_object('code', s.code, 'iconKey', s.icon_key) ORDER BY s.pos), '[]'::json)
                FROM (SELECT um.medal_code AS code, md.icon_key, um.showcase_position AS pos
                        FROM user_medals um
                        JOIN medals md ON md.code = um.medal_code
                       WHERE um.user_id = a.id AND um.showcase_position IS NOT NULL
                       ORDER BY um.showcase_position
                       LIMIT ${LIVE_CHAT_MEDALS_MAX}) s) AS medals
        FROM unnest(${missing}::uuid[]) AS a(id)
        LEFT JOIN family_members fm ON fm.user_id = a.id
        LEFT JOIN families f ON f.id = fm.family_id AND f.disbanded_at IS NULL`;
    for (const row of rows) {
      // v1.72-live (D283, §10.96.10): a Kabso Team account shows no levels, family, medals or newcomer tag — only
      // the team badge.
      const badges: LiveChatAuthorBadgesDto = row.limited_staff
        ? NO_BADGES
        : {
            charmLevel: row.charm_level,
            supportLevel: row.support_level,
            family:
              row.family_name !== null && row.family_level !== null
                ? { name: row.family_name, level: row.family_level }
                : null,
            newcomer: row.newcomer === true,
            medals: (row.medals ?? [])
              .slice(0, LIVE_CHAT_MEDALS_MAX)
              .map((m) => ({ code: m.code, iconKey: m.iconKey })),
          };
      out.set(row.user_id, badges);
      this.remember(row.user_id, badges, now);
    }
    for (const id of missing) if (!out.has(id)) out.set(id, NO_BADGES);
    return out;
  }

  /** The badges of one author. */
  async one(userId: string): Promise<LiveChatAuthorBadgesDto> {
    return (await this.of([userId])).get(userId) ?? NO_BADGES;
  }

  private remember(userId: string, badges: LiveChatAuthorBadgesDto, at: number): void {
    this.cache.delete(userId);
    this.cache.set(userId, { at, badges });
    while (this.cache.size > MAX_CACHED_AUTHORS) {
      const oldest = this.cache.keys().next().value;
      if (oldest === undefined) break;
      this.cache.delete(oldest);
    }
  }
}
