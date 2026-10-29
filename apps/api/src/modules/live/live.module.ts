import { Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { AdminGuard, AdminPermissions } from '../levels/admin.guard.js';
import { GiftsModule } from '../gifts/gifts.module.js';
import { LevelProgressService } from '../levels/level-progress.service.js';
import { MediaModule } from '../media/media.module.js';
import { UsersModule } from '../users/users.module.js';
import { WalletModule } from '../wallet/wallet.module.js';
import { LiveBulletsService } from './live-bullets.service.js';
import { LiveSeatEmojiService } from './live-seat-emoji.service.js';
import { LiveQuipsService } from './live-quips.service.js';
import { LiveBoostsService } from './live-boosts.service.js';
import { LiveNewcomersService } from './live-newcomers.service.js';
import { LiveDataCenterService } from './live-data-center.service.js';
import { LiveProgramService } from './live-program.service.js';
import { LiveStickersService } from './live-stickers.service.js';
import { LiveWatchService } from './live-watch.service.js';
import { HttpYoutubeClient, YOUTUBE_CLIENT } from './youtube/youtube.client.js';
import { LiveCategoriesService } from './live-categories.service.js';
import { LiveChatBadgesService } from './live-chat-badges.service.js';
import { LiveChatService } from './live-chat.service.js';
import { LiveBlockedWordsService } from './live-blocked-words.service.js';
import { LiveCoverService } from './live-cover.service.js';
import { LiveGiftsService } from './live-gifts.service.js';
import { LiveLuckyTickerService } from './live-lucky-ticker.service.js';
import { LiveKicksService } from './live-kicks.service.js';
import { LiveMediaService } from './live-media.service.js';
import { LiveRoomMetadataService } from './live-metadata.service.js';
import { LiveStatsService } from './live-stats.service.js';
import { LiveRankingsService } from './live-rankings.service.js';
import { LiveRoomsService } from './live-rooms.service.js';
import { LiveScheduleService } from './live-schedule.service.js';
import { LiveSeatsService } from './live-seats.service.js';
import { LiveTapsService } from './live-taps.service.js';
import {
  AdminLiveController,
  LiveBlockedWordsController,
  LiveController,
  LiveCoverController,
  LiveMediaWebhookController,
  LiveScheduleController,
} from './live.controller.js';
import { LIVE_MEDIA_PROVIDER } from './media/live-media.provider.js';
import { LiveKitMediaProvider, UnconfiguredMediaProvider } from './media/livekit-media.provider.js';

/**
 * `live` module (contract v1.3 + v1.6-live + v1.7-live drafts): owns `live_categories`,
 * `live_rooms`, `live_hosts` and `live_room_viewers` (DB_PHASE2_DISCOVERY.md, CP-010), and the
 * CP-011 seat tables `live_room_seats`, `live_seat_requests`, `live_seat_invites` and
 * `live_room_moderators`, the CP-012 score tables `live_room_scores` and `live_room_tappers`, and the
 * CP-013 chat tables `live_chat_messages` and `live_chat_mutes`, and the CP-015 live cover
 * (`live_hosts.cover_*`, through the media module's `LIVE_COVER` assets), and the CP-016 tables
 * `live_host_points_hourly` and `live_schedule_slots`, and the CP-017 `live_bullets` (charged through
 * the wallet module), and the v1.20-live `live_room_kicks`. v1.23-live (CP-020): sends gifts
 * (`LiveGiftsService`) into the gifts module's `live_gifts` tables. Runs the in-process
 * stale-room sweeper and the media reconciliation; talks to the media server through
 * {@link LIVE_MEDIA_PROVIDER} (LiveKit, D3).
 */
@Module({
  imports: [MediaModule, UsersModule, WalletModule, GiftsModule],
  controllers: [
    LiveController,
    LiveCoverController,
    LiveBlockedWordsController,
    LiveScheduleController,
    AdminLiveController,
    LiveMediaWebhookController,
  ],
  providers: [
    LiveCategoriesService,
    LiveRoomsService,
    LiveMediaService,
    LiveSeatsService,
    LiveTapsService,
    LiveChatService,
    // v1.24.4-live (D119): the level and family badges of chat authors.
    LiveChatBadgesService,
    LiveCoverService,
    LiveRankingsService,
    // v1.27.6-live (D140): the host's statistics of a live (§10.31).
    LiveStatsService,
    LiveBlockedWordsService,
    LiveScheduleService,
    LiveRoomMetadataService,
    // CP-017: bullet messages, charged through the wallet (§10.19).
    LiveBulletsService,
    // v1.27.5-live (D138): an emoji on one's own seat (§10.30).
    LiveSeatEmojiService,
    LiveQuipsService,
    LiveBoostsService,
    LiveNewcomersService,
    LiveDataCenterService,
    LiveProgramService,
    LiveStickersService,
    LiveWatchService,
    { provide: YOUTUBE_CLIENT, useClass: HttpYoutubeClient },
    // v1.20-live (D105): kicking someone out of a live (§10.20).
    LiveKicksService,
    // v1.23-live (CP-020, D108): gifts in a live, through the wallet and the gifts module (§10.23).
    LiveGiftsService,
    LiveLuckyTickerService,
    // CP-016 D: taps credit the host's charm level inside the taps transaction (§10.18).
    LevelProgressService,
    AdminGuard,
    AdminPermissions,
    {
      provide: LIVE_MEDIA_PROVIDER,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) =>
        config.live.livekit
          ? new LiveKitMediaProvider(
              config.live.livekit.url,
              config.live.livekit.apiKey,
              config.live.livekit.apiSecret,
            )
          : new UnconfiguredMediaProvider(),
    },
  ],
  // v1.40-social (D155): the messages module sends gifts in conversations through LiveGiftsService.
  // v1.43-social (D164): the data center's summaries also feed the creator center.
  exports: [
    LiveRoomsService,
    LiveMediaService,
    LiveSeatsService,
    LiveChatService,
    LiveGiftsService,
    LiveDataCenterService,
  ],
})
export class LiveModule {}
