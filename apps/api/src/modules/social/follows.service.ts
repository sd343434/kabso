import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { isValidUsername } from '../users/username.js';
import { UsersService } from '../users/users.service.js';

/** `FollowState` (openapi v1.3). */
export interface FollowStateDto {
  isFollowing: boolean;
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
   * (v1.3.1, QA-002: the existing-edge check comes before the private check); a new follow of a
   * private target → 403.
   */
  async follow(callerId: string, username: string): Promise<FollowStateDto> {
    assertWellFormed(username);
    return this.prisma.$transaction(async (tx) => {
      const target = await this.lockPair(tx, callerId, username);
      const existing = await tx.follow.count({ where: { followerId: callerId, followeeId: target.id } });
      if (existing === 0) {
        // v1.3: no follow requests yet, so private accounts cannot gain new followers.
        if (target.isPrivate) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
        await tx.follow.createMany({
          data: [{ followerId: callerId, followeeId: target.id }],
          skipDuplicates: true,
        });
      }
      return {
        isFollowing: true,
        followerCount: await tx.follow.count({ where: { followeeId: target.id } }),
      };
    });
  }

  /** `DELETE /users/{username}/follow`: a missing edge is a no-op (200); private targets allowed. */
  async unfollow(callerId: string, username: string): Promise<FollowStateDto> {
    assertWellFormed(username);
    return this.prisma.$transaction(async (tx) => {
      const target = await this.lockPair(tx, callerId, username);
      await tx.follow.deleteMany({ where: { followerId: callerId, followeeId: target.id } });
      return {
        isFollowing: false,
        followerCount: await tx.follow.count({ where: { followeeId: target.id } }),
      };
    });
  }

  async counts(userId: string): Promise<FollowCounts> {
    const [followerCount, followingCount] = await Promise.all([
      this.prisma.follow.count({ where: { followeeId: userId } }),
      this.prisma.follow.count({ where: { followerId: userId } }),
    ]);
    return { followerCount, followingCount };
  }

  async isFollowing(followerId: string, followeeId: string): Promise<boolean> {
    if (followerId === followeeId) return false;
    return (await this.prisma.follow.count({ where: { followerId, followeeId } })) > 0;
  }

  /**
   * Soft deletion (DB_PHASE2_DISCOVERY §3): deletes the user's follow rows in both directions
   * inside the caller's transaction (FK cascades only fire on hard deletion). Returns rows removed.
   */
  async deleteAllEdgesOfIn(tx: Prisma.TransactionClient, userId: string): Promise<number> {
    const removed = await tx.follow.deleteMany({
      where: { OR: [{ followerId: userId }, { followeeId: userId }] },
    });
    return removed.count;
  }
}
