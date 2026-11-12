import { Body, Controller, Delete, Get, HttpCode, Inject, Patch, Put, Query, Req } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { REDIS } from '../../redis/redis.module.js';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { clientIp, type AppRequest, type AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { updateMeSchema, usernameSchema } from '../auth/auth.schemas.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { Public } from '../auth/public.decorator.js';
import {
  ProfileEditService,
  type AnimatedAvatarDto,
  type AvatarDto,
  type CoverDto,
  type ProfileEditMeta,
} from './profile-edit.service.js';
import { UsersService, type MeDto } from './users.service.js';
import { ConsentExempt } from '../privacy/consent-exempt.decorator.js';
import { isWatchStaff, staffIdentityOf, type LimitedStaffRole } from '../live/live-staff.js';
import { staffIdOf } from './staff-ids.js';
import { MediaService } from '../media/media.service.js';
import {
  ownerProfileFields,
  type OwnerBioDto,
  type OwnerCoverVideoDto,
} from '../owner-profile/owner-core.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { StaffRegion } from '../live/staff-regions.js';

function meta(req: AppRequest): ProfileEditMeta {
  return { ip: clientIp(req), requestId: getRequestId(req) };
}

const availabilityQuery = z.strictObject({ username: usernameSchema });

@Controller()
export class UsersController {
  constructor(
    private readonly users: UsersService,
    private readonly profiles: ProfileEditService,
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    @Inject(REDIS) private readonly redis: Redis,
  ) {}

  @Get('me')
  @ConsentExempt()
  async me(@CurrentAuth() auth: AuthContext): Promise<
    MeDto & {
      kabsoTeam?: true;
      staffId?: string;
      staff?: { role: LimitedStaffRole; regions: StaffRegion[]; staffId?: string };
      kabsoOwner?: true;
      coverVideo?: OwnerCoverVideoDto;
      ownerBio?: OwnerBioDto;
      founderFeedbackCount?: number;
    }
  > {
    const me = await this.users.getMe(auth.userId);
    if (!me) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    // v1.72-live (D283, §10.96.10): a limited Kabso Team account — the app hides going live, levels, VIP, families,
    // tasks and every post kind but the announcement.
    const staff = await staffIdentityOf(this.prisma, auth.userId);
    // v1.73-live (D283c, §10.96.12): the official staff ID «Kabso01» (any panel role, the OWNER too).
    const staffId = await staffIdOf(this.prisma, auth.userId);
    // v1.68-live (D273, §10.96.6): «فريق كابسو» (a watch role now) — the app's Me tab entry and the tools in lives.
    return {
      ...me,
      ...((await isWatchStaff(this.prisma, auth.userId)) ? { kabsoTeam: true as const } : {}),
      ...(staffId ? { staffId } : {}),
      ...(staff ? { staff: { ...staff, ...(staffId ? { staffId } : {}) } } : {}),
      // v1.95-social (D301, §10.112): the app owner and the cover videos.
      ...(await ownerProfileFields(
        this.prisma,
        auth.userId,
        (key) => this.media.largeUrl({ largeKey: key }),
        this.redis,
      )),
    };
  }

  /**
   * v1.2 (KL-018): persist an explicit locale choice; v1.27.1-live (D133) the country; v1.45-social
   * (D168) the display name and bio; 30 / hour / user.
   */
  @Patch('me')
  @HttpCode(200)
  @RateLimit({ bucket: 'update_me:user', rule: 'updateMeUser', key: (req) => req.auth?.userId ?? '' })
  async updateMe(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body(new ZodValidationPipe(updateMeSchema)) body: z.output<typeof updateMeSchema>,
  ): Promise<MeDto> {
    return this.profiles.updateMe(auth.userId, body, meta(req));
  }

  @Public()
  @Get('users/username-availability')
  async usernameAvailability(
    @Query(new ZodValidationPipe(availabilityQuery)) query: z.output<typeof availabilityQuery>,
  ): Promise<{ username: string; available: boolean }> {
    return {
      username: query.username,
      available: await this.users.isUsernameAvailable(query.username),
    };
  }
}

/** v1.45-social (D168, §7): `PUT` and `DELETE /me/avatar` share 30 / hour per user, replacing the default. */
const AVATAR = {
  bucket: 'me:avatar',
  rule: 'avatarUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** The caller's profile photo (v1.45-social, D168, CONVENTIONS §10.42). */
@Controller('me/avatar')
export class AvatarController {
  constructor(private readonly profiles: ProfileEditService) {}

  @Put()
  @HttpCode(200)
  @RateLimit(AVATAR)
  setAvatar(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body() body: unknown,
  ): Promise<AvatarDto> {
    return this.profiles.setAvatar(auth.userId, body, meta(req));
  }

  @Delete()
  @HttpCode(204)
  @RateLimit(AVATAR)
  async removeAvatar(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<void> {
    await this.profiles.removeAvatar(auth.userId, meta(req));
  }
}

/** v1.76-social (D218, §7): `PUT` and `DELETE /me/cover` share the avatar's rule (30 / hour per user) in their own bucket. */
const COVER = {
  bucket: 'me:cover',
  rule: 'avatarUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** The caller's profile cover (v1.76-social, D218, CONVENTIONS §10.73.3). */
@Controller('me/cover')
export class CoverController {
  constructor(private readonly profiles: ProfileEditService) {}

  @Put()
  @HttpCode(200)
  @RateLimit(COVER)
  setCover(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body() body: unknown,
  ): Promise<CoverDto> {
    return this.profiles.setCover(auth.userId, body, meta(req));
  }

  @Delete()
  @HttpCode(204)
  @RateLimit(COVER)
  async removeCover(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<void> {
    await this.profiles.removeCover(auth.userId, meta(req));
  }
}

/** v1.136-social (D384, §7): `PUT` and `DELETE /me/animated-avatar` share the avatar's rule in their own bucket. */
const ANIMATED_AVATAR = {
  bucket: 'me:animated-avatar',
  rule: 'avatarUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** The caller's VIP animated picture «صورة متحركة» (v1.136-social, D384, CONVENTIONS §10.173.3). */
@Controller('me/animated-avatar')
export class AnimatedAvatarController {
  constructor(private readonly profiles: ProfileEditService) {}

  @Put()
  @HttpCode(200)
  @RateLimit(ANIMATED_AVATAR)
  setAnimatedAvatar(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body() body: unknown,
  ): Promise<AnimatedAvatarDto> {
    return this.profiles.setAnimatedAvatar(auth.userId, body, meta(req));
  }

  @Delete()
  @HttpCode(204)
  @RateLimit(ANIMATED_AVATAR)
  async removeAnimatedAvatar(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<void> {
    await this.profiles.removeAnimatedAvatar(auth.userId, meta(req));
  }
}
