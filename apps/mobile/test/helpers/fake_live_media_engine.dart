import 'dart:async';

import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
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

  /// While set, `startPreview` waits for it (a camera that is slow to
  /// start), then applies its `video` flag.
  Completer<void>? previewGate;

  /// Whether a camera was running when [publish] was called.
  bool? publishedWithVideo;

  @override
  Future<void> startPreview({bool video = true}) async {
    previewStarts++;
    previewModes.add(video);
    if (previewGate case final gate?) await gate.future;
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

  // ---- CP-017: the live microphone around a voice clip -------------------

  /// Whether the live microphone is paused for a voice clip now.
  bool micPausedForClip = false;

  /// When set, `pauseForClip` throws (the microphone cannot be freed).
  bool micPauseFails = false;

  /// `pause` / `resume` in order (only the calls that changed something).
  final List<String> clipMicLog = [];

  /// Whether a microphone is published (the host after `publish`, a seated
  /// guest after `publishLocal`).
  bool get micPublished => published != null || publishingLocal;

  @override
  Future<bool> pauseForClip() async {
    if (!micPublished || micPausedForClip) return false;
    if (micPauseFails) {
      throw const LiveCaptureException(LiveCaptureProblem.unavailable);
    }
    micPausedForClip = true;
    clipMicLog.add('pause');
    return true;
  }

  @override
  Future<void> resumeAfterClip() async {
    if (!micPausedForClip) return;
    micPausedForClip = false;
    clipMicLog.add('resume');
  }

  @override
  Future<void> publish(LiveMediaAccess access) async {
    if (publishFailure case final failure?) throw failure;
    publishedWithVideo = videoEnabled;
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

  /// The room score the media room's metadata carries (CP-012).
  int? scoreNow;

  @override
  int? get score => scoreNow;

  /// `roomInfoVersion` the media room's metadata carries (CP-014).
  int? infoVersion;

  @override
  int? get roomInfoVersion => infoVersion;

  @override
  Stream<String> get seatInvites => _invites.stream;

  /// CP-013: what the media room delivers to [chatEvents]; tests add to it.
  final chat = StreamController<LiveChatEvent>.broadcast();

  @override
  Stream<LiveChatEvent> get chatEvents => chat.stream;

  @override
  Listenable get changes => _changes;

  /// The media server closed the session (the room was deleted).
  bool dropped = false;

  @override
  bool get connected => !dropped && (joined != null || published != null);

  /// v1.20-live: the media server removed this participant (a kick); set
  /// with [dropped] and [ping].
  bool kickedOut = false;

  @override
  bool get removed => kickedOut;
}
