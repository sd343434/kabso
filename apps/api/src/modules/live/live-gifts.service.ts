import { Inject, Injectable, Logger } from '@nestjs/common';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { LevelCategoryCode, LiveGiftSource, Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { familyLevelFor } from '../families/families.constants.js';
import { consumeStockIn, stockOf } from '../gifts/gift-catalogue.js';
import { giftArtDto, GiftsService, LIVE_GIFT_COMBO_WINDOW_SECONDS } from '../gifts/gifts.service.js';
import { LuckyGiftsService, type LuckyRegionInput } from '../gifts/lucky-gifts.service.js';
import {
  budgetLeft,
  luckyResultDto,
  settleDraws,
  shareOf,
  type AuditedWin,
  type LuckyGiftResultDto,
} from '../gifts/lucky-odds.js';
import { isAvailable, loadCategories, type LoadedCategory } from '../levels/level-catalog.js';
import { LevelProgressService } from '../levels/level-progress.service.js';
import { qualify, type Credit } from '../levels/level-qualification.js';
import { pointsFor } from '../levels/points-math.js';
import { creditGiftCherriesIn } from '../economy/cherry-ledger.js';
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
import { LiveGiftTickerService, type GiftTickerGiftDto } from './live-gift-ticker.service.js';
import { LiveLuckyTickerService, type LuckyWinDto } from './live-lucky-ticker.service.js';
import { LiveRoomMetadataService } from './live-metadata.service.js';
import {
  LiveRoomsService,
  LIVE_TX_OPTIONS,
  setLiveStatementTimeout,
  type UserSummaryDto,
} from './live-rooms.service.js';
import { POINTS_PER_SUPPORT_COIN } from './live-taps.js';
import { liveGiftSendSchema } from './live.schemas.js';
import { quipSlot } from '../gifts/quips.js';
import { LiveQuipsService, type LiveQuipDto } from './live-quips.service.js';
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
  /** v1.32-live (D154): only for a QUIPS gift — its place in the room's queue. */
  quip?: LiveQuipDto;
}

export type { LuckyWinDto } from './live-lucky-ticker.service.js';

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

/** What the first statement of a send reads under the sender's lock (D148). */
interface SendState {
  host_user_id: string;
  status: string;
  wish_gifts: string[];
  price_coins: number | null;
  enabled: boolean | null;
  category: string | null;
  seated: number;
  prev_gift_code: string | null;
  prev_recipients_key: string | null;
  prev_combo_id: string | null;
  prev_combo_count: number | null;
  prev_combo_quantity: bigint | null;
  prev_created_at: Date | null;
  family_id: string | null;
  replay: boolean | null;
  losses: number | null;
  quip_busy_until: Date | null;
  sound_key: string | null;
  sound_ms: number | null;
  quip_text: string | null;
}

