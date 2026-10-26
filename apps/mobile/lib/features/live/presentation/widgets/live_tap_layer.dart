import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// CP-012: tapping the live cheers the host, and [onTap] counts it (the
/// session batches and sends taps). The owner's tap pack (D101): each tap
/// pops one of the Kabi characters, which floats up with a small sway and
/// fades. D120 (owner): the characters do not fly where the finger is: they
/// all rise in one narrow lane at the **physical right** edge near the
/// bottom ([lane]; right in Arabic and English alike), like the hearts lane
/// of other live apps, at half the old size. Every tap picks one of **all ten**
/// characters at random, whatever the host's charm level (never the same one
/// twice in a row, so a run of taps always mixes). Every 10th tap of a combo
/// is a big pop with a ring of sparkles. The host taps their own live too
/// (D120). Without [onTap] (guests without an account, an ended live) it is
/// just [child].
///
/// A tap counts only where nothing above took it: seats, buttons, the chat
/// and person cards keep their own taps (the inner gesture wins the arena).
class LiveTapLayer extends StatefulWidget {
  const new({
    required this.child,
    super.key,
    this.onTap,
    this.random,
    this.laneBottomInset = 72,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// How far above the layer's bottom safe edge the lane starts: just above
  /// the screen's bottom bar or chat input (each screen passes its own).
  final double laneBottomInset;

  /// The source of the characters' picks and motion (tests seed it).
  final math.Random? random;

  static const tapKey = Key('live.tapLayer');

  /// Characters on screen at once (smooth on low-end phones); more taps
  /// still count.
  static const maxCharacters = 36;

  /// A pause longer than this starts a new combo.
  static const comboTimeout = Duration(milliseconds: 900);

  /// The character's size (D120: half of the first 38); a big pop is 1.7 ×.
  static const size = 19.0;

  /// The size of the 10th tap's big pop.
  static const double bigSize = size * 1.7;

  /// D120: the lane's width and its inset from the physical right edge.
  static const laneWidth = 72.0;
  static const laneRightInset = 12.0;

  /// How high a character rises (from its start) at most.
  static const maxRise = 260.0;

  /// The lane every character starts and rises in, for a layer of [size]
  /// whose lane bottom is [bottom] above the layer's bottom edge.
  static Rect lane(Size size, double bottom) {
    final right = size.width - laneRightInset;
    final lower = size.height - bottom;
    return Rect.fromLTRB(
      right - laneWidth,
      lower - maxRise - bigSize,
      right,
      lower,
    );
  }

  /// Sideways sway of a character at most (it stays in the lane).
  static const maxSway = 5.0;

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
  late final math.Random _random = widget.random ?? math.Random();
  CharmTier? _lastTier;
  int _combo = 0;
  DateTime _last = DateTime(0);
  Rect? _lane;

  /// D120: any of the ten characters, not the one just shown.
  CharmTier _pick() {
    const all = CharmTier.values;
    final last = _lastTier;
    var tier = all[_random.nextInt(last == null ? all.length : all.length - 1)];
    if (last != null && tier.index >= last.index) tier = all[tier.index + 1];
    return _lastTier = tier;
  }

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
    final size = context.size ?? Size.zero;
    final lane = _lane = LiveTapLayer.lane(
      size,
      widget.laneBottomInset + MediaQuery.paddingOf(context).bottom,
    );
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
    final s = big
        ? LiveTapLayer.bigSize
        : LiveTapLayer.size * (0.85 + _random.nextDouble() * 0.3);
    final sway = big ? 0.0 : 2 + _random.nextDouble() * 3;
    // The start: the lane's bottom, with a little sideways jitter that keeps
    // the character (even at its elastic overshoot) and its sway in the lane;
    // the big pop starts in the middle so its ring fits.
    final room = math.max(0, lane.width / 2 - s * 0.7 - sway);
    final x =
        lane.center.dx + (big ? 0 : (_random.nextDouble() * 2 - 1) * room);
    final pop = _Pop(
      at: Offset(x, lane.bottom - LiveTapLayer.bigSize / 2),
      tier: _pick(),
      controller: controller,
      size: s,
      rise: 200 + _random.nextDouble() * 60,
      sway: sway,
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
    final lane = _lane;
    // A tap counts when the finger lifts and nothing above took it (a seat,
    // a button, the chat), so pressing those never cheers as well.
    return GestureDetector(
      key: LiveTapLayer.tapKey,
      behavior: HitTestBehavior.opaque,
      // Screen readers use the one "tap to cheer" item below; a tap action
      // here would pull every label of the room into one node.
      excludeFromSemantics: true,
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
                if (lane != null && _combo > 1 && _pops.isNotEmpty)
                  _ComboLabel(
                    key: ValueKey(_combo),
                    lane: lane,
                    combo: _combo,
                    color: _pops.last.tier.pillEnd,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tap character: an elastic pop at the lane's start (the first 18 %),
/// then it rises in the lane with a small sine sway, shrinks a little and
/// fades in the last 30 %.
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
            border: Border.all(
              color: color.withValues(alpha: fade),
              width: size * 0.08,
            ),
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

/// "x12" beside the lane's start while a combo runs; it springs in on every
/// tap and fades once the combo times out.
class _ComboLabel extends StatefulWidget {
  const new({
    required this.lane,
    required this.combo,
    required this.color,
    super.key,
  });

  /// The tap lane ([LiveTapLayer.lane]): the label sits just left of it.
  final Rect lane;
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

  static const _width = 64.0;

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: widget.lane.left - _width - 2,
    width: _width,
    top: widget.lane.bottom - LiveTapLayer.bigSize - 24,
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
          child: Transform.scale(
            scale: 0.6 + 0.4 * t,
            alignment: Alignment.centerRight,
            child: child,
          ),
        );
      },
      child: Text(
        'x${widget.combo}',
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: widget.combo % 10 == 0 ? 20 : 16,
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
