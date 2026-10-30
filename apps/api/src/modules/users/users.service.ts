import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Prisma, type UserRole, type UserStatus } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { grantFreeItemsIn } from '../bag/bag-grants.js';
import type { PremiumTier } from '../premium-usernames/premium-username-rules.js';
import { regularUsernameIssue } from '../premium-usernames/premium-username-rules.js';
import {
  PROFILE_LINKS_SELECT,
  profileLinkDto,
  publicGender,
  type AccountCategory,
  type Gender,
  type ProfileLinkDto,
} from './profile-fields.js';
import { resolveUserIdByUsername } from './special-usernames.js';
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
  /** v1.27.1-live (D133): the caller's own country (ISO alpha-2), or null (D45: user-chosen). */
  country: string | null;
  /** v1.28-live (D146): the tier of the caller's premium username; absent for a regular one. */
  premiumTier?: PremiumTier;
  /** v1.47-social (D175, §10.47): the caller's gender (null until chosen) and whether others see it. */
  gender: Gender | null;
  showGender: boolean;
  /** v1.47-social (D175): the account category shown under the name, or null. */
  category: AccountCategory | null;
  /** v1.47-social (D175): the profile links, in order (0–3). */
  links: ProfileLinkDto[];
  /** v1.54-social (D185): the caller's active special username; absent when none. */
  specialUsername?: MeSpecialUsernameDto;
}

/** Public identity fields of an ACTIVE user (contract v1.3 `PublicProfile` / `UserSummary`). */
export interface PublicUser {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  bio: string | null;
  isPrivate: boolean;
  /** v1.28-live (D146): the premium username's tier, or null. */
  premiumTier: PremiumTier | null;
  /** v1.47-social (D175): the gender others see (only when shown), the category and the links. */
  gender: 'MALE' | 'FEMALE' | null;
  category: AccountCategory | null;
  links: ProfileLinkDto[];
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
  profileLinks: PROFILE_LINKS_SELECT,
  settings: true,
  liveHost: { select: { userId: true, coverUrl: true } },
  // v1.54-social (D185): the caller's own ACTIVE special username (self only, never public).
  specialUsernames: {
    where: { status: 'ACTIVE' },
    select: {
      username: true,
      baseUsername: true,
      source: true,
      grantedAt: true,
      expiresAt: true,
      locked: true,
    },
    take: 1,
  },
} as const;

/** v1.54-social (D185, §10.48.1): `Me.specialUsername` — only ever in the caller's own `Me`. */
export interface MeSpecialUsernameDto {
  username: string;
  baseUsername: string;
  source: 'RECHARGE_AGENT' | 'ADMIN_GIFT' | 'PURCHASE';
  grantedAt: string;
  expiresAt: string | null;
  locked: boolean;
}

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
    /** v1.27.1-live (D133). Absent in older selects: null. */
    countryCode?: string | null;
    /** v1.28-live (D146). Absent in older selects: none. */
    premiumTier?: string | null;
    /** v1.47-social (D175). */
    gender?: Gender | null;
    showGender?: boolean;
    category?: AccountCategory | null;
  } | null;
  /** v1.47-social (D175): `ME_INCLUDE` reads them. */
  profileLinks?: { id: string; url: string; label: string | null }[];
  settings: { isPrivate: boolean } | null;
  /** Absent for a just-created account (no permission yet). */
  liveHost?: { userId: string; coverUrl?: string | null } | null;
  /** v1.54-social (D185): `ME_INCLUDE` reads the ACTIVE one. */
  specialUsernames?: {
    username: string;
    baseUsername: string;
    source: 'RECHARGE_AGENT' | 'ADMIN_GIFT' | 'PURCHASE';
    grantedAt: Date;
    expiresAt: Date | null;
    locked: boolean;
  }[];
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
    country: user.profile.countryCode ?? null,
    ...(user.profile.premiumTier ? { premiumTier: user.profile.premiumTier as PremiumTier } : {}),
    gender: user.profile.gender ?? null,
    showGender: user.profile.showGender ?? false,
    category: user.profile.category ?? null,
    links: (user.profileLinks ?? []).map(profileLinkDto),
    ...specialOf(user),
  };
}

function specialOf(user: UserWithProfile): { specialUsername?: MeSpecialUsernameDto } {
  const s = user.specialUsernames?.[0];
  if (!s) return {};
  return {
    specialUsername: {
      username: s.username,
      baseUsername: s.baseUsername,
      source: s.source,
      grantedAt: s.grantedAt.toISOString(),
      expiresAt: s.expiresAt?.toISOString() ?? null,
      locked: s.locked,
    },
  };
}

