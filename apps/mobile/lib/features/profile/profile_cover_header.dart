// D218: the profile header shared by the public profile and (owner:
// «وحدهما») the own profile — the cover with the photo (D244: inside it),
// then the name, the level badges, the counts, the bio, the country and the
// month joined, the links, the buttons and the family / relationship /
// medals tiles.

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/bag/presentation/avatar_frame_art.dart';
import 'package:kabso_live/features/cp/presentation/cp_special_frame.dart';
import 'package:kabso_live/features/levels/presentation/profile_levels.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_badge.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D218 geometry of the public profile (the owner's reference, right
/// phone; E at ≈0.81 px/dp, 393 dp wide assumed): the cover under the
/// restored top bar (owner after D218), 44 dp pill buttons.
///
/// D244 (owner: «الاسم لا يظهر تحت الصورة، اجعل الصورة داخل الغلاف … يمكن
/// أن تجعل الغلاف أكبر قليلاً»): the photo no longer straddles the cover's
/// edge — a worn frame (up to the frames' common box, 1.6 × the photo wide)
/// hung over the name. The photo and any frame sit wholly inside the cover,
/// in [avatarSlot] at the reading start, and the cover is that slot's height
/// plus [coverMargin] above and below (≈153 dp, was 140).
abstract final class KPublicProfile {
  /// The box every profile photo is drawn in, frame or not: the frames'
  /// common box (`AvatarFrameBox.aroundAvatar`), the real extent of the
  /// largest frame.
  static final AvatarFrameBox avatarSlot = AvatarFrameBox.aroundAvatar(
    KProfile.avatar,
  );

  /// The cover's space above and below [avatarSlot].
  static const double coverMargin = KSpacing.md;

  /// From the screen's reading-start edge to [avatarSlot].
  static const double avatarStart = KSpacing.sm;

  static double get coverHeight => avatarSlot.height + 2 * coverMargin;
  static const double buttonHeight = 44;
  static const double nameFont = 18;
  static const double factIcon = 16;
}

/// D218: the cover (or the Kabso gradient) under the top bar, and the photo
/// at the reading start — D244: wholly inside the cover, frame included,
/// centred in [KPublicProfile.avatarSlot]. (The reference's back
/// and ⋮ squares over the cover were removed: owner, «ارجعهم مثل ما كانو».)
class ProfileCoverHeader extends StatelessWidget {
  const new({required this.profile, super.key, this.onCoverTap, this.cpFrame});

  final PublicProfile profile;

  /// The own profile: a tap on the cover opens «صورة الغلاف» (choose, take,
  /// remove).
  final VoidCallback? onCoverTap;

  /// Whether the photo wears the CP heart frame; default: the couple's
  /// privilege (others see it). D168: the own page shows the plain photo.
  final bool? cpFrame;

