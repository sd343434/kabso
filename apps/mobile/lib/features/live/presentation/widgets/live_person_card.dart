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

/// The card's colours (D383): the plain card on the theme's raised surface
/// with light pills ([pill]); on a VIP background ([LivePersonSheet]) the
/// text follows the backdrop — white over an art (under its scrim) or a dark
/// colour, near-black over a light colour.
@immutable
class _Look {
  const new({
    required this.sheet,
    required this.ink,
    required this.soft,
    required this.pill,
    required this.ring,
    required this.tool,
    this.onBackdrop = false,
  });

  factory of(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _Look(
      sheet: p.surfaceRaised,
      ink: p.textPrimary,
      soft: p.textSecondary,
      pill: p.surfaceOverlay,
      ring: p.surfaceRaised,
      tool: dark ? p.textSecondary : const Color(0xFF5B5E66),
    );
  }

  /// D383: over a VIP background — [light] text (white) over an art's scrim
  /// or a dark colour; near-black text over a light colour.
  factory onBackdrop({required Color sheet, required bool light}) => light
      ? _Look(
          sheet: sheet,
          ink: const Color(0xFFFFFFFF),
          soft: const Color(0xE6FFFFFF),
          pill: const Color(0x29FFFFFF),
          ring: const Color(0xFFFFFFFF),
          tool: const Color(0xFFFFFFFF),
          onBackdrop: true,
        )
      : _Look(
          sheet: sheet,
          ink: KPalette.light.textPrimary,
          soft: const Color(0xD90B0B0D),
          pill: const Color(0x1F000000),
          ring: const Color(0xFFFFFFFF),
          tool: KPalette.light.textPrimary,
          onBackdrop: true,
        );

  /// The sheet's own colour (under a VIP background: its colour, or the
  /// art's base).
  final Color sheet;
  final Color ink;
  final Color soft;

  /// D383: the light rounded pills (numbers, soft buttons, tools).
  final Color pill;

  /// The clean ring around a picture without a frame.
  final Color ring;

  /// The top row's tools.
  final Color tool;

  /// D383: the card wears a VIP background.
  final bool onBackdrop;
}

/// D383 geometry (owner 2026-11-12, after a reference, look only: the name
/// very large, a green live line, the bio, light number pills, round
/// colourful buttons, soft pill buttons).
abstract final class LivePersonCardMetrics {
  /// The round picture (without its ring).
  static const double avatar = 84;

  /// The clean ring around a picture that wears no frame.
  static const double ring = 3;

  /// The sheet's top corners.
  static const double radius = 26;

  /// The name, very large and bold.
  static const double name = 28;

  /// The number in a number pill.
  static const double statNumber = 19;

  /// A number pill's and a soft pill button's height.
  static const double pill = 44;

  /// A round colourful button (≥ 48 with its label: the tap target).
  static const double action = 52;

  /// The white icon inside a round button.
  static const double actionIcon = 24;

  /// The width of a round button's column (its label wraps inside it).
  static const double actionWidth = 64;
}

/// D383: the round buttons' solid colours — design tokens that keep a white
/// icon at ≥ 3:1 in both themes (a solid fill does not change with the
/// theme).
abstract final class LivePersonActionColors {
  static const chat = Color(0xFF1A64BF); // color.light.info
  static const Color gift = KLiveColors.pkLeft;
  static const mention = Color(0xFF137A43); // color.light.success
  static const boost = Color(0xFF955C00); // color.light.warning
  static const invite = Color(0xFF1A64BF); // color.light.info
  static const neutral = Color(0xFF666671); // color.light.textTertiary
}

