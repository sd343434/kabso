import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// D262: how the system's screen-capture consent ended.
enum StreamerConsentOutcome {
  /// The person allowed it; the capture can start.
  granted,

  /// The person said no in the system dialog.
  refused,

  /// The dialog could not be asked or never showed ([StreamerConsent.reason]).
  failed,
}

/// D262: the consent's answer: [outcome] and, when it failed, a short
/// code (`no_activity`, `instant_cancel`, `no_webrtc`, a platform error's
/// code…) shown to the host and logged — never an id.
@immutable
final class StreamerConsent {
  const new _(this.outcome, this.reason);

  const new failed(String this.reason)
    : outcome = StreamerConsentOutcome.failed;

  /// `requestCapture`'s answer `{outcome, reason}`; anything else failed.
  factory parse(Object? wire) {
    final map = wire is Map ? wire : const <Object?, Object?>{};
    return switch (map['outcome']) {
      'granted' => granted,
      'refused' => refused,
      'failed' => StreamerConsent.failed(code(map['reason'])),
      _ => const StreamerConsent.failed('bad_answer'),
    };
  }

  static const granted = StreamerConsent._(
    StreamerConsentOutcome.granted,
    null,
  );
  static const refused = StreamerConsent._(
    StreamerConsentOutcome.refused,
    null,
  );

  /// Allowed, but the screen then could not start again («شارك من جديد»).
  static const startFailed = 'start';

  final StreamerConsentOutcome outcome;
  final String? reason;

  bool get isGranted => outcome == StreamerConsentOutcome.granted;

  /// The reason as a short code: lower-case letters, digits and `_`, at most
  /// 32 characters (`unknown` when empty).
  static String code(Object? raw) {
    final cleaned = '${raw ?? ''}'
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (cleaned.isEmpty) return 'unknown';
    return cleaned.length > 32 ? cleaned.substring(0, 32) : cleaned;
  }

  @override
  bool operator ==(Object other) =>
      other is StreamerConsent &&
      other.outcome == outcome &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(outcome, reason);

  @override
  String toString() =>
      reason == null ? outcome.name : '${outcome.name}($reason)';
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

  /// The system's screen-capture consent (MediaProjection), asked by
  /// `kabso_streamer` (D262) and handed to flutter_webrtc's screen capture.
  /// Never throws: a platform error is [StreamerConsentOutcome.failed]. Must
  /// come before the live's foreground service gains the `mediaProjection`
  /// type (Android 14).
  Future<StreamerConsent> requestCapture();

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

/// [StreamerPlatform] on `com.kabso/streamer` (the consent too, D262).
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

  /// A dialog left open longer than this (or an answer lost with the
  /// Activity) ends as failed, so «ابدأ» never stays stuck.
  static const consentTimeout = Duration(minutes: 3);

  @override
  Future<StreamerConsent> requestCapture() async {
    try {
      final res = await _channel
          // D262b (owner): the whole screen at once — Android 14+ then
          // offers no «single app» choice (whose app picker, left with
          // back, read as a refusal).
          .invokeMethod<Object?>('requestCapture', {'fullScreenOnly': true})
          .timeout(consentTimeout);
      return StreamerConsent.parse(res);
    } on TimeoutException {
      return const StreamerConsent.failed('timeout');
    } on MissingPluginException {
      return const StreamerConsent.failed('no_plugin');
    } on PlatformException catch (e) {
      return StreamerConsent.failed(StreamerConsent.code(e.code));
    } on Object catch (e) {
      return StreamerConsent.failed(StreamerConsent.code(e.runtimeType));
    }
  }

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
