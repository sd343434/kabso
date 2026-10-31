export type MailLocale = 'ar' | 'en';

export interface TokenMail {
  readonly to: string;
  readonly locale: MailLocale;
  /** The raw single-use token (only ever leaves the server inside this message). */
  readonly token: string;
  /** Link the user follows; contains the token. */
  readonly link: string;
  readonly expiresAt: Date;
}

/** Verify-first registration code (contract v1.2 §6). Locale = request locale. */
export interface RegistrationCodeMail {
  readonly to: string;
  readonly locale: MailLocale;
  /** 8-digit code; only ever leaves the server inside this message. */
  readonly code: string;
  readonly expiresAt: Date;
}

/** "An account already exists for this address" notice. Locale = the account's locale. */
export interface AccountExistsMail {
  readonly to: string;
  readonly locale: MailLocale;
  /** Base URL of the app, for "log in / reset password" pointers. */
  readonly appUrl: string;
}

/**
 * v1.62-social (D193, §10.56): the account-deletion notices — `requested` (with the date the account will be purged)
 * and `cancelled`. Locale = the account's locale. No link that could act on the account (a phished link must not
 * cancel or confirm anything): the person signs in to the app to cancel.
 */
export interface AccountDeletionMail {
  readonly to: string;
  readonly locale: MailLocale;
  readonly kind: 'requested' | 'cancelled';
  /** `requested` only: when the account will be deleted for good. */
  readonly purgeAfter: Date | null;
  /** Contact address for help (support), shown in the message. */
  readonly supportEmail: string;
}

/**
 * v1.66-social (D198, §10.61.1): «بياناتك جاهزة للتنزيل». Like D193's notices it carries NO link that acts on the
 * account (a phished copy must not hand the data to anyone): the person downloads it in the app, signed in, once,
 * before `expiresAt`.
 */
export interface DataExportReadyMail {
  readonly to: string;
  readonly locale: MailLocale;
  readonly expiresAt: Date;
  readonly supportEmail: string;
}

/** Outbound mail port. Adapters: `log` (development) and `smtp` (KL-042). */
export interface MailSender {
  sendEmailVerification(mail: TokenMail): Promise<void>;
  sendPasswordReset(mail: TokenMail): Promise<void>;
  sendRegistrationCode(mail: RegistrationCodeMail): Promise<void>;
  sendAccountExistsNotice(mail: AccountExistsMail): Promise<void>;
  sendAccountDeletionNotice(mail: AccountDeletionMail): Promise<void>;
  sendDataExportReady(mail: DataExportReadyMail): Promise<void>;
}

export const MAIL_SENDER = Symbol('MAIL_SENDER');
