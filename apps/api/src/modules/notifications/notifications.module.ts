import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { NotificationsController } from './notifications.controller.js';
import { NotificationsService } from './notifications.service.js';
import { Notifier } from './notifier.js';

/**
 * CP-009 in-app notifications (CONVENTIONS §11.10): owns `notifications`, `notification_actors`
 * and `notification_settings`. The posts, social, stories and safety modules import it for
 * {@link Notifier}, which writes inside their transactions.
 */
@Module({
  imports: [MediaModule],
  controllers: [NotificationsController],
  providers: [NotificationsService, Notifier],
  exports: [Notifier],
})
export class NotificationsModule {}
