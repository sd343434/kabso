import { Injectable } from '@nestjs/common';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { Clock } from '../../common/time/clock.js';
import { PrismaService } from '../../prisma/prisma.service.js';

/**
 * Presence (v1.25-live, CP-022, owner D116, CONVENTIONS §10.25): the minimal honest version. A user
 * is **online** when their last authenticated request was less than {@link PRESENCE_ONLINE_MS} ago;
 * otherwise "last active" is that request's time. There is no socket and no "typing"; the app reads
 * it from lists that carry it (family members), and only as §10.25 allows (same family, the
 * person's `showActivityStatus`, no block either way).
 */
export const PRESENCE_ONLINE_MS = 5 * 60_000;
/** `users.last_active_at` is written at most once a minute per user and API process. */
export const PRESENCE_WRITE_EVERY_MS = 60_000;
/** Users remembered by the per-process throttle before it starts over (bounded memory). */
const MAX_TRACKED = 50_000;

/** Whether a last activity at `at` counts as online at `now`. */
export function isOnline(at: Date | null, now: Date): boolean {
  return at !== null && now.getTime() - at.getTime() < PRESENCE_ONLINE_MS;
}

/**
 * Records that a user made an authenticated request (called by the access-token guard). The write
 * runs after the response ({@link BackgroundTasks}) and is skipped when this process wrote the same
 * user less than a minute ago; the row only moves forward.
 */
@Injectable()
export class PresenceTracker {
  private readonly lastWrite = new Map<string, number>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly background: BackgroundTasks,
  ) {}

  touch(userId: string): void {
    const now = this.clock.now();
    const at = now.getTime();
    const last = this.lastWrite.get(userId);
    if (last !== undefined && at - last < PRESENCE_WRITE_EVERY_MS && at >= last) return;
    if (this.lastWrite.size >= MAX_TRACKED) this.lastWrite.clear();
    this.lastWrite.set(userId, at);
    this.background.run('presence', async () => {
      await this.prisma.$executeRaw`
        UPDATE users SET last_active_at = ${now}::timestamptz
         WHERE id = ${userId}::uuid AND (last_active_at IS NULL OR last_active_at < ${now}::timestamptz)`;
    });
  }
}
