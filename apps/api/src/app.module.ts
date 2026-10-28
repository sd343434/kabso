import { Module, type DynamicModule } from '@nestjs/common';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { LoggerModule } from 'nestjs-pino';
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
import { LiveModule } from './modules/live/live.module.js';
import { SocialModule } from './modules/social/social.module.js';
import { PublicProfileModule } from './modules/users/profiles/public-profile.module.js';
import { UsersModule } from './modules/users/users.module.js';
import { PremiumUsernamesModule } from './modules/premium-usernames/premium-usernames.module.js';
import { WalletModule } from './modules/wallet/wallet.module.js';
import { CouplesModule } from './modules/couples/couples.module.js';
import { FamiliesModule } from './modules/families/families.module.js';
import { MedalsModule } from './modules/medals/medals.module.js';
import { BagModule } from './modules/bag/bag.module.js';
import { GiftsModule } from './modules/gifts/gifts.module.js';
import { CpSpaceModule } from './modules/cp-space/cp-space.module.js';
import { HomeModule } from './modules/home/home.module.js';
import { ClockModule } from './common/time/clock.js';
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
        MediaModule,
        PostsModule,
        SafetyModule,
        StoriesModule,
        NotificationsModule,
        // v1.30-live (DRAFT, D152): push notifications (PUT/DELETE /me/push-token).
        PushModule,
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
      ],
      providers: [
        { provide: APP_FILTER, useClass: AllExceptionsFilter },
        // Order matters: authentication first, then rate limiting (which may key on the user).
        { provide: APP_GUARD, useExisting: AccessTokenGuard },
        { provide: APP_GUARD, useExisting: RateLimitGuard },
      ],
    };
  }
}
