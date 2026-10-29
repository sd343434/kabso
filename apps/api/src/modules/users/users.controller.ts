import { Body, Controller, Delete, Get, HttpCode, Patch, Put, Query, Req } from '@nestjs/common';
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
import { ProfileEditService, type AvatarDto, type ProfileEditMeta } from './profile-edit.service.js';
import { UsersService, type MeDto } from './users.service.js';

function meta(req: AppRequest): ProfileEditMeta {
  return { ip: clientIp(req), requestId: getRequestId(req) };
}

const availabilityQuery = z.strictObject({ username: usernameSchema });

@Controller()
export class UsersController {
  constructor(
    private readonly users: UsersService,
    private readonly profiles: ProfileEditService,
  ) {}

  @Get('me')
  async me(@CurrentAuth() auth: AuthContext): Promise<MeDto> {
    const me = await this.users.getMe(auth.userId);
    if (!me) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    return me;
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
