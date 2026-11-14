import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { Notifier } from '../notifications/notifier.js';
import { isValidUsername } from '../users/username.js';
import { UsersService } from '../users/users.service.js';
import { ACTIVE_COUNTERPART } from './follow-lists.service.js';
import { withdrawFollowRequestIn } from './follow-requests.js';
import { blockedEitherWayIn, lockUserPairIn } from './pair-lock.js';

/** `FollowState` (openapi v1.3). */
export interface FollowStateDto {
  isFollowing: boolean;
  /** v1.47-social (D175): the caller has a pending request to follow this private account. */
  isRequested: boolean;
  followerCount: number;
}

/** `FollowerRemoval` (v1.26.1-live, D125). */
export interface FollowerRemovalDto {
  /** Always false: the user no longer follows the caller. */
  followsMe: false;
  /** The caller's follower count after the removal (ACTIVE followers, like the profile). */
  followerCount: number;
}

export interface FollowCounts {
  followerCount: number;
  followingCount: number;
}

/**
 * SEC-037: a path username that is not well-formed (§6 pattern and length; e.g. one containing a
 * NUL byte) is the contract's 404 and never reaches the database.
 */
function assertWellFormed(username: string): void {
  if (!isValidUsername(username)) throw new AppException(ErrorCode.NOT_FOUND);
}

/**
 * Follow graph (`follows`, owned by the social module; CONVENTIONS §10.5–10.6). Writes are
 * idempotent at the database level (`ON CONFLICT DO NOTHING` / plain DELETE); the target's ACTIVE
 * status and `is_private` are checked under a row lock in the same transaction as the write.
 * Counts are computed on read (v1.3). No per-edge audit (high volume, low risk).
 */
