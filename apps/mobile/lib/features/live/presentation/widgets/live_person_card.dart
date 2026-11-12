import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/bag/presentation/avatar_frame_art.dart';
import 'package:kabso_live/features/cp/presentation/cp_special_frame.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/application/live_viewer_prefs.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_boxes.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_tools.dart';
import 'package:kabso_live/features/medals/presentation/medal_showcase_row.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_badge.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Follows or unfollows [username] through [publicProfileProvider]
/// (optimistic); a failure has already been rolled back and shows a snack.
Future<void> setHostFollowing(
  BuildContext context,
  WidgetRef ref,
  String username, {
  required bool follow,
}) async {
  final l10n = context.l10n;
  try {
    await ref
        .read(publicProfileProvider(username).notifier)
        .setFollowing(follow: follow);
  } on Object catch (e) {
    if (!context.mounted) return;
    KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
  }
}

ImageProvider? _networkImage(String? url) =>
    url == null || url.isEmpty ? null : NetworkImage(url);

/// The card's colours (D220, measured on the owner's reference, E — a small
/// phone photographed in perspective): white in light mode, the app's
/// surface in dark mode.
@immutable
class _Look {
  const new({
    required this.sheet,
    required this.ink,
    required this.soft,
    required this.line,
    required this.divider,
    required this.fill,
    required this.ring,
    this.flat = false,
  });

  factory of(BuildContext context) {
    final scoped = _LookScope.maybeOf(context);
    if (scoped != null) return scoped;
    final p = context.palette;
    return Theme.of(context).brightness == Brightness.dark
        ? _Look(
            sheet: p.surfaceRaised,
            ink: p.textPrimary,
            soft: p.textSecondary,
            line: p.border,
            // Owner: a little lighter than the border in dark mode, still
            // subtle (the strong border token at 60 %).
            divider: p.borderStrong.withValues(alpha: 0.6),
            fill: p.surfaceOverlay,
            ring: p.surfaceRaised,
          )
        : _Look(
            sheet: const Color(0xFFFFFFFF),
            ink: const Color(0xFF2E3130),
            soft: const Color(0xFF9A9BA5),
            // The theme's divider token (lines, outlines).
            line: p.border,
            divider: p.border,
            fill: p.surface,
            ring: const Color(0xFFFFFFFF),
          );
  }

  /// D383 (owner 2026-11-12): over the VIP background (PROFILE_CARD) —
  /// [light]: every text and icon white (over the art's scrim or a dark
  /// colour; D258's «لون الكتابة على هذا vip اجعله ابيض»); otherwise
  /// near-black over a light colour. No button shadows ([flat]).
  factory onBackdrop({required Color sheet, required bool light}) => light
      ? _Look(
          sheet: sheet,
          ink: const Color(0xFFFFFFFF),
          soft: const Color(0xFFFFFFFF),
          line: const Color(0x80FFFFFF),
          divider: const Color(0x66FFFFFF),
          fill: const Color(0x26FFFFFF),
          ring: const Color(0xFFFFFFFF),
          flat: true,
        )
      : _Look(
          sheet: sheet,
          ink: KPalette.light.textPrimary,
          soft: const Color(0xD90B0B0D),
          line: const Color(0x590B0B0D),
          divider: const Color(0x400B0B0D),
          fill: const Color(0x1A000000),
          ring: const Color(0xFFFFFFFF),
          flat: true,
        );

  final Color sheet;
  final Color ink;
  final Color soft;
  final Color line;

  /// The thin line between two numbers.
  final Color divider;

  /// A subtle neutral fill (the gift circle).
  final Color fill;

  /// The clean ring around a picture without a frame.
  final Color ring;

  /// D258 / D383: no shadows under the buttons (over the VIP background).
  final bool flat;
}

/// D220 geometry (E: the reference's right phone, ≈ 0.97 px per dp).
abstract final class LivePersonCardMetrics {
  /// The round picture (without its ring).
  static const double avatar = 84;

  /// The clean ring around a picture that wears no frame.
  static const double ring = 3;

  /// D383 (owner 2026-11-12: «الصورة الشخصية يجب أن تكون داخل البطاقة
  /// التعريفية أكثر، لا يتجاوز منها البطاقة سوى قليلاً»): the share of the
  /// picture's circle (with its ring) above the sheet's top edge — the rest
  /// sits inside the card. It was half (the edge through the centre).
  static const double poke = 0.18;

  /// Where the sheet's top edge crosses a picture whose circle's centre is
  /// [centreY] below the picture's top: [poke] of the circle above it.
  static double edgeIn(double centreY) {
    const circle = avatar + 2 * ring;
    return centreY - circle / 2 + poke * circle;
  }

  /// The sheet's top corners.
  static const double radius = 22;

  /// Number over label: the four numbers' row.
  static const double statNumber = 17;

  /// The gift art inside its circle (≈ 62 % of [action]).
  static const double giftArt = 30;

  /// The thin grey line between two numbers (≈ 60 % of the row).
  static const double statDivider = 22;

  /// The two pills (family + couple, gift wall).
  static const double pill = 40;

  /// Follow, the round gift and Chat.
  static const double action = 48;
}

