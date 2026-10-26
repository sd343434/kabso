import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { creditFamilyForSpendIn } from '../families/family-points.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { isUuid } from '../live/live.schemas.js';
import { awardMedalsIn } from '../medals/medal-awards.js';
import { Notifier } from '../notifications/notifier.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { bumpRoomsSeatingBothIn } from '../live/live-seats.store.js';
import { blockedEitherWayIn, lockUserPairIn } from '../social/pair-lock.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { WalletService } from '../wallet/wallet.service.js';
import {
  CP_GIFT_AMOUNTS,
  CP_REQUEST_COST_COINS,
  CP_REQUEST_TTL_MS,
  CP_TIERS,
  cpLevelFor,
  cpNextTier,
  cpTierName,
} from './couples.constants.js';
import { cpGiftSendSchema, cpRequestSendSchema, type CpRequestListQuery } from './couples.schemas.js';

type Tx = Prisma.TransactionClient;

// ---- Response shapes (openapi v1.21-live, CP-018) ----------------------------------------------

/** `CpRequest`. */
export interface CpRequestDto {
  id: string;
  sender: UserSummaryDto;
  receiver: UserSummaryDto;
  status: 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'CANCELLED' | 'EXPIRED';
  cost: number;
  createdAt: string;
  expiresAt: string;
}

/** `CpRequestResult`: the request and the sender's balance after the charge. */
export interface CpRequestResultDto {
  request: CpRequestDto;
  coins: number;
}

/** `CpCouple`: the caller's couple. */
export interface CpCoupleDto {
  id: string;
  partner: UserSummaryDto;
  since: string;
  /** Days together, counting the day the couple was formed as day 1. */
  days: number;
  points: number;
  level: number;
  levelName: string;
  nextLevelName: string | null;
  /** CP points still needed for the next tier, or null at the top tier. */
  pointsToNext: number | null;
}

/** `CpGiftResult`. */
export interface CpGiftResultDto {
  gift: { id: string; amount: number; createdAt: string };
  cp: CpCoupleDto;
  coins: number;
}

/** `ProfileCp`: a user's couple on their public profile (§10.5, §10.21). */
export interface ProfileCpDto {
  partner: UserSummaryDto;
  since: string;
  level: number;
  levelName: string;
  points: number;
}

/** `CpConfig`. */
export interface CpConfigDto {
  requestCost: number;
  requestTtlDays: number;
  giftAmounts: number[];
  tiers: { level: number; minPoints: number; name: string }[];
}

const REQUEST_INCLUDE = {
  sender: { select: USER_SUMMARY_SELECT },
  receiver: { select: USER_SUMMARY_SELECT },
} as const satisfies Prisma.CpRequestInclude;
type RequestRow = Prisma.CpRequestGetPayload<{ include: typeof REQUEST_INCLUDE }>;

interface LockedRequest {
  id: string;
  sender_id: string;
  receiver_id: string;
  cost: number;
  status: string;
  expires_at: Date;
}

const DAY_MS = 24 * 3600_000;
const SWEEP_BATCH = 200;

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

/**
 * CP couples (العلاقة, CP-018, owner D106, CONVENTIONS §10.21). A CP request costs
 * {@link CP_REQUEST_COST_COINS} coins, taken at send and given back (CP_REFUND) when it is
 * declined, cancelled or expires after 7 days; the receiver accepts and the couple is formed. Each
 * user has at most one partner and one outgoing pending request. Partners send CP gifts (preset
 * amounts) that add CP points and raise the couple's tier. Either partner ends it (no refund).
 */
