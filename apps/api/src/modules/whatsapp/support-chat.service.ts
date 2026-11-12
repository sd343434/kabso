import { Inject, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { MediaService, type MediaAssetDto } from '../media/media.service.js';
import { DM_TEXT_LIMITS } from '../messages/dm.schemas.js';
import { normalizeContentText } from '../posts/content-text.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { PushService } from '../push/push.service.js';
import { PushThrottle } from '../push/push-throttle.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import { vipPerkHeldIn } from '../vip/vip-gift-perks.js';
import { previewOf } from './whatsapp-core.js';
import { WA_DEPARTMENTS, type WaDepartment } from './whatsapp-departments.js';
import { staffFirstName, SUPPORT_STAFF_TITLE } from './support-push.js';
import { WhatsAppService } from './whatsapp.service.js';

/** The most unread replies counted on the «دعم كابسو» circle. */
const UNREAD_CAP = 99;

/** `SupportSendRequest` (openapi v1.137-social, D385): the field of the kind is required, the others are refused. */
export const supportSendSchema = z
  .strictObject({
    kind: z.string().pipe(z.enum(['TEXT', 'IMAGE', 'VOICE'])),
    text: z
      .string()
      .max(8000)
      .transform((raw, ctx) => {
        const result = normalizeContentText(raw, DM_TEXT_LIMITS);
        if ('issue' in result) {
          ctx.addIssue({ code: 'custom', message: result.issue, params: { issue: result.issue } });
          return z.NEVER;
        }
        return result.value;
      })
      .optional(),
    mediaId: z.uuid().optional(),
    clientId: z.uuid(),
    topic: z.string().pipe(z.enum(WA_DEPARTMENTS)).optional(),
  })
  .superRefine((v, ctx) => {
    const need = v.kind === 'TEXT' ? 'text' : 'mediaId';
    for (const field of ['text', 'mediaId'] as const) {
      if (field === need) {
        if (v[field] === undefined)
          ctx.addIssue({ code: 'custom', path: [field], params: { issue: 'required' } });
      } else if (v[field] !== undefined) {
        ctx.addIssue({ code: 'custom', path: [field], params: { issue: 'unknown_field' } });
      }
    }
  });

export const supportMessagesQuery = z.strictObject({
  cursor: z.string().min(1).max(512).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(30),
});
export type SupportMessagesQuery = z.output<typeof supportMessagesQuery>;

export interface SupportThreadDto {
  id: string | null;
  status: 'NONE' | 'OPEN' | 'CLOSED';
  department: WaDepartment | null;
  unreadCount: number;
  lastMessageAt: string | null;
  lastPreview: string | null;
}

export interface SupportMessageDto {
  id: string;
  mine: boolean;
  kind: 'TEXT' | 'IMAGE' | 'VOICE';
  text: string | null;
  media: MediaAssetDto | null;
  staff: { firstName: string | null } | null;
  receipt: 'RECEIVED' | 'READ' | null;
  createdAt: string;
}

type ConvRow = Prisma.WaConversationGetPayload<object>;
const MESSAGE_INCLUDE = { mediaAsset: true } as const;
type MsgRow = Prisma.WaMessageGetPayload<{ include: typeof MESSAGE_INCLUDE }>;

const NONE: SupportThreadDto = {
  id: null,
  status: 'NONE',
  department: null,
  unreadCount: 0,
  lastMessageAt: null,
  lastPreview: null,
};

/**
 * v1.137-social (D385, CONVENTIONS §10.174): «دعم كابسو» — the person's side of their in-app support thread. The thread
 * is a `wa_conversations` row of channel IN_APP (one per account, `linked_user_id`), so the staff answer it in the
 * WhatsApp inbox with its departments, assignment, notes, levels, priority, audit and retention ({@link WhatsAppService}).
 */
@Injectable()
export class SupportChatService {
  private readonly cursors: SocialCursorCodec;

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly media: MediaService,
    private readonly inbox: WhatsAppService,
    private readonly push: PushService,
    private readonly throttle: PushThrottle,
    private readonly background: BackgroundTasks,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  private async rowOf(db: Prisma.TransactionClient | PrismaService, userId: string): Promise<ConvRow | null> {
    const row = await db.waConversation.findFirst({ where: { linkedUserId: userId, channel: 'IN_APP' } });
    // §10.174.1: a thread whose account is being purged reads as none.
    return row && row.purgeAfter === null ? row : null;
  }

  private async threadOf(row: ConvRow | null): Promise<SupportThreadDto> {
    if (!row) return NONE;
    const unread = await this.prisma.waMessage.count({
      where: {
        conversationId: row.id,
        direction: 'OUTBOUND',
        ...(row.userReadAt ? { createdAt: { gt: row.userReadAt } } : {}),
      },
      take: UNREAD_CAP,
    });
    return {
      id: row.id,
      status: row.status,
      department: row.department,
      unreadCount: Math.min(unread, UNREAD_CAP),
      lastMessageAt: row.lastMessageAt.toISOString(),
      lastPreview: row.lastPreview,
    };
  }

  async thread(userId: string): Promise<SupportThreadDto> {
    return this.threadOf(await this.rowOf(this.prisma, userId));
  }

  private async messageDtos(rows: readonly MsgRow[], conv: ConvRow): Promise<SupportMessageDto[]> {
    const staffIds = [...new Set(rows.map((r) => r.sentById).filter((s): s is string => s !== null))];
    const profiles =
      staffIds.length === 0
        ? []
        : await this.prisma.userProfile.findMany({
            where: { userId: { in: staffIds } },
            select: { userId: true, displayName: true },
          });
    const nameOf = new Map(profiles.map((p) => [p.userId, staffFirstName(p.displayName)]));
    return rows.map((r) => {
      const mine = r.direction === 'INBOUND';
      const kind: SupportMessageDto['kind'] =
        r.type === 'IMAGE' ? 'IMAGE' : r.type === 'AUDIO' ? 'VOICE' : 'TEXT';
      return {
        id: r.id,
        mine,
        kind,
        text: r.body,
        media: r.mediaAsset ? this.media.toDto(r.mediaAsset) : null,
        staff: mine ? null : { firstName: r.sentById ? (nameOf.get(r.sentById) ?? null) : null },
        receipt: mine
          ? conv.staffReadAt !== null && r.createdAt.getTime() <= conv.staffReadAt.getTime()
            ? 'READ'
            : 'RECEIVED'
          : null,
        createdAt: r.createdAt.toISOString(),
      };
    });
  }

  async messages(userId: string, q: SupportMessagesQuery) {
    const conv = await this.rowOf(this.prisma, userId);
    const scope = `support:${userId}`;
    let after = null;
    if (q.cursor !== undefined) {
      after = this.cursors.decode(q.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    if (!conv) return { data: [], page: { nextCursor: null, hasMore: false }, thread: NONE };
    const where: Prisma.WaMessageWhereInput = { conversationId: conv.id };
    if (after) where.OR = [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }];
    const rows = await this.prisma.waMessage.findMany({
      where,
      include: MESSAGE_INCLUDE,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: q.limit + 1,
    });
    const more = rows.length > q.limit;
    const page = rows.slice(0, q.limit);
    const last = page[page.length - 1];
    return {
      data: await this.messageDtos(page, conv),
      page: {
        nextCursor: more && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
        hasMore: more,
      },
      thread: await this.threadOf(conv),
    };
  }

  /** `readSupportThread`: the team's replies up to now are read. */
  async read(userId: string): Promise<void> {
    await this.prisma.waConversation.updateMany({
      where: { linkedUserId: userId, channel: 'IN_APP', purgeAfter: null },
      data: { userReadAt: this.clock.now() },
    });
  }

  private async replay(userId: string, clientId: string) {
    const conv = await this.rowOf(this.prisma, userId);
    if (!conv) return null;
    const row = await this.prisma.waMessage.findFirst({
      where: { conversationId: conv.id, clientId },
      include: MESSAGE_INCLUDE,
    });
    if (!row) return null;
    return { message: (await this.messageDtos([row], conv))[0]!, thread: await this.threadOf(conv) };
  }

  /**
   * `sendSupportMessage` (CONVENTIONS §10.174.3). Order after auth and the rate limit: 400 body → a retry with the same
   * `clientId` (200) → 400 `topic` (a new ticket without one) → 400 `mediaId` → stored; then the team's push.
   */
  async send(
    userId: string,
    body: unknown,
  ): Promise<{ created: boolean; result: { message: SupportMessageDto; thread: SupportThreadDto } }> {
    const parsed = supportSendSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const clientId = input.clientId.toLowerCase();
    const first = await this.replay(userId, clientId);
    if (first) return { created: false, result: first };
    const now = this.clock.now();
    let stored: { conv: ConvRow; messageId: string; opened: boolean };
    try {
      stored = await this.prisma.$transaction(async (tx) => {
        // One writer per account at a time (the thread's creation and a reopen are decided under it).
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:wa-app'), hashtext(${userId}))`;
        let conv = await this.rowOf(tx, userId);
        const existed = conv !== null;
        const opening = !conv || conv.status === 'CLOSED';
        if (opening && input.topic === undefined) {
          throw AppException.validation([{ field: 'topic', issue: 'required' }]);
        }
        let mediaAssetId: string | null = null;
        let mediaMime: string | null = null;
        let mediaSize: number | null = null;
        if (input.kind !== 'TEXT') {
          const claimed = await this.media.claimAssetsIn(
            tx,
            userId,
            [input.mediaId!],
            input.kind === 'IMAGE' ? 'DM_IMAGE' : 'DM_VOICE',
          );
          if (claimed === null) throw AppException.validation([{ field: 'mediaId', issue: 'invalid_value' }]);
          const asset = claimed[0]!;
          mediaAssetId = asset.id;
          mediaSize = asset.byteSize;
          mediaMime = mimeOfKey(asset.largeKey, input.kind);
        }
        const profile = await tx.userProfile.findUnique({ where: { userId }, select: { displayName: true } });
        const name = profile?.displayName ?? null;
        const priority = (await vipPerkHeldIn(tx, userId, 'PRIORITY_SUPPORT', now)) !== null;
        if (!conv) {
          // A purged account's old thread (`purge_after` set) is replaced, as a WhatsApp number's is.
          await tx.waConversation.deleteMany({ where: { linkedUserId: userId, channel: 'IN_APP' } });
          conv = await tx.waConversation.create({
            data: {
              channel: 'IN_APP',
              linkedUserId: userId,
              linkedAt: now,
              profileName: name,
              department: input.topic!,
              priority,
              lastMessageAt: now,
              createdAt: now,
              updatedAt: now,
            },
          });
        } else if (conv.status === 'CLOSED') {
          // A new ticket: its topic's queue, unassigned (the history keeps who had it).
          await tx.waConversation.update({
            where: { id: conv.id },
            data: {
              status: 'OPEN',
              closedAt: null,
              closedById: null,
              department: input.topic!,
              assignedToId: null,
              assignedAt: null,
              updatedAt: now,
            },
          });
          await tx.waAssignment.create({
            data: {
              conversationId: conv.id,
              action: 'REOPEN',
              fromUserId: conv.assignedToId,
              toUserId: null,
              actorId: userId,
              department: input.topic!,
              fromDepartment: conv.department,
              createdAt: now,
            },
          });
        }
        const type = input.kind === 'TEXT' ? 'TEXT' : input.kind === 'IMAGE' ? 'IMAGE' : 'AUDIO';
        const text = input.kind === 'TEXT' ? input.text! : null;
        const msg = await tx.waMessage.create({
          data: {
            conversationId: conv.id,
            direction: 'INBOUND',
            type,
            body: text,
            mediaState: mediaAssetId ? 'STORED' : 'NONE',
            mediaAssetId,
            mediaMime,
            mediaSize,
            mediaVoice: input.kind === 'VOICE',
            status: 'RECEIVED',
            clientId,
            createdAt: now,
          },
        });
        const updated = await tx.waConversation.update({
          where: { id: conv.id },
          data: {
            unreadCount: { increment: 1 },
            lastInboundAt: now,
            lastMessageAt: now,
            lastPreview: previewOf(type, text),
            lastDirection: 'INBOUND',
            profileName: name,
            priority,
            updatedAt: now,
          },
        });
        if (opening) {
          await this.audit.recordIn(tx, {
            actorUserId: userId,
            action: AuditAction.SUPPORT_TICKET_OPEN,
            targetType: 'wa_conversation',
            targetId: conv.id,
            metadata: { department: input.topic!, reopened: existed },
          });
        }
        return { conv: updated, messageId: msg.id, opened: opening };
      });
    } catch (err) {
      const index = violatedUniqueIndex(err) ?? '';
      if (index.includes('wa_messages_client_once') || index.includes('wa_conversations_in_app_user_key')) {
        const raced = await this.replay(userId, clientId);
        if (raced) return { created: false, result: raced };
      }
      throw err;
    }
    const row = await this.prisma.waMessage.findUniqueOrThrow({
      where: { id: stored.messageId },
      include: MESSAGE_INCLUDE,
    });
    const conv = stored.conv;
    this.background.run('support.staff.push', () => this.alert(conv));
    return {
      created: true,
      result: { message: (await this.messageDtos([row], conv))[0]!, thread: await this.threadOf(conv) },
    };
  }

  /** The team's push (§10.151.5 recipients, one per staff member and thread per `WHATSAPP_PUSH_GAP_SECONDS`). */
  private async alert(conv: ConvRow): Promise<void> {
    if (!this.push.enabled) return;
    const recipients = await this.inbox.pushRecipients(conv);
    const allowed: string[] = [];
    for (const r of recipients) {
      if (await this.throttle.allow(`wa:${r}:${conv.id}`, this.config.whatsapp.pushGapSeconds))
        allowed.push(r);
    }
    if (allowed.length === 0) return;
    const who = conv.profileName?.trim() || 'Kabso';
    await this.push.deliver({
      userIds: allowed,
      channel: 'staff',
      tag: `wa:${conv.id}`,
      data: { kind: 'whatsapp', channel: 'staff', conversationId: conv.id, source: 'IN_APP' },
      text: (locale) => ({
        title: SUPPORT_STAFF_TITLE[locale],
        body: locale === 'ar' ? `رسالة جديدة من ${who}` : `New message from ${who}`,
      }),
    });
  }
}

/** The stored file's type from the media pipeline's key (a picture is WebP, a voice clip AAC in MP4). */
function mimeOfKey(key: string, kind: 'IMAGE' | 'VOICE'): string {
  const ext = key.split('.').pop()?.toLowerCase() ?? '';
  const known: Record<string, string> = {
    webp: 'image/webp',
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    m4a: 'audio/mp4',
    mp4: 'audio/mp4',
    aac: 'audio/aac',
  };
  return known[ext] ?? (kind === 'IMAGE' ? 'image/webp' : 'audio/mp4');
}
