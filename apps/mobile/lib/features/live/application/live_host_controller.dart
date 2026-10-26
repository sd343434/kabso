import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show FutureProviderFamily, KeepAliveLink;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';

/// Where the go-live flow is.
enum GoLivePhase {
  /// The camera is starting.
  preparing,

  /// The camera runs; the host sets the title, category and guests.
  preview,

  /// The camera or microphone could not start ([GoLiveState.capture]).
  captureFailed,

  /// `POST /live/rooms`, the media token and publishing are under way.
  starting,

  /// On air: heartbeats run until the host ends.
  live,

  /// `POST /live/rooms/{id}/end` is under way.
  ending,

  /// Over (ended by the host, or by the server: timeout, admin).
  ended,
}

class GoLiveState {
  const new({
    this.phase = GoLivePhase.preparing,
    this.capture,
    this.frontCamera = true,
    this.micEnabled = true,
    this.allowGuests = true,
    this.room,
    this.liveSince,
    this.endedAt,
    this.mode = LiveRoomMode.solo,
    this.multiSeats = defaultMultiSeats,
    this.audioSeats = defaultAudioSeats,
    this.theme = LiveThemes.classic,
    this.beauty = const LiveBeauty(),
    this.noiseReduction = true,
    this.voiceEnhance = true,
  });

  /// D94 voice settings (audio rooms, and the microphone in every mode).
  final bool noiseReduction;
  final bool voiceEnhance;

  /// CP-011: SOLO (LIVE), MULTI (multi-guest) or AUDIO.
  final LiveRoomMode mode;

  /// The seat count chosen for each mode (host tile included).
  final int multiSeats;
  final int audioSeats;

  /// The counts a new room starts with: MULTI 6 (D94), AUDIO 10 (owner,
  /// 2026-10-26; D103 allows 5, 10, 15, 20, 25 — the old default 9 was
  /// refused by the server).
  static const defaultMultiSeats = 6;
  static const defaultAudioSeats = 10;

  /// The seat count of [mode], or `null` for SOLO.
  int? get seatCount => switch (mode) {
    LiveRoomMode.multi => multiSeats,
    LiveRoomMode.audio => audioSeats,
    LiveRoomMode.solo || LiveRoomMode.pk => null,
  };

  final String theme;
  final LiveBeauty beauty;

  final GoLivePhase phase;
  final LiveCaptureProblem? capture;
  final bool frontCamera;
  final bool micEnabled;

  /// CP-010 guests switch: before going live it is sent with the room;
  /// while live it is changed with `PATCH /live/rooms/{id}`.
  final bool allowGuests;

  /// The room once created.
  final LiveRoom? room;
  final DateTime? liveSince;
  final DateTime? endedAt;

  GoLiveState copyWith({
    GoLivePhase? phase,
    LiveCaptureProblem? capture,
    bool? frontCamera,
    bool? micEnabled,
    bool? allowGuests,
    LiveRoom? room,
    DateTime? liveSince,
    DateTime? endedAt,
    LiveRoomMode? mode,
    int? multiSeats,
    int? audioSeats,
    String? theme,
    LiveBeauty? beauty,
    bool? noiseReduction,
    bool? voiceEnhance,
  }) => GoLiveState(
    noiseReduction: noiseReduction ?? this.noiseReduction,
    voiceEnhance: voiceEnhance ?? this.voiceEnhance,
    mode: mode ?? this.mode,
    multiSeats: multiSeats ?? this.multiSeats,
    audioSeats: audioSeats ?? this.audioSeats,
    theme: theme ?? this.theme,
    beauty: beauty ?? this.beauty,
    phase: phase ?? this.phase,
    capture: capture ?? this.capture,
    frontCamera: frontCamera ?? this.frontCamera,
    micEnabled: micEnabled ?? this.micEnabled,
    allowGuests: allowGuests ?? this.allowGuests,
    room: room ?? this.room,
    liveSince: liveSince ?? this.liveSince,
    endedAt: endedAt ?? this.endedAt,
  );
}

/// [count] when [allowed] lists it (or lists nothing); else the smallest
/// allowed count above it, else the largest allowed one.
int fitSeatCount(int count, List<int> allowed) {
  if (allowed.isEmpty || allowed.contains(count)) return count;
  final sorted = [...allowed]..sort();
  return sorted.firstWhere((c) => c > count, orElse: () => sorted.last);
}

