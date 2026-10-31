import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma, Report } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { MediaService } from '../media/media.service.js';
import { Notifier } from '../notifications/notifier.js';
import type { AdminReportsQuery } from '../safety/safety.schemas.js';
import {
  reportTargetId,
  reportTargetWhere,
  SafetyService,
  type ReportDto,
} from '../safety/safety.service.js';
import { AccountLifecycleService } from '../users/profiles/account-lifecycle.service.js';
import type { AdminContext } from './admin-auth.service.js';
import { refused } from './admin-users.service.js';

/** What the moderator sees of a reported item (null fields when it is gone). */
export interface ReportPreviewDto {
  text: string | null;
  mediaUrl: string | null;
  author: { id: string; username: string; displayName: string; status: string } | null;
  /** The item was already removed or deleted. */
  gone: boolean;
}

export type PanelReportDto = ReportDto & { preview: ReportPreviewDto };

type Tx = Prisma.TransactionClient;
type Db = Pick<
  PrismaService,
  'post' | 'comment' | 'story' | 'liveRoom' | 'liveChatMessage' | 'cpConfession' | 'familyChatMessage'
>;

/**
 * The panel's report queue (v1.60-social, D191, CONVENTIONS §10.54.5): the open reports of every kind (users, posts,
 * comments, stories, lives, live chat, CP confessions, family chat, DMs, profile links) with a preview of the target,
 * and the actions. DISMISS and REMOVE_TARGET are the existing `/admin/reports` rule (SafetyService.act); WARN sends the
 * author a MODERATION_WARNING notification and BAN suspends the author through AccountLifecycleService — both close
 * every OPEN report on the target as ACTIONED and are audited with the reason.
 */
@Injectable()
export class AdminModerationService {
  private readonly notifier = new Notifier();

  constructor(
    private readonly prisma: PrismaService,
    private readonly safety: SafetyService,
    private readonly media: MediaService,
    private readonly lifecycle: AccountLifecycleService,
    private readonly audit: AuditService,
  ) {}

  async list(query: AdminReportsQuery) {
    const page = await this.safety.adminList(query);
    const rows = await this.prisma.report.findMany({ where: { id: { in: page.data.map((r) => r.id) } } });
    const byId = new Map(rows.map((r) => [r.id, r]));
    const data: PanelReportDto[] = [];
    for (const dto of page.data) {
      const row = byId.get(dto.id);
      data.push({
        ...dto,
        preview: row ? await this.preview(row) : { text: null, mediaUrl: null, author: null, gone: true },
      });
    }
    return { data, page: page.page };
  }

  /** The author (or the reported user) of a report's target, and what it says. */
  private async targetOf(
    db: Db,
    r: Report,
  ): Promise<{ authorId: string | null; text: string | null; mediaUrl: string | null; gone: boolean }> {
    if (r.targetPostId) {
      const p = await db.post.findUnique({
        where: { id: r.targetPostId },
        select: { authorId: true, text: true, moderation: true, deletedAt: true },
      });
      return {
        authorId: p?.authorId ?? null,
        text: p?.text ?? null,
        mediaUrl: null,
        gone: !p || p.deletedAt !== null || p.moderation === 'REMOVED',
      };
    }
    if (r.targetCommentId) {
      const c = await db.comment.findUnique({
        where: { id: r.targetCommentId },
        select: { authorId: true, text: true, deletedAt: true },
      });
      return {
        authorId: c?.authorId ?? null,
        text: c?.text ?? null,
        mediaUrl: null,
        gone: !c || c.deletedAt !== null,
      };
    }
    if (r.targetStoryId) {
      const s = await db.story.findUnique({
        where: { id: r.targetStoryId },
        select: {
          authorId: true,
          text: true,
          deletedAt: true,
          removedAt: true,
          mediaAsset: { select: { thumbKey: true } },
        },
      });
      return {
        authorId: s?.authorId ?? null,
        text: s?.text || null,
        mediaUrl: s?.mediaAsset ? `${this.media.publicBaseUrl ?? ''}/${s.mediaAsset.thumbKey}` : null,
        gone: !s || s.deletedAt !== null || s.removedAt !== null,
      };
    }
    if (r.targetLiveRoomId) {
      const l = await db.liveRoom.findUnique({
        where: { id: r.targetLiveRoomId },
        select: { hostUserId: true, title: true, status: true },
      });
      return {
        authorId: l?.hostUserId ?? null,
        text: l?.title ?? null,
        mediaUrl: null,
        gone: !l || l.status !== 'LIVE',
      };
    }
    if (r.targetLiveChatMessageId) {
      const m = await db.liveChatMessage.findUnique({
        where: { id: r.targetLiveChatMessageId },
        select: { userId: true, text: true, deletedAt: true },
      });
      return {
        authorId: m?.userId ?? null,
        text: m?.text ?? null,
        mediaUrl: null,
        gone: !m || m.deletedAt !== null,
      };
    }
    if (r.targetCpConfessionId) {
      const m = await db.cpConfession.findUnique({
        where: { id: r.targetCpConfessionId },
        select: { authorId: true, text: true, deletedAt: true },
      });
      return {
        authorId: m?.authorId ?? null,
        text: m?.text ?? null,
        mediaUrl: null,
        gone: !m || m.deletedAt !== null,
      };
    }
    if (r.targetFamilyChatMessageId) {
      const m = await db.familyChatMessage.findUnique({
        where: { id: r.targetFamilyChatMessageId },
        select: { authorId: true, text: true, deletedAt: true },
      });
      return {
        authorId: m?.authorId ?? null,
        text: m?.text ?? null,
        mediaUrl: null,
        gone: !m || m.deletedAt !== null,
      };
    }
    if (r.targetDmMessageId) {
      // The message itself lives 24 h; the report keeps a snapshot (shown in `dmSnapshot`).
      const s = (r.dmSnapshot ?? {}) as { senderId?: unknown; text?: unknown };
      return {
        authorId: typeof s.senderId === 'string' ? s.senderId : null,
        text: typeof s.text === 'string' ? s.text : null,
        mediaUrl: null,
        gone: false,
      };
    }
    if (r.targetProfileLinkId) {
      const s = (r.linkSnapshot ?? {}) as { userId?: unknown; url?: unknown };
      return {
        authorId: typeof s.userId === 'string' ? s.userId : null,
        text: typeof s.url === 'string' ? s.url : null,
        mediaUrl: null,
        gone: false,
      };
    }
    return { authorId: r.targetUserId, text: null, mediaUrl: null, gone: r.targetUserId === null };
  }

