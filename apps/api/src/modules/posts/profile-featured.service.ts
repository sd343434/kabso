import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { isUuid } from '../auth/tokens.js';
import { isPanelStaff } from '../live/live-staff.js';
import type { AccountCategory } from '../users/profile-fields.js';
import { PostViews, visiblePostWhere, type PostDto } from './post-views.js';
import { PostsService } from './posts.service.js';

type Tx = Prisma.TransactionClient;

/** v1.138-social (D386, §10.175.3): at most 6 featured pins per person. */
export const FEATURED_PIN_MAX = 6;
/** At most 6 items and 6 schedule slots in the section. */
const FEATURED_MAX = 6;

/** `FeaturedSection` (§10.175.2). */
export type FeaturedSection =
  | 'WORKS'
  | 'RECITATIONS'
  | 'STORIES'
  | 'POEMS'
  | 'ARTICLES'
  | 'REPORTS'
  | 'PROGRAM'
  | 'GAMES'
  | 'ACHIEVEMENTS'
  | 'GALLERY'
  | 'MOST_VIEWED'
  | 'HIGHLIGHTS';

/** The section of each category; PUBLIC_FIGURE and OTHER have none. */
export const FEATURED_SECTION_OF: Readonly<Record<AccountCategory, FeaturedSection | null>> = {
  SINGER: 'WORKS',
  MUSICIAN: 'WORKS',
  DJ: 'WORKS',
  QURAN_RECITER: 'RECITATIONS',
  STORYTELLER: 'STORIES',
  POET: 'POEMS',
  WRITER: 'ARTICLES',
  BLOGGER: 'ARTICLES',
  JOURNALIST: 'REPORTS',
  PRESENTER: 'PROGRAM',
  GAMER: 'GAMES',
  ATHLETE: 'ACHIEVEMENTS',
  ARTIST: 'GALLERY',
  PHOTOGRAPHER: 'GALLERY',
  DESIGNER: 'GALLERY',
  CALLIGRAPHER: 'GALLERY',
  CONTENT_CREATOR: 'MOST_VIEWED',
  ACTOR: 'MOST_VIEWED',
  COMEDIAN: 'MOST_VIEWED',
  CHEF: 'HIGHLIGHTS',
  TRAVELER: 'HIGHLIGHTS',
  TEACHER: 'HIGHLIGHTS',
  PUBLIC_FIGURE: null,
  OTHER: null,
};

const VIDEO_KINDS = ['POST_VIDEO', 'REEL_VIDEO'];
const IMAGE_KINDS = ['POST_IMAGE'];

/**
 * The posts the automatic pick takes for a section (newest published first, except MOST_VIEWED); null = none
 * (PROGRAM: only the schedule).
 */
function autoWhere(section: FeaturedSection): Prisma.PostWhereInput | null {
  switch (section) {
    case 'WORKS':
    case 'RECITATIONS':
    case 'STORIES':
      return { media: { some: { mediaAsset: { kind: { in: VIDEO_KINDS } } } } };
    case 'POEMS':
    case 'ARTICLES':
      return { format: 'POST', media: { none: {} }, NOT: { text: '' } };
    case 'REPORTS':
      return { format: 'POST' };
    case 'GAMES':
      return {};
    case 'ACHIEVEMENTS':
    case 'GALLERY':
      return { media: { some: { mediaAsset: { kind: { in: IMAGE_KINDS } } } } };
    case 'MOST_VIEWED':
      return { format: 'REEL' };
    case 'HIGHLIGHTS':
      return { media: { some: {} } };
    case 'PROGRAM':
      return null;
  }
}

/** `LiveScheduleSlot` (the live schedule's own shape). */
export interface FeaturedScheduleDto {
  id: string;
  title: string;
  startsAt: string;
  createdAt: string;
  mode: 'PODCAST' | null;
  podcastTopic: string | null;
  podcastVideo: boolean;
}

/** `ProfileFeatured`. */
export interface ProfileFeaturedDto {
  section: FeaturedSection | null;
  source: 'PINNED' | 'AUTO' | 'NONE';
  items: PostDto[];
  schedule: FeaturedScheduleDto[];
}

/** `FeaturedPinList`. */
export interface FeaturedPinListDto {
  postIds: string[];
  max: number;
}

