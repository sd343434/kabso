import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import type { z } from 'zod';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma, type RechargeOrder, type RechargeOrderMessage } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { FxRatesService } from '../fx/fx-rates.service.js';
import { priceRateOf } from '../fx/fx.rules.js';
import { MediaService } from '../media/media.service.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import {
  agentSideIn,
  cancelIn,
  confirmIn,
  expireDueOrders,
  expireIfDueIn,
  lockOrderIn,
  messageIn,
  notifyOrderIn,
  orderImageKey,
  OrderStateError,
  partiesIn,
  systemLineIn,
} from './recharge-order-core.js';
import {
  allowedActions,
  createOrderSchema,
  disputeOpensAt,
  formatMinor,
  formatRate,
  markPaidSchema,
  messagesQuerySchema,
  orderMessageSchema,
  ordersQuerySchema,
  paymentDetailsSchema,
  quote,
  quoteQuerySchema,
  reasonBodySchema,
  type OrderAction,
  type OrderStatus,
  type Side,
} from './recharge-order-rules.js';
import { limitedStaffAmong } from '../live/live-staff.js';
import { moveStockIn } from './recharge-core.js';
import {
  agentSideBlock,
  normalizeAgentCode,
  type AgentSideBlock,
  type EmployeeJob,
  type WeeklySlot,
} from './recharge-rules.js';

export type OrderViewerRole = 'BUYER' | 'AGENT' | 'EMPLOYEE';

export interface RechargePriceDto {
  usdMinor: number;
  /** `"12.50"`. */
  usd: string;
  local: { currency: string; minor: number; digits: number; amount: string; rate: string } | null;
}
export interface RechargeQuoteDto {
  agentCode: string;
  country: string;
  coins: number;
  price: RechargePriceDto;
  paymentMethodTypes: string[];
  minCoins: number;
  maxCoins: number;
}
export interface RechargeOrderDto {
  id: string;
  status: OrderStatus;
  viewerRole: OrderViewerRole;
  buyer: UserSummaryDto;
  agent: UserSummaryDto;
  agentCode: string;
  country: string;
  coins: number;
  price: RechargePriceDto;
  paymentType: string;
  heldCoins: number;
  noticeAcknowledged: boolean;
  detailsAt: string | null;
  paidAt: string | null;
  disputeOpensAt: string | null;
  disputedAt: string | null;
  disputedBy: 'BUYER' | 'AGENT' | null;
  closedAt: string | null;
  closeReason: string | null;
  expiresAt: string | null;
  actions: OrderAction[];
  /**
   * v1.87-social (D287): the agent's side person who acted first and owns the order (the agent or an employee), and
   * why the viewer of the agent's side cannot act now (`actions` is then empty; null = they can, or the buyer).
   */
  claimedBy: UserSummaryDto | null;
  claimedAt: string | null;
  viewerBlock: AgentSideBlock | null;
  createdAt: string;
  updatedAt: string;
}
export interface RechargeOrderMessageDto {
  id: string;
  kind: 'TEXT' | 'IMAGE' | 'PAYMENT_DETAILS' | 'TRANSFER_PROOF' | 'SYSTEM';
  role: 'BUYER' | 'AGENT' | 'EMPLOYEE' | 'ADMIN' | 'SYSTEM';
  /** The person who wrote it (never an admin: «الإدارة» has no name). */
  author: UserSummaryDto | null;
  text: string | null;
  method: string | null;
  event: string | null;
  hasImage: boolean;
  createdAt: string;
}

