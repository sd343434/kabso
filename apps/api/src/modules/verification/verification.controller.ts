import { Body, Controller, Get, Module, Put, UseGuards } from '@nestjs/common';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { AdminAuthService, type AdminContext } from '../admin-panel/admin-auth.service.js';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import { viaOf } from '../admin-panel/admin-users.service.js';
import { Public } from '../auth/public.decorator.js';
import {
  VerificationBadgeSweeper,
  VerificationService,
  verificationSettingsBody,
  type AdminVerificationSettingsDto,
  type VerificationSettingsBody,
} from './verification.service.js';

/**
 * «شارات التوثيق» in the panel (v1.90-social, D293, CONVENTIONS §10.105): `verification.view` reads the thresholds,
 * their defaults, the last recompute and the holders per badge; `verification.settings` (OWNER) changes the
 * thresholds with a reason and the authenticator code again, audited `verification.settings.update`, and every badge
 * is recomputed in the same transaction. Every write also needs the CSRF header (the guard).
 */
@Public()
@Controller('admin/verification-badges')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminVerificationController {
  constructor(
    private readonly verification: VerificationService,
    private readonly auth: AdminAuthService,
  ) {}

  @Get('settings')
  @RequireCapability('verification.view')
  settings(): Promise<AdminVerificationSettingsDto> {
    return this.verification.settingsView();
  }

  @Put('settings')
  @RequireCapability('verification.settings')
  async update(
    @Body(new ZodValidationPipe(verificationSettingsBody)) body: VerificationSettingsBody,
    @CurrentAdmin() admin: AdminContext,
  ): Promise<AdminVerificationSettingsDto> {
    await this.auth.reauthenticate(admin, body.totpCode);
    return this.verification.updateSettings(body, viaOf(admin));
  }
}

/** v1.90-social (D293): automatic verification badges «شارة التوثيق». */
@Module({
  imports: [AdminPanelModule],
  controllers: [AdminVerificationController],
  providers: [VerificationService, VerificationBadgeSweeper],
  exports: [VerificationService],
})
export class VerificationModule {}
