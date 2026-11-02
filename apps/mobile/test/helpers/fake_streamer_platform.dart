// D213: the streamer live's native side and the live's foreground service,
// recorded (tests only; no device).
import 'dart:async';

import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/data/streamer/live_streamer_platform.dart';

/// The native side, recorded.
class FakeStreamerPlatform implements StreamerPlatform {
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

  @override
  Future<bool> requestCapture() async {
    consents++;
    return allowCapture;
  }

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

  @override
  Future<void> start(LiveBackgroundSpec spec) async {
    starts.add(spec);
    running = spec;
  }

  @override
  Future<void> stop() async => running = null;

  @override
  Stream<LiveBackgroundAction> get actions => _actions.stream;

  void tap(LiveBackgroundAction a) => _actions.add(a);
}