/// A person's card in a live or party room — the sheet that opens on a tap
/// on a person (D220, redesigned by D383, owner 2026-11-12: «الغاء فكرة
/// صندوق او إطار بطاقة الملف التعريفية»): no box or frame around the card
/// any more. The person's round picture sits centred over the sheet's top
/// edge, inside the avatar frame they wear (bag `AVATAR_FRAME`, the agent
/// frames, the couple's Special Frame, the VIP frame) or a clean ring; then
/// the name very large and bold, a green «في بث الآن» line while the person
/// broadcasts (public; nothing else about presence is known here), «ID:
/// username», the badge pills, the bio, one light pill per number the card
/// shows (followers, following, and cherries received / coins sent unless the
/// person hides them, §10.74), the quick actions as round colourful buttons
/// (follow, chat, gift, mention, traffic card, seat invite) and the rest as
/// soft pills (family, couple, gift wall, edit profile).
///
/// The moderation tools stay on the top row with their rules (D86 onward):
/// «إبلاغ», points, kick, chat mute, moderator, the mic, ⋯ report / block.
///
/// D383: a VIP's PROFILE_CARD perk is the card's background — the tier's
/// colour and / or its art filling the sheet behind the content, dimmed by a
/// scrim so the text stays readable; still under reduced motion or
/// «إخفاء مؤثرات الهدايا». Everyone else gets the plain card.
class LivePersonSheet extends ConsumerWidget {
  const new({required this.username, super.key, this.scope, this.onInvite});

  final String username;
  final LivePersonScope? scope;
  final VoidCallback? onInvite;

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

  /// D220: «متابعة» / «إلغاء المتابعة» / «تم الطلب».
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

  /// D383: the VIP background's art (behind the content), its colour and
  /// the scrim over the art.
  static const vipCardKey = Key('room.userCard.vipCard');
  static const vipColorKey = Key('room.userCard.vipColor');
  static const vipScrimKey = Key('room.userCard.vipScrim');

  /// D383: the art plays, or shows its still (reduced motion, «إخفاء
  /// مؤثرات الهدايا»).
  static const vipArtPlayingKey = Key('room.userCard.vipArt.playing');
  static const vipArtStillKey = Key('room.userCard.vipArt.still');

  /// D220: the badge pills row and the numbers.
  static const badgesKey = Key('room.userCard.badges');
  static const statsKey = Key('room.userCard.stats');
  static Key statKey(LivePersonStat stat) =>
      Key('room.userCard.stat.${stat.name}');

  /// D383: the green «في بث الآن» line and the bio.
  static const liveNowKey = Key('room.userCard.liveNow');
  static const bioKey = Key('room.userCard.bio');

  /// D383: the round buttons' row and the soft pills' row.
  static const actionsKey = Key('room.userCard.actions');
  static const pillsKey = Key('room.userCard.pills');

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
    final vipLook = ref.watch(vipLookProvider(profile?.vip));
    // D383: the PROFILE_CARD perk (or a worn store card) is the background.
    final backdrop = vipCardBackground(vipLook);
    final plain = _Look.of(context);
    final look = switch (backdrop) {
      null => plain,
      (color: final c, :final art) => _Look.onBackdrop(
        sheet: c ?? plain.sheet,
        // Over an art: white on its scrim; over a colour alone: what reads.
        light: art != null || (c ?? plain.sheet).computeLuminance() < 0.19,
      ),
    };
    final picture = _Picture.of(profile, username);
    final scope = this.scope;
    // D258: the VIP frame's plaque hangs below the picture: the name moves
    // down by as much (only for the plain ring, where the VIP frame shows).
    final vipFrame = picture.vipFrame
        ? vipLook?.perk(VipPerks.avatarFrame)
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

    // The sheet's top edge goes through the picture's centre.
    final edge = picture.centreY;
    final body = profile == null
        ? _State(error: loaded.error, look: look)
        : _Body(
            profile: profile,
            username: username,
            scope: scope,
            onInvite: onInvite,
            look: look,
            // Room under the edge for the picture's lower part.
            top: picture.height - picture.centreY + 8 + vipDrop,
          );
    const corners = BorderRadius.vertical(
      top: Radius.circular(LivePersonCardMetrics.radius),
    );
    return Stack(
      key: sheetKey,
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Attached to the bottom, a plain sheet: the live shows above it.
        Container(
          margin: EdgeInsets.only(top: edge),
          decoration: BoxDecoration(color: look.sheet, borderRadius: corners),
          child: Stack(
            children: [
              if (backdrop != null)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: corners,
                    child: _Backdrop(background: backdrop),
                  ),
                ),
              SafeArea(
                top: false,
                // Large text: the card scrolls instead of overflowing.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: body,
                ),
              ),
            ],
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
              ink: look.tool,
              fill: look.pill,
            ),
          ),
        Positioned(
          top: edge - picture.centreY,
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
  }
}

