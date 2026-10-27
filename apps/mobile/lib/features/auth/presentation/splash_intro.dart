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

/// Plays `assets/splash/kabso_voice.mp3` once per app process (a cold
/// start), mixed with the user's own audio:
/// - Android: media usage without audio focus, so it follows the media
///   volume. (Sonification usage, used before, plays on the system stream,
///   which many phones keep muted or tie to "touch sounds".)
/// - iOS: `ambient` session (silenced by the ring/silent switch, never
///   interrupts other audio).
/// - Web: browsers block autoplay before a user gesture, so it stays silent.
///
/// The voice (3 s) outlives the splash screen, so it owns its player and
/// releases it when playback completes, not when the screen goes away.
class AudioplayersSplashVoice implements SplashVoice {
  new({AudioPlayer Function()? createPlayer})
    : _createPlayer = createPlayer ?? AudioPlayer.new;

  static const asset = 'splash/kabso_voice.mp3';

  /// MediaPlayer, not SoundPool: SoundPool (low latency) reports no
  /// completion and decodes MP3 unreliably on some Android devices.
  static const PlayerMode mode = PlayerMode.mediaPlayer;

  static final AudioContext audioContext = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    // The defaults are music content on the media stream (usage media).
    android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
  );

  final AudioPlayer Function() _createPlayer;
  AudioPlayer? _player;
  StreamSubscription<void>? _completion;
  var _played = false;

  @override
  Future<void> play() async {
    if (kIsWeb || _played) return;
    _played = true;
    try {
      final player = _player = _createPlayer();
      _completion = player.onPlayerComplete.listen(
        (_) => unawaited(dispose()),
        onError: (Object _) {},
      );
      await player.setReleaseMode(ReleaseMode.release);
      await player.play(AssetSource(asset), mode: mode, ctx: audioContext);
    } on Object catch (error) {
      debugPrint('Splash voice unavailable: $error');
      await dispose();
    }
  }

  @override
  Future<void> dispose() async {
    final player = _player;
    _player = null;
    unawaited(_completion?.cancel());
    _completion = null;
    try {
      await player?.dispose();
    } on Object catch (_) {
      // Nothing to release.
    }
  }
}

/// Kept alive for the app's lifetime on purpose: the splash only reads it,
/// and an auto-disposed provider would be disposed right after that read,
/// releasing the player before the voice could be heard.
final Provider<SplashVoice> splashVoiceProvider = Provider<SplashVoice>((ref) {
  final voice = AudioplayersSplashVoice();
  ref.onDispose(() => unawaited(voice.dispose()));
  return voice;
});
