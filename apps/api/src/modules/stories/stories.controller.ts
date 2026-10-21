import { Body, Controller, Delete, Get, Headers, HttpCode, Param, Post, Put, Query } from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import type { PageDto } from '../posts/post-views.js';
import { pageQuerySchema, type PageQuery } from '../posts/posts.schemas.js';
import { StoriesService, type StoryDto, type StoryTrayItemDto } from './stories.service.js';

const idempotencyKeySchema = z.uuid();

/** Photo stories (contract v1.5-social draft, CP-008, CONVENTIONS §11.9). Every route needs a token. */
@Controller()
export class StoriesController {
  constructor(private readonly stories: StoriesService) {}

  @Post('stories')
  @HttpCode(201)
  @RateLimit({ bucket: 'stories:create', rule: 'storyCreateUser', key: byUserId, replacesDefault: true })
  create(
    @CurrentAuth() auth: AuthContext,
    @Headers('idempotency-key') rawKey: string | undefined,
    @Body() body: unknown,
  ): Promise<StoryDto> {
    if (rawKey === undefined || rawKey === '') {
      throw AppException.validation([{ field: 'Idempotency-Key', issue: 'required' }]);
    }
    const key = idempotencyKeySchema.safeParse(rawKey);
    if (!key.success) throw AppException.validation([{ field: 'Idempotency-Key', issue: 'invalid_format' }]);
    return this.stories.create(auth.userId, key.data, body);
  }

  @Get('stories/:storyId')
  get(@CurrentAuth() auth: AuthContext, @Param('storyId') storyId: string): Promise<StoryDto> {
    return this.stories.get(auth.userId, storyId);
  }

  @Delete('stories/:storyId')
  @HttpCode(204)
  async delete(@CurrentAuth() auth: AuthContext, @Param('storyId') storyId: string): Promise<void> {
    await this.stories.delete(auth.userId, storyId);
  }

  @Get('feed/stories')
  @RateLimit({ bucket: 'stories:tray', rule: 'feedUser', key: byUserId, replacesDefault: true })
  tray(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<StoryTrayItemDto>> {
    return this.stories.tray(auth.userId, query);
  }

  @Get('users/:username/stories')
  userStories(
    @CurrentAuth() auth: AuthContext,
    @Param('username') username: string,
  ): Promise<{ data: StoryDto[] }> {
    return this.stories.userStories(auth.userId, username);
  }

  @Put('stories/:storyId/seen')
  @HttpCode(204)
  @RateLimit({ bucket: 'stories:seen', rule: 'storySeenUser', key: byUserId, replacesDefault: true })
  async seen(@CurrentAuth() auth: AuthContext, @Param('storyId') storyId: string): Promise<void> {
    await this.stories.markSeen(auth.userId, storyId);
  }

  @Get('stories/:storyId/viewers')
  viewers(
    @CurrentAuth() auth: AuthContext,
    @Param('storyId') storyId: string,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<UserSummaryDto>> {
    return this.stories.viewers(auth.userId, storyId, query);
  }

  @Get('me/stories/archive')
  archive(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<StoryDto>> {
    return this.stories.archive(auth.userId, query);
  }
}
