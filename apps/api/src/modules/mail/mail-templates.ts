import type { MailLocale } from './mail-sender.js';

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
  | { readonly kind: 'password_reset'; readonly link: string; readonly minutes: number };

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
  }
}
