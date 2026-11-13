import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { normalizeContentText } from '../posts/content-text.js';
import { trimHygiene } from '../users/text-hygiene.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { maskBlockedWords } from './live-blocked-words.js';
import { LiveRoomsService } from './live-rooms.service.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

/** The media data topic of program messages. */
export const PROGRAM_TOPIC = 'program';
/** At most this many segments per live (owner: up to 10). */
export const LIVE_PROGRAM_MAX = 10;
/** A segment title: 1–60 code points. */
export const LIVE_PROGRAM_TITLE_MAX = 60;
/** Segments start within this long after the live started. */
export const LIVE_PROGRAM_SPAN_MS = 24 * 3_600_000;
/** A segment whose start passed more than this long ago when it is first seen is not announced. */
export const LIVE_PROGRAM_ANNOUNCE_WINDOW_MS = 10 * 60_000;

/** `LiveProgramItem` (v1.36-live, D154e, CONVENTIONS §10.37). */
export interface LiveProgramItemDto {
  position: number;
  startsAt: string;
  title: string;
}

/** `LiveProgram`. */
export interface LiveProgramDto {
  roomId: string;
  items: LiveProgramItemDto[];
  /** The segment on now (the last one started, while the live is on), or null. */
  current: number | null;
}

const LINE_BREAK = /[\n\r\u2028\u2029]/u;

/**
 * A one-line live text of 1–[max] code points after the §6 hygiene (`required` / `too_long` /
 * `invalid_format`, line breaks refused). Shared by the program (D154e) and the stickers (D154h).
 */
export function liveLineSchema(max: number) {
  return z
    .string()
    .max(max * 8)
    .transform((raw, ctx): string => {
      const value = trimHygiene(raw.normalize('NFC'));
      const issue =
        value.length === 0
          ? 'required'
          : LINE_BREAK.test(value)
            ? 'invalid_format'
            : [...value].length > max
              ? 'too_long'
              : null;
      if (issue) {
        ctx.addIssue({ code: 'custom', message: issue, params: { issue } });
        return z.NEVER;
      }
      const result = normalizeContentText(value, {
        maxCodePoints: max,
        maxLineBreaks: 0,
        allowEmpty: false,
      });
      if ('issue' in result) {
        ctx.addIssue({ code: 'custom', message: result.issue, params: { issue: result.issue } });
        return z.NEVER;
      }
      return result.value;
    });
}

const programSchema = z.strictObject({
  items: z
    .array(
      z.strictObject({
        startsAt: z.iso.datetime({ offset: true }),
        title: liveLineSchema(LIVE_PROGRAM_TITLE_MAX),
      }),
    )
    .max(LIVE_PROGRAM_MAX),
});

/**
 * A live's program «قائمة البرامج» (D154e, CONVENTIONS §10.37): the host sets up to 10 segments (a
 * start time and a title) for the live on now; everyone in the room reads them (late joiners too);
 * when a segment starts the server tells the room (`program-segment` on topic `program`; a background
 * job on the live sweeper's interval, once per segment, never for a live that ended). Titles pass the
 * text hygiene and are masked with the host's blocked words (D99).
 */