/// The go-live flow (CP-010 L1): camera preview → `POST /live/rooms` →
/// media token → publish → heartbeats at the server's interval → end.
///
/// Leaving the screen while live ends the room (best effort) and always
/// turns the camera and microphone off.
class LiveHostController extends Notifier<GoLiveState> {
  late LiveMediaEngine _engine;
  late LiveRepository _repo;
  Timer? _heartbeat;
  KeepAliveLink? _alive;

  /// The room on air (created and not yet ended by this screen).
  String? _onAir;

  /// The engine whose picture the screen shows.
  LiveMediaEngine get engine => _engine;

  @override
  GoLiveState build() {
    _engine = ref.read(liveMediaEngineProvider)();
    _repo = ref.read(liveRepositoryProvider);
    _engine.changes.addListener(_watchRoomInfo);
    ref.onDispose(() {
      _engine.changes.removeListener(_watchRoomInfo);
      _heartbeat?.cancel();
      final onAir = _onAir;
      if (onAir != null) _endQuietly(onAir);
      unawaited(_engine.stop().then((_) {}, onError: (_) {}));
    });
    return const GoLiveState();
  }

  int? _infoSeen;

  /// CP-016 D (§10.18): a tap batch that changes the host's charm level
  /// raises the media room's `roomInfoVersion`; the room is read again so
  /// the room level shows the new level.
  void _watchRoomInfo() {
    final v = _engine.roomInfoVersion;
    final seen = _infoSeen;
    if (_onAir == null || v == null || (seen != null && v <= seen)) return;
    _infoSeen = v;
    unawaited(_refreshRoom());
  }

  /// Failures keep the room as it is; the next version tries again.
  Future<void> _refreshRoom() async {
    final id = _onAir;
    if (id == null) return;
    try {
      final room = await _repo.getRoom(id);
      if (ref.mounted && state.room?.id == id && _onAir == id) {
        state = state.copyWith(room: room);
      }
    } on Object {
      // Kept.
    }
  }

