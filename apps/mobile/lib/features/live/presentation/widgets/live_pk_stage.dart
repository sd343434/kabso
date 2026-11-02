import 'dart:async';
import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/presentation/widgets/battle_emoji.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_boost_fx.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_battle_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// PK stage geometry and colours (D71 / D73 owner layout, production).
abstract final class KLivePk {
  /// Room above the bar for Kabi and the flames (D73: about 40 lp).
  static const double aboveBar = 36;
  static const double barHeight = 22;

  /// D231: «PK 3:47» where the halves meet, under the bar (readable: 15 sp).
  static const double timerHeight = 26;
  static const double timerWidth = 112;
  static const double timerText = 15;

  /// D231 (owner: «لا تظهر صورة المضيفين كل شخص على جزئه من الأسفل مع زر +»):
  /// each side's host at the bottom of their half — picture, name and the
  /// opponent's «+».
  static const double hostAvatar = 38;
  static const double hostRing = 2;
  static const double hostChip = hostAvatar + hostRing * 2;
  static const double hostName = 13;
  static const double follow = 24;
  static const double seam = 2;
  static const double paneInset = 6;
  static const double pillHeight = 22;
  static const double maxPaneHeight = 374;

  /// Pane height per pane width (the owner's 1 v 1 panes are tall).
  static const double paneAspect = 0.58;
  static const double guest = 34;
  static const double supporterAvatar = 28;
  static const double outcome = 132;

  /// The host's team (Kabso red) on the reading start, the opponents on
  /// the end (D71); top → bottom, the last is solid. D231: the opponents
  /// are the owner's bar blue (was orange), so the bar, the host rings and
  /// the supporters show one colour per side.
  static const List<Color> startTeam = [
    Color(0xFFFF4A4A),
    Color(0xFFE50914),
    Color(0xFFA3000B),
  ];
  static const List<Color> endTeam = [
    Color(0xFFA8DCFF),
    Color(0xFF3D8BFF),
    Color(0xFF1340B8),
  ];
  static final List<Color> startFill = startTeam.reversed.toList();
  static final List<Color> endFill = endTeam.reversed.toList();
  static const Color glass = Color(0x59000000);

  /// The booster chips' colours (×2 gold → ×10 violet).
  static List<Color> boosterColors(PkBoosterKind kind) => switch (kind) {
    PkBoosterKind.double => const [Color(0xFFFFC94D), Color(0xFFFF7A00)],
    PkBoosterKind.doubleTurbo => const [Color(0xFFFF9A3C), Color(0xFFE50914)],
    PkBoosterKind.triple => const [Color(0xFFFF4A4A), Color(0xFFA3000B)],
    PkBoosterKind.tripleTurbo => const [Color(0xFFFF5AC8), Color(0xFF7814C8)],
  };
}

/// The booster's name in the app's language.
String pkBoosterName(AppLocalizations l10n, PkBoosterKind kind) =>
    switch (kind) {
      PkBoosterKind.double => l10n.pkBoosterDouble,
      PkBoosterKind.doubleTurbo => l10n.pkBoosterDoubleTurbo,
      PkBoosterKind.triple => l10n.pkBoosterTriple,
      PkBoosterKind.tripleTurbo => l10n.pkBoosterTripleTurbo,
    };

/// The PK 1 v 1 stage of a room (v1.43-live, D195): the owner's
/// [KabsoPkBar] with Kabi on the seam, the booster countdown chips under
/// each side of it, the round timer, both hosts' videos side by side —
/// this room's host on the reading start (D36; the bar's teams mapped the
/// same way in Arabic) — each with their guests as small glowing circles at
/// the bottom (D195), the booster announcement, the result (the owner's
/// win / lose / draw SVGA per side and the result chip), and the top three
/// supporters per side. Everything comes from the server's [match]; [now]
/// is the server clock.
class LivePkStage extends StatefulWidget {
  const new({
    required this.match,
    required this.roomId,
    required this.ownVideo,
    required this.opponentVideo,
    required this.now,
    super.key,
    this.guestVideo,
    this.speaking = const {},
    this.announcement,
    this.onPerson,
    this.onStart,
    this.onHost,
    this.onFollowOpponent,
  });

