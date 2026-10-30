import { Inject, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { isUuid } from '../auth/tokens.js';
import { syncHostFrameIn } from '../economy/host-frames.js';
import { MediaService } from '../media/media.service.js';
import { containsReservedTerm } from './confusables.js';
import type { AccountCategory, Gender, ProfileLinkInput } from './profile-fields.js';
import { UsersService, type MeDto } from './users.service.js';

/** Request metadata for audit records. */
export interface ProfileEditMeta {
  readonly ip: string | null;
  readonly requestId: string;
}

/** The validated `PATCH /me` body (`updateMeSchema` output). */
export interface UpdateMeInput {
  readonly locale?: 'ar' | 'en' | undefined;
  readonly country?: string | null | undefined;
  readonly displayName?: string | undefined;
  readonly bio?: string | null | undefined;
  /** v1.47-social (D175, §10.47). */
  readonly gender?: Gender | undefined;
  readonly showGender?: boolean | undefined;
  readonly category?: AccountCategory | null | undefined;
  readonly links?: readonly ProfileLinkInput[] | undefined;
}

/** `SetAvatarRequest` (v1.45-social): strict (unknown fields → `unknown_field`). */
export const setAvatarSchema = z.strictObject({
  mediaId: z.string().refine(isUuid, { params: { issue: 'invalid_value' } }),
});

/** `Avatar` (v1.45-social). */
export interface AvatarDto {
  avatarUrl: string;
}

/**
 * Editing the own profile (v1.45-social, D168, CONVENTIONS §10.42): the display name and bio of
 * `PATCH /me`, and the profile photo (`PUT` / `DELETE /me/avatar`) on the media pipeline's `AVATAR`
 * assets. A replaced or removed photo's asset is deleted in the same transaction as the change; its
 * objects are deleted after commit (as the live cover, §10.13).
 */
@Injectable()
export class ProfileEditService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly media: MediaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** `PATCH /me`: locale and country as before; the name and bio audited when they change. */
  async updateMe(userId: string, input: UpdateMeInput, meta: ProfileEditMeta): Promise<MeDto> {
    if (
      input.displayName !== undefined &&
      containsReservedTerm(
        input.displayName,
        this.config.reservedDisplayNameTerms,
        this.config.reservedDisplayNameBrandTerms,
      )
    ) {
      throw AppException.validation([{ field: 'displayName', issue: 'reserved_term' }]);
    }
    const found = await this.prisma.$transaction(async (tx) => {
      const [before] = await tx.$queryRaw<
        {
          display_name: string;
          bio: string | null;
          gender: string | null;
          show_gender: boolean;
          account_category: string | null;
        }[]
      >`
        SELECT display_name, bio, gender::text AS gender, show_gender, account_category::text AS account_category
          FROM user_profiles WHERE user_id = ${userId}::uuid FOR UPDATE`;
      if (!before) return false;
      await tx.userProfile.update({
        where: { userId },
        data: {
          ...(input.locale !== undefined ? { locale: input.locale } : {}),
          ...(input.country !== undefined ? { countryCode: input.country } : {}),
          ...(input.displayName !== undefined ? { displayName: input.displayName } : {}),
          ...(input.bio !== undefined ? { bio: input.bio } : {}),
          ...(input.gender !== undefined ? { gender: input.gender } : {}),
          ...(input.showGender !== undefined ? { showGender: input.showGender } : {}),
          ...(input.category !== undefined ? { category: input.category } : {}),
        },
      });
      const fields: string[] = [];
      if (input.displayName !== undefined && input.displayName !== before.display_name)
        fields.push('displayName');
      if (input.bio !== undefined && input.bio !== before.bio) fields.push('bio');
      if (input.gender !== undefined && input.gender !== before.gender) {
        fields.push('gender');
        // v1.55-social (D186, §10.49): the active-host frame follows the gender (blue / pink), worn stays worn.
        await syncHostFrameIn(
          tx,
          userId,
          this.clock.now(),
          this.config.economy,
          this.config.live.rankingsTimeZone,
        );
      }
      if (input.showGender !== undefined && input.showGender !== before.show_gender)
        fields.push('showGender');
      if (input.category !== undefined && input.category !== before.account_category) fields.push('category');
      if (input.links !== undefined && (await this.replaceLinksIn(tx, userId, input.links)))
        fields.push('links');
      if (fields.length > 0) {
        // Which fields changed, never their values (§10.42).
        await this.audit.recordIn(tx, {
          action: AuditAction.PROFILE_UPDATE,
          actorUserId: userId,
          targetType: 'user',
          targetId: userId,
          metadata: { fields },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
      return true;
    });
    const me = found ? await this.users.getMe(userId) : null;
    if (!me) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    return me;
  }

  /**
   * v1.47-social (D175): replaces the caller's links with `links` (in order) unless they are the same
   * already; returns whether anything changed.
   */
  private async replaceLinksIn(
    tx: Prisma.TransactionClient,
    userId: string,
    links: readonly ProfileLinkInput[],
  ): Promise<boolean> {
    const current = await tx.userProfileLink.findMany({
      where: { userId },
      orderBy: { position: 'asc' },
      select: { url: true, label: true },
    });
    const same =
      current.length === links.length &&
      current.every((c, i) => c.url === links[i]!.url && c.label === (links[i]!.label ?? null));
    if (same) return false;
    await tx.userProfileLink.deleteMany({ where: { userId } });
    if (links.length > 0) {
      await tx.userProfileLink.createMany({
        data: links.map((l, position) => ({ userId, position, url: l.url, label: l.label ?? null })),
      });
    }
    return true;
  }

  /**
   * `PUT /me/avatar`. Order after auth and the rate limit: uploads switch (503) → body → the asset
   * (400 `mediaId` / `invalid_value` unless it is a READY, unattached `AVATAR` of the caller from
   * the last 24 hours).
   */
  async setAvatar(userId: string, body: unknown, meta: ProfileEditMeta): Promise<AvatarDto> {
    this.media.assertEnabled();
    const parsed = setAvatarSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const mediaId = parsed.data.mediaId.toLowerCase();
    let avatarUrl = '';
    const oldKeys = await this.prisma.$transaction(async (tx) => {
      const old = await this.lockProfile(tx, userId);
      if (old.avatar_media_id === mediaId && old.avatar_url !== null) {
        avatarUrl = old.avatar_url;
        return [];
      }
      const claimed = await this.media.claimAssetsIn(tx, userId, [mediaId], 'AVATAR');
      if (!claimed) throw AppException.validation([{ field: 'mediaId', issue: 'invalid_value' }]);
      avatarUrl = this.media.largeUrl(claimed[0]!);
      return this.applyIn(tx, userId, old, { mediaId, url: avatarUrl }, meta);
    });
    await this.media.deleteObjects(oldKeys);
    return { avatarUrl };
  }

  /** `DELETE /me/avatar`: back to the initial; idempotent (no photo → 204 too); uploads may be off. */
  async removeAvatar(userId: string, meta: ProfileEditMeta): Promise<void> {
    const oldKeys = await this.prisma.$transaction(async (tx) => {
      const old = await this.lockProfile(tx, userId);
      if (old.avatar_media_id === null && old.avatar_url === null) return [];
      return this.applyIn(tx, userId, old, null, meta);
    });
    await this.media.deleteObjects(oldKeys);
  }

  private async lockProfile(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<{ avatar_media_id: string | null; avatar_url: string | null }> {
    const [row] = await tx.$queryRaw<{ avatar_media_id: string | null; avatar_url: string | null }[]>`
      SELECT avatar_media_id::text AS avatar_media_id, avatar_url
        FROM user_profiles WHERE user_id = ${userId}::uuid
         FOR UPDATE`;
    if (!row) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    return row;
  }

  /** Sets (or clears) the photo, deletes the replaced asset's row; returns its object keys. */
  private async applyIn(
    tx: Prisma.TransactionClient,
    userId: string,
    old: { avatar_media_id: string | null },
    next: { mediaId: string; url: string } | null,
    meta: ProfileEditMeta,
  ): Promise<string[]> {
    await tx.userProfile.update({
      where: { userId },
      data: { avatarMediaId: next?.mediaId ?? null, avatarUrl: next?.url ?? null },
    });
    let oldKeys: string[] = [];
    if (old.avatar_media_id !== null) {
      const gone = await tx.mediaAsset.delete({
        where: { id: old.avatar_media_id },
        select: { largeKey: true, thumbKey: true },
      });
      oldKeys = [gone.largeKey, gone.thumbKey];
    }
    await this.audit.recordIn(tx, {
      action: AuditAction.AVATAR_UPDATE,
      actorUserId: userId,
      targetType: 'user',
      targetId: userId,
      metadata: { avatar: next === null ? 'removed' : 'set' },
      ip: meta.ip,
      requestId: meta.requestId,
    });
    return oldKeys;
  }
}
