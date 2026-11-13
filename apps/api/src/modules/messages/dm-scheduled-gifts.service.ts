import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma, VipScheduledGift } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { CUSTOM_CATEGORY, QUIPS_CATEGORY } from '../gifts/gift-catalogue.js';
import { GiftsService, giftDto, type GiftDto } from '../gifts/gifts.service.js';
import { isUuid } from '../live/live.schemas.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { assertNotRestricted } from '../users/account-control.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import { VIP_SCHEDULED_GIFT_MAX_PENDING, vipPerkHeldIn } from '../vip/vip-gift-perks.js';
import { creditIn, debitIn, inCoinDebtIn } from '../wallet/wallet-ledger.js';
import { DmService } from './dm.service.js';
import { refuseStaffGift } from '../live/live-staff.js';

type Tx = Prisma.TransactionClient;

/** A scheduled gift is at least this far ahead (so it can still be cancelled). */
export const VIP_SCHEDULED_GIFT_MIN_LEAD_MS = 5 * 60_000;
/** …and at most this far (a birthday next year). */
export const VIP_SCHEDULED_GIFT_MAX_AHEAD_MS = 366 * 86_400_000;
/** The list returns the newest this many (a server-bounded list, §5). */
export const VIP_SCHEDULED_GIFT_LIST_MAX = 50;
/** An undeliverable gift that failed only for unexpected reasons is given up (and refunded) this long after its time. */
const GIVE_UP_MS = 24 * 3600_000;
const BATCH = 50;

/** `ScheduleVipGiftRequest` (strict). */
export function scheduleVipGiftSchema(quantities: readonly number[]) {
  return z.strictObject({
    to: z.string().min(1).max(64),
    giftCode: z.string().min(1).max(40),
    quantity: z
      .number()
      .int()
      .refine((q) => quantities.includes(q), {
        message: 'not an allowed quantity',
        params: { issue: 'invalid_value' },
      }),
    deliverAt: z.iso.datetime({ offset: true }),
    clientId: z.uuid(),
  });
}

/** `VipScheduledGift` (v1.134-social, D381, §10.171.5). */
export interface VipScheduledGiftDto {
  id: string;
  /** The recipient, or null once their account is gone. */
  to: UserSummaryDto | null;
  giftCode: string;
  /** The gift as the catalogue shows it now, or null when it is no longer in the catalogue. */
  gift: GiftDto | null;
  quantity: number;
  /** The coins held for it (unit price at scheduling × quantity). */
  coins: number;
  deliverAt: string;
  status: 'PENDING' | 'DELIVERED' | 'CANCELLED' | 'FAILED';
  /** FAILED: why (an error code of §4, e.g. `DM_NOT_ALLOWED`, `INSUFFICIENT_COINS`, `RECIPIENT_GONE`). */
  failure: string | null;
  createdAt: string;
  handledAt: string | null;
}

export interface VipScheduledGiftListDto {
  data: VipScheduledGiftDto[];
  pending: number;
  maxPending: number;
}

export interface VipScheduledGiftResultDto {
  scheduledGift: VipScheduledGiftDto;
  /** The caller's balance now. */
  coins: number;
}

/** Thrown inside a delivery's transaction when the row was handled meanwhile (the send rolls back). */
class AlreadyHandled extends Error {}

type Row = VipScheduledGift & {
  recipient: Prisma.UserGetPayload<{ select: typeof USER_SUMMARY_SELECT }> | null;
};

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

/**
 * v1.134-social (D381, CONVENTIONS §10.171.5) SCHEDULED_GIFT «هدية مؤجلة»: a member holding the perk schedules a gift
 * to a person at a time (a host's birthday). Scheduling checks what a conversation gift checks now (the recipient
 * rules, the gift, the quantity, the sender's restrictions) and holds the coins (wallet ledger `VIP_SCHEDULED_GIFT`).
 * At its time the worker (the DM sweeper's cadence, `DM_SWEEP_INTERVAL_SECONDS`) sends it **as the sender's gift in
 * their conversation** («هدية» message with its push, `POST /dm/gifts`' pipeline) — in that send's transaction the held
 * coins are given back (`VIP_SCHEDULED_GIFT_RELEASE`) and the gift charged (`DM_GIFT`) at its price then; the rules of
 * that moment apply (blocks, privacy, inactive accounts, restrictions, the sender's VIP for an exclusive gift or a VIP
 * quantity). A refused delivery fails the gift and gives the coins back. Cancellable while pending (coins back). At
 * most {@link VIP_SCHEDULED_GIFT_MAX_PENDING} wait per sender. Idempotent: `clientId` for scheduling, the scheduled
 * gift's id as the delivery's `clientId`.
 */
