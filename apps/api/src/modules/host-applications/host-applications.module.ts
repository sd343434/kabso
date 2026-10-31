import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { HostApplicationsController } from './host-applications.controller.js';
import { HostApplicationsService } from './host-applications.service.js';

/**
 * «كن مضيفاً مع الإدارة» (v1.73-social, D209, CONVENTIONS §10.68): the person's application to host directly with
 * the Kabso team. The team's decisions (`host-applications.core.ts`) are run by the admin panel and `host-admin`.
 */
@Module({
  imports: [MediaModule],
  controllers: [HostApplicationsController],
  providers: [HostApplicationsService],
})
export class HostApplicationsModule {}