/// A person's card in a live (D220, owner 2026-11-01, after a reference,
/// layout only): a compact white bottom sheet under which the live stays
/// visible. The person's round picture sits centred over the sheet's top
/// edge, inside the avatar frame they wear (bag `AVATAR_FRAME`, the agent
/// frames, the couple's Special Frame) or a clean ring; «إبلاغ» and the
/// host's tools on the top row; the name, «ID: username», one row of badge
/// pills (role, levels, recharge and agent badges, medals), the four
/// numbers — followers, following, cherries received, coins sent (each of
/// the last two only when the person shows it, §10.74; the rest re-centre)
/// — the family-and-couple gradient pill and the gift wall pill, then
/// «+ متابعة», the round gift and «دردشة». Your own card: «تعديل الملف».
///
/// Everything the earlier card did stays (D86 onward): the moderation row
/// (kick, chat mute, moderator, the mic, points, ⋯ report / block), the
/// mention, traffic card and seat invite, copy the ID, open the profile
/// from the picture or the name, and its honest states (loading, error).
class LivePersonSheet extends ConsumerWidget {
  const new({
    required this.username,
    super.key,
    this.scope,
    this.onInvite,
    this.header,
  });

  final String username;
  final LivePersonScope? scope;
  final VoidCallback? onInvite;

  /// The person's header decoration on the card's top edge; null: the
  /// profile card they wear (`PublicProfile.profileCard`, CP-019), or none.
  /// D383: hidden for now (owner «اخفيها الآن حتى نأخذ قرار حاسم»,
  /// [kabsoProfileHeadersHidden]); when shown, over the VIP background.
  final KabsoProfileHeader? header;

  static const sheetKey = Key('room.hostSheet');
  static const inviteKey = Key('room.userCard.invite');

  /// The picture: opens the person's full profile.
  static const profileKey = Key('room.userCard.profile');

  /// The name: opens the full profile too (D220).
  static const nameKey = Key('room.userCard.name');

  /// D293: the verification seal after the name.
  static const verificationKey = Key('livePerson.verification');

  /// D220: «دردشة» (a direct conversation).
  static const messageKey = Key('room.userCard.message');
  static const giftKey = Key('room.userCard.gift');
  static const mentionKey = Key('room.userCard.mention');
  static const boostKey = Key('room.userCard.boost');

  /// D220: «+ متابعة» / «متابَع» / «تم الطلب».
  static const followKey = Key('room.userCard.follow');

  /// D299h: the staff ID as the gold special-ID pill.
  static const staffIdKey = Key('liveCard.staffId');

  static const copyKey = Key('room.userCard.copy');
  static const medalsKey = Key('room.userCard.medals');
  static const cpFrameKey = Key('room.userCard.cpFrame');
  static const agentFrameKey = Key('room.userCard.agentFrame');
  static const agentBadgeKey = Key('room.userCard.agentBadge');
  static const hostAgentBadgeKey = Key('room.userCard.hostAgentBadge');
  static const rechargeBadgeKey = Key('room.userCard.rechargeBadge');

  /// D220: the bag frame the person wears, and the clean ring without one.
  static const bagFrameKey = Key('room.userCard.bagFrame');
  static const ringKey = Key('room.userCard.ring');

  /// D383: the VIP background (PROFILE_CARD) — its art behind the content,
  /// its colour and the scrim over the art.
  static const vipCardKey = Key('room.userCard.vipCard');
  static const vipColorKey = Key('room.userCard.vipColor');
  static const vipScrimKey = Key('room.userCard.vipScrim');

  /// D383: the art plays, or shows its still (reduced motion, «إخفاء
  /// مؤثرات الهدايا»).
  static const vipArtPlayingKey = Key('room.userCard.vipArt.playing');
  static const vipArtStillKey = Key('room.userCard.vipArt.still');

  /// D220: the badge pills row and the four numbers.
  static const badgesKey = Key('room.userCard.badges');
  static const statsKey = Key('room.userCard.stats');

  /// D220: the line before the [index]-th number shown (1-based gaps).
  static Key statDividerKey(int index) =>
      Key('room.userCard.statDivider.$index');
  static Key statKey(LivePersonStat stat) =>
      Key('room.userCard.stat.${stat.name}');

  /// D220: «تعديل الملف» on your own card.
  static const editKey = Key('room.userCard.edit');

  /// D218 × D220: the person's country flag before «ID: username».
  static const countryKey = Key('room.userCard.country');

  /// D218 × D220: «إلغاء الحظر» in Follow's place for someone you blocked.
  static const unblockKey = Key('room.userCard.unblock');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(publicProfileProvider(username));
    final profile = loaded.value;
    // D383 (owner 2026-11-12: no box or frame around the card; «تغير لون
    // خلفية او تكون خلفية فيها عناصر متحركة»): the PROFILE_CARD perk (or a
    // worn store card) is the card's background; the text follows it.
    final vipLook = ref.watch(vipLookProvider(profile?.vip));
    final backdrop = vipCardBackground(vipLook);
    final plain = _Look.of(context);
    final vipCard = switch (backdrop) {
      null => null,
      (color: final c, :final art) => _Look.onBackdrop(
        sheet: c ?? plain.sheet,
        // Over an art: white on its scrim. Over a colour alone: white on a
        // dark one, near-black on a light one (≥ 4.5:1 either way).
        light: art != null || (c ?? plain.sheet).computeLuminance() < 0.19,
      ),
    };
    final look = vipCard ?? plain;
    // D383: hidden pending the owner's decision (kabsoProfileHeadersHidden).
    final header = kabsoProfileHeadersHidden
        ? null
        : this.header ?? KabsoProfileHeader.byCode(profile?.profileCard?.code);
    final picture = _Picture.of(profile, username);
    final scope = this.scope;
    // D258: the VIP frame's plaque hangs below the picture: the name moves
    // down by as much (only for the plain ring, where the VIP frame shows).
    final vipFrame = picture.vipFrame
        ? ref.watch(vipLookProvider(profile?.vip))?.perk(VipPerks.avatarFrame)
        : null;
    const avatar = LivePersonCardMetrics.avatar;
    final vipDrop =
        vipFrame != null &&
            (vipFrame.still != null || vipFrame.animation != null)
        ? math.max(
            0,
            VipAvatarFrame.artRect(
                  avatar,
                  VipAvatarFrame.templateCentre,
                  VipAvatarFrame.templateWindow,
                ).bottom -
                avatar -
                LivePersonCardMetrics.ring,
          )
        : 0.0;

