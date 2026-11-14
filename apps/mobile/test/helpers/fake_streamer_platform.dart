// D213: the streamer live's native side and the live's foreground service,
// recorded (tests only; no device).
import 'dart:async';

import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/data/streamer/live_streamer_platform.dart';

/// The native side, recorded.
class FakeStreamerPlatform implements StreamerPlatform {
  /// D346: a log shared with [FakeBackground] (the order of the steps).
  List<String>? log;

  int sdk = 34;
  bool allowCapture = true;
  StreamerGameAudio answer = StreamerGameAudio.ok;
  bool failAttach = false;
  int consents = 0;
  final List<bool> attaches = [];
  final List<bool> micMutes = [];
  final List<bool> gameMutes = [];
  final List<bool> secure = [];
  int detaches = 0;
  int toBack = 0;

  /// What `headsetConnected` answers (a headset plugged in).
  bool headset = false;
  int headsetReads = 0;
  final _events = StreamController<StreamerPlatformEvent>.broadcast();

  void emit(StreamerPlatformEvent e) => _events.add(e);

  @override
  Future<int> sdkInt() async => sdk;

  @override
  Future<bool> headsetConnected() async {
    headsetReads++;
    return headset;
  }

  /// D262: the consent's answer; null → granted or refused by [allowCapture].
  StreamerConsent? consentAnswer;

  /// D262: throws instead of answering (a platform that misbehaves).
  bool throwOnConsent = false;

  @override
  Future<StreamerConsent> requestCapture() async {
    consents++;
    log?.add('consent');
    if (throwOnConsent) throw StateError('consent');
    return consentAnswer ??
        (allowCapture ? StreamerConsent.granted : StreamerConsent.refused);
  }

  /// D346: what `captureCheck` answers (null: the capture may start).
  String? blocker;
  int captureChecks = 0;

  /// D346: what `diagnostics` answers.
  Map<Object?, Object?> device = const {
    'sdk': 34,
    'release': '14',
    'manufacturer': 'Google',
    'model': 'Pixel 8',
    'serviceForeground': true,
    'serviceTypes': [
      'microphone',
      'mediaPlayback',
      'mediaProjection',
      'camera',
    ],
    'consentHanded': true,
    'consentUsed': true,
  };

  @override
  Future<String?> captureCheck() async {
    captureChecks++;
    log?.add('captureCheck');
    return blocker;
  }

  @override
  Future<Map<Object?, Object?>> diagnostics() async => device;

  @override
  Future<({bool projection, StreamerGameAudio gameAudio})> attach({
    required bool gameAudio,
  }) async {
    attaches.add(gameAudio);
    if (failAttach) throw StateError('not_ready');
    return (
      projection: true,
      gameAudio: gameAudio ? answer : StreamerGameAudio.off,
    );
  }

  @override
  Future<void> setMicMuted({required bool muted}) async => micMutes.add(muted);

  @override
  Future<void> setGameMuted({required bool muted}) async =>
      gameMutes.add(muted);

  @override
  Future<void> detach() async => detaches++;

  @override
  Future<void> setSecure({required bool on}) async => secure.add(on);

  @override
  Future<void> moveToBack() async => toBack++;

  @override
  Stream<StreamerPlatformEvent> get events => _events.stream;
}

/// The foreground service, recorded.
class FakeBackground implements LiveBackgroundService {
  LiveBackgroundSpec? running;
  final List<LiveBackgroundSpec> starts = [];
  final _actions = StreamController<LiveBackgroundAction>.broadcast();

  /// D346: a log shared with [FakeStreamerPlatform].
  List<String>? log;

  /// D346: thrown by [start] while set (Android refused the service).
  Exception? failStart;

  @override
  Future<void> start(LiveBackgroundSpec spec) async {
    starts.add(spec);
    log?.add(spec.screen ? 'service:screen' : 'service');
    if (failStart case final e?) throw e;
    running = spec;
  }

  @override
  Future<void> stop() async => running = null;

  @override
  Stream<LiveBackgroundAction> get actions => _actions.stream;

  void tap(LiveBackgroundAction a) => _actions.add(a);
}
