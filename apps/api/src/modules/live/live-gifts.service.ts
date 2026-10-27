import { Inject, Injectable, Logger } from '@nestjs/common';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { LevelCategoryCode, LiveGiftSource, Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { creditFamilyForSpendIn } from '../families/family-points.js';
import { consumeStockIn, stockOf } from '../gifts/gift-catalogue.js';
import { giftArtDto, GiftsService, LIVE_GIFT_COMBO_WINDOW_SECONDS } from '../gifts/gifts.service.js';
import { LuckyGiftsService, type LuckyRegionInput } from '../gifts/lucky-gifts.service.js';
import {
  budgetLeft,
  capWins,
  luckyResultDto,
  shareOf,
  type AuditedWin,
  type LuckyGiftResultDto,
} from '../gifts/lucky-odds.js';
import { isAvailable, loadCategory, type LoadedCategory } from '../levels/level-catalog.js';
import { LevelProgressService } from '../levels/level-progress.service.js';
import { qualify, type Credit } from '../levels/level-qualification.js';
import { pointsFor } from '../levels/points-math.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import { WalletService } from '../wallet/wallet.service.js';
import {
  comboFor,
  giftAmounts,
  LIVE_GIFT_TOPIC,
  LUCKY_WIN_TOPIC,
  recipientsKey,
  type PreviousSend,
} from './live-gifts.js';
import { LiveRoomMetadataService } from './live-metadata.service.js';
import {
  LiveRoomsService,
  LIVE_TX_OPTIONS,
  setLiveStatementTimeout,
  type UserSummaryDto,
} from './live-rooms.service.js';
import { POINTS_PER_SUPPORT_COIN } from './live-taps.js';
import { liveGiftSendSchema } from './live.schemas.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

// ---- Response shapes (openapi v1.23-live, CP-020) ----------------------------------------------

/** `LiveGiftCombo`. */
export interface LiveGiftComboDto {
  /** The first send of the combo (equal to the gift id when this send starts it). */
  id: string;
  /** 1 for the first send of a combo, then 2, 3 … */
  count: number;
  /** Gifts per recipient in the whole combo so far (this send included). */
  quantity: number;
}

/** `LiveGift`: one send, as the response and the `gift` data message carry it. */
export interface LiveGiftDto {
  id: string;
  roomId: string;
  giftCode: string;
  assetKey: string;
  animationKey: string | null;
  /** v1.26.2-live (D126): the gift's hosted art now (as in the catalogue). */
  imageUrl: string | null;
  animationUrl: string | null;
  animationBytes: number | null;
  /** The gift's price in coins when it was sent. */
  unitPrice: number;
  /** Gifts each recipient received. */
  quantity: number;
  source: LiveGiftSource;
  /** The send's coin value (unitPrice × quantity × recipients). */
  totalCoins: number;
  sender: UserSummaryDto;
  /** In the order the sender listed them. */
  recipients: UserSummaryDto[];
  combo: LiveGiftComboDto;
  createdAt: string;
}

/** `LiveGiftResult`: the send, the sender's coins and what the bag holds of that gift after it. */
export interface LiveGiftResultDto {
  gift: LiveGiftDto;
  coins: number;
  bagQuantity: number;
  /** v1.27-live (D132): only for a LUCKY gift. */
  luckyResult?: LuckyGiftResultDto;
}

/** The `win` of a `lucky-win` data message (v1.27-live, D132, CONVENTIONS §10.27). */
export interface LuckyWinDto {
  giftId: string;
  roomId: string;
  giftCode: string;
  sender: UserSummaryDto;
  multiplier: number;
  coinsWon: number;
  createdAt: string;
}

/** The data message of topic `lucky`. */
export interface LuckyWinData {
  readonly type: 'lucky-win';
  readonly win: LuckyWinDto;
}

/** The data message of topic `gift`. */
export interface LiveGiftData {
  readonly type: 'gift';
  readonly gift: LiveGiftDto;
}

const GIFT_INCLUDE = {
  sender: { select: USER_SUMMARY_SELECT },
  gift: {
    select: {
      assetKey: true,
      animationKey: true,
      imageObjectKey: true,
      animationObjectKey: true,
      animationBytes: true,
    },
  },
  recipients: { orderBy: { position: 'asc' }, include: { user: { select: USER_SUMMARY_SELECT } } },
  // v1.27-live (D132): a lucky send's draws (a retry answers with the same result).
  luckyDraw: { select: { draws: true, wins: true, unitPrice: true, downgraded: true } },
} as const satisfies Prisma.LiveGiftInclude;
type GiftRow = Prisma.LiveGiftGetPayload<{ include: typeof GIFT_INCLUDE }>;

function toDto(row: GiftRow, originRoomId: string, publicBaseUrl: string | undefined): LiveGiftDto {
  return {
    id: row.id,
    roomId: row.roomId ?? originRoomId,
    giftCode: row.giftCode,
    assetKey: row.gift.assetKey,
    animationKey: row.gift.animationKey,
    ...giftArtDto(row.gift, publicBaseUrl),
    unitPrice: row.unitPrice,
    quantity: row.quantity,
    source: row.source,
    totalCoins: Number(row.totalCoins),
    sender: userSummary(row.sender),
    recipients: row.recipients.map((r) => userSummary(r.user)),
    combo: { id: row.comboId, count: row.comboCount, quantity: Number(row.comboQuantity) },
    createdAt: row.createdAt.toISOString(),
  };
}

interface Recipient {
  readonly id: string;
  readonly username: string;
}

/**
 * Live gifts (CP-020, D108, CONVENTIONS §10.23): a signed-in person in a LIVE room sends
 * `quantity` of one catalogue gift to each of 1 … 25 recipients — the host and/or people seated in
 * that room — paid with coins (one wallet debit, ledger `LIVE_GIFT`, counted for the sender's
 * family) or from their gift bag. In the same transaction: the room score and the host's
 * popularity points (100 a coin), the sender's Contribution points in this live (100 a coin), the
 * recipients' charm and the sender's support levels (CP-005 rules, `GIFT_RECEIVED` / `GIFT_SENT`).
 * After the commit: a `gift` data message to the room, the score metadata, and the room info
 * version when the host's charm level moved (§10.18). A retry with the same `clientId` is never
 * charged or sent again.
 */
@Injectable()
export class LiveGiftsService {
  private readonly logger = new Logger(LiveGiftsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly gifts: GiftsService,
    private readonly wallet: WalletService,
    private readonly levels: LevelProgressService,
    private readonly metadata: LiveRoomMetadataService,
    private readonly clock: Clock,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    private readonly background: BackgroundTasks,
    private readonly lucky: LuckyGiftsService,
  ) {}

  /** v1.27-live (D132): the lucky-gift region facts of a request (the edge's country header). */
  regionOf(headers: Readonly<Record<string, string | string[] | undefined>>): LuckyRegionInput {
    return this.lucky.regionOf(headers);
  }

  /** In the room now: a row in the room's media session (CP-010 `live_room_viewers`). */
  private async inMediaSession(roomId: string, userId: string): Promise<boolean> {
    return (await this.prisma.liveRoomViewer.count({ where: { roomId, userId } })) > 0;
  }

  /**
   * `POST /live/rooms/{roomId}/gifts`. Checks after the auth guard and the rate limit (§10.23):
   * visible room (404; a block with the host too), LIVE (409 LIVE_ROOM_ENDED), the body (400), a
   * retry with the same `clientId` by the same sender → the first send with the current balance
   * and bag quantity (`created` false), not kicked out of this live (403 LIVE_KICKED), in the room
   * (403 LIVE_CHAT_NOT_IN_ROOM; the host always is), an enabled catalogue gift (409
   * GIFT_UNAVAILABLE), every recipient the host or seated now, ACTIVE and without a block either way
   * with the sender (409 LIVE_GIFT_RECIPIENT_UNAVAILABLE; D128: the caller may be a recipient when
   * they are the host or seated), then the charge: 409 INSUFFICIENT_COINS (COINS) or 409
   * GIFT_BAG_INSUFFICIENT (BAG), nothing stored, charged or sent.
   */
  async send(
    callerId: string,
    roomId: string,
    body: unknown,
    region: LuckyRegionInput = { edgeCountry: undefined },
  ): Promise<{ created: boolean; result: LiveGiftResultDto }> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const parsed = liveGiftSendSchema(this.gifts.quantities).safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const clientId = input.clientId.toLowerCase();

    const first = await this.byClientId(callerId, clientId);
    if (first) return { created: false, result: await this.replay(callerId, first, row.id) };

    if (callerId !== row.host_user_id) {
      if (row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
      if (!(await this.inMediaSession(row.id, callerId))) {
        throw new AppException(ErrorCode.LIVE_CHAT_NOT_IN_ROOM);
      }
    }

    // D128 (owner): the caller may be among the recipients — the host, or someone seated, gifting
    // themself; a viewer who is not seated is refused below like any recipient who is not seated.
    const recipients = await this.resolveRecipients(input.recipients);
    const gift = await this.prisma.gift.findUnique({ where: { code: input.giftCode } });
    if (!gift?.enabled) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
    // v1.27-live (D132, §10.27): a lucky gift — on, paid with coins, the caller's region and 18+.
    const isLucky = gift.category === 'LUCKY';
    if (isLucky) {
      if (!this.lucky.enabled) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
      if (input.source !== 'COINS')
        throw AppException.validation([{ field: 'source', issue: 'invalid_value' }]);
      await this.lucky.assertMaySend(callerId, region);
    }
    if (recipients.some((r) => r === null)) {
      throw new AppException(ErrorCode.LIVE_GIFT_RECIPIENT_UNAVAILABLE);
    }
    const to = recipients as Recipient[];
    await this.assertNoBlocks(callerId, to);

    const now = this.clock.now();
    const at = now.toISOString();
    const giftId = uuidv7();
    const key = recipientsKey(to.map((r) => r.id));
    // The draws are made before the transaction (CSPRNG, pure) and committed only with this send:
    // a refused or raced send discards them, a retry reads the stored ones and never draws again.
    const draws = input.quantity * to.length;
    const winners = isLucky ? this.lucky.draw(draws) : null;
    const table = this.lucky.table;
    let created: {
      row: GiftRow;
      coins: number | null;
      bagQuantity: number | null;
      hostLevelChanged: boolean;
      luckyResult: LuckyGiftResultDto | null;
    };
    try {
      created = await this.prisma.$transaction(async (tx) => {
        await setLiveStatementTimeout(tx);
        // One send of this sender at a time (their combo follows the previous send).
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`live-gift:${callerId}`}, 0))`;
        // The room row first, like taps (§10.10): sends and tap batches of a room are serialized.
        const [room] = await tx.$queryRaw<{ host_user_id: string; status: string }[]>`
          SELECT host_user_id::text AS host_user_id, status::text AS status
            FROM live_rooms WHERE id = ${row.id}::uuid
             FOR NO KEY UPDATE`;
        if (!room) throw new AppException(ErrorCode.NOT_FOUND);
        if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
        await this.assertRecipientsInRoom(tx, row.id, room.host_user_id, to);
        const [current] = await tx.$queryRaw<{ price_coins: number; enabled: boolean; category: string }[]>`
          SELECT price_coins, enabled, category::text AS category FROM gifts WHERE code = ${gift.code} FOR SHARE`;
        if (!current?.enabled) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
        // The category was checked before the transaction (lucky gates); a change since → refused.
        if ((current.category === 'LUCKY') !== isLucky) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
        const amounts = giftAmounts(current.price_coins, input.quantity, to.length);
        // v1.27-live (D132): a lucky gift counts its host share (10 %) for everyone but the sender's
        // Wizard level (CP-005: the value of lucky gifts sent).
        const shareBps = isLucky ? table.hostShareBps : 10_000;
        // The counted coins C = floor(value × share); every score is 100 × C (§10.10, and the
        // Contribution row's CHECK points = taps + 100 × support coins).
        const countedCoins = shareOf(amounts.totalCoins, shareBps);
        const counted = {
          scorePoints: countedCoins * POINTS_PER_SUPPORT_COIN,
          supportCoins: countedCoins,
          perRecipientCoins: shareOf(amounts.perRecipientCoins, shareBps),
        };

        const [previous] = await tx.$queryRaw<
          {
            gift_code: string;
            recipients_key: string;
            combo_id: string;
            combo_count: number;
            combo_quantity: bigint;
            created_at: Date;
          }[]
        >`
          SELECT gift_code, recipients_key, combo_id::text AS combo_id, combo_count, combo_quantity, created_at
            FROM live_gifts
           WHERE sender_id = ${callerId}::uuid AND room_id = ${row.id}::uuid
           ORDER BY created_at DESC, id DESC
           LIMIT 1`;
        const prev: PreviousSend | null = previous
          ? {
              giftCode: previous.gift_code,
              recipientsKey: previous.recipients_key,
              comboId: previous.combo_id,
              comboCount: previous.combo_count,
              comboQuantity: previous.combo_quantity,
              createdAt: previous.created_at,
            }
          : null;
        const combo = comboFor(
          prev,
          { id: giftId, giftCode: gift.code, recipientsKey: key, quantity: input.quantity },
          now,
          LIVE_GIFT_COMBO_WINDOW_SECONDS * 1000,
        );

        await tx.liveGift.create({
          data: {
            id: giftId,
            senderId: callerId,
            clientId,
            roomId: row.id,
            giftCode: gift.code,
            quantity: input.quantity,
            source: input.source,
            unitPrice: current.price_coins,
            totalCoins: BigInt(amounts.totalCoins),
            coinsCharged: input.source === 'COINS' ? BigInt(amounts.totalCoins) : 0n,
            recipientsKey: key,
            comboId: combo.id,
            comboCount: combo.count,
            comboQuantity: combo.quantity,
            createdAt: now,
          },
        });
        await tx.liveGiftRecipient.createMany({
          data: to.map((r, i) => ({
            giftId,
            userId: r.id,
            position: i,
            coins: BigInt(amounts.perRecipientCoins),
          })),
        });

        // The charge.
        let coins: number | null = null;
        let bagQuantity: number | null = null;
        let luckyResult: LuckyGiftResultDto | null = null;
        if (isLucky) {
          const charged = await this.wallet.debitIn(tx, callerId, amounts.totalCoins, 'LUCKY_GIFT', giftId);
          if (!charged) throw new AppException(ErrorCode.INSUFFICIENT_COINS);
          coins = Number(charged.coins);
          // Family points: the host share of the charge (not the full price like LIVE_GIFT).
          await creditFamilyForSpendIn(tx, callerId, charged.ledgerId, BigInt(counted.supportCoins));
          const lucky = await this.settleLucky(tx, {
            giftId,
            senderId: callerId,
            giftCode: gift.code,
            unitPrice: current.price_coins,
            quantity: input.quantity,
            recipients: to.length,
            totalCoins: amounts.totalCoins,
            winners: winners ?? [],
            now,
          });
          if (lucky.coins !== null) coins = lucky.coins;
          luckyResult = lucky.result;
        } else if (input.source === 'COINS') {
          const charged = await this.wallet.debitIn(tx, callerId, amounts.totalCoins, 'LIVE_GIFT', giftId);
          if (!charged) throw new AppException(ErrorCode.INSUFFICIENT_COINS);
          coins = Number(charged.coins);
        } else {
          bagQuantity = await consumeStockIn(tx, callerId, gift.code, amounts.bagUnits);
          if (bagQuantity === null) throw new AppException(ErrorCode.GIFT_BAG_INSUFFICIENT);
        }

        // The live score, the host's popularity points and the sender's Contribution points.
        await tx.$executeRaw`
          INSERT INTO live_room_scores (room_id, tap_points, support_points, updated_at)
          VALUES (${row.id}::uuid, 0, ${counted.scorePoints}, ${at}::timestamptz)
          ON CONFLICT (room_id) DO UPDATE
             SET support_points = live_room_scores.support_points + EXCLUDED.support_points,
                 updated_at = EXCLUDED.updated_at`;
        await tx.$executeRaw`
          UPDATE live_rooms SET score = score + ${counted.scorePoints} WHERE id = ${row.id}::uuid`;
        await tx.$executeRaw`
          INSERT INTO live_host_points_hourly (host_user_id, hour_start, points)
          VALUES (${room.host_user_id}::uuid, date_trunc('hour', ${at}::timestamptz), ${counted.scorePoints})
          ON CONFLICT (host_user_id, hour_start) DO UPDATE
             SET points = live_host_points_hourly.points + EXCLUDED.points`;
        await tx.$executeRaw`
          INSERT INTO live_room_tappers (room_id, user_id, counted, last_batch_at, support_coins, points, points_at)
          VALUES (${row.id}::uuid, ${callerId}::uuid, 0, NULL, ${counted.supportCoins}, ${counted.scorePoints},
                  ${at}::timestamptz)
          ON CONFLICT (room_id, user_id) DO UPDATE
             SET support_coins = live_room_tappers.support_coins + EXCLUDED.support_coins,
                 points = live_room_tappers.points + EXCLUDED.points,
                 points_at = EXCLUDED.points_at`;

        // Levels: the recipients' charm and the sender's support.
        const hostLevelChanged = await this.creditLevels(tx, {
          giftId,
          senderId: callerId,
          hostId: room.host_user_id,
          recipients: to,
          perRecipientCoins: amounts.perRecipientCoins,
          lucky: isLucky,
          countedPerRecipientCoins: counted.perRecipientCoins,
        });
        if (hostLevelChanged) {
          await tx.$executeRaw`
            UPDATE live_rooms SET info_version = info_version + 1, updated_at = now()
             WHERE id = ${row.id}::uuid`;
        }

        const stored = await tx.liveGift.findUniqueOrThrow({ where: { id: giftId }, include: GIFT_INCLUDE });
        return { row: stored, coins, bagQuantity, hostLevelChanged, luckyResult };
      }, LIVE_TX_OPTIONS);
    } catch (err) {
      // A concurrent request with the same clientId won: answer with its send.
      if (violatedUniqueIndex(err) !== null) {
        const raced = await this.byClientId(callerId, clientId);
        if (raced) return { created: false, result: await this.replay(callerId, raced, row.id) };
      }
      throw err;
    }

    const dto = toDto(created.row, row.id, this.gifts.publicBaseUrl);
    this.background.run('live gift data message', async () => {
      await this.broadcast(row.id, { type: 'gift', gift: dto });
    });
    const luckyResult = created.luckyResult;
    if (
      luckyResult &&
      luckyResult.topMultiplier !== null &&
      luckyResult.topMultiplier >= this.lucky.bigWinMultiplier
    ) {
      const win: LuckyWinDto = {
        giftId: dto.id,
        roomId: dto.roomId,
        giftCode: dto.giftCode,
        sender: dto.sender,
        multiplier: luckyResult.topMultiplier,
        coinsWon: luckyResult.coinsWon,
        createdAt: dto.createdAt,
      };
      this.background.run('lucky win data message', async () => {
        await this.broadcastLuckyWin(row.id, { type: 'lucky-win', win });
      });
    }
    await this.metadata.scoreChanged(row.id);
    if (created.hostLevelChanged) await this.metadata.infoChanged(row.id);
    return {
      created: true,
      result: {
        gift: dto,
        coins: created.coins ?? (await this.wallet.mine(callerId)).coins,
        bagQuantity: created.bagQuantity ?? (await stockOf(this.prisma, callerId, dto.giftCode)),
        ...(luckyResult ? { luckyResult } : {}),
      },
    };
  }

  /**
   * v1.27-live (D132, §10.27), inside the send's transaction after the charge: adds the send to the
   * day's lucky spend (locking the day row: lucky sends are serialized per day), pays the winning
   * draws that fit in the day's budget (`floor(spend × RTP) − paid`; a draw that does not fit pays
   * the largest smaller multiplier that fits, or nothing), credits the coins won
   * (`LUCKY_GIFT_WIN`) and writes the audit row of the draws. Returns the balance after the win
   * (null: nothing won) and the response's `luckyResult`.
   */
  private async settleLucky(
    tx: Prisma.TransactionClient,
    send: {
      giftId: string;
      senderId: string;
      giftCode: string;
      unitPrice: number;
      quantity: number;
      recipients: number;
      totalCoins: number;
      winners: readonly (readonly [number, number])[];
      now: Date;
    },
  ): Promise<{ coins: number | null; result: LuckyGiftResultDto }> {
    const table = this.lucky.table;
    const draws = send.quantity * send.recipients;
    const day = this.lucky.dayOf(send.now);
    const at = send.now.toISOString();
    const [dayRow] = await tx.$queryRaw<{ spend_coins: bigint; paid_coins: bigint }[]>`
      INSERT INTO lucky_gift_days (day, spend_coins, paid_coins, sends, draws, updated_at)
      VALUES (${day}::date, ${send.totalCoins}, 0, 1, ${draws}, ${at}::timestamptz)
      ON CONFLICT (day) DO UPDATE
         SET spend_coins = lucky_gift_days.spend_coins + EXCLUDED.spend_coins,
             sends = lucky_gift_days.sends + 1,
             draws = lucky_gift_days.draws + EXCLUDED.draws,
             updated_at = EXCLUDED.updated_at
      RETURNING spend_coins, paid_coins`;
    const budgetBefore = budgetLeft(dayRow!.spend_coins, dayRow!.paid_coins, table.rtpBps);
    const capped = capWins(
      send.winners,
      send.unitPrice,
      table.outcomes.map((o) => o.multiplier),
      budgetBefore,
    );
    let coins: number | null = null;
    if (capped.coinsWon > 0n) {
      await tx.$executeRaw`
        UPDATE lucky_gift_days SET paid_coins = paid_coins + ${capped.coinsWon} WHERE day = ${day}::date`;
      const credited = await this.wallet.creditIn(
        tx,
        send.senderId,
        Number(capped.coinsWon),
        'LUCKY_GIFT_WIN',
        send.giftId,
      );
      coins = Number(credited.coins);
    }
    const result = luckyResultDto(draws, capped.wins, send.unitPrice, capped.downgraded);
    await tx.luckyGiftDraw.create({
      data: {
        giftId: send.giftId,
        senderId: send.senderId,
        giftCode: send.giftCode,
        unitPrice: send.unitPrice,
        quantity: send.quantity,
        recipients: send.recipients,
        draws,
        odds: {
          rtpBps: table.rtpBps,
          hostShareBps: table.hostShareBps,
          outcomes: table.outcomes.map((o) => [o.multiplier, o.chancePerMillion]),
        },
        wins: capped.wins,
        coinsWon: capped.coinsWon,
        topMultiplier: result.topMultiplier,
        downgraded: capped.downgraded,
        budgetDay: new Date(`${day}T00:00:00.000Z`),
        budgetBefore,
        budgetAfter: capped.budgetAfter,
        spendAfter: dayRow!.spend_coins,
        createdAt: send.now,
      },
    });
    return { coins, result };
  }

  /** The `lucky-win` data message to the room (best effort, like every data message). */
  private async broadcastLuckyWin(roomId: string, data: LuckyWinData): Promise<void> {
    try {
      await this.media.broadcastData(roomId, LUCKY_WIN_TOPIC, JSON.stringify(data));
    } catch (err) {
      this.logger.warn(
        { error: safeErrorLog(err) },
        'Could not send a lucky win data message to the media room',
      );
    }
  }

  /** The users named (ACTIVE), in request order; null where nobody ACTIVE has that username. */
  private async resolveRecipients(usernames: readonly string[]): Promise<(Recipient | null)[]> {
    const profiles = await this.prisma.userProfile.findMany({
      where: { username: { in: [...usernames] }, user: { status: 'ACTIVE' } },
      select: { userId: true, username: true },
    });
    const byName = new Map(profiles.map((p) => [p.username, { id: p.userId, username: p.username }]));
    return usernames.map((name) => byName.get(name) ?? null);
  }

  /** 409 when a recipient blocked the sender or the sender blocked a recipient. */
  private async assertNoBlocks(senderId: string, to: readonly Recipient[]): Promise<void> {
    const ids = to.map((r) => r.id);
    const blocks = await this.prisma.userBlock.count({
      where: {
        OR: [
          { blockerId: senderId, blockedId: { in: ids } },
          { blockerId: { in: ids }, blockedId: senderId },
        ],
      },
    });
    if (blocks > 0) throw new AppException(ErrorCode.LIVE_GIFT_RECIPIENT_UNAVAILABLE);
  }

  /** 409 unless every recipient is the host or seated in the room now (inside the send's transaction). */
  private async assertRecipientsInRoom(
    tx: Prisma.TransactionClient,
    roomId: string,
    hostId: string,
    to: readonly Recipient[],
  ): Promise<void> {
    const others = to.filter((r) => r.id !== hostId).map((r) => r.id);
    if (others.length === 0) return;
    const seated = await tx.liveRoomSeat.count({ where: { roomId, userId: { in: others } } });
    if (seated !== others.length) throw new AppException(ErrorCode.LIVE_GIFT_RECIPIENT_UNAVAILABLE);
  }

  /**
   * The CP-005 credits of the send (§10.18, §10.23), in the send's transaction: for each recipient
   * a normal gift worth `perRecipientCoins` coins ({@link qualify}: charm `ATTRACTIVENESS` for the
   * recipient as `GIFT_RECEIVED`, support `SUPPORT` for the sender as `GIFT_SENT`; D128: both for
   * the caller when they gift themself); points =
   * floor(coins × the category's published multiplier). The source id is
   * `gift:<giftId>:<recipientId>`, so nothing is credited twice. User states are locked in a fixed
   * (user, category) order, after the room row, like the levels inbox. Nothing is credited while a
   * category is unavailable (or not seeded). Returns whether the host's charm level moved.
   */
  private async creditLevels(
    tx: Prisma.TransactionClient,
    send: {
      giftId: string;
      senderId: string;
      hostId: string;
      recipients: readonly Recipient[];
      perRecipientCoins: number;
      /** v1.27-live (D132): a LUCKY gift (Wizard for the sender; the host share for the rest). */
      lucky: boolean;
      /** The value counted for charm (and support, when switched on): the host share for lucky gifts. */
      countedPerRecipientCoins: number;
    },
  ): Promise<boolean> {
    const loaded = new Map<LevelCategoryCode, LoadedCategory | null>();
    const category = async (code: LevelCategoryCode): Promise<LoadedCategory | null> => {
      if (loaded.has(code)) return loaded.get(code) ?? null;
      const seeded = await tx.levelCategory.findUnique({ where: { code }, select: { id: true } });
      const value = seeded ? await loadCategory(tx, code, 'share') : null;
      loaded.set(code, value);
      return value;
    };
    // CP-005: lucky gifts count for the sender's Support only when the published SUPPORT version says.
    let luckyGiftsCountAsSupport = false;
    if (send.lucky) {
      const support = await category('SUPPORT');
      luckyGiftsCountAsSupport =
        support !== null && isAvailable(support) && support.version.luckyGiftsCountAsSupport;
    }

    const credits: (Credit & { source: string })[] = [];
    for (const r of send.recipients) {
      const result = qualify(
        {
          type: 'GIFT_COMMITTED',
          sourceTransactionId: `gift:${send.giftId}:${r.id}`,
          senderUserId: send.senderId,
          recipientUserId: r.id,
          value: BigInt(send.perRecipientCoins),
          lucky: send.lucky,
        },
        // D128: a gift to oneself (host or seated) earns like any gift.
        { luckyGiftsCountAsSupport, selfGiftsEarn: true },
      );
      if (typeof result === 'string') continue;
      for (const credit of result) {
        // v1.27-live (D132): Wizard counts the full value sent; charm and support the host share.
        const value = credit.category === 'WIZARD' ? credit.value : BigInt(send.countedPerRecipientCoins);
        if (value <= 0n) continue;
        credits.push({ ...credit, value, source: `gift:${send.giftId}:${r.id}` });
      }
    }
    credits.sort((a, b) =>
      a.userId === b.userId
        ? a.category.localeCompare(b.category) || a.source.localeCompare(b.source)
        : a.userId.localeCompare(b.userId),
    );

    let hostLevelChanged = false;
    for (const credit of credits) {
      const cat = await category(credit.category);
      if (!cat || !isAvailable(cat)) continue;
      const points = pointsFor(credit.value, cat.version.multiplier);
      if (points === 0n) continue;
      const result = await this.levels.apply(tx, cat, {
        userId: credit.userId,
        entryType: 'EARN',
        sourceType: credit.sourceType,
        pointsDelta: points,
        sourceTransactionId: credit.source,
        sourceValue: credit.value,
        multiplierUsed: cat.version.multiplier,
      });
      if (
        result.kind === 'applied' &&
        credit.category === 'ATTRACTIVENESS' &&
        credit.userId === send.hostId &&
        result.state.currentLevel !== result.state.previousLevel
      ) {
        hostLevelChanged = true;
      }
    }
    return hostLevelChanged;
  }

  private byClientId(senderId: string, clientId: string): Promise<GiftRow | null> {
    return this.prisma.liveGift.findUnique({
      where: { senderId_clientId: { senderId, clientId } },
      include: GIFT_INCLUDE,
    });
  }

  private async replay(userId: string, row: GiftRow, roomId: string): Promise<LiveGiftResultDto> {
    const draw = row.luckyDraw;
    return {
      gift: toDto(row, roomId, this.gifts.publicBaseUrl),
      coins: (await this.wallet.mine(userId)).coins,
      bagQuantity: await stockOf(this.prisma, userId, row.giftCode),
      // v1.27-live (D132): the stored draws, never new ones.
      ...(draw
        ? {
            luckyResult: luckyResultDto(
              draw.draws,
              draw.wins as AuditedWin[],
              draw.unitPrice,
              draw.downgraded,
            ),
          }
        : {}),
    };
  }

  /** Sends the gift to everyone in the media room (best effort, like every data message). */
  private async broadcast(roomId: string, data: LiveGiftData): Promise<void> {
    try {
      await this.media.broadcastData(roomId, LIVE_GIFT_TOPIC, JSON.stringify(data));
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a gift data message to the media room');
    }
  }
}
