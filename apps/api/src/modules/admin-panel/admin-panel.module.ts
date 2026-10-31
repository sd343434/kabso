import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { MediaModule } from '../media/media.module.js';
import { SafetyModule } from '../safety/safety.module.js';
import { PublicProfileModule } from '../users/profiles/public-profile.module.js';
import { AdminAuthService } from './admin-auth.service.js';
import { AdminFinanceService } from './admin-finance.service.js';
import { AdminModerationService } from './admin-moderation.service.js';
import {
  AdminAuthController,
  AdminFinanceController,
  AdminModerationController,
  AdminUsersController,
} from './admin-panel.controller.js';
import { AdminSessionGuard } from './admin-session.guard.js';
import { AdminUsersService } from './admin-users.service.js';

/**
 * v1.60-social (D191, CONVENTIONS §10.54): the admin panel «لوحة الإدارة» API behind its own cookie session with a
 * mandatory TOTP second factor. Owns `admin_credentials`, `admin_recovery_codes` and `admin_sessions`; reads the
 * other modules' tables for its views and changes them only through their shared rules (recharge-core,
 * withdrawal-admin, avatar-admin, special-usernames, AccountLifecycleService, SafetyService).
 */
@Module({
  imports: [AuthModule, MediaModule, SafetyModule, PublicProfileModule],
  controllers: [AdminAuthController, AdminUsersController, AdminFinanceController, AdminModerationController],
  providers: [
    AdminAuthService,
    AdminSessionGuard,
    AdminUsersService,
    AdminFinanceService,
    AdminModerationService,
  ],
  exports: [AdminAuthService, AdminSessionGuard],
})
export class AdminPanelModule {}
