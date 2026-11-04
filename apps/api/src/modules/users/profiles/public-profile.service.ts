import { Injectable, Logger } from '@nestjs/common';
import { Clock } from '../../../common/time/clock.js';
import { recordProfileVisit } from '../../vip/profile-visits.js';
import { AppException } from '../../../common/errors/app-exception.js';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { ErrorCode } from '../../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../../common/http/content-language.js';
import { BagService, type ProfileCardDto } from '../../bag/bag.service.js';
import { CouplesService, type ProfileCpDto } from '../../couples/couples.service.js';
import { FamiliesService, type ProfileFamilyDto } from '../../families/families.service.js';
import { MedalsService, type ProfileMedalsDto } from '../../medals/medals.service.js';
import { LiveRoomsService } from '../../live/live-rooms.service.js';
import { FollowsService } from '../../social/follows.service.js';
import { type AccountCategory, type ProfileLinkDto } from '../profile-fields.js';
import { activeRechargeBadge, type RechargeBadgeDto } from '../../recharge/recharge-badges.js';
import { activeVipOf } from '../../posts/post-views.js';
import { UsersService } from '../users.service.js';
import { profileStatsTotals } from './profile-stats.js';

/**
 * `PublicProfile` (openapi v1.3). Never an email, role, status, locale or created-at time (D218: only the month
 * the account was created, `joinedMonth`).
 */
export interface PublicProfileDto {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  bio: string | null;
  isPrivate: boolean;
  followerCount: number;
  followingCount: number;
  isFollowing: boolean;
  /** CP-007: the caller's own mute of this user; the muted user is never told. */
  isMuted: boolean;
  isSelf: boolean;
  liveRoomId: string | null;
  /** v1.21-live (CP-018): the user's family and role, or null. */
  family: ProfileFamilyDto | null;
  /** v1.21-live (CP-018): the user's CP couple, or null. */
  cp: ProfileCpDto | null;
  /** v1.21-live (CP-018): medals owned, the catalogue size and the newest three. */
  medals: ProfileMedalsDto;
  /** v1.22-live (CP-019): the PROFILE_CARD the user wears, or null. */
  profileCard: ProfileCardDto | null;
  /** v1.28-live (D146): the tier of the user's premium username; absent for a regular one. */
  premiumTier?: 'LEGEND' | 'RUBY' | 'GOLD' | 'SILVER';
  /** v1.47-social (D175, §10.47): the caller has a pending follow request to this private account. */
  followRequested: boolean;
  /** v1.47-social (D175): the gender, only when the user shows it (MALE / FEMALE), else null. */
  gender: 'MALE' | 'FEMALE' | null;
  /** v1.47-social (D175): the account category under the name, or null. */
  category: AccountCategory | null;
  /** v1.47-social (D175): the profile links (0–3), also on a private account's profile. */
  links: ProfileLinkDto[];
  /** v1.54-social (D185, §10.48): the user is an ACTIVE recharge agent (the frame, badge and entrance). */
  rechargeAgent: { code: string } | null;
  /** v1.58-social (D189, §10.52): the host agent's code while not suspended (frame, badge), else null. */
  hostAgent: { code: string } | null;
  /** v1.55-social (D186, §10.49): the avatar frame the user wears now (`AvatarFrame`), or null. */
  avatarFrame: { code: string; assetKey: string } | null;
  /** v1.56-social (D187, §10.50): present only while the daily recharge badge is showing. */
  rechargeBadge?: RechargeBadgeDto;
  /** v1.83-social (D258, §10.94): present only while the user holds an active VIP (`UserVip`). */
  /** v1.65-live (D264): `off` — the VIP items the member took off in the bag (absent when none). */
  vip?: { tier: string; rank: number; color: string; off?: string[] };
  /** v1.76-social (D218, §10.73.3): the profile cover (1 080 px), or null (the app's Kabso gradient). */
  coverUrl: string | null;
  /** v1.76-social (D218): the country the user chose (D133, ISO alpha-2), or null. */
  country: string | null;
  /** v1.76-social (D218): the month the account was created, `YYYY-MM` (UTC). */
  joinedMonth: string;
  /** v1.76-social (D218): the caller blocked this user (the profile's «إلغاء الحظر»); false when isSelf. */
  blockedByMe: boolean;
  /**
   * v1.77-social (D220, §10.74): the lifetime cherries received from gifts. Absent when the user hides it
   * (`PrivacySettings.hideCherriesReceived`) and the caller is someone else: the value is not computed or sent.
   */
  cherriesReceived?: number;
  /** v1.77-social (D220, §10.74): the lifetime coins sent on gifts; absent like `cherriesReceived` (`hideCoinsSent`). */
  coinsSent?: number;
}

/**
 * `GET /users/{username}` (CONVENTIONS §10.5). Composes the users module (identity), social
 * (counts, isFollowing), live (`liveRoomId`) and, v1.21-live (CP-018), families, couples and
 * medals, and v1.22-live (CP-019) the bag, through their services. Lives in its own module so
 * that `live` and `social` can depend on `users` without a cycle.
 */
@Injectable()
export class PublicProfileService {
  constructor(
    private readonly users: UsersService,
    private readonly follows: FollowsService,
    private readonly live: LiveRoomsService,
    private readonly prisma: PrismaService,
    private readonly families: FamiliesService,
    private readonly couples: CouplesService,
    private readonly medals: MedalsService,
    private readonly bag: BagService,
    private readonly clock: Clock,
  ) {}

  private readonly logger = new Logger(PublicProfileService.name);

