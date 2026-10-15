import { Global, Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { LogMailSender } from './log-mail-sender.js';
import { MAIL_SENDER, type MailSender } from './mail-sender.js';

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
        }
      },
    },
  ],
  exports: [MAIL_SENDER],
})
export class MailModule {}