@Injectable()
export class CouplesService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(CouplesService.name);
  private readonly cursors: SocialCursorCodec;
  private sweepTimer: NodeJS.Timeout | undefined;
  private sweepInFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly wallet: WalletService,
    private readonly users: UsersService,
    private readonly notifier: Notifier,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  onModuleInit(): void {
    if (this.config.social.bondsSweepIntervalSeconds > 0) this.scheduleSweep();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.sweepTimer) clearTimeout(this.sweepTimer);
    await this.sweepInFlight?.catch(() => undefined);
  }

  /** `GET /cp/config`. */
  configDto(lang: ContentLanguage): CpConfigDto {
    return {
      requestCost: CP_REQUEST_COST_COINS,
      requestTtlDays: CP_REQUEST_TTL_MS / DAY_MS,
      giftAmounts: [...CP_GIFT_AMOUNTS],
      tiers: CP_TIERS.map((t) => ({
        level: t.level,
        minPoints: t.minPoints,
        name: cpTierName(t.level, lang),
      })),
    };
  }

  private requestDto(row: RequestRow): CpRequestDto {
    const expired = row.status === 'PENDING' && row.expiresAt <= this.clock.now();
    return {
      id: row.id,
      sender: userSummary(row.sender),
      receiver: userSummary(row.receiver),
      status: expired ? 'EXPIRED' : row.status,
      cost: row.cost,
      createdAt: row.createdAt.toISOString(),
      expiresAt: row.expiresAt.toISOString(),
    };
  }

  private async requestById(id: string): Promise<CpRequestDto> {
    return this.requestDto(
      await this.prisma.cpRequest.findUniqueOrThrow({ where: { id }, include: REQUEST_INCLUDE }),
    );
  }

  /** Gives a request's coins back (CP_REFUND, reference the request id). */
  private async refundIn(tx: Tx, request: Pick<LockedRequest, 'id' | 'sender_id' | 'cost'>): Promise<void> {
    await this.wallet.creditIn(tx, request.sender_id, request.cost, 'CP_REFUND', request.id);
  }

  /** Closes a locked PENDING request with `status` and refunds it. */
  private async closeWithRefundIn(
    tx: Tx,
    request: LockedRequest,
    status: 'DECLINED' | 'CANCELLED' | 'EXPIRED',
  ): Promise<void> {
    await tx.cpRequest.update({ where: { id: request.id }, data: { status, handledAt: this.clock.now() } });
    await this.refundIn(tx, request);
  }

  private async lockRequest(tx: Tx, where: Prisma.Sql): Promise<LockedRequest | null> {
    const [row] = await tx.$queryRaw<LockedRequest[]>`
      SELECT id::text AS id, sender_id::text AS sender_id, receiver_id::text AS receiver_id, cost,
             status::text AS status, expires_at
        FROM cp_requests WHERE ${where} FOR UPDATE`;
    return row ?? null;
  }

  // ---------------------------------------------------------------------------------------------
  // Requests

  /**
   * `POST /cp/requests`. Order after auth and rate limit: 400 body; a retry with the same
   * `clientId` → 200 with the first request and the current balance (nothing charged again); 404
   * (unknown or inactive user, or a block either way); 400 `username` / `invalid_value` (oneself);
   * 409 CP_ALREADY_PAIRED (the caller or the other person has a partner); 409 CP_REQUEST_PENDING
   * (the caller has a pending request); 409 INSUFFICIENT_COINS. The request, the 99-coin charge
   * (ledger CP_REQUEST) and the receiver's `CP_REQUEST` notification are one transaction.
   */
  async send(callerId: string, body: unknown): Promise<{ created: boolean; result: CpRequestResultDto }> {
    const parsed = cpRequestSendSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const clientId = parsed.data.clientId.toLowerCase();
    const replay = await this.replaySend(callerId, clientId);
    if (replay) return { created: false, result: replay };

    const now = this.clock.now();
    let created: { id: string; coins: bigint };
    try {
      created = await this.prisma.$transaction(async (tx) => {
        const target = await this.users.lockActiveByUsername(tx, parsed.data.username);
        if (!target) throw notFound();
        if (target.id === callerId)
          throw AppException.validation([{ field: 'username', issue: 'invalid_value' }]);
        await lockUserPairIn(tx, callerId, target.id);
        if (await blockedEitherWayIn(tx, callerId, target.id)) throw notFound();
        const paired = await tx.cpPartner.count({ where: { userId: { in: [callerId, target.id] } } });
        if (paired > 0) throw new AppException(ErrorCode.CP_ALREADY_PAIRED);
        // A pending request of the caller that ran out of time is expired (and refunded) first.
        const pending = await this.lockRequest(
          tx,
          Prisma.sql`sender_id = ${callerId}::uuid AND status = 'PENDING'`,
        );
        if (pending) {
          if (pending.expires_at > now) throw new AppException(ErrorCode.CP_REQUEST_PENDING);
          await this.closeWithRefundIn(tx, pending, 'EXPIRED');
        }
        const request = await tx.cpRequest.create({
          data: {
            senderId: callerId,
            receiverId: target.id,
            clientId,
            cost: CP_REQUEST_COST_COINS,
            createdAt: now,
            expiresAt: new Date(now.getTime() + CP_REQUEST_TTL_MS),
          },
          select: { id: true },
        });
        const charged = await this.wallet.debitIn(
          tx,
          callerId,
          CP_REQUEST_COST_COINS,
          'CP_REQUEST',
          request.id,
        );
        if (!charged) throw new AppException(ErrorCode.INSUFFICIENT_COINS);
        await this.notifier.notify(tx, { type: 'CP_REQUEST', recipientId: target.id, actorId: callerId });
        return { id: request.id, coins: charged.coins };
      });
    } catch (err) {
      const index = violatedUniqueIndex(err);
      if (index !== null && index.includes('cp_requests_client_once')) {
        const raced = await this.replaySend(callerId, clientId);
        if (raced) return { created: false, result: raced };
      }
      if (index !== null && index.includes('cp_requests_one_outgoing')) {
        throw new AppException(ErrorCode.CP_REQUEST_PENDING);
      }
      throw err;
    }
    return {
      created: true,
      result: { request: await this.requestById(created.id), coins: Number(created.coins) },
    };
  }

  private async replaySend(callerId: string, clientId: string): Promise<CpRequestResultDto | null> {
    const row = await this.prisma.cpRequest.findUnique({
      where: { senderId_clientId: { senderId: callerId, clientId } },
      include: REQUEST_INCLUDE,
    });
    if (!row) return null;
    return { request: this.requestDto(row), coins: (await this.wallet.mine(callerId)).coins };
  }

  /**
   * `GET /cp/requests?direction=incoming|outgoing`: the caller's pending requests (not expired),
   * newest first; incoming ones only from ACTIVE senders the caller has no block with.
   */
  async list(callerId: string, query: CpRequestListQuery): Promise<PageDto<CpRequestDto>> {
    const now = this.clock.now();
    const scope = `cp-requests:${query.direction}:${callerId}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const side: Prisma.CpRequestWhereInput =
      query.direction === 'incoming'
        ? {
            receiverId: callerId,
            sender: {
              status: 'ACTIVE',
              blocking: { none: { blockedId: callerId } },
              blockedBy: { none: { blockerId: callerId } },
            },
          }
        : { senderId: callerId, receiver: { status: 'ACTIVE' } };
    const rows = await this.prisma.cpRequest.findMany({
      where: {
        AND: [
          side,
          { status: 'PENDING', expiresAt: { gt: now } },
          after
            ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
            : {},
        ],
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
      include: REQUEST_INCLUDE,
    });
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];
    return {
      data: page.map((r) => this.requestDto(r)),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  /**
   * Runs `fn` on the caller's request `requestId` (as `role`) locked in a transaction. A request
   * that is not PENDING → 409 CP_REQUEST_NOT_PENDING; one that ran out of time is expired and
   * refunded (committed) and answers the same 409.
   */
  private async onPending<T>(
    callerId: string,
    requestId: string,
    role: 'sender' | 'receiver',
    fn: (tx: Tx, request: LockedRequest) => Promise<T>,
  ): Promise<T> {
    if (!isUuid(requestId)) throw notFound();
    const id = requestId.toLowerCase();
    const outcome = await this.prisma.$transaction(async (tx) => {
      const who = role === 'sender' ? Prisma.sql`sender_id` : Prisma.sql`receiver_id`;
      const request = await this.lockRequest(tx, Prisma.sql`id = ${id}::uuid AND ${who} = ${callerId}::uuid`);
      if (!request) throw notFound();
      if (request.status !== 'PENDING') return { notPending: true as const };
      if (request.expires_at <= this.clock.now()) {
        await this.closeWithRefundIn(tx, request, 'EXPIRED');
        return { notPending: true as const };
      }
      return { value: await fn(tx, request) };
    });
    if ('notPending' in outcome) throw new AppException(ErrorCode.CP_REQUEST_NOT_PENDING);
    return outcome.value;
  }

  /** `DELETE /cp/requests/{requestId}`: the sender cancels; the coins come back → 204. */
  async cancel(callerId: string, requestId: string): Promise<void> {
    await this.onPending(callerId, requestId, 'sender', (tx, request) =>
      this.closeWithRefundIn(tx, request, 'CANCELLED'),
    );
  }

  /** `POST /cp/requests/{requestId}/decline`: the receiver declines; the sender's coins come back → 204. */
  async decline(callerId: string, requestId: string): Promise<void> {
    await this.onPending(callerId, requestId, 'receiver', (tx, request) =>
      this.closeWithRefundIn(tx, request, 'DECLINED'),
    );
  }

  /**
   * `POST /cp/requests/{requestId}/accept` (the receiver). After 404 / 409 CP_REQUEST_NOT_PENDING:
   * a block either way or an inactive sender closes the request (CANCELLED, refunded) → 409
   * CP_REQUEST_NOT_PENDING; 409 CP_ALREADY_PAIRED (either has a partner; the request stays). In one
   * transaction: the couple and both partner rows, the request ACCEPTED, the sender's 99 coins
   * counted for the sender's family, every other pending request of either partner closed and
   * refunded, FIRST_CP for both, and a `CP_ACCEPTED` notification to the sender.
   */
  async accept(callerId: string, requestId: string, lang: ContentLanguage): Promise<CpCoupleDto> {
    const now = this.clock.now();
    let result: { closed: true } | { coupleId: string };
    try {
      result = await this.onPending(callerId, requestId, 'receiver', async (tx, request) => {
        await lockUserPairIn(tx, request.sender_id, request.receiver_id);
        const senderActive = await this.users.lockActiveById(tx, request.sender_id);
        if (!senderActive || (await blockedEitherWayIn(tx, request.sender_id, request.receiver_id))) {
          await this.closeWithRefundIn(tx, request, 'CANCELLED');
          return { closed: true as const };
        }
        const paired = await tx.cpPartner.count({
          where: { userId: { in: [request.sender_id, request.receiver_id] } },
        });
        if (paired > 0) throw new AppException(ErrorCode.CP_ALREADY_PAIRED);
        const [a, b] =
          request.sender_id < request.receiver_id
            ? [request.sender_id, request.receiver_id]
            : [request.receiver_id, request.sender_id];
        const couple = await tx.cpCouple.create({
          data: { userAId: a, userBId: b, requestId: request.id, since: now },
          select: { id: true },
        });
        await tx.cpPartner.createMany({
          data: [
            { userId: a, partnerId: b, coupleId: couple.id },
            { userId: b, partnerId: a, coupleId: couple.id },
          ],
        });
        await tx.cpRequest.update({
          where: { id: request.id },
          data: { status: 'ACCEPTED', handledAt: now },
        });
        // The request's coins are spent now: they count for the sender's family (§10.21).
        const ledger = await tx.walletLedgerEntry.findUnique({
          where: { reason_referenceId: { reason: 'CP_REQUEST', referenceId: request.id } },
          select: { id: true },
        });
        if (ledger) await creditFamilyForSpendIn(tx, request.sender_id, ledger.id, BigInt(request.cost));
        await this.closeOthersIn(tx, [a, b], request.id);
        await awardMedalsIn(tx, a, ['FIRST_CP'], { at: now });
        await awardMedalsIn(tx, b, ['FIRST_CP'], { at: now });
        // v1.23.3-live (D111): rooms where both sit now show the pair joined (§10.9).
        await bumpRoomsSeatingBothIn(tx, a, b);
        await this.notifier.notify(tx, {
          type: 'CP_ACCEPTED',
          recipientId: request.sender_id,
          actorId: callerId,
        });
        return { coupleId: couple.id };
      });
    } catch (err) {
      const index = violatedUniqueIndex(err);
      if (index !== null && (index.includes('cp_partners_pkey') || index === 'user_id')) {
        throw new AppException(ErrorCode.CP_ALREADY_PAIRED);
      }
      throw err;
    }
    if ('closed' in result) throw new AppException(ErrorCode.CP_REQUEST_NOT_PENDING);
    const mine = await this.mine(callerId, lang);
    if (!mine.cp) throw notFound();
    return mine.cp;
  }

  /** Closes (CANCELLED, refunded) every other pending request sent by or to `userIds`. */
  private async closeOthersIn(tx: Tx, userIds: readonly string[], exceptId: string): Promise<void> {
    const rows = await tx.$queryRaw<LockedRequest[]>`
      SELECT id::text AS id, sender_id::text AS sender_id, receiver_id::text AS receiver_id, cost,
             status::text AS status, expires_at
        FROM cp_requests
       WHERE status = 'PENDING' AND id <> ${exceptId}::uuid
         AND (sender_id = ANY(${[...userIds]}::uuid[]) OR receiver_id = ANY(${[...userIds]}::uuid[]))
       ORDER BY id
         FOR UPDATE`;
    for (const row of rows) await this.closeWithRefundIn(tx, row, 'CANCELLED');
  }

  // ---------------------------------------------------------------------------------------------
  // The couple

  private coupleDto(
    row: { id: string; since: Date; points: bigint; level: number },
    partner: UserSummaryDto,
    lang: ContentLanguage,
  ): CpCoupleDto {
    const next = cpNextTier(row.level);
    const points = Number(row.points);
    return {
      id: row.id,
      partner,
      since: row.since.toISOString(),
      days: Math.floor((this.clock.now().getTime() - row.since.getTime()) / DAY_MS) + 1,
      points,
      level: row.level,
      levelName: cpTierName(row.level, lang),
      nextLevelName: next ? cpTierName(next.level, lang) : null,
      pointsToNext: next ? Math.max(0, next.minPoints - points) : null,
    };
  }

  /** `GET /cp/me`: the caller's couple, or null. */
  async mine(callerId: string, lang: ContentLanguage): Promise<{ cp: CpCoupleDto | null }> {
    const row = await this.prisma.cpPartner.findUnique({
      where: { userId: callerId },
      include: {
        couple: { select: { id: true, since: true, points: true, level: true } },
        partner: { select: USER_SUMMARY_SELECT },
      },
    });
    return { cp: row ? this.coupleDto(row.couple, userSummary(row.partner), lang) : null };
  }

  /** A user's couple on their public profile (§10.5), or null; a partner who is not ACTIVE → null. */
  async profileCp(userId: string, lang: ContentLanguage): Promise<ProfileCpDto | null> {
    const row = await this.prisma.cpPartner.findFirst({
      where: { userId, partner: { status: 'ACTIVE' } },
      include: {
        couple: { select: { since: true, points: true, level: true } },
        partner: { select: USER_SUMMARY_SELECT },
      },
    });
    if (!row) return null;
    return {
      partner: userSummary(row.partner),
      since: row.couple.since.toISOString(),
      level: row.couple.level,
      levelName: cpTierName(row.couple.level, lang),
      points: Number(row.couple.points),
    };
  }

  /** `DELETE /cp/me`: either partner ends the couple (no refund); not paired → 204 too. */
  async end(callerId: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const [row] = await tx.$queryRaw<{ couple_id: string }[]>`
        SELECT couple_id::text AS couple_id FROM cp_partners WHERE user_id = ${callerId}::uuid`;
      if (!row) return;
      await tx.$queryRaw`SELECT id FROM cp_couples WHERE id = ${row.couple_id}::uuid FOR UPDATE`;
      const partners = await tx.cpPartner.findMany({
        where: { coupleId: row.couple_id },
        select: { userId: true },
      });
      await tx.cpPartner.deleteMany({ where: { coupleId: row.couple_id } });
      const ended = await tx.cpCouple.update({
        where: { id: row.couple_id },
        data: { endedAt: this.clock.now(), endedById: callerId },
        select: { userAId: true, userBId: true },
      });
      // v1.23.3-live (D111): rooms where both sit now stop showing the pair joined (§10.9).
      if (partners.length > 0) await bumpRoomsSeatingBothIn(tx, ended.userAId, ended.userBId);
    });
  }

  /**
   * `POST /cp/me/gifts`. Order: 400 body (`amount` one of {@link CP_GIFT_AMOUNTS}); a retry with
   * the same `clientId` → 200 with the first gift, the couple and the current balance; 409
   * CP_NOT_PAIRED; 409 INSUFFICIENT_COINS. The gift, the charge (ledger CP_GIFT, which also counts
   * for the sender's family) and the couple's points and tier are one transaction.
   */
  async gift(
    callerId: string,
    body: unknown,
    lang: ContentLanguage,
  ): Promise<{ created: boolean; result: CpGiftResultDto }> {
    const parsed = cpGiftSendSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const clientId = parsed.data.clientId.toLowerCase();
    const amount = parsed.data.amount;
    const replay = await this.replayGift(callerId, clientId, lang);
    if (replay) return { created: false, result: replay };
    const now = this.clock.now();
    let created: { id: string; coins: bigint };
    try {
      created = await this.prisma.$transaction(async (tx) => {
        const [partner] = await tx.$queryRaw<{ couple_id: string; partner_id: string }[]>`
          SELECT couple_id::text AS couple_id, partner_id::text AS partner_id
            FROM cp_partners WHERE user_id = ${callerId}::uuid`;
        if (!partner) throw new AppException(ErrorCode.CP_NOT_PAIRED);
        const [couple] = await tx.$queryRaw<{ points: bigint; level: number }[]>`
          SELECT points, level FROM cp_couples WHERE id = ${partner.couple_id}::uuid AND ended_at IS NULL FOR UPDATE`;
        if (!couple) throw new AppException(ErrorCode.CP_NOT_PAIRED);
        const gift = await tx.cpGift.create({
          data: {
            coupleId: partner.couple_id,
            senderId: callerId,
            receiverId: partner.partner_id,
            amount,
            clientId,
            createdAt: now,
          },
          select: { id: true },
        });
        const charged = await this.wallet.debitIn(tx, callerId, amount, 'CP_GIFT', gift.id);
        if (!charged) throw new AppException(ErrorCode.INSUFFICIENT_COINS);
        const points = couple.points + BigInt(amount);
        const level = cpLevelFor(points);
        await tx.cpCouple.update({
          where: { id: partner.couple_id },
          data: { points, level },
        });
        // v1.23.3-live (D111): `LiveSeats.couples` carries the level (§10.9).
        if (level !== couple.level) await bumpRoomsSeatingBothIn(tx, callerId, partner.partner_id);
        return { id: gift.id, coins: charged.coins };
      });
    } catch (err) {
      const index = violatedUniqueIndex(err);
      if (index !== null && index.includes('cp_gifts_client_once')) {
        const raced = await this.replayGift(callerId, clientId, lang);
        if (raced) return { created: false, result: raced };
      }
      throw err;
    }
    const mine = await this.mine(callerId, lang);
    return {
      created: true,
      result: {
        gift: { id: created.id, amount, createdAt: now.toISOString() },
        cp: mine.cp!,
        coins: Number(created.coins),
      },
    };
  }

  private async replayGift(
    callerId: string,
    clientId: string,
    lang: ContentLanguage,
  ): Promise<CpGiftResultDto | null> {
    const row = await this.prisma.cpGift.findUnique({
      where: { senderId_clientId: { senderId: callerId, clientId } },
      include: {
        couple: { select: { id: true, since: true, points: true, level: true } },
        receiver: { select: USER_SUMMARY_SELECT },
      },
    });
    if (!row) return null;
    return {
      gift: { id: row.id, amount: row.amount, createdAt: row.createdAt.toISOString() },
      cp: this.coupleDto(row.couple, userSummary(row.receiver), lang),
      coins: (await this.wallet.mine(callerId)).coins,
    };
  }

  // ---------------------------------------------------------------------------------------------
  // Expiry

  /**
   * Expires CP requests older than 7 days and gives their coins back, one request per short
   * transaction (rows another instance holds are skipped). Returns how many.
   */
  async sweepExpired(now: Date = this.clock.now()): Promise<number> {
    let total = 0;
    for (;;) {
      const due = await this.prisma.cpRequest.findMany({
        where: { status: 'PENDING', expiresAt: { lte: now } },
        select: { id: true },
        orderBy: { expiresAt: 'asc' },
        take: SWEEP_BATCH,
      });
      if (due.length === 0) return total;
      let batch = 0;
      for (const { id } of due) {
        const expired = await this.prisma.$transaction(async (tx) => {
          const [row] = await tx.$queryRaw<LockedRequest[]>`
            SELECT id::text AS id, sender_id::text AS sender_id, receiver_id::text AS receiver_id, cost,
                   status::text AS status, expires_at
              FROM cp_requests
             WHERE id = ${id}::uuid AND status = 'PENDING' AND expires_at <= ${now.toISOString()}::timestamptz
               FOR UPDATE SKIP LOCKED`;
          if (!row) return false;
          await this.closeWithRefundIn(tx, row, 'EXPIRED');
          return true;
        });
        if (expired) batch += 1;
      }
      total += batch;
      // Rows another instance holds are left to it; stop rather than spin on them.
      if (due.length < SWEEP_BATCH || batch === 0) return total;
    }
  }

  private scheduleSweep(): void {
    this.sweepTimer = setTimeout(() => {
      this.sweepInFlight = this.sweepExpired()
        .then(() => undefined)
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'CP request sweep failed');
        })
        .finally(() => {
          this.sweepInFlight = null;
          this.scheduleSweep();
        });
    }, this.config.social.bondsSweepIntervalSeconds * 1000);
    this.sweepTimer.unref();
  }
}
