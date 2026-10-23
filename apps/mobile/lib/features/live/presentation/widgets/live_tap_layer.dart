import 'dart:math' as math;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// CP-012: tapping the live cheers the host. A heart rises where the
/// viewer taps and [onTap] counts it (the session batches and sends taps).
/// Without [onTap] (the host, guests without an account) it is just
/// [child].
class LiveTapLayer extends StatefulWidget {
  const new({required this.child, super.key, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  static const tapKey = Key('live.tapLayer');

  /// Hearts on screen at once; more taps still count.
  static const maxHearts = 14;

  @override
  State<LiveTapLayer> createState() => _LiveTapLayerState();
}

class _Heart {
  new(this.at, this.color, this.controller, this.drift);

  final Offset at;
  final Color color;
  final AnimationController controller;
  final double drift;
}

class _LiveTapLayerState extends State<LiveTapLayer>
    with TickerProviderStateMixin {
  final _hearts = <_Heart>[];
  final _random = math.Random();

  static const _colors = [
    Color(0xFFFF4D7A),
    Color(0xFFFF8AD8),
    Color(0xFFFFA43A),
    Color(0xFF6FE7FF),
    Color(0xFFB65CFF),
  ];

  @override
  void dispose() {
    for (final h in _hearts) {
      h.controller.dispose();
    }
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    widget.onTap?.call();
    if (_hearts.length >= LiveTapLayer.maxHearts) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final heart = _Heart(
      details.localPosition,
      _colors[_random.nextInt(_colors.length)],
      controller,
      (_random.nextDouble() - 0.5) * 40,
    );
    controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _hearts.remove(heart));
          controller.dispose();
        }
      })
      ..forward();
    setState(() => _hearts.add(heart));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return Semantics(
      button: true,
      label: context.l10n.liveTapHint,
      onTap: widget.onTap,
      child: GestureDetector(
        key: LiveTapLayer.tapKey,
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            for (final h in _hearts)
              AnimatedBuilder(
                animation: h.controller,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(h.controller.value);
                  return Positioned(
                    left: h.at.dx - 16 + h.drift * t,
                    top: h.at.dy - 16 - 90 * t,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 1 - h.controller.value,
                        child: Transform.scale(
                          scale: 0.7 + 0.5 * math.sin(math.pi * t / 2),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 32,
                            color: h.color,
                            shadows: const [
                              Shadow(
                                color: KLiveColors.chatScrim,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
