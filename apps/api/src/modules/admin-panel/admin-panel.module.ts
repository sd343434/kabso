import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { EconomyModule } from '../economy/economy.module.js';
import { LiveModule } from '../live/live.module.js';
import { TopupModule } from '../topup/topup.module.js';
import { MediaModule } from '../media/media.module.js';
import { RechargeModule } from '../recharge/recharge.module.js';
import { VipModule } from '../vip/vip.module.js';
import { RechargePointsModule } from '../recharge-points/recharge-points.module.js';
import { StoreModule } from '../store/store.module.js';
import { MedalsModule } from '../medals/medals.module.js';
import { SafetyModule } from '../safety/safety.module.js';
import { PostsModule } from '../posts/posts.module.js';
import { PublicProfileModule } from '../users/profiles/public-profile.module.js';
import { AdminAuthService } from './admin-auth.service.js';
import { StaffReportActionsService } from './staff-report-actions.service.js';
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
import { AdminGiftEventsService } from './admin-gift-events.service.js';
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
import { AdminStoreController } from './admin-store.controller.js';
import { AdminMedalsController } from './admin-medals.controller.js';
import { AdminIapController } from './admin-iap.controller.js';
import { AdminIapService } from './admin-iap.service.js';
import { IapModule } from '../store-iap/iap.module.js';
import { AdminOpsController } from './admin-ops.controller.js';
import { AdminRoleHomesService } from './admin-role-homes.service.js';
import { StaffCompensationsService } from './staff-compensations.service.js';
import { StaffScheduleService } from './staff-schedule.service.js';

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
import { StaffAppController, StaffTeamAvatarController } from './staff-app.controller.js';
import { StaffAppGuard } from './staff-app.guard.js';
import { StaffAppService } from './staff-app.service.js';
import { OwnerModerationController, OwnerModerationService } from './owner-moderation.service.js';

@Module({
  imports: [
    // v1.110-social (D345): «مشتريات المتجر».
    IapModule,
    AuthModule,
    MediaModule,
    SafetyModule,
    // v1.93-social (D296): a reported post as the staff see it.
    PostsModule,
    PublicProfileModule,
    EconomyModule,
    LiveModule,
    TopupModule,
    RechargeModule,
    // v1.82-social (D252): «VIP».
    VipModule,
    // v1.126-social (D370): «نقاط الشحن» — the user page's balance, ledger and adjustment.
    RechargePointsModule,
    StoreModule,
    // v1.81-live (D291): the medals' levels.
    MedalsModule,
  ],
  controllers: [
    AdminIapController,
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
    AdminStoreController,
    AdminMedalsController,
    // v1.68-live (D273, §10.96.6): «أدوات فريق كابسو» in the app.
    StaffTeamAvatarController,
    StaffAppController,
    // v1.99-social (D311, §10.117): «إجراءات المؤسس» — the app owner's moderation actions in the app.
    OwnerModerationController,
    // v1.139-social (D387, §10.176): the operations roles — homes, the shift schedule, compensations.
    AdminOpsController,
  ],
  providers: [
    AdminIapService,
    AdminAuthService,
    StaffReportActionsService,
    OwnerModerationService,
    AdminSessionGuard,
    AdminUsersService,
    AdminFinanceService,
    AdminModerationService,
    AdminStatsService,
    AdminPeopleService,
    AdminAgenciesService,
    AdminLivesService,
    AdminCatalogService,
    AdminGiftEventsService,
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
    // v1.68-live (D273): the staff tools in the app.
    StaffAppService,
    StaffAppGuard,
    // v1.139-social (D387, §10.176).
    StaffScheduleService,
    StaffCompensationsService,
    AdminRoleHomesService,
  ],
  exports: [AdminAuthService, AdminSessionGuard],
})
export class AdminPanelModule {}