@Injectable()
export class LiveProgramService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(LiveProgramService.name);
  private timer: NodeJS.Timeout | undefined;

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
  ) {}

  onModuleInit(): void {
    const seconds = this.config.live.sweepIntervalSeconds;
    if (seconds > 0) {
      this.timer = setInterval(() => {
        this.announceDue().catch((err: unknown) =>
          this.logger.warn({ error: safeErrorLog(err) }, 'Program announcements failed'),
        );
      }, seconds * 1000);
      this.timer.unref();
    }
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  private dto(
    roomId: string,
    live: boolean,
    rows: readonly { position: number; startsAt: Date; title: string }[],
  ): LiveProgramDto {
    const now = this.clock.now();
    const started = rows.filter((r) => r.startsAt <= now);
    return {
      roomId,
      items: rows.map((r) => ({ position: r.position, startsAt: r.startsAt.toISOString(), title: r.title })),
      current: live && started.length > 0 ? started.at(-1)!.position : null,
    };
  }

  /** `GET /live/rooms/{roomId}/program`: anyone who can see the room (404 otherwise), ended lives too. */
  async get(callerId: string | null, roomId: string): Promise<LiveProgramDto> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    const rows = await this.prisma.liveProgramItem.findMany({
      where: { roomId: row.id },
      orderBy: { position: 'asc' },
    });
    return this.dto(row.id, row.status === 'LIVE', rows);
  }

  /**
   * `PUT /live/rooms/{roomId}/program` `{items: [{startsAt, title}]}`: replaces the program (empty
   * clears it). Visible room (404), the host (403 AUTH_FORBIDDEN), LIVE (409 LIVE_ROOM_ENDED), the body
   * (400: ≤ 10 items; titles 1–60 code points after the hygiene; `startsAt` ascending, from the live's
   * start to 24 h after it → `items` / `invalid_value`). A segment that keeps its start and title keeps
   * its announcement. The room gets `{"type":"program","program":LiveProgram}` on topic `program`.
   */
  async set(callerId: string, roomId: string, body: unknown): Promise<LiveProgramDto> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.host_user_id !== callerId) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const parsed = programSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const starts = parsed.data.items.map((i) => new Date(i.startsAt));
    const from = row.started_at.getTime() - 60_000;
    const until = row.started_at.getTime() + LIVE_PROGRAM_SPAN_MS;
    const ordered = starts.every(
      (s, i) => s.getTime() >= from && s.getTime() <= until && (i === 0 || s > starts[i - 1]!),
    );
    if (!ordered) throw AppException.validation([{ field: 'items', issue: 'invalid_value' }]);
    const host = await this.prisma.liveHost.findUnique({
      where: { userId: callerId },
      select: { blockedWords: true },
    });
    const items = parsed.data.items.map((i, position) => ({
      position,
      startsAt: starts[position]!,
      title: maskBlockedWords(i.title, host?.blockedWords ?? []),
    }));
    const saved = await this.prisma.$transaction(async (tx) => {
      const before = await tx.liveProgramItem.findMany({ where: { roomId: row.id } });
      await tx.liveProgramItem.deleteMany({ where: { roomId: row.id } });
      if (items.length > 0) {
        await tx.liveProgramItem.createMany({
          data: items.map((i) => {
            const same = before.find(
              (b) => b.startsAt.getTime() === i.startsAt.getTime() && b.title === i.title,
            );
            return { roomId: row.id, ...i, announcedAt: same?.announcedAt ?? null };
          }),
        });
      }
      return tx.liveProgramItem.findMany({ where: { roomId: row.id }, orderBy: { position: 'asc' } });
    });
    const program = this.dto(row.id, true, saved);
    await this.broadcast(row.id, { type: 'program', program });
    return program;
  }

  /**
   * Tells each LIVE room about its segments that have started and were not announced yet (once each,
   * safe on several instances); a segment whose start passed more than 10 min ago is marked without a
   * message. Returns how many were announced.
   */
  async announceDue(): Promise<number> {
    const now = this.clock.now();
    const due = await this.prisma.$queryRaw<
      { room_id: string; position: number; starts_at: Date; title: string }[]
    >`
      UPDATE live_program_items p SET announced_at = ${now.toISOString()}::timestamptz
        FROM live_rooms r
       WHERE r.id = p.room_id AND r.status = 'LIVE' AND p.announced_at IS NULL
         AND p.starts_at <= ${now.toISOString()}::timestamptz
         AND (p.room_id, p.position) IN (
               SELECT q.room_id, q.position FROM live_program_items q
                WHERE q.announced_at IS NULL AND q.starts_at <= ${now.toISOString()}::timestamptz
                FOR UPDATE SKIP LOCKED)
      RETURNING p.room_id::text AS room_id, p.position, p.starts_at, p.title`;
    let sent = 0;
    for (const item of due) {
      if (now.getTime() - item.starts_at.getTime() > LIVE_PROGRAM_ANNOUNCE_WINDOW_MS) continue;
      await this.broadcast(item.room_id, {
        type: 'program-segment',
        item: { position: item.position, startsAt: item.starts_at.toISOString(), title: item.title },
      });
      sent += 1;
    }
    return sent;
  }

  private async broadcast(roomId: string, data: object): Promise<void> {
    try {
      await this.media.broadcastData(roomId, PROGRAM_TOPIC, JSON.stringify(data));
    } catch (err) {
      this.logger.warn(
        { error: safeErrorLog(err) },
        'Could not send a program data message to the media room',
      );
    }
  }
}
