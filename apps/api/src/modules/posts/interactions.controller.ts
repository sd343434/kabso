import { Body, Controller, Delete, Get, HttpCode, Param, Post, Put, Query } from '@nestjs/common';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { FeedService } from './feed.service.js';
import { PostInteractionsService, type LikeStateDto } from './post-interactions.service.js';
import type { PageDto, PostDto } from './post-views.js';
import { feedQuerySchema, pageQuerySchema, type FeedQuery, type PageQuery } from './posts.schemas.js';

const LIKE_LIMIT = { bucket: 'social:like', rule: 'likeUser', key: byUserId, replacesDefault: true } as const;
const REPOST_LIMIT = {
  bucket: 'social:repost',
  rule: 'repostUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** Feeds and post interactions (contract v1.5-social draft, CONVENTIONS §11.2–§11.4). */
@Controller()
export class InteractionsController {
  constructor(
    private readonly interactions: PostInteractionsService,
    private readonly feeds: FeedService,
  ) {}

  @Get('feed/posts')
  @RateLimit({ bucket: 'social:feed', rule: 'feedUser', key: byUserId, replacesDefault: true })
  feed(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(feedQuerySchema)) query: FeedQuery,
  ): Promise<PageDto<PostDto>> {
    return this.feeds.feed(auth.userId, query, 'POST');
  }

  /** v1.41-social (D162): reels for Moments (CONVENTIONS §11.14); the `social:feed` bucket. */
  @Get('feed/reels')
  @RateLimit({ bucket: 'social:feed', rule: 'feedUser', key: byUserId, replacesDefault: true })
  reels(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(feedQuerySchema)) query: FeedQuery,
  ): Promise<PageDto<PostDto>> {
    return this.feeds.feed(auth.userId, query, 'REEL');
  }

  @Put('posts/:postId/like')
  @HttpCode(200)
  @RateLimit(LIKE_LIMIT)
  like(@CurrentAuth() auth: AuthContext, @Param('postId') postId: string): Promise<LikeStateDto> {
    return this.interactions.like(auth.userId, postId, true);
  }

  @Delete('posts/:postId/like')
  @HttpCode(200)
  @RateLimit(LIKE_LIMIT)
  unlike(@CurrentAuth() auth: AuthContext, @Param('postId') postId: string): Promise<LikeStateDto> {
    return this.interactions.like(auth.userId, postId, false);
  }

  @Get('posts/:postId/likes')
  likers(
    @CurrentAuth() auth: AuthContext,
    @Param('postId') postId: string,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<UserSummaryDto>> {
    return this.interactions.likers(auth.userId, postId, query);
  }

  @Put('posts/:postId/save')
  @HttpCode(200)
  save(@CurrentAuth() auth: AuthContext, @Param('postId') postId: string): Promise<{ saved: boolean }> {
    return this.interactions.save(auth.userId, postId, true);
  }

  @Delete('posts/:postId/save')
  @HttpCode(200)
  unsave(@CurrentAuth() auth: AuthContext, @Param('postId') postId: string): Promise<{ saved: boolean }> {
    return this.interactions.save(auth.userId, postId, false);
  }

  @Get('me/saved')
  saved(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<PostDto>> {
    return this.feeds.saved(auth.userId, query);
  }

  @Put('posts/:postId/repost')
  @HttpCode(200)
  @RateLimit(REPOST_LIMIT)
  repost(
    @CurrentAuth() auth: AuthContext,
    @Param('postId') postId: string,
  ): Promise<{ reposted: boolean; repostCount: number }> {
    return this.interactions.repost(auth.userId, postId, true);
  }

  @Delete('posts/:postId/repost')
  @HttpCode(200)
  @RateLimit(REPOST_LIMIT)
  unrepost(
    @CurrentAuth() auth: AuthContext,
    @Param('postId') postId: string,
  ): Promise<{ reposted: boolean; repostCount: number }> {
    return this.interactions.repost(auth.userId, postId, false);
  }

  @Get('users/:username/reposts')
  @RateLimit({ bucket: 'users:profile', rule: 'profileUser', key: byUserId, replacesDefault: true })
  userReposts(
    @CurrentAuth() auth: AuthContext,
    @Param('username') username: string,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<PostDto>> {
    return this.feeds.userReposts(auth.userId, username, query);
  }

  @Post('posts/:postId/shares')
  @HttpCode(200)
  @RateLimit({ bucket: 'social:share', rule: 'shareUser', key: byUserId, replacesDefault: true })
  share(@CurrentAuth() auth: AuthContext, @Param('postId') postId: string): Promise<{ shareCount: number }> {
    return this.interactions.share(auth.userId, postId);
  }

  @Post('views')
  @HttpCode(204)
  @RateLimit({ bucket: 'social:views', rule: 'viewsUser', key: byUserId, replacesDefault: true })
  async views(@CurrentAuth() auth: AuthContext, @Body() body: unknown): Promise<void> {
    await this.interactions.recordViews(auth.userId, body);
  }
}
