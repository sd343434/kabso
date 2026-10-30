import { Injectable } from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { hostAgentPerksActive } from '../economy/host-agents.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { MediaService, type MediaAssetDto } from '../media/media.service.js';
import { parseHashtags, parseMentions } from './text-entities.js';

/** `Post` (openapi v1.5-social). */
export interface PostDto {
  id: string;
  /** v1.41-social (D162): `REEL` — one vertical video (Moments). */
  format: 'POST' | 'REEL';
  author: UserSummaryDto;
  text: string;
  media: MediaAssetDto[];
  location: string | null;
  hashtags: string[];
  mentions: UserSummaryDto[];
  status: 'DRAFT' | 'SCHEDULED' | 'PUBLISHED';
  createdAt: string;
  publishAt: string | null;
  publishedAt: string | null;
  editedAt: string | null;
  pinned: boolean;
  likeCount: number | null;
  commentCount: number;
  shareCount: number;
  repostCount: number;
  viewCount: number;
  viewerHasLiked: boolean;
  viewerHasSaved: boolean;
  viewerHasReposted: boolean;
  isSelf: boolean;
  settings: {
    commentsEnabled: boolean;
    whoCanComment: 'EVERYONE' | 'FOLLOWERS' | 'NOBODY';
    hideLikeCount: boolean;
  };
  moderation: 'VISIBLE' | 'PENDING';
  repostedBy: UserSummaryDto | null;
}

export interface PageDto<T> {
  data: T[];
  page: { nextCursor: string | null; hasMore: boolean };
}

const PROFILE_SELECT = { username: true, displayName: true, avatarUrl: true, premiumTier: true } as const;

/** A user row with its profile → `UserSummary` (never an email). */
export function userSummary(user: {
  id: string;
  profile: {
    username: string;
    displayName: string;
    avatarUrl: string | null;
    /** v1.28-live (D146); absent in older selects. */
    premiumTier?: 'LEGEND' | 'RUBY' | 'GOLD' | 'SILVER' | null;
  } | null;
  /** v1.54-social (D185); absent in older selects. */
  status?: string;
  rechargeAgent?: { status: string; code: string | null } | null;
  /** v1.58-social (D189); absent in older selects. */
  ownedAgency?: { hostCode: string | null; suspendedAt: Date | null } | null;
  /** v1.55-social (D186); absent in older selects. */
  bagItems?: readonly WornFrameRow[];
}): UserSummaryDto {
  const tier = user.profile?.premiumTier;
  const agentCode = rechargeAgentCodeOf(user);
  const hostCode = hostAgentCodeOf(user);
  const frame = wornAvatarFrameOf(user.bagItems);
  return {
    id: user.id,
    username: user.profile?.username ?? '',
    displayName: user.profile?.displayName ?? '',
    avatarUrl: user.profile?.avatarUrl ?? null,
    // v1.28-live (D146): only while the username is a premium one (absent otherwise).
    ...(tier ? { premiumTier: tier } : {}),
    // v1.54-social (D185, §10.48): only while an ACTIVE recharge agent with an active account (the badge).
    ...(agentCode ? { rechargeAgent: { code: agentCode } } : {}),
    // v1.58-social (D189, §10.52): only while a host agent (agency not suspended) with an active account.
    ...(hostCode ? { hostAgent: { code: hostCode } } : {}),
    // v1.55-social (D186, §10.49): only while the user wears an avatar frame (live seats draw it).
    ...(frame ? { avatarFrame: frame } : {}),
  };
}

/**
 * v1.58-social (D189, §10.52): the host-agent code to show, or null — the person owns an agency with a code that
 * the team has not suspended (any rank, LAPSED too) and the account is active.
 */
export function hostAgentCodeOf(user: {
  status?: string;
  ownedAgency?: { hostCode: string | null; suspendedAt: Date | null } | null;
}): string | null {
  const agency = user.ownedAgency;
  if (!agency || !hostAgentPerksActive(agency)) return null;
  if (user.status !== undefined && user.status !== 'ACTIVE') return null;
  return agency.hostCode;
}

/** v1.55-social (D186): a worn AVATAR_FRAME row of {@link USER_SUMMARY_SELECT}. */
export interface WornFrameRow {
  readonly itemCode: string;
  readonly expiresAt: Date | null;
  readonly item: { readonly assetKey: string };
}

/** v1.55-social (D186): the avatar frame worn now (`AvatarFrame`), or null (an expired one is not worn). */
export function wornAvatarFrameOf(
  rows: readonly WornFrameRow[] | undefined,
  now: Date = new Date(),
): { code: string; assetKey: string } | null {
  const row = rows?.find((r) => r.expiresAt === null || r.expiresAt > now);
  return row ? { code: row.itemCode, assetKey: row.item.assetKey } : null;
}

