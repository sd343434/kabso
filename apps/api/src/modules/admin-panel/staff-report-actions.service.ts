import { Inject, Injectable, Logger } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import type { AccountRestrictionKind, Prisma, Report } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { LiveMediaService } from '../live/live-media.service.js';
import { LiveRoomsService } from '../live/live-rooms.service.js';
import { MediaService } from '../media/media.service.js';
import { dmSnapshotDto, dmThreadDto, type DmSnapshotDto, type DmThreadDto } from '../messages/dm-reports.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { PostViews, USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { Notifier } from '../notifications/notifier.js';
import { markReportAlertsReadIn } from '../safety/report-staff-alerts.service.js';
import { reportTargetId, SafetyService } from '../safety/safety.service.js';
import {
  AccountControlError,
  MAX_RESTRICTION_DAYS,
  restrictIn,
  restrictionEnd,
} from '../users/account-control.js';
import { AccountLifecycleService } from '../users/profiles/account-lifecycle.service.js';
import type { AdminContext } from './admin-auth.service.js';
import { AdminModerationService, type PanelReportDto } from './admin-moderation.service.js';
import { can, isPanelRole, type Capability } from './admin-permissions.js';
import { refused, viaOf } from './admin-users.service.js';
import { AdminControlService } from './admin-control.service.js';
import { requestDeletionIn } from '../users/account-deletion.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';

type Tx = Prisma.TransactionClient;

/** The closed conversation card's summary of a stored thread (null: none, or purged). */
function threadSummaryOf(raw: unknown): DmThreadSummaryDto | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const t = (raw as { thread?: unknown }).thread;
  if (typeof t !== 'object' || t === null) return null;
  const th = t as { messages?: unknown; total?: unknown; truncated?: unknown; capturedAt?: unknown };
  const messages = Array.isArray(th.messages) ? th.messages.length : 0;
  return {
    messages,
    total: typeof th.total === 'number' ? th.total : messages,
    truncated: th.truncated === true,
    capturedAt: typeof th.capturedAt === 'string' ? th.capturedAt : new Date(0).toISOString(),
  };
}

/** v1.93-social (D296, §10.109): what a staff member may do from a report. */
export const STAFF_REPORT_ACTIONS = [
  'WARN',
  'RESTRICT',
  'SUSPEND',
  'BAN',
  'REMOVE_CONTENT',
  // Owner (2026-11-06): the permanent deletions in the app too, for the roles the panel allows (no code since D288).
  'DELETE_CONTENT',
  'DELETE_ACCOUNT',
] as const;
export type StaffReportAction = (typeof STAFF_REPORT_ACTIONS)[number];

/** The restrictions «منع النشر» / «منع البث» / «منع الرسائل» (D208's kinds; CHAT_MUTE covers DMs, comments, live chat). */
export const STAFF_REPORT_RESTRICTIONS = ['NO_POSTING', 'NO_LIVE', 'CHAT_MUTE'] as const;

/** The capability each action needs — the panel's own table (§10.54.1), so the app can do what the panel can. */
export const STAFF_REPORT_ACTION_CAPABILITY: Record<StaffReportAction, Capability> = {
  WARN: 'reports.act',
  RESTRICT: 'users.restrict',
  SUSPEND: 'users.lock',
  BAN: 'users.ban',
  REMOVE_CONTENT: 'reports.act',
  DELETE_CONTENT: 'users.content',
  DELETE_ACCOUNT: 'users.delete',
};

/** The two permanent deletions need the typed confirmation word as well as the reason. */
export const STAFF_REPORT_CONFIRM_WORD = 'DELETE';
const PERMANENT: readonly StaffReportAction[] = ['DELETE_CONTENT', 'DELETE_ACCOUNT'];

/** The report types whose item can be deleted for good: a post or reel, a story (a comment is only ever removed). */
const DELETABLE_CONTENT: readonly string[] = ['POST', 'STORY'];

