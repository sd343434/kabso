import { Module } from '@nestjs/common';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import { AdminReferralsController } from './admin-referrals.controller.js';
import { AdminReferralsService } from './admin-referrals.service.js';
import { ReferralsController, ReferralTickerController } from './referrals.controller.js';
import { ReferralSweeper, ReferralsService } from './referrals.service.js';

/**
 * «دعوة الأصدقاء» (v1.74-social, D217, CONVENTIONS §10.71): owns `referral_settings`, `referral_codes`, `referrals` and
 * `referral_rewards`. The sign-up (`RegistrationService`) and the three recharge paths call the shared rules in
 * `referral-core.ts` directly (no module dependency); the panel's «الدعوات» and `referral-admin` use them too.
 */
@Module({
  imports: [AdminPanelModule],
  controllers: [ReferralsController, ReferralTickerController, AdminReferralsController],
  providers: [ReferralsService, ReferralSweeper, AdminReferralsService],
  exports: [ReferralSweeper],
})
export class ReferralsModule {}