export interface NewAccount {
  email: string;
  passwordHash: string;
  username: string;
  displayName: string;
  locale: 'ar' | 'en';
  /** v1.47-social (D175): chosen at sign-up (null only for a pending row made before v1.47). */
  gender?: Gender | null;
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
            create: {
              username: input.username,
              displayName: input.displayName,
              locale: input.locale,
              gender: input.gender ?? null,
            },
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
    if (profile) return profile.user;
    // v1.54-social (D185, §10.48.1): the person's own (base) username still signs in while a special
    // one is shown. A special username in grace does not (only the username shown now and the base).
    const special = await this.prisma.specialUsername.findFirst({
      where: { baseUsername: identifier.username, status: 'ACTIVE' },
      select: { user: { select } },
    });
    return special?.user ?? null;
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
    const [accounts, pending, held] = await Promise.all([
      this.prisma.userProfile.count({ where: { username } }),
      this.prisma.pendingRegistration.count({
        where: {
          username,
          expiresAt: { gt: now },
          ...(exceptEmail === undefined ? {} : { email: { not: exceptEmail } }),
        },
      }),
      // v1.28-live (D146): the regular username a renter goes back to is kept for them.
      this.prisma.premiumUsernameLease.count({ where: { regularUsername: username, status: 'ACTIVE' } }),
      // v1.54-social (D185): a base username behind a special one, a special one in grace, any `coin` name.
      this.prisma.specialUsername.count({
        where: {
          OR: [
            { status: 'ACTIVE', baseUsername: username },
            { status: { in: ['ACTIVE', 'GRACE'] }, username },
            { username, source: 'RECHARGE_AGENT' },
          ],
        },
      }),
    ]).then(([a, p, h, s]) => [a, p, h + s] as const);
    return accounts > 0 || pending > 0 || held > 0;
  }

  /** Reserved, malformed, taken or reserved-by-pending names are reported unavailable. */
  async isUsernameAvailable(username: string): Promise<boolean> {
    // v1.28-live (D146): only a name a new account may take (the regular rule) is available.
    if (
      !isValidUsername(username) ||
      regularUsernameIssue(username) !== null ||
      isReservedUsername(username)
    ) {
      return false;
    }
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
   * (SEC-037: a NUL byte or other invalid text must never reach the driver). Otherwise the name is
   * resolved (also a base or grace name, D185) and the profile read
   * filtered on `status = 'ACTIVE'`, so unknown, pending-only, SUSPENDED and DELETED are
   * indistinguishable and the response time does not depend on the reason.
   */
  async findActivePublicUser(username: string): Promise<PublicUser | null> {
    if (!isValidUsername(username)) return null;
    // v1.54-social (D185, §10.48.1): an old link by the person's base username (behind an ACTIVE special
    // one) or by a special one in grace still leads to them; the response carries the username shown now.
    const owner = await resolveUserIdByUsername(this.prisma, username);
    if (owner === null) return null;
    const profile = await this.prisma.userProfile.findFirst({
      where: { userId: owner, user: { status: 'ACTIVE' } },
      select: {
        userId: true,
        username: true,
        displayName: true,
        avatarUrl: true,
        bio: true,
        premiumTier: true,
        gender: true,
        showGender: true,
        category: true,
        user: { select: { settings: { select: { isPrivate: true } }, profileLinks: PROFILE_LINKS_SELECT } },
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
      premiumTier: profile.premiumTier,
      gender: publicGender(profile.gender, profile.showGender),
      category: profile.category,
      links: profile.user.profileLinks.map(profileLinkDto),
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
       WHERE (p.username = ${username}
              -- v1.54-social (D185): an old link by a base or grace name still leads to the person.
              OR (NOT EXISTS (SELECT 1 FROM user_profiles p2 WHERE p2.username = ${username})
                  AND EXISTS (SELECT 1 FROM special_usernames su
                               WHERE su.user_id = u.id
                                 AND ((su.status = 'ACTIVE'::special_username_status AND su.base_username = ${username})
                                   OR (su.status = 'GRACE'::special_username_status AND su.username = ${username})))))
         AND u.status = 'ACTIVE'::user_status
       LIMIT 1
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
    return this.updateMe(userId, { locale });
  }

  /** `PATCH /me`: the fields given (v1.2 `locale`; v1.27.1-live `country`, null clears it). */
  async updateMe(
    userId: string,
    fields: { locale?: 'ar' | 'en' | undefined; country?: string | null | undefined },
  ): Promise<MeDto | null> {
    const updated = await this.prisma.userProfile.updateMany({
      where: { userId },
      data: {
        ...(fields.locale !== undefined ? { locale: fields.locale } : {}),
        ...(fields.country !== undefined ? { countryCode: fields.country } : {}),
      },
    });
    return updated.count === 0 ? null : this.getMe(userId);
  }
}
