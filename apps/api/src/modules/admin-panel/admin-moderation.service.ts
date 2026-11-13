import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma, Report } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { MediaService } from '../media/media.service.js';
import { Notifier } from '../notifications/notifier.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import type { SharedReportsQuery } from '../safety/safety.schemas.js';
import {
  reportTargetId,
  reportTargetWhere,
  SafetyService,
  type ReportDto,
} from '../safety/safety.service.js';
import { markReportAlertsReadIn } from '../safety/report-staff-alerts.service.js';
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

/** v1.78-live (D288): who closed a report («تم حله» or an action) — a staff account, by its panel name. */
export interface ReportResolverDto {
  id: string;
  username: string;
  displayName: string;
}

export type PanelReportDto = ReportDto & {
  preview: ReportPreviewDto;
  /** v1.78-live (D288, §10.101): who resolved it (null while OPEN, or the account is gone) and their note. */
  resolvedBy: ReportResolverDto | null;
  resolutionNote: string | null;
  /**
   * v1.93-social (D296, §10.109): the staff action that resolved it automatically (WARN, RESTRICT, SUSPEND, BAN,
   * REMOVE_CONTENT, DISMISS); null for «تم حله» without an action and while OPEN.
   */
  resolutionAction: string | null;
};

type Tx = Prisma.TransactionClient;

const RESOLVER_SELECT = {
  id: true,
  profile: { select: { username: true, displayName: true } },
} satisfies Prisma.UserSelect;