  /// Starts (or retries) the camera and microphone.
  Future<void> startPreview() async {
    state = state.copyWith(phase: GoLivePhase.preparing);
    try {
      var video = state.mode != LiveRoomMode.audio;
      await _engine.startPreview(video: video);
      // The mode may change while the camera starts (Audio tapped while
      // preparing): follow it, so an audio room never keeps a camera.
      while (ref.mounted && (state.mode != LiveRoomMode.audio) != video) {
        video = state.mode != LiveRoomMode.audio;
        await _engine.startPreview(video: video);
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: GoLivePhase.preview,
        frontCamera: _engine.frontCamera,
      );
    } on LiveCaptureException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: GoLivePhase.captureFailed,
        capture: e.problem,
      );
    }
  }

  /// CP-011: switches the mode before going live; an audio room needs no
  /// camera, so the camera stops (or starts again).
  Future<void> setMode(LiveRoomMode mode) async {
    if (state.phase != GoLivePhase.preview &&
        state.phase != GoLivePhase.captureFailed &&
        state.phase != GoLivePhase.preparing) {
      return;
    }
    if (mode == state.mode) return;
    final wasPreview = state.phase == GoLivePhase.preview;
    final cameraChanges =
        (mode == LiveRoomMode.audio) != (state.mode == LiveRoomMode.audio);
    state = state.copyWith(mode: mode);
    if (wasPreview && cameraChanges) {
      try {
        await _engine.startPreview(video: mode != LiveRoomMode.audio);
      } on LiveCaptureException catch (e) {
        if (!ref.mounted) return;
        state = state.copyWith(
          phase: GoLivePhase.captureFailed,
          capture: e.problem,
        );
      }
    }
  }

  /// The seat count of the current mode (before going live), or of the
  /// room (while live: `PATCH /live/rooms/{id}`, throws an `AppFailure`).
  Future<void> setSeatCount(int count) async {
    final room = state.room;
    if (state.phase == GoLivePhase.live && room != null) {
      final updated = await _repo.updateRoom(room.id, seatCount: count);
      if (!ref.mounted) return;
      state = state.copyWith(room: updated);
      return;
    }
    state = state.mode == LiveRoomMode.audio
        ? state.copyWith(audioSeats: count)
        : state.copyWith(multiSeats: count);
  }

  /// The room theme (before going live, or `PATCH` while live).
  Future<void> setTheme(String theme) async {
    final room = state.room;
    if (state.phase == GoLivePhase.live && room != null) {
      final updated = await _repo.updateRoom(room.id, theme: theme);
      if (!ref.mounted) return;
      state = state.copyWith(room: updated, theme: updated.theme);
      return;
    }
    state = state.copyWith(theme: theme);
  }

  /// CP-014: while live, the title, the category (`null`: none) and the
  /// topic (`null`: none); a field left out keeps its value. Throws an
  /// `AppFailure`.
  Future<void> editInfo({
    String? title,
    Object? categorySlug = _keep,
    Object? topic = _keep,
  }) async {
    final room = state.room;
    if (state.phase != GoLivePhase.live || room == null) return;
    final updated = await _repo.editRoom(
      room.id,
      title: title ?? room.title,
      categorySlug: identical(categorySlug, _keep)
          ? room.category?.slug
          : categorySlug as String?,
      topic: identical(topic, _keep) ? room.topic : topic as String?,
    );
    if (!ref.mounted) return;
    state = state.copyWith(room: updated);
  }

  /// Voice processing (D94), before and while live.
  Future<void> setVoice({bool? noiseReduction, bool? enhance}) async {
    state = state.copyWith(
      noiseReduction: noiseReduction,
      voiceEnhance: enhance,
    );
    await _engine.setVoice(
      noiseReduction: state.noiseReduction,
      enhance: state.voiceEnhance,
    );
  }

  /// Beauty on the camera (D94), before and while live.
  Future<void> setBeauty(LiveBeauty beauty) async {
    state = state.copyWith(beauty: beauty);
    await _engine.setBeauty(beauty);
  }

  Future<void> flipCamera() async {
    await _engine.flipCamera();
    if (!ref.mounted) return;
    state = state.copyWith(frontCamera: _engine.frontCamera);
  }

  Future<void> toggleMic() async {
    final enabled = !state.micEnabled;
    await _engine.setMicEnabled(enabled: enabled);
    if (!ref.mounted) return;
    state = state.copyWith(micEnabled: enabled);
  }

  /// Before going live: local. While live: `PATCH /live/rooms/{id}`
  /// (throws an `AppFailure`; the switch is unchanged then).
  Future<void> setAllowGuests({required bool allow}) async {
    final room = state.room;
    if (state.phase != GoLivePhase.live || room == null) {
      state = state.copyWith(allowGuests: allow);
      return;
    }
    final updated = await _repo.setAllowGuests(room.id, allow: allow);
    if (!ref.mounted) return;
    state = state.copyWith(room: updated, allowGuests: updated.allowGuests);
  }

  /// Goes live. Throws an `AppFailure` and returns to the preview when the
  /// room, the token or publishing fails (a room already created is ended
  /// so it does not linger until the heartbeat timeout).
  Future<void> goLive({required String title, String? categorySlug}) async {
    if (state.phase != GoLivePhase.preview) return;
    state = state.copyWith(phase: GoLivePhase.starting);
    // On air the session outlives the screen (minimized, owner D94).
    _alive ??= ref.keepAlive();
    LiveRoom? room;
    try {
      final config = await _repo.getConfig();
      // The count sent is the one previewed: a count the server no longer
      // allows moves to the next allowed one first (as D103 moved rooms).
      final allowed = switch (state.mode) {
        LiveRoomMode.audio => config.seatCounts.audio,
        LiveRoomMode.multi => config.seatCounts.multi,
        LiveRoomMode.solo || LiveRoomMode.pk => const <int>[],
      };
      if (state.seatCount case final count?
          when fitSeatCount(count, allowed) != count) {
        final fitted = fitSeatCount(count, allowed);
        state = state.mode == LiveRoomMode.audio
            ? state.copyWith(audioSeats: fitted)
            : state.copyWith(multiSeats: fitted);
      }
      room = await _repo.startRoom(
        title: title,
        categorySlug: categorySlug,
        allowGuests: state.allowGuests,
        mode: state.mode,
        seatCount: state.seatCount,
        theme: state.mode.hasSeats ? state.theme : null,
      );
      _onAir = room.id;
      if (ref.mounted) state = state.copyWith(room: room);
      final access = await _repo.mediaToken(room.id);
      // An audio room's media token allows the microphone only (CP-011): a
      // camera left running would be refused and the publish would fail.
      if (state.mode == LiveRoomMode.audio && _engine.videoEnabled) {
        await _engine.startPreview(video: false);
      }
      await _engine.publish(access);
      if (!ref.mounted) return;
      state = state.copyWith(phase: GoLivePhase.live, liveSince: clock.now());
      _heartbeat = Timer.periodic(
        Duration(seconds: config.heartbeatIntervalSeconds),
        (_) => unawaited(_beat()),
      );
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (room != null && _onAir == room.id) {
        _onAir = null;
        _endQuietly(room.id);
      }
      if (ref.mounted) {
        state = GoLiveState(
          phase: GoLivePhase.preview,
          frontCamera: state.frontCamera,
          micEnabled: state.micEnabled,
          allowGuests: state.allowGuests,
          mode: state.mode,
          multiSeats: state.multiSeats,
          audioSeats: state.audioSeats,
          theme: state.theme,
          beauty: state.beauty,
          noiseReduction: state.noiseReduction,
          voiceEnhance: state.voiceEnhance,
        );
      }
      _release();
      throw failure;
    }
  }

  Future<void> _beat() async {
    final room = state.room;
    if (room == null || state.phase != GoLivePhase.live) return;
    try {
      await _repo.heartbeat(room.id);
    } on Object catch (e) {
      // The room was ended elsewhere (timeout, admin, suspension): stop.
      // Anything else is transient; the next beat retries.
      if (toAppFailure(e).code == ErrorCode.liveRoomEnded && ref.mounted) {
        _onAir = null;
        await _finish();
      }
    }
  }

  /// Ends the live (`POST /live/rooms/{id}/end`, idempotent). The camera
  /// stops whatever the server answers.
  Future<void> end() async {
    final room = state.room;
    if (room == null || state.phase != GoLivePhase.live) return;
    state = state.copyWith(phase: GoLivePhase.ending);
    _heartbeat?.cancel();
    LiveRoom? ended;
    try {
      ended = await _repo.endRoom(room.id);
      _onAir = null;
    } on Object {
      // The room times out on its own once heartbeats stop.
    }
    if (!ref.mounted) return;
    await _finish(ended);
  }

  void _endQuietly(String roomId) =>
      unawaited(_repo.endRoom(roomId).then((_) {}, onError: (_) {}));

  /// Lets the session go once it is over (the screen may be gone).
  void _release() {
    _alive?.close();
    _alive = null;
  }

  Future<void> _finish([LiveRoom? ended]) async {
    _heartbeat?.cancel();
    await _engine.stop();
    if (!ref.mounted) return;
    state = state.copyWith(
      phase: GoLivePhase.ended,
      room: ended,
      endedAt: clock.now(),
    );
    _release();
  }
}

