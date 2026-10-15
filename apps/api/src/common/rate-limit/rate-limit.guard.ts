import { Inject, Injectable, type CanActivate, type ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { clientIpBucket, type AppRequest } from '../http/request-context.js';
import { RATE_LIMITS_KEY, SKIP_RATE_LIMIT_KEY, type RateLimitSpec } from './rate-limit.decorator.js';
import { RateLimitService } from './rate-limit.service.js';

/**
 * Global rate-limit guard (runs after the auth guard):
 *  - routes with `@RateLimit(...)` get their specific limits;
 *  - every authenticated request also counts against the per-user default;
 *  - unauthenticated routes without specific limits count against the per-IP default.
 */
@Injectable()
export class RateLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly limiter: RateLimitService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // Deny-by-default for transports without a rate-limit strategy yet (SEC-013).
    if (context.getType() !== 'http') return false;
    const targets = [context.getHandler(), context.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(SKIP_RATE_LIMIT_KEY, targets)) return true;

    const req = context.switchToHttp().getRequest<AppRequest>();
    const specs =
      this.reflector.getAllAndOverride<RateLimitSpec[] | undefined>(RATE_LIMITS_KEY, targets) ?? [];

    for (const spec of specs) {
      await this.limiter.consume(spec.bucket, spec.key(req), this.config.rateLimits[spec.rule]);
    }

    if (req.auth) {
      await this.limiter.consume('user', req.auth.userId, this.config.rateLimits.authenticatedUser);
    } else if (specs.length === 0) {
      await this.limiter.consume('public:ip', clientIpBucket(req), this.config.rateLimits.publicIp);
    }
    return true;
  }
}
