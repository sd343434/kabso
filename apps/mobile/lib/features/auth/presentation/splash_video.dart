import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

/// What the launch screen knows about its video (D156).
@immutable
class SplashVideoState {
  const new({
    this.initialized = false,
    this.completed = false,
    this.failed = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.size = Size.zero,
  });

  final bool initialized;

  /// Played to its last frame.
  final bool completed;

  /// The video could not be loaded or played.
  final bool failed;
  final Duration position;
  final Duration duration;

  /// The video's own size in pixels (zero until initialized).
  final Size size;
}

/// The seam between the launch screen and a video player: the real one is
/// [VideoPlayerSplashVideo]; widget tests use a fake (the plugin has no
/// implementation there).
abstract class SplashVideoController implements Listenable {
  SplashVideoState get state;

  /// Loads the video. Throws when it cannot be played.
  Future<void> initialize();

  /// 0 (muted) or 1.
  Future<void> setVolume(double volume);

  Future<void> play();

  /// Stops at the current frame (the frame stays on screen).
  Future<void> pause();

  /// The video's picture at its own size.
  Widget buildView();

  Future<void> dispose();
}

/// The launch video through the official `video_player` plugin (BSD-3,
/// pinned in pubspec): ExoPlayer on Android, AVPlayer on iOS. It mixes with
/// the person's own audio (no audio focus on Android, a mixing session on
/// iOS), as the D63 voice did.
class VideoPlayerSplashVideo implements SplashVideoController {
  new(String asset)
    : _controller = VideoPlayerController.asset(
        asset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

  final VideoPlayerController _controller;

  @override
  SplashVideoState get state {
    final v = _controller.value;
    return SplashVideoState(
      initialized: v.isInitialized,
      completed:
          v.isCompleted ||
          (v.isInitialized &&
              v.duration > Duration.zero &&
              v.position >= v.duration),
      failed: v.hasError,
      position: v.position,
      duration: v.duration,
      size: v.size,
    );
  }

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<void> setVolume(double volume) => _controller.setVolume(volume);

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  Future<void> dispose() => _controller.dispose();

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);
}

/// Makes the launch screen's video controller (tests override it).
final Provider<SplashVideoController Function(String asset)>
splashVideoFactoryProvider =
    Provider<SplashVideoController Function(String asset)>(
      (ref) => VideoPlayerSplashVideo.new,
    );

/// Whether the phone is in silent or vibrate mode. Detectable on Android
/// only (the ring mode, through `com.kabso/audio` in MainActivity); iOS
/// does not report its silent switch to apps, so there it is always false.
abstract interface class DeviceSilentMode {
  Future<bool> isSilent();
}

class PlatformDeviceSilentMode implements DeviceSilentMode {
  const new();

  static const channel = MethodChannel('com.kabso/audio');

  /// `AudioManager.RINGER_MODE_NORMAL`; silent is 0, vibrate 1.
  static const ringerModeNormal = 2;

  @override
  Future<bool> isSilent() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      // The splash bounds the wait (an unanswered call counts as not
      // silent).
      final mode = await channel.invokeMethod<int>('ringerMode');
      return mode != null && mode < ringerModeNormal;
    } on Object catch (error) {
      debugPrint('Ring mode unavailable: $error');
      return false;
    }
  }
}

final Provider<DeviceSilentMode> deviceSilentModeProvider =
    Provider<DeviceSilentMode>((ref) => const PlatformDeviceSilentMode());

/// D156: whether the launch video plays with its sound — the app's
/// **Sound effects** setting (D145d) is on and the phone is not in silent
/// or vibrate mode (Android). On the web browsers refuse to autoplay sound,
/// so the video is always muted there.
Future<bool> splashSoundOn({
  required bool soundEffects,
  required DeviceSilentMode silentMode,
}) async {
  if (kIsWeb || !soundEffects) return false;
  return !await silentMode.isSilent();
}
