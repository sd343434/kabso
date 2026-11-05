import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { LiveMediaService } from '../live/live-media.service.js';
import { LIVE_TX_OPTIONS, LiveRoomsService } from '../live/live-rooms.service.js';
import { normalizeUsername } from '../users/username.js';
import type { AdminContext } from './admin-auth.service.js';
import { tableResult, window, type TableQuery } from './admin-tables.js';
import { refused } from './admin-users.service.js';
import { openLiveReportsByRoom } from './admin-live-moderation.service.js';
import { countriesOfRegions, isStaffRegion, regionOfCountry } from '../live/staff-regions.js';

/** v1.54-live (D241): an open D195 PK match (CONNECTED, BATTLE or RESULT) on either side. */
const OPEN_PK = { status: { not: 'CLOSED' as const } };
const inOpenPk: Prisma.LiveRoomWhereInput = {
  OR: [{ mode: 'PK' }, { pkMatchesAsA: { some: OPEN_PK } }, { pkMatchesAsB: { some: OPEN_PK } }],
};
const pkOpponent = {
  pkMatchesAsA: {
    where: OPEN_PK,
    take: 1,
    select: {
      roomB: {
        select: {
          id: true,
          host: { select: { profile: { select: { username: true, displayName: true } } } },
        },
      },
    },
  },
  pkMatchesAsB: {
    where: OPEN_PK,
    take: 1,
    select: {
      roomA: {
        select: {
          id: true,
          host: { select: { profile: { select: { username: true, displayName: true } } } },
        },
      },
    },
  },
};

type PkSides = {
  mode: string;
  pkMatchesAsA: {
    roomB: { id: string; host: { profile: { username: string; displayName: string } | null } };
  }[];
  pkMatchesAsB: {
    roomA: { id: string; host: { profile: { username: string; displayName: string } | null } };
  }[];
};

/**
 * v1.54-live (D241): the row's PK — the opponent's room and host when the room is in an open match; a legacy
 * `mode = 'PK'` room without a match has no opponent. Null when not in a PK.
 */
function pkOf(r: PkSides) {
  const other = r.pkMatchesAsA[0]?.roomB ?? r.pkMatchesAsB[0]?.roomA;
  if (!other && r.mode !== 'PK') return null;
  return {
    opponentRoomId: other?.id ?? null,
    opponentUsername: other?.host.profile?.username ?? null,
    opponentDisplayName: other?.host.profile?.displayName ?? null,
  };
}

const host = {
  select: {
    id: true,
    profile: { select: { username: true, displayName: true, avatarUrl: true, countryCode: true } },
    liveHost: { select: { coverUrl: true, roomNumber: true } },
  },
};

/**
 * «المضيفون والبث» in the panel v2 (v1.65-social, D197, CONVENTIONS §10.60.3): the lives on air now (thumbnail,
 * title, viewers), a live's details, **ending a live** with a required reason (the report action's rule,
 * `LiveRoomsService.endByAdminIn`: end reason ADMIN, the media session closed after the commit; audited
 * `admin.live.end` with the reason), and the hosting permissions (`live_hosts`, the CP-010 grant / revoke of
 * `LiveMediaService`, audited with the reason). PK history is not in this base (D195 not merged): no route.
 */
