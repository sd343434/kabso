import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { TopupHandoffService } from './topup-handoff.service.js';
import { TopupController, TopupWebController } from './topup.controller.js';
import { TopupService } from './topup.service.js';

/**
 * v1.59-social (D190): card top-ups on the website through Stripe (CONVENTIONS §10.53). v1.64-social (D196): the
 * keys, options and the Stripe client come from the global `PaymentSettingsStore` (panel over env, §10.53.1).
 */
@Module({
  // v1.109-social (D344): the website handoff issues sessions and access tokens.
  imports: [AuthModule],
  controllers: [TopupController, TopupWebController],
  providers: [TopupService, TopupHandoffService],
  exports: [TopupService],
})
export class TopupModule {}
