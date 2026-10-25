import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// CP-012: tapping the live cheers the host, and [onTap] counts it (the
/// session batches and sends taps). D101 (owner's tap pack): each tap pops
/// one of the Kabi characters at the finger, which floats up with a sway and
/// fades; only the tiers the host's charm level has reached ([maxTier], 1–10)
/// take turns. Every 10th tap of a combo is a big pop with a ring of
/// sparkles. Without [onTap] (the host, guests without an account) it is
/// just [child].
class LiveTapLayer extends StatefulWidget {
  const new({required this.child, super.key, this.onTap, this.maxTier = 1});

  final Widget child;
  final VoidCallback? onTap;

  /// The highest charm tier the host has reached (the room level's tier).
  final int maxTier;

  static const tapKey = Key('live.tapLayer');

  /// Characters on screen at once (smooth on low-end phones); more taps
  /// still count.
  static const maxCharacters = 36;

  /// A pause longer than this starts a new combo.
  static const comboTimeout = Duration(milliseconds: 900);

  /// The character's size; a big pop is 1.7 ×.
  static const size = 38.0;

  @override
  State<LiveTapLayer> createState() => _LiveTapLayerState();
}

class _Pop {
  new({
    required this.at,
    required this.tier,
    required this.controller,
    required this.size,
    required this.rise,
    required this.sway,
    required this.phase,
    required this.spin,
    required this.big,
  });

  final Offset at;
  final CharmTier tier;
  final AnimationController controller;
  final double size;
  final double rise;
  final double sway;
  final double phase;
  final double spin;
  final bool big;
}