  static const coverKey = Key('profile.public.cover');
  static const coverFallbackKey = Key('profile.public.cover.gradient');
  static const coverButtonKey = Key('profile.cover.tap');
  static const watchLiveKey = Key('profile.public.watchLive');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    // Under the restored bar (owner, after D218): no status-bar inset here.
    final coverHeight = KPublicProfile.coverHeight;
    final slot = KPublicProfile.avatarSlot;
    final room = profile.liveRoomId;
    final live = room != null;
    final fallback = DecoratedBox(
      key: ProfileCoverHeader.coverFallbackKey,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            KBrandColors.red700,
            KBrandColors.red500,
            KBrandColors.red400.withValues(alpha: 0.85),
          ],
        ),
      ),
    );
    return SizedBox(
      // D244: nothing hangs below the cover (the live badge fits in the
      // slot), so the name under it is never covered.
      height: coverHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: coverHeight,
            child: switch (profile.coverUrl) {
              final url? => Image.network(
                url,
                key: ProfileCoverHeader.coverKey,
                fit: BoxFit.cover,
                semanticLabel: l10n.profileCoverOf(profile.displayName),
                errorBuilder: (_, _, _) => fallback,
              ),
              null => fallback,
            },
          ),
          // The own profile: the cover is a button (change it).
          if (onCoverTap case final tap?)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: coverHeight,
              child: Semantics(
                button: true,
                label: l10n.profileEditCover,
                excludeSemantics: true,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(key: coverButtonKey, onTap: tap),
                ),
              ),
            ),
          PositionedDirectional(
            top: KPublicProfile.coverMargin,
            start: KPublicProfile.avatarStart,
            width: slot.width,
            height: slot.height,
            child: Center(
              child: Semantics(
                key: ProfileHeaderView.avatarKey,
                button: live,
                label: live ? l10n.profileWatchLive : null,
                // While live the photo is the way into the room (one label).
                excludeSemantics: live,
                child: GestureDetector(
                  key: live ? ProfileCoverHeader.watchLiveKey : null,
                  onTap: live
                      ? () => context.push(AppRoutes.liveRoom(room))
                      : null,
                  // D258: the VIP's animated frame, unless an agent or bag
                  // frame is worn (those keep their own art).
                  child: VipAvatarFrame(
                    vip:
                        profile.rechargeAgentCode == null &&
                            profile.hostAgentCode == null &&
                            profile.avatarFrame == null
                        ? profile.vip
                        : null,
                    size: KProfile.avatar,
                    child: ProfileAvatar(
                      displayName: profile.displayName,
                      avatarUrl: profile.avatarUrl,
                      live: live,
                      cpFrame: cpFrame ?? cpWearsSpecialFrame(profile.cp),
                      agentCode: profile.rechargeAgentCode,
                      hostAgentCode: profile.hostAgentCode,
                      avatarFrame: profile.avatarFrame,
                      outline: p.background,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// D218: the name and the level badges, the counts, the bio, the country
/// and the month joined, the links, the buttons, then our features.
class ProfileInfoBlock extends StatelessWidget {
  const new({
    required this.profile,
    required this.actions,
    super.key,
    this.onOpenFollowers,
    this.onOpenFollowing,
    this.countsKnown = true,
    this.countsFailed = false,
  });

  final PublicProfile profile;
  final Widget actions;
  final VoidCallback? onOpenFollowers;
  final VoidCallback? onOpenFollowing;

  /// The own profile while `GET /users/{me}` loads: the counts show a
  /// skeleton, never a made-up 0.
  final bool countsKnown;

  /// The counts could not be read: a dash, never a made-up number (pull to
  /// refresh retries).
  final bool countsFailed;

  static const factsKey = Key('profile.public.facts');
  static const levelsKey = Key('profile.public.levels');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context);
    final tag = locale.toLanguageTag();
    final bio = profile.bio;
    final arabic = locale.languageCode == 'ar';
    final country = KCountries.byCode(profile.country);
    final joined = switch (profile.joinedMonth?.split('-')) {
      [final y, final m]
          when int.tryParse(y) != null && int.tryParse(m) != null =>
        DateTime(int.parse(y), int.parse(m)),
      _ => null,
    };
    final muted = t.caption.copyWith(color: p.textSecondary, fontSize: 13);
    Widget count(int value, String label, VoidCallback? onTap, Key key) =>
        Semantics(
          key: key,
          button: onTap != null,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(KRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.xxs),
              child: !countsKnown && !countsFailed
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const KSkeleton(width: KSpacing.xl),
                        const SizedBox(width: KSpacing.xs),
                        Text(
                          label,
                          style: t.body.copyWith(color: p.textPrimary),
                        ),
                      ],
                    )
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: countsFailed
                                ? '\u2013'
                                : KFormat.compact(value, l10n),
                            style: t.bodyStrong.copyWith(
                              color: p.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: label,
                            style: t.body.copyWith(color: p.textPrimary),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
    Widget fact(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: KPublicProfile.factIcon, color: p.textSecondary),
        const SizedBox(width: KSpacing.xs),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
      ],
    );
    final agentCode = profile.rechargeAgentCode;
    final hostCode = profile.hostAgentCode;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        KProfile.inset,
        KSpacing.sm,
        KProfile.inset,
        KSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The name, our badges and the handle on one line (they wrap).
          // No verification mark (owner, D218: decided later).
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: KSpacing.sm,
            runSpacing: KSpacing.xxs,
            children: [
              Text(
                profile.displayName,
                key: const Key('profile.displayName'),
                style: t.title.copyWith(
                  color: p.textPrimary,
                  fontSize: KPublicProfile.nameFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (agentCode case final code?)
                RechargeAgentBadge(
                  key: ProfileHeaderView.agentBadgeKey,
                  code: code,
                ),
              if (hostCode case final code?)
                HostAgentBadge(
                  key: ProfileHeaderView.hostAgentBadgeKey,
                  code: code,
                ),
              if (rechargeBadgeShows(profile.rechargeBadge))
                RechargeTierBadge(
                  key: ProfileHeaderView.rechargeBadgeKey,
                  badge: profile.rechargeBadge,
                ),
              // D258: the VIP badge.
              if (profile.vip != null)
                VipNameBadge(vip: profile.vip, height: 20),
              // Owner (after D218): «اليوزر فقط بالاعلى وليس بجانب الاسم» —
              // the @username is only in the top bar; this place is kept
              // for a verification mark (none yet).
            ],
          ),
          // Owner (after D218): «واسفلها ميداليات الليفيل» — the level
          // badges right under the name.
          ProfileLevels(
            key: ProfileInfoBlock.levelsKey,
            username: profile.isSelf ? null : profile.username,
            onOpen: profile.isSelf
                ? () => context.push(AppRoutes.levels)
                : null,
            padding: const EdgeInsetsDirectional.only(top: KSpacing.xs),
          ),
          ProfileFieldsLine(category: profile.category, gender: profile.gender),
          const SizedBox(height: KSpacing.xs),
          Wrap(
            key: ProfileScreen.statsKey,
            spacing: KSpacing.lg,
            children: [
              count(
                profile.followerCount,
                l10n.profileFollowerWord,
                onOpenFollowers,
                ProfileHeaderView.followersKey,
              ),
              count(
                profile.followingCount,
                l10n.profileFollowingWord,
                onOpenFollowing,
                ProfileHeaderView.followingKey,
              ),
            ],
          ),
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: KSpacing.xs),
            Text(bio, style: t.body.copyWith(color: p.textPrimary)),
          ],
          if (country != null || joined != null) ...[
            const SizedBox(height: KSpacing.sm),
            Wrap(
              key: ProfileInfoBlock.factsKey,
              spacing: KSpacing.lg,
              runSpacing: KSpacing.xs,
              children: [
                if (country != null)
                  fact(
                    Icons.place_outlined,
                    '${KCountries.flag(country.code)} '
                    '${KCountries.name(country, arabic: arabic)}',
                  ),
                if (joined != null)
                  fact(
                    Icons.calendar_month_outlined,
                    l10n.profileJoined(
                      '${DateFormat.MMMM(tag).format(joined)} ${joined.year}',
                    ),
                  ),
              ],
            ),
          ],
          // D175: the links — on a private profile too (§10.47).
          ProfileLinksRow(links: profile.links, reportable: !profile.isSelf),
          const SizedBox(height: KSpacing.md),
          actions,
          // Our features (D218): the medals shown, the family,
          // relationship and medals tiles (the levels sit under the name;
          // owner: no PK record pill on the profile — «ايقونة pk فوز
          // وخسارة ازلها»).
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.xs),
            child: ProfileBondsBlock(
              levels: const SizedBox.shrink(),
              profile: profile,
              // The own bag and premium tiles stay in the Me hub (D163).
              ownTiles: false,
            ),
          ),
        ],
      ),
    );
  }
}
