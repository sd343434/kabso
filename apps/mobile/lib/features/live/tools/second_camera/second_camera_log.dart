import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';

/// D251: the second camera's state log, copied from its screen with
/// «نسخ سجل التشخيص» and pasted to support.
///
/// The app has no crash reporting and its logger is off in release builds,
/// so this is what an owner can send after a problem on the second phone.
/// It holds only event names, durations, states and error **types** — never
/// the pairing code, a token, a room or user id, a name or an error's text.
class SecondCameraLog {
  new({DateTime Function()? now, this.capacity = 200})
    : _now = now ?? DateTime.now {
    _start = _now();
  }

  final DateTime Function() _now;
  late final DateTime _start;

  /// How many lines are kept (the oldest go first).
  final int capacity;

  final List<String> _lines = [];

  /// The lines kept, oldest first (`+<ms> <event> <detail>`).
  List<String> get lines => List.unmodifiable(_lines);

  /// Adds [event] (a fixed name) with an optional [detail] (states, numbers,
  /// type names — never free text from a server or the person).
  void add(String event, [String? detail]) {
    final ms = _now().difference(_start).inMilliseconds;
    _lines.add(detail == null ? '+$ms $event' : '+$ms $event $detail');
    if (_lines.length > capacity) _lines.removeAt(0);
  }

  /// The text to copy: a header with [facts] (fixed keys and states) and the
  /// lines.
  String report(Map<String, String> facts) {
    final out = StringBuffer('kabso cam2 log v1\n')
      ..writeln('platform ${defaultTargetPlatform.name}')
      ..writeln('release $kReleaseMode');
    for (final e in facts.entries) {
      out.writeln('${e.key} ${e.value}');
    }
    out.writeln('--');
    _lines.forEach(out.writeln);
    return out.toString();
  }
}

/// What a time-limited call ended with.
enum Cam2CallEnd { ok, failed, timedOut }

/// The result of [guardCall].
@immutable
class Cam2Call<T> {
  const new(this.end, [this.value]);

  final Cam2CallEnd end;
  final T? value;

  bool get ok => end == Cam2CallEnd.ok;
}

/// D251: runs one platform call of the second camera's screen with a time
/// limit; never throws. The call itself may go on after [limit] (a Dart
/// future cannot be cancelled), but the screen no longer waits for it.
/// Logs `<name> ok <ms>`, `<name> failed <ErrorType> <ms>` or
/// `<name> timeout`. A [PlatformException] adds its code (letters only) and,
/// for flutter_webrtc's own fixed messages, a short tag — never the text
/// (it carries track ids).
Future<Cam2Call<T>> guardCall<T>(
  SecondCameraLog log,
  String name,
  Duration limit,
  Future<T> Function() op,
) async {
  final watch = Stopwatch()..start();
  try {
    final value = await Future<T>.sync(op).timeout(limit);
    log.add(name, 'ok ${watch.elapsedMilliseconds}ms');
    return Cam2Call<T>(Cam2CallEnd.ok, value);
  } on TimeoutException {
    log.add(name, 'timeout ${limit.inMilliseconds}ms');
    return Cam2Call<T>(Cam2CallEnd.timedOut);
  } on Object catch (e) {
    final ms = watch.elapsedMilliseconds;
    final why = e is PlatformException ? platformErrorTag(e) : null;
    log.add(
      name,
      why == null
          ? 'failed ${e.runtimeType} ${ms}ms'
          : 'failed ${e.runtimeType} $why ${ms}ms',
    );
    return Cam2Call<T>(Cam2CallEnd.failed);
  }
}

/// flutter_webrtc's fixed error messages (their ids cut off) and their tags.
const _webrtcMessages = {
  'Switching camera failed': 'switch-error',
  'Video capturer not found': 'no-capturer',
};

/// The tags [KabsoCameraFlipper.flip]'s own errors carry (D251c).
const _flipWhys = {'no-capturer', 'no-device', 'switch-busy', 'switch-error'};

/// `code=<code> why=<tag> state=<camera state>` for [e]: the code only when
/// it is a plain name (letters, digits, `_`, at most 40), the tag only for a
/// known message, the state only when it is a known camera state.
///
/// D251c: flutter_webrtc prefixes its messages with the method
/// (`switchCamera(): Switching camera failed: <id>`), which hid the tag; the
/// prefix is cut before matching. Nothing outside the fixed words is kept.
@visibleForTesting
String? platformErrorTag(PlatformException e) {
  final parts = <String>[];
  if (RegExp(r'^[A-Za-z0-9_]{1,40}$').hasMatch(e.code)) {
    parts.add('code=${e.code}');
  }
  final raw = e.message;
  if (raw != null) {
    final message = raw.replaceFirst(
      RegExp(r'^[A-Za-z0-9_]{1,40}\(\):\s*'),
      '',
    );
    String? why;
    for (final m in _webrtcMessages.entries) {
      if (message.startsWith(m.key)) why = m.value;
    }
    final whyToken = RegExp(r'(?:^|\s)why=([a-z-]+)(?=\s|$)')
        .firstMatch(message);
    if (why == null && whyToken != null && _flipWhys.contains(whyToken[1])) {
      why = whyToken[1];
    }
    if (why != null) parts.add('why=$why');
    final state = RegExp(r'(?:^|\s)state=([A-Z]+)(?=\s|$)').firstMatch(message);
    if (state != null && KabsoCameraFlip.cameraStates.contains(state[1])) {
      parts.add('state=${state[1]}');
    }
  }
  return parts.isEmpty ? null : parts.join(' ');
}
