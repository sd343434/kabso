import 'dart:async';
import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/domain/live_pk4.dart';
import 'package:kabso_live/features/live/presentation/widgets/battle_emoji.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_boost_fx.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// «PK رباعي» stage geometry and colours (D71's 2 × 2 layout, wired to the
/// real match — v1.118-live, D391, CP-041 §2 / §8).
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

  /// [KabsoPkBar] fills, outer edge → seam.
  static final List<Color> startFill = startTeam.reversed.toList();
  static final List<Color> endFill = endTeam.reversed.toList();
  static const Color glass = Color(0x66000000);
}

/// The 2 × 2 stage of a 4-way PK (v1.118-live, D391, §10.180): the
/// two-colour [KabsoPkBar] with the TEAM totals (this room's team on the
/// reading start), the round timer under it, the four hosts' panes — this
/// room's team in the start column with this room's host at the top, the
/// opponents in the end column — each with that host's own score under the
/// pane, the team booster chips, the result per team and the top three
/// supporters per team. The hosts' guests are not drawn (CP-041 §8). A host
/// sees one switch per other pane to mute that host for their own room.
/// Everything comes from the server's [match]; [now] is the server clock.
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

  /// This room (its team on the reading start, its host at the top).
  final String roomId;

  /// A host's video (this room's from its own session, the others' from the
  /// 4-way connections), or null: their picture.
  final Widget? Function(Pk4Seat seat) video;

  /// Who speaks now (user ids, the four rooms): their pane glows.
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
  static const timerKey = Key('pk4.timer');
  static const resultKey = Key('pk4.result');
  static const connectedKey = Key('pk4.connected');
  static const announcementKey = Key('pk4.announcement');
  static Key paneKey(int seat) => Key('pk4.pane.$seat');
  static Key scoreKey(int seat) => Key('pk4.score.$seat');
  static Key muteKey(int seat) => Key('pk4.mute.$seat');
  static Key boostKey(Pk4Team team) => Key('pk4.boost.${team.wire}');

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
    final now = (LivePkStage.debugNow ?? widget.now)();
    final battle = match.status == PkMatchStatus.battle;
    final connected = match.status == PkMatchStatus.connected;
    final ended = !battle && !connected;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gridHeight = math.min(
          KLivePk4.maxGridHeight,
          width * KLivePk4.gridAspect,
        );
        Widget column(List<Pk4Seat> seats, List<Color> colors) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, seat) in seats.indexed) ...[
              if (i > 0) const SizedBox(height: KLivePk4.seam),
              Expanded(
                child: _Pane(
                  key: LivePk4Stage.paneKey(seat.seat),
                  seat: seat,
                  video: widget.video(seat),
                  colors: colors,
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
                Expanded(child: column(ownSeats, KLivePk4.startTeam)),
                const SizedBox(width: KLivePk4.seam),
                Expanded(child: column(otherSeats, KLivePk4.endTeam)),
              ],
            ),
            if (battle) ...[
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
            if (ended && match.endReason != PkEndReason.admin) ...[
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
          ],
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  if (ended)
                    Align(
                      alignment: Alignment.topCenter,
                      child: _ResultChip(
                        key: LivePk4Stage.resultKey,
                        match: match,
                        own: own,
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
                      colors: KLivePk4.startTeam,
                      start: true,
                      onTap: widget.onPerson,
                    ),
                  ),
                  Expanded(
                    child: _Supporters(
                      supporters: other.supporters,
                      colors: KLivePk4.endTeam,
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
    required this.seat,
    required this.video,
    required this.colors,
    required this.speaking,
    required this.muted,
    super.key,
    this.onMute,
    this.onTap,
  });

  final Pk4Seat seat;
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

/// The result for this room's team (or the moderator's void end).
class _ResultChip extends StatelessWidget {
  const new({required this.match, required this.own, super.key});

  final Pk4Match match;
  final Pk4TeamState own;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (text, colors) = switch (own.result) {
      _ when match.endReason == PkEndReason.admin => (
        l10n.pkEndedAdmin,
        const [Color(0xCC1A0A06), Color(0x991A0A06)],
      ),
      'WIN' => (l10n.pk4ResultWin, KLivePk4.startFill),
      'LOSS' => (
        l10n.pk4ResultLoss,
        const [Color(0xFF3A3A44), Color(0xFF22222A)],
      ),
      _ => (l10n.pkResultDraw, const [Color(0xFF6B5B95), Color(0xFF3F3567)]),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(KRadius.md),
        ),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          text,
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