  private async preview(r: Report): Promise<ReportPreviewDto> {
    const t = await this.targetOf(this.prisma, r);
    const author = t.authorId
      ? await this.prisma.user.findUnique({
          where: { id: t.authorId },
          select: {
            id: true,
            status: true,
            profile: { select: { username: true, displayName: true, bio: true, avatarUrl: true } },
          },
        })
      : null;
    const isUser = r.targetType === 'USER';
    return {
      text: isUser ? (author?.profile?.bio ?? null) : t.text,
      mediaUrl: isUser ? (author?.profile?.avatarUrl ?? null) : t.mediaUrl,
      author: author
        ? {
            id: author.id,
            username: author.profile?.username ?? '',
            displayName: author.profile?.displayName ?? '',
            status: author.status,
          }
        : null,
      gone: t.gone,
    };
  }

  async act(
    reportId: string,
    body: { action: 'DISMISS' | 'REMOVE_TARGET' | 'WARN' | 'BAN'; note?: string | undefined },
    ctx: AdminContext,
  ) {
    if (body.action === 'DISMISS' || body.action === 'REMOVE_TARGET') {
      return this.safety.act(
        { userId: ctx.userId, ip: ctx.ip, requestId: ctx.requestId, via: 'panel' },
        reportId,
        { action: body.action, ...(body.note ? { note: body.note } : {}) },
      );
    }
    const note = body.note ?? '';
    await this.prisma.$transaction(async (tx: Tx) => {
      const locked = await tx.$queryRaw<
        { id: string }[]
      >`SELECT id::text AS id FROM reports WHERE id = ${reportId}::uuid FOR UPDATE`;
      if (locked.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
      const report = await tx.report.findUniqueOrThrow({ where: { id: reportId } });
      if (report.status !== 'OPEN') throw new AppException(ErrorCode.REPORT_ALREADY_RESOLVED);
      const { authorId } = await this.targetOf(tx, report);
      if (!authorId) throw refused('The reported item has no author to act on.');
      if (authorId === ctx.userId) throw refused('You cannot do this to your own account.');
      const author = await tx.user.findUnique({
        where: { id: authorId },
        select: { role: true, status: true },
      });
      if (author?.role === 'ADMIN' && !ctx.roles.includes('OWNER'))
        throw new AppException(ErrorCode.AUTH_FORBIDDEN);
      if (body.action === 'WARN') {
        await this.notifier.system(tx, {
          type: 'MODERATION_WARNING',
          recipientId: authorId,
          ...(report.targetPostId ? { postId: report.targetPostId } : {}),
        });
      } else if (!(await this.lifecycle.suspendIn(tx, authorId))) {
        throw refused('The account is not ACTIVE.');
      }
      const closed = await tx.report.updateMany({
        where: { ...reportTargetWhere(report), status: 'OPEN' },
        data: { status: 'ACTIONED', resolvedAt: new Date(), resolvedById: ctx.userId, resolutionNote: note },
      });
      await this.audit.recordIn(tx, {
        action: body.action === 'WARN' ? AuditAction.ADMIN_USER_WARN : AuditAction.ADMIN_USER_BAN,
        actorUserId: ctx.userId,
        targetType: 'user',
        targetId: authorId,
        metadata: {
          reason: note,
          reportId,
          ...(body.action === 'BAN' ? { before: author?.status ?? null, after: 'SUSPENDED' } : {}),
          via: 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.MODERATION_REPORT_ACTION,
        actorUserId: ctx.userId,
        targetType: report.targetType.toLowerCase(),
        targetId: reportTargetId(report),
        metadata: { reportId, action: body.action, reportsClosed: closed.count, via: 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    return this.safety.adminGet(reportId);
  }
}
