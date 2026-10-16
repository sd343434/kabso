import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../../common/audit/audit.service.js';
import { AppException } from '../../../common/errors/app-exception.js';
import { ErrorCode } from '../../../common/errors/error-codes.js';
import { Clock } from '../../../common/time/clock.js';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { CountriesService } from '../../countries/countries.service.js';
import { LiveRoomsService } from '../../live/live-rooms.service.js';
import { MediaService } from '../../media/media.service.js';
import type { UpdateMeInput } from '../me.schemas.js';
import { UsersService, type MeDto, type ProfileUpdate } from '../users.service.js';

/** Request facts recorded in the audit trail. */
export interface MeRequestMeta {
  readonly ip: string | null;
  readonly requestId: string | null;
}

const ME_TX_OPTIONS = { maxWait: 5_000, timeout: 10_000 } as const;

/**
 * `PATCH /me` (v1.2 locale; v1.4 avatar and country, CONVENTIONS §11.4, §11.7). It composes
 * `users` (the profile row), `media` (attach/detach the avatar) and `live` (the host's LIVE room
 * country, §11.8) in ONE transaction, so the update is all-or-nothing. It lives in the profiles
 * module because `live` depends on `users`.
 *
 * Check order after the body schema (pipe): a non-null `avatarUploadId` while uploads are
 * disabled → 503 MEDIA_UPLOADS_UNAVAILABLE; then the values: a country not on the vendored list,
 * or an avatar upload that is not the caller's own attachable `avatar` upload → 400
 * `invalid_value` (one answer for every reason).
 */
@Injectable()
export class MeService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly media: MediaService,
    private readonly live: LiveRoomsService,
    private readonly countries: CountriesService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
  ) {}

  async updateMe(userId: string, body: UpdateMeInput, meta: MeRequestMeta): Promise<MeDto> {
    const avatarUploadId = body.avatarUploadId;
    if (avatarUploadId !== undefined && avatarUploadId !== null) this.media.assertUploadsEnabled();
    if (body.country !== undefined && body.country !== null && !this.countries.isListed(body.country)) {
      throw AppException.validation([{ field: 'country', issue: 'invalid_value' }]);
    }

    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      const current = await this.users.lockProfileIn(tx, userId);
      if (!current) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
      const update: { -readonly [K in keyof ProfileUpdate]: ProfileUpdate[K] } = {};
      if (body.locale !== undefined) update.locale = body.locale;

      if (avatarUploadId !== undefined) {
        if (
          avatarUploadId !== null &&
          !(await this.media.attachIn(tx, userId, avatarUploadId, 'AVATAR', now))
        ) {
          throw AppException.validation([{ field: 'avatarUploadId', issue: 'invalid_value' }]);
        }
        if (current.avatarMediaId !== null) await this.media.detachIn(tx, current.avatarMediaId, now);
        update.avatarMediaId = avatarUploadId;
        if (avatarUploadId !== null || current.avatarMediaId !== null) {
          await this.audit.recordIn(tx, {
            action: avatarUploadId === null ? AuditAction.MEDIA_AVATAR_REMOVE : AuditAction.MEDIA_AVATAR_SET,
            actorUserId: userId,
            targetType: 'user',
            targetId: userId,
            metadata: avatarUploadId === null ? {} : { uploadId: avatarUploadId },
            ip: meta.ip,
            requestId: meta.requestId,
          });
        }
      }

      if (body.country !== undefined && body.country !== current.country) {
        update.country = body.country;
        // §11.8: the host's LIVE room never shows a country the host no longer chose.
        await this.live.syncHostCountryIn(tx, userId, body.country);
        // §11.7: no history — the audit row records only that the country changed.
        await this.audit.recordIn(tx, {
          action: AuditAction.USERS_COUNTRY_UPDATE,
          actorUserId: userId,
          targetType: 'user',
          targetId: userId,
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
      await this.users.updateProfileIn(tx, userId, update);
    }, ME_TX_OPTIONS);

    const me = await this.users.getMe(userId);
    if (!me) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    return me;
  }
}
