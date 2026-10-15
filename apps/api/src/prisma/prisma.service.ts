import { Inject, Injectable, type OnApplicationShutdown, type OnModuleInit } from '@nestjs/common';
import { PrismaPg } from '@prisma/adapter-pg';
import { APP_CONFIG, type AppConfig } from '../config/app-config.js';
import { PrismaClient } from '../generated/prisma/client.js';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnApplicationShutdown {
  constructor(@Inject(APP_CONFIG) config: AppConfig) {
    super({
      adapter: new PrismaPg({
        connectionString: config.databaseUrl,
        max: 10,
        connectionTimeoutMillis: 5000,
        idleTimeoutMillis: 30_000,
      }),
    });
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
  }

  /** In onApplicationShutdown (not onModuleDestroy) so background tasks can drain first. */
  async onApplicationShutdown(): Promise<void> {
    await this.$disconnect();
  }
}
