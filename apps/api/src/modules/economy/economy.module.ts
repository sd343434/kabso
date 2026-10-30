import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import { AgencyService } from './agency.service.js';
import { CherriesService } from './cherries.service.js';
import { EconomyController } from './economy.controller.js';

/**
 * v1.52-social (D179, CONVENTIONS §10.43): the cherry economy, phase 1 — owns `cherry_wallets`,
 * `cherry_ledger`, `agencies`, `agency_hosts`, `agency_earnings`, `agency_months`, `agency_complaints`
 * and `cherry_withdrawals`. Gifts are credited by the gift send itself (`creditGiftCherriesIn`, in the
 * send's transaction); admins act through the `economy-admin` CLI.
 */
@Module({
  imports: [UsersModule],
  controllers: [EconomyController],
  providers: [CherriesService, AgencyService],
  exports: [AgencyService],
})
export class EconomyModule {}
