import { Inject, Injectable } from '@nestjs/common';
import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma, RechargePointsReason } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { PageQuery } from '../posts/posts.schemas.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { movePointsIn, pointsBalanceIn } from './recharge-points-ledger.js';

type Tx = Prisma.TransactionClient;

/** `RechargePointsEntry` (openapi v1.126-social, D370): one change of the balance; the reference is never returned. */
export interface RechargePointsEntryDto {
  id: string;
  reason: RechargePointsReason;
  delta: number;
  balanceAfter: number;
  createdAt: string;
}

/** `RechargePoints` (v1.126-social): the balance and a cursor page of the history, newest first. */
export interface RechargePointsDto {
  balance: number;
  data: RechargePointsEntryDto[];
  page: { nextCursor: string | null; hasMore: boolean };
}

/** `AdminRechargePointsAdjustResult` (v1.126-social). */
export interface RechargePointsAdjustResultDto {
  delta: number;
  before: number;
  after: number;
}

function entryDto(r: {
  id: string;
  reason: RechargePointsReason;
  delta: bigint;
  balanceAfter: bigint;
  createdAt: Date;
}): RechargePointsEntryDto {
  return {
    id: r.id,
    reason: r.reason,
    delta: Number(r.delta),
    balanceAfter: Number(r.balanceAfter),
    createdAt: r.createdAt.toISOString(),
  };
}

const ENTRY_SELECT = { id: true, reason: true, delta: true, balanceAfter: true, createdAt: true } as const;

/**
 * Recharge points «نقاط الشحن» (v1.126-social, D370, CONVENTIONS §10.162): the person's balance and history, and the
 * team's audited adjustment. Earning, reversing and redeeming happen in the recharge, refund and VIP transactions
 * (`recharge-points-ledger.ts`).
 */
@Injectable()
export class RechargePointsService {
  private readonly cursors: SocialCursorCodec;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(APP_CONFIG) config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  /** `GET /me/recharge-points`: the balance and the caller's own history (cursor pages, newest first). */
  async mine(userId: string, query: PageQuery): Promise<RechargePointsDto> {
    const scope = `recharge-points:${userId}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const [balance, rows] = await Promise.all([
      pointsBalanceIn(this.prisma, userId),
      this.prisma.rechargePointsEntry.findMany({
        where: {
          userId,
          ...(after
            ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
            : {}),
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: query.limit + 1,
        select: ENTRY_SELECT,
      }),
    ]);
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];
    return {
      balance: Number(balance),
      data: page.map(entryDto),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  /** The panel's ledger page (`listAdminUserLedger?kind=recharge_points`). */
  async adminPage(userId: string, page: number, pageSize: number) {
    const where = { userId };
    const [rows, total] = await Promise.all([
      this.prisma.rechargePointsEntry.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * pageSize,
        take: pageSize,
        select: ENTRY_SELECT,
      }),
      this.prisma.rechargePointsEntry.count({ where }),
    ]);
    return { data: rows.map(entryDto), total, page, pageSize };
  }

  /**
   * `POST /admin/users/{userId}/recharge-points/adjustments`: the team's correction (`ADMIN_ADJUST`, reference a new
   * id), audited `recharge_points.adjust` {before, after, delta, reason} in the same transaction. A debit never takes the
   * balance below 0 unless `allowNegative` (OWNER only; checked by the caller).
   */
  async adjust(
    userId: string,
    input: { delta: bigint; allowNegative: boolean; reason: string },
    by: AdminVia,
  ): Promise<RechargePointsAdjustResultDto> {
    return this.prisma.$transaction(async (tx: Tx) => {
      // Lock the person's balance row (created at 0 if missing) so `before` is what the change applies to.
      await tx.$executeRaw`
        INSERT INTO recharge_points_balances (user_id, points, updated_at) VALUES (${userId}::uuid, 0, now())
        ON CONFLICT (user_id) DO NOTHING`;
      const [row] = await tx.$queryRaw<{ points: bigint }[]>`
        SELECT points FROM recharge_points_balances WHERE user_id = ${userId}::uuid FOR UPDATE`;
      const before = BigInt(row!.points);
      if (input.delta < 0n && !input.allowNegative && before + input.delta < 0n) {
        throw new AppException(
          ErrorCode.ADMIN_ACTION_REFUSED,
          'The balance would go below 0 («Allow negative» is the OWNER’s).',
          [{ field: 'amount', issue: 'below_zero' }],
        );
      }
      const change = await movePointsIn(tx, userId, input.delta, 'ADMIN_ADJUST', uuidv7());
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.RECHARGE_POINTS_ADJUST,
          targetType: 'user',
          targetId: userId,
          metadata: {
            delta: Number(input.delta),
            before: Number(before),
            after: Number(change.points),
            entryId: change.entryId,
            allowNegative: input.allowNegative,
            reason: input.reason,
            via: by.via,
          },
        },
      });
      return { delta: Number(input.delta), before: Number(before), after: Number(change.points) };
    });
  }
}
