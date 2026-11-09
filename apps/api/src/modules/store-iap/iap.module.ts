import { Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { AuthModule } from '../auth/auth.module.js';
import { PublicProfileModule } from '../users/profiles/public-profile.module.js';
import { IapController } from './iap.controller.js';
import { IapService } from './iap.service.js';
import { IapSweeper } from './iap.sweeper.js';
import { IAP_STORE_CLIENTS, loadStoreClients } from './store-clients.js';

/**
 * v1.110-social (D345, CONVENTIONS §10.144): coins from Google Play Billing and App Store In-App Purchase. The store
 * clients are built once from the credential files (a bad file stops the boot); tests override IAP_STORE_CLIENTS.
 */
@Module({
  imports: [AuthModule, PublicProfileModule],
  controllers: [IapController],
  providers: [
    {
      provide: IAP_STORE_CLIENTS,
      inject: [APP_CONFIG],
      useFactory: (c: AppConfig) => loadStoreClients(c.storeIap),
    },
    IapService,
    IapSweeper,
  ],
  exports: [IapService],
})
export class IapModule {}
