import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { PostsModule } from '../posts/posts.module.js';
import { UsersModule } from '../users/users.module.js';
import { StoriesController } from './stories.controller.js';
import { StoriesService } from './stories.service.js';

/** CP-008 photo stories (CONVENTIONS §11.9): owns `stories`, `story_views` and `story_mentions`. */
@Module({
  imports: [MediaModule, PostsModule, UsersModule],
  controllers: [StoriesController],
  providers: [StoriesService],
  exports: [StoriesService],
})
export class StoriesModule {}