function resolverDto(
  u: { id: string; profile: { username: string; displayName: string } | null } | null,
): ReportResolverDto | null {
  return u
    ? { id: u.id, username: u.profile?.username ?? '', displayName: u.profile?.displayName ?? '' }
    : null;
}
type Db = Pick<
  PrismaService,
  | 'post'
  | 'comment'
  | 'story'
  | 'liveRoom'
  | 'liveChatMessage'
  | 'cpConfession'
  | 'familyChatMessage'
  | 'dmGroup'
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

  /**
   * The shared queue (v1.78-live, D288, §10.101): every role with `reports.view` (OWNER, MODERATION, SUPPORT) sees the
   * same reports — `OPEN` oldest first, `RESOLVED` newest resolution first — with who resolved each and their note.
   * The panel (`listAdminModerationReports`) and the app's «بلاغات» (`listStaffReports`) read this.
   */
  async list(query: SharedReportsQuery) {
    const page = await this.safety.adminList(query);
    const rows = await this.prisma.report.findMany({
      where: { id: { in: page.data.map((r) => r.id) } },
      include: { resolvedBy: { select: RESOLVER_SELECT } },
    });
    const byId = new Map(rows.map((r) => [r.id, r]));
    const data: PanelReportDto[] = [];
    for (const dto of page.data) {
      const row = byId.get(dto.id);
      data.push({
        ...dto,
        preview: row ? await this.preview(row) : { text: null, mediaUrl: null, author: null, gone: true },
        resolvedBy: resolverDto(row?.resolvedBy ?? null),
        resolutionNote: row?.resolutionNote ?? null,
        resolutionAction: row?.resolutionAction ?? null,
      });
    }
    return { data, page: page.page };
  }

  /** One report as the shared queue shows it. */
  async one(reportId: string): Promise<PanelReportDto> {
    const dto = await this.safety.adminGet(reportId);
    const row = await this.prisma.report.findUniqueOrThrow({
      where: { id: reportId },
      include: { resolvedBy: { select: RESOLVER_SELECT } },
    });
    return {
      ...dto,
      preview: await this.preview(row),
      resolvedBy: resolverDto(row.resolvedBy),
      resolutionNote: row.resolutionNote,
      resolutionAction: row.resolutionAction,
    };
  }

  /** D288: the unresolved counter (the panel's nav badge and the app's «بلاغات» row). */
  async summary(): Promise<{ open: number }> {
    return { open: await this.prisma.report.count({ where: { status: 'OPEN' } }) };
  }

  /**
   * D288 «تم حله»: the report is resolved for everyone (ACTIONED, `resolvedAt`, `resolvedById`, the optional note). The
   * row is locked, so of two people pressing at once the first wins and the second gets 409 `REPORT_ALREADY_RESOLVED`
   * (the app and the panel then show who resolved it). Only this report closes (another person's report on the same
   * target stays in the queue). Audited `moderation.report.resolve` {reportId, note, via}.
   */
  async resolve(reportId: string, note: string | undefined, ctx: AdminContext): Promise<PanelReportDto> {
    await this.prisma.$transaction(async (tx: Tx) => {
      const locked = await tx.$queryRaw<
        { status: string }[]
      >`SELECT status::text AS status FROM reports WHERE id = ${reportId}::uuid FOR UPDATE`;
      if (locked.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
      if (locked[0]!.status !== 'OPEN') throw new AppException(ErrorCode.REPORT_ALREADY_RESOLVED);
      const report = await tx.report.update({
        where: { id: reportId },
        data: {
          status: 'ACTIONED',
          resolvedAt: new Date(),
          resolvedById: ctx.userId,
          resolutionNote: note ?? null,
        },
      });
      // The staff's alert about this report is read for everyone now (the inbox would only send them to a closed one).
      await tx.notification.updateMany({
        where: { type: 'STAFF_REPORT_NEW', reportId, readAt: null },
        data: { readAt: new Date() },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.MODERATION_REPORT_RESOLVE,
        actorUserId: ctx.userId,
        targetType: report.targetType.toLowerCase(),
        targetId: reportTargetId(report),
        metadata: { reportId, note: note ?? null, via: ctx.via ?? 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    return this.one(reportId);
  }

  /**
   * D288: reopen a resolved report (`reports.reopen`: OWNER, MODERATION) with a reason: back to OPEN, the resolution cleared (the
   * audit keeps it). An OPEN report → 409 `ADMIN_ACTION_REFUSED` `report_open`; the same person already has another
   * open report on the same target → 409 `report_duplicate`. Nothing done to the target is undone. Audited
   * `moderation.report.reopen` {reportId, reason, before, resolvedById}.
   */
  async reopen(reportId: string, reason: string, ctx: AdminContext): Promise<PanelReportDto> {
    try {
      await this.prisma.$transaction(async (tx: Tx) => {
        const locked = await tx.$queryRaw<
          { id: string }[]
        >`SELECT id::text AS id FROM reports WHERE id = ${reportId}::uuid FOR UPDATE`;
        if (locked.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
        const before = await tx.report.findUniqueOrThrow({ where: { id: reportId } });
        if (before.status === 'OPEN') throw refused('The report is open.', 'report_open', 'rule');
        await tx.report.update({
          where: { id: reportId },
          data: {
            status: 'OPEN',
            resolvedAt: null,
            resolvedById: null,
            resolutionNote: null,
            resolutionAction: null,
          },
        });
        await this.audit.recordIn(tx, {
          action: AuditAction.MODERATION_REPORT_REOPEN,
          actorUserId: ctx.userId,
          targetType: before.targetType.toLowerCase(),
          targetId: reportTargetId(before),
          metadata: {
            reportId,
            reason,
            before: before.status,
            resolvedById: before.resolvedById,
            resolutionAction: before.resolutionAction,
            via: ctx.via ?? 'panel',
          },
          ip: ctx.ip,
          requestId: ctx.requestId,
        });
      });
    } catch (err) {
      if (violatedUniqueIndex(err) !== null)
        throw refused('The same person has another open report on this target.', 'report_duplicate', 'rule');
      throw err;
    }
    return this.one(reportId);
  }

  /** The author (or the reported user) of a report's target, and what it says. */
  async targetOf(
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
    if (r.targetDmGroupId) {
      // v1.104-social (D339): a group — its name as it was when reported (the snapshot; the group may be gone since).
      const s = (r.dmSnapshot ?? {}) as { creatorId?: unknown; name?: unknown };
      return {
        authorId: typeof s.creatorId === 'string' ? s.creatorId : null,
        text: typeof s.name === 'string' ? s.name : null,
        mediaUrl: null,
        gone: (await db.dmGroup.count({ where: { id: r.targetDmGroupId, status: 'ACTIVE' } })) === 0,
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
        { userId: ctx.userId, ip: ctx.ip, requestId: ctx.requestId, via: ctx.via ?? 'panel' },
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
      // v1.93-social (D296): the closed reports record the action, and the staff's alerts about them are read.
      const closing = await tx.report.findMany({
        where: { ...reportTargetWhere(report), status: 'OPEN' },
        select: { id: true },
      });
      const closed = await tx.report.updateMany({
        where: { id: { in: closing.map((r) => r.id) }, status: 'OPEN' },
        data: {
          status: 'ACTIONED',
          resolvedAt: new Date(),
          resolvedById: ctx.userId,
          resolutionNote: note,
          resolutionAction: body.action,
        },
      });
      await markReportAlertsReadIn(
        tx,
        closing.map((r) => r.id),
      );
      await this.audit.recordIn(tx, {
        action: body.action === 'WARN' ? AuditAction.ADMIN_USER_WARN : AuditAction.ADMIN_USER_BAN,
        actorUserId: ctx.userId,
        targetType: 'user',
        targetId: authorId,
        metadata: {
          reason: note,
          reportId,
          ...(body.action === 'BAN' ? { before: author?.status ?? null, after: 'SUSPENDED' } : {}),
          via: ctx.via ?? 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.MODERATION_REPORT_ACTION,
        actorUserId: ctx.userId,
        targetType: report.targetType.toLowerCase(),
        targetId: reportTargetId(report),
        metadata: { reportId, action: body.action, reportsClosed: closed.count, via: ctx.via ?? 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    return this.safety.adminGet(reportId);
  }
}
