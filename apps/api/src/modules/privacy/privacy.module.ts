import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { MediaModule } from '../media/media.module.js';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { ConsentGuard, ConsentsService } from './consents.service.js';
import { DataExportsService, DataExportSweeper } from './data-exports.service.js';
import { ConsentsController, DataExportsController, LegalController } from './privacy.controller.js';

/**
 * v1.66-social (DRAFT, D198, CONVENTIONS §10.61): privacy — versioned legal documents and consents (with the 428
 * gate, `ConsentGuard`, registered as a global guard in AppModule) and the personal-data export «تنزيل بياناتي».
 */
@Module({
  imports: [AuthModule, MediaModule, NotificationsModule],
  controllers: [LegalController, ConsentsController, DataExportsController],
  providers: [ConsentsService, ConsentGuard, DataExportsService, DataExportSweeper],
  exports: [ConsentGuard, ConsentsService, DataExportsService],
})
export class PrivacyModule {}
