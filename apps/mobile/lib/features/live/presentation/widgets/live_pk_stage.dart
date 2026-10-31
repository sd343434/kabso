import 'dart:async';
import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/presentation/widgets/battle_emoji.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// PK stage geometry and colours (D71 / D73 owner layout, production).
abstract final class KLivePk {
  /// Room above the bar for Kabi and the flames (D73: about 40 lp).
  static const double aboveBar = 36;
  static const double barHeight = 22;
  static const double timerHeight = 20;
  static const double timerWidth = 104;
  static const double seam = 2;
  static const double paneInset = 6;
  static const double pillHeight = 22;
  static const double maxPaneHeight = 374;

  /// Pane height per pane width (the owner's 1 v 1 panes are tall).
  static const double paneAspect = 0.58;
  static const double guest = 34;
  static const double supporterAvatar = 28;
  static const double outcome = 132;

  /// The host's team (Kabso red) on the reading start, the opponents
  /// (blazing orange) on the end (D71); top → bottom, the last is solid.
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
  });

  final PkMatch match;

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

  static const barKey = Key('pk.bar');
  static const timerKey = Key('pk.timer');
  static const ownPaneKey = Key('pk.pane.own');
  static const opponentPaneKey = Key('pk.pane.opponent');
  static const announcementKey = Key('pk.announcement');
  static const resultKey = Key('pk.result');
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
    final now = widget.now();
    final battle = match.status == PkMatchStatus.battle;
    final left = battle ? match.battleEndsAt.difference(now) : Duration.zero;
    final remaining = left.isNegative ? Duration.zero : left;
    final startIsLeft = Directionality.of(context) == TextDirection.ltr;
    final ownWins = match.winnerRoomId == own.roomId;
    final otherWins = match.winnerRoomId == other.roomId;
    final result = battle
        ? null
        : match.winnerRoomId == null
        ? KabsoPkResult.draw
        : (ownWins == startIsLeft)
        ? KabsoPkResult.leftWins
        : KabsoPkResult.rightWins;
    final ownBoost = battle ? own.boostAt(now) : null;
    final otherBoost = battle ? other.boostAt(now) : null;
    final announcement = widget.announcement;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final paneHeight = math.min(
          KLivePk.maxPaneHeight,
          (width - KLivePk.seam) / 2 / KLivePk.paneAspect,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: KLivePk.aboveBar),
            Semantics(
              label: l10n.pkScoreSemantics(
                KFormat.grouped(own.score),
                KFormat.grouped(other.score),
              ),
              excludeSemantics: true,
              child: RepaintBoundary(
                child: KabsoPkBar(
                  key: LivePkStage.barKey,
                  left: startIsLeft ? own.score : other.score,
                  right: startIsLeft ? other.score : own.score,
                  remaining: battle
                      ? Duration(seconds: remaining.inSeconds)
                      : null,
                  result: result,
                  leftColors: startIsLeft ? KLivePk.startFill : KLivePk.endFill,
                  rightColors: startIsLeft
                      ? KLivePk.endFill
                      : KLivePk.startFill,
                  formatScore: KFormat.grouped,
                ),
              ),
            ),
            SizedBox(
              height: paneHeight,
              child: Stack(
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
                          showName: false,
                          stage: widget,
                        ),
                      ),
                      const SizedBox(width: KLivePk.seam),
                      Expanded(
                        child: _Pane(
                          key: LivePkStage.opponentPaneKey,
                          side: other,
                          video: widget.opponentVideo,
                          label: l10n.pkOpponentPane(other.host.displayName),
                          showName: true,
                          muted: own.mutesOpponent,
                          stage: widget,
                        ),
                      ),
                    ],
                  ),
                  // The booster countdown chips hang from each side of the bar.
                  if (ownBoost != null)
                    PositionedDirectional(
                      start: KLivePk.paneInset,
                      top: KLivePk.paneInset,
                      child: _BoostChip(
                        key: LivePkStage.boostChipKey(own.roomId),
                        boost: ownBoost,
                        left: ownBoost.endsAt.difference(now),
                      ),
                    ),
                  if (otherBoost != null)
                    PositionedDirectional(
                      end: KLivePk.paneInset,
                      top: KLivePk.paneInset,
                      child: _BoostChip(
                        key: LivePkStage.boostChipKey(other.roomId),
                        boost: otherBoost,
                        left: otherBoost.endsAt.difference(now),
                      ),
                    ),
                  if (battle)
                    Align(
                      alignment: Alignment.topCenter,
                      child: _RoundTimer(
                        key: LivePkStage.timerKey,
                        left: remaining,
                      ),
                    ),
                  if (!battle) ...[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
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
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
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
                    Align(
                      alignment: Alignment.topCenter,
                      child: _ResultChip(
                        key: LivePkStage.resultKey,
                        match: match,
                        own: own,
                        other: other,
                      ),
                    ),
                  ],
                  if (announcement != null)
                    Align(
                      alignment: const Alignment(0, -0.25),
                      child: _Announcement(
                        key: LivePkStage.announcementKey,
                        announcement: announcement,
                        own: announcement.roomId == own.roomId,
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
    required this.showName,
    required this.stage,
    super.key,
    this.muted = false,
  });

  final PkSide side;
  final Widget? video;
  final String label;
  final bool showName;
  final bool muted;
  final LivePkStage stage;

  @override
  Widget build(BuildContext context) {
    final white = KPalette.dark.textPrimary;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final host = side.host;
    return ClipRect(
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
          if (showName)
            PositionedDirectional(
              end: KLivePk.paneInset,
              top: KLivePk.paneInset + KLivePk.timerHeight + 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Container(
                  height: KLivePk.pillHeight,
                  padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
                  decoration: BoxDecoration(
                    color: KLivePk.glass,
                    borderRadius: BorderRadius.circular(KLivePk.pillHeight / 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (muted) ...[
                        Icon(
                          Icons.volume_off_rounded,
                          size: 13,
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
          if (side.guests.isNotEmpty)
            PositionedDirectional(
              start: KLivePk.paneInset,
              end: KLivePk.paneInset,
              bottom: KLivePk.paneInset,
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

/// A side's booster: ×N and its countdown.
class _BoostChip extends StatelessWidget {
  const new({required this.boost, required this.left, super.key});

  final PkActiveBoost boost;
  final Duration left;

  @override
  Widget build(BuildContext context) {
    final seconds = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
    return Container(
      height: KLivePk.pillHeight,
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: KLivePk.boosterColors(boost.kind)),
        borderRadius: BorderRadius.circular(KLivePk.pillHeight / 2),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFFFF59D)),
          const SizedBox(width: 2),
          Text(
            // Numbers read left to right in Arabic too.
            KFormat.bidiIsolate(
              context.l10n.pkBoostChip(
                '${boost.multiplier}',
                KFormat.countdown(Duration(seconds: seconds)),
              ),
            ),
            textScaler: TextScaler.noScaling,
            style: context.textStyles.caption.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFFFFFFFF),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The battle's time, hanging from the bar on the seam.
class _RoundTimer extends StatelessWidget {
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
          last ? l10n.pkFinalRound(time) : l10n.pkRoundTimer(time),
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
          style: context.textStyles.label.copyWith(
            fontWeight: FontWeight.w800,
            color: KPalette.dark.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
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
            if (reason != null)
              Text(
                reason,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                style: context.textStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// «فعّل فريق X تربل ×5!» over the stage for both rooms.
class _Announcement extends StatelessWidget {
  const new({required this.announcement, required this.own, super.key});

  final PkAnnouncement announcement;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = l10n.pkBoostAnnounce(
      KFormat.bidiIsolate(announcement.teamName),
      pkBoosterName(l10n, announcement.kind),
      // «×5» stays «×5» in Arabic (a left-to-right isolate).
      '\u2066×${announcement.multiplier}\u2069',
    );
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(announcement.serial),
        tween: Tween(begin: 0.6, end: 1),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.md,
            vertical: KSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: KLivePk.boosterColors(announcement.kind),
            ),
            borderRadius: BorderRadius.circular(KRadius.lg),
            border: Border.all(
              color: own ? KLivePk.startTeam[1] : KLivePk.endTeam[1],
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x88000000), blurRadius: 12),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: 22,
                color: Color(0xFFFFF59D),
              ),
              const SizedBox(width: KSpacing.xs),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                  style: context.textStyles.label.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFFFFFF),
                    shadows: const [
                      Shadow(color: Color(0x99000000), blurRadius: 3),
                    ],
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