/** `StaffReportActionRequest`. */
export const staffReportActionSchema = z
  .strictObject({
    action: z.enum(STAFF_REPORT_ACTIONS),
    reason: z.string().trim().min(1).max(500),
    restriction: z.enum(STAFF_REPORT_RESTRICTIONS).optional(),
    days: z.number().int().min(1).max(MAX_RESTRICTION_DAYS).optional(),
    /** DELETE_CONTENT and DELETE_ACCOUNT only, and required there: the word the staff member typed. */
    confirm: z.literal(STAFF_REPORT_CONFIRM_WORD).optional(),
  })
  .superRefine((v, ctx) => {
    const timed = v.action === 'RESTRICT' || v.action === 'SUSPEND';
    if (timed && v.days === undefined)
      ctx.addIssue({ code: 'custom', path: ['days'], message: 'required', params: { issue: 'required' } });
    if (!timed && v.days !== undefined)
      ctx.addIssue({
        code: 'custom',
        path: ['days'],
        message: 'invalid_value',
        params: { issue: 'invalid_value' },
      });
    if (v.action === 'RESTRICT' && v.restriction === undefined)
      ctx.addIssue({
        code: 'custom',
        path: ['restriction'],
        message: 'required',
        params: { issue: 'required' },
      });
    const permanent = (PERMANENT as readonly string[]).includes(v.action);
    if (permanent && v.confirm === undefined)
      ctx.addIssue({ code: 'custom', path: ['confirm'], message: 'required', params: { issue: 'required' } });
    if (!permanent && v.confirm !== undefined)
      ctx.addIssue({
        code: 'custom',
        path: ['confirm'],
        message: 'invalid_value',
        params: { issue: 'invalid_value' },
      });
    if (v.action !== 'RESTRICT' && v.restriction !== undefined)
      ctx.addIssue({
        code: 'custom',
        path: ['restriction'],
        message: 'invalid_value',
        params: { issue: 'invalid_value' },
      });
  });
export type StaffReportActionInput = z.output<typeof staffReportActionSchema>;

/** The reported item's state for the staff banner. */
export type StaffTargetState = 'VISIBLE' | 'HIDDEN' | 'DELETED' | 'EXPIRED' | 'LIVE' | 'ENDED' | 'GONE';

/** `StaffReportTarget` — the reported content as the staff see it, whatever its visibility. */
export interface StaffReportTargetDto {
  type: Report['targetType'];
  state: StaffTargetState;
  /** The author of the item (the reported user for USER; the sender for DM_MESSAGE). */
  author: UserSummaryDto | null;
  /** POST: the post or reel; COMMENT: the post it is on. */
  post?: unknown;
  comment?: { id: string; text: string; createdAt: string; parentId: string | null; postId: string } | null;
  story?: { id: string; text: string; media: unknown; createdAt: string; expiresAt: string } | null;
  live?: { roomId: string; title: string; status: string } | null;
  /**
   * DM_MESSAGE (and a USER reported from a conversation): the two people, the reported message (as the queue shows it)
   * and only a SUMMARY of the conversation frozen with the report — the conversation itself comes from
   * `getStaffReportDmThread`, which audits the read (owner: «عندما يضغط الموظف عليه تفتح الشات»).
   */
  dm?: {
    snapshot: DmSnapshotDto | null;
    recipient: UserSummaryDto | null;
    threadSummary: DmThreadSummaryDto | null;
  } | null;
  /** The text of a live chat message, a CP confession, a family chat message or a profile link. */
  text?: string | null;
}

/** `DmReportThreadSummary`: what the closed conversation card says (no message content). */
export interface DmThreadSummaryDto {
  /** Messages kept. */
  messages: number;
  /** Messages that existed when the report was filed (before the cap). */
  total: number;
  truncated: boolean;
  capturedAt: string;
}

/** `StaffReportDmThread`: the conversation opened by a staff member (audited). */
export interface StaffReportDmThreadDto {
  reportId: string;
  /** The reported person (the DM's sender, or the reported user). */
  reported: UserSummaryDto | null;
  /** The reporter, the other side of the conversation. */
  recipient: UserSummaryDto | null;
  /** The reported message (DM_MESSAGE reports; null for a person). */
  snapshot: DmSnapshotDto | null;
  /** The whole conversation; null for an older report that kept the reported message only, or once purged. */
  thread: DmThreadDto | null;
}

