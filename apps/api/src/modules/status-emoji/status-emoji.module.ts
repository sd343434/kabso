import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import { StatusEmojiController } from './status-emoji.controller.js';
import { StatusEmojiService } from './status-emoji.service.js';

/**
 * v1.130-social (D376, CONVENTIONS §10.167): «الحالة». Owns `users.status_emoji_id` (written here only),
 * `status_pack_offers`, `user_status_packs` and the append-only `status_pack_purchases`; takes coins through
 * `wallet_ledger` (`STATUS_PACK_PURCHASE`). Readers of `UserSummary` / `Me` / `PublicProfile` read the two user columns
 * with their own query (`USER_SUMMARY_SELECT`, `ME_INCLUDE`) — the documented read-only exception.
 */
@Module({
  imports: [UsersModule],
  controllers: [StatusEmojiController],
  providers: [StatusEmojiService],
})
export class StatusEmojiModule {}
