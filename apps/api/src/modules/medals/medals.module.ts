import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import { MedalsController } from './medals.controller.js';
import { MedalsAdminService } from './medals-admin.service.js';
import { MedalsService } from './medals.service.js';

/**
 * CP-018 (D106, CONVENTIONS §10.21): owns `medals` (seeded by migration) and `user_medals`
 * (written by medal-awards.ts inside the transactions of the events that earn them); v1.81-live (D291): `medal_levels`
 * (seeded by migration, edited in the panel through MedalsAdminService).
 */
@Module({
  imports: [UsersModule],
  controllers: [MedalsController],
  providers: [MedalsService, MedalsAdminService],
  exports: [MedalsService, MedalsAdminService],
})
export class MedalsModule {}
