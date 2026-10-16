import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Multi-guest seats: a `KMetrics.guestSeatColumns`-column grid of 3:4 seat
/// tiles in reading order (the first seat at the start). A `null` seat is
/// open; it is not a button, because there is no request-to-join API.
///
/// **Fixture-only**: there is no multi-guest API, so no production screen
/// builds it. It goes in `KLiveRoomScaffold.stage`.
class KGuestSeatGrid extends StatelessWidget {
  const new({required this.seats, super.key});

  final List<GuestSeatData?> seats;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const columns = KMetrics.guestSeatColumns;
      const gap = KSpacing.xxs;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final seat in seats)
            SizedBox(
              width: width,
              height: width / KMetrics.guestSeatAspect,
              child: seat == null ? const _OpenSeat() : _Seat(seat: seat),
            ),
        ],
      );
    },
  );
}

class _Seat extends StatelessWidget {
  const new({required this.seat});

  final GuestSeatData seat;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    final l10n = context.l10n;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final style = context.textStyles.caption.copyWith(
      color: p.textPrimary,
      fontWeight: FontWeight.w600,
    );
    return Semantics(
      container: true,
      label: seat.muted ? l10n.multiGuestMicOff(seat.name) : seat.name,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KRadius.sm),
          child: Stack(
            fit: StackFit.expand,
            children: [
              seat.video ??
                  ColoredBox(
                    color: p.surfaceRaised,
                    child: Center(
                      child: KAvatar(name: seat.name, image: seat.avatar),
                    ),
                  ),
              if (seat.isHost)
                PositionedDirectional(
                  top: KSpacing.xs,
                  start: KSpacing.xs,
                  child: _Tag(
                    color: p.primary,
                    child: Text(
                      l10n.multiGuestHost,
                      textScaler: scaler,
                      style: style.copyWith(color: p.onPrimary),
                    ),
                  ),
                ),
              PositionedDirectional(
                start: KSpacing.xs,
                end: KSpacing.xs,
                bottom: KSpacing.xs,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _Tag(
                    color: p.scrim,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (seat.muted) ...[
                          Icon(
                            Icons.mic_off_rounded,
                            size: KMetrics.iconXs,
                            color: p.textPrimary,
                          ),
                          const SizedBox(width: KSpacing.xxs),
                        ],
                        Flexible(
                          child: Text(
                            seat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textScaler: scaler,
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
        ),
      ),
    );
  }
}

class _OpenSeat extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    final label = context.l10n.multiGuestOpenSeat;
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.scrim,
            borderRadius: BorderRadius.circular(KRadius.sm),
            border: Border.all(color: p.border),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event_seat_outlined,
                  size: KMetrics.iconMd,
                  color: p.textPrimary,
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                  style: context.textStyles.caption.copyWith(
                    color: p.textPrimary,
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

class _Tag extends StatelessWidget {
  const new({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: KSpacing.xs,
      vertical: KSpacing.xxs,
    ),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: child,
  );
}
