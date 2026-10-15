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

/** Outbound mail port. Adapters: `log` (development). SMTP is BLOCKED (B2). */
export interface MailSender {
  sendEmailVerification(mail: TokenMail): Promise<void>;
  sendPasswordReset(mail: TokenMail): Promise<void>;
}

export const MAIL_SENDER = Symbol('MAIL_SENDER');
