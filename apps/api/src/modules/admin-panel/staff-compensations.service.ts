import { randomUUID } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { BagAdminError, grantBagItemByAdminIn } from '../bag/bag-admin-rules.js';
import { dayStart } from '../recharge/recharge-rules.js';
import { parseStaffId } from '../users/staff-ids.js';
import { wearVipItemsIn } from '../vip/vip-bag.js';
import { syncVipIdentityIn } from '../vip/vip-identity-ops.js';
import { vipActive } from '../vip/vip-rules.js';
import { creditIn } from '../wallet/wallet-ledger.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import { PANEL_ROLES } from './admin-permissions.js';
import { refused } from './admin-users.service.js';

type Tx = Prisma.TransactionClient;

export const COMPENSATION_KINDS = ['COINS', 'VIP_DAYS', 'ITEM'] as const;
export type CompensationKind = (typeof COMPENSATION_KINDS)[number];
export const COMPENSATION_STATUSES = ['GRANTED', 'PENDING', 'APPROVED', 'REJECTED'] as const;
export type CompensationStatus = (typeof COMPENSATION_STATUSES)[number];
/** The store prices a compensation item may use (D270: 7, 14 or 30 days). */
export const COMPENSATION_ITEM_DAYS = [7, 14, 30] as const;
/** The defaults of `staff_compensation_settings` (the migration's; also when the row is missing). */
export const COMPENSATION_DEFAULTS = { dailyLimitCoins: 50_000n, perGrantMaxCoins: 10_000n } as const;

/**
 * Whether a grant of `value` waits for the OWNER (§10.176.4): above the per-grant maximum, or past the daily limit with
 * what the staff member already granted today. The OWNER is never limited.
 */
export function overLimitOf(
  value: bigint,
  usedToday: bigint,
  limits: { dailyLimitCoins: bigint; perGrantMaxCoins: bigint },
  isOwner: boolean,
): 'per_grant' | 'daily' | null {
  if (isOwner) return null;
  if (value > limits.perGrantMaxCoins) return 'per_grant';
  if (usedToday + value > limits.dailyLimitCoins) return 'daily';
  return null;
}

/** The value of VIP days: ⌈price × days ÷ duration⌉ (at least 1). */
export function vipDaysValue(priceCoins: bigint, durationDays: number, days: number): bigint {
  const v = (priceCoins * BigInt(days) + BigInt(durationDays) - 1n) / BigInt(durationDays);
  return v < 1n ? 1n : v;
}

export interface CompensationInput {
  readonly user: string;
  readonly kind: CompensationKind;
  readonly coins?: number | undefined;
  readonly days?: number | undefined;
  readonly tierCode?: string | undefined;
  readonly itemCode?: string | undefined;
  readonly reason: string;
  readonly totpCode: string;
}

const PERSON = { select: { id: true, profile: { select: { username: true, displayName: true, avatarUrl: true } } } };
type Person = { id: string; profile: { username: string; displayName: string; avatarUrl: string | null } | null };
const personDto = (u: Person) => ({
  id: u.id,
  username: u.profile?.username ?? '',
  displayName: u.profile?.displayName ?? '',
  avatarUrl: u.profile?.avatarUrl ?? null,
});

const ROW_SELECT = {
  id: true,
  kind: true,
  coins: true,
  days: true,
  itemCode: true,
  valueCoins: true,
  reason: true,
  status: true,
  overLimit: true,
  decidedAt: true,
  decisionNote: true,
  createdAt: true,
  vipTier: { select: { code: true } },
  staff: PERSON,
  user: PERSON,
  decidedBy: PERSON,
} as const;
type Row = Prisma.StaffCompensationGetPayload<{ select: typeof ROW_SELECT }>;

function dto(r: Row) {
  return {
    id: r.id,
    staff: r.staff ? personDto(r.staff) : null,
    user: personDto(r.user),
    kind: r.kind as CompensationKind,
    coins: r.coins === null ? null : Number(r.coins),
    days: r.days,
    tierCode: r.vipTier?.code ?? null,
    itemCode: r.itemCode,
    valueCoins: Number(r.valueCoins),
    reason: r.reason,
    status: r.status as CompensationStatus,
    overLimit: (r.overLimit ?? null) as 'per_grant' | 'daily' | null,
    decidedBy: r.decidedBy ? personDto(r.decidedBy) : null,
    decidedAt: r.decidedAt?.toISOString() ?? null,
    decisionNote: r.decisionNote,
    createdAt: r.createdAt.toISOString(),
  };
}
export type CompensationDto = ReturnType<typeof dto>;

