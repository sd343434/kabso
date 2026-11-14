import { Global, Module } from '@nestjs/common';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import { AdminFxController } from './fx.controller.js';
import { FxPoller, FxRatesService } from './fx-rates.service.js';
import { FxSettingsService } from './fx-settings.service.js';

/**
 * v1.81-social (D245, CONVENTIONS §10.87): automatic exchange rates for every country. Global: every price reads its
 * rate through {@link FxRatesService.effective} (recharge orders, the panel, the CLI rule); the poller fetches the free
 * feed hourly or the OWNER's paid provider every minute.
 */
@Global()
@Module({
  providers: [FxRatesService, FxPoller],
  exports: [FxRatesService],
})
export class FxCoreModule {}

/** The panel's «مزوّد أسعار الصرف», «تحديث الآن» and held values. */
@Module({
  imports: [AdminPanelModule],
  controllers: [AdminFxController],
  providers: [FxSettingsService],
})
export class FxModule {}
