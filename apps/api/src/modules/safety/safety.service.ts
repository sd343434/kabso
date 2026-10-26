import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { readableCpConfession, removeCpConfessionIn } from '../cp-space/cp-confessions.js';
import { readableFamilyChatMessage, removeFamilyChatMessageIn } from '../families/family-chat.js';
import { LiveChatService } from '../live/live-chat.service.js';
import { LiveMediaService } from '../live/live-media.service.js';
import { LiveRoomsService } from '../live/live-rooms.service.js';
import { LiveSeatsService } from '../live/live-seats.service.js';
import { bumpRoomsSeatingBothIn } from '../live/live-seats.store.js';
import { Notifier } from '../notifications/notifier.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { isUuid } from '../live/live.schemas.js';
import type { AdminActor } from '../levels/level-config.service.js';
import { CommentsService } from '../posts/comments.service.js';
import { USER_SUMMARY_SELECT, userSummary, visiblePostWhere, type PageDto } from '../posts/post-views.js';
import type { PageQuery } from '../posts/posts.schemas.js';
import { PostsService } from '../posts/posts.service.js';
import { lockUserPairIn } from '../social/pair-lock.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import {
  createReportSchema,
  reportActionSchema,
  updatePrivacySchema,
  type AdminReportsQuery,
  type CreateReportInput,
} from './safety.schemas.js';
import { visibleStoryWhere } from '../stories/stories.service.js';

type Tx = Prisma.TransactionClient;

/** `Report` (openapi v1.5-social); `reporter` in admin views only. */
export interface ReportDto {
  id: string;
  targetType:
    | 'POST'
    | 'COMMENT'
    | 'STORY'
    | 'USER'
    | 'LIVE_ROOM'
    | 'LIVE_CHAT_MESSAGE'
    | 'CP_CONFESSION'
    | 'FAMILY_CHAT_MESSAGE';
  targetId: string;
  reason: string;
  note: string | null;
  status: 'OPEN' | 'ACTIONED' | 'DISMISSED';
  createdAt: string;
  resolvedAt: string | null;
  reporter?: UserSummaryDto;
}

export interface PrivacyDto {
  whoCanMention: 'EVERYONE' | 'FOLLOWING' | 'NOBODY';
  defaultWhoCanComment: 'EVERYONE' | 'FOLLOWERS' | 'NOBODY';
  /** v1.25-live (CP-022): others may see when the user was last active (§10.25). */
  showActivityStatus: boolean;
}

const REPORT_INCLUDE = {
  reporter: { select: USER_SUMMARY_SELECT },
  targetUser: { select: { profile: { select: { username: true } } } },
} satisfies Prisma.ReportInclude;

type ReportRow = Prisma.ReportGetPayload<{ include: typeof REPORT_INCLUDE }>;

/**
 * Block, mute, hide, reports with the admin queue, and privacy settings (CONVENTIONS §11.7).
 * Block and follow writes between two users are serialized by a pair lock, so no follow survives
 * a block.
 */
