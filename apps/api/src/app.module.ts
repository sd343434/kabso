import { Module, type DynamicModule } from '@nestjs/common';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { LoggerModule } from 'nestjs-pino';
import { AdminPanelModule } from './modules/admin-panel/admin-panel.module.js';
import { SiteSettingsModule } from './modules/site-settings/site-settings.module.js';
import {
  PaymentSettingsCoreModule,
  PaymentSettingsModule,
} from './modules/payment-settings/payment-settings.module.js';
import {
  StorageSettingsCoreModule,
  StorageSettingsModule,
} from './modules/storage-settings/storage-settings.module.js';
import { KycCoreModule, KycModule } from './modules/kyc/kyc.module.js';
import { FxCoreModule, FxModule } from './modules/fx/fx.module.js';
import { AuditModule } from './common/audit/audit.module.js';
import { BackgroundTasksModule } from './common/background/background-tasks.js';
import { AllExceptionsFilter } from './common/errors/all-exceptions.filter.js';
import { RateLimitGuard } from './common/rate-limit/rate-limit.guard.js';
import { RateLimitModule } from './common/rate-limit/rate-limit.module.js';
import type { AppConfig } from './config/app-config.js';
import { ConfigModule } from './config/config.module.js';
import { buildLoggerOptions } from './logging/logger.options.js';
import { AccessTokenGuard } from './modules/auth/access-token.guard.js';
import { AuthModule } from './modules/auth/auth.module.js';
import { HealthModule } from './modules/health/health.module.js';
import { MailModule } from './modules/mail/mail.module.js';
import { LevelsModule } from './modules/levels/levels.module.js';
import { MediaModule } from './modules/media/media.module.js';
import { PostsModule } from './modules/posts/posts.module.js';
import { SafetyModule } from './modules/safety/safety.module.js';
import { StoriesModule } from './modules/stories/stories.module.js';
import { NotificationsModule } from './modules/notifications/notifications.module.js';
import { PushModule } from './modules/push/push.module.js';
import { DmModule } from './modules/messages/dm.module.js';
import { LiveModule } from './modules/live/live.module.js';
import { SocialModule } from './modules/social/social.module.js';
import { PublicProfileModule } from './modules/users/profiles/public-profile.module.js';
import { UsersModule } from './modules/users/users.module.js';
import { PremiumUsernamesModule } from './modules/premium-usernames/premium-usernames.module.js';
import { WalletModule } from './modules/wallet/wallet.module.js';
import { CreatorModule } from './modules/creator/creator.module.js';
import { ProgramsModule } from './modules/programs/programs.module.js';
import { VipModule } from './modules/vip/vip.module.js';
import { StoreModule } from './modules/store/store.module.js';
import { EconomyModule } from './modules/economy/economy.module.js';
import { RechargeModule } from './modules/recharge/recharge.module.js';
import { TopupModule } from './modules/topup/topup.module.js';
import { CouplesModule } from './modules/couples/couples.module.js';
import { FamiliesModule } from './modules/families/families.module.js';
import { MedalsModule } from './modules/medals/medals.module.js';
import { BagModule } from './modules/bag/bag.module.js';
import { GiftsModule } from './modules/gifts/gifts.module.js';
import { CpSpaceModule } from './modules/cp-space/cp-space.module.js';
import { HomeModule } from './modules/home/home.module.js';
import { HostApplicationsModule } from './modules/host-applications/host-applications.module.js';
import { ReferralsModule } from './modules/referrals/referrals.module.js';
import { RecruitsModule } from './modules/recruits/recruits.controller.js';
import { LevelRaiseModule } from './modules/level-raise/level-raise.controller.js';
import { VerificationModule } from './modules/verification/verification.controller.js';
import { PkDaresAdminModule } from './modules/live/pk-dares/pk-dares-admin.module.js';
import { ProgramsAdminModule } from './modules/programs/admin-host-targets.controller.js';
import { WaitlistModule } from './modules/waitlist/waitlist.module.js';
import { ClockModule } from './common/time/clock.js';
import { ConsentGuard } from './modules/privacy/consents.service.js';
import { PrivacyModule } from './modules/privacy/privacy.module.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { RedisModule } from './redis/redis.module.js';