/** `StaffReportView`. */
export interface StaffReportViewDto {
  report: PanelReportDto;
  target: StaffReportTargetDto;
  /** The actions the caller may take on this report now (empty once it is closed). */
  actions: StaffReportAction[];
  /** The restrictions RESTRICT offers the caller. */
  restrictions: AccountRestrictionKind[];
  canResolve: boolean;
}

/**
 * v1.93-social (D296, CONVENTIONS §10.109; owner: «يجب عند الضغط عليه الدخول إلى البوست، ويكون له أزرار صلاحية للتحذير
 * والحظر ومنع النشر … عندما يضغط على البلاغ يدخل إلى الشات المبلغ عنه ويكون عنده إجراء»): a report opened from the app's
 * «بلاغات» — the reported content for the staff whatever its visibility (a DM only as the report's frozen snapshot,
 * every read audited), and the actions, which reuse the panel's rules: WARN and BAN are the report queue's
 * (`AdminModerationService`), RESTRICT and SUSPEND the account controls' restriction (`restrictIn`, D208), REMOVE_CONTENT
 * the report action REMOVE_TARGET (`SafetyService.act`). Every action resolves the report automatically (owner,
 * 2026-11-06) — and every other OPEN report on the same target, as the panel's actions always did — recording which
 * action did it (`resolution_action`), marking the staff's alerts about them read as «تم حله» does, audited with the
 * report id.
 */
@Injectable()
export class StaffReportActionsService {
  private readonly logger = new Logger(StaffReportActionsService.name);
  private readonly notifier = new Notifier();

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly queue: AdminModerationService,
    private readonly safety: SafetyService,
    private readonly lifecycle: AccountLifecycleService,
    private readonly posts: PostViews,
    private readonly media: MediaService,
    private readonly live: LiveRoomsService,
    private readonly liveMedia: LiveMediaService,
    private readonly control: AdminControlService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** The actions the caller's roles allow on a report of this type (none on a closed one). */
  allowedActions(ctx: AdminContext, report: Pick<Report, 'status' | 'targetType'>): StaffReportAction[] {
    if (report.status !== 'OPEN') return [];
    return STAFF_REPORT_ACTIONS.filter((a) => {
      if (!can(ctx.roles, STAFF_REPORT_ACTION_CAPABILITY[a])) return false;
      // A user has no content to remove (the decision is recorded by «تم حله»).
      if (a === 'REMOVE_CONTENT') return report.targetType !== 'USER';
      // Deleted for good: a post or reel, or a story (the panel's rule; comments are only removed).
      if (a === 'DELETE_CONTENT') return DELETABLE_CONTENT.includes(report.targetType);
      return true;
    });
  }

  /** `getStaffReport`: the report, its target for the staff and what the caller may do. */
  async view(reportId: string, ctx: AdminContext): Promise<StaffReportViewDto> {
    const row = await this.prisma.report.findUnique({ where: { id: reportId } });
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    const report = await this.queue.one(reportId);
    // D296 follow-up (owner): the conversation stays closed here — only its summary, so nothing is read or audited
    // until the staff member opens it (`dmThread`).
    const target = await this.targetView(row, ctx);
    return {
      report,
      target,
      actions: this.allowedActions(ctx, row),
      restrictions: can(ctx.roles, 'users.restrict') ? [...STAFF_REPORT_RESTRICTIONS] : [],
      canResolve: row.status === 'OPEN' && can(ctx.roles, 'reports.resolve'),
    };
  }

  private async summaryOf(userId: string | null): Promise<UserSummaryDto | null> {
    if (!userId) return null;
    const u = await this.prisma.user.findUnique({ where: { id: userId }, select: USER_SUMMARY_SELECT });
    return u?.profile ? userSummary(u) : null;
  }

