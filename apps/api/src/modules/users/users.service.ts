import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Prisma, type UserRole, type UserStatus } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { ModerationStatus } from '../media/media.constants.js';
import { MediaUrls, NO_IMAGE, type ImageUrls } from '../media/media-urls.js';
import { isReservedUsername, isValidUsername } from './username.js';

/** `Me` response (openapi `#/components/schemas/Me`). */
export interface MeDto {
  id: string;
  email: string;
  emailVerified: boolean;
  username: string;
  displayName: string;
  bio: string | null;
  /** v1.4: the caller's own avatar, also while PENDING (CONVENTIONS §11.5). */
  avatarUrl: string | null;
  avatarThumbUrl: string | null;
  /** v1.4: moderation state of the current avatar; null when there is none. */
  avatarModeration: ModerationStatus | null;
  /** v1.4: the country the user chose; null unless set. */
  country: string | null;
  locale: 'ar' | 'en';
  role: UserRole;
  isPrivate: boolean;
  createdAt: string;
}

/** Public identity fields of an ACTIVE user (contract v1.3 `PublicProfile` / `UserSummary`). */
export interface PublicUser {
  id: string;
  username: string;
  displayName: string;
  /** v1.4: computed for the viewer under the moderation visibility rule (CONVENTIONS §11.5). */
  avatarUrl: string | null;
  avatarThumbUrl: string | null;
  bio: string | null;
  /** v1.4: the user's chosen country, else null. */
  country: string | null;
  isPrivate: boolean;
}

/** The avatar columns read for URLs and visibility (never the original upload). */
export const AVATAR_MEDIA_SELECT = {
  ownerUserId: true,
  purpose: true,
  status: true,
  publicToken: true,
  moderationStatus: true,
} as const;

export interface AvatarMediaRow {
  ownerUserId: string;
  purpose: 'AVATAR' | 'ROOM_COVER';
  status: string;
  publicToken: string | null;
  moderationStatus: ModerationStatus | null;
}

/** The profile columns `PATCH /me` changes (v1.4), locked for the edit. */
export interface LockedProfile {
  readonly avatarMediaId: string | null;
  readonly country: string | null;
}

export interface ProfileUpdate {
  readonly locale?: 'ar' | 'en';
  readonly country?: string | null;
  readonly avatarMediaId?: string | null;
}

/** A follow target locked for the duration of the caller's transaction. */
export interface LockedUser {
  id: string;
  isPrivate: boolean;
}

export const ME_INCLUDE = {
  profile: { include: { avatarMedia: { select: AVATAR_MEDIA_SELECT } } },
  settings: true,
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
    locale: string;
    country: string | null;
    avatarMedia: AvatarMediaRow | null;
  } | null;
  settings: { isPrivate: boolean } | null;
}

/**
 * `Me` for its owner. `urls` builds the avatar URLs (the owner sees a PENDING avatar); without
 * it (a just-created account, which has no avatar) every image field is null.
 */
export function toMeDto(user: UserWithProfile, urls: MediaUrls | null = null): MeDto {
  if (!user.profile) throw new Error(`User ${user.id} has no profile`);
  const media = user.profile.avatarMedia;
  const avatar: ImageUrls = urls && media ? urls.visibleUrls(media, user.id) : NO_IMAGE;
  return {
    id: user.id,
    email: user.email,
    emailVerified: user.emailVerifiedAt !== null,
    username: user.profile.username,
    displayName: user.profile.displayName,
    bio: user.profile.bio,
    avatarUrl: avatar.url,
    avatarThumbUrl: avatar.thumbUrl,
    avatarModeration: media?.moderationStatus ?? null,
    country: user.profile.country,
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
  constructor(
    private readonly prisma: PrismaService,
    private readonly mediaUrls: MediaUrls,
  ) {}

  async getMe(userId: string): Promise<MeDto | null> {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, include: ME_INCLUDE });
    return user ? toMeDto(user, this.mediaUrls) : null;
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
  async findActivePublicUser(username: string, viewerId: string | null): Promise<PublicUser | null> {
    if (!isValidUsername(username)) return null;
    const profile = await this.prisma.userProfile.findFirst({
      where: { username, user: { status: 'ACTIVE' } },
      select: {
        userId: true,
        username: true,
        displayName: true,
        bio: true,
        country: true,
        avatarMedia: { select: AVATAR_MEDIA_SELECT },
        user: { select: { settings: { select: { isPrivate: true } } } },
      },
    });
    if (!profile) return null;
    const avatar = this.mediaUrls.visibleUrls(profile.avatarMedia, viewerId);
    return {
      id: profile.userId,
      username: profile.username,
      displayName: profile.displayName,
      avatarUrl: avatar.url,
      avatarThumbUrl: avatar.thumbUrl,
      bio: profile.bio,
      country: profile.country,
      isPrivate: profile.user.settings?.isPrivate ?? false,
    };
  }

  /**
   * v1.4: the host's chosen country inside the go-live transaction, share-locked so a concurrent
   * `PATCH /me` country change (which locks the row for update) is either seen or waits (§11.8).
   */
  async countryOfIn(tx: Prisma.TransactionClient, userId: string): Promise<string | null> {
    const rows = await tx.$queryRaw<{ country: string | null }[]>`
      SELECT country::text AS country FROM user_profiles WHERE user_id = ${userId}::uuid FOR SHARE`;
    return rows[0]?.country ?? null;
  }

  /** v1.4 `PATCH /me`: locks the caller's profile row for the edit; null when it does not exist. */
  async lockProfileIn(tx: Prisma.TransactionClient, userId: string): Promise<LockedProfile | null> {
    const rows = await tx.$queryRaw<{ avatar_media_id: string | null; country: string | null }[]>`
      SELECT avatar_media_id::text AS avatar_media_id, country::text AS country
        FROM user_profiles WHERE user_id = ${userId}::uuid FOR UPDATE`;
    const row = rows[0];
    return row ? { avatarMediaId: row.avatar_media_id, country: row.country } : null;
  }

  /** v1.4 `PATCH /me`: writes the changed profile columns inside the caller's transaction. */
  async updateProfileIn(tx: Prisma.TransactionClient, userId: string, update: ProfileUpdate): Promise<void> {
    const data: Prisma.UserProfileUncheckedUpdateInput = {};
    if (update.locale !== undefined) data.locale = update.locale;
    if (update.country !== undefined) data.country = update.country;
    if (update.avatarMediaId !== undefined) data.avatarMediaId = update.avatarMediaId;
    if (Object.keys(data).length === 0) return;
    await tx.userProfile.update({ where: { userId }, data });
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
}
