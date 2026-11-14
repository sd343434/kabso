// v1.136-social (D384, owner 2026-11-12: «record and pick from the
// gallery»; CONVENTIONS §10.173.2): trimming a picked video to the 3 s the
// animated picture keeps, and the times of its frames (15 a second). Pure
// Dart (unit-tested).

import 'dart:math' as math;

import 'package:kabso_live/features/vip/animated_avatar/cutout_frames.dart';

/// The part of a [durationMs] video kept from [startMs]: at most
/// [CutoutLimits.length] long, never past the end (the start is pulled back
/// when needed, and never below 0).
({int startMs, int lengthMs}) trimWindow(int durationMs, int startMs) {
  final length = math.max(
    0,
    math.min(durationMs, CutoutLimits.length.inMilliseconds),
  );
  final start = math.min(
    math.max(0, startMs),
    math.max(0, durationMs - length),
  );
  return (startMs: start, lengthMs: length);
}

/// The latest start a [durationMs] video allows (0 when it is 3 s or less:
/// the whole clip is kept).
int maxTrimStartMs(int durationMs) =>
    math.max(0, durationMs - CutoutLimits.length.inMilliseconds);

/// The frames' times (ms) in a window from [startMs] of [lengthMs]: one every
/// 1000 / [fps] ms, at most [max]; nothing for an empty window.
List<int> frameTimesMs(
  int startMs,
  int lengthMs, {
  int fps = CutoutLimits.fps,
  int max = CutoutLimits.maxFrames,
}) => [
  for (var i = 0; i < max; i++)
    if (i * 1000 / fps < lengthMs) startMs + (i * 1000 / fps).round(),
];

/// A time as `m:ss.d` (Latin digits), e.g. `0:04.2`.
String trimTimeLabel(int ms) {
  final tenths = (ms / 100).round();
  final minutes = tenths ~/ 600;
  final seconds = (tenths ~/ 10) % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}.${tenths % 10}';
}