  private async targetView(r: Report, ctx: AdminContext): Promise<StaffReportTargetDto> {
    const base = await this.queue.targetOf(this.prisma, r);
    const author = await this.summaryOf(base.authorId);
    const out: StaffReportTargetDto = { type: r.targetType, state: base.gone ? 'GONE' : 'VISIBLE', author };
    if (r.targetPostId) {
      const p = await this.prisma.post.findUnique({
        where: { id: r.targetPostId },
        select: { id: true, moderation: true, deletedAt: true },
      });
      if (!p) return { ...out, state: 'GONE', post: null };
      out.state = p.deletedAt ? 'DELETED' : p.moderation === 'REMOVED' ? 'HIDDEN' : 'VISIBLE';
      out.post = await this.posts.one(ctx.userId, p.id);
      return out;
    }
    if (r.targetCommentId) {
      const c = await this.prisma.comment.findUnique({
        where: { id: r.targetCommentId },
        select: { id: true, text: true, createdAt: true, parentId: true, postId: true, deletedAt: true },
      });
      if (!c) return { ...out, state: 'GONE', comment: null };
      out.state = c.deletedAt ? 'DELETED' : 'VISIBLE';
      out.comment = {
        id: c.id,
        text: c.text,
        createdAt: c.createdAt.toISOString(),
        parentId: c.parentId,
        postId: c.postId,
      };
      out.post = await this.posts.one(ctx.userId, c.postId);
      return out;
    }
    if (r.targetStoryId) {
      const s = await this.prisma.story.findUnique({
        where: { id: r.targetStoryId },
        select: {
          id: true,
          text: true,
          createdAt: true,
          expiresAt: true,
          deletedAt: true,
          removedAt: true,
          mediaAsset: {
            select: {
              id: true,
              kind: true,
              width: true,
              height: true,
              blurhash: true,
              largeKey: true,
              thumbKey: true,
              durationMs: true,
              posterKey: true,
            },
          },
        },
      });
      if (!s) return { ...out, state: 'GONE', story: null };
      out.state = s.deletedAt
        ? 'DELETED'
        : s.removedAt
          ? 'HIDDEN'
          : s.expiresAt <= new Date()
            ? 'EXPIRED'
            : 'VISIBLE';
      out.story = {
        id: s.id,
        text: s.text,
        media: this.media.toDto(s.mediaAsset),
        createdAt: s.createdAt.toISOString(),
        expiresAt: s.expiresAt.toISOString(),
      };
      return out;
    }
    if (r.targetLiveRoomId || r.targetLiveChatMessageId) {
      const roomId =
        r.targetLiveRoomId ??
        (
          await this.prisma.liveChatMessage.findUnique({
            where: { id: r.targetLiveChatMessageId! },
            select: { roomId: true },
          })
        )?.roomId ??
        null;
      const room = roomId
        ? await this.prisma.liveRoom.findUnique({
            where: { id: roomId },
            select: { id: true, title: true, status: true },
          })
        : null;
      out.live = room ? { roomId: room.id, title: room.title, status: room.status } : null;
      if (r.targetLiveRoomId) out.state = room ? (room.status === 'LIVE' ? 'LIVE' : 'ENDED') : 'GONE';
      else out.text = base.text;
      if (r.targetLiveChatMessageId && !base.gone) out.state = 'VISIBLE';
      if (r.targetLiveChatMessageId && base.gone) out.state = 'DELETED';
      return out;
    }
    if (r.targetDmMessageId || r.targetType === 'DM_MESSAGE') {
      // The frozen snapshot only: the live conversation is never read (D155, 24-hour life).
      const snapshot = dmSnapshotDto(r.dmSnapshot, this.media.publicBaseUrl);
      out.dm = {
        snapshot,
        recipient: await this.summaryOf(r.reporterId),
        threadSummary: threadSummaryOf(r.dmSnapshot),
      };
      const live = r.targetDmMessageId
        ? await this.prisma.dmMessage.findFirst({
            where: { id: r.targetDmMessageId, expiresAt: { gt: new Date() } },
            select: { id: true },
          })
        : null;
      out.state = live ? 'VISIBLE' : 'EXPIRED';
      return out;
    }
    if (r.targetType === 'DM_GROUP') {
      // v1.104-social (D339): a group — the frozen snapshot (its name and the messages the reporter could read).
      out.text = base.text;
      out.dm = {
        snapshot: null,
        recipient: await this.summaryOf(r.reporterId),
        threadSummary: threadSummaryOf(r.dmSnapshot),
      };
      const g = r.targetDmGroupId
        ? await this.prisma.dmGroup.findUnique({ where: { id: r.targetDmGroupId }, select: { status: true } })
        : null;
      out.state = !g ? 'GONE' : g.status === 'ACTIVE' ? 'VISIBLE' : 'HIDDEN';
      return out;
    }
    if (r.targetUserId && r.targetType === 'USER') {
      const u = await this.prisma.user.findUnique({
        where: { id: r.targetUserId },
        select: { status: true },
      });
      out.state = !u || u.status === 'DELETED' ? 'GONE' : 'VISIBLE';
      // v1.93-social (D296): a person reported from a conversation — the conversation frozen with the report.
      if (r.dmSnapshot !== null) {
        out.dm = {
          snapshot: null,
          recipient: await this.summaryOf(r.reporterId),
          threadSummary: threadSummaryOf(r.dmSnapshot),
        };
      }
      return out;
    }
    out.text = base.text;
    return out;
  }

