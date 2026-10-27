import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import { GiftsController } from './gifts.controller.js';
import { GiftsService } from './gifts.service.js';
import { LuckyGiftsService } from './lucky-gifts.service.js';
import { CRYPTO_LUCKY_RNG, LUCKY_RNG } from './lucky-rng.js';

/**
 * CP-020 (D108, CONVENTIONS §10.23): owns `gifts` (managed by the `gift-admin` CLI, never seeded),
 * `user_gift_stock` (the gift bag; grants by the CLI, uses by sends) and `live_gifts` /
 * `live_gift_recipients` (written by the live module's `LiveGiftsService` through
 * `gift-catalogue.ts`, in the send's transaction).
 */
@Module({
  imports: [UsersModule],
  controllers: [GiftsController],
  // v1.27-live (D132): lucky gifts; the CSPRNG is the only LUCKY_RNG outside tests.
  providers: [GiftsService, LuckyGiftsService, { provide: LUCKY_RNG, useValue: CRYPTO_LUCKY_RNG }],
  exports: [GiftsService, LuckyGiftsService],
})
export class GiftsModule {}
