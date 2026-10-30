import { Injectable } from '@nestjs/common';
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
import { UsersService } from '../users.service.js';

/** `PublicProfile` (openapi v1.3). Never an email, role, status, locale or created-at time. */
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
  ) {}

  /** Whether [callerId] muted [targetId] (primary-key lookup). */
  private async isMuted(callerId: string, targetId: string): Promise<boolean> {
    const row = await this.prisma.userMute.findUnique({
      where: { muterId_mutedId: { muterId: callerId, mutedId: targetId } },
      select: { muterId: true },
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
        where: { ownerUserId: user.id, suspendedAt: null, hostCode: { not: null } },
        select: { hostCode: true },
      }),
      // v1.55-social (D186): the worn avatar frame (e.g. the active-host frame).
      this.bag.avatarFrame(user.id),
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
    };
  }
}