/** D287: the refusal of an agent's side person who may read but not act. */
export function blockError(block: AgentSideBlock): AppException {
  // D287 (owner): an employee who is a Kabso Team account now — D283's code, the issue names what was refused.
  if (block === 'STAFF') {
    return new AppException(ErrorCode.STAFF_ACCOUNT_LIMITED, undefined, [
      { field: 'staff', issue: 'recharge_employee' },
    ]);
  }
  return new AppException(
    block === 'NOT_PERMITTED'
      ? ErrorCode.RECHARGE_EMPLOYEE_NOT_PERMITTED
      : block === 'CLAIMED'
        ? ErrorCode.RECHARGE_ORDER_CLAIMED
        : ErrorCode.RECHARGE_OFF_SHIFT,
  );
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ORDER_IMAGE_KIND = 'RECHARGE_ORDER_IMAGE';

function parse<S extends z.ZodType>(schema: S, body: unknown): z.output<S> {
  const parsed = schema.safeParse(body ?? {});
  if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
  return parsed.data;
}

function idempotencyKey(raw: string | undefined): string {
  if (raw === undefined || raw === '')
    throw AppException.validation([{ field: 'Idempotency-Key', issue: 'required' }]);
  if (!UUID.test(raw)) throw AppException.validation([{ field: 'Idempotency-Key', issue: 'invalid_format' }]);
  return raw.toLowerCase();
}

function pathId(raw: string): string {
  if (!UUID.test(raw)) throw new AppException(ErrorCode.NOT_FOUND);
  return raw.toLowerCase();
}

function isUniqueViolation(err: unknown, index?: string): boolean {
  if (!(err instanceof Prisma.PrismaClientKnownRequestError) || err.code !== 'P2002') return false;
  if (index === undefined) return true;
  return JSON.stringify(err.meta ?? {}).includes(index) || err.message.includes(index);
}

export function priceDto(o: {
  usdMinor: bigint;
  localCurrency: string | null;
  localMinor: bigint | null;
  localDigits: number | null;
  localRateMicro: bigint | null;
}): RechargePriceDto {
  return {
    usdMinor: Number(o.usdMinor),
    usd: formatMinor(o.usdMinor, 2),
    local:
      o.localCurrency !== null && o.localMinor !== null && o.localDigits !== null && o.localRateMicro !== null
        ? {
            currency: o.localCurrency,
            minor: Number(o.localMinor),
            digits: o.localDigits,
            amount: formatMinor(o.localMinor, o.localDigits),
            rate: formatRate(o.localRateMicro),
          }
        : null,
  };
}

interface Access {
  readonly order: RechargeOrder;
  readonly role: OrderViewerRole;
  readonly side: Side;
  /** The employee's job (null for the buyer and the agent). */
  readonly job: EmployeeJob | null;
  /** D287: an employee off shift, without «يستقبل طلبات الشراء» or not the order's owner reads but does not act. */
  readonly block: AgentSideBlock | null;
}

/**
 * Recharge orders with escrow «طلبات الشحن» (v1.69-social, D204, CONVENTIONS §10.64): the buyer's order to an agent
 * with the server's price, the order's own chat (evidence), the agent's payment details that freeze the coins, the
 * protection notice, «قمت بالإرسال» with the transfer's screenshot, the 15-minute wait, «استلمت» / «نزاع», the
 * cancellations and the expiry sweeper. The coin movements are in `recharge-order-core.ts` (shared with the panel
 * and the CLI); every one runs on the locked order row.
 */
@Injectable()
export class RechargeOrdersService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RechargeOrdersService.name);
  private readonly cursors: SocialCursorCodec;
  private timer: NodeJS.Timeout | undefined;
  private inFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly media: MediaService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly fx: FxRatesService,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  onModuleInit(): void {
    if (this.rules.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    this.timer = undefined;
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.sweep()
        .then((n) => {
          if (n > 0) this.logger.log({ expired: n }, 'Recharge orders expired');
        })
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Recharge order sweep failed');
        })
        .finally(() => {
          this.inFlight = null;
          if (this.timer !== undefined) this.schedule();
        });
    }, this.rules.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }

  /** The expiry step (the sweeper; tests call it directly). */
  sweep(): Promise<number> {
    return expireDueOrders(this.prisma, this.clock.now());
  }

  private get rules() {
    return this.config.recharge.orders;
  }

  private assertEnabled(): void {
    if (!this.rules.enabled) throw new AppException(ErrorCode.RECHARGE_ORDERS_UNAVAILABLE);
  }

  private async blocked(a: string, b: string): Promise<boolean> {
    const [row] = await this.prisma.$queryRaw<{ blocked: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM user_blocks
                      WHERE (blocker_id = ${a}::uuid AND blocked_id = ${b}::uuid)
                         OR (blocker_id = ${b}::uuid AND blocked_id = ${a}::uuid)) AS blocked`;
    return row?.blocked ?? false;
  }

  /**
   * D245: the rate a new order's price uses — the one resolver (the admin's manual rate «يدوي», else the automatic
   * rate of the country's currency; stale or missing → USD only; a USD country has no second line).
   */
  private async rateOf(country: string) {
    return priceRateOf(await this.fx.effective(country, this.clock.now()));
  }

  /** The ACTIVE agent of `code` serving `country`, with the payment types there. */
  private async agentFor(rawCode: string, country: string) {
    const code = normalizeAgentCode(rawCode);
    const agent =
      code === null
        ? null
        : await this.prisma.rechargeAgent.findFirst({
            where: { code, status: 'ACTIVE', user: { status: 'ACTIVE' } },
            select: { userId: true, code: true, countries: true, paymentTypes: true, stockCoins: true },
          });
    if (!agent) throw new AppException(ErrorCode.NOT_FOUND);
    if (!agent.countries.includes(country)) {
      throw AppException.validation([{ field: 'country', issue: 'invalid_value' }]);
    }
    const types = (agent.paymentTypes as Record<string, string[]>)[country] ?? [];
    return { ...agent, code: agent.code!, types };
  }

  private priceOf(coins: bigint, rate: Awaited<ReturnType<RechargeOrdersService['rateOf']>>) {
    return quote(coins, this.config.economy.coinRetailUsdPerMillion, rate);
  }

  private checkAmount(coins: number): void {
    if (coins < this.rules.minCoins || coins > this.rules.maxCoins) {
      throw AppException.validation([{ field: 'coins', issue: 'out_of_range' }]);
    }
  }

  /** `GET /recharge-orders/quote`: the server's price (USD always; the local amount when a rate is set). */
  async quote(query: unknown): Promise<RechargeQuoteDto> {
    this.assertEnabled();
    const q = parse(quoteQuerySchema, query);
    this.checkAmount(q.coins);
    const agent = await this.agentFor(q.agentCode, q.country);
    const p = this.priceOf(BigInt(q.coins), await this.rateOf(q.country));
    return {
      agentCode: agent.code,
      country: q.country,
      coins: q.coins,
      price: priceDto({
        usdMinor: p.usdMinor,
        localCurrency: p.local?.currency ?? null,
        localMinor: p.local?.minor ?? null,
        localDigits: p.local?.digits ?? null,
        localRateMicro: p.local?.rateMicro ?? null,
      }),
      paymentMethodTypes: agent.types,
      minCoins: this.rules.minCoins,
      maxCoins: this.rules.maxCoins,
    };
  }

  // ---- Access and DTOs ---------------------------------------------------------------------------------------

  private async employment(
    userId: string,
    agentUserId: string,
    db: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<EmployeeJob | null> {
    const row = await db.rechargeEmployee.findFirst({
      where: { employeeUserId: userId, agentUserId, removedAt: null },
      select: { timeZone: true, schedule: true, canBuyCherries: true, receivesOrders: true },
    });
    if (!row) return null;
    const kabsoTeam = (await limitedStaffAmong(db, [userId])).has(userId);
    return { ...row, schedule: row.schedule as unknown as WeeklySlot[], kabsoTeam };
  }

  private async access(userId: string, rawId: string): Promise<Access> {
    const id = pathId(rawId);
    const order = await this.prisma.rechargeOrder.findUnique({ where: { id } });
    if (!order) throw new AppException(ErrorCode.NOT_FOUND);
    if (order.buyerUserId === userId) return { order, role: 'BUYER', side: 'BUYER', job: null, block: null };
    if (order.agentUserId === userId) return { order, role: 'AGENT', side: 'AGENT', job: null, block: null };
    const job = await this.employment(userId, order.agentUserId);
    if (!job) throw new AppException(ErrorCode.NOT_FOUND);
    const block = agentSideBlock(userId, job, 'RECEIVE_ORDERS', this.clock.now(), order.claimedBy);
    return { order, role: 'EMPLOYEE', side: 'AGENT', job, block };
  }

  private requireAct(a: Access): void {
    if (a.block !== null) throw blockError(a.block);
  }

  /**
   * D287 (§10.100): on the locked order, the agent's side person who acts first owns it (`claimedBy`); another
   * employee is refused with 409 `RECHARGE_ORDER_CLAIMED` (the agent always acts). An employee removed meanwhile is
   * 404. Returns the order as it is now (with the claim).
   */
  private async claimIn(
    tx: Prisma.TransactionClient,
    o: RechargeOrder,
    a: Access,
    userId: string,
    now: Date,
  ): Promise<RechargeOrder> {
    if (a.side !== 'AGENT') return o;
    if (a.role === 'EMPLOYEE') {
      const job = await this.employment(userId, o.agentUserId, tx);
      if (!job) throw new AppException(ErrorCode.NOT_FOUND);
      const block = agentSideBlock(userId, job, 'RECEIVE_ORDERS', now, o.claimedBy);
      if (block !== null) throw blockError(block);
    }
    if (o.claimedBy !== null) return o;
    await tx.rechargeOrder.update({ where: { id: o.id }, data: { claimedBy: userId, claimedAt: now } });
    return { ...o, claimedBy: userId, claimedAt: now };
  }

  private async summaries(ids: readonly string[]): Promise<Map<string, UserSummaryDto>> {
    const users = await this.prisma.user.findMany({
      where: { id: { in: [...new Set(ids)] } },
      select: USER_SUMMARY_SELECT,
    });
    return new Map(users.map((u) => [u.id, userSummary(u)]));
  }

  private async orderDtos(rows: readonly RechargeOrder[], viewer: string): Promise<RechargeOrderDto[]> {
    if (rows.length === 0) return [];
    const users = await this.summaries(
      rows.flatMap((r) => [r.buyerUserId, r.agentUserId, ...(r.claimedBy === null ? [] : [r.claimedBy])]),
    );
    // D287: the viewer's job for the orders of an agent they work for (at most one active employment).
    const employer = rows.find((r) => r.buyerUserId !== viewer && r.agentUserId !== viewer)?.agentUserId;
    const job = employer === undefined ? null : await this.employment(viewer, employer);
    const agents = await this.prisma.rechargeAgent.findMany({
      where: { userId: { in: [...new Set(rows.map((r) => r.agentUserId))] } },
      select: { userId: true, code: true },
    });
    const codes = new Map(agents.map((a) => [a.userId, a.code ?? '']));
    const blank = (id: string): UserSummaryDto => ({ id, username: '', displayName: '', avatarUrl: null });
    const now = this.clock.now();
    return rows.map((o) => {
      const role: OrderViewerRole =
        o.buyerUserId === viewer ? 'BUYER' : o.agentUserId === viewer ? 'AGENT' : 'EMPLOYEE';
      const side: Side = role === 'BUYER' ? 'BUYER' : 'AGENT';
      const block =
        role === 'EMPLOYEE'
          ? job === null
            ? 'NOT_PERMITTED'
            : agentSideBlock(viewer, job, 'RECEIVE_ORDERS', now, o.claimedBy)
          : null;
      return {
        id: o.id,
        status: o.status,
        viewerRole: role,
        buyer: users.get(o.buyerUserId) ?? blank(o.buyerUserId),
        agent: users.get(o.agentUserId) ?? blank(o.agentUserId),
        agentCode: codes.get(o.agentUserId) ?? '',
        country: o.country,
        coins: Number(o.coins),
        price: priceDto(o),
        paymentType: o.paymentType,
        heldCoins: Number(o.heldCoins),
        noticeAcknowledged: o.noticeAckAt !== null,
        detailsAt: o.detailsAt?.toISOString() ?? null,
        paidAt: o.paidAt?.toISOString() ?? null,
        disputeOpensAt: o.paidAt
          ? disputeOpensAt(o.paidAt, this.rules.disputeAfterMinutes).toISOString()
          : null,
        disputedAt: o.disputedAt?.toISOString() ?? null,
        disputedBy: o.disputedBy === 'BUYER' ? 'BUYER' : o.disputedBy === null ? null : 'AGENT',
        closedAt: o.closedAt?.toISOString() ?? null,
        closeReason: o.closeReason,
        expiresAt: o.expiresAt?.toISOString() ?? null,
        actions: block === null ? allowedActions(o, side, now, this.rules) : [],
        claimedBy: o.claimedBy === null ? null : (users.get(o.claimedBy) ?? blank(o.claimedBy)),
        claimedAt: o.claimedAt?.toISOString() ?? null,
        viewerBlock: block,
        createdAt: o.createdAt.toISOString(),
        updatedAt: o.updatedAt.toISOString(),
      };
    });
  }

  private async orderDto(order: RechargeOrder, viewer: string): Promise<RechargeOrderDto> {
    const [dto] = await this.orderDtos([order], viewer);
    return dto!;
  }

  async messageDtos(rows: readonly RechargeOrderMessage[]): Promise<RechargeOrderMessageDto[]> {
    const authors = rows
      .filter((m) => m.role !== 'ADMIN' && m.authorUserId !== null)
      .map((m) => m.authorUserId!);
    const users = authors.length > 0 ? await this.summaries(authors) : new Map<string, UserSummaryDto>();
    return rows.map((m) => ({
      id: m.id,
      kind: m.kind,
      role: m.role,
      author: m.role === 'ADMIN' || m.authorUserId === null ? null : (users.get(m.authorUserId) ?? null),
      text: m.text,
      method: m.method,
      event: m.event,
      hasImage: m.imageKey !== null,
      createdAt: m.createdAt.toISOString(),
    }));
  }

  /**
   * Runs `step` on the locked order after a due expiry (its own transaction first, so the expiry is kept even when
   * the step is refused). The step sees the row as it is now.
   */
  private async onLocked<T>(
    id: string,
    step: (tx: Prisma.TransactionClient, o: RechargeOrder) => Promise<T>,
  ) {
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      const o = await lockOrderIn(tx, id);
      if (o) await expireIfDueIn(tx, o, now);
    });
    try {
      return await this.prisma.$transaction(async (tx) => {
        const o = await lockOrderIn(tx, id);
        if (!o) throw new AppException(ErrorCode.NOT_FOUND);
        return step(tx, o);
      });
    } catch (err) {
      if (err instanceof OrderStateError) throw new AppException(ErrorCode.RECHARGE_ORDER_STATE_CHANGED);
      throw err;
    }
  }

  private stateChanged(): AppException {
    return new AppException(ErrorCode.RECHARGE_ORDER_STATE_CHANGED);
  }

  private messageRole(a: Access): 'BUYER' | 'AGENT' | 'EMPLOYEE' {
    return a.role;
  }

  // ---- Buyer: create -------------------------------------------------------------------------------------------

  /** `POST /recharge-orders` (Idempotency-Key): 201 created, 200 the same key again. */
  async create(
    buyerId: string,
    rawKey: string | undefined,
    body: unknown,
  ): Promise<{ created: boolean; result: RechargeOrderDto }> {
    this.assertEnabled();
    const clientId = idempotencyKey(rawKey);
    const input = parse(createOrderSchema, body);
    const replay = async () => {
      const row = await this.prisma.rechargeOrder.findUnique({
        where: { buyerUserId_clientId: { buyerUserId: buyerId, clientId } },
      });
      if (!row) return null;
      const code = await this.prisma.rechargeAgent.findUnique({
        where: { userId: row.agentUserId },
        select: { code: true },
      });
      if (
        Number(row.coins) !== input.coins ||
        row.country !== input.country ||
        row.paymentType !== input.paymentType ||
        code?.code !== normalizeAgentCode(input.agentCode)
      ) {
        throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
      }
      return { created: false, result: await this.orderDto(row, buyerId) };
    };
    const earlier = await replay();
    if (earlier) return earlier;
    this.checkAmount(input.coins);
    const agent = await this.agentFor(input.agentCode, input.country);
    if (agent.userId === buyerId)
      throw AppException.validation([{ field: 'agentCode', issue: 'invalid_value' }]);
    if (await this.employment(buyerId, agent.userId)) {
      throw AppException.validation([{ field: 'agentCode', issue: 'invalid_value' }]);
    }
    if (await this.blocked(buyerId, agent.userId)) throw new AppException(ErrorCode.NOT_FOUND);
    if (!agent.types.includes(input.paymentType)) {
      throw AppException.validation([{ field: 'paymentType', issue: 'invalid_value' }]);
    }
    const coins = BigInt(input.coins);
    if (agent.stockCoins < coins) throw new AppException(ErrorCode.RECHARGE_STOCK_INSUFFICIENT);
    const p = this.priceOf(coins, await this.rateOf(input.country));
    const now = this.clock.now();
    const id = uuidv7();
    try {
      const row = await this.prisma.$transaction(async (tx) => {
        const created = await tx.rechargeOrder.create({
          data: {
            id,
            buyerUserId: buyerId,
            agentUserId: agent.userId,
            clientId,
            country: input.country,
            coins,
            usdMinor: p.usdMinor,
            localCurrency: p.local?.currency ?? null,
            localRateMicro: p.local?.rateMicro ?? null,
            localMinor: p.local?.minor ?? null,
            localDigits: p.local?.digits ?? null,
            paymentType: input.paymentType,
            expiresAt: new Date(now.getTime() + this.rules.requestTtlMinutes * 60_000),
            createdAt: now,
            updatedAt: now,
          },
        });
        await systemLineIn(tx, id, 'CREATED', now);
        await tx.auditLog.create({
          data: {
            actorUserId: buyerId,
            action: AuditAction.RECHARGE_ORDER_CREATE,
            targetType: 'recharge_order',
            targetId: id,
            metadata: {
              agent: agent.userId,
              country: input.country,
              coins: Number(coins),
              usdMinor: Number(p.usdMinor),
              local: p.local ? { currency: p.local.currency, minor: Number(p.local.minor) } : null,
              paymentType: input.paymentType,
              after: 'REQUESTED',
            },
          },
        });
        await notifyOrderIn(tx, id, await agentSideIn(tx, agent.userId, now), 'CREATED', now);
        return created;
      });
      return { created: true, result: await this.orderDto(row, buyerId) };
    } catch (err) {
      if (isUniqueViolation(err)) {
        const raced = await replay();
        if (raced) return raced;
        throw new AppException(ErrorCode.RECHARGE_ORDER_OPEN_EXISTS);
      }
      throw err;
    }
  }

  // ---- Reading -------------------------------------------------------------------------------------------------

  /** `GET /recharge-orders`: as buyer, or for the agent the caller is (or works for); newest first. */
  async list(userId: string, query: unknown): Promise<PageDto<RechargeOrderDto>> {
    const q = parse(ordersQuerySchema, query);
    let agentUserId: string | null = null;
    if (q.role === 'agent') {
      const own = await this.prisma.rechargeAgent.findUnique({ where: { userId }, select: { userId: true } });
      if (own) agentUserId = own.userId;
      else {
        const job = await this.prisma.rechargeEmployee.findFirst({
          where: { employeeUserId: userId, removedAt: null },
          select: { agentUserId: true, receivesOrders: true },
        });
        if (!job) throw new AppException(ErrorCode.NOT_FOUND);
        // D287: «يستقبل طلبات الشراء» off → the agent's inbox is not theirs.
        if (!job.receivesOrders) throw new AppException(ErrorCode.RECHARGE_EMPLOYEE_NOT_PERMITTED);
        agentUserId = job.agentUserId;
      }
    }
    const scope = `recharge-orders:${q.role}:${q.state}:${userId}`;
    const after = q.cursor === undefined ? null : this.cursors.decode(q.cursor, scope);
    if (q.cursor !== undefined && !after) {
      throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const open = ['REQUESTED', 'AWAITING_PAYMENT', 'PAID', 'DISPUTED'] as const;
    const rows = await this.prisma.rechargeOrder.findMany({
      where: {
        ...(agentUserId === null ? { buyerUserId: userId } : { agentUserId }),
        ...(q.state === 'open'
          ? { status: { in: [...open] } }
          : q.state === 'closed'
            ? { status: { notIn: [...open] } }
            : {}),
        ...(after
          ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: q.limit + 1,
    });
    const hasMore = rows.length > q.limit;
    const page = rows.slice(0, q.limit);
    const last = page[page.length - 1];
    return {
      data: await this.orderDtos(page, userId),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  /** `GET /recharge-orders/{id}`. A due expiry is applied first. */
  async get(userId: string, rawId: string): Promise<RechargeOrderDto> {
    const a = await this.access(userId, rawId);
    if (
      (a.order.status === 'REQUESTED' || a.order.status === 'AWAITING_PAYMENT') &&
      a.order.expiresAt !== null &&
      a.order.expiresAt.getTime() <= this.clock.now().getTime()
    ) {
      await this.prisma.$transaction(async (tx) => {
        const o = await lockOrderIn(tx, a.order.id);
        if (o) await expireIfDueIn(tx, o, this.clock.now());
      });
      const fresh = await this.prisma.rechargeOrder.findUniqueOrThrow({ where: { id: a.order.id } });
      return this.orderDto(fresh, userId);
    }
    return this.orderDto(a.order, userId);
  }

  /** `GET /recharge-orders/{id}/messages`: newest first. */
  async messages(userId: string, rawId: string, query: unknown): Promise<PageDto<RechargeOrderMessageDto>> {
    const a = await this.access(userId, rawId);
    return this.messagePage(a.order.id, query);
  }

  /** A page of the order's chat, newest first (also the panel's). */
  async messagePage(orderId: string, query: unknown): Promise<PageDto<RechargeOrderMessageDto>> {
    const q = parse(messagesQuerySchema, query);
    const scope = `recharge-order-messages:${orderId}`;
    const after = q.cursor === undefined ? null : this.cursors.decode(q.cursor, scope);
    if (q.cursor !== undefined && !after) {
      throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const seq = after === null ? null : after.n === undefined ? null : BigInt(after.n);
    if (after !== null && seq === null)
      throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    const rows = await this.prisma.rechargeOrderMessage.findMany({
      where: { orderId, ...(seq === null ? {} : { seq: { lt: seq } }) },
      orderBy: { seq: 'desc' },
      take: q.limit + 1,
    });
    const hasMore = rows.length > q.limit;
    const page = rows.slice(0, q.limit);
    const last = page[page.length - 1];
    return {
      data: await this.messageDtos(page),
      page: {
        hasMore,
        nextCursor:
          hasMore && last
            ? this.cursors.encode(scope, { at: last.createdAt, id: last.id, n: Number(last.seq) })
            : null,
      },
    };
  }

  /** `GET /recharge-orders/{id}/messages/{messageId}/image`: the private picture (participants only). */
  async image(userId: string, rawId: string, rawMessageId: string): Promise<Buffer> {
    const a = await this.access(userId, rawId);
    return this.imageBytes(a.order.id, rawMessageId);
  }

  async imageBytes(orderId: string, rawMessageId: string): Promise<Buffer> {
    const message = await this.prisma.rechargeOrderMessage.findFirst({
      where: { id: pathId(rawMessageId), orderId },
      select: { imageKey: true },
    });
    if (!message?.imageKey) throw new AppException(ErrorCode.NOT_FOUND);
    const bytes = await this.storage.get(message.imageKey, 16 * 1024 * 1024);
    if (!bytes) throw new AppException(ErrorCode.NOT_FOUND);
    return bytes;
  }

  // ---- Chat ------------------------------------------------------------------------------------------------------

  /** Consumes a private image upload into the order's prefix (re-encoded, metadata stripped), or 400. */
  private async consumeImage(userId: string, orderId: string, uploadId: string, field: string) {
    await this.media.assertEnabled();
    const messageId = uuidv7();
    const key = orderImageKey(orderId, messageId);
    if (!(await this.media.consumePrivateImage(userId, uploadId, ORDER_IMAGE_KIND, key))) {
      throw AppException.validation([{ field, issue: 'invalid_value' }]);
    }
    return { messageId, key };
  }

  /** `POST /recharge-orders/{id}/messages`: text or a picture (kept as evidence; open and disputed orders). */
  async postMessage(userId: string, rawId: string, body: unknown): Promise<RechargeOrderMessageDto> {
    const a = await this.access(userId, rawId);
    this.requireAct(a);
    const input = parse(orderMessageSchema, body);
    if (a.order.status === 'CANCELLED' || a.order.status === 'EXPIRED') throw this.stateChanged();
    const image =
      input.imageUploadId !== undefined
        ? await this.consumeImage(userId, a.order.id, input.imageUploadId, 'imageUploadId')
        : null;
    try {
      const id = await this.onLocked(a.order.id, async (tx, locked) => {
        if (locked.status === 'CANCELLED' || locked.status === 'EXPIRED') throw this.stateChanged();
        const now = this.clock.now();
        const o = await this.claimIn(tx, locked, a, userId, now);
        const mid = await messageIn(tx, {
          id: image?.messageId,
          orderId: o.id,
          authorUserId: userId,
          role: this.messageRole(a),
          kind: image ? 'IMAGE' : 'TEXT',
          text: input.text ?? null,
          imageKey: image?.key ?? null,
          now,
        });
        await tx.rechargeOrder.update({ where: { id: o.id }, data: { updatedAt: now } });
        const parties = await partiesIn(tx, o, now);
        await notifyOrderIn(
          tx,
          o.id,
          parties.filter((p) => p !== userId),
          image ? 'IMAGE' : 'MESSAGE',
          now,
        );
        return mid;
      });
      const row = await this.prisma.rechargeOrderMessage.findUniqueOrThrow({ where: { id } });
      return (await this.messageDtos([row]))[0]!;
    } catch (err) {
      if (image) await this.media.deletePrivateObjects([image.key]).catch(() => undefined);
      throw err;
    }
  }

  // ---- Agent: details --------------------------------------------------------------------------------------------

  /**
   * `POST /recharge-orders/{id}/payment-details`: the agent's (or an on-shift employee's) structured message; the
   * agreed coins are frozen from the stock now (ORDER_HOLD). Not enough stock: 409, nothing changes.
   */
  async sendDetails(userId: string, rawId: string, body: unknown): Promise<RechargeOrderDto> {
    this.assertEnabled();
    const a = await this.access(userId, rawId);
    if (a.side !== 'AGENT') throw new AppException(ErrorCode.NOT_FOUND);
    this.requireAct(a);
    const input = parse(paymentDetailsSchema, body);
    const row = await this.onLocked(a.order.id, async (tx, locked) => {
      if (locked.status !== 'REQUESTED') throw this.stateChanged();
      const o = await this.claimIn(tx, locked, a, userId, this.clock.now());
      const [agent] = await tx.$queryRaw<{ status: string; user_status: string; types: unknown }[]>`
        SELECT a.status::text AS status, u.status::text AS user_status, a.payment_types AS types
          FROM recharge_agents a JOIN users u ON u.id = a.user_id
         WHERE a.user_id = ${o.agentUserId}::uuid FOR UPDATE OF a`;
      if (agent?.status !== 'ACTIVE' || agent.user_status !== 'ACTIVE') {
        throw new AppException(ErrorCode.RECHARGE_AGENT_NOT_ACTIVE);
      }
      const types = (agent.types as Record<string, string[]>)[o.country] ?? [];
      if (!types.includes(input.method)) {
        throw AppException.validation([{ field: 'method', issue: 'invalid_value' }]);
      }
      const now = this.clock.now();
      const stock = await moveStockIn(tx, o.agentUserId, -o.coins, 'ORDER_HOLD', o.id, now);
      if (stock === null) throw new AppException(ErrorCode.RECHARGE_STOCK_INSUFFICIENT);
      const updated = await tx.rechargeOrder.update({
        where: { id: o.id },
        data: {
          status: 'AWAITING_PAYMENT',
          heldCoins: o.coins,
          detailsAt: now,
          expiresAt: new Date(now.getTime() + this.rules.paymentTtlMinutes * 60_000),
          updatedAt: now,
        },
      });
      await messageIn(tx, {
        orderId: o.id,
        authorUserId: userId,
        role: this.messageRole(a),
        kind: 'PAYMENT_DETAILS',
        method: input.method,
        text: input.details,
        now,
      });
      await systemLineIn(tx, o.id, 'DETAILS_SENT', now);
      await tx.auditLog.create({
        data: {
          actorUserId: userId,
          action: AuditAction.RECHARGE_ORDER_DETAILS,
          targetType: 'recharge_order',
          targetId: o.id,
          metadata: {
            before: 'REQUESTED',
            after: 'AWAITING_PAYMENT',
            held: Number(o.coins),
            stockAfter: Number(stock),
            method: input.method,
            byEmployee: a.role === 'EMPLOYEE',
            claimedBy: o.claimedBy,
          },
        },
      });
      await notifyOrderIn(tx, o.id, [o.buyerUserId], 'DETAILS_SENT', now);
      return updated;
    });
    return this.orderDto(row, userId);
  }

  // ---- Buyer: notice, paid -----------------------------------------------------------------------------------------

  /** `POST /recharge-orders/{id}/notice-ack`: the buyer read the protection notice (once; again = no change). */
  async ackNotice(userId: string, rawId: string): Promise<RechargeOrderDto> {
    const a = await this.access(userId, rawId);
    if (a.side !== 'BUYER') throw new AppException(ErrorCode.NOT_FOUND);
    const row = await this.onLocked(a.order.id, async (tx, o) => {
      if (o.status !== 'AWAITING_PAYMENT') throw this.stateChanged();
      if (o.noticeAckAt !== null) return o;
      const now = this.clock.now();
      const updated = await tx.rechargeOrder.update({
        where: { id: o.id },
        data: { noticeAckAt: now, updatedAt: now },
      });
      await systemLineIn(tx, o.id, 'NOTICE_ACKNOWLEDGED', now);
      await tx.auditLog.create({
        data: {
          actorUserId: userId,
          action: AuditAction.RECHARGE_ORDER_NOTICE_ACK,
          targetType: 'recharge_order',
          targetId: o.id,
          metadata: {},
        },
      });
      return updated;
    });
    return this.orderDto(row, userId);
  }

  /** `POST /recharge-orders/{id}/paid`: «قمت بالإرسال» with the transfer's screenshot → PAID (the wait starts). */
  async markPaid(userId: string, rawId: string, body: unknown): Promise<RechargeOrderDto> {
    const a = await this.access(userId, rawId);
    if (a.side !== 'BUYER') throw new AppException(ErrorCode.NOT_FOUND);
    const input = parse(markPaidSchema, body);
    if (a.order.status !== 'AWAITING_PAYMENT') throw this.stateChanged();
    if (a.order.noticeAckAt === null) throw new AppException(ErrorCode.RECHARGE_ORDER_NOTICE_REQUIRED);
    const image = await this.consumeImage(userId, a.order.id, input.proofUploadId, 'proofUploadId');
    try {
      const row = await this.onLocked(a.order.id, async (tx, o) => {
        if (o.status !== 'AWAITING_PAYMENT') throw this.stateChanged();
        if (o.noticeAckAt === null) throw new AppException(ErrorCode.RECHARGE_ORDER_NOTICE_REQUIRED);
        const now = this.clock.now();
        const updated = await tx.rechargeOrder.update({
          where: { id: o.id },
          data: { status: 'PAID', paidAt: now, expiresAt: null, updatedAt: now },
        });
        await messageIn(tx, {
          id: image.messageId,
          orderId: o.id,
          authorUserId: userId,
          role: 'BUYER',
          kind: 'TRANSFER_PROOF',
          imageKey: image.key,
          now,
        });
        await systemLineIn(tx, o.id, 'PAID', now);
        await tx.auditLog.create({
          data: {
            actorUserId: userId,
            action: AuditAction.RECHARGE_ORDER_PAID,
            targetType: 'recharge_order',
            targetId: o.id,
            metadata: { before: 'AWAITING_PAYMENT', after: 'PAID', proof: image.messageId },
          },
        });
        await notifyOrderIn(tx, o.id, await agentSideIn(tx, o.agentUserId, now, o.claimedBy), 'PAID', now);
        return updated;
      });
      return await this.orderDto(row, userId);
    } catch (err) {
      await this.media.deletePrivateObjects([image.key]).catch(() => undefined);
      throw err;
    }
  }

  // ---- Agent: «استلمت» ---------------------------------------------------------------------------------------------

  /** `POST /recharge-orders/{id}/confirm`: the frozen coins go to the buyer (idempotent: COMPLETED again → 200). */
  async confirm(userId: string, rawId: string): Promise<RechargeOrderDto> {
    const a = await this.access(userId, rawId);
    if (a.side !== 'AGENT') throw new AppException(ErrorCode.NOT_FOUND);
    this.requireAct(a);
    const row = await this.onLocked(a.order.id, async (tx, locked) => {
      const now = this.clock.now();
      const o = locked.status === 'COMPLETED' ? locked : await this.claimIn(tx, locked, a, userId, now);
      await confirmIn(tx, o, userId, now, {
        ...this.config.recharge.badges,
        cherriesPerCoin: this.config.economy.cherriesPerCoin,
      });
      return tx.rechargeOrder.findUniqueOrThrow({ where: { id: o.id } });
    });
    return this.orderDto(row, userId);
  }

  // ---- «نزاع» -----------------------------------------------------------------------------------------------------

  /**
   * `POST /recharge-orders/{id}/dispute`: the agent any time after PAID, the buyer once the wait is over. The coins
   * stay frozen; the chat stays open and admins can join it. Again on a DISPUTED order: no change.
   */
  async dispute(userId: string, rawId: string, body: unknown): Promise<RechargeOrderDto> {
    const a = await this.access(userId, rawId);
    this.requireAct(a);
    const input = parse(reasonBodySchema, body);
    const row = await this.onLocked(a.order.id, async (tx, locked) => {
      if (locked.status === 'DISPUTED') return locked;
      if (locked.status !== 'PAID') throw this.stateChanged();
      const now = this.clock.now();
      const o = await this.claimIn(tx, locked, a, userId, now);
      if (
        a.side === 'BUYER' &&
        now.getTime() < disputeOpensAt(o.paidAt!, this.rules.disputeAfterMinutes).getTime()
      ) {
        throw new AppException(ErrorCode.RECHARGE_ORDER_DISPUTE_TOO_EARLY);
      }
      const updated = await tx.rechargeOrder.update({
        where: { id: o.id },
        data: { status: 'DISPUTED', disputedAt: now, disputedBy: a.side, updatedAt: now },
      });
      if (input.reason !== undefined) {
        await messageIn(tx, {
          orderId: o.id,
          authorUserId: userId,
          role: this.messageRole(a),
          kind: 'TEXT',
          text: input.reason,
          now,
        });
      }
      await systemLineIn(tx, o.id, a.side === 'BUYER' ? 'DISPUTED_BY_BUYER' : 'DISPUTED_BY_AGENT', now);
      await tx.auditLog.create({
        data: {
          actorUserId: userId,
          action: AuditAction.RECHARGE_ORDER_DISPUTE,
          targetType: 'recharge_order',
          targetId: o.id,
          metadata: { before: 'PAID', after: 'DISPUTED', side: a.side, held: Number(o.heldCoins) },
        },
      });
      const parties = await partiesIn(tx, o, now);
      await notifyOrderIn(
        tx,
        o.id,
        parties.filter((p) => p !== userId),
        'DISPUTED',
        now,
      );
      return updated;
    });
    return this.orderDto(row, userId);
  }

  // ---- Cancel ------------------------------------------------------------------------------------------------------

  /** `POST /recharge-orders/{id}/cancel`: the buyer before PAID, the agent before the details. */
  async cancel(userId: string, rawId: string, body: unknown): Promise<RechargeOrderDto> {
    const a = await this.access(userId, rawId);
    this.requireAct(a);
    const input = parse(reasonBodySchema, body);
    const row = await this.onLocked(a.order.id, async (tx, locked) => {
      const now = this.clock.now();
      const o = await this.claimIn(tx, locked, a, userId, now);
      await cancelIn(tx, o, { userId, side: a.side }, input.reason ?? null, now);
      return tx.rechargeOrder.findUniqueOrThrow({ where: { id: o.id } });
    });
    return this.orderDto(row, userId);
  }

  // ---- The agent's dashboard -------------------------------------------------------------------------------------

  /** The coins frozen in the agent's open orders and how many orders wait for them. */
  async agentTotals(agentUserId: string): Promise<{ heldCoins: number; openOrders: number }> {
    const [row] = await this.prisma.$queryRaw<{ held: bigint; open: number }[]>`
      SELECT COALESCE(sum(held_coins), 0)::bigint AS held,
             count(*) FILTER (WHERE status IN ('REQUESTED', 'PAID', 'DISPUTED'))::int AS open
        FROM recharge_orders
       WHERE agent_user_id = ${agentUserId}::uuid
         AND status IN ('REQUESTED', 'AWAITING_PAYMENT', 'PAID', 'DISPUTED')`;
    return { heldCoins: Number(row?.held ?? 0n), openOrders: row?.open ?? 0 };
  }
}
