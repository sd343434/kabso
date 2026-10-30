import { Inject, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma, type TaskDefinition } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import { creditTaskCherriesIn, taskRewardReference } from '../economy/cherry-ledger.js';
import { creditIn } from '../wallet/wallet-ledger.js';
import { addDays, dateValue, programWindowsIn, type ProgramWindow } from './programs-time.js';
import {
  CHECK_IN_CYCLE_DAYS,
  DEFAULT_TASK_POOL_BANDS,
  NEW_HOST_DAYS,
  TASK_POOL_BANDS,
  WATCH_LIVE_MIN_MS,
  assignDailyTasks,
  bandForLevel,
  cappedReward,
  cappedTaskReward,
  checkInCycleDay,
  checkInReward,
  isTaskMetric,
  monthlyCapCherries,
  seedOf,
  type TaskMetric,
  type TaskPoolBand,
} from './programs-rules.js';

type Tx = Prisma.TransactionClient;
type Db = Pick<Tx, '$queryRaw'>;

/** A task the caller has now, with its target and reward (a pool task's from today's assignment). */
interface OfferedTask {
  def: TaskDefinition;
  target: number;
  /** v1.53-social (D184): task rewards are cherries. */
  rewardCherries: number;
  pooled: boolean;
}

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
  audience: 'EVERYONE' | 'HOSTS';
  name: string;
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
  band: { band: number; level: number; name: string; host: boolean };
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
 * The query counting `metric` for `me` in `w` (column `n`). Counterparts (hosts, people followed, gift
 * recipients and senders) must be ACTIVE; nothing is counted from the caller's own lives or gifts.
 */
