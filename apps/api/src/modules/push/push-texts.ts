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
  /** The family's name (FAMILY targets); the agency's name (AGENCY). */
  readonly targetText: string | null;
  /** v1.70-social (D206): AGENCY targets — the activated hosts reached and the hosts needed. */
  readonly activatedHosts?: number | null;
  readonly requiredHosts?: number | null;
  /** v1.70-social (D206): AGENCY_PROBATION_DAYS (the closing's sentence). */
  readonly probationDays?: number | null;
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
    case 'BAG_ITEM_RECEIVED':
      return w && (ar ? `أرسل لك ${w} عنصراً إلى حقيبتك` : `${w} sent you an item for your bag`);
    case 'RECHARGE_COINS_RECEIVED':
      return w && (ar ? `شحن لك ${w} عملات` : `${w} topped up your coins`);
    case 'RECHARGE_CHERRY_REQUEST':
      return w && (ar ? `${w} يطلب تأكيد بيع كرز` : `${w} asks you to confirm a cherry sale`);
    case 'RECHARGE_ORDER_UPDATE':
      return rechargeOrderBody(n.targetText, ar);
    case 'PREMIUM_USERNAME_EXPIRED':
      return ar
        ? `انتهت مدة يوزرك المميز @${n.targetId ?? ''}`
        : `Your premium username @${n.targetId ?? ''} has ended`;
    // v1.70-social (D206, §10.65): «افتح وكالة».
    case 'AGENCY_OPENED':
      return ar
        ? 'وكالتك مفتوحة الآن. فعّل مضيفيك خلال فترة التجربة'
        : 'Your agency is open. Activate your hosts during the trial period';
    case 'AGENCY_PROBATION_REMINDER': {
      const x = n.activatedHosts ?? 0;
      const y = n.requiredHosts ?? 0;
      return ar
        ? `بقي أقل من يوم على نهاية فترة التجربة: المضيفون المفعّلون ${x} / ${y}`
        : `Less than a day left in your agency's trial: ${x} / ${y} hosts activated`;
    }
    case 'AGENCY_PROBATION_PASSED':
      return ar ? 'اجتازت وكالتك فترة التجربة' : 'Your agency passed its trial period';
    case 'AGENCY_CLOSED':
      if (n.requiredHosts === null || n.requiredHosts === undefined) {
        return ar ? 'أُغلقت وكالتك من قِبل فريق Kabso' : 'Your agency was closed by the Kabso team';
      }
      // The owner's sentence (2026-10-31), with the count reached.
      return ar
        ? `أُغلقت وكالتك لأنها لم تفعّل ${n.requiredHosts} مضيفين (بثّ واستلام هدايا) خلال ${n.probationDays ?? 7} أيام — المفعّلون: ${n.activatedHosts ?? 0}`
        : `Your agency was closed because it did not activate ${n.requiredHosts} hosts (live + gifts) within ${n.probationDays ?? 7} days — activated: ${n.activatedHosts ?? 0}`;
    case 'AGENCY_HOST_RELEASED':
      return ar
        ? 'أُغلقت الوكالة التي كنت فيها، وأصبحت حرًا للانضمام إلى وكالة أخرى'
        : 'Your agency was closed; you are free to join another agency';
    // v1.73-social (D209, §10.68): «كن مضيفاً مع الإدارة» (the reason of a rejection is in the app, not the push).
    case 'HOST_APPLICATION_APPROVED':
      return ar
        ? 'تمت الموافقة على طلبك: أنت الآن مضيف مع إدارة Kabso Live ويمكنك بدء البث'
        : 'Your application was approved: you now host with the Kabso Live team and can go live';
    case 'HOST_APPLICATION_REJECTED':
      return ar
        ? 'لم تتم الموافقة على طلبك لتكون مضيفاً مع الإدارة. افتح «الوكالة» لمعرفة السبب'
        : 'Your application to host with the Kabso Live team was not approved. Open Agency to see why';
    case 'DATA_EXPORT_READY':
      // v1.66-social (D198): the push says only that it is ready (never what is inside).
      return ar ? 'نسخة بياناتك جاهزة للتنزيل' : 'Your data is ready to download';
    // v1.72-social (D208): the team's account controls (the inbox row says what and until when).
    case 'ACCOUNT_RESTRICTED':
      return ar
        ? 'فرض فريق Kabso قيداً مؤقتاً على حسابك'
        : 'The Kabso team restricted your account for a while';
    case 'ACCOUNT_RESTRICTION_LIFTED':
      return ar ? 'رُفع القيد عن حسابك' : 'The restriction on your account was lifted';
    case 'BALANCE_ADJUSTED':
      return ar ? 'عدّل فريق Kabso رصيدك' : 'The Kabso team adjusted your balance';
    // v1.74-social (D217): the amount is in the cherry history (`REFERRAL_REVERSAL`).
    case 'REFERRAL_REWARD_REVERSED':
      return ar
        ? 'ألغى فريق Kabso دعوة غير صالحة واسترجع كرز مكافأتها'
        : 'The Kabso team voided an invalid invite and took back its cherries';
    case 'PROFILE_EDITED_BY_TEAM':
      return ar ? 'عدّل فريق Kabso ملفك الشخصي' : 'The Kabso team edited your profile';
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

/** v1.69-social (D204): the push of a recharge order's latest event (`targetText` carries the event). */
function rechargeOrderBody(event: string | null, ar: boolean): string {
  switch (event) {
    case 'CREATED':
      return ar
        ? 'طلب شحن جديد ينتظر معلومات الدفع'
        : 'A new recharge order is waiting for your payment details';
    case 'DETAILS_SENT':
      return ar
        ? 'أرسل الوكيل معلومات الدفع لطلب الشحن'
        : 'The agent sent the payment details for your order';
    case 'PAID':
      return ar
        ? 'أكّد المشتري إرسال المبلغ: تحقّق من وصول الحوالة'
        : 'The buyer says the money was sent: check the transfer';
    case 'COMPLETED':
    case 'COMPLETED_BY_ADMIN':
      return ar ? 'تمت إضافة العملات من طلب الشحن' : 'The coins of your recharge order were added';
    case 'REFUNDED_TO_AGENT':
      return ar
        ? 'أُغلق النزاع وأُعيدت العملات إلى الوكيل'
        : 'The dispute was closed and the coins went back to the agent';
    case 'DISPUTED':
      return ar ? 'فُتح نزاع على طلب الشحن' : 'A dispute was opened on the recharge order';
    case 'CANCELLED':
      return ar ? 'أُلغي طلب الشحن' : 'The recharge order was cancelled';
    case 'EXPIRED':
      return ar ? 'انتهت مهلة طلب الشحن' : 'The recharge order expired';
    case 'ADMIN_MESSAGE':
      return ar ? 'رسالة من الإدارة في طلب الشحن' : 'A message from the team on the recharge order';
    case 'IMAGE':
      return ar ? 'صورة جديدة في طلب الشحن' : 'A new picture on the recharge order';
    default:
      return ar ? 'رسالة جديدة في طلب الشحن' : 'A new message on the recharge order';
  }
}
