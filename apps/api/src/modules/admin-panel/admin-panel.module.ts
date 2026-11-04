import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { EconomyModule } from '../economy/economy.module.js';
import { LiveModule } from '../live/live.module.js';
import { TopupModule } from '../topup/topup.module.js';
import { MediaModule } from '../media/media.module.js';
import { RechargeModule } from '../recharge/recharge.module.js';
import { VipModule } from '../vip/vip.module.js';
import { SafetyModule } from '../safety/safety.module.js';
import { PublicProfileModule } from '../users/profiles/public-profile.module.js';
import { AdminAuthService } from './admin-auth.service.js';
import { AdminFinanceService } from './admin-finance.service.js';
import { AdminModerationService } from './admin-moderation.service.js';
import {
  AdminAuthController,
  AdminFinanceController,
  AdminModerationController,
  AdminRechargeOrdersController,
  AdminUsersController,
} from './admin-panel.controller.js';
import { AdminOrdersService } from './admin-orders.service.js';
import { AdminSessionGuard } from './admin-session.guard.js';
import { AdminUsersService } from './admin-users.service.js';
import { AdminAgenciesService } from './admin-agencies.service.js';
import { AdminCatalogService } from './admin-catalog.service.js';
import { AdminLiveModerationController } from './admin-live-moderation.controller.js';
import { AdminLiveModerationService } from './admin-live-moderation.service.js';
import { AdminStaffShiftsService } from './admin-staff-shifts.service.js';
import { AdminLivesService } from './admin-lives.service.js';
import { AdminMoneyService } from './admin-money.service.js';
import { AdminPeopleService } from './admin-people.service.js';
import { AdminProgramsService } from './admin-programs.service.js';
import { AdminStatsService } from './admin-stats.service.js';
import { AdminTeamService } from './admin-team.service.js';
import { AdminV2Controller } from './admin-v2.controller.js';
import { AdminLiveBoostsController } from './admin-live-boosts.controller.js';
import { AdminControlController } from './admin-control.controller.js';
import { AdminControlService } from './admin-control.service.js';
import { AdminHostApplicationsController } from './admin-host-applications.controller.js';
import { AdminHostApplicationsService } from './admin-host-applications.service.js';
import { AdminDeviceSignupsController } from './admin-device-signups.controller.js';
import { AdminDeviceSignupsService } from './admin-device-signups.service.js';
import { AdminVipController } from './admin-vip.controller.js';

/**
 * v1.60-social (D191, CONVENTIONS §10.54): the admin panel «لوحة الإدارة» API behind its own cookie session with a
 * mandatory TOTP second factor. Owns `admin_credentials`, `admin_recovery_codes` and `admin_sessions`; reads the
 * other modules' tables for its views and changes them only through their shared rules (recharge-core,
 * withdrawal-admin, avatar-admin, special-usernames, AccountLifecycleService, SafetyService).
 *
 * v1.65-social (D197, CONVENTIONS §10.60): the panel v2 — statistics, search, tables with CSV, agencies, lives,
 * gifts and items, money, the audit log and the team, programs — again only through the CLIs' rules (agency-admin,
 * host-agents, gift-admin-rules, bag-admin-rules, home-banners, event-admin-rules, topup-core, admin-roles,
 * waitlist-admin, LiveRoomsService / LiveMediaService, SessionsService).
 */
@Module({
  imports: [
    AuthModule,
    MediaModule,
    SafetyModule,
    PublicProfileModule,
    EconomyModule,
    LiveModule,
    TopupModule,
    RechargeModule,
    // v1.82-social (D252): «VIP».
    VipModule,
  ],
  controllers: [
    AdminAuthController,
    AdminUsersController,
    AdminFinanceController,
    AdminModerationController,
    AdminV2Controller,
    // v1.51-live (D233): «صواريخ الزيارات».
    AdminLiveBoostsController,
    AdminRechargeOrdersController,
    // v1.72-social (D208, §10.67): the account controls.
    AdminControlController,
    // v1.73-social (D209, §10.68): «طلبات المضيفين».
    AdminHostApplicationsController,
    // v1.78-social (D223, §10.75): the accounts made on a device, and its exception.
    AdminDeviceSignupsController,
    // v1.60-live (D250, §10.91): live moderation «مراقبة البث».
    AdminLiveModerationController,
    // v1.82-social (D252, §10.93.4): «VIP».
    AdminVipController,
  ],
  providers: [
    AdminAuthService,
    AdminSessionGuard,
    AdminUsersService,
    AdminFinanceService,
    AdminModerationService,
    AdminStatsService,
    AdminPeopleService,
    AdminAgenciesService,
    AdminLivesService,
    AdminCatalogService,
    AdminMoneyService,
    AdminTeamService,
    AdminProgramsService,
    AdminOrdersService,
    AdminControlService,
    AdminHostApplicationsService,
    AdminDeviceSignupsService,
    AdminLiveModerationService,
    // v1.64-live (D260): the shift «في المناوبة» and who is on it (§10.96).
    AdminStaffShiftsService,
  ],
  exports: [AdminAuthService, AdminSessionGuard],
})
export class AdminPanelModule {}
