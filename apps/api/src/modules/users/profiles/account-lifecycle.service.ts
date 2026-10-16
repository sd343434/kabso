import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { LiveRoomsService } from '../../live/live-rooms.service.js';
import { FollowsService } from '../../social/follows.service.js';
import { UsersService } from '../users.service.js';

/**
 * Account status transitions with their v1.3 side effects, each in ONE transaction:
 *
 *  - {@link suspend}: ACTIVE → SUSPENDED and the host's LIVE room is ended with HOST_SUSPENDED
 *    (CONVENTIONS §10.2). Follow rows are kept so they return on unsuspension (§3 of
 *    DB_PHASE2_DISCOVERY).
 *  - {@link softDelete}: → DELETED (`deleted_at` stamped) and every follow row of the user is
 *    deleted in both directions (DB_PHASE2_DISCOVERY §3; FK cascades fire only on hard deletion).
 *    A LIVE room is hidden at once by the ACTIVE-host filter and ended as HEARTBEAT_TIMEOUT by the
 *    sweeper (the host can no longer heartbeat); the contract defines no other end reason for it.
 *
 * No HTTP route calls these yet: there is no admin API and no account-deletion endpoint in v1.3
 * (suspension is an ops action). The future admin/KL-014 flows must use this service rather than
 * updating `users.status` directly, so the side effects cannot be forgotten.
 */
@Injectable()
export class AccountLifecycleService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly live: LiveRoomsService,
    private readonly follows: FollowsService,
  ) {}

  /** Returns false when the account was not ACTIVE (nothing changed). */
  async suspend(userId: string): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      if (!(await this.users.deactivate(tx, userId, 'SUSPENDED', new Date()))) return false;
      await this.live.endForSuspendedHostIn(tx, userId);
      return true;
    });
  }

  /** Returns false when the account was already DELETED (nothing changed). */
  async softDelete(userId: string): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      if (!(await this.users.deactivate(tx, userId, 'DELETED', new Date()))) return false;
      await this.follows.deleteAllEdgesOfIn(tx, userId);
      return true;
    });
  }
}
