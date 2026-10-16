import { Global, Injectable, Module } from '@nestjs/common';

/**
 * Source of "now" for time rules that tests must be able to move (live-room heartbeat freshness,
 * CONVENTIONS §10.2). Tests replace it with a controllable clock instead of sleeping.
 */
export abstract class Clock {
  abstract now(): Date;
}

@Injectable()
export class SystemClock extends Clock {
  now(): Date {
    return new Date();
  }
}

@Global()
@Module({
  providers: [{ provide: Clock, useClass: SystemClock }],
  exports: [Clock],
})
export class ClockModule {}
