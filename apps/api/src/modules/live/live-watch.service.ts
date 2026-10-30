import { randomUUID } from 'node:crypto';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { trimHygiene } from '../users/text-hygiene.js';
import { maskBlockedWords } from './live-blocked-words.js';
import { LiveRoomsService, type UserSummaryDto } from './live-rooms.service.js';
import { LiveSeatsService } from './live-seats.service.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';
import {
  thumbnailOf,
  YOUTUBE_CLIENT,
  youtubeVideoId,
  type YoutubeClient,
  type YoutubeVideo,
} from './youtube/youtube.client.js';

/** The media data topic of watch-together messages. */
export const WATCH_TOPIC = 'watch';
/** A viewer suggests at most one video this often per live (owner: 1 per 60 s). */
export const WATCH_SUGGEST_INTERVAL_MS = 60_000;
/** The host sees at most this many waiting suggestions (the oldest first). */
export const WATCH_SUGGESTIONS_MAX = 50;
/** A position is at most this far in (a day). */
const POSITION_MAX_MS = 24 * 3_600_000;

/** `LiveWatchVideo` (v1.38-live, D154i, CONVENTIONS §10.39). */
export type LiveWatchVideoDto = YoutubeVideo;

/** `LiveWatch`: what the live watches now; `serverTime` lets a phone place the position. */
export interface LiveWatchDto {
  roomId: string;
  video: LiveWatchVideoDto | null;
  playing: boolean;
  positionMs: number;
  updatedAt: string | null;
  serverTime: string;
  searchEnabled: boolean;
}

/** `LiveWatchSuggestion`. */
export interface LiveWatchSuggestionDto {
  id: string;
  roomId: string;
  video: LiveWatchVideoDto;
  suggester: UserSummaryDto;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  createdAt: string;
}

const videoRef = z.string().min(1).max(300);

const setSchema = z.strictObject({
  video: videoRef.nullable().optional(),
  playing: z.boolean(),
  positionMs: z.number().int().min(0).max(POSITION_MAX_MS),
});

const suggestSchema = z.strictObject({ video: videoRef });
const decisionSchema = z.strictObject({ approve: z.boolean() });
const searchSchema = z.strictObject({ q: z.string().min(1).max(100) });

/**
 * YouTube watch-together «يوتيوب» (D154i, CONVENTIONS §10.39). Every phone plays the video in the
 * official YouTube embedded player, streamed from YouTube; the server only keeps and relays the sync
 * state (which video, playing or paused, the position at `updatedAt`) on topic `watch`, so late
 * joiners start in the right place. Viewers suggest videos (one a minute, titles masked with the
 * host's blocked words); the host plays or turns them down. Search uses the server's YouTube Data
 * API key when set; otherwise hosts and viewers paste links.
 */
@Injectable()
export class LiveWatchService {
  private readonly logger = new Logger(LiveWatchService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly limiter: RateLimitService,
    private readonly clock: Clock,
    @Inject(YOUTUBE_CLIENT) private readonly youtube: YoutubeClient,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    private readonly seats: LiveSeatsService,
  ) {}

  /**
   * v1.39-live (D173): an AUDIO room is a cinema while it watches — at most 10 seats; people on
   * seats 10+ move down or leave the seat when it starts; the room's own count returns when it stops.
   */
  private async cinema(room: { id: string; mode: string }, watching: boolean): Promise<void> {
    if (room.mode !== 'AUDIO') return;
    if (watching) await this.seats.enterCinema(room.id);
    else await this.seats.leaveCinema(room.id);
  }

  private watchDto(
    roomId: string,
    row: {
      videoId: string;
      title: string;
      channel: string | null;
      playing: boolean;
      positionMs: number;
      updatedAt: Date;
    } | null,
  ): LiveWatchDto {
    return {
      roomId,
      video:
        row === null
          ? null
          : {
              videoId: row.videoId,
              title: row.title,
              channel: row.channel,
              thumbnailUrl: thumbnailOf(row.videoId),
            },
      playing: row?.playing ?? false,
      positionMs: row?.positionMs ?? 0,
      updatedAt: row?.updatedAt.toISOString() ?? null,
      serverTime: this.clock.now().toISOString(),
      searchEnabled: this.youtube.searchEnabled,
    };
  }

  private async blockedWords(hostId: string): Promise<readonly string[]> {
    const host = await this.prisma.liveHost.findUnique({
      where: { userId: hostId },
      select: { blockedWords: true },
    });
    return host?.blockedWords ?? [];
  }

