import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

/** The one body `POST /waitlist` ever answers (202): it never says whether the email was already there. */
export const WAITLIST_ACCEPTED = { status: 'accepted' } as const;
export type WaitlistAcceptedDto = typeof WAITLIST_ACCEPTED;

export interface WaitlistSignupInput {
  /** Trimmed + lowercase (the schema normalizes it). */
  readonly email: string;
  readonly locale: 'ar' | 'en';
}

/**
 * D192 (contract v1.61-social, CONVENTIONS §10.55): the website's «أبلغني عند الإطلاق» waitlist. Owns
 * `waitlist_signups`. Idempotent per email: a repeated sign-up keeps the first row (its date and language) and
 * answers exactly the same; one `INSERT … ON CONFLICT DO NOTHING`, so both paths do the same work. No mail is sent
 * now (the launch e-mail is a later, separate step); the e-mails are read only by the `waitlist-admin` CLI.
 */
@Injectable()
export class WaitlistService {
  constructor(private readonly prisma: PrismaService) {}

  async signUp(input: WaitlistSignupInput): Promise<WaitlistAcceptedDto> {
    await this.prisma.waitlistSignup.createMany({
      data: [{ email: input.email, locale: input.locale }],
      skipDuplicates: true,
    });
    return WAITLIST_ACCEPTED;
  }
}
