import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the launch animation has finished (D63). The router keeps the
/// splash until it has; after that the auth redirect applies as before.
class SplashIntro extends Notifier<bool> {
  @override
  bool build() => false;

  void finish() => state = true;
}

final splashIntroProvider = NotifierProvider<SplashIntro, bool>(
  SplashIntro.new,
);

/// The launch voice ("kab kab kabsooo"), timed with the animation.
abstract interface class SplashVoice {
  /// Starts the voice. Never throws: a voice that cannot play (no audio
  /// plugin, web autoplay policy) leaves the animation silent.
  Future<void> play();

  Future<void> dispose();
}

/// Plays `assets/splash/kabso_voice.mp3` as a system sound that respects
/// the silent switch and mixes with the user's own audio (D63):
/// - iOS: `ambient` session (silenced by the ring/silent switch, never
///   interrupts other audio).
/// - Android: sonification usage without audio focus (follows the system
///   volume, which silent and vibrate modes mute on most devices).
/// - Web: browsers block autoplay before a user gesture, so it stays silent.
class AudioplayersSplashVoice implements SplashVoice {
  static const asset = 'splash/kabso_voice.mp3';

  AudioPlayer? _player;

  @override
  Future<void> play() async {
    if (kIsWeb) return;
    try {
      final player = _player = AudioPlayer();
      await player.play(
        AssetSource(asset),
        mode: PlayerMode.lowLatency,
        ctx: AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
    } on Object catch (error) {
      debugPrint('Splash voice unavailable: $error');
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } on Object catch (_) {
      // Nothing to release.
    }
  }
}

final Provider<SplashVoice> splashVoiceProvider =
    Provider.autoDispose<SplashVoice>((ref) {
      final voice = AudioplayersSplashVoice();
      ref.onDispose(() => unawaited(voice.dispose()));
      return voice;
    });
