import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { LiveBoost, LiveBoostSource, Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import { creditIn, debitIn } from '../wallet/wallet-ledger.js';
import { WalletService } from '../wallet/wallet.service.js';
import {
  addBoostCardsIn,
  BOOST_TOPIC,
  boostOptions,
  placeBoost,
  replanWaiting,
  slotsFreeAt,
  type BoostOptionDto,
} from './live-boosts.js';
import {
  LiveRoomsService,
  LIVE_TX_OPTIONS,
  setLiveStatementTimeout,
  type LiveRoomSummaryDto,
  type UserSummaryDto,
} from './live-rooms.service.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

/** `LiveBoostState`: waiting for its slot, on the list now, over, or cancelled (refunded). */
export type LiveBoostState = 'WAITING' | 'RUNNING' | 'DONE' | 'CANCELLED';

/** `LiveBoost` (v1.33-live, D154b, CONVENTIONS §10.34). */
export interface LiveBoostDto {
  id: string;
  roomId: string;
  host: UserSummaryDto;
  buyer: UserSummaryDto;
  minutes: number;
  source: LiveBoostSource;
  coinsCharged: number;
  state: LiveBoostState;
  /** When it starts (at the latest, while WAITING) and ends. */
  startsAt: string;
  endsAt: string;
  createdAt: string;
}

/** `LiveBoostCardStock`: traffic cards the caller holds of one length. */
export interface BoostCardDto {
  minutes: number;
  quantity: number;
}

/** `LiveBoostOffers`. */
export interface LiveBoostOffersDto {
  slots: number;
  maxWaitMinutes: number;
  options: BoostOptionDto[];
  cards: BoostCardDto[];
  /** When a new card would start now (at the latest), whatever its length. */
  nextStartAt: string;
  /** The room's own card running or waiting (`roomId` given), or null. */
  roomBoost: LiveBoostDto | null;
}

/** `LiveBoostedRoom`: a live in a paid slot now. */
export interface LiveBoostedRoomDto {
  room: LiveRoomSummaryDto;
  endsAt: string;
}

/** `LiveBoostResult`. */
export interface LiveBoostResultDto {
  boost: LiveBoostDto;
  coins: number;
  cards: BoostCardDto[];
}

const buySchema = (minutes: readonly number[]) =>
  z.strictObject({
    minutes: z
      .number()
      .int()
      .refine((m) => minutes.includes(m), {
        message: 'not an offered length',
        params: { issue: 'invalid_value' },
      }),
    source: z.string().pipe(z.enum(['COINS', 'CARD'])),
    clientId: z.uuid(),
  });

const BOOST_INCLUDE = {
  host: { select: USER_SUMMARY_SELECT },
  buyer: { select: USER_SUMMARY_SELECT },
} as const satisfies Prisma.LiveBoostInclude;
type BoostRow = Prisma.LiveBoostGetPayload<{ include: typeof BOOST_INCLUDE }>;

/** One transaction-wide lock: every change of the plan of slots runs under it. */
const PLAN_LOCK = 'live-boosts-plan';

/**
 * Traffic cards «بطاقة الزيارات» (D154b, CONVENTIONS §10.34; the room boost of CP-014 part C): a
 * signed-in person who can see a LIVE room — its host, or a viewer gifting it — buys a card of one
 * of the configured lengths with coins (ledger `LIVE_BOOST`) or uses one of their cards (granted by an
 * admin); the live then shows in one of the `slots` paid slots at the top of the live list, labelled
 * «مميز», for that long. Cards wait in one FIFO queue; the buyer is told when it starts (at the
 * latest). The host earns nothing from it (no score, charm or share; owner 15c). When a live ends, its
 * waiting card is cancelled and refunded (the coins, or the card), its running card stops there.
 */
@Injectable()
export class LiveBoostsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(LiveBoostsService.name);
  private timer: NodeJS.Timeout | undefined;

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly wallet: WalletService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
  ) {}

  onModuleInit(): void {
    const seconds = this.config.live.sweepIntervalSeconds;
    if (seconds > 0) {
      this.timer = setInterval(() => {
        this.settle().catch((err: unknown) =>
          this.logger.warn({ error: safeErrorLog(err) }, 'Traffic card settlement failed'),
        );
      }, seconds * 1000);
      this.timer.unref();
    }
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  private get slots(): number {
    return this.config.boosts.slots;
  }

  private stateOf(b: Pick<LiveBoost, 'startsAt' | 'endsAt' | 'cancelledAt'>, now: Date): LiveBoostState {
    if (b.cancelledAt) return 'CANCELLED';
    if (b.startsAt > now) return 'WAITING';
    return b.endsAt > now ? 'RUNNING' : 'DONE';
  }

  private toDto(row: BoostRow, now: Date): LiveBoostDto {
    return {
      id: row.id,
      roomId: row.roomId,
      host: userSummary(row.host),
      buyer: userSummary(row.buyer),
      minutes: row.minutes,
      source: row.source,
      coinsCharged: Number(row.coinsCharged),
      state: this.stateOf(row, now),
      startsAt: row.startsAt.toISOString(),
      endsAt: row.endsAt.toISOString(),
      createdAt: row.createdAt.toISOString(),
    };
  }

  private async cardsOf(
    db: Pick<Prisma.TransactionClient, 'liveBoostCard'>,
    userId: string,
  ): Promise<BoostCardDto[]> {
    const rows = await db.liveBoostCard.findMany({
      where: { userId, quantity: { gt: 0 } },
      orderBy: { minutes: 'asc' },
      select: { minutes: true, quantity: true },
    });
    return rows;
  }

  /**
   * In `tx`, under the plan lock: cancels and refunds the waiting cards of lives that ended, stops the
   * running ones of lives that ended, and plans the waiting cards again (never later than before).
   * Returns the plan of the cards that end after `now`.
   */
  private async settleIn(tx: Prisma.TransactionClient, now: Date): Promise<LiveBoost[]> {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${PLAN_LOCK}, 0))`;
    const at = now.toISOString();
    const open = await tx.$queryRaw<(LiveBoost & { live: boolean })[]>`
      SELECT b.id, b.room_id AS "roomId", b.host_user_id AS "hostUserId", b.buyer_id AS "buyerId",
             b.client_id AS "clientId", b.minutes, b.source, b.coins_charged AS "coinsCharged", b.slot,
             b.starts_at AS "startsAt", b.ends_at AS "endsAt", b.cancelled_at AS "cancelledAt",
             b.created_at AS "createdAt", (r.status = 'LIVE') AS live
        FROM live_boosts b JOIN live_rooms r ON r.id = b.room_id
       WHERE b.cancelled_at IS NULL AND b.ends_at > ${at}::timestamptz
       ORDER BY b.starts_at, b.id`;
    let changed = false;
    const keep: LiveBoost[] = [];
    for (const b of open) {
      if (b.live) {
        keep.push(b);
        continue;
      }
      changed = true;
      if (b.startsAt > now) {
        // Never ran: cancelled, and the coins or the card go back to the buyer.
        await tx.liveBoost.update({ where: { id: b.id }, data: { cancelledAt: now } });
        if (b.source === 'COINS') {
          await creditIn(tx, b.buyerId, b.coinsCharged, 'LIVE_BOOST_REFUND', b.id);
        } else {
          await addBoostCardsIn(tx, b.buyerId, b.minutes, 1);
        }
      } else {
        // The live ended while on the list: the card stops there (its time is used).
        await tx.liveBoost.update({ where: { id: b.id }, data: { endsAt: now } });
      }
    }
    if (!changed) return keep;
    const running = keep.filter((b) => b.startsAt <= now);
    const waiting = keep.filter((b) => b.startsAt > now);
    const plan = replanWaiting(now, this.slots, running, waiting);
    for (const b of waiting) {
      const p = plan.get(b.id)!;
      if (p.slot !== b.slot || p.startsAt.getTime() !== b.startsAt.getTime()) {
        await tx.liveBoost.update({
          where: { id: b.id },
          data: { slot: p.slot, startsAt: p.startsAt, endsAt: p.endsAt },
        });
        Object.assign(b, p);
      }
    }
    return keep;
  }

  /** The background settlement (and tests): ended lives' cards cancelled, refunded or stopped. */
  async settle(): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await setLiveStatementTimeout(tx);
      await this.settleIn(tx, this.clock.now());
    }, LIVE_TX_OPTIONS);
  }

  /** `GET /live/boosts/offers[?roomId=]`: the lengths and prices, the caller's cards, the queue. */
  async offers(callerId: string, roomId: string | undefined): Promise<LiveBoostOffersDto> {
    if (roomId !== undefined && !z.uuid().safeParse(roomId).success) {
      throw AppException.validation([{ field: 'roomId', issue: 'invalid_format' }]);
    }
    if (roomId !== undefined) await this.rooms.visibleRow(roomId, callerId);
    const now = this.clock.now();
    const at = now.toISOString();
    const planned = await this.prisma.liveBoost.findMany({
      where: { cancelledAt: null, endsAt: { gt: now } },
      select: { id: true, slot: true, startsAt: true, endsAt: true, roomId: true },
    });
    const free = slotsFreeAt(now, this.slots, planned);
    const next = new Date(Math.min(...free));
    const own =
      roomId === undefined
        ? null
        : await this.prisma.liveBoost.findFirst({
            where: { roomId, cancelledAt: null, endsAt: { gt: new Date(at) } },
            orderBy: { startsAt: 'asc' },
            include: BOOST_INCLUDE,
          });
    return {
      slots: this.slots,
      maxWaitMinutes: Math.round(this.config.boosts.maxWaitMs / 60_000),
      options: boostOptions(this.config.boosts.prices),
      cards: await this.cardsOf(this.prisma, callerId),
      nextStartAt: next.toISOString(),
      roomBoost: own ? this.toDto(own, now) : null,
    };
  }

  /** `GET /live/boosts/active`: the lives in a paid slot now (at most `slots`), first started first. */
  async active(callerId: string | null, lang: ContentLanguage): Promise<{ data: LiveBoostedRoomDto[] }> {
    const now = this.clock.now();
    const running = await this.prisma.liveBoost.findMany({
      where: { cancelledAt: null, startsAt: { lte: now }, endsAt: { gt: now } },
      orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
      take: this.slots,
      select: { roomId: true, endsAt: true },
    });
    const summaries = await this.rooms.liveSummaries(
      running.map((b) => b.roomId),
      callerId,
      lang,
    );
    return {
      data: running.flatMap((b) => {
        const room = summaries.get(b.roomId);
        return room ? [{ room, endsAt: b.endsAt.toISOString() }] : [];
      }),
    };
  }

  /**
   * `POST /live/rooms/{roomId}/boosts`. Checks after the auth guard and the route's bucket: visible
   * room (404), LIVE (409 LIVE_ROOM_ENDED), the body (400), a retry with the same `clientId` → 200 the
   * first card (nothing charged again), then in one transaction under the plan lock: the live has no
   * card running or waiting (409 BOOST_ROOM_BUSY), the card starts within the wait limit (409
   * BOOST_QUEUE_FULL), the charge (409 INSUFFICIENT_COINS, or 409 BOOST_CARD_INSUFFICIENT for CARD).
   * After the commit: a `boost` data message to the room (best effort).
   */
  async buy(
    callerId: string,
    roomId: string,
    body: unknown,
  ): Promise<{ created: boolean; result: LiveBoostResultDto }> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const prices = this.config.boosts.prices;
    const parsed = buySchema(prices.map((p) => p.minutes)).safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const clientId = input.clientId.toLowerCase();
    const replay = async (): Promise<{ created: boolean; result: LiveBoostResultDto } | null> => {
      const first = await this.prisma.liveBoost.findUnique({
        where: { buyerId_clientId: { buyerId: callerId, clientId } },
        include: BOOST_INCLUDE,
      });
      if (!first) return null;
      return { created: false, result: await this.resultOf(callerId, first) };
    };
    const again = await replay();
    if (again) return again;

    const price = prices.find((p) => p.minutes === input.minutes)!;
    const isCoins = input.source === 'COINS';
    let created: BoostRow;
    try {
      created = await this.prisma.$transaction(async (tx) => {
        await setLiveStatementTimeout(tx);
        const now = this.clock.now();
        const open = await this.settleIn(tx, now);
        const [room] = await tx.$queryRaw<{ status: string }[]>`
          SELECT status::text AS status FROM live_rooms WHERE id = ${row.id}::uuid FOR SHARE`;
        if (room?.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
        if (open.some((b) => b.roomId === row.id)) throw new AppException(ErrorCode.BOOST_ROOM_BUSY);
        const place = placeBoost(slotsFreeAt(now, this.slots, open), input.minutes);
        if (place.startsAt.getTime() - now.getTime() > this.config.boosts.maxWaitMs) {
          throw new AppException(ErrorCode.BOOST_QUEUE_FULL);
        }
        const id = uuidv7();
        if (isCoins) {
          const debit = await debitIn(tx, callerId, BigInt(price.coins), 'LIVE_BOOST', id);
          if (!debit) throw new AppException(ErrorCode.INSUFFICIENT_COINS);
        } else {
          const [left] = await tx.$queryRaw<{ quantity: number }[]>`
            UPDATE live_boost_cards SET quantity = quantity - 1, updated_at = now()
             WHERE user_id = ${callerId}::uuid AND minutes = ${input.minutes} AND quantity >= 1
            RETURNING quantity`;
          if (!left) throw new AppException(ErrorCode.BOOST_CARD_INSUFFICIENT);
        }
        return tx.liveBoost.create({
          data: {
            id,
            roomId: row.id,
            hostUserId: row.host_user_id,
            buyerId: callerId,
            clientId,
            minutes: input.minutes,
            source: input.source,
            coinsCharged: isCoins ? BigInt(price.coins) : 0n,
            slot: place.slot,
            startsAt: place.startsAt,
            endsAt: place.endsAt,
            createdAt: now,
          },
          include: BOOST_INCLUDE,
        });
      }, LIVE_TX_OPTIONS);
    } catch (err) {
      if (violatedUniqueIndex(err) !== null) {
        const raced = await replay();
        if (raced) return raced;
      }
      throw err;
    }
    const result = await this.resultOf(callerId, created);
    try {
      await this.media.broadcastData(
        row.id,
        BOOST_TOPIC,
        JSON.stringify({ type: 'boost', boost: result.boost }),
      );
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a boost data message to the media room');
    }
    return { created: true, result };
  }

  private async resultOf(callerId: string, row: BoostRow): Promise<LiveBoostResultDto> {
    const now = this.clock.now();
    return {
      boost: this.toDto(row, now),
      coins: (await this.wallet.mine(callerId)).coins,
      cards: await this.cardsOf(this.prisma, callerId),
    };
  }

  /** `GET /live/rooms/{roomId}/boosts`: the room's cards running or waiting, then the last 10 others. */
  async roomBoosts(callerId: string, roomId: string): Promise<{ data: LiveBoostDto[] }> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    const now = this.clock.now();
    const rows = await this.prisma.liveBoost.findMany({
      where: { roomId: row.id },
      orderBy: [{ startsAt: 'desc' }, { id: 'desc' }],
      take: 12,
      include: BOOST_INCLUDE,
    });
    return { data: rows.map((r) => this.toDto(r, now)) };
  }
}
