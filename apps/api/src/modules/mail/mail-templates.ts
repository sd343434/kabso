import type { AccountDeletionMail, DataExportReadyMail, MailLocale } from './mail-sender.js';

/**
 * Transactional email copy (ar + en). Plain text: adapters may wrap it in HTML later.
 * Locale rules (contract v1.2 §6, KL-018): registration code → request locale; account notices,
 * password reset and security mail → the account's stored locale.
 */
export interface RenderedMail {
  readonly subject: string;
  readonly text: string;
}

export type MailTemplate =
  | { readonly kind: 'registration_code'; readonly code: string; readonly minutes: number }
  | { readonly kind: 'account_exists'; readonly appUrl: string }
  | { readonly kind: 'email_verification'; readonly link: string }
  | { readonly kind: 'password_reset'; readonly link: string; readonly minutes: number }
  | {
      readonly kind: 'account_deletion_requested';
      /** The purge date, already formatted for the locale (YYYY-MM-DD, UTC). */
      readonly date: string;
      readonly supportEmail: string;
    }
  | { readonly kind: 'account_deletion_cancelled'; readonly supportEmail: string }
  | { readonly kind: 'data_export_ready'; readonly date: string; readonly supportEmail: string };

/** U+200F RIGHT-TO-LEFT MARK: keeps mixed Arabic/Latin lines right-aligned in plain text. */
const RLM = '\u200f';

