import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { MediaService } from '../media/media.service.js';
import { LiveRoomMetadataService } from './live-metadata.service.js';
import { LIVE_TX_OPTIONS, setLiveStatementTimeout, type RequestMeta } from './live-rooms.service.js';
import { isUuid } from './live.schemas.js';

/** `SetLiveCoverRequest`: strict (unknown fields → `unknown_field`). */
export const setLiveCoverSchema = z.strictObject({
  mediaId: z.string().refine(isUuid, { message: 'invalid_value' }),
});

/** `LiveCover` (openapi v1.11-live). */
export interface LiveCoverDto {
  coverUrl: string;
}

interface CoverChange {
  /** The host's LIVE room whose `cover_url` and info version moved, if any. */
  readonly roomId: string | null;
  /** Objects of the asset the change replaced or removed (its row is already deleted). */
  readonly oldKeys: readonly string[];
}

/**
 * The host's live cover (CP-015, CONVENTIONS §10.13): one `LIVE_COVER` asset per host in
 * `live_hosts`, reused by every live. Setting or removing it locks the host row (a go-live reads the
 * cover under a share lock, so it sees the old or the new one, never neither), deletes the asset it
 * replaced and updates the host's LIVE room in the same transaction (`cover_url`, `info_version` + 1,
 * audited as `live.cover.update`); the room's media metadata is rewritten after commit.
 */
@Injectable()
export class LiveCoverService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly metadata: LiveRoomMetadataService,
    private readonly audit: AuditService,
  ) {}

  /**
   * `PUT /me/live-cover`. Order after auth and rate limit: uploads switch (503) → hosting
   * permission (403 LIVE_HOSTING_NOT_ALLOWED) → body → the asset (400 `mediaId` / `invalid_value`
   * unless it is a READY, unattached `LIVE_COVER` of the caller from the last 24 hours).
   */
  async setCover(userId: string, body: unknown, meta: RequestMeta): Promise<LiveCoverDto> {
    this.media.assertEnabled();
    await this.assertHost(userId);
    const parsed = setLiveCoverSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const mediaId = parsed.data.mediaId.toLowerCase();

    let coverUrl = '';
    const change = await this.prisma.$transaction(async (tx) => {
      await setLiveStatementTimeout(tx);
      const old = await this.lockHost(tx, userId);
      if (old.cover_media_id === mediaId) {
        coverUrl = old.cover_url ?? '';
        return { roomId: null, oldKeys: [] };
      }
      const claimed = await this.media.claimAssetsIn(tx, userId, [mediaId], 'LIVE_COVER');
      if (!claimed) throw AppException.validation([{ field: 'mediaId', issue: 'invalid_value' }]);
      coverUrl = this.media.largeUrl(claimed[0]!);
      return this.applyIn(tx, userId, old, { mediaId, url: coverUrl }, meta);
    }, LIVE_TX_OPTIONS);
    await this.afterCommit(change);
    return { coverUrl };
  }

  /** `DELETE /me/live-cover`: back to the host's avatar; idempotent (no cover → 204 too). */
  async removeCover(userId: string, meta: RequestMeta): Promise<void> {
    await this.assertHost(userId);
    const change = await this.prisma.$transaction(async (tx) => {
      await setLiveStatementTimeout(tx);
      const old = await this.lockHost(tx, userId);
      if (old.cover_media_id === null) return { roomId: null, oldKeys: [] };
      return this.applyIn(tx, userId, old, null, meta);
    }, LIVE_TX_OPTIONS);
    await this.afterCommit(change);
  }

  private async assertHost(userId: string): Promise<void> {
    if ((await this.prisma.liveHost.count({ where: { userId } })) === 0) {
      throw new AppException(ErrorCode.LIVE_HOSTING_NOT_ALLOWED);
    }
  }

  private async lockHost(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<{ cover_media_id: string | null; cover_url: string | null }> {
    const [row] = await tx.$queryRaw<{ cover_media_id: string | null; cover_url: string | null }[]>`
      SELECT cover_media_id::text AS cover_media_id, cover_url
        FROM live_hosts WHERE user_id = ${userId}::uuid
         FOR UPDATE`;
    // The permission was revoked between the check and the lock.
    if (!row) throw new AppException(ErrorCode.LIVE_HOSTING_NOT_ALLOWED);
    return row;
  }

  private async applyIn(
    tx: Prisma.TransactionClient,
    userId: string,
    old: { cover_media_id: string | null },
    next: { mediaId: string; url: string } | null,
    meta: RequestMeta,
  ): Promise<CoverChange> {
    await tx.liveHost.update({
      where: { userId },
      data: { coverMediaId: next?.mediaId ?? null, coverUrl: next?.url ?? null },
    });
    let oldKeys: string[] = [];
    if (old.cover_media_id !== null) {
      const gone = await tx.mediaAsset.delete({
        where: { id: old.cover_media_id },
        select: { largeKey: true, thumbKey: true },
      });
      oldKeys = [gone.largeKey, gone.thumbKey];
    }
    const [room] = await tx.$queryRaw<{ id: string; info_version: number }[]>`
      UPDATE live_rooms
         SET cover_url = ${next?.url ?? null}, info_version = info_version + 1, updated_at = now()
       WHERE host_user_id = ${userId}::uuid AND status = 'LIVE'
       RETURNING id::text AS id, info_version`;
    await this.audit.recordIn(tx, {
      action: AuditAction.LIVE_COVER_UPDATE,
      actorUserId: userId,
      targetType: 'user',
      targetId: userId,
      metadata: {
        cover: next === null ? 'removed' : 'set',
        ...(room ? { roomId: room.id, infoVersion: room.info_version } : {}),
      },
      ip: meta.ip,
      requestId: meta.requestId,
    });
    return { roomId: room?.id ?? null, oldKeys };
  }

  private async afterCommit(change: CoverChange): Promise<void> {
    await this.media.deleteObjects(change.oldKeys);
    if (change.roomId !== null) await this.metadata.infoChanged(change.roomId);
  }
}