/** What a compensation gives (validated, priced). */
interface Plan {
  readonly kind: CompensationKind;
  readonly coins: bigint | null;
  readonly days: number | null;
  readonly vipTierId: string | null;
  readonly itemCode: string | null;
  readonly value: bigint;
}

function invalid(field: string): AppException {
  return new AppException(ErrorCode.VALIDATION_FAILED, undefined, [{ field, issue: 'invalid_value' }]);
}

/**
 * v1.139-social (D387, CONVENTIONS §10.176.4): «التعويضات» — a VIP_CARE staff member's grant of coins (wallet ledger
 * `STAFF_COMPENSATION`), VIP days or a store item (the bag-grant path) to a person, always with a reason and the
 * authenticator code again (money). Within the OWNER's limits (a daily value per staff member and a per-grant maximum,
 * in coins) it is GRANTED at once; above them it is a PENDING request until the OWNER approves (the grant runs then)
 * or rejects. Every step is audited.
 */
@Injectable()
export class StaffCompensationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    private readonly adminAuth: AdminAuthService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private get zone(): string {
    return this.config.adminPanel.dashboardTimeZone;
  }

  private async limits(db: Tx | PrismaService = this.prisma) {
    const row = await db.staffCompensationSettings.findUnique({ where: { id: 1 } });
    return {
      dailyLimitCoins: row?.dailyLimitCoins ?? COMPENSATION_DEFAULTS.dailyLimitCoins,
      perGrantMaxCoins: row?.perGrantMaxCoins ?? COMPENSATION_DEFAULTS.perGrantMaxCoins,
      updatedAt: row?.updatedAt ?? null,
    };
  }

  private async usedToday(db: Tx | PrismaService, staffId: string, now: Date): Promise<bigint> {
    const sum = await db.staffCompensation.aggregate({
      where: { staffId, status: 'GRANTED', createdAt: { gte: dayStart(now, this.zone) } },
      _sum: { valueCoins: true },
    });
    return sum._sum.valueCoins ?? 0n;
  }

  /** `getAdminCompensationSettings`. */
  async settings(ctx: AdminContext) {
    const now = this.clock.now();
    const [l, used] = await Promise.all([this.limits(), this.usedToday(this.prisma, ctx.userId, now)]);
    return {
      dailyLimitCoins: Number(l.dailyLimitCoins),
      perGrantMaxCoins: Number(l.perGrantMaxCoins),
      usedTodayCoins: Number(used),
      timeZone: this.zone,
      updatedAt: l.updatedAt?.toISOString() ?? null,
    };
  }

  /** `updateAdminCompensationSettings` (OWNER; reason and the code again). */
  async updateSettings(
    body: { dailyLimitCoins: number; perGrantMaxCoins: number; reason: string; totpCode: string },
    ctx: AdminContext,
  ) {
    await this.adminAuth.reauthenticate(ctx, body.totpCode);
    await this.prisma.$transaction(async (tx) => {
      const before = await this.limits(tx);
      const now = this.clock.now();
      await tx.staffCompensationSettings.upsert({
        where: { id: 1 },
        create: {
          id: 1,
          dailyLimitCoins: BigInt(body.dailyLimitCoins),
          perGrantMaxCoins: BigInt(body.perGrantMaxCoins),
          updatedAt: now,
          updatedById: ctx.userId,
        },
        update: {
          dailyLimitCoins: BigInt(body.dailyLimitCoins),
          perGrantMaxCoins: BigInt(body.perGrantMaxCoins),
          updatedAt: now,
          updatedById: ctx.userId,
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.STAFF_COMPENSATION_SETTINGS,
        actorUserId: ctx.userId,
        targetType: 'staff_compensation_settings',
        targetId: '1',
        metadata: {
          before: {
            dailyLimitCoins: Number(before.dailyLimitCoins),
            perGrantMaxCoins: Number(before.perGrantMaxCoins),
          },
          after: { dailyLimitCoins: body.dailyLimitCoins, perGrantMaxCoins: body.perGrantMaxCoins },
          reason: body.reason,
          via: ctx.via ?? 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    return this.settings(ctx);
  }

  /** `listAdminCompensations`: VIP_CARE sees their own, the OWNER (`compensation.approve`) everyone's. */
  async list(q: { status?: CompensationStatus | undefined; page: number; pageSize: number }, ctx: AdminContext) {
    const where: Prisma.StaffCompensationWhereInput = {
      ...(q.status ? { status: q.status } : {}),
      ...(ctx.capabilities.includes('compensation.approve') ? {} : { staffId: ctx.userId }),
    };
    const [rows, total] = await Promise.all([
      this.prisma.staffCompensation.findMany({
        where,
        select: ROW_SELECT,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (q.page - 1) * q.pageSize,
        take: q.pageSize,
      }),
      this.prisma.staffCompensation.count({ where }),
    ]);
    return { data: rows.map(dto), total, page: q.page, pageSize: q.pageSize };
  }

  /** The account by id, email, staff ID or (@)username. */
  private async recipientId(tx: Tx, who: string): Promise<string> {
    const value = who.trim();
    let id: string | null = null;
    if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) id = value.toLowerCase();
    else if (/^[^@\s]+@[^@\s]+$/.test(value)) {
      id = (await tx.user.findUnique({ where: { email: value.toLowerCase() }, select: { id: true } }))?.id ?? null;
    } else if (value.length > 0) {
      const staff = parseStaffId(value);
      if (staff !== null) {
        id = (await tx.staffId.findUnique({ where: { number: staff }, select: { userId: true } }))?.userId ?? null;
      }
      if (id === null) {
        const username = value.replace(/^@/, '').toLowerCase();
        id = (await tx.userProfile.findUnique({ where: { username }, select: { userId: true } }))?.userId ?? null;
      }
    }
    if (id === null) throw new AppException(ErrorCode.NOT_FOUND);
    return id;
  }

  /** The recipient rules: ACTIVE, not a panel staff account, never oneself (409 `compensation_recipient`). */
  private async checkRecipient(tx: Tx, userId: string, ctx: AdminContext): Promise<void> {
    const user = await tx.user.findUnique({
      where: { id: userId },
      select: { status: true, adminPermissions: { select: { permission: true } } },
    });
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    const staff = user.adminPermissions.some((p) => (PANEL_ROLES as readonly string[]).includes(p.permission));
    if (userId === ctx.userId || user.status !== 'ACTIVE' || staff) {
      throw refused(
        'A compensation goes to an active person who is not on the team (and never to oneself).',
        'compensation_recipient',
        'rule',
      );
    }
  }

  /** Validates the kind's fields and prices the grant. */
  private async plan(tx: Tx, input: CompensationInput): Promise<Plan> {
    if (input.kind === 'COINS') {
      if (input.coins === undefined || input.days !== undefined || input.tierCode || input.itemCode) {
        throw invalid(input.coins === undefined ? 'coins' : 'kind');
      }
      const coins = BigInt(input.coins);
      return { kind: 'COINS', coins, days: null, vipTierId: null, itemCode: null, value: coins };
    }
    if (input.kind === 'VIP_DAYS') {
      if (input.days === undefined || !input.tierCode || input.coins !== undefined || input.itemCode) {
        throw invalid(input.days === undefined ? 'days' : !input.tierCode ? 'tierCode' : 'kind');
      }
      const tier = await tx.vipTier.findUnique({
        where: { code: input.tierCode },
        select: { id: true, priceCoins: true, durationDays: true },
      });
      if (!tier) throw invalid('tierCode');
      return {
        kind: 'VIP_DAYS',
        coins: null,
        days: input.days,
        vipTierId: tier.id,
        itemCode: null,
        value: vipDaysValue(tier.priceCoins, tier.durationDays, input.days),
      };
    }
    if (input.days === undefined || !input.itemCode || input.coins !== undefined || input.tierCode) {
      throw invalid(input.days === undefined ? 'days' : !input.itemCode ? 'itemCode' : 'kind');
    }
    if (!(COMPENSATION_ITEM_DAYS as readonly number[]).includes(input.days)) throw invalid('days');
    const item = await tx.storeItem.findUnique({
      where: { bagCode: input.itemCode },
      select: { prices: { where: { currency: 'COINS', days: input.days }, select: { amount: true } } },
    });
    const price = item?.prices[0]?.amount ?? null;
    if (price === null || price <= 0n) {
      throw refused('This store item has no coin price for those days.', 'compensation_item', 'rule');
    }
    return { kind: 'ITEM', coins: null, days: input.days, vipTierId: null, itemCode: input.itemCode, value: price };
  }

  /** Gives what the compensation says, inside the caller's transaction (GRANTED now, or APPROVED by the OWNER). */
  private async give(tx: Tx, id: string, userId: string, plan: Plan, reason: string, by: AdminVia): Promise<void> {
    const now = this.clock.now();
    if (plan.kind === 'COINS') {
      await creditIn(tx, userId, plan.coins!, 'STAFF_COMPENSATION', id);
      return;
    }
    if (plan.kind === 'ITEM') {
      try {
        await grantBagItemByAdminIn(tx, userId, plan.itemCode!, plan.days, by, `compensation ${id}: ${reason}`, now);
      } catch (err) {
        if (err instanceof BagAdminError) throw refused(err.message, 'compensation_item', 'rule');
        throw err;
      }
      return;
    }
    // VIP_DAYS: the person's VIP purchases are serialized on the same lock (vip.service.ts).
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:vip-user'), hashtext(${userId}))`;
    const tier = await tx.vipTier.findUniqueOrThrow({ where: { id: plan.vipTierId! } });
    const held = await tx.vipMembership.findUnique({ where: { userId } });
    const add = plan.days! * 86_400_000;
    const active = held !== null && vipActive(held.expiresAt, now);
    if (active && held.tierId !== tier.id) {
      throw refused('The person holds another VIP tier now: give days of that tier.', 'compensation_vip_tier', 'rule');
    }
    const membership = await tx.vipMembership.upsert({
      where: { userId },
      create: { userId, tierId: tier.id, startedAt: now, expiresAt: new Date(now.getTime() + add) },
      update: active
        ? { expiresAt: new Date(held.expiresAt.getTime() + add) }
        : { tierId: tier.id, startedAt: now, expiresAt: new Date(now.getTime() + add), offPerks: [] },
    });
    await wearVipItemsIn(tx, userId, tier.sortOrder, membership.offPerks);
    await syncVipIdentityIn(tx, userId, now);
  }

  private viaOf(ctx: AdminContext): AdminVia {
    return { via: ctx.via ?? 'panel', actorUserId: ctx.userId, ip: ctx.ip, requestId: ctx.requestId };
  }

  private one(db: Tx | PrismaService, id: string) {
    return db.staffCompensation.findUniqueOrThrow({ where: { id }, select: ROW_SELECT }).then(dto);
  }

  /** `createAdminCompensation`. */
  async create(input: CompensationInput, ctx: AdminContext): Promise<CompensationDto> {
    await this.adminAuth.reauthenticate(ctx, input.totpCode);
    const by = this.viaOf(ctx);
    return this.prisma.$transaction(async (tx) => {
      const userId = await this.recipientId(tx, input.user);
      await this.checkRecipient(tx, userId, ctx);
      const plan = await this.plan(tx, input);
      // One staff member's grants at a time: the day's sum below cannot be passed by two requests together.
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:staff-compensation'), hashtext(${ctx.userId}))`;
      const now = this.clock.now();
      const limits = await this.limits(tx);
      const used = await this.usedToday(tx, ctx.userId, now);
      const over = overLimitOf(plan.value, used, limits, ctx.roles.includes('OWNER'));
      const id = randomUUID();
      await tx.staffCompensation.create({
        data: {
          id,
          staffId: ctx.userId,
          userId,
          kind: plan.kind,
          coins: plan.coins,
          days: plan.days,
          vipTierId: plan.vipTierId,
          itemCode: plan.itemCode,
          valueCoins: plan.value,
          reason: input.reason,
          status: over ? 'PENDING' : 'GRANTED',
          overLimit: over,
          createdAt: now,
        },
      });
      if (!over) await this.give(tx, id, userId, plan, input.reason, by);
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: over ? AuditAction.STAFF_COMPENSATION_REQUEST : AuditAction.STAFF_COMPENSATION_GRANT,
          targetType: 'user',
          targetId: userId,
          metadata: {
            compensationId: id,
            kind: plan.kind,
            coins: plan.coins === null ? null : Number(plan.coins),
            days: plan.days,
            tierId: plan.vipTierId,
            itemCode: plan.itemCode,
            valueCoins: Number(plan.value),
            usedTodayBefore: Number(used),
            limits: {
              dailyLimitCoins: Number(limits.dailyLimitCoins),
              perGrantMaxCoins: Number(limits.perGrantMaxCoins),
            },
            ...(over ? { overLimit: over } : {}),
            reason: input.reason,
            via: by.via,
          },
        },
      });
      return this.one(tx, id);
    });
  }

  /** The PENDING row locked, or 409 `compensation_decided`. */
  private async pendingIn(tx: Tx, id: string) {
    const rows = await tx.$queryRaw<{ status: string }[]>`
      SELECT status FROM staff_compensations WHERE id = ${id}::uuid FOR UPDATE`;
    if (rows.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
    if (rows[0]!.status !== 'PENDING') {
      throw refused('This compensation was already decided.', 'compensation_decided', 'rule');
    }
    return tx.staffCompensation.findUniqueOrThrow({ where: { id } });
  }

  /** `approveAdminCompensation` (OWNER; the code again): the grant runs now. */
  async approve(id: string, body: { note?: string | undefined; totpCode: string }, ctx: AdminContext) {
    await this.adminAuth.reauthenticate(ctx, body.totpCode);
    const by = this.viaOf(ctx);
    return this.prisma.$transaction(async (tx) => {
      const row = await this.pendingIn(tx, id);
      const user = await tx.user.findUnique({ where: { id: row.userId }, select: { status: true } });
      if (user?.status !== 'ACTIVE') {
        throw refused('The person is no longer active.', 'compensation_recipient', 'rule');
      }
      const plan: Plan = {
        kind: row.kind as CompensationKind,
        coins: row.coins,
        days: row.days,
        vipTierId: row.vipTierId,
        itemCode: row.itemCode,
        value: row.valueCoins,
      };
      await this.give(tx, id, row.userId, plan, row.reason, by);
      const now = this.clock.now();
      await tx.staffCompensation.update({
        where: { id },
        data: { status: 'APPROVED', decidedById: ctx.userId, decidedAt: now, decisionNote: body.note ?? null },
      });
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.STAFF_COMPENSATION_APPROVE,
          targetType: 'user',
          targetId: row.userId,
          metadata: {
            compensationId: id,
            kind: row.kind,
            valueCoins: Number(row.valueCoins),
            staffId: row.staffId,
            overLimit: row.overLimit,
            note: body.note ?? null,
            via: by.via,
          },
        },
      });
      return this.one(tx, id);
    });
  }

  /** `rejectAdminCompensation` (OWNER; reason): nothing moves. */
  async reject(id: string, reason: string, ctx: AdminContext) {
    const by = this.viaOf(ctx);
    return this.prisma.$transaction(async (tx) => {
      const row = await this.pendingIn(tx, id);
      await tx.staffCompensation.update({
        where: { id },
        data: { status: 'REJECTED', decidedById: ctx.userId, decidedAt: this.clock.now(), decisionNote: reason },
      });
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.STAFF_COMPENSATION_REJECT,
          targetType: 'user',
          targetId: row.userId,
          metadata: {
            compensationId: id,
            kind: row.kind,
            valueCoins: Number(row.valueCoins),
            staffId: row.staffId,
            reason,
            via: by.via,
          },
        },
      });
      return this.one(tx, id);
    });
  }

  /** The PENDING count (the VIP_CARE home): the caller's own, or everyone's for the OWNER. */
  pendingCount(ctx: AdminContext): Promise<number> {
    return this.prisma.staffCompensation.count({
      where: {
        status: 'PENDING',
        ...(ctx.capabilities.includes('compensation.approve') ? {} : { staffId: ctx.userId }),
      },
    });
  }
}
