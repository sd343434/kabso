import { Module } from '@nestjs/common';
import { MediaController } from './media.controller.js';
import { MediaService } from './media.service.js';
import { OBJECT_STORAGE } from './object-storage.js';
import { S3ObjectStorage } from './s3-object-storage.js';

/** v1.5-social media (CONVENTIONS §11.1): owns `media_uploads` and `media_assets`. */
@Module({
  controllers: [MediaController],
  providers: [MediaService, { provide: OBJECT_STORAGE, useClass: S3ObjectStorage }],
  exports: [MediaService],
})
export class MediaModule {}