/** A send with this clientId was stored while this one waited for the sender's lock. */
class ReplayRace extends Error {}

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
    private readonly limiter: RateLimitService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly ticker: LiveLuckyTickerService,
    private readonly giftTicker: LiveGiftTickerService,
    private readonly quips: LiveQuipsService,
  ) {}

  /** D148: the tail of each sender's queue of sends in this process. */
  private readonly senderQueues = new Map<string, Promise<void>>();

  /** Runs `task` after every earlier task of `senderId` in this process has settled (FIFO). */
  private async oneAtATime<T>(senderId: string, task: () => Promise<T>): Promise<T> {
    const before = this.senderQueues.get(senderId) ?? Promise.resolve();
    let done!: () => void;
    const tail = before.then(() => new Promise<void>((resolve) => (done = resolve)));
    this.senderQueues.set(senderId, tail);
    await before;
    try {
      return await task();
    } finally {
      done();
      if (this.senderQueues.get(senderId) === tail) this.senderQueues.delete(senderId);
    }
  }

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
    const { recipients, people } = await this.resolveRecipients(callerId, input.recipients);
    const gift = await this.prisma.gift.findUnique({ where: { code: input.giftCode } });
    if (!gift?.enabled) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
    // v1.27-live (D132, §10.27): a lucky gift — on, paid with coins, the caller's region and 18+.
    const isLucky = gift.category === 'LUCKY';
    // v1.32-live (D154, §10.33): a quip — paid with coins (or free), one at a time.
    const isQuip = gift.category === 'QUIPS';
    if (isQuip) {
      if (input.source !== 'COINS')
        throw AppException.validation([{ field: 'source', issue: 'invalid_value' }]);
      if (input.quantity !== 1)
        throw AppException.validation([{ field: 'quantity', issue: 'invalid_value' }]);
    }
    // D145c (§7): a lucky streak (MAX X) has its own burst limit; normal gifts keep theirs. A retry
    // with the same clientId was answered above and is not counted here.
    await this.limiter.consume(
      isLucky ? 'live:gift:lucky' : 'live:gift',
      callerId,
      isLucky ? this.config.rateLimits.liveLuckyGiftBurstUser : this.config.rateLimits.liveGiftUser,
    );
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

    const key = recipientsKey(to.map((r) => r.id));
    const toIds = to.map((r) => r.id);
    // The draws are made before the transaction (CSPRNG, pure) and committed only with this send:
    // a refused or raced send discards them, a retry reads the stored ones and never draws again.
    const draws = input.quantity * to.length;
    const winners = isLucky ? this.lucky.draw(draws) : null;
    const table = this.lucky.table;
    // v1.32-live (D154): the recipients' earnings share of this send, fixed now (§10.33).
    const hostShareBps =
      gift.category === 'LUCKY' ? table.hostShareBps : this.config.gifts.hostShareBps[gift.category];
    let created: {
      dto: LiveGiftDto;
      coins: number | null;
      bagQuantity: number | null;
      hostLevelChanged: boolean;
      luckyResult: LuckyGiftResultDto | null;
      quip: LiveQuipDto | null;
    };
    try {
      // D148: one transaction per sender at a time in this process too (FIFO), so a burst of one
      // sender's sends waits here instead of holding pool connections while it waits for the
      // sender's advisory lock (which still orders sends across API instances).
      created = await this.oneAtATime(callerId, () =>
        this.prisma.$transaction(async (tx) => {
          await setLiveStatementTimeout(tx);
          // One send of this sender at a time (their combo follows the previous send; D148: their
          // lucky streak too). Always the first lock of a send (before the room's), so two sends of one
          // sender never wait on each other in the other order.
          await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`live-gift:${callerId}`}, 0))`;
          // D145d (load check, 100 lucky sends a second): the time and the id are taken under the
          // sender's lock, so concurrent sends of one sender are stored in the order they ran and each
          // continues the combo of the one before (taken earlier, two could read the same previous).
          const now = this.clock.now();
          const at = now.toISOString();
          const giftId = uuidv7();
          const isCoins = input.source === 'COINS';
          // D148 (fewer round trips): one statement reads and locks what the send needs — the room row
          // first, like taps (§10.10: sends and tap batches of a room are serialized), then (LATERAL,
          // so after it) the gift FOR SHARE and the sender's family membership FOR SHARE (coins only);
          // the recipients seated now, the sender's previous send here (combo), a send already stored
          // with this clientId (the sender's lock makes this check exact), and the lucky streak.
          const [state] = await tx.$queryRaw<SendState[]>`
          SELECT r.host_user_id::text AS host_user_id, r.status::text AS status, r.wish_gifts,
                 g.price_coins, g.enabled, g.category::text AS category,
                 (SELECT count(*)::int FROM live_room_seats s
                   WHERE s.room_id = r.id AND s.user_id = ANY(${toIds}::uuid[])
                     AND s.user_id <> r.host_user_id) AS seated,
                 p.gift_code AS prev_gift_code, p.recipients_key AS prev_recipients_key,
                 p.combo_id::text AS prev_combo_id, p.combo_count AS prev_combo_count,
                 p.combo_quantity AS prev_combo_quantity, p.created_at AS prev_created_at,
                 fm.family_id::text AS family_id,
                 (SELECT true FROM live_gifts d
                   WHERE d.sender_id = ${callerId}::uuid AND d.client_id = ${clientId}::uuid) AS replay,
                 (SELECT losses FROM lucky_gift_pity WHERE user_id = ${callerId}::uuid) AS losses,
                 r.quip_busy_until, g.sound_key, g.sound_ms, g.quip_text
            FROM (SELECT id, host_user_id, status, wish_gifts, quip_busy_until FROM live_rooms
                   WHERE id = ${row.id}::uuid FOR NO KEY UPDATE) r
            LEFT JOIN LATERAL (SELECT price_coins, enabled, category, sound_key, sound_ms, quip_text FROM gifts
                                WHERE code = ${gift.code} AND r.id IS NOT NULL FOR SHARE) g ON true
            LEFT JOIN LATERAL (SELECT gift_code, recipients_key, combo_id, combo_count, combo_quantity, created_at
                                 FROM live_gifts
                                WHERE sender_id = ${callerId}::uuid AND room_id = r.id
                                ORDER BY created_at DESC, id DESC
                                LIMIT 1) p ON true
            LEFT JOIN LATERAL (SELECT family_id FROM family_members
                                WHERE user_id = ${callerId}::uuid AND ${isCoins} AND r.id IS NOT NULL
                                  FOR SHARE) fm ON true`;
          if (!state) throw new AppException(ErrorCode.NOT_FOUND);
          if (state.replay) throw new ReplayRace();
          if (state.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
          const others = toIds.filter((id) => id !== state.host_user_id);
          if (state.seated !== others.length)
            throw new AppException(ErrorCode.LIVE_GIFT_RECIPIENT_UNAVAILABLE);
          if (state.price_coins === null || !state.enabled)
            throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
          // The category was checked before the transaction (lucky gates); a change since → refused.
          if ((state.category === 'LUCKY') !== isLucky) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
          if ((state.category === 'QUIPS') !== isQuip) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
          const unitPrice = state.price_coins;
          // v1.32-live (D154, §10.33): a quip takes the next slot of the room's one queue (the room row
          // is locked); a free one (price 0) is the sender's one free quip of this live.
          const freeQuip = isQuip && unitPrice === 0;
          let slot: ReturnType<typeof quipSlot> = null;
          if (isQuip) {
            if (state.sound_key === null || state.sound_ms === null)
              throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
            slot = quipSlot(now, state.quip_busy_until, state.sound_ms, this.quips.maxWaitMs);
            if (!slot) throw new AppException(ErrorCode.QUIP_QUEUE_FULL);
          }
          const amounts = giftAmounts(unitPrice, input.quantity, to.length);
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
          const prev: PreviousSend | null =
            state.prev_combo_id !== null
              ? {
                  giftCode: state.prev_gift_code!,
                  recipientsKey: state.prev_recipients_key!,
                  comboId: state.prev_combo_id,
                  comboCount: state.prev_combo_count!,
                  comboQuantity: state.prev_combo_quantity!,
                  createdAt: state.prev_created_at!,
                }
              : null;
          const combo = comboFor(
            prev,
            { id: giftId, giftCode: gift.code, recipientsKey: key, quantity: input.quantity },
            now,
            LIVE_GIFT_COMBO_WINDOW_SECONDS * 1000,
          );
          // v1.27.3-live (D136): a wished gift to the host moves the wish list's received count, so
          // the room info version moves too (the metadata follows with the score's write).
          const wished = state.wish_gifts.includes(gift.code) && toIds.includes(state.host_user_id);

          // The bag (BAG): its own statement, refused before anything is written.
          let bagQuantity: number | null = null;
          if (!isCoins) {
            bagQuantity = await consumeStockIn(tx, callerId, gift.code, amounts.bagUnits);
            if (bagQuantity === null) throw new AppException(ErrorCode.GIFT_BAG_INSUFFICIENT);
          }
          // D148: the send's rows in one statement — the send and its recipients; the charge (COINS:
          // the wallet and its ledger row, then the family points: the full price for LIVE_GIFT, the
          // host share for LUCKY_GIFT); the live score, the host's popularity points, the sender's
          // Contribution points; the room's info version (a wished gift) and seats version (a seated
          // recipient's points moved, v1.27.2-live D135). A refused charge returns no balance and the
          // whole transaction is rolled back.
          // Ledger rows keep the wall-clock time of their write (as Prisma's default did), so a win
          // written later in the transaction sorts after its charge.
          const ledgerId = uuidv7();
          const familyCoins = isLucky ? counted.supportCoins : amounts.totalCoins;
          const family = isCoins && state.family_id !== null && familyCoins > 0 ? state.family_id : null;
          // A free quip charges nothing (no wallet row needed) and counts for nothing.
          const charged = isCoins && amounts.totalCoins > 0;
          const [written] = await tx.$queryRaw<
            {
              coins: bigint | null;
              family_points: bigint | null;
              family_level: number | null;
              free_quips: number;
            }[]
          >`
          WITH sent AS (
            INSERT INTO live_gifts (id, sender_id, client_id, room_id, gift_code, quantity, source, unit_price,
                                    total_coins, coins_charged, recipients_key, combo_id, combo_count,
                                    combo_quantity, host_share_bps, created_at)
            VALUES (${giftId}::uuid, ${callerId}::uuid, ${clientId}::uuid, ${row.id}::uuid, ${gift.code},
                    ${input.quantity}, ${input.source}::live_gift_source, ${unitPrice}, ${amounts.totalCoins},
                    ${isCoins ? amounts.totalCoins : 0}, ${key}, ${combo.id}::uuid, ${combo.count},
                    ${combo.quantity}, ${hostShareBps}, ${at}::timestamptz)
            RETURNING id),
          free_quip AS (
            INSERT INTO live_free_quips (room_id, user_id, gift_id, created_at)
            SELECT ${row.id}::uuid, ${callerId}::uuid, sent.id, ${at}::timestamptz FROM sent WHERE ${freeQuip}
            ON CONFLICT (room_id, user_id) DO NOTHING
            RETURNING 1),
          recipients AS (
            INSERT INTO live_gift_recipients (gift_id, user_id, position, coins)
            SELECT sent.id, t.user_id, (t.ord - 1)::smallint, ${amounts.perRecipientCoins}
              FROM sent, unnest(${toIds}::uuid[]) WITH ORDINALITY AS t(user_id, ord)
            RETURNING 1),
          debit AS (
            UPDATE wallets SET coins = coins - ${amounts.totalCoins}, updated_at = now()
             WHERE ${charged} AND user_id = ${callerId}::uuid AND coins >= ${amounts.totalCoins}
            RETURNING coins),
          ledger AS (
            INSERT INTO wallet_ledger (id, user_id, delta, balance_after, reason, reference_id, created_at)
            SELECT ${ledgerId}::uuid, ${callerId}::uuid, ${-amounts.totalCoins}, debit.coins,
                   ${isLucky ? 'LUCKY_GIFT' : 'LIVE_GIFT'}::wallet_ledger_reason, ${giftId},
                   ${new Date().toISOString()}::timestamptz
              FROM debit
            RETURNING id),
          family_entry AS (
            INSERT INTO family_points_ledger (id, family_id, user_id, wallet_ledger_id, points, created_at)
            SELECT ${uuidv7()}::uuid, ${family}::uuid, ${callerId}::uuid, ledger.id, ${familyCoins}, now()
              FROM ledger WHERE ${family}::uuid IS NOT NULL
            ON CONFLICT (wallet_ledger_id) DO NOTHING
            RETURNING family_id),
          family_member AS (
            UPDATE family_members SET points = points + ${familyCoins}
             WHERE user_id = ${callerId}::uuid AND EXISTS (SELECT 1 FROM family_entry)
            RETURNING 1),
          family_row AS (
            UPDATE families SET points = LEAST(points + ${familyCoins}, 9007199254740991), updated_at = now()
             WHERE id IN (SELECT family_id FROM family_entry)
            RETURNING points, level),
          score AS (
            INSERT INTO live_room_scores (room_id, tap_points, support_points, updated_at)
            SELECT ${row.id}::uuid, 0, ${counted.scorePoints}, ${at}::timestamptz WHERE NOT ${freeQuip}
            ON CONFLICT (room_id) DO UPDATE
               SET support_points = live_room_scores.support_points + EXCLUDED.support_points,
                   updated_at = EXCLUDED.updated_at
            RETURNING 1),
          room AS (
            UPDATE live_rooms
               SET score = score + ${counted.scorePoints},
                   info_version = info_version + ${wished ? 1 : 0},
                   updated_at = CASE WHEN ${wished} THEN now() ELSE updated_at END,
                   seats_version = seats_version + ${others.length > 0 && !freeQuip ? 1 : 0},
                   quip_busy_until = CASE WHEN ${slot !== null} THEN ${slot?.busyUntil.toISOString() ?? null}::timestamptz
                                          ELSE quip_busy_until END
             WHERE id = ${row.id}::uuid
            RETURNING 1),
          host_points AS (
            INSERT INTO live_host_points_hourly (host_user_id, hour_start, points)
            SELECT ${state.host_user_id}::uuid, date_trunc('hour', ${at}::timestamptz), ${counted.scorePoints}
             WHERE NOT ${freeQuip}
            ON CONFLICT (host_user_id, hour_start) DO UPDATE
               SET points = live_host_points_hourly.points + EXCLUDED.points
            RETURNING 1),
          tapper AS (
            INSERT INTO live_room_tappers (room_id, user_id, counted, last_batch_at, support_coins, points, points_at)
            SELECT ${row.id}::uuid, ${callerId}::uuid, 0, NULL, ${counted.supportCoins}, ${counted.scorePoints},
                   ${at}::timestamptz
             WHERE NOT ${freeQuip}
            ON CONFLICT (room_id, user_id) DO UPDATE
               SET support_coins = live_room_tappers.support_coins + EXCLUDED.support_coins,
                   points = live_room_tappers.points + EXCLUDED.points,
                   points_at = EXCLUDED.points_at
            RETURNING 1)
          SELECT (SELECT coins FROM debit) AS coins,
                 (SELECT points FROM family_row) AS family_points,
                 (SELECT level FROM family_row) AS family_level,
                 (SELECT count(*) FROM free_quip)::int AS free_quips,
                 (SELECT count(*) FROM recipients) + (SELECT count(*) FROM family_member)
                   + (SELECT count(*) FROM score) + (SELECT count(*) FROM room) + (SELECT count(*) FROM host_points)
                   + (SELECT count(*) FROM tapper) AS rows`;
          if (charged && (written?.coins ?? null) === null)
            throw new AppException(ErrorCode.INSUFFICIENT_COINS);
          // v1.32-live (D154): the sender's free quip of this live was already used → nothing is kept.
          if (freeQuip && written?.free_quips !== 1) throw new AppException(ErrorCode.QUIP_FREE_USED);
          let coins: number | null = charged ? Number(written!.coins) : null;
          if (written?.family_points !== null && written?.family_points !== undefined && family !== null) {
            const level = familyLevelFor(written.family_points);
            if (level !== written.family_level) {
              await tx.$executeRaw`UPDATE families SET level = ${level} WHERE id = ${family}::uuid`;
            }
          }

          // Levels: the recipients' charm and the sender's support (and Wizard for lucky gifts); a free
          // quip is worth nothing.
          const hostLevelChanged =
            !freeQuip &&
            (await this.creditLevels(tx, {
              giftId,
              senderId: callerId,
              hostId: state.host_user_id,
              recipients: to,
              perRecipientCoins: amounts.perRecipientCoins,
              lucky: isLucky,
              countedPerRecipientCoins: counted.perRecipientCoins,
            }));
          if (hostLevelChanged && !wished) {
            await tx.$executeRaw`
            UPDATE live_rooms SET info_version = info_version + 1, updated_at = now()
             WHERE id = ${row.id}::uuid`;
          }
          // v1.52-social (D179, §10.46): the recipients' cherries and their agencies' commissions, credited
          // now in the send's transaction (a free quip credits nothing).
          if (!freeQuip) await this.creditCherries(tx, giftId, now);

          // v1.27-live (D132, §10.27): the lucky settlement last, so the day row (locked by every lucky
          // send of the day) is held for as short a time as possible.
          let luckyResult: LuckyGiftResultDto | null = null;
          if (isLucky) {
            const lucky = await this.settleLucky(tx, {
              giftId,
              senderId: callerId,
              giftCode: gift.code,
              unitPrice,
              quantity: input.quantity,
              recipients: to.length,
              totalCoins: amounts.totalCoins,
              winners: winners ?? [],
              lossesBefore: state.losses ?? 0,
              now,
            });
            if (lucky.coins !== null) coins = lucky.coins;
            luckyResult = lucky.result;
          }

          const dto: LiveGiftDto = {
            id: giftId,
            roomId: row.id,
            giftCode: gift.code,
            assetKey: gift.assetKey,
            animationKey: gift.animationKey,
            ...giftArtDto(gift, this.gifts.publicBaseUrl),
            unitPrice,
            quantity: input.quantity,
            source: input.source,
            totalCoins: amounts.totalCoins,
            sender: people.get(callerId)!,
            recipients: toIds.map((id) => people.get(id)!),
            combo: { id: combo.id, count: combo.count, quantity: Number(combo.quantity) },
            createdAt: at,
          };
          const quip: LiveQuipDto | null =
            slot === null
              ? null
              : {
                  id: giftId,
                  roomId: row.id,
                  kind: 'GIFT',
                  giftCode: gift.code,
                  soundKey: state.sound_key!,
                  durationMs: state.sound_ms!,
                  text: state.quip_text,
                  free: freeQuip,
                  sender: dto.sender,
                  startsAt: slot.startsAt.toISOString(),
                  delayMs: slot.delayMs,
                  createdAt: at,
                };
          return { dto, coins, bagQuantity, hostLevelChanged, luckyResult, quip };
        }, LIVE_TX_OPTIONS),
      );
    } catch (err) {
      // A concurrent request with the same clientId won: answer with its send.
      if (err instanceof ReplayRace || violatedUniqueIndex(err) !== null) {
        const raced = await this.byClientId(callerId, clientId);
        if (raced) return { created: false, result: await this.replay(callerId, raced, row.id) };
      }
      throw err;
    }

    const dto = created.dto;
    const quip = created.quip;
    if (quip) {
      // v1.32-live (D154): a quip is heard, not shown as a gift effect: only the `quip` message.
      this.background.run('live quip data message', async () => {
        await this.quips.broadcast(quip);
      });
    } else {
      this.background.run('live gift data message', async () => {
        await this.broadcast(row.id, { type: 'gift', gift: dto });
      });
      // v1.41-live (D178): a big enough send is a strip in every other live (one at a time).
      this.background.run('gift global ticker', async () => {
        await this.giftTicker.offer(dto as unknown as GiftTickerGiftDto);
      });
    }
    const luckyResult = created.luckyResult;
    // v1.41-live (D178, owner: «لا يظهر المكسب في التكست»): every win (×1 and up) is announced to its
    // room — the banner and the chat line for everyone, not only the sender; the big ones
    // (≥ LUCKY_GIFT_BIG_WIN_MULTIPLIER) are also told to every other live (D148).
    if (luckyResult && luckyResult.topMultiplier !== null && luckyResult.coinsWon > 0) {
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
      // v1.30-live (D148): «لحظة الحظ» — every other live room hears about a big one (rate-limited).
      if (luckyResult.topMultiplier >= this.lucky.bigWinMultiplier) {
        this.background.run('lucky global ticker', async () => {
          await this.ticker.offer(win);
        });
      }
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
        ...(quip ? { quip } : {}),
      },
    };
  }

  /**
   * v1.40-social (D155, CONVENTIONS §11.13): a gift sent in a **direct conversation** — the live
   * pipeline without a room: one recipient, the catalogue gift and quantity, `COINS` or `BAG`
   * (lucky: `COINS`, its switch and gates), the normal or lucky rate limit, the wallet charge and
   * ledger (`DM_GIFT`, or `LUCKY_GIFT` / `LUCKY_GIFT_WIN`), the sender's family points, the lucky
   * draws (guarantee and daily protection) and the level credits — the recipient's charm counts
   * `GIFT_DM_RECIPIENT_SHARE_PERCENT` of the value (lucky: the lucky host share), the sender's
   * support the full value (lucky: as in a live). No score, Contribution, wish list, data message
   * or ticker. That share is also the send's stored `host_share_bps` (v1.32-live, D154): in a
   * conversation the DM share replaces the category's live share (`GIFT_HOST_SHARE_PERCENTS`; a
   * quip's 50 % and a normal gift's 65 % both become the DM share), lucky keeps its own. A paid
   * quip (v1.32-live, §10.33) is sent like in a live — `COINS`, quantity 1 — without the room's
   * queue; a free quip (price 0, the one free quip of a live) cannot be sent in a conversation
   * (`GIFT_UNAVAILABLE`, D155 × D154 merge). The caller (the messages module) checked the recipient, blocks, privacy and the
   * request rules before; `hooks.before` runs first inside the transaction (after the sender's
   * lock: it locks the pair, checks again and returns the conversation id) and `hooks.after` last
   * (it writes the gift message). A refusal in either rolls everything back. Retries are answered
   * by the caller (the message's `clientId`), and a concurrent retry fails on `live_gifts_client_once`.
   */
  async sendDirect<T>(
    callerId: string,
    recipientId: string,
    input: { giftCode: string; quantity: number; source: 'COINS' | 'BAG'; clientId: string },
    region: LuckyRegionInput,
    hooks: {
      before(tx: Prisma.TransactionClient): Promise<string>;
      after(
        tx: Prisma.TransactionClient,
        sent: { giftId: string; at: Date; luckyResult: LuckyGiftResultDto | null },
      ): Promise<T>;
    },
  ): Promise<{ extra: T; coins: number; bagQuantity: number; luckyResult: LuckyGiftResultDto | null }> {
    const clientId = input.clientId.toLowerCase();
    const gift = await this.prisma.gift.findUnique({ where: { code: input.giftCode } });
    if (!gift?.enabled) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
    const isLucky = gift.category === 'LUCKY';
    // v1.32-live (D154, §10.33) in a conversation: a paid quip, COINS and one at a time (as in a
    // live); the free quip belongs to a live (one per viewer per live) and is refused here.
    const isQuip = gift.category === 'QUIPS';
    if (isQuip) {
      if (gift.priceCoins === 0) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
      if (input.source !== 'COINS')
        throw AppException.validation([{ field: 'source', issue: 'invalid_value' }]);
      if (input.quantity !== 1)
        throw AppException.validation([{ field: 'quantity', issue: 'invalid_value' }]);
    }
    if (isLucky) {
      if (!this.lucky.enabled) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
      if (input.source !== 'COINS')
        throw AppException.validation([{ field: 'source', issue: 'invalid_value' }]);
      await this.lucky.assertMaySend(callerId, region);
    }
    await this.limiter.consume(
      isLucky ? 'live:gift:lucky' : 'live:gift',
      callerId,
      isLucky ? this.config.rateLimits.liveLuckyGiftBurstUser : this.config.rateLimits.liveGiftUser,
    );
    const winners = isLucky ? this.lucky.draw(input.quantity) : null;
    const table = this.lucky.table;
    const done = await this.oneAtATime(callerId, () =>
      this.prisma.$transaction(async (tx) => {
        await setLiveStatementTimeout(tx);
        // The same first lock as a live send: one send of this sender at a time (the lucky streak).
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`live-gift:${callerId}`}, 0))`;
        const conversationId = await hooks.before(tx);
        const now = this.clock.now();
        const at = now.toISOString();
        const giftId = uuidv7();
        const isCoins = input.source === 'COINS';
        const [state] = await tx.$queryRaw<
          {
            price_coins: number;
            enabled: boolean;
            category: string;
            family_id: string | null;
            losses: number | null;
          }[]
        >`
          SELECT g.price_coins, g.enabled, g.category::text AS category,
                 (SELECT family_id::text FROM family_members
                   WHERE user_id = ${callerId}::uuid AND ${isCoins} FOR SHARE) AS family_id,
                 (SELECT losses FROM lucky_gift_pity WHERE user_id = ${callerId}::uuid) AS losses
            FROM gifts g WHERE g.code = ${gift.code} FOR SHARE`;
        if (!state?.enabled) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
        if ((state.category === 'LUCKY') !== isLucky) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
        if ((state.category === 'QUIPS') !== isQuip) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
        const unitPrice = state.price_coins;
        // A quip made free since the check above: still refused (no free sends in a conversation).
        if (unitPrice === 0) throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
        const amounts = giftAmounts(unitPrice, input.quantity, 1);
        // The recipient's share (charm, and the stored host_share_bps): the DM share for every
        // non-lucky category (quips included), the lucky host share for a lucky gift.
        const shareBps = isLucky ? table.hostShareBps : this.config.dm.giftRecipientSharePercent * 100;
        const charmCoins = shareOf(amounts.perRecipientCoins, shareBps);
        let bagQuantity: number | null = null;
        if (!isCoins) {
          bagQuantity = await consumeStockIn(tx, callerId, gift.code, amounts.bagUnits);
          if (bagQuantity === null) throw new AppException(ErrorCode.GIFT_BAG_INSUFFICIENT);
        }
        const familyCoins = isLucky ? shareOf(amounts.totalCoins, table.hostShareBps) : amounts.totalCoins;
        const family = isCoins && state.family_id !== null && familyCoins > 0 ? state.family_id : null;
        const [written] = await tx.$queryRaw<
          { coins: bigint | null; family_points: bigint | null; family_level: number | null }[]
        >`
          WITH sent AS (
            INSERT INTO live_gifts (id, sender_id, client_id, room_id, dm_conversation_id, gift_code, quantity,
                                    source, unit_price, total_coins, coins_charged, recipients_key, combo_id,
                                    combo_count, combo_quantity, host_share_bps, created_at)
            VALUES (${giftId}::uuid, ${callerId}::uuid, ${clientId}::uuid, NULL, ${conversationId}::uuid,
                    ${gift.code}, ${input.quantity}, ${input.source}::live_gift_source, ${unitPrice},
                    ${amounts.totalCoins}, ${isCoins ? amounts.totalCoins : 0}, ${recipientsKey([recipientId])},
                    ${giftId}::uuid, 1, ${input.quantity}, ${shareBps}, ${at}::timestamptz)
            RETURNING id),
          recipients AS (
            INSERT INTO live_gift_recipients (gift_id, user_id, position, coins)
            SELECT sent.id, ${recipientId}::uuid, 0, ${amounts.perRecipientCoins} FROM sent
            RETURNING 1),
          debit AS (
            UPDATE wallets SET coins = coins - ${amounts.totalCoins}, updated_at = now()
             WHERE ${isCoins} AND user_id = ${callerId}::uuid AND coins >= ${amounts.totalCoins}
            RETURNING coins),
          ledger AS (
            INSERT INTO wallet_ledger (id, user_id, delta, balance_after, reason, reference_id, created_at)
            SELECT ${uuidv7()}::uuid, ${callerId}::uuid, ${-amounts.totalCoins}, debit.coins,
                   ${isLucky ? 'LUCKY_GIFT' : 'DM_GIFT'}::wallet_ledger_reason, ${giftId},
                   ${new Date().toISOString()}::timestamptz
              FROM debit
            RETURNING id),
          family_entry AS (
            INSERT INTO family_points_ledger (id, family_id, user_id, wallet_ledger_id, points, created_at)
            SELECT ${uuidv7()}::uuid, ${family}::uuid, ${callerId}::uuid, ledger.id, ${familyCoins}, now()
              FROM ledger WHERE ${family}::uuid IS NOT NULL
            ON CONFLICT (wallet_ledger_id) DO NOTHING
            RETURNING family_id),
          family_member AS (
            UPDATE family_members SET points = points + ${familyCoins}
             WHERE user_id = ${callerId}::uuid AND EXISTS (SELECT 1 FROM family_entry)
            RETURNING 1),
          family_row AS (
            UPDATE families SET points = LEAST(points + ${familyCoins}, 9007199254740991), updated_at = now()
             WHERE id IN (SELECT family_id FROM family_entry)
            RETURNING points, level)
          SELECT (SELECT coins FROM debit) AS coins,
                 (SELECT points FROM family_row) AS family_points,
                 (SELECT level FROM family_row) AS family_level,
                 (SELECT count(*) FROM recipients) + (SELECT count(*) FROM family_member) AS rows`;
        if (isCoins && (written?.coins ?? null) === null)
          throw new AppException(ErrorCode.INSUFFICIENT_COINS);
        let coins: number | null = isCoins ? Number(written!.coins) : null;
        if (written?.family_points !== null && written?.family_points !== undefined && family !== null) {
          const level = familyLevelFor(written.family_points);
          if (level !== written.family_level) {
            await tx.$executeRaw`UPDATE families SET level = ${level} WHERE id = ${family}::uuid`;
          }
        }
        await this.creditLevels(tx, {
          giftId,
          senderId: callerId,
          hostId: recipientId,
          recipients: [{ id: recipientId, username: '' }],
          perRecipientCoins: amounts.perRecipientCoins,
          lucky: isLucky,
          countedPerRecipientCoins: charmCoins,
          ...(isLucky ? {} : { supportPerRecipientCoins: amounts.perRecipientCoins }),
        });
        // v1.52-social (D179, §10.46): the recipient's cherries and their agency's commissions.
        await this.creditCherries(tx, giftId, now);
        let luckyResult: LuckyGiftResultDto | null = null;
        if (isLucky) {
          const lucky = await this.settleLucky(tx, {
            giftId,
            senderId: callerId,
            giftCode: gift.code,
            unitPrice,
            quantity: input.quantity,
            recipients: 1,
            totalCoins: amounts.totalCoins,
            winners: winners ?? [],
            lossesBefore: state.losses ?? 0,
            now,
          });
          if (lucky.coins !== null) coins = lucky.coins;
          luckyResult = lucky.result;
        }
        const extra = await hooks.after(tx, { giftId, at: now, luckyResult });
        return { extra, coins, bagQuantity, luckyResult };
      }, LIVE_TX_OPTIONS),
    );
    return {
      extra: done.extra,
      coins: done.coins ?? (await this.wallet.mine(callerId)).coins,
      bagQuantity: done.bagQuantity ?? (await stockOf(this.prisma, callerId, gift.code)),
      luckyResult: done.luckyResult,
    };
  }

  /** D179: the cherry credit of a send (CONVENTIONS §10.46), inside its transaction. */
  private async creditCherries(tx: Prisma.TransactionClient, giftId: string, now: Date): Promise<void> {
    await creditGiftCherriesIn(tx, giftId, now, this.config.economy, this.config.live.rankingsTimeZone);
  }

  /**
   * v1.27-live (D132, §10.27), D148: inside the send's transaction, after everything else: adds the
   * send to the day's lucky spend (locking the day row: lucky sends are serialized per day, so this
   * comes last), settles the draws in draw order with the sender's streak (the guarantee, D148) and
   * the day's budget (`floor(spend × RTP) − paid`; a draw that does not fit pays the largest smaller
   * multiplier that fits, or nothing), then in one statement: the coins paid on the day row, the win
   * credited (`LUCKY_GIFT_WIN`), the audit row of the draws and the sender's new streak. Returns the
   * balance after the win (null: nothing won) and the response's `luckyResult`.
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
      lossesBefore: number;
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
    const settled = settleDraws(
      send.winners,
      draws,
      send.unitPrice,
      table.outcomes.map((o) => o.multiplier),
      budgetBefore,
      table.pity,
      send.lossesBefore,
    );
    const result = luckyResultDto(draws, settled.wins, send.unitPrice, settled.downgraded);
    const won = settled.coinsWon;
    const odds = JSON.stringify({
      rtpBps: table.rtpBps,
      hostShareBps: table.hostShareBps,
      outcomes: table.outcomes.map((o) => [o.multiplier, o.chancePerMillion]),
      pity: table.pity === null ? null : [table.pity.after, table.pity.multiplier],
    });
    const [written] = await tx.$queryRaw<{ coins: bigint | null }[]>`
      WITH paid AS (
        UPDATE lucky_gift_days SET paid_coins = paid_coins + ${won}
         WHERE ${won > 0n} AND day = ${day}::date
        RETURNING 1),
      credit AS (
        INSERT INTO wallets (user_id, coins, updated_at)
        SELECT ${send.senderId}::uuid, ${won}, now() WHERE ${won > 0n}
        ON CONFLICT (user_id) DO UPDATE SET coins = wallets.coins + EXCLUDED.coins, updated_at = now()
        RETURNING coins),
      ledger AS (
        INSERT INTO wallet_ledger (id, user_id, delta, balance_after, reason, reference_id, created_at)
        SELECT ${uuidv7()}::uuid, ${send.senderId}::uuid, ${won}, credit.coins,
               'LUCKY_GIFT_WIN'::wallet_ledger_reason, ${send.giftId}, ${new Date().toISOString()}::timestamptz
          FROM credit
        RETURNING 1),
      audit AS (
        INSERT INTO lucky_gift_draws (gift_id, sender_id, gift_code, unit_price, quantity, recipients, draws, odds,
                                      wins, coins_won, top_multiplier, downgraded, budget_day, budget_before,
                                      budget_after, spend_after, losses_before, losses_after, guaranteed, created_at)
        VALUES (${send.giftId}::uuid, ${send.senderId}::uuid, ${send.giftCode}, ${send.unitPrice}, ${send.quantity},
                ${send.recipients}, ${draws}, ${odds}::jsonb, ${JSON.stringify(settled.wins)}::jsonb, ${won},
                ${result.topMultiplier}::int, ${settled.downgraded}, ${day}::date, ${budgetBefore},
                ${settled.budgetAfter}, ${dayRow!.spend_coins}, ${send.lossesBefore}, ${settled.lossesAfter},
                ${settled.guaranteed}, ${at}::timestamptz)
        RETURNING 1),
      streak AS (
        INSERT INTO lucky_gift_pity (user_id, losses, updated_at)
        VALUES (${send.senderId}::uuid, ${settled.lossesAfter}, ${at}::timestamptz)
        ON CONFLICT (user_id) DO UPDATE SET losses = EXCLUDED.losses, updated_at = EXCLUDED.updated_at
        RETURNING 1)
      SELECT (SELECT coins FROM credit) AS coins,
             (SELECT count(*) FROM paid) + (SELECT count(*) FROM ledger) + (SELECT count(*) FROM audit)
               + (SELECT count(*) FROM streak) AS rows`;
    const coins = won > 0n ? Number(written!.coins) : null;
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

  /**
   * The users named (ACTIVE), in request order — null where nobody ACTIVE has that username — and
   * (D148, one query) the `UserSummary` of the caller and of each of them for the response (the
   * transaction no longer reads the send back).
   */
  private async resolveRecipients(
    callerId: string,
    usernames: readonly string[],
  ): Promise<{ recipients: (Recipient | null)[]; people: Map<string, UserSummaryDto> }> {
    const users = await this.prisma.user.findMany({
      where: {
        OR: [{ id: callerId }, { status: 'ACTIVE', profile: { username: { in: [...usernames] } } }],
      },
      select: { ...USER_SUMMARY_SELECT, status: true },
    });
    const byName = new Map(
      users
        .filter((u) => u.status === 'ACTIVE' && u.profile !== null)
        .map((u) => [u.profile!.username, { id: u.id, username: u.profile!.username }]),
    );
    return {
      recipients: usernames.map((name) => byName.get(name) ?? null),
      people: new Map(users.map((u) => [u.id, userSummary(u)])),
    };
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
      /**
       * v1.40-social (D155): the value counted for the sender's support when it differs from the
       * charm value (a gift in a conversation: charm counts the recipient's share, support the full
       * value). Absent: `countedPerRecipientCoins`.
       */
      supportPerRecipientCoins?: number;
    },
  ): Promise<boolean> {
    // D148 (fewer round trips): every category a send can credit, share-locked and loaded at once
    // (the categories of a send: charm and support; for a lucky gift also Wizard). A category that is
    // not seeded is not credited.
    const loaded = await loadCategories(
      tx,
      send.lucky ? ['ATTRACTIVENESS', 'SUPPORT', 'WIZARD'] : ['ATTRACTIVENESS', 'SUPPORT'],
    );
    const category = (code: LevelCategoryCode): LoadedCategory | null => loaded.get(code) ?? null;
    // CP-005: lucky gifts count for the sender's Support only when the published SUPPORT version says.
    let luckyGiftsCountAsSupport = false;
    if (send.lucky) {
      const support = category('SUPPORT');
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
        const value =
          credit.category === 'WIZARD'
            ? credit.value
            : credit.category === 'SUPPORT' && send.supportPerRecipientCoins !== undefined
              ? BigInt(send.supportPerRecipientCoins)
              : BigInt(send.countedPerRecipientCoins);
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
      const cat = category(credit.category);
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