    return LayoutBuilder(
      builder: (context, box) {
        // D383: the sheet's top edge crosses the picture's circle near its
        // top (only [LivePersonCardMetrics.poke] of it above the card), or
        // lower when the header decoration rises higher than that.
        final inPicture = LivePersonCardMetrics.edgeIn(picture.centreY);
        final edge = header == null
            ? inPicture
            : math.max(inPicture, header.overhang(box.maxWidth));
        final body = profile == null
            ? _State(error: loaded.error, look: look)
            : _Body(
                profile: profile,
                username: username,
                scope: scope,
                onInvite: onInvite,
                look: look,
                // Room under the edge for the picture's lower part.
                top: picture.height - inPicture + 6 + vipDrop,
              );
        final sheet = Stack(
          key: sheetKey,
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Attached to the bottom, a plain sheet: the live shows above it.
            Container(
              margin: EdgeInsets.only(top: edge),
              decoration: BoxDecoration(
                color: look.sheet,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(LivePersonCardMetrics.radius),
                ),
              ),
              child: Stack(
                children: [
                  // D383: the VIP background fills the sheet behind its
                  // content (the sheet's own shape: no frame, no box).
                  if (backdrop != null)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(LivePersonCardMetrics.radius),
                        ),
                        child: _Backdrop(background: backdrop),
                      ),
                    ),
                  SafeArea(
                    top: false,
                    // Large text: the card scrolls instead of overflowing.
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: body,
                    ),
                  ),
                ],
              ),
            ),
            // The bag's header ornament on the top edge, over the VIP
            // background (D383: hidden for now, see [header]).
            if (header != null)
              Positioned(
                top: edge - header.overhang(box.maxWidth),
                left: 0,
                child: KabsoProfileHeaderArt(
                  header,
                  key: const Key('room.userCard.header'),
                  width: box.maxWidth,
                ),
              ),
            // The top row: «إبلاغ», points and the host's tools at the start;
            // the mutes and ⋯ at the end, either side of the picture.
            if (scope != null && profile != null)
              PositionedDirectional(
                top: edge + 8,
                start: 10,
                end: 10,
                child: LivePersonTools(
                  scope: scope,
                  person: (
                    id: profile.id,
                    username: username,
                    name: profile.displayName,
                  ),
                  self: profile.isSelf,
                  // D273: no actions against «فريق كابسو».
                  kabsoTeam: profile.kabsoTeam,
                  // D311: no founder actions on an owner.
                  kabsoOwner: profile.kabsoOwner,
                  middle: picture.width + 8,
                  // D383: what reads on the VIP background.
                  ink: vipCard?.ink,
                ),
              ),
            Positioned(
              top: edge - inPicture,
              child: Semantics(
                button: true,
                label: context.l10n.liveUserViewProfile,
                child: GestureDetector(
                  key: profileKey,
                  onTap: () => _openProfile(context, username),
                  child: picture.build(look),
                ),
              ),
            ),
          ],
        );
        return vipCard == null
            ? sheet
            : _LookScope(look: vipCard, child: sheet);
      },
    );
  }
}

/// The four numbers, in order.
enum LivePersonStat { followers, following, cherries, coins }

void _openProfile(BuildContext context, String username) {
  Navigator.of(context).pop();
  unawaited(context.push(AppRoutes.userProfile(username)));
}

/// Loading, or the failure's honest message.
class _State extends StatelessWidget {
  const new({required this.error, required this.look});

  final Object? error;
  final _Look look;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return SizedBox(
      height: 200,
      child: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Text(
                failureMessage(context.l10n, toAppFailure(error)),
                textAlign: TextAlign.center,
                style: context.textStyles.body.copyWith(color: look.soft),
              ),
      ),
    );
  }
}

/// The picture with what goes around it, and where its centre is.
/// D189 d + D186 (as the profile): the recharge-agent frame > the
/// host-agent frame > the bag frame > the couple's Special Frame > a clean
/// ring. Every frame in one box (`AvatarFrameBox`), the photo in its circle.
@immutable
class _Picture {
  const new({
    required this.width,
    required this.height,
    required this.centreY,
    required this.build,
    this.vipFrame = false,
  });

