import { Logger, Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { MediaCleanupService } from './media-cleanup.service.js';
import { MEDIA_MODERATION, moderationFor } from './media-moderation.js';
import { MEDIA_STORAGE } from './media-storage.js';
import { MediaUrls } from './media-urls.js';
import { MediaController } from './media.controller.js';
import { MediaService } from './media.service.js';
import { S3MediaStorage } from './s3-media-storage.js';

/**
 * `media` module (contract v1.4): owns `media_objects` (DB_PHASE2_MEDIA.md). Depends on nothing
 * but the shared infrastructure, so `users` and `live` can import it. The S3 adapter is created
 * only from a complete storage configuration (MEDIA_STORAGE_*); otherwise MEDIA_STORAGE is null
 * and nothing can talk to storage. Creating the client contacts no provider.
 */
@Module({
  controllers: [MediaController],
  providers: [
    {
      provide: MEDIA_STORAGE,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) =>
        config.media.storage === null ? null : new S3MediaStorage(config.media.storage),
    },
    {
      provide: MEDIA_MODERATION,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => {
        if (config.media.moderationProvider === 'allow_all') {
          new Logger('MediaModule').warn(
            'MEDIA_MODERATION_PROVIDER=allow_all: images are approved without any content check (dev/test only)',
          );
        }
        return moderationFor(config.media.moderationProvider);
      },
    },
    {
      provide: MediaUrls,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => new MediaUrls(config.media.publicBaseUrl),
    },
    MediaService,
    MediaCleanupService,
  ],
  exports: [MediaService, MediaUrls],
})
export class MediaModule {}
