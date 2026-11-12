import { Inject, Injectable, Logger } from '@nestjs/common';
import { vipPerkHeldIn } from '../vip/vip-gift-perks.js';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { MediaService } from '../media/media.service.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import { PushService } from '../push/push.service.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { formatStaffId } from '../users/staff-ids.js';
import { GraphError, WHATSAPP_GRAPH, type GraphTemplate, type WhatsAppGraph } from './graph-client.js';
import {
  baseMime,
  fillTemplate,
  MAX_TEXT_CHARS,
  MEDIA_MIME_ALLOWLIST,
  mediaKey,
  phoneSearchOf,
  previewOf,
  windowOf,
} from './whatsapp-core.js';
import { isAtWhatsAppLevel, staffAtLevel } from './whatsapp-access.js';
import { SupportPush } from './support-push.js';
import {
  DEFAULT_DEPARTMENT,
  effectiveDepartments,
  firstAvailable,
  setDepartmentsOf,
  type WaDepartment,
} from './whatsapp-departments.js';

type Tx = Prisma.TransactionClient;

export type WaFilter = 'unassigned' | 'mine' | 'all' | 'closed';

/** v1.137-social (D385, §10.174.6): where a support conversation is. */
export type WaChannel = 'WHATSAPP' | 'IN_APP';

export const WA_TRANSFER_PUSH_TITLE = { ar: 'واتساب Kabso', en: 'Kabso WhatsApp' } as const;

/** The department names in the pushes (the clients word them from the code everywhere else). */
export const WA_DEPARTMENT_NAMES: Record<WaDepartment, { ar: string; en: string }> = {
  PAYMENTS: { ar: 'الشحن والمدفوعات', en: 'Top-ups & payments' },
  AGENCIES: { ar: 'الوكالات والمضيفون', en: 'Agencies & hosts' },
  TECHNICAL: { ar: 'المشاكل التقنية', en: 'Technical issues' },
  REPORTS: { ar: 'البلاغات والحظر', en: 'Reports & bans' },
  GENERAL: { ar: 'عام', en: 'General' },
};

/** «+9665••••4567»: a push never shows the full number on a lock screen. */
function maskedPhoneOf(e164: string | null): string {
  // v1.137-social (D385): an IN_APP thread has no phone (its name is the account's display name).
  if (e164 === null) return 'Kabso';
  if (e164.length <= 8) return e164;
  return `${e164.slice(0, 5)}${'•'.repeat(Math.max(e164.length - 9, 2))}${e164.slice(-4)}`;
}

/** D366 (§10.159.2): a transfer — a department, optionally a person, optionally an internal note. */
export interface WaTransferInput {
  readonly toUserId?: string | undefined;
  readonly department?: WaDepartment | undefined;
  readonly note?: string | undefined;
}

export interface StaffRefDto {
  userId: string;
  displayName: string | null;
  staffId: string | null;
}

export interface WaAccountCardDto {
  userId: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  status: string;
  countryCode: string | null;
  createdAt: string;
}

export interface WaConversationDto {
  id: string;
  /** v1.137-social (D385): null for an IN_APP thread. */
  phone: string | null;
  name: string | null;
  status: 'OPEN' | 'CLOSED';
  assignedTo: StaffRefDto | null;
  assignedToMe: boolean;
  unreadCount: number;
  lastMessageAt: string;
  lastPreview: string | null;
  lastDirection: 'INBOUND' | 'OUTBOUND' | null;
  window: { open: boolean; closesAt: string | null };
  linkedAccount: WaAccountCardDto | null;
  closedAt: string | null;
  createdAt: string;
  /** D366 (§10.159): the department «القسم». */
  department: WaDepartment;
  /**
   * v1.134-social (D381, §10.171.3): the linked account held PRIORITY_SUPPORT when it was linked or last wrote — the
   * inbox lists it first.
   */
  priority: boolean;
  /** v1.137-social (D385, §10.174.6): WHATSAPP, or IN_APP «دعم كابسو» «داخل التطبيق». */
  channel: WaChannel;
}

export interface WaMessageDto {
  id: string;
  direction: 'INBOUND' | 'OUTBOUND';
  type: string;
  text: string | null;
  media: {
    state: string;
    mime: string | null;
    size: number | null;
    filename: string | null;
    voice: boolean;
  } | null;
  location: { latitude: number; longitude: number; name: string | null } | null;
  reaction: string | null;
  template: { name: string; language: string } | null;
  status: string;
  error: { code: number | null; title: string | null } | null;
  sentBy: StaffRefDto | null;
  at: string;
  statusAt: string | null;
}

export interface WaTemplateDto {
  name: string;
  language: string;
  category: string | null;
  body: string | null;
  parameterCount: number;
}

type ConvRow = Prisma.WaConversationGetPayload<object>;
type MsgRow = Prisma.WaMessageGetPayload<object>;

const iso = (d: Date | null | undefined) => (d ? d.toISOString() : null);

/**
 * v1.116-social (D355, CONVENTIONS §10.151): «واتساب» — the shared inbox of the official Kabso WhatsApp number, for the
 * panel (`/admin/whatsapp/*`, cookie) and the staff's app (`/staff/whatsapp/*`, bearer): both guards hand an
 * {@link AdminContext} (the roles held now), so the same rules run for both and audit `via`. Off until the credentials
 * are on the server (503 `WHATSAPP_UNAVAILABLE`; the summary says `enabled: false`).
 */
@Injectable()
export class WhatsAppService {
  private readonly logger = new Logger('WhatsApp');
  private readonly cursors: SocialCursorCodec;
  private templateCache: { at: number; list: WaTemplateDto[] } | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(WHATSAPP_GRAPH) private readonly graph: WhatsAppGraph | null,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    private readonly push: PushService,
    private readonly background: BackgroundTasks,
    private readonly supportPush: SupportPush,
    private readonly mediaPipeline: MediaService,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  get enabled(): boolean {
    return this.graph !== null;
  }

  private requireGraph(): WhatsAppGraph {
    if (!this.graph) throw new AppException(ErrorCode.WHATSAPP_UNAVAILABLE);
    return this.graph;
  }

  /**
   * v1.137-social (D385, §10.174.6): a conversation the inbox serves now — an IN_APP thread always, a WhatsApp one only
   * while WhatsApp is configured (else 503 `WHATSAPP_UNAVAILABLE`, as before).
   */
  private async servedRow(id: string): Promise<ConvRow> {
    const row = await this.rowOf(id);
    if (row.channel === 'WHATSAPP') this.requireGraph();
    return row;
  }

  /** The channels the inbox lists now: both, or (WhatsApp off) the in-app threads only. */
  private servedChannel(): WaChannel | undefined {
    return this.enabled ? undefined : 'IN_APP';
  }

  private audited(ctx: AdminContext) {
    return { actorUserId: ctx.userId, ip: ctx.ip, requestId: ctx.requestId };
  }

  // ---- reading --------------------------------------------------------------------------------------------------

