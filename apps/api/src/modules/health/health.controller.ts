import { Controller, Get, HttpCode, Inject, Res } from '@nestjs/common';
import type { Response } from 'express';
import type { Redis } from 'ioredis';
import { SkipRateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { REDIS } from '../../redis/redis.module.js';
import { Public } from '../auth/public.decorator.js';

type CheckStatus = 'ok' | 'down';

interface HealthStatus {
  status: 'ok' | 'degraded' | 'down';
  checks?: Record<string, CheckStatus>;
}

const CHECK_TIMEOUT_MS = 2000;

async function probe(fn: () => Promise<unknown>): Promise<CheckStatus> {
  let timer: NodeJS.Timeout | undefined;
  try {
    await Promise.race([
      fn(),
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error('timeout')), CHECK_TIMEOUT_MS);
      }),
    ]);
    return 'ok';
  } catch {
    return 'down';
  } finally {
    clearTimeout(timer);
  }
}

@Public()
@SkipRateLimit()
@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
  ) {}

  @Get('live')
  @HttpCode(200)
  live(): HealthStatus {
    return { status: 'ok' };
  }

  @Get('ready')
  async ready(@Res({ passthrough: true }) res: Response): Promise<HealthStatus> {
    const [database, redis] = await Promise.all([
      probe(() => this.prisma.$queryRaw`SELECT 1`),
      probe(() => this.redis.ping()),
    ]);
    const healthy = database === 'ok' && redis === 'ok';
    res.status(healthy ? 200 : 503);
    return { status: healthy ? 'ok' : 'down', checks: { database, redis } };
  }
}
