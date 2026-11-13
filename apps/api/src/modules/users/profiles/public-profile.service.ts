import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { REDIS } from '../../../redis/redis.module.js';
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
import { LiveRoomsService, type ProfileLiveDto } from '../../live/live-rooms.service.js';
import { FollowsService } from '../../social/follows.service.js';
import { type AccountCategory, type ProfileLinkDto } from '../profile-fields.js';
import { activeRechargeBadge, type RechargeBadgeDto } from '../../recharge/recharge-badges.js';
import { activeVipOf, heldGoldenIdOf } from '../../posts/post-views.js';
import type { StoreWearDto } from '../../store/store-rules.js';
import { UsersService } from '../users.service.js';
import { profileStatsTotals } from './profile-stats.js';
import { isPanelStaff, staffIdentityOf, type LimitedStaffRole } from '../../live/live-staff.js';
import { staffIdOf } from '../staff-ids.js';
import { MediaService } from '../../media/media.service.js';
import {
  ownerProfileFields,
  type OwnerBioDto,
  type OwnerCoverVideoDto,
} from '../../owner-profile/owner-core.js';
import type { VerificationBadgeValue } from '../../verification/verification-rules.js';
import { visibleStatusEmoji } from '../../status-emoji/status-emoji-catalogue.js';
import type { StaffRegion } from '../../live/staff-regions.js';
import { shownAnimatedAvatarIn } from '../animated-avatar.js';
import { ambassadorBadgeIn } from '../../ambassadors/ambassador-core.js';
import type { AnimatedAvatarDto } from '../profile-edit.service.js';

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
  /**
   * v1.68-live (D273, §10.96.7): the account holds a panel role — «فريق كابسو»; the app hides the actions against it
   * (kick, mute, seat, family) and the server refuses them (403 STAFF_PROTECTED). Absent (false) for everyone else.
   */
  kabsoTeam?: true;
  /**
   * v1.72-live (D283, §10.96.10–11): a limited Kabso Team account (MODERATION / SUPPORT / FINANCE, not OWNER) — the
   * role its profile line names and its regions; the app shows the team badge and frame, the line, and no levels.
   * Absent for everyone else (the OWNER too).
   */
  staff?: { role: LimitedStaffRole; regions: StaffRegion[]; staffId?: string };
  /** v1.73-live (D283c, §10.96.12): the official staff ID «Kabso01» while a panel role is held (the OWNER too). */
  staffId?: string;
  /** v1.131-social (D378, §10.168.4): the golden ID held now (`UserSummary.goldenId`). */
  goldenId?: { number: string; class: string };
  liveRoomId: string | null;
  /**
   * v1.70-live (D279, §10.5.1): the «في بث الآن» card's facts while `liveRoomId` is set (null otherwise, and across a
   * block either way, as the room itself).
   */
  live: ProfileLiveDto | null;
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
  /** v1.85-social (D278b, §10.99): the profile tags «منشنات» (0–10), also on a private account's profile. */
  tags: string[];
  /** v1.91-social (D292, §10.106): the icon of each tag, one per tag. */
  tagIcons: string[];
  /** v1.54-social (D185, §10.48): the user is an ACTIVE recharge agent (the frame, badge and entrance). */
  rechargeAgent: { code: string } | null;
  /** v1.58-social (D189, §10.52): the host agent's code while not suspended (frame, badge), else null. */
  hostAgent: { code: string } | null;
  /**
   * v1.90-social (D293, §10.105): the automatic verification badge «شارة التوثيق» beside the name — only its type
   * (never an amount or a threshold), or null.
   */
  verification: VerificationBadgeValue | null;
  /** v1.130-social (D376, §10.167): «الحالة» — the status emoji worn over the picture, or null. */
  statusEmojiId: string | null;
  /** v1.55-social (D186, §10.49): the avatar frame the user wears now (`AvatarFrame`), or null. */
  avatarFrame: { code: string; assetKey: string } | null;
  /** v1.56-social (D187, §10.50): present only while the daily recharge badge is showing. */
  rechargeBadge?: RechargeBadgeDto;
  /** v1.83-social (D258, §10.94): present only while the user holds an active VIP (`UserVip`). */
  /** v1.65-live (D264): `off` — the VIP items the member took off in the bag (absent when none). */
  vip?: { tier: string; rank: number; color: string; off?: string[]; signature?: string };
  /** D270 (§10.98): the store items the user wears now, by kind (absent when none). */
  wear?: StoreWearDto;
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
  /** v1.95-social (D301, §10.112): the app owner (an ACTIVE account holding the OWNER panel role); absent otherwise. */
  kabsoOwner?: true;
  /**
   * v1.140-social (D390 follow-up, §10.179.9): the exclusive ambassador badge — `{level}` only while the programme is on
   * and the membership is ACTIVE; absent otherwise (frozen and ended stay private).
   */
  ambassador?: { level: string };
  /** v1.95-social (D301, §10.112.1): the owner's cover videos per language (only with at least one). */
  coverVideo?: OwnerCoverVideoDto;
  /** v1.98-social (D307, §10.112.11): the owner's bilingual bio (only with at least one language). */
  ownerBio?: OwnerBioDto;
  /** v1.118-social (D357, §10.153): the «اقترح ميزة / أبلغ» submissions the founder received (owner only). */
  founderFeedbackCount?: number;
  /**
   * v1.136-social (D384, §10.173.4): the VIP animated picture — only while the person holds the ANIMATED_AVATAR perk
   * and has a clip, never across a block either way, never for a limited Kabso Team account.
   */
  animatedAvatar?: AnimatedAvatarDto;
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
    private readonly media: MediaService,
    @Inject(REDIS) private readonly redis: Redis,
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
      { liveRoomId, live },
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
      verification,
      membership,
      worn,
      status,
    ] = await Promise.all([
      this.follows.counts(user.id),
      isSelf ? Promise.resolve(false) : this.follows.isFollowing(callerId, user.id),
      isSelf ? Promise.resolve(false) : this.follows.isRequested(callerId, user.id),
      isSelf ? Promise.resolve(false) : this.isMuted(callerId, user.id),
      this.live.profileLiveOf(user.id, callerId),
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
      // v1.90-social (D293, §10.105): the stored verification badge (only its type).
      this.prisma.userVerificationBadge.findUnique({ where: { userId: user.id }, select: { badge: true } }),
      // v1.83-social (D258): the VIP membership (shown while active).
      this.prisma.vipMembership.findUnique({
        where: { userId: user.id },
        select: {
          expiresAt: true,
          offPerks: true,
          // v1.131-social (D378): the ANIMATED_SIGNATURE text.
          signature: true,
          tier: { select: { code: true, sortOrder: true, color: true } },
        },
      }),
      // D270 (§10.98): every stored item worn now (its kind covers the VIP one) and the store items' art.
      this.bag.wornNow(user.id),
      // v1.130-social (D376, §10.167): the status emoji and the status packs held.
      this.prisma.user.findUnique({
        where: { id: user.id },
        select: { statusEmojiId: true, statusPacks: { select: { packId: true, expiresAt: true } } },
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
    // D270: every stored kind worn (a store bubble, banner or car covers the VIP one too).
    const vip = activeVipOf({ vipMembership: membership }, new Date(), worn.categories);
    const staff = await staffIdentityOf(this.prisma, user.id);
    // v1.73-live (D283c, §10.96.12): the official staff ID «Kabso01» while a panel role is held (the OWNER too).
    const staffId = await staffIdOf(this.prisma, user.id);
    // v1.124-social (D367, §10.160): a Kabso Team account (any panel role, the founder too) shows no account category.
    const kabsoTeam = await isPanelStaff(this.prisma, user.id);
    const golden = heldGoldenIdOf(
      {
        vipGoldenId: await this.prisma.vipGoldenId.findUnique({
          where: { holderId: user.id },
          select: { number: true, class: true, state: true, heldUntil: true },
        }),
        vipMembership: membership,
      },
      new Date(),
    );
    // v1.136-social (D384, §10.173.4): the animated picture while the perk is held; never across a block.
    const animatedAvatar = staff
      ? null
      : await shownAnimatedAvatarIn(this.prisma, user.id, callerId, this.clock.now());
    // v1.140-social (D390 follow-up, §10.179.9): the ambassador badge (ACTIVE membership, programme on).
    const ambassadorLevel = staff ? null : await ambassadorBadgeIn(this.prisma, user.id);
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
      ...(kabsoTeam ? { kabsoTeam: true as const } : {}),
      ...(staffId ? { staffId } : {}),
      // v1.131-social (D378, §10.168.4): the golden ID held now (not on a Kabso Team account).
      ...(golden && !kabsoTeam ? { goldenId: golden } : {}),
      ...(staff ? { staff: { ...staff, ...(staffId ? { staffId } : {}) } } : {}),
      liveRoomId,
      live,
      family,
      cp,
      medals,
      profileCard,
      gender: user.gender,
      category: kabsoTeam ? null : user.category,
      links: user.links,
      tags: user.tags,
      tagIcons: user.tagIcons,
      rechargeAgent: agent?.code ? { code: agent.code } : null,
      hostAgent: hostAgency?.hostCode ? { code: hostAgency.hostCode } : null,
      verification: verification?.badge ?? null,
      // v1.130-social (D376, §10.167): «الحالة» (a store pack's only while held; never on a limited staff account).
      statusEmojiId: staff
        ? null
        : visibleStatusEmoji(status?.statusEmojiId, status?.statusPacks, new Date()),
      // v1.72-live (D283, §10.96.10): a limited staff account wears only the team frame (the app's) and its region's
      // team cover — no bag, VIP or store frame, no VIP / store wear, no cover of its own.
      avatarFrame: staff ? null : avatarFrame,
      ...(shown ? { rechargeBadge: shown } : {}),
      ...(vip && !staff ? { vip } : {}),
      ...(worn.wear && !staff ? { wear: worn.wear } : {}),
      coverUrl: staff ? null : user.coverUrl,
      country: user.country,
      joinedMonth: user.joinedMonth,
      blockedByMe,
      ...stats,
      ...(animatedAvatar ? { animatedAvatar } : {}),
      ...(ambassadorLevel ? { ambassador: { level: ambassadorLevel } } : {}),
      // v1.95-social (D301, §10.112): the owner's profile layout and cover videos; v1.118-social (D357) the count of
      // «اقترح ميزة / أبلغ» submissions he has received (cached).
      ...(await ownerProfileFields(
        this.prisma,
        user.id,
        (key) => this.media.largeUrl({ largeKey: key }),
        this.redis,
      )),
    };
  }
}
