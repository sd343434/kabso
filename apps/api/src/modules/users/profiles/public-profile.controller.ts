import { Controller, Get, Param } from '@nestjs/common';
import type { AuthContext } from '../../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../../common/rate-limit/rate-limit.decorator.js';
import { CurrentAuth } from '../../auth/current-auth.decorator.js';
import { PublicProfileService, type PublicProfileDto } from './public-profile.service.js';

@Controller('users')
export class PublicProfileController {
  constructor(private readonly profiles: PublicProfileService) {}

  /**
   * `GET /users/{username}` (v1.3). No validation of `username`: a malformed name is simply not
   * found (404, never 400). `GET /users/username-availability` is registered first (UsersModule is
   * imported before this module) and cannot be a username anyway (`-` is not allowed).
   */
  @Get(':username')
  @RateLimit({ bucket: 'users:profile', rule: 'profileUser', key: byUserId, replacesDefault: true })
  get(@CurrentAuth() auth: AuthContext, @Param('username') username: string): Promise<PublicProfileDto> {
    return this.profiles.get(auth.userId, username);
  }
}
