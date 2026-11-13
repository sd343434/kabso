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
import {
  keptProfileTagIcons,
  MAX_PROFILE_LINKS,
  profileTagIconsOf,
  type AccountCategory,
  type Gender,
  type ProfileLinkInput,
} from './profile-fields.js';
import { UsersService, type MeDto } from './users.service.js';
import { refuseLimitedStaff } from '../live/live-staff.js';
import { vipHoldsPerkIn } from '../vip/vip-perks.js';
import { isKabsoOwner } from '../owner-profile/owner-core.js';

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
  /** v1.85-social (D278b, §10.99). */
  readonly tags?: readonly string[] | undefined;
  /** v1.91-social (D292, §10.106): one icon per tag of `tags` (only with `tags`). */
  readonly tagIcons?: readonly string[] | undefined;
}

/** `SetAvatarRequest` (v1.45-social): strict (unknown fields → `unknown_field`). */
export const setAvatarSchema = z.strictObject({
  mediaId: z.string().refine(isUuid, { params: { issue: 'invalid_value' } }),
});

/** `Avatar` (v1.45-social). */
export interface AvatarDto {
  avatarUrl: string;
}

/** `ProfileCover` (v1.76-social, D218). */
export interface CoverDto {
  coverUrl: string;
}

/** `AnimatedAvatar` (v1.136-social, D384, §10.173). */
export interface AnimatedAvatarDto {
  url: string;
  stillUrl: string;
  width: number;
  height: number;
}

