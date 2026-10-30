import { Inject, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { Notifier } from '../notifications/notifier.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import type { PageQuery } from '../posts/posts.schemas.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { isValidUsername } from '../users/username.js';
import { UsersService } from '../users/users.service.js';
import { ACTIVE_COUNTERPART } from './follow-lists.service.js';

type Tx = Prisma.TransactionClient;

/** `FollowRequest` (v1.47-social, D175). */
export interface FollowRequestDto {
  user: UserSummaryDto;
  requestedAt: string;
}

/** `FollowRequestPage`: a page plus `total`, every pending request the list would show. */
export interface FollowRequestPageDto extends PageDto<FollowRequestDto> {
  total: number;
}

/** `FollowRequestAccepted` (v1.47-social, D175). */
export interface FollowRequestAcceptedDto {
  /** Always true: the requester follows the caller now. */
  followsMe: true;
  /** The caller's follower count after (ACTIVE followers, like the profile). */
  followerCount: number;
}

/**
 * Deletes `requesterId`'s pending request to `targetId` (cancel, decline, block) and withdraws its
 * FOLLOW_REQUEST notification. Returns whether a request was pending.
 */
export async function withdrawFollowRequestIn(
  tx: Tx,
  notifier: Notifier,
  requesterId: string,
  targetId: string,
): Promise<boolean> {
  const { count } = await tx.followRequest.deleteMany({ where: { requesterId, targetId } });
  if (count > 0) {
    await notifier.undo(tx, { type: 'FOLLOW_REQUEST', recipientId: targetId, actorId: requesterId });
  }
  return count > 0;
}

/**
 * v1.47-social (D175, §10.43): switching a private account to public accepts every pending request
 * to it: each requester follows the account from now on (existing rows are kept), the requests and
 * their FOLLOW_REQUEST notifications go. One statement each, whatever the number of requests; the
 * requesters are not notified one by one (their profiles simply show Following). Returns how many
 * were accepted. The caller holds the account's lock.
 */
export async function acceptAllFollowRequestsIn(tx: Tx, targetId: string): Promise<number> {
  const accepted = await tx.$executeRaw`
    INSERT INTO follows (follower_id, followee_id, created_at)
    SELECT r.requester_id, r.target_id, now() FROM follow_requests r WHERE r.target_id = ${targetId}::uuid
    ON CONFLICT DO NOTHING`;
  await tx.followRequest.deleteMany({ where: { targetId } });
  await tx.notification.deleteMany({ where: { recipientId: targetId, type: 'FOLLOW_REQUEST' } });
  return accepted;
}

/** Who may appear in the caller's request list: ACTIVE and no block either way. */
function listedRequester(ownerId: string): Prisma.UserWhereInput {
  return {
    ...ACTIVE_COUNTERPART,
    blocking: { none: { blockedId: ownerId } },
    blockedBy: { none: { blockerId: ownerId } },
  };
}

/**
 * Follow requests to the caller's private account (v1.47-social, D175, CONVENTIONS §10.43): the
 * list (newest first), accept (→ a follow, FOLLOW_REQUEST_ACCEPTED to the requester) and decline
 * (deleted; the requester is not told). Writes lock both accounts as follows do.
 */
@Injectable()
export class FollowRequestsService {
  private readonly cursors: SocialCursorCodec;

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly notifier: Notifier,
    @Inject(APP_CONFIG) config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  /** `GET /me/follow-requests`: newest request first; keyset on (time, requester id). */
  async list(ownerId: string, query: PageQuery): Promise<FollowRequestPageDto> {
    const scope = `follow-requests:${ownerId}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const where: Prisma.FollowRequestWhereInput = { targetId: ownerId, requester: listedRequester(ownerId) };
    const [rows, total] = await Promise.all([
      this.prisma.followRequest.findMany({
        where: {
          ...where,
          ...(after
            ? {
                OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, requesterId: { lt: after.id } }],
              }
            : {}),
        },
        orderBy: [{ createdAt: 'desc' }, { requesterId: 'desc' }],
        take: query.limit + 1,
        select: { createdAt: true, requesterId: true, requester: { select: USER_SUMMARY_SELECT } },
      }),
      this.prisma.followRequest.count({ where }),
    ]);
    const hasMore = rows.length > query.limit;
    const pageRows = rows.slice(0, query.limit);
    const last = pageRows[pageRows.length - 1];
    return {
      data: pageRows.map((r) => ({ user: userSummary(r.requester), requestedAt: r.createdAt.toISOString() })),
      page: {
        hasMore,
        nextCursor:
          hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.requesterId }) : null,
      },
      total,
    };
  }

  /** Locks the caller and the requester (ACTIVE; malformed, unknown, inactive → 404; self → 400). */
  private async lockRequester(tx: Tx, ownerId: string, username: string): Promise<string> {
    if (!isValidUsername(username)) throw new AppException(ErrorCode.NOT_FOUND);
    if (!(await this.users.lockActiveById(tx, ownerId)))
      throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    const requester = await this.users.lockActiveByUsername(tx, username);
    if (!requester) throw new AppException(ErrorCode.NOT_FOUND);
    if (requester.id === ownerId)
      throw AppException.validation([{ field: 'username', issue: 'invalid_value' }]);
    return requester.id;
  }

  private followerCountIn(tx: Tx, ownerId: string): Promise<number> {
    return tx.follow.count({ where: { followeeId: ownerId, follower: ACTIVE_COUNTERPART } });
  }

  /**
   * `POST /me/follow-requests/{username}/accept`: the requester follows the caller. Already a
   * follower → 200 (idempotent); no pending request otherwise → 409 `FOLLOW_REQUEST_NOT_PENDING`.
   */
  async accept(ownerId: string, username: string): Promise<FollowRequestAcceptedDto> {
    return this.prisma.$transaction(async (tx) => {
      const requesterId = await this.lockRequester(tx, ownerId, username);
      const pending = await withdrawFollowRequestIn(tx, this.notifier, requesterId, ownerId);
      if (!pending) {
        const follows = await tx.follow.count({ where: { followerId: requesterId, followeeId: ownerId } });
        if (follows === 0) throw new AppException(ErrorCode.FOLLOW_REQUEST_NOT_PENDING);
        return { followsMe: true, followerCount: await this.followerCountIn(tx, ownerId) };
      }
      const { count } = await tx.follow.createMany({
        data: [{ followerId: requesterId, followeeId: ownerId }],
        skipDuplicates: true,
      });
      if (count > 0) {
        await this.notifier.notify(tx, {
          type: 'FOLLOW_REQUEST_ACCEPTED',
          recipientId: requesterId,
          actorId: ownerId,
        });
      }
      return { followsMe: true, followerCount: await this.followerCountIn(tx, ownerId) };
    });
  }

  /** `POST /me/follow-requests/{username}/decline`: deleted; idempotent (none pending → 204 too). */
  async decline(ownerId: string, username: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const requesterId = await this.lockRequester(tx, ownerId, username);
      await withdrawFollowRequestIn(tx, this.notifier, requesterId, ownerId);
    });
  }
}
