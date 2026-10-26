import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { UsersModule } from '../users/users.module.js';
import { WalletModule } from '../wallet/wallet.module.js';
import { FamiliesController, FamilyLookupController } from './families.controller.js';
import { FamiliesService } from './families.service.js';
import { FamilyChatService } from './family-chat.service.js';
import { FamilyRankingsService } from './family-rankings.service.js';

/**
 * CP-018 (D106, CONVENTIONS §10.21): owns `families`, `family_members`, `family_join_requests` and
 * `family_points_ledger` (the last one written through family-points.ts by the wallet's debits);
 * v1.25-live (CP-022, D116): the family boards, `family_chat_messages` and `family_chat_mutes`.
 */
@Module({
  imports: [MediaModule, NotificationsModule, UsersModule, WalletModule],
  controllers: [FamiliesController, FamilyLookupController],
  providers: [FamiliesService, FamilyRankingsService, FamilyChatService],
  exports: [FamiliesService],
})
export class FamiliesModule {}
