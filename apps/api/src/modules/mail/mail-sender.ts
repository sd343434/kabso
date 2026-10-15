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

/** Outbound mail port. Adapters: `log` (development). SMTP is BLOCKED (B2). */
export interface MailSender {
  sendEmailVerification(mail: TokenMail): Promise<void>;
  sendPasswordReset(mail: TokenMail): Promise<void>;
  sendRegistrationCode(mail: RegistrationCodeMail): Promise<void>;
  sendAccountExistsNotice(mail: AccountExistsMail): Promise<void>;
}

export const MAIL_SENDER = Symbol('MAIL_SENDER');
