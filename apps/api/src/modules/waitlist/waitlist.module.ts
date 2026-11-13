import { Module } from '@nestjs/common';
import { WaitlistController } from './waitlist.controller.js';
import { WaitlistService } from './waitlist.service.js';

/** D192 (v1.61-social draft, CONVENTIONS §10.55): the website's waitlist. Owns `waitlist_signups`. */
@Module({
  controllers: [WaitlistController],
  providers: [WaitlistService],
})
export class WaitlistModule {}
