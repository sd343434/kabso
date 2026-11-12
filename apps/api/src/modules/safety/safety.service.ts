import { Injectable } from '@nestjs/common';
import { vipPerkHeldIn } from '../vip/vip-gift-perks.js';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { Prisma, Report } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { readableCpConfession, removeCpConfessionIn } from '../cp-space/cp-confessions.js';
import { readableFamilyChatMessage, removeFamilyChatMessageIn } from '../families/family-chat.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { MediaService } from '../media/media.service.js';
import {
  DM_REPORT_THREAD_MAX_FILES,
  dmGroupSnapshotDto,
  dmSnapshotDto,
  dmThreadRowsOf,
  removeDmGroupIn,
  removeDmMessageIn,
  reportableDmGroup,
  reportableDmMessage,
  type DmGroupSnapshot,
  type DmGroupSnapshotDto,
  type DmSnapshot,
  type DmSnapshotDto,
  type DmThreadMessage,
  type DmThreadSnapshot,
} from '../messages/dm-reports.js';
import { LiveChatService } from '../live/live-chat.service.js';
import { LiveStaffAlertsService } from '../live/live-staff-alerts.service.js';
import { markReportAlertsReadIn, ReportStaffAlertsService } from './report-staff-alerts.service.js';
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
import { acceptAllFollowRequestsIn, withdrawFollowRequestIn } from '../social/follow-requests.js';
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

/** Request metadata for the privacy audit record. */
export interface PrivacyMeta {
  readonly ip: string | null;
  readonly requestId: string;
}

function linkSnapshotDto(value: Prisma.JsonValue | null): ProfileLinkSnapshot | undefined {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return undefined;
  const v = value as Record<string, unknown>;
  return {
    username: typeof v.username === 'string' ? v.username : '',
    url: typeof v.url === 'string' ? v.url : '',
    label: typeof v.label === 'string' ? v.label : null,
  };
}

/** `Report` (openapi v1.5-social); `reporter` in admin views only. */
/** v1.134-social (D381, §10.171.3): the reasons that keep the first place in the queue, whoever reports. */
export const SAFETY_REPORT_REASONS: ReadonlySet<string> = new Set(['NUDITY', 'VIOLENCE', 'ILLEGAL']);

/**
 * v1.134-social (D381, §10.171.3): a new report's priority — 2 for a safety reason (everyone), else 1 when the reporter
 * holds PRIORITY_SUPPORT now, else 0.
 */
export async function reportPriorityOf(
  db: Pick<Prisma.TransactionClient, 'vipMembership' | 'vipTierPerk'>,
  reporterId: string,
  reason: string,
): Promise<number> {
  if (SAFETY_REPORT_REASONS.has(reason)) return 2;
  return (await vipPerkHeldIn(db, reporterId, 'PRIORITY_SUPPORT', new Date())) ? 1 : 0;
}

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
    | 'FAMILY_CHAT_MESSAGE'
    | 'DM_MESSAGE'
    | 'PROFILE_LINK'
    | 'DM_GROUP';
  targetId: string;
  reason: string;
  note: string | null;
  status: 'OPEN' | 'ACTIONED' | 'DISMISSED';
  createdAt: string;
  resolvedAt: string | null;
  reporter?: UserSummaryDto;
  /** v1.40-social (D155): admin views of DM_MESSAGE reports. */
  dmSnapshot?: DmSnapshotDto;
  /** v1.104-social (D339): admin views of DM_GROUP reports — the group as it was when reported. */
  dmGroupSnapshot?: DmGroupSnapshotDto;
  /** v1.47-social (D175): admin views of PROFILE_LINK reports — what the link was. */
  linkSnapshot?: ProfileLinkSnapshot;
  /**
   * v1.134-social (D381, §10.171.3): admin views — the shared queue's order: 2 a safety reason, 1 from a
   * PRIORITY_SUPPORT holder, 0 otherwise.
   */
  priority?: number;
}

