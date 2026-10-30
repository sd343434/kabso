import { Inject, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma, type TaskDefinition } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import { creditIn } from '../wallet/wallet-ledger.js';
import { addDays, dateValue, programWindowsIn, type ProgramWindow } from './programs-time.js';
import {
  CHECK_IN_CYCLE_DAYS,
  WATCH_LIVE_MIN_MS,
  cappedReward,
  checkInCycleDay,
  checkInReward,
  isTaskMetric,
  type TaskMetric,
} from './programs-rules.js';

type Tx = Prisma.TransactionClient;
type Db = Pick<Tx, '$queryRaw'>;

// ---- Response shapes (openapi v1.44-social, D166) ---------------------------------------------

/** `ProgramTask`. */
export interface ProgramTaskDto {
  code: string;
  period: 'DAILY' | 'WEEKLY';
  metric: TaskMetric;
  audience: 'EVERYONE' | 'HOSTS';
  name: string;
  target: number;
  progress: number;
  rewardCoins: number;
  completed: boolean;
  claimed: boolean;
  /** The coins the claim paid (after the daily cap), null before it is claimed. */
  claimedCoins: number | null;
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
  dailyCapCoins: number;
  /** Coins from daily tasks and the check-in today (counts toward the cap). */
  dailyEarnedCoins: number;
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
  paidCoins: number;
  balanceCoins: number;
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
 * and period (`task_claims_once`) in the claim's transaction as a `TASK_REWARD` ledger row; daily tasks
 * and the check-in share a daily cap (`TASK_DAILY_CAP_COINS`). Claims and check-ins of one person are
 * serialized by a lock on their `users` row, so the cap holds under concurrent requests.
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

  /** The tasks the caller sees: enabled, known metric, and HOSTS tasks only for hosts. */
  private async definitionsFor(db: Tx | PrismaService, me: string): Promise<TaskDefinition[]> {
    const defs = await db.taskDefinition.findMany({
      where: { enabled: true },
      orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
    });
    const host = defs.some((d) => d.audience === 'HOSTS') ? await this.isHost(db, me) : false;
    return defs.filter((d) => isTaskMetric(d.metric) && (d.audience === 'EVERYONE' || host));
  }

  /** Coins already paid today by daily tasks and the check-in (what the cap counts). */
  private async earnedToday(db: Db, me: string, day: string): Promise<number> {
    const [row] = await db.$queryRaw<{ n: bigint }[]>`
      SELECT (COALESCE((SELECT sum(c.reward_coins) FROM task_claims c
                          JOIN task_definitions d ON d.code = c.task_code AND d.period = 'DAILY'
                         WHERE c.user_id = ${me}::uuid AND c.period_start = ${day}::date), 0)
            + COALESCE((SELECT sum(reward_coins) FROM daily_check_ins
                         WHERE user_id = ${me}::uuid AND day = ${day}::date), 0))::bigint AS n`;
    return Number(row?.n ?? 0n);
  }

  private async balance(db: Db, me: string): Promise<number> {
    const [row] = await db.$queryRaw<
      { coins: bigint }[]
    >`SELECT coins FROM wallets WHERE user_id = ${me}::uuid`;
    return Number(row?.coins ?? 0n);
  }

  private taskDto(
    def: TaskDefinition,
    progress: number,
    claimedCoins: number | null,
    lang: ContentLanguage,
  ): ProgramTaskDto {
    return {
      code: def.code,
      period: def.period,
      metric: def.metric as TaskMetric,
      audience: def.audience,
      name: lang === 'ar' ? def.nameAr : def.nameEn,
      target: def.target,
      progress: Math.min(progress, def.target),
      rewardCoins: def.rewardCoins,
      completed: progress >= def.target,
      claimed: claimedCoins !== null,
      claimedCoins,
    };
  }

  private async taskIn(
    db: Db,
    me: string,
    def: TaskDefinition,
    windows: { day: ProgramWindow; week: ProgramWindow },
    now: Date,
    lang: ContentLanguage,
  ): Promise<ProgramTaskDto> {
    const w = def.period === 'DAILY' ? windows.day : windows.week;
    const [claim] = await db.$queryRaw<{ reward_coins: number }[]>`
      SELECT reward_coins FROM task_claims
       WHERE user_id = ${me}::uuid AND task_code = ${def.code} AND period_start = ${w.date}::date`;
    const progress = await this.progressOf(db, me, def.metric as TaskMetric, w, now);
    return this.taskDto(def, progress, claim ? claim.reward_coins : null, lang);
  }