  /** The badge: the conversations waiting for the caller (theirs and the unassigned ones) with unread messages. */
  async summary(ctx: AdminContext) {
    // v1.137-social (D385, §10.174.6): the in-app threads are always served; with WhatsApp off, only they count.
    const channel = this.servedChannel();
    const [mine, unassigned] = await Promise.all([
      this.prisma.waConversation.aggregate({
        where: {
          status: 'OPEN',
          assignedToId: ctx.userId,
          unreadCount: { gt: 0 },
          purgeAfter: null,
          ...(channel ? { channel } : {}),
        },
        _count: { _all: true },
        _sum: { unreadCount: true },
      }),
      this.prisma.waConversation.aggregate({
        where: {
          status: 'OPEN',
          assignedToId: null,
          unreadCount: { gt: 0 },
          purgeAfter: null,
          ...(channel ? { channel } : {}),
        },
        _count: { _all: true },
        _sum: { unreadCount: true },
      }),
    ]);
    return {
      enabled: this.enabled,
      inApp: true,
      badge: mine._count._all + unassigned._count._all,
      mine: mine._count._all,
      unassigned: unassigned._count._all,
      unreadMessages: (mine._sum.unreadCount ?? 0) + (unassigned._sum.unreadCount ?? 0),
    };
  }

  async list(
    ctx: AdminContext,
    q: {
      filter: WaFilter;
      department?: WaDepartment | undefined;
      channel?: WaChannel | undefined;
      q?: string;
      cursor?: string;
      limit: number;
    },
  ) {
    // v1.137-social (D385, §10.174.6): WhatsApp off → the in-app threads only (asking for WhatsApp ones: 503).
    if (q.channel === 'WHATSAPP') this.requireGraph();
    const channel = q.channel ?? this.servedChannel();
    const term = q.q?.trim() ?? '';
    const scope = `wa:${q.filter}:${ctx.userId}:${q.department ?? '*'}:${channel ?? '*'}:${term}`;
    const where: Prisma.WaConversationWhereInput = { purgeAfter: null };
    if (q.department) where.department = q.department;
    if (channel) where.channel = channel;
    if (q.filter === 'closed') where.status = 'CLOSED';
    else where.status = 'OPEN';
    if (q.filter === 'unassigned') where.assignedToId = null;
    if (q.filter === 'mine') where.assignedToId = ctx.userId;
    if (term.length > 0) {
      const phone = phoneSearchOf(term);
      where.OR = [
        { profileName: { contains: term, mode: 'insensitive' } },
        ...(phone ? [{ phoneE164: { startsWith: phone } }] : []),
      ];
    }
    if (q.cursor) {
      const pos = this.cursors.decode(q.cursor, scope);
      if (!pos) {
        throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
      }
      // v1.134-social (D381, §10.171.3): the order is priority first; the cursor keeps {at, id} and the priority is
      // the cursor row's now.
      const at = await this.prisma.waConversation.findUnique({
        where: { id: pos.id },
        select: { priority: true },
      });
      const p = at?.priority ?? false;
      where.AND = [
        {
          OR: [
            ...(p ? [{ priority: false }] : []),
            { priority: p, lastMessageAt: { lt: pos.at } },
            { priority: p, lastMessageAt: pos.at, id: { lt: pos.id } },
          ],
        },
      ];
    }
    const rows = await this.prisma.waConversation.findMany({
      where,
      // v1.134-social (D381, §10.171.3): PRIORITY_SUPPORT holders' conversations first, each newest first.
      orderBy: [{ priority: 'desc' }, { lastMessageAt: 'desc' }, { id: 'desc' }],
      take: q.limit + 1,
    });
    const more = rows.length > q.limit;
    const page = rows.slice(0, q.limit);
    const last = page[page.length - 1];
    return {
      data: await this.conversationsOf(page, ctx),
      page: {
        nextCursor: more && last ? this.cursors.encode(scope, { at: last.lastMessageAt, id: last.id }) : null,
        hasMore: more,
      },
    };
  }

  private async rowOf(id: string): Promise<ConvRow> {
    const row = await this.prisma.waConversation.findUnique({ where: { id } });
    if (!row || row.purgeAfter !== null) throw new AppException(ErrorCode.NOT_FOUND);
    return row;
  }

  async get(ctx: AdminContext, id: string): Promise<WaConversationDto> {
    return (await this.conversationsOf([await this.servedRow(id)], ctx))[0]!;
  }