  /** The video of [ref] (an id or a link); 400 when it is neither, 422 when YouTube refuses it. */
  private async resolve(ref: string, field: string): Promise<YoutubeVideo> {
    const id = youtubeVideoId(ref);
    if (id === null) throw AppException.validation([{ field, issue: 'invalid_format' }]);
    let video: YoutubeVideo | null;
    try {
      video = await this.youtube.video(id);
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'YouTube could not be reached');
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    }
    if (video === null) throw new AppException(ErrorCode.YOUTUBE_VIDEO_UNAVAILABLE);
    return { ...video, title: trimHygiene(video.title).slice(0, 400) || id };
  }

  private async broadcast(roomId: string, data: object): Promise<void> {
    try {
      await this.media.broadcastData(roomId, WATCH_TOPIC, JSON.stringify(data));
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a watch message to the media room');
    }
  }

  /** `GET /live/rooms/{roomId}/watch`: anyone who can see the room; no video once it ended. */
  async get(callerId: string | null, roomId: string): Promise<LiveWatchDto> {
    const room = await this.rooms.visibleRow(roomId, callerId);
    if (room.status !== 'LIVE') return this.watchDto(room.id, null);
    const row = await this.prisma.liveWatch.findUnique({ where: { roomId: room.id } });
    return this.watchDto(room.id, row);
  }

  /**
   * `PUT /live/rooms/{roomId}/watch` `{video?, playing, positionMs}`: the host's player state (on every
   * play, pause and seek, and now and then while playing). `video` (an id or a link) changes the video;
   * null stops watching; absent keeps it. 404 / 403 / 409 as usual; 400 `video` / `invalid_format`;
   * 422 YOUTUBE_VIDEO_UNAVAILABLE. The room gets `{"type":"watch","watch":LiveWatch}`.
   */
  async set(callerId: string, roomId: string, body: unknown): Promise<LiveWatchDto> {
    const room = await this.rooms.visibleRow(roomId, callerId);
    if (room.host_user_id !== callerId) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const parsed = setSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { video, playing, positionMs } = parsed.data;
    const now = this.clock.now();
    let row;
    if (video === null) {
      await this.prisma.liveWatch.deleteMany({ where: { roomId: room.id } });
      row = null;
    } else if (video === undefined) {
      const current = await this.prisma.liveWatch.findUnique({ where: { roomId: room.id } });
      if (current === null) throw AppException.validation([{ field: 'video', issue: 'required' }]);
      row = await this.prisma.liveWatch.update({
        where: { roomId: room.id },
        data: { playing, positionMs, updatedAt: now },
      });
    } else {
      const found = await this.resolve(video, 'video');
      const title = maskBlockedWords(found.title, await this.blockedWords(callerId));
      const data = {
        videoId: found.videoId,
        title,
        channel: found.channel,
        playing,
        positionMs,
        updatedAt: now,
      };
      row = await this.prisma.liveWatch.upsert({
        where: { roomId: room.id },
        create: { roomId: room.id, ...data },
        update: data,
      });
    }
    await this.cinema(room, row !== null);
    const watch = this.watchDto(room.id, row);
    await this.broadcast(room.id, { type: 'watch', watch });
    return watch;
  }

  private suggestionDto(row: {
    id: string;
    roomId: string;
    videoId: string;
    title: string;
    channel: string | null;
    status: string;
    createdAt: Date;
    user: Parameters<typeof userSummary>[0];
  }): LiveWatchSuggestionDto {
    return {
      id: row.id,
      roomId: row.roomId,
      video: {
        videoId: row.videoId,
        title: row.title,
        channel: row.channel,
        thumbnailUrl: thumbnailOf(row.videoId),
      },
      suggester: userSummary(row.user),
      status: row.status as LiveWatchSuggestionDto['status'],
      createdAt: row.createdAt.toISOString(),
    };
  }

  /**
   * `POST /live/rooms/{roomId}/watch/suggestions` `{video}`: a signed-in viewer of a LIVE room (not the
   * host: 403) suggests a video; one a minute per viewer per live (429 with Retry-After). The title is
   * masked with the host's blocked words. The room gets `{"type":"watch-suggestion","suggestion":…}`
   * (the host's app lists it).
   */
  async suggest(callerId: string, roomId: string, body: unknown): Promise<LiveWatchSuggestionDto> {
    const room = await this.rooms.visibleRow(roomId, callerId);
    if (room.host_user_id === callerId) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const parsed = suggestSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const found = await this.resolve(parsed.data.video, 'video');
    const waitMs = await this.limiter.interval(
      'live:watch:suggest',
      `${room.id}:${callerId}`,
      this.clock.now().getTime(),
      WATCH_SUGGEST_INTERVAL_MS,
    );
    if (waitMs > 0) {
      throw new AppException(ErrorCode.RATE_LIMITED, undefined, undefined, {
        'Retry-After': String(Math.max(1, Math.ceil(waitMs / 1000))),
      });
    }
    const title = maskBlockedWords(found.title, await this.blockedWords(room.host_user_id));
    const row = await this.prisma.liveWatchSuggestion.create({
      data: {
        id: randomUUID(),
        roomId: room.id,
        userId: callerId,
        videoId: found.videoId,
        title,
        channel: found.channel,
        createdAt: this.clock.now(),
      },
      include: { user: { select: USER_SUMMARY_SELECT } },
    });
    const suggestion = this.suggestionDto(row);
    await this.broadcast(room.id, { type: 'watch-suggestion', suggestion });
    return suggestion;
  }

  /** `GET /live/rooms/{roomId}/watch/suggestions`: the host's waiting suggestions, the oldest first. */
  async suggestions(callerId: string, roomId: string): Promise<{ data: LiveWatchSuggestionDto[] }> {
    const room = await this.rooms.visibleRow(roomId, callerId);
    if (room.host_user_id !== callerId) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const rows = await this.prisma.liveWatchSuggestion.findMany({
      where: { roomId: room.id, status: 'PENDING' },
      orderBy: { createdAt: 'asc' },
      take: WATCH_SUGGESTIONS_MAX,
      include: { user: { select: USER_SUMMARY_SELECT } },
    });
    return { data: rows.map((r) => this.suggestionDto(r)) };
  }

  /**
   * `POST /live/rooms/{roomId}/watch/suggestions/{id}/decision` `{approve}`: the host plays a waiting
   * suggestion from the start (approve) or turns it down; 404 when it is not waiting. Answers the watch
   * state (changed when approved, with its `watch` message).
   */
  async decide(callerId: string, roomId: string, suggestionId: string, body: unknown): Promise<LiveWatchDto> {
    const room = await this.rooms.visibleRow(roomId, callerId);
    if (room.host_user_id !== callerId) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const parsed = decisionSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    if (!z.uuid().safeParse(suggestionId).success) throw new AppException(ErrorCode.NOT_FOUND);
    const now = this.clock.now();
    const decided = await this.prisma.liveWatchSuggestion.updateManyAndReturn({
      where: { id: suggestionId, roomId: room.id, status: 'PENDING' },
      data: { status: parsed.data.approve ? 'APPROVED' : 'REJECTED', decidedAt: now },
    });
    const suggestion = decided[0];
    if (!suggestion) throw new AppException(ErrorCode.NOT_FOUND);
    if (!parsed.data.approve) {
      const row = await this.prisma.liveWatch.findUnique({ where: { roomId: room.id } });
      return this.watchDto(room.id, row);
    }
    const data = {
      videoId: suggestion.videoId,
      title: suggestion.title,
      channel: suggestion.channel,
      playing: true,
      positionMs: 0,
      updatedAt: now,
    };
    const row = await this.prisma.liveWatch.upsert({
      where: { roomId: room.id },
      create: { roomId: room.id, ...data },
      update: data,
    });
    await this.cinema(room, true);
    const watch = this.watchDto(room.id, row);
    await this.broadcast(room.id, { type: 'watch', watch });
    return watch;
  }

  /**
   * `GET /live/youtube/search?q=`: embeddable videos for a query (signed in). 503
   * YOUTUBE_SEARCH_UNAVAILABLE when the server has no YouTube key or YouTube fails.
   */
  async search(query: unknown, language: string): Promise<{ items: LiveWatchVideoDto[] }> {
    const parsed = searchSchema.safeParse(query ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    if (!this.youtube.searchEnabled) throw new AppException(ErrorCode.YOUTUBE_SEARCH_UNAVAILABLE);
    try {
      return { items: await this.youtube.search(parsed.data.q.trim(), language) };
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'YouTube search failed');
      throw new AppException(ErrorCode.YOUTUBE_SEARCH_UNAVAILABLE);
    }
  }
}
