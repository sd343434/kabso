import { Controller, Delete, Get, HttpCode, Param, Put, Query } from '@nestjs/common';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit, type RateLimitSpec } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { PageDto } from '../posts/post-views.js';
import { pageQuerySchema, type PageQuery } from '../posts/posts.schemas.js';
import { FollowListsService, type FollowListItemDto } from './follow-lists.service.js';
import { FollowsService, type FollowStateDto } from './follows.service.js';

/**
 * CONVENTIONS §7/§10.6: follow and unfollow share one bucket pair per user (60 / hour,
 * 300 / day); idempotent no-op calls count too (anti follow/unfollow churn). Rejections are logged.
 */
const FOLLOW_LIMITS: RateLimitSpec[] = [
  { bucket: 'follow:h', rule: 'followHourUser', key: byUserId, replacesDefault: true, logRejections: true },
  { bucket: 'follow:d', rule: 'followDayUser', key: byUserId, replacesDefault: true, logRejections: true },
];

/** D121: the follow lists count against the profile-scraping bucket (300 / 15 min per user). */
const PROFILE_READ_LIMIT: RateLimitSpec = {
  bucket: 'users:profile',
  rule: 'profileUser',
  key: byUserId,
  replacesDefault: true,
};

@Controller('users')
export class FollowsController {
  constructor(
    private readonly follows: FollowsService,
    private readonly lists: FollowListsService,
  ) {}

  /** D121: who follows the user, newest first. Shares the `GET /users/{username}` bucket (§7). */
  @Get(':username/followers')
  @RateLimit(PROFILE_READ_LIMIT)
  followers(
    @CurrentAuth() auth: AuthContext,
    @Param('username') username: string,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<FollowListItemDto>> {
    return this.lists.list(auth.userId, username, 'followers', query);
  }

  /** D121: whom the user follows, newest first. Shares the `GET /users/{username}` bucket (§7). */
  @Get(':username/following')
  @RateLimit(PROFILE_READ_LIMIT)
  following(
    @CurrentAuth() auth: AuthContext,
    @Param('username') username: string,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<FollowListItemDto>> {
    return this.lists.list(auth.userId, username, 'following', query);
  }

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
