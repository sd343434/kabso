import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { UsersModule } from '../users/users.module.js';
import { FollowListsService } from './follow-lists.service.js';
import { FollowRequestsService } from './follow-requests.js';
import { FollowRequestsController, FollowsController, MyFollowersController } from './follows.controller.js';
import { FollowsService } from './follows.service.js';

/** `social` module (contract v1.3): owns the follow graph (`follows`) and, D121, its lists
 * (D125: search, order and removing a follower; v1.47-social, D175: follow requests). */
@Module({
  imports: [NotificationsModule, UsersModule],
  controllers: [FollowsController, MyFollowersController, FollowRequestsController],
  providers: [FollowsService, FollowListsService, FollowRequestsService],
  exports: [FollowsService],
})
export class SocialModule {}
