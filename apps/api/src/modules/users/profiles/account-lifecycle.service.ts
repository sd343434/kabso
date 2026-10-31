import { Inject, Injectable } from '@nestjs/common';
import type { Prisma } from '../../../generated/prisma/client.js';
import { APP_CONFIG, type AppConfig } from '../../../config/app-config.js';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { LiveRoomsService } from '../../live/live-rooms.service.js';
import { FollowsService } from '../../social/follows.service.js';
import { syncAgentUsernameIn } from '../agent-usernames.js';
import { UsersService } from '../users.service.js';

/**
 * Account status transitions with their v1.3 side effects, each in ONE transaction:
 *
 *  - {@link suspend}: ACTIVE → SUSPENDED and the host's LIVE room is ended with HOST_SUSPENDED
 *    (CONVENTIONS §10.2); CP-011: the user's seats, seat requests, invitations and moderator roles
 *    in other rooms end too (§10.9; also on soft delete). Follow rows are kept so they return on unsuspension (§3 of
 *    DB_PHASE2_DISCOVERY).
 *  - {@link softDelete}: → DELETED (`deleted_at` stamped) and every follow row of the user is
 *    deleted in both directions (DB_PHASE2_DISCOVERY §3; FK cascades fire only on hard deletion).
 *    A LIVE room is hidden at once by the ACTIVE-host filter and ended as HEARTBEAT_TIMEOUT by the
 *    sweeper (the host can no longer heartbeat); the contract defines no other end reason for it.
 *
 * v1.60-social (D191): the admin panel's ban / unban call {@link suspendIn} / {@link unsuspendIn}; there is no
 * account-deletion endpoint yet. Every flow must use this service rather than updating `users.status` directly,
 * so the side effects cannot be forgotten.
 */
@Injectable()
export class AccountLifecycleService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly live: LiveRoomsService,
    private readonly follows: FollowsService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** Returns false when the account was not ACTIVE (nothing changed). */
  async suspend(userId: string): Promise<boolean> {
    return this.prisma.$transaction((tx) => this.suspendIn(tx, userId));
  }

  /**
   * v1.60-social (D191): {@link suspend} inside the caller's transaction (the panel's ban writes its audit row and
   * closes the reports in the same one).
   */
  async suspendIn(tx: Prisma.TransactionClient, userId: string): Promise<boolean> {
    if (!(await this.users.deactivate(tx, userId, 'SUSPENDED', new Date()))) return false;
    await this.live.endForSuspendedHostIn(tx, userId);
    // CP-011: the user also loses seats, requests, invitations and moderator roles elsewhere.
    await this.live.releaseSeatsOfUserIn(tx, userId);
    // v1.58-social (D189, §10.52): an agent code shown as the username ends (the base one is shown again; the
    // code stays the person's); the frame, badges and entrance already follow the account status.
    await syncAgentUsernameIn(tx, userId, new Date(), this.config.specialUsernames.graceDays, {
      note: 'account suspended',
    });
    return true;
  }

  /**
   * v1.60-social (D191): SUSPENDED → ACTIVE (the panel's unban) inside the caller's transaction; an agent code comes
   * back as the shown username. Follows were kept. Returns false when the account was not SUSPENDED.
   */
  async unsuspendIn(tx: Prisma.TransactionClient, userId: string): Promise<boolean> {
    const updated = await tx.user.updateMany({
      where: { id: userId, status: 'SUSPENDED' },
      data: { status: 'ACTIVE' },
    });
    if (updated.count !== 1) return false;
    await syncAgentUsernameIn(tx, userId, new Date(), this.config.specialUsernames.graceDays);
    return true;
  }

  /** Returns false when the account was already DELETED (nothing changed). */
  async softDelete(userId: string): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      if (!(await this.users.deactivate(tx, userId, 'DELETED', new Date()))) return false;
      await this.follows.deleteAllEdgesOfIn(tx, userId);
      await this.live.releaseSeatsOfUserIn(tx, userId);
      return true;
    });
  }
}
