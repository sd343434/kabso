import { Body, Controller, Delete, Get, HttpCode, Param, Post, Put, Query } from '@nestjs/common';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { CommentsService, type CommentDto } from './comments.service.js';
import type { LikeStateDto } from './post-interactions.service.js';
import type { PageDto } from './post-views.js';
import { pageQuerySchema, type PageQuery } from './posts.schemas.js';

/** Post and comment likes share one bucket (CONVENTIONS §11.8). */
const LIKE_LIMIT = { bucket: 'social:like', rule: 'likeUser', key: byUserId, replacesDefault: true } as const;

/** Comments and replies (contract v1.5-social draft, CONVENTIONS §11.5). */
@Controller()
export class CommentsController {
  constructor(private readonly comments: CommentsService) {}

  @Get('posts/:postId/comments')
  list(
    @CurrentAuth() auth: AuthContext,
    @Param('postId') postId: string,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<CommentDto>> {
    return this.comments.list(auth.userId, postId, query);
  }

  @Post('posts/:postId/comments')
  @HttpCode(201)
  @RateLimit({ bucket: 'social:comment', rule: 'commentUser', key: byUserId, replacesDefault: true })
  create(
    @CurrentAuth() auth: AuthContext,
    @Param('postId') postId: string,
    @Body() body: unknown,
  ): Promise<CommentDto> {
    return this.comments.create(auth.userId, postId, body);
  }

  @Get('comments/:commentId/replies')
  replies(
    @CurrentAuth() auth: AuthContext,
    @Param('commentId') commentId: string,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<CommentDto>> {
    return this.comments.replies(auth.userId, commentId, query);
  }

  @Delete('comments/:commentId')
  @HttpCode(204)
  async delete(@CurrentAuth() auth: AuthContext, @Param('commentId') commentId: string): Promise<void> {
    await this.comments.delete(auth.userId, commentId);
  }

  @Put('comments/:commentId/like')
  @HttpCode(200)
  @RateLimit(LIKE_LIMIT)
  like(@CurrentAuth() auth: AuthContext, @Param('commentId') commentId: string): Promise<LikeStateDto> {
    return this.comments.like(auth.userId, commentId, true);
  }

  @Delete('comments/:commentId/like')
  @HttpCode(200)
  @RateLimit(LIKE_LIMIT)
  unlike(@CurrentAuth() auth: AuthContext, @Param('commentId') commentId: string): Promise<LikeStateDto> {
    return this.comments.like(auth.userId, commentId, false);
  }

  @Put('comments/:commentId/pin')
  @HttpCode(200)
  pin(@CurrentAuth() auth: AuthContext, @Param('commentId') commentId: string): Promise<CommentDto> {
    return this.comments.pin(auth.userId, commentId, true);
  }

  @Delete('comments/:commentId/pin')
  @HttpCode(200)
  unpin(@CurrentAuth() auth: AuthContext, @Param('commentId') commentId: string): Promise<CommentDto> {
    return this.comments.pin(auth.userId, commentId, false);
  }
}