final NotifierProvider<LiveHostController, GoLiveState>
liveHostControllerProvider =
    NotifierProvider.autoDispose<LiveHostController, GoLiveState>(
      LiveHostController.new,
    );

/// `GET /live/config` for the go-live screen.
final FutureProvider<LiveConfig> liveConfigProvider =
    FutureProvider.autoDispose<LiveConfig>(
      (ref) => ref.watch(liveRepositoryProvider).getConfig(),
    );

/// `GET /live/categories` for the go-live screen.
final FutureProvider<List<LiveCategory>> liveCategoriesProvider =
    FutureProvider.autoDispose<List<LiveCategory>>(
      (ref) => ref.watch(liveRepositoryProvider).listCategories(),
    );

/// CP-011: a room's seats, refreshed every 5 seconds while watched.
final FutureProviderFamily<LiveSeats, String> liveSeatsProvider = FutureProvider
    .autoDispose
    .family<LiveSeats, String>((ref, roomId) {
      final timer = Timer(const Duration(seconds: 5), ref.invalidateSelf);
      ref.onDispose(timer.cancel);
      return ref.watch(liveRepositoryProvider).seats(roomId);
    });

/// The first page of viewers (`GET /live/rooms/{id}/viewers`) for the
/// room's avatars and count, refreshed every 10 seconds: the host's audio
/// room and, D109 (v1.23.2-live), every viewer's room screen.
final FutureProviderFamily<({List<LiveViewer> items, String? next}), String>
liveViewersPreviewProvider = FutureProvider.autoDispose
    .family<({List<LiveViewer> items, String? next}), String>((ref, roomId) {
      final timer = Timer(const Duration(seconds: 10), ref.invalidateSelf);
      ref.onDispose(timer.cancel);
      return ref.watch(liveRepositoryProvider).viewers(roomId);
    });

/// Whether the host minimized their live into the floating window (owner
/// D94): the live goes on while they use the app.
class LiveMinimized extends Notifier<bool> {
  @override
  bool build() => false;

  void minimize() => state = true;

  void restore() => state = false;
}

final NotifierProvider<LiveMinimized, bool> liveMinimizedProvider =
    NotifierProvider<LiveMinimized, bool>(LiveMinimized.new);

/// [LiveHostController.editInfo]: the field keeps its value.
const Object _keep = Object();