export function renderMail(template: MailTemplate, locale: MailLocale): RenderedMail {
  const ar = locale === 'ar';
  switch (template.kind) {
    case 'registration_code':
      return ar
        ? {
            subject: `رمز التحقق من كابسو: ${template.code}`,
            text:
              `${RLM}رمز التحقق الخاص بك هو: ${template.code}\n` +
              `${RLM}أدخل هذا الرمز في التطبيق لإكمال إنشاء حسابك. ينتهي خلال ${template.minutes} دقيقة.\n` +
              `${RLM}إذا لم تطلب إنشاء حساب في كابسو فتجاهل هذه الرسالة.`,
          }
        : {
            subject: `Your Kabso verification code: ${template.code}`,
            text:
              `Your verification code is: ${template.code}\n` +
              `Enter it in the app to finish creating your account. It expires in ${template.minutes} minutes.\n` +
              `If you did not try to create a Kabso account, you can ignore this email.`,
          };
    case 'account_exists':
      return ar
        ? {
            subject: 'لديك حساب في كابسو بالفعل',
            text:
              `${RLM}حاول شخص ما إنشاء حساب جديد في كابسو باستخدام بريدك الإلكتروني، لكن لديك حساب بالفعل.\n` +
              `${RLM}سجّل الدخول من التطبيق، أو أعد تعيين كلمة المرور إذا نسيتها: ${template.appUrl}\n` +
              `${RLM}إذا لم تكن أنت، فلا داعي لأي إجراء؛ لم يتغير شيء في حسابك.`,
          }
        : {
            subject: 'You already have a Kabso account',
            text:
              `Someone tried to create a new Kabso account with your email address, but you already have one.\n` +
              `Log in from the app, or reset your password if you forgot it: ${template.appUrl}\n` +
              `If this wasn't you, no action is needed; nothing changed on your account.`,
          };
    case 'email_verification':
      return ar
        ? {
            subject: 'تأكيد بريدك الإلكتروني في كابسو',
            text: `${RLM}افتح الرابط لتأكيد بريدك الإلكتروني: ${template.link}`,
          }
        : {
            subject: 'Confirm your Kabso email address',
            text: `Open this link to confirm your email address: ${template.link}`,
          };
    case 'password_reset':
      return ar
        ? {
            subject: 'إعادة تعيين كلمة المرور في كابسو',
            text:
              `${RLM}افتح الرابط لإعادة تعيين كلمة المرور (صالح ${template.minutes} دقيقة): ${template.link}\n` +
              `${RLM}إذا لم تطلب ذلك فتجاهل هذه الرسالة.`,
          }
        : {
            subject: 'Reset your Kabso password',
            text:
              `Open this link to reset your password (valid for ${template.minutes} minutes): ${template.link}\n` +
              `If you did not ask for this, ignore this email.`,
          };
    case 'account_deletion_requested':
      return ar
        ? {
            subject: 'طلب حذف حسابك في كابسو',
            text:
              `${RLM}استلمنا طلب حذف حسابك في كابسو. أُخفي حسابك وسُجّل خروجك من كل الأجهزة.\n` +
              `${RLM}سيُحذف الحساب نهائياً في ${template.date}. حتى ذلك الوقت يمكنك إلغاء الحذف بتسجيل الدخول في التطبيق واختيار «إلغاء الحذف».\n` +
              `${RLM}إذا لم تطلب ذلك، سجّل الدخول وألغِ الحذف ثم غيّر كلمة المرور، أو راسلنا على ${template.supportEmail}.`,
          }
        : {
            subject: 'Your Kabso account deletion request',
            text:
              `We received a request to delete your Kabso account. Your account is hidden and you were signed out on every device.\n` +
              `It will be deleted for good on ${template.date}. Until then you can cancel by signing in to the app and choosing "Cancel deletion".\n` +
              `If this wasn't you, sign in, cancel the deletion and change your password, or write to ${template.supportEmail}.`,
          };
    case 'data_export_ready':
      return ar
        ? {
            subject: 'نسخة بياناتك في كابسو جاهزة',
            text:
              `${RLM}نسخة بياناتك التي طلبتها جاهزة للتنزيل.\n` +
              `${RLM}افتح تطبيق كابسو لايف › الإعدادات › الخصوصية › «تنزيل بياناتي» وأنت مسجّل الدخول. يعمل التنزيل مرة واحدة حتى ${template.date}.\n` +
              `${RLM}لا نرسل بياناتك أو رابطاً لها بالبريد. إذا لم تطلب ذلك، غيّر كلمة المرور وراسلنا على ${template.supportEmail}.`,
          }
        : {
            subject: 'Your Kabso data is ready',
            text:
              `The copy of your data you asked for is ready to download.\n` +
              `Open the Kabso Live app › Settings › Privacy › Download my data while signed in. The download works once, until ${template.date}.\n` +
              `We never email your data or a link to it. If this wasn't you, change your password and write to ${template.supportEmail}.`,
          };
    case 'account_deletion_cancelled':
      return ar
        ? {
            subject: 'أُلغي حذف حسابك في كابسو',
            text:
              `${RLM}أُلغي طلب حذف حسابك في كابسو، وعاد حسابك كما كان.\n` +
              `${RLM}إذا لم تكن أنت، غيّر كلمة المرور أو راسلنا على ${template.supportEmail}.`,
          }
        : {
            subject: 'Your Kabso account deletion was cancelled',
            text:
              `The request to delete your Kabso account was cancelled and your account is back as it was.\n` +
              `If this wasn't you, change your password or write to ${template.supportEmail}.`,
          };
  }
}

/** D193: the template of an account-deletion notice (the date in UTC, YYYY-MM-DD: unambiguous in both languages). */
export function deletionTemplate(mail: AccountDeletionMail): MailTemplate {
  return mail.kind === 'requested'
    ? {
        kind: 'account_deletion_requested',
        date: (mail.purgeAfter ?? new Date()).toISOString().slice(0, 10),
        supportEmail: mail.supportEmail,
      }
    : { kind: 'account_deletion_cancelled', supportEmail: mail.supportEmail };
}

/** D198: the template of the data-export notice (the last day in UTC, YYYY-MM-DD). */
export function dataExportTemplate(mail: DataExportReadyMail): MailTemplate {
  return {
    kind: 'data_export_ready',
    date: mail.expiresAt.toISOString().slice(0, 10),
    supportEmail: mail.supportEmail,
  };
}
