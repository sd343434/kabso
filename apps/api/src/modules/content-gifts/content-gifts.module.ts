import { Module } from '@nestjs/common';
import { GiftsModule } from '../gifts/gifts.module.js';
import { LiveModule } from '../live/live.module.js';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { PostsModule } from '../posts/posts.module.js';
import { UsersModule } from '../users/users.module.js';
import { WalletModule } from '../wallet/wallet.module.js';
import { ContentGiftsController } from './content-gifts.controller.js';
import { ContentGiftsService } from './content-gifts.service.js';

/**
 * v1.127-social (DRAFT, D372, CONVENTIONS §10.164): «هدية الدعم» — gifts on posts and reels. Sends through the live
 * module's `LiveGiftsService` (`live_gifts.post_id`); writes the gift line through the posts module's tables
 * (`comments` kind GIFT, `posts.comment_count`, `posts.gift_cherries`) in the send's transaction.
 */
@Module({
  imports: [GiftsModule, LiveModule, NotificationsModule, PostsModule, UsersModule, WalletModule],
  controllers: [ContentGiftsController],
  providers: [ContentGiftsService],
})
export class ContentGiftsModule {}
