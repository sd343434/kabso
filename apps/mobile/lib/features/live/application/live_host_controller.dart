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
    this.multiSeats = 6,
    this.audioSeats = 9,
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
    ref.onDispose(() {
      _heartbeat?.cancel();
      final onAir = _onAir;
      if (onAir != null) _endQuietly(onAir);
      unawaited(_engine.stop().then((_) {}, onError: (_) {}));
    });
    return const GoLiveState();
  }

  /// Starts (or retries) the camera and microphone.
  Future<void> startPreview() async {
    state = state.copyWith(phase: GoLivePhase.preparing);
    try {
      await _engine.startPreview(video: state.mode != LiveRoomMode.audio);
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

/// The host's first page of viewers (`GET /live/rooms/{id}/viewers`) for
/// the audio room's avatars and count, refreshed every 10 seconds.
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
