import { Inject, Injectable } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { PushService } from '../push/push.service.js';
import { clip, type PushLocale } from '../push/push-texts.js';
import { PushThrottle } from '../push/push-throttle.js';

/** The Android tag (and conversation id in the app) of a direct conversation. */
export function dmTag(conversationId: string): string {
  return `dm:${conversationId}`;
}

export interface DmPushInput {
  readonly conversationId: string;
  readonly messageId: string;
  readonly senderId: string;
  readonly recipientId: string;
  readonly kind: 'TEXT' | 'IMAGE' | 'VOICE' | 'EMOJI' | 'GIFT';
  /** TEXT: the stored (masked) text. */
  readonly text: string | null;
  /** GIFT: how many. */
  readonly quantity: number | null;
  /** A message request (the recipient's REQUESTS box). */
  readonly asRequest: boolean;
}

/** The body of a direct message's push in `locale` (CONVENTIONS §11.13). */
export function dmPushBody(
  input: Pick<DmPushInput, 'kind' | 'text' | 'quantity' | 'asRequest'>,
  locale: PushLocale,
): string {
  const ar = locale === 'ar';
  let body: string;
  switch (input.kind) {
    case 'TEXT':
      body = input.text ?? '';
      break;
    case 'IMAGE':
      body = ar ? '📷 صورة' : '📷 Photo';
      break;
    case 'VOICE':
      body = ar ? '🎤 رسالة صوتية' : '🎤 Voice message';
      break;
    case 'EMOJI':
      body = ar ? 'ملصق' : 'Sticker';
      break;
    case 'GIFT':
      body = ar ? `🎁 أرسل لك هدية ×${input.quantity ?? 1}` : `🎁 Sent you a gift ×${input.quantity ?? 1}`;
      break;
  }
  if (input.asRequest) body = ar ? `طلب مراسلة: ${body}` : `Message request: ${body}`;
  return clip(body);
}

/**
 * v1.40-social (D155, CONVENTIONS §11.13, §11.12): the push of a new direct message (channel
 * `messages`) to its recipient when they are ACTIVE, keep `messages` on, have not muted the
 * conversation or the sender, and there is no block either way — never the sender; one per
 * recipient per conversation per `PUSH_MESSAGES_GAP_SECONDS`. Runs after the send's response.
 */
@Injectable()
export class DmPush {
  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushService,
    private readonly throttle: PushThrottle,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** Returns how many devices accepted it. */
  async newMessage(input: DmPushInput): Promise<number> {
    if (!this.push.enabled) return 0;
    const { conversationId, senderId, recipientId } = input;
    const rows = await this.prisma.$queryRaw<{ ok: boolean }[]>`
      SELECT true AS ok
        FROM users u
        JOIN dm_participants p ON p.conversation_id = ${conversationId}::uuid AND p.user_id = u.id
        LEFT JOIN notification_settings ns ON ns.user_id = u.id
       WHERE u.id = ${recipientId}::uuid
         AND u.status = 'ACTIVE'::user_status
         AND NOT p.muted
         AND COALESCE(ns.messages, true)
         AND EXISTS (SELECT 1 FROM device_tokens d WHERE d.user_id = u.id)
         AND NOT EXISTS (SELECT 1 FROM user_blocks b
                          WHERE (b.blocker_id = u.id AND b.blocked_id = ${senderId}::uuid)
                             OR (b.blocker_id = ${senderId}::uuid AND b.blocked_id = u.id))
         AND NOT EXISTS (SELECT 1 FROM user_mutes m
                          WHERE m.muter_id = u.id AND m.muted_id = ${senderId}::uuid)`;
    if (rows.length === 0) return 0;
    const tag = dmTag(conversationId);
    if (!(await this.throttle.allow(`m:${tag}:${recipientId}`, this.config.push.messagesGapSeconds)))
      return 0;
    const sender = await this.prisma.userProfile.findUnique({
      where: { userId: senderId },
      select: { displayName: true, username: true },
    });
    if (!sender) return 0;
    return this.push.deliver({
      userIds: [recipientId],
      channel: 'messages',
      tag,
      data: {
        kind: 'dm',
        channel: 'messages',
        conversationId,
        messageId: input.messageId,
        senderUsername: sender.username,
      },
      text: (locale) => ({ title: sender.displayName, body: dmPushBody(input, locale) }),
    });
  }
}
