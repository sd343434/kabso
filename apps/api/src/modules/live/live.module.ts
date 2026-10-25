import { Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { AdminGuard, AdminPermissions } from '../levels/admin.guard.js';
import { MediaModule } from '../media/media.module.js';
import { UsersModule } from '../users/users.module.js';
import { LiveCategoriesService } from './live-categories.service.js';
import { LiveChatService } from './live-chat.service.js';
import { LiveBlockedWordsService } from './live-blocked-words.service.js';
import { LiveCoverService } from './live-cover.service.js';
import { LiveMediaService } from './live-media.service.js';
import { LiveRoomMetadataService } from './live-metadata.service.js';
import { LiveRankingsService } from './live-rankings.service.js';
import { LiveRoomsService } from './live-rooms.service.js';
import { LiveSeatsService } from './live-seats.service.js';
import { LiveTapsService } from './live-taps.service.js';
import {
  AdminLiveController,
  LiveBlockedWordsController,
  LiveController,
  LiveCoverController,
  LiveMediaWebhookController,
} from './live.controller.js';
import { LIVE_MEDIA_PROVIDER } from './media/live-media.provider.js';
import { LiveKitMediaProvider, UnconfiguredMediaProvider } from './media/livekit-media.provider.js';

/**
 * `live` module (contract v1.3 + v1.6-live + v1.7-live drafts): owns `live_categories`,
 * `live_rooms`, `live_hosts` and `live_room_viewers` (DB_PHASE2_DISCOVERY.md, CP-010), and the
 * CP-011 seat tables `live_room_seats`, `live_seat_requests`, `live_seat_invites` and
 * `live_room_moderators`, the CP-012 score tables `live_room_scores` and `live_room_tappers`, and the
 * CP-013 chat tables `live_chat_messages` and `live_chat_mutes`, and the CP-015 live cover
 * (`live_hosts.cover_*`, through the media module's `LIVE_COVER` assets). Runs the in-process
 * stale-room sweeper and the media reconciliation; talks to the media server through
 * {@link LIVE_MEDIA_PROVIDER} (LiveKit, D3).
 */
@Module({
  imports: [MediaModule, UsersModule],
  controllers: [
    LiveController,
    LiveCoverController,
    LiveBlockedWordsController,
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
    LiveCoverService,
    LiveRankingsService,
    LiveBlockedWordsService,
    LiveRoomMetadataService,
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
  exports: [LiveRoomsService, LiveMediaService, LiveSeatsService, LiveChatService],
})
export class LiveModule {}
