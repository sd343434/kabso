import { Module } from '@nestjs/common';
import { MediaController } from './media.controller.js';
import { MediaService } from './media.service.js';
import { OBJECT_STORAGE } from './object-storage.js';
import { ActiveObjectStorage } from './active-object-storage.js';

/**
 * v1.5-social media (CONVENTIONS §11.1): owns `media_uploads` and `media_assets`. v1.75-social (D222): the storage is
 * the panel's «التخزين (R2 / S3)» when on, else the server's `S3_*` ({@link ActiveObjectStorage}).
 */
@Module({
  controllers: [MediaController],
  providers: [MediaService, { provide: OBJECT_STORAGE, useClass: ActiveObjectStorage }],
  // v1.60-social (D191): the admin panel streams private pictures and deletes removed avatars' files.
  exports: [MediaService, OBJECT_STORAGE],
})
export class MediaModule {}
