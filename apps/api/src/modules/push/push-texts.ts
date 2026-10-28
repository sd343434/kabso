/**
 * D152 (CONVENTIONS §11.12): the text of a push, in the recipient's account language — the inbox's
 * own sentences (app_ar.arb / app_en.arb `notif*`), so a push reads like the row it opens.
 */

/** What a general push needs from a `Notification` (§11.10). */
export interface NotificationText {
  readonly type: string;
  /** The newest visible actor's display name, or null (system types). */
  readonly actorName: string | null;
  /** All visible actors (the newest included). */
  readonly actorCount: number;
  readonly targetType: string | null;
  readonly targetId: string | null;
  /** The family's name (FAMILY targets). */
  readonly targetText: string | null;
}

export type PushLocale = 'ar' | 'en';

export const PUSH_TITLE: Readonly<Record<PushLocale, string>> = { ar: 'Kabso Live', en: 'Kabso Live' };

/** At most this many code points of a chat message in its push. */
export const PUSH_BODY_MAX = 100;

const AR_PLURAL = new Intl.PluralRules('ar');

/** "Sara", "Sara and 2 others" / «سارة و2 أشخاص آخرين» (`notifActors`). */
export function who(name: string, others: number, locale: PushLocale): string {
  if (others <= 0) return name;
  if (locale === 'en') return `${name} and ${others} ${others === 1 ? 'other' : 'others'}`;
  switch (AR_PLURAL.select(others)) {
    case 'one':
      return `${name} وشخص آخر`;
    case 'two':
      return `${name} وشخصان آخران`;
    case 'few':
      return `${name} و${others} أشخاص آخرين`;
    case 'many':
      return `${name} و${others} شخصًا آخر`;
    default:
      return `${name} و${others} شخص آخر`;
  }
}

/** The body of a general push, or null for a type this server cannot word (nothing is sent). */
export function notificationBody(n: NotificationText, locale: PushLocale): string | null {
  const ar = locale === 'ar';
  const w = n.actorName === null ? null : who(n.actorName, n.actorCount - 1, locale);
  const family = n.targetText ?? '';
  switch (n.type) {
    case 'LIKE_POST':
      return w && (ar ? `أعجب ${w} بمنشورك` : `${w} liked your post`);
    case 'LIKE_COMMENT':
      return w && (ar ? `أعجب ${w} بتعليقك` : `${w} liked your comment`);
    case 'COMMENT':
      return w && (ar ? `علّق ${w} على منشورك` : `${w} commented on your post`);
    case 'REPLY':
      return w && (ar ? `ردّ ${w} على تعليقك` : `${w} replied to your comment`);
    case 'MENTION':
      if (!w) return null;
      if (n.targetType === 'COMMENT')
        return ar ? `أشار إليك ${w} في تعليق` : `${w} mentioned you in a comment`;
      if (n.targetType === 'STORY') return ar ? `أشار إليك ${w} في قصة` : `${w} mentioned you in a story`;
      return ar ? `أشار إليك ${w} في منشور` : `${w} mentioned you in a post`;
    case 'FOLLOW':
      return w && (ar ? `بدأ ${w} بمتابعتك` : `${w} started following you`);
    case 'REPOST':
      return w && (ar ? `أعاد ${w} نشر منشورك` : `${w} reposted your post`);
    case 'POST_PUBLISHED':
      return ar ? 'نُشر منشورك المجدول' : 'Your scheduled post is now live';
    case 'CONTENT_REMOVED':
      if (n.targetType === 'COMMENT') {
        return ar
          ? 'أُزيل تعليقك لمخالفته إرشادات المجتمع'
          : 'Your comment was removed for breaking the community guidelines';
      }
      if (n.targetType === 'STORY') {
        return ar
          ? 'أُزيلت قصتك لمخالفتها إرشادات المجتمع'
          : 'Your story was removed for breaking the community guidelines';
      }
      return ar
        ? 'أُزيل منشورك لمخالفته إرشادات المجتمع'
        : 'Your post was removed for breaking the community guidelines';
    case 'LIVE_SCHEDULED_SOON':
      return w && (ar ? `يبدأ ${w} بثًا مباشرًا قريبًا` : `${w} goes live soon`);
    case 'CP_REQUEST':
      return w && (ar ? `${w} أرسل لك طلب علاقة` : `${w} sent you a CP request`);
    case 'CP_ACCEPTED':
      return w && (ar ? `${w} قبل طلب العلاقة، أصبحتما ثنائياً` : `${w} accepted your CP request`);
    case 'FAMILY_JOIN_ACCEPTED':
      return ar ? `تم قبولك في عائلة ${family}` : `You're now a member of ${family}`;
    case 'FAMILY_JOIN_DECLINED':
      return ar ? `تم رفض طلبك للانضمام إلى ${family}` : `Your request to join ${family} was declined`;
    case 'MEDAL_AWARDED':
      return ar ? 'حصلت على ميدالية جديدة' : 'You earned a new medal';
    case 'PREMIUM_USERNAME_EXPIRING':
      return ar
        ? `يوشك يوزرك المميز @${n.targetId ?? ''} على الانتهاء`
        : `Your premium username @${n.targetId ?? ''} ends soon`;
    case 'PREMIUM_USERNAME_EXPIRED':
      return ar
        ? `انتهت مدة يوزرك المميز @${n.targetId ?? ''}`
        : `Your premium username @${n.targetId ?? ''} has ended`;
    default:
      return null;
  }
}

/** One line of at most `max` code points (a chat message's push body). */
export function clip(text: string, max: number = PUSH_BODY_MAX): string {
  const flat = text.replace(/\s+/gu, ' ').trim();
  const points = [...flat];
  return points.length <= max
    ? flat
    : `${points
        .slice(0, max - 1)
        .join('')
        .trimEnd()}…`;
}
