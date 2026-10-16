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
import { UsersModule } from './modules/users/users.module.js';
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
        UsersModule,
        AuthModule,
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
