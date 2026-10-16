import { Module } from '@nestjs/common';
import { CountriesModule } from '../countries/countries.module.js';
import { MediaModule } from '../media/media.module.js';
import { UsersModule } from '../users/users.module.js';
import { LiveCategoriesService } from './live-categories.service.js';
import { LiveRoomsService } from './live-rooms.service.js';
import { LiveController } from './live.controller.js';

/**
 * `live` module (contract v1.3): owns `live_categories` and `live_rooms`
 * (DB_PHASE2_DISCOVERY.md; v1.4 `cover_media_id` and `country`, DB_PHASE2_MEDIA.md). Runs the
 * in-process stale-room sweeper.
 */
@Module({
  imports: [UsersModule, MediaModule, CountriesModule],
  controllers: [LiveController],
  providers: [LiveCategoriesService, LiveRoomsService],
  exports: [LiveRoomsService],
})
export class LiveModule {}