function progressSql(me: string, metric: TaskMetric, w: ProgramWindow, now: Date): Prisma.Sql {
  const from = w.start;
  const to = w.end;
  switch (metric) {
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
                        WHERE gr.gift_id = g.id AND gr.user_id <> ${me}::uuid
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
  ): Promise<number> {
    const rows = await db.$queryRaw<{ n: bigint | number | null }[]>(progressSql(me, metric, w, now));
    return Number(rows[0]?.n ?? 0);
  }

  private async isHost(db: Db, me: string): Promise<boolean> {
    const [row] = await db.$queryRaw<{ host: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM live_hosts WHERE user_id = ${me}::uuid) AS host`;
    return row?.host ?? false;
  }

  /** The tasks the caller may see: enabled, known metric, and HOSTS tasks only for hosts. */
  private async definitionsFor(db: Tx | PrismaService, me: string): Promise<TaskDefinition[]> {
    const defs = await db.taskDefinition.findMany({
      where: { enabled: true },
      orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
    });
    const host = defs.some((d) => d.audience === 'HOSTS') ? await this.isHost(db, me) : false;
    return defs.filter((d) => isTaskMetric(d.metric) && (d.audience === 'EVERYONE' || host));
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
    rows: { taskCode: string; target: number; rewardCherries: number; position: number; band: number }[];
  }> {
    const where = { userId: me, day: dateValue(day) };
    const select = {
      taskCode: true,
      target: true,
      rewardCherries: true,
      position: true,
      band: true,
    } as const;
    let rows = await db.taskAssignment.findMany({ where, select, orderBy: { position: 'asc' } });
    if (rows.length > 0) return { rows };
    const templates = await db.taskDefinition.findMany({ where: { enabled: true, pool: true } });
    const usable = templates.filter((t) => isTaskMetric(t.metric) && t.poolGroup !== null);
    if (usable.length === 0) return { rows };
    const band = bandForLevel(await this.levelOf(db, me), await this.bands(db));
    const picks = assignDailyTasks(
      usable.map((t) => ({
        code: t.code,
        group: t.poolGroup!,
        audience: t.audience,
        bandTargets: t.bandTargets,
        bandRewards: t.bandRewards,
        sortOrder: t.sortOrder,
      })),
      band,
      await this.isHost(db, me),
      seedOf(`${me}:${day}`),
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
    rows = await db.taskAssignment.findMany({ where, select, orderBy: { position: 'asc' } });
    return { rows };
  }

  /**
   * The tasks the caller has now: today's pool tasks (assigned, in their order), then the fixed
   * tasks (not pool), each with its target and reward (a pool task's from its assignment). v1.57-social
   * (D188 follow-up): a fixed task with one value per band (the weekly host tasks) takes the caller's
   * band of the day — today's assignment's, else the band of their level now; 0 = not offered.
   */
  private async tasksFor(db: Tx | PrismaService, me: string, day: string): Promise<OfferedTask[]> {
    const defs = await this.definitionsFor(db, me);
    const byCode = new Map(defs.map((d) => [d.code, d]));
    const { rows } = await this.assignmentsFor(db, me, day);
    const pooled: OfferedTask[] = [];
    for (const r of rows) {
      const def = byCode.get(r.taskCode);
      if (def?.pool) pooled.push({ def, target: r.target, rewardCherries: r.rewardCherries, pooled: true });
    }
    const banded = (d: TaskDefinition) =>
      d.bandTargets.length === TASK_POOL_BANDS && d.bandRewards.length === TASK_POOL_BANDS;
    let band: number | null = rows[0]?.band ?? null;
    if (band === null && defs.some((d) => !d.pool && banded(d))) {
      band = bandForLevel(await this.levelOf(db, me), await this.bands(db)).band;
    }
    const fixed: OfferedTask[] = [];
    for (const def of defs.filter((d) => !d.pool)) {
      if (!banded(def)) {
        fixed.push({ def, target: def.target, rewardCherries: def.rewardCherries, pooled: false });
        continue;
      }
      const target = def.bandTargets[band! - 1] ?? 0;
      const rewardCherries = def.bandRewards[band! - 1] ?? 0;
      if (target > 0 && rewardCherries > 0) fixed.push({ def, target, rewardCherries, pooled: false });
    }
    return [...pooled, ...fixed];
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
  ): ProgramTaskDto {
    const { def, target } = task;
    return {
      code: def.code,
      pooled: task.pooled,
      period: def.period,
      metric: def.metric as TaskMetric,
      audience: def.audience,
      name: lang === 'ar' ? def.nameAr : def.nameEn,
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
    const progress = await this.progressOf(db, me, task.def.metric as TaskMetric, w, now);
    return this.taskDto(task, progress, claim ?? null, lang);
  }

  /** `GET /me/tasks`. */
  async mine(me: string, lang: ContentLanguage): Promise<MyTasksDto> {
    const now = this.clock.now();
    const windows = await programWindowsIn(this.prisma, now, this.zone);
    const today = windows.day.date;
    const offered = await this.tasksFor(this.prisma, me, today);
    const tasks = await Promise.all(offered.map((t) => this.taskIn(this.prisma, me, t, windows, now, lang)));
    // The band of today's assignment (fixed for the day), else the band of the level now.
    const level = await this.levelOf(this.prisma, me);
    const bands = await this.bands(this.prisma);
    const assignedBand = await this.assignedBand(me, today);
    const shownBand = bands.find((b) => b.band === assignedBand) ?? bandForLevel(level, bands);
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
        host: await this.isHost(this.prisma, me),
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
    const now = this.clock.now();
    const run = () =>
      this.prisma.$transaction(async (tx) => {
        const windows = await programWindowsIn(tx, now, this.zone);
        // A pool task only when it is one of the caller's tasks of today (404 otherwise).
        const offered = (await this.tasksFor(tx, me, windows.day.date)).find((t) => t.def.code === code);
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
        const progress = await this.progressOf(tx, me, def.metric as TaskMetric, w, now);
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
        return { created: true, task: this.taskDto(offered, progress, paid, lang), paid };
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
}