  factory of(PublicProfile? profile, String username) {
    const avatar = LivePersonCardMetrics.avatar;
    final name = profile?.displayName ?? username;
    final image = _networkImage(profile?.avatarUrl);
    final kind = agentFrameKindFor(
      rechargeCode: profile?.rechargeAgentCode,
      hostCode: profile?.hostAgentCode,
    );
    final art = AvatarFrameArt.of(profile?.avatarFrame);
    final box = AvatarFrameBox.aroundAvatar(avatar);
    if (kind != null) {
      final width = AgentFrameGeometry.widthIn(kind, box);
      final height = AgentFrameGeometry.height(kind, width);
      return _Picture(
        width: box.width,
        height: box.height,
        centreY:
            box.topOf(height) + AgentFrameGeometry.pictureCentreY(kind, width),
        build: (_) => box.place(
          kind == AgentFrameKind.recharge
              ? RechargeAgentFrame(
                  key: LivePersonSheet.agentFrameKey,
                  width: width,
                  name: name,
                  code: profile!.rechargeAgentCode!,
                  image: image,
                )
              : HostAgentFrame(
                  key: LivePersonSheet.agentFrameKey,
                  width: width,
                  name: name,
                  image: image,
                ),
        ),
      );
    }
    if (art != null) {
      final side = box.square;
      final photo = art.pictureForWidth(side);
      return _Picture(
        width: box.width,
        height: box.height,
        centreY: box.topOf(side) + side * art.cy,
        build: (_) => box.place(
          FramedAvatar(
            key: LivePersonSheet.bagFrameKey,
            art: art,
            picture: photo,
            layout: true,
            child: KAvatar(name: name, image: image, size: photo),
          ),
        ),
      );
    }
    if (cpWearsSpecialFrame(profile?.cp)) {
      final width = box.fit(CpSpecialFrameAvatar.paintAspect).width;
      final height = CpSpecialFrameAvatar.heightFor(width);
      return _Picture(
        width: box.width,
        height: box.height,
        centreY: box.topOf(height) + CpSpecialFrameAvatar.pictureCentreY(width),
        build: (_) => box.place(
          CpSpecialFrameAvatar(
            key: LivePersonSheet.cpFrameKey,
            width: width,
            name: name,
            image: image,
          ),
        ),
      );
    }
    const side = avatar + 2 * LivePersonCardMetrics.ring;
    return _Picture(
      width: side,
      height: side,
      centreY: side / 2,
      vipFrame: true,
      build: (look) => Container(
        key: LivePersonSheet.ringKey,
        padding: const EdgeInsets.all(LivePersonCardMetrics.ring),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: look.ring,
          boxShadow: const [
            BoxShadow(color: Color(0x26000000), blurRadius: 10),
          ],
        ),
        // D258: the VIP's animated frame (over the ring).
        child: VipAvatarFrame(
          vip: profile?.vip,
          size: avatar,
          child: ClipOval(
            child: KAvatar(name: name, image: image, size: avatar),
          ),
        ),
      ),
    );
  }

  final double width;
  final double height;

  /// The photo's centre below the widget's top.
  final double centreY;

  /// D258: the plain ring, where a VIP's frame is drawn.
  final bool vipFrame;
  final Widget Function(_Look look) build;
}

class _Body extends ConsumerWidget {
  const new({
    required this.profile,
    required this.username,
    required this.scope,
    required this.onInvite,
    required this.look,
    required this.top,
  });

  final PublicProfile profile;
  final String username;
  final LivePersonScope? scope;
  final VoidCallback? onInvite;
  final _Look look;
  final double top;

