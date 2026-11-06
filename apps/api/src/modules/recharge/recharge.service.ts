import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { kycOn, kycSettingsIn } from '../kyc/kyc-core.js';
import { takeIdPictures } from '../kyc/id-pictures.js';
import { z } from 'zod';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma, type RechargeCherryRequest, type RechargeSale } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { holdCherriesIn, taskCherryLockIn } from '../economy/cherry-ledger.js';
import { uuidv7 } from '../levels/uuidv7.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { MediaService } from '../media/media.service.js';
import { resolveUserIdByUsername } from '../users/special-usernames.js';
import { Notifier } from '../notifications/notifier.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import type { PageQuery } from '../posts/posts.schemas.js';
import { SocialCursorCodec, type SocialPosition } from '../posts/social-cursor.js';
import { creditIn } from '../wallet/wallet-ledger.js';
import { recordRechargeIn } from './recharge-badges.js';
import { employeeStatsIn, type SalesStatsDto } from './recharge-employee-stats.js';
import { referralRechargeIn } from '../referrals/referral-core.js';
import { blockError, RechargeOrdersService } from './recharge-orders.service.js';
import { moveStockIn, privateKeyOf, purgeApplications } from './recharge-core.js';
import { recruiterOfForm } from '../recruits/recruit-core.js';
import { isLimitedStaff, limitedStaffAmong } from '../live/live-staff.js';
import {
  agentSideBlock,
  applicationSchema,
  availabilitySchema,
  cherryActionFits,
  cherryActions,
  onShift,
  type AgentSideBlock,
  type CherryAction,
  type CherrySide,
  type EmployeeJob,
  cherriesPayoutMinor,
  cherriesToCoins,
  dayStart,
  employeeHoursSchema,
  normalizeAgentCode,
  slotAt,
  validCherryAmount,
  type AvailabilitySlot,
  type WeeklySlot,
} from './recharge-rules.js';

type Status = 'NONE' | 'PENDING' | 'REJECTED' | 'APPROVED' | 'ACTIVE' | 'SUSPENDED';

export interface AvailabilityDto {
  timeZone: string;
  slots: AvailabilitySlot[];
}
export interface RechargeAgentMeDto {
  status: Status;
  canApply: boolean;
  application: {
    status: 'PENDING' | 'APPROVED' | 'REJECTED';
    submittedAt: string;
    decidedAt: string | null;
    rejectReason: string | null;
  } | null;
  agent: {
    code: string | null;
    status: 'APPROVED' | 'ACTIVE' | 'SUSPENDED';
    stockCoins: number;
    /** v1.69-social (D204): coins frozen in open orders (not in `stockCoins`) and the orders waiting for the agent. */
    heldCoins: number;
    openOrders: number;
    activatedAt: string | null;
    dailyCherryCap: number;
    todayCherries: number;
    availability: AvailabilityDto;
    sales: SalesStatsDto;
  } | null;
  employment: {
    agentCode: string | null;
    agent: UserSummaryDto;
    timeZone: string;
    schedule: WeeklySlot[];
    onShiftNow: boolean;
    /** v1.87-social (D287): what the agent allows this employee to do for them. */
    canBuyCherries: boolean;
    receivesOrders: boolean;
    /** D287 (owner): a Kabso Team account now (D283) — reads, cannot act as an employee. */
    kabsoTeam: boolean;
  } | null;
  rules: {
    activationMinCoins: number;
    cherryUnit: number;
    coinsPerCherryUnit: number;
    minCherries: number;
    stepCherries: number;
    requestTtlMinutes: number;
    payout: {
      currency: string;
      rateCherries: number;
      rateMinor: number;
      minAmountMinor: number;
      payoutDays: number;
    };
    /** v1.69-social (D204, §10.64): recharge orders with escrow. */
    orders: {
      enabled: boolean;
      minCoins: number;
      maxCoins: number;
      requestTtlMinutes: number;
      paymentTtlMinutes: number;
      disputeAfterMinutes: number;
    };
  };
}
export interface RechargeSaleDto {
  id: string;
  coins: number;
  buyer: UserSummaryDto;
  seller: UserSummaryDto;
  agentCode: string;
  stockAfter?: number;
  createdAt: string;
}
export interface RechargeEmployeeDto {
  user: UserSummaryDto;
  timeZone: string;
  schedule: WeeklySlot[];
  onShiftNow: boolean;
  addedAt: string;
  /** D185 sales; v1.87-social (D287): the permissions and what the employee did for the agent (count and coins). */
  sales: SalesStatsDto;
  canBuyCherries: boolean;
  receivesOrders: boolean;
  cherryPurchases: SalesStatsDto;
  orders: SalesStatsDto;
  /** D287 (owner): a Kabso Team account now (D283) — the agent sees why they cannot act. */
  kabsoTeam: boolean;
}
export interface RechargeAgentListingDto {
  code: string;
  user: UserSummaryDto;
  locations: { country: string; cities: string[] }[];
  paymentMethodTypes: string[];
  availableNow: { whatsapp: string; paymentMethod: string } | null;
}
export interface RechargeCherryRequestDto {
  id: string;
  status: 'PENDING' | 'CONFIRMED' | 'DECLINED' | 'CANCELLED' | 'EXPIRED';
  cherries: number;
  coins: number;
  payoutMinor: number;
  currency: string;
  agentCode: string;
  agent: UserSummaryDto;
  host: UserSummaryDto;
  initiatedBy: 'HOST' | 'AGENT';
  createdAt: string;
  expiresAt: string;
  decidedAt: string | null;
  /**
   * v1.87-social (D287): the viewer's side, what they may do now, why not (an employee off shift or without
   * «يمكنه شراء الكرز»), and the agent's employee who acted on it (null = the agent or the host).
   */
  viewerSide: CherrySide;
  actions: CherryAction[];
  viewerBlock: AgentSideBlock | null;
  actedBy: UserSummaryDto | null;
}

const saleBodySchema = z.strictObject({
  buyer: z.string().trim().min(1).max(64),
  coins: z.number().int().min(1).max(1_000_000_000_000),
});
/** D287: the employee's permissions (both ON when not given: the agent added them to sell). */
const employeePermissions = {
  canBuyCherries: z.boolean().optional(),
  receivesOrders: z.boolean().optional(),
};
const employeeAddSchema = employeeHoursSchema.extend({
  username: z.string().trim().min(1).max(64),
  ...employeePermissions,
});
const employeeUpdateSchema = employeeHoursSchema.extend(employeePermissions);
const cherryCreateSchema = z
  .strictObject({
    cherries: z.number().int().min(1).max(1_000_000_000_000),
    agentCode: z.string().trim().min(1).max(16).optional(),
    host: z.string().trim().min(1).max(64).optional(),
  })
  .refine((b) => (b.agentCode === undefined) !== (b.host === undefined), {
    message: 'exactly one of agentCode and host',
    path: ['agentCode'],
  });
