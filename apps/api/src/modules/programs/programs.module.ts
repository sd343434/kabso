import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import { EventsService } from './events.service.js';
import { ProgramsController } from './programs.controller.js';
import { SvipService } from './svip.service.js';
import { TasksService } from './tasks.service.js';

/**
 * v1.44-social (D166, CP-024 approved with defaults, CONVENTIONS §10.41): the Me hub's programs — the
 * Task Center (`task_definitions`, `task_claims`, `daily_check_ins`), the Event Center (`events`,
 * `event_results`, the freeze-and-payout sweeper) and SVIP (computed from `wallet_ledger`). Pays coins
 * only through `wallet_ledger` (`TASK_REWARD`, `CHECK_IN_REWARD`, `EVENT_PRIZE`).
 */
@Module({
  imports: [UsersModule],
  controllers: [ProgramsController],
  providers: [TasksService, EventsService, SvipService],
  exports: [EventsService],
})
export class ProgramsModule {}
