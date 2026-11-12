// v1.136-social (D384): the preview of a freshly made cut-out — the strip's
// frames played in a loop at 12 a second (the first frame only under
// reduced motion), before anything is uploaded.

import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_frames.dart';
import 'package:material_ui/material_ui.dart';

/// Plays the [frames] square frames of [strip] (one under another) in a
/// loop; only the first one when [playing] is false.
class CutoutStripPlayer extends StatefulWidget {
  const new({
    required this.strip,
    required this.frames,
    required this.playing,
    super.key,
  });

  final ui.Image strip;
  final int frames;
  final bool playing;

  @override
  State<CutoutStripPlayer> createState() => _CutoutStripPlayerState();
}

class _CutoutStripPlayerState extends State<CutoutStripPlayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  int _frame = 0;

  void _tick(Duration elapsed) {
    final next =
        (elapsed.inMilliseconds ~/ CutoutLimits.frameMs) % widget.frames;
    if (next != _frame) setState(() => _frame = next);
  }

  void _sync() {
    if (widget.playing && widget.frames > 1) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      _ticker.stop();
      _frame = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(CutoutStripPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _FramePainter(widget.strip, _frame),
    child: const SizedBox.expand(),
  );
}

class _FramePainter extends CustomPainter {
  new(this.strip, this.frame);

  final ui.Image strip;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final side = strip.width.toDouble();
    final s = size.shortestSide;
    canvas.drawImageRect(
      strip,
      Rect.fromLTWH(0, frame * side, side, side),
      Rect.fromLTWH((size.width - s) / 2, size.height - s, s, s),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.frame != frame || old.strip != strip;
}
