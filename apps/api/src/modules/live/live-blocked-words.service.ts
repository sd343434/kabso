import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { setLiveBlockedWordsSchema } from './live-blocked-words.js';
import type { RequestMeta } from './live-rooms.service.js';

/** `LiveBlockedWords` (openapi v1.12-live). */
export interface LiveBlockedWordsDto {
  words: string[];
}

/**
 * The host's blocked words (CP-016 B, CONVENTIONS §10.14): masked in the chat of every live of
 * that host (see `maskBlockedWords`). Stored on `live_hosts`, so only hosts have them.
 */
@Injectable()
export class LiveBlockedWordsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  /** `GET /me/live-blocked-words`: in the order saved. No hosting permission → 403. */
  async get(userId: string): Promise<LiveBlockedWordsDto> {
    const host = await this.prisma.liveHost.findUnique({
      where: { userId },
      select: { blockedWords: true },
    });
    if (!host) throw new AppException(ErrorCode.LIVE_HOSTING_NOT_ALLOWED);
    return { words: host.blockedWords };
  }

  /**
   * `PUT /me/live-blocked-words`: replaces the list. Order: hosting permission (403) → body
   * (normalized, duplicates dropped, ≤ 100). Audited as `live.blocked_words.update` with the count
   * only (never the words). Applies to messages sent from now on.
   */
  async set(userId: string, body: unknown, meta: RequestMeta): Promise<LiveBlockedWordsDto> {
    if ((await this.prisma.liveHost.count({ where: { userId } })) === 0) {
      throw new AppException(ErrorCode.LIVE_HOSTING_NOT_ALLOWED);
    }
    const parsed = setLiveBlockedWordsSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { words } = parsed.data;
    const saved = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.liveHost.update({
        where: { userId },
        data: { blockedWords: words },
        select: { blockedWords: true },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_BLOCKED_WORDS_UPDATE,
        actorUserId: userId,
        targetType: 'user',
        targetId: userId,
        metadata: { count: words.length },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      return updated;
    });
    return { words: saved.blockedWords };
  }

  /** The words to mask in [hostUserId]'s rooms (none without the hosting permission). */
  async wordsOf(hostUserId: string): Promise<string[]> {
    const host = await this.prisma.liveHost.findUnique({
      where: { userId: hostUserId },
      select: { blockedWords: true },
    });
    return host?.blockedWords ?? [];
  }
}