@Injectable()
export class AdminLivesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly rooms: LiveRoomsService,
    private readonly media: LiveMediaService,
  ) {}

  async now(
    q: TableQuery & {
      mode?: 'SOLO' | 'PK' | 'MULTI' | 'AUDIO' | 'PODCAST' | 'STREAMER' | undefined;
      reported?: boolean | undefined;
      assigned?: 'me' | undefined;
      region?: string | undefined;
    },
    ctx: AdminContext,
  ) {
    // v1.71-live (D283, §10.96.11): the region filter — the host's country in the region (or in my regions).
    const regionCountries = q.region ? await this.regionCountries(q.region, ctx.userId) : null;
    // v1.60-live (D250, §10.91.2): «لايفات مبلّغ عنها» — the lives with open reports (a filter, combinable with a mode).
    const reported = q.reported === true ? await openLiveReportsByRoom(this.prisma) : null;
    const text = q.q?.trim().toLowerCase().replace(/^@/, '');
    // v1.47-live (D212): the mode filter (the panel's category chips). v1.54-live (D241): «PK» = the rooms in an
    // open D195 match (they stay SOLO) or the legacy mode PK; «بث مباشر» (SOLO) = SOLO rooms NOT in a PK, so
    // the chips partition the lives.
    const modeWhere: Prisma.LiveRoomWhereInput =
      q.mode === 'PK'
        ? inOpenPk
        : q.mode === 'SOLO'
          ? { mode: 'SOLO', NOT: inOpenPk }
          : q.mode
            ? { mode: q.mode }
            : {};
    const where: Prisma.LiveRoomWhereInput = {
      status: 'LIVE',
      AND: [
        modeWhere,
        ...(reported ? [{ id: { in: [...reported.keys()] } }] : []),
        ...(q.assigned === 'me' ? [{ assignment: { adminId: ctx.userId } }] : []),
        ...(regionCountries ? [{ host: { profile: { countryCode: { in: regionCountries } } } }] : []),
      ],
      ...(text
        ? {
            OR: [
              { title: { contains: q.q!, mode: 'insensitive' } },
              { host: { profile: { username: { startsWith: text } } } },
            ],
          }
        : {}),
    };
    const orderBy: Prisma.LiveRoomOrderByWithRelationInput[] =
      q.sort === 'startedAt'
        ? [{ startedAt: q.order }, { id: q.order }]
        : [{ viewerCount: q.order }, { startedAt: 'desc' }];
    const [rows, total] = await Promise.all([
      this.prisma.liveRoom.findMany({
        where,
        orderBy,
        ...window(q),
        select: {
          id: true,
          title: true,
          mode: true,
          viewerCount: true,
          startedAt: true,
          coverUrl: true,
          score: true,
          category: { select: { nameAr: true, nameEn: true } },
          host,
          ...pkOpponent,
          // v1.64-live (D260): who watches it, and the staff watching it visibly now.
          assignment: {
            select: { adminId: true, admin: { select: { profile: { select: { displayName: true } } } } },
          },
          _count: { select: { staffWatchers: true } },
        },
      }),
      this.prisma.liveRoom.count({ where }),
    ]);
    // v1.60-live (D250): each card's open reports (the red badge).
    const open =
      reported ??
      (await openLiveReportsByRoom(
        this.prisma,
        rows.map((r) => r.id),
      ));
    const data = rows.map((r) => ({
      id: r.id,
      title: r.title,
      mode: r.mode,
      openReports: open.get(r.id) ?? 0,
      viewers: r.viewerCount,
      startedAt: r.startedAt.toISOString(),
      coverUrl: r.coverUrl ?? r.host.liveHost?.coverUrl ?? null,
      score: Number(r.score),
      categoryAr: r.category?.nameAr ?? null,
      categoryEn: r.category?.nameEn ?? null,
      host: {
        id: r.host.id,
        username: r.host.profile?.username ?? '',
        displayName: r.host.profile?.displayName ?? '',
        avatarUrl: r.host.profile?.avatarUrl ?? null,
      },
      // v1.71-live (D283): the host's country (ISO alpha-2) and its staff region, or null.
      hostCountry: r.host.profile?.countryCode ?? null,
      region: regionOfCountry(r.host.profile?.countryCode),
      pk: pkOf(r),
      assignedTo: r.assignment
        ? { id: r.assignment.adminId, displayName: r.assignment.admin.profile?.displayName ?? '' }
        : null,
      staffWatching: r._count.staffWatchers,
    }));
    return tableResult(
      this.audit,
      ctx,
      'lives',
      q,
      data,
      total,
      [
        ['id', (r) => r.id],
        ['title', (r) => r.title],
        ['host', (r) => r.host.username],
        ['mode', (r) => r.mode],
        ['pk_opponent', (r) => r.pk?.opponentUsername ?? (r.pk ? 'PK' : '')],
        ['viewers', (r) => r.viewers],
        ['started_at', (r) => r.startedAt],
      ],
      {
        ...(q.mode ? { mode: q.mode } : {}),
        ...(q.reported ? { reported: true } : {}),
        ...(q.assigned ? { assigned: q.assigned } : {}),
        ...(q.region ? { region: q.region } : {}),
      },
    );
  }

  /** The countries of one region, or of the staff member's own regions (`mine`). */
  private async regionCountries(region: string, adminId: string): Promise<string[]> {
    if (isStaffRegion(region)) return countriesOfRegions([region]);
    const mine = await this.prisma.adminStaffRegion.findMany({
      where: { userId: adminId },
      select: { region: true },
    });
    return countriesOfRegions(mine.map((r) => r.region).filter(isStaffRegion));
  }

  async detail(id: string) {
    const r = await this.prisma.liveRoom.findUnique({
      where: { id },
      select: {
        id: true,
        title: true,
        topic: true,
        mode: true,
        status: true,
        endReason: true,
        viewerCount: true,
        peakViewerCount: true,
        startedAt: true,
        endedAt: true,
        coverUrl: true,
        chatEnabled: true,
        allowGuests: true,
        category: { select: { nameAr: true, nameEn: true } },
        host,
        ...pkOpponent,
      },
    });
    if (!r) throw new AppException(ErrorCode.NOT_FOUND);
    const [gifts, seats, openReports, moderators] = await Promise.all([
      this.prisma.liveGift.aggregate({ where: { roomId: id }, _sum: { totalCoins: true }, _count: true }),
      this.prisma.liveRoomSeat.count({ where: { roomId: id, userId: { not: null } } }),
      // v1.60-live (D250): the room's and its host's (as a user, since the live started) open reports.
      openLiveReportsByRoom(this.prisma, [id]).then((m) => m.get(id) ?? 0),
      this.prisma.liveRoomModerator.count({ where: { roomId: id } }),
    ]);
    return {
      id: r.id,
      title: r.title,
      topic: r.topic,
      mode: r.mode as string,
      status: r.status as string,
      endReason: (r.endReason as string | null) ?? null,
      viewers: r.viewerCount,
      peakViewers: r.peakViewerCount ?? 0,
      startedAt: r.startedAt.toISOString(),
      endedAt: r.endedAt?.toISOString() ?? null,
      coverUrl: r.coverUrl ?? r.host.liveHost?.coverUrl ?? null,
      chatEnabled: r.chatEnabled,
      allowGuests: r.allowGuests,
      categoryAr: r.category?.nameAr ?? null,
      categoryEn: r.category?.nameEn ?? null,
      roomNumber: r.host.liveHost?.roomNumber ?? null,
      host: {
        id: r.host.id,
        username: r.host.profile?.username ?? '',
        displayName: r.host.profile?.displayName ?? '',
        avatarUrl: r.host.profile?.avatarUrl ?? null,
      },
      giftCoins: Number(gifts._sum.totalCoins ?? 0n),
      giftsSent: gifts._count,
      seatsTaken: seats,
      openReports,
      moderators,
      pk: pkOf(r),
    };
  }

  /** Ends a live now (end reason ADMIN), with the reason in the audit row; refused when it is not on air. */
  async end(id: string, reason: string, ctx: AdminContext) {
    const room = await this.prisma.liveRoom.findUnique({ where: { id }, select: { hostUserId: true } });
    if (!room) throw new AppException(ErrorCode.NOT_FOUND);
    if (room.hostUserId === ctx.userId) throw refused('You cannot do this to your own live.');
    const ended = await this.prisma.$transaction(async (tx) => {
      const ids = await this.rooms.endByAdminIn(tx, { roomId: id });
      if (ids.length === 0) throw refused('The live is not on air.');
      await this.audit.recordIn(tx, {
        action: AuditAction.ADMIN_LIVE_END,
        actorUserId: ctx.userId,
        targetType: 'live_room',
        targetId: id,
        metadata: {
          reason,
          hostUserId: room.hostUserId,
          before: 'LIVE',
          after: 'ENDED',
          endReason: 'ADMIN',
          via: 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
      return ids;
    }, LIVE_TX_OPTIONS);
    for (const roomId of ended) await this.media.closeMedia(roomId);
    return { status: 'ENDED', endReason: 'ADMIN' };
  }

  async hosts(q: TableQuery & { source?: 'ADMIN' | 'AGENCY' | 'IDENTITY' | undefined }, ctx: AdminContext) {
    const text = q.q?.trim().toLowerCase().replace(/^@/, '');
    const where: Prisma.LiveHostWhereInput = {
      ...(q.source ? { source: q.source } : {}),
      ...(text ? { user: { profile: { username: { startsWith: text } } } } : {}),
    };
    const [rows, total] = await Promise.all([
      this.prisma.liveHost.findMany({
        where,
        orderBy: [{ grantedAt: q.order }, { userId: 'asc' }],
        ...window(q),
        select: {
          userId: true,
          source: true,
          grantedAt: true,
          roomNumber: true,
          user: {
            select: {
              status: true,
              profile: { select: { username: true, displayName: true, avatarUrl: true } },
              liveRooms: { where: { status: 'LIVE' }, select: { id: true }, take: 1 },
            },
          },
          grantedBy: { select: { profile: { select: { username: true } } } },
        },
      }),
      this.prisma.liveHost.count({ where }),
    ]);
    const data = rows.map((h) => ({
      userId: h.userId,
      username: h.user.profile?.username ?? '',
      displayName: h.user.profile?.displayName ?? '',
      avatarUrl: h.user.profile?.avatarUrl ?? null,
      status: h.user.status,
      source: h.source,
      grantedAt: h.grantedAt.toISOString(),
      grantedBy: h.grantedBy?.profile?.username ?? null,
      roomNumber: h.roomNumber,
      liveRoomId: h.user.liveRooms[0]?.id ?? null,
    }));
    return tableResult(this.audit, ctx, 'hosts', q, data, total, [
      ['user_id', (r) => r.userId],
      ['username', (r) => r.username],
      ['source', (r) => r.source],
      ['granted_at', (r) => r.grantedAt],
      ['room_number', (r) => r.roomNumber],
    ]);
  }

  async grantHost(username: string, reason: string, ctx: AdminContext) {
    const changed = await this.media.grantHost(
      ctx.userId,
      normalizeUsername(username).replace(/^@/, ''),
      { ip: ctx.ip, requestId: ctx.requestId },
      { reason, via: 'panel' },
    );
    return { host: true, changed };
  }

  async revokeHost(username: string, reason: string, ctx: AdminContext) {
    const name = normalizeUsername(username).replace(/^@/, '');
    const target = await this.prisma.userProfile.findUnique({
      where: { username: name },
      select: { userId: true },
    });
    if (target?.userId === ctx.userId) throw refused('You cannot do this to your own account.');
    const changed = await this.media.revokeHost(
      ctx.userId,
      name,
      { ip: ctx.ip, requestId: ctx.requestId },
      { reason, via: 'panel' },
    );
    return { host: false, changed };
  }
}