  void _close(BuildContext context, VoidCallback then) {
    Navigator.of(context).pop();
    then();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final profile = this.profile;
    final scope = this.scope;
    // D258: on the VIP card art, the colours measured for it.
    final look = _LookScope.maybeOf(context) ?? this.look;
    // D361 (§10.156): the founder shows no level (the server sends none too).
    final levels = profile.kabsoOwner
        ? const <PublicLevel>[]
        : ref.watch(profileLevelsProvider(username)).value ?? const [];
    final shown = [
      for (final l in levels)
        if (l.level != null) l,
    ];
    final charm = shown
        .where((l) => l.category == LevelCategory.attractiveness)
        .firstOrNull
        ?.level;
    final cpAction = cpTap(
      profile,
      signedIn: ref.watch(currentUserProvider) != null,
    );
    // D218: the country the person chose (PublicProfile.country).
    final country = KCountries.byCode(profile.country);

    final badges = <Widget>[
      // Everyone sees that the person is the host or a moderator here.
      if (scope?.target case final role? when role != LivePersonRole.viewer)
        _RoleBadge(host: role == LivePersonRole.host),
      if (charm != null) CharmLevelBadge(level: charm.levelNumber, height: 18),
      for (final l in shown)
        if (l.category != LevelCategory.attractiveness)
          Semantics(
            label: '${l.name} ${l.level!.levelNumber}',
            excludeSemantics: true,
            child: KLevelBadge(
              category: l.category,
              levelNumber: l.level!.levelNumber,
              iconKey: l.level!.iconKey,
            ),
          ),
      if (rechargeBadgeShows(profile.rechargeBadge))
        RechargeTierBadge(
          key: LivePersonSheet.rechargeBadgeKey,
          badge: profile.rechargeBadge,
          height: 20,
        ),
      if (profile.rechargeAgentCode case final code?)
        RechargeAgentBadge(
          key: LivePersonSheet.agentBadgeKey,
          code: code,
          height: 20,
        ),
      if (profile.hostAgentCode case final code?)
        HostAgentBadge(
          key: LivePersonSheet.hostAgentBadgeKey,
          code: code,
          height: 20,
        ),
      // CP-018: the medals the person chose to show (up to six).
      if (profile.medals.showcase.isNotEmpty)
        MedalShowcaseRow(
          key: LivePersonSheet.medalsKey,
          medals: profile.medals.showcase,
          size: 22,
          onTap: () => _close(
            context,
            () => unawaited(
              context.push(
                profile.isSelf
                    ? AppRoutes.medals
                    : AppRoutes.userMedals(username),
              ),
            ),
          ),
        ),
    ];

    // §10.74: the server leaves out a number the person hides; the others
    // share the row evenly (4 → 3 → 2).
    final stats = <(LivePersonStat, int, String)>[
      (LivePersonStat.followers, profile.followerCount, l10n.liveCardFollowers),
      (
        LivePersonStat.following,
        profile.followingCount,
        l10n.liveCardFollowing,
      ),
      if (profile.cherriesReceived case final n?)
        (LivePersonStat.cherries, n, l10n.liveCardCherries),
      if (profile.coinsSent case final n?)
        (LivePersonStat.coins, n, l10n.liveCardCoinsSent),
    ];

    final extras = <Widget>[
      // D135: puts @username into the chat box.
      if (!profile.isSelf && scope?.onMention != null)
        _SmallAction(
          key: LivePersonSheet.mentionKey,
          look: look,
          icon: Icons.alternate_email_rounded,
          label: l10n.liveUserMention,
          onTap: () =>
              _close(context, () => scope!.onMention!(profile.username)),
        ),
      // D154b: a traffic card for the host's live.
      if (!profile.isSelf && scope?.onBoost != null)
        _SmallAction(
          key: LivePersonSheet.boostKey,
          look: look,
          icon: Icons.confirmation_number_rounded,
          label: l10n.liveBoostGiftAction,
          onTap: () => _close(context, scope!.onBoost!),
        ),
      if (!profile.isSelf && onInvite != null)
        _SmallAction(
          key: LivePersonSheet.inviteKey,
          look: look,
          icon: Icons.event_seat_rounded,
          label: l10n.liveSeatInviteSend,
          onTap: () => _close(context, onInvite!),
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: top),
        // The name (opens the profile, like the picture). D268 (owner:
        // «ايقونة vip دائماً تأتي بعد الاسم»): the VIP badge right after it.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Semantics(
                header: true,
                button: true,
                child: GestureDetector(
                  key: LivePersonSheet.nameKey,
                  onTap: () => _openProfile(context, username),
                  // D258: the VIP name's gold (CHAT_NAME_COLOR).
                  child: VipNameShimmer(
                    vip: profile.vip,
                    child: Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: text.title.copyWith(
                        color: look.ink,
                        fontSize: 20,
                        // D258: the special colour at semi-bold (owner).
                        fontWeight: profile.vip.isMember
                            ? FontWeight.w600
                            : FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // D293: the verification seal right after the name.
            VerificationSeal(
              profile.verification,
              key: LivePersonSheet.verificationKey,
              fontSize: 20,
              gap: 6,
            ),
            if (profile.vip.isMember) ...[
              const SizedBox(width: 6),
              // As tall as the name's line.
              VipNameBadge(vip: profile.vip, height: 24),
            ],
            // D282: a staff account wears the Kabso Team badge after the
            // name; D299i: taller than the name's line, so its name reads.
            if (profile.kabsoTeam) ...[
              const SizedBox(width: 6),
              const KabsoTeamBadge(height: KabsoTeamBadge.cardHeight),
            ],
          ],
        ),
        const SizedBox(height: 2),
        // «ID: username», copied with one tap (D283c: «ID: Kabso01» for a
        // staff account).
        InkWell(
          key: LivePersonSheet.copyKey,
          borderRadius: BorderRadius.circular(KRadius.pill),
          onTap: () {
            unawaited(
              Clipboard.setData(
                ClipboardData(
                  text: KHandle.plain(
                    profile.username,
                    premiumTier: profile.premiumTier,
                    staffId: profile.staffId,
                  ),
                ),
              ),
            );
            KSnack.info(context, l10n.profileCopied);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              textDirection: TextDirection.ltr,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (country != null) ...[
                  Text(
                    KCountries.flag(country.code),
                    key: LivePersonSheet.countryKey,
                    semanticsLabel: KCountries.name(
                      country,
                      arabic:
                          Localizations.localeOf(context).languageCode == 'ar',
                    ),
                    style: text.caption.copyWith(fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                ],
                // D146: a premium username wears its special-ID badge.
                if (profile.premiumTier case final tier?
                    when profile.staffId == null)
                  KSpecialUsername(
                    username: profile.username,
                    tier: tier,
                    height: 18,
                    // D299l: the tier's full motion on the person card.
                    effects: KSpecialIdEffects.full,
                  )
                // D299h: a staff ID as the gold special-ID pill, «Kabso».
                else if (profile.staffId case final id?)
                  Flexible(
                    child: KStaffIdText(
                      id,
                      key: LivePersonSheet.staffIdKey,
                      semanticHint: l10n.profileStaffIdHint,
                      effects: KSpecialIdEffects.full,
                    ),
                  )
                else
                  Flexible(
                    child: Text(
                      l10n.liveCardId(
                        KFormat.bidiIsolate(
                          KHandle.id(
                            profile.username,
                            staffId: profile.staffId,
                          ),
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // «ID: username» reads left to right in both
                      // languages (the reference's ID line).
                      textDirection: TextDirection.ltr,
                      style: text.caption.copyWith(
                        color: look.soft,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.copy_rounded, size: 12, color: look.soft),
              ],
            ),
          ),
        ),
        // D185 / D189: the agents' codes under the ID.
        if (profile.rechargeAgentCode case final code?)
          Text(
            l10n.rechargeAgentIdLine(KFormat.bidiIsolate(code)),
            key: const Key('room.userCard.agentCode'),
            style: text.caption.copyWith(
              color: const Color(0xFFC0262D),
              fontWeight: FontWeight.w700,
            ),
          ),
        if (profile.hostAgentCode case final code?)
          Text(
            l10n.hostAgentIdLine(KFormat.bidiIsolate(code)),
            key: const Key('room.userCard.hostAgentCode'),
            style: text.caption.copyWith(
              color: const Color(0xFF1D5FD1),
              fontWeight: FontWeight.w700,
            ),
          ),
        if (badges.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _CentredRow(
              key: LivePersonSheet.badgesKey,
              children: badges,
            ),
          ),
        if (profile.bio case final bio? when bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: text.caption.copyWith(color: look.soft),
            ),
          ),
        const SizedBox(height: 12),
        // D220 (owner): short Latin numbers, smaller, equal columns, a
        // thin grey line between two numbers (only between those shown).
        IntrinsicHeight(
          child: Row(
            key: LivePersonSheet.statsKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, (stat, value, label)) in stats.indexed) ...[
                if (i > 0)
                  Center(
                    child: Container(
                      key: LivePersonSheet.statDividerKey(i),
                      width: 1,
                      height: LivePersonCardMetrics.statDivider,
                      color: look.divider,
                    ),
                  ),
                Expanded(
                  child: Semantics(
                    key: LivePersonSheet.statKey(stat),
                    label: '$label ${KFormat.compactLatin(value)}',
                    excludeSemantics: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            KFormat.compactLatin(value),
                            maxLines: 1,
                            style: text.title.copyWith(
                              color: look.ink,
                              fontSize: LivePersonCardMetrics.statNumber,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 1),
                        // A long label shrinks a little to stay whole.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: text.caption.copyWith(
                              color: look.soft,
                              fontSize: 11,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        // The family-and-couple gradient pill, then the gift wall.
        SizedBox(
          height: LivePersonCardMetrics.pill,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _BondsPill(
                  family: profile.family == null
                      ? null
                      : KFormat.bidiIsolate(profile.family!.name),
                  cpPartner: switch (profile.cp) {
                    final cp? => (
                      name: KFormat.bidiIsolate(
                        cp.partner.displayName.isEmpty
                            ? cp.partner.username
                            : cp.partner.displayName,
                      ),
                      avatar: _networkImage(cp.partner.avatarUrl),
                    ),
                    null => null,
                  },
                  cpValue: profile.cp == null && cpAction == BondTap.sendCp
                      ? l10n.cpSendShort
                      : null,
                  onFamily: bondAction(
                    context,
                    ref,
                    profile,
                    familyTap(profile),
                    before: Navigator.of(context).pop,
                  ),
                  onCp: bondAction(
                    context,
                    ref,
                    profile,
                    cpAction,
                    before: Navigator.of(context).pop,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(flex: 2, child: _GiftWallPill()),
            ],
          ),
        ),
        if (extras.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _CentredRow(spacing: 8, children: extras),
          ),
        const SizedBox(height: 14),
        if (profile.isSelf)
          _OutlineButton(
            key: LivePersonSheet.editKey,
            look: look,
            icon: Icons.edit_rounded,
            label: l10n.liveCardEditProfile,
            onTap: () => _close(
              context,
              () => unawaited(context.push(AppRoutes.editProfile)),
            ),
          )
        else
          SizedBox(
            height: LivePersonCardMetrics.action,
            child: Row(
              children: [
                Expanded(
                  flex: 11,
                  child: _FollowPill(
                    profile: profile,
                    username: username,
                    look: look,
                  ),
                ),
                // CP-020: the gift panel with this person chosen.
                if (scope?.onGift case final onGift?) ...[
                  const SizedBox(width: 8),
                  _GiftButton(
                    look: look,
                    onTap: () => _close(
                      context,
                      () => onGift((
                        username: profile.username,
                        name: profile.displayName,
                      )),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  flex: 9,
                  child: _OutlineButton(
                    key: LivePersonSheet.messageKey,
                    look: look,
                    icon: Icons.sms_outlined,
                    label: l10n.liveCardChat,
                    onTap: () => _close(
                      context,
                      () => unawaited(
                        context.push(
                          AppRoutes.chat(profile.username),
                          extra: (
                            displayName: profile.displayName,
                            premiumTier: profile.premiumTier,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A row centred when it fits; a long row scrolls sideways (many badges).
class _CentredRow extends StatelessWidget {
  const new({required this.children, super.key, this.spacing = 6});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: box.maxWidth),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              children[i],
            ],
          ],
        ),
      ),
    ),
  );
}

/// Sinks a little while pressed (the design's `_Press`).
class _Press extends StatefulWidget {
  const new({required this.child, required this.label, super.key, this.onTap});

  final Widget child;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    if (onTap == null) {
      return Semantics(
        label: widget.label,
        excludeSemantics: true,
        child: widget.child,
      );
    }
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

/// The gradient pill (the reference's orange showcase pill): the family at
/// the start and the couple at the end, each opening what exists (CP-018,
/// `bondAction`). Keys: `LivePersonBoxes.boxKey(0)` (family), `(1)` (couple).
class _BondsPill extends StatelessWidget {
  const new({
    required this.family,
    required this.cpPartner,
    required this.cpValue,
    required this.onFamily,
    required this.onCp,
  });

  final String? family;
  final ({String name, ImageProvider? avatar})? cpPartner;
  final String? cpValue;
  final VoidCallback? onFamily;
  final VoidCallback? onCp;

  static const _colors = [Color(0xFFFFC596), Color(0xFFFF9466)];
  static const _ink = Color(0xFF4A1D05);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final style = text.caption.copyWith(
      color: _ink,
      fontSize: 12.5,
      height: 1.2,
      fontWeight: FontWeight.w800,
    );
    final partner = cpPartner;
    final cpLine = partner?.name ?? cpValue ?? l10n.liveUserCp;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(colors: _colors),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33FF8A55),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _Press(
              key: LivePersonBoxes.boxKey(0),
              label: '${l10n.liveUserFamily}, ${family ?? l10n.liveUserNone}',
              onTap: onFamily,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 4, 0),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/card_boxes/family.webp',
                      width: 26,
                      height: 26,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        family ?? l10n.liveCardFamilyNone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: family == null
                            ? style.copyWith(
                                color: _ink.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w600,
                              )
                            : style,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 20, color: const Color(0x66FFFFFF)),
          Expanded(
            child: _Press(
              key: LivePersonBoxes.boxKey(1),
              label: '${l10n.liveUserCp}, $cpLine',
              onTap: onCp,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 6, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (partner != null) ...[
                      KAvatar(
                        // Initials without the direction marks.
                        name: partner.name.replaceAll(
                          RegExp('[\u2066-\u2069]'),
                          '',
                        ),
                        image: partner.avatar,
                        size: 20,
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.favorite_rounded,
                        size: 13,
                        color: Color(0xFFD62A66),
                      ),
                    ] else
                      Image.asset(
                        'assets/card_boxes/cp.webp',
                        width: 24,
                        height: 24,
                        excludeFromSemantics: true,
                      ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        partner?.name ?? cpValue ?? l10n.liveUserCp,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «حائط الهدايا» in purple (the reference's Gift Wall pill). A person's
/// gift wall has no API yet: it says it is coming (`LivePersonBoxes.
/// boxKey(2)`).
class _GiftWallPill extends StatelessWidget {
  const new();

  static const _colors = [Color(0xFFC77BFB), Color(0xFF9445E6)];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Press(
      key: LivePersonBoxes.boxKey(2),
      label: '${l10n.liveUserGiftWall}, ${l10n.liveUserSoon}',
      onTap: () =>
          KSnack.info(context, l10n.liveUserBoxSoon(l10n.liveUserGiftWall)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(colors: _colors),
          boxShadow: const [
            BoxShadow(
              color: Color(0x339445E6),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/card_boxes/gift_wall.webp',
                width: 26,
                height: 26,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l10n.liveUserGiftWall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.caption.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owner (2026-11-01, «اجعله احمر وعندما يكون متابع الشخص يكون زر الغاء
/// المتابعة»): «+ متابعة» filled in the brand red (white text, the palette's
/// `primary` / `onPrimary`); once followed, a neutral outline «إلغاء
/// المتابعة» that asks first (as the profile page) and unfollows; D175's
/// «تم الطلب» for a private account (a tap asks, then cancels the request).
class _FollowPill extends ConsumerWidget {
  const new({
    required this.profile,
    required this.username,
    required this.look,
  });

  final PublicProfile profile;
  final String username;
  final _Look look;

  /// D218: unblocks the person (as on their profile) and reloads the card.
  Future<void> _unblock(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      await ref
          .read(safetyRepositoryProvider)
          .setBlocked(profile.username, blocked: false);
      ref.invalidate(publicProfileProvider(username));
      if (context.mounted) {
        KSnack.success(context, l10n.safetyUnblocked(profile.displayName));
      }
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    // D218: someone you blocked gets «إلغاء الحظر» instead of Follow.
    final blocked = profile.blockedByMe;
    final following = !blocked && profile.isFollowing;
    final requested = !blocked && profile.followRequested;
    final plain = following || requested;
    final label = blocked
        ? l10n.safetyUnblock
        : following
        ? l10n.liveCardUnfollow
        : requested
        ? l10n.followRequested
        : l10n.liveCardFollow;
    final ink = plain ? look.ink : palette.onPrimary;
    return _Press(
      key: blocked ? LivePersonSheet.unblockKey : LivePersonSheet.followKey,
      label: label,
      onTap: () => unawaited(() async {
        if (blocked) {
          await _unblock(context, ref);
          return;
        }
        if (requested) {
          if (await confirmCancelFollowRequest(
                context,
                profile.displayName,
                live: true,
              ) &&
              context.mounted) {
            await setHostFollowing(context, ref, username, follow: false);
          }
          return;
        }
        if (following) {
          if (await confirmUnfollow(context, profile.displayName, live: true) &&
              context.mounted) {
            await setHostFollowing(context, ref, username, follow: false);
          }
          return;
        }
        await setHostFollowing(context, ref, username, follow: true);
      }()),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KRadius.pill),
          color: plain ? null : palette.primary,
          border: plain ? Border.all(color: look.line, width: 1.2) : null,
          boxShadow: plain || look.flat
              ? null
              : [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  blocked
                      ? Icons.lock_open_rounded
                      : following
                      ? Icons.person_remove_alt_1_rounded
                      : requested
                      ? Icons.hourglass_top_rounded
                      : Icons.add_rounded,
                  size: 20,
                  color: ink,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.bodyStrong.copyWith(
                      color: ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The gift button between Follow and Chat (owner: «اجعل ايقونة الهدايا
/// بداخل دائرة»): the app's main gift icon (the live bar's colourful box)
/// centred at ≈ 62 % inside a circle as high as the pills beside it, with a
/// subtle neutral fill and the outline of the Chat pill.
class _GiftButton extends StatelessWidget {
  const new({required this.onTap, required this.look});

  final VoidCallback onTap;
  final _Look look;

  static const circleKey = Key('room.userCard.gift.circle');

  @override
  Widget build(BuildContext context) => _Press(
    key: LivePersonSheet.giftKey,
    label: context.l10n.liveCardSendGift,
    onTap: onTap,
    child: Container(
      key: circleKey,
      width: LivePersonCardMetrics.action,
      height: LivePersonCardMetrics.action,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: look.fill,
        border: Border.all(color: look.line, width: 1.2),
      ),
      child: const KabsoArtIcon(
        KabsoArt.mainGift,
        size: LivePersonCardMetrics.giftArt,
      ),
    ),
  );
}

/// «دردشة» and «تعديل الملف»: an outline pill.
class _OutlineButton extends StatelessWidget {
  const new({
    required this.look,
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final _Look look;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Press(
    label: label,
    onTap: onTap,
    child: Container(
      height: LivePersonCardMetrics.action,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        border: Border.all(color: look.line, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: look.ink),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.bodyStrong.copyWith(
                color: look.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The smaller actions the card keeps (mention, traffic card, seat
/// invite): a light outline chip each.
class _SmallAction extends StatelessWidget {
  const new({
    required this.look,
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final _Look look;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Press(
    label: label,
    onTap: onTap,
    // A 48 pt target with the 36 pt chip drawn inside it.
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Center(
        widthFactor: 1,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KRadius.pill),
            border: Border.all(color: look.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: look.ink),
              const SizedBox(width: 4),
              Text(
                label,
                maxLines: 1,
                style: context.textStyles.caption.copyWith(
                  color: look.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The host's or a moderator's badge among the card's pills.
class _RoleBadge extends StatelessWidget {
  const new({required this.host});

  final bool host;

  static const badgeKey = Key('room.userCard.roleBadge');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = host ? l10n.goLiveHostTag : l10n.liveSeatModeratorTag;
    final colors = host
        ? const [Color(0xFFFFC94D), Color(0xFFF29A1F)]
        : const [Color(0xFF6FA8FF), Color(0xFF3B6FE0)];
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        key: badgeKey,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KRadius.pill),
          gradient: LinearGradient(colors: colors),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              host ? Icons.mic_rounded : Icons.shield_rounded,
              size: 12,
              color: const Color(0xFFFFFFFF),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: context.textStyles.caption.copyWith(
                color: const Color(0xFFFFFFFF),
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// D383 (owner 2026-11-12: «لا ستكون موجودة بحيث ستكون مثلاً تغير لون خلفية
/// او تكون خلفية فيها عناصر متحركة»): the VIP PROFILE_CARD perk as the card's
/// background — no longer a box or frame around it. Its colour across the
/// sheet; its art over it, covering the whole sheet behind the content (an
/// SVGA first, else the perk's MP4, else its still; a worn store card the
/// same way), under a scrim so white text stays ≥ 4.5:1 on any art. Still
/// under reduced motion and «إخفاء مؤثرات الهدايا»: the still, else the
/// SVGA's or the video's first frame.
class _Backdrop extends ConsumerWidget {
  const new({required this.background});

  final VipCardBackground background;

  /// Black at 55 %: white text over it reads ≥ 4.5:1 even on a white art.
  static const scrim = Color(0x8C000000);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final art = background.art;
    final color = background.color;
    final hidden = ref.watch(
      liveViewerPrefsProvider.select((p) => p.giftEffectsHidden),
    );
    final playing = !hidden && !MediaQuery.disableAnimationsOf(context);
    Widget? artWidget;
    if (art != null) {
      // An SVGA first, else the perk's MP4 (or a store card's MP4).
      final svga = art.video == null ? art.animation : null;
      final mp4 = art.video != null ? art.animation : art.videoUrl;
      final video = svga != null
          ? null
          : (art.video ?? (mp4 == null ? null : ArtVideo.plain));
      artWidget = KeyedSubtree(
        key: playing
            ? LivePersonSheet.vipArtPlayingKey
            : LivePersonSheet.vipArtStillKey,
        // Still: the players show their first frame without motion; with a
        // still, only the still is drawn.
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: !playing),
          child: VipAnimatedArt(
            animation: svga ?? mp4,
            still: art.still,
            video: video,
            fit: BoxFit.cover,
            animate: playing || art.still == null,
          ),
        ),
      );
    }
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (color != null)
            ColoredBox(key: LivePersonSheet.vipColorKey, color: color),
          if (artWidget != null) ...[
            KeyedSubtree(key: LivePersonSheet.vipCardKey, child: artWidget),
            const ColoredBox(key: LivePersonSheet.vipScrimKey, color: scrim),
          ],
        ],
      ),
    );
  }
}

/// D258 / D383: the colours the person card's text uses on the VIP
/// background.
class _LookScope extends InheritedWidget {
  const new({required this.look, required super.child});

  final _Look look;

  static _Look? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LookScope>()?.look;

  @override
  bool updateShouldNotify(_LookScope old) => old.look != look;
}
