import { Inject, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type {
  CherryLedgerReason,
  CherryWithdrawal,
  CherryWithdrawalStatus,
} from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import type { PageQuery } from '../posts/posts.schemas.js';
import { SocialCursorCodec, type SocialPosition } from '../posts/social-cursor.js';
import { holdCherriesIn, taskCherryLockIn } from './cherry-ledger.js';
import { cherriesValueMinor, withdrawableCherries, withdrawalCherries } from './economy-math.js';

/** `CherryPayoutRules` (openapi v1.52-social, D179). */
export interface CherryPayoutRulesDto {
  currency: string;
  rateCherries: number;
  rateMinor: number;
  minAmountMinor: number;
  payoutDays: number;
}

/** `CherryWithdrawal`. */
export interface CherryWithdrawalDto {
  id: string;
  status: CherryWithdrawalStatus;
  cherries: number;
  amountMinor: number;
  currency: string;
  payoutDetails: string;
  createdAt: string;
  decidedAt: string | null;
  decisionNote: string | null;
}

/** `CherryWallet`. */
export interface CherryWalletDto {
  cherries: number;
  /** What the available cherries are worth at the payout rate (minor units, rounded down). */
  valueMinor: number;
  heldCherries: number;
  earnedTotal: number;
  earnedLast7Days: number;
  earnedLast30Days: number;
  commissionTotal: number;
  /** v1.53-social (D184): Task Center rewards (`TASK_REWARD`), all time. */
  taskRewardTotal: number;
  /** v1.53-social (D184): task cherries not withdrawable yet (0 once unlocked). */
  lockedTaskCherries: number;
  /** v1.53-social (D184): what a withdrawal may take now — the balance less the locked task cherries. */
  withdrawableCherries: number;
  /** v1.53-social (D184): the unlock rule for task cherries (owner: $50 of lifetime gift cherries). */
  taskUnlock: { unlocked: boolean; giftValueMinor: number; thresholdMinor: number };
  payout: CherryPayoutRulesDto;
  pendingWithdrawal: CherryWithdrawalDto | null;
}

/** `CherryLedgerEntry`. */
export interface CherryLedgerEntryDto {
  id: string;
  reason: CherryLedgerReason;
  delta: number;
  balanceAfter: number;
  createdAt: string;
  gift: {
    giftCode: string;
    giftName: string;
    quantity: number;
    giftCoins: number;
    shareBps: number;
    context: 'LIVE' | 'DM';
    sender: UserSummaryDto | null;
  } | null;
}

export const withdrawalBodySchema = z.strictObject({
  amountMinor: z.number().int().min(1).max(100_000_000),
  payoutDetails: z.string().trim().min(3).max(500),
});

const GIFT_REASONS = new Set<CherryLedgerReason>(['GIFT_RECEIVED', 'GIFT_REVERSAL']);
const DAY_MS = 86_400_000;

function withdrawalDto(w: CherryWithdrawal): CherryWithdrawalDto {
  return {
    id: w.id,
    status: w.status,
    cherries: Number(w.cherries),
    amountMinor: Number(w.amountMinor),
    currency: w.currency,
    payoutDetails: w.payoutDetails,
    createdAt: w.createdAt.toISOString(),
    decidedAt: w.decidedAt?.toISOString() ?? null,
    decisionNote: w.decisionNote,
  };
}

/**
 * The caller's cherries (v1.52-social, D179, CONVENTIONS §10.46): the balance and history from the cherry
 * ledger (credited per gift and per commission in the send's transaction), and withdrawal requests — the
 * cherries are held at request; an admin pays by hand (no payment provider yet) or rejects (they come
 * back) with `economy-admin`.
 */
@Injectable()
export class CherriesService {
  private readonly cursors: SocialCursorCodec;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  private get payout(): CherryPayoutRulesDto {
    const e = this.config.economy;
    return {
      currency: e.currency,
      rateCherries: e.rateCherries,
      rateMinor: e.rateMinor,
      minAmountMinor: e.minWithdrawalMinor,
      payoutDays: e.payoutDays,
    };
  }

  private after(cursor: string | undefined, scope: string): SocialPosition | null {
    if (cursor === undefined) return null;
    const after = this.cursors.decode(cursor, scope);
    if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    return after;
  }

  /** `GET /wallet/me/cherries`. */
  async wallet(me: string): Promise<CherryWalletDto> {
    const now = this.clock.now().getTime();
    const d7 = new Date(now - 7 * DAY_MS);
    const d30 = new Date(now - 30 * DAY_MS);
    const [wallet, sums, pending, lock] = await Promise.all([
      this.prisma.cherryWallet.findUnique({ where: { userId: me }, select: { cherries: true } }),
      this.prisma.$queryRaw<{ total: bigint; d7: bigint; d30: bigint; commission: bigint; task: bigint }[]>`
        SELECT COALESCE(sum(delta) FILTER (WHERE reason IN ('GIFT_RECEIVED', 'GIFT_REVERSAL')), 0)::bigint AS total,
               COALESCE(sum(delta) FILTER (WHERE reason IN ('GIFT_RECEIVED', 'GIFT_REVERSAL')
                                             AND created_at >= ${d7}), 0)::bigint AS d7,
               COALESCE(sum(delta) FILTER (WHERE reason IN ('GIFT_RECEIVED', 'GIFT_REVERSAL')
                                             AND created_at >= ${d30}), 0)::bigint AS d30,
               COALESCE(sum(delta) FILTER (WHERE reason IN ('AGENCY_COMMISSION', 'PARENT_COMMISSION',
                 'AGENCY_COMMISSION_REVERSAL', 'PARENT_COMMISSION_REVERSAL')), 0)::bigint AS commission,
               COALESCE(sum(delta) FILTER (WHERE reason = 'TASK_REWARD'), 0)::bigint AS task
          FROM cherry_ledger WHERE user_id = ${me}::uuid`,
      this.prisma.cherryWithdrawal.findFirst({ where: { userId: me, status: 'PENDING' } }),
      taskCherryLockIn(this.prisma, me, this.config.economy),
    ]);
    const cherries = wallet?.cherries ?? 0n;
    const s = sums[0];
    return {
      cherries: Number(cherries),
      valueMinor: Number(
        cherriesValueMinor(cherries, this.config.economy.rateCherries, this.config.economy.rateMinor),
      ),
      heldCherries: Number(pending?.cherries ?? 0n),
      earnedTotal: Number(s?.total ?? 0n),
      earnedLast7Days: Number(s?.d7 ?? 0n),
      earnedLast30Days: Number(s?.d30 ?? 0n),
      commissionTotal: Number(s?.commission ?? 0n),
      taskRewardTotal: Number(s?.task ?? 0n),
      lockedTaskCherries: Number(lock.lockedCherries),
      withdrawableCherries: Number(withdrawableCherries(cherries, lock.lockedCherries)),
      taskUnlock: {
        unlocked: lock.unlocked,
        giftValueMinor: Number(lock.giftValueMinor),
        thresholdMinor: Number(lock.thresholdMinor),
      },
      payout: this.payout,
      pendingWithdrawal: pending ? withdrawalDto(pending) : null,
    };
  }

  /** `GET /wallet/me/cherries/ledger`: newest first; a gift row names the gift and (if visible) the sender. */
  async ledger(me: string, query: PageQuery, lang: ContentLanguage): Promise<PageDto<CherryLedgerEntryDto>> {
    const scope = `cherry-ledger:${me}`;
    const after = this.after(query.cursor, scope);
    const rows = await this.prisma.cherryLedgerEntry.findMany({
      where: {
        userId: me,
        ...(after
          ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
      select: { id: true, reason: true, delta: true, balanceAfter: true, createdAt: true, referenceId: true },
    });
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const giftIds = [...new Set(page.filter((r) => GIFT_REASONS.has(r.reason)).map((r) => r.referenceId))];
    const gifts =
      giftIds.length === 0
        ? []
        : await this.prisma.$queryRaw<
            {
              id: string;
              dm: boolean;
              gift_code: string;
              name_ar: string;
              name_en: string;
              quantity: number;
              sender_id: string;
              coins: bigint;
              share_bps: number;
            }[]
          >`
            SELECT g.id::text AS id, (g.dm_conversation_id IS NOT NULL) AS dm, g.gift_code, gf.name_ar, gf.name_en,
                   g.quantity, g.sender_id::text AS sender_id, gr.coins, g.host_share_bps AS share_bps
              FROM live_gifts g
              JOIN gifts gf ON gf.code = g.gift_code
              JOIN live_gift_recipients gr ON gr.gift_id = g.id AND gr.user_id = ${me}::uuid
             WHERE g.id = ANY(${giftIds}::uuid[])`;
    const byId = new Map(gifts.map((g) => [g.id, g]));
    const senders = await this.visibleSenders(me, [...new Set(gifts.map((g) => g.sender_id))]);
    const last = page[page.length - 1];
    return {
      data: page.map((r) => {
        const g = GIFT_REASONS.has(r.reason) ? byId.get(r.referenceId) : undefined;
        return {
          id: r.id,
          reason: r.reason,
          delta: Number(r.delta),
          balanceAfter: Number(r.balanceAfter),
          createdAt: r.createdAt.toISOString(),
          gift: g
            ? {
                giftCode: g.gift_code,
                giftName: lang === 'ar' ? g.name_ar : g.name_en,
                quantity: g.quantity,
                giftCoins: Number(g.coins),
                shareBps: g.share_bps,
                context: g.dm ? 'DM' : 'LIVE',
                sender: senders.get(g.sender_id) ?? null,
              }
            : null,
        };
      }),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  /**
   * `POST /wallet/me/cherries/withdrawals` (Idempotency-Key). Order: 400 (key, body, amount below the
   * minimum) → the same key again → 200 with that request (409 IDEMPOTENCY_CONFLICT when the body differs)
   * → 409 WITHDRAWAL_PENDING → 409 INSUFFICIENT_CHERRIES (more than the withdrawable cherries: the balance
   * less the locked task cherries, v1.53-social D184) → 201, the cherries held.
   */
  async withdraw(
    me: string,
    rawKey: string | undefined,
    body: unknown,
  ): Promise<{ created: boolean; result: CherryWithdrawalDto }> {
    if (rawKey === undefined || rawKey === '') {
      throw AppException.validation([{ field: 'Idempotency-Key', issue: 'required' }]);
    }
    const key = z.uuid().safeParse(rawKey);
    if (!key.success) throw AppException.validation([{ field: 'Idempotency-Key', issue: 'invalid_format' }]);
    const parsed = withdrawalBodySchema.safeParse(body);
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { amountMinor, payoutDetails } = parsed.data;
    const e = this.config.economy;
    if (amountMinor < e.minWithdrawalMinor) {
      throw AppException.validation([{ field: 'amountMinor', issue: 'too_small' }]);
    }
    const clientId = key.data.toLowerCase();
    const replay = async () => {
      const existing = await this.prisma.cherryWithdrawal.findUnique({
        where: { userId_clientId: { userId: me, clientId } },
      });
      if (!existing) return null;
      if (Number(existing.amountMinor) !== amountMinor || existing.payoutDetails !== payoutDetails) {
        throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
      }
      return { created: false, result: withdrawalDto(existing) };
    };
    const earlier = await replay();
    if (earlier) return earlier;
    const cherries = withdrawalCherries(BigInt(amountMinor), e.rateCherries, e.rateMinor);
    const now = this.clock.now();
    try {
      const row = await this.prisma.$transaction(async (tx) => {
        const pending = await tx.cherryWithdrawal.findFirst({
          where: { userId: me, status: 'PENDING' },
          select: { id: true },
        });
        if (pending) throw new AppException(ErrorCode.WITHDRAWAL_PENDING);
        const id = uuidv7();
        const created = await tx.cherryWithdrawal.create({
          data: {
            id,
            userId: me,
            clientId,
            cherries,
            amountMinor: BigInt(amountMinor),
            currency: e.currency,
            rateCherries: BigInt(e.rateCherries),
            rateMinor: e.rateMinor,
            payoutDetails,
            createdAt: now,
          },
        });
        // v1.53-social (D184): task cherries stay out of a withdrawal until they are unlocked.
        const lock = await taskCherryLockIn(tx, me, e);
        const balance = await holdCherriesIn(tx, me, cherries, id, now, lock.lockedCherries);
        if (balance === null) throw new AppException(ErrorCode.INSUFFICIENT_CHERRIES);
        await tx.auditLog.create({
          data: {
            actorUserId: me,
            action: AuditAction.CHERRY_WITHDRAWAL_REQUEST,
            targetType: 'cherry_withdrawal',
            targetId: id,
            metadata: {
              cherries: Number(cherries),
              amountMinor,
              currency: e.currency,
              balance: Number(balance),
            },
          },
        });
        return created;
      });
      return { created: true, result: withdrawalDto(row) };
    } catch (err) {
      // A concurrent request: the same key (→ its request) or another pending one (the partial unique index).
      if (err instanceof AppException) throw err;
      const raced = await replay();
      if (raced) return raced;
      const pending = await this.prisma.cherryWithdrawal.findFirst({
        where: { userId: me, status: 'PENDING' },
      });
      if (pending) throw new AppException(ErrorCode.WITHDRAWAL_PENDING);
      throw err;
    }
  }

  /** `GET /wallet/me/cherries/withdrawals`: newest first. */
  async withdrawals(me: string, query: PageQuery): Promise<PageDto<CherryWithdrawalDto>> {
    const scope = `cherry-withdrawals:${me}`;
    const after = this.after(query.cursor, scope);
    const rows = await this.prisma.cherryWithdrawal.findMany({
      where: {
        userId: me,
        ...(after
          ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
    });
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];
    return {
      data: page.map(withdrawalDto),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  /** The senders the caller may see: ACTIVE, and no block either way. */
  private async visibleSenders(me: string, ids: string[]): Promise<Map<string, UserSummaryDto>> {
    if (ids.length === 0) return new Map();
    const users = await this.prisma.user.findMany({
      where: {
        id: { in: ids },
        status: 'ACTIVE',
        blocking: { none: { blockedId: me } },
        blockedBy: { none: { blockerId: me } },
      },
      select: USER_SUMMARY_SELECT,
    });
    return new Map(users.map((u) => [u.id, userSummary(u)]));
  }
}
