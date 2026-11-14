import { Inject, Injectable, Logger } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { maskBlockedWords } from './live-blocked-words.js';
import { LiveBlockedWordsService } from './live-blocked-words.service.js';
import { readStudio, segmentsOf, type LivePodcastStudioDto } from './live-podcast-studio.js';
import { LIVE_TX_OPTIONS, LiveRoomsService, type RoomRow } from './live-rooms.service.js';
import {
  isUuid,
  livePodcastControlBodySchema,
  livePodcastDirectorBodySchema,
  livePodcastOnScreenBodySchema,
  livePodcastSegmentsBodySchema,
  type PodcastDirectorShot,
} from './live.schemas.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

/** v1.114-live (D363, §10.157): the data topic of the video podcast's room events. */
export const PODCAST_TOPIC = 'podcast';

/** `LivePodcastQuestionVotes`. */
export interface LivePodcastQuestionVotesDto {
  requestId: string;
  votes: number;
  votedByMe: boolean;
}

/** The data messages of topic `podcast`. */
export type LivePodcastData =
  | { readonly type: 'question-votes'; readonly requestId: string; readonly votes: number }
  | {
      readonly type: 'director';
      readonly shot: PodcastDirectorShot;
      readonly userIds: readonly string[];
      readonly locked: boolean;
      readonly seq: number;
      readonly at: string;
    }
  /** v1.114-live (D363, scope extension): the studio changed (the whole state; apps drop an older `seq`). */
  | { readonly type: 'studio'; readonly studio: LivePodcastStudioDto };

/** What a studio change writes (absent = unchanged). */
interface StudioPatch {
  pinUserId?: string | null;
  layout?: string | null;
  segments?: Prisma.InputJsonValue;
  segmentIndex?: number | null;
  segmentStartedAt?: Date | null;
  closing?: boolean;
  onScreenRequestId?: string | null;
  answerUserId?: string | null;
  onScreenAt?: Date | null;
}

/** The studio as stored (before it is read for people). */
interface StudioRow {
  pinUserId: string | null;
  layout: string | null;
  segments: Prisma.JsonValue;
  segmentIndex: number | null;
  closing: boolean;
  onScreenRequestId: string | null;
  answerUserId: string | null;
}

const NO_STUDIO: StudioRow = {
  pinUserId: null,
  layout: null,
  segments: [],
  segmentIndex: null,
  closing: false,
  onScreenRequestId: null,
  answerUserId: null,
};

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

/**
 * v1.114-live (D363, CONVENTIONS §10.157): the video podcast's question upvotes and the director relay. The hot seat,
 * guest titles and the questions list live with the seats ({@link LiveSeatsService}); this service only adds the two
 * room events of topic `podcast`, both best effort (the provider retries a closed room, D319).
 */
@Injectable()
export class LivePodcastVideoService {
  private readonly logger = new Logger(LivePodcastVideoService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly clock: Clock,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    private readonly blockedWords: LiveBlockedWordsService,
  ) {}

