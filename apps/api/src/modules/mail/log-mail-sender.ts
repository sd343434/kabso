import { Inject, Injectable, Logger } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type {
  AccountExistsMail,
  MailLocale,
  MailSender,
  RegistrationCodeMail,
  TokenMail,
} from './mail-sender.js';
import { renderMail, type MailTemplate } from './mail-templates.js';

/** Masks the local part of an address for logs: `al***@example.com`. */
export function maskEmail(email: string): string {
  const at = email.lastIndexOf('@');
  if (at <= 0) return '***';
  return `${email.slice(0, Math.min(2, at))}***${email.slice(at)}`;
}

const REDACTED = '[REDACTED]';

/**
 * Development-only adapter: writes the rendered message to the log instead of sending it.
 * Refused in production by config validation; as defence in depth, secrets (codes, token links)
 * are only written when NODE_ENV is not production. It never receives or logs passwords.
 */
@Injectable()
export class LogMailSender implements MailSender {
  private readonly logger = new Logger('Mail');

  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {}

  sendEmailVerification(mail: TokenMail): Promise<void> {
    return this.write(mail.to, mail.locale, { kind: 'email_verification', link: mail.link }, [mail.link]);
  }

  sendPasswordReset(mail: TokenMail): Promise<void> {
    const minutes = Math.round((mail.expiresAt.getTime() - Date.now()) / 60_000);
    return this.write(mail.to, mail.locale, { kind: 'password_reset', link: mail.link, minutes }, [
      mail.link,
    ]);
  }

  sendRegistrationCode(mail: RegistrationCodeMail): Promise<void> {
    const minutes = Math.max(1, Math.round((mail.expiresAt.getTime() - Date.now()) / 60_000));
    return this.write(mail.to, mail.locale, { kind: 'registration_code', code: mail.code, minutes }, [
      mail.code,
    ]);
  }

  sendAccountExistsNotice(mail: AccountExistsMail): Promise<void> {
    return this.write(mail.to, mail.locale, { kind: 'account_exists', appUrl: mail.appUrl }, []);
  }

  private write(
    to: string,
    locale: MailLocale,
    template: MailTemplate,
    secrets: readonly string[],
  ): Promise<void> {
    const rendered = renderMail(template, locale);
    const reveal = !this.config.isProduction;
    const scrub = (text: string) =>
      reveal ? text : secrets.reduce((acc, secret) => acc.split(secret).join(REDACTED), text);
    this.logger.log(
      {
        mail: {
          kind: template.kind,
          to: maskEmail(to),
          locale,
          subject: scrub(rendered.subject),
          text: scrub(rendered.text),
        },
      },
      `[dev mail] ${template.kind} → ${maskEmail(to)}`,
    );
    return Promise.resolve();
  }
}