/** v1.54-social (D185): the recharge-agent code to show, or null (not ACTIVE, or the account is not active). */
export function rechargeAgentCodeOf(user: {
  status?: string;
  rechargeAgent?: { status: string; code: string | null } | null;
}): string | null {
  const agent = user.rechargeAgent;
  if (!agent || agent.status !== 'ACTIVE' || agent.code === null) return null;
  if (user.status !== undefined && user.status !== 'ACTIVE') return null;
  return agent.code;
}

export const USER_SUMMARY_SELECT = {
  id: true,
  profile: { select: PROFILE_SELECT },
  // v1.54-social (D185): the recharge-agent badge (`UserSummary.rechargeAgent`).
  status: true,
  rechargeAgent: { select: { status: true, code: true } },
  // v1.58-social (D189): the host-agent badge (`UserSummary.hostAgent`).
  ownedAgency: { select: { hostCode: true, suspendedAt: true } },
  // v1.55-social (D186): the avatar frame worn (`UserSummary.avatarFrame`; at most one per category).
  bagItems: {
    where: { category: 'AVATAR_FRAME', equipped: true },
    select: { itemCode: true, expiresAt: true, item: { select: { assetKey: true } } },
    take: 1,
  },
} as const;

/**
 * v1.54-social (D185, §10.48.1): a mentioned user, with the names an older text may still use for them — the
 * base username behind an ACTIVE special one, a special one in grace. Read only to link the text; never
 * returned (the summary carries the username shown now).
 */
export const MENTION_USER_SELECT = {
  ...USER_SUMMARY_SELECT,
  specialUsernames: {
    where: { status: { in: ['ACTIVE', 'GRACE'] } },
    select: { username: true, baseUsername: true, status: true },
  },
} as const satisfies Prisma.UserSelect;

/** The mentioned users by the name in the text: the shown username first, then the older names. */
export function mentionedByName(
  rows: readonly {
    user: Parameters<typeof userSummary>[0] & {
      specialUsernames: readonly { username: string; baseUsername: string; status: string }[];
    };
  }[],
): Map<string, UserSummaryDto> {
  const map = new Map<string, UserSummaryDto>();
  for (const m of rows) map.set(m.user.profile?.username ?? '', userSummary(m.user));
  for (const m of rows) {
    for (const s of m.user.specialUsernames) {
      const alias = s.status === 'ACTIVE' ? s.baseUsername : s.username;
      if (!map.has(alias)) map.set(alias, userSummary(m.user));
    }
  }
  return map;
}

/**
 * Posts a viewer may see in lists and by id (CONVENTIONS §11.2): published, not deleted, not
 * removed; the author ACTIVE and no block either way; and either the viewer's own post, or a
 * VISIBLE post of a public author or of an author the viewer follows. Drafts and scheduled posts
 * are added by the callers that may show them (the author's own lists).
 */
export function visiblePostWhere(viewerId: string): Prisma.PostWhereInput {
  return {
    deletedAt: null,
    status: 'PUBLISHED',
    moderation: { not: 'REMOVED' },
    author: {
      status: 'ACTIVE',
      blocking: { none: { blockedId: viewerId } },
      blockedBy: { none: { blockerId: viewerId } },
    },
    OR: [
      { authorId: viewerId },
      {
        moderation: 'VISIBLE',
        author: {
          OR: [
            { settings: { is: null } },
            { settings: { is: { isPrivate: false } } },
            { followers: { some: { followerId: viewerId } } },
          ],
        },
      },
    ],
  };
}

/**
 * The same rule as {@link visiblePostWhere} in SQL, for post `p` joined with its author `a` and
 * the author's settings `s` (LEFT JOIN user_settings). Feeds also leave out muted authors and
 * hidden posts; hashtag pages leave out hidden posts (CONVENTIONS §11.7).
 */