  /**
   * `getStaffReportDmThread` (D296 follow-up; owner: «عند وصول الإبلاغ عن محادثة يجب أن يكون الإبلاغ مغلقاً … وعندما يضغط
   * الموظف عليه تفتح الشات»): the conversation frozen with a DM report — or with a person reported from it — opened by a
   * staff member. Every opening is audited `moderation.report.dm_read`. A report with no conversation → 404.
   */
  async dmThread(reportId: string, ctx: AdminContext): Promise<StaffReportDmThreadDto> {
    const r = await this.prisma.report.findUnique({ where: { id: reportId } });
    const dmReport = r?.targetType === 'DM_MESSAGE';
    // v1.104-social (D339): a group report keeps the group's messages the same way.
    const groupReport = r?.targetType === 'DM_GROUP';
    if (!r || (!dmReport && !groupReport && (r.targetType !== 'USER' || r.dmSnapshot === null)))
      throw new AppException(ErrorCode.NOT_FOUND);
    const reportedId = dmReport ? (await this.queue.targetOf(this.prisma, r)).authorId : r.targetUserId;
    const snapshot = dmReport ? dmSnapshotDto(r.dmSnapshot, this.media.publicBaseUrl) : null;
    const thread = await this.threadOf(r, reportedId);
    // D155 privacy: a staff read of private messages is always audited.
    await this.audit.record({
      action: AuditAction.MODERATION_REPORT_DM_READ,
      actorUserId: ctx.userId,
      targetType: dmReport ? 'dm_message' : groupReport ? 'dm_group' : 'user',
      targetId: r.targetDmMessageId ?? r.targetDmGroupId ?? r.targetUserId ?? undefined,
      metadata: {
        reportId,
        purged: snapshot?.purged ?? thread === null,
        threadMessages: thread?.messages.length ?? 0,
        via: ctx.via ?? 'panel',
      },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return {
      reportId,
      reported: await this.summaryOf(reportedId),
      recipient: await this.summaryOf(r.reporterId),
      snapshot,
      thread,
    };
  }

  /** The frozen conversation, the senders' usernames read now (a renamed account shows its current name). */
  private async threadOf(r: Report, reportedUserId: string | null): Promise<DmThreadDto | null> {
    const raw = r.dmSnapshot as { thread?: { messages?: { senderId?: unknown }[] } | null } | null;
    const ids = [
      ...new Set(
        (raw?.thread?.messages ?? [])
          .map((m) => m.senderId)
          .filter((id): id is string => typeof id === 'string'),
      ),
    ];
    const users = ids.length
      ? await this.prisma.userProfile.findMany({
          where: { userId: { in: ids } },
          select: { userId: true, username: true },
        })
      : [];
    return dmThreadDto(
      r.dmSnapshot,
      this.media.publicBaseUrl,
      new Map(users.map((u) => [u.userId, u.username])),
      reportedUserId,
    );
  }

  /** `actOnStaffReport`: one action from the report, which then resolves that report only (owner). */
  async act(
    reportId: string,
    input: StaffReportActionInput,
    ctx: AdminContext,
  ): Promise<{
    report: PanelReportDto;
    action: StaffReportAction;
    reportsClosed: number;
  }> {
    const head = await this.prisma.report.findUnique({ where: { id: reportId } });
    if (!head) throw new AppException(ErrorCode.NOT_FOUND);
    if (!can(ctx.roles, STAFF_REPORT_ACTION_CAPABILITY[input.action]))
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    if (input.action === 'REMOVE_CONTENT') {
      if (head.targetType === 'USER') throw refused('A user has no content to remove.', 'no_content', 'rule');
      // The report queue's own REMOVE_TARGET (it locks the report, 409 when closed, records `resolution_action`
      // REMOVE_CONTENT and reads the staff's alerts) — closing only this report (owner).
      await this.safety.act(
        { userId: ctx.userId, ip: ctx.ip, requestId: ctx.requestId, via: ctx.via ?? 'panel' },
        reportId,
        { action: 'REMOVE_TARGET', note: input.reason },
        { onlyThisReport: true },
      );
      return { report: await this.queue.one(reportId), action: input.action, reportsClosed: 1 };
    }
    // DELETE_CONTENT: the panel's «حذف نهائي» of a post / reel or a story, its author checked like the panel does.
    const contentType =
      head.targetType === 'POST'
        ? ('post' as const)
        : head.targetType === 'STORY'
          ? ('story' as const)
          : null;
    const contentId = head.targetPostId ?? head.targetStoryId;
    if (input.action === 'DELETE_CONTENT') {
      if (!contentType || !contentId)
        throw refused('Only a post, a reel or a story can be deleted for good.', 'not_deletable', 'rule');
      await this.control.contentAuthor(contentType, contentId, ctx);
    }
    let rooms: string[] = [];
    let reportsClosed = 0;
    try {
      await this.prisma.$transaction(async (tx: Tx) => {
        const locked = await tx.$queryRaw<
          { id: string }[]
        >`SELECT id::text AS id FROM reports WHERE id = ${reportId}::uuid FOR UPDATE`;
        if (locked.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
        const report = await tx.report.findUniqueOrThrow({ where: { id: reportId } });
        // One action per report: a second press (or a second staff member) gets 409 and sees who resolved it.
        if (report.status !== 'OPEN') throw new AppException(ErrorCode.REPORT_ALREADY_RESOLVED);
        const { authorId } = await this.queue.targetOf(tx, report);
        if (!authorId) throw refused('The reported item has no author to act on.', 'no_author', 'rule');
        if (authorId === ctx.userId) throw refused('You cannot do this to your own account.');
        const author = await tx.user.findUnique({
          where: { id: authorId },
          select: { role: true, status: true, adminPermissions: { select: { permission: true } } },
        });
        if (!author || author.status === 'DELETED') throw new AppException(ErrorCode.NOT_FOUND);
        // Nobody acts on «فريق كابسو» from a report except an OWNER (the panel's rule).
        const staffTarget =
          author.role === 'ADMIN' && author.adminPermissions.some((p) => isPanelRole(p.permission));
        if (staffTarget && !ctx.roles.includes('OWNER')) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
        const now = new Date();
        const via = viaOf(ctx);
        let detail: Record<string, unknown> = {};
        if (input.action === 'WARN') {
          // The queue's WARN: the author is told (MODERATION_WARNING, system, never the staff member's name).
          await this.notifier.system(tx, {
            type: 'MODERATION_WARNING',
            recipientId: authorId,
            ...(report.targetPostId ? { postId: report.targetPostId } : {}),
          });
          await this.audit.recordIn(tx, {
            action: AuditAction.ADMIN_USER_WARN,
            actorUserId: ctx.userId,
            targetType: 'user',
            targetId: authorId,
            metadata: { reason: input.reason, reportId, via: via.via },
            ip: ctx.ip,
            requestId: ctx.requestId,
          });
        } else if (input.action === 'BAN') {
          if (!(await this.lifecycle.suspendIn(tx, authorId))) throw refused('The account is not ACTIVE.');
          await this.audit.recordIn(tx, {
            action: AuditAction.ADMIN_USER_BAN,
            actorUserId: ctx.userId,
            targetType: 'user',
            targetId: authorId,
            metadata: {
              reason: input.reason,
              reportId,
              before: author.status,
              after: 'SUSPENDED',
              via: via.via,
            },
            ip: ctx.ip,
            requestId: ctx.requestId,
          });
        } else if (input.action === 'DELETE_CONTENT') {
          // `contentIn` locks the item, deletes it for good, tells the author (CONTENT_REMOVED) and audits
          // `admin.content.delete` {via: app}; the report below is the only one it closes.
          await this.control.contentIn(
            tx,
            contentType!,
            contentId!,
            'delete',
            { reason: input.reason },
            ctx,
            authorId,
            { closeReports: false },
          );
          detail = { contentType, contentId };
        } else if (input.action === 'DELETE_ACCOUNT') {
          // The panel's «حذف الحساب»: the D193 deletion with its grace period (still cancellable), audited
          // `account.deletion.requested` {reason, via: app}; the person's live ends.
          const r = await requestDeletionIn(tx, authorId, now, this.config.accountDeletion.graceDays, {
            via: 'ADMIN',
            actorUserId: ctx.userId,
            reason: input.reason,
            ip: ctx.ip,
            requestId: ctx.requestId,
            auditVia: via.via === 'app' ? 'app' : 'panel',
          });
          if (r.outcome === 'not_active') throw refused('The account is not ACTIVE.');
          if (r.outcome === 'already_pending') throw refused('A deletion is already pending.');
          if (r.outcome === 'blocked') {
            throw new AppException(
              ErrorCode.ACCOUNT_DELETION_BLOCKED,
              undefined,
              r.blockers.map((b) => ({ field: 'blocker', issue: b })),
            );
          }
          rooms = await this.live.endByAdminIn(tx, { hostUserId: authorId });
          detail = { purgeAfter: r.request.purgeAfter.toISOString(), sessions: r.revokedSessions };
        } else {
          const kind: AccountRestrictionKind = input.action === 'SUSPEND' ? 'LOCK' : input.restriction!;
          const endsAt = restrictionEnd(now, { days: input.days });
          // `restrictIn` audits `admin.user.lock` / `admin.user.restrict` and tells the person (ACCOUNT_RESTRICTED).
          const out = await restrictIn(tx, authorId, kind, endsAt, input.reason, via, now);
          if (kind === 'LOCK' || kind === 'NO_LIVE') {
            rooms = await this.live.endByAdminIn(tx, { hostUserId: authorId });
            await this.live.releaseSeatsOfUserIn(tx, authorId);
          }
          detail = {
            kind,
            days: input.days,
            endsAt: endsAt.toISOString(),
            restrictionId: out.restriction.id,
          };
        }
        // Owner (2026-11-06, as D288's «تم حله»): the action closes ONLY the pressed report; other people's reports on
        // the same target stay in the queue.
        const ids = [reportId];
        const closed = await tx.report.updateMany({
          where: { id: { in: ids }, status: 'OPEN' },
          data: {
            status: 'ACTIONED',
            resolvedAt: now,
            resolvedById: ctx.userId,
            resolutionNote: input.reason,
            resolutionAction: input.action,
          },
        });
        reportsClosed = closed.count;
        await markReportAlertsReadIn(tx, ids, now);
        await this.audit.recordIn(tx, {
          action: AuditAction.MODERATION_REPORT_ACTION,
          actorUserId: ctx.userId,
          targetType: report.targetType.toLowerCase(),
          targetId: reportTargetId(report),
          metadata: {
            reportId,
            action: input.action,
            authorId,
            reason: input.reason,
            ...detail,
            reportsClosed: closed.count,
            via: via.via,
          },
          ip: ctx.ip,
          requestId: ctx.requestId,
        });
      });
    } catch (err) {
      if (err instanceof AccountControlError) {
        if (err.issue === 'not_found') throw new AppException(ErrorCode.NOT_FOUND);
        throw refused(err.message, err.issue, 'rule');
      }
      throw err;
    }
    for (const roomId of rooms) {
      try {
        await this.liveMedia.closeMedia(roomId);
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err), roomId }, 'Media session could not be closed');
      }
    }
    return { report: await this.queue.one(reportId), action: input.action, reportsClosed };
  }
}
