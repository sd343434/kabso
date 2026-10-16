import { Inject, Injectable, Logger, type OnApplicationShutdown, type OnModuleInit } from '@nestjs/common';
import { PrismaPg } from '@prisma/adapter-pg';
import { APP_CONFIG, type AppConfig } from '../config/app-config.js';
import { PrismaClient } from '../generated/prisma/client.js';
import { checkRuntimeRole, type RuntimeRoleFacts } from './runtime-role-check.js';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnApplicationShutdown {
  private readonly logger = new Logger('Database');
  private readonly enforceRuntimeRole: boolean;

  constructor(@Inject(APP_CONFIG) config: AppConfig) {
    super({
      adapter: new PrismaPg({
        connectionString: config.databaseUrl,
        max: 10,
        connectionTimeoutMillis: 5000,
        idleTimeoutMillis: 30_000,
      }),
    });
    this.enforceRuntimeRole = config.isProduction;
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
    try {
      // SEC-011: refuse (production) or warn (elsewhere) when DATABASE_URL is not the DML-only
      // runtime role.
      await checkRuntimeRole((sql) => this.$queryRawUnsafe<RuntimeRoleFacts[]>(sql), {
        enforce: this.enforceRuntimeRole,
        logger: this.logger,
      });
    } catch (err) {
      await this.$disconnect();
      throw err;
    }
  }

  /** In onApplicationShutdown (not onModuleDestroy) so background tasks can drain first. */
  async onApplicationShutdown(): Promise<void> {
    await this.$disconnect();
  }
}