  final PkMatch match;

  /// D231: a tap on a half or its host's picture: that host's person card
  /// (`opponent` true for the other room's host).
  final void Function(UserSummary host, {required bool opponent})? onHost;

  /// D231: the «+» on the other host's chip — given by the screen only when
  /// this person may follow them and does not yet (never for yourself);
  /// null hides it.
  final VoidCallback? onFollowOpponent;

  /// v1.44-live (D199): the host starts a CONNECTED PK (null: a viewer, who
  /// only reads that it will start).
  final VoidCallback? onStart;

  /// This room (its side is drawn on the reading start).
  final String roomId;

  /// This room's host video (null: their picture).
  final Widget? ownVideo;

  /// The other host's video from the PK connection (null: their picture).
  final Widget? opponentVideo;

  /// A guest's video (either room), or null: their picture.
  final Widget? Function(String userId)? guestVideo;

  /// Who speaks now (user ids, both rooms): their circle glows.
  final Set<String> speaking;

  final PkAnnouncement? announcement;

  /// A tap on a guest or a supporter: their person card.
  final ValueChanged<UserSummary>? onPerson;

  /// The server's clock (countdowns).
  final DateTime Function() now;

  /// The countdowns rebuild every second; widget tests and goldens turn
  /// it off (`test/flutter_test_config.dart`) so frames settle.
  static bool ticks = true;

  /// D231: goldens pin the stage's clock to their fixture's server time,
  /// so the round timer never flips a second under load (the known
  /// `room.pk.*` flake); null in the app.
  @visibleForTesting
  static DateTime Function()? debugNow;

  static const barKey = Key('pk.bar');
  static const timerKey = Key('pk.timer');
  static const ownPaneKey = Key('pk.pane.own');
  static const opponentPaneKey = Key('pk.pane.opponent');
  static const announcementKey = Key('pk.announcement');
  static const resultKey = Key('pk.result');
  static const startKey = Key('pk.stage.start');
  static const connectedKey = Key('pk.stage.connected');
  static const bannersKey = Key('pk.banners');
  static const ownHostKey = Key('pk.host.own');
  static const opponentHostKey = Key('pk.host.opponent');
  static const followOpponentKey = Key('pk.host.opponent.follow');
  static Key boostChipKey(String roomId) => Key('pk.boost.$roomId');
  static Key guestKey(String userId) => Key('pk.guest.$userId');

  @override
  State<LivePkStage> createState() => _LivePkStageState();
}

