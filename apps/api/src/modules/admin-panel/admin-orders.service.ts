import { Inject, Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { RechargeAdminError } from '../recharge/recharge-core.js';
import {
  clearExchangeRateIn,
  lockOrderIn,
  messageIn,
  notifyOrderIn,
  partiesIn,
  resolveDisputeIn,
  setExchangeRateIn,
} from '../recharge/recharge-order-core.js';
import {
  ARAB_CURRENCIES,
  formatRate,
  parseRateMicro,
  type DisputeOutcome,
} from '../recharge/recharge-order-rules.js';
import { priceDto, RechargeOrdersService } from '../recharge/recharge-orders.service.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import { decodeCursor, pageOf } from './admin-panel.schemas.js';
import { refused, viaOf } from './admin-users.service.js';

async function shared<T>(step: () => Promise<T>): Promise<T> {
  try {
    return await step();
  } catch (err) {
    if (err instanceof RechargeAdminError) throw refused(err.message);
    throw err;
  }
}

/**
 * The panel's «نزاعات الشحن» and «أسعار الصرف» (v1.69-social, D204, CONVENTIONS §10.64.6). An admin opens an order only
 * once it was disputed (the chat is private to the buyer and the agent until then); each view of an order and of its
 * pictures is audited (`via: panel`). The admin's lines are labelled «الإدارة» (never the admin's name). A decision
 * moves the frozen coins through the rule the CLI uses (`resolveDisputeIn`) and needs the authenticator code again.
 */
@Injectable()
export class AdminOrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly auth: AdminAuthService,
    private readonly orders: RechargeOrdersService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private user(u: {
    id: string;
    email: string | null;
    profile: { username: string; displayName: string } | null;
  }) {
    return { id: u.id, username: u.profile?.username ?? '', displayName: u.profile?.displayName ?? '' };
  }

  /** Disputed orders (open ones oldest first: the queue) or the decided ones (newest first). */
  async disputes(query: { status: 'OPEN' | 'RESOLVED'; cursor?: string | undefined; limit: number }) {
    const dir = query.status === 'OPEN' ? 'asc' : 'desc';
    const c = decodeCursor(query.cursor);
    const op = dir === 'asc' ? 'gt' : 'lt';
    const rows = await this.prisma.rechargeOrder.findMany({
      where: {
        disputedAt: { not: null },
        status: query.status === 'OPEN' ? 'DISPUTED' : { in: ['COMPLETED_BY_ADMIN', 'REFUNDED_TO_AGENT'] },
        ...(c ? { OR: [{ disputedAt: { [op]: c.at } }, { disputedAt: c.at, id: { [op]: c.id } }] } : {}),
      },
      orderBy: [{ disputedAt: dir }, { id: dir }],
      take: query.limit + 1,
      include: {
        buyer: {
          select: { id: true, email: true, profile: { select: { username: true, displayName: true } } },
        },
        agent: {
          select: {
            code: true,
            user: {
              select: { id: true, email: true, profile: { select: { username: true, displayName: true } } },
            },
          },
        },
      },
    });
    return pageOf(
      rows.map((r) => ({ ...r, createdAt: r.disputedAt! })),
      query.limit,
      (o) => ({
        id: o.id,
        status: o.status,
        coins: Number(o.coins),
        country: o.country,
        price: priceDto(o),
        disputedAt: o.disputedAt!.toISOString(),
        disputedBy: o.disputedBy,
        closedAt: o.closedAt?.toISOString() ?? null,
        buyer: this.user(o.buyer),
        agent: { ...this.user(o.agent.user), code: o.agent.code },
      }),
    );
  }

  private async disputed(id: string) {
    const order = await this.prisma.rechargeOrder.findUnique({
      where: { id },
      include: {
        buyer: {
          select: { id: true, email: true, profile: { select: { username: true, displayName: true } } },
        },
        agent: {
          select: {
            code: true,
            stockCoins: true,
            user: {
              select: { id: true, email: true, profile: { select: { username: true, displayName: true } } },
            },
          },
        },
      },
    });
    // Before a dispute the order's chat is the buyer's and the agent's only (§10.64.6).
    if (!order || order.disputedAt === null) throw new AppException(ErrorCode.NOT_FOUND);
    return order;
  }

  /** The disputed order with its whole chat (audited `recharge.order.admin_view`). */
  async order(id: string, ctx: AdminContext) {
    const o = await this.disputed(id);
    await this.audit.record({
      action: AuditAction.RECHARGE_ORDER_ADMIN_VIEW,
      actorUserId: ctx.userId,
      targetType: 'recharge_order',
      targetId: o.id,
      metadata: { via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    const messages = await this.prisma.rechargeOrderMessage.findMany({
      where: { orderId: o.id },
      orderBy: { seq: 'asc' },
      take: 1000,
    });
    return {
      id: o.id,
      status: o.status,
      coins: Number(o.coins),
      heldCoins: Number(o.heldCoins),
      country: o.country,
      price: priceDto(o),
      paymentType: o.paymentType,
      createdAt: o.createdAt.toISOString(),
      detailsAt: o.detailsAt?.toISOString() ?? null,
      noticeAcknowledgedAt: o.noticeAckAt?.toISOString() ?? null,
      paidAt: o.paidAt?.toISOString() ?? null,
      disputedAt: o.disputedAt!.toISOString(),
      disputedBy: o.disputedBy,
      closedAt: o.closedAt?.toISOString() ?? null,
      closeReason: o.closeReason,
      buyer: { ...this.user(o.buyer), email: o.buyer.email },
      agent: {
        ...this.user(o.agent.user),
        email: o.agent.user.email,
        code: o.agent.code,
        stockCoins: Number(o.agent.stockCoins),
      },
      messages: (await this.orders.messageDtos(messages)).map((m, i) => ({
        ...m,
        // The panel sees which admin wrote a «الإدارة» line (users never do).
        adminUserId: messages[i]!.role === 'ADMIN' ? messages[i]!.authorUserId : null,
      })),
    };
  }

  /** One picture of a disputed order (audited per view, streamed `private, no-store`). */
  async image(id: string, messageId: string, ctx: AdminContext): Promise<Buffer> {
    const o = await this.disputed(id);
    const bytes = await this.orders.imageBytes(o.id, messageId);
    await this.audit.record({
      action: AuditAction.RECHARGE_ORDER_IMAGE_VIEW,
      actorUserId: ctx.userId,
      targetType: 'recharge_order',
      targetId: o.id,
      metadata: { message: messageId, via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return bytes;
  }

  /** «الإدارة» posts in the order's chat (from the dispute on; also after the decision, as a record). */
  async post(id: string, text: string, ctx: AdminContext) {
    const o = await this.disputed(id);
    const now = new Date();
    const messageId = await this.prisma.$transaction(async (tx) => {
      const locked = await lockOrderIn(tx, o.id);
      if (!locked) throw new AppException(ErrorCode.NOT_FOUND);
      const mid = await messageIn(tx, {
        orderId: o.id,
        authorUserId: ctx.userId,
        role: 'ADMIN',
        kind: 'TEXT',
        text,
        now,
      });
      await tx.rechargeOrder.update({ where: { id: o.id }, data: { updatedAt: now } });
      await tx.auditLog.create({
        data: {
          actorUserId: ctx.userId,
          action: AuditAction.RECHARGE_ORDER_ADMIN_MESSAGE,
          targetType: 'recharge_order',
          targetId: o.id,
          metadata: { message: mid, via: 'panel' },
          ip: ctx.ip?.slice(0, 64) ?? null,
          requestId: ctx.requestId,
        },
      });
      await notifyOrderIn(tx, o.id, await partiesIn(tx, locked), 'ADMIN_MESSAGE', now);
      return mid;
    });
    const row = await this.prisma.rechargeOrderMessage.findUniqueOrThrow({ where: { id: messageId } });
    return { ...(await this.orders.messageDtos([row]))[0]!, adminUserId: ctx.userId };
  }

  /** The decision (authenticator code again): credit the buyer or refund the agent; idempotent. */
  async resolve(
    id: string,
    body: { outcome: DisputeOutcome; reason: string; totpCode: string },
    ctx: AdminContext,
  ) {
    await this.disputed(id);
    await this.auth.reauthenticate(ctx, body.totpCode);
    const r = await shared(() =>
      this.prisma.$transaction((tx) =>
        resolveDisputeIn(
          tx,
          id,
          body.outcome,
          body.reason,
          new Date(),
          this.config.recharge.badges,
          viaOf(ctx),
        ),
      ),
    );
    return { status: r.status, changed: r.changed };
  }

  // ---- exchange rates ---------------------------------------------------------------------------------------------

  async rates() {
    const rows = await this.prisma.rechargeExchangeRate.findMany({ orderBy: { country: 'asc' } });
    const set = new Map(rows.map((r) => [r.country, r]));
    const countries = [...new Set([...Object.keys(ARAB_CURRENCIES), ...rows.map((r) => r.country)])].sort();
    return {
      retailUsdPerMillion: this.config.economy.coinRetailUsdPerMillion,
      data: countries.map((country) => {
        const r = set.get(country);
        const fallback = ARAB_CURRENCIES[country];
        return {
          country,
          currency: r?.currency ?? fallback?.currency ?? null,
          digits: r?.digits ?? fallback?.digits ?? 2,
          unitsPerUsd: r ? formatRate(r.rateMicro) : null,
          updatedAt: r?.updatedAt.toISOString() ?? null,
        };
      }),
    };
  }

  async setRate(
    country: string,
    body: { currency: string; unitsPerUsd: string; digits: number; reason: string },
    ctx: AdminContext,
  ) {
    const rateMicro = parseRateMicro(body.unitsPerUsd);
    if (rateMicro === null) throw AppException.validation([{ field: 'unitsPerUsd', issue: 'invalid' }]);
    await shared(() =>
      this.prisma.$transaction((tx) =>
        setExchangeRateIn(
          tx,
          country,
          { currency: body.currency, rateMicro, digits: body.digits },
          body.reason,
          new Date(),
          viaOf(ctx),
        ),
      ),
    );
    return { country, currency: body.currency, digits: body.digits, unitsPerUsd: formatRate(rateMicro) };
  }

  async clearRate(country: string, reason: string, ctx: AdminContext) {
    await shared(() =>
      this.prisma.$transaction((tx) => clearExchangeRateIn(tx, country, reason, viaOf(ctx))),
    );
    return { country, unitsPerUsd: null };
  }
}
