import { Injectable, Logger } from '@nestjs/common';
import type { MailSender, TokenMail } from './mail-sender.js';

/** Masks the local part of an address for logs: `al***@example.com`. */
export function maskEmail(email: string): string {
  const at = email.lastIndexOf('@');
  if (at <= 0) return '***';
  return `${email.slice(0, Math.min(2, at))}***${email.slice(at)}`;
}

/**
 * Development-only adapter: writes the action link to the log instead of sending mail.
 * Refused in production by config validation. It never receives or logs passwords.
 */
@Injectable()
export class LogMailSender implements MailSender {
  private readonly logger = new Logger('Mail');

  sendEmailVerification(mail: TokenMail): Promise<void> {
    this.write('email_verification', mail);
    return Promise.resolve();
  }

  sendPasswordReset(mail: TokenMail): Promise<void> {
    this.write('password_reset', mail);
    return Promise.resolve();
  }

  private write(kind: string, mail: TokenMail): void {
    this.logger.log(
      {
        mail: {
          kind,
          to: maskEmail(mail.to),
          locale: mail.locale,
          link: mail.link,
          expiresAt: mail.expiresAt.toISOString(),
        },
      },
      `[dev mail] ${kind} → open ${mail.link}`,
    );
  }
}
