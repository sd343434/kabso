import { Inject, Injectable } from '@nestjs/common';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { scoresSql } from '../programs/events.service.js';
import { dayStart } from '../recharge/recharge-rules.js';
import type { AdminContext } from './admin-auth.service.js';
import { PANEL_ROLES } from './admin-permissions.js';
import { StaffCompensationsService } from './staff-compensations.service.js';
import { StaffScheduleService } from './staff-schedule.service.js';

const DAY_MS = 86_400_000;
/** VIP_CARE's pool of top supporters (§10.176.3): SUPPORT level at least this, or an active VIP. */
export const VIP_CARE_MIN_LEVEL = 10;
/** «توقف عن النشاط»: not seen for this many days. */
export const VIP_CARE_INACTIVE_DAYS = 7;
/** TALENT: an agency with no host live for this many days is inactive. */
export const TALENT_INACTIVE_AGENCY_DAYS = 14;

const PERSON = { select: { id: true, profile: { select: { username: true, displayName: true, avatarUrl: true } } } };
type Person = { id: string; profile: { username: string; displayName: string; avatarUrl: string | null } | null };
const personDto = (u: Person) => ({
  id: u.id,
  username: u.profile?.username ?? '',
  displayName: u.profile?.displayName ?? '',
  avatarUrl: u.profile?.avatarUrl ?? null,
});

const panelRolesSql = Prisma.join(PANEL_ROLES.map((r) => Prisma.sql`${r}::admin_permission`));

interface SupporterRow {
  id: string;
  username: string | null;
  display_name: string | null;
  avatar_url: string | null;
  level: number | null;
  tier_code: string | null;
  tier_name_ar: string | null;
  tier_name_en: string | null;
  tier_color: string | null;
  last_active_at: Date | null;
}

function supporterDto(r: SupporterRow) {
  return {
    user: {
      id: r.id,
      username: r.username ?? '',
      displayName: r.display_name ?? '',
      avatarUrl: r.avatar_url,
    },
    level: r.level,
    vipTier:
      r.tier_code === null
        ? null
        : { code: r.tier_code, nameAr: r.tier_name_ar ?? '', nameEn: r.tier_name_en ?? '', color: r.tier_color ?? '' },
    lastActiveAt: r.last_active_at?.toISOString() ?? null,
  };
}

/**
 * v1.139-social (D387, CONVENTIONS §10.176.3): the landing page of each operations role — counts and lists only, never
 * a coin, revenue or earnings figure (§10.176.2). Each is one read with indexed range scans.
 */
