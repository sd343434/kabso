import { Inject, Injectable } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { REDIS } from '../../redis/redis.module.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { dayKey } from '../admin-panel/admin-stats.service.js';
import { dayBound } from '../admin-panel/admin-tables.js';
import { isUuid } from '../auth/tokens.js';
import { assertKabsoOwner } from './owner-core.js';
import type { OwnerMeta } from './owner-profile.service.js';
import {
  cardFees,
  CHERRY_COST_REASONS,
  CHERRY_LINES,
  cherryMoney,
  coinMoney,
  fixedCostShare,
  FREE_COIN_REASONS,
  STAFF_COMPENSATION_COIN_REASONS,
  AMBASSADOR_REWARD_CHERRY_REASONS,
  AMBASSADOR_REWARD_COIN_REASONS,
  GIFT_OWNER_COIN_REASONS,
  isDayKey,
  periodsOf,
  PROFIT_DEDUCTIONS,
  PROFIT_FIRST_DAY,
  type FixedCostTerm,
  type ProfitDeduction,
  type ProfitPeriod,
} from './owner-profit-rules.js';

/** `OwnerFixedCost` (§10.112.10). */
export type FixedCostDto = {
  id: string;
  name: string;
  monthlyMinor: number;
  currency: 'USD';
  activeFrom: string;
  activeTo: string | null;
  createdAt: string;
  updatedAt: string;
};

/** `OwnerProfitPeriod` (§10.112.10). */
export interface ProfitPeriodDto extends ProfitPeriod {
  before: {
    amountMinor: number;
    cardChargedMinor: number;
    refundsMinor: number;
    chargebacksMinor: number;
    agentsMinor: number;
  };
  deductions: {
    key: ProfitDeduction;
    amountMinor: number;
    cherries: number | null;
    coins: number | null;
    orders: number | null;
  }[];
  fixedCosts: {
    amountMinor: number;
    items: { id: string; name: string; monthlyMinor: number; days: number; shareMinor: number }[];
  };
  after: { amountMinor: number };
  info: {
    agentCoins: number;
    agentCoinsRetailMinor: number;
  };
  otherCurrencies: {
    currency: string;
    beforeMinor: number;
    cardChargedMinor: number;
    refundsMinor: number;
    chargebacksMinor: number;
    agentsMinor: number;
    deductionsMinor: number;
    afterMinor: number;
  }[];
}

/** `OwnerProfit` (§10.112.10). */
export interface ProfitDto {
  timeZone: string;
  currency: 'USD';
  today: string;
  day: ProfitPeriodDto;
  month: ProfitPeriodDto;
  rates: {
    cherries: number;
    minor: number;
    cherryCurrency: string;
    cardFeeBps: number;
    cardFeeFixedMinor: number;
    coinRetailUsdPerMillion: number;
    coinValueMinorPerMillion: number;
  };
  generatedAt: string;
}

/** «الربح» is cached this long per day (and dropped when a fixed cost changes). */
export const PROFIT_CACHE_SECONDS = 60;
const PROFIT_GEN_KEY = 'owner:profit:gen';
const MAX_FIXED_COSTS = 100;

const name = z.string().trim().min(1).max(60);
const money = z.number().int().min(1).max(100_000_000_000);
const day = z.string().refine(isDayKey, { params: { issue: 'invalid_value' } });
const currency = z.literal('USD');
export const createFixedCostSchema = z
  .strictObject({
    name,
    monthlyMinor: money,
    currency: currency.optional(),
    activeFrom: day.optional(),
    activeTo: day.nullable().optional(),
  })
  .refine((v) => !v.activeFrom || !v.activeTo || v.activeTo >= v.activeFrom, {
    path: ['activeTo'],
    params: { issue: 'invalid_value' },
  });
