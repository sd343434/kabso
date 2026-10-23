import { Injectable } from '@nestjs/common';
import { createTransport, type Transporter } from 'nodemailer';
import type { AppConfig } from '../../config/app-config.js';
import type {
  AccountExistsMail,
  MailLocale,
  MailSender,
  RegistrationCodeMail,
  TokenMail,
} from './mail-sender.js';
import { renderMail, type MailTemplate } from './mail-templates.js';

type SmtpSettings = NonNullable<AppConfig['smtp']>;

/** The nodemailer transport for the SMTP settings: always TLS, bounded waits. */
export function smtpTransport(smtp: SmtpSettings): Transporter {
  return createTransport({
    host: smtp.host,
    port: smtp.port,
    // Implicit TLS (465); otherwise STARTTLS is required, never plain text.
    secure: smtp.secure,
    requireTLS: !smtp.secure,
    auth: { user: smtp.user, pass: smtp.password },
    tls: { minVersion: 'TLSv1.2' },
    connectionTimeout: 10_000,
    greetingTimeout: 10_000,
    socketTimeout: 20_000,
    // nodemailer must never log message bodies (codes, links) or credentials.
    logger: false,
    debug: false,
  });
}

/**
 * KL-042 (B2): sends the rendered messages through SMTP. A failure throws; callers already run
 * sends in the background or catch them, so delivery never fails the user's request. Nothing is
 * logged here: the message holds codes and token links.
 */
@Injectable()
export class SmtpMailSender implements MailSender {
  constructor(
    private readonly transport: Pick<Transporter, 'sendMail'>,
    private readonly from: string,
  ) {}

  sendEmailVerification(mail: TokenMail): Promise<void> {
    return this.send(mail.to, mail.locale, { kind: 'email_verification', link: mail.link });
  }

  sendPasswordReset(mail: TokenMail): Promise<void> {
    const minutes = Math.round((mail.expiresAt.getTime() - Date.now()) / 60_000);
    return this.send(mail.to, mail.locale, { kind: 'password_reset', link: mail.link, minutes });
  }

  sendRegistrationCode(mail: RegistrationCodeMail): Promise<void> {
    const minutes = Math.max(1, Math.round((mail.expiresAt.getTime() - Date.now()) / 60_000));
    return this.send(mail.to, mail.locale, { kind: 'registration_code', code: mail.code, minutes });
  }

  sendAccountExistsNotice(mail: AccountExistsMail): Promise<void> {
    return this.send(mail.to, mail.locale, { kind: 'account_exists', appUrl: mail.appUrl });
  }

  private async send(to: string, locale: MailLocale, template: MailTemplate): Promise<void> {
    const rendered = renderMail(template, locale);
    await this.transport.sendMail({
      from: this.from,
      to,
      subject: rendered.subject,
      text: rendered.text,
      headers: { 'Content-Language': locale, 'Auto-Submitted': 'auto-generated' },
    });
  }
}
