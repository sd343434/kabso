import { Body, Controller, Get, HttpCode, Param, Post, Query } from '@nestjs/common';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { PageDto, PostDto } from './post-views.js';
import {
  hashtagPostsQuerySchema,
  recordSearchQuerySchema,
  searchQuerySchema,
  trendingHashtagsQuerySchema,
  type HashtagPostsQuery,
  type RecordSearchQuery,
  type SearchQuery,
  type TrendingHashtagsQuery,
} from './posts.schemas.js';
import { SearchService, type HashtagDto, type SearchPageDto } from './search.service.js';
import { SearchTrendsService, type TrendingSearchDto } from './search-trends.service.js';

/**
 * Hashtag pages and search (contract v1.5-social draft, CONVENTIONS §11.6); search trends
 * (v1.29-live draft, D147, §11.11).
 */
@Controller()
export class SearchController {
  constructor(
    private readonly search: SearchService,
    private readonly trends: SearchTrendsService,
  ) {}

  /** D147: the terms people search most (global, cached 60 s). Per-user default rate limit. */
  @Get('search/trending')
  trending(): Promise<{ data: TrendingSearchDto[] }> {
    return this.trends.trending();
  }

  /** D147: the hashtags of the week the caller can see. Per-user default rate limit. */
  @Get('search/trending-hashtags')
  trendingHashtags(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(trendingHashtagsQuerySchema)) query: TrendingHashtagsQuery,
  ): Promise<{ data: HashtagDto[] }> {
    return this.trends.trendingHashtags(auth.userId, query.limit);
  }

  /** D147: a search the caller submitted, counted for trends (no user id stored with it). */
  @Post('search/queries')
  @HttpCode(204)
  @RateLimit({ bucket: 'search:record', rule: 'searchRecordUser', key: byUserId, replacesDefault: true })
  async recordQuery(
    @CurrentAuth() auth: AuthContext,
    @Body(new ZodValidationPipe(recordSearchQuerySchema)) body: RecordSearchQuery,
  ): Promise<void> {
    await this.trends.record(auth.userId, body.q);
  }

  @Get('hashtags/:tag')
  hashtag(@CurrentAuth() auth: AuthContext, @Param('tag') tag: string): Promise<HashtagDto> {
    return this.search.hashtag(auth.userId, tag);
  }

  @Get('hashtags/:tag/posts')
  hashtagPosts(
    @CurrentAuth() auth: AuthContext,
    @Param('tag') tag: string,
    @Query(new ZodValidationPipe(hashtagPostsQuerySchema)) query: HashtagPostsQuery,
  ): Promise<PageDto<PostDto>> {
    return this.search.hashtagPosts(auth.userId, tag, query);
  }

  @Get('search')
  @RateLimit({ bucket: 'social:search', rule: 'searchUser', key: byUserId, replacesDefault: true })
  find(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(searchQuerySchema)) query: SearchQuery,
  ): Promise<SearchPageDto> {
    return this.search.search(auth.userId, query);
  }
}
