import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/logging/app_logger.dart';

/// D243: keeps this phone's screen on while it is a live's second camera.
///
/// The second device usually sits untouched on a stand. Without this its
/// screen times out, Android stops the app's activity, and an app that is not
/// in the foreground loses the camera (Android 9+): the published track stays
/// up with no frames, so the viewers' picture froze on its last frame.
/// Android: the window's `FLAG_KEEP_SCREEN_ON` (no permission, only while
/// the app's window is shown); iOS: `isIdleTimerDisabled`. Elsewhere nothing.
abstract interface class LiveScreenAwake {
  /// Keeps the screen on ([on]) or lets it time out again.
  Future<void> keepOn({required bool on});
}

/// The platform side, over the app's `com.kabso/screen` channel
/// (`MainActivity`, `AppDelegate`).
class PlatformLiveScreenAwake implements LiveScreenAwake {
  const new();

  static const channel = MethodChannel('com.kabso/screen');

  @override
  Future<void> keepOn({required bool on}) async {
    if (kIsWeb) return;
    try {
      await channel.invokeMethod<void>('keepOn', on);
    } on Object catch (e) {
      // Best effort: the camera still works while the person touches it.
      AppLogger.warning('live: keep screen on failed (${e.runtimeType})');
    }
  }
}

/// Tests override it with a fake.
final Provider<LiveScreenAwake> liveScreenAwakeProvider =
    Provider<LiveScreenAwake>((_) => const PlatformLiveScreenAwake());
