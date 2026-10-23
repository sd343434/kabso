import { Module } from '@nestjs/common';
import { AdminGuard, AdminPermissions } from '../levels/admin.guard.js';
import { LiveModule } from '../live/live.module.js';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { PostsModule } from '../posts/posts.module.js';
import { UsersModule } from '../users/users.module.js';
import { AdminReportsController, SafetyController } from './safety.controller.js';
import { SafetyService } from './safety.service.js';

/**
 * v1.5-social safety (CONVENTIONS §11.7): owns `user_blocks`, `user_mutes`, `post_hides`,
 * `reports` and `privacy_settings`.
 */
@Module({
  imports: [LiveModule, NotificationsModule, PostsModule, UsersModule],
  controllers: [SafetyController, AdminReportsController],
  providers: [SafetyService, AdminGuard, AdminPermissions],
})
export class SafetyModule {}
