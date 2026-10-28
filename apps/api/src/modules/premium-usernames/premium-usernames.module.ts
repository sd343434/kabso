import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { UsersModule } from '../users/users.module.js';
import { PremiumUsernamesController } from './premium-usernames.controller.js';
import { PremiumUsernamesService } from './premium-usernames.service.js';

/**
 * D146 (CONVENTIONS §10.32): owns `premium_username_leases`, `premium_username_payments`,
 * `premium_username_tier_prices`, `premium_username_name_prices` and `premium_username_reserved`;
 * writes `user_profiles.username` / `premium_tier` and the wallet ledger (PREMIUM_USERNAME_*).
 */
@Module({
  imports: [NotificationsModule, UsersModule],
  controllers: [PremiumUsernamesController],
  providers: [PremiumUsernamesService],
  exports: [PremiumUsernamesService],
})
export class PremiumUsernamesModule {}
