import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import { WalletHistoryService } from './wallet-history.service.js';
import { WalletController } from './wallet.controller.js';
import { WalletService } from './wallet.service.js';

/** CP-017 (D104): owns `wallets` and `wallet_ledger`. v1.43-social (D164): their history, earnings. */
@Module({
  imports: [UsersModule],
  controllers: [WalletController],
  providers: [WalletService, WalletHistoryService],
  exports: [WalletService],
})
export class WalletModule {}
