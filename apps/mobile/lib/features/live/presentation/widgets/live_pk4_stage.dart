import 'dart:async';
import 'dart:math' as math;

import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/domain/live_pk4.dart';
import 'package:kabso_live/features/live/presentation/widgets/battle_emoji.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_boost_fx.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_dare.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// «PK رباعي» stage geometry and colours (D71's 2 × 2 layout, wired to the
/// real match — v1.118-live, D391, CP-041 §2 / §8; v1.119-live, D395: two to
/// four hosts and FREE_FOR_ALL).
abstract final class KLivePk4 {
  /// D71: the 2 × 2 grid (M: 389 lp tall at 430 wide).
  static const double maxGridHeight = 389;

  /// Grid height per grid width (D71: 389 / 430).
  static const double gridAspect = 0.905;
  static const double seam = 2;
  static const double paneInset = 5;
  static const double pillHeight = 20;
  static const double pillText = 10;
  static const double muteSize = 26;
  static const double avatar = 46;
  static const double outcome = 96;

  /// D395: the result animation over a FREE_FOR_ALL pane (a quarter).
  static const double paneOutcome = 64;

  /// D71 (owner): the caller's team in Kabso red, the opponents in blazing
  /// orange; top → bottom, the last is solid.
  static const List<Color> startTeam = [
    Color(0xFFFF4A4A),
    Color(0xFFE50914),
    Color(0xFFA3000B),
  ];
  static const List<Color> endTeam = [
    Color(0xFFFFC94D),
    Color(0xFFFF7A00),
    Color(0xFFD94400),
  ];

  /// D395 (CP-041 §2): FREE_FOR_ALL — one colour per host (place 1 Kabso
  /// red, 2 violet, 3 blazing orange, 4 teal), in the same three-stop form.
  static const List<List<Color>> ffaSeat = [
    startTeam,
    [Color(0xFFB794FF), Color(0xFF7C3AED), Color(0xFF4C1D95)],
    endTeam,
    [Color(0xFF5EEAD4), Color(0xFF0D9488), Color(0xFF115E59)],
  ];

  /// [KabsoPkBar] fills, outer edge → seam.
  static final List<Color> startFill = startTeam.reversed.toList();
  static final List<Color> endFill = endTeam.reversed.toList();
  static const Color glass = Color(0x66000000);

  /// D395: the four-part bar's height (KabsoPkBar's bar, without Kabi).
  static const double ffaBarHeight = 26;

  /// D395 (owner «أ»): the result badge under the scores line — smaller and
  /// softer than the 1 v 1 result.
  static const double badgeHeight = 26;
  static const double badgeText = 12.5;
  static const double badgeIcon = 15;

  /// The colours of [seat]'s pane (TEAMS: by team, this room's team red).
  static List<Color> colorsOf(Pk4Match match, Pk4Seat seat, Pk4Team ownTeam) {
    if (match.ffa) return ffaSeat[(seat.seat - 1).clamp(0, 3)];
    return seat.team == ownTeam ? startTeam : endTeam;
  }
}

/// The stage of a 4-way PK (v1.118-live, D391, §10.180; v1.119-live, D395,
/// §10.181): the bar — TEAMS: the two-colour [KabsoPkBar] with the team
/// totals (this room's team on the reading start); FREE_FOR_ALL: the
/// four-part [Pk4FfaBar], the leader first — the result badge right under it
/// ([Pk4ResultBadge]), the round timer, and the hosts' panes by side: this
/// room's side in the start column with this room's host at the top, the
/// other side in the end column. Two hosts: half the screen each; three: two
/// stacked on one side and the third alone on the other (a tile the size of
/// two); four: the 2 × 2 grid. Each pane has that host's own score, the
/// booster chips (TEAMS: per team; FREE_FOR_ALL: per host), the result (the
/// 1 v 1 win / lose / draw animation; FREE_FOR_ALL: per pane with its place)
/// and the top three supporters per side. The hosts' guests are not drawn
/// (CP-041 §8). A host sees one switch per other pane to mute that host for
/// their own room. Everything comes from the server's [match]; [now] is the
/// server clock.
class LivePk4Stage extends StatefulWidget {
  const new({
    required this.match,
    required this.roomId,
    required this.now,
    required this.video,
    super.key,
    this.speaking = const {},
    this.announcement,
    this.isHost = false,
    this.onMute,
    this.onStart,
    this.onHost,
    this.onPerson,
  });

  final Pk4Match match;

  /// This room (its side on the reading start, its host at the top).
  final String roomId;

  /// A host's video (this room's from its own session, the others' from the
  /// 4-way connections), or null: their picture.
  final Widget? Function(Pk4Seat seat) video;

