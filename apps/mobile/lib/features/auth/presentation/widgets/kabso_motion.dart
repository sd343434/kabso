import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Timing helpers of the owner's animated auth screens (welcome, join,
/// login; D64/D65), taken from the owner's files.

/// 0→1 progress of a one-shot animation starting at [delay] seconds.
double motionProgress(
  double t,
  double delay,
  double dur, [
  Curve c = Curves.easeOutCubic,
]) => c.transform(((t - delay) / dur).clamp(0.0, 1.0));

/// 0→1 position inside a repeating loop of [period] seconds.
double motionLoop(double t, double period, [double delay = 0]) =>
    t < delay ? 0 : ((t - delay) % period) / period;

/// Smooth 0→1→0 over one loop.
double motionWave(double u) => 0.5 - 0.5 * math.cos(2 * math.pi * u);

/// Keyframe interpolation (like CSS @keyframes).
double motionKeyframes(
  double u,
  List<double> at,
  List<double> v, [
  Curve c = Curves.easeInOut,
]) {
  if (u <= at.first) return v.first;
  for (var i = 0; i < at.length - 1; i++) {
    if (u <= at[i + 1]) {
      final k = c.transform((u - at[i]) / (at[i + 1] - at[i]));
      return v[i] + (v[i + 1] - v[i]) * k;
    }
  }
  return v.last;
}

double degrees(double d) => d * math.pi / 180;

/// A clock for those screens: seconds since the screen appeared, in
/// [time]. It runs for [motionSeconds] and then rests (battery; it also
/// lets tests settle); with reduced motion it never runs and shows
/// [restSeconds], a moment after every entrance has finished.
mixin MotionClock<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  final ValueNotifier<double> time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_tick);
  var _started = false;

  double get motionSeconds;
  double get restSeconds;

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    if (t >= motionSeconds) {
      time.value = motionSeconds;
      _ticker.stop();
    } else {
      time.value = t;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      time.value = restSeconds;
    } else {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    time.dispose();
    super.dispose();
  }
}

/// Fade-up entrance at [delay] seconds of [time]; [child] is not rebuilt
/// every frame.
class MotionRise extends StatelessWidget {
  const new({
    required this.time,
    required this.delay,
    required this.child,
    super.key,
    this.distance = 28,
  });

  final ValueListenable<double> time;
  final double delay;
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: time,
    child: child,
    builder: (_, t, c) {
      final p = motionProgress(t, delay, .6);
      return Opacity(
        opacity: p,
        child: Transform.translate(
          offset: Offset(0, distance * (1 - p)),
          child: c,
        ),
      );
    },
  );
}

/// Reports [height] as its intrinsic height, so a column sized with
/// `IntrinsicHeight` scrolls only when the rest no longer fits; the child
/// (a flexible illustration) takes whatever space is left.
class FixedIntrinsicHeight extends SingleChildRenderObjectWidget {
  const new({required this.height, super.key, super.child});

  final double height;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderFixedIntrinsicHeight(height);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderFixedIntrinsicHeight renderObject,
  ) => renderObject.height = height;
}

class RenderFixedIntrinsicHeight extends RenderProxyBox {
  new(this._height);

  double _height;
  double get height => _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;
}
