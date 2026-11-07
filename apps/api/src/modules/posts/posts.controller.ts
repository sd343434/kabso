import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Req,
} from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { clientIp, type AppRequest, type AuthContext } from '../../common/http/request-context.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { PageDto, PostDto } from './post-views.js';
import { myPostsQuerySchema, pageQuerySchema, type MyPostsQuery, type PageQuery } from './posts.schemas.js';
import { PostsService } from './posts.service.js';

const idempotencyKeySchema = z.uuid();

/** Posts (contract v1.5-social draft, CONVENTIONS §11.2). Every route needs a token. */
@Controller()
export class PostsController {
  constructor(private readonly posts: PostsService) {}

  @Post('posts')
  @HttpCode(201)
  @RateLimit(
    { bucket: 'posts:create:h', rule: 'postCreateHourUser', key: byUserId, replacesDefault: true },
    { bucket: 'posts:create:d', rule: 'postCreateDayUser', key: byUserId, replacesDefault: true },
  )
  create(
    @CurrentAuth() auth: AuthContext,
    @Headers('idempotency-key') rawKey: string | undefined,
    @Body() body: unknown,
  ): Promise<PostDto> {
    if (rawKey === undefined || rawKey === '') {
      throw AppException.validation([{ field: 'Idempotency-Key', issue: 'required' }]);
    }
    const key = idempotencyKeySchema.safeParse(rawKey);
    if (!key.success) throw AppException.validation([{ field: 'Idempotency-Key', issue: 'invalid_format' }]);
    return this.posts.create(auth.userId, key.data, body);
  }

  @Get('posts/:postId')
  get(@CurrentAuth() auth: AuthContext, @Param('postId') postId: string): Promise<PostDto> {
    return this.posts.get(auth.userId, postId);
  }

  @Patch('posts/:postId')
  update(
    @CurrentAuth() auth: AuthContext,
    @Param('postId') postId: string,
    @Body() body: unknown,
  ): Promise<PostDto> {
    return this.posts.update(auth.userId, postId, body);
  }

  @Delete('posts/:postId')
  @HttpCode(204)
  async delete(@CurrentAuth() auth: AuthContext, @Param('postId') postId: string): Promise<void> {
    await this.posts.delete(auth.userId, postId);
  }

  @Get('me/posts')
  listMine(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(myPostsQuerySchema)) query: MyPostsQuery,
  ): Promise<PageDto<PostDto>> {
    return this.posts.listMine(auth.userId, query);
  }

  @Put('posts/:postId/pin')
  @HttpCode(200)
  pin(@CurrentAuth() auth: AuthContext, @Param('postId') postId: string): Promise<PostDto> {
    return this.posts.pin(auth.userId, postId);
  }

  @Delete('posts/:postId/pin')
  @HttpCode(200)
  unpin(@CurrentAuth() auth: AuthContext, @Param('postId') postId: string): Promise<PostDto> {
    return this.posts.unpin(auth.userId, postId);
  }

  /** v1.95-social (D301, §10.112.2): «رسمي» — the app owner only (403 `OWNER_ONLY`). */
  @Put('posts/:postId/official')
  @HttpCode(200)
  official(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('postId') postId: string,
  ): Promise<PostDto> {
    return this.posts.setOfficial(auth.userId, postId, true, {
      ip: clientIp(req),
      requestId: getRequestId(req),
    });
  }

  @Delete('posts/:postId/official')
  @HttpCode(200)
  unofficial(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('postId') postId: string,
  ): Promise<PostDto> {
    return this.posts.setOfficial(auth.userId, postId, false, {
      ip: clientIp(req),
      requestId: getRequestId(req),
    });
  }

  /** v1.95-social (D301, §10.112.2): «إعلانات رسمية» — pinned first, then newest. */
  @Get('users/:username/official-posts')
  @RateLimit({ bucket: 'users:profile', rule: 'profileUser', key: byUserId, replacesDefault: true })
  listUserOfficialPosts(
    @CurrentAuth() auth: AuthContext,
    @Param('username') username: string,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<PostDto>> {
    return this.posts.listUserOfficialPosts(auth.userId, username, query);
  }

  @Get('users/:username/posts')
  @RateLimit({ bucket: 'users:profile', rule: 'profileUser', key: byUserId, replacesDefault: true })
  listUserPosts(
    @CurrentAuth() auth: AuthContext,
    @Param('username') username: string,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<PostDto>> {
    return this.posts.listUserPosts(auth.userId, username, query);
  }
}