/** v1.47-social (D175): a reported profile link as it was when reported. */
export interface ProfileLinkSnapshot {
  username: string;
  url: string;
  label: string | null;
}

export interface PrivacyDto {
  whoCanMention: 'EVERYONE' | 'FOLLOWING' | 'NOBODY';
  defaultWhoCanComment: 'EVERYONE' | 'FOLLOWERS' | 'NOBODY';
  /** v1.25-live (CP-022): others may see when the user was last active (§10.25). */
  showActivityStatus: boolean;
  /** v1.40-social (D155): who may send the user direct messages (§11.13). */
  whoCanMessage: 'EVERYONE' | 'FOLLOWING' | 'NOBODY';
  /** v1.47-social (D175, §10.47): a private account (follow requests; content for followers only). */
  isPrivate: boolean;
  /** v1.77-social (D220, §10.74): others do not get `PublicProfile.cherriesReceived` (default false). */
  hideCherriesReceived: boolean;
  /** v1.77-social (D220, §10.74): others do not get `PublicProfile.coinsSent` (default false). */
  hideCoinsSent: boolean;
}

/**
 * Every report on the same target as `report` (v1.60-social, D191: shared with the admin panel's warn and ban, which
 * close the target's OPEN reports like REMOVE_TARGET does).
 */
export function reportTargetWhere(report: Report): Prisma.ReportWhereInput {
  return report.targetPostId
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
                : report.targetDmMessageId
                  ? { targetDmMessageId: report.targetDmMessageId }
                  : report.targetDmGroupId
                    ? { targetDmGroupId: report.targetDmGroupId }
                    : report.targetProfileLinkId
                      ? { targetProfileLinkId: report.targetProfileLinkId }
                      : { targetUserId: report.targetUserId };
}

/** The reported item's id (the audit row's target). */
export function reportTargetId(report: Report): string | undefined {
  return (
    report.targetPostId ??
    report.targetCommentId ??
    report.targetStoryId ??
    report.targetLiveRoomId ??
    report.targetLiveChatMessageId ??
    report.targetCpConfessionId ??
    report.targetFamilyChatMessageId ??
    report.targetDmMessageId ??
    report.targetDmGroupId ??
    report.targetProfileLinkId ??
    report.targetUserId ??
    undefined
  );
}

