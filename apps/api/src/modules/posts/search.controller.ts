import { Controller, Get, Param, Query } from '@nestjs/common';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { PageDto, PostDto } from './post-views.js';
import {
  hashtagPostsQuerySchema,
  searchQuerySchema,
  type HashtagPostsQuery,
  type SearchQuery,
} from './posts.schemas.js';
import { SearchService, type HashtagDto, type SearchPageDto } from './search.service.js';

/** Hashtag pages and search (contract v1.5-social draft, CONVENTIONS §11.6). */
@Controller()
export class SearchController {
  constructor(private readonly search: SearchService) {}

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
