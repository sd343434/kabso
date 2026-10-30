import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { UsersModule } from '../users/users.module.js';
import { BagController } from './bag.controller.js';
import { BagService } from './bag.service.js';

/**
 * CP-019 (D107, CONVENTIONS §10.22): owns `bag_items` (seeded by migration) and `user_bag_items`
 * (free items written at signup by `grantFreeItemsIn` inside the account's transaction; admin
 * grants by the `bag-admin` CLI). v1.46-live (D171, §10.41): `bag_transfers` (sends between users,
 * notified through the notifications module's `Notifier`) and the expired-item sweeper.
 */
@Module({
  imports: [UsersModule, NotificationsModule],
  controllers: [BagController],
  providers: [BagService],
  exports: [BagService],
})
export class BagModule {}