const REPORT_INCLUDE = {
  reporter: { select: USER_SUMMARY_SELECT },
  targetUser: { select: { profile: { select: { username: true } } } },
  // D193: the content was deleted with its author's account and is under a legal hold (the hold keeps its id).
  legalHold: { select: { targetId: true } },
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
    private readonly media: MediaService,
    private readonly staffAlerts: LiveStaffAlertsService,
    private readonly reportAlerts: ReportStaffAlertsService,
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
        // v1.47-social (D175): pending follow requests either way go, with their notifications.
        await withdrawFollowRequestIn(tx, this.notifier, callerId, targetId);
        await withdrawFollowRequestIn(tx, this.notifier, targetId, callerId);
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
    // v1.68-live (D273): the live a user was reported from (its context; USER only).
    let contextLiveRoomId: string | null = null;
    if (input.liveRoomId !== undefined) {
      if (input.targetType !== 'USER')
        throw AppException.validation([{ field: 'liveRoomId', issue: 'invalid_value' }]);
      contextLiveRoomId = (await this.liveRooms.visibleRow(input.liveRoomId.toLowerCase(), reporterId)).id;
    }
    if (input.dmConversationId !== undefined && input.targetType !== 'USER')
      throw AppException.validation([{ field: 'dmConversationId', issue: 'invalid_value' }]);
    // v1.40-social (D155): a direct message is kept as a snapshot (it is deleted after 24 h).
    const dm =
      input.targetType === 'DM_MESSAGE' && isUuid(input.targetId)
        ? await reportableDmMessage(this.prisma, input.targetId.toLowerCase(), reporterId, new Date())
        : null;
    if (input.targetType === 'DM_MESSAGE' && !dm) throw new AppException(ErrorCode.NOT_FOUND);
    // v1.47-social (D175): a profile link is kept as a snapshot (its owner may edit it away).
    const link =
      input.targetType === 'PROFILE_LINK' ? await this.reportableLink(reporterId, input.targetId) : null;
    // v1.104-social (D339): a group the reporter belongs to, kept as a snapshot (its messages live 24 h).
    let group: DmGroupSnapshot | null = null;
    if (input.targetType === 'DM_GROUP') {
      if (!isUuid(input.targetId)) throw new AppException(ErrorCode.NOT_FOUND);
      group = await reportableDmGroup(this.prisma, input.targetId.toLowerCase(), reporterId, new Date());
    }
    const target = dm
      ? { targetDmMessageId: dm.id }
      : group
        ? { targetDmGroupId: group.groupId }
        : link
          ? { targetProfileLinkId: link.id }
          : await this.resolveTarget(reporterId, input);
    const where: Prisma.ReportWhereInput = { reporterId, status: 'OPEN', ...target };
    const existing = await this.prisma.report.findFirst({ where, include: REPORT_INCLUDE });
    if (existing) {
      // v1.68-live (D273): the same person reported again from inside a live — the staff of that live are told.
      if (contextLiveRoomId !== null && existing.contextLiveRoomId === null) {
        await this.prisma.report.update({ where: { id: existing.id }, data: { contextLiveRoomId } });
        await this.staffAlerts.afterReport(existing.id, reporterId);
      }
      return { report: this.toDto(existing, false), created: false };
    }
    const reportId = uuidv7();
    // v1.93-social (D296): a person reported from a conversation — the reporter's conversation with them.
    let personConversationId: string | null = null;
    if (input.dmConversationId !== undefined && 'targetUserId' in target) {
      const [low, high] = [reporterId, target.targetUserId].sort();
      const conv = await this.prisma.dmConversation.findFirst({
        where: { id: input.dmConversationId.toLowerCase(), userLowId: low!, userHighId: high! },
        select: { id: true },
      });
      if (!conv) throw new AppException(ErrorCode.NOT_FOUND);
      personConversationId = conv.id;
    }
    let snapshot:
      (DmSnapshot | DmGroupSnapshot | { conversationId: string; thread: DmThreadSnapshot | null }) | null =
      null;
    if (dm) {
      let mediaKey: string | null = null;
      if (dm.media) {
        const key = `reports/dm/${reportId}.${dm.media.extension}`;
        if (await this.media.copyObject(dm.media.key, key, dm.media.contentType)) mediaKey = key;
      }
      const thread = await this.freezeThread(reportId, dm.snapshot.conversationId, dm.id, mediaKey);
      snapshot = { ...dm.snapshot, mediaKey, purged: false, thread };
    } else if (group) {
      snapshot = group;
    } else if (personConversationId !== null) {
      snapshot = {
        conversationId: personConversationId,
        thread: await this.freezeThread(reportId, personConversationId, null, null),
      };
    }
    try {
      const row = await this.prisma.report.create({
        data: {
          id: reportId,
          ...(snapshot ? { dmSnapshot: snapshot as unknown as Prisma.InputJsonValue } : {}),
          ...(link ? { linkSnapshot: link.snapshot as unknown as Prisma.InputJsonValue } : {}),
          reporterId,
          targetType: input.targetType,
          reason: input.reason,
          note: input.note ?? null,
          // v1.134-social (D381, §10.171.3): the shared queue's order, fixed now.
          priority: await reportPriorityOf(this.prisma, reporterId, input.reason),
          ...(contextLiveRoomId !== null ? { contextLiveRoomId } : {}),
          ...target,
        },
        include: REPORT_INCLUDE,
      });
      // v1.68-live (D273, §10.96.8): a report on a live alerts its staff member; v1.78-live (D288, §10.101): every new
      // report alerts the moderators and the support (best effort, never fails the report).
      await this.reportAlerts.afterNewReport(row.id, reporterId);
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

  /**
   * v1.93-social (D296, §10.109.5; owner: «مثل طريقة نزاع وكيل الشحن»): every message of the conversation that still
   * exists now, oldest first (the newest DM_REPORT_THREAD_MAX_MESSAGES), with a copy of the newest
   * DM_REPORT_THREAD_MAX_FILES files — taken once, when the report is filed; later messages are never added.
   */
  private async freezeThread(
    reportId: string,
    conversationId: string,
    reportedMessageId: string | null,
    reportedMediaKey: string | null,
  ): Promise<DmThreadSnapshot> {
    const now = new Date();
    const { rows, total } = await dmThreadRowsOf(this.prisma, conversationId, now);
    // The newest files first, up to the cap (the reported message's own copy is reused).
    const copy = new Set(
      rows
        .filter((r) => r.media !== null && r.message.id !== reportedMessageId)
        .slice(-DM_REPORT_THREAD_MAX_FILES)
        .map((r) => r.message.id),
    );
    const messages: DmThreadMessage[] = [];
    for (const r of rows) {
      const reported = r.message.id === reportedMessageId;
      let mediaKey: string | null = reported ? reportedMediaKey : null;
      if (!reported && r.media && copy.has(r.message.id)) {
        const key = `reports/dm/${reportId}/${r.message.id}.${r.media.extension}`;
        if (await this.media.copyObject(r.media.key, key, r.media.contentType)) mediaKey = key;
      }
      messages.push({
        ...r.message,
        mediaKey,
        mediaMissing: r.media !== null && mediaKey === null,
        reported,
      });
    }
    return {
      conversationId,
      capturedAt: now.toISOString(),
      total,
      truncated: total > rows.length,
      messages,
    };
  }

  /**
   * v1.47-social (D175): a link on the profile of an ACTIVE user with no block either way with the
   * reporter, not the reporter's own (400 `targetId` / `invalid_value`); else 404.
   */
  private async reportableLink(
    reporterId: string,
    targetId: string,
  ): Promise<{ id: string; snapshot: ProfileLinkSnapshot & { userId: string } }> {
    if (!isUuid(targetId)) throw new AppException(ErrorCode.NOT_FOUND);
    const link = await this.prisma.userProfileLink.findFirst({
      where: {
        id: targetId.toLowerCase(),
        user: {
          status: 'ACTIVE',
          blocking: { none: { blockedId: reporterId } },
          blockedBy: { none: { blockerId: reporterId } },
        },
      },
      select: {
        id: true,
        userId: true,
        url: true,
        label: true,
        user: { select: { profile: { select: { username: true } } } },
      },
    });
    if (!link) throw new AppException(ErrorCode.NOT_FOUND);
    if (link.userId === reporterId)
      throw AppException.validation([{ field: 'targetId', issue: 'invalid_value' }]);
    return {
      id: link.id,
      snapshot: {
        userId: link.userId,
        username: link.user.profile?.username ?? '',
        url: link.url,
        label: link.label,
      },
    };
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
      // v1.93-social (D296, §10.109): the user's id is accepted too — the app has always sent the id (the profile,
      // the chat's «الإبلاغ عن الشخص», the live person card), which the username lookup answered with 404.
      const byId = isUuid(input.targetId)
        ? await this.prisma.user.findFirst({
            where: { id: input.targetId.toLowerCase(), status: 'ACTIVE' },
            select: { id: true },
          })
        : null;
      const userId = byId?.id ?? (await this.users.findActivePublicUser(input.targetId))?.id;
      if (!userId) throw new AppException(ErrorCode.NOT_FOUND);
      if (userId === reporterId) throw invalid();
      return { targetUserId: userId };
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

  /**
   * v1.134-social (D381): the rows after the cursor's in the open queue's order (priority desc, then oldest first). The
   * cursor keeps its shape ({at, id}); the priority is the cursor row's (fixed when a report is made).
   */
  private async afterInPriorityOrder(after: { at: Date; id: string }): Promise<Prisma.ReportWhereInput> {
    const row = await this.prisma.report.findUnique({ where: { id: after.id }, select: { priority: true } });
    const p = row?.priority ?? 0;
    return {
      OR: [
        { priority: { lt: p } },
        { priority: p, createdAt: { gt: after.at } },
        { priority: p, createdAt: after.at, id: { gt: after.id } },
      ],
    };
  }

  /**
   * `GET /admin/reports`: oldest first (MODERATION; checked by the guard). v1.78-live (D288): the shared queue's
   * `RESOLVED` — every closed report, newest resolution first.
   */
  async adminList(
    query: Omit<AdminReportsQuery, 'status'> & { status: AdminReportsQuery['status'] | 'RESOLVED' },
  ): Promise<PageDto<ReportDto>> {
    const scope = `admin-reports:${query.status}`;
    const after = this.posts.decode(query.cursor, scope);
    const resolved = query.status === 'RESOLVED';
    const rows = resolved
      ? await this.prisma.report.findMany({
          where: {
            status: { not: 'OPEN' },
            resolvedAt: { not: null },
            ...(after
              ? { OR: [{ resolvedAt: { lt: after.at } }, { resolvedAt: after.at, id: { lt: after.id } }] }
              : {}),
          },
          orderBy: [{ resolvedAt: 'desc' }, { id: 'desc' }],
          take: query.limit + 1,
          include: REPORT_INCLUDE,
        })
      : await this.prisma.report.findMany({
          where: {
            status: query.status as AdminReportsQuery['status'],
            ...(after ? await this.afterInPriorityOrder(after) : {}),
          },
          // v1.134-social (D381, §10.171.3): the higher priority first (safety, then PRIORITY_SUPPORT), each oldest first.
          orderBy: [{ priority: 'desc' }, { createdAt: 'asc' }, { id: 'asc' }],
          take: query.limit + 1,
          include: REPORT_INCLUDE,
        });
    const hasMore = rows.length > query.limit;
    const pageRows = rows.slice(0, query.limit);
    const last = pageRows[pageRows.length - 1];
    const at = last ? (resolved ? (last.resolvedAt ?? last.createdAt) : last.createdAt) : null;
    return {
      data: pageRows.map((r) => this.toDto(r, true)),
      page: {
        hasMore,
        nextCursor: hasMore && last && at ? this.posts.cursors.encode(scope, { at, id: last.id }) : null,
      },
    };
  }

  /**
   * `POST /admin/reports/{reportId}/actions`: REMOVE_TARGET removes the post or comment (soft) or,
   * for a user, records the decision only; DISMISS changes nothing. Every OPEN report on the same
   * target closes with the same outcome; one audit row records the action. A closed report → 409.
   */
  async act(
    actor: AdminActor,
    reportId: string,
    body: unknown,
    /**
     * v1.93-social (D296, §10.109.2; owner, as for «تم حله» in D288): close only this report — the app's actions from a
     * report. Without it (the panel's queue, §11.7) every OPEN report on the target closes.
     */
    options: { onlyThisReport?: boolean } = {},
  ): Promise<ReportDto> {
    if (!isUuid(reportId)) throw new AppException(ErrorCode.NOT_FOUND);
    const parsed = reportActionSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { action, note } = parsed.data;
    const id = reportId.toLowerCase();
    const endedRooms: string[] = [];
    let removedChat: { roomId: string; messageId: string } | null = null;
    const removedGroupPhotos: string[] = [];
    await this.prisma.$transaction(async (tx) => {
      const locked = await tx.$queryRaw<
        { id: string }[]
      >`SELECT id::text AS id FROM reports WHERE id = ${id}::uuid FOR UPDATE`;
      if (locked.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
      const report = await tx.report.findUniqueOrThrow({
        where: { id },
        include: { legalHold: { select: { targetId: true } } },
      });
      if (report.status !== 'OPEN') throw new AppException(ErrorCode.REPORT_ALREADY_RESOLVED);
      // D193: content deleted with its author's account and kept under a legal hold has no target row left (nothing
      // to remove; the decision is recorded and every report of the hold closes together).
      const heldOnly =
        report.legalHoldId !== null &&
        report.targetCommentId === null &&
        report.targetDmMessageId === null &&
        report.targetDmGroupId === null &&
        report.targetProfileLinkId === null;
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
        if (report.targetDmMessageId) {
          // v1.40-social (D155): the message expires now (the sweeper deletes it and its file); the
          // report keeps its snapshot.
          await removeDmMessageIn(tx, report.targetDmMessageId, new Date());
        }
        if (report.targetDmGroupId) {
          // v1.104-social (D339): the group is removed for everyone and its messages expire now; the report keeps its
          // snapshot. The photo's files go after the commit.
          const removed = await removeDmGroupIn(tx, report.targetDmGroupId, new Date());
          if (removed.photoMediaId) removedGroupPhotos.push(removed.photoMediaId);
        }
        if (report.targetProfileLinkId) {
          // v1.47-social (D175): the link leaves the profile (when it is still there).
          await tx.userProfileLink.deleteMany({ where: { id: report.targetProfileLinkId } });
        }
        if (report.targetLiveRoomId) {
          // CP-010: the room ends with ADMIN; its media session closes after the commit.
          endedRooms.push(...(await this.liveRooms.endByAdminIn(tx, { roomId: report.targetLiveRoomId })));
        }
        // USER: the decision is recorded only; suspension is a separate admin tool.
      }
      const target: Prisma.ReportWhereInput = heldOnly
        ? { legalHoldId: report.legalHoldId }
        : reportTargetWhere(report);
      // v1.93-social (D296, §10.109): the closed reports record which action resolved them, and the staff's alerts
      // about them are read for everyone (as after «تم حله»).
      const closing = options.onlyThisReport
        ? [{ id }]
        : await tx.report.findMany({
            where: { ...target, status: 'OPEN' },
            select: { id: true },
          });
      const closed = await tx.report.updateMany({
        where: { id: { in: closing.map((r) => r.id) }, status: 'OPEN' },
        data: {
          status: action === 'REMOVE_TARGET' ? 'ACTIONED' : 'DISMISSED',
          resolvedAt: new Date(),
          resolvedById: actor.userId,
          resolutionNote: note ?? null,
          resolutionAction: action === 'REMOVE_TARGET' ? 'REMOVE_CONTENT' : 'DISMISS',
        },
      });
      await markReportAlertsReadIn(
        tx,
        closing.map((r) => r.id),
      );
      await this.audit.recordIn(tx, {
        action: AuditAction.MODERATION_REPORT_ACTION,
        actorUserId: actor.userId,
        targetType: report.targetType.toLowerCase(),
        targetId: (report.legalHoldId ? report.legalHold?.targetId : undefined) ?? reportTargetId(report),
        metadata: {
          reportId: id,
          action,
          reportsClosed: closed.count,
          ...(actor.via ? { via: actor.via } : {}),
          ...(report.legalHoldId ? { legalHoldId: report.legalHoldId } : {}),
        },
        ip: actor.ip,
        requestId: actor.requestId,
      });
    });
    for (const roomId of endedRooms) await this.liveMedia.closeMedia(roomId);
    if (removedGroupPhotos.length > 0) {
      const assets = await this.prisma.mediaAsset.findMany({
        where: { id: { in: removedGroupPhotos } },
        select: { id: true, largeKey: true, thumbKey: true },
      });
      await this.media.purgeAssets(assets).catch(() => 0);
    }
    const chat = removedChat as { roomId: string; messageId: string } | null;
    if (chat) await this.liveChat.afterRemoved(chat.roomId, chat.messageId);
    return this.toDto(
      await this.prisma.report.findUniqueOrThrow({ where: { id }, include: REPORT_INCLUDE }),
      true,
    );
  }

  /** v1.60-social (D191): one report as the admin queue shows it (the panel's answer after an action). */
  async adminGet(id: string): Promise<ReportDto> {
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
        row.targetDmMessageId ??
        row.targetDmGroupId ??
        row.targetProfileLinkId ??
        row.legalHold?.targetId ??
        row.targetUser?.profile?.username ??
        row.targetUserId ??
        '',
      reason: row.reason,
      note: row.note,
      status: row.status,
      createdAt: row.createdAt.toISOString(),
      resolvedAt: row.resolvedAt?.toISOString() ?? null,
      ...(admin ? { reporter: userSummary(row.reporter), priority: row.priority } : {}),
      ...(admin && row.targetType === 'DM_MESSAGE'
        ? { dmSnapshot: dmSnapshotDto(row.dmSnapshot, this.media.publicBaseUrl) ?? undefined }
        : {}),
      ...(admin && row.targetType === 'DM_GROUP'
        ? { dmGroupSnapshot: dmGroupSnapshotDto(row.dmSnapshot, this.media.publicBaseUrl) ?? undefined }
        : {}),
      ...(admin && row.targetType === 'PROFILE_LINK'
        ? { linkSnapshot: linkSnapshotDto(row.linkSnapshot) }
        : {}),
    };
  }

  // ---------------------------------------------------------------------------------------------
  // Privacy

  async privacy(userId: string): Promise<PrivacyDto> {
    const [row, settings] = await Promise.all([
      this.prisma.privacySettings.findUnique({ where: { userId } }),
      this.prisma.userSettings.findUnique({ where: { userId }, select: { isPrivate: true } }),
    ]);
    return {
      whoCanMention: row?.whoCanMention ?? 'EVERYONE',
      defaultWhoCanComment: row?.defaultWhoCanComment ?? 'EVERYONE',
      showActivityStatus: row?.showActivityStatus ?? true,
      whoCanMessage: row?.whoCanMessage ?? 'EVERYONE',
      isPrivate: settings?.isPrivate ?? false,
      hideCherriesReceived: row?.hideCherriesReceived ?? false,
      hideCoinsSent: row?.hideCoinsSent ?? false,
    };
  }

  /**
   * `PATCH /me/privacy`. v1.47-social (D175, §10.47): `isPrivate` switches the account private or
   * public under the account's lock (a concurrent follow waits for it); private → public accepts
   * every pending follow request. Audited `user.privacy.private` when it changes.
   */
  async updatePrivacy(userId: string, body: unknown, meta: PrivacyMeta): Promise<PrivacyDto> {
    const parsed = updatePrivacySchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { isPrivate, ...rest } = parsed.data;
    await this.prisma.$transaction(async (tx) => {
      if (Object.keys(rest).length > 0) {
        await tx.privacySettings.upsert({ where: { userId }, create: { userId, ...rest }, update: rest });
      }
      if (isPrivate === undefined) return;
      const [locked] = await tx.$queryRaw<{ is_private: boolean | null }[]>`
        SELECT s.is_private FROM users u LEFT JOIN user_settings s ON s.user_id = u.id
         WHERE u.id = ${userId}::uuid FOR UPDATE OF u`;
      if (!locked) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
      const before = locked.is_private ?? false;
      if (before === isPrivate) return;
      await tx.userSettings.upsert({
        where: { userId },
        create: { userId, isPrivate },
        update: { isPrivate },
      });
      const accepted = isPrivate ? 0 : await acceptAllFollowRequestsIn(tx, userId);
      await this.audit.recordIn(tx, {
        action: AuditAction.PRIVACY_PRIVATE,
        actorUserId: userId,
        targetType: 'user',
        targetId: userId,
        metadata: { isPrivate, requestsAccepted: accepted },
        ip: meta.ip,
        requestId: meta.requestId,
      });
    });
    return this.privacy(userId);
  }
}
