import { Inject, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma, type TaskDefinition } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { levelSql } from '../live/live-chat-badges.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import { creditTaskCherriesIn, taskRewardReference } from '../economy/cherry-ledger.js';
import { creditIn } from '../wallet/wallet-ledger.js';
import { giftArtUrl } from '../gifts/gift-art.js';
import { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
import { isAllDay } from './host-target-engine.js';
import { HostTargetsService, type HostDailyTargetDto } from './host-targets.service.js';
import {
  TARGET_METRICS,
  assignSmartTasks,
  catalogueTemplates,
  taskCatalogueStats,
  taskSeed,
  variantName,
  type TaskProfile,
  type TaskTemplate,
} from './task-catalogue.js';
import { addDays, dateValue, programWindowsIn, type ProgramWindow } from './programs-time.js';
import {
  GEN_WEEKLY_COUNT,
  assignGenerated,
  genEntryOf,
  isGenTemplateCode,
  type GenAudience,
} from './task-generator.js';
import {
  CHECK_IN_CYCLE_DAYS,
  D281_POOL_TASKS,
  DEFAULT_TASK_POOL_BANDS,
  NEW_HOST_DAYS,
  TASK_POOL_BANDS,
  WATCH_LIVE_MIN_MS,
  assignDailyTasks,
  audienceOffered,
  bandForLevel,
  cappedReward,
  cappedTaskReward,
  checkInCycleDay,
  checkInReward,
  HOST_GIFTS_TARGET_TASK,
  HOST_LUCKY_TARGET_TASK,
  isTaskMetric,
  monthlyCapCherries,
  seedOf,
  taskRoleOf,
  type TaskAudience,
  type TaskMetric,
  type TaskPoolBand,
} from './programs-rules.js';
import { isLimitedStaff, refuseLimitedStaff } from '../live/live-staff.js';
import { rankedUser, vipPrivacyOnIn } from '../vip/vip-privacy.js';

type Tx = Prisma.TransactionClient;
type Db = Pick<Tx, '$queryRaw'>;

/** v1.44-live (D199): the host's statistics periods (Riyadh calendar, like the tasks). */
export const HOST_STATS_PERIODS = ['DAY', 'WEEK', 'MONTH', 'ALL'] as const;
export type HostStatsPeriod = (typeof HOST_STATS_PERIODS)[number];

/** v1.44-live (D199) `HostTarget`: today's value against today's target (0: no target). */
export interface HostTargetDto {
  received: number;
  target: number;
  reached: boolean;
}

/** v1.44-live (D199) `HostSupporter`. */
export interface HostSupporterDto {
  user: ReturnType<typeof userSummary>;
  coins: number;
  /** D199b: the cherries the host got from their sends in the period (the ledger, net of reversals). */
  cherries: number;
  /** D199b: their `SUPPORT` level number; null while that category is unavailable. */
  supportLevel: number | null;
}

/** D199b `HostSupporterRank`: the caller's own place in a list (rank null: they sent nothing). */
export interface HostSupporterRankDto {
  rank: number | null;
  /** Cherries in the gifts (cherries) list, coins in the lucky list. */
  amount: number;
}

/** D199b: how many people a supporters list holds. */
export const HOST_SUPPORTERS_LIMIT = 20;

/** v1.44-live (D199) `LiveHostTargets`: the «تارجت» chip — public (today only). */
export interface LiveHostTargetsDto {
  day: string;
  timeZone: string;
  /** D199b: the end of the Riyadh day (the countdown). */
  endsAt: string;
  band: number;
  /**
   * v1.69-live (D277) «هدف الهدايا»: cherries received today from gifts outside the lucky category sent by
   * other ACTIVE people / the band's P_HOST_GIFTS target (cherries).
   */
  gifts: HostTargetDto;
  /** Deprecated (D277): the same as `gifts`, for apps before v1.69-live. */
  cherries: HostTargetDto;
  /**
   * D277 «هدف هدايا الحظ»: cherries the host got today from lucky gifts (their own sends to themself too)
   * / the band's HOST_LUCKY_COINS target (cherries since D277).
   */
  lucky: HostTargetDto;
  /** Today's top supporters by cherries from non-lucky gifts (D199b: up to 20). */
  topSupporters: HostSupporterDto[];
  /** D199b: today's lucky list by coins (up to 20). */
  luckySupporters: HostSupporterDto[];
  /** D199b: a signed-in caller's own place today (null for guests and the host). */
  me: { gifts: HostSupporterRankDto; cherries: HostSupporterRankDto; lucky: HostSupporterRankDto } | null;
  /**
   * v1.71-live (D281): the host's three smart targets of today (easy, medium, hard) with their progress and reward;
   * [] before the smart engine's first day (then `gifts` / `lucky` carry D277's two targets).
   */
  daily: HostDailyTargetDto[];
}

/** v1.44-live (D199) `HostGiftStats`: the host's own statistics of a period. */
export interface HostGiftStatsDto {
  period: HostStatsPeriod;
  timeZone: string;
  from: string | null;
  to: string;
  cherries: {
    received: number;
    gifts: number;
    givers: number;
    topSupporters: HostSupporterDto[];
    series: { start: string; cherries: number }[];
  };
  /** D277: `cherries` — what the host got from lucky gifts in the period, self-sends included. */
  lucky: {
    coins: number;
    cherries: number;
    gifts: number;
    givers: number;
    topSupporters: HostSupporterDto[];
  };
  /** DAY only: today's two targets. */
  targets: LiveHostTargetsDto | null;
}

/** A task the caller has now, with its target and reward (a pool task's from today's assignment). */
interface OfferedTask {
  def: TaskDefinition;
  target: number;
  /** v1.53-social (D184): task rewards are cherries. */
  rewardCherries: number;
  pooled: boolean;
  /**
   * v1.86-social (D281): a generated variant's gift or category, its window of the day (minutes; null = the whole
   * day) and its resolved names (null: the template's).
   */
  subject: string | null;
  window: { from: number; to: number } | null;
  nameAr: string | null;
  nameEn: string | null;
}

/** A pool task as offered without a variant (rows before D281, fixed tasks). */
const PLAIN = { subject: null, window: null, nameAr: null, nameEn: null } as const;

/** A claim as stored: what it paid and in which currency (claims before v1.53-social paid coins). */
interface StoredClaim {
  amount: number;
  currency: 'COINS' | 'CHERRIES';
}

// ---- Response shapes (openapi v1.44-social, D166) ---------------------------------------------

/** `ProgramTask`. */
export interface ProgramTaskDto {
  code: string;
  /** v1.50-social (D176): one of the caller's daily pool tasks of today. */
  pooled: boolean;
  period: 'DAILY' | 'WEEKLY';
  metric: TaskMetric;
  /** v1.94-social (D297): `CREATORS` — a creator-programme member's task «مهام صانع المحتوى». */
  audience: TaskAudience;
  name: string;
  /** v1.86-social (D281): the gift a chosen-gift task names (its picture and name), else null. */
  gift: { code: string; name: string; assetKey: string; imageUrl: string | null } | null;
  /** v1.86-social (D281): the task's hours of the day (`HH:MM`), null for the whole day / week. */
  window: { from: string; to: string } | null;
  target: number;
  progress: number;
  /** Deprecated since v1.53-social (D184): always 0 — the reward is `rewardCherries`. */
  rewardCoins: number;
  /** v1.53-social (D184): the cherries the task pays. */
  rewardCherries: number;
  completed: boolean;
  claimed: boolean;
  /** The coins the claim paid (a claim before v1.53-social; 0 for a cherry claim), null before it is claimed. */
  claimedCoins: number | null;
  /** v1.53-social (D184): the cherries the claim paid (after the daily cap; 0 for a coin claim), null before. */
  claimedCherries: number | null;
}

/** `CheckInDay`: one of the seven days of the sign-in strip (today first). */
export interface CheckInDayDto {
  date: string;
  /** Its place in the 7-day cycle (7 = the bonus day). */
  cycleDay: number;
  today: boolean;
  checkedIn: boolean;
  rewardCoins: number;
}

/** `MyTasks`. */
export interface MyTasksDto {
  day: string;
  timeZone: string;
  dayStartsAt: string;
  dayResetsAt: string;
  weekStartsAt: string;
  weekResetsAt: string;
  /** Since v1.53-social (D184): the check-in's daily coin cap. */
  dailyCapCoins: number;
  /** Coins today from the check-in (and from daily task claims made before v1.53-social). */
  dailyEarnedCoins: number;
  /** v1.53-social (D184): the daily tasks' cherry cap. */
  dailyCapCherries: number;
  /** v1.53-social (D184): cherries from daily tasks today. */
  dailyEarnedCherries: number;
  /** v1.57-social (D188): the monthly cherry cap of daily and weekly tasks together (0 = none). */
  monthlyCapCherries: number;
  /** v1.57-social (D188): cherries from tasks (daily and weekly) paid this calendar month. */
  monthlyEarnedCherries: number;
  /** v1.50-social (D176): the level band today's pool tasks were chosen for. */
  /**
   * `host`: host tasks are offered (the hosting permission, and — v1.94-social, D297 — not a creator-programme
   * member); `creator` (D297): creator tasks are offered (a creator-programme member).
   */
  band: { band: number; level: number; name: string; host: boolean; creator: boolean };
  checkIn: {
    checkedInToday: boolean;
    streak: number;
    cycleDays: number;
    rewardCoins: number;
    bonusCoins: number;
    days: CheckInDayDto[];
  };
  tasks: ProgramTaskDto[];
}

/** `TaskClaimResult`. */
export interface TaskClaimResultDto {
  task: ProgramTaskDto;
  /** 0 for a cherry claim (a claim before v1.53-social: its coins). */
  paidCoins: number;
  balanceCoins: number;
  /** v1.53-social (D184). */
  paidCherries: number;
  balanceCherries: number;
}

/** `CheckInResult`. */
export interface CheckInResultDto {
  paidCoins: number;
  balanceCoins: number;
  tasks: MyTasksDto;
}

/**
 * v1.69-live (D277, CONVENTIONS §10.62.1): the cherries `me` received for gifts sent in [from, to) — the
 * cherry ledger's rows of those sends (`GIFT_RECEIVED` net of `GIFT_REVERSAL`, column `n`), from ACTIVE
 * senders. `lucky` false: «هدف الهدايا» — every gift OUTSIDE the lucky category (a send without a stored
 * lucky draw), from other people only; `lucky` true: «هدف هدايا الحظ» — lucky gifts only, the host's own
 * sends to themself included (D128 lets a host gift themself; the ledger credits them like any recipient).
 */
function hostCherriesSql(me: string, from: Date | null, to: Date, lucky: boolean): Prisma.Sql {
  return Prisma.sql`
    SELECT COALESCE(sum(l.delta), 0)::bigint AS n
      FROM live_gift_recipients gr
      JOIN live_gifts g ON g.id = gr.gift_id
      JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
      JOIN cherry_ledger l ON l.user_id = gr.user_id AND l.reference_id = g.id::text
                          AND l.reason IN ('GIFT_RECEIVED', 'GIFT_REVERSAL')
     WHERE gr.user_id = ${me}::uuid
       AND (${lucky} OR g.sender_id <> ${me}::uuid)
       AND ${lucky} = EXISTS (SELECT 1 FROM lucky_gift_draws d WHERE d.gift_id = g.id)
       AND (${from}::timestamptz IS NULL OR g.created_at >= ${from}::timestamptz)
       AND g.created_at < ${to}::timestamptz`;
}

/**
 * The query counting `metric` for `me` in `w` (column `n`). Counterparts (hosts, people followed, gift
 * recipients and senders) must be ACTIVE; nothing is counted from the caller's own lives or gifts.
 */
function progressSql(
  me: string,
  metric: TaskMetric,
  w: ProgramWindow,
  now: Date,
  subject: string | null = null,
  zone = 'UTC',
): Prisma.Sql {
  const from = w.start;
  const to = w.end;
  switch (metric) {
    case 'GIFT_COUNT_SENT':
    case 'CATEGORY_GIFTS_SENT':
      // v1.86-social (D281): how many of one gift (or of one category's gifts) the caller sent in the period, paid
      // with coins, to other ACTIVE people (the send's quantity).
      return Prisma.sql`
        SELECT COALESCE(sum(g.quantity), 0)::bigint AS n
          FROM live_gifts g
          JOIN gifts gf ON gf.code = g.gift_code
         WHERE g.sender_id = ${me}::uuid AND g.coins_charged > 0
           AND ${metric === 'GIFT_COUNT_SENT' ? Prisma.sql`g.gift_code = ${subject}` : Prisma.sql`gf.category = ${subject}`}
           AND g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz
           AND EXISTS (SELECT 1 FROM live_gift_recipients gr JOIN users u ON u.id = gr.user_id
                        WHERE gr.gift_id = g.id AND gr.user_id <> ${me}::uuid AND u.status = 'ACTIVE')`;
    case 'GIFTED_HOSTS':
      // D281: different ACTIVE people the caller sent a paid gift to in the period.
      return Prisma.sql`
        SELECT count(DISTINCT gr.user_id) AS n
          FROM live_gifts g
          JOIN live_gift_recipients gr ON gr.gift_id = g.id AND gr.user_id <> ${me}::uuid
          JOIN users u ON u.id = gr.user_id AND u.status = 'ACTIVE'
         WHERE g.sender_id = ${me}::uuid AND g.coins_charged > 0
           AND g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz`;
    case 'FAMILY_JOIN':
      // D281: the caller joined (or founded) a family in the period and is still in it.
      return Prisma.sql`
        SELECT count(*) AS n FROM family_members m
         WHERE m.user_id = ${me}::uuid
           AND m.joined_at >= ${from}::timestamptz AND m.joined_at < ${to}::timestamptz`;
    case 'FAMILY_CHAT_MESSAGES':
      return Prisma.sql`
        SELECT count(*) AS n FROM family_chat_messages m
         WHERE m.author_id = ${me}::uuid AND m.deleted_at IS NULL
           AND m.created_at >= ${from}::timestamptz AND m.created_at < ${to}::timestamptz`;
    // ---- v1.94-social (D297, CONVENTIONS §10.110): what OTHER ACTIVE people did with the caller's content -------
    case 'REEL_VIEWS_RECEIVED':
      // §11.4 views of the caller's reels (published, not removed or deleted) by other ACTIVE people whose counted view
      // falls in the period: one per viewer and reel (`post_views` keeps the last counted view; a new one counts after
      // 24 h and moves it).
      return Prisma.sql`
        SELECT count(*) AS n
          FROM post_views v
          JOIN posts p ON p.id = v.post_id AND p.author_id = ${me}::uuid AND p.format = 'REEL'::post_format
                      AND p.status = 'PUBLISHED' AND p.moderation <> 'REMOVED' AND p.deleted_at IS NULL
          JOIN users u ON u.id = v.user_id AND u.status = 'ACTIVE'
         WHERE v.user_id <> ${me}::uuid
           AND v.viewed_at >= ${from}::timestamptz AND v.viewed_at < ${to}::timestamptz`;
    case 'LIKES_RECEIVED':
      // Likes on the caller's posts and reels (published, not removed or deleted) made in the period by other ACTIVE
      // people that still stand (an unlike deletes the row).
      return Prisma.sql`
        SELECT count(*) AS n
          FROM post_likes l
          JOIN posts p ON p.id = l.post_id AND p.author_id = ${me}::uuid
                      AND p.status = 'PUBLISHED' AND p.moderation <> 'REMOVED' AND p.deleted_at IS NULL
          JOIN users u ON u.id = l.user_id AND u.status = 'ACTIVE'
         WHERE l.user_id <> ${me}::uuid
           AND l.created_at >= ${from}::timestamptz AND l.created_at < ${to}::timestamptz`;
    case 'COMMENT_REPLIES':
      // Different comments of other ACTIVE people (not deleted) on the caller's own posts that the caller replied to in
      // the period (the reply not deleted): ten replies under one comment count once.
      return Prisma.sql`
        SELECT count(DISTINCT c.parent_id) AS n
          FROM comments c
          JOIN comments pc ON pc.id = c.parent_id AND pc.author_id <> ${me}::uuid AND pc.deleted_at IS NULL
          JOIN users u ON u.id = pc.author_id AND u.status = 'ACTIVE'
          JOIN posts p ON p.id = c.post_id AND p.author_id = ${me}::uuid AND p.deleted_at IS NULL
         WHERE c.author_id = ${me}::uuid AND c.deleted_at IS NULL
           AND c.created_at >= ${from}::timestamptz AND c.created_at < ${to}::timestamptz`;
    case 'NEW_FOLLOWERS':
      // ACTIVE people who started following the caller in the period and still do (an unfollow deletes the row, so a
      // follower who left does not count; one who comes back counts once, from the new follow).
      return Prisma.sql`
        SELECT count(*) AS n
          FROM follows f
          JOIN users u ON u.id = f.follower_id AND u.status = 'ACTIVE'
         WHERE f.followee_id = ${me}::uuid AND f.follower_id <> ${me}::uuid
           AND f.created_at >= ${from}::timestamptz AND f.created_at < ${to}::timestamptz`;
    case 'SHARES_RECEIVED':
      // Shares of the caller's posts and reels (published, not removed or deleted) by other ACTIVE people: outside
      // shares (`post_share_events`, at most one per person, post and UTC day — counted for the UTC days from the one
      // the period starts in up to the one it ends in, each day in one period only) and reposts made in the period
      // that still stand.
      return Prisma.sql`
        SELECT (
          (SELECT count(*) FROM post_share_events e
             JOIN posts p ON p.id = e.post_id AND p.author_id = ${me}::uuid
                         AND p.status = 'PUBLISHED' AND p.moderation <> 'REMOVED' AND p.deleted_at IS NULL
             JOIN users u ON u.id = e.user_id AND u.status = 'ACTIVE'
            WHERE e.user_id <> ${me}::uuid
              AND e.day >= (${from}::timestamptz AT TIME ZONE 'UTC')::date
              AND e.day < (${to}::timestamptz AT TIME ZONE 'UTC')::date)
          + (SELECT count(*) FROM post_reposts r
             JOIN posts p ON p.id = r.post_id AND p.author_id = ${me}::uuid
                         AND p.status = 'PUBLISHED' AND p.moderation <> 'REMOVED' AND p.deleted_at IS NULL
             JOIN users u ON u.id = r.user_id AND u.status = 'ACTIVE'
            WHERE r.user_id <> ${me}::uuid
              AND r.created_at >= ${from}::timestamptz AND r.created_at < ${to}::timestamptz))::bigint AS n`;
    case 'HOST_LIVE_DAYS':
      // D297 follow-up: different days (the programs' clock) of the period on which the caller started a live that lasted
      // at least 10 minutes (a live in progress up to its last heartbeat).
      return Prisma.sql`
        SELECT count(DISTINCT (r.started_at AT TIME ZONE ${zone})::date) AS n
          FROM live_rooms r
         WHERE r.host_user_id = ${me}::uuid
           AND r.started_at >= ${from}::timestamptz AND r.started_at < ${to}::timestamptz
           AND COALESCE(r.ended_at, r.last_heartbeat_at) - r.started_at >= interval '10 minutes'`;
    case 'PK_BATTLES':
    case 'PK_WINS':
      // D281: PK battles the caller (a host) started in the period — started, never the void ones (cancelled or
      // ended by a moderator) — and of those, the ones they won.
      return Prisma.sql`
        SELECT count(*) AS n FROM pk_matches p
         WHERE (p.host_a_id = ${me}::uuid OR p.host_b_id = ${me}::uuid)
           AND p.status <> 'CONNECTED'
           AND (p.end_reason IS NULL OR p.end_reason NOT IN ('CANCELLED', 'ADMIN'))
           AND p.started_at >= ${from}::timestamptz AND p.started_at < ${to}::timestamptz
           AND (${metric === 'PK_BATTLES'}
                OR (p.winner = 'A' AND p.host_a_id = ${me}::uuid) OR (p.winner = 'B' AND p.host_b_id = ${me}::uuid))`;
    case 'WATCH_LIVES':
      // Lives of someone else first joined in the period and watched ≥ 15 s in total.
      return Prisma.sql`
        SELECT count(*) AS n
          FROM live_room_audience a
          JOIN live_rooms r ON r.id = a.room_id AND r.host_user_id <> ${me}::uuid
          JOIN users h ON h.id = r.host_user_id AND h.status = 'ACTIVE'
         WHERE a.user_id = ${me}::uuid
           AND a.first_joined_at >= ${from}::timestamptz AND a.first_joined_at < ${to}::timestamptz
           AND a.watch_ms + COALESCE(GREATEST(0, floor(extract(epoch FROM (${now}::timestamptz - a.open_since)) * 1000)), 0)
               >= ${WATCH_LIVE_MIN_MS}`;
    case 'FOLLOWS':
      // Follows made in the period that still stand (an unfollow deletes the row), of ACTIVE people.
      return Prisma.sql`
        SELECT count(*) AS n
          FROM follows f
          JOIN users u ON u.id = f.followee_id AND u.status = 'ACTIVE'
         WHERE f.follower_id = ${me}::uuid
           AND f.created_at >= ${from}::timestamptz AND f.created_at < ${to}::timestamptz`;
    case 'LIVE_CHAT_MESSAGES':
      // Messages in someone else's live, not deleted.
      return Prisma.sql`
        SELECT count(*) AS n
          FROM live_chat_messages m
          JOIN live_rooms r ON r.id = m.room_id AND r.host_user_id <> ${me}::uuid
         WHERE m.user_id = ${me}::uuid AND m.deleted_at IS NULL
           AND m.created_at >= ${from}::timestamptz AND m.created_at < ${to}::timestamptz`;
    case 'GIFT_SENDS':
      // Gift sends paid with coins to someone ACTIVE (a live or a direct conversation; free quips and
      // gifts from the bag do not count).
      return Prisma.sql`
        SELECT count(*) AS n
          FROM live_gifts g
         WHERE g.sender_id = ${me}::uuid AND g.coins_charged > 0
           AND g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz
           AND EXISTS (SELECT 1 FROM live_gift_recipients gr JOIN users u ON u.id = gr.user_id
                        WHERE gr.gift_id = g.id AND gr.user_id <> ${me}::uuid AND u.status = 'ACTIVE')`;
    case 'HOST_LIVE_MINUTES':
      // Minutes of the caller's lives inside the period (a live in progress up to its last heartbeat).
      return Prisma.sql`
        SELECT COALESCE(floor(sum(GREATEST(0, extract(epoch FROM (
                 LEAST(COALESCE(r.ended_at, r.last_heartbeat_at), ${to}::timestamptz)
                 - GREATEST(r.started_at, ${from}::timestamptz))))) / 60), 0)::bigint AS n
          FROM live_rooms r
         WHERE r.host_user_id = ${me}::uuid
           AND r.started_at < ${to}::timestamptz
           AND COALESCE(r.ended_at, r.last_heartbeat_at) > ${from}::timestamptz`;
    case 'WATCH_MINUTES':
      // Whole minutes watched in lives of someone else first joined in the period.
      return Prisma.sql`
        SELECT COALESCE(floor(sum(a.watch_ms + COALESCE(GREATEST(0, floor(extract(epoch FROM
                 (${now}::timestamptz - a.open_since)) * 1000)), 0)) / 60000), 0)::bigint AS n
          FROM live_room_audience a
          JOIN live_rooms r ON r.id = a.room_id AND r.host_user_id <> ${me}::uuid
          JOIN users h ON h.id = r.host_user_id AND h.status = 'ACTIVE'
         WHERE a.user_id = ${me}::uuid
           AND a.first_joined_at >= ${from}::timestamptz AND a.first_joined_at < ${to}::timestamptz`;
    case 'AUDIO_ROOMS':
      // Audio rooms of someone else first joined in the period and stayed in ≥ 15 s.
      return Prisma.sql`
        SELECT count(*) AS n
          FROM live_room_audience a
          JOIN live_rooms r ON r.id = a.room_id AND r.host_user_id <> ${me}::uuid AND r.mode = 'AUDIO'
          JOIN users h ON h.id = r.host_user_id AND h.status = 'ACTIVE'
         WHERE a.user_id = ${me}::uuid
           AND a.first_joined_at >= ${from}::timestamptz AND a.first_joined_at < ${to}::timestamptz
           AND a.watch_ms + COALESCE(GREATEST(0, floor(extract(epoch FROM (${now}::timestamptz - a.open_since)) * 1000)), 0)
               >= ${WATCH_LIVE_MIN_MS}`;
    case 'LIVE_TAPS':
      // Taps (hearts) the server counted in lives of someone else started in the period (the per-live
      // count of live_room_tappers, as the event boards read it).
      return Prisma.sql`
        SELECT COALESCE(sum(t.counted), 0)::bigint AS n
          FROM live_room_tappers t
          JOIN live_rooms r ON r.id = t.room_id AND r.host_user_id <> ${me}::uuid
          JOIN users h ON h.id = r.host_user_id AND h.status = 'ACTIVE'
         WHERE t.user_id = ${me}::uuid
           AND r.started_at >= ${from}::timestamptz AND r.started_at < ${to}::timestamptz`;
    case 'NEW_HOST_GIFTS':
      // Gift sends paid with coins to an ACTIVE host whose hosting permission is at most 30 days old.
      return Prisma.sql`
        SELECT count(*) AS n
          FROM live_gifts g
         WHERE g.sender_id = ${me}::uuid AND g.coins_charged > 0
           AND g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz
           AND EXISTS (SELECT 1 FROM live_gift_recipients gr
                         JOIN users u ON u.id = gr.user_id AND u.status = 'ACTIVE'
                         JOIN live_hosts lh ON lh.user_id = gr.user_id
                              AND lh.source <> 'CREATOR'::live_host_source
                        WHERE gr.gift_id = g.id AND gr.user_id <> ${me}::uuid
                          -- D295 (owner, int16): a gift to a content creator is not a gift to a new host.
                          AND NOT EXISTS (SELECT 1 FROM creator_members cm WHERE cm.user_id = gr.user_id)
                          AND lh.granted_at > g.created_at - make_interval(days => ${NEW_HOST_DAYS}))`;
    case 'POSTS':
    case 'REELS':
      // Published posts (or reels) made in the period, not deleted and not removed.
      return Prisma.sql`
        SELECT count(*) AS n
          FROM posts p
         WHERE p.author_id = ${me}::uuid AND p.format = ${metric === 'REELS' ? 'REEL' : 'POST'}::post_format
           AND p.status = 'PUBLISHED' AND p.moderation <> 'REMOVED' AND p.deleted_at IS NULL
           AND p.created_at >= ${from}::timestamptz AND p.created_at < ${to}::timestamptz`;
    case 'STORIES':
      return Prisma.sql`
        SELECT count(*) AS n
          FROM stories s
         WHERE s.author_id = ${me}::uuid AND s.deleted_at IS NULL AND s.removed_at IS NULL
           AND s.created_at >= ${from}::timestamptz AND s.created_at < ${to}::timestamptz`;
    case 'POST_COMMENTS':
      // Comments (not deleted) on posts of someone ACTIVE.
      return Prisma.sql`
        SELECT count(*) AS n
          FROM comments c
          JOIN posts p ON p.id = c.post_id AND p.author_id <> ${me}::uuid AND p.deleted_at IS NULL
          JOIN users u ON u.id = p.author_id AND u.status = 'ACTIVE'
         WHERE c.author_id = ${me}::uuid AND c.deleted_at IS NULL
           AND c.created_at >= ${from}::timestamptz AND c.created_at < ${to}::timestamptz`;
    case 'DM_FRIENDS':
      // Different friends (both follow each other, ACTIVE) messaged in the period. A message lives
      // 24 hours, so every message of the current day is still stored.
      return Prisma.sql`
        SELECT count(DISTINCT m.recipient_id) AS n
          FROM dm_messages m
          JOIN users u ON u.id = m.recipient_id AND u.status = 'ACTIVE'
         WHERE m.sender_id = ${me}::uuid AND m.recipient_id <> ${me}::uuid
           AND m.created_at >= ${from}::timestamptz AND m.created_at < ${to}::timestamptz
           AND EXISTS (SELECT 1 FROM follows f WHERE f.follower_id = ${me}::uuid AND f.followee_id = m.recipient_id)
           AND EXISTS (SELECT 1 FROM follows f WHERE f.follower_id = m.recipient_id AND f.followee_id = ${me}::uuid)`;
    case 'DM_VOICE_MESSAGES':
      return Prisma.sql`
        SELECT count(*) AS n
          FROM dm_messages m
          JOIN users u ON u.id = m.recipient_id AND u.status = 'ACTIVE'
         WHERE m.sender_id = ${me}::uuid AND m.recipient_id <> ${me}::uuid AND m.kind = 'VOICE'
           AND m.created_at >= ${from}::timestamptz AND m.created_at < ${to}::timestamptz`;
    case 'HOST_GIFTS_RECEIVED':
      // Gift sends the caller received in the period from other ACTIVE people.
      return Prisma.sql`
        SELECT count(DISTINCT g.id) AS n
          FROM live_gift_recipients gr
          JOIN live_gifts g ON g.id = gr.gift_id
          JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
         WHERE gr.user_id = ${me}::uuid AND g.sender_id <> ${me}::uuid
           AND g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz`;
    case 'HOST_GUESTS':
      // Guests seated in the caller's lives in the period (a seat request or invitation ACCEPTED).
      return Prisma.sql`
        SELECT count(*) AS n FROM (
          SELECT q.room_id, q.user_id FROM live_seat_requests q
            JOIN live_rooms r ON r.id = q.room_id AND r.host_user_id = ${me}::uuid
            JOIN users u ON u.id = q.user_id AND u.status = 'ACTIVE'
           WHERE q.status = 'ACCEPTED' AND q.user_id <> ${me}::uuid
             AND q.handled_at >= ${from}::timestamptz AND q.handled_at < ${to}::timestamptz
          UNION
          SELECT i.room_id, i.user_id FROM live_seat_invites i
            JOIN live_rooms r ON r.id = i.room_id AND r.host_user_id = ${me}::uuid
            JOIN users u ON u.id = i.user_id AND u.status = 'ACTIVE'
           WHERE i.status = 'ACCEPTED' AND i.user_id <> ${me}::uuid
             AND i.handled_at >= ${from}::timestamptz AND i.handled_at < ${to}::timestamptz) seated`;
    case 'GIFT_COINS_SENT':
      // v1.57-social (D188): the coin value of the gifts the caller sent in the period, paid with coins
      // (live or direct conversation; free quips and bag gifts do not count), to other ACTIVE people —
      // each recipient's stored share of the send (live_gift_recipients.coins).
      return Prisma.sql`
        SELECT COALESCE(sum(gr.coins), 0)::bigint AS n
          FROM live_gifts g
          JOIN live_gift_recipients gr ON gr.gift_id = g.id AND gr.user_id <> ${me}::uuid
          JOIN users u ON u.id = gr.user_id AND u.status = 'ACTIVE'
         WHERE g.sender_id = ${me}::uuid AND g.coins_charged > 0
           AND g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz`;
    case 'HOST_LUCKY_COINS':
      // v1.44-live (D199): the coin value of the LUCKY gifts the caller received in the period (sends with
      // a stored lucky draw) from ACTIVE senders.
      return Prisma.sql`
        SELECT COALESCE(sum(gr.coins), 0)::bigint AS n
          FROM live_gift_recipients gr
          JOIN live_gifts g ON g.id = gr.gift_id
          JOIN lucky_gift_draws d ON d.gift_id = g.id
          JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
         WHERE gr.user_id = ${me}::uuid AND g.sender_id <> ${me}::uuid
           AND g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz`;
    case 'HOST_GIFT_CHERRIES':
      return hostCherriesSql(me, from, to, false);
    case 'HOST_LUCKY_CHERRIES':
      return hostCherriesSql(me, from, to, true);
    case 'HOST_GIFT_COINS':
      // The coin value of the gifts the caller received in the period from ACTIVE senders.
      return Prisma.sql`
        SELECT COALESCE(sum(gr.coins), 0)::bigint AS n
          FROM live_gift_recipients gr
          JOIN live_gifts g ON g.id = gr.gift_id
          JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
         WHERE gr.user_id = ${me}::uuid AND g.sender_id <> ${me}::uuid
           AND g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz`;
  }
}

/**
 * The Task Center «مركز المهام» (v1.44-social, D166, CP-024 §1 approved with defaults, CONVENTIONS
 * §10.41). Tasks come from `task_definitions`; progress is computed per read from what the server
 * already stores (watch time, follows, live chat, gift sends, lives, gifts received) — nothing the app
 * reports. Days and ISO weeks follow `LIVE_RANKINGS_TIME_ZONE`. A reward is paid once per person, task
 * and period (`task_claims_once`) in the claim's transaction. v1.53-social (D184, §10.41.3): task rewards
 * are cherries — a `cherry_ledger` row `TASK_REWARD` (reference `<code>@<period start>`), daily tasks under
 * `TASK_DAILY_CAP_CHERRIES`; the check-in keeps paying coins (`wallet_ledger` `CHECK_IN_REWARD`) under
 * `TASK_DAILY_CAP_COINS`. Claims and check-ins of one person are serialized by a lock on their `users`
 * row, so the caps hold under concurrent requests.
 */
@Injectable()
export class TasksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly targets: HostTargetsService,
    private readonly storage: StorageSettingsStore,
  ) {}

  private get zone(): string {
    return this.config.live.rankingsTimeZone;
  }

  /** The progress of `metric` for `me` in `w` (stored data only; counterparts must be ACTIVE). */
  private async progressOf(
    db: Db,
    me: string,
    metric: TaskMetric,
    w: ProgramWindow,
    now: Date,
    subject: string | null = null,
  ): Promise<number> {
    const rows = await db.$queryRaw<{ n: bigint | number | null }[]>(
      progressSql(me, metric, w, now, subject, this.zone),
    );
    return Number(rows[0]?.n ?? 0);
  }

  /** v1.86-social (D281): a task's period narrowed to its window of the day (the whole period without one). */
  private narrowed(w: ProgramWindow, window: OfferedTask['window']): ProgramWindow {
    if (window === null) return w;
    return {
      date: w.date,
      start: new Date(w.start.getTime() + window.from * 60_000),
      end: new Date(Math.min(w.end.getTime(), w.start.getTime() + window.to * 60_000)),
    };
  }

  /**
   * v1.94-social (D297, CONVENTIONS §10.110): the caller's role for the tasks — a creator-programme member
   * (`creator_members`) gets CREATORS tasks and never HOSTS tasks (D295 gives members a hosting permission); otherwise a
   * hosting-permission holder gets HOSTS tasks.
   */
  private async roleOf(db: Db, me: string): Promise<{ host: boolean; creator: boolean }> {
    const [row] = await db.$queryRaw<{ host: boolean; creator: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM live_hosts WHERE user_id = ${me}::uuid) AS host,
             EXISTS (SELECT 1 FROM creator_members WHERE user_id = ${me}::uuid) AS creator`;
    return taskRoleOf(row?.host ?? false, row?.creator ?? false);
  }

  /**
   * The tasks the caller may see: enabled, known metric, HOSTS tasks only for hosts and (v1.94-social, D297) CREATORS
   * tasks only for creator-programme members (who never get HOSTS tasks).
   */
  private async definitionsFor(db: Tx | PrismaService, me: string): Promise<TaskDefinition[]> {
    const defs = await db.taskDefinition.findMany({
      where: { enabled: true },
      orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
    });
    const role = defs.some((d) => d.audience !== 'EVERYONE')
      ? await this.roleOf(db, me)
      : { host: false, creator: false };
    return defs.filter((d) => isTaskMetric(d.metric) && audienceOffered(d.audience, role));
  }

  /** The caller's level for the pool: the higher of their Support and Charm levels (0 = none). */
  private async levelOf(db: Db, me: string): Promise<number> {
    const [row] = await db.$queryRaw<{ level: number | null }[]>`
      SELECT max(s.current_level) AS level
        FROM user_level_states s
        JOIN level_categories c ON c.id = s.category_id AND c.is_enabled
                               AND c.code IN ('SUPPORT', 'ATTRACTIVENESS')
       WHERE s.user_id = ${me}::uuid`;
    return row?.level ?? 0;
  }

  /**
   * D297 (owner: «مستوى الشخص للجاذبية»): the caller's CHARM level (`ATTRACTIVENESS`, enabled category) — the only level
   * the generated tasks read; none = 0.
   */
  private async charmLevelOf(db: Db, me: string): Promise<number> {
    const [row] = await db.$queryRaw<{ level: number | null }[]>`
      SELECT s.current_level AS level
        FROM user_level_states s
        JOIN level_categories c ON c.id = s.category_id AND c.is_enabled AND c.code = 'ATTRACTIVENESS'
       WHERE s.user_id = ${me}::uuid`;
    return row?.level ?? 0;
  }

  /** The level bands (the defaults when the table is empty). */
  private async bands(db: Tx | PrismaService): Promise<TaskPoolBand[]> {
    const rows = await db.taskPoolBand.findMany({ orderBy: { band: 'asc' } });
    return rows.length === 0 ? [...DEFAULT_TASK_POOL_BANDS] : rows;
  }

  /**
   * The caller's pool tasks of `day` (v1.50-social, D176): fixed by the day's first read —
   * deterministic from the person and the day (`seedOf`), for their level band, hosts getting host
   * tasks — with each band's target and reward at that moment, so the day's list never changes
   * (a template switched off later is hidden). Concurrent first reads pick the same tasks.
   */
  private async assignmentsFor(
    db: Tx | PrismaService,
    me: string,
    day: string,
  ): Promise<{
    rows: {
      taskCode: string;
      target: number;
      rewardCherries: number;
      position: number;
      band: number;
      subject: string | null;
      windowFrom: number | null;
      windowTo: number | null;
      nameAr: string | null;
      nameEn: string | null;
    }[];
  }> {
    // D297: a week's generated tasks are stored on the week's first day; they are not the day's (see weeklyGenerated).
    const where = {
      userId: me,
      day: dateValue(day),
      NOT: { taskCode: { startsWith: 'G_', endsWith: '_W' } },
    };
    const select = {
      taskCode: true,
      target: true,
      rewardCherries: true,
      position: true,
      band: true,
      subject: true,
      windowFrom: true,
      windowTo: true,
      nameAr: true,
      nameEn: true,
    } as const;
    let rows = await db.taskAssignment.findMany({ where, select, orderBy: { position: 'asc' } });
    if (rows.length > 0) return { rows };
    // D297 (§10.110.1): with the generator on for the caller's audience, their creator / host share of the day (the
    // band's creator / host count) comes from the generated catalogue; the pool fills the rest with everyone's tasks.
    const role = await this.roleOf(db, me);
    const genDaily = (await this.genTemplates(db, role))
      .filter((d) => d.period === 'DAILY')
      .map((d) => d.code);
    const band = bandForLevel(await this.levelOf(db, me), await this.bands(db));
    const reserve =
      genDaily.length === 0
        ? 0
        : Math.min(band.dailyCount, role.creator ? band.creatorCount : band.hostCount);
    const poolRole = reserve > 0 ? { host: false, creator: false } : role;
    const poolBand = { ...band, dailyCount: band.dailyCount - reserve };
    // D297 (§10.110.1, «creator tasks first»): the generator's share is taken after the pool, so the pool must not hold
    // an everyone task whose metric a generated daily template counts — else the generator drops that template (one
    // post never completes two tasks) and the creator / host share of the day comes up short.
    const genMetrics = new Set<string>(
      reserve > 0 ? genDaily.map((c) => genEntryOf(c)?.metric).filter((m) => m !== undefined) : [],
    );
    const poolOk = (t: { audience: string; metric: string }) =>
      t.audience !== 'EVERYONE' || !genMetrics.has(t.metric);
    // v1.86-social (D281): from the smart engine's first day, the generated catalogue and the smart assignment.
    if (await this.targets.engineOn(day, db)) {
      await this.smartAssign(db, me, day, reserve, poolOk);
    } else {
      const templates = await db.taskDefinition.findMany({ where: { enabled: true, pool: true } });
      // D281: its new templates need the smart engine (a gift, a category, a variant): never on the old path.
      const usable = templates.filter(
        (t) =>
          isTaskMetric(t.metric) && t.poolGroup !== null && !D281_POOL_TASKS.includes(t.code) && poolOk(t),
      );
      const picks =
        usable.length === 0 || poolBand.dailyCount <= 0
          ? []
          : assignDailyTasks(
              usable.map((t) => ({
                code: t.code,
                group: t.poolGroup!,
                audience: t.audience,
                metric: t.metric,
                bandTargets: t.bandTargets,
                bandRewards: t.bandRewards,
                sortOrder: t.sortOrder,
              })),
              poolBand,
              poolRole.host,
              seedOf(`${me}:${day}`),
              poolRole.creator,
            );
      await db.taskAssignment.createMany({
        data: picks.map((p) => ({
          userId: me,
          day: dateValue(day),
          taskCode: p.code,
          band: band.band,
          target: p.target,
          rewardCherries: p.rewardCherries,
          position: p.position,
        })),
        skipDuplicates: true,
      });
    }
    rows = await db.taskAssignment.findMany({ where, select, orderBy: { position: 'asc' } });
    if (reserve > 0) {
      await this.genAssign(db, me, day, 'DAILY', genDaily, reserve, rows, band.band);
      rows = await db.taskAssignment.findMany({ where, select, orderBy: { position: 'asc' } });
    }
    return { rows };
  }

  /** D297 (§10.110.1): the generator's enabled template rows for the caller's audience (none: off, or neither role). */
  private async genTemplates(
    db: Tx | PrismaService,
    role: { host: boolean; creator: boolean },
  ): Promise<TaskDefinition[]> {
    const audience: GenAudience | null = role.creator ? 'CREATORS' : role.host ? 'HOSTS' : null;
    if (audience === null) return [];
    const rows = await db.taskDefinition.findMany({
      where: { enabled: true, audience, code: { startsWith: 'G_' } },
      orderBy: { code: 'asc' },
    });
    return rows.filter((r) => isGenTemplateCode(r.code) && genEntryOf(r.code)?.audience === audience);
  }

  /**
   * D297 (§10.110.1): picks and stores the caller's generated tasks of a day or an ISO week (`key`: its first day) —
   * at their CHARM level now, never a metric another task of the day counts, and never the previous period's exact task
   * — with each reward within the caps (the claim applies them again).
   */
  private async genAssign(
    db: Tx | PrismaService,
    me: string,
    key: string,
    period: 'DAILY' | 'WEEKLY',
    templates: readonly string[],
    count: number,
    existing: readonly { taskCode: string }[],
    band: number,
  ): Promise<void> {
    const audience = genEntryOf(templates[0] ?? '')?.audience;
    if (audience === undefined || count <= 0) return;
    const charmLevel = await this.charmLevelOf(db, me);
    const previous = await db.taskAssignment.findMany({
      where: {
        userId: me,
        day: dateValue(addDays(key, period === 'DAILY' ? -1 : -7)),
        taskCode: { startsWith: 'G_', endsWith: period === 'DAILY' ? '_D' : '_W' },
      },
      select: { taskCode: true, variant: true },
    });
    const taken = existing.length
      ? await db.taskDefinition.findMany({
          where: { code: { in: existing.map((r) => r.taskCode) } },
          select: { metric: true },
        })
      : [];
    const picks = assignGenerated({
      audience,
      period,
      templates,
      userId: me,
      periodKey: key,
      charmLevel,
      count,
      avoidMetrics: new Set(taken.map((t) => t.metric)),
      previousCodes: new Set(previous.map((r) => r.variant).filter((v): v is string => v !== null)),
      previousMetrics: new Set(
        previous.map((r) => genEntryOf(r.taskCode)?.metric).filter((m) => m !== undefined),
      ),
      caps: { dailyCherries: this.config.programs.taskDailyCapCherries, monthlyCherries: this.monthlyCap },
    });
    await db.taskAssignment.createMany({
      data: picks.map((p, i) => ({
        userId: me,
        day: dateValue(key),
        taskCode: p.template,
        band,
        target: p.target,
        rewardCherries: p.rewardCherries,
        position: Math.min(11, existing.length + i),
        variant: p.code,
        nameAr: p.nameAr,
        nameEn: p.nameEn,
        reason: { generated: true, charmLevel: p.level, step: p.step, variant: p.variant },
      })),
      skipDuplicates: true,
    });
  }

  /** D297: the caller's generated tasks of the ISO week starting `week` (assigned at the week's first read). */
  private async weeklyGenerated(
    db: Tx | PrismaService,
    me: string,
    week: string,
    templates: readonly string[],
    band: number,
  ) {
    const where = { userId: me, day: dateValue(week), taskCode: { in: [...templates] } };
    const select = {
      taskCode: true,
      target: true,
      rewardCherries: true,
      nameAr: true,
      nameEn: true,
    } as const;
    let rows = await db.taskAssignment.findMany({ where, select, orderBy: { position: 'asc' } });
    if (rows.length === 0 && templates.length > 0) {
      const audience = genEntryOf(templates[0]!)!.audience;
      await this.genAssign(db, me, week, 'WEEKLY', templates, GEN_WEEKLY_COUNT[audience], [], band);
      rows = await db.taskAssignment.findMany({ where, select, orderBy: { position: 'asc' } });
    }
    return rows;
  }

  /**
   * The tasks the caller has now: today's pool tasks (assigned, in their order), then the fixed
   * tasks (not pool), each with its target and reward (a pool task's from its assignment). v1.57-social
   * (D188 follow-up): a fixed task with one value per band (the weekly host tasks) takes the caller's
   * band of the day — today's assignment's, else the band of their level now; 0 = not offered.
   * D297 (§10.110.1): with the generator on for the caller's audience, the generated tasks of the day (among the pool
   * tasks) and of the week (instead of the audience's fixed weekly tasks).
   */
  private async tasksFor(
    db: Tx | PrismaService,
    me: string,
    day: string,
    week: string | null = null,
  ): Promise<OfferedTask[]> {
    // v1.72-live (D283, §10.96.10): a Kabso Team account has no tasks or targets (none listed, none claimable).
    if (await isLimitedStaff(db, me)) return [];
    const defs = await this.definitionsFor(db, me);
    const byCode = new Map(defs.map((d) => [d.code, d]));
    const { rows } = await this.assignmentsFor(db, me, day);
    const generated = (r: {
      target: number;
      rewardCherries: number;
      nameAr: string | null;
      nameEn: string | null;
    }) => ({
      target: r.target,
      rewardCherries: r.rewardCherries,
      subject: null,
      window: null,
      nameAr: r.nameAr,
      nameEn: r.nameEn,
    });
    const pooled: OfferedTask[] = [];
    for (const r of rows) {
      const def = byCode.get(r.taskCode);
      if (def?.pool) {
        pooled.push({
          def,
          target: r.target,
          rewardCherries: r.rewardCherries,
          pooled: true,
          subject: r.subject,
          window:
            r.windowFrom !== null && r.windowTo !== null ? { from: r.windowFrom, to: r.windowTo } : null,
          nameAr: r.nameAr,
          nameEn: r.nameEn,
        });
      } else if (def && isGenTemplateCode(def.code) && def.period === 'DAILY') {
        pooled.push({ def, pooled: true, ...generated(r) });
      }
    }
    const banded = (d: TaskDefinition) =>
      d.bandTargets.length === TASK_POOL_BANDS && d.bandRewards.length === TASK_POOL_BANDS;
    let band: number | null = rows[0]?.band ?? null;
    if (band === null && defs.some((d) => !d.pool && banded(d))) {
      band = bandForLevel(await this.levelOf(db, me), await this.bands(db)).band;
    }
    // D297: the generator's weekly templates of the caller's audience (definitionsFor keeps only theirs).
    const genWeekly = defs
      .filter((d) => isGenTemplateCode(d.code) && d.period === 'WEEKLY')
      .map((d) => d.code);
    // v1.71-live (D281): from the smart engine's first day the host's targets are the targets engine's own (rewarded
    // with a share of the profit), never Task Center tasks: the fixed «هدف هدايا الحظ» task is no longer offered.
    const engine = await this.targets.engineOn(day, db);
    const fixed: OfferedTask[] = [];
    for (const def of defs.filter((d) => !d.pool && !isGenTemplateCode(d.code))) {
      if (engine && (TARGET_METRICS as readonly string[]).includes(def.metric)) continue;
      // D297: the generated weekly tasks replace the audience's fixed weekly tasks.
      if (genWeekly.length > 0 && def.period === 'WEEKLY' && def.audience !== 'EVERYONE') continue;
      if (!banded(def)) {
        fixed.push({ def, target: def.target, rewardCherries: def.rewardCherries, pooled: false, ...PLAIN });
        continue;
      }
      const target = def.bandTargets[band! - 1] ?? 0;
      const rewardCherries = def.bandRewards[band! - 1] ?? 0;
      if (target > 0 && rewardCherries > 0)
        fixed.push({ def, target, rewardCherries, pooled: false, ...PLAIN });
    }
    const weekly: OfferedTask[] = [];
    if (week !== null && genWeekly.length > 0) {
      for (const r of await this.weeklyGenerated(db, me, week, genWeekly, band ?? 1)) {
        const def = byCode.get(r.taskCode);
        if (def) weekly.push({ def, pooled: false, ...generated(r) });
      }
    }
    return [...pooled, ...fixed, ...weekly];
  }

  /**
   * v1.86-social (D281, CONVENTIONS §10.41.4): what the smart task assignment reads about the caller — their 7-day
   * daily average of each offered metric (stored data, the same queries as the progress), their completion over the
   * last 7 days, the variants of the last `task_no_repeat_days` days and yesterday's templates, family membership,
   * the gifts they send most and the hours they join lives (30 days).
   */
  private async taskProfile(
    db: Tx | PrismaService,
    me: string,
    day: string,
    dayStart: Date,
    templates: readonly TaskTemplate[],
    noRepeatDays: number,
  ): Promise<TaskProfile> {
    const now = this.clock.now();
    const week: ProgramWindow = {
      date: day,
      start: new Date(dayStart.getTime() - 7 * 86_400_000),
      end: dayStart,
    };
    const month = new Date(dayStart.getTime() - 30 * 86_400_000);
    const [favourites, hours, family, recent, claimed, host, level, bands] = await Promise.all([
      db.$queryRaw<{ code: string }[]>`
        SELECT g.gift_code AS code FROM live_gifts g
         WHERE g.sender_id = ${me}::uuid AND g.coins_charged > 0
           AND g.created_at >= ${month}::timestamptz AND g.created_at < ${dayStart}::timestamptz
         GROUP BY g.gift_code ORDER BY sum(g.quantity) DESC, g.gift_code LIMIT 3`,
      db.$queryRaw<{ h: number; n: number }[]>`
        SELECT extract(hour FROM a.first_joined_at AT TIME ZONE ${this.zone})::int AS h, count(*)::int AS n
          FROM live_room_audience a
         WHERE a.user_id = ${me}::uuid
           AND a.first_joined_at >= ${month}::timestamptz AND a.first_joined_at < ${dayStart}::timestamptz
         GROUP BY 1`,
      db.$queryRaw<{ inside: boolean }[]>`
        SELECT EXISTS (SELECT 1 FROM family_members WHERE user_id = ${me}::uuid) AS inside`,
      db.taskAssignment.findMany({
        where: {
          userId: me,
          day: { gte: dateValue(addDays(day, -Math.max(7, noRepeatDays))), lt: dateValue(day) },
        },
        select: { day: true, taskCode: true, variant: true },
      }),
      db.$queryRaw<{ n: number }[]>`
        SELECT count(*)::int AS n FROM task_claims c
          JOIN task_assignments a ON a.user_id = c.user_id AND a.task_code = c.task_code AND a.day = c.period_start
         WHERE c.user_id = ${me}::uuid AND c.period_start >= ${addDays(day, -7)}::date
           AND c.period_start < ${day}::date`,
      this.roleOf(db, me),
      this.levelOf(db, me),
      this.bands(db),
    ]);
    const favouriteGifts = favourites.map((f) => f.code);
    const dailyAverage: Partial<Record<TaskMetric, number>> = {};
    for (const metric of new Set(templates.map((t) => t.metric))) {
      // A chosen gift: the average of their favourite one (the one the assignment names); a category: not read.
      if (metric === 'CATEGORY_GIFTS_SENT') continue;
      const subject = metric === 'GIFT_COUNT_SENT' ? (favouriteGifts[0] ?? null) : null;
      if (metric === 'GIFT_COUNT_SENT' && subject === null) continue;
      dailyAverage[metric] = (await this.progressOf(db, me, metric, week, now, subject)) / 7;
    }
    const activeHours = new Array<number>(24).fill(0);
    for (const h of hours) activeHours[h.h] = h.n;
    const yesterday = addDays(day, -1);
    const sinceRepeat = addDays(day, -noRepeatDays);
    const recentWeek = recent.filter((r) => r.day.toISOString().slice(0, 10) >= addDays(day, -7));
    return {
      band: bandForLevel(level, bands),
      isHost: host.host,
      isCreator: host.creator,
      dailyAverage,
      recentAssigned: recentWeek.length,
      recentClaimed: claimed[0]?.n ?? 0,
      recentVariants: recent
        .filter((r) => r.variant !== null && r.day.toISOString().slice(0, 10) >= sinceRepeat)
        .map((r) => r.variant!),
      yesterdayTemplates: recent
        .filter((r) => r.day.toISOString().slice(0, 10) === yesterday)
        .map((r) => r.taskCode),
      inFamily: family[0]?.inside ?? false,
      favouriteGifts,
      activeHours,
    };
  }

  /**
   * v1.86-social (D281): the caller's tasks of `day` from the generated catalogue (task-catalogue.ts): the smart
   * assignment from their profile, each with its variant, gift or category, window, names and reasons, stored for the
   * day (concurrent first reads pick the same and keep one set).
   */
  private async smartAssign(
    db: Tx | PrismaService,
    me: string,
    day: string,
    reserve = 0,
    poolOk: (t: { audience: string; metric: string }) => boolean = () => true,
  ): Promise<void> {
    const windows = await programWindowsIn(db, this.clock.now(), this.zone);
    const dayStart = windows.day.date === day ? windows.day.start : dateValue(day);
    const rows = await db.taskDefinition.findMany({ where: { enabled: true, pool: true } });
    const templates: TaskTemplate[] = rows
      .filter((t) => isTaskMetric(t.metric) && t.poolGroup !== null && poolOk(t))
      .map((t) => ({
        code: t.code,
        metric: t.metric as TaskMetric,
        group: t.poolGroup!,
        audience: t.audience,
        bandTargets: t.bandTargets,
        bandRewards: t.bandRewards,
        sortOrder: t.sortOrder,
        nameAr: t.nameAr,
        nameEn: t.nameEn,
      }));
    if (templates.length === 0) return;
    const settings = await this.targets.settings(db);
    const gifts = await this.targets.catalogueGifts(db);
    const profile = await this.taskProfile(
      db,
      me,
      day,
      dayStart,
      catalogueTemplates(templates),
      settings.taskNoRepeatDays,
    );
    // D297: the generator's share of the day is reserved (no creator / host template, fewer pool tasks).
    const forPool: TaskProfile =
      reserve > 0
        ? {
            ...profile,
            isHost: false,
            isCreator: false,
            band: { ...profile.band, dailyCount: Math.max(0, profile.band.dailyCount - reserve) },
          }
        : profile;
    const picks = assignSmartTasks(templates, forPool, gifts, taskSeed(me, day));
    const giftBy = new Map(gifts.map((g) => [g.code, g]));
    const cats = new Map(
      (await db.giftCategory.findMany({ select: { code: true, nameAr: true, nameEn: true } })).map((c) => [
        c.code,
        c,
      ]),
    );
    const byCode = new Map(templates.map((t) => [t.code, t]));
    await db.taskAssignment.createMany({
      data: picks.map((p) => {
        const t = byCode.get(p.template)!;
        const s = p.variant.subject;
        const names = variantName(t, p.variant, {
          ar: s ? (giftBy.get(s)?.nameAr ?? cats.get(s)?.nameAr) : undefined,
          en: s ? (giftBy.get(s)?.nameEn ?? cats.get(s)?.nameEn) : undefined,
        });
        const whole = isAllDay(p.variant.window);
        return {
          userId: me,
          day: dateValue(day),
          taskCode: p.template,
          band: profile.band.band,
          target: p.target,
          rewardCherries: p.rewardCherries,
          position: p.position,
          variant: p.variant.code,
          subject: s,
          windowFrom: whole ? null : p.variant.window.from,
          windowTo: whole ? null : p.variant.window.to,
          nameAr: s !== null || !whole ? names.ar.slice(0, 160) : null,
          nameEn: s !== null || !whole ? names.en.slice(0, 160) : null,
          reason: p.reason,
        };
      }),
      skipDuplicates: true,
    });
  }

  /**
   * Coins paid today by the check-in and by daily task claims made before v1.53-social (what the
   * check-in's coin cap counts).
   */
  private async earnedCoinsToday(db: Db, me: string, day: string): Promise<number> {
    const [row] = await db.$queryRaw<{ n: bigint }[]>`
      SELECT (COALESCE((SELECT sum(c.reward_amount) FROM task_claims c
                          JOIN task_definitions d ON d.code = c.task_code AND d.period = 'DAILY'
                         WHERE c.user_id = ${me}::uuid AND c.period_start = ${day}::date
                           AND c.reward_currency = 'COINS'), 0)
            + COALESCE((SELECT sum(reward_coins) FROM daily_check_ins
                         WHERE user_id = ${me}::uuid AND day = ${day}::date), 0))::bigint AS n`;
    return Number(row?.n ?? 0n);
  }

  /**
   * v1.57-social (D188): task cherries paid in the calendar month `w` — daily and weekly claims, by the
   * time they were paid (what the monthly cap counts).
   */
  private async earnedCherriesInMonth(db: Db, me: string, w: ProgramWindow): Promise<number> {
    const [row] = await db.$queryRaw<{ n: bigint }[]>`
      SELECT COALESCE(sum(c.reward_amount), 0)::bigint AS n
        FROM task_claims c
       WHERE c.user_id = ${me}::uuid AND c.reward_currency = 'CHERRIES'
         AND c.created_at >= ${w.start}::timestamptz AND c.created_at < ${w.end}::timestamptz`;
    return Number(row?.n ?? 0n);
  }

  /** v1.57-social (D188): the monthly cap in cherries (`TASK_MONTHLY_CAP_MINOR` at the payout rate). */
  private get monthlyCap(): number {
    const { rateCherries, rateMinor } = this.config.economy;
    return monthlyCapCherries(this.config.programs.taskMonthlyCapMinor, rateCherries, rateMinor);
  }

  /** v1.53-social (D184): cherries paid today by daily tasks (what `TASK_DAILY_CAP_CHERRIES` counts). */
  private async earnedCherriesToday(db: Db, me: string, day: string): Promise<number> {
    const [row] = await db.$queryRaw<{ n: bigint }[]>`
      SELECT COALESCE(sum(c.reward_amount), 0)::bigint AS n
        FROM task_claims c
        JOIN task_definitions d ON d.code = c.task_code AND d.period = 'DAILY'
       WHERE c.user_id = ${me}::uuid AND c.period_start = ${day}::date AND c.reward_currency = 'CHERRIES'`;
    return Number(row?.n ?? 0n);
  }

  private async balance(db: Db, me: string): Promise<number> {
    const [row] = await db.$queryRaw<
      { coins: bigint }[]
    >`SELECT coins FROM wallets WHERE user_id = ${me}::uuid`;
    return Number(row?.coins ?? 0n);
  }

  private async cherryBalance(db: Db, me: string): Promise<number> {
    const [row] = await db.$queryRaw<
      { cherries: bigint }[]
    >`SELECT cherries FROM cherry_wallets WHERE user_id = ${me}::uuid`;
    return Number(row?.cherries ?? 0n);
  }

  private taskDto(
    task: OfferedTask,
    progress: number,
    claim: StoredClaim | null,
    lang: ContentLanguage,
    gift: ProgramTaskDto['gift'] = null,
  ): ProgramTaskDto {
    const { def, target } = task;
    const hm = (m: number) =>
      `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
    return {
      code: def.code,
      pooled: task.pooled,
      period: def.period,
      metric: def.metric as TaskMetric,
      audience: def.audience,
      name: lang === 'ar' ? (task.nameAr ?? def.nameAr) : (task.nameEn ?? def.nameEn),
      gift,
      window: task.window === null ? null : { from: hm(task.window.from), to: hm(task.window.to) },
      target,
      progress: Math.min(progress, target),
      rewardCoins: 0,
      rewardCherries: task.rewardCherries,
      completed: progress >= target,
      claimed: claim !== null,
      claimedCoins: claim === null ? null : claim.currency === 'COINS' ? claim.amount : 0,
      claimedCherries: claim === null ? null : claim.currency === 'CHERRIES' ? claim.amount : 0,
    };
  }

  private async taskIn(
    db: Db,
    me: string,
    task: OfferedTask,
    windows: { day: ProgramWindow; week: ProgramWindow },
    now: Date,
    lang: ContentLanguage,
  ): Promise<ProgramTaskDto> {
    const w = task.def.period === 'DAILY' ? windows.day : windows.week;
    const [claim] = await db.$queryRaw<{ amount: number; currency: 'COINS' | 'CHERRIES' }[]>`
      SELECT reward_amount AS amount, reward_currency::text AS currency FROM task_claims
       WHERE user_id = ${me}::uuid AND task_code = ${task.def.code} AND period_start = ${w.date}::date`;
    const progress = await this.progressOf(
      db,
      me,
      task.def.metric as TaskMetric,
      this.narrowed(w, task.window),
      now,
      task.subject,
    );
    return this.taskDto(task, progress, claim ?? null, lang, await this.giftOf(db, task, lang));
  }

  /** v1.86-social (D281): the gift a chosen-gift task names (its picture and name), else null. */
  private async giftOf(db: Db, task: OfferedTask, lang: ContentLanguage): Promise<ProgramTaskDto['gift']> {
    if (task.subject === null || task.def.metric !== 'GIFT_COUNT_SENT') return null;
    const [g] = await db.$queryRaw<
      { code: string; name_ar: string; name_en: string; asset_key: string; image_object_key: string | null }[]
    >`SELECT code, name_ar, name_en, asset_key, image_object_key FROM gifts WHERE code = ${task.subject}`;
    if (!g) return null;
    return {
      code: g.code,
      name: lang === 'ar' ? g.name_ar : g.name_en,
      assetKey: g.asset_key,
      imageUrl: giftArtUrl(this.storage.current().publicBaseUrl, g.image_object_key),
    };
  }

  /** `GET /me/tasks`. */
  async mine(me: string, lang: ContentLanguage): Promise<MyTasksDto> {
    const now = this.clock.now();
    const windows = await programWindowsIn(this.prisma, now, this.zone);
    const today = windows.day.date;
    const offered = await this.tasksFor(this.prisma, me, today, windows.week.date);
    const tasks = await Promise.all(offered.map((t) => this.taskIn(this.prisma, me, t, windows, now, lang)));
    // The band of today's assignment (fixed for the day), else the band of the level now.
    const level = await this.levelOf(this.prisma, me);
    const bands = await this.bands(this.prisma);
    const assignedBand = await this.assignedBand(me, today);
    const shownBand = bands.find((b) => b.band === assignedBand) ?? bandForLevel(level, bands);
    const role = await this.roleOf(this.prisma, me);
    const checks = await this.prisma.dailyCheckIn.findMany({
      where: { userId: me, day: { in: [dateValue(addDays(today, -1)), dateValue(today)] } },
      select: { day: true, streak: true },
    });
    const todayRow = checks.find((c) => c.day.toISOString().startsWith(today));
    const yesterdayRow = checks.find((c) => !c.day.toISOString().startsWith(today));
    const {
      checkInCoins,
      checkInStreakBonusCoins: bonus,
      taskDailyCapCoins,
      taskDailyCapCherries,
    } = this.config.programs;
    // Today's place in the cycle: the streak made by today's check-in (done, or if done now).
    const streak = todayRow?.streak ?? yesterdayRow?.streak ?? 0;
    const todayStreak = todayRow ? todayRow.streak : streak + 1;
    const days: CheckInDayDto[] = [];
    for (let i = 0; i < CHECK_IN_CYCLE_DAYS; i++) {
      days.push({
        date: addDays(today, i),
        cycleDay: checkInCycleDay(todayStreak + i),
        today: i === 0,
        checkedIn: i === 0 && todayRow !== undefined,
        rewardCoins: checkInReward(todayStreak + i, checkInCoins, bonus),
      });
    }
    return {
      day: today,
      timeZone: this.zone,
      dayStartsAt: windows.day.start.toISOString(),
      dayResetsAt: windows.day.end.toISOString(),
      weekStartsAt: windows.week.start.toISOString(),
      weekResetsAt: windows.week.end.toISOString(),
      dailyCapCoins: taskDailyCapCoins,
      dailyEarnedCoins: await this.earnedCoinsToday(this.prisma, me, today),
      dailyCapCherries: taskDailyCapCherries,
      dailyEarnedCherries: await this.earnedCherriesToday(this.prisma, me, today),
      monthlyCapCherries: this.monthlyCap,
      monthlyEarnedCherries: await this.earnedCherriesInMonth(this.prisma, me, windows.month),
      band: {
        band: shownBand.band,
        level,
        name: lang === 'ar' ? shownBand.nameAr : shownBand.nameEn,
        host: role.host,
        creator: role.creator,
      },
      checkIn: {
        checkedInToday: todayRow !== undefined,
        streak,
        cycleDays: CHECK_IN_CYCLE_DAYS,
        rewardCoins: checkInCoins,
        bonusCoins: bonus,
        days,
      },
      tasks,
    };
  }

  /** The band today's pool tasks were assigned for (null when none). */
  private async assignedBand(me: string, day: string): Promise<number | null> {
    const row = await this.prisma.taskAssignment.findFirst({
      where: { userId: me, day: dateValue(day) },
      select: { band: true },
    });
    return row?.band ?? null;
  }

  /** Locks the caller's `users` row: one claim or check-in of a person at a time. */
  private async lockUser(tx: Tx, me: string): Promise<void> {
    await tx.$queryRaw`SELECT id FROM users WHERE id = ${me}::uuid FOR UPDATE`;
  }

  /**
   * `POST /me/check-in`: today's check-in (once per day). 201 checked in now, 200 already today. The
   * coins (5, or 5 + 20 on every 7th day in a row) are capped by `TASK_DAILY_CAP_COINS` (since v1.53-social
   * it counts only coins: the check-in and coin task claims of the day); a check-in after the cap still
   * keeps the streak and pays 0.
   */
  async checkIn(me: string, lang: ContentLanguage): Promise<{ created: boolean; result: CheckInResultDto }> {
    await refuseLimitedStaff(this.prisma, me, 'tasks');
    const now = this.clock.now();
    let created = false;
    let paid = 0;
    try {
      ({ created, paid } = await this.prisma.$transaction(async (tx) => {
        await this.lockUser(tx, me);
        const { day } = await programWindowsIn(tx, now, this.zone);
        const existing = await tx.dailyCheckIn.findUnique({
          where: { userId_day: { userId: me, day: dateValue(day.date) } },
          select: { rewardCoins: true },
        });
        if (existing) return { created: false, paid: existing.rewardCoins };
        const yesterday = await tx.dailyCheckIn.findUnique({
          where: { userId_day: { userId: me, day: dateValue(addDays(day.date, -1)) } },
          select: { streak: true },
        });
        const streak = (yesterday?.streak ?? 0) + 1;
        const { checkInCoins, checkInStreakBonusCoins, taskDailyCapCoins } = this.config.programs;
        const reward = checkInReward(streak, checkInCoins, checkInStreakBonusCoins);
        const coins = cappedReward(reward, taskDailyCapCoins, await this.earnedCoinsToday(tx, me, day.date));
        const row = await tx.dailyCheckIn.create({
          data: { userId: me, day: dateValue(day.date), streak, rewardCoins: coins, createdAt: now },
          select: { id: true },
        });
        if (coins > 0) await creditIn(tx, me, BigInt(coins), 'CHECK_IN_REWARD', row.id);
        return { created: true, paid: coins };
      }));
    } catch (err) {
      const index = violatedUniqueIndex(err);
      if (index === null || !index.includes('daily_check_ins_once')) throw err;
    }
    return {
      created,
      result: {
        paidCoins: paid,
        balanceCoins: await this.balance(this.prisma, me),
        tasks: await this.mine(me, lang),
      },
    };
  }

  /**
   * `POST /me/tasks/{code}/claim`. Order: 404 (unknown, disabled or not for the caller) → already
   * claimed in this period → 200 (nothing paid again) → 409 TASK_NOT_COMPLETED → 409
   * TASK_MONTHLY_CAP_REACHED when the month's task cherries are used up (v1.57-social, D188; daily and
   * weekly tasks) → (daily tasks) 409 TASK_DAILY_CAP_REACHED when the day's cherry cap is used up → 201,
   * paying the reward or what is left of the caps in cherries (v1.53-social, D184: a `cherry_ledger`
   * `TASK_REWARD` row in this transaction). Weekly (host) tasks are outside the daily cap: each pays once
   * a week, within the monthly cap.
   */
  async claim(
    me: string,
    code: string,
    lang: ContentLanguage,
  ): Promise<{ created: boolean; result: TaskClaimResultDto }> {
    await refuseLimitedStaff(this.prisma, me, 'tasks');
    const now = this.clock.now();
    const run = () =>
      this.prisma.$transaction(async (tx) => {
        const windows = await programWindowsIn(tx, now, this.zone);
        // A pool task only when it is one of the caller's tasks of today (404 otherwise).
        const offered = (await this.tasksFor(tx, me, windows.day.date, windows.week.date)).find(
          (t) => t.def.code === code,
        );
        if (!offered) throw new AppException(ErrorCode.NOT_FOUND);
        const { def } = offered;
        await this.lockUser(tx, me);
        const w = def.period === 'DAILY' ? windows.day : windows.week;
        const existing = await tx.taskClaim.findUnique({
          where: {
            userId_taskCode_periodStart: { userId: me, taskCode: def.code, periodStart: dateValue(w.date) },
          },
          select: { rewardAmount: true, rewardCurrency: true },
        });
        if (existing) {
          const task = await this.taskIn(tx, me, offered, windows, now, lang);
          const paid: StoredClaim = { amount: existing.rewardAmount, currency: existing.rewardCurrency };
          return { created: false, task, paid };
        }
        const progress = await this.progressOf(
          tx,
          me,
          def.metric as TaskMetric,
          this.narrowed(w, offered.window),
          now,
          offered.subject,
        );
        if (progress < offered.target) throw new AppException(ErrorCode.TASK_NOT_COMPLETED);
        const { pay: cherries, cap } = cappedTaskReward(
          offered.rewardCherries,
          def.period === 'DAILY'
            ? {
                cap: this.config.programs.taskDailyCapCherries,
                earned: await this.earnedCherriesToday(tx, me, w.date),
              }
            : null,
          { cap: this.monthlyCap, earned: await this.earnedCherriesInMonth(tx, me, windows.month) },
        );
        if (cap === 'MONTHLY') throw new AppException(ErrorCode.TASK_MONTHLY_CAP_REACHED);
        if (cap === 'DAILY') throw new AppException(ErrorCode.TASK_DAILY_CAP_REACHED);
        await tx.taskClaim.create({
          data: {
            userId: me,
            taskCode: def.code,
            periodStart: dateValue(w.date),
            rewardAmount: cherries,
            rewardCurrency: 'CHERRIES',
            createdAt: now,
          },
          select: { id: true },
        });
        await creditTaskCherriesIn(tx, me, BigInt(cherries), taskRewardReference(def.code, w.date), now);
        const paid: StoredClaim = { amount: cherries, currency: 'CHERRIES' };
        const task = this.taskDto(offered, progress, paid, lang, await this.giftOf(tx, offered, lang));
        return { created: true, task, paid };
      });
    let outcome: { created: boolean; task: ProgramTaskDto; paid: StoredClaim };
    try {
      outcome = await run();
    } catch (err) {
      const index = violatedUniqueIndex(err);
      if (
        index === null ||
        !(index.includes('task_claims_once') || index.includes('cherry_ledger_reference_once'))
      )
        throw err;
      outcome = await run();
    }
    return {
      created: outcome.created,
      result: {
        task: outcome.task,
        paidCoins: outcome.paid.currency === 'COINS' ? outcome.paid.amount : 0,
        balanceCoins: await this.balance(this.prisma, me),
        paidCherries: outcome.paid.currency === 'CHERRIES' ? outcome.paid.amount : 0,
        balanceCherries: await this.cherryBalance(this.prisma, me),
      },
    };
  }

  // ---- v1.44-live (D199): the host's «تارجت» and statistics ------------------------------------

  /**
   * The ACTIVE people who sent `host` gifts in [from, to) (lucky sends only with `lucky`; D277: otherwise
   * every send outside the lucky category — the «هدف الهدايا» list); never the host: the coin value
   * and the cherries the host got from them (the ledger rows of those sends, net of reversals), ranked by
   * cherries (a cherries list) or coins (`lucky`); the first `limit` with their support level, and — for
   * `viewer` — the viewer's own place (D199b).
   */
  private async supporters(
    host: string,
    from: Date | null,
    to: Date,
    lucky: boolean,
    limit: number,
    viewer: string | null = null,
    /**
     * v1.133-social (D380, §10.170.3): the public «تارجت» chip — who reads it (null: a guest): a supporter with
     * RANKING_ANONYMOUS on is «مجهول» (no support level) to everyone but themselves and the host. Undefined: the host's
     * own statistics (never masked).
     */
    reader?: string | null,
  ): Promise<{ list: HostSupporterDto[]; me: HostSupporterRankDto | null }> {
    const rows = await this.prisma.$queryRaw<{ id: string; coins: bigint; cherries: bigint; rank: bigint }[]>`
      WITH per AS (
        SELECT g.sender_id AS id, sum(gr.coins)::bigint AS coins, COALESCE(sum(c.n), 0)::bigint AS cherries
          FROM live_gift_recipients gr
          JOIN live_gifts g ON g.id = gr.gift_id
          JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
          LEFT JOIN LATERAL (
            SELECT sum(l.delta) AS n FROM cherry_ledger l
             WHERE l.user_id = gr.user_id AND l.reference_id = g.id::text
               AND l.reason IN ('GIFT_RECEIVED', 'GIFT_REVERSAL')) c ON true
         WHERE gr.user_id = ${host}::uuid AND g.sender_id <> ${host}::uuid
           AND (${from}::timestamptz IS NULL OR g.created_at >= ${from}::timestamptz)
           AND g.created_at < ${to}::timestamptz
           -- D277: the gifts list counts gifts outside the lucky category only; the lucky list lucky ones.
           AND ${lucky} = EXISTS (SELECT 1 FROM lucky_gift_draws d WHERE d.gift_id = g.id)
         GROUP BY g.sender_id
        HAVING sum(gr.coins) > 0),
      ranked AS (
        SELECT id, coins, cherries,
               row_number() OVER (
                 ORDER BY CASE WHEN ${lucky} THEN coins ELSE cherries END DESC, coins DESC, id) AS rank
          FROM per)
      SELECT id::text AS id, coins, cherries, rank FROM ranked
       WHERE rank <= ${limit} OR id = ${viewer}::uuid
       ORDER BY rank`;
    const top = rows.filter((r) => Number(r.rank) <= limit);
    const mine = viewer === null ? undefined : rows.find((r) => r.id === viewer);
    const me =
      viewer === null
        ? null
        : mine
          ? { rank: Number(mine.rank), amount: Number(lucky ? mine.coins : mine.cherries) }
          : { rank: null, amount: 0 };
    if (top.length === 0) return { list: [], me };
    const ids = top.map((r) => r.id);
    const [users, levels] = await Promise.all([
      this.prisma.user.findMany({ where: { id: { in: ids } }, select: USER_SUMMARY_SELECT }),
      this.prisma.$queryRaw<{ id: string; level: number | null }[]>`
        SELECT a.id::text AS id, ${levelSql('SUPPORT')} AS level FROM unnest(${ids}::uuid[]) AS a(id)`,
    ]);
    const byId = new Map(users.map((u) => [u.id, userSummary(u)]));
    const levelOf = new Map(levels.map((l) => [l.id, l.level]));
    const anonymous =
      reader === undefined
        ? new Set<string>()
        : await vipPrivacyOnIn(this.prisma, ids, 'RANKING_ANONYMOUS', new Date());
    const list = top
      .filter((r) => byId.has(r.id))
      .map((r) => {
        const user = rankedUser(byId.get(r.id)!, anonymous, reader ?? null, [host]);
        return {
          user,
          coins: Number(r.coins),
          cherries: Number(r.cherries),
          supportLevel: user.anonymous ? null : (levelOf.get(r.id) ?? null),
        };
      });
    return { list, me };
  }

  /** D277: the cherries of one of the host's targets for gifts sent in [from, to) ({@link hostCherriesSql}). */
  private async hostCherries(host: string, from: Date | null, to: Date, lucky: boolean): Promise<number> {
    const [row] = await this.prisma.$queryRaw<{ n: bigint }[]>(hostCherriesSql(host, from, to, lucky));
    return Number(row?.n ?? 0n);
  }

  /**
   * Gift sends `host` received from other ACTIVE people in [from, to), and their different senders: lucky
   * sends with `lucky`, D277: else the sends outside the lucky category (the «هدف الهدايا» tab).
   */
  private async received(
    host: string,
    from: Date | null,
    to: Date,
    lucky: boolean,
  ): Promise<{ coins: number; gifts: number; givers: number }> {
    const [row] = await this.prisma.$queryRaw<{ coins: bigint; gifts: number; givers: number }[]>`
      SELECT COALESCE(sum(gr.coins), 0)::bigint AS coins, count(DISTINCT g.id)::int AS gifts,
             count(DISTINCT g.sender_id)::int AS givers
        FROM live_gift_recipients gr
        JOIN live_gifts g ON g.id = gr.gift_id
        JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
       WHERE gr.user_id = ${host}::uuid AND g.sender_id <> ${host}::uuid
         AND (${from}::timestamptz IS NULL OR g.created_at >= ${from}::timestamptz)
         AND g.created_at < ${to}::timestamptz
         AND ${lucky} = EXISTS (SELECT 1 FROM lucky_gift_draws d WHERE d.gift_id = g.id)`;
    return { coins: Number(row?.coins ?? 0n), gifts: row?.gifts ?? 0, givers: row?.givers ?? 0 };
  }

  /**
   * v1.44-live (D199) `GET /live/hosts/{username}/targets` (and the DAY tab): today's progress against the
   * host's band targets. v1.69-live (D277, owner): both in CHERRIES, as stored — «هدف الهدايا» is
   * P_HOST_GIFTS's band target against the cherries of today's gifts outside the lucky category from other
   * people, «هدف هدايا الحظ» HOST_LUCKY_COINS's against the cherries of today's lucky gifts (self-sends
   * too); 0 when that task is switched off. The band: today's assignment's, else the level's now (as the
   * Task Center).
   *
   * v1.71-live (D281): from the smart engine's first day `daily` holds the host's three targets (easy, medium,
   * hard; reached ones are paid here, once); `gifts` / `lucky` keep today's amounts received and, for older apps,
   * the target of the whole-day «هدف الهدايا» / «هدف هدايا الحظ» among the three (0 when none is).
   */
  async hostTargets(
    host: string,
    viewer: string | null = null,
    lang: ContentLanguage = 'ar',
  ): Promise<LiveHostTargetsDto> {
    const now = this.clock.now();
    const { day } = await programWindowsIn(this.prisma, now, this.zone);
    if (await this.targets.engineOn(day.date)) return this.smartTargets(host, viewer, lang, day);
    const bands = await this.bands(this.prisma);
    const assigned = await this.assignedBand(host, day.date);
    const band =
      bands.find((b) => b.band === assigned) ?? bandForLevel(await this.levelOf(this.prisma, host), bands);
    const defs = await this.prisma.taskDefinition.findMany({
      where: { code: { in: [HOST_GIFTS_TARGET_TASK, HOST_LUCKY_TARGET_TASK] }, enabled: true },
      select: { code: true, bandTargets: true },
    });
    const targetOf = (code: string) => defs.find((d) => d.code === code)?.bandTargets[band.band - 1] ?? 0;
    // D199b: the caller's own place (never the host's own).
    const me = viewer !== null && viewer !== host ? viewer : null;
    const [giftsCherries, luckyCherries, top, luckyTop] = await Promise.all([
      this.hostCherries(host, day.start, day.end, false),
      this.hostCherries(host, day.start, day.end, true),
      this.supporters(host, day.start, day.end, false, HOST_SUPPORTERS_LIMIT, me, viewer),
      this.supporters(host, day.start, day.end, true, HOST_SUPPORTERS_LIMIT, me, viewer),
    ]);
    const target = (received: number, t: number): HostTargetDto => ({
      received,
      target: t,
      reached: t > 0 && received >= t,
    });
    const gifts = target(giftsCherries, targetOf(HOST_GIFTS_TARGET_TASK));
    return {
      day: day.date,
      timeZone: this.zone,
      endsAt: day.end.toISOString(),
      band: band.band,
      gifts,
      cherries: gifts,
      lucky: target(luckyCherries, targetOf(HOST_LUCKY_TARGET_TASK)),
      topSupporters: top.list,
      luckySupporters: luckyTop.list,
      me:
        me !== null && top.me && luckyTop.me ? { gifts: top.me, cherries: top.me, lucky: luckyTop.me } : null,
      daily: [],
    };
  }

  /** v1.71-live (D281): {@link hostTargets} from the smart engine's first day. */
  private async smartTargets(
    host: string,
    viewer: string | null,
    lang: ContentLanguage,
    day: ProgramWindow,
  ): Promise<LiveHostTargetsDto> {
    const me = viewer !== null && viewer !== host ? viewer : null;
    const [daily, giftsCherries, luckyCherries, top, luckyTop, band] = await Promise.all([
      this.targets.daily(host, lang),
      this.hostCherries(host, day.start, day.end, false),
      this.hostCherries(host, day.start, day.end, true),
      this.supporters(host, day.start, day.end, false, HOST_SUPPORTERS_LIMIT, me, viewer),
      this.supporters(host, day.start, day.end, true, HOST_SUPPORTERS_LIMIT, me, viewer),
      this.levelOf(this.prisma, host).then(async (level) =>
        bandForLevel(level, await this.bands(this.prisma)),
      ),
    ]);
    const wholeDay = (kind: string) => daily.find((t) => t.kind === kind && t.window === null)?.amount ?? 0;
    const target = (received: number, t: number): HostTargetDto => ({
      received,
      target: t,
      reached: t > 0 && received >= t,
    });
    const gifts = target(giftsCherries, wholeDay('GIFT_CHERRIES'));
    return {
      day: day.date,
      timeZone: this.zone,
      endsAt: day.end.toISOString(),
      band: band.band,
      gifts,
      cherries: gifts,
      lucky: target(luckyCherries, wholeDay('LUCKY_CHERRIES')),
      topSupporters: top.list,
      luckySupporters: luckyTop.list,
      me:
        me !== null && top.me && luckyTop.me ? { gifts: top.me, cherries: top.me, lucky: luckyTop.me } : null,
      daily,
    };
  }

  // ---- v1.86-social (D281): the panel's catalogue stats -------------------------------------------

  /** The Task Center catalogue's size now (the enabled pool templates × parameters, the enabled gifts). */
  async taskCatalogue() {
    const rows = await this.prisma.taskDefinition.findMany({ where: { enabled: true, pool: true } });
    const templates: TaskTemplate[] = rows
      .filter((t) => isTaskMetric(t.metric) && t.poolGroup !== null)
      .map((t) => ({
        code: t.code,
        metric: t.metric as TaskMetric,
        group: t.poolGroup!,
        audience: t.audience,
        bandTargets: t.bandTargets,
        bandRewards: t.bandRewards,
        sortOrder: t.sortOrder,
        nameAr: t.nameAr,
        nameEn: t.nameEn,
      }));
    return taskCatalogueStats(templates, await this.targets.catalogueGifts());
  }

  /**
   * v1.44-live (D199) `GET /me/host-gift-stats?period=`: the caller's own gifts of the period (Riyadh
   * calendar day, ISO week, month, or ALL) — cherries received (the ledger), gift sends, different givers,
   * the top supporters and a bar series (hours of the day, days of the week or month, months of the last
   * year for ALL); lucky gifts' coin value, sends, givers and top supporters; the day's targets. D277: the
   * cherries side is «هدف الهدايا»'s — gifts outside the lucky category from other people (the series
   * too); lucky adds the cherries of lucky gifts (self-sends included).
   */
  async hostGiftStats(
    me: string,
    period: HostStatsPeriod,
    lang: ContentLanguage = 'ar',
  ): Promise<HostGiftStatsDto> {
    const now = this.clock.now();
    const windows = await programWindowsIn(this.prisma, now, this.zone);
    const w =
      period === 'DAY'
        ? windows.day
        : period === 'WEEK'
          ? windows.week
          : period === 'MONTH'
            ? windows.month
            : null;
    const from = w?.start ?? null;
    // ALL: everything until the end of today (a send made this very instant included).
    const to = w?.end ?? windows.day.end;
    const unit = period === 'DAY' ? 'hour' : period === 'ALL' ? 'month' : 'day';
    const seriesFrom = from ?? new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 11, 1));
    const series = await this.prisma.$queryRaw<{ start: string; n: bigint }[]>`
      WITH buckets AS (
        SELECT generate_series(
                 date_trunc(${unit}, ${seriesFrom}::timestamptz AT TIME ZONE ${this.zone}),
                 date_trunc(${unit}, (${to}::timestamptz - interval '1 millisecond') AT TIME ZONE ${this.zone}),
                 ('1 ' || ${unit})::interval) AS b)
      SELECT to_char(b.b, 'YYYY-MM-DD"T"HH24:MI:SS') AS start, COALESCE(sum(x.delta), 0)::bigint AS n
        FROM buckets b
        LEFT JOIN (
          SELECT l.delta, g.created_at
            FROM live_gift_recipients gr
            JOIN live_gifts g ON g.id = gr.gift_id
            JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
            JOIN cherry_ledger l ON l.user_id = gr.user_id AND l.reference_id = g.id::text
                                AND l.reason IN ('GIFT_RECEIVED', 'GIFT_REVERSAL')
           WHERE gr.user_id = ${me}::uuid AND g.sender_id <> ${me}::uuid
             AND NOT EXISTS (SELECT 1 FROM lucky_gift_draws d WHERE d.gift_id = g.id)
             AND g.created_at < ${to}::timestamptz) x
          ON date_trunc(${unit}, x.created_at AT TIME ZONE ${this.zone}) = b.b
       GROUP BY b.b ORDER BY b.b`;
    const [cherries, luckyCherries, gifts, lucky, top, luckyTop] = await Promise.all([
      this.hostCherries(me, from, to, false),
      this.hostCherries(me, from, to, true),
      this.received(me, from, to, false),
      this.received(me, from, to, true),
      this.supporters(me, from, to, false, HOST_SUPPORTERS_LIMIT),
      this.supporters(me, from, to, true, HOST_SUPPORTERS_LIMIT),
    ]);
    return {
      period,
      timeZone: this.zone,
      from: from?.toISOString() ?? null,
      to: to.toISOString(),
      cherries: {
        received: cherries,
        gifts: gifts.gifts,
        givers: gifts.givers,
        topSupporters: top.list,
        series: series.map((r) => ({ start: r.start, cherries: Number(r.n) })),
      },
      lucky: {
        coins: lucky.coins,
        cherries: luckyCherries,
        gifts: lucky.gifts,
        givers: lucky.givers,
        topSupporters: luckyTop.list,
      },
      targets: period === 'DAY' ? await this.hostTargets(me, null, lang) : null,
    };
  }
}
