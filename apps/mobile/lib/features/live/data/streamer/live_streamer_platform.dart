import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

/// D213 (owner: «ANDROID FIRST»): where a streamer live can be hosted.
enum StreamerSupport {
  /// Android: the phone screen, the camera bubble and (10+) the game sound.
  supported,

  /// iOS: an honest «قريباً على آيفون» — no flow (the broadcast extension is
  /// not built).
  iosSoon,

  /// The web and desktops: not offered.
  unsupported,
}

/// The platform this build runs on (tests set
/// `debugDefaultTargetPlatformOverride`).
StreamerSupport streamerSupportHere() {
  if (kIsWeb) return StreamerSupport.unsupported;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => StreamerSupport.supported,
    TargetPlatform.iOS => StreamerSupport.iosSoon,
    _ => StreamerSupport.unsupported,
  };
}

/// Overridable in tests.
final Provider<StreamerSupport> streamerSupportProvider =
    Provider<StreamerSupport>((_) => streamerSupportHere());

/// The game sound's state once the screen runs (`attach`).
enum StreamerGameAudio {
  /// Mixed into the microphone (Android 10+). Apps that forbid capture still
  /// come out silent — Android gives no error, so the host is told up front.
  ok,

  /// Below Android 10: the microphone only.
  unsupportedOs,

  /// The host turned the game sound off in the setup.
  off,

  /// The screen capture's MediaProjection was not found (another
  /// flutter_webrtc build): the microphone only.
  noProjection,

  /// Android refused the capture: the microphone only.
  failed;

  static StreamerGameAudio parse(Object? wire) => switch (wire) {
    'ok' => ok,
    'unsupported_os' => unsupportedOs,
    'off' => off,
    'no_projection' => noProjection,
    _ => failed,
  };

  /// The game sound reaches the viewers.
  bool get mixed => this == ok;
}

/// What the phone reports while streaming.
sealed class StreamerPlatformEvent {
  const new();
}

/// The person stopped the screen capture from the system (Android 14's
/// status-bar chip, the cast tile): the screen track is over.
final class StreamerProjectionStopped extends StreamerPlatformEvent {
  const new();
}

/// The phone's screen went off or on.
final class StreamerScreenPower extends StreamerPlatformEvent {
  const new({required this.on});
  final bool on;
}

/// A phone call rings or is on (or ended).
final class StreamerPhoneCall extends StreamerPlatformEvent {
  const new({required this.active});
  final bool active;
}

/// A headset was plugged in or out (on air).
final class StreamerHeadset extends StreamerPlatformEvent {
  const new({required this.connected});
  final bool connected;
}

/// The display turned (a landscape game).
final class StreamerRotation extends StreamerPlatformEvent {
  const new({required this.landscape});
  final bool landscape;
}

/// The native side of the streamer live (Android, `kabso_streamer`).
abstract interface class StreamerPlatform {
  /// Android's API level (0 elsewhere).
  Future<int> sdkInt();

  /// A wired, USB or Bluetooth headset is an output now (the «use
  /// headphones» tip). False when unknown.
  Future<bool> headsetConnected();

  /// The system's screen-capture consent (MediaProjection). False: refused.
  /// Must come before the live's foreground service gains the
  /// `mediaProjection` type (Android 14).
  Future<bool> requestCapture();

  /// Once the screen track runs: joins the published microphone (the voice
  /// and the game muted separately), watches the capture and, with
  /// [gameAudio] on Android 10+, mixes the game sound in.
  Future<({bool projection, StreamerGameAudio gameAudio})> attach({
    required bool gameAudio,
  });

  Future<void> setMicMuted({required bool muted});

  Future<void> setGameMuted({required bool muted});

  /// Undoes [attach] (before the screen track is stopped by the app).
  Future<void> detach();

  /// FLAG_SECURE on the app's own window (while streaming).
  Future<void> setSecure({required bool on});

  /// The app goes to the background (to the game).
  Future<void> moveToBack();

  Stream<StreamerPlatformEvent> get events;
}

/// [StreamerPlatform] on `com.kabso/streamer` and flutter_webrtc's consent.
class ChannelStreamerPlatform implements StreamerPlatform {
  new() {
    _channel.setMethodCallHandler(_onCall);
  }

  static const _channel = MethodChannel('com.kabso/streamer');
  final _events = StreamController<StreamerPlatformEvent>.broadcast();

  Future<void> _onCall(MethodCall call) async {
    final args = call.arguments;
    final map = args is Map ? args : const <Object?, Object?>{};
    switch (call.method) {
      case 'projectionStopped':
        _events.add(const StreamerProjectionStopped());
      case 'screen':
        _events.add(StreamerScreenPower(on: map['on'] == true));
      case 'call':
        _events.add(StreamerPhoneCall(active: map['active'] == true));
      case 'headset':
        _events.add(StreamerHeadset(connected: map['connected'] == true));
      case 'rotation':
        _events.add(StreamerRotation(landscape: map['landscape'] == true));
    }
  }

  @override
  Future<int> sdkInt() async =>
      (await _channel.invokeMethod<int>('sdkInt')) ?? 0;

  @override
  Future<bool> headsetConnected() async =>
      (await _channel.invokeMethod<bool>('headset')) ?? false;

  @override
  Future<bool> requestCapture() => rtc.Helper.requestCapturePermission();

  @override
  Future<({bool projection, StreamerGameAudio gameAudio})> attach({
    required bool gameAudio,
  }) async {
    final res = await _channel.invokeMapMethod<String, Object?>('attach', {
      'gameAudio': gameAudio,
    });
    return (
      projection: res?['projection'] == true,
      gameAudio: StreamerGameAudio.parse(res?['gameAudio']),
    );
  }

  @override
  Future<void> setMicMuted({required bool muted}) =>
      _channel.invokeMethod<void>('setMicMuted', {'muted': muted});

  @override
  Future<void> setGameMuted({required bool muted}) =>
      _channel.invokeMethod<void>('setGameMuted', {'muted': muted});

  @override
  Future<void> detach() => _channel.invokeMethod<void>('detach');

  @override
  Future<void> setSecure({required bool on}) =>
      _channel.invokeMethod<void>('setSecure', {'on': on});

  @override
  Future<void> moveToBack() => _channel.invokeMethod<void>('moveToBack');

  @override
  Stream<StreamerPlatformEvent> get events => _events.stream;
}

/// The app's one platform side (tests override it).
final Provider<StreamerPlatform> streamerPlatformProvider =
    Provider<StreamerPlatform>((_) => ChannelStreamerPlatform());
