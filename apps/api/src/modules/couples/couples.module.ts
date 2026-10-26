import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { UsersModule } from '../users/users.module.js';
import { WalletModule } from '../wallet/wallet.module.js';
import { CouplesController } from './couples.controller.js';
import { CouplesService } from './couples.service.js';

/** CP-018 (D106, CONVENTIONS §10.21): owns `cp_requests`, `cp_couples`, `cp_partners` and `cp_gifts`. */
@Module({
  imports: [NotificationsModule, UsersModule, WalletModule],
  controllers: [CouplesController],
  providers: [CouplesService],
  exports: [CouplesService],
})
export class CouplesModule {}