class _LivePkStageState extends State<LivePkStage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (LivePkStage.ticks) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final match = widget.match;
    final (own, other) = match.of(widget.roomId);
    final now = (LivePkStage.debugNow ?? widget.now)();
    final battle = match.status == PkMatchStatus.battle;
    final connected = match.connected;
    final left = battle ? match.battleEndsAt.difference(now) : Duration.zero;
    final remaining = left.isNegative ? Duration.zero : left;
    final startIsLeft = Directionality.of(context) == TextDirection.ltr;
    final ownWins = match.winnerRoomId == own.roomId;
    final otherWins = match.winnerRoomId == other.roomId;
    final ownBoost = battle ? own.boostAt(now) : null;
    final otherBoost = battle ? other.boostAt(now) : null;
    final announcement = battle ? widget.announcement : null;
    // D199 (owner's bar and banners): sides by screen position.
    final (leftSide, rightSide) = startIsLeft ? (own, other) : (other, own);
    final (leftBoost, rightBoost) = startIsLeft
        ? (ownBoost, otherBoost)
        : (otherBoost, ownBoost);
    // The server's clock → this device's (the banners count down locally).
    final skew = now.difference(DateTime.now());
    PkPowerActivation? activation(
      PkSide side,
      PkActiveBoost? boost,
      PkPowerSide screen,
    ) => boost == null
        ? null
        : PkPowerActivation(
            id: boost.id,
            teamId: side.roomId,
            side: screen,
            tier: pkPowerTier(boost.kind),
            multiplier: boost.multiplier,
            endsAt: boost.endsAt.subtract(skew),
            label: pkBoosterName(l10n, boost.kind),
          );
    ImageProvider? avatar(PkSide side) => switch (side.host.avatarUrl) {
      final String url => NetworkImage(url),
      null => null,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final paneHeight = math.min(
          KLivePk.maxPaneHeight,
          (width - KLivePk.seam) / 2 / KLivePk.paneAspect,
        );
        final onHost = widget.onHost;
        // D231 (owner: «خط الـpk مرتفع عن الشاشتين»): the bar's track ends
        // exactly where the two videos start — no gap; its frames and the
        // PK emblem reach a little over the videos' top edge.
        const barHeight = PkBarMetrics.height;
        final panes = Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Pane(
                    key: LivePkStage.ownPaneKey,
                    side: own,
                    video: widget.ownVideo,
                    label: l10n.pkOwnPane(own.host.displayName),
                    stage: widget,
                    hostKey: LivePkStage.ownHostKey,
                    ring: KLivePk.startTeam,
                    end: false,
                    onTap: onHost == null
                        ? null
                        : () => onHost(own.host, opponent: false),
                  ),
                ),
                const SizedBox(width: KLivePk.seam),
                Expanded(
                  child: _Pane(
                    key: LivePkStage.opponentPaneKey,
                    side: other,
                    video: widget.opponentVideo,
                    label: l10n.pkOpponentPane(other.host.displayName),
                    muted: own.mutesOpponent,
                    stage: widget,
                    hostKey: LivePkStage.opponentHostKey,
                    ring: KLivePk.endTeam,
                    end: true,
                    onFollow: widget.onFollowOpponent,
                    onTap: onHost == null
                        ? null
                        : () => onHost(other.host, opponent: true),
                  ),
                ),
              ],
            ),
            // D199: each running booster for screen readers (the
            // banner itself is a picture).
            for (final (side, boost) in [(own, ownBoost), (other, otherBoost)])
              if (boost != null)
                Semantics(
                  key: LivePkStage.boostChipKey(side.roomId),
                  liveRegion: true,
                  label: l10n.pkBoostChipSemantics(
                    pkBoosterName(l10n, boost.kind),
                    '${boost.multiplier}',
                    math
                        .max(0, boost.endsAt.difference(now).inSeconds)
                        .toString(),
                  ),
                  child: const SizedBox.shrink(),
                ),
            // v1.44-live (D199): connected, waiting for a start.
            if (connected)
              Align(
                alignment: const Alignment(0, -0.2),
                child: _Connected(
                  key: LivePkStage.connectedKey,
                  onStart: widget.onStart,
                ),
              ),
            if (!battle && !connected) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IgnorePointer(
                  child: SizedBox(
                    width: (width - KLivePk.seam) / 2,
                    child: Center(
                      child: KabsoBattleEmoji(
                        ownWins
                            ? KabsoBattle.win
                            : otherWins
                            ? KabsoBattle.lose
                            : KabsoBattle.draw,
                        size: KLivePk.outcome,
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IgnorePointer(
                  child: SizedBox(
                    width: (width - KLivePk.seam) / 2,
                    child: Center(
                      child: KabsoBattleEmoji(
                        otherWins
                            ? KabsoBattle.win
                            : ownWins
                            ? KabsoBattle.lose
                            : KabsoBattle.draw,
                        size: KLivePk.outcome,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            // D199 (owner «استخدمها بنفس المكان … وبنفس الحجم واجعلها
            // تظهر للفرقين»): the owner's banners where the
            // announcement pill was — centred over both boxes, 52 % of
            // the width — for every boosted side, in both rooms.
            Positioned.fill(
              child: IgnorePointer(
                child: PkPowerLayer(
                  key: LivePkStage.bannersKey,
                  left: activation(leftSide, leftBoost, PkPowerSide.left),
                  right: activation(rightSide, rightBoost, PkPowerSide.right),
                  centred: true,
                  widthFactor: PkStageBanner.widthFactor,
                  top: PkStageBanner.top(width, paneHeight),
                ),
              ),
            ),
            // «فعّل فريق {host} {booster}» under the banners (3 s).
            if (announcement != null)
              Positioned(
                left: 0,
                right: 0,
                top: PkStageBanner.captionTop(
                  width,
                  paneHeight,
                  both: leftBoost != null && rightBoost != null,
                ),
                child: IgnorePointer(
                  child: Center(
                    child: Padding(
                      key: LivePkStage.announcementKey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.lg,
                      ),
                      child: Text(
                        l10n.pkBoostActivated(
                          KFormat.bidiIsolate(announcement.teamName),
                          pkBoosterName(l10n, announcement.kind),
                        ),
                        key: PkBoostText.lineKey,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textScaler: MediaQuery.textScalerOf(
                          context,
                        ).clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                        style: pkBoostLineStyle(context),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: barHeight + paneHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: barHeight,
                    height: paneHeight,
                    child: panes,
                  ),
                  // D199 (owner «يصبح شريط النقاط هكذا حسب كل حالة»): the
                  // owner's battle bar — neutral frames, or the tier's
                  // frame and emblem on a boosted side; Kabi pushes, pulls
                  // and wins on the seam. Drawn over the videos' top edge.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: barHeight,
                    child: Semantics(
                      label: l10n.pkScoreSemantics(
                        KFormat.grouped(own.score),
                        KFormat.grouped(other.score),
                      ),
                      excludeSemantics: true,
                      child: RepaintBoundary(
                        child: PkBattleBar(
                          key: LivePkStage.barKey,
                          leftScore: leftSide.score,
                          rightScore: rightSide.score,
                          ownSide: startIsLeft
                              ? PkPowerSide.left
                              : PkPowerSide.right,
                          leftTier: leftBoost == null
                              ? null
                              : pkPowerTier(leftBoost.kind),
                          rightTier: rightBoost == null
                              ? null
                              : pkPowerTier(rightBoost.kind),
                          leftAvatar: avatar(leftSide),
                          rightAvatar: avatar(rightSide),
                          winner: battle || connected
                              ? null
                              : match.winnerRoomId == leftSide.roomId
                              ? PkPowerSide.left
                              : match.winnerRoomId == rightSide.roomId
                              ? PkPowerSide.right
                              : null,
                        ),
                      ),
                    ),
                  ),
                  // The round's time hangs from the bar where the halves
                  // meet, over the emblem's lower edge (always readable).
                  if (battle)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: barHeight,
                      child: Center(
                        child: _RoundTimer(
                          key: LivePkStage.timerKey,
                          left: remaining,
                          round: match.bestOfThree ? match.round : null,
                        ),
                      ),
                    ),
                  if (!battle && !connected)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: barHeight,
                      child: Center(
                        child: _ResultChip(
                          key: LivePkStage.resultKey,
                          match: match,
                          own: own,
                          other: other,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: KSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: _Supporters(
                      supporters: own.supporters,
                      colors: KLivePk.startTeam,
                      start: true,
                      onTap: widget.onPerson,
                    ),
                  ),
                  Expanded(
                    child: _Supporters(
                      supporters: other.supporters,
                      colors: KLivePk.endTeam,
                      start: false,
                      onTap: widget.onPerson,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Pane extends StatelessWidget {
  const new({
    required this.side,
    required this.video,
    required this.label,
    required this.stage,
    required this.hostKey,
    required this.ring,
    required this.end,
    super.key,
    this.muted = false,
    this.onTap,
    this.onFollow,
  });

  final PkSide side;
  final Widget? video;
  final String label;
  final bool muted;
  final LivePkStage stage;

  /// D231: the host chip at the bottom of the half.
  final Key hostKey;
  final List<Color> ring;

  /// The chip on the half's end (the opponent: the outer edge).
  final bool end;

  /// D231: a tap on the half or the chip: the host's card.
  final VoidCallback? onTap;

  /// D231: the opponent's «+» (null hides it).
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final host = side.host;
    final onTap = this.onTap;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              image: true,
              label: label,
              child:
                  video ??
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF2A1A2E), Color(0xFF120A14)],
                      ),
                    ),
                    child: Center(
                      child: KAvatar(
                        name: host.displayName,
                        imageUrl: host.avatarUrl,
                        size: 72,
                      ),
                    ),
                  ),
            ),
            if (side.guests.isNotEmpty)
              PositionedDirectional(
                start: KLivePk.paneInset,
                end: KLivePk.paneInset,
                // Over the host's chip.
                bottom: KLivePk.paneInset * 2 + KLivePk.hostChip,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final (i, g) in side.guests.take(3).indexed) ...[
                      if (i > 0) const SizedBox(width: KSpacing.xs),
                      _GuestCircle(
                        key: LivePkStage.guestKey(g.user.id),
                        guest: g,
                        video: stage.guestVideo?.call(g.user.id),
                        speaking: stage.speaking.contains(g.user.id),
                        onTap: stage.onPerson == null
                            ? null
                            : () => stage.onPerson!(g.user),
                      ),
                    ],
                  ],
                ),
              ),
            PositionedDirectional(
              start: KLivePk.paneInset,
              end: KLivePk.paneInset,
              bottom: KLivePk.paneInset,
              child: Align(
                alignment: end
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: _HostChip(
                  key: hostKey,
                  host: host,
                  ring: ring,
                  muted: muted,
                  onTap: onTap,
                  onFollow: onFollow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// D231: a PK side's host at the bottom of their half — the round picture
/// in the team's ring, the name on one line, a muted mark when this room
/// muted them, and the opponent's «+» (follow) when given.
class _HostChip extends StatelessWidget {
  const new({
    required this.host,
    required this.ring,
    required this.muted,
    super.key,
    this.onTap,
    this.onFollow,
  });

  final UserSummary host;
  final List<Color> ring;
  final bool muted;
  final VoidCallback? onTap;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const white = Color(0xFFFFFFFF);
    final onFollow = this.onFollow;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    return Container(
      height: KLivePk.hostChip,
      padding: EdgeInsetsDirectional.only(
        end: onFollow == null ? KSpacing.sm : KSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: KLivePk.glass,
        borderRadius: BorderRadius.circular(KLivePk.hostChip / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: onTap != null,
            label: l10n.liveUserViewProfile,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: KLivePk.hostChip,
                height: KLivePk.hostChip,
                padding: const EdgeInsets.all(KLivePk.hostRing),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: ring),
                ),
                child: KAvatar(
                  name: host.displayName,
                  imageUrl: host.avatarUrl,
                  size: KLivePk.hostAvatar,
                ),
              ),
            ),
          ),
          const SizedBox(width: KSpacing.xs),
          if (muted) ...[
            Icon(
              Icons.volume_off_rounded,
              size: 14,
              color: white.withValues(alpha: 0.85),
            ),
            const SizedBox(width: KSpacing.xxs),
          ],
          Flexible(
            child: Text(
              host.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: scaler,
              style: context.textStyles.caption.copyWith(
                fontSize: KLivePk.hostName,
                fontWeight: FontWeight.w700,
                color: white,
                shadows: const [
                  Shadow(color: Color(0x99000000), blurRadius: 3),
                ],
              ),
            ),
          ),
          if (onFollow != null) ...[
            const SizedBox(width: KSpacing.xs),
            Semantics(
              button: true,
              label: l10n.pkFollowHost(host.displayName),
              excludeSemantics: true,
              child: GestureDetector(
                key: LivePkStage.followOpponentKey,
                behavior: HitTestBehavior.opaque,
                onTap: onFollow,
                // A 38 lp target around the 24 lp «+».
                child: const SizedBox(
                  width: KLivePk.hostChip - 4,
                  height: KLivePk.hostChip,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFE50914),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: KLivePk.follow,
                        height: KLivePk.follow,
                        child: Icon(Icons.add_rounded, size: 18, color: white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A PK guest: a small circle at the bottom of their host's box, glowing
/// while they speak (D195).
class _GuestCircle extends StatelessWidget {
  const new({
    required this.guest,
    required this.video,
    required this.speaking,
    required this.onTap,
    super.key,
  });

  final PkGuest guest;
  final Widget? video;
  final bool speaking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final glow = speaking ? const Color(0xFFFFD54F) : const Color(0xCCFFFFFF);
    final video = this.video;
    return Semantics(
      button: onTap != null,
      label: context.l10n.pkGuestSemantics(guest.user.displayName),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: KLivePk.guest,
          height: KLivePk.guest,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: glow, width: speaking ? 2 : 1.2),
            boxShadow: [
              if (speaking)
                const BoxShadow(
                  color: Color(0xAAFFC107),
                  blurRadius: 10,
                  spreadRadius: 1.5,
                ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                video ??
                    KAvatar(
                      name: guest.user.displayName,
                      imageUrl: guest.user.avatarUrl,
                      size: KLivePk.guest - 4,
                    ),
                if (guest.mutedByHost)
                  const ColoredBox(
                    color: Color(0x66000000),
                    child: Icon(
                      Icons.mic_off_rounded,
                      size: 14,
                      color: Color(0xFFFFFFFF),
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

/// The battle's time, hanging from the bar on the seam.
class _RoundTimer extends StatelessWidget {
  const new({required this.left, super.key, this.round});

  final Duration left;

  /// D199: a best-of-three round (null: a single PK).
  final int? round;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final time = KFormat.countdown(Duration(seconds: left.inSeconds));
    final last = left.inSeconds <= 60;
    return Container(
      height: KLivePk.timerHeight,
      constraints: const BoxConstraints(minWidth: KLivePk.timerWidth),
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: last
              ? const [Color(0xE6A3000B), Color(0xB3E50914)]
              : const [Color(0xCC1A0A06), Color(0x991A0A06)],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(KRadius.md),
        ),
        boxShadow: const [BoxShadow(color: Color(0x40FF7A00), blurRadius: 6)],
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          switch (round) {
            final r? => '${l10n.pkRoundLabel('$r')} $time',
            null when last => l10n.pkFinalRound(time),
            null => l10n.pkRoundTimer(time),
          },
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
          style: context.textStyles.label.copyWith(
            fontSize: KLivePk.timerText,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: KPalette.dark.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
            shadows: const [Shadow(color: Color(0x99000000), blurRadius: 2)],
          ),
        ),
      ),
    );
  }
}

/// The result from this room's side and why it ended.
class _ResultChip extends StatelessWidget {
  const new({
    required this.match,
    required this.own,
    required this.other,
    super.key,
  });

  final PkMatch match;
  final PkSide own;
  final PkSide other;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final win = match.winnerRoomId == own.roomId;
    final lose = match.winnerRoomId == other.roomId;
    final title = match.endReason == PkEndReason.admin
        ? l10n.pkEndedAdmin
        : win
        ? l10n.pkResultWin
        : lose
        ? l10n.pkResultLose
        : l10n.pkResultDraw;
    final loser = match.loserCauseRoomId == own.roomId
        ? own.host.displayName
        : other.host.displayName;
    final reason = switch (match.endReason) {
      PkEndReason.forfeit => l10n.pkEndedForfeit(loser),
      PkEndReason.disconnect => l10n.pkEndedDisconnect(loser),
      PkEndReason.away => l10n.pkEndedAway(loser),
      _ => null,
    };
    final colors = win
        ? const [Color(0xFFFFD54F), Color(0xFFFF8F00)]
        : lose
        ? const [Color(0xFF8E8E9A), Color(0xFF4A4A55)]
        : const [Color(0xFF7FB3FF), Color(0xFF3D6FD9)];
    return Semantics(
      liveRegion: true,
      label: reason == null ? title : '$title. $reason',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(top: KSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.lg,
          vertical: KSpacing.xs,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(KRadius.pill),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
              style: context.textStyles.title.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFFFFFF),
              ),
            ),
            // D216: why it ended, on a dark glass line with its icon (the
            // interruption states' style).
            if (reason != null)
              Container(
                margin: const EdgeInsets.only(
                  top: KSpacing.xxs,
                  bottom: KSpacing.xxs,
                ),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  KSpacing.xs,
                  KSpacing.xxs,
                  KSpacing.sm,
                  KSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x59000000),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      switch (match.endReason) {
                        PkEndReason.disconnect => Icons.wifi_off_rounded,
                        PkEndReason.away => Icons.hourglass_bottom_rounded,
                        _ => Icons.flag_rounded,
                      },
                      size: 13,
                      color: const Color(0xFFFFFFFF),
                    ),
                    const SizedBox(width: KSpacing.xs),
                    Flexible(
                      child: Text(
                        reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: MediaQuery.textScalerOf(
                          context,
                        ).clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                        style: context.textStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// v1.44-live (D199): connected — the host's «ابدأ PK», or for a viewer
/// the line that it starts when a host taps it.
class _Connected extends StatelessWidget {
  const new({required this.onStart, super.key});

  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(KRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.pkConnectedHint,
            textAlign: TextAlign.center,
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
            style: context.textStyles.label.copyWith(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onStart != null) ...[
            const SizedBox(height: KSpacing.sm),
            FilledButton.icon(
              key: LivePkStage.startKey,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
              ),
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.pkStart),
            ),
          ],
        ],
      ),
    );
  }
}

/// A side's top three, rank 1 nearest the seam, ringed in the team colour.
class _Supporters extends StatelessWidget {
  const new({
    required this.supporters,
    required this.colors,
    required this.start,
    this.onTap,
  });

  final List<PkSupporter> supporters;
  final List<Color> colors;
  final bool start;
  final ValueChanged<UserSummary>? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final top = supporters.take(3).toList();
    final ordered = [for (final (i, s) in top.indexed) (i + 1, s)];
    final shown = start ? ordered.reversed.toList() : ordered;
    final separator = Directionality.of(context) == TextDirection.rtl
        ? '، '
        : ', ';
    return Align(
      alignment: start
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Semantics(
        label: top.isEmpty
            ? null
            : l10n.pkSupporters(
                top.map((s) => s.user.displayName).join(separator),
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, (rank, s)) in shown.indexed) ...[
              if (i > 0) const SizedBox(width: 4),
              GestureDetector(
                onTap: onTap == null ? null : () => onTap!(s.user),
                child: SizedBox(
                  width: KLivePk.supporterAvatar + 4,
                  height: KLivePk.supporterAvatar + 4,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: colors),
                        ),
                        child: KAvatar(
                          name: s.user.displayName,
                          imageUrl: s.user.avatarUrl,
                          size: KLivePk.supporterAvatar,
                        ),
                      ),
                      PositionedDirectional(
                        end: -2,
                        bottom: -3,
                        child: Text(
                          '$rank',
                          textScaler: TextScaler.noScaling,
                          style: context.textStyles.label.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: colors[1],
                            shadows: [
                              for (final o in const [
                                Offset(1, 1),
                                Offset(-1, -1),
                                Offset(1, -1),
                                Offset(-1, 1),
                              ])
                                Shadow(
                                  color: KPalette.dark.textPrimary,
                                  offset: o,
                                ),
                            ],
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
    );
  }
}
