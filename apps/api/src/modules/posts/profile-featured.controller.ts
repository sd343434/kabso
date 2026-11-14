import { Body, Controller, Delete, Get, Param, Put } from '@nestjs/common';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import {
  ProfileFeaturedService,
  type FeaturedPinListDto,
  type ProfileFeaturedDto,
} from './profile-featured.service.js';

/** v1.138-social (D386, §7): featured-pin writes, 60 / hour per user, replacing the default. */
const PIN_WRITE = {
  bucket: 'featured:pins',
  rule: 'featuredPinsUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/**
 * v1.138-social (D386, CONVENTIONS §10.175.2–3): the featured section of a profile (the profile grid's rate limit) and
 * the caller's featured pins.
 */
@Controller()
export class ProfileFeaturedController {
  constructor(private readonly featured: ProfileFeaturedService) {}

  @Get('users/:username/featured')
  @RateLimit({ bucket: 'users:profile', rule: 'profileUser', key: byUserId, replacesDefault: true })
  get(@CurrentAuth() auth: AuthContext, @Param('username') username: string): Promise<ProfileFeaturedDto> {
    return this.featured.featured(auth.userId, username);
  }

  @Get('me/featured-pins')
  list(@CurrentAuth() auth: AuthContext): Promise<FeaturedPinListDto> {
    return this.featured.list(auth.userId);
  }

  @Put('me/featured-pins')
  @RateLimit(PIN_WRITE)
  set(@CurrentAuth() auth: AuthContext, @Body() body: unknown): Promise<FeaturedPinListDto> {
    return this.featured.set(auth.userId, body);
  }

  @Put('me/featured-pins/:postId')
  @RateLimit(PIN_WRITE)
  pin(@CurrentAuth() auth: AuthContext, @Param('postId') postId: string): Promise<FeaturedPinListDto> {
    return this.featured.pin(auth.userId, postId);
  }

  @Delete('me/featured-pins/:postId')
  @RateLimit(PIN_WRITE)
  unpin(@CurrentAuth() auth: AuthContext, @Param('postId') postId: string): Promise<FeaturedPinListDto> {
    return this.featured.unpin(auth.userId, postId);
  }
}
