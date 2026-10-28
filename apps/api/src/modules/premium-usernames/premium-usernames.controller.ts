import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  Param,
  Post,
  Put,
  Query,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { MeDto } from '../users/users.service.js';
import {
  PremiumUsernamesService,
  storeQuerySchema,
  type MyPremiumUsernameDto,
  type PremiumUsernameRentalDto,
  type PremiumUsernameStatusDto,
  type PremiumUsernameStoreDto,
} from './premium-usernames.service.js';

const idempotencyKeySchema = z.uuid();

/** D146 (§7): rent / renew, 20 / hour per user, replacing the default. */
const RENT = {
  bucket: 'premium:rent',
  rule: 'premiumRentUser',
  key: byUserId,
  replacesDefault: true,
} as const;
/** D146 (§7): username changes, 5 / day per user, replacing the default. */
const CHANGE = {
  bucket: 'username:change',
  rule: 'usernameChangeUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** Premium usernames and the username change (contract v1.28-live draft, D146, CONVENTIONS §10.32). */
@Controller()
export class PremiumUsernamesController {
  constructor(private readonly premium: PremiumUsernamesService) {}

  /** The store: tiers with prices and suggested names that are free and on sale. */
  @Get('premium-usernames')
  store(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(storeQuerySchema)) query: z.output<typeof storeQuerySchema>,
  ): Promise<PremiumUsernameStoreDto> {
    return this.premium.store(auth.userId, query.tier);
  }

  /** What one name is for the caller (the store's live check). Never 404. */
  @Get('premium-usernames/:username')
  status(
    @CurrentAuth() auth: AuthContext,
    @Param('username') username: string,
  ): Promise<PremiumUsernameStatusDto> {
    return this.premium.status(auth.userId, username);
  }

  @Get('me/premium-username')
  mine(@CurrentAuth() auth: AuthContext): Promise<{ premium: MyPremiumUsernameDto | null }> {
    return this.premium.mine(auth.userId);
  }

  /** Rent or renew. 201 new, 200 a retry with the same `Idempotency-Key`. */
  @Post('me/premium-username/rentals')
  @RateLimit(RENT)
  async rent(
    @CurrentAuth() auth: AuthContext,
    @Headers('idempotency-key') rawKey: string | undefined,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<PremiumUsernameRentalDto> {
    if (rawKey === undefined || rawKey === '') {
      throw AppException.validation([{ field: 'Idempotency-Key', issue: 'required' }]);
    }
    const key = idempotencyKeySchema.safeParse(rawKey);
    if (!key.success) throw AppException.validation([{ field: 'Idempotency-Key', issue: 'invalid_format' }]);
    const { replay, result } = await this.premium.rent(auth.userId, key.data, body);
    res.status(replay ? 200 : 201);
    return result;
  }

  /** Give the premium username back now (no refund); idempotent. */
  @Delete('me/premium-username')
  @HttpCode(204)
  @RateLimit(RENT)
  async release(@CurrentAuth() auth: AuthContext): Promise<void> {
    await this.premium.release(auth.userId);
  }

  /** A new regular username (D146 rule). */
  @Put('me/username')
  @HttpCode(200)
  @RateLimit(CHANGE)
  changeUsername(@CurrentAuth() auth: AuthContext, @Body() body: unknown): Promise<MeDto> {
    return this.premium.changeUsername(auth.userId, body);
  }
}