  async messages(ctx: AdminContext, id: string, q: { cursor?: string; limit: number }) {
    await this.servedRow(id);
    const scope = `wa-msg:${id}`;
    const where: Prisma.WaMessageWhereInput = { conversationId: id, type: { not: 'REACTION' } };
    if (q.cursor) {
      const pos = this.cursors.decode(q.cursor, scope);
      if (!pos) {
        throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
      }
      where.OR = [{ createdAt: { lt: pos.at } }, { createdAt: pos.at, id: { lt: pos.id } }];
    }
    const rows = await this.prisma.waMessage.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: q.limit + 1,
    });
    const more = rows.length > q.limit;
    const page = rows.slice(0, q.limit);
    const last = page[page.length - 1];
    void ctx;
    return {
      data: await this.messagesOf(page),
      page: {
        nextCursor: more && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
        hasMore: more,
      },
    };
  }

  /** A message's media bytes from the private storage (`Cache-Control: private, no-store`). */
  async media(id: string): Promise<{ bytes: Buffer; mime: string; filename: string | null }> {
    const row = await this.prisma.waMessage.findUnique({
      where: { id },
      select: {
        mediaKey: true,
        mediaState: true,
        mediaMime: true,
        mediaFilename: true,
        conversation: true,
        mediaAsset: { select: { largeKey: true } },
      },
    });
    if (row?.conversation.channel === 'WHATSAPP') this.requireGraph();
    // v1.137-social (D385, §10.174.3): an in-app picture or voice clip is the person's upload's file.
    const key = row?.mediaKey ?? row?.mediaAsset?.largeKey ?? null;
    if (!row || row.conversation.purgeAfter !== null || row.mediaState !== 'STORED' || !key) {
      throw new AppException(ErrorCode.NOT_FOUND);
    }
    const bytes = await this.storage.get(key, this.config.whatsapp.mediaMaxBytes);
    if (!bytes) throw new AppException(ErrorCode.NOT_FOUND);
    return {
      bytes,
      mime: baseMime(row.mediaMime) || 'application/octet-stream',
      filename: row.mediaFilename,
    };
  }

  // ---- DTOs -----------------------------------------------------------------------------------------------------

  private async staffRefs(ids: readonly (string | null)[]): Promise<Map<string, StaffRefDto>> {
    const want = [...new Set(ids.filter((i): i is string => i !== null))];
    if (want.length === 0) return new Map();
    const [profiles, numbers] = await Promise.all([
      this.prisma.userProfile.findMany({
        where: { userId: { in: want } },
        select: { userId: true, displayName: true },
      }),
      this.prisma.staffId.findMany({
        where: { userId: { in: want } },
        select: { userId: true, number: true },
      }),
    ]);
    const map = new Map<string, StaffRefDto>();
    for (const id of want) {
      const p = profiles.find((x) => x.userId === id);
      const n = numbers.find((x) => x.userId === id);
      map.set(id, {
        userId: id,
        displayName: p?.displayName ?? null,
        staffId: n ? formatStaffId(n.number) : null,
      });
    }
    return map;
  }

  private async accountCards(ids: readonly (string | null)[]): Promise<Map<string, WaAccountCardDto>> {
    const want = [...new Set(ids.filter((i): i is string => i !== null))];
    if (want.length === 0) return new Map();
    const users = await this.prisma.user.findMany({
      where: { id: { in: want } },
      select: {
        id: true,
        status: true,
        createdAt: true,
        profile: { select: { username: true, displayName: true, avatarUrl: true, countryCode: true } },
      },
    });
    const map = new Map<string, WaAccountCardDto>();
    for (const u of users) {
      if (!u.profile || u.status === 'DELETED') continue;
      map.set(u.id, {
        userId: u.id,
        username: u.profile.username,
        displayName: u.profile.displayName,
        avatarUrl: u.profile.avatarUrl,
        status: u.status,
        countryCode: u.profile.countryCode,
        createdAt: u.createdAt.toISOString(),
      });
    }
    return map;
  }

  private async conversationsOf(rows: readonly ConvRow[], ctx: AdminContext): Promise<WaConversationDto[]> {
    const now = this.clock.now();
    const [staff, cards] = await Promise.all([
      this.staffRefs(rows.map((r) => r.assignedToId)),
      this.accountCards(rows.map((r) => r.linkedUserId)),
    ]);
    return rows.map((r) => {
      // v1.137-social (D385, §10.174.6): no 24-hour window in the app.
      const w = r.channel === 'IN_APP' ? { open: true, closesAt: null } : windowOf(r.lastInboundAt, now);
      return {
        id: r.id,
        phone: r.phoneE164,
        name: r.profileName,
        status: r.status,
        assignedTo: r.assignedToId ? (staff.get(r.assignedToId) ?? null) : null,
        assignedToMe: r.assignedToId === ctx.userId,
        unreadCount: r.unreadCount,
        lastMessageAt: r.lastMessageAt.toISOString(),
        lastPreview: r.lastPreview,
        lastDirection: r.lastDirection,
        window: { open: w.open, closesAt: iso(w.closesAt) },
        linkedAccount: r.linkedUserId ? (cards.get(r.linkedUserId) ?? null) : null,
        closedAt: iso(r.closedAt),
        createdAt: r.createdAt.toISOString(),
        department: r.department,
        priority: r.priority,
        channel: r.channel,
      };
    });
  }

  private async messagesOf(rows: readonly MsgRow[]): Promise<WaMessageDto[]> {
    const staff = await this.staffRefs(rows.map((r) => r.sentById));
    return rows.map((r) => ({
      id: r.id,
      direction: r.direction,
      type: r.type,
      text: r.body,
      media:
        r.mediaState === 'NONE'
          ? null
          : {
              state: r.mediaState,
              mime: r.mediaMime,
              size: r.mediaSize,
              filename: r.mediaFilename,
              voice: r.mediaVoice,
            },
      location:
        r.latitude !== null && r.longitude !== null
          ? { latitude: r.latitude, longitude: r.longitude, name: r.locationName }
          : null,
      reaction: r.reactionEmoji,
      template: r.templateName ? { name: r.templateName, language: r.templateLang ?? '' } : null,
      status: r.status,
      error:
        r.errorCode !== null || r.errorTitle !== null ? { code: r.errorCode, title: r.errorTitle } : null,
      sentBy: r.sentById ? (staff.get(r.sentById) ?? null) : null,
      at: (r.waTimestamp ?? r.createdAt).toISOString(),
      statusAt: iso(r.statusAt),
    }));
  }

  // ---- sending --------------------------------------------------------------------------------------------------

  /**
   * The send rules (§10.151.4): open conversation; the caller's or unassigned (then the caller claims it); free-form
   * text and media only inside the 24-hour window, a template always.
   */
  private async sendable(ctx: AdminContext, id: string, freeForm: boolean): Promise<ConvRow> {
    const row = await this.servedRow(id);
    if (row.status === 'CLOSED') throw new AppException(ErrorCode.WHATSAPP_CONVERSATION_CLOSED);
    if (row.assignedToId !== null && row.assignedToId !== ctx.userId) {
      throw new AppException(ErrorCode.WHATSAPP_CONVERSATION_ASSIGNED);
    }
    // v1.137-social (D385, §10.174.6): no 24-hour window in the app.
    if (row.channel === 'WHATSAPP' && freeForm && !windowOf(row.lastInboundAt, this.clock.now()).open) {
      throw new AppException(ErrorCode.WHATSAPP_WINDOW_CLOSED);
    }
    return row;
  }

  /** Meta's error → the contract's: the window (131047 re-engagement), the rate limits, else 502. */
  private sendFailure(err: unknown): never {
    if (err instanceof GraphError) {
      this.logger.warn({ status: err.status, code: err.code }, 'WhatsApp send refused');
      if (err.code === 131047) throw new AppException(ErrorCode.WHATSAPP_WINDOW_CLOSED);
      if (err.code === 130429 || err.code === 131056 || err.code === 80007 || err.code === 4) {
        throw new AppException(ErrorCode.RATE_LIMITED, undefined, undefined, { 'Retry-After': '60' });
      }
      throw new AppException(ErrorCode.WHATSAPP_SEND_FAILED, undefined, [
        { field: 'whatsapp', issue: err.code !== null ? `meta_${err.code}` : `http_${err.status}` },
      ]);
    }
    throw err;
  }

  /** Stores the sent message, claims an unassigned conversation and audits — one transaction. */
  private async recordSent(
    ctx: AdminContext,
    conv: ConvRow,
    data: Omit<Prisma.WaMessageUncheckedCreateInput, 'conversationId' | 'direction' | 'status'>,
    preview: string,
  ): Promise<WaMessageDto> {
    const now = this.clock.now();
    const row = await this.prisma.$transaction(async (tx) => {
      // D360: claimed only if the sender can still answer (their level may have gone down since the guard; then the
      // message is kept — it was sent — and the conversation stays unassigned). The staff row first (lock order).
      const claim = conv.assignedToId === null && (await this.canAnswerIn(tx, ctx.userId));
      const msg = await tx.waMessage.create({
        data: {
          ...data,
          conversationId: conv.id,
          direction: 'OUTBOUND',
          status: 'SENT',
          sentById: ctx.userId,
          statusAt: now,
          createdAt: now,
        },
      });
      await tx.waConversation.update({
        where: { id: conv.id },
        data: {
          lastMessageAt: now,
          lastPreview: preview,
          lastDirection: 'OUTBOUND',
          updatedAt: now,
          ...(claim ? { assignedToId: ctx.userId, assignedAt: now } : {}),
        },
      });
      if (claim) {
        await tx.waAssignment.create({
          data: { conversationId: conv.id, action: 'CLAIM', toUserId: ctx.userId, actorId: ctx.userId },
        });
      }
      await this.audit.recordIn(tx, {
        ...this.audited(ctx),
        action: AuditAction.WHATSAPP_SEND,
        targetType: 'wa_conversation',
        targetId: conv.id,
        metadata: {
          messageId: msg.id,
          type: data.type,
          claimed: claim,
          channel: conv.channel,
          via: ctx.via ?? 'panel',
        },
      });
      return msg;
    });
    return (await this.messagesOf([row]))[0]!;
  }

  async sendText(ctx: AdminContext, id: string, text: string): Promise<WaMessageDto> {
    const conv = await this.sendable(ctx, id, true);
    const body = text.trim();
    if (body.length === 0 || body.length > MAX_TEXT_CHARS) {
      throw AppException.validation([{ field: 'text', issue: 'invalid_value' }]);
    }
    if (conv.channel === 'IN_APP') {
      // v1.137-social (D385, §10.174.6): stored for the person's «دعم كابسو», who is pushed (every reply).
      const sent = await this.recordSent(ctx, conv, { type: 'TEXT', body }, previewOf('TEXT', body));
      const userId = conv.linkedUserId!;
      this.background.run('support.reply.push', async () => {
        await this.supportPush.reply({ userId, conversationId: conv.id, staffId: ctx.userId, text: body });
      });
      return sent;
    }
    const graph = this.requireGraph();
    let waMessageId: string;
    try {
      ({ waMessageId } = await graph.sendMessage({
        to: conv.waId,
        type: 'text',
        text: { body, preview_url: false },
      }));
    } catch (err) {
      this.sendFailure(err);
    }
    return this.recordSent(ctx, conv, { waMessageId, type: 'TEXT', body }, previewOf('TEXT', body));
  }

  async sendTemplate(
    ctx: AdminContext,
    id: string,
    t: { name: string; language: string; parameters: readonly string[] },
  ): Promise<WaMessageDto> {
    const conv = await this.sendable(ctx, id, false);
    // v1.137-social (D385, §10.174.6): no templates in the app.
    if (conv.channel === 'IN_APP') throw AppException.validation([{ field: 'template', issue: 'in_app' }]);
    const graph = this.requireGraph();
    const template = (await this.templates()).find((x) => x.name === t.name && x.language === t.language);
    if (!template) {
      throw AppException.validation([{ field: 'template', issue: 'not_approved' }]);
    }
    if (t.parameters.length !== template.parameterCount) {
      throw AppException.validation([{ field: 'parameters', issue: 'count_mismatch' }]);
    }
    let waMessageId: string;
    try {
      ({ waMessageId } = await graph.sendMessage({
        to: conv.waId,
        type: 'template',
        template: {
          name: template.name,
          language: { code: template.language },
          ...(t.parameters.length > 0
            ? {
                components: [
                  { type: 'body', parameters: t.parameters.map((p) => ({ type: 'text', text: p })) },
                ],
              }
            : {}),
        },
      }));
    } catch (err) {
      this.sendFailure(err);
    }
    const body = fillTemplate(template.body, t.parameters);
    return this.recordSent(
      ctx,
      conv,
      { waMessageId, type: 'TEMPLATE', body, templateName: template.name, templateLang: template.language },
      previewOf('TEMPLATE', body ?? template.name),
    );
  }

  /** Outbound media: allowlisted type and size, uploaded to Meta, kept in the private storage for the inbox. */
  async sendMedia(
    ctx: AdminContext,
    id: string,
    bytes: unknown,
    q: { mime: string; filename?: string; caption?: string },
  ): Promise<WaMessageDto> {
    const target = await this.servedRow(id);
    if (target.channel === 'IN_APP') return this.sendInAppPicture(ctx, id, bytes, q);
    const graph = this.requireGraph();
    const mime = baseMime(q.mime);
    const kind = MEDIA_MIME_ALLOWLIST[mime];
    if (!kind || kind === 'STICKER') {
      throw AppException.validation([{ field: 'mime', issue: 'not_allowed' }]);
    }
    if (!Buffer.isBuffer(bytes) || bytes.length === 0) {
      throw AppException.validation([{ field: 'body', issue: 'required' }]);
    }
    if (bytes.length > this.config.whatsapp.mediaMaxBytes) {
      throw AppException.validation([{ field: 'body', issue: 'too_large' }]);
    }
    const conv = await this.sendable(ctx, id, true);
    const filename = (q.filename ?? '').trim() || `kabso.${mime.split('/')[1] ?? 'bin'}`;
    const caption = q.caption?.trim() || null;
    const type = kind.toLowerCase();
    let waMessageId: string;
    try {
      const mediaId = await graph.uploadMedia(bytes, mime, filename);
      const media: Record<string, unknown> = { id: mediaId };
      if (caption && kind !== 'AUDIO') media.caption = caption;
      if (kind === 'DOCUMENT') media.filename = filename;
      ({ waMessageId } = await graph.sendMessage({ to: conv.waId, type, [type]: media }));
    } catch (err) {
      this.sendFailure(err);
    }
    const sent = await this.recordSent(
      ctx,
      conv,
      {
        waMessageId,
        type: kind,
        body: kind === 'AUDIO' ? null : caption,
        mediaState: 'NONE',
        mediaMime: mime,
        mediaSize: bytes.length,
        mediaFilename: filename.slice(0, 240),
      },
      previewOf(kind, caption),
    );
    // Kept for the inbox (best effort: Meta already has it).
    const key = mediaKey(conv.id, sent.id, mime);
    try {
      await this.storage.put(key, bytes, mime, 'private, no-store');
      await this.prisma.waMessage.update({
        where: { id: sent.id },
        data: { mediaKey: key, mediaState: 'STORED' },
      });
      return { ...sent, media: { state: 'STORED', mime, size: bytes.length, filename, voice: false } };
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not keep a sent WhatsApp media file');
      await this.prisma.waMessage.update({ where: { id: sent.id }, data: { mediaState: 'FAILED' } });
      return { ...sent, media: { state: 'FAILED', mime, size: bytes.length, filename, voice: false } };
    }
  }

  /**
   * v1.137-social (D385, §10.174.6; owner 2026-11-12): a picture in an in-app thread — the direct-message image rules
   * and pipeline ({@link MediaService.storeRawImage}: an asset of the sender), the send rules of a text (open, the
   * caller's or unassigned), audited and pushed like a text. Nothing goes to Meta.
   */
  private async sendInAppPicture(
    ctx: AdminContext,
    id: string,
    bytes: unknown,
    q: { mime: string; caption?: string },
  ): Promise<WaMessageDto> {
    const mime = baseMime(q.mime);
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(mime)) {
      throw AppException.validation([{ field: 'mime', issue: 'not_allowed' }]);
    }
    if (!Buffer.isBuffer(bytes) || bytes.length === 0) {
      throw AppException.validation([{ field: 'body', issue: 'required' }]);
    }
    if (bytes.length > this.config.whatsapp.mediaMaxBytes) {
      throw AppException.validation([{ field: 'body', issue: 'too_large' }]);
    }
    const conv = await this.sendable(ctx, id, true);
    const asset = await this.mediaPipeline.storeRawImage(ctx.userId, bytes, mime);
    const caption = q.caption?.trim() || null;
    let sent: WaMessageDto;
    try {
      sent = await this.recordSent(
        ctx,
        conv,
        {
          type: 'IMAGE',
          body: caption,
          mediaState: 'STORED',
          mediaAssetId: asset.id,
          mediaMime: 'image/webp',
          mediaSize: asset.byteSize,
        },
        previewOf('IMAGE', caption),
      );
    } catch (err) {
      await this.mediaPipeline.purgeAssets([asset]).catch(() => 0);
      throw err;
    }
    const userId = conv.linkedUserId!;
    this.background.run('support.reply.push', async () => {
      await this.supportPush.reply({
        userId,
        conversationId: conv.id,
        staffId: ctx.userId,
        text: caption ?? '📷',
      });
    });
    return sent;
  }

  /** The approved templates (cached `WHATSAPP_TEMPLATE_CACHE_SECONDS`; `refresh` reads Meta now). */
  async templates(refresh = false): Promise<WaTemplateDto[]> {
    const graph = this.requireGraph();
    const now = this.clock.now().getTime();
    const ttl = this.config.whatsapp.templateCacheSeconds * 1000;
    if (!refresh && this.templateCache && now - this.templateCache.at < ttl) return this.templateCache.list;
    let list: GraphTemplate[];
    try {
      list = await graph.templates();
    } catch (err) {
      if (this.templateCache) return this.templateCache.list;
      if (err instanceof GraphError) {
        throw new AppException(ErrorCode.WHATSAPP_SEND_FAILED, undefined, [
          { field: 'templates', issue: err.code !== null ? `meta_${err.code}` : `http_${err.status}` },
        ]);
      }
      throw err;
    }
    const dto = list.map((t) => ({
      name: t.name,
      language: t.language,
      category: t.category,
      body: t.body,
      parameterCount: t.parameterCount,
    }));
    this.templateCache = { at: now, list: dto };
    return dto;
  }

  /** The team read the conversation: the unread count goes to 0 and the customer sees blue ticks (best effort). */
  async markRead(ctx: AdminContext, id: string): Promise<WaConversationDto> {
    const row = await this.servedRow(id);
    if (row.channel === 'IN_APP') {
      // v1.137-social (D385, §10.174.2): the person's «تم الاستلام» becomes read; nothing goes to Meta.
      await this.prisma.waConversation.update({
        where: { id },
        data: { unreadCount: 0, staffReadAt: this.clock.now() },
      });
      return this.get(ctx, id);
    }
    const graph = this.requireGraph();
    if (row.unreadCount > 0) {
      await this.prisma.waConversation.update({ where: { id }, data: { unreadCount: 0 } });
      const lastIn = await this.prisma.waMessage.findFirst({
        where: { conversationId: id, direction: 'INBOUND', waMessageId: { not: null } },
        orderBy: { createdAt: 'desc' },
        select: { waMessageId: true },
      });
      if (lastIn?.waMessageId) {
        await graph.markRead(lastIn.waMessageId).catch((err: unknown) => {
          this.logger.warn({ error: safeErrorLog(err) }, 'WhatsApp read receipt failed');
        });
      }
    }
    return this.get(ctx, id);
  }

  // ---- assignment -----------------------------------------------------------------------------------------------

  /** MANAGE (D360: the person's WhatsApp level, carried by the guard's context like the roles). */
  private manages(ctx: AdminContext): boolean {
    return ctx.capabilities.includes('support.whatsapp.manage');
  }

  /**
   * D360 (§10.155.4): whether `userId` can be given a conversation now (an ACTIVE staff account at REPLY or above).
   * Their `users` row is share-locked first, so a level change (which locks it for update, then releases their
   * conversations) runs entirely before or after — never a conversation assigned to someone just lowered to VIEW.
   */
  private async canAnswerIn(tx: Tx, userId: string): Promise<boolean> {
    await tx.$queryRaw`SELECT 1 FROM users WHERE id = ${userId}::uuid FOR SHARE`;
    return isAtWhatsAppLevel(tx, userId, 'REPLY');
  }

  private async assign(
    ctx: AdminContext,
    id: string,
    action: 'CLAIM' | 'RELEASE' | 'TRANSFER' | 'CLOSE' | 'REOPEN',
    apply: (
      row: ConvRow,
      tx: Tx,
      answerer: boolean,
    ) => Promise<{ to: string | null; data: Prisma.WaConversationUpdateInput } | null>,
    /** The staff member the conversation would go to (checked with {@link canAnswerIn} before the row lock). */
    to?: string,
  ): Promise<WaConversationDto> {
    const served = await this.servedRow(id);
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      const answerer = to ? await this.canAnswerIn(tx, to) : false;
      const [locked] = await tx.$queryRaw<{ id: string }[]>`
        SELECT id::text AS id FROM wa_conversations WHERE id = ${id}::uuid AND purge_after IS NULL FOR UPDATE`;
      if (!locked) throw new AppException(ErrorCode.NOT_FOUND);
      const row = (await tx.waConversation.findUnique({ where: { id } }))!;
      const change = await apply(row, tx, answerer);
      if (!change) return;
      await tx.waConversation.update({ where: { id }, data: { ...change.data, updatedAt: now } });
      await tx.waAssignment.create({
        data: {
          conversationId: id,
          action,
          fromUserId: row.assignedToId,
          toUserId: change.to,
          actorId: ctx.userId,
        },
      });
      await this.audit.recordIn(tx, {
        ...this.audited(ctx),
        action: AuditAction.WHATSAPP_ASSIGN,
        targetType: 'wa_conversation',
        targetId: id,
        metadata: {
          action,
          from: row.assignedToId,
          to: change.to,
          channel: served.channel,
          via: ctx.via ?? 'panel',
        },
      });
    });
    return this.get(ctx, id);
  }

  claim(ctx: AdminContext, id: string) {
    const now = this.clock.now();
    return this.assign(
      ctx,
      id,
      'CLAIM',
      async (row, _tx, answerer) => {
        if (!answerer) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
        if (row.status === 'CLOSED') throw new AppException(ErrorCode.WHATSAPP_CONVERSATION_CLOSED);
        if (row.assignedToId === ctx.userId) return null;
        if (row.assignedToId !== null) throw new AppException(ErrorCode.WHATSAPP_CONVERSATION_ASSIGNED);
        return { to: ctx.userId, data: { assignedToId: ctx.userId, assignedAt: now } };
      },
      ctx.userId,
    );
  }

  release(ctx: AdminContext, id: string) {
    return this.assign(ctx, id, 'RELEASE', async (row) => {
      if (row.assignedToId === null) return null;
      if (row.assignedToId !== ctx.userId && !this.manages(ctx)) {
        throw new AppException(ErrorCode.WHATSAPP_CONVERSATION_ASSIGNED);
      }
      return { to: null, data: { assignedToId: null, assignedAt: null } };
    });
  }

  /**
   * D366 (CONVENTIONS §10.159.2): the transfer — to a `department` (required since D366), optionally to a person in it
   * (REPLY+, a member of that department), else «أول متاح في القسم» (the on-shift member with the fewest open assigned
   * conversations, ties to the one assigned least recently) or, nobody on shift, the department's unassigned queue. An
   * optional note is stored as an internal note (never sent) linked to the history row. Without a department (an app
   * or panel before D366): D355's call — `toUserId` required, the department GENERAL, no membership check.
   */
  async transfer(ctx: AdminContext, id: string, input: WaTransferInput | string): Promise<WaConversationDto> {
    const served = await this.servedRow(id);
    const body: WaTransferInput = typeof input === 'string' ? { toUserId: input } : input;
    const legacy = body.department === undefined;
    const department: WaDepartment = body.department ?? DEFAULT_DEPARTMENT;
    const noteText = body.note?.trim() ?? '';
    const now = this.clock.now();
    const outcome = await this.prisma.$transaction(async (tx) => {
      // Routing into one department runs one at a time (two «first available» never both count the same load).
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:wa-dept'), hashtext(${department}))`;
      const peek = await tx.waConversation.findUnique({
        where: { id },
        select: { assignedToId: true, purgeAfter: true },
      });
      if (!peek || peek.purgeAfter !== null) throw new AppException(ErrorCode.NOT_FOUND);
      let to: string | null;
      if (body.toUserId !== undefined) {
        // The target's `users` row share-locked BEFORE the conversation (the D360 lock order).
        if (!(await this.canAnswerIn(tx, body.toUserId))) {
          throw AppException.validation([{ field: 'toUserId', issue: 'not_an_agent' }]);
        }
        if (!legacy) {
          const theirs = effectiveDepartments(
            (await setDepartmentsOf(tx, [body.toUserId])).get(body.toUserId),
          );
          if (!theirs.includes(department)) {
            throw AppException.validation([{ field: 'toUserId', issue: 'not_in_department' }]);
          }
        }
        to = body.toUserId;
      } else {
        to = await this.pickFirstAvailable(tx, department, peek.assignedToId);
      }
      const [locked] = await tx.$queryRaw<{ id: string }[]>`
        SELECT id::text AS id FROM wa_conversations WHERE id = ${id}::uuid AND purge_after IS NULL FOR UPDATE`;
      if (!locked) throw new AppException(ErrorCode.NOT_FOUND);
      const row = (await tx.waConversation.findUnique({ where: { id } }))!;
      if (row.status === 'CLOSED') throw new AppException(ErrorCode.WHATSAPP_CONVERSATION_CLOSED);
      if (row.assignedToId !== null && row.assignedToId !== ctx.userId && !this.manages(ctx)) {
        throw new AppException(ErrorCode.WHATSAPP_CONVERSATION_ASSIGNED);
      }
      // Nothing changes (same person, same department, no note): D355's no-op.
      if (row.assignedToId === to && row.department === department && noteText.length === 0) {
        return null;
      }
      const note =
        noteText.length > 0
          ? await tx.waNote.create({
              data: { conversationId: id, authorId: ctx.userId, body: noteText, createdAt: now },
            })
          : null;
      await tx.waConversation.update({
        where: { id },
        data: {
          department,
          assignedToId: to,
          assignedAt: to === null ? null : row.assignedToId === to ? row.assignedAt : now,
          updatedAt: now,
        },
      });
      const history = await tx.waAssignment.create({
        data: {
          conversationId: id,
          action: 'TRANSFER',
          fromUserId: row.assignedToId,
          toUserId: to,
          actorId: ctx.userId,
          department,
          fromDepartment: row.department,
          noteId: note?.id ?? null,
          createdAt: now,
        },
      });
      await this.audit.recordIn(tx, {
        ...this.audited(ctx),
        action: AuditAction.WHATSAPP_ASSIGN,
        targetType: 'wa_conversation',
        targetId: id,
        metadata: {
          action: 'TRANSFER',
          from: row.assignedToId,
          to,
          department,
          fromDepartment: row.department,
          routed: body.toUserId === undefined ? (to === null ? 'queue' : 'first_available') : 'person',
          noteId: note?.id ?? null,
          legacy,
          assignmentId: history.id,
          channel: served.channel,
          via: ctx.via ?? 'panel',
        },
      });
      return {
        to,
        department,
        conv: { id: row.id, profileName: row.profileName, phoneE164: row.phoneE164 },
      };
    });
    if (outcome) {
      const o = outcome;
      this.background.run('whatsapp.transfer.push', () => this.transferPush(ctx.userId, o));
    }
    return this.get(ctx, id);
  }

  /**
   * «أول متاح في القسم»: the REPLY+ staff ON SHIFT who belong to `department`, except the conversation's current
   * assignee (a transfer hands it to someone else); the fewest open assigned conversations, then the least recently
   * assigned ({@link firstAvailable}). The chosen one's `users` row is share-locked and their level checked again
   * (a level change between the read and the lock picks the next one). Null: nobody — the department's queue.
   */
  private async pickFirstAvailable(
    tx: Tx,
    department: WaDepartment,
    current: string | null,
  ): Promise<string | null> {
    const members = await this.departmentAgents(tx, department);
    const shifts = await tx.adminShift.findMany({
      where: { userId: { in: members }, onShift: true },
      select: { userId: true },
    });
    const on = new Set(shifts.map((s) => s.userId));
    let pool = members.filter((m) => on.has(m) && m !== current);
    while (pool.length > 0) {
      const loads = await this.loadsOf(tx, pool);
      const best = firstAvailable(
        pool.map((userId) => ({
          userId,
          open: loads.open.get(userId) ?? 0,
          lastAssignedAt: loads.last.get(userId) ?? null,
        })),
      );
      if (!best) return null;
      if (await this.canAnswerIn(tx, best.userId)) return best.userId;
      pool = pool.filter((u) => u !== best.userId);
    }
    return null;
  }

  /** The REPLY+ staff who belong to `department` (no membership set: GENERAL), oldest account first. */
  private async departmentAgents(db: Tx | PrismaService, department: WaDepartment): Promise<string[]> {
    const ids = (await staffAtLevel(db, 'REPLY')).map((a) => a.userId);
    const set = await setDepartmentsOf(db, ids);
    return ids.filter((u) => effectiveDepartments(set.get(u)).includes(department));
  }

  /** Each person's open assigned conversations and their last CLAIM / TRANSFER received. */
  private async loadsOf(db: Tx | PrismaService, userIds: readonly string[]) {
    const open = new Map<string, number>();
    const last = new Map<string, Date>();
    if (userIds.length === 0) return { open, last };
    const [counts, latest] = await Promise.all([
      db.waConversation.groupBy({
        by: ['assignedToId'],
        where: { assignedToId: { in: [...userIds] }, status: 'OPEN', purgeAfter: null },
        _count: { _all: true },
      }),
      db.waAssignment.groupBy({
        by: ['toUserId'],
        where: { toUserId: { in: [...userIds] }, action: { in: ['CLAIM', 'TRANSFER'] } },
        _max: { createdAt: true },
      }),
    ]);
    for (const c of counts) if (c.assignedToId) open.set(c.assignedToId, c._count._all);
    for (const l of latest) if (l.toUserId && l._max.createdAt) last.set(l.toUserId, l._max.createdAt);
    return { open, last };
  }

  /**
   * D366 (§10.159.5): who a transfer is pushed to — the receiver; for the queue, the department's REPLY+ members on
   * shift, else all of them (somebody who can reply is always told, as D360). Never the one who transferred, never a
   * muted one, never below REPLY. Exported for the tests through {@link transferPushRecipients}.
   */
  async transferPushRecipients(
    actorId: string,
    outcome: { to: string | null; department: WaDepartment },
  ): Promise<string[]> {
    const muted = new Set(
      (
        await this.prisma.waAgentSetting.findMany({ where: { pushMuted: true }, select: { userId: true } })
      ).map((s) => s.userId),
    );
    let ids: string[];
    if (outcome.to !== null) {
      ids = (await this.isAgent(this.prisma, outcome.to)) ? [outcome.to] : [];
    } else {
      const members = await this.departmentAgents(this.prisma, outcome.department);
      const on = new Set(
        (
          await this.prisma.adminShift.findMany({
            where: { userId: { in: members }, onShift: true },
            select: { userId: true },
          })
        ).map((s) => s.userId),
      );
      const onShift = members.filter((m) => on.has(m) && m !== actorId);
      ids = onShift.length > 0 ? onShift : members;
    }
    return ids.filter((u) => u !== actorId && !muted.has(u));
  }

  private async transferPush(
    actorId: string,
    o: {
      to: string | null;
      department: WaDepartment;
      conv: { id: string; profileName: string | null; phoneE164: string | null };
    },
  ) {
    if (!this.push.enabled) return;
    const userIds = await this.transferPushRecipients(actorId, o);
    if (userIds.length === 0) return;
    const who = o.conv.profileName?.trim() || maskedPhoneOf(o.conv.phoneE164);
    const dept = WA_DEPARTMENT_NAMES[o.department];
    await this.push.deliver({
      userIds,
      channel: 'staff',
      tag: `wa:${o.conv.id}`,
      data: {
        kind: 'whatsapp',
        channel: 'staff',
        conversationId: o.conv.id,
        event: 'transfer',
        department: o.department,
      },
      text: (locale) => ({
        title: WA_TRANSFER_PUSH_TITLE[locale],
        body:
          o.to !== null
            ? locale === 'ar'
              ? `حُوّلت إليك محادثة ${who} — ${dept.ar}`
              : `${who}'s conversation was transferred to you — ${dept.en}`
            : locale === 'ar'
              ? `محادثة ${who} بانتظار الرد في قسم ${dept.ar}`
              : `${who}'s conversation is waiting in ${dept.en}`,
      }),
    });
  }

  close(ctx: AdminContext, id: string) {
    const now = this.clock.now();
    return this.assign(ctx, id, 'CLOSE', async (row) => {
      if (row.status === 'CLOSED') return null;
      if (row.assignedToId !== null && row.assignedToId !== ctx.userId && !this.manages(ctx)) {
        throw new AppException(ErrorCode.WHATSAPP_CONVERSATION_ASSIGNED);
      }
      return {
        to: row.assignedToId,
        data: { status: 'CLOSED', closedAt: now, closedById: ctx.userId, unreadCount: 0 },
      };
    });
  }

  reopen(ctx: AdminContext, id: string) {
    return this.assign(ctx, id, 'REOPEN', async (row) => {
      if (row.status === 'OPEN') return null;
      return { to: row.assignedToId, data: { status: 'OPEN', closedAt: null, closedById: null } };
    });
  }

  async assignments(id: string) {
    await this.servedRow(id);
    const rows = await this.prisma.waAssignment.findMany({
      where: { conversationId: id },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: 100,
    });
    const staff = await this.staffRefs(rows.flatMap((r) => [r.fromUserId, r.toUserId, r.actorId]));
    const ref = (u: string | null) => (u ? (staff.get(u) ?? null) : null);
    const noteIds = rows.map((r) => r.noteId).filter((n): n is string => n !== null);
    const notes = new Map(
      (noteIds.length === 0
        ? []
        : await this.prisma.waNote.findMany({
            where: { id: { in: noteIds }, conversationId: id },
            select: { id: true, body: true },
          })
      ).map((n) => [n.id, n]),
    );
    return {
      data: rows.map((r) => ({
        id: r.id,
        action: r.action,
        from: ref(r.fromUserId),
        to: ref(r.toUserId),
        by: ref(r.actorId),
        at: r.createdAt.toISOString(),
        // D366 (§10.159.6): a transfer's departments and its internal note (null for other actions).
        department: r.department,
        fromDepartment: r.fromDepartment,
        note: r.noteId ? (notes.get(r.noteId) ?? null) : null,
      })),
    };
  }

  /**
   * The agents: ACTIVE staff whose WhatsApp level is REPLY or MANAGE now (D360, §10.155 — the roles' default when no
   * level is set). Only they can be given a conversation (transfer); VIEW never.
   */
  private async isAgent(db: Tx | PrismaService, userId: string): Promise<boolean> {
    return isAtWhatsAppLevel(db, userId, 'REPLY');
  }

  /**
   * The agents (REPLY+). D366 (§10.159.2): each with their departments and open assigned conversations;
   * `department` keeps the members of one (the transfer sheet's list), on shift first, then the fewest open.
   */
  async agents(department?: WaDepartment) {
    // v1.137-social (D385): also for the in-app threads (served without WhatsApp).
    const all = (await staffAtLevel(this.prisma, 'REPLY')).map((a) => a.userId);
    const set = await setDepartmentsOf(this.prisma, all);
    const ids = department ? all.filter((u) => effectiveDepartments(set.get(u)).includes(department)) : all;
    const [staff, shifts, loads] = await Promise.all([
      this.staffRefs(ids),
      this.prisma.adminShift.findMany({
        where: { userId: { in: ids } },
        select: { userId: true, onShift: true },
      }),
      this.loadsOf(this.prisma, ids),
    ]);
    const rows = ids.map((id) => ({
      ...staff.get(id)!,
      onShift: shifts.some((s) => s.userId === id && s.onShift),
      departments: effectiveDepartments(set.get(id)),
      openCount: loads.open.get(id) ?? 0,
    }));
    if (department) {
      rows.sort((a, b) => Number(b.onShift) - Number(a.onShift) || a.openCount - b.openCount);
    }
    return { data: rows };
  }

  /**
   * The staff a new message is pushed to (§10.151.5, D360 §10.155.3) — exported for the webhook service. Only staff at
   * VIEW or above, never a muted one: the assignee if they can still answer (REPLY+); else the VIEW+ staff on shift,
   * plus every REPLY+ agent when none of those on shift can answer (somebody who can reply is always told).
   */
  async pushRecipients(conv: { assignedToId: string | null }): Promise<string[]> {
    const muted = new Set(
      (
        await this.prisma.waAgentSetting.findMany({ where: { pushMuted: true }, select: { userId: true } })
      ).map((s) => s.userId),
    );
    if (conv.assignedToId && (await this.isAgent(this.prisma, conv.assignedToId))) {
      return muted.has(conv.assignedToId) ? [] : [conv.assignedToId];
    }
    const staff = await staffAtLevel(this.prisma, 'VIEW');
    const on = new Set(
      (
        await this.prisma.adminShift.findMany({
          where: { userId: { in: staff.map((s) => s.userId) }, onShift: true },
          select: { userId: true },
        })
      ).map((s) => s.userId),
    );
    const repliers = staff.filter((s) => s.level === 'REPLY' || s.level === 'MANAGE');
    const onShift = staff.filter((s) => on.has(s.userId));
    const answerable = onShift.some((s) => s.level === 'REPLY' || s.level === 'MANAGE');
    const chosen = new Set(onShift.map((s) => s.userId));
    if (!answerable) for (const r of repliers) chosen.add(r.userId);
    return staff.map((s) => s.userId).filter((id) => chosen.has(id) && !muted.has(id));
  }

  // ---- notes ----------------------------------------------------------------------------------------------------

  async notes(id: string) {
    await this.servedRow(id);
    const rows = await this.prisma.waNote.findMany({
      where: { conversationId: id },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      take: 200,
    });
    const staff = await this.staffRefs(rows.map((r) => r.authorId));
    return {
      data: rows.map((r) => ({
        id: r.id,
        body: r.body,
        author: staff.get(r.authorId) ?? null,
        at: r.createdAt.toISOString(),
      })),
    };
  }

  async addNote(ctx: AdminContext, id: string, body: string) {
    const served = await this.servedRow(id);
    const note = await this.prisma.$transaction(async (tx) => {
      const n = await tx.waNote.create({ data: { conversationId: id, authorId: ctx.userId, body } });
      await this.audit.recordIn(tx, {
        ...this.audited(ctx),
        action: AuditAction.WHATSAPP_NOTE,
        targetType: 'wa_conversation',
        targetId: id,
        metadata: { noteId: n.id, channel: served.channel, via: ctx.via ?? 'panel' },
      });
      return n;
    });
    const staff = await this.staffRefs([ctx.userId]);
    return {
      id: note.id,
      body: note.body,
      author: staff.get(ctx.userId) ?? null,
      at: note.createdAt.toISOString(),
    };
  }

  // ---- the Kabso account ----------------------------------------------------------------------------------------

  /**
   * Links the conversation to a Kabso account the customer named (a username or a staff-confirmed id). Kabso keeps no
   * verified phone number on accounts (§10.151.7), so a phone match cannot prove who the customer is: the link is
   * always the staff member's decision after asking the customer, and audited.
   */
  async link(ctx: AdminContext, id: string, username: string): Promise<WaConversationDto> {
    const row = await this.servedRow(id);
    // v1.137-social (D385, §10.174.6): an in-app thread's account is its owner, never changed.
    if (row.channel === 'IN_APP') throw AppException.validation([{ field: 'channel', issue: 'in_app' }]);
    const profile = await this.prisma.userProfile.findUnique({
      where: { username: username.replace(/^@/, '').toLowerCase() },
      select: { userId: true, user: { select: { status: true } } },
    });
    if (!profile || profile.user.status === 'DELETED') {
      throw AppException.validation([{ field: 'username', issue: 'not_found' }]);
    }
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      await tx.waConversation.update({
        where: { id },
        data: {
          linkedUserId: profile.userId,
          linkedById: ctx.userId,
          linkedAt: now,
          updatedAt: now,
          // v1.134-social (D381, §10.171.3): a PRIORITY_SUPPORT holder's conversation is listed first.
          priority: (await vipPerkHeldIn(tx, profile.userId, 'PRIORITY_SUPPORT', now)) !== null,
        },
      });
      await this.audit.recordIn(tx, {
        ...this.audited(ctx),
        action: AuditAction.WHATSAPP_LINK,
        targetType: 'wa_conversation',
        targetId: id,
        metadata: { userId: profile.userId, before: row.linkedUserId, via: ctx.via ?? 'panel' },
      });
    });
    return this.get(ctx, id);
  }

  async unlink(ctx: AdminContext, id: string): Promise<WaConversationDto> {
    const row = await this.servedRow(id);
    if (row.channel === 'IN_APP') throw AppException.validation([{ field: 'channel', issue: 'in_app' }]);
    if (row.linkedUserId !== null) {
      await this.prisma.$transaction(async (tx) => {
        await tx.waConversation.update({
          where: { id },
          data: { linkedUserId: null, linkedById: null, linkedAt: null, priority: false },
        });
        await this.audit.recordIn(tx, {
          ...this.audited(ctx),
          action: AuditAction.WHATSAPP_UNLINK,
          targetType: 'wa_conversation',
          targetId: id,
          metadata: { userId: row.linkedUserId, via: ctx.via ?? 'panel' },
        });
      });
    }
    return this.get(ctx, id);
  }

  // ---- quick replies --------------------------------------------------------------------------------------------

  async quickReplies() {
    const rows = await this.prisma.waQuickReply.findMany({ orderBy: [{ title: 'asc' }] });
    return {
      data: rows.map((r) => ({
        id: r.id,
        title: r.title,
        body: r.body,
        updatedAt: r.updatedAt.toISOString(),
      })),
    };
  }

  private async quickReplyAudit(ctx: AdminContext, tx: Tx, change: string, id: string) {
    await this.audit.recordIn(tx, {
      ...this.audited(ctx),
      action: AuditAction.WHATSAPP_QUICK_REPLY,
      targetType: 'wa_quick_reply',
      targetId: id,
      metadata: { change, via: ctx.via ?? 'panel' },
    });
  }

  private duplicateTitle(err: unknown): boolean {
    return typeof err === 'object' && err !== null && (err as { code?: string }).code === 'P2002';
  }

  async createQuickReply(ctx: AdminContext, input: { title: string; body: string }) {
    try {
      const r = await this.prisma.$transaction(async (tx) => {
        const row = await tx.waQuickReply.create({
          data: { title: input.title, body: input.body, createdById: ctx.userId, updatedById: ctx.userId },
        });
        await this.quickReplyAudit(ctx, tx, 'create', row.id);
        return row;
      });
      return { id: r.id, title: r.title, body: r.body, updatedAt: r.updatedAt.toISOString() };
    } catch (err) {
      if (this.duplicateTitle(err)) {
        throw AppException.validation([{ field: 'title', issue: 'duplicate' }]);
      }
      throw err;
    }
  }

  async updateQuickReply(ctx: AdminContext, id: string, input: { title?: string; body?: string }) {
    const now = this.clock.now();
    try {
      const r = await this.prisma.$transaction(async (tx) => {
        const found = await tx.waQuickReply.findUnique({ where: { id } });
        if (!found) throw new AppException(ErrorCode.NOT_FOUND);
        const row = await tx.waQuickReply.update({
          where: { id },
          data: { ...input, updatedById: ctx.userId, updatedAt: now },
        });
        await this.quickReplyAudit(ctx, tx, 'update', id);
        return row;
      });
      return { id: r.id, title: r.title, body: r.body, updatedAt: r.updatedAt.toISOString() };
    } catch (err) {
      if (this.duplicateTitle(err)) {
        throw AppException.validation([{ field: 'title', issue: 'duplicate' }]);
      }
      throw err;
    }
  }

  async deleteQuickReply(ctx: AdminContext, id: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const gone = await tx.waQuickReply.deleteMany({ where: { id } });
      if (gone.count === 0) throw new AppException(ErrorCode.NOT_FOUND);
      await this.quickReplyAudit(ctx, tx, 'delete', id);
    });
  }

  // ---- the caller's settings and the connection ------------------------------------------------------------------

  async mySettings(ctx: AdminContext) {
    const s = await this.prisma.waAgentSetting.findUnique({ where: { userId: ctx.userId } });
    return { pushMuted: s?.pushMuted ?? false };
  }

  async setMySettings(ctx: AdminContext, pushMuted: boolean) {
    const now = this.clock.now();
    await this.prisma.waAgentSetting.upsert({
      where: { userId: ctx.userId },
      create: { userId: ctx.userId, pushMuted, updatedAt: now },
      update: { pushMuted, updatedAt: now },
    });
    return { pushMuted };
  }

  /** The panel's «إعدادات واتساب»: what is configured (never a secret) and the address to paste in Meta. */
  async status() {
    const c = this.config.whatsapp.credentials;
    const last = await this.prisma.waMessage.findFirst({
      where: { direction: 'INBOUND' },
      orderBy: { createdAt: 'desc' },
      select: { createdAt: true },
    });
    const conversations = await this.prisma.waConversation.count({ where: { purgeAfter: null } });
    return {
      enabled: this.enabled,
      phoneNumberId: c?.phoneNumberId ?? null,
      businessAccountId: c?.businessAccountId ?? null,
      displayName: this.config.whatsapp.displayName,
      graphApiVersion: this.config.whatsapp.graphApiVersion,
      webhookUrl: `${this.config.kyc.publicApiBaseUrl}/api/v1/webhooks/whatsapp`,
      subscribedFields: ['messages'],
      retentionDays: this.config.whatsapp.retentionDays,
      mediaMaxBytes: this.config.whatsapp.mediaMaxBytes,
      lastInboundAt: iso(last?.createdAt),
      conversations,
      missing: c
        ? []
        : [
            'WHATSAPP_PHONE_NUMBER_ID',
            'WHATSAPP_BUSINESS_ACCOUNT_ID',
            'WHATSAPP_ACCESS_TOKEN_FILE',
            'WHATSAPP_APP_SECRET_FILE',
            'WHATSAPP_VERIFY_TOKEN_FILE',
          ],
    };
  }

  /** «اختبار الاتصال»: the number's details and the approved templates read from Meta now. Audited. */
  async test(ctx: AdminContext) {
    const graph = this.requireGraph();
    let result: {
      ok: boolean;
      displayPhoneNumber: string | null;
      verifiedName: string | null;
      qualityRating: string | null;
      templates: number | null;
      error: { status: number; code: number | null; title: string | null } | null;
    };
    try {
      const info = await graph.phoneInfo();
      const templates = await this.templates(true);
      result = { ok: true, ...info, templates: templates.length, error: null };
    } catch (err) {
      const e =
        err instanceof GraphError
          ? { status: err.status, code: err.code, title: err.title }
          : err instanceof AppException
            ? { status: 502, code: null, title: 'templates' }
            : { status: 0, code: null, title: null };
      result = {
        ok: false,
        displayPhoneNumber: null,
        verifiedName: null,
        qualityRating: null,
        templates: null,
        error: e,
      };
    }
    await this.audit.record({
      ...this.audited(ctx),
      action: AuditAction.WHATSAPP_TEST,
      targetType: 'whatsapp',
      metadata: { ok: result.ok, code: result.error?.code ?? null, via: ctx.via ?? 'panel' },
    });
    return result;
  }
}