@Injectable()
export class SafetyService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly posts: PostsService,
    private readonly comments: CommentsService,
    private readonly audit: AuditService,
    private readonly notifier: Notifier,
    private readonly liveRooms: LiveRoomsService,
    private readonly liveMedia: LiveMediaService,
    private readonly liveSeats: LiveSeatsService,
    private readonly liveChat: LiveChatService,
  ) {}

  // ---------------------------------------------------------------------------------------------
  // Block and mute

  /** The ACTIVE target of a block/mute by username (404), never the caller (400 `username`). */
  private async target(tx: Tx, callerId: string, username: string): Promise<string> {
    if (!(await this.users.lockActiveById(tx, callerId)))
      throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    const target = await this.users.lockActiveByUsername(tx, username);
    if (!target) throw new AppException(ErrorCode.NOT_FOUND);
    if (target.id === callerId)
      throw AppException.validation([{ field: 'username', issue: 'invalid_value' }]);
    return target.id;
  }

  /** `PUT /users/{username}/block`: also deletes follows both ways (not restored by unblock). */
  async block(callerId: string, username: string, blocked: boolean): Promise<{ blocked: boolean }> {
    const targetId = await this.prisma.$transaction(async (tx) => {
      const targetId = await this.target(tx, callerId, username);
      await lockUserPairIn(tx, callerId, targetId);
      if (blocked) {
        await tx.userBlock.createMany({
          data: [{ blockerId: callerId, blockedId: targetId }],
          skipDuplicates: true,
        });
        await tx.follow.deleteMany({
          where: {
            OR: [
              { followerId: callerId, followeeId: targetId },
              { followerId: targetId, followeeId: callerId },
            ],
          },
        });
      } else {
        await tx.userBlock.deleteMany({ where: { blockerId: callerId, blockedId: targetId } });
      }
      // v1.23.3-live (D111): a block between CP partners hides their joined seats (§10.9).
      const partners = await tx.cpPartner.count({ where: { userId: callerId, partnerId: targetId } });
      if (partners > 0) await bumpRoomsSeatingBothIn(tx, callerId, targetId);
      return targetId;
    });
    // CP-011 (§10.9): a block with a live host ends the other user's seat, request, invitation and
    // moderator role in that host's room.
    if (blocked) await this.liveSeats.onBlock(callerId, targetId);
    return { blocked };
  }

  /** `GET /me/blocks`: newest first. */
  async blocks(callerId: string, query: PageQuery): Promise<PageDto<UserSummaryDto>> {
    const scope = `blocks:${callerId}`;
    const after = this.posts.decode(query.cursor, scope);
    const rows = await this.prisma.userBlock.findMany({
      where: {
        blockerId: callerId,
        ...(after
          ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, blockedId: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { blockedId: 'desc' }],
      take: query.limit + 1,
      select: { createdAt: true, blockedId: true, blocked: { select: USER_SUMMARY_SELECT } },
    });
    const hasMore = rows.length > query.limit;
    const pageRows = rows.slice(0, query.limit);
    const last = pageRows[pageRows.length - 1];
    return {
      data: pageRows.map((r) => userSummary(r.blocked)),
      page: {
        hasMore,
        nextCursor:
          hasMore && last
            ? this.posts.cursors.encode(scope, { at: last.createdAt, id: last.blockedId })
            : null,
      },
    };
  }

  /**
   * `GET /me/mutes` (CP-007): newest first; every muted account, like `/me/blocks` (the caller
   * must be able to unmute any of them). Only the caller's own mutes.
   */
  async mutes(callerId: string, query: PageQuery): Promise<PageDto<UserSummaryDto>> {
    const scope = `mutes:${callerId}`;
    const after = this.posts.decode(query.cursor, scope);
    const rows = await this.prisma.userMute.findMany({
      where: {
        muterId: callerId,
        ...(after
          ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, mutedId: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { mutedId: 'desc' }],
      take: query.limit + 1,
      select: { createdAt: true, mutedId: true, muted: { select: USER_SUMMARY_SELECT } },
    });
    const hasMore = rows.length > query.limit;
    const pageRows = rows.slice(0, query.limit);
    const last = pageRows[pageRows.length - 1];
    return {
      data: pageRows.map((r) => userSummary(r.muted)),
      page: {
        hasMore,
        nextCursor:
          hasMore && last ? this.posts.cursors.encode(scope, { at: last.createdAt, id: last.mutedId }) : null,
      },
    };
  }

  /** `PUT`/`DELETE /users/{username}/mute`: one-way and silent. */
  async mute(callerId: string, username: string, muted: boolean): Promise<{ muted: boolean }> {
    await this.prisma.$transaction(async (tx) => {
      const targetId = await this.target(tx, callerId, username);
      if (muted) {
        await tx.userMute.createMany({
          data: [{ muterId: callerId, mutedId: targetId }],
          skipDuplicates: true,
        });
      } else {
        await tx.userMute.deleteMany({ where: { muterId: callerId, mutedId: targetId } });
      }
    });
    return { muted };
  }

  // ---------------------------------------------------------------------------------------------
  // Hide

  /** `PUT`/`DELETE /posts/{postId}/hide`: a post the caller may see (404 otherwise). */
  async hide(callerId: string, postId: string, hidden: boolean): Promise<void> {
    if (!isUuid(postId)) throw new AppException(ErrorCode.NOT_FOUND);
    const post = await this.prisma.post.findFirst({
      where: { AND: [{ id: postId.toLowerCase() }, visiblePostWhere(callerId)] },
      select: { id: true },
    });
    if (!post) throw new AppException(ErrorCode.NOT_FOUND);
    if (hidden) {
      await this.prisma.postHide.createMany({
        data: [{ userId: callerId, postId: post.id }],
        skipDuplicates: true,
      });
    } else {
      await this.prisma.postHide.deleteMany({ where: { userId: callerId, postId: post.id } });
    }
  }

  // ---------------------------------------------------------------------------------------------
  // Reports

  /**
   * `POST /reports`: one OPEN report per reporter and target; a repeat returns it (`created`
   * false → 200). The target must be visible to the reporter and not the reporter's own.
   */
  async report(reporterId: string, body: unknown): Promise<{ report: ReportDto; created: boolean }> {
    const parsed = createReportSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const target = await this.resolveTarget(reporterId, input);
    const where: Prisma.ReportWhereInput = { reporterId, status: 'OPEN', ...target };
    const existing = await this.prisma.report.findFirst({ where, include: REPORT_INCLUDE });
    if (existing) return { report: this.toDto(existing, false), created: false };
    try {
      const row = await this.prisma.report.create({
        data: {
          reporterId,
          targetType: input.targetType,
          reason: input.reason,
          note: input.note ?? null,
          ...target,
        },
        include: REPORT_INCLUDE,
      });
      return { report: this.toDto(row, false), created: true };
    } catch (err) {
      // A concurrent identical report won (partial unique index): return it.
      if (violatedUniqueIndex(err) !== null) {
        const raced = await this.prisma.report.findFirst({ where, include: REPORT_INCLUDE });
        if (raced) return { report: this.toDto(raced, false), created: false };
      }
      throw err;
    }
  }

  private async resolveTarget(
    reporterId: string,
    input: CreateReportInput,
  ): Promise<
    | { targetPostId: string }
    | { targetCommentId: string }
    | { targetUserId: string }
    | { targetStoryId: string }
    | { targetLiveRoomId: string }
    | { targetLiveChatMessageId: string }
    | { targetCpConfessionId: string }
    | { targetFamilyChatMessageId: string }
  > {
    const invalid = () => AppException.validation([{ field: 'targetId', issue: 'invalid_value' }]);
    if (input.targetType === 'USER') {
      const user = await this.users.findActivePublicUser(input.targetId);
      if (!user) throw new AppException(ErrorCode.NOT_FOUND);
      if (user.id === reporterId) throw invalid();
      return { targetUserId: user.id };
    }
    if (!isUuid(input.targetId)) throw new AppException(ErrorCode.NOT_FOUND);
    const id = input.targetId.toLowerCase();
    if (input.targetType === 'LIVE_ROOM') {
      // CP-010: a room the reporter can see (live or ended), not their own.
      const room = await this.liveRooms.visibleRow(id, reporterId);
      if (room.host_user_id === reporterId) throw invalid();
      return { targetLiveRoomId: room.id };
    }
    if (input.targetType === 'LIVE_CHAT_MESSAGE') {
      // CP-013: a message the reporter could read (§10.11), not their own.
      const message = await this.liveChat.readableMessage(id, reporterId);
      if (message.userId === reporterId) throw invalid();
      return { targetLiveChatMessageId: message.id };
    }
    if (input.targetType === 'CP_CONFESSION') {
      // CP-021: a confession the reporter could read (§10.24), not their own.
      const confession = await readableCpConfession(this.prisma, id, reporterId);
      if (confession.authorId === reporterId) throw invalid();
      return { targetCpConfessionId: confession.id };
    }
    if (input.targetType === 'FAMILY_CHAT_MESSAGE') {
      // CP-022: a message in the reporter's family chat (§10.25), not their own.
      const message = await readableFamilyChatMessage(this.prisma, id, reporterId);
      if (message.authorId === reporterId) throw invalid();
      return { targetFamilyChatMessageId: message.id };
    }
    if (input.targetType === 'STORY') {
      // CP-008: an active story the reporter may see (expired stories can no longer be seen).
      const story = await this.prisma.story.findFirst({
        where: { AND: [{ id, expiresAt: { gt: new Date() } }, visibleStoryWhere(reporterId)] },
        select: { id: true, authorId: true },
      });
      if (!story) throw new AppException(ErrorCode.NOT_FOUND);
      if (story.authorId === reporterId) throw invalid();
      return { targetStoryId: story.id };
    }
    if (input.targetType === 'POST') {
      const post = await this.prisma.post.findFirst({
        where: { AND: [{ id }, visiblePostWhere(reporterId)] },
        select: { id: true, authorId: true },
      });
      if (!post) throw new AppException(ErrorCode.NOT_FOUND);
      if (post.authorId === reporterId) throw invalid();
      return { targetPostId: post.id };
    }
    const comment = await this.prisma.comment.findFirst({
      where: {
        id,
        deletedAt: null,
        post: visiblePostWhere(reporterId),
        author: {
          status: 'ACTIVE',
          blocking: { none: { blockedId: reporterId } },
          blockedBy: { none: { blockerId: reporterId } },
        },
      },
      select: { id: true, authorId: true },
    });
    if (!comment) throw new AppException(ErrorCode.NOT_FOUND);
    if (comment.authorId === reporterId) throw invalid();
    return { targetCommentId: comment.id };
  }

  /** `GET /admin/reports`: oldest first (MODERATION; checked by the guard). */
  async adminList(query: AdminReportsQuery): Promise<PageDto<ReportDto>> {
    const scope = `admin-reports:${query.status}`;
    const after = this.posts.decode(query.cursor, scope);
    const rows = await this.prisma.report.findMany({
      where: {
        status: query.status,
        ...(after
          ? { OR: [{ createdAt: { gt: after.at } }, { createdAt: after.at, id: { gt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      take: query.limit + 1,
      include: REPORT_INCLUDE,
    });
    const hasMore = rows.length > query.limit;
    const pageRows = rows.slice(0, query.limit);
    const last = pageRows[pageRows.length - 1];
    return {
      data: pageRows.map((r) => this.toDto(r, true)),
      page: {
        hasMore,
        nextCursor:
          hasMore && last ? this.posts.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  /**
   * `POST /admin/reports/{reportId}/actions`: REMOVE_TARGET removes the post or comment (soft) or,
   * for a user, records the decision only; DISMISS changes nothing. Every OPEN report on the same
   * target closes with the same outcome; one audit row records the action. A closed report → 409.
   */
  async act(actor: AdminActor, reportId: string, body: unknown): Promise<ReportDto> {
    if (!isUuid(reportId)) throw new AppException(ErrorCode.NOT_FOUND);
    const parsed = reportActionSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { action, note } = parsed.data;
    const id = reportId.toLowerCase();
    const endedRooms: string[] = [];
    let removedChat: { roomId: string; messageId: string } | null = null;
    await this.prisma.$transaction(async (tx) => {
      const locked = await tx.$queryRaw<
        { id: string }[]
      >`SELECT id::text AS id FROM reports WHERE id = ${id}::uuid FOR UPDATE`;
      if (locked.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
      const report = await tx.report.findUniqueOrThrow({ where: { id } });
      if (report.status !== 'OPEN') throw new AppException(ErrorCode.REPORT_ALREADY_RESOLVED);
      if (action === 'REMOVE_TARGET') {
        // §11.10: the author is told (CONTENT_REMOVED) when this action removed the item.
        if (report.targetPostId) {
          await tx.$queryRaw`SELECT 1 FROM posts WHERE id = ${report.targetPostId}::uuid FOR UPDATE`;
          const post = await tx.post.findUniqueOrThrow({
            where: { id: report.targetPostId },
            select: { id: true, authorId: true, moderation: true, deletedAt: true },
          });
          await tx.post.update({ where: { id: post.id }, data: { moderation: 'REMOVED' } });
          await tx.postPin.deleteMany({ where: { postId: post.id } });
          if (post.moderation !== 'REMOVED' && post.deletedAt === null) {
            await this.notifier.system(tx, {
              type: 'CONTENT_REMOVED',
              recipientId: post.authorId,
              postId: post.id,
            });
          }
        } else if (report.targetCommentId) {
          const comment = await tx.comment.findUniqueOrThrow({
            where: { id: report.targetCommentId },
            select: { id: true, postId: true, authorId: true },
          });
          if (await this.comments.removeIn(tx, comment.id)) {
            await this.notifier.system(tx, {
              type: 'CONTENT_REMOVED',
              recipientId: comment.authorId,
              postId: comment.postId,
              commentId: comment.id,
            });
          }
        } else if (report.targetStoryId) {
          // CP-008: the story leaves every list, the archive included (soft, audited).
          const removed = await tx.story.updateMany({
            where: { id: report.targetStoryId, removedAt: null },
            data: { removedAt: new Date() },
          });
          const story = await tx.story.findUniqueOrThrow({
            where: { id: report.targetStoryId },
            select: { id: true, authorId: true, deletedAt: true },
          });
          if (removed.count > 0 && story.deletedAt === null) {
            await this.notifier.system(tx, {
              type: 'CONTENT_REMOVED',
              recipientId: story.authorId,
              storyId: story.id,
            });
          }
        }
        if (report.targetLiveChatMessageId) {
          // CP-013: the message is soft-deleted; the room's apps drop it after the commit.
          const roomId = await this.liveChat.removeIn(tx, report.targetLiveChatMessageId, actor.userId);
          if (roomId) removedChat = { roomId, messageId: report.targetLiveChatMessageId };
        }
        if (report.targetCpConfessionId) {
          // CP-021: the confession leaves the couple's page (soft).
          await removeCpConfessionIn(tx, report.targetCpConfessionId, actor.userId, new Date());
        }
        if (report.targetFamilyChatMessageId) {
          // CP-022: the message leaves the family chat (soft).
          await removeFamilyChatMessageIn(tx, report.targetFamilyChatMessageId, actor.userId, new Date());
        }
        if (report.targetLiveRoomId) {
          // CP-010: the room ends with ADMIN; its media session closes after the commit.
          endedRooms.push(...(await this.liveRooms.endByAdminIn(tx, { roomId: report.targetLiveRoomId })));
        }
        // USER: the decision is recorded only; suspension is a separate admin tool.
      }
      const target: Prisma.ReportWhereInput = report.targetPostId
        ? { targetPostId: report.targetPostId }
        : report.targetCommentId
          ? { targetCommentId: report.targetCommentId }
          : report.targetStoryId
            ? { targetStoryId: report.targetStoryId }
            : report.targetLiveRoomId
              ? { targetLiveRoomId: report.targetLiveRoomId }
              : report.targetLiveChatMessageId
                ? { targetLiveChatMessageId: report.targetLiveChatMessageId }
                : report.targetCpConfessionId
                  ? { targetCpConfessionId: report.targetCpConfessionId }
                  : report.targetFamilyChatMessageId
                    ? { targetFamilyChatMessageId: report.targetFamilyChatMessageId }
                    : { targetUserId: report.targetUserId };
      const closed = await tx.report.updateMany({
        where: { ...target, status: 'OPEN' },
        data: {
          status: action === 'REMOVE_TARGET' ? 'ACTIONED' : 'DISMISSED',
          resolvedAt: new Date(),
          resolvedById: actor.userId,
          resolutionNote: note ?? null,
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.MODERATION_REPORT_ACTION,
        actorUserId: actor.userId,
        targetType: report.targetType.toLowerCase(),
        targetId:
          report.targetPostId ??
          report.targetCommentId ??
          report.targetStoryId ??
          report.targetLiveRoomId ??
          report.targetLiveChatMessageId ??
          report.targetCpConfessionId ??
          report.targetFamilyChatMessageId ??
          report.targetUserId ??
          undefined,
        metadata: { reportId: id, action, reportsClosed: closed.count },
        ip: actor.ip,
        requestId: actor.requestId,
      });
    });
    for (const roomId of endedRooms) await this.liveMedia.closeMedia(roomId);
    const chat = removedChat as { roomId: string; messageId: string } | null;
    if (chat) await this.liveChat.afterRemoved(chat.roomId, chat.messageId);
    return this.toDto(
      await this.prisma.report.findUniqueOrThrow({ where: { id }, include: REPORT_INCLUDE }),
      true,
    );
  }

  private toDto(row: ReportRow, admin: boolean): ReportDto {
    return {
      id: row.id,
      targetType: row.targetType,
      targetId:
        row.targetPostId ??
        row.targetCommentId ??
        row.targetStoryId ??
        row.targetLiveRoomId ??
        row.targetLiveChatMessageId ??
        row.targetCpConfessionId ??
        row.targetFamilyChatMessageId ??
        row.targetUser?.profile?.username ??
        row.targetUserId ??
        '',
      reason: row.reason,
      note: row.note,
      status: row.status,
      createdAt: row.createdAt.toISOString(),
      resolvedAt: row.resolvedAt?.toISOString() ?? null,
      ...(admin ? { reporter: userSummary(row.reporter) } : {}),
    };
  }

  // ---------------------------------------------------------------------------------------------
  // Privacy

  async privacy(userId: string): Promise<PrivacyDto> {
    const row = await this.prisma.privacySettings.findUnique({ where: { userId } });
    return {
      whoCanMention: row?.whoCanMention ?? 'EVERYONE',
      defaultWhoCanComment: row?.defaultWhoCanComment ?? 'EVERYONE',
      showActivityStatus: row?.showActivityStatus ?? true,
    };
  }

  async updatePrivacy(userId: string, body: unknown): Promise<PrivacyDto> {
    const parsed = updatePrivacySchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    await this.prisma.privacySettings.upsert({
      where: { userId },
      create: { userId, ...parsed.data },
      update: parsed.data,
    });
    return this.privacy(userId);
  }
}
