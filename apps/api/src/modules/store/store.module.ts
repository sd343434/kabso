import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { UsersModule } from '../users/users.module.js';
import { StoreAdminService } from './store-admin.service.js';
import { StoreController } from './store.controller.js';
import { StoreService } from './store.service.js';

/**
 * D270 (CONVENTIONS §10.98): «المتجر». Owns `store_items`, `store_item_prices` and `store_purchases`; each item is a
 * `bag_items` row too. Takes coins through `wallet_ledger` and cherries through `cherry_ledger` (`STORE_PURCHASE`).
 * The admin panel's page uses {@link StoreAdminService} (exported).
 */
@Module({
  imports: [UsersModule, MediaModule, NotificationsModule],
  controllers: [StoreController],
  providers: [StoreService, StoreAdminService],
  exports: [StoreAdminService],
})
export class StoreModule {}
