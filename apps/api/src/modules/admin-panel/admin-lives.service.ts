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

const host = {
  select: {
    id: true,
    profile: { select: { username: true, displayName: true, avatarUrl: true } },
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
    q: TableQuery & { mode?: 'SOLO' | 'PK' | 'MULTI' | 'AUDIO' | 'PODCAST' | undefined },
    ctx: AdminContext,
  ) {
    const text = q.q?.trim().toLowerCase().replace(/^@/, '');
    const where: Prisma.LiveRoomWhereInput = {
      status: 'LIVE',
      // v1.47-live (D212): the mode filter (the panel's category chips).
      ...(q.mode ? { mode: q.mode } : {}),
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
        },
      }),
      this.prisma.liveRoom.count({ where }),
    ]);
    const data = rows.map((r) => ({
      id: r.id,
      title: r.title,
      mode: r.mode,
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
        ['viewers', (r) => r.viewers],
        ['started_at', (r) => r.startedAt],
      ],
      q.mode ? { mode: q.mode } : {},
    );
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
      },
    });
    if (!r) throw new AppException(ErrorCode.NOT_FOUND);
    const [gifts, seats, openReports, moderators] = await Promise.all([
      this.prisma.liveGift.aggregate({ where: { roomId: id }, _sum: { totalCoins: true }, _count: true }),
      this.prisma.liveRoomSeat.count({ where: { roomId: id, userId: { not: null } } }),
      this.prisma.report.count({ where: { targetLiveRoomId: id, status: 'OPEN' } }),
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
