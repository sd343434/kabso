import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { UsersModule } from '../users/users.module.js';
import { FollowListsService } from './follow-lists.service.js';
import { FollowsController } from './follows.controller.js';
import { FollowsService } from './follows.service.js';

/** `social` module (contract v1.3): owns the follow graph (`follows`) and, D121, its lists. */
@Module({
  imports: [NotificationsModule, UsersModule],
  controllers: [FollowsController],
  providers: [FollowsService, FollowListsService],
  exports: [FollowsService],
})
export class SocialModule {}
