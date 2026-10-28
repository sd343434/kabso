import { Module } from '@nestjs/common';
import { GiftsModule } from '../gifts/gifts.module.js';
import { LiveModule } from '../live/live.module.js';
import { MediaModule } from '../media/media.module.js';
import { PushModule } from '../push/push.module.js';
import { UsersModule } from '../users/users.module.js';
import { WalletModule } from '../wallet/wallet.module.js';
import { DmController } from './dm.controller.js';
import { DmPush } from './dm-push.js';
import { DmService } from './dm.service.js';
import { DmSweeper } from './dm-sweeper.js';

/**
 * v1.40-social (DRAFT, D155, CONVENTIONS §11.13): direct messages. Owns `dm_conversations`,
 * `dm_participants`, `dm_messages` and `dm_message_hides`; sends gifts through the live module's
 * `LiveGiftsService` (`live_gifts.dm_conversation_id`); pushes through the push module; runs the
 * 24-hour retention sweeper ({@link DmSweeper}). Reports of messages are handled by the safety
 * module through `dm-reports.ts`.
 */
@Module({
  imports: [GiftsModule, LiveModule, MediaModule, PushModule, UsersModule, WalletModule],
  controllers: [DmController],
  providers: [DmService, DmPush, DmSweeper],
})
export class DmModule {}
