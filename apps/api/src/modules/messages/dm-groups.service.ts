import { Inject, Injectable } from '@nestjs/common';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma, type DmMessageKind } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { maskBlockedWords } from '../live/live-blocked-words.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { isUuid } from '../live/live.schemas.js';
import { MediaService, type MediaAssetDto } from '../media/media.service.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { blockedEitherWayIn, lockUserPairIn } from '../social/pair-lock.js';
import { assertNotRestricted } from '../users/account-control.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { DmPush } from './dm-push.js';
import {
  dmGroupAddMembersSchema,
  dmGroupCreateSchema,
  dmGroupRoleSchema,
  dmGroupSendSchema,
  dmGroupUpdateSchema,
  dmReadSchema,
  type DmDeleteMessageQuery,
  type DmGroupCandidatesQuery,
  type DmMessagesQuery,
} from './dm.schemas.js';

// ---- Response shapes (openapi v1.104-social, D339, CONVENTIONS §10.133) -----------------------------------------

export type DmGroupRoleDto = 'ADMIN' | 'MEMBER';

export interface DmGroupMessageDto {
  id: string;
  groupId: string;
  /** null when the sender's account is no longer ACTIVE. */
  sender: UserSummaryDto | null;
  mine: boolean;
  kind: Exclude<DmMessageKind, 'GIFT'>;
  text: string | null;
  token: string | null;
  media: MediaAssetDto | null;
  /** The caller's own message: how many other members have read it (0 on others' messages). */
  readCount: number;
  createdAt: string;
  expiresAt: string;
}

export interface DmGroupDto {
  id: string;
  name: string;
  photoUrl: string | null;
  memberCount: number;
  role: DmGroupRoleDto;
  muted: boolean;
  archived: boolean;
  unreadCount: number;
  lastMessage: DmGroupMessageDto | null;
  lastActivityAt: string;
  createdAt: string;
}

export interface DmGroupMemberDto {
  user: UserSummaryDto;
  role: DmGroupRoleDto;
  creator: boolean;
  joinedAt: string;
}

export interface DmGroupDetailDto {
  group: DmGroupDto;
  members: DmGroupMemberDto[];
  maxMembers: number;
}

export interface DmGroupMessagePageDto extends PageDto<DmGroupMessageDto> {
  group: DmGroupDto;
}

export interface DmGroupSendResultDto {
  message: DmGroupMessageDto;
  group: DmGroupDto;
}

// ---- Rows ---------------------------------------------------------------------------------------------------------

const MESSAGE_INCLUDE = {
  media: true,
  sender: { select: USER_SUMMARY_SELECT },
} as const satisfies Prisma.DmGroupMessageInclude;
type MessageRow = Prisma.DmGroupMessageGetPayload<{ include: typeof MESSAGE_INCLUDE }>;

type MemberRow = Prisma.DmGroupMemberGetPayload<object>;

/** The cap of every unread count (the badge shows "99+"). */
const UNREAD_CAP = 99;
/** The server's blocked words are re-read at most this often. */
const BLOCKED_WORDS_TTL_MS = 60_000;

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

