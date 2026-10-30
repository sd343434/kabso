import { Inject, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma, type WalletLedgerReason } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import type { PageQuery } from '../posts/posts.schemas.js';
import { SocialCursorCodec, type SocialPosition } from '../posts/social-cursor.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';

/** `WalletLedgerEntry` (openapi v1.43-social, D164). */
export interface WalletLedgerEntryDto {
  id: string;
  reason: WalletLedgerReason;
  delta: number;
  balanceAfter: number;
  createdAt: string;
}

/** `MyEarnings` (v1.43-social, D164): display only, never coins (payouts are D149). */
export interface MyEarningsDto {
  totalCoins: number;
  last7DaysCoins: number;
  last30DaysCoins: number;
  sendCount: number;
}

/** `Earning` (v1.43-social, D164): one gift send that gave the caller earnings. */
export interface EarningDto {
  id: string;
  createdAt: string;
  context: 'LIVE' | 'DM';
  giftCode: string;
  giftName: string;
  quantity: number;
  giftCoins: number;
  shareBps: number;
  coins: number;
  sender: UserSummaryDto | null;
}

const DAY_MS = 86_400_000;

/**
 * The caller's coin history and gift earnings (v1.43-social, D164, CONVENTIONS §10.40). Reads only
 * the caller's own rows. Earnings are not a balance: the ledger never credits a recipient's share,
 * so they are computed per read from the sends the caller received — floor(recipient coins × the
 * send's stored `host_share_bps` / 10 000), the data center's arithmetic (§10.36).
 */
@Injectable()
export class WalletHistoryService {
  private readonly cursors: SocialCursorCodec;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  private after(cursor: string | undefined, scope: string): SocialPosition | null {
    if (cursor === undefined) return null;
    const after = this.cursors.decode(cursor, scope);
    if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    return after;
  }

  /** `GET /wallet/me/ledger`: newest first; the row's reference is never returned. */
  async ledger(me: string, query: PageQuery): Promise<PageDto<WalletLedgerEntryDto>> {
    const scope = `wallet-ledger:${me}`;
    const after = this.after(query.cursor, scope);
    const rows = await this.prisma.walletLedgerEntry.findMany({
      where: {
        userId: me,
        ...(after
          ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
      select: { id: true, reason: true, delta: true, balanceAfter: true, createdAt: true },
    });
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];
    return {
      data: page.map((r) => ({
        id: r.id,
        reason: r.reason,
        delta: Number(r.delta),
        balanceAfter: Number(r.balanceAfter),
        createdAt: r.createdAt.toISOString(),
      })),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  /** `GET /wallet/me/earnings`: all time and the rolling 7 and 30 days ending now. */
  async earnings(me: string): Promise<MyEarningsDto> {
    const now = this.clock.now().getTime();
    const d7 = new Date(now - 7 * DAY_MS).toISOString();
    const d30 = new Date(now - 30 * DAY_MS).toISOString();
    const [row] = await this.prisma.$queryRaw<{ total: bigint; d7: bigint; d30: bigint; sends: bigint }[]>`
      SELECT COALESCE(sum(e.coins), 0)::bigint AS total,
             COALESCE(sum(e.coins) FILTER (WHERE e.created_at >= ${d7}::timestamptz), 0)::bigint AS d7,
             COALESCE(sum(e.coins) FILTER (WHERE e.created_at >= ${d30}::timestamptz), 0)::bigint AS d30,
             count(*)::bigint AS sends
        FROM (SELECT g.created_at, floor(gr.coins * g.host_share_bps / 10000.0)::bigint AS coins
                FROM live_gift_recipients gr
                JOIN live_gifts g ON g.id = gr.gift_id
               WHERE gr.user_id = ${me}::uuid) e
       WHERE e.coins > 0`;
    return {
      totalCoins: Number(row?.total ?? 0n),
      last7DaysCoins: Number(row?.d7 ?? 0n),
      last30DaysCoins: Number(row?.d30 ?? 0n),
      sendCount: Number(row?.sends ?? 0n),
    };
  }

  /** `GET /wallet/me/earnings/history`: one row per send with a share > 0, newest first. */
  async earningHistory(me: string, query: PageQuery, lang: ContentLanguage): Promise<PageDto<EarningDto>> {
    const scope = `earnings:${me}`;
    const after = this.after(query.cursor, scope);
    const afterSql = after
      ? Prisma.sql`AND (g.created_at, g.id) < (${after.at.toISOString()}::timestamptz, ${after.id}::uuid)`
      : Prisma.empty;
    const rows = await this.prisma.$queryRaw<
      {
        id: string;
        created_at: Date;
        dm: boolean;
        gift_code: string;
        name_ar: string;
        name_en: string;
        quantity: number;
        sender_id: string;
        gift_coins: bigint;
        share_bps: number;
        coins: bigint;
      }[]
    >`
      SELECT g.id::text AS id, g.created_at, (g.dm_conversation_id IS NOT NULL) AS dm, g.gift_code,
             gf.name_ar, gf.name_en, g.quantity, g.sender_id::text AS sender_id, gr.coins AS gift_coins,
             g.host_share_bps AS share_bps, floor(gr.coins * g.host_share_bps / 10000.0)::bigint AS coins
        FROM live_gift_recipients gr
        JOIN live_gifts g ON g.id = gr.gift_id
        JOIN gifts gf ON gf.code = g.gift_code
       WHERE gr.user_id = ${me}::uuid
         AND floor(gr.coins * g.host_share_bps / 10000.0) > 0
         ${afterSql}
       ORDER BY g.created_at DESC, g.id DESC
       LIMIT ${query.limit + 1}`;
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const senders = await this.visibleSenders(me, [...new Set(page.map((r) => r.sender_id))]);
    const last = page[page.length - 1];
    return {
      data: page.map((r) => ({
        id: r.id,
        createdAt: r.created_at.toISOString(),
        context: r.dm ? 'DM' : 'LIVE',
        giftCode: r.gift_code,
        giftName: lang === 'ar' ? r.name_ar : r.name_en,
        quantity: r.quantity,
        giftCoins: Number(r.gift_coins),
        shareBps: r.share_bps,
        coins: Number(r.coins),
        sender: senders.get(r.sender_id) ?? null,
      })),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.created_at, id: last.id }) : null,
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
