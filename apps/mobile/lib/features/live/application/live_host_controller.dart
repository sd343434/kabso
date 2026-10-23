import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
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
  });

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
  }) => GoLiveState(
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
    state = GoLiveState(
      allowGuests: state.allowGuests,
      micEnabled: state.micEnabled,
    );
    try {
      await _engine.startPreview();
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
    LiveRoom? room;
    try {
      final config = await _repo.getConfig();
      room = await _repo.startRoom(
        title: title,
        categorySlug: categorySlug,
        allowGuests: state.allowGuests,
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
        );
      }
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

  Future<void> _finish([LiveRoom? ended]) async {
    _heartbeat?.cancel();
    await _engine.stop();
    if (!ref.mounted) return;
    state = state.copyWith(
      phase: GoLivePhase.ended,
      room: ended,
      endedAt: clock.now(),
    );
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
