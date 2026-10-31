import { Module } from '@nestjs/common';
import { AdminGuard, AdminPermissions } from '../levels/admin.guard.js';
import { AdminSiteSettingsController, SiteSettingsController } from './site-settings.controller.js';
import { SiteSettingsService } from './site-settings.service.js';

/**
 * D192 (v1.61-social draft, CONVENTIONS §10.55): the public website's settings. Owns `site_settings`; written only
 * by `PUT /admin/site-settings` (D191's admin panel is the UI). Exported so the admin side can reuse the service.
 */
@Module({
  controllers: [SiteSettingsController, AdminSiteSettingsController],
  providers: [SiteSettingsService, AdminGuard, AdminPermissions],
  exports: [SiteSettingsService],
})
export class SiteSettingsModule {}