  /**
   * v1.77-social (D220, §10.74): the card's lifetime totals the caller may see — both for the user themself; for
   * anyone else only those the user does not hide. A hidden total is not even read.
   */
  private async statsFor(
    userId: string,
    isSelf: boolean,
  ): Promise<{ cherriesReceived?: number; coinsSent?: number }> {
    const hidden = isSelf
      ? null
      : await this.prisma.privacySettings.findUnique({
          where: { userId },
          select: { hideCherriesReceived: true, hideCoinsSent: true },
        });
    const which = { cherries: !hidden?.hideCherriesReceived, coins: !hidden?.hideCoinsSent };
    if (!which.cherries && !which.coins) return {};
    return profileStatsTotals(this.prisma, userId, which);
  }

  /** Whether [callerId] muted [targetId] (primary-key lookup). */
  private async isMuted(callerId: string, targetId: string): Promise<boolean> {
    const row = await this.prisma.userMute.findUnique({
      where: { muterId_mutedId: { muterId: callerId, mutedId: targetId } },
      select: { muterId: true },
    });
    return row !== null;
  }

  /** Whether [callerId] blocked [targetId] (primary-key lookup). */
  private async blocked(callerId: string, targetId: string): Promise<boolean> {
    const row = await this.prisma.userBlock.findUnique({
      where: { blockerId_blockedId: { blockerId: callerId, blockedId: targetId } },
      select: { blockerId: true },
    });
    return row !== null;
  }

  async get(callerId: string, username: string, lang: ContentLanguage): Promise<PublicProfileDto> {
    const user = await this.users.findActivePublicUser(username);
    // Malformed, unknown, pending-only, SUSPENDED and DELETED: the same 404 body.
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    const isSelf = user.id === callerId;
    const [
      counts,
      isFollowing,
      followRequested,
      isMuted,
      liveRoomId,
      family,
      cp,
      medals,
      profileCard,
      agent,
      hostAgency,
      avatarFrame,
      badge,
      blockedByMe,
      stats,
      membership,
    ] = await Promise.all([
      this.follows.counts(user.id),
      isSelf ? Promise.resolve(false) : this.follows.isFollowing(callerId, user.id),
      isSelf ? Promise.resolve(false) : this.follows.isRequested(callerId, user.id),
      isSelf ? Promise.resolve(false) : this.isMuted(callerId, user.id),
      this.live.freshLiveRoomIdOf(user.id),
      this.families.profileFamily(user.id),
      this.couples.profileCp(user.id, lang),
      this.medals.profileMedals(user.id, lang),
      this.bag.profileCard(user.id),
      // v1.54-social (D185): the perks follow the status (the user is ACTIVE here).
      this.prisma.rechargeAgent.findFirst({
        where: { userId: user.id, status: 'ACTIVE', code: { not: null } },
        select: { code: true },
      }),
      // v1.58-social (D189): the agency's owner while not suspended (any rank).
      this.prisma.agency.findFirst({
        where: { ownerUserId: user.id, suspendedAt: null, status: 'OPEN', hostCode: { not: null } },
        select: { hostCode: true },
      }),
      // v1.55-social (D186): the worn avatar frame (e.g. the active-host frame).
      this.bag.avatarFrame(user.id),
      // v1.56-social (D187): the daily recharge badge — never for a recharge agent (from approval on).
      this.prisma.rechargeBadge.findFirst({
        where: { userId: user.id, user: { rechargeAgent: { is: null } } },
        select: { tier: true, until: true },
      }),
      // v1.76-social (D218): the caller's own block of this user.
      isSelf ? Promise.resolve(false) : this.blocked(callerId, user.id),
      // v1.77-social (D220): the card's lifetime totals, minus what the user hides from others.
      this.statsFor(user.id, isSelf),
      // v1.83-social (D258): the VIP membership (shown while active).
      this.prisma.vipMembership.findUnique({
        where: { userId: user.id },
        select: {
          expiresAt: true,
          offPerks: true,
          tier: { select: { code: true, sortOrder: true, color: true } },
        },
      }),
    ]);
    // v1.83-social (D258, §10.94.9): someone else's opening is a visit («من زار ملفي»); never fails the read.
    if (!isSelf) {
      await recordProfileVisit(this.prisma, user.id, callerId, this.clock.now()).catch((err: unknown) => {
        this.logger.warn(`profile visit not recorded: ${String(err)}`);
      });
    }
    const shown = activeRechargeBadge(badge, new Date());
    // v1.65-live (D264): a profile card or frame worn from the bag covers the VIP one (one worn item per kind).
    const vip = activeVipOf({ vipMembership: membership }, new Date(), [
      ...(profileCard ? ['PROFILE_CARD'] : []),
      ...(avatarFrame ? ['AVATAR_FRAME'] : []),
    ]);
    return {
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      bio: user.bio,
      isPrivate: user.isPrivate,
      ...(user.premiumTier ? { premiumTier: user.premiumTier } : {}),
      followerCount: counts.followerCount,
      followingCount: counts.followingCount,
      isFollowing,
      followRequested,
      isMuted,
      isSelf,
      liveRoomId,
      family,
      cp,
      medals,
      profileCard,
      gender: user.gender,
      category: user.category,
      links: user.links,
      rechargeAgent: agent?.code ? { code: agent.code } : null,
      hostAgent: hostAgency?.hostCode ? { code: hostAgency.hostCode } : null,
      avatarFrame,
      ...(shown ? { rechargeBadge: shown } : {}),
      ...(vip ? { vip } : {}),
      coverUrl: user.coverUrl,
      country: user.country,
      joinedMonth: user.joinedMonth,
      blockedByMe,
      ...stats,
    };
  }
}