/// D383: the VIP background — its colour, the art over it (covering the
/// sheet) and, over an art, a scrim so white text stays ≥ 4.5:1 on any art.
/// The art is still under reduced motion and «إخفاء مؤثرات الهدايا»: its
/// still, else the SVGA's or the video's first frame.
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
      final animation = svga ?? mp4;
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
            animation: animation,
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
    final palette = context.palette;
    final profile = this.profile;
    final scope = this.scope;
    final look = this.look;
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

    // §10.74: the server leaves out a number the person hides — no pill.
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

    // D383: the quick actions as round colourful buttons.
    final actions = <Widget>[
      if (!profile.isSelf) ...[
        _FollowButton(profile: profile, username: username, look: look),
        _RoundAction(
          key: LivePersonSheet.messageKey,
          look: look,
          color: LivePersonActionColors.chat,
          icon: Icons.chat_bubble_rounded,
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
      ],
      // CP-020: the gift panel with this person chosen.
      if (!profile.isSelf)
        if (scope?.onGift case final onGift?)
          _RoundAction(
            key: LivePersonSheet.giftKey,
            look: look,
            color: LivePersonActionColors.gift,
            icon: Icons.card_giftcard_rounded,
            label: l10n.liveCardSendGift,
            onTap: () => _close(
              context,
              () => onGift((
                username: profile.username,
                name: profile.displayName,
              )),
            ),
          ),
      // D135: puts @username into the chat box.
      if (!profile.isSelf && scope?.onMention != null)
        _RoundAction(
          key: LivePersonSheet.mentionKey,
          look: look,
          color: LivePersonActionColors.mention,
          icon: Icons.alternate_email_rounded,
          label: l10n.liveUserMention,
          onTap: () =>
              _close(context, () => scope!.onMention!(profile.username)),
        ),
      // D154b: a traffic card for the host's live.
      if (!profile.isSelf && scope?.onBoost != null)
        _RoundAction(
          key: LivePersonSheet.boostKey,
          look: look,
          color: LivePersonActionColors.boost,
          icon: Icons.rocket_launch_rounded,
          label: l10n.liveBoostGiftAction,
          onTap: () => _close(context, scope!.onBoost!),
        ),
      if (!profile.isSelf && onInvite != null)
        _RoundAction(
          key: LivePersonSheet.inviteKey,
          look: look,
          color: LivePersonActionColors.invite,
          icon: Icons.event_seat_rounded,
          label: l10n.liveSeatInviteSend,
          onTap: () => _close(context, onInvite!),
        ),
    ];

    final family = profile.family == null
        ? null
        : KFormat.bidiIsolate(profile.family!.name);
    final partner = switch (profile.cp) {
      final cp? => (
        name: KFormat.bidiIsolate(
          cp.partner.displayName.isEmpty
              ? cp.partner.username
              : cp.partner.displayName,
        ),
        avatar: _networkImage(cp.partner.avatarUrl),
      ),
      null => null,
    };
    final cpValue = profile.cp == null && cpAction == BondTap.sendCp
        ? l10n.cpSendShort
        : null;
    final cpLine = partner?.name ?? cpValue ?? l10n.liveUserCp;
    // The live line's green: the theme's, or what reads on the backdrop
    // (the dark theme's bright green under white text).
    final green = !look.onBackdrop
        ? palette.success
        : look.ink.computeLuminance() > 0.5
        ? KPalette.dark.success
        : KPalette.light.success;

    // D383: the rest as soft pills (icon + label).
    final pills = <Widget>[
      if (profile.isSelf)
        _SoftPill(
          key: LivePersonSheet.editKey,
          look: look,
          leading: Icon(Icons.edit_rounded, size: 18, color: look.ink),
          label: l10n.liveCardEditProfile,
          semantics: l10n.liveCardEditProfile,
          onTap: () => _close(
            context,
            () => unawaited(context.push(AppRoutes.editProfile)),
          ),
        ),
      _SoftPill(
        key: LivePersonBoxes.boxKey(0),
        look: look,
        leading: Image.asset(
          'assets/card_boxes/family.webp',
          width: 24,
          height: 24,
          excludeFromSemantics: true,
        ),
        label: family ?? l10n.liveCardFamilyNone,
        muted: family == null,
        semantics: '${l10n.liveUserFamily}, ${family ?? l10n.liveUserNone}',
        onTap: bondAction(
          context,
          ref,
          profile,
          familyTap(profile),
          before: Navigator.of(context).pop,
        ),
      ),
      _SoftPill(
        key: LivePersonBoxes.boxKey(1),
        look: look,
        leading: partner == null
            ? Image.asset(
                'assets/card_boxes/cp.webp',
                width: 24,
                height: 24,
                excludeFromSemantics: true,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KAvatar(
                    // Initials without the direction marks.
                    name: partner.name.replaceAll(
                      RegExp('[\u2066-\u2069]'),
                      '',
                    ),
                    image: partner.avatar,
                    size: 22,
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.favorite_rounded,
                    size: 13,
                    color: Color(0xFFD62A66),
                  ),
                ],
              ),
        label: cpLine,
        semantics: '${l10n.liveUserCp}, $cpLine',
        onTap: bondAction(
          context,
          ref,
          profile,
          cpAction,
          before: Navigator.of(context).pop,
        ),
      ),
      // A person's gift wall has no API yet: it says it is coming.
      _SoftPill(
        key: LivePersonBoxes.boxKey(2),
        look: look,
        leading: Image.asset(
          'assets/card_boxes/gift_wall.webp',
          width: 24,
          height: 24,
          excludeFromSemantics: true,
        ),
        label: l10n.liveUserGiftWall,
        semantics: '${l10n.liveUserGiftWall}, ${l10n.liveUserSoon}',
        onTap: () =>
            KSnack.info(context, l10n.liveUserBoxSoon(l10n.liveUserGiftWall)),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: top),
        // The name, very large and bold (opens the profile, like the
        // picture). D268: the VIP badge right after it.
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
                        fontSize: LivePersonCardMetrics.name,
                        height: 1.2,
                        letterSpacing: -0.3,
                        fontWeight: FontWeight.w800,
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
              fontSize: 24,
              gap: 6,
            ),
            if (profile.vip.isMember) ...[
              const SizedBox(width: 6),
              VipNameBadge(vip: profile.vip, height: 24),
            ],
            // D282 / D299i: a staff account wears the Kabso Team badge.
            if (profile.kabsoTeam) ...[
              const SizedBox(width: 6),
              const KabsoTeamBadge(height: KabsoTeamBadge.cardHeight),
            ],
          ],
        ),
        // D383: a green line while the person broadcasts (public: their
        // profile says «في بث الآن» too). The activity status is never
        // shown here: the server gives it to family members only, and only
        // when the person allows it (§10.25, `showActivityStatus`).
        if (profile.liveRoomId != null)
          Padding(
            key: LivePersonSheet.liveNowKey,
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: green,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.profileLiveNowTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyStrong.copyWith(
                      color: green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
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
                      // languages.
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
              color: look.onBackdrop ? look.ink : const Color(0xFFC0262D),
              fontWeight: FontWeight.w700,
            ),
          ),
        if (profile.hostAgentCode case final code?)
          Text(
            l10n.hostAgentIdLine(KFormat.bidiIsolate(code)),
            key: const Key('room.userCard.hostAgentCode'),
            style: text.caption.copyWith(
              color: look.onBackdrop ? look.ink : const Color(0xFF1D5FD1),
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
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              bio,
              key: LivePersonSheet.bioKey,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: text.body.copyWith(color: look.soft, height: 1.35),
            ),
          ),
        const SizedBox(height: 14),
        // D383: one light pill per number shown (short Latin numbers).
        Wrap(
          key: LivePersonSheet.statsKey,
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (stat, value, label) in stats)
              _StatPill(
                key: LivePersonSheet.statKey(stat),
                look: look,
                value: KFormat.compactLatin(value),
                label: label,
              ),
          ],
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            key: LivePersonSheet.actionsKey,
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 10,
            children: actions,
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          key: LivePersonSheet.pillsKey,
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: pills,
        ),
      ],
    );
  }
}

