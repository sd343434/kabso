import { Inject, Injectable, Logger, type OnModuleDestroy } from '@nestjs/common';
import { Clock } from '../../common/time/clock.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

/** CP-012 (§10.10): the score reaches the media room at most once every 2 seconds per room. */
export const SCORE_METADATA_INTERVAL_MS = 2_000;

/**
 * The media room metadata: the seat version (CP-011, §10.9) next to the score (CP-012, §10.10) and,
 * once the host has edited the live's title, category or topic, the room info version (CP-014,
 * §10.12). `roomInfoVersion` is left out while it is 0 (never edited): apps read a missing key as 0,
 * and rooms that were never edited keep exactly the metadata they had before v1.10-live.
 */
export function roomMetadataJson(seatsVersion: number, score: number, roomInfoVersion = 0): string {
  return JSON.stringify(
    roomInfoVersion > 0 ? { seatsVersion, score, roomInfoVersion } : { seatsVersion, score },
  );
}

/**
 * Runs `run(key)` at most once per `intervalMs` per key: a call inside the interval schedules one
 * trailing run at the end of it (so the last value is eventually written), and further calls
 * until then join that run. `now` is the clock the interval is measured on; the trailing run waits
 * on a real timer.
 */
export class TrailingThrottle {
  private readonly last = new Map<string, number>();
  private readonly timers = new Map<string, NodeJS.Timeout>();
  private readonly inFlight = new Set<Promise<void>>();
  private stopped = false;

  constructor(
    private readonly intervalMs: number,
    private readonly now: () => number,
    private readonly run: (key: string) => Promise<void>,
  ) {}

  /** Runs now (awaited) when the interval has passed; otherwise schedules the trailing run. */
  async touch(key: string): Promise<void> {
    if (this.stopped) return;
    const now = this.now();
    const last = this.last.get(key);
    if (last === undefined || now - last >= this.intervalMs || now < last) {
      const timer = this.timers.get(key);
      if (timer) {
        clearTimeout(timer);
        this.timers.delete(key);
      }
      await this.fire(key, now);
      return;
    }
    if (this.timers.has(key)) return;
    const timer = setTimeout(
      () => {
        this.timers.delete(key);
        void this.fire(key, this.now());
      },
      Math.max(0, this.intervalMs - (now - last)),
    );
    timer.unref();
    this.timers.set(key, timer);
  }

  private async fire(key: string, at: number): Promise<void> {
    this.last.set(key, at);
    this.prune(at);
    const run = this.run(key).finally(() => this.inFlight.delete(run));
    this.inFlight.add(run);
    await run;
  }

  /** Forgets keys whose interval passed long ago, so the map stays bounded by active rooms. */
  private prune(now: number): void {
    if (this.last.size < 1_000) return;
    for (const [key, at] of this.last) {
      if (now - at >= this.intervalMs && !this.timers.has(key)) this.last.delete(key);
    }
  }

  /** Cancels pending trailing runs and waits for running ones. */
  async stop(): Promise<void> {
    this.stopped = true;
    for (const timer of this.timers.values()) clearTimeout(timer);
    this.timers.clear();
    await Promise.allSettled([...this.inFlight]);
  }

  /** Keys with a trailing run scheduled (tests). */
  pending(): string[] {
    return [...this.timers.keys()];
  }
}

/**
 * The media room's metadata `{"seatsVersion": n, "score": total, "roomInfoVersion": m}` (CONVENTIONS
 * §10.9, §10.10, §10.12). Every writer composes ALL keys from the database at write time, so a seat
 * change never drops the score or the info version, and a score update never drops the others. Writes are best effort: a failure is
 * logged and the sweeper's reconciliation repeats it.
 */
@Injectable()
export class LiveRoomMetadataService implements OnModuleDestroy {
  private readonly logger = new Logger(LiveRoomMetadataService.name);
  private readonly scoreThrottle: TrailingThrottle;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
  ) {
    this.scoreThrottle = new TrailingThrottle(
      SCORE_METADATA_INTERVAL_MS,
      () => this.clock.now().getTime(),
      (roomId) => this.write(roomId),
    );
  }

  async onModuleDestroy(): Promise<void> {
    await this.scoreThrottle.stop();
  }

  /** The metadata the room should carry now, or null when the room does not exist. */
  async expected(roomId: string): Promise<{ json: string; score: number; roomInfoVersion: number } | null> {
    const room = await this.prisma.liveRoom.findUnique({
      where: { id: roomId },
      select: { seatsVersion: true, score: true, infoVersion: true },
    });
    if (!room) return null;
    const score = Number(room.score);
    return {
      json: roomMetadataJson(room.seatsVersion, score, room.infoVersion),
      score,
      roomInfoVersion: room.infoVersion,
    };
  }

  /** Writes the room's current metadata (best effort). */
  async write(roomId: string): Promise<void> {
    try {
      const expected = await this.expected(roomId);
      if (expected) await this.media.setRoomMetadata(roomId, expected.json);
    } catch (err) {
      this.logger.warn(
        { error: safeErrorLog(err) },
        'Could not write the room metadata into the media room; reconciliation repeats it',
      );
    }
  }

  /**
   * CP-014: the room info version moved (title, category or topic edited). Written at once, not
   * throttled: an edit is rare (the `PATCH` bucket) and everyone in the room should see it promptly.
   * A trailing score write still pending composes every key from the database again, so it never
   * takes the new version back.
   */
  async infoChanged(roomId: string): Promise<void> {
    await this.write(roomId);
  }

  /** The score changed: write it now, or at the end of the room's 2-second interval. */
  async scoreChanged(roomId: string): Promise<void> {
    await this.scoreThrottle.touch(roomId);
  }

  /** Rooms with a trailing score write pending (tests). */
  pendingScoreWrites(): string[] {
    return this.scoreThrottle.pending();
  }
}
