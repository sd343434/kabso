import { Module } from '@nestjs/common';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import { AdminSiteSettingsController, SiteSettingsController } from './site-settings.controller.js';
import { SiteSettingsService } from './site-settings.service.js';

/**
 * v1.60-social (D191/D192, CONVENTIONS §10.54.6): the public website's settings — owns `site_settings`. Public read
 * `GET /site/settings`; the OWNER's `PUT /admin/site-settings` behind the panel session.
 */
@Module({
  imports: [AdminPanelModule],
  controllers: [SiteSettingsController, AdminSiteSettingsController],
  providers: [SiteSettingsService],
  exports: [SiteSettingsService],
})
export class SiteSettingsModule {}
