import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_score_bar.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// PK split screen (owner decision D36, HOME_LIVE_LAYOUT_DECISIONS §3
/// HL-L8, VG-37–39): the score bar, then two 3:4 panes side by side, the
/// host at the **start** and the opponent at the end (so the panes, the bar
/// and the supporter rows mirror in Arabic), the timer and a Kabso VS mark
/// centred on the seam, a per-pane result once the battle is over and the
/// top supporters under each pane.
///
/// **Fixture-only**: there is no PK API, so no production screen builds it.
/// It goes in `KLiveRoomScaffold.stage`.
class KPkLayout extends StatelessWidget {
  const new({
    required this.host,
    required this.opponent,
    super.key,
    this.timeLeft,
    this.result,
  });

  final PkSideData host;
  final PkSideData opponent;

  /// Time left while the battle runs.
  final Duration? timeLeft;

  /// Host's point of view; the opponent pane shows the inverse.
  final PkResult? result;

  static PkResult? _inverse(PkResult? r) => switch (r) {
    PkResult.win => PkResult.lose,
    PkResult.lose => PkResult.win,
    PkResult.draw => PkResult.draw,
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final timeLeft = this.timeLeft;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KPkScoreBar(
          hostScore: host.score,
          opponentScore: opponent.score,
          showStatus: false,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final paneWidth = constraints.maxWidth / 2;
            return SizedBox(
              height: paneWidth / KMetrics.pkPaneAspect,
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _Pane(side: host, result: result),
                      ),
                      Expanded(
                        child: _Pane(side: opponent, result: _inverse(result)),
                      ),
                    ],
                  ),
                  if (timeLeft != null && result == null)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: KSpacing.sm),
                        child: KPkTimerChip(
                          timeLeft: timeLeft,
                          urgentTint: true,
                        ),
                      ),
                    ),
                  const Center(child: _VsMark()),
                ],
              ),
            );
          },
        ),
        if (host.supporters.isNotEmpty || opponent.supporters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: _Supporters(
                    names: host.supporters,
                    alignment: AlignmentDirectional.centerStart,
                  ),
                ),
                Expanded(
                  child: _Supporters(
                    names: opponent.supporters,
                    alignment: AlignmentDirectional.centerEnd,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Pane extends StatelessWidget {
  const new({required this.side, this.result});

  final PkSideData side;
  final PkResult? result;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    final result = this.result;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          side.video ??
              KRoomCameraOff(hostName: side.name, avatar: side.avatar),
          PositionedDirectional(
            start: KSpacing.xs,
            bottom: KSpacing.xs,
            end: KSpacing.xs,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: KSpacing.sm,
                  vertical: KSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: p.scrim,
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Text(
                  side.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                  style: context.textStyles.caption.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (result != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: KSpacing.xxxl * 2),
                child: KPkResultChip(result: result),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kabso's own VS mark: a small `primary` disc with "VS" on the seam.
class _VsMark extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    return ExcludeSemantics(
      child: Container(
        width: KMetrics.pkVsMark,
        height: KMetrics.pkVsMark,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.primary,
          shape: BoxShape.circle,
          border: Border.all(color: p.textPrimary, width: KMetrics.thinStroke),
        ),
        child: Text(
          context.l10n.pkVersus,
          textScaler: TextScaler.noScaling,
          style: context.textStyles.label.copyWith(
            color: p.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Supporters extends StatelessWidget {
  const new({required this.names, required this.alignment});

  final List<String> names;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final shown = names.take(KMetrics.viewerStripMax).toList();
    final separator = Directionality.of(context) == TextDirection.rtl
        ? '، '
        : ', ';
    return Align(
      alignment: alignment,
      child: Semantics(
        label: context.l10n.pkSupporters(shown.join(separator)),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final name in shown)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: KSpacing.xs),
                  child: KAvatar(name: name, size: KMetrics.pkSupporterAvatar),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
