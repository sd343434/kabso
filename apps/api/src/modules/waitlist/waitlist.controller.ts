import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { z } from 'zod';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { emailSchema, localeSchema } from '../auth/auth.schemas.js';
import { Public } from '../auth/public.decorator.js';
import { WaitlistService, type WaitlistAcceptedDto, type WaitlistSignupInput } from './waitlist.service.js';

export const waitlistSignupSchema = z.strictObject({ email: emailSchema, locale: localeSchema });

/**
 * `POST /waitlist` (D192, v1.61-social, §10.55): public, from the website's «أبلغني عند الإطلاق» form. Always 202
 * `{status: "accepted"}` for a valid email, new or already listed (no enumeration); 422 for an invalid body; 429
 * past `RATE_LIMIT_WAITLIST_IP` (10 / hour per client IP, bucket `waitlist:ip`, replaces the public default).
 */
@Controller('waitlist')
export class WaitlistController {
  constructor(private readonly waitlist: WaitlistService) {}

  @Public()
  @Post()
  @HttpCode(202)
  @RateLimit({ bucket: 'waitlist:ip', rule: 'waitlistIp', key: byIp, replacesDefault: true })
  signUp(
    @Body(new ZodValidationPipe(waitlistSignupSchema)) body: WaitlistSignupInput,
  ): Promise<WaitlistAcceptedDto> {
    return this.waitlist.signUp(body);
  }
}
