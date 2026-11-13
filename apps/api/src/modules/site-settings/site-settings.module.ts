import { Module } from '@nestjs/common';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import {
  AdminCameraFxController,
  AdminGlobalStripsController,
  AdminLevelTickerController,
  AdminSiteSettingsController,
  SiteSettingsController,
} from './site-settings.controller.js';
import { SiteSettingsService } from './site-settings.service.js';

/**
 * v1.60-social (D191/D192, CONVENTIONS §10.54.6): the public website's settings — owns `site_settings`. Public read
 * `GET /site/settings`; the OWNER's `PUT /admin/site-settings` behind the panel session. D228: the OWNER's
 * `GET|PUT /admin/camera-fx` (the app's camera effects engine, a row of the same table). D254: the OWNER's
 * `GET|PUT /admin/level-ticker` (the level-up banner's threshold, a row of the same table). D305: the OWNER's
 * `GET|PUT /admin/global-strips` (the global strips' thresholds, a row of the same table).
 */
@Module({
  imports: [AdminPanelModule],
  controllers: [
    SiteSettingsController,
    AdminSiteSettingsController,
    AdminCameraFxController,
    AdminLevelTickerController,
    AdminGlobalStripsController,
  ],
  providers: [SiteSettingsService],
  exports: [SiteSettingsService],
})
export class SiteSettingsModule {}
