import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:material_ui/material_ui.dart'
    show AppLifecycleState, WidgetsBinding;

/// One sound of an SVGA effect: [bytes] (MP3) from [startFrame] to
/// [endFrame] of the movie (SVGA 2.x `MovieEntity.audios`).
@immutable
class GiftSoundClip {
  const new({
    required this.key,
    required this.startFrame,
    required this.endFrame,
    required this.bytes,
  });

  final String key;
  final int startFrame;
  final int endFrame;
  final Uint8List bytes;
}

/// The gift's own sound, embedded in its SVGA (owner D126: the sound plays
/// with the animation). The app plays it itself instead of the SVGA player
/// (whose audio is cleared from the movie): on Android as media without
/// taking audio focus, so the live's audio and other apps keep playing and
/// the media volume applies; on iOS in the audio session the live already
/// set (no category change, which would disturb the live's microphone).
/// Never while the app is in the background; [stop] ends every clip.
class GiftEffectSound {
  new(this.clips);

  /// Takes the clips out of [movie] (and its audio from the SVGA player,
  /// so the sound plays once, here). Empty when it has none.
  factory fromMovie(MovieEntity movie) {
    final clips = [
      for (final a in movie.audios)
        if (movie.audiosData[a.audioKey] case final bytes?)
          GiftSoundClip(
            key: a.audioKey,
            startFrame: a.startFrame,
            endFrame: a.endFrame,
            bytes: bytes,
          ),
    ];
    movie.audios.clear();
    return GiftEffectSound(clips);
  }

  final List<GiftSoundClip> clips;

  /// Off in widget tests (`test/flutter_test_config.dart`).
  static bool enabled = true;

  /// Makes a player (tests replace it).
  @visibleForTesting
  static AudioPlayer Function() newPlayer = AudioPlayer.new;

  /// Whether sound may start now: the app is in the foreground.
  @visibleForTesting
  static bool Function() foreground = () {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  };

  final _players = <AudioPlayer>[];
  final _started = <String>{};
  bool _stopped = false;

  bool get isEmpty => clips.isEmpty;

  /// The movie is at [frame]: starts the clips that begin by then (once
  /// each; a clip whose end has passed is skipped).
  void onFrame(int frame) {
    if (_stopped || !enabled) return;
    for (final clip in clips) {
      if (clip.startFrame > frame || _started.contains(clip.key)) continue;
      _started.add(clip.key);
      if (clip.endFrame < frame || !foreground()) continue;
      unawaited(_play(clip));
    }
  }

  Future<void> _play(GiftSoundClip clip) async {
    final player = newPlayer();
    _players.add(player);
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await player.setAudioContext(
          AudioContext(
            // Media volume (the defaults: music, media), no audio focus.
            android: const AudioContextAndroid(
              audioFocus: AndroidAudioFocus.none,
            ),
          ),
        );
      }
      if (_stopped) return;
      await player.play(BytesSource(clip.bytes, mimeType: 'audio/mpeg'));
    } on Object catch (e) {
      // No sound on this device: the animation plays silently.
      debugPrint('GiftEffectSound(${clip.key}): $e');
    }
  }

  /// Stops and releases every clip (the effect ended, or the app left the
  /// foreground). Nothing plays afterwards.
  Future<void> stop() async {
    _stopped = true;
    final players = [..._players];
    _players.clear();
    for (final p in players) {
      try {
        await p.stop();
        await p.dispose();
      } on Object {
        // Already gone.
      }
    }
  }
}
