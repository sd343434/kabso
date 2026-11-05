import { Injectable } from '@nestjs/common';
import { Prisma, type AdminPermission } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { hostAgentPerksActive } from '../economy/host-agents.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { MediaService, type MediaAssetDto } from '../media/media.service.js';
import { activeRechargeBadge } from '../recharge/recharge-badges.js';
import { parseHashtags, parseMentions } from './text-entities.js';
import { vipNotWorn } from '../vip/vip-bag.js';
import { STORE_ART_SELECT, storeWearOf, type StoreArtRow } from '../store/store-rules.js';
import { isTeamAvatarUrl } from '../live/staff-avatar.js';
import { summaryStaffIdOf } from '../users/staff-ids.js';

/** `Post` (openapi v1.5-social). */
export interface PostDto {
  id: string;
  /** v1.41-social (D162): `REEL` — one vertical video (Moments). */
  format: 'POST' | 'REEL';
  /** v1.72-live (D283, §10.96.10): an official announcement «إعلان رسمي — فريق كابسو». */
  announcement: boolean;
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
  /** v1.76-social (D218): the caller follows the author (false on the caller's own post). */
  viewerFollowsAuthor: boolean;
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

/**
 * A user row with its profile → `UserSummary` (never an email). `now`: when the daily recharge badge
 * (v1.56-social, D187) is checked (the badge shows only while its `until` is after it).
 */
export function userSummary(
  user: {
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
    /** v1.55-social (D186); absent in older selects. */
    bagItems?: readonly WornFrameRow[];
    /** v1.56-social (D187); absent in older selects. */
    rechargeBadge?: { tier: number; until: Date } | null;
    /** v1.58-social (D189); absent in older selects. */
    ownedAgency?: { hostCode: string | null; suspendedAt: Date | null; status?: 'OPEN' | 'CLOSED' } | null;
    /** v1.83-social (D258); absent in older selects. */
    vipMembership?: {
      expiresAt: Date;
      offPerks?: string[];
      tier: { code: string; sortOrder: number; color: string };
    } | null;
    /** v1.73-live (D283c); absent in older selects. */
    role?: string;
    staffNumber?: { number: number } | null;
    adminPermissions?: readonly { permission: string }[];
  },
  now: Date = new Date(),
): UserSummaryDto {
  const tier = user.profile?.premiumTier;
  const agentCode = rechargeAgentCodeOf(user);
  const hostCode = hostAgentCodeOf(user);
  const wornFrame = wornAvatarFrameOf(user.bagItems, now);
  // A recharge agent (from approval on) never shows the daily recharge badge.
  const badge = activeRechargeBadge(user.rechargeBadge, now, (user.rechargeAgent ?? null) !== null);
  // v1.72-live (D283, §10.96.10): the Kabso Team's fixed picture marks a limited staff account — it wears the team
  // frame (the app's) only: no bag / VIP / store frame or wear.
  const team = isTeamAvatarUrl(user.profile?.avatarUrl);
  const frame = team ? null : wornFrame;
  const vip = team ? null : activeVipOf(user, now);
  // D270 (§10.98): the store items worn — only for an active account, as the other badges.
  const wear =
    !team && (user.status === undefined || user.status === 'ACTIVE') ? storeWearOf(user.bagItems, now) : null;
  const staffId = summaryStaffIdOf(user);
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
    // v1.56-social (D187, §10.50): only while the daily recharge badge is showing.
    ...(badge ? { rechargeBadge: badge } : {}),
    // v1.83-social (D258, §10.94): only while the VIP membership is active (and the account is).
    ...(vip ? { vip } : {}),
    // D270 (§10.98): only while the user wears a store item.
    ...(wear ? { wear } : {}),
    // v1.73-live (D283c, §10.96.12): only while a panel role is held (the apps show it instead of the @username).
    ...(staffId ? { staffId } : {}),
  };
}

/**
 * v1.83-social (D258, §10.94): the active VIP to show, or null. v1.65-live (D264, §10.97): `off` — the tier items not
 * worn: taken off in the bag, or covered by a bag item worn of the same kind (one frame, one card: [bagWorn] are the
 * categories of the stored items worn now; by default those of `user.bagItems`).
 */
export function activeVipOf(
  user: {
    status?: string;
    bagItems?: readonly WornFrameRow[];
    vipMembership?: {
      expiresAt: Date;
      offPerks?: string[];
      tier: { code: string; sortOrder: number; color: string };
    } | null;
  },
  now: Date,
  bagWorn?: readonly string[],
): { tier: string; rank: number; color: string; off?: string[] } | null {
  const m = user.vipMembership;
  if (!m || m.expiresAt.getTime() <= now.getTime()) return null;
  if (user.status !== undefined && user.status !== 'ACTIVE') return null;
  const worn =
    bagWorn ??
    (user.bagItems ?? [])
      .filter((r) => r.expiresAt === null || r.expiresAt > now)
      .map((r) => r.category ?? 'AVATAR_FRAME');
  const off = vipNotWorn(m.offPerks ?? [], worn);
  return {
    tier: m.tier.code,
    rank: m.tier.sortOrder,
    color: m.tier.color,
    ...(off.length > 0 ? { off } : {}),
  };
}

