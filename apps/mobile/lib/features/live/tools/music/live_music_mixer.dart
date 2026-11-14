import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// D201 «موسيقى»: why music cannot be mixed into the live here (the tile and
/// the sheet say so), or none.
enum LiveMusicUnsupported {
  /// iOS: the mixer is an Android module on flutter_webrtc's capture
  /// post-processing; the iOS one is not built yet.
  ios,

  /// The web build.
  web,
}

/// D232: why a file did not play — each with its own message.
enum LiveMusicError {
  /// The mixer has no live microphone to mix into (the live's audio is not
  /// running yet); the file itself is fine (native `not_ready`).
  notReady,

  /// The phone has no decoder for this file's format (native
  /// `unsupported`).
  unsupported,

  /// The file could not be opened or decoded (native `unreadable`, or a
  /// decode error while playing).
  unreadable;

  /// The native error code (`PlatformException.code`, the `error` event's
  /// `reason`) → the error.
  static LiveMusicError fromCode(String? code) => switch (code) {
    'not_ready' => notReady,
    'unsupported' => unsupported,
    _ => unreadable,
  };
}

/// D232: [LiveMusicMixer.load] failed for [error].
class LiveMusicLoadException implements Exception {
  const new(this.error);

  final LiveMusicError error;

  @override
  String toString() => 'LiveMusicLoadException($error)';
}

/// A file the host picked (copied into the app's own storage by the picker,
/// under a safe ASCII name that keeps the format's extension — D232).
@immutable
class LiveMusicFile {
  const new({required this.path, required this.name});

  final String path;
  final String name;
}

/// What the mixer tells: the position, the end of a file, a file it cannot
/// read.
sealed class LiveMusicEvent {
  const new();
}

final class LiveMusicPosition extends LiveMusicEvent {
  const new(this.position, this.duration);
  final Duration position;
  final Duration? duration;
}

final class LiveMusicCompleted extends LiveMusicEvent {
  const new();
}

final class LiveMusicFailed extends LiveMusicEvent {
  const new([this.error = LiveMusicError.unreadable]);

  /// D232: unsupported (no decoder) or unreadable (a decode error).
  final LiveMusicError error;
}

/// D201: mixes an audio file into the host's own published microphone, after
/// echo cancelling and noise suppression, at [setVolume] and lowered while
/// the host speaks ([setDucking]) — viewers hear voice + music in the one
/// track; the host does not hear it from the phone.
abstract interface class LiveMusicMixer {
  /// Null where it works.
  LiveMusicUnsupported? get unsupported;

  /// Opens the system file picker for audio files (no storage permission:
  /// the picker grants the chosen files only). Empty when cancelled.
  Future<List<LiveMusicFile>> pickFiles();

  /// Loads [file] (stops what plays); its length, when the file says.
  /// Throws a [LiveMusicLoadException] when it cannot play (D232).
  Future<Duration?> load(LiveMusicFile file);

  Future<void> play();

  Future<void> pause();

  /// Stops and unloads (the mixer is idle: nothing is added to the mic).
  Future<void> stop();

  /// 0 … 1 of the music's own level, under the voice.
  Future<void> setVolume(double volume);

  Future<void> setDucking({required bool on});

  Stream<LiveMusicEvent> get events;
}

/// [LiveMusicMixer] on the `kabso_live_music` plugin
/// (`com.kabso/live_music`, Android).
class ChannelLiveMusicMixer implements LiveMusicMixer {
  new() {
    _channel.setMethodCallHandler(_onCall);
  }

  static const _channel = MethodChannel('com.kabso/live_music');
  final _events = StreamController<LiveMusicEvent>.broadcast();

  Future<void> _onCall(MethodCall call) async {
    final args = call.arguments;
    switch (call.method) {
      case 'position':
        if (args is Map) {
          final pos = args['positionMs'];
          final dur = args['durationMs'];
          _events.add(
            LiveMusicPosition(
              Duration(milliseconds: pos is int ? pos : 0),
              dur is int && dur > 0 ? Duration(milliseconds: dur) : null,
            ),
          );
        }
      case 'completed':
        _events.add(const LiveMusicCompleted());
      case 'error':
        final reason = args is Map ? args['reason'] : null;
        _events.add(
          LiveMusicFailed(
            LiveMusicError.fromCode(reason is String ? reason : null),
          ),
        );
    }
  }

  @override
  LiveMusicUnsupported? get unsupported {
    if (kIsWeb) return LiveMusicUnsupported.web;
    if (defaultTargetPlatform == TargetPlatform.android) return null;
    return LiveMusicUnsupported.ios;
  }

  @override
  Future<List<LiveMusicFile>> pickFiles() async {
    final picked = await _channel.invokeListMethod<Object?>('pick');
    return [
      for (final item in picked ?? const <Object?>[])
        if (item is Map && item['path'] is String)
          LiveMusicFile(
            path: item['path']! as String,
            name: '${item['name'] ?? ''}',
          ),
    ];
  }

  @override
  Future<Duration?> load(LiveMusicFile file) async {
    final int? ms;
    try {
      ms = await _channel.invokeMethod<int>('load', {'path': file.path});
    } on PlatformException catch (e) {
      throw LiveMusicLoadException(LiveMusicError.fromCode(e.code));
    }
    return ms == null || ms <= 0 ? null : Duration(milliseconds: ms);
  }

  @override
  Future<void> play() => _channel.invokeMethod<void>('play');

  @override
  Future<void> pause() => _channel.invokeMethod<void>('pause');

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<void> setVolume(double volume) =>
      _channel.invokeMethod<void>('setVolume', {'volume': volume});

  @override
  Future<void> setDucking({required bool on}) =>
      _channel.invokeMethod<void>('setDucking', {'on': on});

  @override
  Stream<LiveMusicEvent> get events => _events.stream;
}

final liveMusicMixerProvider = Provider<LiveMusicMixer>(
  (ref) => ChannelLiveMusicMixer(),
);