const EMPTY: ProfileFeaturedDto = { section: null, source: 'NONE', items: [], schedule: [] };

/** A post its author may pin: published, not deleted, not hidden by the team. */
const PINNABLE: Prisma.PostWhereInput = {
  deletedAt: null,
  status: 'PUBLISHED',
  moderation: { not: 'REMOVED' },
};

const setPinsBody = z.strictObject({ postIds: z.array(z.string()).max(64) });

/**
 * v1.138-social (D386, owner 2026-11-12), CONVENTIONS §10.175.2–3: the featured section at the top of a profile whose
 * category the Kabso Team verified, and the person's featured pins (`profile_featured_pins`, ≤ 6, in order).
 */
@Injectable()
export class ProfileFeaturedService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly posts: PostsService,
    private readonly views: PostViews,
    private readonly clock: Clock,
  ) {}

  /** `GET /users/{username}/featured` — the `listUserPosts` visibility (404 the same way). */
  async featured(viewerId: string, username: string): Promise<ProfileFeaturedDto> {
    const authorId = await this.posts.readableAuthor(viewerId, username);
    const profile = await this.prisma.userProfile.findUnique({
      where: { userId: authorId },
      select: { category: true, categoryVerifiedAt: true },
    });
    if (!profile?.category || profile.categoryVerifiedAt === null) return EMPTY;
    const section = FEATURED_SECTION_OF[profile.category];
    // D367: a Kabso Team account shows no category, so no section either.
    if (section === null || (await isPanelStaff(this.prisma, authorId))) return EMPTY;
    const schedule = section === 'PROGRAM' ? await this.schedule(authorId) : [];
    const visible: Prisma.PostWhereInput = { AND: [visiblePostWhere(viewerId), { authorId }] };
    const pins = await this.prisma.profileFeaturedPin.findMany({
      where: { userId: authorId, post: visible },
      orderBy: { position: 'asc' },
      take: FEATURED_MAX,
      select: { postId: true },
    });
    if (pins.length > 0) {
      const items = await this.views.load(
        viewerId,
        pins.map((p) => p.postId),
      );
      return { section, source: 'PINNED', items, schedule };
    }
    const match = autoWhere(section);
    let ids: string[] = [];
    if (match !== null) {
      const rows = await this.prisma.post.findMany({
        where: { AND: [visible, match] },
        orderBy:
          section === 'MOST_VIEWED'
            ? [{ viewCount: 'desc' }, { publishedAt: 'desc' }, { id: 'desc' }]
            : [{ publishedAt: 'desc' }, { id: 'desc' }],
        take: FEATURED_MAX,
        select: { id: true },
      });
      ids = rows.map((r) => r.id);
    }
    const items = ids.length > 0 ? await this.views.load(viewerId, ids) : [];
    const source = items.length > 0 || schedule.length > 0 ? 'AUTO' : 'NONE';
    return { section, source, items, schedule };
  }

  /** PROGRAM: the announced lives and podcast episodes still ahead, soonest first. */
  private async schedule(hostId: string): Promise<FeaturedScheduleDto[]> {
    const rows = await this.prisma.liveScheduleSlot.findMany({
      where: { hostUserId: hostId, startsAt: { gt: this.clock.now() } },
      orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
      take: FEATURED_MAX,
      select: {
        id: true,
        title: true,
        startsAt: true,
        createdAt: true,
        mode: true,
        podcastTopic: true,
        podcastVideo: true,
      },
    });
    return rows.map((r) => ({
      id: r.id,
      title: r.title,
      startsAt: r.startsAt.toISOString(),
      createdAt: r.createdAt.toISOString(),
      mode: r.mode === 'PODCAST' ? 'PODCAST' : null,
      podcastTopic: r.mode === 'PODCAST' ? r.podcastTopic : null,
      podcastVideo: r.mode === 'PODCAST' && r.podcastVideo,
    }));
  }

  // ---- pins -------------------------------------------------------------------------------------------------------

  /** Locks the person's pins (one writer at a time) and drops the pins whose post can no longer be pinned. */
  private async lockAndPrune(tx: Tx, userId: string): Promise<string[]> {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:featured-pin'), hashtext(${userId}))`;
    const rows = await tx.profileFeaturedPin.findMany({
      where: { userId },
      orderBy: { position: 'asc' },
      select: {
        postId: true,
        post: { select: { authorId: true, deletedAt: true, status: true, moderation: true } },
      },
    });
    const kept = rows
      .filter(
        (r) =>
          r.post.authorId === userId &&
          r.post.deletedAt === null &&
          r.post.status === 'PUBLISHED' &&
          r.post.moderation !== 'REMOVED',
      )
      .map((r) => r.postId);
    if (kept.length !== rows.length) await this.writeIn(tx, userId, kept);
    return kept;
  }

  /** Rewrites the person's pins as `postIds`, in order (positions 0…n−1). */
  private async writeIn(tx: Tx, userId: string, postIds: readonly string[]): Promise<void> {
    await tx.profileFeaturedPin.deleteMany({ where: { userId } });
    if (postIds.length === 0) return;
    const now = this.clock.now();
    await tx.profileFeaturedPin.createMany({
      data: postIds.map((postId, position) => ({ userId, postId, position, createdAt: now })),
    });
  }

  private result(postIds: string[]): FeaturedPinListDto {
    return { postIds, max: FEATURED_PIN_MAX };
  }

  /** `GET /me/featured-pins`. */
  async list(userId: string): Promise<FeaturedPinListDto> {
    return this.result(await this.prisma.$transaction((tx) => this.lockAndPrune(tx, userId)));
  }

  /** `PUT /me/featured-pins {postIds}`: the whole set, in order (0–6). */
  async set(userId: string, raw: unknown): Promise<FeaturedPinListDto> {
    const parsed = setPinsBody.safeParse(raw);
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const ids = parsed.data.postIds.map((id) => id.toLowerCase());
    if (ids.length > FEATURED_PIN_MAX)
      throw AppException.validation([{ field: 'postIds', issue: 'too_many' }]);
    const valid = ids.filter(isUuid);
    const own = new Set(
      (
        await this.prisma.post.findMany({
          where: { AND: [{ id: { in: valid } }, { authorId: userId }, PINNABLE] },
          select: { id: true },
        })
      ).map((p) => p.id),
    );
    const seen = new Set<string>();
    const bad = ids.findIndex((id) => {
      const wrong = !own.has(id) || seen.has(id);
      seen.add(id);
      return wrong;
    });
    if (bad >= 0) throw AppException.validation([{ field: `postIds.${bad}`, issue: 'invalid_value' }]);
    return this.result(
      await this.prisma.$transaction(async (tx) => {
        await this.lockAndPrune(tx, userId);
        await this.writeIn(tx, userId, ids);
        return ids;
      }),
    );
  }

  /** `PUT /me/featured-pins/{postId}`: appended at the end; idempotent; a 7th → 409 `FEATURED_PIN_LIMIT`. */
  async pin(userId: string, postId: string): Promise<FeaturedPinListDto> {
    if (!isUuid(postId)) throw new AppException(ErrorCode.NOT_FOUND);
    const id = postId.toLowerCase();
    return this.result(
      await this.prisma.$transaction(async (tx) => {
        const post = await tx.post.findFirst({
          where: { AND: [{ id }, { authorId: userId }, PINNABLE] },
          select: { id: true },
        });
        if (!post) throw new AppException(ErrorCode.NOT_FOUND);
        const kept = await this.lockAndPrune(tx, userId);
        if (kept.includes(id)) return kept;
        if (kept.length >= FEATURED_PIN_MAX) {
          throw new AppException(ErrorCode.FEATURED_PIN_LIMIT, undefined, [
            { field: 'pins', issue: 'too_many' },
          ]);
        }
        const next = [...kept, id];
        await this.writeIn(tx, userId, next);
        return next;
      }),
    );
  }

  /** `DELETE /me/featured-pins/{postId}` (idempotent; the others keep their order). */
  async unpin(userId: string, postId: string): Promise<FeaturedPinListDto> {
    const id = isUuid(postId) ? postId.toLowerCase() : null;
    return this.result(
      await this.prisma.$transaction(async (tx) => {
        const kept = await this.lockAndPrune(tx, userId);
        if (id === null || !kept.includes(id)) return kept;
        const next = kept.filter((p) => p !== id);
        await this.writeIn(tx, userId, next);
        return next;
      }),
    );
  }
}