  /** `GET /me/tasks`. */
  async mine(me: string, lang: ContentLanguage): Promise<MyTasksDto> {
    const now = this.clock.now();
    const windows = await programWindowsIn(this.prisma, now, this.zone);
    const defs = await this.definitionsFor(this.prisma, me);
    const tasks = await Promise.all(defs.map((d) => this.taskIn(this.prisma, me, d, windows, now, lang)));
    const today = windows.day.date;
    const checks = await this.prisma.dailyCheckIn.findMany({
      where: { userId: me, day: { in: [dateValue(addDays(today, -1)), dateValue(today)] } },
      select: { day: true, streak: true },
    });
    const todayRow = checks.find((c) => c.day.toISOString().startsWith(today));
    const yesterdayRow = checks.find((c) => !c.day.toISOString().startsWith(today));
    const { checkInCoins, checkInStreakBonusCoins: bonus, taskDailyCapCoins } = this.config.programs;
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
      dailyEarnedCoins: await this.earnedToday(this.prisma, me, today),
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

  /** Locks the caller's `users` row: one claim or check-in of a person at a time. */
  private async lockUser(tx: Tx, me: string): Promise<void> {
    await tx.$queryRaw`SELECT id FROM users WHERE id = ${me}::uuid FOR UPDATE`;
  }

  /**
   * `POST /me/check-in`: today's check-in (once per day). 201 checked in now, 200 already today. The
   * coins (5, or 5 + 20 on every 7th day in a row) count toward the daily cap; a check-in after the cap
   * still keeps the streak and pays 0.
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
        const coins = cappedReward(reward, taskDailyCapCoins, await this.earnedToday(tx, me, day.date));
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
   * claimed in this period → 200 (nothing paid again) → 409 TASK_NOT_COMPLETED → (daily tasks) 409
   * TASK_DAILY_CAP_REACHED when the day's cap is used up → 201, paying the reward or what is left of
   * the cap. Weekly (host) tasks are outside the daily cap: each pays once a week.
   */
  async claim(
    me: string,
    code: string,
    lang: ContentLanguage,
  ): Promise<{ created: boolean; result: TaskClaimResultDto }> {
    const now = this.clock.now();
    const run = () =>
      this.prisma.$transaction(async (tx) => {
        const def = (await this.definitionsFor(tx, me)).find((d) => d.code === code);
        if (!def) throw new AppException(ErrorCode.NOT_FOUND);
        await this.lockUser(tx, me);
        const windows = await programWindowsIn(tx, now, this.zone);
        const w = def.period === 'DAILY' ? windows.day : windows.week;
        const existing = await tx.taskClaim.findUnique({
          where: {
            userId_taskCode_periodStart: { userId: me, taskCode: def.code, periodStart: dateValue(w.date) },
          },
          select: { rewardCoins: true },
        });
        if (existing) {
          const task = await this.taskIn(tx, me, def, windows, now, lang);
          return { created: false, task, paid: existing.rewardCoins };
        }
        const progress = await this.progressOf(tx, me, def.metric as TaskMetric, w, now);
        if (progress < def.target) throw new AppException(ErrorCode.TASK_NOT_COMPLETED);
        let coins = def.rewardCoins;
        if (def.period === 'DAILY') {
          coins = cappedReward(
            def.rewardCoins,
            this.config.programs.taskDailyCapCoins,
            await this.earnedToday(tx, me, w.date),
          );
          if (coins === 0) throw new AppException(ErrorCode.TASK_DAILY_CAP_REACHED);
        }
        const claim = await tx.taskClaim.create({
          data: {
            userId: me,
            taskCode: def.code,
            periodStart: dateValue(w.date),
            rewardCoins: coins,
            createdAt: now,
          },
          select: { id: true },
        });
        await creditIn(tx, me, BigInt(coins), 'TASK_REWARD', claim.id);
        return { created: true, task: this.taskDto(def, progress, coins, lang), paid: coins };
      });
    let outcome: { created: boolean; task: ProgramTaskDto; paid: number };
    try {
      outcome = await run();
    } catch (err) {
      const index = violatedUniqueIndex(err);
      if (index === null || !index.includes('task_claims_once')) throw err;
      outcome = await run();
    }
    return {
      created: outcome.created,
      result: {
        task: outcome.task,
        paidCoins: outcome.paid,
        balanceCoins: await this.balance(this.prisma, me),
      },
    };
  }
}
