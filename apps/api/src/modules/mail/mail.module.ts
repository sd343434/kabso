import { Global, Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { LogMailSender } from './log-mail-sender.js';
import { MAIL_SENDER, type MailSender } from './mail-sender.js';
import { SmtpMailSender, smtpTransport } from './smtp-mail-sender.js';

@Global()
@Module({
  providers: [
    LogMailSender,
    {
      provide: MAIL_SENDER,
      inject: [APP_CONFIG, LogMailSender],
      useFactory: (config: AppConfig, log: LogMailSender): MailSender => {
        switch (config.mailTransport) {
          case 'log':
            return log;
          case 'smtp': {
            // Validation guarantees the settings when the transport is smtp.
            const smtp = config.smtp;
            if (smtp === null) throw new Error('MAIL_TRANSPORT=smtp without SMTP settings');
            return new SmtpMailSender(smtpTransport(smtp), smtp.from);
          }
        }
      },
    },
  ],
  exports: [MAIL_SENDER],
})
export class MailModule {}
