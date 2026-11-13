import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import { clip } from '../push/push-texts.js';
import { PushService } from '../push/push.service.js';

/** v1.137-social (D385, §10.174): the name of «دعم كابسو» in the person's language (pushes, the staff alert). */
export const SUPPORT_TITLE = { ar: 'دعم كابسو', en: 'Kabso Support' } as const;

/** The staff alert's title for an in-app thread «داخل التطبيق». */
export const SUPPORT_STAFF_TITLE = {
  ar: 'دعم كابسو — داخل التطبيق',
  en: 'Kabso Support — in app',
} as const;

/** The Android tag (and the app's thread key) of a person's «دعم كابسو» push. */
export function supportTag(conversationId: string): string {
  return `support:${conversationId}`;
}

/**
 * v1.137-social (D385, §10.174.2): the only part of a staff member that a person sees — the first word of their display
 * name (at most 40 characters), shown under the «فريق كابسو» badge; null when there is none. Never the account.
 */
export function staffFirstName(displayName: string | null | undefined): string | null {
  const first = (displayName ?? '').trim().split(/\s+/u)[0] ?? '';
  if (first.length === 0) return null;
  return Array.from(first).slice(0, 40).join('');
}

/**
 * v1.137-social (D385, §10.174.6): the push of a staff reply to the person — every reply (no gap), channel `messages`,
 * to an ACTIVE account that keeps `messages` on. Title «دعم كابسو», body «<first name> · فريق كابسو: <text>». Returns how
 * many devices accepted it.
 */
@Injectable()
export class SupportPush {
  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushService,
  ) {}

  async reply(input: {
    userId: string;
    conversationId: string;
    staffId: string;
    text: string;
  }): Promise<number> {
    if (!this.push.enabled) return 0;
    const rows = await this.prisma.$queryRaw<{ ok: boolean }[]>`
      SELECT true AS ok
        FROM users u
        LEFT JOIN notification_settings ns ON ns.user_id = u.id
       WHERE u.id = ${input.userId}::uuid
         AND u.status = 'ACTIVE'::user_status
         AND COALESCE(ns.messages, true)
         AND EXISTS (SELECT 1 FROM device_tokens d WHERE d.user_id = u.id)`;
    if (rows.length === 0) return 0;
    const profile = await this.prisma.userProfile.findUnique({
      where: { userId: input.staffId },
      select: { displayName: true },
    });
    const first = staffFirstName(profile?.displayName);
    return this.push.deliver({
      userIds: [input.userId],
      channel: 'messages',
      tag: supportTag(input.conversationId),
      data: { kind: 'support', channel: 'messages', conversationId: input.conversationId },
      text: (locale) => {
        const team = locale === 'ar' ? 'فريق كابسو' : 'Kabso Team';
        const who = first ? `${first} · ${team}` : team;
        return { title: SUPPORT_TITLE[locale], body: clip(`${who}: ${input.text}`) };
      },
    });
  }
}