/// A row centred when it fits; a long row scrolls sideways (many badges).
class _CentredRow extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;
  static const double spacing = 6;

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
              if (i > 0) const SizedBox(width: spacing),
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
  const new({required this.child, required this.label, this.onTap});

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

/// D383: a number pill — the number large and bold, its label beside it
/// (the reference's «45.4K All-time reacts received»), read as one.
class _StatPill extends StatelessWidget {
  const new({
    required this.look,
    required this.value,
    required this.label,
    super.key,
  });

  final _Look look;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: LivePersonCardMetrics.pill,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: look.pill,
          borderRadius: BorderRadius.circular(KRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              // Short Latin numbers read left to right in both languages.
              textDirection: TextDirection.ltr,
              style: text.title.copyWith(
                color: look.ink,
                fontSize: LivePersonCardMetrics.statNumber,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.caption.copyWith(
                  color: look.soft,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// D383: a round colourful button — a solid circle in a token colour with a
/// white icon, its label under it (a 64 × ≥ 72 tap target).
class _RoundAction extends StatelessWidget {
  const new({
    required this.look,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final _Look look;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const circleKey = Key('room.userCard.action.circle');

  @override
  Widget build(BuildContext context) => _Press(
    label: label,
    onTap: onTap,
    child: SizedBox(
      width: LivePersonCardMetrics.actionWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: circleKey,
            width: LivePersonCardMetrics.action,
            height: LivePersonCardMetrics.action,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: look.onBackdrop
                  ? null
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Icon(
              icon,
              size: LivePersonCardMetrics.actionIcon,
              color: const Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.textStyles.caption.copyWith(
              color: look.ink,
              fontSize: 11.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

/// D383: a soft pill button — a light rounded pill with an icon and a label
/// (the reference's «Edit Profile»): the family, the couple, the gift wall,
/// «تعديل الملف». Without [onTap] it is not a button (nothing to open).
class _SoftPill extends StatelessWidget {
  const new({
    required this.look,
    required this.leading,
    required this.label,
    required this.semantics,
    required this.onTap,
    this.muted = false,
    super.key,
  });

  final _Look look;
  final Widget leading;
  final String label;
  final String semantics;
  final VoidCallback? onTap;

  /// «لا عائلة بعد»: the label in the soft colour.
  final bool muted;

  @override
  Widget build(BuildContext context) => _Press(
    label: semantics,
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(
        minHeight: LivePersonCardMetrics.pill,
        maxWidth: 220,
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 14, 6),
      decoration: BoxDecoration(
        color: look.pill,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.bodyStrong.copyWith(
                color: muted ? look.soft : look.ink,
                fontSize: 14,
                fontWeight: muted ? FontWeight.w600 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// D383: Follow as a round button — «متابعة» in the brand colour (the
/// palette's `primary`, a white icon); once followed «إلغاء المتابعة» in a
/// neutral grey that asks first (as the profile page) and unfollows; D175's
/// «تم الطلب» for a private account (a tap asks, then cancels the request);
/// D218's «إلغاء الحظر» for someone you blocked.
class _FollowButton extends ConsumerWidget {
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
    final label = blocked
        ? l10n.safetyUnblock
        : following
        ? l10n.liveCardUnfollow
        : requested
        ? l10n.followRequested
        : l10n.liveCardFollow;
    return _RoundAction(
      key: blocked ? LivePersonSheet.unblockKey : LivePersonSheet.followKey,
      look: look,
      color: following || requested || blocked
          ? LivePersonActionColors.neutral
          : palette.primary,
      icon: blocked
          ? Icons.lock_open_rounded
          : following
          ? Icons.person_remove_alt_1_rounded
          : requested
          ? Icons.hourglass_top_rounded
          : Icons.person_add_alt_1_rounded,
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
    );
  }
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
