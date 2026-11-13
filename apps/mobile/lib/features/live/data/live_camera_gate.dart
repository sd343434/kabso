import 'dart:async';

import 'package:flutter/foundation.dart';

/// D144b: one camera at a time in this app process.
///
/// flutter_webrtc 1.6.2+hotfix.4 (Android) does not open a camera twice: a
/// second `getUserMedia` for a camera that is still open gets a *shared*
/// track off the first one's `VideoSource`. Only the first track's wrapper is
/// on the frame path, so the native camera processor (`kabso_camera_fx`:
/// DeepAR, colour filters, the fill light) attached to the shared one never
/// sees a frame, while the picture itself looks normal — the owner's
/// `in 0 … init no … on track`, and «جارٍ تشغيل المؤثر…» for ever.
///
/// Every go-live makes a fresh media engine and the screen's controller stops
/// the old one without waiting (`ref.onDispose`), so closing and reopening
/// the go-live screen raced the old camera's stop against the new camera's
/// start. Stops now go through [stopping] and starts wait for [idle] first.
abstract final class LiveCameraGate {
  static final Set<Future<void>> _pending = {};

  /// How long a start waits for a stop that hangs (the camera starts anyway;
  /// the processor's own frame-path check and start watch take it from there).
  static Duration timeout = const Duration(seconds: 4);

  /// Whether a camera is still being stopped.
  static bool get busy => _pending.isNotEmpty;

  /// Runs [stop] (a camera's teardown); [idle] waits for it. Starts [stop]
  /// synchronously, so a start that comes right after already waits.
  static Future<void> stopping(Future<void> Function() stop) {
    final Future<void> running;
    try {
      running = stop();
    } on Object catch (e, s) {
      return Future.error(e, s);
    }
    final tracked = running.then<void>((_) {}, onError: (Object _) {});
    _pending.add(tracked);
    unawaited(tracked.whenComplete(() => _pending.remove(tracked)));
    return running;
  }

  /// Completes when no camera is being stopped (or after [timeout]).
  static Future<void> idle() async {
    if (_pending.isEmpty) return;
    try {
      await Future.wait(List.of(_pending)).timeout(timeout);
    } on TimeoutException {
      return;
    }
    // A stop that began meanwhile.
    if (_pending.isNotEmpty) await idle();
  }

  @visibleForTesting
  static void reset() {
    _pending.clear();
    timeout = const Duration(seconds: 4);
  }
}
