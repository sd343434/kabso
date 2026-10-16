import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// PK score bar (G-12, DESIGN_SYSTEM §6.2): the host's score is on the
/// **start** side in `pkLeft`, the opponent's on the end side in `pkRight`,
/// so the bar mirrors in Arabic. Fill widths follow the score ratio (50/50
/// at 0–0). Scores are white, ≥ 20 sp / 700 (large text on the PK fills).
/// Below the bar: time left while running, or the [result] when finished.
class KPkScoreBar extends StatelessWidget {
  const new({
    required this.hostScore,
    required this.opponentScore,
    super.key,
    this.timeLeft,
    this.result,
  });

  final int hostScore;
  final int opponentScore;
  final Duration? timeLeft;

  /// Non-null once the battle is over (host's point of view).
  final PkResult? result;

  double get _hostShare {
    final total = hostScore + opponentScore;
    if (total <= 0) return 0.5;
    return (hostScore / total).clamp(
      KMetrics.pkMinShare,
      1 - KMetrics.pkMinShare,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final host = KFormat.grouped(hostScore);
    final opponent = KFormat.grouped(opponentScore);
    final scoreStyle = context.textStyles.title.copyWith(
      fontSize: KMetrics.pkScoreMinFontSize,
      fontWeight: FontWeight.w700,
      height: KMetrics.pkScoreLineHeight,
      color: KPalette.dark.textPrimary,
    );
    final result = this.result;
    final timeLeft = this.timeLeft;

    return Semantics(
      container: true,
      label: l10n.pkScoreSemantics(host, opponent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              height: KMetrics.pkBarHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final hostWidth = constraints.maxWidth * _hostShare;
                  return Row(
                    children: [
                      _Side(
                        width: hostWidth,
                        color: KLiveColors.pkLeft,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          host,
                          style: scoreStyle,
                          textScaler: TextScaler.noScaling,
                        ),
                      ),
                      Expanded(
                        child: _Side(
                          color: KLiveColors.pkRight,
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            opponent,
                            style: scoreStyle,
                            textScaler: TextScaler.noScaling,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: KSpacing.xs),
          if (result != null)
            _ResultChip(result: result)
          else if (timeLeft != null)
            _TimerChip(timeLeft: timeLeft),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const new({
    required this.color,
    required this.alignment,
    required this.child,
    this.width,
  });

  final Color color;
  final AlignmentGeometry alignment;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: KMotion.of(context, KMotion.base),
    curve: KMotion.standard,
    width: width,
    color: color,
    alignment: alignment,
    padding: const EdgeInsetsDirectional.symmetric(horizontal: KSpacing.sm),
    child: FittedBox(fit: BoxFit.scaleDown, child: child),
  );
}

class _TimerChip extends StatelessWidget {
  const new({required this.timeLeft});

  final Duration timeLeft;

  @override
  Widget build(BuildContext context) {
    final white = KPalette.dark.textPrimary;
    // Final 10 s: label switches to bold (no colour change on video).
    final urgent = timeLeft <= KMetrics.pkUrgentThreshold;
    final style = context.textStyles.label.copyWith(
      color: white,
      fontWeight: urgent ? FontWeight.w700 : null,
    );
    return _Pill(
      color: KPalette.dark.scrim,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.timer_outlined,
              size: KMetrics.iconSm,
              color: white,
            ),
          ),
          const SizedBox(width: KSpacing.xs),
          Text(
            context.l10n.pkTimeLeft(KFormat.countdown(timeLeft)),
            style: style,
          ),
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const new({required this.result});

  final PkResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, fill, fg) = switch (result) {
      PkResult.win => (l10n.pkWin, KBrandColors.gold, KStatusColors.onStatus),
      PkResult.lose => (
        l10n.pkLose,
        KPalette.dark.surfaceOverlay,
        KPalette.dark.textPrimary,
      ),
      PkResult.draw => (
        l10n.pkDraw,
        KPalette.dark.surfaceOverlay,
        KPalette.dark.textPrimary,
      ),
    };
    return _Pill(
      color: fill,
      child: Text(
        label,
        style: context.textStyles.label.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const new({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: KSpacing.md,
      vertical: KSpacing.xxs,
    ),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: child,
  );
}
