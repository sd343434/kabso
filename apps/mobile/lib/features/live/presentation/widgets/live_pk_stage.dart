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
import 'package:kabso_live/features/live/presentation/widgets/live_pk_dare.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_rematch.dart';
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

  /// D231 → D238b (owner, ref 332: «حتى حجم خط pk»): «PK 3:47» hanging
  /// under the bar where the halves meet, at the reference's size —
  /// measured 64.7 × 17.9 lp (152 × 42 px at 2.349 px/lp), its digits
  /// 8.1 lp tall (11.5 sp, estimate). Was 112 × 26, 15 sp.
  static const double timerHeight = 18;
  static const double timerWidth = 64;
  static const double timerText = 11.5;
  static const double timerRadius = 5;

  /// D238b (owner, ref 332: «اسم المضيف يظهر للمشاهدين اسم المضيف الآخر …
  /// واجعل طريقة اسم المضيف مطابق للقطة»): only the OTHER host's name, in
  /// the reference's pill at the bottom outer corner of their half —
  /// measured 14 lp tall (33 px), its bottom 7.2 lp over the video's bottom
  /// and its end 11.1 lp in from the screen edge, at most 86 lp wide; the
  /// name 9 sp (estimate: 6.4 lp cap height) with «…», the round «+»
  /// (13 lp) at its end. Dark glass about 32 % (measured over the video).
  static const double pillHeight = 14;
  static const double pillBottom = 7.2;
  static const double pillEnd = 11.1;
  static const double pillMaxWidth = 86;
  static const double pillText = 9;
  static const double pillPlus = 13;
  static const Color pillGlass = Color(0x52000000);

  /// D276 (owner: «يجب ان يظهر لكل شخص نقاط بيكيه الاخر»): each host's
  /// «نقاط PK» in the name pill's glass at the top outer corner of their
  /// half, just under the battle bar's track, its edge in the side's
  /// colour — both hosts' for both rooms and every viewer.
  static const double pointsTop = 5;
  static const double pointsHeight = 16;
  static const double pointsLabel = 8.5;
  static const double pointsValue = 10;

  /// The «+»'s touch target around the 13 lp circle (the pill stays the
  /// reference's size; the target reaches past it).
  static const double pillTarget = 28;

  /// D238b: the reference's hairline between the halves (measured 1 px at
  /// 2.349 px/lp; was 2 lp).
  static const double seam = 0.5;
  static const double paneInset = 6;
  static const double maxPaneHeight = 374;

  /// Pane height per pane width. D238b: the reference's halves (measured
  /// 196.1 × 327.1 lp: 0.6; was 0.58) — edge to edge.
  static const double paneAspect = 0.6;
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
    this.rematchBanner = false,
  });

  final PkMatch match;

  /// D242: «جولة أخرى!» over the videos (the new battle just started).
  final bool rematchBanner;

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

  /// D276: a host's «نقاط PK» chip (by their room).
  static Key pointsKey(String roomId) => Key('pk.points.$roomId');

  /// D238: the «PK أحكام» card for the room's bottom dock
  /// (`KLiveRoomScaffold.dock`) while [match] has a dare after its battle;
  /// the draw stays over the stage. [isHost]: this device is [roomId]'s host
  /// (the dare's buttons); [actions]: what it may do. D242: and the hosts'
  /// «جولة أخرى» card ([rematch]; null for viewers) under it in the result.
  /// Null when there is nothing to dock.
  static Widget? dareDock({
    required PkMatch match,
    required String roomId,
    required DateTime Function() now,
    bool isHost = false,
    PkDareActions actions = const PkDareActions(),
    PkRematchActions? rematch,
  }) {
    if (match.status == PkMatchStatus.battle || match.connected) return null;
    final clock = debugNow ?? now;
    final dare = match.dare;
    final dareCard = dare == null
        ? null
        : PkDareDock(
            match: match,
            dare: dare,
            roomId: roomId,
            // D231's test clock pins the dare's phases too.
            now: clock,
            isHost: isHost,
            actions: actions,
            ticks: ticks,
          );
    final rematchCard = rematch == null || !PkRematchDock.shows(match, roomId)
        ? null
        : PkRematchDock(
            match: match,
            roomId: roomId,
            now: clock,
            actions: rematch,
            ticks: ticks,
          );
    if (dareCard == null) return rematchCard;
    if (rematchCard == null) return dareCard;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dareCard,
        const SizedBox(height: KSpacing.xs),
        rematchCard,
      ],
    );
  }

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // D231b (owner: «خط الـpk اجعله كامل الشاشة»): the bar bleeds past
        // the stage's side margins to the screen's edges (the room's
        // scaffold keeps the stage inset by the same amount on each side).
        final bleed = math
            .max(0, (MediaQuery.sizeOf(context).width - width) / 2)
            .toDouble();
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
                    end: false,
                    team: KLivePk.startTeam,
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
                    end: true,
                    team: KLivePk.endTeam,
                    // D238b: only the other host's name on their video.
                    pill: true,
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
            if (!battle && !connected && match.dare == null) ...[
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
            // v1.50-live (D229): «PK أحكام» — the draw, both rooms (under
            // the result chip at the videos' top edge). D238: the loser's
            // answer, the banner and the outcome are [dareDock]'s small
            // card at the bottom of the room, off the videos.
            if (match.dare case final dare? when !battle && !connected)
              Positioned.fill(
                top: 28,
                child: PkDareLayer(
                  match: match,
                  dare: dare,
                  roomId: widget.roomId,
                  // D231's test clock pins the dare's phases too.
                  now: LivePkStage.debugNow ?? widget.now,
                  ticks: LivePkStage.ticks,
                ),
              ),
            // D199 → D231b (owner: «الدبل والتربل يجب أن يظهر عند من
            // ظهر»): each side's banner over its OWN video half (the
            // screen's left half is the left team in both languages),
            // centred in it and scaled to the half; two boosted sides show
            // side by side, never stacked in the middle. Both rooms.
            Positioned.fill(
              child: IgnorePointer(
                child: PkPowerLayer(
                  key: LivePkStage.bannersKey,
                  left: activation(leftSide, leftBoost, PkPowerSide.left),
                  right: activation(rightSide, rightBoost, PkPowerSide.right),
                  perHalf: true,
                  seam: KLivePk.seam,
                  widthFactor: PkStageBanner.halfFactor,
                  top: PkStageBanner.top(width, paneHeight),
                ),
              ),
            ),
            // D242: «جولة أخرى!» for everyone as the new battle starts.
            if (widget.rematchBanner)
              const Positioned(
                left: 0,
                right: 0,
                top: KLivePk.timerHeight + KSpacing.md,
                child: IgnorePointer(child: Center(child: PkRematchBanner())),
              ),
            // «فعّل فريق {host} {booster}» under the banners (3 s).
            if (announcement != null)
              Positioned(
                left: 0,
                right: 0,
                top: PkStageBanner.captionTop(width, paneHeight),
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
                  // owner's battle bar — each side's tier on its half of
                  // the track, the PK emblem; Kabi pushes, pulls and wins
                  // on the seam. D231b: edge to edge of the screen, no end
                  // frames.
                  Positioned(
                    left: -bleed,
                    right: -bleed,
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
    required this.end,
    required this.team,
    super.key,
    this.muted = false,
    this.pill = false,
    this.onTap,
    this.onFollow,
  });

  final PkSide side;
  final Widget? video;
  final String label;
  final bool muted;
  final LivePkStage stage;

  /// D231: the host's name pill at the bottom of the half.
  final Key hostKey;

  /// The pill on the half's end (the opponent: the outer edge).
  final bool end;

  /// D276: the side's colours (the «نقاط PK» chip's edge).
  final List<Color> team;

  /// D238b: this half shows its host's name pill (only the other room's
  /// host: this room's host is already in the top bar).
  final bool pill;

  /// D231: a tap on the half: the host's card.
  final VoidCallback? onTap;

  /// D231: the opponent's «+» (null hides it).
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final host = side.host;
    final onTap = this.onTap;
    // D238b: the whole half is the host's button (their card) for screen
    // readers too; the guests and the «+» are their own buttons.
    return Semantics(
      container: true,
      button: onTap != null,
      label: label,
      hint: onTap == null ? null : context.l10n.liveUserViewProfile,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
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
                  // Over the name pill's touch row.
                  bottom: KLivePk.pillTarget + KSpacing.xs,
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
              // D276: «نقاط PK» at the half's top outer corner.
              if (side.pkPoints case final points?)
                PositionedDirectional(
                  top: KLivePk.pointsTop,
                  start: end ? null : KLivePk.paneInset,
                  end: end ? KLivePk.paneInset : null,
                  child: PkPointsChip(
                    key: LivePkStage.pointsKey(side.roomId),
                    name: host.displayName,
                    points: points,
                    team: team,
                  ),
                ),
              if (pill)
                PositionedDirectional(
                  start: KLivePk.paneInset,
                  // The pill's end [KLivePk.pillEnd] from the edge; its «+»
                  // target reaches half the slack further.
                  end:
                      KLivePk.pillEnd -
                      (onFollow == null ? 0 : _HostPill.slack),
                  bottom:
                      KLivePk.pillBottom -
                      (KLivePk.pillTarget - KLivePk.pillHeight) / 2,
                  child: Align(
                    alignment: end
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: _HostPill(
                      key: hostKey,
                      host: host,
                      muted: muted,
                      onFollow: onFollow,
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

/// D276 «نقاط PK»: a host's PK points (`PkHostRecord.points`, may be below
/// 0) in the name pill's dark glass, edged in their side's colour like the
/// battle bar's halves: the label, then the figure in the bar's face.
class PkPointsChip extends StatelessWidget {
  const new({
    required this.name,
    required this.points,
    required this.team,
    super.key,
  });

  final String name;
  final int points;
  final List<Color> team;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const white = Color(0xFFFFFFFF);
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    // A real minus below 0, left to right in Arabic too (as D229's
    // [KFormat.signed], without the «+»).
    final figure =
        '\u2066${points < 0 ? '\u2212' : ''}'
        '${KFormat.grouped(points.abs())}\u2069';
    return Semantics(
      label: l10n.pkPointsSemantics(KFormat.bidiIsolate(name), figure),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: KLivePk.pointsHeight),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: KLivePk.pillGlass,
          borderRadius: BorderRadius.circular(KLivePk.pointsHeight / 2),
          border: Border.all(color: team[1].withValues(alpha: 0.9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.pkPointsLabel,
              maxLines: 1,
              textScaler: scaler,
              style: context.textStyles.caption.copyWith(
                fontSize: KLivePk.pointsLabel,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              figure,
              maxLines: 1,
              textScaler: scaler,
              style: TextStyle(
                fontFamily: PkBarMetrics.family,
                fontSize: KLivePk.pointsValue,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: team[0],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// D238b (ref 332, measured): the other host's name in a small dark glass
/// pill — the name on one line with «…», a muted mark when this room muted
/// them, and the round «+» (follow) at its end when given: Kabso red
/// (D232) with a white «+». The pill is [KLivePk.pillHeight] tall inside a
/// transparent [KLivePk.pillTarget] row, so the «+» has a usable target.
/// A tap on the name falls through to the half (the host's card).
class _HostPill extends StatelessWidget {
  const new({
    required this.host,
    required this.muted,
    super.key,
    this.onFollow,
  });

  final UserSummary host;
  final bool muted;
  final VoidCallback? onFollow;

  /// How far the «+» target reaches past the pill's end.
  static const double slack = (KLivePk.pillTarget - KLivePk.pillPlus) / 2 - 1;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const white = Color(0xFFFFFFFF);
    final onFollow = this.onFollow;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final pill = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KLivePk.pillMaxWidth),
      child: Container(
        constraints: const BoxConstraints(minHeight: KLivePk.pillHeight),
        padding: EdgeInsetsDirectional.only(
          start: 6,
          end: onFollow == null ? 6 : 0.5,
        ),
        decoration: BoxDecoration(
          color: KLivePk.pillGlass,
          borderRadius: BorderRadius.circular(KLivePk.pillHeight / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (muted) ...[
              Icon(
                Icons.volume_off_rounded,
                size: 10,
                color: white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 2),
            ],
            Flexible(
              child: Text(
                host.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: scaler,
                style: context.textStyles.caption.copyWith(
                  fontSize: KLivePk.pillText,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: white,
                ),
              ),
            ),
            if (onFollow != null) ...[
              const SizedBox(width: 4),
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFE50914),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: KLivePk.pillPlus,
                  child: Icon(Icons.add_rounded, size: 11, color: white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    final name = Semantics(
      label: host.displayName,
      excludeSemantics: true,
      child: pill,
    );
    if (onFollow == null) {
      return SizedBox(
        height: KLivePk.pillTarget,
        child: Center(widthFactor: 1, child: name),
      );
    }
    return SizedBox(
      height: KLivePk.pillTarget,
      child: Stack(
        alignment: AlignmentDirectional.centerEnd,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: slack),
            child: name,
          ),
          PositionedDirectional(
            end: 0,
            top: 0,
            bottom: 0,
            width: KLivePk.pillTarget,
            child: Semantics(
              button: true,
              label: l10n.pkFollowHost(host.displayName),
              excludeSemantics: true,
              child: GestureDetector(
                key: LivePkStage.followOpponentKey,
                behavior: HitTestBehavior.opaque,
                onTap: onFollow,
              ),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: last
              ? const [Color(0xE6A3000B), Color(0xB3E50914)]
              : const [Color(0xCC1A0A06), Color(0x991A0A06)],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(KLivePk.timerRadius),
        ),
        boxShadow: const [BoxShadow(color: Color(0x40FF7A00), blurRadius: 4)],
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