const countrySchema = z
  .string()
  .regex(/^[A-Za-z]{2}$/)
  .transform((c) => c.toUpperCase());
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DAY_MS = 86_400_000;
const DIRECTORY_MAX = 1000;

function idempotencyKey(raw: string | undefined): string {
  if (raw === undefined || raw === '')
    throw AppException.validation([{ field: 'Idempotency-Key', issue: 'required' }]);
  if (!UUID.test(raw)) throw AppException.validation([{ field: 'Idempotency-Key', issue: 'invalid_format' }]);
  return raw.toLowerCase();
}

function parse<T>(schema: z.ZodType<T>, body: unknown): T {
  const parsed = schema.safeParse(body ?? {});
  if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
  return parsed.data;
}

function isUniqueViolation(err: unknown): boolean {
  return err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002';
}

/**
 * Recharge agents «وكلاء الشحن» (v1.54-social, D185, CONVENTIONS §10.48): the application (private pictures
 * consumed from uploads), the agent's dashboard, availability and coin sales, employees, the directory and the
 * cherry sales between hosts and agents. The team's decisions go through the `recharge-admin` CLI
 * (`recharge-core.ts`). The perks are derived from the status (`UserSummary.rechargeAgent`,
 * `PublicProfile.rechargeAgent`).
 */
