import { Global, Module } from '@nestjs/common';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import { createStripeApi, STRIPE_API_FACTORY } from '../topup/stripe-api.js';
import { AdminPaymentSettingsController } from './payment-settings.controller.js';
import { PaymentSettingsService } from './payment-settings.service.js';
import { PaymentSettingsStore } from './payment-settings.store.js';

/**
 * v1.64-social (D196, CONVENTIONS §10.53.1): which Stripe keys and options card top-ups use now — the panel's
 * (`payment_settings`, encrypted) over the server environment. Global: the top-up service, the wallet's app link
 * and the website settings read {@link PaymentSettingsStore}.
 */
@Global()
@Module({
  providers: [PaymentSettingsStore, { provide: STRIPE_API_FACTORY, useValue: createStripeApi }],
  exports: [PaymentSettingsStore],
})
export class PaymentSettingsCoreModule {}

/** The OWNER's «الدفع (Stripe)» section of the admin panel. */
@Module({
  imports: [AdminPanelModule],
  controllers: [AdminPaymentSettingsController],
  providers: [PaymentSettingsService],
})
export class PaymentSettingsModule {}