@Injectable()
export class DmScheduledGiftsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('DmScheduledGifts');
  private timer: NodeJS.Timeout | undefined;
  private inFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly dm: DmService,
    private readonly gifts: GiftsService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.dm.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.deliverDue()
        .then((n) => {
          if (n > 0) this.logger.log({ handled: n }, 'Scheduled gifts handled');
        })
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Scheduled gift delivery failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.dm.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }

  private async dto(row: Row, lang: ContentLanguage): Promise<VipScheduledGiftDto> {
    const gift = await this.prisma.gift.findUnique({ where: { code: row.giftCode } });
    return {
      id: row.id,
      to: row.recipient ? userSummary(row.recipient) : null,
      giftCode: row.giftCode,
      gift: gift ? giftDto(gift, lang, this.gifts.publicBaseUrl) : null,
      quantity: row.quantity,
      coins: Number(row.coinsHeld),
      deliverAt: row.deliverAt.toISOString(),
      status: row.status,
      failure: row.failure,
      createdAt: row.createdAt.toISOString(),
      handledAt: row.handledAt?.toISOString() ?? null,
    };
  }

  private async balance(userId: string): Promise<number> {
    const w = await this.prisma.wallet.findUnique({ where: { userId }, select: { coins: true } });
    return Number(w?.coins ?? 0n);
  }

  private rowById(id: string): Promise<Row | null> {
    return this.prisma.vipScheduledGift.findUnique({
      where: { id },
      include: { recipient: { select: USER_SUMMARY_SELECT } },
    });
  }

  /**
   * `POST /me/vip/scheduled-gifts`. After auth and the rate limit: 400 body → a retry with the same `clientId` (200,
   * nothing charged again) → 409 `VIP_UNAVAILABLE` `perk` `no_perk` → 400 `deliverAt` `out_of_range` (under 5 minutes
   * or over 366 days ahead) → the recipient (400 `to` oneself, 404, 403 `DM_NOT_ALLOWED` …) → 409 `GIFT_UNAVAILABLE`
   * (not a gift that can be scheduled: disabled, lucky, a quip, custom, an event's own, a PK booster, free, or an
   * exclusive gift the caller's VIP may not send) → 409 `VIP_UNAVAILABLE` `pending` `too_many` → 403 restrictions /
   * 409 `TOPUP_ACCOUNT_FROZEN` → 409 `INSUFFICIENT_COINS`; then the row and the hold in one transaction.
   */
  async create(
    callerId: string,
    body: unknown,
    lang: ContentLanguage,
  ): Promise<{ created: boolean; result: VipScheduledGiftResultDto }> {
    const parsed = scheduleVipGiftSchema(await this.gifts.quantitiesFor(callerId, body)).safeParse(
      body ?? {},
      {
        reportInput: true,
      },
    );
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const clientId = input.clientId.toLowerCase();
    const replay = await this.prisma.vipScheduledGift.findUnique({
      where: { senderId_clientId: { senderId: callerId, clientId } },
      include: { recipient: { select: USER_SUMMARY_SELECT } },
    });
    if (replay) {
      return {
        created: false,
        result: { scheduledGift: await this.dto(replay, lang), coins: await this.balance(callerId) },
      };
    }
    const now = this.clock.now();
    if (!(await vipPerkHeldIn(this.prisma, callerId, 'SCHEDULED_GIFT', now))) {
      throw new AppException(ErrorCode.VIP_UNAVAILABLE, undefined, [{ field: 'perk', issue: 'no_perk' }]);
    }
    const deliverAt = new Date(input.deliverAt);
    const ahead = deliverAt.getTime() - now.getTime();
    if (ahead < VIP_SCHEDULED_GIFT_MIN_LEAD_MS || ahead > VIP_SCHEDULED_GIFT_MAX_AHEAD_MS) {
      throw AppException.validation([{ field: 'deliverAt', issue: 'out_of_range' }]);
    }
    const to = await this.dm.assertMayGift(callerId, input.to, 'to');
    const gift = await this.prisma.gift.findUnique({
      where: { code: input.giftCode },
      include: { categoryRef: { select: { enabled: true, kind: true } } },
    });
    if (
      !gift ||
      !gift.enabled ||
      !gift.categoryRef.enabled ||
      gift.categoryRef.kind !== 'NORMAL' ||
      gift.category === 'LUCKY' ||
      gift.category === QUIPS_CATEGORY ||
      gift.category === CUSTOM_CATEGORY ||
      gift.eventId !== null ||
      gift.pkBooster !== null ||
      gift.priceCoins <= 0
    ) {
      throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
    }
    await this.gifts.assertVipMaySend(callerId, gift.code);
    const coins = BigInt(gift.priceCoins) * BigInt(input.quantity);
    const id = uuidv7();
    let after: bigint;
    try {
      after = await this.prisma.$transaction(async (tx) => {
        // One sender's schedulings at a time (the pending cap is exact).
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`vip-scheduled-gift:${callerId}`}, 0))`;
        const pending = await tx.vipScheduledGift.count({ where: { senderId: callerId, status: 'PENDING' } });
        if (pending >= VIP_SCHEDULED_GIFT_MAX_PENDING) {
          throw new AppException(ErrorCode.VIP_UNAVAILABLE, undefined, [
            { field: 'pending', issue: 'too_many' },
          ]);
        }
        await assertNotRestricted(tx, callerId, 'NO_GIFTS');
        // v1.139-social (D387, §10.176.8): a staff account sends no gift (owner: «اي موظف لدينا لا يمكنه ارسال الهدايا»).
        await refuseStaffGift(tx, callerId);
        if (await inCoinDebtIn(tx, callerId)) throw new AppException(ErrorCode.TOPUP_ACCOUNT_FROZEN);
        await tx.vipScheduledGift.create({
          data: {
            id,
            senderId: callerId,
            recipientId: to.id,
            clientId,
            giftCode: gift.code,
            quantity: input.quantity,
            unitPrice: gift.priceCoins,
            coinsHeld: coins,
            deliverAt,
            createdAt: now,
          },
        });
        const debit = await debitIn(tx, callerId, coins, 'VIP_SCHEDULED_GIFT', id);
        if (!debit) throw new AppException(ErrorCode.INSUFFICIENT_COINS);
        return debit.coins;
      });
    } catch (err) {
      if ((violatedUniqueIndex(err) ?? '').includes('vip_scheduled_gifts_client_once')) {
        return this.create(callerId, body, lang);
      }
      throw err;
    }
    return {
      created: true,
      result: { scheduledGift: await this.dto((await this.rowById(id))!, lang), coins: Number(after) },
    };
  }

  /** `GET /me/vip/scheduled-gifts`: the caller's newest {@link VIP_SCHEDULED_GIFT_LIST_MAX}, pending ones first. */
  async list(callerId: string, lang: ContentLanguage): Promise<VipScheduledGiftListDto> {
    const rows = await this.prisma.vipScheduledGift.findMany({
      where: { senderId: callerId },
      include: { recipient: { select: USER_SUMMARY_SELECT } },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: VIP_SCHEDULED_GIFT_LIST_MAX,
    });
    const pending = await this.prisma.vipScheduledGift.count({
      where: { senderId: callerId, status: 'PENDING' },
    });
    const sorted = [
      ...rows
        .filter((r) => r.status === 'PENDING')
        .sort((a, b) => a.deliverAt.getTime() - b.deliverAt.getTime()),
      ...rows.filter((r) => r.status !== 'PENDING'),
    ];
    const data: VipScheduledGiftDto[] = [];
    for (const r of sorted) data.push(await this.dto(r, lang));
    return { data, pending, maxPending: VIP_SCHEDULED_GIFT_MAX_PENDING };
  }

  /** Locks the row and, while PENDING, closes it with [status] and gives the held coins back. */
  private async closeIn(
    tx: Tx,
    id: string,
    status: 'CANCELLED' | 'FAILED',
    failure: string | null,
  ): Promise<boolean> {
    const [row] = await tx.$queryRaw<{ sender_id: string; coins_held: bigint; status: string }[]>`
      SELECT sender_id::text AS sender_id, coins_held, status::text AS status
        FROM vip_scheduled_gifts WHERE id = ${id}::uuid FOR UPDATE`;
    if (row?.status !== 'PENDING') return false;
    await tx.vipScheduledGift.update({
      where: { id },
      data: { status, failure, handledAt: this.clock.now() },
    });
    await creditIn(tx, row.sender_id, row.coins_held, 'VIP_SCHEDULED_GIFT_RELEASE', id);
    return true;
  }

  /**
   * `DELETE /me/vip/scheduled-gifts/{scheduledGiftId}`: the sender cancels a pending gift; the held coins come back. 404
   * (not the caller's); 409 `VIP_UNAVAILABLE` `status` `not_pending` (delivered, cancelled or failed). Allowed after
   * the VIP ended too (the coins are the sender's).
   */
  async cancel(callerId: string, id: string, lang: ContentLanguage): Promise<VipScheduledGiftResultDto> {
    if (!isUuid(id)) throw notFound();
    const key = id.toLowerCase();
    const row = await this.prisma.vipScheduledGift.findFirst({ where: { id: key, senderId: callerId } });
    if (!row) throw notFound();
    const closed = await this.prisma.$transaction((tx) => this.closeIn(tx, key, 'CANCELLED', null));
    if (!closed) {
      throw new AppException(ErrorCode.VIP_UNAVAILABLE, undefined, [
        { field: 'status', issue: 'not_pending' },
      ]);
    }
    return {
      scheduledGift: await this.dto((await this.rowById(key))!, lang),
      coins: await this.balance(callerId),
    };
  }

  /**
   * The worker: delivers every pending gift whose time has come (oldest first, bounded batches). Returns how many were
   * handled (delivered or failed).
   */
  async deliverDue(now: Date = this.clock.now()): Promise<number> {
    let total = 0;
    for (;;) {
      const due = await this.prisma.vipScheduledGift.findMany({
        where: { status: 'PENDING', deliverAt: { lte: now } },
        orderBy: [{ deliverAt: 'asc' }, { id: 'asc' }],
        take: BATCH,
        select: { id: true },
      });
      let handled = 0;
      for (const { id } of due) if (await this.deliverOne(id, now)) handled += 1;
      total += handled;
      if (due.length < BATCH || handled === 0) return total;
    }
  }

  /**
   * Delivers one scheduled gift (see the class). True when it was delivered or failed now; false when it was handled
   * elsewhere or stays pending for the next run (a passing error).
   */
  async deliverOne(id: string, now: Date = this.clock.now()): Promise<boolean> {
    const row = await this.rowById(id);
    if (row?.status !== 'PENDING') return false;
    const fail = async (failure: string): Promise<boolean> =>
      this.prisma.$transaction((tx) => this.closeIn(tx, id, 'FAILED', failure));
    const sender = await this.prisma.user.findUnique({
      where: { id: row.senderId },
      select: { status: true },
    });
    if (sender?.status !== 'ACTIVE') return fail('SENDER_INACTIVE');
    if (!row.recipient) return fail('RECIPIENT_GONE');
    try {
      const sent = await this.dm.sendGift(
        row.senderId,
        {
          to: row.recipient.profile?.username ?? '',
          giftCode: row.giftCode,
          quantity: row.quantity,
          source: 'COINS',
          clientId: row.id,
        },
        { edgeCountry: undefined },
        {
          inTransaction: async (tx) => {
            const [locked] = await tx.$queryRaw<{ status: string }[]>`
              SELECT status::text AS status FROM vip_scheduled_gifts WHERE id = ${id}::uuid FOR UPDATE`;
            if (locked?.status !== 'PENDING') throw new AlreadyHandled();
            await tx.vipScheduledGift.update({
              where: { id },
              data: { status: 'DELIVERED', handledAt: this.clock.now() },
            });
            await creditIn(tx, row.senderId, row.coinsHeld, 'VIP_SCHEDULED_GIFT_RELEASE', id);
          },
        },
      );
      await this.prisma.vipScheduledGift.updateMany({
        where: { id, status: 'DELIVERED' },
        data: { dmMessageId: sent.result.message.id },
      });
      return true;
    } catch (err) {
      if (err instanceof AlreadyHandled) return false;
      if (err instanceof AppException && err.code !== ErrorCode.RATE_LIMITED) return fail(err.code);
      this.logger.warn({ id, error: safeErrorLog(err) }, 'Scheduled gift not delivered yet');
      if (now.getTime() - row.deliverAt.getTime() > GIVE_UP_MS) return fail('ERROR');
      return false;
    }
  }
}
