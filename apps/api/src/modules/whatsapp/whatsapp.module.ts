import { Logger, Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import { LiveModule } from '../live/live.module.js';
import { MediaModule } from '../media/media.module.js';
import { PushModule } from '../push/push.module.js';
import {
  FetchWhatsAppGraph,
  loadWhatsAppSecrets,
  WHATSAPP_GRAPH,
  WHATSAPP_SECRETS,
  type WhatsAppSecrets,
} from './graph-client.js';
import {
  AdminWhatsAppController,
  StaffWhatsAppController,
  WhatsAppWebhookController,
} from './whatsapp.controller.js';
import { WhatsAppSweeper } from './whatsapp.sweeper.js';
import { WhatsAppWebhookService } from './whatsapp-webhook.service.js';
import { WhatsAppService } from './whatsapp.service.js';

/**
 * v1.116-social (D355, CONVENTIONS §10.151): «واتساب» — owns `wa_*`. Off (every inbox route 503
 * `WHATSAPP_UNAVAILABLE`, the summary `enabled: false`, the webhook 503) until the five WHATSAPP_* settings are on the
 * server; the three secret files are read at boot and a missing or empty one refuses to boot.
 */
@Module({
  imports: [AdminPanelModule, LiveModule, MediaModule, PushModule],
  controllers: [StaffWhatsAppController, AdminWhatsAppController, WhatsAppWebhookController],
  providers: [
    {
      provide: WHATSAPP_SECRETS,
      inject: [APP_CONFIG],
      useFactory: (c: AppConfig) => {
        const secrets = loadWhatsAppSecrets(c.whatsapp);
        new Logger('WhatsApp').log(
          secrets ? { phoneNumberId: c.whatsapp.credentials?.phoneNumberId } : {},
          secrets ? 'WhatsApp is on' : 'WhatsApp is off: the WHATSAPP_* settings are not set',
        );
        return secrets;
      },
    },
    {
      provide: WHATSAPP_GRAPH,
      inject: [APP_CONFIG, WHATSAPP_SECRETS],
      useFactory: (c: AppConfig, s: WhatsAppSecrets | null) =>
        s ? new FetchWhatsAppGraph(c.whatsapp, s) : null,
    },
    WhatsAppService,
    WhatsAppWebhookService,
    WhatsAppSweeper,
  ],
  exports: [WhatsAppService, WhatsAppSweeper],
})
export class WhatsAppModule {}