@Module({})
export class AppModule {
  static register(config: AppConfig): DynamicModule {
    return {
      module: AppModule,
      imports: [
        ConfigModule.forRoot(config),
        LoggerModule.forRoot(buildLoggerOptions(config)),
        PrismaModule,
        RedisModule,
        RateLimitModule,
        AuditModule,
        BackgroundTasksModule,
        MailModule,
        HealthModule,
        ClockModule,
        UsersModule,
        AuthModule,
        // v1.3. PublicProfileModule (GET users/:username) after UsersModule, so the static
        // users/username-availability route is registered first.
        LiveModule,
        SocialModule,
        // v1.4-levels (DRAFT, CP-005).
        LevelsModule,
        // v1.75-social (DRAFT, D222): the media storage from the panel «التخزين (R2 / S3)» (over the env S3_*).
        StorageSettingsCoreModule,
        // v1.80-kyc (DRAFT, D227): identity checks with Didit (the settings store, read by the applications).
        KycCoreModule,
        // v1.81-social (DRAFT, D245): automatic exchange rates (the resolver every price reads, and the poller).
        FxCoreModule,
        MediaModule,
        PostsModule,
        SafetyModule,
        StoriesModule,
        NotificationsModule,
        // v1.30-live (DRAFT, D152): push notifications (PUT/DELETE /me/push-token).
        PushModule,
        // v1.40-social (DRAFT, D155): direct messages.
        DmModule,
        PublicProfileModule,
        // v1.19-live (DRAFT, CP-017).
        WalletModule,
        // v1.28-live (D146): premium usernames and PUT /me/username.
        PremiumUsernamesModule,
        // v1.21-live (DRAFT, CP-018).
        FamiliesModule,
        CouplesModule,
        MedalsModule,
        // v1.22-live (DRAFT, CP-019).
        BagModule,
        GiftsModule,
        // v1.24-live (DRAFT, CP-021).
        CpSpaceModule,
        // v1.26-live (DRAFT, D124).
        HomeModule,
        // v1.43-social (DRAFT, D164): the Me hub's creator center.
        CreatorModule,
        // v1.44-social (DRAFT, D166): the Me hub's Task Center, Event Center and SVIP.
        ProgramsModule,
        // v1.82-social (DRAFT, D252): «شراء VIP».
        VipModule,
        StoreModule,
        // v1.52-social (DRAFT, D179): cherries, host agencies, commissions and withdrawals.
        EconomyModule,
        // v1.73-social (D209, §10.68): «كن مضيفاً مع الإدارة».
        HostApplicationsModule,
        // v1.74-social (D217): «دعوة الأصدقاء».
        ReferralsModule,
        RecruitsModule,
        // v1.89-social (D290, §10.103): level-raise requests «طلب رفع ليفيل».
        LevelRaiseModule,
        // v1.90-social (D293, §10.105): automatic verification badges «شارة التوثيق».
        VerificationModule,
        // v1.50-live (D229): «أحكام PK».
        PkDaresAdminModule,
        // v1.71-live (D281): «الأهداف الذكية» (OWNER only).
        ProgramsAdminModule,
        RechargeModule,
        // v1.59-social (DRAFT, D190): card top-ups on the website through Stripe; v1.64-social (DRAFT, D196): the
        // keys and options from the admin panel «الدفع (Stripe)» (over the env).
        PaymentSettingsCoreModule,
        TopupModule,
        // v1.60-social (DRAFT, D191): the admin panel and the public website's settings (one module, D191 + D192).
        AdminPanelModule,
        SiteSettingsModule,
        PaymentSettingsModule,
        StorageSettingsModule,
        // v1.80-kyc (DRAFT, D227): «تأكيد الهوية» (Didit), its webhook and the panel's «التحقق من الهوية (Didit)».
        KycModule,
        // v1.81-social (DRAFT, D245): «مزوّد أسعار الصرف», «تحديث الآن» and held values in the panel.
        FxModule,
        // v1.61-social (DRAFT, D192): the public website's waitlist.
        WaitlistModule,
        // v1.66-social (DRAFT, D198): privacy — legal documents, consents (the 428 gate) and the data export.
        PrivacyModule,
      ],
      providers: [
        { provide: APP_FILTER, useClass: AllExceptionsFilter },
        // Order matters: authentication first, then rate limiting (which may key on the user).
        { provide: APP_GUARD, useExisting: AccessTokenGuard },
        { provide: APP_GUARD, useExisting: RateLimitGuard },
        // v1.66-social (D198): 428 CONSENT_REQUIRED after authentication (and the rate limit).
        { provide: APP_GUARD, useExisting: ConsentGuard },
      ],
    };
  }
}
