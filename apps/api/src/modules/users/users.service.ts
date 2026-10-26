import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Prisma, type UserRole, type UserStatus } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { grantFreeItemsIn } from '../bag/bag-grants.js';
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
  /** CP-010: holds the hosting permission (`live_hosts`). */
  canHost: boolean;
  /** CP-015: the host's live cover (640 px square), or null (the avatar is shown). */
  liveCoverUrl: string | null;
}

/** Public identity fields of an ACTIVE user (contract v1.3 `PublicProfile` / `UserSummary`). */
export interface PublicUser {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  bio: string | null;
  isPrivate: boolean;
}

/** A follow target locked for the duration of the caller's transaction. */
export interface LockedUser {
  id: string;
  isPrivate: boolean;
}

// `liveHost`: a read of the live module's `live_hosts` (one row or none), the documented
// read-only exception for `Me.canHost` (CP-010) and `Me.liveCoverUrl` (CP-015).
export const ME_INCLUDE = {
  profile: true,
  settings: true,
  liveHost: { select: { userId: true, coverUrl: true } },
} as const;

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
  /** Absent for a just-created account (no permission yet). */
  liveHost?: { userId: string; coverUrl?: string | null } | null;
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
    canHost: Boolean(user.liveHost),
    liveCoverUrl: user.liveHost?.coverUrl ?? null,
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
   * violations are translated to EMAIL_TAKEN / USERNAME_TAKEN. v1.22-live (CP-019, D107): the
   * account receives the free bag items and wears them (`bunny_royal`), in the same transaction.
   * This is the only path that creates accounts (verify-first registration).
   */
  async createAccount(tx: Prisma.TransactionClient, input: NewAccount): Promise<UserWithProfile> {
    try {
      const user = await tx.user.create({
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
      await grantFreeItemsIn(tx, user.id, 'FREE_SIGNUP');
      return user;
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

  /** Stored locale of a user (`ar` when unknown); used to localize server-curated names. */
  async getLocale(userId: string): Promise<'ar' | 'en'> {
    const profile = await this.prisma.userProfile.findUnique({ where: { userId }, select: { locale: true } });
    return profile?.locale === 'en' ? 'en' : 'ar';
  }

  async isEmailVerified(userId: string): Promise<boolean> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { emailVerifiedAt: true },
    });
    return user !== null && user.emailVerifiedAt !== null;
  }

  /**
   * The public identity of an ACTIVE user by username, else null (contract v1.3 §10.5). A name
   * that is not a well-formed username (§6 pattern and length) is not found without querying
   * (SEC-037: a NUL byte or other invalid text must never reach the driver). Otherwise one query
   * filtered on `status = 'ACTIVE'`, so unknown, pending-only, SUSPENDED and DELETED are
   * indistinguishable and the response time does not depend on the reason.
   */
  async findActivePublicUser(username: string): Promise<PublicUser | null> {
    if (!isValidUsername(username)) return null;
    const profile = await this.prisma.userProfile.findFirst({
      where: { username, user: { status: 'ACTIVE' } },
      select: {
        userId: true,
        username: true,
        displayName: true,
        avatarUrl: true,
        bio: true,
        user: { select: { settings: { select: { isPrivate: true } } } },
      },
    });
    if (!profile) return null;
    return {
      id: profile.userId,
      username: profile.username,
      displayName: profile.displayName,
      avatarUrl: profile.avatarUrl,
      bio: profile.bio,
      isPrivate: profile.user.settings?.isPrivate ?? false,
    };
  }

  /**
   * Locks (FOR SHARE) an ACTIVE user found by username inside the caller's transaction and returns
   * it, else null. A concurrent suspension or soft deletion either commits first (no row) or waits
   * for the caller's transaction, so a follow edge can never be written to a DELETED account.
   */
  async lockActiveByUsername(tx: Prisma.TransactionClient, username: string): Promise<LockedUser | null> {
    if (!isValidUsername(username)) return null; // SEC-037: never query with a malformed name
    const rows = await tx.$queryRaw<{ id: string; is_private: boolean | null }[]>`
      SELECT u.id::text AS id, s.is_private
        FROM user_profiles p
        JOIN users u ON u.id = p.user_id
        LEFT JOIN user_settings s ON s.user_id = u.id
       WHERE p.username = ${username} AND u.status = 'ACTIVE'::user_status
         FOR SHARE OF u`;
    const row = rows[0];
    return row ? { id: row.id, isPrivate: row.is_private ?? false } : null;
  }

  /** Like {@link lockActiveByUsername}, by id (the caller's own row). */
  async lockActiveById(tx: Prisma.TransactionClient, userId: string): Promise<boolean> {
    const rows = await tx.$queryRaw<{ id: string }[]>`
      SELECT id::text AS id FROM users WHERE id = ${userId}::uuid AND status = 'ACTIVE'::user_status FOR SHARE`;
    return rows.length === 1;
  }

  /**
   * Suspends (ACTIVE → SUSPENDED) or soft-deletes (any → DELETED, stamping `deleted_at`) an account
   * inside the caller's transaction; building block of AccountLifecycleService. Returns false when
   * nothing changed.
   */
  async deactivate(
    tx: Prisma.TransactionClient,
    userId: string,
    status: 'SUSPENDED' | 'DELETED',
    at: Date,
  ): Promise<boolean> {
    const updated = await tx.user.updateMany({
      // Suspension applies to ACTIVE accounts; soft deletion to any account not yet deleted.
      where: { id: userId, status: status === 'DELETED' ? { not: 'DELETED' } : 'ACTIVE' },
      data: { status, ...(status === 'DELETED' ? { deletedAt: at } : {}) },
    });
    return updated.count === 1;
  }

  /** PATCH /me (contract v1.2, KL-018): persists an explicit locale choice. */
  async updateLocale(userId: string, locale: 'ar' | 'en'): Promise<MeDto | null> {
    const updated = await this.prisma.userProfile.updateMany({ where: { userId }, data: { locale } });
    return updated.count === 0 ? null : this.getMe(userId);
  }
}
