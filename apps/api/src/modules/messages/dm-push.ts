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

/** v1.103-social (D339): the Android tag (and the group id in the app) of a group conversation. */
export function dmGroupTag(groupId: string): string {
  return `dmg:${groupId}`;
}

export interface DmGroupPushInput {
  readonly groupId: string;
  readonly messageId: string;
  readonly senderId: string;
  readonly kind: 'TEXT' | 'IMAGE' | 'VOICE' | 'EMOJI';
  /** TEXT: the stored (masked) text. */
  readonly text: string | null;
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

  /**
   * v1.103-social (D339, CONVENTIONS §10.133): a new group message to every other member who is ACTIVE, keeps
   * `messages` on, has not muted the group or the sender, and has no block either way with the sender; one per member
   * per group per `PUSH_MESSAGES_GAP_SECONDS`. Title: the group's name; body: «<sender>: <message>». Returns how many
   * devices accepted it.
   */
  async newGroupMessage(input: DmGroupPushInput): Promise<number> {
    if (!this.push.enabled) return 0;
    const { groupId, senderId } = input;
    const rows = await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT u.id::text AS id
        FROM dm_group_members m
        JOIN users u ON u.id = m.user_id AND u.status = 'ACTIVE'::user_status
        LEFT JOIN notification_settings ns ON ns.user_id = u.id
       WHERE m.group_id = ${groupId}::uuid
         AND m.user_id <> ${senderId}::uuid
         AND NOT m.muted
         AND COALESCE(ns.messages, true)
         AND EXISTS (SELECT 1 FROM device_tokens d WHERE d.user_id = u.id)
         AND NOT EXISTS (SELECT 1 FROM user_blocks b
                          WHERE (b.blocker_id = u.id AND b.blocked_id = ${senderId}::uuid)
                             OR (b.blocker_id = ${senderId}::uuid AND b.blocked_id = u.id))
         AND NOT EXISTS (SELECT 1 FROM user_mutes um
                          WHERE um.muter_id = u.id AND um.muted_id = ${senderId}::uuid)`;
    if (rows.length === 0) return 0;
    const tag = dmGroupTag(groupId);
    const allowed: string[] = [];
    for (const r of rows) {
      if (await this.throttle.allow(`m:${tag}:${r.id}`, this.config.push.messagesGapSeconds))
        allowed.push(r.id);
    }
    if (allowed.length === 0) return 0;
    const [sender, group] = await Promise.all([
      this.prisma.userProfile.findUnique({
        where: { userId: senderId },
        select: { displayName: true, username: true },
      }),
      this.prisma.dmGroup.findUnique({ where: { id: groupId }, select: { name: true } }),
    ]);
    if (!sender || !group) return 0;
    return this.push.deliver({
      userIds: allowed,
      channel: 'messages',
      tag,
      data: {
        kind: 'dm_group',
        channel: 'messages',
        groupId,
        messageId: input.messageId,
        senderUsername: sender.username,
      },
      text: (locale) => ({
        title: group.name,
        body: clip(
          `${sender.displayName}: ${dmPushBody({ ...input, quantity: null, asRequest: false }, locale)}`,
        ),
      }),
    });
  }

  /**
   * v1.103-social (D339): «<adder> أضافك إلى <group>» / "<adder> added you to <group>" to the people just added (ACTIVE,
   * `messages` on). Returns how many devices accepted it.
   */
  async addedToGroup(input: {
    groupId: string;
    adderId: string;
    userIds: readonly string[];
  }): Promise<number> {
    if (!this.push.enabled || input.userIds.length === 0) return 0;
    const rows = await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT u.id::text AS id
        FROM users u
        LEFT JOIN notification_settings ns ON ns.user_id = u.id
       WHERE u.id = ANY(${[...input.userIds]}::uuid[])
         AND u.status = 'ACTIVE'::user_status
         AND COALESCE(ns.messages, true)`;
    if (rows.length === 0) return 0;
    const [adder, group] = await Promise.all([
      this.prisma.userProfile.findUnique({
        where: { userId: input.adderId },
        select: { displayName: true, username: true },
      }),
      this.prisma.dmGroup.findUnique({ where: { id: input.groupId }, select: { name: true } }),
    ]);
    if (!adder || !group) return 0;
    return this.push.deliver({
      userIds: rows.map((r) => r.id),
      channel: 'messages',
      tag: dmGroupTag(input.groupId),
      data: { kind: 'dm_group', channel: 'messages', groupId: input.groupId, senderUsername: adder.username },
      text: (locale) => ({
        title: group.name,
        body: clip(
          locale === 'ar'
            ? `${adder.displayName} أضافك إلى المجموعة`
            : `${adder.displayName} added you to the group`,
        ),
      }),
    });
  }

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
