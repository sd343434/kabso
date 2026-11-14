import { Global, Module } from '@nestjs/common';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import { createDiditApi, DIDIT_API_FACTORY } from './didit-api.js';
import { KycAdminService } from './kyc-admin.service.js';
import { KycSettingsService } from './kyc-settings.service.js';
import { AdminKycController, KycController, KycWebhookController } from './kyc.controller.js';
import { KycService } from './kyc.service.js';
import { KycSettingsStore } from './kyc.store.js';

/**
 * v1.80-kyc (D227, CONVENTIONS §10.77): identity checks with Didit. Global store: the applications' services read
 * whether Didit is on (`KycSettingsStore`; the gates themselves read the row in their transaction, kyc-core.ts).
 */
@Global()
@Module({
  providers: [KycSettingsStore, { provide: DIDIT_API_FACTORY, useValue: createDiditApi }],
  exports: [KycSettingsStore, DIDIT_API_FACTORY],
})
export class KycCoreModule {}

@Module({
  imports: [AdminPanelModule],
  controllers: [KycController, KycWebhookController, AdminKycController],
  providers: [KycService, KycSettingsService, KycAdminService],
  exports: [KycService],
})
export class KycModule {}
