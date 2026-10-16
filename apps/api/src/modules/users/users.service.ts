import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Prisma, type UserRole, type UserStatus } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { isReservedUsername, isValidUsername } from './username.js';

/** `Me` response (openapi `#/components/schemas/Me`). */
export interface MeDto {
  id: string;
  email: string;
  emailVerified: boolean;
  username: string;
  displayName: string;
  bio: string | null;
  avatarUrl: string | null;
  locale: 'ar' | 'en';
  role: UserRole;
  isPrivate: boolean;
  createdAt: string;
}

export const ME_INCLUDE = { profile: true, settings: true } as const;

export interface UserWithProfile {
  id: string;
  email: string;
  emailVerifiedAt: Date | null;
  role: UserRole;
  createdAt: Date;
  profile: {
    username: string;
    displayName: string;
    bio: string | null;
    avatarUrl: string | null;
    locale: string;
  } | null;
  settings: { isPrivate: boolean } | null;
}

export function toMeDto(user: UserWithProfile): MeDto {
  if (!user.profile) throw new Error(`User ${user.id} has no profile`);
  return {
    id: user.id,
    email: user.email,
    emailVerified: user.emailVerifiedAt !== null,
    username: user.profile.username,
    displayName: user.profile.displayName,
    bio: user.profile.bio,
    avatarUrl: user.profile.avatarUrl,
    locale: user.profile.locale === 'en' ? 'en' : 'ar',
    role: user.role,
    isPrivate: user.settings?.isPrivate ?? false,
    createdAt: user.createdAt.toISOString(),
  };
}

export interface NewAccount {
  email: string;
  passwordHash: string;
  username: string;
  displayName: string;
  locale: 'ar' | 'en';
  /** Set at creation for verify-first registration (contract v1.2). */
  emailVerifiedAt?: Date;
}

export interface LoginCandidate {
  id: string;
  passwordHash: string;
  status: UserStatus;
}

export interface MailRecipient {
  id: string;
  email: string;
  emailVerifiedAt: Date | null;
  status: UserStatus;
  locale: 'ar' | 'en';
}

/**
 * Name of the unique index a Prisma P2002 error violated, or null. Driver adapters report it in
 * `meta.driverAdapterError.cause.constraint.index`; the classic engine in `meta.target`. The
 * error *message* is never inspected: it embeds the calling source code.
 */
export function violatedUniqueIndex(err: unknown): string | null {
  if (!(err instanceof Prisma.PrismaClientKnownRequestError) || err.code !== 'P2002') return null;
  const meta = (err.meta ?? {}) as {
    target?: unknown;
    driverAdapterError?: { cause?: { constraint?: { index?: unknown; fields?: unknown } } };
  };
  const constraint = meta.driverAdapterError?.cause?.constraint;
  if (typeof constraint?.index === 'string') return constraint.index;
  if (Array.isArray(constraint?.fields)) return constraint.fields.join(',');
  if (typeof meta.target === 'string') return meta.target;
  if (Array.isArray(meta.target)) return meta.target.join(',');
  return 'unknown';
}

/** Maps a Prisma unique violation to the conflicting contract code, if recognizable. */
export function uniqueViolationCode(err: unknown): ErrorCode.EMAIL_TAKEN | ErrorCode.USERNAME_TAKEN | null {
  const index = violatedUniqueIndex(err);
  if (index === null) return null;
  if (/users_email_key|^email$/.test(index)) return ErrorCode.EMAIL_TAKEN;
  if (/user_profiles_username_key|^username$/.test(index)) return ErrorCode.USERNAME_TAKEN;
  return null;
}

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(userId: string): Promise<MeDto | null> {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, include: ME_INCLUDE });
    return user ? toMeDto(user) : null;
  }

  /**
   * Creates User + UserProfile + UserSettings inside the caller's transaction. Unique
   * violations are translated to EMAIL_TAKEN / USERNAME_TAKEN.
   */
  async createAccount(tx: Prisma.TransactionClient, input: NewAccount): Promise<UserWithProfile> {
    try {
      return await tx.user.create({
        data: {
          email: input.email,
          passwordHash: input.passwordHash,
          emailVerifiedAt: input.emailVerifiedAt ?? null,
          profile: {
            create: { username: input.username, displayName: input.displayName, locale: input.locale },
          },
          settings: { create: {} },
        },
        include: ME_INCLUDE,
      });
    } catch (err) {
      const code = uniqueViolationCode(err);
      if (code) throw new AppException(code);
      throw err;
    }
  }

  async emailExists(email: string): Promise<boolean> {
    return (await this.prisma.user.count({ where: { email } })) > 0;
  }

  async usernameExists(username: string): Promise<boolean> {
    return (await this.prisma.userProfile.count({ where: { username } })) > 0;
  }

  /** Looks a user up by normalized email or username. */
  async findLoginCandidate(
    identifier: { email: string } | { username: string },
  ): Promise<LoginCandidate | null> {
    const select = { id: true, passwordHash: true, status: true } as const;
    if ('email' in identifier) {
      return this.prisma.user.findUnique({ where: { email: identifier.email }, select });
    }
    const profile = await this.prisma.userProfile.findUnique({
      where: { username: identifier.username },
      select: { user: { select } },
    });
    return profile?.user ?? null;
  }

  async findMailRecipient(where: { id: string } | { email: string }): Promise<MailRecipient | null> {
    const user = await this.prisma.user.findUnique({
      where,
      select: {
        id: true,
        email: true,
        emailVerifiedAt: true,
        status: true,
        profile: { select: { locale: true } },
      },
    });
    if (!user) return null;
    return { ...user, locale: user.profile?.locale === 'en' ? 'en' : 'ar' };
  }

  async updatePasswordHash(
    tx: Prisma.TransactionClient | PrismaService,
    userId: string,
    passwordHash: string,
  ): Promise<void> {
    await tx.user.update({ where: { id: userId }, data: { passwordHash } });
  }

  async markEmailVerified(tx: Prisma.TransactionClient, userId: string, at: Date): Promise<void> {
    await tx.user.updateMany({ where: { id: userId, emailVerifiedAt: null }, data: { emailVerifiedAt: at } });
  }

  /**
   * True when an account has the username or a *live* pending registration (other than one for
   * `exceptEmail`, which is about to be replaced) holds it (contract v1.2 §6 rule 7).
   */
  async isUsernameTaken(username: string, exceptEmail?: string, now: Date = new Date()): Promise<boolean> {
    const [accounts, pending] = await Promise.all([
      this.prisma.userProfile.count({ where: { username } }),
      this.prisma.pendingRegistration.count({
        where: {
          username,
          expiresAt: { gt: now },
          ...(exceptEmail === undefined ? {} : { email: { not: exceptEmail } }),
        },
      }),
    ]);
    return accounts > 0 || pending > 0;
  }

  /** Reserved, malformed, taken or reserved-by-pending names are reported unavailable. */
  async isUsernameAvailable(username: string): Promise<boolean> {
    if (!isValidUsername(username) || isReservedUsername(username)) return false;
    return !(await this.isUsernameTaken(username));
  }

  /** PATCH /me (contract v1.2, KL-018): persists an explicit locale choice. */
  async updateLocale(userId: string, locale: 'ar' | 'en'): Promise<MeDto | null> {
    const updated = await this.prisma.userProfile.updateMany({ where: { userId }, data: { locale } });
    return updated.count === 0 ? null : this.getMe(userId);
  }
}
