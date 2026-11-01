import { Global, Module } from '@nestjs/common';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import { AdminStorageSettingsController } from './storage-settings.controller.js';
import { StorageSettingsService } from './storage-settings.service.js';
import { StorageSettingsStore } from './storage-settings.store.js';

/**
 * v1.75-social (D222, CONVENTIONS §10.72): which object storage uploads use now — the panel's (`storage_settings`,
 * encrypted) over the server environment. Global: the media storage (`OBJECT_STORAGE`), the upload switch and every
 * public media URL read {@link StorageSettingsStore}.
 */
@Global()
@Module({
  providers: [StorageSettingsStore],
  exports: [StorageSettingsStore],
})
export class StorageSettingsCoreModule {}

/** The OWNER's «التخزين (R2 / S3)» section of the admin panel. */
@Module({
  imports: [AdminPanelModule],
  controllers: [AdminStorageSettingsController],
  providers: [StorageSettingsService],
})
export class StorageSettingsModule {}
