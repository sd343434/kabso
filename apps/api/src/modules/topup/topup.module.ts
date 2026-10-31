import { Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { createStripeApi, STRIPE_API } from './stripe-api.js';
import { TopupController, TopupWebController } from './topup.controller.js';
import { TopupService } from './topup.service.js';

/** v1.59-social (D190): card top-ups on the website through Stripe (CONVENTIONS §10.53). */
@Module({
  controllers: [TopupController, TopupWebController],
  providers: [
    TopupService,
    {
      provide: STRIPE_API,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) =>
        config.topup.stripe ? createStripeApi(config.topup.stripe.secretKey) : null,
    },
  ],
  exports: [TopupService],
})
export class TopupModule {}
