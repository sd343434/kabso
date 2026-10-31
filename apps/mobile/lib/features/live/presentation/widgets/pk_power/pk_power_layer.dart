// Kabso Live — places one power banner per team over that team's half of the PK
// screen.
//
// Drop it into the PK screen's Stack ABOVE the battle content (it ignores
// pointers), and feed it from your
// existing PK state:
//
//   PkPowerLayer(
//     left:  state.leftTeam.activePower == null ? null : PkPowerActivation(
//              id: state.leftTeam.activePower!.eventId, teamId:
// state.leftTeam.id, side: PkPowerSide.left,
//              multiplier: state.leftTeam.activePower!.multiplier, endsAt:
// state.leftTeam.activePower!.endsAt),
//     right: …same for the right team…,
//     top: 140,                  // vertical anchor inside the PK area
//   )
//
// Each side is an independent slot: activating on one team never replaces the
// other team's banner.
// When a side becomes null (or the power expires) its banner plays the exit
// animation, then is removed.

import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_banner.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_models.dart';
import 'package:material_ui/material_ui.dart';

class PkPowerLayer extends StatefulWidget {
  const new({
    super.key,
    this.left,
    this.right,
    this.top = 140,
    this.widthFactor = .62,
    this.stackGap = .9,
    this.centred = false,
  });

  final PkPowerActivation? left;
  final PkPowerActivation? right;

  /// Distance from the top of the layer to the first banner.
  final double top;

  /// Banner width as a fraction of the layer width (each banner sits on its own
  /// team's side).
  final double widthFactor;

  /// When both teams are active, the right team's banner is shifted down by
  /// this × banner height so they never overlap.
  final double stackGap;

  /// Kabso (D199, owner «بنفس المكان … وبنفس الحجم»): every banner centred
  /// across both halves (the old announcement pill's place); with two
  /// boosted teams the right one sits under the left one.
  final bool centred;

  @override
  State<PkPowerLayer> createState() => _PkPowerLayerState();
}

class _Slot {
  new(this.activation);
  PkPowerActivation activation;
  bool exiting = false;
}

class _PkPowerLayerState extends State<PkPowerLayer> {
  final Map<PkPowerSide, _Slot> _slots = {};

  @override
  void initState() {
    super.initState();
    _sync(PkPowerSide.left, widget.left);
    _sync(PkPowerSide.right, widget.right);
  }

  @override
  void didUpdateWidget(covariant PkPowerLayer old) {
    super.didUpdateWidget(old);
    _sync(PkPowerSide.left, widget.left);
    _sync(PkPowerSide.right, widget.right);
  }

  void _sync(PkPowerSide side, PkPowerActivation? a) {
    assert(
      a == null || a.side == side,
      'PkPowerActivation.side must match the slot it is passed to',
    );
    final slot = _slots[side];
    if (a == null) {
      slot?.exiting = true; // play exit, removed in onExited
    } else if (slot == null || slot.activation.id != a.id) {
      _slots[side] = _Slot(a); // new activation for this team only
    } else {
      slot
        ..activation =
            // same activation: update data (e.g. extended endsAt), keep
            // animation running
            a
        ..exiting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_slots.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth * widget.widthFactor;
        final both = _slots.length == 2;
        // the left team's banner height decides how far the right one is pushed
        // down (tiers have different art)
        final leftSlot = _slots[PkPowerSide.left];
        final h =
            w *
            PkPowerTheme.of((leftSlot ?? _slots.values.first).activation.tier)
                .geometry
                .aspect;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // brief electrical pulse on the activating team's screen edge
            // (TRIPLE+). Thin, translucent, ignores touches.
            for (final e in _slots.entries)
              if (PkPowerTheme.of(e.value.activation.tier).fx.edgePulse > 0)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: e.key == PkPowerSide.left ? 0 : null,
                  right: e.key == PkPowerSide.right ? 0 : null,
                  width: 26,
                  child: _EdgePulse(
                    key: ValueKey(
                      'pk-edge-${e.key.name}-${e.value.activation.id}',
                    ),
                    side: e.key,
                    theme: PkPowerTheme.of(e.value.activation.tier),
                  ),
                ),
            for (final e in _slots.entries)
              Positioned(
                top:
                    widget.top +
                    (both && e.key == PkPowerSide.right
                        ? h * widget.stackGap
                        : 0),
                left: widget.centred
                    ? (c.maxWidth - w) / 2
                    : (e.key == PkPowerSide.left ? 0 : null),
                right: !widget.centred && e.key == PkPowerSide.right ? 0 : null,
                child: PkPowerBanner(
                  key: ValueKey(
                    'pk-power-${e.key.name}-${e.value.activation.id}',
                  ),
                  activation: e.value.activation,
                  width: w,
                  exiting: e.value.exiting,
                  onExited: () {
                    if (!mounted) return;
                    final cur = _slots[e.key];
                    if (cur != null &&
                        cur.activation.id == e.value.activation.id) {
                      setState(() => _slots.remove(e.key));
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Plays once per activation (keyed by id): a short violet electric pulse
/// hugging the team's screen edge.
class _EdgePulse extends StatefulWidget {
  const new({required this.side, required this.theme, super.key});
  final PkPowerSide side;
  final PkPowerTheme theme;

  @override
  State<_EdgePulse> createState() => _EdgePulseState();
}

class _EdgePulseState extends State<_EdgePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.theme.fx.rainbow ? 1300 : 1000),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            // 150 ms delay, quick rise, flicker, fade by 1 s
            final t = _c.value * 1000;
            final env = t < 150
                ? 0.0
                : (t < 300 ? (t - 150) / 150 : (1 - (t - 300) / 700)).clamp(
                    0.0,
                    1.0,
                  );
            final flick = .75 + .25 * ((t ~/ 45).isEven ? 1 : -1);
            final a = env * flick * widget.theme.fx.edgePulse;
            if (a <= 0) return const SizedBox.shrink();
            final left = widget.side == PkPowerSide.left;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: left ? Alignment.centerLeft : Alignment.centerRight,
                  end: left ? Alignment.centerRight : Alignment.centerLeft,
                  colors: [
                    widget.theme.highlight.pkAlpha(.75 * a),
                    widget.theme.amber.pkAlpha(.55 * a),
                    widget.theme.orange.pkAlpha(0),
                  ],
                  stops: const [0, .25, 1],
                ),
              ),
              // ultimate tier: a multicolour wave travelling along the edge on
              // top of the pulse
              child: widget.theme.fx.rainbow
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            for (var k = 0; k <= 6; k++)
                              HSVColor.fromAHSV(
                                1,
                                (k * 60 + t * .4) % 360,
                                .9,
                                1,
                              ).toColor().pkAlpha(.7 * a),
                          ],
                        ),
                      ),
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }
}