  /// Who speaks now (user ids, the rooms): their pane glows.
  final Set<String> speaking;

  final PkAnnouncement? announcement;

  /// This device is [roomId]'s host: the mute switches.
  final bool isHost;

  /// The host mutes (or unmutes) another pane's host for their room.
  final void Function(Pk4Seat seat, {required bool muted})? onMute;

  /// A host starts a CONNECTED match (null: a viewer).
  final VoidCallback? onStart;

  /// A tap on a pane: that host's card.
  final ValueChanged<UserSummary>? onHost;

  /// A tap on a supporter: their card.
  final ValueChanged<UserSummary>? onPerson;

  final DateTime Function() now;

  static const barKey = Key('pk4.bar');
  static const ffaBarKey = Key('pk4.ffaBar');
  static const timerKey = Key('pk4.timer');
  static const resultKey = Key('pk4.result');
  static const connectedKey = Key('pk4.connected');
  static const announcementKey = Key('pk4.announcement');
  static Key paneKey(int seat) => Key('pk4.pane.$seat');
  static Key scoreKey(int seat) => Key('pk4.score.$seat');
  static Key muteKey(int seat) => Key('pk4.mute.$seat');
  static Key boostKey(Pk4Team team) => Key('pk4.boost.${team.wire}');
  static Key seatBoostKey(int seat) => Key('pk4.boost.seat.$seat');
  static Key placeKey(int seat) => Key('pk4.place.$seat');

