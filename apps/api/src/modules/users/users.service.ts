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

/** Maps a Prisma unique violation to the conflicting contract code, if recognizable. */
export function uniqueViolationCode(err: unknown): ErrorCode.EMAIL_TAKEN | ErrorCode.USERNAME_TAKEN | null {
  if (!(err instanceof Prisma.PrismaClientKnownRequestError) || err.code !== 'P2002') return null;
  // Driver adapters report the constraint in different meta shapes; inspect all of it.
  const haystack = `${JSON.stringify(err.meta ?? {})} ${err.message}`;
  if (/users_email_key|\bemail\b/.test(haystack)) return ErrorCode.EMAIL_TAKEN;
  if (/user_profiles_username_key|\busername\b/.test(haystack)) return ErrorCode.USERNAME_TAKEN;
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

  /** Reserved or malformed names are reported unavailable. */
  async isUsernameAvailable(username: string): Promise<boolean> {
    if (!isValidUsername(username) || isReservedUsername(username)) return false;
    const existing = await this.prisma.userProfile.findUnique({
      where: { username },
      select: { userId: true },
    });
    return existing === null;
  }
}
