import { Inject, Injectable, Logger } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import { PushService } from '../push/push.service.js';
import { PushThrottle } from '../push/push-throttle.js';
import {
  WHATSAPP_GRAPH,
  WHATSAPP_SECRETS,
  type WhatsAppGraph,
  type WhatsAppSecrets,
} from './graph-client.js';
import {
  baseMime,
  mediaAllowed,
  mediaKey,
  parseWebhook,
  previewOf,
  signatureValid,
  statusAdvances,
  verifyTokenMatches,
  type InboundMessage,
  type StatusUpdate,
} from './whatsapp-core.js';
import { WhatsAppService } from './whatsapp.service.js';

export const WA_PUSH_TITLE = { ar: 'واتساب Kabso', en: 'Kabso WhatsApp' } as const;

/** «+9665••••4567»: the push never shows the full number on a lock screen. */
export function maskedPhone(e164: string): string {
  if (e164.length <= 8) return e164;
  return `${e164.slice(0, 5)}${'•'.repeat(Math.max(e164.length - 9, 2))}${e164.slice(-4)}`;
}

/**
 * v1.116-social (D355, CONVENTIONS §10.151.3): Meta's webhook. `GET` answers the subscription check (`hub.mode` =
 * subscribe and the verify token → `hub.challenge`); `POST` is accepted only with a valid `X-Hub-Signature-256` over
 * the exact bytes (the app secret), then every message is stored once (Meta's `wamid` is unique — a retried delivery
 * changes nothing), statuses move forward only, media is fetched into the private storage after the answer, and the
 * agents are pushed. Meta retries a non-2xx answer, so a valid body is always answered 200 even if one event fails.
 */