@Injectable()
export class AdminRoleHomesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly schedule: StaffScheduleService,
    private readonly compensations: StaffCompensationsService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private livesNow(): Promise<number> {
    return this.prisma.liveRoom.count({ where: { status: 'LIVE' } });
  }

  /** Published events that have not ended (running first, then the next to start). */
  private async events(now: Date, limit = 20) {
    const rows = await this.prisma.event.findMany({
      where: { status: 'PUBLISHED', OR: [{ endsAt: null }, { endsAt: { gt: now } }] },
      select: { id: true, titleAr: true, titleEn: true, startsAt: true, endsAt: true, metric: true },
      orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
      take: limit,
    });
    return rows.map((e) => ({
      id: e.id,
      titleAr: e.titleAr,
      titleEn: e.titleEn,
      startsAt: e.startsAt?.toISOString() ?? null,
      endsAt: e.endsAt?.toISOString() ?? null,
      running: (e.startsAt === null || e.startsAt <= now) && (e.endsAt === null || e.endsAt > now),
      metric: e.metric,
    }));
  }

  /** `getAdminLiveOpsHome`. */
  async liveOps() {
    const now = this.clock.now();
    const since = new Date(now.getTime() - 7 * DAY_MS);
    const [livesNow, top, hosts, battlesNow, battlesToday, events] = await Promise.all([
      this.livesNow(),
      this.prisma.liveRoom.findMany({
        where: { status: 'LIVE' },
        select: { id: true, title: true, viewerCount: true, startedAt: true, host: PERSON },
        orderBy: [{ viewerCount: 'desc' }, { startedAt: 'asc' }],
        take: 10,
      }),
      this.prisma.$queryRaw<{ host_user_id: string; minutes: bigint }[]>`
        SELECT r.host_user_id::text AS host_user_id,
               floor(sum(GREATEST(0, extract(epoch FROM (
                 LEAST(COALESCE(r.ended_at, r.last_heartbeat_at), ${now}::timestamptz)
                 - GREATEST(r.started_at, ${since}::timestamptz))))) / 60)::bigint AS minutes
          FROM live_rooms r
         WHERE r.started_at < ${now}::timestamptz AND COALESCE(r.ended_at, r.last_heartbeat_at) > ${since}::timestamptz
         GROUP BY r.host_user_id
         ORDER BY minutes DESC, r.host_user_id
         LIMIT 10`,
      this.prisma.pkMatch.count({ where: { status: { in: ['CONNECTED', 'BATTLE', 'RESULT'] } } }),
      this.prisma.pkMatch.count({
        where: { startedAt: { gte: dayStart(now, this.config.adminPanel.dashboardTimeZone) } },
      }),
      this.events(now),
    ]);
    const ids = hosts.map((h) => h.host_user_id);
    const [people, live] = await Promise.all([
      this.prisma.user.findMany({ where: { id: { in: ids } }, ...PERSON }),
      this.prisma.liveRoom.findMany({
        where: { status: 'LIVE', hostUserId: { in: ids } },
        select: { hostUserId: true },
      }),
    ]);
    const byId = new Map(people.map((p) => [p.id, p]));
    const liveSet = new Set(live.map((l) => l.hostUserId));
    return {
      livesNow,
      topLives: top.map((r) => ({
        roomId: r.id,
        title: r.title,
        host: personDto(r.host),
        viewers: r.viewerCount,
        startedAt: r.startedAt.toISOString(),
      })),
      topHosts: hosts
        .filter((h) => byId.has(h.host_user_id))
        .map((h) => ({
          host: personDto(byId.get(h.host_user_id)!),
          liveMinutes7d: Number(h.minutes),
          liveNow: liveSet.has(h.host_user_id),
        })),
      pk: { battlesNow, battlesToday },
      events: events.map(({ metric: _metric, ...e }) => e),
    };
  }

  /** `getAdminTalentHome`. */
  async talent() {
    const now = this.clock.now();
    const since = new Date(now.getTime() - 7 * DAY_MS);
    const idle = new Date(now.getTime() - TALENT_INACTIVE_AGENCY_DAYS * DAY_MS);
    const [newHosts7d, hours, inactive, hostApplications, creatorApplications] = await Promise.all([
      this.prisma.agencyHost.count({ where: { activatedAt: { gte: since } } }),
      this.prisma.$queryRaw<{ minutes: bigint | null }[]>`
        SELECT floor(sum(GREATEST(0, extract(epoch FROM (
                 LEAST(COALESCE(r.ended_at, r.last_heartbeat_at), ${now}::timestamptz)
                 - GREATEST(r.started_at, ${since}::timestamptz))))) / 60)::bigint AS minutes
          FROM live_rooms r
          JOIN agency_hosts h ON h.host_user_id = r.host_user_id AND h.status = 'ACTIVE'::agency_host_status
         WHERE r.started_at < ${now}::timestamptz AND COALESCE(r.ended_at, r.last_heartbeat_at) > ${since}::timestamptz`,
      this.prisma.$queryRaw<{ id: string; active_hosts: bigint; last_live_at: Date | null }[]>`
        SELECT a.id::text AS id,
               (SELECT count(*) FROM agency_hosts h WHERE h.agency_id = a.id AND h.status = 'ACTIVE'::agency_host_status)
                 AS active_hosts,
               (SELECT max(r.started_at) FROM live_rooms r
                  JOIN agency_hosts h ON h.host_user_id = r.host_user_id
                 WHERE h.agency_id = a.id AND h.status = 'ACTIVE'::agency_host_status) AS last_live_at
          FROM agencies a
         WHERE a.status = 'OPEN'::agency_status AND a.suspended_at IS NULL
           AND NOT EXISTS (SELECT 1 FROM live_rooms r
                             JOIN agency_hosts h ON h.host_user_id = r.host_user_id
                            WHERE h.agency_id = a.id AND h.status = 'ACTIVE'::agency_host_status
                              AND r.started_at >= ${idle}::timestamptz)
         ORDER BY last_live_at ASC NULLS FIRST, a.id
         LIMIT 20`,
      this.prisma.hostApplication.count({ where: { status: 'PENDING' } }),
      this.prisma.creatorApplication.count({ where: { status: 'PENDING' } }),
    ]);
    const agencies = await this.prisma.agency.findMany({
      where: { id: { in: inactive.map((a) => a.id) } },
      select: { id: true, name: true, inviteCode: true, owner: PERSON },
    });
    const byId = new Map(agencies.map((a) => [a.id, a]));
    return {
      newHosts7d,
      liveHours7d: Math.round(Number(hours[0]?.minutes ?? 0n) / 6) / 10,
      inactiveAgencies: inactive
        .filter((a) => byId.has(a.id))
        .map((a) => {
          const row = byId.get(a.id)!;
          return {
            id: a.id,
            name: row.name,
            inviteCode: row.inviteCode,
            owner: personDto(row.owner),
            activeHosts: Number(a.active_hosts),
            lastLiveAt: a.last_live_at?.toISOString() ?? null,
          };
        }),
      queue: { hostApplications, creatorApplications },
    };
  }

  /** `getAdminTrustSafetyHome`. */
  async trustSafety() {
    const now = this.clock.now();
    const since = new Date(now.getTime() - 7 * DAY_MS);
    const [openReports, avg, livesNow, shift] = await Promise.all([
      this.prisma.report.count({ where: { status: 'OPEN' } }),
      this.prisma.$queryRaw<{ minutes: number | null; n: bigint }[]>`
        SELECT round(avg(extract(epoch FROM (resolved_at - created_at)) / 60))::int AS minutes, count(*)::bigint AS n
          FROM reports
         WHERE resolved_at IS NOT NULL AND resolved_at >= ${since}::timestamptz`,
      this.livesNow(),
      this.schedule.shiftNow(),
    ]);
    return {
      openReports,
      avgResolveMinutes: avg[0]?.minutes ?? null,
      resolved7d: Number(avg[0]?.n ?? 0n),
      livesNow,
      shift,
    };
  }

  /** The top-supporter pool (SUPPORT level ≥ 10 or an active VIP), no panel staff, ACTIVE; `inactiveSince` filters. */
  private supporters(now: Date, inactiveSince: Date | null): Promise<SupporterRow[]> {
    const idle = inactiveSince
      ? Prisma.sql`AND (u.last_active_at IS NULL OR u.last_active_at < ${inactiveSince}::timestamptz)`
      : Prisma.empty;
    return this.prisma.$queryRaw<SupporterRow[]>`
      SELECT u.id::text AS id, p.username, p.display_name, p.avatar_url, s.current_level AS level,
             t.code AS tier_code, t.name_ar AS tier_name_ar, t.name_en AS tier_name_en, t.color AS tier_color,
             u.last_active_at
        FROM users u
        LEFT JOIN user_profiles p ON p.user_id = u.id
        LEFT JOIN user_level_states s ON s.user_id = u.id
             AND s.category_id = (SELECT c.id FROM level_categories c WHERE c.code = 'SUPPORT'::level_category_code)
        LEFT JOIN vip_memberships m ON m.user_id = u.id AND m.expires_at > ${now}::timestamptz
        LEFT JOIN vip_tiers t ON t.id = m.tier_id
       WHERE u.status = 'ACTIVE'::user_status
         AND (s.current_level >= ${VIP_CARE_MIN_LEVEL} OR m.user_id IS NOT NULL)
         AND NOT EXISTS (SELECT 1 FROM user_admin_permissions ap WHERE ap.user_id = u.id
                           AND ap.permission IN (${panelRolesSql}))
         ${idle}
       ORDER BY s.current_level DESC NULLS LAST, t.sort_order DESC NULLS LAST, u.id
       LIMIT 20`;
  }

  /** `getAdminVipCareHome`. */
  async vipCare(ctx: AdminContext) {
    const now = this.clock.now();
    const [top, stopped, pendingCompensations, shift] = await Promise.all([
      this.supporters(now, null),
      this.supporters(now, new Date(now.getTime() - VIP_CARE_INACTIVE_DAYS * DAY_MS)),
      this.compensations.pendingCount(ctx),
      this.schedule.shiftNow(),
    ]);
    return {
      topSupporters: top.map(supporterDto),
      stoppedActive: stopped.map(supporterDto),
      inactiveDays: VIP_CARE_INACTIVE_DAYS,
      pendingCompensations,
      shift,
    };
  }

  /** `getAdminCommunityHome`. */
  async community() {
    const now = this.clock.now();
    const [events, banners] = await Promise.all([
      this.events(now),
      this.prisma.homeBanner.findMany({
        where: { enabled: true, startsAt: { lte: now }, OR: [{ endsAt: null }, { endsAt: { gt: now } }] },
        select: { id: true, titleAr: true, titleEn: true, placement: true, endsAt: true },
        orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
        take: 50,
      }),
    ]);
    const running = events.filter((e) => e.running && e.startsAt !== null).slice(0, 10);
    const participation = await Promise.all(
      running.map(async (e) => {
        const from = new Date(e.startsAt!);
        const to = e.endsAt && new Date(e.endsAt) < now ? new Date(e.endsAt) : now;
        const rows =
          e.metric === 'EVENT_GIFTS'
            ? await this.prisma.$queryRaw<{ n: bigint }[]>`
                SELECT count(DISTINCT g.sender_id)::bigint AS n
                  FROM live_gifts g
                  JOIN event_gifts eg ON eg.gift_code = g.gift_code AND eg.event_id = ${e.id}::uuid
                 WHERE g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz`
            : await this.prisma.$queryRaw<{ n: bigint }[]>`
                SELECT count(*)::bigint AS n FROM (${scoresSql(e.metric, from, to)}) s WHERE s.score > 0`;
        return { eventId: e.id, titleAr: e.titleAr, titleEn: e.titleEn, entrants: Number(rows[0]?.n ?? 0n) };
      }),
    );
    return {
      upcomingEvents: events.map(({ metric: _metric, ...e }) => e),
      participation,
      bannersLive: banners.map((b) => ({
        id: b.id,
        titleAr: b.titleAr,
        titleEn: b.titleEn,
        placement: b.placement,
        endsAt: b.endsAt?.toISOString() ?? null,
      })),
    };
  }
}