export function visiblePostSql(
  viewer: string,
  options: { excludeMuted: boolean; excludeHidden: boolean },
): Prisma.Sql {
  return Prisma.sql`
    p.status = 'PUBLISHED'::post_status AND p.deleted_at IS NULL
    AND (p.moderation = 'VISIBLE'::post_moderation
         OR (p.author_id = ${viewer}::uuid AND p.moderation <> 'REMOVED'::post_moderation))
    AND a.status = 'ACTIVE'::user_status
    AND NOT EXISTS (SELECT 1 FROM user_blocks b
                     WHERE (b.blocker_id = a.id AND b.blocked_id = ${viewer}::uuid)
                        OR (b.blocker_id = ${viewer}::uuid AND b.blocked_id = a.id))
    AND (p.author_id = ${viewer}::uuid OR COALESCE(s.is_private, false) = false
         OR EXISTS (SELECT 1 FROM follows f2 WHERE f2.follower_id = ${viewer}::uuid AND f2.followee_id = a.id))
    ${
      options.excludeMuted
        ? Prisma.sql`AND NOT EXISTS (SELECT 1 FROM user_mutes m WHERE m.muter_id = ${viewer}::uuid AND m.muted_id = a.id)`
        : Prisma.empty
    }
    ${
      options.excludeHidden
        ? Prisma.sql`AND NOT EXISTS (SELECT 1 FROM post_hides h WHERE h.user_id = ${viewer}::uuid AND h.post_id = p.id)`
        : Prisma.empty
    }`;
}

function include(viewerId: string) {
  return {
    author: { select: USER_SUMMARY_SELECT },
    media: { orderBy: { position: 'asc' }, include: { mediaAsset: true } },
    mentions: { where: { user: { status: 'ACTIVE' } }, include: { user: { select: MENTION_USER_SELECT } } },
    hashtags: { include: { hashtag: true } },
    pin: { select: { postId: true } },
    likes: { where: { userId: viewerId }, select: { userId: true }, take: 1 },
    saves: { where: { userId: viewerId }, select: { userId: true }, take: 1 },
    reposts: { where: { userId: viewerId }, select: { userId: true }, take: 1 },
  } satisfies Prisma.PostInclude;
}

type PostRow = Prisma.PostGetPayload<{ include: ReturnType<typeof include> }>;

/** Builds `Post` bodies for one viewer, in the order asked (missing ids are skipped). */
@Injectable()
export class PostViews {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
  ) {}

  async load(
    viewerId: string,
    ids: readonly string[],
    repostedBy: ReadonlyMap<string, UserSummaryDto> = new Map(),
    db: Prisma.TransactionClient = this.prisma,
  ): Promise<PostDto[]> {
    if (ids.length === 0) return [];
    const rows = await db.post.findMany({ where: { id: { in: [...ids] } }, include: include(viewerId) });
    const byId = new Map(rows.map((r) => [r.id, r]));
    return ids.flatMap((id) => {
      const row = byId.get(id);
      return row ? [this.toDto(viewerId, row, repostedBy.get(id) ?? null)] : [];
    });
  }

  async one(viewerId: string, id: string, db: Prisma.TransactionClient = this.prisma): Promise<PostDto> {
    const [dto] = await this.load(viewerId, [id], new Map(), db);
    if (!dto) throw new Error(`post ${id} vanished`);
    return dto;
  }

  private toDto(viewerId: string, row: PostRow, repostedBy: UserSummaryDto | null): PostDto {
    const isSelf = row.authorId === viewerId;
    // Order follows the text; only linked (stored) entities are returned.
    const storedTags = new Set(row.hashtags.map((h) => h.hashtag.tag));
    const mentioned = mentionedByName(row.mentions);
    return {
      id: row.id,
      format: row.format,
      author: userSummary(row.author),
      text: row.text,
      media: row.media.map((m) => this.media.toDto(m.mediaAsset)),
      location: row.location,
      hashtags: parseHashtags(row.text).filter((t) => storedTags.has(t)),
      mentions: parseMentions(row.text).flatMap((u) => {
        const user = mentioned.get(u);
        return user ? [user] : [];
      }),
      status: row.status,
      createdAt: row.createdAt.toISOString(),
      publishAt: row.status === 'SCHEDULED' ? (row.publishAt?.toISOString() ?? null) : null,
      publishedAt: row.publishedAt?.toISOString() ?? null,
      editedAt: row.editedAt?.toISOString() ?? null,
      pinned: row.pin !== null,
      likeCount: row.hideLikeCount && !isSelf ? null : row.likeCount,
      commentCount: row.commentCount,
      shareCount: row.shareCount,
      repostCount: row.repostCount,
      viewCount: row.viewCount,
      viewerHasLiked: row.likes.length > 0,
      viewerHasSaved: row.saves.length > 0,
      viewerHasReposted: row.reposts.length > 0,
      isSelf,
      settings: {
        commentsEnabled: row.commentsEnabled,
        whoCanComment: row.whoCanComment,
        hideLikeCount: row.hideLikeCount,
      },
      moderation: row.moderation === 'PENDING' ? 'PENDING' : 'VISIBLE',
      repostedBy,
    };
  }
}
