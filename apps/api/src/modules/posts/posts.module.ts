import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { UsersModule } from '../users/users.module.js';
import { CommentsController } from './comments.controller.js';
import { CommentsService } from './comments.service.js';
import { FeedService } from './feed.service.js';
import { InteractionsController } from './interactions.controller.js';
import { PostInteractionsService } from './post-interactions.service.js';
import { PostViews } from './post-views.js';
import { PostsController } from './posts.controller.js';
import { PostsService } from './posts.service.js';
import { SearchController } from './search.controller.js';
import { SearchService } from './search.service.js';

/**
 * v1.5-social posts (CONVENTIONS §11.2–§11.6): owns `posts`, `post_*`, `hashtags`, `comments`
 * and `comment_*`.
 */
@Module({
  imports: [MediaModule, UsersModule],
  controllers: [PostsController, InteractionsController, CommentsController, SearchController],
  providers: [PostsService, PostViews, PostInteractionsService, FeedService, CommentsService, SearchService],
  exports: [PostsService, PostViews],
})
export class PostsModule {}