/**
 * v1.58-social (D189, §10.52): the host-agent code to show, or null — the person owns an agency with a code that
 * the team has not suspended (any rank, LAPSED too) and the account is active.
 */
export function hostAgentCodeOf(user: {
  status?: string;
  ownedAgency?: { hostCode: string | null; suspendedAt: Date | null; status?: 'OPEN' | 'CLOSED' } | null;
}): string | null {
  const agency = user.ownedAgency;
  if (!agency || !hostAgentPerksActive(agency)) return null;
  if (user.status !== undefined && user.status !== 'ACTIVE') return null;
  return agency.hostCode;
}

/** v1.55-social (D186): a worn AVATAR_FRAME row of {@link USER_SUMMARY_SELECT} (v1.65-live: or PROFILE_CARD). */
export interface WornFrameRow {
  /** v1.65-live (D264); absent in older selects (an AVATAR_FRAME then). */
  readonly category?: string;
  readonly itemCode: string;
  readonly expiresAt: Date | null;
  /** D270 (§10.98): `storeItem` — a store item's art (absent in older selects; null: not a store item). */
  readonly item: { readonly assetKey: string; readonly storeItem?: StoreArtRow | null };
}

/** v1.55-social (D186): the avatar frame worn now (`AvatarFrame`), or null (an expired one is not worn). */
export function wornAvatarFrameOf(
  rows: readonly WornFrameRow[] | undefined,
  now: Date = new Date(),
): { code: string; assetKey: string } | null {
  // D270: a store frame is drawn from its hosted art (`UserSummary.wear.avatarFrame`), not a bundled asset.
  const row = rows?.find(
    (r) =>
      (r.category ?? 'AVATAR_FRAME') === 'AVATAR_FRAME' &&
      !r.item.storeItem &&
      (r.expiresAt === null || r.expiresAt > now),
  );
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
  ownedAgency: { select: { hostCode: true, suspendedAt: true, status: true } },
  // v1.55-social (D186): the avatar frame worn (`UserSummary.avatarFrame`; at most one per category).
  // v1.65-live (D264, §10.97): and whether a profile card is worn (it covers the VIP card: one worn item per kind).
  // D270 (§10.98): and the store items worn (bubble, banner, car too: `UserSummary.wear`; one worn per category).
  bagItems: {
    where: {
      category: {
        in: ['AVATAR_FRAME', 'PROFILE_CARD', 'CHAT_BUBBLE', 'ENTRY_BANNER', 'ENTRY_EFFECT'] as (
          'AVATAR_FRAME' | 'PROFILE_CARD' | 'CHAT_BUBBLE' | 'ENTRY_BANNER' | 'ENTRY_EFFECT'
        )[],
      },
      equipped: true,
    },
    select: {
      category: true,
      itemCode: true,
      expiresAt: true,
      item: { select: { assetKey: true, storeItem: { select: STORE_ART_SELECT } } },
    },
    take: 5,
  },
  // v1.56-social (D187): the daily recharge badge (`UserSummary.rechargeBadge`).
  rechargeBadge: { select: { tier: true, until: true } },
  // v1.83-social (D258, §10.94): the VIP membership (`UserSummary.vip` while active).
  vipMembership: {
    select: {
      expiresAt: true,
      offPerks: true,
      tier: { select: { code: true, sortOrder: true, color: true } },
    },
  },
  // v1.73-live (D283c, §10.96.12): the staff ID (`UserSummary.staffId` while a panel role is held).
  role: true,
  staffNumber: { select: { number: true } },
  adminPermissions: {
    where: { permission: { in: ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'] as AdminPermission[] } },
    select: { permission: true },
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
    // D218: whom of these authors the caller follows (the feed's «متابعة» pill).
    const authorIds = [...new Set(rows.map((r) => r.authorId).filter((a) => a !== viewerId))];
    const followed =
      authorIds.length === 0
        ? new Set<string>()
        : new Set(
            (
              await db.follow.findMany({
                where: { followerId: viewerId, followeeId: { in: authorIds } },
                select: { followeeId: true },
              })
            ).map((f) => f.followeeId),
          );
    return ids.flatMap((id) => {
      const row = byId.get(id);
      return row ? [this.toDto(viewerId, row, repostedBy.get(id) ?? null, followed.has(row.authorId))] : [];
    });
  }

  async one(viewerId: string, id: string, db: Prisma.TransactionClient = this.prisma): Promise<PostDto> {
    const [dto] = await this.load(viewerId, [id], new Map(), db);
    if (!dto) throw new Error(`post ${id} vanished`);
    return dto;
  }

  private toDto(
    viewerId: string,
    row: PostRow,
    repostedBy: UserSummaryDto | null,
    followsAuthor: boolean,
  ): PostDto {
    const isSelf = row.authorId === viewerId;
    // Order follows the text; only linked (stored) entities are returned.
    const storedTags = new Set(row.hashtags.map((h) => h.hashtag.tag));
    const mentioned = mentionedByName(row.mentions);
    return {
      id: row.id,
      format: row.format,
      announcement: row.announcement,
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
      viewerFollowsAuthor: !isSelf && followsAuthor,
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
