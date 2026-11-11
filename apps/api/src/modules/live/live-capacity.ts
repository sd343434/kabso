/**
 * v1.113-live (D351, CONVENTIONS §10.148): the capacity guard «حد الامتلاء» — a cluster-wide ceiling on the lives that
 * run at the same time, so a full media tier refuses a NEW live with a clear message instead of degrading everyone
 * (docs/infrastructure/SURGE_AND_OVERFLOW_PLAN.md §6).
 *
 * Only `startLiveRoom` asks it (every mode — solo, multi-guest, audio, podcast, streamer, the web studio's streamer —
 * comes through that one operation; a PK pairs two rooms that already exist). Viewers, guests, seats, PK invitations,
 * heartbeats and media tokens never reach it.
 *
 * Race safety: with the guard on, the go-live transaction takes ONE transaction-scoped Postgres advisory lock
 * ({@link CAPACITY_LOCK}) right before it counts and inserts, so the count-then-insert of two go-lives can never
 * interleave: the second waits until the first commits (its new room is then visible to the second's count — READ
 * COMMITTED takes a new snapshot per statement) or rolls back. The ceiling is therefore never overshot, whatever the
 * concurrency and the number of API instances (they share the database). The lock lives only for that short
 * transaction (a few statements) and is released by COMMIT / ROLLBACK, also when the process dies — nothing to leak or
 * to reconcile, unlike a Redis counter that every way a live ends (the host, the sweeper, a suspension, the team)
 * would have to keep exact. With the guard off (0, the default) no lock is taken and nothing is counted.
 *
 * The count is the same "live" as everywhere else: status LIVE with a fresh heartbeat (§10.2), so a crashed host's room
 * stops counting at the stale window and an ENDED room frees its place at once.
 */
import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { REDIS } from '../../redis/redis.module.js';

/** The advisory lock of the guard (one key for the whole cluster). */
export const CAPACITY_LOCK = 'kabso:live-capacity';

/** The refusals of one UTC day are kept this long in Redis (read by a later admin stat / exporter). */
const REFUSALS_TTL_SECONDS = 8 * 86_400;

export type CapacityMode = 'SOLO' | 'PK' | 'MULTI' | 'AUDIO' | 'PODCAST' | 'STREAMER';

/**
 * The weight of one room of [mode], in percent of a video room. v1.114-live (D363, §10.157): a video podcast
 * ([podcastVideo]) weighs as a video room.
 */
export function capacityWeightOf(
  mode: CapacityMode,
  capacity: AppConfig['live']['capacity'],
  podcastVideo = false,
): number {
  const voice = mode === 'AUDIO' || (mode === 'PODCAST' && !podcastVideo);
  return voice ? capacity.audioWeightPercent : capacity.videoWeightPercent;
}

/** True when a new room of [weight] percent no longer fits next to [usedPercent] (ceiling [maxRooms] video rooms). */
export function capacityExceeded(usedPercent: number, weight: number, maxRooms: number): boolean {
  return usedPercent + weight > maxRooms * 100;
}

/** The Redis key of the refusals of the UTC day of [now]. */
export function refusalsKey(now: Date): string {
  return `live:capacity:refused:${now.toISOString().slice(0, 10)}`;
}

@Injectable()
export class LiveCapacityGuard {
  private readonly logger = new Logger('LiveCapacity');
  /** Refusals since this process started (a gauge for a later /metrics; the Redis day counter is cluster-wide). */
  private refusedSinceStart = 0;

  constructor(
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(REDIS) private readonly redis: Redis,
  ) {}

  get enabled(): boolean {
    return this.config.live.capacity.maxRooms > 0;
  }

  get refusalsSinceStart(): number {
    return this.refusedSinceStart;
  }

  /**
   * Inside the go-live transaction [tx], after the host's own stale room was ended and before the insert: refuses with
   * 503 LIVE_CAPACITY_FULL (+ `Retry-After`) when a room of [mode] does not fit. Holds {@link CAPACITY_LOCK} until
   * [tx] ends. Skipped when the guard is off, for a bypass user, and when the caller already has a fresh LIVE room
   * (the insert then answers 409 LIVE_ROOM_ALREADY_ACTIVE, as without the guard).
   */
  async assertFits(
    tx: Prisma.TransactionClient,
    callerId: string,
    mode: CapacityMode,
    cutoff: Date,
    now: Date,
    podcastVideo = false,
  ): Promise<void> {
    const capacity = this.config.live.capacity;
    if (capacity.maxRooms <= 0) return;
    if (capacity.bypassUserIds.includes(callerId.toLowerCase())) return;
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${CAPACITY_LOCK}))`;
    const [row] = await tx.$queryRaw<{ used: number; rooms: number; mine: boolean }[]>`
      SELECT COALESCE(SUM(CASE WHEN mode = 'AUDIO'::live_room_mode
                                    OR (mode = 'PODCAST'::live_room_mode AND NOT podcast_video)
                               THEN ${capacity.audioWeightPercent}::int
                               ELSE ${capacity.videoWeightPercent}::int END), 0)::int AS used,
             COUNT(*)::int AS rooms,
             COALESCE(BOOL_OR(host_user_id = ${callerId}::uuid), false) AS mine
        FROM live_rooms
       WHERE status = 'LIVE' AND last_heartbeat_at > ${cutoff.toISOString()}::timestamptz`;
    if (!row || row.mine) return;
    const weight = capacityWeightOf(mode, capacity, podcastVideo);
    if (!capacityExceeded(row.used, weight, capacity.maxRooms)) return;
    this.recordRefusal(now, {
      mode,
      rooms: row.rooms,
      usedPercent: row.used,
      weight,
      maxRooms: capacity.maxRooms,
    });
    throw new AppException(ErrorCode.LIVE_CAPACITY_FULL, undefined, undefined, {
      'Retry-After': String(capacity.retryAfterSeconds),
    });
  }

  /** The refusals counted today (UTC) across the cluster; null when Redis does not answer. */
  async refusalsToday(now: Date): Promise<number | null> {
    try {
      const value = await this.redis.get(refusalsKey(now));
      return value === null ? 0 : Number(value);
    } catch {
      return null;
    }
  }

  /** Log line (no user id: the event is about load) + the cluster day counter (best effort, never fails a request). */
  private recordRefusal(
    now: Date,
    facts: { mode: CapacityMode; rooms: number; usedPercent: number; weight: number; maxRooms: number },
  ): void {
    this.refusedSinceStart += 1;
    this.logger.warn({ event: 'live.capacity.full', ...facts }, 'go-live refused: LIVE_CAPACITY_FULL');
    const key = refusalsKey(now);
    void this.redis
      .multi()
      .incr(key)
      .expire(key, REFUSALS_TTL_SECONDS)
      .exec()
      .catch((err: unknown) => {
        this.logger.warn({ err: safeErrorLog(err) }, 'live capacity refusal not counted in Redis');
      });
  }
}
