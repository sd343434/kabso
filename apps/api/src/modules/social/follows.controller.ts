import { Controller, Delete, HttpCode, Param, Put } from '@nestjs/common';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit, type RateLimitSpec } from '../../common/rate-limit/rate-limit.decorator.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { FollowsService, type FollowStateDto } from './follows.service.js';

/**
 * CONVENTIONS §7/§10.6: follow and unfollow share one bucket pair per user (60 / hour,
 * 300 / day); idempotent no-op calls count too (anti follow/unfollow churn). Rejections are logged.
 */
const FOLLOW_LIMITS: RateLimitSpec[] = [
  { bucket: 'follow:h', rule: 'followHourUser', key: byUserId, replacesDefault: true, logRejections: true },
  { bucket: 'follow:d', rule: 'followDayUser', key: byUserId, replacesDefault: true, logRejections: true },
];

@Controller('users')
export class FollowsController {
  constructor(private readonly follows: FollowsService) {}

  @Put(':username/follow')
  @HttpCode(200)
  @RateLimit(...FOLLOW_LIMITS)
  follow(@CurrentAuth() auth: AuthContext, @Param('username') username: string): Promise<FollowStateDto> {
    return this.follows.follow(auth.userId, username);
  }

  @Delete(':username/follow')
  @HttpCode(200)
  @RateLimit(...FOLLOW_LIMITS)
  unfollow(@CurrentAuth() auth: AuthContext, @Param('username') username: string): Promise<FollowStateDto> {
    return this.follows.unfollow(auth.userId, username);
  }
}