@Injectable()
export class WhatsAppWebhookService {
  private readonly logger = new Logger('WhatsApp');

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    private readonly background: BackgroundTasks,
    private readonly inbox: WhatsAppService,
    private readonly push: PushService,
    private readonly throttle: PushThrottle,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(WHATSAPP_GRAPH) private readonly graph: WhatsAppGraph | null,
    @Inject(WHATSAPP_SECRETS) private readonly secrets: WhatsAppSecrets | null,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
  ) {}

  /** The subscription check: the challenge (text) or 403. */
  verify(query: Record<string, unknown>): string {
    if (!this.secrets) throw new AppException(ErrorCode.WHATSAPP_UNAVAILABLE);
    const hub = (typeof query.hub === 'object' && query.hub !== null ? query.hub : {}) as Record<
      string,
      unknown
    >;
    const mode = query['hub.mode'] ?? hub.mode;
    const token = query['hub.verify_token'] ?? hub.verify_token;
    const challenge = query['hub.challenge'] ?? hub.challenge;
    if (mode !== 'subscribe' || !verifyTokenMatches(token, this.secrets.verifyToken)) {
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    }
    if (typeof challenge !== 'string' || !/^[A-Za-z0-9_-]{1,200}$/.test(challenge)) {
      throw AppException.validation([{ field: 'hub.challenge', issue: 'invalid_value' }]);
    }
    return challenge;
  }

  async receive(raw: unknown, signature: string | undefined): Promise<{ received: true; events: number }> {
    if (!this.secrets || !this.graph) throw new AppException(ErrorCode.WHATSAPP_UNAVAILABLE);
    if (!Buffer.isBuffer(raw) || !signatureValid(raw, signature, this.secrets.appSecret)) {
      await this.audit.record({
        action: AuditAction.WHATSAPP_WEBHOOK_REFUSED,
        actorUserId: null,
        targetType: 'whatsapp',
        metadata: { reason: Buffer.isBuffer(raw) ? 'signature' : 'body' },
      });
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    }
    let body: unknown;
    try {
      body = JSON.parse(raw.toString('utf8'));
    } catch {
      throw AppException.validation([{ field: 'body', issue: 'invalid_json' }]);
    }
    const now = this.clock.now();
    const mine = this.config.whatsapp.credentials?.phoneNumberId ?? null;
    const events = parseWebhook(body, now).filter(
      (e) => e.phoneNumberId === null || e.phoneNumberId === mine,
    );
    for (const e of events) {
      try {
        if (e.kind === 'message') await this.onMessage(e);
        else await this.onStatus(e);
      } catch (err) {
        this.logger.error({ error: safeErrorLog(err), kind: e.kind }, 'A WhatsApp event could not be stored');
      }
    }
    return { received: true, events: events.length };
  }

  private async onStatus(s: StatusUpdate): Promise<void> {
    const row = await this.prisma.waMessage.findUnique({
      where: { waMessageId: s.waMessageId },
      select: { id: true, status: true, direction: true },
    });
    if (!row || row.direction !== 'OUTBOUND' || !statusAdvances(row.status, s.status)) return;
    await this.prisma.waMessage.updateMany({
      where: { id: row.id, status: row.status },
      data: {
        status: s.status,
        statusAt: s.timestamp,
        ...(s.status === 'FAILED' ? { errorCode: s.errorCode, errorTitle: s.errorTitle } : {}),
      },
    });
  }

  private async onMessage(m: InboundMessage): Promise<void> {
    const now = this.clock.now();
    const stored = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:wa'), hashtext(${m.phoneE164}))`;
      const dup = await tx.waMessage.findUnique({
        where: { waMessageId: m.waMessageId },
        select: { id: true },
      });
      if (dup) return null;
      let conv = await tx.waConversation.findUnique({ where: { phoneE164: m.phoneE164 } });
      if (!conv) {
        conv = await tx.waConversation.create({
          data: {
            phoneE164: m.phoneE164,
            waId: m.waId,
            profileName: m.profileName,
            lastMessageAt: now,
            createdAt: now,
          },
        });
      }
      if (conv.purgeAfter !== null) {
        // The linked account was purged: the old conversation goes; this message starts a new one.
        await tx.waConversation.delete({ where: { id: conv.id } });
        conv = await tx.waConversation.create({
          data: {
            phoneE164: m.phoneE164,
            waId: m.waId,
            profileName: m.profileName,
            lastMessageAt: now,
            createdAt: now,
          },
        });
      }
      const msg = await tx.waMessage.create({
        data: {
          conversationId: conv.id,
          waMessageId: m.waMessageId,
          direction: 'INBOUND',
          type: m.type,
          body: m.body,
          mediaState: m.media ? 'FAILED' : 'NONE',
          mediaMime: m.media?.mime ? baseMime(m.media.mime) : null,
          mediaFilename: m.media?.filename ?? null,
          mediaVoice: m.media?.voice ?? false,
          latitude: m.location?.latitude ?? null,
          longitude: m.location?.longitude ?? null,
          locationName: m.location?.name ?? null,
          reactionEmoji: m.reaction?.emoji ?? null,
          reactionToWaId: m.reaction?.toWaMessageId ?? null,
          status: 'RECEIVED',
          waTimestamp: m.timestamp,
          createdAt: now,
        },
      });
      if (m.type === 'REACTION' && m.reaction) {
        // Shown on the message it reacts to; not an unread message, and it does not reopen the window.
        await tx.waMessage.updateMany({
          where: { waMessageId: m.reaction.toWaMessageId, conversationId: conv.id },
          data: { reactionEmoji: m.reaction.emoji },
        });
        return null;
      }
      const reopened = conv.status === 'CLOSED';
      const lastInbound =
        conv.lastInboundAt && conv.lastInboundAt.getTime() > m.timestamp.getTime()
          ? conv.lastInboundAt
          : m.timestamp;
      const updated = await tx.waConversation.update({
        where: { id: conv.id },
        data: {
          waId: m.waId,
          ...(m.profileName ? { profileName: m.profileName } : {}),
          unreadCount: { increment: 1 },
          lastInboundAt: lastInbound,
          lastMessageAt: now,
          lastPreview: previewOf(m.type, m.body),
          lastDirection: 'INBOUND',
          updatedAt: now,
          ...(reopened ? { status: 'OPEN', closedAt: null, closedById: null } : {}),
        },
      });
      if (reopened) {
        await tx.waAssignment.create({
          data: {
            conversationId: conv.id,
            action: 'REOPEN',
            fromUserId: conv.assignedToId,
            toUserId: conv.assignedToId,
          },
        });
      }
      return { conv: updated, messageId: msg.id };
    });
    if (!stored) return;
    if (m.media) {
      const media = m.media;
      this.background.run('whatsapp.media', () => this.fetchMedia(stored.conv.id, stored.messageId, media));
    }
    this.background.run('whatsapp.push', () => this.alert(stored.conv));
  }

  /** Downloads an inbound media file into the private storage (allowlisted type, `WHATSAPP_MEDIA_MAX_BYTES`). */
  async fetchMedia(conversationId: string, messageId: string, media: NonNullable<InboundMessage['media']>) {
    if (!this.graph) return;
    const max = this.config.whatsapp.mediaMaxBytes;
    let state: 'STORED' | 'TOO_LARGE' | 'TYPE_REFUSED' | 'FAILED' = 'FAILED';
    let key: string | null = null;
    let size: number | null = null;
    let mime = baseMime(media.mime);
    try {
      const info = await this.graph.mediaInfo(media.id);
      mime = baseMime(info.mime ?? media.mime);
      size = info.size;
      if (!mediaAllowed(mime)) state = 'TYPE_REFUSED';
      else if (info.size !== null && info.size > max) state = 'TOO_LARGE';
      else {
        const bytes = await this.graph.download(info.url, max);
        if (!bytes) state = 'TOO_LARGE';
        else {
          key = mediaKey(conversationId, messageId, mime);
          await this.storage.put(key, bytes, mime, 'private, no-store');
          size = bytes.length;
          state = 'STORED';
        }
      }
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'A WhatsApp media file could not be fetched');
      key = null;
    }
    await this.prisma.waMessage.updateMany({
      where: { id: messageId },
      data: { mediaState: state, mediaKey: key, mediaSize: size, mediaMime: mime || null },
    });
  }

  /** The push (§10.151.5): the assigned agent, else the agents on shift, else every agent; muted ones never. */
  private async alert(conv: {
    id: string;
    assignedToId: string | null;
    profileName: string | null;
    phoneE164: string;
  }) {
    if (!this.push.enabled) return;
    const recipients = await this.inbox.pushRecipients(conv);
    const allowed: string[] = [];
    for (const r of recipients) {
      if (await this.throttle.allow(`wa:${r}:${conv.id}`, this.config.whatsapp.pushGapSeconds))
        allowed.push(r);
    }
    if (allowed.length === 0) return;
    const who = conv.profileName?.trim() || maskedPhone(conv.phoneE164);
    await this.push.deliver({
      userIds: allowed,
      channel: 'staff',
      tag: `wa:${conv.id}`,
      data: { kind: 'whatsapp', channel: 'staff', conversationId: conv.id },
      text: (locale) => ({
        title: WA_PUSH_TITLE[locale],
        body: locale === 'ar' ? `رسالة واتساب جديدة من ${who}` : `New WhatsApp message from ${who}`,
      }),
    });
  }
}
