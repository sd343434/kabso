import { Inject, Injectable } from '@nestjs/common';
import { AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { cherriesValueMinor } from '../economy/economy-math.js';
import { PaymentSettingsStore } from '../payment-settings/payment-settings.store.js';
import { closeCaseIn, requestTeamRefund } from '../topup/topup-core.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import { dayKey } from './admin-stats.service.js';
import { dayBound, tableResult, window, type TableQuery } from './admin-tables.js';
import { refused, viaOf } from './admin-users.service.js';

export interface RangeQuery extends TableQuery {
  readonly from?: string | undefined;
  readonly to?: string | undefined;
}

const person = {
  select: { id: true, email: true, profile: { select: { username: true, displayName: true } } },
};
type Person = { id: string; email: string; profile: { username: string; displayName: string } | null };
const personDto = (u: Person) => ({
  id: u.id,
  username: u.profile?.username ?? '',
  displayName: u.profile?.displayName ?? '',
});

type PeriodRow = { period: string; a: bigint | number | null; b: bigint | number | null };

/** Cherry reasons that create cherries (gross issuance) and those that take them back (D179, D184). */
const ISSUE_REASONS = ['GIFT_RECEIVED', 'AGENCY_COMMISSION', 'PARENT_COMMISSION', 'TASK_REWARD'];
const REVERSAL_REASONS = ['GIFT_REVERSAL', 'AGENCY_COMMISSION_REVERSAL', 'PARENT_COMMISSION_REVERSAL'];

export interface ReportRow {
  period: string;
  agentTopupCoins: number;
  agentRevenueMinor: number;
  agentExpectedMinor: number;
  agentSalesCoins: number;
  cardCoins: number;
  cardRevenueMinor: number;
  cardRefundedMinor: number;
  hostPayoutsMinor: number;
  cherriesWithdrawn: number;
  agencyCommissionCherries: number;
  cherriesIssued: number;
  cherriesReversed: number;
  cherriesSoldToAgents: number;
  cherriesIssuedValueMinor: number;
  cardOrders: number;
  estimatedCardFeesMinor: number;
  estimatedMarginMinor: number;
}

/**
 * «المال» in the panel v2 (v1.65-social, D197, CONVENTIONS §10.60.5), FINANCE and OWNER (D275: the moderator reads the
 * agents' top-ups and the card orders, `recharge.topups.view`, without the CSV): the recharge agents'
 * top-ups (what each agent paid at the tier price), the website's card orders and Stripe cases (D190: refunds,
 * early-fraud warnings, disputes) with the team refund (`payments-admin refund`'s rule, authenticator code again)
 * and closing a case, and the financial report by day or month (Asia/Riyadh): money in from agents and cards, host
 * payouts, agency commissions, cherries issued against withdrawn, and an **estimated** margin (cash in − card
 * refunds − estimated card fees − host payouts; the cherries not withdrawn yet are shown apart).
 */
@Injectable()
export class AdminMoneyService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly auth: AdminAuthService,
    // D196 (§10.53.1): the Stripe client of the key in force now (the panel's over the env's).
    private readonly payments: PaymentSettingsStore,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private get zone(): string {
    return this.config.adminPanel.dashboardTimeZone;
  }

  private range(q: { from?: string | undefined; to?: string | undefined }) {
    const gte = dayBound(q.from, false, this.zone);
    const lt = dayBound(q.to, true, this.zone);
    return gte || lt ? { ...(gte ? { gte } : {}), ...(lt ? { lt } : {}) } : undefined;
  }

  async rechargeTopups(q: RangeQuery, ctx: AdminContext) {
    const createdAt = this.range(q);
    const text = q.q?.trim().toLowerCase();
    const where: Prisma.RechargeTopupWhereInput = {
      ...(createdAt ? { createdAt } : {}),
      ...(text
        ? {
            agent: {
              OR: [{ code: { startsWith: text } }, { user: { profile: { username: { startsWith: text } } } }],
            },
          }
        : {}),
    };
    const orderBy: Prisma.RechargeTopupOrderByWithRelationInput[] =
      q.sort === 'paidMinor'
        ? [{ paidMinor: q.order }, { id: q.order }]
        : q.sort === 'coins'
          ? [{ coins: q.order }, { id: q.order }]
          : [{ createdAt: q.order }, { id: q.order }];
    const [rows, total, sum] = await Promise.all([
      this.prisma.rechargeTopup.findMany({
        where,
        orderBy,
        ...window(q),
        select: {
          id: true,
          coins: true,
          tier: true,
          pricePerMillionMinor: true,
          expectedMinor: true,
          paidMinor: true,
          currency: true,
          first: true,
          note: true,
          createdAt: true,
          agent: { select: { userId: true, code: true, user: person } },
        },
      }),
      this.prisma.rechargeTopup.count({ where }),
      this.prisma.rechargeTopup.aggregate({
        where,
        _sum: { coins: true, paidMinor: true, expectedMinor: true },
      }),
    ]);
    const data = rows.map((t) => ({
      id: t.id,
      agent: { ...personDto(t.agent.user), code: t.agent.code },
      coins: Number(t.coins),
      tier: t.tier,
      pricePerMillionMinor: t.pricePerMillionMinor,
      expectedMinor: Number(t.expectedMinor),
      paidMinor: Number(t.paidMinor),
      currency: t.currency,
      first: t.first,
      note: t.note,
      createdAt: t.createdAt.toISOString(),
    }));
    const result = await tableResult(
      this.audit,
      ctx,
      'recharge-topups',
      q,
      data,
      total,
      [
        ['id', (r) => r.id],
        ['agent_code', (r) => r.agent.code],
        ['agent_username', (r) => r.agent.username],
        ['coins', (r) => r.coins],
        ['tier', (r) => r.tier],
        ['expected_minor', (r) => r.expectedMinor],
        ['paid_minor', (r) => r.paidMinor],
        ['currency', (r) => r.currency],
        ['first', (r) => r.first],
        ['note', (r) => r.note],
        ['created_at', (r) => r.createdAt],
      ],
      { from: q.from ?? null, to: q.to ?? null },
    );
    if (result.kind === 'csv') return result;
    return {
      kind: 'json' as const,
      body: {
        ...result.body,
        totals: {
          coins: Number(sum._sum.coins ?? 0n),
          paidMinor: Number(sum._sum.paidMinor ?? 0n),
          expectedMinor: Number(sum._sum.expectedMinor ?? 0n),
        },
      },
    };
  }

  async cardOrders(
    q: RangeQuery & { status?: 'PENDING' | 'AWAITING_FUNDS' | 'PAID' | 'EXPIRED' | 'FAILED' | undefined },
    ctx: AdminContext,
  ) {
    const createdAt = this.range(q);
    const text = q.q?.trim().toLowerCase();
    const where: Prisma.TopupOrderWhereInput = {
      ...(q.status ? { status: q.status } : {}),
      ...(createdAt ? { createdAt } : {}),
      ...(text
        ? /^[0-9a-f-]{36}$/.test(text)
          ? { id: text }
          : {
              user: {
                OR: [{ email: { startsWith: text } }, { profile: { username: { startsWith: text } } }],
              },
            }
        : {}),
    };
    const orderBy: Prisma.TopupOrderOrderByWithRelationInput[] =
      q.sort === 'amountMinor'
        ? [{ amountMinor: q.order }, { id: q.order }]
        : [{ createdAt: q.order }, { id: q.order }];
    const [rows, total] = await Promise.all([
      this.prisma.topupOrder.findMany({
        where,
        orderBy,
        ...window(q),
        include: { user: person, _count: { select: { cases: true } } },
      }),
      this.prisma.topupOrder.count({ where }),
    ]);
    const data = rows.map((o) => ({
      id: o.id,
      user: personDto(o.user),
      coins: Number(o.coins),
      amountMinor: o.amountMinor,
      currency: o.currency,
      status: o.status,
      paymentMethodType: o.paymentMethodType,
      creditedAt: o.creditedAt?.toISOString() ?? null,
      refundedMinor: o.refundedMinor,
      teamRefundedMinor: o.teamRefundedMinor,
      disputeStatus: o.disputeStatus,
      coinsReversed: Number(o.coinsReversed),
      cases: o._count.cases,
      refundable:
        o.creditedAt !== null &&
        o.stripePaymentIntentId !== null &&
        Math.max(o.refundedMinor, o.teamRefundedMinor) < o.amountMinor,
      createdAt: o.createdAt.toISOString(),
    }));
    return tableResult(
      this.audit,
      ctx,
      'card-orders',
      q,
      data,
      total,
      [
        ['id', (r) => r.id],
        ['username', (r) => r.user.username],
        ['coins', (r) => r.coins],
        ['amount_minor', (r) => r.amountMinor],
        ['currency', (r) => r.currency],
        ['status', (r) => r.status],
        ['credited_at', (r) => r.creditedAt],
        ['refunded_minor', (r) => r.refundedMinor],
        ['team_refunded_minor', (r) => r.teamRefundedMinor],
        ['dispute_status', (r) => r.disputeStatus],
        ['created_at', (r) => r.createdAt],
      ],
      { status: q.status ?? null, from: q.from ?? null, to: q.to ?? null },
    );
  }

  async cases(q: TableQuery & { status?: 'OPEN' | 'CLOSED' | undefined }, ctx: AdminContext) {
    const where: Prisma.TopupCaseWhereInput = q.status ? { status: q.status } : {};
    const [rows, total] = await Promise.all([
      this.prisma.topupCase.findMany({
        where,
        orderBy: [{ createdAt: q.order }, { id: q.order }],
        ...window(q),
        include: { user: person, order: { select: { amountMinor: true, currency: true } } },
      }),
      this.prisma.topupCase.count({ where }),
    ]);
    const data = rows.map((c) => ({
      id: c.id,
      orderId: c.orderId,
      kind: c.kind,
      status: c.status,
      outcome: c.outcome,
      coinsReversed: Number(c.coinsReversed),
      amountMinor: c.order.amountMinor,
      currency: c.order.currency,
      note: c.note,
      user: personDto(c.user),
      createdAt: c.createdAt.toISOString(),
      closedAt: c.closedAt?.toISOString() ?? null,
    }));
    return tableResult(this.audit, ctx, 'topup-cases', q, data, total, [
      ['id', (r) => r.id],
      ['order_id', (r) => r.orderId],
      ['kind', (r) => r.kind],
      ['status', (r) => r.status],
      ['outcome', (r) => r.outcome],
      ['coins_reversed', (r) => r.coinsReversed],
      ['username', (r) => r.user.username],
      ['created_at', (r) => r.createdAt],
    ]);
  }

  /** `payments-admin refund` from the panel: the authenticator code again; the coins come back by the webhook. */
  async refund(orderId: string, body: { reason: string; totpCode: string }, ctx: AdminContext) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const { api } = await this.payments.active();
    if (!api) throw new AppException(ErrorCode.TOPUP_UNAVAILABLE);
    try {
      return await requestTeamRefund(this.prisma, api, orderId, body.reason, new Date(), viaOf(ctx));
    } catch (err) {
      if (err instanceof RangeError) throw refused(err.message);
      throw err;
    }
  }

  async closeCase(id: string, note: string, ctx: AdminContext) {
    const done = await this.prisma.$transaction((tx) =>
      closeCaseIn(tx, id, new Date(), note, null, ctx.userId, viaOf(ctx)),
    );
    if (!done) throw refused('The case does not exist or is already closed.');
    return { status: 'CLOSED' };
  }

  // ---- the financial report ------------------------------------------------------------------------------------

  /** The report rows of [from, to] (local days) by day or month, every period present (zeros included). */
  async report(
    granularity: 'day' | 'month',
    from: string,
    to: string,
  ): Promise<{ rows: ReportRow[]; totals: ReportRow }> {
    const zone = this.zone;
    const gte = dayBound(from, false, zone)!;
    const lt = dayBound(to, true, zone)!;
    const fmt = granularity === 'day' ? 'YYYY-MM-DD' : 'YYYY-MM';
    const p = (col: string) => Prisma.sql`to_char(timezone(${zone}::text, ${Prisma.raw(col)}), ${fmt})`;
    const q = (sql: Prisma.Sql) => this.prisma.$queryRaw<PeriodRow[]>(sql);
    const [topups, sales, cards, payouts, commissions, issued, reversed, sold] = await Promise.all([
      q(Prisma.sql`SELECT ${p('created_at')} AS period, sum(coins) AS a, sum(paid_minor) AS b FROM recharge_topups
                     WHERE created_at >= ${gte} AND created_at < ${lt} GROUP BY 1`),
      q(Prisma.sql`SELECT ${p('created_at')} AS period, sum(coins) AS a, 0 AS b FROM recharge_sales
                     WHERE created_at >= ${gte} AND created_at < ${lt} GROUP BY 1`),
      q(Prisma.sql`SELECT ${p('credited_at')} AS period, sum(coins) AS a, sum(amount_minor) AS b FROM topup_orders
                     WHERE credited_at IS NOT NULL AND credited_at >= ${gte} AND credited_at < ${lt} GROUP BY 1`),
      q(Prisma.sql`SELECT ${p('decided_at')} AS period, sum(amount_minor) AS a, sum(cherries) AS b FROM cherry_withdrawals
                     WHERE status = 'PAID' AND decided_at >= ${gte} AND decided_at < ${lt} GROUP BY 1`),
      q(Prisma.sql`SELECT ${p('created_at')} AS period, sum(commission + parent_commission) AS a, 0 AS b FROM agency_earnings
                     WHERE reversed_at IS NULL AND created_at >= ${gte} AND created_at < ${lt} GROUP BY 1`),
      q(Prisma.sql`SELECT ${p('created_at')} AS period, sum(delta) AS a, 0 AS b FROM cherry_ledger
                     WHERE created_at >= ${gte} AND created_at < ${lt} AND delta > 0
                       AND reason::text = ANY(${ISSUE_REASONS}::text[]) GROUP BY 1`),
      q(Prisma.sql`SELECT ${p('created_at')} AS period, -sum(delta) AS a, 0 AS b FROM cherry_ledger
                     WHERE created_at >= ${gte} AND created_at < ${lt}
                       AND reason::text = ANY(${REVERSAL_REASONS}::text[]) GROUP BY 1`),
      q(Prisma.sql`SELECT ${p('created_at')} AS period, -sum(delta) AS a, 0 AS b FROM cherry_ledger
                     WHERE created_at >= ${gte} AND created_at < ${lt} AND reason = 'RECHARGE_SALE' GROUP BY 1`),
    ]);
    // Card refunds by the day the order was credited (what that period's sales gave back).
    // Owner answer CP-039 Q3: the card orders credited per period (the fixed part of the estimated fees).
    const orderCounts =
      await q(Prisma.sql`SELECT ${p('credited_at')} AS period, count(*) AS a, 0 AS b FROM topup_orders
                     WHERE credited_at IS NOT NULL AND credited_at >= ${gte} AND credited_at < ${lt} GROUP BY 1`);
    const refunds =
      await q(Prisma.sql`SELECT ${p('credited_at')} AS period, sum(GREATEST(refunded_minor, team_refunded_minor)) AS a, 0 AS b
                     FROM topup_orders WHERE credited_at IS NOT NULL AND credited_at >= ${gte} AND credited_at < ${lt} GROUP BY 1`);
    // Agent revenue at the tier price (what the top-ups should have brought) for the same rows.
    const expected =
      await q(Prisma.sql`SELECT ${p('created_at')} AS period, sum(expected_minor) AS a, 0 AS b FROM recharge_topups
                     WHERE created_at >= ${gte} AND created_at < ${lt} GROUP BY 1`);
    const map = (rows: PeriodRow[], k: 'a' | 'b') => new Map(rows.map((r) => [r.period, Number(r[k] ?? 0)]));
    const m = {
      topupCoins: map(topups, 'a'),
      topupPaid: map(topups, 'b'),
      expected: map(expected, 'a'),
      sales: map(sales, 'a'),
      cardCoins: map(cards, 'a'),
      cardMinor: map(cards, 'b'),
      cardOrders: map(orderCounts, 'a'),
      refunds: map(refunds, 'a'),
      payouts: map(payouts, 'a'),
      withdrawn: map(payouts, 'b'),
      commissions: map(commissions, 'a'),
      issued: map(issued, 'a'),
      reversed: map(reversed, 'a'),
      sold: map(sold, 'a'),
    };
    const { rateCherries, rateMinor } = this.config.economy;
    const fee = this.config.adminPanel.reportCardFee;
    const row = (period: string): ReportRow => {
      const g = (x: Map<string, number>) => x.get(period) ?? 0;
      const agentRevenueMinor = g(m.topupPaid);
      const cardRevenueMinor = g(m.cardMinor);
      const cardRefundedMinor = g(m.refunds);
      const hostPayoutsMinor = g(m.payouts);
      const cherriesIssued = g(m.issued);
      const cardOrders = g(m.cardOrders);
      // Owner answer CP-039 Q3: an ESTIMATE of the card fees (percent of the amount + a fixed fee per order).
      const estimatedCardFeesMinor =
        Math.round((cardRevenueMinor * fee.bps) / 10_000) + cardOrders * fee.fixedMinor;
      return {
        period,
        agentTopupCoins: g(m.topupCoins),
        agentRevenueMinor,
        agentExpectedMinor: g(m.expected),
        agentSalesCoins: g(m.sales),
        cardCoins: g(m.cardCoins),
        cardRevenueMinor,
        cardRefundedMinor,
        hostPayoutsMinor,
        cherriesWithdrawn: g(m.withdrawn),
        agencyCommissionCherries: g(m.commissions),
        cherriesIssued,
        cherriesReversed: g(m.reversed),
        cherriesSoldToAgents: g(m.sold),
        cherriesIssuedValueMinor: Number(cherriesValueMinor(BigInt(cherriesIssued), rateCherries, rateMinor)),
        cardOrders,
        estimatedCardFeesMinor,
        estimatedMarginMinor:
          agentRevenueMinor +
          cardRevenueMinor -
          cardRefundedMinor -
          estimatedCardFeesMinor -
          hostPayoutsMinor,
      };
    };
    const periods = this.periods(granularity, gte, lt);
    const rows = periods.map(row);
    const totals = rows.reduce<ReportRow>(
      (acc, r) => {
        for (const k of Object.keys(r) as (keyof ReportRow)[]) if (k !== 'period') acc[k] += r[k];
        return acc;
      },
      { ...row('__none__'), period: 'total' },
    );
    totals.cherriesIssuedValueMinor = Number(
      cherriesValueMinor(BigInt(totals.cherriesIssued), rateCherries, rateMinor),
    );
    return { rows, totals };
  }

  private periods(granularity: 'day' | 'month', gte: Date, lt: Date): string[] {
    const keys: string[] = [];
    for (let t = gte.getTime() + 43_200_000; t < lt.getTime(); t += 86_400_000) {
      const day = dayKey(new Date(t), this.zone);
      const key = granularity === 'day' ? day : day.slice(0, 7);
      if (keys[keys.length - 1] !== key) keys.push(key);
    }
    return keys;
  }

  async reportTable(
    q: { granularity: 'day' | 'month'; from: string; to: string; format: 'json' | 'csv' },
    ctx: AdminContext,
  ) {
    const { rows, totals } = await this.report(q.granularity, q.from, q.to);
    const body = {
      granularity: q.granularity,
      from: q.from,
      to: q.to,
      timeZone: this.zone,
      currency: this.config.economy.currency,
      rate: { cherries: this.config.economy.rateCherries, minor: this.config.economy.rateMinor },
      cardFee: this.config.adminPanel.reportCardFee,
      rows,
      totals,
    };
    if (q.format !== 'csv') return { kind: 'json' as const, body };
    const cols = Object.keys(totals) as (keyof ReportRow)[];
    const tq = {
      page: 1,
      pageSize: rows.length || 1,
      sort: 'period',
      order: 'asc' as const,
      format: 'csv' as const,
    };
    return tableResult(
      this.audit,
      ctx,
      `finance-report-${q.granularity}`,
      tq,
      [...rows, totals],
      rows.length,
      cols.map((k) => [k.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`), (r: ReportRow) => r[k]] as const),
      { from: q.from, to: q.to, granularity: q.granularity },
    );
  }
}
