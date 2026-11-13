import type { Prisma } from '../../generated/prisma/client.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import type { UserSummaryDto } from './live-rooms.service.js';
import { PODCAST_LOCK_LAYOUTS, type PodcastLockLayout } from './live.schemas.js';

/**
 * v1.114-live (D363, CONVENTIONS §10.157, owner scope extension 2026-11-11): a video podcast's studio state, as
 * everyone reads it (`LiveSeats.studio`) and as the `studio` data message carries it.
 */

/** `LivePodcastSegment`. */
export interface LivePodcastSegmentDto {
  title: string;
  minutes: number | null;
}

/** `LivePodcastOnScreen`: the listener question the host shows over the video. */
export interface LivePodcastOnScreenDto {
  requestId: string;
  user: UserSummaryDto;
  question: string;
  /** Who answers (the director prefers them while the card is up); null = whoever speaks. */
  answerUserId: string | null;
  at: string;
}

/** `LivePodcastStudio`. */
export interface LivePodcastStudioDto {
  seq: number;
  pinUserId: string | null;
  layout: PodcastLockLayout | null;
  segments: LivePodcastSegmentDto[];
  segmentIndex: number | null;
  segmentStartedAt: string | null;
  closing: boolean;
  onScreen: LivePodcastOnScreenDto | null;
}

/** The studio of a room that never changed it: the automatic director, no segments, nothing on screen. */
export const EMPTY_STUDIO: LivePodcastStudioDto = {
  seq: 0,
  pinUserId: null,
  layout: null,
  segments: [],
  segmentIndex: null,
  segmentStartedAt: null,
  closing: false,
  onScreen: null,
};

/** The stored `segments` JSON as DTOs (anything malformed is skipped; the CHECK keeps it an array of ≤ 8). */
export function segmentsOf(raw: Prisma.JsonValue): LivePodcastSegmentDto[] {
  if (!Array.isArray(raw)) return [];
  const out: LivePodcastSegmentDto[] = [];
  for (const item of raw) {
    if (item === null || typeof item !== 'object' || Array.isArray(item)) continue;
    const title = item['title'];
    const minutes = item['minutes'];
    if (typeof title !== 'string') continue;
    out.push({ title, minutes: typeof minutes === 'number' ? minutes : null });
  }
  return out;
}

function layoutOf(raw: string | null): PodcastLockLayout | null {
  return (PODCAST_LOCK_LAYOUTS as readonly string[]).includes(raw ?? '') ? (raw as PodcastLockLayout) : null;
}

/**
 * Reads a room's studio. [onStage] are the host and the people seated on air (not backstage): a pinned or answering
 * person who left reads as null. [mask] masks the host's blocked words in the question (§10.11).
 */
export async function readStudio(
  db: Prisma.TransactionClient,
  roomId: string,
  onStage: ReadonlySet<string>,
  mask: (text: string) => string,
): Promise<LivePodcastStudioDto> {
  const row = await db.livePodcastStudio.findUnique({
    where: { roomId },
    include: {
      onScreenRequest: { select: { id: true, question: true, user: { select: USER_SUMMARY_SELECT } } },
    },
  });
  if (!row) return { ...EMPTY_STUDIO };
  const shown = row.onScreenRequest;
  return {
    seq: row.seq,
    pinUserId: row.pinUserId !== null && onStage.has(row.pinUserId) ? row.pinUserId : null,
    layout: layoutOf(row.layout),
    segments: segmentsOf(row.segments),
    segmentIndex: row.segmentIndex,
    segmentStartedAt: row.segmentStartedAt?.toISOString() ?? null,
    closing: row.closing,
    onScreen:
      shown && shown.question !== null
        ? {
            requestId: shown.id,
            user: userSummary(shown.user),
            question: mask(shown.question),
            answerUserId:
              row.answerUserId !== null && onStage.has(row.answerUserId) ? row.answerUserId : null,
            at: (row.onScreenAt ?? row.updatedAt).toISOString(),
          }
        : null,
  };
}
