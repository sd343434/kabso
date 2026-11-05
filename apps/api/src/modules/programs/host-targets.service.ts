import { Inject, Injectable, Logger } from '@nestjs/common';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { topupMinorPerMillion } from '../../config/env.schema.js';
import { Prisma, type HostTargetAssignment, type HostTargetSettings } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { creditHostTargetCherriesIn, hostTargetRewardReference } from '../economy/cherry-ledger.js';
import { giftArtUrl } from '../gifts/gift-art.js';
import { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import {
  DEFAULT_TARGET_TUNING,
  TARGET_LEVELS,
  assignHostTargets,
  cappedTargetReward,
  catalogueStats,
  catalogueVersion,
  isAllDay,
  platformProfitUnits,
  targetSeed,
  targetTitle,
  unitsUsd,
  windowLabel,
  type CatalogueGift,
  type HostDay,
  type HostProfile,
  type ProfitEconomy,
  type SendMoney,
  type TargetKind,
  type TargetLevel,
  type TargetTuning,
  type TargetWindow,
} from './host-target-engine.js';
import { DEFAULT_TASK_POOL_BANDS, bandForLevel } from './programs-rules.js';
import { addDays, dateValue, programWindowsIn } from './programs-time.js';

type Tx = Prisma.TransactionClient;
type Db = Tx | PrismaService;

/** v1.71-live (D281) `HostDailyTarget`: one of a host's three targets of today. */
export interface HostDailyTargetDto {
  level: TargetLevel;
  code: string;
  kind: TargetKind;
  title: string;
  amount: number;
  progress: number;
  reached: boolean;
  /** The reward shown before completion: the level's share of the platform profit the amount stands for. */
  rewardCherries: number;
  /** The level's share of the profit, basis points (150 / 250 / 400 by default). */
  rewardBps: number;
  /** What the completion paid (locked task cherries; at most `rewardCherries`), null until paid. */
  paidCherries: number | null;
  /** Always true: the reward is locked task cherries (§10.46.1). */
  locked: true;
  /** The target's hours of the day (`HH:MM`), null for the whole day. */
  window: { from: string; to: string } | null;
  /** The gift of a gift target (GIFT_COUNT, GIFT_COMBO), else null. */
  gift: { code: string; name: string; assetKey: string; imageUrl: string | null } | null;
  /** The category of a CATEGORY_COUNT target, else null. */
  category: { code: string; name: string } | null;
}

/** One send to the host in a day, as the targets read it. */
interface SendRow {
  id: string;
  giftCode: string;
  category: string;
  lucky: boolean;
  self: boolean;
  senderId: string;
  quantity: number;
  combo: number;
  coins: bigint;
  charged: bigint;
  cherries: bigint;
  /** Minutes since the start of the host's day. */
  minute: number;
}

/** The settings row as the engine reads it. */
export interface HostTargetSettingsDto extends TargetTuning {
  taskNoRepeatDays: number;
  engineFrom: string | null;
  updatedAt: string;
  updatedById: string | null;
}

export function settingsDto(row: HostTargetSettings): HostTargetSettingsDto {
  return {
    easyPercentile: row.easyPercentile,
    mediumPercentile: row.mediumPercentile,
    hardPercentile: row.hardPercentile,
    easyRewardBps: row.easyRewardBps,
    mediumRewardBps: row.mediumRewardBps,
    hardRewardBps: row.hardRewardBps,
    noRepeatDays: row.noRepeatDays,
    taskNoRepeatDays: row.taskNoRepeatDays,
    historyDays: row.historyDays,
    completionShift: row.completionShift,
    engineFrom: row.engineFrom?.toISOString().slice(0, 10) ?? null,
    updatedAt: row.updatedAt.toISOString(),
    updatedById: row.updatedById,
  };
}

/** Does `kind` count the send (the host's own sends count only for the lucky target, as D277)? */
function counts(kind: TargetKind, subject: string | null, s: SendRow): boolean {
  switch (kind) {
    case 'GIFT_CHERRIES':
      return !s.lucky && !s.self;
    case 'LUCKY_CHERRIES':
      return s.lucky;
    case 'GIFT_COUNT':
    case 'GIFT_COMBO':
      return !s.self && s.giftCode === subject;
    case 'CATEGORY_COUNT':
      return !s.self && s.category === subject;
    default:
      return !s.self;
  }
}

/** A target's progress from the sends it counts. */
export function progressOf(kind: TargetKind, rows: readonly SendRow[]): number {
  switch (kind) {
    case 'GIFT_CHERRIES':
    case 'LUCKY_CHERRIES':
      return Number(rows.reduce((a, r) => a + r.cherries, 0n));
    case 'SUPPORTERS':
      return new Set(rows.map((r) => r.senderId)).size;
    case 'COMBO':
    case 'GIFT_COMBO':
      return rows.reduce((a, r) => Math.max(a, r.combo), 0);
    default:
      return rows.reduce((a, r) => a + r.quantity, 0);
  }
}

/**
 * «الأهداف الذكية» (v1.71-live, D281, CONVENTIONS §10.62.2): a host's three daily targets from the generated
 * catalogue, chosen from their data at the day's first read and stored; their progress from the stored gift
 * sends; the profit-share reward paid once, in locked task cherries, when a read sees the target reached.
 */
@Injectable()
export class HostTargetsService {
  private readonly logger = new Logger(HostTargetsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly storage: StorageSettingsStore,
  ) {}

  private get zone(): string {
    return this.config.live.rankingsTimeZone;
  }

  /** The economy constants of the profit (configuration). */
  economy(): ProfitEconomy {
    const e = this.config.economy;
    return {
      cherriesPerCoin: e.cherriesPerCoin,
      coinCentsPerMillion:
        topupMinorPerMillion(e.coinRetailUsdPerMillion) ?? Math.round(e.coinRetailUsdPerMillion * 100),
      rateCherries: e.rateCherries,
      rateMinor: e.rateMinor,
      luckyRtpBps: this.config.lucky.table.rtpBps,
      luckyHostShareBps: this.config.lucky.table.hostShareBps,
      hostShareBps: this.config.gifts.hostShareBps,
    };
  }

  /** The settings row (created with the defaults when missing). */
  async settings(db: Db = this.prisma): Promise<HostTargetSettings> {
    const row = await db.hostTargetSettings.findUnique({ where: { id: 1 } });
    if (row) return row;
    return db.hostTargetSettings.upsert({ where: { id: 1 }, create: { id: 1 }, update: {} });
  }

  tuningOf(row: HostTargetSettings): TargetTuning {
    return {
      ...DEFAULT_TARGET_TUNING,
      easyPercentile: row.easyPercentile,
      mediumPercentile: row.mediumPercentile,
      hardPercentile: row.hardPercentile,
      easyRewardBps: row.easyRewardBps,
      mediumRewardBps: row.mediumRewardBps,
      hardRewardBps: row.hardRewardBps,
      noRepeatDays: row.noRepeatDays,
      historyDays: row.historyDays,
      completionShift: row.completionShift,
    };
  }

  /**
   * Whether the smart engine runs on `day` (`YYYY-MM-DD`). The first time this is asked (no `engine_from` yet) it
   * becomes the NEXT day: today keeps D277's two targets and their progress; the switch is at the day boundary.
   */
  async engineOn(day: string, db: Db = this.prisma): Promise<boolean> {
    let row = await this.settings(db);
    if (row.engineFrom === null) {
      await db.$executeRaw`
        UPDATE host_target_settings SET engine_from = ${addDays(day, 1)}::date WHERE id = 1 AND engine_from IS NULL`;
      row = await this.settings(db);
    }
    return row.engineFrom !== null && row.engineFrom.toISOString().slice(0, 10) <= day;
  }

  /** The enabled gift catalogue (enabled gifts of enabled categories). */
  async catalogueGifts(db: Db = this.prisma): Promise<CatalogueGift[]> {
    const rows = await db.$queryRaw<
      { code: string; category: string; price: number; name_ar: string; name_en: string; lucky: boolean }[]
    >`
      SELECT g.code, g.category, g.price_coins AS price, g.name_ar, g.name_en, (c.kind = 'LUCKY') AS lucky
        FROM gifts g JOIN gift_categories c ON c.code = g.category AND c.enabled
       WHERE g.enabled
       ORDER BY g.code`;
    return rows.map((r) => ({
      code: r.code,
      category: r.category,
      priceCoins: r.price,
      nameAr: r.name_ar,
      nameEn: r.name_en,
      lucky: r.lucky,
    }));
  }

  /** The host's level band (the Task Center's: the higher of Support and Charm levels, the bands table). */
  private async bandOf(db: Db, host: string): Promise<number> {
    const [row] = await db.$queryRaw<{ level: number | null }[]>`
      SELECT max(s.current_level) AS level
        FROM user_level_states s
        JOIN level_categories c ON c.id = s.category_id AND c.is_enabled AND c.code IN ('SUPPORT', 'ATTRACTIVENESS')
       WHERE s.user_id = ${host}::uuid`;
    const rows = await db.taskPoolBand.findMany({ orderBy: { band: 'asc' } });
    return bandForLevel(row?.level ?? 0, rows.length === 0 ? DEFAULT_TASK_POOL_BANDS : rows).band;
  }

  /** The sends to `host` in [from, to) with what the targets need (one query). */
  private async sendsIn(db: Db, host: string, from: Date, to: Date): Promise<SendRow[]> {
    const rows = await db.$queryRaw<
      {
        id: string;
        gift_code: string;
        category: string;
        lucky: boolean;
        self: boolean;
        sender_id: string;
        quantity: number;
        combo: bigint;
        coins: bigint;
        charged: bigint;
        cherries: bigint;
        minute: number;
      }[]
    >`
      SELECT g.id::text AS id, g.gift_code, gf.category,
             EXISTS (SELECT 1 FROM lucky_gift_draws d WHERE d.gift_id = g.id) AS lucky,
             (g.sender_id = ${host}::uuid) AS self, g.sender_id::text AS sender_id, g.quantity,
             g.combo_quantity AS combo, gr.coins,
             CASE WHEN g.total_coins > 0 THEN (gr.coins * g.coins_charged) / g.total_coins ELSE 0 END::bigint AS charged,
             COALESCE((SELECT sum(l.delta) FROM cherry_ledger l
                        WHERE l.user_id = gr.user_id AND l.reference_id = g.id::text
                          AND l.reason IN ('GIFT_RECEIVED', 'GIFT_REVERSAL')), 0)::bigint AS cherries,
             floor(extract(epoch FROM (g.created_at - ${from}::timestamptz)) / 60)::int AS minute
        FROM live_gift_recipients gr
        JOIN live_gifts g ON g.id = gr.gift_id
        JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
        JOIN gifts gf ON gf.code = g.gift_code
       WHERE gr.user_id = ${host}::uuid
         AND g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz`;
    return rows.map((r) => ({
      id: r.id,
      giftCode: r.gift_code,
      category: r.category,
      lucky: r.lucky,
      self: r.self,
      senderId: r.sender_id,
      quantity: r.quantity,
      combo: Number(r.combo),
      coins: r.coins,
      charged: r.charged,
      cherries: r.cherries,
      minute: r.minute,
    }));
  }

  /** The sends one target counts (its kind, subject and window). */
  private counted(
    a: Pick<HostTargetAssignment, 'kind' | 'subject' | 'windowFrom' | 'windowTo'>,
    sends: readonly SendRow[],
  ) {
    const kind = a.kind as TargetKind;
    return sends.filter(
      (s) => s.minute >= a.windowFrom && s.minute < a.windowTo && counts(kind, a.subject, s),
    );
  }

  /**
   * What the assignment reads about a host: their last `historyDays` days (not today) — per day the cherries and coins
   * from gifts and from lucky gifts, gifts received, supporters, the biggest combo, the minutes live and the cherries
   * per hour, gifts by code; their usual live hours, viewers per live, the completion of their recent targets and the
   * codes of the last `noRepeatDays` days.
   */
  async profileOf(
    db: Db,
    host: string,
    day: string,
    dayStart: Date,
    tuning: TargetTuning,
  ): Promise<HostProfile> {
    const from = new Date(dayStart.getTime() - tuning.historyDays * 86_400_000);
    const zone = this.zone;
    const [sendRows, supporters, rooms, viewers, recent, codes, band] = await Promise.all([
      db.$queryRaw<
        {
          d: string;
          h: number;
          gift_code: string;
          lucky: boolean;
          self: boolean;
          qty: bigint;
          coins: bigint;
          cherries: bigint;
          combo: bigint;
        }[]
      >`
        SELECT to_char((g.created_at AT TIME ZONE ${zone})::date, 'YYYY-MM-DD') AS d,
               extract(hour FROM g.created_at AT TIME ZONE ${zone})::int AS h,
               g.gift_code, EXISTS (SELECT 1 FROM lucky_gift_draws ld WHERE ld.gift_id = g.id) AS lucky,
               (g.sender_id = ${host}::uuid) AS self,
               sum(g.quantity)::bigint AS qty, sum(gr.coins)::bigint AS coins,
               COALESCE(sum((SELECT sum(l.delta) FROM cherry_ledger l
                              WHERE l.user_id = gr.user_id AND l.reference_id = g.id::text
                                AND l.reason IN ('GIFT_RECEIVED', 'GIFT_REVERSAL'))), 0)::bigint AS cherries,
               max(g.combo_quantity)::bigint AS combo
          FROM live_gift_recipients gr
          JOIN live_gifts g ON g.id = gr.gift_id
          JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
         WHERE gr.user_id = ${host}::uuid
           AND g.created_at >= ${from}::timestamptz AND g.created_at < ${dayStart}::timestamptz
         GROUP BY 1, 2, 3, 4, 5`,
      db.$queryRaw<{ d: string; n: number }[]>`
        SELECT to_char((g.created_at AT TIME ZONE ${zone})::date, 'YYYY-MM-DD') AS d, count(DISTINCT g.sender_id)::int AS n
          FROM live_gift_recipients gr
          JOIN live_gifts g ON g.id = gr.gift_id
          JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
         WHERE gr.user_id = ${host}::uuid AND g.sender_id <> ${host}::uuid
           AND g.created_at >= ${from}::timestamptz AND g.created_at < ${dayStart}::timestamptz
         GROUP BY 1`,
      db.$queryRaw<{ start: Date; end: Date }[]>`
        SELECT GREATEST(r.started_at, ${from}::timestamptz) AS start,
               LEAST(COALESCE(r.ended_at, r.last_heartbeat_at), ${dayStart}::timestamptz) AS "end"
          FROM live_rooms r
         WHERE r.host_user_id = ${host}::uuid AND r.started_at < ${dayStart}::timestamptz
           AND COALESCE(r.ended_at, r.last_heartbeat_at) > ${from}::timestamptz`,
      db.$queryRaw<{ v: number | null }[]>`
        SELECT avg(n)::float AS v FROM (
          SELECT count(DISTINCT a.user_id) AS n FROM live_rooms r
            JOIN live_room_audience a ON a.room_id = r.id AND a.user_id IS NOT NULL
           WHERE r.host_user_id = ${host}::uuid AND r.started_at >= ${from}::timestamptz
             AND r.started_at < ${dayStart}::timestamptz
           GROUP BY r.id) x`,
      db.$queryRaw<{ assigned: number; completed: number }[]>`
        SELECT count(*)::int AS assigned, count(*) FILTER (WHERE completed_at IS NOT NULL)::int AS completed
          FROM host_target_assignments
         WHERE user_id = ${host}::uuid AND day < ${day}::date
           AND day >= ${addDays(day, -Math.max(1, Math.floor(tuning.historyDays / 2)))}::date`,
      db.hostTargetAssignment.findMany({
        where: {
          userId: host,
          day: { gte: dateValue(addDays(day, -tuning.noRepeatDays)), lt: dateValue(day) },
        },
        select: { code: true },
      }),
      this.bandOf(db, host),
    ]);
    // Bucket everything by the host's day.
    const byDay = new Map<
      string,
      {
        gc: number;
        lc: number;
        gco: number;
        lco: number;
        sends: number;
        combo: number;
        hour: number[];
        qty: Record<string, number>;
        minutes: number;
        hourMinutes: number[];
      }
    >();
    const at = (d: string) => {
      let v = byDay.get(d);
      if (!v) {
        v = {
          gc: 0,
          lc: 0,
          gco: 0,
          lco: 0,
          sends: 0,
          combo: 0,
          hour: new Array<number>(24).fill(0),
          qty: {},
          minutes: 0,
          hourMinutes: new Array<number>(24).fill(0),
        };
        byDay.set(d, v);
      }
      return v;
    };
    for (const r of sendRows) {
      const v = at(r.d);
      const cherries = Number(r.cherries);
      if (r.lucky) {
        v.lc += cherries;
        v.lco += Number(r.coins);
      } else if (!r.self) {
        v.gc += cherries;
        v.gco += Number(r.coins);
      }
      if (r.lucky || !r.self) v.hour[r.h] = (v.hour[r.h] ?? 0) + cherries;
      if (!r.self) {
        v.sends += Number(r.qty);
        v.combo = Math.max(v.combo, Number(r.combo));
        v.qty[r.gift_code] = (v.qty[r.gift_code] ?? 0) + Number(r.qty);
      }
    }
    // Live minutes by day and hour of the host's zone (rooms split into minutes; Riyadh has no daylight saving).
    const liveHourMinutes = new Array<number>(24).fill(0);
    const fmt = new Intl.DateTimeFormat('en-CA', {
      timeZone: zone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      hourCycle: 'h23',
    });
    for (const r of rooms) {
      for (let t = r.start.getTime(); t < r.end.getTime();) {
        const parts = Object.fromEntries(fmt.formatToParts(new Date(t)).map((p) => [p.type, p.value]));
        const d = `${parts.year!}-${parts.month!}-${parts.day!}`;
        const h = Number(parts.hour) % 24;
        const next = Math.min(r.end.getTime(), Math.floor(t / 3_600_000) * 3_600_000 + 3_600_000);
        const minutes = (next - t) / 60_000;
        const v = at(d);
        v.minutes += minutes;
        v.hourMinutes[h] = (v.hourMinutes[h] ?? 0) + minutes;
        liveHourMinutes[h] = (liveHourMinutes[h] ?? 0) + minutes;
        t = next;
      }
    }
    const sup = new Map(supporters.map((s) => [s.d, s.n]));
    const days: HostDay[] = [...byDay.entries()]
      .filter(([, v]) => v.minutes > 0 || v.gc + v.lc + v.sends > 0)
      .sort((a, b) => (a[0] < b[0] ? 1 : -1))
      .map(([d, v]) => ({
        day: d,
        giftCherries: v.gc,
        luckyCherries: v.lc,
        giftCoins: v.gco,
        luckyCoins: v.lco,
        sends: v.sends,
        supporters: sup.get(d) ?? 0,
        maxCombo: v.combo,
        liveMinutes: Math.round(v.minutes),
        hourCherries: v.hour,
        giftQty: v.qty,
      }));
    return {
      band,
      days,
      liveHourMinutes,
      avgViewers: viewers[0]?.v ?? 0,
      recentAssigned: recent[0]?.assigned ?? 0,
      recentCompleted: recent[0]?.completed ?? 0,
      recentCodes: codes.map((c) => c.code),
    };
  }

  /**
   * The host's targets of `day`, fixed at the day's first read: the smart assignment from their profile, with titles,
   * the reasons and the catalogue version. Concurrent first reads compute the same picks (seeded) and keep one set.
   */
  async assignmentsFor(db: Db, host: string, day: string, dayStart: Date): Promise<HostTargetAssignment[]> {
    const where = { userId: host, day: dateValue(day) };
    const order = (rows: HostTargetAssignment[]) =>
      [...rows].sort(
        (a, b) =>
          TARGET_LEVELS.indexOf(a.level as TargetLevel) - TARGET_LEVELS.indexOf(b.level as TargetLevel),
      );
    const existing = await db.hostTargetAssignment.findMany({ where });
    if (existing.length > 0) return order(existing);
    const settings = await this.settings(db);
    const tuning = this.tuningOf(settings);
    const gifts = await this.catalogueGifts(db);
    const profile = await this.profileOf(db, host, day, dayStart, tuning);
    const e = this.economy();
    const picks = assignHostTargets(profile, gifts, e, tuning, targetSeed(host, day));
    const giftBy = new Map(gifts.map((g) => [g.code, g]));
    const categories = await db.giftCategory.findMany({ select: { code: true, nameAr: true, nameEn: true } });
    const catBy = new Map(categories.map((c) => [c.code, c]));
    const version = catalogueVersion(gifts);
    await db.hostTargetAssignment.createMany({
      data: picks.map((p) => {
        const g = p.target.subject ? giftBy.get(p.target.subject) : undefined;
        const c = p.target.subject ? catBy.get(p.target.subject) : undefined;
        const title = targetTitle(p.target, {
          giftAr: g?.nameAr,
          giftEn: g?.nameEn,
          categoryAr: c?.nameAr,
          categoryEn: c?.nameEn,
        });
        return {
          userId: host,
          day: dateValue(day),
          level: p.level,
          code: p.target.code,
          kind: p.target.kind,
          subject: p.target.subject,
          amount: BigInt(p.target.amount),
          windowFrom: p.target.window.from,
          windowTo: p.target.window.to,
          expectedCoins: BigInt(p.expectedCoins),
          rewardBps: p.rewardBps,
          rewardCherries: BigInt(p.rewardCherries),
          titleAr: title.ar.slice(0, 160),
          titleEn: title.en.slice(0, 160),
          reason: p.reason as unknown as Prisma.InputJsonValue,
          catalogueVersion: version,
        };
      }),
      skipDuplicates: true,
    });
    return order(await db.hostTargetAssignment.findMany({ where }));
  }

  /**
   * Pays a reached target once (row lock; `paid_at` set in the same transaction as the ledger row): the reward shown,
   * never more than its share of the ACTUAL profit of the sends the target counted (owner's guard). Audited
   * `host_targets.reward`. Returns the stored row after.
   */
  private async payIfReached(
    a: HostTargetAssignment,
    progress: number,
    counted: readonly SendRow[],
  ): Promise<HostTargetAssignment> {
    if (a.paidAt !== null || progress < Number(a.amount)) return a;
    const e = this.economy();
    const money: SendMoney[] = counted.map((s) => ({
      lucky: s.lucky,
      coins: s.coins,
      chargedCoins: s.charged,
      hostCherries: s.cherries,
    }));
    const profit = platformProfitUnits(money, e);
    const pay = cappedTargetReward(Number(a.rewardCherries), profit, a.rewardBps, e);
    const now = this.clock.now();
    const day = a.day.toISOString().slice(0, 10);
    try {
      return await this.prisma.$transaction(async (tx) => {
        const [locked] = await tx.$queryRaw<{ paid: boolean }[]>`
          SELECT paid_at IS NOT NULL AS paid FROM host_target_assignments
           WHERE user_id = ${a.userId}::uuid AND day = ${day}::date AND level = ${a.level} FOR UPDATE`;
        if (!locked || locked.paid) {
          return tx.hostTargetAssignment.findUniqueOrThrow({
            where: { userId_day_level: { userId: a.userId, day: a.day, level: a.level } },
          });
        }
        const microcents = profit / BigInt(e.rateCherries);
        const row = await tx.hostTargetAssignment.update({
          where: { userId_day_level: { userId: a.userId, day: a.day, level: a.level } },
          data: {
            completedAt: now,
            progress: BigInt(progress),
            profitMicrocents: microcents,
            paidCherries: BigInt(pay),
            paidAt: now,
          },
        });
        if (pay > 0) {
          await creditHostTargetCherriesIn(
            tx,
            a.userId,
            BigInt(pay),
            hostTargetRewardReference(a.level, day),
            now,
          );
        }
        await tx.auditLog.create({
          data: {
            action: AuditAction.HOST_TARGET_REWARD,
            actorUserId: null,
            targetType: 'host_target',
            targetId: `${a.userId.slice(0, 36)}:${a.level}`.slice(0, 64),
            metadata: {
              host: a.userId,
              day,
              level: a.level,
              code: a.code,
              amount: Number(a.amount),
              progress,
              sends: counted.length,
              profitUsd: Math.round(unitsUsd(profit, e) * 1e6) / 1e6,
              rewardBps: a.rewardBps,
              shownCherries: Number(a.rewardCherries),
              paidCherries: pay,
            },
          },
        });
        return row;
      });
    } catch (err) {
      const index = violatedUniqueIndex(err);
      if (index === null || !index.includes('cherry_ledger_reference_once')) throw err;
      this.logger.warn(`host target ${a.level}@${day} of ${a.userId} was paid by a concurrent read`);
      return this.prisma.hostTargetAssignment.findUniqueOrThrow({
        where: { userId_day_level: { userId: a.userId, day: a.day, level: a.level } },
      });
    }
  }

  /** The window of a target as the app shows it (null for the whole day). */
  private windowDto(from: number, to: number): HostDailyTargetDto['window'] {
    const w: TargetWindow = { from, to };
    if (isAllDay(w)) return null;
    const [a, b] = windowLabel(w).split('–');
    return { from: a!, to: b! };
  }

  /**
   * The host's three targets of today with their progress (and yesterday's unpaid ones settled), for the «تارجت»
   * chip and sheet; [] while the smart engine has not started (D277's two targets then).
   */
  async daily(host: string, lang: ContentLanguage = 'ar'): Promise<HostDailyTargetDto[]> {
    const now = this.clock.now();
    const { day } = await programWindowsIn(this.prisma, now, this.zone);
    if (!(await this.engineOn(day.date))) return [];
    // Yesterday's targets reached after the last read are settled now (their own day's sends).
    const yesterday = addDays(day.date, -1);
    const unpaid = await this.prisma.hostTargetAssignment.findMany({
      where: { userId: host, day: dateValue(yesterday), paidAt: null },
    });
    if (unpaid.length > 0) {
      const yStart = new Date(day.start.getTime() - 86_400_000);
      const sends = await this.sendsIn(this.prisma, host, yStart, day.start);
      for (const a of unpaid) {
        const rows = this.counted(a, sends);
        await this.payIfReached(a, progressOf(a.kind as TargetKind, rows), rows);
      }
    }
    const assigned = await this.assignmentsFor(this.prisma, host, day.date, day.start);
    const sends = await this.sendsIn(this.prisma, host, day.start, day.end);
    const gifts = new Map(
      (
        await this.prisma.gift.findMany({
          where: { code: { in: assigned.flatMap((a) => (a.subject ? [a.subject] : [])) } },
          select: { code: true, nameAr: true, nameEn: true, assetKey: true, imageObjectKey: true },
        })
      ).map((g) => [g.code, g]),
    );
    const cats = new Map(
      (
        await this.prisma.giftCategory.findMany({
          where: { code: { in: assigned.flatMap((a) => (a.subject ? [a.subject] : [])) } },
          select: { code: true, nameAr: true, nameEn: true },
        })
      ).map((c) => [c.code, c]),
    );
    const base = this.storage.current().publicBaseUrl;
    const out: HostDailyTargetDto[] = [];
    for (const a0 of assigned) {
      const kind = a0.kind as TargetKind;
      const rows = this.counted(a0, sends);
      const progress = progressOf(kind, rows);
      const a = await this.payIfReached(a0, progress, rows);
      const g = kind === 'GIFT_COUNT' || kind === 'GIFT_COMBO' ? gifts.get(a.subject ?? '') : undefined;
      const c = kind === 'CATEGORY_COUNT' ? cats.get(a.subject ?? '') : undefined;
      out.push({
        level: a.level as TargetLevel,
        code: a.code,
        kind,
        title: lang === 'ar' ? a.titleAr : a.titleEn,
        amount: Number(a.amount),
        progress: Math.min(progress, Number(a.amount)),
        reached: progress >= Number(a.amount),
        rewardCherries: Number(a.rewardCherries),
        rewardBps: a.rewardBps,
        paidCherries: a.paidCherries === null ? null : Number(a.paidCherries),
        locked: true,
        window: this.windowDto(a.windowFrom, a.windowTo),
        gift: g
          ? {
              code: g.code,
              name: lang === 'ar' ? g.nameAr : g.nameEn,
              assetKey: g.assetKey,
              imageUrl: giftArtUrl(base, g.imageObjectKey),
            }
          : null,
        category: c ? { code: c.code, name: lang === 'ar' ? c.nameAr : c.nameEn } : null,
      });
    }
    return out;
  }

  // ---- The panel ------------------------------------------------------------------------------------

  /** The catalogue's size now (targets and, from TasksService, tasks). */
  async targetCatalogue() {
    const gifts = await this.catalogueGifts();
    return { version: catalogueVersion(gifts), ...catalogueStats(gifts) };
  }

  /**
   * A host's targets of `day` with the reasons («لماذا هذا الهدف») and their progress / payment, for the panel. Does
   * not assign (a day nobody read has none).
   */
  async forPanel(host: string, day: string) {
    const rows = await this.prisma.hostTargetAssignment.findMany({
      where: { userId: host, day: dateValue(day) },
    });
    const windows = await programWindowsIn(this.prisma, new Date(`${day}T12:00:00.000Z`), this.zone);
    const sends =
      rows.length > 0 ? await this.sendsIn(this.prisma, host, windows.day.start, windows.day.end) : [];
    return rows
      .sort(
        (a, b) =>
          TARGET_LEVELS.indexOf(a.level as TargetLevel) - TARGET_LEVELS.indexOf(b.level as TargetLevel),
      )
      .map((a) => {
        const counted = this.counted(a, sends);
        return {
          level: a.level,
          code: a.code,
          kind: a.kind,
          subject: a.subject,
          titleAr: a.titleAr,
          titleEn: a.titleEn,
          amount: Number(a.amount),
          progress: progressOf(a.kind as TargetKind, counted),
          window: this.windowDto(a.windowFrom, a.windowTo),
          expectedCoins: Number(a.expectedCoins),
          rewardBps: a.rewardBps,
          rewardCherries: Number(a.rewardCherries),
          paidCherries: a.paidCherries === null ? null : Number(a.paidCherries),
          paidAt: a.paidAt?.toISOString() ?? null,
          profitUsd: a.profitMicrocents === null ? null : Number(a.profitMicrocents) / 100_000_000,
          catalogueVersion: a.catalogueVersion,
          reason: a.reason,
        };
      });
  }
}