class _LiveTapLayerState extends State<LiveTapLayer>
    with TickerProviderStateMixin {
  final _pops = <_Pop>[];
  final _random = math.Random();
  int _turn = 0;
  int _combo = 0;
  DateTime _last = DateTime(0);
  Offset? _comboAt;

  int get _tiers => widget.maxTier.clamp(1, CharmTier.values.length);

  @override
  void dispose() {
    for (final p in _pops) {
      p.controller.dispose();
    }
    super.dispose();
  }

  void _onTapUp(TapUpDetails details) {
    widget.onTap?.call();
    final now = clock.now();
    _combo = now.difference(_last) > LiveTapLayer.comboTimeout ? 1 : _combo + 1;
    _last = now;
    _comboAt = details.localPosition;
    final big = _combo % 10 == 0;
    unawaited(
      big ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick(),
    );
    if (_pops.length >= LiveTapLayer.maxCharacters) {
      _pops.removeAt(0).controller.dispose();
    }
    final controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: big ? 1700 : 1300 + _random.nextInt(500),
      ),
    );
    final pop = _Pop(
      at: details.localPosition,
      // The big pop shows the host's highest tier; the others take turns.
      tier: CharmTier.values[big ? _tiers - 1 : _turn++ % _tiers],
      controller: controller,
      size: LiveTapLayer.size * (big ? 1.7 : 0.85 + _random.nextDouble() * 0.3),
      rise: 220 + _random.nextDouble() * 120,
      sway: 14 + _random.nextDouble() * 22,
      phase: _random.nextDouble() * math.pi * 2,
      spin: (_random.nextDouble() - 0.5) * 0.5,
      big: big,
    );
    controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _pops.remove(pop));
          controller.dispose();
        }
      })
      ..forward();
    setState(() => _pops.add(pop));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    final comboAt = _comboAt;
    // A tap counts when the finger lifts and nothing above took it (a seat,
    // a button, the chat), so pressing those never cheers as well.
    return GestureDetector(
      key: LiveTapLayer.tapKey,
      behavior: HitTestBehavior.opaque,
      onTapUp: _onTapUp,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Screen readers get one "tap to cheer" item, not the whole room
          // as a single button.
          Positioned.fill(
            child: Semantics(
              button: true,
              label: context.l10n.liveTapHint,
              onTap: widget.onTap,
              child: const SizedBox.expand(),
            ),
          ),
          widget.child,
          IgnorePointer(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final p in _pops) LiveTapCharacter._(p, key: ObjectKey(p)),
                if (comboAt != null && _combo > 1 && _pops.isNotEmpty)
                  _ComboLabel(
                    key: ValueKey(_combo),
                    at: comboAt,
                    combo: _combo,
                    color: CharmTier.values[(_combo ~/ 10) % _tiers].pillEnd,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tap character: an elastic pop at the finger (the first 18 %), then
/// it rises with a sine sway, shrinks a little and fades in the last 30 %.
class LiveTapCharacter extends StatelessWidget {
  const new _(this._pop, {super.key});

  final _Pop _pop;

  @override
  Widget build(BuildContext context) {
    final p = _pop;
    return AnimatedBuilder(
      animation: p.controller,
      builder: (context, _) {
        final t = p.controller.value;
        final pop = t < 0.18 ? Curves.elasticOut.transform(t / 0.18) : 1.0;
        final r = Curves.easeOut.transform(((t - 0.12) / 0.88).clamp(0, 1));
        final dx = math.sin(p.phase + r * math.pi * 2.2) * p.sway * r;
        final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
        final s = p.size;
        return Positioned(
          left: p.at.dx - s / 2 + dx,
          top: p.at.dy - s / 2 - p.rise * r,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: p.spin * r + (t < 0.18 ? (1 - t / 0.18) * -0.4 : 0),
              child: Transform.scale(
                scale: pop * (1 - 0.3 * r),
                child: SizedBox.square(
                  dimension: s,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (p.big) _Ring(t: t, color: p.tier.pillEnd, size: s),
                      Image.asset(
                        p.tier.tap,
                        width: s,
                        height: s,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The big pop's ring and eight sparkles, spreading out and fading.
class _Ring extends StatelessWidget {
  const new({required this.t, required this.color, required this.size});

  final double t;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final k = Curves.easeOut.transform((t / 0.45).clamp(0, 1));
    final fade = 1 - k;
    final ring = size * (0.6 + 1.2 * k);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: ring,
          height: ring,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: fade), width: 3),
          ),
        ),
        for (var j = 0; j < 8; j++)
          Transform.translate(
            offset: Offset(
              math.cos(j * math.pi / 4) * size * (0.3 + 0.75 * k),
              math.sin(j * math.pi / 4) * size * (0.3 + 0.75 * k),
            ),
            child: Opacity(
              opacity: fade,
              child: Icon(
                j.isEven ? Icons.auto_awesome : Icons.favorite,
                size: size * 0.26,
                color: j.isEven ? Colors.white : color,
              ),
            ),
          ),
      ],
    );
  }
}

/// "x12" next to the finger while a combo runs; it springs in on every tap
/// and fades once the combo times out.
class _ComboLabel extends StatefulWidget {
  const new({
    required this.at,
    required this.combo,
    required this.color,
    super.key,
  });

  final Offset at;
  final int combo;
  final Color color;

  @override
  State<_ComboLabel> createState() => _ComboLabelState();
}

class _ComboLabelState extends State<_ComboLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: LiveTapLayer.comboTimeout + const Duration(milliseconds: 400),
  )..forward();

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: widget.at.dx + 18,
    top: widget.at.dy - 54,
    child: AnimatedBuilder(
      animation: _spring,
      builder: (context, child) {
        // The first 320 ms spring in; after the combo timeout it fades.
        final total = _spring.duration!.inMilliseconds;
        final ms = _spring.value * total;
        final t = Curves.elasticOut.transform((ms / 320).clamp(0, 1));
        final idle = LiveTapLayer.comboTimeout.inMilliseconds;
        final fade = ms <= idle ? 1.0 : (1 - (ms - idle) / 400).clamp(0.0, 1.0);
        return Opacity(
          opacity: fade,
          child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
        );
      },
      child: Text(
        'x${widget.combo}',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: widget.combo % 10 == 0 ? 26 : 20,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: Colors.white,
          shadows: [
            Shadow(color: widget.color, blurRadius: 12),
            const Shadow(
              color: Colors.black54,
              offset: Offset(0, 2),
              blurRadius: 3,
            ),
          ],
        ),
      ),
    ),
  );
}
