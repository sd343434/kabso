import { Injectable } from '@nestjs/common';
import { AppException } from '../../../common/errors/app-exception.js';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { ErrorCode } from '../../../common/errors/error-codes.js';
import { LiveRoomsService } from '../../live/live-rooms.service.js';
import { FollowsService } from '../../social/follows.service.js';
import { UsersService } from '../users.service.js';

/** `PublicProfile` (openapi v1.3). Never an email, role, status, locale or created-at time. */
export interface PublicProfileDto {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  bio: string | null;
  isPrivate: boolean;
  followerCount: number;
  followingCount: number;
  isFollowing: boolean;
  /** CP-007: the caller's own mute of this user; the muted user is never told. */
  isMuted: boolean;
  isSelf: boolean;
  liveRoomId: string | null;
}

/**
 * `GET /users/{username}` (CONVENTIONS §10.5). Composes the users module (identity), social
 * (counts, isFollowing) and live (`liveRoomId`) through their services. Lives in its own module so
 * that `live` and `social` can depend on `users` without a cycle.
 */
@Injectable()
export class PublicProfileService {
  constructor(
    private readonly users: UsersService,
    private readonly follows: FollowsService,
    private readonly live: LiveRoomsService,
    private readonly prisma: PrismaService,
  ) {}

  /** Whether [callerId] muted [targetId] (primary-key lookup). */
  private async isMuted(callerId: string, targetId: string): Promise<boolean> {
    const row = await this.prisma.userMute.findUnique({
      where: { muterId_mutedId: { muterId: callerId, mutedId: targetId } },
      select: { muterId: true },
    });
    return row !== null;
  }

  async get(callerId: string, username: string): Promise<PublicProfileDto> {
    const user = await this.users.findActivePublicUser(username);
    // Malformed, unknown, pending-only, SUSPENDED and DELETED: the same 404 body.
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    const isSelf = user.id === callerId;
    const [counts, isFollowing, isMuted, liveRoomId] = await Promise.all([
      this.follows.counts(user.id),
      isSelf ? Promise.resolve(false) : this.follows.isFollowing(callerId, user.id),
      isSelf ? Promise.resolve(false) : this.isMuted(callerId, user.id),
      this.live.freshLiveRoomIdOf(user.id),
    ]);
    return {
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      bio: user.bio,
      isPrivate: user.isPrivate,
      followerCount: counts.followerCount,
      followingCount: counts.followingCount,
      isFollowing,
      isMuted,
      isSelf,
      liveRoomId,
    };
  }
}