export const updateFixedCostSchema = z
  .strictObject({
    name: name.optional(),
    monthlyMinor: money.optional(),
    currency: currency.optional(),
    activeFrom: day.optional(),
    activeTo: day.nullable().optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { params: { issue: 'required' } });
const profitQuerySchema = z.strictObject({ day: day.optional() });

function parse<T extends z.ZodType>(schema: T, body: unknown): z.output<T> {
  const parsed = schema.safeParse(body ?? {});
  if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
  return parsed.data;
}

const dateOf = (key: string) => new Date(`${key}T00:00:00.000Z`);
const keyOf = (d: Date) => d.toISOString().slice(0, 10);
const num = (v: bigint | number | null | undefined) => Number(v ?? 0);

type Row = {
  id: string;
  name: string;
  monthlyMinor: bigint;
  currency: string;
  activeFrom: Date;
  activeTo: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

function costDto(r: Row): FixedCostDto {
  return {
    id: r.id,
    name: r.name,
    monthlyMinor: Number(r.monthlyMinor),
    currency: 'USD',
    activeFrom: keyOf(r.activeFrom),
    activeTo: r.activeTo ? keyOf(r.activeTo) : null,
    createdAt: r.createdAt.toISOString(),
    updatedAt: r.updatedAt.toISOString(),
  };
}

/**
 * v1.95-social (D301 follow-up, owner 2026-11-07: «ان تزيل نسب الجميع لكون ربح نهائي وضعها قبل وبعد … تكاليف ثابتة …
 * يتم تقسيمها على الشهر»; CONVENTIONS §10.112.10): «الربح» on «لوحة المؤسس» — the money Kabso received («قبل», the
 * PP-58 definition), every share it owes from the real ledgers in the period, the estimated card fees, the owner's fixed
 * monthly costs prorated by day, and what is left («بعد», may be negative). Owner only (403 `OWNER_ONLY`). The fixed
 * costs are managed by the owner in the app and in the panel (`owner.costs`, OWNER), audited.
 */
@Injectable()
export class OwnerProfitService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private get zone(): string {
    return this.config.adminPanel.dashboardTimeZone;
  }

  // ---- «الربح» -----------------------------------------------------------------------------------------------------

  /** `GET /owner/profit?day=`: owner only; the day (default today) and its month. */
  async profit(userId: string, query: unknown): Promise<ProfitDto> {
    await assertKabsoOwner(this.prisma, userId);
    const q = parse(profitQuerySchema, query);
    const now = this.clock.now();
    const today = dayKey(now, this.zone);
    const day = q.day ?? today;
    if (day > today || day < PROFIT_FIRST_DAY) {
      throw AppException.validation([{ field: 'day', issue: 'out_of_range' }]);
    }
    const gen = (await this.redis.get(PROFIT_GEN_KEY).catch(() => null)) ?? '0';
    const key = `owner:profit:v1:${gen}:${today}:${day}`;
    const cached = await this.redis.get(key).catch(() => null);
    if (cached) return JSON.parse(cached) as ProfitDto;
    const fresh = await this.compute(day, today, now);
    await this.redis.set(key, JSON.stringify(fresh), 'EX', PROFIT_CACHE_SECONDS).catch(() => undefined);
    return fresh;
  }

  /** The numbers of `day` and its month, `today` being the current local day (exported for the tests). */
  async compute(day: string, today: string, now: Date): Promise<ProfitDto> {
    const periods = periodsOf(day, today);
    const costs = await this.prisma.ownerFixedCost.findMany({
      where: {
        activeFrom: { lte: dateOf(periods.month.to) },
        OR: [{ activeTo: null }, { activeTo: { gte: dateOf(periods.month.from) } }],
      },
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
    });
    const [d, m] = await Promise.all([this.period(periods.day, costs), this.period(periods.month, costs)]);
    const e = this.config.economy;
    const fee = this.config.adminPanel.reportCardFee;
    return {
      timeZone: this.zone,
      currency: 'USD',
      today,
      day: d,
      month: m,
      rates: {
        cherries: e.rateCherries,
        minor: e.rateMinor,
        cherryCurrency: e.currency,
        cardFeeBps: fee.bps,
        cardFeeFixedMinor: fee.fixedMinor,
        coinRetailUsdPerMillion: e.coinRetailUsdPerMillion,
        coinValueMinorPerMillion: this.config.adminPanel.ownerProfitCoinMinorPerMillion,
      },
      generatedAt: now.toISOString(),
    };
  }

  private async period(p: ProfitPeriod, costs: Row[]): Promise<ProfitPeriodDto> {
    const gte = dayBound(p.from, false, this.zone)!;
    const lt = dayBound(p.to, true, this.zone)!;
    const [cards, agents, cherries, free, royalties, compensations, ambassadorRewards] = await Promise.all([
      // The store's card orders credited in the period, by currency: charged, refunded (the team's or Stripe's,
      // whichever is larger), held by an open or lost dispute (never more than what is left), and their count.
      this.prisma.$queryRaw<
        { currency: string; charged: bigint; refunds: bigint; chargebacks: bigint; orders: bigint }[]
      >`
        SELECT upper(currency) AS currency, sum(amount_minor)::bigint AS charged,
               sum(GREATEST(refunded_minor, team_refunded_minor))::bigint AS refunds,
               sum(CASE WHEN dispute_status IS NOT NULL
                         AND dispute_status NOT IN ('won', 'warning_closed', 'prevented')
                        THEN GREATEST(LEAST(dispute_amount_minor,
                               amount_minor - GREATEST(refunded_minor, team_refunded_minor)), 0)
                        ELSE 0 END)::bigint AS chargebacks,
               count(*)::bigint AS orders
          FROM topup_orders
         WHERE credited_at IS NOT NULL AND credited_at >= ${gte} AND credited_at < ${lt}
         GROUP BY 1`,
      // What agents paid Kabso for their coin stock (D185), by currency.
      this.prisma.$queryRaw<{ currency: string; paid: bigint; coins: bigint }[]>`
        SELECT upper(currency) AS currency, sum(paid_minor)::bigint AS paid, sum(coins)::bigint AS coins
          FROM recharge_topups WHERE created_at >= ${gte} AND created_at < ${lt} GROUP BY 1`,
      // Every cherry credited (net of reversals) in the period, by reason.
      this.prisma.$queryRaw<{ reason: string; n: bigint }[]>`
        SELECT reason::text AS reason, sum(delta)::bigint AS n FROM cherry_ledger
         WHERE created_at >= ${gte} AND created_at < ${lt}
           AND reason::text = ANY(${[...CHERRY_COST_REASONS]}::text[])
         GROUP BY 1`,
      // The free coins given (for information).
      this.prisma.$queryRaw<{ n: bigint | null }[]>`
        SELECT sum(delta)::bigint AS n FROM wallet_ledger
         WHERE reason IN (${Prisma.join(FREE_COIN_REASONS.map((r) => Prisma.sql`${r}::wallet_ledger_reason`))})
           AND created_at >= ${gte} AND created_at < ${lt}`,
      // v1.100-social (D312): the custom gift owners' coin shares, net of claw-backs (`wallet_ledger_gift_owner_idx`).
      this.prisma.$queryRaw<{ n: bigint | null }[]>`
        SELECT sum(delta)::bigint AS n FROM wallet_ledger
         WHERE reason IN (${Prisma.join(GIFT_OWNER_COIN_REASONS.map((r) => Prisma.sql`${r}::wallet_ledger_reason`))})
           AND created_at >= ${gte} AND created_at < ${lt}`,
      // v1.139-social (D387, §10.176.4): the coin compensations (`wallet_ledger_staff_compensation_idx`).
      this.prisma.$queryRaw<{ n: bigint | null }[]>`
        SELECT sum(delta)::bigint AS n FROM wallet_ledger
         WHERE reason IN (${Prisma.join(STAFF_COMPENSATION_COIN_REASONS.map((r) => Prisma.sql`${r}::wallet_ledger_reason`))})
           AND created_at >= ${gte} AND created_at < ${lt}`,
      // v1.141-social (D390, §10.179.10): the ambassadors' coin rewards.
      this.prisma.$queryRaw<{ n: bigint | null }[]>`
        SELECT sum(delta)::bigint AS n FROM wallet_ledger
         WHERE reason IN (${Prisma.join(AMBASSADOR_REWARD_COIN_REASONS.map((r) => Prisma.sql`${r}::wallet_ledger_reason`))})
           AND created_at >= ${gte} AND created_at < ${lt}`,
    ]);
    const e = this.config.economy;
    const fee = this.config.adminPanel.reportCardFee;
    type Money = {
      charged: bigint;
      refunds: bigint;
      chargebacks: bigint;
      orders: bigint;
      agents: bigint;
      coins: bigint;
    };
    const byCurrency = new Map<string, Money>();
    const line = (c: string): Money => {
      const v = byCurrency.get(c) ?? {
        charged: 0n,
        refunds: 0n,
        chargebacks: 0n,
        orders: 0n,
        agents: 0n,
        coins: 0n,
      };
      byCurrency.set(c, v);
      return v;
    };
    for (const r of cards) {
      const l = line(r.currency);
      l.charged += BigInt(r.charged);
      l.refunds += BigInt(r.refunds);
      l.chargebacks += BigInt(r.chargebacks);
      l.orders += BigInt(r.orders);
    }
    for (const r of agents) {
      const l = line(r.currency);
      l.agents += BigInt(r.paid);
      l.coins += BigInt(r.coins);
    }
    const reasons = new Map(cherries.map((r) => [r.reason, BigInt(r.n)]));
    const cherryLines = new Map<ProfitDeduction, { cherries: bigint; minor: bigint }>();
    for (const [k, rs] of Object.entries(CHERRY_LINES) as [ProfitDeduction, readonly string[]][]) {
      const c = rs.reduce((s, r) => s + (reasons.get(r) ?? 0n), 0n);
      cherryLines.set(k, { cherries: c, minor: cherryMoney(c, e.rateCherries, e.rateMinor) });
    }
    // D390 follow-up: the ambassadors' cherry rewards (in AMBASSADOR_REWARDS, not a cherry line of their own).
    const ambCherries = AMBASSADOR_REWARD_CHERRY_REASONS.reduce((s, r) => s + (reasons.get(r) ?? 0n), 0n);
    const ambCherryMinor = cherryMoney(ambCherries, e.rateCherries, e.rateMinor);
    const cherryTotal = [...cherryLines.values()].reduce((s, v) => s + v.minor, 0n) + ambCherryMinor;
    const cherryInUsd = e.currency.toUpperCase() === 'USD';
    const before = (l: Money) => l.charged - l.refunds - l.chargebacks + l.agents;

    const usd = byCurrency.get('USD') ?? line('USD');
    const usdFees = cardFees(usd.charged, usd.orders, fee);
    const freeCoins = BigInt(free[0]?.n ?? 0n) + BigInt(royalties[0]?.n ?? 0n);
    const coinValue = coinMoney(freeCoins, this.config.adminPanel.ownerProfitCoinMinorPerMillion);
    const compCoins = BigInt(compensations[0]?.n ?? 0n);
    const compValue = coinMoney(compCoins, this.config.adminPanel.ownerProfitCoinMinorPerMillion);
    const ambCoins = BigInt(ambassadorRewards[0]?.n ?? 0n);
    const ambValue = coinMoney(ambCoins, this.config.adminPanel.ownerProfitCoinMinorPerMillion);
    const deductions: ProfitPeriodDto['deductions'] = PROFIT_DEDUCTIONS.map((key) => {
      if (key === 'CARD_FEES')
        return { key, amountMinor: num(usdFees), cherries: null, coins: null, orders: num(usd.orders) };
      if (key === 'COIN_REWARDS')
        return { key, amountMinor: num(coinValue), cherries: null, coins: num(freeCoins), orders: null };
      if (key === 'STAFF_COMPENSATIONS')
        return { key, amountMinor: num(compValue), cherries: null, coins: num(compCoins), orders: null };
      if (key === 'AMBASSADOR_REWARDS')
        return {
          key,
          amountMinor: num(ambValue) + (cherryInUsd ? num(ambCherryMinor) : 0),
          cherries: num(ambCherries),
          coins: num(ambCoins),
          orders: null,
        };
      const v = cherryLines.get(key)!;
      return {
        key,
        amountMinor: cherryInUsd ? num(v.minor) : 0,
        cherries: num(v.cherries),
        coins: null,
        orders: null,
      };
    });
    const items = costs
      .map((c) => {
        const term: FixedCostTerm = {
          monthlyMinor: c.monthlyMinor,
          activeFrom: keyOf(c.activeFrom),
          activeTo: c.activeTo ? keyOf(c.activeTo) : null,
        };
        const share = fixedCostShare(term, p);
        const from = term.activeFrom > p.from ? term.activeFrom : p.from;
        const to = term.activeTo !== null && term.activeTo < p.to ? term.activeTo : p.to;
        const days = from > to ? 0 : Number(to.slice(8)) - Number(from.slice(8)) + 1;
        return { id: c.id, name: c.name, monthlyMinor: Number(c.monthlyMinor), days, shareMinor: num(share) };
      })
      .filter((i) => i.days > 0);
    const fixed = items.reduce((s, i) => s + i.shareMinor, 0);
    const usdBefore = before(usd);
    const deducted = deductions.reduce((s, d) => s + d.amountMinor, 0);
    const otherCurrencies = [...byCurrency.entries()]
      .filter(([c]) => c !== 'USD')
      .map(([c, l]) => {
        const cherry = !cherryInUsd && c === e.currency.toUpperCase() ? cherryTotal : 0n;
        const ded = cardFees(l.charged, l.orders, fee) + cherry;
        return {
          currency: c,
          beforeMinor: num(before(l)),
          cardChargedMinor: num(l.charged),
          refundsMinor: num(l.refunds),
          chargebacksMinor: num(l.chargebacks),
          agentsMinor: num(l.agents),
          deductionsMinor: num(ded),
          afterMinor: num(before(l) - ded),
        };
      })
      .filter((o) => o.beforeMinor !== 0 || o.deductionsMinor !== 0)
      .sort((a, b) => a.currency.localeCompare(b.currency));
    if (
      !cherryInUsd &&
      cherryTotal !== 0n &&
      !otherCurrencies.some((o) => o.currency === e.currency.toUpperCase())
    ) {
      otherCurrencies.push({
        currency: e.currency.toUpperCase(),
        beforeMinor: 0,
        cardChargedMinor: 0,
        refundsMinor: 0,
        chargebacksMinor: 0,
        agentsMinor: 0,
        deductionsMinor: num(cherryTotal),
        afterMinor: -num(cherryTotal),
      });
    }
    const retail = (coins: bigint) =>
      Math.round((Number(coins) * e.coinRetailUsdPerMillion * 100) / 1_000_000);
    return {
      ...p,
      before: {
        amountMinor: num(usdBefore),
        cardChargedMinor: num(usd.charged),
        refundsMinor: num(usd.refunds),
        chargebacksMinor: num(usd.chargebacks),
        agentsMinor: num(usd.agents),
      },
      deductions,
      fixedCosts: { amountMinor: fixed, items },
      after: { amountMinor: num(usdBefore) - deducted - fixed },
      info: {
        agentCoins: num(usd.coins),
        agentCoinsRetailMinor: retail(usd.coins),
      },
      otherCurrencies,
    };
  }

  // ---- «تكاليف ثابتة» ----------------------------------------------------------------------------------------------

  /** Every fixed cost, the active ones first (then by name). */
  async listCosts(): Promise<{ items: FixedCostDto[] }> {
    const today = dateOf(dayKey(this.clock.now(), this.zone));
    const rows = await this.prisma.ownerFixedCost.findMany({ orderBy: [{ name: 'asc' }, { id: 'asc' }] });
    const active = (r: Row) => r.activeFrom <= today && (r.activeTo === null || r.activeTo >= today);
    return { items: [...rows.filter(active), ...rows.filter((r) => !active(r))].map(costDto) };
  }

  /** `GET /owner/fixed-costs` (owner). */
  async listCostsFor(userId: string): Promise<{ items: FixedCostDto[] }> {
    await assertKabsoOwner(this.prisma, userId);
    return this.listCosts();
  }

  async createCost(actor: CostActor, body: unknown): Promise<FixedCostDto> {
    await this.assertActor(actor);
    const input = parse(createFixedCostSchema, body);
    const from = input.activeFrom ?? dayKey(this.clock.now(), this.zone);
    if (input.activeTo && input.activeTo < from) {
      throw AppException.validation([{ field: 'activeTo', issue: 'invalid_value' }]);
    }
    const row = await this.prisma.$transaction(async (tx) => {
      const count = await tx.ownerFixedCost.count();
      if (count >= MAX_FIXED_COSTS) throw AppException.validation([{ field: 'name', issue: 'too_many' }]);
      const created = await tx.ownerFixedCost.create({
        data: {
          name: input.name,
          monthlyMinor: BigInt(input.monthlyMinor),
          activeFrom: dateOf(from),
          activeTo: input.activeTo ? dateOf(input.activeTo) : null,
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.OWNER_FIXED_COST_CREATE,
        actorUserId: actor.userId,
        targetType: 'owner_fixed_cost',
        targetId: created.id,
        metadata: { after: costDto(created), via: actor.via },
        ip: actor.ip,
        requestId: actor.requestId,
      });
      return created;
    });
    await this.bump();
    return costDto(row);
  }

  async updateCost(actor: CostActor, id: string, body: unknown): Promise<FixedCostDto> {
    await this.assertActor(actor);
    const input = parse(updateFixedCostSchema, body);
    const current = await this.rowOf(id);
    const from = input.activeFrom ?? keyOf(current.activeFrom);
    const to =
      input.activeTo === undefined ? (current.activeTo ? keyOf(current.activeTo) : null) : input.activeTo;
    if (to !== null && to < from)
      throw AppException.validation([{ field: 'activeTo', issue: 'invalid_value' }]);
    const row = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.ownerFixedCost.update({
        where: { id: current.id },
        data: {
          ...(input.name !== undefined ? { name: input.name } : {}),
          ...(input.monthlyMinor !== undefined ? { monthlyMinor: BigInt(input.monthlyMinor) } : {}),
          activeFrom: dateOf(from),
          activeTo: to ? dateOf(to) : null,
          updatedAt: this.clock.now(),
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.OWNER_FIXED_COST_UPDATE,
        actorUserId: actor.userId,
        targetType: 'owner_fixed_cost',
        targetId: updated.id,
        metadata: { before: costDto(current), after: costDto(updated), via: actor.via },
        ip: actor.ip,
        requestId: actor.requestId,
      });
      return updated;
    });
    await this.bump();
    return costDto(row);
  }

  async deleteCost(actor: CostActor, id: string): Promise<void> {
    await this.assertActor(actor);
    const current = await this.rowOf(id);
    await this.prisma.$transaction(async (tx) => {
      await tx.ownerFixedCost.delete({ where: { id: current.id } });
      await this.audit.recordIn(tx, {
        action: AuditAction.OWNER_FIXED_COST_DELETE,
        actorUserId: actor.userId,
        targetType: 'owner_fixed_cost',
        targetId: current.id,
        metadata: { before: costDto(current), via: actor.via },
        ip: actor.ip,
        requestId: actor.requestId,
      });
    });
    await this.bump();
  }

  /** The app's owner (the panel's OWNER is checked by its capability). */
  private async assertActor(actor: CostActor): Promise<void> {
    if (actor.via === 'app') await assertKabsoOwner(this.prisma, actor.userId);
  }

  private async rowOf(id: string): Promise<Row> {
    if (!isUuid(id)) throw new AppException(ErrorCode.NOT_FOUND);
    const row = await this.prisma.ownerFixedCost.findUnique({ where: { id: id.toLowerCase() } });
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    return row;
  }

  /** A fixed cost changed: every cached «الربح» is stale. */
  private async bump(): Promise<void> {
    await this.redis.incr(PROFIT_GEN_KEY).catch(() => undefined);
  }
}

/** Who changes a fixed cost: the owner in the app, or an OWNER in the panel. */
export interface CostActor {
  readonly userId: string;
  readonly via: 'app' | 'panel';
  readonly ip: string | null;
  readonly requestId: string | null;
}

export const appActor = (userId: string, meta: OwnerMeta): CostActor => ({ userId, via: 'app', ...meta });
export const panelActor = (admin: AdminContext): CostActor => ({
  userId: admin.userId,
  via: 'panel',
  ip: admin.ip,
  requestId: admin.requestId,
});
