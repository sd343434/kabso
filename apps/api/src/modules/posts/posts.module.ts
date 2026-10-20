import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { UsersModule } from '../users/users.module.js';
import { PostViews } from './post-views.js';
import { PostsController } from './posts.controller.js';
import { PostsService } from './posts.service.js';

/**
 * v1.5-social posts (CONVENTIONS §11.2–§11.6): owns `posts`, `post_*`, `hashtags`, `comments`
 * and `comment_*`.
 */
@Module({
  imports: [MediaModule, UsersModule],
  controllers: [PostsController],
  providers: [PostsService, PostViews],
  exports: [PostsService, PostViews],
})
export class PostsModule {}
