import { Inject, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { maskBlockedWords } from '../live/live-blocked-words.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { isUuid } from '../live/live.schemas.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { blockedEitherWayIn } from '../social/pair-lock.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import { findOwnCouple, findVisibleCouple } from './cp-couple-visibility.js';
import { cpConfessionCreateSchema, type CpPageQuery } from './cp-space.schemas.js';

/** `CpConfession`. */
export interface CpConfessionDto {
  id: string;
  coupleId: string;
  author: UserSummaryDto;
  recipient: UserSummaryDto;
  /** Both partners' live blocked words are masked (each character → `*`). */
  text: string;
  createdAt: string;
}

const INCLUDE = {
  author: { select: USER_SUMMARY_SELECT },
  recipient: { select: USER_SUMMARY_SELECT },
} as const satisfies Prisma.CpConfessionInclude;
type Row = Prisma.CpConfessionGetPayload<{ include: typeof INCLUDE }>;

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

/**
 * The confession wall (CP-021, owner D112, CONVENTIONS §10.24): a partner leaves a short
 * confession for the other on the couple's page. Only the partners write; both partners read it
 * and anyone who may see the couple page reads it publicly. Either partner deletes one (soft);
 * anyone who can read one reports it (`POST /reports`, `CP_CONFESSION`).
 */
@Injectable()
export class CpConfessionsService {
  private readonly cursors: SocialCursorCodec;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  private toDto(row: Row): CpConfessionDto {
    return {
      id: row.id,
      coupleId: row.coupleId,
      author: userSummary(row.author),
      recipient: userSummary(row.recipient),
      text: row.text,
      createdAt: row.createdAt.toISOString(),
    };
  }

  /**
   * `POST /cp/me/confessions`. Order after auth and rate limit: 400 body (the chat text rules,
   * 1–200 code points); a retry with the same `clientId` → 200 with the first confession; 409
   * CP_NOT_PAIRED; 403 AUTH_FORBIDDEN (the partner is not ACTIVE, or a block either way between the
   * partners). Both partners' live blocked words are masked before it is stored.
   */
  async create(callerId: string, body: unknown): Promise<{ created: boolean; confession: CpConfessionDto }> {
    const parsed = cpConfessionCreateSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const clientId = parsed.data.clientId.toLowerCase();
    const first = await this.byClientId(callerId, clientId);
    if (first) return { created: false, confession: this.toDto(first) };

    const couple = await findOwnCouple(this.prisma, callerId);
    if (!couple) throw new AppException(ErrorCode.CP_NOT_PAIRED);
    const partnerActive = await this.prisma.user.count({
      where: { id: couple.partner_id, status: 'ACTIVE' },
    });
    if (partnerActive === 0 || (await blockedEitherWayIn(this.prisma, callerId, couple.partner_id))) {
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    }
    const hosts = await this.prisma.liveHost.findMany({
      where: { userId: { in: [callerId, couple.partner_id] } },
      select: { blockedWords: true },
    });
    const text = maskBlockedWords(
      parsed.data.text,
      hosts.flatMap((h) => h.blockedWords),
    );
    try {
      const row = await this.prisma.cpConfession.create({
        data: {
          coupleId: couple.id,
          authorId: callerId,
          recipientId: couple.partner_id,
          text,
          clientId,
          createdAt: this.clock.now(),
        },
        include: INCLUDE,
      });
      return { created: true, confession: this.toDto(row) };
    } catch (err) {
      const index = violatedUniqueIndex(err);
      if (index !== null && index.includes('cp_confessions_client_once')) {
        const raced = await this.byClientId(callerId, clientId);
        if (raced) return { created: false, confession: this.toDto(raced) };
      }
      throw err;
    }
  }

  private byClientId(authorId: string, clientId: string): Promise<Row | null> {
    return this.prisma.cpConfession.findUnique({
      where: { authorId_clientId: { authorId, clientId } },
      include: INCLUDE,
    });
  }

  private async page(coupleId: string, query: CpPageQuery): Promise<PageDto<CpConfessionDto>> {
    const scope = `cp-confessions:${coupleId}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const rows = await this.prisma.cpConfession.findMany({
      where: {
        coupleId,
        deletedAt: null,
        ...(after
          ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
      include: INCLUDE,
    });
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];
    return {
      data: page.map((r) => this.toDto(r)),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  /** `GET /cp/me/confessions`: the caller's couple's confessions, newest first (409 CP_NOT_PAIRED). */
  async listMine(callerId: string, query: CpPageQuery): Promise<PageDto<CpConfessionDto>> {
    const couple = await findOwnCouple(this.prisma, callerId);
    if (!couple) throw new AppException(ErrorCode.CP_NOT_PAIRED);
    return this.page(couple.id, query);
  }

  /** `GET /cp/couples/{coupleId}/confessions`: public, newest first (404 like the couple page). */
  async listPublic(
    readerId: string,
    coupleId: string,
    query: CpPageQuery,
  ): Promise<PageDto<CpConfessionDto>> {
    if (!isUuid(coupleId)) throw notFound();
    const couple = await findVisibleCouple(this.prisma, coupleId.toLowerCase(), readerId);
    if (!couple) throw notFound();
    return this.page(couple.id, query);
  }

  /**
   * `DELETE /cp/me/confessions/{confessionId}`: either partner of the caller's current couple
   * removes one (soft); 404 when it is not on the caller's couple page; already deleted → 204.
   */
  async remove(callerId: string, confessionId: string): Promise<void> {
    if (!isUuid(confessionId)) throw notFound();
    const couple = await findOwnCouple(this.prisma, callerId);
    if (!couple) throw notFound();
    const row = await this.prisma.cpConfession.findFirst({
      where: { id: confessionId.toLowerCase(), coupleId: couple.id },
      select: { id: true, deletedAt: true },
    });
    if (!row) throw notFound();
    if (row.deletedAt !== null) return;
    await this.prisma.cpConfession.updateMany({
      where: { id: row.id, deletedAt: null },
      data: { deletedAt: this.clock.now(), deletedById: callerId },
    });
  }
}