@Injectable()
export class FollowsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly notifier: Notifier,
  ) {}

  /**
   * Locks the caller and the target (both must be ACTIVE) and applies the shared rules: unknown /
   * suspended / deleted / malformed target → 404; the caller's own username → 400.
   */
  private async lockPair(tx: Prisma.TransactionClient, callerId: string, username: string) {
    if (!(await this.users.lockActiveById(tx, callerId)))
      throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    const target = await this.users.lockActiveByUsername(tx, username);
    if (!target) throw new AppException(ErrorCode.NOT_FOUND);
    if (target.id === callerId) {
      throw AppException.validation([{ field: 'username', issue: 'invalid_value' }]);
    }
    return target;
  }

  /**
   * `PUT /users/{username}/follow`: an existing edge is a no-op (200), also on a private target
   * (v1.3.1, QA-002: the existing-edge check comes before the private check). v1.47-social (D175,
   * §10.47): a new follow of a private target creates a follow request instead (idempotent; the
   * owner gets a FOLLOW_REQUEST notification) and answers `{isFollowing: false, isRequested: true}`.
   */
  async follow(callerId: string, username: string): Promise<FollowStateDto> {
    assertWellFormed(username);
    return this.prisma.$transaction(async (tx) => {
      const target = await this.lockPair(tx, callerId, username);
      // v1.5-social §11.7: while a block exists either way, the target is not found.
      await lockUserPairIn(tx, callerId, target.id);
      if (await blockedEitherWayIn(tx, callerId, target.id)) throw new AppException(ErrorCode.NOT_FOUND);
      const existing = await tx.follow.count({ where: { followerId: callerId, followeeId: target.id } });
      let requested = false;
      if (existing === 0 && target.isPrivate) {
        const { count } = await tx.followRequest.createMany({
          data: [{ requesterId: callerId, targetId: target.id }],
          skipDuplicates: true,
        });
        if (count > 0) {
          await this.notifier.notify(tx, {
            type: 'FOLLOW_REQUEST',
            recipientId: target.id,
            actorId: callerId,
          });
        }
        requested = true;
      } else if (existing === 0) {
        const { count } = await tx.follow.createMany({
          data: [{ followerId: callerId, followeeId: target.id }],
          skipDuplicates: true,
        });
        if (count > 0) {
          await this.notifier.notify(tx, { type: 'FOLLOW', recipientId: target.id, actorId: callerId });
        }
      }
      return {
        isFollowing: !requested,
        isRequested: requested,
        followerCount: await tx.follow.count({
          where: { followeeId: target.id, follower: ACTIVE_COUNTERPART },
        }),
      };
    });
  }

  /**
   * `DELETE /users/{username}/follow`: a missing edge is a no-op (200); private targets allowed.
   * v1.47-social (D175): also cancels the caller's pending follow request (its notification goes).
   */
  async unfollow(callerId: string, username: string): Promise<FollowStateDto> {
    assertWellFormed(username);
    return this.prisma.$transaction(async (tx) => {
      const target = await this.lockPair(tx, callerId, username);
      const { count } = await tx.follow.deleteMany({
        where: { followerId: callerId, followeeId: target.id },
      });
      if (count > 0) {
        await this.notifier.undo(tx, { type: 'FOLLOW', recipientId: target.id, actorId: callerId });
      }
      await withdrawFollowRequestIn(tx, this.notifier, callerId, target.id);
      return {
        isFollowing: false,
        isRequested: false,
        followerCount: await tx.follow.count({
          where: { followeeId: target.id, follower: ACTIVE_COUNTERPART },
        }),
      };
    });
  }

  /**
   * D125 `DELETE /me/followers/{username}`: removes the edge `username` → caller. A missing edge
   * is a no-op (200); the same 404 / 400 rules as `unfollow` (the other account must be ACTIVE,
   * never the caller). The follow notification it sent is withdrawn, as on an unfollow. They
   * can follow again later (v1.47-social: by a follow request while the caller is private).
   */
  async removeFollower(callerId: string, username: string): Promise<FollowerRemovalDto> {
    assertWellFormed(username);
    return this.prisma.$transaction(async (tx) => {
      const follower = await this.lockPair(tx, callerId, username);
      const { count } = await tx.follow.deleteMany({
        where: { followerId: follower.id, followeeId: callerId },
      });
      if (count > 0) {
        await this.notifier.undo(tx, { type: 'FOLLOW', recipientId: callerId, actorId: follower.id });
      }
      return {
        followsMe: false,
        followerCount: await tx.follow.count({
          where: { followeeId: callerId, follower: ACTIVE_COUNTERPART },
        }),
      };
    });
  }

  /**
   * D121: only edges whose other side is ACTIVE count, the same rows the follower and following
   * lists show (the lists also leave out accounts with a block either way with the reader).
   */
  async counts(userId: string): Promise<FollowCounts> {
    const [followerCount, followingCount] = await Promise.all([
      this.prisma.follow.count({ where: { followeeId: userId, follower: ACTIVE_COUNTERPART } }),
      this.prisma.follow.count({ where: { followerId: userId, followee: ACTIVE_COUNTERPART } }),
    ]);
    return { followerCount, followingCount };
  }

  async isFollowing(followerId: string, followeeId: string): Promise<boolean> {
    if (followerId === followeeId) return false;
    return (await this.prisma.follow.count({ where: { followerId, followeeId } })) > 0;
  }

  /** v1.47-social (D175): whether `requesterId` has a pending follow request to `targetId`. */
  async isRequested(requesterId: string, targetId: string): Promise<boolean> {
    if (requesterId === targetId) return false;
    return (await this.prisma.followRequest.count({ where: { requesterId, targetId } })) > 0;
  }

  /**
   * Soft deletion (DB_PHASE2_DISCOVERY §3): deletes the user's follow rows in both directions
   * inside the caller's transaction (FK cascades only fire on hard deletion). Returns rows removed.
   */
  async deleteAllEdgesOfIn(tx: Prisma.TransactionClient, userId: string): Promise<number> {
    const removed = await tx.follow.deleteMany({
      where: { OR: [{ followerId: userId }, { followeeId: userId }] },
    });
    // v1.47-social (D175): pending follow requests both ways go too.
    await tx.followRequest.deleteMany({ where: { OR: [{ requesterId: userId }, { targetId: userId }] } });
    return removed.count;
  }
}