  /// v1.119-live (D395): the «PK أحكام» card and the hosts' «جولة أخرى» card
  /// for the room's bottom dock while [match] is in its result (null when
  /// there is nothing to dock). [isHost]: this device is [roomId]'s host;
  /// [actions]: what it may do with the dare; [rematch]: the host's
  /// «جولة أخرى» (null for viewers).
  static Widget? dock({
    required Pk4Match match,
    required String roomId,
    required DateTime Function() now,
    bool isHost = false,
    PkDareActions actions = const PkDareActions(),
    Pk4RematchActions? rematch,
  }) {
    if (match.status == PkMatchStatus.battle ||
        match.status == PkMatchStatus.connected) {
      return null;
    }
    // ignore: invalid_use_of_visible_for_testing_member, the goldens' clock pin (D231).
    final clock = LivePkStage.debugNow ?? now;
    final view = match.dareView(roomId);
    final dareCard = view?.dare == null
        ? null
        : PkDareDock(
            match: view!,
            dare: view.dare!,
            roomId: roomId,
            now: clock,
            isHost: isHost,
            actions: actions,
            ticks: LivePkStage.ticks,
          );
    final rematchCard = rematch == null || !Pk4RematchDock.shows(match, roomId)
        ? null
        : Pk4RematchDock(
            match: match,
            roomId: roomId,
            now: clock,
            actions: rematch,
            ticks: LivePkStage.ticks,
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
  State<LivePk4Stage> createState() => _LivePk4StageState();
}

class _LivePk4StageState extends State<LivePk4Stage> {
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
    // ignore: invalid_use_of_visible_for_testing_member, the goldens' clock pin (D231).
    final clock = LivePkStage.debugNow ?? widget.now;
    final now = clock();
    final battle = match.status == PkMatchStatus.battle;
    final connected = match.status == PkMatchStatus.connected;
    final ended = !battle && !connected;
    final ffa = match.ffa;
    final ownTeam = match.teamOf(widget.roomId);
    final own = match.team(ownTeam);
    final other = match.team(ownTeam.other);
    final ownSeats = match.seatsOf(ownTeam, first: widget.roomId);
    final otherSeats = match.seatsOf(ownTeam.other);
    final me = match.seatOf(widget.roomId);
    final left = battle ? match.battleEndsAt.difference(now) : Duration.zero;
    final remaining = left.isNegative ? Duration.zero : left;
    final startIsLeft = Directionality.of(context) == TextDirection.ltr;
    final result = switch (match.winnerTeam) {
      _ when !ended => null,
      null => KabsoPkResult.draw,
      final w when (w == ownTeam) == startIsLeft => KabsoPkResult.leftWins,
      _ => KabsoPkResult.rightWins,
    };
    final voided =
        match.endReason == PkEndReason.admin ||
        match.endReason == PkEndReason.cancelled;
    final dareView = ended ? match.dareView(widget.roomId) : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gridHeight = math.min(
          KLivePk4.maxGridHeight,
          width * KLivePk4.gridAspect,
        );
        Widget column(List<Pk4Seat> seats) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, seat) in seats.indexed) ...[
              if (i > 0) const SizedBox(height: KLivePk4.seam),
              Expanded(
                child: _Pane(
                  key: LivePk4Stage.paneKey(seat.seat),
                  seat: seat,
                  video: widget.video(seat),
                  colors: KLivePk4.colorsOf(match, seat, ownTeam),
                  speaking: widget.speaking.contains(seat.host.id),
                  // The host's own pane has no switch; the others show
                  // whether this room's host muted them.
                  muted: me?.mutedRoomIds.contains(seat.roomId) ?? false,
                  onMute: widget.isHost && seat.roomId != widget.roomId
                      ? widget.onMute
                      : null,
                  onTap: widget.onHost == null
                      ? null
                      : () => widget.onHost!(seat.host),
                  // FREE_FOR_ALL: the host's own booster and, at the end,
                  // the place and the 1 v 1 result animation.
                  boost: ffa && battle ? seat.boostAt(now) : null,
                  now: now,
                  place: ffa && ended && !voided ? seat.place : null,
                  outcome: ffa && ended && !voided ? seat.result : null,
                ),
              ),
            ],
          ],
        );
        final grid = Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: column(ownSeats)),
                const SizedBox(width: KLivePk4.seam),
                Expanded(child: column(otherSeats)),
              ],
            ),
            if (battle && !ffa) ...[
              for (final (team, start) in [(own, true), (other, false)])
                if (team.boostAt(now) case final boost?)
                  Align(
                    alignment: start
                        ? AlignmentDirectional.topStart
                        : AlignmentDirectional.topEnd,
                    child: Padding(
                      padding: const EdgeInsets.all(KLivePk4.paneInset),
                      child: _BoostChip(
                        key: LivePk4Stage.boostKey(team.team),
                        boost: boost,
                        now: now,
                      ),
                    ),
                  ),
            ],
            if (connected)
              Align(
                child: _Connected(
                  key: LivePk4Stage.connectedKey,
                  onStart: widget.onStart,
                ),
              ),
            // TEAMS: the 1 v 1 result animation per side (win / lose / draw).
            if (ended && !voided && !ffa) ...[
              for (final (team, start) in [(own, true), (other, false)])
                Align(
                  alignment: start
                      ? AlignmentDirectional.centerStart
                      : AlignmentDirectional.centerEnd,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: (width - KLivePk4.seam) / 2,
                      child: Center(
                        child: KabsoBattleEmoji(switch (team.result) {
                          'WIN' => KabsoBattle.win,
                          'LOSS' => KabsoBattle.lose,
                          _ => KabsoBattle.draw,
                        }, size: KLivePk4.outcome),
                      ),
                    ),
                  ),
                ),
            ],
            if (battle && widget.announcement != null)
              Align(
                alignment: const Alignment(0, -0.1),
                child: IgnorePointer(
                  child: Padding(
                    key: LivePk4Stage.announcementKey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.lg,
                    ),
                    child: Text(
                      l10n.pkBoostActivated(
                        KFormat.bidiIsolate(widget.announcement!.teamName),
                        pkBoosterName(l10n, widget.announcement!.kind),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textScaler: MediaQuery.textScalerOf(context)
                          .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                      style: pkBoostLineStyle(context),
                    ),
                  ),
                ),
              ),
            // v1.119-live (D395): the «PK أحكام» draw over the stage.
            if (dareView?.dare case final dare?)
              Positioned.fill(
                top: KLivePk4.badgeHeight + KSpacing.sm,
                child: PkDareLayer(
                  match: dareView!,
                  dare: dare,
                  roomId: widget.roomId,
                  now: clock,
                  ticks: LivePkStage.ticks,
                ),
              ),
          ],
        );
        final ownResult = ended && !voided
            ? match.resultOf(widget.roomId)
            : null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ffa)
              Pk4FfaBar(
                key: LivePk4Stage.ffaBarKey,
                match: match,
                ownTeam: ownTeam,
              )
            else
              Semantics(
                label: l10n.pk4ScoreSemantics(
                  KFormat.grouped(own.score),
                  KFormat.grouped(other.score),
                ),
                excludeSemantics: true,
                child: RepaintBoundary(
                  child: KabsoPkBar(
                    key: LivePk4Stage.barKey,
                    left: startIsLeft ? own.score : other.score,
                    right: startIsLeft ? other.score : own.score,
                    remaining: Duration(seconds: remaining.inSeconds),
                    result: result,
                    leftColors: startIsLeft
                        ? KLivePk4.startFill
                        : KLivePk4.endFill,
                    rightColors: startIsLeft
                        ? KLivePk4.endFill
                        : KLivePk4.startFill,
                    formatScore: KFormat.grouped,
                  ),
                ),
              ),
            SizedBox(
              height: gridHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: grid),
                  if (battle)
                    Align(
                      alignment: Alignment.topCenter,
                      child: _Timer(
                        key: LivePk4Stage.timerKey,
                        left: remaining,
                      ),
                    ),
                  // D395 (owner «أ»): the result badge directly under the
                  // scores line; the moderator's void end keeps its chip.
                  if (ended && voided)
                    const Align(
                      alignment: Alignment.topCenter,
                      child: _VoidChip(key: LivePk4Stage.resultKey),
                    )
                  else if (ownResult != null)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: KSpacing.xxs),
                        child: Pk4ResultBadge(
                          key: LivePk4Stage.resultKey,
                          result: ownResult,
                          label: pk4ResultLabel(
                            l10n,
                            match,
                            widget.roomId,
                            ownResult,
                          ),
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
                      supporters: ffa ? _merged(ownSeats) : own.supporters,
                      colors: ffa
                          ? KLivePk4.colorsOf(match, ownSeats.first, ownTeam)
                          : KLivePk4.startTeam,
                      start: true,
                      onTap: widget.onPerson,
                    ),
                  ),
                  Expanded(
                    child: _Supporters(
                      supporters: ffa ? _merged(otherSeats) : other.supporters,
                      colors: ffa && otherSeats.isNotEmpty
                          ? KLivePk4.colorsOf(match, otherSeats.first, ownTeam)
                          : KLivePk4.endTeam,
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

  /// FREE_FOR_ALL: the top three of the hosts on one side.
  static List<PkSupporter> _merged(List<Pk4Seat> seats) =>
      [for (final s in seats) ...s.supporters]
        ..sort((a, b) => b.points.compareTo(a.points));
}

/// v1.119-live (D395): the label of this room's result badge — TEAMS «فاز
/// فريقكم» / «خسر فريقكم» / «تعادل الفريقان» («فزت» / «خسرت» when the room
/// plays alone on its side); FREE_FOR_ALL «المركز الأول» / «المركز N» /
/// «تعادل على المركز الأول».
String pk4ResultLabel(
  AppLocalizations l10n,
  Pk4Match match,
  String roomId,
  Pk4Result result,
) {
  final seat = match.seatOf(roomId);
  if (match.ffa) {
    final place = seat?.place ?? 1;
    return switch (result) {
      Pk4Result.win => l10n.pk4ResultFirst,
      Pk4Result.draw => l10n.pk4ResultDrawFirst,
      Pk4Result.loss => l10n.pk4ResultPlace('$place'),
    };
  }
  final alone = seat != null && match.seatsOf(seat.team).length == 1;
  return switch (result) {
    Pk4Result.win => alone ? l10n.pk4ResultWinSolo : l10n.pk4ResultWin,
    Pk4Result.loss => alone ? l10n.pk4ResultLossSolo : l10n.pk4ResultLoss,
    Pk4Result.draw => l10n.pk4ResultDrawTeams,
  };
}

class _Pane extends StatelessWidget {
  const new({
    required this.seat,
    required this.video,
    required this.colors,
    required this.speaking,
    required this.muted,
    super.key,
    this.onMute,
    this.onTap,
    this.boost,
    this.now,
    this.place,
    this.outcome,
  });

  final Pk4Seat seat;

  /// v1.119-live (D395) FREE_FOR_ALL: the host's own booster now.
  final PkActiveBoost? boost;
  final DateTime? now;

  /// v1.119-live (D395) FREE_FOR_ALL: the place and the result at the end.
  final int? place;
  final Pk4Result? outcome;
  final Widget? video;
  final List<Color> colors;
  final bool speaking;
  final bool muted;
  final void Function(Pk4Seat seat, {required bool muted})? onMute;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = KPalette.dark.textPrimary;
    final t = context.textStyles;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final host = seat.host;
    final onMute = this.onMute;
    return Semantics(
      label: l10n.pk4PaneSemantics(
        host.displayName,
        KFormat.grouped(seat.score),
      ),
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRect(
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(
                color: speaking ? colors[1] : const Color(0x00000000),
                width: 2,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: const Color(0xFF15131A),
                  child:
                      video ??
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: colors),
                          ),
                          child: KAvatar(
                            name: host.displayName,
                            imageUrl: host.avatarUrl,
                            size: KLivePk4.avatar,
                          ),
                        ),
                      ),
                ),
                // D395: FREE_FOR_ALL's result per pane — the 1 v 1 animation
                // (win for the 1st, draw for a shared 1st, lose otherwise).
                if (outcome case final o?)
                  IgnorePointer(
                    child: Center(
                      child: KabsoBattleEmoji(switch (o) {
                        Pk4Result.win => KabsoBattle.win,
                        Pk4Result.loss => KabsoBattle.lose,
                        Pk4Result.draw => KabsoBattle.draw,
                      }, size: KLivePk4.paneOutcome),
                    ),
                  ),
                if (seat.out)
                  ColoredBox(
                    color: const Color(0x99000000),
                    child: Center(
                      child: _Glass(
                        child: Text(
                          l10n.pk4Out,
                          textScaler: scaler,
                          style: t.caption.copyWith(
                            fontWeight: FontWeight.w800,
                            color: white,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (boost case final b? when now != null)
                  PositionedDirectional(
                    top: KLivePk4.paneInset,
                    start: KLivePk4.paneInset,
                    child: _BoostChip(
                      key: LivePk4Stage.seatBoostKey(seat.seat),
                      boost: b,
                      now: now!,
                    ),
                  ),
                if (place case final p?)
                  PositionedDirectional(
                    top: KLivePk4.paneInset,
                    start: KLivePk4.paneInset,
                    child: _PlaceMedal(
                      key: LivePk4Stage.placeKey(seat.seat),
                      place: p,
                    ),
                  ),
                if (onMute != null)
                  PositionedDirectional(
                    top: KLivePk4.paneInset + 22,
                    end: KLivePk4.paneInset,
                    child: Semantics(
                      button: true,
                      toggled: muted,
                      label: muted
                          ? l10n.pk4UnmuteHost(host.displayName)
                          : l10n.pk4MuteHost(host.displayName),
                      excludeSemantics: true,
                      child: InkResponse(
                        key: LivePk4Stage.muteKey(seat.seat),
                        radius: 22,
                        onTap: () => onMute(seat, muted: !muted),
                        child: SizedBox.square(
                          dimension: 40,
                          child: Center(
                            child: Container(
                              width: KLivePk4.muteSize,
                              height: KLivePk4.muteSize,
                              decoration: const BoxDecoration(
                                color: KLivePk4.glass,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                muted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                size: 16,
                                color: white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                PositionedDirectional(
                  start: KLivePk4.paneInset,
                  end: KLivePk4.paneInset,
                  bottom: KLivePk4.paneInset,
                  child: Row(
                    children: [
                      // This host's own score under their pane (the team's
                      // sum is on the bar).
                      Flexible(
                        flex: 2,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: _Glass(
                            key: LivePk4Stage.scoreKey(seat.seat),
                            border: colors[1],
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 12,
                                  color: colors[0],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  KFormat.compact(seat.score, l10n),
                                  textScaler: scaler,
                                  style: t.caption.copyWith(
                                    fontSize: KLivePk4.pillText,
                                    fontWeight: FontWeight.w800,
                                    color: white,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: KSpacing.xxs),
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _Glass(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (muted) ...[
                                  Icon(
                                    Icons.volume_off_rounded,
                                    size: 11,
                                    color: white.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 2),
                                ],
                                Flexible(
                                  child: Text(
                                    host.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textScaler: scaler,
                                    style: t.caption.copyWith(
                                      fontSize: KLivePk4.pillText,
                                      fontWeight: FontWeight.w700,
                                      color: white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _Glass extends StatelessWidget {
  const new({required this.child, super.key, this.border});

  final Widget child;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: KLivePk4.pillHeight),
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs + 1),
    decoration: BoxDecoration(
      color: KLivePk4.glass,
      borderRadius: BorderRadius.circular(KLivePk4.pillHeight / 2),
      border: border == null ? null : Border.all(color: border!),
    ),
    child: Center(widthFactor: 1, heightFactor: 1, child: child),
  );
}

/// The team's booster: its colours, ×N and the seconds left.
class _BoostChip extends StatelessWidget {
  const new({required this.boost, required this.now, super.key});

  final PkActiveBoost boost;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seconds = math.max(0, boost.endsAt.difference(now).inSeconds);
    final colors = KLivePk.boosterColors(boost.kind);
    return Semantics(
      liveRegion: true,
      label: l10n.pkBoostChipSemantics(
        pkBoosterName(l10n, boost.kind),
        '${boost.multiplier}',
        '$seconds',
      ),
      excludeSemantics: true,
      child: Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(KRadius.pill),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            l10n.pkBoostChip('${boost.multiplier}', '${seconds}s'),
            textScaler: TextScaler.noScaling,
            style: context.textStyles.caption.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: KPalette.dark.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Timer extends StatelessWidget {
  const new({required this.left, super.key});

  final Duration left;

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
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          last ? l10n.pkFinalRound(time) : l10n.pkRoundTimer(time),
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
          style: context.textStyles.label.copyWith(
            fontSize: KLivePk.timerText,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: KPalette.dark.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// v1.119-live (D395): a FREE_FOR_ALL pane's place at the end (1st gold with
/// the crown, 2nd silver, 3rd bronze, 4th grey).
class _PlaceMedal extends StatelessWidget {
  const new({required this.place, super.key});

  final int place;

  @override
  Widget build(BuildContext context) {
    final colors = switch (place) {
      1 => Pk4ResultBadge.winFill,
      2 => const [Color(0xFFF1F3F7), Color(0xFFB8BEC9)],
      3 => const [Color(0xFFF2C79A), Color(0xFFC07A3A)],
      _ => const [Color(0xFF8A8D92), Color(0xFF55585E)],
    };
    final ink = place == 1
        ? Pk4ResultBadge.winInk
        : place == 4
        ? KPalette.dark.textPrimary
        : const Color(0xFF2A2A30);
    return Semantics(
      label: context.l10n.pk4PlaceN('$place'),
      excludeSemantics: true,
      child: Container(
        height: KLivePk4.pillHeight + 2,
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(KRadius.pill),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (place == 1) ...[
              const CustomPaint(
                size: Size(13, 11),
                painter: _CrownPainter(color: Color(0xFFB7791F)),
              ),
              const SizedBox(width: 3),
            ],
            Text(
              '#$place',
              textScaler: TextScaler.noScaling,
              style: context.textStyles.caption.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CONNECTED: the four are connected; a host starts it.
class _Connected extends StatelessWidget {
  const new({super.key, this.onStart});

  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xCC1A0A06),
        borderRadius: BorderRadius.circular(KRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.pk4ConnectedHint,
            textAlign: TextAlign.center,
            style: context.textStyles.label.copyWith(
              color: KPalette.dark.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onStart != null) ...[
            const SizedBox(height: KSpacing.sm),
            KButton(label: l10n.pkStart, onPressed: onStart, expand: false),
          ],
        ],
      ),
    );
  }
}

/// A team's top three, rank 1 nearest the seam, ringed in the team colour.
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
        label: l10n.pkSupporters(
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

/// The moderator's void end (or a match that never started).
class _VoidChip extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 22),
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xCC1A0A06), Color(0x991A0A06)]),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(KRadius.md)),
    ),
    child: Center(
      widthFactor: 1,
      heightFactor: 1,
      child: Text(
        context.l10n.pkEndedAdmin,
        maxLines: 1,
        textScaler: MediaQuery.textScalerOf(context)
            .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
        style: context.textStyles.label.copyWith(
          fontWeight: FontWeight.w900,
          color: KPalette.dark.textPrimary,
        ),
      ),
    ),
  );
}

/// v1.119-live (D395, owner «أ»): the 4-way result badge, directly under the
/// scores line — smaller and softer than the 1 v 1 result (whose win / lose
/// / draw animation still plays over the panes): gold with a crown for a
/// win, a calm muted glass for a loss, a soft lavender for a draw. It grows
/// in once (reduced motion: at once); [label] is the room's own result
/// («فاز فريقكم», «المركز الأول» …).
class Pk4ResultBadge extends StatelessWidget {
  const new({required this.result, required this.label, super.key});

  final Pk4Result result;
  final String label;

  static const crownKey = Key('pk4.badge.crown');

  /// Win: gold, ink dark amber; loss: muted glass; draw: soft lavender.
  static const List<Color> winFill = [Color(0xFFFFE9A3), Color(0xFFFFC233)];
  static const List<Color> lossFill = [Color(0xB3303038), Color(0xB31C1C22)];
  static const List<Color> drawFill = [Color(0xCC8E9BE8), Color(0xCC6474D6)];
  static const Color winInk = Color(0xFF5A3A00);

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final (fill, ink, border, icon) = switch (result) {
      Pk4Result.win => (
        winFill,
        winInk,
        const Color(0xFFFFF4CC),
        null as IconData?,
      ),
      Pk4Result.loss => (
        lossFill,
        const Color(0xD9FFFFFF),
        const Color(0x33FFFFFF),
        Icons.sentiment_neutral_rounded,
      ),
      Pk4Result.draw => (
        drawFill,
        const Color(0xFFFFFFFF),
        const Color(0x66FFFFFF),
        Icons.handshake_rounded,
      ),
    };
    final badge = Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        height: KLivePk4.badgeHeight,
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm + 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: fill,
          ),
          borderRadius: BorderRadius.circular(KLivePk4.badgeHeight / 2),
          border: Border.all(color: border),
          boxShadow: result == Pk4Result.win
              ? const [BoxShadow(color: Color(0x55FFB300), blurRadius: 10)]
              : const [BoxShadow(color: Color(0x33000000), blurRadius: 6)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (result == Pk4Result.win)
              const CustomPaint(
                key: crownKey,
                size: Size(KLivePk4.badgeIcon + 2, KLivePk4.badgeIcon),
                painter: _CrownPainter(color: Color(0xFFB7791F)),
              )
            else
              Icon(icon, size: KLivePk4.badgeIcon, color: ink),
            const SizedBox(width: KSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                style: context.textStyles.label.copyWith(
                  fontSize: KLivePk4.badgeText,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (reduced || !LivePkStage.ticks) return badge;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: ((t - 0.6) / 0.4).clamp(0, 1),
        child: Transform.scale(scale: t, child: child),
      ),
      child: badge,
    );
  }
}

/// A small three-point crown (the win badge's mark).
class _CrownPainter extends CustomPainter {
  const new({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.08, h * 0.82)
      ..lineTo(w * 0.02, h * 0.28)
      ..lineTo(w * 0.30, h * 0.52)
      ..lineTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.70, h * 0.52)
      ..lineTo(w * 0.98, h * 0.28)
      ..lineTo(w * 0.92, h * 0.82)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = color)
      ..drawRect(
        Rect.fromLTWH(w * 0.08, h * 0.86, w * 0.84, h * 0.12),
        Paint()..color = color,
      );
    final jewel = Paint()..color = const Color(0xFFFFF4CC);
    for (final x in [0.02, 0.5, 0.98]) {
      canvas.drawCircle(
        Offset(w * x, h * (x == 0.5 ? 0.12 : 0.28)),
        w * 0.07,
        jewel,
      );
    }
  }

  @override
  bool shouldRepaint(_CrownPainter old) => old.color != color;
}

/// v1.119-live (D395, CP-041 §2): FREE_FOR_ALL's four-part bar — one part
/// per host in its colour, its width by its share of the points (a host with
/// none keeps a sliver), the leader first on the reading start, each part
/// with that host's points; a host who left is dimmed.
class Pk4FfaBar extends StatelessWidget {
  const new({required this.match, required this.ownTeam, super.key});

  final Pk4Match match;
  final Pk4Team ownTeam;

  static Key partKey(int seat) => Key('pk4.ffaBar.part.$seat');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ranked = match.ranked;
    final total = ranked.fold(0, (sum, s) => sum + s.score);
    final separator = Directionality.of(context) == TextDirection.rtl
        ? '، '
        : ', ';
    return Semantics(
      label: l10n.pk4FfaScoreSemantics(
        ranked
            .map((s) => '${s.host.displayName} ${KFormat.grouped(s.score)}')
            .join(separator),
      ),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KLivePk4.ffaBarHeight / 2),
          child: SizedBox(
            height: KLivePk4.ffaBarHeight,
            child: Row(
              children: [
                for (final (i, s) in ranked.indexed) ...[
                  if (i > 0) const SizedBox(width: 1.5),
                  Expanded(
                    // An even split while nobody has points; else by share
                    // (at least a sliver so every host stays visible).
                    flex: total == 0
                        ? 100
                        : math.max(18, (s.score * 1000 / total).round()),
                    child: Opacity(
                      opacity: s.out ? 0.45 : 1,
                      child: DecoratedBox(
                        key: partKey(s.seat),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: KLivePk4.colorsOf(match, s, ownTeam),
                          ),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: KSpacing.xxs,
                              ),
                              child: Text(
                                KFormat.compact(s.score, l10n),
                                maxLines: 1,
                                textScaler: TextScaler.noScaling,
                                style: context.textStyles.caption.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: KPalette.dark.textPrimary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x88000000),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a host may do with «جولة أخرى» for four (D395); null for viewers.
class Pk4RematchActions {
  const new({
    required this.onOffer,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
  });

  final Future<void> Function() onOffer;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final Future<void> Function() onCancel;
}

/// v1.119-live (D395, CP-041 §7): «جولة أخرى» for four in the result, in the
/// D238 dock style (the small white card at the bottom of the room), for a
/// host still present (not out of the battle):
///
/// - nothing asked: «العب جولة أخرى مع الجميع؟» and «جولة أخرى»;
/// - this host asked: «بانتظار موافقة N…» with the ring and «إلغاء»;
/// - this host accepted another's offer: «وافقت — بانتظار البقية»;
/// - another host asked: «@A يريد جولة أخرى» with «قبول» / «رفض».
///
/// Every present host must accept; the server decides.
class Pk4RematchDock extends StatefulWidget {
  const new({
    required this.match,
    required this.roomId,
    required this.now,
    required this.actions,
    super.key,
    this.ticks = true,
  });

  final Pk4Match match;
  final String roomId;
  final DateTime Function() now;
  final Pk4RematchActions actions;
  final bool ticks;

  static const offerKey = Key('pk4.rematch.offer');
  static const waitingKey = Key('pk4.rematch.waiting');
  static const cancelKey = Key('pk4.rematch.cancel');
  static const acceptedKey = Key('pk4.rematch.accepted');
  static const promptKey = Key('pk4.rematch.prompt');
  static const acceptKey = Key('pk4.rematch.accept');
  static const declineKey = Key('pk4.rematch.decline');

  /// The answer's full time (PK_REMATCH_ACCEPT_SECONDS default).
  static const int acceptSeconds = 15;

  /// Whether [match] has anything to show to the host of [roomId].
  static bool shows(Pk4Match match, String roomId) {
    final seat = match.seatOf(roomId);
    if (seat == null || seat.out || match.status != PkMatchStatus.result) {
      return false;
    }
    return match.rematch != null || match.canOfferRematch;
  }

  @override
  State<Pk4RematchDock> createState() => _Pk4RematchDockState();
}

class _Pk4RematchDockState extends State<Pk4RematchDock> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.ticks) {
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

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: buildAppTheme(
      brightness: Brightness.light,
      locale: Localizations.localeOf(context),
    ),
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final match = widget.match;
    if (!Pk4RematchDock.shows(match, widget.roomId)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final offer = match.rematch;
    final left = offer == null
        ? 0
        : math.max(0, offer.expiresAt.difference(widget.now()).inSeconds);
    final ink = KLiveDialogCard.inkOf(context);
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final cancel = MaterialLocalizations.of(context).cancelButtonLabel;
    final asker = offer == null ? null : match.seatOf(offer.byRoomId)?.host;
    final (String text, Key key, List<KLiveDialogAction> actions) = switch ((
      offer,
      offer?.acceptedRoomIds.contains(widget.roomId) ?? false,
    )) {
      (null, _) => (
        l10n.pk4RematchAskAll,
        Pk4RematchDock.offerKey,
        [
          KLiveDialogAction(
            key: Pk4RematchDock.offerKey,
            label: l10n.pkRematch,
            primary: true,
            loading: _busy,
            onPressed: () => unawaited(_run(widget.actions.onOffer)),
          ),
        ],
      ),
      (final o?, true) when o.byRoomId == widget.roomId => (
        l10n.pk4RematchWaitingAll('${o.waitingRoomIds.length}'),
        Pk4RematchDock.waitingKey,
        [
          KLiveDialogAction(
            key: Pk4RematchDock.cancelKey,
            label: cancel,
            loading: _busy,
            onPressed: () => unawaited(_run(widget.actions.onCancel)),
          ),
        ],
      ),
      (_, true) => (
        l10n.pk4RematchAccepted,
        Pk4RematchDock.acceptedKey,
        <KLiveDialogAction>[],
      ),
      (_, false) => (
        l10n.pk4RematchOffered(
          KFormat.bidiIsolate('@${asker?.username ?? ''}'),
        ),
        Pk4RematchDock.promptKey,
        [
          KLiveDialogAction(
            key: Pk4RematchDock.acceptKey,
            label: l10n.pkDareAccept,
            primary: true,
            loading: _busy,
            onPressed: () => unawaited(_run(widget.actions.onAccept)),
          ),
          KLiveDialogAction(
            key: Pk4RematchDock.declineKey,
            label: l10n.pkDareRefuse,
            onPressed: _busy
                ? null
                : () => unawaited(_run(widget.actions.onDecline)),
          ),
        ],
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Center(
        child: KLiveDialogCard(
          key: key == Pk4RematchDock.offerKey ? null : key, // gitleaks:allow
          semanticsLabel: text,
          padding: KLiveDialogCard.densePadding,
          dense: true,
          body: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textScaler: scaler,
                  style: context.textStyles.body.copyWith(
                    color: ink,
                    fontSize: PkDareDock.textSize,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
              if (offer != null) ...[
                const SizedBox(width: KSpacing.xs),
                PkDareRing(
                  seconds: left,
                  fraction: left / Pk4RematchDock.acceptSeconds,
                  onCard: true,
                  size: PkDareDock.ring,
                ),
              ],
            ],
          ),
          actions: actions,
        ),
      ),
    );
  }
}
