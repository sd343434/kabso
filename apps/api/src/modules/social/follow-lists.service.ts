import { Inject, Injectable } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import { SocialCursorCodec, type SocialPosition } from '../posts/social-cursor.js';
import { UsersService } from '../users/users.service.js';
import type { FollowListQuery } from './follows.schemas.js';

/** `FollowListItem` (openapi v1.25.2-live, D121): a `UserSummary` plus the reader's relation. */
export interface FollowListItemDto extends UserSummaryDto {
  /** The row is the reader. */
  isSelf: boolean;
  /** The listed account is private (v1.47-social: a new follow is a request, §10.47). */
  isPrivate: boolean;
  /** v1.47-social (D175): the reader has a pending follow request to the listed account. */
  requestedByMe: boolean;
  /** The reader follows the listed account (false when `isSelf`). */
  followedByMe: boolean;
  /** The listed account follows the reader (false when `isSelf`). */
  followsMe: boolean;
}

export type FollowListKind = 'followers' | 'following';

/**
 * The accounts counted on a profile and listed by `GET /users/{username}/followers|following`:
 * the other side of the edge is ACTIVE (D121). A suspended or deleted account is neither counted
 * nor listed (deletion also removes its rows).
 */
export const ACTIVE_COUNTERPART = { status: 'ACTIVE' } as const satisfies Prisma.UserWhereInput;

/**
 * Follower and following lists (CONVENTIONS §10.6, D121). The target must be ACTIVE and have no
 * block either way with the reader (else 404, like `GET /users/{username}/posts`); a private
 * target's lists are its own and its followers' only (else 403). Rows are the edges, newest
 * follow first (`created_at` desc, then the other user's id desc; D125 `order=oldest` reverses
 * both), keyset-paged with the social cursor bound to the list, the target and the reader (and,
 * D125, the order and the search). Rows whose account is not ACTIVE, or has a block either way
 * with the reader, are left out; D125 `q` keeps those whose username or display name starts
 * with it (case-insensitive).
 */
@Injectable()
export class FollowListsService {
  private readonly cursors: SocialCursorCodec;

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    @Inject(APP_CONFIG) config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  private async readableTarget(viewerId: string, username: string): Promise<string> {
    const user = await this.users.findActivePublicUser(username);
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    if (user.id === viewerId) return user.id;
    const [blocks, follows] = await Promise.all([
      this.prisma.userBlock.count({
        where: {
          OR: [
            { blockerId: viewerId, blockedId: user.id },
            { blockerId: user.id, blockedId: viewerId },
          ],
        },
      }),
      user.isPrivate ? this.prisma.follow.count({ where: { followerId: viewerId, followeeId: user.id } }) : 1,
    ]);
    if (blocks > 0) throw new AppException(ErrorCode.NOT_FOUND);
    if (follows === 0) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    return user.id;
  }

  async list(
    viewerId: string,
    username: string,
    kind: FollowListKind,
    query: FollowListQuery,
  ): Promise<PageDto<FollowListItemDto>> {
    const targetId = await this.readableTarget(viewerId, username);
    const q = query.q?.toLowerCase();
    // Prisma hands `startsWith` to LIKE unescaped: `%`, `_` and the backslash must match themselves.
    const prefix = q?.replace(/[\\%_]/g, (c) => `\\${c}`);
    // D125: the D121 scope for the default list (cursors already issued stay valid); a search or
    // the oldest-first order binds the cursor to them too.
    const base = `${kind}:${targetId}:${viewerId}`;
    const scope = q === undefined && query.order === 'newest' ? base : `${base}:${query.order}:${q ?? ''}`;
    let after: SocialPosition | null = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const visible: Prisma.UserWhereInput = {
      ...ACTIVE_COUNTERPART,
      blocking: { none: { blockedId: viewerId } },
      blockedBy: { none: { blockerId: viewerId } },
      // D125: a case-insensitive prefix of the username or the display name.
      ...(prefix === undefined
        ? {}
        : {
            profile: {
              OR: [
                { username: { startsWith: prefix, mode: 'insensitive' } },
                { displayName: { startsWith: prefix, mode: 'insensitive' } },
              ],
            },
          }),
    };
    const desc = query.order === 'newest';
    const dir: Prisma.SortOrder = desc ? 'desc' : 'asc';
    /** The keys past the cursor in the list's order. */
    const past = <T>(v: T) => (desc ? { lt: v } : { gt: v });
    const person = { select: { ...USER_SUMMARY_SELECT, settings: { select: { isPrivate: true } } } } as const;
    const people =
      kind === 'followers'
        ? (
            await this.prisma.follow.findMany({
              where: {
                followeeId: targetId,
                follower: visible,
                ...(after
                  ? {
                      OR: [
                        { createdAt: past(after.at) },
                        { createdAt: after.at, followerId: past(after.id) },
                      ],
                    }
                  : {}),
              },
              orderBy: [{ createdAt: dir }, { followerId: dir }],
              take: query.limit + 1,
              select: { createdAt: true, follower: person },
            })
          ).map((r) => ({ at: r.createdAt, user: r.follower }))
        : (
            await this.prisma.follow.findMany({
              where: {
                followerId: targetId,
                followee: visible,
                ...(after
                  ? {
                      OR: [
                        { createdAt: past(after.at) },
                        { createdAt: after.at, followeeId: past(after.id) },
                      ],
                    }
                  : {}),
              },
              orderBy: [{ createdAt: dir }, { followeeId: dir }],
              take: query.limit + 1,
              select: { createdAt: true, followee: person },
            })
          ).map((r) => ({ at: r.createdAt, user: r.followee }));
    const hasMore = people.length > query.limit;
    people.splice(query.limit);
    const ids = people.map((p) => p.user.id).filter((id) => id !== viewerId);
    const [mine, theirs, requested] = ids.length
      ? await Promise.all([
          this.prisma.follow.findMany({
            where: { followerId: viewerId, followeeId: { in: ids } },
            select: { followeeId: true },
          }),
          this.prisma.follow.findMany({
            where: { followeeId: viewerId, followerId: { in: ids } },
            select: { followerId: true },
          }),
          this.prisma.followRequest.findMany({
            where: { requesterId: viewerId, targetId: { in: ids } },
            select: { targetId: true },
          }),
        ])
      : [[], [], []];
    const requestedByMe = new Set(requested.map((r) => r.targetId));
    const followedByMe = new Set(mine.map((f) => f.followeeId));
    const followsMe = new Set(theirs.map((f) => f.followerId));
    const last = people[people.length - 1];
    return {
      data: people.map(({ user }) => ({
        ...userSummary(user),
        isSelf: user.id === viewerId,
        isPrivate: user.settings?.isPrivate ?? false,
        followedByMe: followedByMe.has(user.id),
        requestedByMe: requestedByMe.has(user.id),
        followsMe: followsMe.has(user.id),
      })),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.at, id: last.user.id }) : null,
      },
    };
  }
}
