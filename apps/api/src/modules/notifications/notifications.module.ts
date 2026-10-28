import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { PushModule } from '../push/push.module.js';
import { NotificationPushDispatcher } from './notification-push.dispatcher.js';
import { NotificationsController } from './notifications.controller.js';
import { NotificationsService } from './notifications.service.js';
import { Notifier } from './notifier.js';

/**
 * CP-009 in-app notifications (CONVENTIONS §11.10): owns `notifications`, `notification_actors`
 * and `notification_settings`. The posts, social, stories and safety modules import it for
 * {@link Notifier}, which writes inside their transactions. v1.30-live (D152, §11.12): the
 * {@link NotificationPushDispatcher} pushes new notifications through the push module.
 */
@Module({
  imports: [MediaModule, PushModule],
  controllers: [NotificationsController],
  providers: [NotificationsService, Notifier, NotificationPushDispatcher],
  exports: [Notifier, NotificationPushDispatcher],
})
export class NotificationsModule {}
