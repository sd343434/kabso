import { Controller, Get, Query } from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { AuthContext } from '../../common/http/request-context.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { usernameSchema } from '../auth/auth.schemas.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { Public } from '../auth/public.decorator.js';
import { UsersService, type MeDto } from './users.service.js';

const availabilityQuery = z.strictObject({ username: usernameSchema });

@Controller()
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  async me(@CurrentAuth() auth: AuthContext): Promise<MeDto> {
    const me = await this.users.getMe(auth.userId);
    if (!me) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    return me;
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
