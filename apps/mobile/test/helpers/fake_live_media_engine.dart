import 'dart:async';

import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:material_ui/material_ui.dart';

/// In-memory [LiveMediaEngine]: no camera, no media server. Records every
/// call; [previewProblem] / [publishFailure] make them fail.
class FakeLiveMediaEngine implements LiveMediaEngine {
  static const previewKey = Key('fakeCamera');

  LiveCaptureProblem? previewProblem;
  Exception? publishFailure;

  int previewStarts = 0;
  int flips = 0;
  int stops = 0;
  bool running = false;
  LiveMediaAccess? published;
  bool _front = true;
  bool _mic = true;

  /// The `video` flag of every `startPreview` call.
  final List<bool> previewModes = [];
  bool _video = true;

  /// What [beautySupported] answers.
  bool supportsBeauty = true;
  LiveBeauty beauty = const LiveBeauty();

  @override
  Future<void> startPreview({bool video = true}) async {
    previewStarts++;
    previewModes.add(video);
    if (previewProblem case final problem?) {
      throw LiveCaptureException(problem);
    }
    running = true;
    _video = video;
  }

  @override
  bool get videoEnabled => running && _video;

  @override
  bool get beautySupported => supportsBeauty;

  @override
  Future<void> setBeauty(LiveBeauty beauty) async => this.beauty = beauty;

  /// The last `setVoice`.
  ({bool noiseReduction, bool enhance}) voice = (
    noiseReduction: true,
    enhance: true,
  );

  @override
  Future<void> setVoice({
    required bool noiseReduction,
    required bool enhance,
  }) async => voice = (noiseReduction: noiseReduction, enhance: enhance);

  @override
  Widget? preview() => videoEnabled
      ? ColoredBox(
          key: previewKey,
          color: _front ? const Color(0xFF203040) : const Color(0xFF402030),
        )
      : null;

  @override
  bool get frontCamera => _front;

  @override
  Future<void> flipCamera() async {
    flips++;
    _front = !_front;
  }

  @override
  bool get micEnabled => _mic;

  @override
  Future<void> setMicEnabled({required bool enabled}) async => _mic = enabled;

  @override
  Future<void> publish(LiveMediaAccess access) async {
    if (publishFailure case final failure?) throw failure;
    published = access;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
    published = null;
  }

  // ---- session --------------------------------------------------------

  /// What `join` received.
  LiveMediaAccess? joined;

  /// The identities present in the session (their video is a coloured box
  /// keyed `remote.<identity>`).
  final Set<String> present = {};
  bool publishAllowed = false;
  bool publishingLocal = false;
  final List<bool> publishLocalCalls = [];
  int unpublishLocalCalls = 0;
  Set<String> speakingNow = {};
  int? version;
  final _invites = StreamController<String>.broadcast();
  final _changes = ChangeNotifier();

  /// Tells listeners the session changed (tests).
  void ping() => _changes.notifyListeners();

  void invite(String roomId) => _invites.add(roomId);

  @override
  Future<void> join(LiveMediaAccess access) async => joined = access;

  @override
  bool get canPublish => publishAllowed;

  @override
  Future<void> publishLocal({required bool video}) async {
    publishLocalCalls.add(video);
    await startPreview(video: video);
    publishingLocal = true;
  }

  @override
  Future<void> unpublishLocal() async {
    unpublishLocalCalls++;
    publishingLocal = false;
    running = false;
  }

  @override
  Widget? remoteVideo(String identity) => present.contains(identity)
      ? ColoredBox(key: Key('remote.$identity'), color: const Color(0xFF304050))
      : null;

  @override
  bool isPresent(String identity) => present.contains(identity);

  @override
  Set<String> get speaking => speakingNow;

  @override
  int? get seatsVersion => version;

  @override
  Stream<String> get seatInvites => _invites.stream;

  @override
  Listenable get changes => _changes;

  @override
  bool get connected => joined != null || published != null;
}