/** A LIKE pattern for the prefix `q` (`\\`, `%` and `_` escaped), as search does (§11.6). */
function likePrefix(q: string): string {
  return `${q.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
}

/**
 * The messages of group member `m` that `me` may read now (SQL over `msg` and `m`): not expired, sent since they
 * joined, by an ACTIVE account with no block either way with them.
 */
function visibleMessageSql(me: string, now: Date): Prisma.Sql {
  return Prisma.sql`msg.expires_at > ${now}::timestamptz AND msg.created_at >= m.joined_at
    AND EXISTS (SELECT 1 FROM users su WHERE su.id = msg.sender_id AND su.status = 'ACTIVE'::user_status)
    AND NOT EXISTS (SELECT 1 FROM user_blocks b
                     WHERE (b.blocker_id = ${me}::uuid AND b.blocked_id = msg.sender_id)
                        OR (b.blocker_id = msg.sender_id AND b.blocked_id = ${me}::uuid))`;
}

/**
 * Group messages «رسائل جماعية» (D339, CONVENTIONS §10.133): a named group with an optional photo, created by a user
 * with people they follow and who follow them back (and who accept messages, §11.13), up to `DM_GROUP_MAX_MEMBERS`;
 * admins add and remove members, rename it, change its photo and the roles; anyone leaves. TEXT / IMAGE / VOICE / EMOJI
 * messages, each living `DM_RETENTION_HOURS` like a direct message; a read pointer per member; mute and archive per
 * member; blocks hide the two people's messages from each other. Membership writes run under the group's row lock.
 */
@Injectable()
export class DmGroupsService {
  private readonly cursors: SocialCursorCodec;
  private serverWords: { at: number; words: string[] } | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly media: MediaService,
    private readonly clock: Clock,
    private readonly background: BackgroundTasks,
    private readonly push: DmPush,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  private get retentionMs(): number {
    return this.config.dm.retentionHours * 3600 * 1000;
  }

  private get maxMembers(): number {
    return this.config.dm.groupMaxMembers;
  }

  // ---- DTOs -------------------------------------------------------------------------------------------------------

  private messageDto(row: MessageRow, callerId: string, readers: readonly MemberRow[]): DmGroupMessageDto {
    const mine = row.senderId === callerId;
    const sender = row.sender.status === 'ACTIVE' ? userSummary(row.sender) : null;
    return {
      id: row.id,
      groupId: row.groupId,
      sender,
      mine,
      kind: row.kind as Exclude<DmMessageKind, 'GIFT'>,
      text: row.text,
      token: row.token,
      media: row.media ? this.media.toDto(row.media) : null,
      readCount: mine
        ? readers.filter((r) => r.userId !== callerId && r.readAt !== null && r.readAt >= row.createdAt)
            .length
        : 0,
      createdAt: row.createdAt.toISOString(),
      expiresAt: row.expiresAt.toISOString(),
    };
  }

  /**
   * The DTOs of the caller's groups `ids` (in that order): ACTIVE groups the caller belongs to; the others are dropped.
   */
  async groupDtos(callerId: string, ids: readonly string[]): Promise<DmGroupDto[]> {
    if (ids.length === 0) return [];
    const now = this.clock.now();
    const visible = visibleMessageSql(callerId, now);
    const rows = await this.prisma.$queryRaw<
      {
        id: string;
        name: string;
        photo_media_id: string | null;
        created_at: Date;
        at: Date;
        role: DmGroupRoleDto;
        muted: boolean;
        archived: boolean;
        member_count: number;
        last_id: string | null;
        unread: number;
      }[]
    >`
      SELECT g.id::text AS id, g.name, g.photo_media_id::text AS photo_media_id, g.created_at,
             GREATEST(g.last_message_at, m.joined_at) AS at, m.role::text AS role, m.muted,
             (m.archived_at IS NOT NULL) AS archived,
             (SELECT count(*)::int FROM dm_group_members x
                JOIN users xu ON xu.id = x.user_id AND xu.status = 'ACTIVE'::user_status
               WHERE x.group_id = g.id) AS member_count,
             (SELECT msg.id::text FROM dm_group_messages msg
               WHERE msg.group_id = g.id AND ${visible}
               ORDER BY msg.created_at DESC, msg.id DESC LIMIT 1) AS last_id,
             (SELECT count(*)::int FROM (
                SELECT 1 FROM dm_group_messages msg
                 WHERE msg.group_id = g.id AND msg.sender_id <> m.user_id AND ${visible}
                   AND (m.read_at IS NULL OR msg.created_at > m.read_at)
                 LIMIT ${UNREAD_CAP}) x) AS unread
        FROM dm_group_members m
        JOIN dm_groups g ON g.id = m.group_id AND g.status = 'ACTIVE'::dm_group_status
       WHERE m.user_id = ${callerId}::uuid AND m.group_id = ANY(${[...ids]}::uuid[])`;
    const lastIds = rows.map((r) => r.last_id).filter((id): id is string => id !== null);
    const photoIds = rows.map((r) => r.photo_media_id).filter((id): id is string => id !== null);
    const [lastRows, photos, readers] = await Promise.all([
      lastIds.length === 0
        ? Promise.resolve([] as MessageRow[])
        : this.prisma.dmGroupMessage.findMany({ where: { id: { in: lastIds } }, include: MESSAGE_INCLUDE }),
      photoIds.length === 0
        ? Promise.resolve([])
        : this.prisma.mediaAsset.findMany({ where: { id: { in: photoIds } } }),
      lastIds.length === 0
        ? Promise.resolve([] as MemberRow[])
        : this.prisma.dmGroupMember.findMany({ where: { groupId: { in: rows.map((r) => r.id) } } }),
    ]);
    const lastOf = new Map(lastRows.map((r) => [r.id, r]));
    const photoOf = new Map(photos.map((p) => [p.id, p]));
    const byId = new Map(rows.map((r) => [r.id, r]));
    const out: DmGroupDto[] = [];
    for (const id of ids) {
      const r = byId.get(id);
      if (!r) continue;
      const last = r.last_id ? (lastOf.get(r.last_id) ?? null) : null;
      const photo = r.photo_media_id ? photoOf.get(r.photo_media_id) : undefined;
      out.push({
        id: r.id,
        name: r.name,
        photoUrl: photo ? this.media.toDto(photo).thumbUrl : null,
        memberCount: r.member_count,
        role: r.role,
        muted: r.muted,
        archived: r.archived,
        unreadCount: Math.min(UNREAD_CAP, r.unread),
        lastMessage: last
          ? this.messageDto(
              last,
              callerId,
              readers.filter((x) => x.groupId === r.id),
            )
          : null,
        lastActivityAt: r.at.toISOString(),
        createdAt: r.created_at.toISOString(),
      });
    }
    return out;
  }

  private async groupDto(callerId: string, groupId: string): Promise<DmGroupDto> {
    const [dto] = await this.groupDtos(callerId, [groupId]);
    if (!dto) throw notFound();
    return dto;
  }

  /** The caller's membership of an ACTIVE group, else 404. */
  private async access(callerId: string, groupId: string): Promise<MemberRow> {
    if (!isUuid(groupId)) throw notFound();
    const row = await this.prisma.dmGroupMember.findFirst({
      where: { groupId: groupId.toLowerCase(), userId: callerId, group: { status: 'ACTIVE' } },
    });
    if (!row) throw notFound();
    return row;
  }

  /** Under the group's row lock: the caller's membership (404) and, with `admin`, the ADMIN role (403). */
  private async lockIn(
    tx: Prisma.TransactionClient,
    callerId: string,
    groupId: string,
    admin: boolean,
  ): Promise<{ me: MemberRow; createdById: string | null }> {
    if (!isUuid(groupId)) throw notFound();
    const id = groupId.toLowerCase();
    const [group] = await tx.$queryRaw<{ created_by_id: string | null }[]>`
      SELECT created_by_id::text AS created_by_id FROM dm_groups
       WHERE id = ${id}::uuid AND status = 'ACTIVE'::dm_group_status FOR UPDATE`;
    if (!group) throw notFound();
    const me = await tx.dmGroupMember.findUnique({
      where: { groupId_userId: { groupId: id, userId: callerId } },
    });
    if (!me) throw notFound();
    if (admin && me.role !== 'ADMIN') throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    return { me, createdById: group.created_by_id };
  }

  /** `GET /dm/groups/{groupId}`: the group, its members (people with a block either way not listed) and the cap. */
  async detail(callerId: string, groupId: string): Promise<DmGroupDetailDto> {
    const me = await this.access(callerId, groupId);
    const [group, members, row] = await Promise.all([
      this.groupDto(callerId, me.groupId),
      this.prisma.dmGroupMember.findMany({
        where: {
          groupId: me.groupId,
          user: {
            status: 'ACTIVE',
            blocking: { none: { blockedId: callerId } },
            blockedBy: { none: { blockerId: callerId } },
          },
        },
        include: { user: { select: USER_SUMMARY_SELECT } },
        orderBy: [{ joinedAt: 'asc' }, { userId: 'asc' }],
      }),
      this.prisma.dmGroup.findUniqueOrThrow({ where: { id: me.groupId }, select: { createdById: true } }),
    ]);
    // Admins first, then the others, each in the order they joined.
    const ordered = [
      ...members.filter((m) => m.role === 'ADMIN'),
      ...members.filter((m) => m.role !== 'ADMIN'),
    ];
    return {
      group,
      members: ordered.map((m) => ({
        user: userSummary(m.user),
        role: m.role,
        creator: m.userId === row.createdById,
        joinedAt: m.joinedAt.toISOString(),
      })),
      maxMembers: this.maxMembers,
    };
  }

  // ---- Who may be added ---------------------------------------------------------------------------------------------

  /**
   * Resolves `usernames` to the people `adderId` may add to a group (CONVENTIONS §10.133): ACTIVE, not the adder, no
   * block either way, a mutual follow (the adder follows them and they follow the adder) and their «من يستطيع مراسلتك»
   * is not NOBODY. Under each pair's lock (the one follow and block use). Any other → 403
   * `DM_GROUP_MEMBER_NOT_ALLOWED` naming each refused entry (`members.<i>`, the same issue whatever the reason: a
   * block is never told).
   */
  private async addableIn(
    tx: Prisma.TransactionClient,
    adderId: string,
    usernames: readonly string[],
  ): Promise<{ id: string; username: string }[]> {
    const out: { id: string; username: string }[] = [];
    const refused: { field: string; issue: string }[] = [];
    for (const [i, name] of usernames.entries()) {
      const user = await this.users.findActivePublicUser(name);
      if (user?.id === adderId) {
        throw AppException.validation([{ field: `members.${String(i)}`, issue: 'invalid_value' }]);
      }
      if (!user) {
        refused.push({ field: `members.${String(i)}`, issue: 'not_allowed' });
        continue;
      }
      await lockUserPairIn(tx, adderId, user.id);
      const [blocked, follows, privacy] = await Promise.all([
        blockedEitherWayIn(tx, adderId, user.id),
        tx.follow.count({
          where: {
            OR: [
              { followerId: adderId, followeeId: user.id },
              { followerId: user.id, followeeId: adderId },
            ],
          },
        }),
        tx.privacySettings.findUnique({ where: { userId: user.id }, select: { whoCanMessage: true } }),
      ]);
      if (blocked || follows < 2 || privacy?.whoCanMessage === 'NOBODY') {
        refused.push({ field: `members.${String(i)}`, issue: 'not_allowed' });
        continue;
      }
      out.push({ id: user.id, username: user.username });
    }
    if (refused.length > 0) throw new AppException(ErrorCode.DM_GROUP_MEMBER_NOT_ALLOWED, undefined, refused);
    return out;
  }

  /** `GET /dm/group-candidates`: the caller's mutual follows they may add, newest follow first. */
  async candidates(callerId: string, query: DmGroupCandidatesQuery): Promise<PageDto<UserSummaryDto>> {
    let groupId: string | null = null;
    if (query.groupId !== undefined) groupId = (await this.access(callerId, query.groupId)).groupId;
    const scope = `dm-group-candidates:${callerId}:${groupId ?? ''}${query.q === undefined ? '' : `:q=${query.q.toLowerCase()}`}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const prefix = query.q === undefined ? null : likePrefix(query.q.toLowerCase());
    const rows = await this.prisma.$queryRaw<{ id: string; at: Date }[]>`
      SELECT f.followee_id::text AS id, f.created_at AS at
        FROM follows f
        JOIN follows back ON back.follower_id = f.followee_id AND back.followee_id = f.follower_id
        JOIN users u ON u.id = f.followee_id AND u.status = 'ACTIVE'::user_status
       WHERE f.follower_id = ${callerId}::uuid
         AND NOT EXISTS (SELECT 1 FROM privacy_settings ps
                          WHERE ps.user_id = f.followee_id AND ps.who_can_message = 'NOBODY'::who_can_message)
         AND NOT EXISTS (SELECT 1 FROM user_blocks b
                          WHERE (b.blocker_id = f.follower_id AND b.blocked_id = f.followee_id)
                             OR (b.blocker_id = f.followee_id AND b.blocked_id = f.follower_id))
         AND (${groupId === null} OR NOT EXISTS (
               SELECT 1 FROM dm_group_members gm
                WHERE gm.group_id = ${groupId ?? '00000000-0000-0000-0000-000000000000'}::uuid
                  AND gm.user_id = f.followee_id))
         AND (${prefix === null} OR EXISTS (
               SELECT 1 FROM user_profiles up
                WHERE up.user_id = f.followee_id
                  AND (lower(up.username) LIKE ${prefix ?? ''} ESCAPE '\\'
                       OR lower(up.display_name) LIKE ${prefix ?? ''} ESCAPE '\\')))
         AND (${after === null} OR (f.created_at, f.followee_id)
                                   < (${after?.at ?? new Date(0)}::timestamptz, ${after?.id ?? '00000000-0000-0000-0000-000000000000'}::uuid))
       ORDER BY f.created_at DESC, f.followee_id DESC
       LIMIT ${query.limit + 1}`;
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const people = await this.prisma.user.findMany({
      where: { id: { in: page.map((r) => r.id) } },
      select: USER_SUMMARY_SELECT,
    });
    const personOf = new Map(people.map((p) => [p.id, userSummary(p)]));
    const last = page[page.length - 1];
    return {
      data: page.map((r) => personOf.get(r.id)).filter((p): p is UserSummaryDto => p !== undefined),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.at, id: last.id }) : null,
      },
    };
  }

  // ---- Lifecycle -------------------------------------------------------------------------------------------------

  /**
   * `POST /dm/groups`: the caller (ADMIN, the creator) and `members` (MEMBER). Order after auth and the rate limit:
   * 400 body → a retry with the same `clientId` (200) → 400 `members.<i>` (oneself) → 409 `DM_GROUP_FULL` → 403
   * `DM_GROUP_MEMBER_NOT_ALLOWED` → 400 `photoMediaId` → stored; the members are told by push (after the response).
   */
  async create(callerId: string, body: unknown): Promise<{ created: boolean; result: DmGroupDetailDto }> {
    const parsed = dmGroupCreateSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const clientId = input.clientId.toLowerCase();
    const first = await this.prisma.dmGroup.findUnique({
      where: { createdById_clientId: { createdById: callerId, clientId } },
      select: { id: true, status: true },
    });
    if (first) {
      const member = await this.prisma.dmGroupMember.count({
        where: { groupId: first.id, userId: callerId },
      });
      if (first.status !== 'ACTIVE' || member === 0) throw notFound();
      return { created: false, result: await this.detail(callerId, first.id) };
    }
    if (input.members.length + 1 > this.maxMembers) throw new AppException(ErrorCode.DM_GROUP_FULL);
    const id = uuidv7();
    let added: { id: string; username: string }[] = [];
    try {
      await this.prisma.$transaction(async (tx) => {
        added = await this.addableIn(tx, callerId, input.members);
        let photoMediaId: string | null = null;
        if (input.photoMediaId !== undefined) {
          const claimed = await this.media.claimAssetsIn(
            tx,
            callerId,
            [input.photoMediaId],
            'DM_GROUP_PHOTO',
          );
          if (claimed === null)
            throw AppException.validation([{ field: 'photoMediaId', issue: 'invalid_value' }]);
          photoMediaId = claimed[0]!.id;
        }
        const at = this.clock.now();
        await tx.dmGroup.create({
          data: {
            id,
            name: input.name,
            photoMediaId,
            createdById: callerId,
            clientId,
            createdAt: at,
            lastMessageAt: at,
          },
        });
        await tx.dmGroupMember.createMany({
          data: [
            { groupId: id, userId: callerId, role: 'ADMIN', joinedAt: at, readAt: at },
            ...added.map((u) => ({ groupId: id, userId: u.id, role: 'MEMBER' as const, joinedAt: at })),
          ],
        });
      });
    } catch (err) {
      if ((violatedUniqueIndex(err) ?? '').includes('dm_groups_client_once')) {
        const raced = await this.prisma.dmGroup.findUnique({
          where: { createdById_clientId: { createdById: callerId, clientId } },
          select: { id: true },
        });
        if (raced) return { created: false, result: await this.detail(callerId, raced.id) };
      }
      throw err;
    }
    this.afterAdded(
      id,
      callerId,
      added.map((u) => u.id),
    );
    return { created: true, result: await this.detail(callerId, id) };
  }

  /** `PATCH /dm/groups/{groupId}` (admins): the name and / or the photo (`null` removes it). */
  async update(callerId: string, groupId: string, body: unknown): Promise<DmGroupDetailDto> {
    const parsed = dmGroupUpdateSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    let old: { id: string; largeKey: string; thumbKey: string } | null = null;
    const id = await this.prisma.$transaction(async (tx) => {
      const { me } = await this.lockIn(tx, callerId, groupId, true);
      const group = await tx.dmGroup.findUniqueOrThrow({
        where: { id: me.groupId },
        select: { photoMediaId: true },
      });
      const data: Prisma.DmGroupUncheckedUpdateInput = {};
      if (input.name !== undefined) data.name = input.name;
      if (input.photoMediaId !== undefined) {
        if (input.photoMediaId === null) {
          data.photoMediaId = null;
        } else {
          const claimed = await this.media.claimAssetsIn(
            tx,
            callerId,
            [input.photoMediaId],
            'DM_GROUP_PHOTO',
          );
          if (claimed === null)
            throw AppException.validation([{ field: 'photoMediaId', issue: 'invalid_value' }]);
          data.photoMediaId = claimed[0]!.id;
        }
        if (group.photoMediaId !== null && group.photoMediaId !== data.photoMediaId) {
          old = await tx.mediaAsset.findUnique({
            where: { id: group.photoMediaId },
            select: { id: true, largeKey: true, thumbKey: true },
          });
        }
      }
      await tx.dmGroup.update({ where: { id: me.groupId }, data });
      return me.groupId;
    });
    const replaced = old as { id: string; largeKey: string; thumbKey: string } | null;
    if (replaced) {
      this.background.run('dm.group.photo', async () => {
        await this.media.purgeAssets([replaced]);
      });
    }
    return this.detail(callerId, id);
  }

  /** `POST /dm/groups/{groupId}/members` (admins): the members are added (ones already in are ignored). */
  async addMembers(callerId: string, groupId: string, body: unknown): Promise<DmGroupDetailDto> {
    const parsed = dmGroupAddMembersSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    let added: string[] = [];
    const id = await this.prisma.$transaction(async (tx) => {
      const { me } = await this.lockIn(tx, callerId, groupId, true);
      const people = await this.addableIn(tx, callerId, parsed.data.members);
      const existing = await tx.dmGroupMember.findMany({
        where: { groupId: me.groupId },
        select: { userId: true },
      });
      const inGroup = new Set(existing.map((e) => e.userId));
      const fresh = people.filter((p) => !inGroup.has(p.id));
      if (existing.length + fresh.length > this.maxMembers) throw new AppException(ErrorCode.DM_GROUP_FULL);
      const at = this.clock.now();
      await tx.dmGroupMember.createMany({
        data: fresh.map((u) => ({
          groupId: me.groupId,
          userId: u.id,
          role: 'MEMBER' as const,
          joinedAt: at,
        })),
        skipDuplicates: true,
      });
      added = fresh.map((u) => u.id);
      return me.groupId;
    });
    this.afterAdded(id, callerId, added);
    return this.detail(callerId, id);
  }

  /**
   * `DELETE /dm/groups/{groupId}/members/{username}` (admins): not oneself (400 `username`, leave instead), not the
   * creator (403 `AUTH_FORBIDDEN`); someone not in the group → 404.
   */
  async removeMember(callerId: string, groupId: string, username: string): Promise<void> {
    const user = await this.users.findActivePublicUser(username.trim().replace(/^@/, '').toLowerCase());
    if (user?.id === callerId) throw AppException.validation([{ field: 'username', issue: 'invalid_value' }]);
    const left = await this.prisma.$transaction(async (tx) => {
      const { me, createdById } = await this.lockIn(tx, callerId, groupId, true);
      if (!user) throw notFound();
      const target = await tx.dmGroupMember.findUnique({
        where: { groupId_userId: { groupId: me.groupId, userId: user.id } },
      });
      if (!target) throw notFound();
      if (target.userId === createdById) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
      await tx.dmGroupMember.delete({ where: { groupId_userId: { groupId: me.groupId, userId: user.id } } });
      return this.afterLeaveIn(tx, me.groupId);
    });
    if (left.ended) this.purgePhoto(left.photo);
  }

  /** `PUT /dm/groups/{groupId}/members/{username}/role` (admins): not oneself (400), not the creator (403). */
  async setRole(callerId: string, groupId: string, username: string, body: unknown): Promise<void> {
    const parsed = dmGroupRoleSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const user = await this.users.findActivePublicUser(username.trim().replace(/^@/, '').toLowerCase());
    if (user?.id === callerId) throw AppException.validation([{ field: 'username', issue: 'invalid_value' }]);
    await this.prisma.$transaction(async (tx) => {
      const { me, createdById } = await this.lockIn(tx, callerId, groupId, true);
      if (!user) throw notFound();
      const target = await tx.dmGroupMember.findUnique({
        where: { groupId_userId: { groupId: me.groupId, userId: user.id } },
      });
      if (!target) throw notFound();
      if (target.userId === createdById) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
      await tx.dmGroupMember.update({
        where: { groupId_userId: { groupId: me.groupId, userId: user.id } },
        data: { role: parsed.data.role },
      });
    });
  }

  /** `POST /dm/groups/{groupId}/leave`: the caller leaves (the last admin hands the role on; the last member ends it). */
  async leave(callerId: string, groupId: string): Promise<void> {
    const left = await this.prisma.$transaction(async (tx) => {
      const { me } = await this.lockIn(tx, callerId, groupId, false);
      await tx.dmGroupMember.delete({ where: { groupId_userId: { groupId: me.groupId, userId: callerId } } });
      return this.afterLeaveIn(tx, me.groupId);
    });
    if (left.ended) this.purgePhoto(left.photo);
  }

  /**
   * After someone left or was removed (under the group's lock): with no admin left, the member who joined first
   * becomes one; with nobody left, every message expires now (the sweeper deletes them and their files) and the photo
   * goes — the group cannot be opened again.
   */
  private async afterLeaveIn(
    tx: Prisma.TransactionClient,
    groupId: string,
  ): Promise<{ ended: boolean; photo: string | null }> {
    const rest = await tx.dmGroupMember.findMany({
      where: { groupId },
      orderBy: [{ joinedAt: 'asc' }, { userId: 'asc' }],
      select: { userId: true, role: true },
    });
    if (rest.length === 0) {
      const now = this.clock.now();
      await tx.dmGroupMessage.updateMany({
        where: { groupId, expiresAt: { gt: now } },
        data: { expiresAt: now },
      });
      const group = await tx.dmGroup.findUniqueOrThrow({
        where: { id: groupId },
        select: { photoMediaId: true },
      });
      await tx.dmGroup.update({ where: { id: groupId }, data: { photoMediaId: null } });
      return { ended: true, photo: group.photoMediaId };
    }
    if (!rest.some((m) => m.role === 'ADMIN')) {
      await tx.dmGroupMember.update({
        where: { groupId_userId: { groupId, userId: rest[0]!.userId } },
        data: { role: 'ADMIN' },
      });
    }
    return { ended: false, photo: null };
  }

  private purgePhoto(mediaId: string | null): void {
    if (mediaId === null) return;
    this.background.run('dm.group.photo', async () => {
      const asset = await this.prisma.mediaAsset.findUnique({
        where: { id: mediaId },
        select: { id: true, largeKey: true, thumbKey: true },
      });
      if (asset) await this.media.purgeAssets([asset]);
    });
  }

  // ---- Messages --------------------------------------------------------------------------------------------------

  /** `GET /dm/groups/{groupId}/messages`: newest first, what the caller may read. */
  async messages(callerId: string, groupId: string, query: DmMessagesQuery): Promise<DmGroupMessagePageDto> {
    const me = await this.access(callerId, groupId);
    const scope = `dm-group-messages:${me.groupId}:${callerId}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const now = this.clock.now();
    const [rows, group, readers] = await Promise.all([
      this.prisma.dmGroupMessage.findMany({
        where: {
          groupId: me.groupId,
          expiresAt: { gt: now },
          createdAt: { gte: me.joinedAt },
          sender: {
            status: 'ACTIVE',
            blocking: { none: { blockedId: callerId } },
            blockedBy: { none: { blockerId: callerId } },
          },
          ...(after
            ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
            : {}),
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: query.limit + 1,
        include: MESSAGE_INCLUDE,
      }),
      this.groupDto(callerId, me.groupId),
      this.prisma.dmGroupMember.findMany({ where: { groupId: me.groupId } }),
    ]);
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];
    return {
      data: page.map((r) => this.messageDto(r, callerId, readers)),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
      group,
    };
  }

  /** The server's blocked words (§11.11); a group has no single recipient whose own live words would apply. */
  private async blockedWords(): Promise<string[]> {
    const nowMs = Date.now();
    if (this.serverWords === null || nowMs - this.serverWords.at > BLOCKED_WORDS_TTL_MS) {
      const rows = await this.prisma.searchBlockedWord.findMany({ select: { word: true } });
      this.serverWords = { at: nowMs, words: rows.map((r) => r.word) };
    }
    return this.serverWords.words;
  }

  private byClientId(senderId: string, clientId: string): Promise<MessageRow | null> {
    return this.prisma.dmGroupMessage.findUnique({
      where: { senderId_clientId: { senderId, clientId } },
      include: MESSAGE_INCLUDE,
    });
  }

  private async sendResult(callerId: string, row: MessageRow): Promise<DmGroupSendResultDto> {
    const [group, readers] = await Promise.all([
      this.groupDto(callerId, row.groupId),
      this.prisma.dmGroupMember.findMany({ where: { groupId: row.groupId } }),
    ]);
    return { message: this.messageDto(row, callerId, readers), group };
  }

  /**
   * `POST /dm/groups/{groupId}/messages`. Order after auth and the rate limit (`dm:send`): 400 body → a retry with the
   * same `clientId` (200; also after the sender left) → 403 `ACCOUNT_RESTRICTED` → 404 (not a member, or the group was
   * removed) → 400 `mediaId` → stored; the group moves up for everyone, leaves the others' «المؤرشفة», and the members
   * are pushed (after the response).
   */
  async send(
    callerId: string,
    groupId: string,
    body: unknown,
  ): Promise<{ created: boolean; result: DmGroupSendResultDto }> {
    const parsed = dmGroupSendSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const clientId = input.clientId.toLowerCase();
    const first = await this.byClientId(callerId, clientId);
    if (first) {
      await this.access(callerId, first.groupId);
      return { created: false, result: await this.sendResult(callerId, first) };
    }
    await assertNotRestricted(this.prisma, callerId, 'CHAT_MUTE');
    await this.access(callerId, groupId);
    const kind = input.kind;
    const text = kind === 'TEXT' ? maskBlockedWords(input.text!, await this.blockedWords()) : null;
    let messageId: string;
    try {
      messageId = await this.prisma.$transaction(async (tx) => {
        const { me } = await this.lockIn(tx, callerId, groupId, false);
        let mediaId: string | null = null;
        if (kind === 'IMAGE' || kind === 'VOICE') {
          const claimed = await this.media.claimAssetsIn(
            tx,
            callerId,
            [input.mediaId!],
            kind === 'IMAGE' ? 'DM_IMAGE' : 'DM_VOICE',
          );
          if (claimed === null) throw AppException.validation([{ field: 'mediaId', issue: 'invalid_value' }]);
          mediaId = claimed[0]!.id;
        }
        const at = this.clock.now();
        const id = uuidv7();
        await tx.dmGroupMessage.create({
          data: {
            id,
            groupId: me.groupId,
            senderId: callerId,
            clientId,
            kind,
            text,
            token: kind === 'EMOJI' ? input.token! : null,
            mediaId,
            createdAt: at,
            expiresAt: new Date(at.getTime() + this.retentionMs),
          },
        });
        await tx.$executeRaw`
          UPDATE dm_groups SET last_message_at = GREATEST(last_message_at, ${at}::timestamptz)
           WHERE id = ${me.groupId}::uuid`;
        // The sender has read up to their own message; a message from someone else brings an archived group back.
        await tx.$executeRaw`
          UPDATE dm_group_members SET read_at = GREATEST(COALESCE(read_at, ${at}::timestamptz), ${at}::timestamptz)
           WHERE group_id = ${me.groupId}::uuid AND user_id = ${callerId}::uuid`;
        await tx.$executeRaw`
          UPDATE dm_group_members SET archived_at = NULL
           WHERE group_id = ${me.groupId}::uuid AND user_id <> ${callerId}::uuid AND archived_at IS NOT NULL`;
        return id;
      });
    } catch (err) {
      if ((violatedUniqueIndex(err) ?? '').includes('dm_group_messages_client_once')) {
        const raced = await this.byClientId(callerId, clientId);
        if (raced) return { created: false, result: await this.sendResult(callerId, raced) };
      }
      throw err;
    }
    const row = await this.prisma.dmGroupMessage.findUniqueOrThrow({
      where: { id: messageId },
      include: MESSAGE_INCLUDE,
    });
    this.background.run('push.dm.group', async () => {
      await this.push.newGroupMessage({
        groupId: row.groupId,
        messageId: row.id,
        senderId: callerId,
        kind,
        text,
      });
    });
    return { created: true, result: await this.sendResult(callerId, row) };
  }

  private afterAdded(groupId: string, adderId: string, userIds: readonly string[]): void {
    if (userIds.length === 0) return;
    this.background.run('push.dm.group.added', async () => {
      await this.push.addedToGroup({ groupId, adderId, userIds });
    });
  }

  /** `POST /dm/groups/{groupId}/read {lastMessageId}`: the read pointer moves forward only. */
  async markRead(callerId: string, groupId: string, body: unknown): Promise<void> {
    const me = await this.access(callerId, groupId);
    const parsed = dmReadSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const message = await this.prisma.dmGroupMessage.findFirst({
      where: {
        id: parsed.data.lastMessageId.toLowerCase(),
        groupId: me.groupId,
        expiresAt: { gt: this.clock.now() },
        createdAt: { gte: me.joinedAt },
      },
      select: { createdAt: true },
    });
    if (!message) throw AppException.validation([{ field: 'lastMessageId', issue: 'invalid_value' }]);
    await this.prisma.$executeRaw`
      UPDATE dm_group_members
         SET read_at = GREATEST(COALESCE(read_at, ${message.createdAt}::timestamptz), ${message.createdAt}::timestamptz)
       WHERE group_id = ${me.groupId}::uuid AND user_id = ${callerId}::uuid`;
  }

  /**
   * `DELETE /dm/groups/{groupId}/messages/{messageId}`: for everyone — one's own within `DM_DELETE_FOR_EVERYONE_SECONDS`
   * (later → 409 `DM_DELETE_WINDOW_PASSED`), or any message by an admin (moderation inside the group); someone else's
   * by a member → 403 `AUTH_FORBIDDEN`. The message expires now (the sweeper deletes it and its file). `scope=me` is
   * not offered in a group (400 `scope`).
   */
  async deleteMessage(
    callerId: string,
    groupId: string,
    messageId: string,
    query: DmDeleteMessageQuery,
  ): Promise<void> {
    const me = await this.access(callerId, groupId);
    if (!isUuid(messageId)) throw notFound();
    if (query.scope !== 'everyone')
      throw AppException.validation([{ field: 'scope', issue: 'invalid_value' }]);
    const now = this.clock.now();
    const row = await this.prisma.dmGroupMessage.findFirst({
      where: {
        id: messageId.toLowerCase(),
        groupId: me.groupId,
        expiresAt: { gt: now },
        createdAt: { gte: me.joinedAt },
      },
      select: { id: true, senderId: true, createdAt: true },
    });
    if (!row) throw notFound();
    if (row.senderId !== callerId) {
      if (me.role !== 'ADMIN') throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    } else if (now.getTime() - row.createdAt.getTime() > this.config.dm.deleteForEveryoneSeconds * 1000) {
      if (me.role !== 'ADMIN') throw new AppException(ErrorCode.DM_DELETE_WINDOW_PASSED);
    }
    await this.prisma.dmGroupMessage.updateMany({
      where: { id: row.id, expiresAt: { gt: now } },
      data: { expiresAt: now },
    });
  }

  /** `PUT` / `DELETE /dm/groups/{groupId}/mute`: no push and not in the badge, for the caller. */
  async setMuted(callerId: string, groupId: string, muted: boolean): Promise<void> {
    const me = await this.access(callerId, groupId);
    await this.prisma.dmGroupMember.update({
      where: { groupId_userId: { groupId: me.groupId, userId: callerId } },
      data: { muted },
    });
  }

  /** `PUT` / `DELETE /dm/groups/{groupId}/archive` «المؤرشفة», for the caller (idempotent). */
  async setArchived(callerId: string, groupId: string, archived: boolean): Promise<void> {
    const me = await this.access(callerId, groupId);
    if ((me.archivedAt !== null) === archived) return;
    await this.prisma.dmGroupMember.update({
      where: { groupId_userId: { groupId: me.groupId, userId: callerId } },
      data: { archivedAt: archived ? this.clock.now() : null },
    });
  }
}