  /** A visible (404), LIVE (409 LIVE_ROOM_ENDED) video podcast (404 otherwise). */
  private async videoPodcast(roomId: string, callerId: string): Promise<RoomRow> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (!(row.mode === 'PODCAST' && row.podcast_video)) throw notFound();
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    return row;
  }

  /**
   * `PUT` (vote) / `DELETE` (unvote) `…/seat-requests/{requestId}/vote`. Order: the room (404 / 409), kicked (403
   * LIVE_KICKED), the hand — of this room with a question (404), still up (409 LIVE_REQUEST_NOT_PENDING) —, then the
   * asker (403, voting only). Idempotent; a change sends `question-votes` to the room.
   */
  async setVote(
    callerId: string,
    roomId: string,
    requestId: string,
    vote: boolean,
  ): Promise<LivePodcastQuestionVotesDto> {
    if (!isUuid(requestId)) throw notFound();
    const row = await this.videoPodcast(roomId, callerId);
    if (row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
    const id = requestId.toLowerCase();
    const request = await this.prisma.liveSeatRequest.findFirst({
      where: { id, roomId: row.id },
      select: { id: true, userId: true, status: true, question: true },
    });
    if (!request || request.question === null) throw notFound();
    if (request.status !== 'PENDING') throw new AppException(ErrorCode.LIVE_REQUEST_NOT_PENDING);
    if (vote && request.userId === callerId) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const changed = vote
      ? (
          await this.prisma.liveQuestionVote.createMany({
            data: [{ requestId: id, userId: callerId, createdAt: this.clock.now() }],
            skipDuplicates: true,
          })
        ).count
      : (await this.prisma.liveQuestionVote.deleteMany({ where: { requestId: id, userId: callerId } })).count;
    const [votes, mine] = await Promise.all([
      this.prisma.liveQuestionVote.count({ where: { requestId: id } }),
      this.prisma.liveQuestionVote.count({ where: { requestId: id, userId: callerId } }),
    ]);
    if (changed > 0) await this.send(row.id, { type: 'question-votes', requestId: id, votes });
    return { requestId: id, votes, votedByMe: mine > 0 };
  }

  /**
   * `PUT /live/rooms/{roomId}/podcast/director` (host only): checks the shot (400), that every person on it is the
   * host or seated now (400 `userIds`), then relays it to the room. Nothing is stored.
   */
  async relayDirector(callerId: string, roomId: string, body: unknown): Promise<void> {
    const row = await this.videoPodcast(roomId, callerId);
    if (callerId !== row.host_user_id) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const parsed = livePodcastDirectorBodySchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const userIds = parsed.data.userIds.map((u) => u.toLowerCase());
    const seated = new Set(
      (
        await this.prisma.liveRoomSeat.findMany({
          // v1.114-live (D363, scope extension): a guest waiting backstage is not on the shot.
          where: { roomId: row.id, userId: { in: userIds }, backstage: false },
          select: { userId: true },
        })
      ).map((s) => s.userId),
    );
    if (userIds.some((u) => u !== row.host_user_id && !seated.has(u))) {
      throw AppException.validation([{ field: 'userIds', issue: 'invalid_value' }]);
    }
    await this.send(row.id, {
      type: 'director',
      shot: parsed.data.shot,
      userIds,
      locked: parsed.data.locked,
      seq: parsed.data.seq,
      at: this.clock.now().toISOString(),
    });
  }

  // ---- v1.114-live (D363, scope extension 2026-11-11): the studio --------------------------------------------

  /** A LIVE video podcast whose host is the caller (403 otherwise). */
  private async hostedVideoPodcast(roomId: string, callerId: string): Promise<RoomRow> {
    const row = await this.videoPodcast(roomId, callerId);
    if (callerId !== row.host_user_id) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    return row;
  }

  /**
   * Runs one studio change under the room's lock: [fn] gets the stored studio and the people on air (the host and
   * the seated people who are not backstage) and returns the patch, or null for no change. A change raises `seq`
   * and is sent to the room as `studio`; the answer is the studio as everyone reads it.
   */
  private async mutate(
    row: RoomRow,
    fn: (
      tx: Prisma.TransactionClient,
      current: StudioRow,
      onStage: ReadonlySet<string>,
      now: Date,
    ) => Promise<StudioPatch | null>,
  ): Promise<LivePodcastStudioDto> {
    const words = await this.blockedWords.wordsOf(row.host_user_id);
    const mask = (text: string): string => maskBlockedWords(text, words);
    const now = this.clock.now();
    const { studio, changed } = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM live_rooms WHERE id = ${row.id}::uuid FOR UPDATE`;
      const seated = await tx.liveRoomSeat.findMany({
        where: { roomId: row.id, userId: { not: null }, backstage: false },
        select: { userId: true },
      });
      const onStage = new Set([row.host_user_id, ...seated.flatMap((s) => (s.userId ? [s.userId] : []))]);
      const stored = await tx.livePodcastStudio.findUnique({ where: { roomId: row.id } });
      const patch = await fn(tx, stored ?? NO_STUDIO, onStage, now);
      if (patch !== null) {
        await tx.livePodcastStudio.upsert({
          where: { roomId: row.id },
          create: { roomId: row.id, ...patch, seq: 1, updatedAt: now },
          update: { ...patch, seq: { increment: 1 }, updatedAt: now },
        });
      }
      return { studio: await readStudio(tx, row.id, onStage, mask), changed: patch !== null };
    }, LIVE_TX_OPTIONS);
    if (changed) await this.send(row.id, { type: 'studio', studio });
    return studio;
  }

  /**
   * `PUT /live/rooms/{roomId}/podcast/control` (host): pin a person (the host or someone on air, else 400
   * `pinUserId`) and/or lock a layout (`HOT_SEAT` needs a hot seat now, else 400 `layout`); both null = «تلقائي».
   */
  async setControl(callerId: string, roomId: string, body: unknown): Promise<LivePodcastStudioDto> {
    const row = await this.hostedVideoPodcast(roomId, callerId);
    const parsed = livePodcastControlBodySchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const pin = parsed.data.pinUserId?.toLowerCase() ?? null;
    const layout = parsed.data.layout ?? null;
    return this.mutate(row, async (tx, current, onStage) => {
      if (pin !== null && !onStage.has(pin)) {
        throw AppException.validation([{ field: 'pinUserId', issue: 'invalid_value' }]);
      }
      if (
        layout === 'HOT_SEAT' &&
        (await tx.liveRoomSeat.count({ where: { roomId: row.id, hotSeatRequestId: { not: null } } })) === 0
      ) {
        throw AppException.validation([{ field: 'layout', issue: 'invalid_value' }]);
      }
      const currentPin =
        current.pinUserId !== null && onStage.has(current.pinUserId) ? current.pinUserId : null;
      if (currentPin === pin && current.layout === layout) return null;
      return { pinUserId: pin, layout };
    });
  }

  /**
   * `PUT /live/rooms/{roomId}/podcast/segments` (host): replaces the episode's segments (0–8). A current segment
   * beyond the new list moves to the last one (none left: not started).
   */
  async setSegments(callerId: string, roomId: string, body: unknown): Promise<LivePodcastStudioDto> {
    const row = await this.hostedVideoPodcast(roomId, callerId);
    const parsed = livePodcastSegmentsBodySchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const segments = parsed.data.segments.map((g) => ({ title: g.title, minutes: g.minutes ?? null }));
    return this.mutate(row, async (_tx, current, _onStage, now) => {
      if (JSON.stringify(segmentsOf(current.segments)) === JSON.stringify(segments)) return null;
      const index = current.segmentIndex;
      if (segments.length === 0) {
        return { segments, segmentIndex: null, segmentStartedAt: null, closing: false };
      }
      if (index !== null && index >= segments.length) {
        return { segments, segmentIndex: segments.length - 1, segmentStartedAt: now };
      }
      return { segments };
    });
  }

  /**
   * `POST /live/rooms/{roomId}/podcast/segments/next` (host): the first segment, the next one, or after the last
   * the closing card (then nothing changes). No segments → 400 `segments` `required`.
   */
  async nextSegment(callerId: string, roomId: string): Promise<LivePodcastStudioDto> {
    const row = await this.hostedVideoPodcast(roomId, callerId);
    return this.mutate(row, async (_tx, current, _onStage, now) => {
      const count = segmentsOf(current.segments).length;
      if (count === 0) throw AppException.validation([{ field: 'segments', issue: 'required' }]);
      if (current.closing) return null;
      const index = current.segmentIndex;
      if (index === null) return { segmentIndex: 0, segmentStartedAt: now };
      if (index + 1 < count) return { segmentIndex: index + 1, segmentStartedAt: now };
      return { closing: true };
    });
  }

  /**
   * `PUT /live/rooms/{roomId}/podcast/on-screen` (host): shows a hand's question over the video. The hand must be of
   * this room with a question (404), up or seated (409 LIVE_REQUEST_NOT_PENDING); `answerUserId` the host or someone
   * on air (400).
   */
  async showOnScreen(callerId: string, roomId: string, body: unknown): Promise<LivePodcastStudioDto> {
    const row = await this.hostedVideoPodcast(roomId, callerId);
    const parsed = livePodcastOnScreenBodySchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const requestId = parsed.data.requestId.toLowerCase();
    const answer = parsed.data.answerUserId?.toLowerCase() ?? null;
    return this.mutate(row, async (tx, current, onStage, now) => {
      const request = await tx.liveSeatRequest.findFirst({
        where: { id: requestId, roomId: row.id },
        select: { status: true, question: true },
      });
      if (!request || request.question === null) throw notFound();
      if (request.status !== 'PENDING' && request.status !== 'ACCEPTED') {
        throw new AppException(ErrorCode.LIVE_REQUEST_NOT_PENDING);
      }
      if (answer !== null && !onStage.has(answer)) {
        throw AppException.validation([{ field: 'answerUserId', issue: 'invalid_value' }]);
      }
      if (current.onScreenRequestId === requestId && current.answerUserId === answer) return null;
      return { onScreenRequestId: requestId, answerUserId: answer, onScreenAt: now };
    });
  }

  /** `DELETE /live/rooms/{roomId}/podcast/on-screen` (host; idempotent): the question card goes away. */
  async hideOnScreen(callerId: string, roomId: string): Promise<LivePodcastStudioDto> {
    const row = await this.hostedVideoPodcast(roomId, callerId);
    return this.mutate(row, async (_tx, current) =>
      current.onScreenRequestId === null && current.answerUserId === null
        ? null
        : { onScreenRequestId: null, answerUserId: null, onScreenAt: null },
    );
  }

  private async send(roomId: string, data: LivePodcastData): Promise<void> {
    try {
      await this.media.broadcastData(roomId, PODCAST_TOPIC, JSON.stringify(data));
    } catch (err) {
      this.logger.warn(
        { type: data.type, error: safeErrorLog(err) },
        'Could not send a podcast data message',
      );
    }
  }
}
