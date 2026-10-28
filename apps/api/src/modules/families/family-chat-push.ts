import { Inject, Injectable } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { PushService } from '../push/push.service.js';
import { clip } from '../push/push-texts.js';
import { PushThrottle } from '../push/push-throttle.js';

/** The Android tag (and conversation id in the app) of a family's chat. */
export function familyChatTag(familyId: string): string {
  return `family:${familyId}`;
}

/**
 * v1.30-live (D152, CONVENTIONS §11.12): the push of a new family chat message (channel
 * `messages`). To the family's other members who are ACTIVE, keep `messages` on, have no block
 * either way with the author and have not muted them — never the sender; one per member per chat
 * per `PUSH_MESSAGES_GAP_SECONDS`. Runs after the send's response (BackgroundTasks).
 */
@Injectable()
export class FamilyChatPush {
  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushService,
    private readonly throttle: PushThrottle,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** Returns how many devices accepted it. */
  async newMessage(input: {
    familyId: string;
    messageId: string;
    authorId: string;
    text: string;
  }): Promise<number> {
    if (!this.push.enabled) return 0;
    const { familyId, messageId, authorId } = input;
    const rows = await this.prisma.$queryRaw<{ user_id: string }[]>`
      SELECT fm.user_id
        FROM family_members fm
        JOIN users u ON u.id = fm.user_id AND u.status = 'ACTIVE'::user_status
        LEFT JOIN notification_settings ns ON ns.user_id = fm.user_id
       WHERE fm.family_id = ${familyId}::uuid
         AND fm.user_id <> ${authorId}::uuid
         AND COALESCE(ns.messages, true)
         AND EXISTS (SELECT 1 FROM device_tokens d WHERE d.user_id = fm.user_id)
         AND NOT EXISTS (SELECT 1 FROM user_blocks b
                          WHERE (b.blocker_id = fm.user_id AND b.blocked_id = ${authorId}::uuid)
                             OR (b.blocker_id = ${authorId}::uuid AND b.blocked_id = fm.user_id))
         AND NOT EXISTS (SELECT 1 FROM user_mutes m
                          WHERE m.muter_id = fm.user_id AND m.muted_id = ${authorId}::uuid)`;
    if (rows.length === 0) return 0;
    const tag = familyChatTag(familyId);
    const allowed = await this.throttle.allowMany(
      rows.map((r) => `m:${tag}:${r.user_id}`),
      this.config.push.messagesGapSeconds,
    );
    const userIds = rows.map((r) => r.user_id).filter((id) => allowed.has(`m:${tag}:${id}`));
    if (userIds.length === 0) return 0;
    const [family, author] = await Promise.all([
      this.prisma.family.findUnique({ where: { id: familyId }, select: { name: true } }),
      this.prisma.userProfile.findUnique({ where: { userId: authorId }, select: { displayName: true } }),
    ]);
    if (!family || !author) return 0;
    const body = clip(`${author.displayName}: ${input.text}`);
    return this.push.deliver({
      userIds,
      channel: 'messages',
      tag,
      data: { kind: 'family_chat', channel: 'messages', familyId, messageId },
      text: () => ({ title: family.name, body }),
    });
  }
}