@Injectable()
export class RechargeService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RechargeService.name);
  private readonly cursors: SocialCursorCodec;
  private readonly notifier = new Notifier();
  private timer: NodeJS.Timeout | undefined;
  private inFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly media: MediaService,
    private readonly orders: RechargeOrdersService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  onModuleInit(): void {
    if (this.config.recharge.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.purge()
        .then((n) => {
          if (n > 0) this.logger.log({ purged: n }, 'Recharge applications purged (retention)');
        })
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Recharge retention step failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.recharge.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }

  /** The retention step (the sweeper; `recharge-admin purge` runs the same function). */
  purge(): Promise<number> {
    return purgeApplications(
      this.prisma,
      (keys) => this.media.deletePrivateObjects(keys),
      this.clock.now(),
      this.config.recharge.kycRetentionDays,
      'sweeper',
    );
  }

  private get zone(): string {
    return this.config.live.rankingsTimeZone;
  }

  private after(cursor: string | undefined, scope: string): SocialPosition | null {
    if (cursor === undefined) return null;
    const after = this.cursors.decode(cursor, scope);
    if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    return after;
  }

  private async summaries(ids: readonly string[]): Promise<Map<string, UserSummaryDto>> {
    if (ids.length === 0) return new Map();
    const users = await this.prisma.user.findMany({
      where: { id: { in: [...new Set(ids)] } },
      select: USER_SUMMARY_SELECT,
    });
    return new Map(users.map((u) => [u.id, userSummary(u)]));
  }

  /** Whether either of `a` / `b` blocked the other. */
  private async blocked(a: string, b: string): Promise<boolean> {
    const [row] = await this.prisma.$queryRaw<{ blocked: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM user_blocks
                      WHERE (blocker_id = ${a}::uuid AND blocked_id = ${b}::uuid)
                         OR (blocker_id = ${b}::uuid AND blocked_id = ${a}::uuid)) AS blocked`;
    return row?.blocked ?? false;
  }

  /** An ACTIVE user by username (an `@` and case ignored) or id, or null. */
  private async activeUser(raw: string): Promise<{ id: string } | null> {
    const value = raw.trim().replace(/^@/, '');
    if (UUID.test(value)) {
      return this.prisma.user.findFirst({
        where: { id: value.toLowerCase(), status: 'ACTIVE' },
        select: { id: true },
      });
    }
    const userId = await resolveUserIdByUsername(this.prisma, value.toLowerCase());
    if (userId === null) return null;
    return this.prisma.user.findUnique({ where: { id: userId, status: 'ACTIVE' }, select: { id: true } });
  }

  private rules(): RechargeAgentMeDto['rules'] {
    const r = this.config.recharge;
    const e = this.config.economy;
    return {
      activationMinCoins: r.activationMinCoins,
      cherryUnit: r.cherryRate.cherries,
      coinsPerCherryUnit: r.cherryRate.coins,
      minCherries: r.cherryMin,
      stepCherries: r.cherryStep,
      requestTtlMinutes: r.requestTtlMinutes,
      payout: {
        currency: e.currency,
        rateCherries: e.rateCherries,
        rateMinor: e.rateMinor,
        minAmountMinor: e.minWithdrawalMinor,
        payoutDays: e.payoutDays,
      },
      orders: {
        enabled: r.orders.enabled,
        minCoins: r.orders.minCoins,
        maxCoins: r.orders.maxCoins,
        requestTtlMinutes: r.orders.requestTtlMinutes,
        paymentTtlMinutes: r.orders.paymentTtlMinutes,
        disputeAfterMinutes: r.orders.disputeAfterMinutes,
      },
    };
  }

  /** Sales totals today (the economy's zone), in 7 and in 30 days, of `where`. */
  private async salesStats(where: Prisma.Sql): Promise<SalesStatsDto> {
    const now = this.clock.now();
    const today = dayStart(now, this.zone);
    const d7 = new Date(now.getTime() - 7 * DAY_MS);
    const d30 = new Date(now.getTime() - 30 * DAY_MS);
    const [row] = await this.prisma.$queryRaw<
      { tc: number; tq: bigint; c7: number; q7: bigint; c30: number; q30: bigint }[]
    >`
      SELECT count(*) FILTER (WHERE created_at >= ${today})::int AS tc,
             COALESCE(sum(coins) FILTER (WHERE created_at >= ${today}), 0)::bigint AS tq,
             count(*) FILTER (WHERE created_at >= ${d7})::int AS c7,
             COALESCE(sum(coins) FILTER (WHERE created_at >= ${d7}), 0)::bigint AS q7,
             count(*)::int AS c30, COALESCE(sum(coins), 0)::bigint AS q30
        FROM recharge_sales WHERE created_at >= ${d30} AND ${where}`;
    return {
      today: { count: row?.tc ?? 0, coins: Number(row?.tq ?? 0n) },
      last7Days: { count: row?.c7 ?? 0, coins: Number(row?.q7 ?? 0n) },
      last30Days: { count: row?.c30 ?? 0, coins: Number(row?.q30 ?? 0n) },
    };
  }

  private async todayCherries(
    db: Pick<Prisma.TransactionClient, '$queryRaw'>,
    agentUserId: string,
  ): Promise<bigint> {
    const since = dayStart(this.clock.now(), this.zone);
    const [row] = await db.$queryRaw<{ total: bigint }[]>`
      SELECT COALESCE(sum(cherries), 0)::bigint AS total FROM recharge_cherry_requests
       WHERE agent_user_id = ${agentUserId}::uuid AND status = 'CONFIRMED' AND decided_at >= ${since}`;
    return row?.total ?? 0n;
  }

  /** The agent's daily cherry cap: their own (`set-cap`), else the server's; 0 = no cap (owner: «حد وكيل مفتوح»). */
  private capOf(agent: { dailyCherryCap: bigint | null }): bigint {
    return agent.dailyCherryCap ?? BigInt(this.config.recharge.dailyCherryCap);
  }

  /** Whether `today` plus `cherries` goes over the agent's cap (never when the cap is 0, i.e. none). */
  private overCap(agent: { dailyCherryCap: bigint | null }, today: bigint, cherries: bigint): boolean {
    const cap = this.capOf(agent);
    return cap > 0n && today + cherries > cap;
  }

  private activeEmployment(userId: string) {
    return this.prisma.rechargeEmployee.findFirst({
      where: { employeeUserId: userId, removedAt: null },
      include: { agent: { select: { userId: true, code: true, status: true } } },
    });
  }

  /** D287: an employment row as the rules' job (with whether the employee is a Kabso Team account now). */
  private async jobOf(
    row: {
      employeeUserId: string;
      timeZone: string;
      schedule: unknown;
      canBuyCherries: boolean;
      receivesOrders: boolean;
    },
    db: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<EmployeeJob> {
    return {
      timeZone: row.timeZone,
      schedule: row.schedule as WeeklySlot[],
      canBuyCherries: row.canBuyCherries,
      receivesOrders: row.receivesOrders,
      kabsoTeam: await isLimitedStaff(db, row.employeeUserId),
    };
  }

  // ---- The caller ------------------------------------------------------------------------------------

  /** `GET /me/recharge-agent`. */
  async me(userId: string): Promise<RechargeAgentMeDto> {
    const [app, agent, job] = await Promise.all([
      this.prisma.rechargeAgentApplication.findFirst({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        select: { status: true, createdAt: true, decidedAt: true, rejectReason: true },
      }),
      this.prisma.rechargeAgent.findUnique({ where: { userId } }),
      this.activeEmployment(userId),
    ]);
    const status: Status = agent ? agent.status : app ? app.status : 'NONE';
    let agentDto: RechargeAgentMeDto['agent'] = null;
    if (agent) {
      const [sales, today, totals] = await Promise.all([
        this.salesStats(Prisma.sql`agent_user_id = ${userId}::uuid`),
        this.todayCherries(this.prisma, userId),
        this.orders.agentTotals(userId),
      ]);
      agentDto = {
        code: agent.code,
        status: agent.status,
        stockCoins: Number(agent.stockCoins),
        heldCoins: totals.heldCoins,
        openOrders: totals.openOrders,
        activatedAt: agent.activatedAt?.toISOString() ?? null,
        dailyCherryCap: Number(this.capOf(agent)),
        todayCherries: Number(today),
        availability: {
          timeZone: agent.availabilityTimeZone,
          slots: agent.availability as unknown as AvailabilitySlot[],
        },
        sales,
      };
    }
    let employment: RechargeAgentMeDto['employment'] = null;
    if (job) {
      const owner = await this.summaries([job.agentUserId]);
      const schedule = job.schedule as unknown as WeeklySlot[];
      employment = {
        agentCode: job.agent.code,
        agent: owner.get(job.agentUserId)!,
        timeZone: job.timeZone,
        schedule,
        onShiftNow: slotAt(schedule, job.timeZone, this.clock.now()) !== null,
        canBuyCherries: job.canBuyCherries,
        receivesOrders: job.receivesOrders,
        kabsoTeam: await isLimitedStaff(this.prisma, userId),
      };
    }
    return {
      status,
      canApply: !agent && (app === null || app.status === 'REJECTED') && job === null,
      application: app
        ? {
            status: app.status,
            submittedAt: app.createdAt.toISOString(),
            decidedAt: app.decidedAt?.toISOString() ?? null,
            rejectReason: app.rejectReason,
          }
        : null,
      agent: agentDto,
      employment,
      rules: this.rules(),
    };
  }

  /** `POST /me/recharge-agent/application`. */
  async apply(userId: string, body: unknown): Promise<RechargeAgentMeDto> {
    // v1.80-kyc (D227): with Didit on the ID pictures are not asked (the identity check is, before activation).
    const kyc = kycOn(await kycSettingsIn(this.prisma));
    if (!kyc) await this.media.assertEnabled();
    const input = parse(applicationSchema, body);
    const [pending, agent, job] = await Promise.all([
      this.prisma.rechargeAgentApplication.count({ where: { userId, status: 'PENDING' } }),
      this.prisma.rechargeAgent.count({ where: { userId } }),
      this.activeEmployment(userId),
    ]);
    if (pending > 0 || agent > 0 || job) throw new AppException(ErrorCode.RECHARGE_APPLICATION_NOT_ALLOWED);
    // v1.75-live (D285, §10.96.13): the optional recruiter field (400 `recruiter` when it names no recruiter).
    const recruiter = await recruiterOfForm(this.prisma, input.recruiter, userId);
    const id = uuidv7();
    const { photoKey, selfieKey } = await takeIdPictures(
      this.media,
      userId,
      input,
      { photo: privateKeyOf(id, 'photo'), selfie: privateKeyOf(id, 'selfie') },
      kyc,
    );
    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.rechargeAgentApplication.create({
          data: {
            id,
            userId,
            fullName: input.fullName.replace(/\s+/gu, ' '),
            phone: input.phone,
            photoKey,
            selfieKey,
            locations: input.locations,
            paymentMethods: input.paymentMethods,
            createdAt: this.clock.now(),
            recruiterUserId: recruiter,
          },
        });
        // Field names only: the application's data never goes to logs or the audit trail.
        await tx.auditLog.create({
          data: {
            actorUserId: userId,
            action: AuditAction.RECHARGE_APPLICATION_SUBMIT,
            targetType: 'recharge_application',
            targetId: id,
            metadata: { countries: input.locations.map((l) => l.country) },
          },
        });
      });
    } catch (err) {
      const taken = [photoKey, selfieKey].filter((k): k is string => k !== null);
      if (taken.length > 0) await this.media.deletePrivateObjects(taken).catch(() => undefined);
      if (isUniqueViolation(err)) throw new AppException(ErrorCode.RECHARGE_APPLICATION_NOT_ALLOWED);
      throw err;
    }
    return this.me(userId);
  }

  /** `PUT /me/recharge-agent/availability`. */
  async setAvailability(userId: string, body: unknown): Promise<AvailabilityDto> {
    const agent = await this.prisma.rechargeAgent.findUnique({ where: { userId }, select: { userId: true } });
    if (!agent) throw new AppException(ErrorCode.NOT_FOUND);
    const input = parse(availabilitySchema, body);
    await this.prisma.$transaction(async (tx) => {
      await tx.rechargeAgent.update({
        where: { userId },
        data: {
          availability: input.slots,
          availabilityTimeZone: input.timeZone,
          updatedAt: this.clock.now(),
        },
      });
      await tx.auditLog.create({
        data: {
          actorUserId: userId,
          action: AuditAction.RECHARGE_AVAILABILITY,
          targetType: 'recharge_agent',
          targetId: userId,
          metadata: { slots: input.slots.length, timeZone: input.timeZone },
        },
      });
    });
    return { timeZone: input.timeZone, slots: input.slots };
  }

  // ---- Selling ---------------------------------------------------------------------------------------

  /** The agent the caller sells for: themselves, or their employer (with the caller's hours). */
  private async sellerRole(
    userId: string,
  ): Promise<
    | { agentUserId: string; employee: null }
    | { agentUserId: string; employee: { timeZone: string; schedule: WeeklySlot[] } }
  > {
    const own = await this.prisma.rechargeAgent.findUnique({ where: { userId }, select: { userId: true } });
    if (own) return { agentUserId: userId, employee: null };
    const job = await this.activeEmployment(userId);
    if (!job) throw new AppException(ErrorCode.NOT_FOUND);
    return {
      agentUserId: job.agentUserId,
      employee: { timeZone: job.timeZone, schedule: job.schedule as unknown as WeeklySlot[] },
    };
  }

  private async saleDtos(
    rows: readonly RechargeSale[],
    codes: Map<string, string>,
  ): Promise<RechargeSaleDto[]> {
    const users = await this.summaries(rows.flatMap((r) => [r.buyerUserId, r.sellerUserId]));
    const blank = (id: string): UserSummaryDto => ({ id, username: '', displayName: '', avatarUrl: null });
    return rows.map((r) => ({
      id: r.id,
      coins: Number(r.coins),
      buyer: users.get(r.buyerUserId) ?? blank(r.buyerUserId),
      seller: users.get(r.sellerUserId) ?? blank(r.sellerUserId),
      agentCode: codes.get(r.agentUserId) ?? '',
      createdAt: r.createdAt.toISOString(),
    }));
  }

  /** `POST /me/recharge-agent/sales` (Idempotency-Key). */
  async sell(
    userId: string,
    rawKey: string | undefined,
    body: unknown,
  ): Promise<{ created: boolean; result: RechargeSaleDto }> {
    const clientId = idempotencyKey(rawKey);
    const input = parse(saleBodySchema, body);
    const role = await this.sellerRole(userId);
    const agent = await this.prisma.rechargeAgent.findUniqueOrThrow({
      where: { userId: role.agentUserId },
      select: { status: true, code: true, user: { select: { status: true } } },
    });
    const buyer = await this.activeUser(input.buyer);
    const replay = async () => {
      const sale = await this.prisma.rechargeSale.findUnique({
        where: { sellerUserId_clientId: { sellerUserId: userId, clientId } },
      });
      if (!sale) return null;
      if (Number(sale.coins) !== input.coins || sale.buyerUserId !== buyer?.id) {
        throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
      }
      const [dto] = await this.saleDtos([sale], new Map([[sale.agentUserId, agent.code ?? '']]));
      return { created: false, result: dto! };
    };
    const earlier = await replay();
    if (earlier) return earlier;
    if (agent.status !== 'ACTIVE' || agent.code === null || agent.user.status !== 'ACTIVE') {
      throw new AppException(ErrorCode.RECHARGE_AGENT_NOT_ACTIVE);
    }
    const now = this.clock.now();
    // D287 (owner): an employee who is a Kabso Team account now sells nothing for the agent.
    if (role.employee && (await isLimitedStaff(this.prisma, userId))) throw blockError('STAFF');
    if (role.employee && slotAt(role.employee.schedule, role.employee.timeZone, now) === null) {
      throw new AppException(ErrorCode.RECHARGE_OFF_SHIFT);
    }
    if (!buyer) throw new AppException(ErrorCode.NOT_FOUND);
    if (buyer.id === userId || buyer.id === role.agentUserId) {
      throw AppException.validation([{ field: 'buyer', issue: 'invalid_value' }]);
    }
    if ((await this.blocked(buyer.id, userId)) || (await this.blocked(buyer.id, role.agentUserId))) {
      throw new AppException(ErrorCode.NOT_FOUND);
    }
    const coins = BigInt(input.coins);
    const saleId = uuidv7();
    try {
      const { sale, stock } = await this.prisma.$transaction(async (tx) => {
        const stockAfter = await moveStockIn(tx, role.agentUserId, -coins, 'SALE', saleId, now);
        if (stockAfter === null) throw new AppException(ErrorCode.RECHARGE_STOCK_INSUFFICIENT);
        const created = await tx.rechargeSale.create({
          data: {
            id: saleId,
            agentUserId: role.agentUserId,
            sellerUserId: userId,
            buyerUserId: buyer.id,
            clientId,
            coins,
            createdAt: now,
          },
        });
        const wallet = await creditIn(tx, buyer.id, coins, 'RECHARGE_PURCHASE', saleId);
        // v1.56-social (D187, §10.50): the buyer's coins count toward the daily recharge badge.
        await recordRechargeIn(
          tx,
          { userId: buyer.id, coins, source: 'AGENT_SALE', now },
          this.config.recharge.badges,
        );
        // v1.74-social (D217): the invitee's first recharge pays the inviter a share (held).
        await referralRechargeIn(
          tx,
          { userId: buyer.id, coins, reason: 'RECHARGE_PURCHASE', reference: saleId, now },
          this.config.economy.cherriesPerCoin,
        );
        await tx.auditLog.create({
          data: {
            actorUserId: userId,
            action: AuditAction.RECHARGE_SALE,
            targetType: 'recharge_sale',
            targetId: saleId,
            metadata: {
              agent: role.agentUserId,
              buyer: buyer.id,
              coins: Number(coins),
              stockAfter: Number(stockAfter),
              buyerBalance: Number(wallet.coins),
              byEmployee: role.employee !== null,
            },
          },
        });
        await this.notifier.notify(tx, {
          type: 'RECHARGE_COINS_RECEIVED',
          recipientId: buyer.id,
          actorId: userId,
          rechargeSaleId: saleId,
        });
        return { sale: created, stock: stockAfter };
      });
      const [dto] = await this.saleDtos([sale], new Map([[sale.agentUserId, agent.code]]));
      return { created: true, result: { ...dto!, stockAfter: Number(stock) } };
    } catch (err) {
      if (err instanceof AppException) throw err;
      if (isUniqueViolation(err)) {
        const raced = await replay();
        if (raced) return raced;
      }
      throw err;
    }
  }

  /** `GET /me/recharge-agent/sales`: the agent's, or the employee's own. */
  async sales(userId: string, query: PageQuery): Promise<PageDto<RechargeSaleDto>> {
    const role = await this.sellerRole(userId);
    const scope = `recharge-sales:${userId}`;
    const after = this.after(query.cursor, scope);
    const rows = await this.prisma.rechargeSale.findMany({
      where: {
        agentUserId: role.agentUserId,
        ...(role.employee ? { sellerUserId: userId } : {}),
        ...(after
          ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
    });
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const agent = await this.prisma.rechargeAgent.findUnique({
      where: { userId: role.agentUserId },
      select: { code: true },
    });
    const last = page[page.length - 1];
    return {
      data: await this.saleDtos(page, new Map([[role.agentUserId, agent?.code ?? '']])),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  // ---- Employees -------------------------------------------------------------------------------------

  private async requireAgent(userId: string): Promise<void> {
    const agent = await this.prisma.rechargeAgent.findUnique({ where: { userId }, select: { userId: true } });
    if (!agent) throw new AppException(ErrorCode.NOT_FOUND);
  }

  private async employeeDto(row: {
    agentUserId: string;
    employeeUserId: string;
    timeZone: string;
    schedule: unknown;
    createdAt: Date;
    canBuyCherries: boolean;
    receivesOrders: boolean;
  }): Promise<RechargeEmployeeDto> {
    const users = await this.summaries([row.employeeUserId]);
    const schedule = row.schedule as WeeklySlot[];
    const acts = await employeeStatsIn(
      this.prisma,
      row.agentUserId,
      row.employeeUserId,
      this.clock.now(),
      this.zone,
    );
    return {
      user: users.get(row.employeeUserId)!,
      timeZone: row.timeZone,
      schedule,
      onShiftNow: slotAt(schedule, row.timeZone, this.clock.now()) !== null,
      addedAt: row.createdAt.toISOString(),
      canBuyCherries: row.canBuyCherries,
      receivesOrders: row.receivesOrders,
      ...acts,
      kabsoTeam: await isLimitedStaff(this.prisma, row.employeeUserId),
    };
  }

  /** `GET /me/recharge-agent/employees`. */
  async employees(userId: string): Promise<{ data: RechargeEmployeeDto[] }> {
    await this.requireAgent(userId);
    const rows = await this.prisma.rechargeEmployee.findMany({
      where: { agentUserId: userId, removedAt: null },
      orderBy: { createdAt: 'asc' },
    });
    return { data: await Promise.all(rows.map((r) => this.employeeDto(r))) };
  }

  private async employeeByUsername(agentUserId: string, username: string) {
    const profile = await this.prisma.userProfile.findUnique({
      where: { username: username.trim().replace(/^@/, '').toLowerCase() },
      select: { userId: true },
    });
    if (!profile) throw new AppException(ErrorCode.NOT_FOUND);
    const row = await this.prisma.rechargeEmployee.findFirst({
      where: { agentUserId, employeeUserId: profile.userId, removedAt: null },
    });
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    return row;
  }

  /** `POST /me/recharge-agent/employees`. */
  async addEmployee(userId: string, body: unknown): Promise<RechargeEmployeeDto> {
    await this.requireAgent(userId);
    const input = parse(employeeAddSchema, body);
    const user = await this.activeUser(
      input.username.startsWith('@') ? input.username : `@${input.username}`,
    );
    if (!user || (await this.blocked(userId, user.id))) throw new AppException(ErrorCode.NOT_FOUND);
    const [isAgent, pending, job, count] = await Promise.all([
      this.prisma.rechargeAgent.count({ where: { userId: user.id } }),
      this.prisma.rechargeAgentApplication.count({ where: { userId: user.id, status: 'PENDING' } }),
      this.activeEmployment(user.id),
      this.prisma.rechargeEmployee.count({ where: { agentUserId: userId, removedAt: null } }),
    ]);
    if (
      user.id === userId ||
      isAgent > 0 ||
      pending > 0 ||
      job ||
      count >= this.config.recharge.maxEmployees
    ) {
      throw new AppException(ErrorCode.RECHARGE_EMPLOYEE_NOT_ALLOWED);
    }
    // D287 (owner): a Kabso Team account (D283's limited staff) is never a recharge agent's employee.
    if (await isLimitedStaff(this.prisma, user.id))
      throw new AppException(ErrorCode.RECHARGE_EMPLOYEE_IS_STAFF);
    const now = this.clock.now();
    try {
      const row = await this.prisma.$transaction(async (tx) => {
        const created = await tx.rechargeEmployee.create({
          data: {
            id: uuidv7(),
            agentUserId: userId,
            employeeUserId: user.id,
            timeZone: input.timeZone,
            schedule: input.schedule,
            canBuyCherries: input.canBuyCherries ?? true,
            receivesOrders: input.receivesOrders ?? true,
            createdAt: now,
          },
        });
        await tx.auditLog.create({
          data: {
            actorUserId: userId,
            action: AuditAction.RECHARGE_EMPLOYEE_ADD,
            targetType: 'recharge_employee',
            targetId: created.id,
            metadata: {
              employee: user.id,
              timeZone: input.timeZone,
              slots: input.schedule.length,
              canBuyCherries: created.canBuyCherries,
              receivesOrders: created.receivesOrders,
            },
          },
        });
        return created;
      });
      return this.employeeDto(row);
    } catch (err) {
      if (isUniqueViolation(err)) throw new AppException(ErrorCode.RECHARGE_EMPLOYEE_NOT_ALLOWED);
      throw err;
    }
  }

  /** `PUT /me/recharge-agent/employees/{username}`. */
  async updateEmployee(userId: string, username: string, body: unknown): Promise<RechargeEmployeeDto> {
    await this.requireAgent(userId);
    const row = await this.employeeByUsername(userId, username);
    const input = parse(employeeUpdateSchema, body);
    const updated = await this.prisma.$transaction(async (tx) => {
      const r = await tx.rechargeEmployee.update({
        where: { id: row.id },
        data: {
          timeZone: input.timeZone,
          schedule: input.schedule,
          ...(input.canBuyCherries === undefined ? {} : { canBuyCherries: input.canBuyCherries }),
          ...(input.receivesOrders === undefined ? {} : { receivesOrders: input.receivesOrders }),
        },
      });
      await tx.auditLog.create({
        data: {
          actorUserId: userId,
          action: AuditAction.RECHARGE_EMPLOYEE_UPDATE,
          targetType: 'recharge_employee',
          targetId: row.id,
          metadata: {
            timeZone: input.timeZone,
            slots: input.schedule.length,
            canBuyCherries: r.canBuyCherries,
            receivesOrders: r.receivesOrders,
            before: { canBuyCherries: row.canBuyCherries, receivesOrders: row.receivesOrders },
          },
        },
      });
      return r;
    });
    return this.employeeDto(updated);
  }

  /** `DELETE /me/recharge-agent/employees/{username}`. */
  async removeEmployee(userId: string, username: string): Promise<void> {
    await this.requireAgent(userId);
    const row = await this.employeeByUsername(userId, username);
    await this.prisma.$transaction(async (tx) => {
      await tx.rechargeEmployee.update({ where: { id: row.id }, data: { removedAt: this.clock.now() } });
      await tx.auditLog.create({
        data: {
          actorUserId: userId,
          action: AuditAction.RECHARGE_EMPLOYEE_REMOVE,
          targetType: 'recharge_employee',
          targetId: row.id,
          metadata: { employee: row.employeeUserId },
        },
      });
    });
  }

  // ---- Directory -------------------------------------------------------------------------------------

  private listing(
    a: {
      userId: string;
      code: string | null;
      locations: unknown;
      paymentTypes: unknown;
      availability: unknown;
      availabilityTimeZone: string;
    },
    user: UserSummaryDto,
    country: string | null,
    now: Date,
  ): RechargeAgentListingDto {
    const types = a.paymentTypes as Record<string, string[]>;
    const slot = slotAt(a.availability as AvailabilitySlot[], a.availabilityTimeZone, now);
    return {
      code: a.code!,
      user,
      locations: a.locations as { country: string; cities: string[] }[],
      paymentMethodTypes:
        country === null ? [...new Set(Object.values(types).flat())] : (types[country] ?? []),
      availableNow: slot ? { whatsapp: slot.whatsapp, paymentMethod: slot.paymentMethod } : null,
    };
  }

  private activeAgentWhere(): Prisma.RechargeAgentWhereInput {
    return { status: 'ACTIVE', code: { not: null }, user: { status: 'ACTIVE' } };
  }

  /** `GET /recharge-agents?country=`: available now first, then by code; an offset cursor. */
  async directory(country: unknown, query: PageQuery): Promise<PageDto<RechargeAgentListingDto>> {
    if (country === undefined) throw AppException.validation([{ field: 'country', issue: 'required' }]);
    const c = countrySchema.safeParse(country);
    if (!c.success) throw AppException.validation([{ field: 'country', issue: 'invalid_value' }]);
    const scope = `recharge-directory:${c.data}`;
    let offset = 0;
    if (query.cursor !== undefined) {
      const pos = this.cursors.decode(query.cursor, scope);
      const n = pos ? Number(pos.id) : NaN;
      if (!pos || !Number.isInteger(n) || n < 0) {
        throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
      }
      offset = n;
    }
    const rows = await this.prisma.rechargeAgent.findMany({
      where: { ...this.activeAgentWhere(), countries: { has: c.data } },
      orderBy: { codeNumber: 'asc' },
      take: DIRECTORY_MAX,
    });
    const users = await this.summaries(rows.map((r) => r.userId));
    const now = this.clock.now();
    const all = rows
      .filter((r) => users.has(r.userId))
      .map((r) => this.listing(r, users.get(r.userId)!, c.data, now));
    const sorted = [
      ...all.filter((l) => l.availableNow !== null),
      ...all.filter((l) => l.availableNow === null),
    ];
    const page = sorted.slice(offset, offset + query.limit);
    const hasMore = offset + query.limit < sorted.length;
    return {
      data: page,
      page: {
        hasMore,
        nextCursor: hasMore
          ? this.cursors.encode(scope, { at: now, id: String(offset + query.limit) })
          : null,
      },
    };
  }

  /** `GET /recharge-agents/{code}`. */
  async byCode(raw: string): Promise<RechargeAgentListingDto> {
    const code = normalizeAgentCode(raw);
    const agent =
      code === null
        ? null
        : await this.prisma.rechargeAgent.findFirst({ where: { ...this.activeAgentWhere(), code } });
    if (!agent) throw new AppException(ErrorCode.NOT_FOUND);
    const users = await this.summaries([agent.userId]);
    return this.listing(agent, users.get(agent.userId)!, null, this.clock.now());
  }

  // ---- Cherry sales from hosts -----------------------------------------------------------------------

  /**
   * The viewer's side of a cherry request (v1.87-social, D287): the host, the agent, or — for the agent's side — an
   * active employee of the agent (`job`), or null when the viewer has nothing to do with it.
   */
  private async cherrySideOf(
    userId: string,
    row: { agentUserId: string; hostUserId: string },
    db: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<{ side: CherrySide; job: EmployeeJob | null } | null> {
    if (row.hostUserId === userId) return { side: 'HOST', job: null };
    if (row.agentUserId === userId) return { side: 'AGENT', job: null };
    const job = await db.rechargeEmployee.findFirst({
      where: { employeeUserId: userId, agentUserId: row.agentUserId, removedAt: null },
    });
    return job ? { side: 'AGENT', job: await this.jobOf(job, db) } : null;
  }

  private async requestDtos(
    rows: readonly RechargeCherryRequest[],
    viewer: string,
  ): Promise<RechargeCherryRequestDto[]> {
    const users = await this.summaries(
      rows.flatMap((r) => [r.agentUserId, r.hostUserId, ...(r.actedBy === null ? [] : [r.actedBy])]),
    );
    const agents = await this.prisma.rechargeAgent.findMany({
      where: { userId: { in: [...new Set(rows.map((r) => r.agentUserId))] } },
      select: { userId: true, code: true },
    });
    const codes = new Map(agents.map((a) => [a.userId, a.code ?? '']));
    // D287: the viewer's job for the requests of an agent they work for (at most one active employment).
    const employer = rows.find((r) => r.hostUserId !== viewer && r.agentUserId !== viewer)?.agentUserId;
    const job =
      employer === undefined
        ? null
        : ((await this.cherrySideOf(viewer, { agentUserId: employer, hostUserId: '' }))?.job ?? null);
    const nowDate = this.clock.now();
    const now = nowDate.getTime();
    const blank = (id: string): UserSummaryDto => ({ id, username: '', displayName: '', avatarUrl: null });
    return rows.map((r) => {
      const status = r.status === 'PENDING' && r.expiresAt.getTime() <= now ? 'EXPIRED' : r.status;
      const initiatedBy: CherrySide = r.createdBy === r.hostUserId ? 'HOST' : 'AGENT';
      const viewerSide: CherrySide = r.hostUserId === viewer ? 'HOST' : 'AGENT';
      const employee = viewerSide === 'AGENT' && r.agentUserId !== viewer;
      const block: AgentSideBlock | null = employee
        ? job === null
          ? 'NOT_PERMITTED'
          : agentSideBlock(viewer, job, 'BUY_CHERRIES', nowDate)
        : null;
      return {
        id: r.id,
        status,
        cherries: Number(r.cherries),
        coins: Number(r.coins),
        payoutMinor: Number(r.payoutMinor),
        currency: r.currency,
        agentCode: codes.get(r.agentUserId) ?? '',
        agent: users.get(r.agentUserId) ?? blank(r.agentUserId),
        host: users.get(r.hostUserId) ?? blank(r.hostUserId),
        initiatedBy,
        createdAt: r.createdAt.toISOString(),
        expiresAt: r.expiresAt.toISOString(),
        decidedAt: r.decidedAt?.toISOString() ?? null,
        viewerSide,
        actions: cherryActions(viewerSide, initiatedBy, status === 'PENDING', block),
        viewerBlock: block,
        actedBy: r.actedBy === null ? null : (users.get(r.actedBy) ?? blank(r.actedBy)),
      };
    });
  }

  /**
   * D287: the agent's side people a host's cherry offer goes to — the agent and every employee allowed to buy
   * cherries («يمكنه شراء الكرز») who is on shift now.
   */
  private async cherryDeskIn(
    tx: Prisma.TransactionClient,
    agentUserId: string,
    now: Date,
  ): Promise<string[]> {
    const rows = await tx.rechargeEmployee.findMany({
      where: { agentUserId, removedAt: null, canBuyCherries: true },
      select: { employeeUserId: true, timeZone: true, schedule: true },
    });
    const desk = rows.filter((r) =>
      onShift({ timeZone: r.timeZone, schedule: r.schedule as unknown as WeeklySlot[] }, now),
    );
    // D287 (owner): an employee who is a Kabso Team account now cannot act, so is not told.
    const staff = await limitedStaffAmong(
      tx,
      desk.map((r) => r.employeeUserId),
    );
    return [agentUserId, ...desk.map((r) => r.employeeUserId).filter((id) => !staff.has(id))];
  }

  /** Withdrawable cherries of `hostId` now: the balance less the locked task cherries (D184). */
  private async withdrawable(db: Prisma.TransactionClient | PrismaService, hostId: string): Promise<bigint> {
    const [wallet, lock] = await Promise.all([
      db.cherryWallet.findUnique({ where: { userId: hostId }, select: { cherries: true } }),
      taskCherryLockIn(db, hostId, this.config.economy),
    ]);
    return (wallet?.cherries ?? 0n) - lock.lockedCherries;
  }

  /**
   * `POST /recharge-cherry-requests` (Idempotency-Key). D287: an employee (with «يمكنه شراء الكرز», on shift) asks a
   * host for the agent — the request is the agent's (stock, caps, money), `actedBy` the employee.
   */
  async createCherryRequest(
    userId: string,
    rawKey: string | undefined,
    body: unknown,
  ): Promise<{ created: boolean; result: RechargeCherryRequestDto }> {
    const clientId = idempotencyKey(rawKey);
    const input = parse(cherryCreateSchema, body);
    let agentUserId: string;
    let hostUserId: string;
    let job: EmployeeJob | null = null;
    if (input.agentCode !== undefined) {
      const code = normalizeAgentCode(input.agentCode);
      const agent = code === null ? null : await this.prisma.rechargeAgent.findUnique({ where: { code } });
      const owner = agent ? await this.activeUser(agent.userId) : null;
      if (!agent || !owner) throw new AppException(ErrorCode.NOT_FOUND);
      agentUserId = agent.userId;
      hostUserId = userId;
    } else {
      const own = await this.prisma.rechargeAgent.findUnique({ where: { userId }, select: { userId: true } });
      if (own) agentUserId = userId;
      else {
        const employment = await this.activeEmployment(userId);
        if (!employment) throw new AppException(ErrorCode.NOT_FOUND);
        agentUserId = employment.agentUserId;
        job = await this.jobOf(employment);
      }
      const host = await this.activeUser(input.host!.startsWith('@') ? input.host! : `@${input.host!}`);
      if (!host) throw new AppException(ErrorCode.NOT_FOUND);
      hostUserId = host.id;
    }
    if (agentUserId === hostUserId || (job !== null && hostUserId === userId))
      throw AppException.validation([{ field: 'host', issue: 'invalid_value' }]);
    if (
      (await this.blocked(agentUserId, hostUserId)) ||
      (job !== null && (await this.blocked(userId, hostUserId)))
    ) {
      throw new AppException(ErrorCode.NOT_FOUND);
    }
    const r = this.config.recharge;
    const cherries = BigInt(input.cherries);
    if (!validCherryAmount(cherries, r.cherryMin, r.cherryStep)) {
      throw AppException.validation([{ field: 'cherries', issue: 'invalid_value' }]);
    }
    const replay = async () => {
      const row = await this.prisma.rechargeCherryRequest.findUnique({
        where: { createdBy_clientId: { createdBy: userId, clientId } },
      });
      if (!row) return null;
      if (row.cherries !== cherries || row.agentUserId !== agentUserId || row.hostUserId !== hostUserId) {
        throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
      }
      const [dto] = await this.requestDtos([row], userId);
      return { created: false, result: dto! };
    };
    const earlier = await replay();
    if (earlier) return earlier;
    const agent = await this.prisma.rechargeAgent.findUniqueOrThrow({ where: { userId: agentUserId } });
    if (agent.status !== 'ACTIVE') throw new AppException(ErrorCode.RECHARGE_AGENT_NOT_ACTIVE);
    const now = this.clock.now();
    const block = agentSideBlock(userId, job, 'BUY_CHERRIES', now);
    if (block !== null) throw blockError(block);
    await this.prisma.rechargeCherryRequest.updateMany({
      where: { agentUserId, hostUserId, status: 'PENDING', expiresAt: { lte: now } },
      data: { status: 'EXPIRED', decidedAt: now },
    });
    const open = await this.prisma.rechargeCherryRequest.count({
      where: { agentUserId, hostUserId, status: 'PENDING' },
    });
    if (open > 0) throw new AppException(ErrorCode.RECHARGE_CHERRY_REQUEST_PENDING);
    if ((await this.withdrawable(this.prisma, hostUserId)) < cherries) {
      throw new AppException(ErrorCode.INSUFFICIENT_CHERRIES);
    }
    if (this.overCap(agent, await this.todayCherries(this.prisma, agentUserId), cherries)) {
      throw new AppException(ErrorCode.RECHARGE_CHERRY_CAP_REACHED);
    }
    const e = this.config.economy;
    const id = uuidv7();
    try {
      const row = await this.prisma.$transaction(async (tx) => {
        const created = await tx.rechargeCherryRequest.create({
          data: {
            id,
            agentUserId,
            hostUserId,
            createdBy: userId,
            clientId,
            cherries,
            coins: cherriesToCoins(cherries, r.cherryRate),
            payoutMinor: cherriesPayoutMinor(cherries, e.rateCherries, e.rateMinor),
            currency: e.currency,
            createdAt: now,
            expiresAt: new Date(now.getTime() + r.requestTtlMinutes * 60_000),
            actedBy: job === null ? null : userId,
          },
        });
        await tx.auditLog.create({
          data: {
            actorUserId: userId,
            action: AuditAction.RECHARGE_CHERRY_REQUEST,
            targetType: 'recharge_cherry_request',
            targetId: id,
            metadata: {
              agent: agentUserId,
              host: hostUserId,
              cherries: Number(cherries),
              byEmployee: job !== null,
              ...(job === null ? {} : { actedBy: userId }),
            },
          },
        });
        if (userId === hostUserId) {
          // D287: the agent and every allowed employee on shift; the first of them to answer decides.
          for (const recipientId of await this.cherryDeskIn(tx, agentUserId, now)) {
            await this.notifier.notify(tx, { type: 'RECHARGE_CHERRY_REQUEST', recipientId, actorId: userId });
          }
        } else {
          // The host sees the agent (an employee acts in the agent's name).
          await this.notifier.notify(tx, {
            type: 'RECHARGE_CHERRY_REQUEST',
            recipientId: hostUserId,
            actorId: agentUserId,
          });
        }
        return created;
      });
      const [dto] = await this.requestDtos([row], userId);
      return { created: true, result: dto! };
    } catch (err) {
      if (isUniqueViolation(err)) {
        const raced = await replay();
        if (raced) return raced;
      }
      throw err;
    }
  }

  /** `GET /recharge-cherry-requests`: as host or as agent, newest first. */
  async cherryRequests(userId: string, query: PageQuery): Promise<PageDto<RechargeCherryRequestDto>> {
    const scope = `recharge-cherry:${userId}`;
    const after = this.after(query.cursor, scope);
    // D287: an employee allowed to buy cherries also sees the agent's requests (off shift: to read).
    const job = await this.prisma.rechargeEmployee.findFirst({
      where: { employeeUserId: userId, removedAt: null, canBuyCherries: true },
      select: { agentUserId: true },
    });
    const rows = await this.prisma.rechargeCherryRequest.findMany({
      where: {
        AND: [
          {
            OR: [
              { hostUserId: userId },
              { agentUserId: userId },
              ...(job ? [{ agentUserId: job.agentUserId }] : []),
            ],
          },
          after
            ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
            : {},
        ],
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
    });
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];
    return {
      data: await this.requestDtos(page, userId),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  /**
   * `POST /recharge-cherry-requests/{id}/{confirm|decline|cancel}`. The creator's side cancels, the other side
   * confirms or declines. D287: the agent's side is the agent or an employee allowed to buy cherries and on shift;
   * the first to answer wins (the row lock), the others get 409 `RECHARGE_CHERRY_REQUEST_CLOSED`.
   */
  async answerCherryRequest(
    userId: string,
    requestId: string,
    action: string,
  ): Promise<RechargeCherryRequestDto> {
    if (!UUID.test(requestId)) throw new AppException(ErrorCode.NOT_FOUND);
    const id = requestId.toLowerCase();
    const found = await this.prisma.rechargeCherryRequest.findUnique({ where: { id } });
    const viewer = found ? await this.cherrySideOf(userId, found) : null;
    if (!found || !viewer) throw new AppException(ErrorCode.NOT_FOUND);
    const initiatedBy: CherrySide = found.createdBy === found.hostUserId ? 'HOST' : 'AGENT';
    if (!cherryActionFits(action, viewer.side, initiatedBy)) {
      throw AppException.validation([{ field: 'action', issue: 'invalid_value' }]);
    }
    const now = this.clock.now();
    const block = agentSideBlock(userId, viewer.job, 'BUY_CHERRIES', now);
    if (block !== null) throw blockError(block);
    if (found.status === 'PENDING' && found.expiresAt.getTime() <= now.getTime()) {
      await this.prisma.rechargeCherryRequest.updateMany({
        where: { id, status: 'PENDING' },
        data: { status: 'EXPIRED', decidedAt: now },
      });
      throw new AppException(ErrorCode.RECHARGE_CHERRY_REQUEST_CLOSED);
    }
    const byEmployee = viewer.job !== null;
    const row = await this.prisma.$transaction(async (tx) => {
      const [locked] = await tx.$queryRaw<{ status: string; expires_at: Date }[]>`
        SELECT status::text AS status, expires_at FROM recharge_cherry_requests WHERE id = ${id}::uuid FOR UPDATE`;
      if (locked?.status !== 'PENDING' || locked.expires_at.getTime() <= now.getTime()) {
        throw new AppException(ErrorCode.RECHARGE_CHERRY_REQUEST_CLOSED);
      }
      if (byEmployee) {
        // Removed (or the permission switched off) since the first look: refused.
        const again = await this.cherrySideOf(userId, found, tx);
        if (!again?.job) throw new AppException(ErrorCode.NOT_FOUND);
        const now2 = agentSideBlock(userId, again.job, 'BUY_CHERRIES', now);
        if (now2 !== null) throw blockError(now2);
      }
      if (action === 'confirm') {
        const [agent] = await tx.$queryRaw<{ status: string; cap: bigint | null; user_status: string }[]>`
          SELECT a.status::text AS status, a.daily_cherry_cap AS cap, u.status::text AS user_status
            FROM recharge_agents a JOIN users u ON u.id = a.user_id
           WHERE a.user_id = ${found.agentUserId}::uuid FOR UPDATE OF a`;
        if (agent?.status !== 'ACTIVE' || agent.user_status !== 'ACTIVE') {
          throw new AppException(ErrorCode.RECHARGE_AGENT_NOT_ACTIVE);
        }
        const today = await this.todayCherries(tx, found.agentUserId);
        if (this.overCap({ dailyCherryCap: agent.cap }, today, found.cherries)) {
          throw new AppException(ErrorCode.RECHARGE_CHERRY_CAP_REACHED);
        }
        // D184: the locked task cherries are never sold (the same guarded debit as a withdrawal).
        const lock = await taskCherryLockIn(tx, found.hostUserId, this.config.economy);
        const balance = await holdCherriesIn(
          tx,
          found.hostUserId,
          found.cherries,
          id,
          now,
          lock.lockedCherries,
          'RECHARGE_SALE',
        );
        if (balance === null) throw new AppException(ErrorCode.INSUFFICIENT_CHERRIES);
        if (found.coins > 0n)
          await moveStockIn(tx, found.agentUserId, found.coins, 'CHERRY_PURCHASE', id, now);
      }
      const status = action === 'confirm' ? 'CONFIRMED' : action === 'decline' ? 'DECLINED' : 'CANCELLED';
      const actedBy = byEmployee ? userId : found.actedBy;
      const updated = await tx.rechargeCherryRequest.update({
        where: { id },
        data: { status, decidedAt: now, decidedBy: userId, actedBy },
      });
      await tx.auditLog.create({
        data: {
          actorUserId: userId,
          action:
            action === 'confirm'
              ? AuditAction.RECHARGE_CHERRY_CONFIRM
              : action === 'decline'
                ? AuditAction.RECHARGE_CHERRY_DECLINE
                : AuditAction.RECHARGE_CHERRY_CANCEL,
          targetType: 'recharge_cherry_request',
          targetId: id,
          metadata: {
            agent: found.agentUserId,
            host: found.hostUserId,
            cherries: Number(found.cherries),
            coins: Number(found.coins),
            side: viewer.side,
            byEmployee,
            ...(actedBy === null ? {} : { actedBy }),
          },
        },
      });
      return updated;
    });
    const [dto] = await this.requestDtos([row], userId);
    return dto!;
  }
}