/** v1.136-social (D384): the VIP perk that lets a member set an animated picture. */
export const ANIMATED_AVATAR_PERK = 'ANIMATED_AVATAR';

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
    // v1.72-live (D283b, §10.96.10): a Kabso Team account's bio is the app's fixed official text — 403 `bio`.
    if (input.bio !== undefined) await refuseLimitedStaff(this.prisma, userId, 'bio');
    // v1.118-social (D357): more than 3 links only for the app owner (his page's social row; up to 7).
    if (
      input.links !== undefined &&
      input.links.length > MAX_PROFILE_LINKS &&
      !(await isKabsoOwner(this.prisma, userId))
    ) {
      throw AppException.validation([{ field: 'links', issue: 'too_many' }]);
    }
    const found = await this.prisma.$transaction(async (tx) => {
      const [before] = await tx.$queryRaw<
        {
          display_name: string;
          bio: string | null;
          gender: string | null;
          show_gender: boolean;
          account_category: string | null;
          tags: string[];
          tag_icons: string[];
        }[]
      >`
        SELECT display_name, bio, gender::text AS gender, show_gender, account_category::text AS account_category,
               tags, tag_icons
          FROM user_profiles WHERE user_id = ${userId}::uuid FOR UPDATE`;
      if (!before) return false;
      // v1.91-social (D292, §10.106): the icons go with the tags — the ones sent, or (an older app sending only
      // `tags`) each tag keeps the icon it had by its text; a new tag is `default`.
      const beforeIcons = profileTagIconsOf(before.tags, before.tag_icons);
      const tagIcons =
        input.tags === undefined
          ? undefined
          : (input.tagIcons ?? keptProfileTagIcons(input.tags, before.tags, beforeIcons));
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
          ...(input.tags !== undefined ? { tags: [...input.tags] } : {}),
          ...(tagIcons !== undefined ? { tagIcons: [...tagIcons] } : {}),
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
      if (
        input.tags !== undefined &&
        (input.tags.length !== before.tags.length || input.tags.some((t, i) => t !== before.tags[i]))
      )
        fields.push('tags');
      if (
        tagIcons !== undefined &&
        (tagIcons.length !== beforeIcons.length || tagIcons.some((t, i) => t !== beforeIcons[i]))
      )
        fields.push('tagIcons');
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
    // v1.72-live (D283, §10.96.10): a Kabso Team account's picture is the team's, fixed.
    await refuseLimitedStaff(this.prisma, userId, 'avatar');
    await this.media.assertEnabled();
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
    await refuseLimitedStaff(this.prisma, userId, 'avatar');
    const oldKeys = await this.prisma.$transaction(async (tx) => {
      const old = await this.lockProfile(tx, userId);
      if (old.avatar_media_id === null && old.avatar_url === null) return [];
      return this.applyIn(tx, userId, old, null, meta);
    });
    await this.media.deleteObjects(oldKeys);
  }

  /**
   * v1.76-social (D218, CONVENTIONS §10.73.3): `PUT /me/cover`. The avatar's rules: uploads switch (503) →
   * body (`SetAvatarRequest`'s shape) → the asset (400 `mediaId` / `invalid_value` unless it is a READY,
   * unattached `PROFILE_COVER` of the caller from the last 24 hours). The old cover's asset is deleted in
   * the same transaction, its objects after commit. Setting the current cover again changes nothing.
   */
  async setCover(userId: string, body: unknown, meta: ProfileEditMeta): Promise<CoverDto> {
    // v1.72-live (D283, §10.96.10): a Kabso Team account's cover is its region's team cover (the app's), fixed.
    await refuseLimitedStaff(this.prisma, userId, 'cover');
    await this.media.assertEnabled();
    const parsed = setAvatarSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const mediaId = parsed.data.mediaId.toLowerCase();
    let coverUrl = '';
    const oldKeys = await this.prisma.$transaction(async (tx) => {
      const old = await this.lockCover(tx, userId);
      if (old.cover_media_id === mediaId && old.cover_url !== null) {
        coverUrl = old.cover_url;
        return [];
      }
      const claimed = await this.media.claimAssetsIn(tx, userId, [mediaId], 'PROFILE_COVER');
      if (!claimed) throw AppException.validation([{ field: 'mediaId', issue: 'invalid_value' }]);
      coverUrl = this.media.largeUrl(claimed[0]!);
      return this.applyCoverIn(tx, userId, old, { mediaId, url: coverUrl }, meta);
    });
    await this.media.deleteObjects(oldKeys);
    return { coverUrl };
  }

  /** v1.76-social (D218): `DELETE /me/cover` — back to the Kabso gradient; idempotent; uploads may be off. */
  async removeCover(userId: string, meta: ProfileEditMeta): Promise<void> {
    await refuseLimitedStaff(this.prisma, userId, 'cover');
    const oldKeys = await this.prisma.$transaction(async (tx) => {
      const old = await this.lockCover(tx, userId);
      if (old.cover_media_id === null) return [];
      return this.applyCoverIn(tx, userId, old, null, meta);
    });
    await this.media.deleteObjects(oldKeys);
  }

  /**
   * v1.136-social (D384, CONVENTIONS §10.173.3): `PUT /me/animated-avatar`. Order after auth and the rate limit: limited
   * staff (403 `avatar`) → uploads switch (503) → body → the perk (409 `VIP_UNAVAILABLE` `perk` / `no_perk` without an
   * active VIP holding ANIMATED_AVATAR) → the asset (400 `mediaId` / `invalid_value` unless it is a READY, unattached
   * `ANIMATED_AVATAR` of the caller from the last 24 hours). The old clip's asset is deleted in the same transaction,
   * its objects after commit. Setting the current clip again changes nothing.
   */
  async setAnimatedAvatar(userId: string, body: unknown, meta: ProfileEditMeta): Promise<AnimatedAvatarDto> {
    await refuseLimitedStaff(this.prisma, userId, 'avatar');
    await this.media.assertEnabled();
    const parsed = setAvatarSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const mediaId = parsed.data.mediaId.toLowerCase();
    if (!(await vipHoldsPerkIn(this.prisma, userId, ANIMATED_AVATAR_PERK, this.clock.now()))) {
      throw new AppException(ErrorCode.VIP_UNAVAILABLE, undefined, [{ field: 'perk', issue: 'no_perk' }]);
    }
    let dto: AnimatedAvatarDto | null = null;
    const oldKeys = await this.prisma.$transaction(async (tx) => {
      const old = await this.lockAnimatedAvatar(tx, userId);
      if (
        old.animated_avatar_media_id === mediaId &&
        old.animated_avatar_url &&
        old.animated_avatar_still_url
      ) {
        const asset = await tx.mediaAsset.findUniqueOrThrow({
          where: { id: mediaId },
          select: { width: true, height: true },
        });
        dto = {
          url: old.animated_avatar_url,
          stillUrl: old.animated_avatar_still_url,
          width: asset.width,
          height: asset.height,
        };
        return [];
      }
      const claimed = await this.media.claimAssetsIn(tx, userId, [mediaId], 'ANIMATED_AVATAR');
      if (!claimed) throw AppException.validation([{ field: 'mediaId', issue: 'invalid_value' }]);
      const asset = claimed[0]!;
      dto = {
        url: this.media.largeUrl(asset),
        stillUrl: this.media.thumbUrl(asset),
        width: asset.width,
        height: asset.height,
      };
      return this.applyAnimatedAvatarIn(
        tx,
        userId,
        old,
        { mediaId, url: dto.url, stillUrl: dto.stillUrl },
        meta,
      );
    });
    await this.media.deleteObjects(oldKeys);
    return dto!;
  }

  /**
   * v1.136-social (D384): `DELETE /me/animated-avatar` — the round photo shows again; idempotent; works without the
   * perk (a former member deletes the kept clip) and while uploads are off.
   */
  async removeAnimatedAvatar(userId: string, meta: ProfileEditMeta): Promise<void> {
    await refuseLimitedStaff(this.prisma, userId, 'avatar');
    const oldKeys = await this.prisma.$transaction(async (tx) => {
      const old = await this.lockAnimatedAvatar(tx, userId);
      if (old.animated_avatar_media_id === null) return [];
      return this.applyAnimatedAvatarIn(tx, userId, old, null, meta);
    });
    await this.media.deleteObjects(oldKeys);
  }

  private async lockAnimatedAvatar(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<{
    animated_avatar_media_id: string | null;
    animated_avatar_url: string | null;
    animated_avatar_still_url: string | null;
  }> {
    const [row] = await tx.$queryRaw<
      {
        animated_avatar_media_id: string | null;
        animated_avatar_url: string | null;
        animated_avatar_still_url: string | null;
      }[]
    >`
      SELECT animated_avatar_media_id::text AS animated_avatar_media_id, animated_avatar_url, animated_avatar_still_url
        FROM user_profiles WHERE user_id = ${userId}::uuid
         FOR UPDATE`;
    if (!row) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    return row;
  }

  /** Sets (or clears) the animated picture, deletes the replaced asset's row; returns its object keys. */
  private async applyAnimatedAvatarIn(
    tx: Prisma.TransactionClient,
    userId: string,
    old: { animated_avatar_media_id: string | null },
    next: { mediaId: string; url: string; stillUrl: string } | null,
    meta: ProfileEditMeta,
  ): Promise<string[]> {
    await tx.userProfile.update({
      where: { userId },
      data: {
        animatedAvatarMediaId: next?.mediaId ?? null,
        animatedAvatarUrl: next?.url ?? null,
        animatedAvatarStillUrl: next?.stillUrl ?? null,
      },
    });
    let oldKeys: string[] = [];
    if (old.animated_avatar_media_id !== null) {
      const gone = await tx.mediaAsset.delete({
        where: { id: old.animated_avatar_media_id },
        select: { largeKey: true, thumbKey: true },
      });
      oldKeys = [gone.largeKey, gone.thumbKey];
    }
    await this.audit.recordIn(tx, {
      action: AuditAction.ANIMATED_AVATAR_UPDATE,
      actorUserId: userId,
      targetType: 'user',
      targetId: userId,
      metadata: { animatedAvatar: next === null ? 'removed' : 'set' },
      ip: meta.ip,
      requestId: meta.requestId,
    });
    return oldKeys;
  }

  private async lockCover(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<{ cover_media_id: string | null; cover_url: string | null }> {
    const [row] = await tx.$queryRaw<{ cover_media_id: string | null; cover_url: string | null }[]>`
      SELECT cover_media_id::text AS cover_media_id, cover_url
        FROM user_profiles WHERE user_id = ${userId}::uuid
         FOR UPDATE`;
    if (!row) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    return row;
  }

  /** Sets (or clears) the cover, deletes the replaced asset's row; returns its object keys. */
  private async applyCoverIn(
    tx: Prisma.TransactionClient,
    userId: string,
    old: { cover_media_id: string | null },
    next: { mediaId: string; url: string } | null,
    meta: ProfileEditMeta,
  ): Promise<string[]> {
    await tx.userProfile.update({
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
    await this.audit.recordIn(tx, {
      action: AuditAction.COVER_UPDATE,
      actorUserId: userId,
      targetType: 'user',
      targetId: userId,
      metadata: { cover: next === null ? 'removed' : 'set' },
      ip: meta.ip,
      requestId: meta.requestId,
    });
    return oldKeys;
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
