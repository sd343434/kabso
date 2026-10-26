import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import { MedalsController } from './medals.controller.js';
import { MedalsService } from './medals.service.js';

/**
 * CP-018 (D106, CONVENTIONS §10.21): owns `medals` (seeded by migration) and `user_medals`
 * (written by medal-awards.ts inside the transactions of the events that earn them).
 */
@Module({
  imports: [UsersModule],
  controllers: [MedalsController],
  providers: [MedalsService],
  exports: [MedalsService],
})
export class MedalsModule {}
