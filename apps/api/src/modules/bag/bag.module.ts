import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import { BagController } from './bag.controller.js';
import { BagService } from './bag.service.js';

/**
 * CP-019 (D107, CONVENTIONS §10.22): owns `bag_items` (seeded by migration) and `user_bag_items`
 * (free items written at signup by `grantFreeItemsIn` inside the account's transaction; admin
 * grants by the `bag-admin` CLI).
 */
@Module({
  imports: [UsersModule],
  controllers: [BagController],
  providers: [BagService],
  exports: [BagService],
})
export class BagModule {}
