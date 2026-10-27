import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D129: the hub's top-level filter, "voice rooms · live" (غرف صوتية ·
/// بث حي), under the top bar and above the Following · Popular · New tabs.
/// It applies to every tab (the server filters, `kind`); the category chips
/// and the banner after the 4th card work inside the filtered list.
///
/// Two equal halves of a pill track (`surfaceOverlay`), the selected one
/// filled `primary`; voice rooms first in the reading order. Each half is a
/// 48 pt touch target, announced as a selected/unselected button of one
/// group; the labels grow with the text scale up to
/// [KMetrics.topBarMaxTextScale] and are cut with an ellipsis after that.
class LiveHubKindSwitch extends StatelessWidget {
  const new({required this.selected, required this.onSelected, super.key});

  final LiveRoomsKind selected;
  final ValueChanged<LiveRoomsKind> onSelected;

  static Key segmentKey(LiveRoomsKind kind) => Key('liveHub.kind.${kind.wire}');

  /// The row's height: one touch target.
  static const double height = KSizes.minTouchTarget;

  /// The visible track inside the row (4 pt above and below).
  static const double trackInset = KSpacing.xs;
  static const double thumbInset = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.topBarMaxTextScale);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KLiveGrid.inset),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                top: trackInset,
                bottom: trackInset,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.surfaceOverlay,
                    borderRadius: BorderRadius.circular(KRadius.pill),
                  ),
                ),
              ),
              Semantics(
                container: true,
                explicitChildNodes: true,
                label: l10n.liveHubKindLabel,
                child: Row(
                  // Each half takes the whole 48 pt row (its touch target).
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final kind in LiveRoomsKind.values)
                      Expanded(
                        child: _Segment(
                          key: segmentKey(kind),
                          kind: kind,
                          selected: kind == selected,
                          onTap: () => onSelected(kind),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const new({
    required this.kind,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final LiveRoomsKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final label = switch (kind) {
      LiveRoomsKind.audio => l10n.liveHubKindAudio,
      LiveRoomsKind.video => l10n.liveHubKindVideo,
    };
    final color = selected ? p.onPrimary : p.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical:
                LiveHubKindSwitch.trackInset + LiveHubKindSwitch.thumbInset,
            horizontal: LiveHubKindSwitch.thumbInset,
          ),
          child: AnimatedContainer(
            duration: KMotion.of(context, KMotion.fast),
            curve: KMotion.standard,
            decoration: BoxDecoration(
              color: selected ? p.primary : p.primary.withAlpha(0),
              borderRadius: BorderRadius.circular(KRadius.pill),
            ),
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(
                  switch (kind) {
                    LiveRoomsKind.audio => AppIcons.mic,
                    LiveRoomsKind.video => AppIcons.liveTv,
                  },
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: KSpacing.xs + 2),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.label.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
