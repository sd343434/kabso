import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show FutureProviderFamily, KeepAliveLink;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/beauty/live_color_filter.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_permissions.dart';
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
    this.wishGifts,
    this.fillLight = false,
  });

  /// D143 fill light, kept for this go-live (setup and on air): the front
  /// camera lights the face with the screen (a warm frame), the back
  /// camera with its torch.
  final bool fillLight;

  /// D136: the wish list picked before going live (sent once the room
  /// exists); null: the server keeps the host's last live's list.
  final List<String>? wishGifts;

  /// D94 voice settings (audio rooms, and the microphone in every mode).
  final bool noiseReduction;
  final bool voiceEnhance;

  /// CP-011: SOLO (LIVE), MULTI (multi-guest) or AUDIO.
  final LiveRoomMode mode;

  /// The seat count chosen for each mode (host tile included).
  final int multiSeats;
  final int audioSeats;

  /// The counts a new room starts with: MULTI 6 (D94), AUDIO 10 (owner,
  /// 2026-10-26; D103/D123 allow 5, 10, 15, 20 — the old default 9 was
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
    List<String>? wishGifts,
    bool? fillLight,
  }) => GoLiveState(
    fillLight: fillLight ?? this.fillLight,
    wishGifts: wishGifts ?? this.wishGifts,
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

/// D144a: the screen's rationale before the system's camera/microphone
/// prompt; true when the person goes on ([camera] false: microphone only).
typedef LivePermissionPrompt = Future<bool> Function({required bool camera});

/// The go-live flow (CP-010 L1): camera preview → `POST /live/rooms` →
/// media token → publish → heartbeats at the server's interval → end.
///
/// On air the session outlives the screen (minimized) and the app (D123:
/// a foreground service keeps it, and the heartbeats, running in the
/// background; nothing ends on a lifecycle change). Disposing the session
/// while live ends the room (best effort) and always turns the camera and
/// microphone off.
class LiveHostController extends Notifier<GoLiveState> {
  late LiveMediaEngine _engine;
  late LiveRepository _repo;
  late LivePermissions _permissions;
  Timer? _heartbeat;
  KeepAliveLink? _alive;
  late LiveBackgroundKeeper _keeper;

  /// The room on air (created and not yet ended by this screen).
  String? _onAir;

  /// The engine whose picture the screen shows.
  LiveMediaEngine get engine => _engine;

  @override
  GoLiveState build() {
    _engine = ref.read(liveMediaEngineProvider)();
    _repo = ref.read(liveRepositoryProvider);
    _permissions = ref.read(livePermissionsProvider);
    _keeper = ref.read(liveBackgroundKeeperProvider);
    _engine.changes.addListener(_watchRoomInfo);
    _engine.arStatus.addListener(_watchArStatus);
    ref.onDispose(() {
      _engine.changes.removeListener(_watchRoomInfo);
      _engine.arStatus.removeListener(_watchArStatus);
      _keeper.release(this);
      _heartbeat?.cancel();
      final onAir = _onAir;
      if (onAir != null) _endQuietly(onAir);
      unawaited(_engine.stop().then((_) {}, onError: (_) {}));
    });
    return const GoLiveState();
  }

  int? _infoSeen;

  /// D144a: DeepAR switched the picked effect off on the device (it stopped
  /// giving new pictures, the licence was refused, it did not start). Magic
  /// shows None selected again — the picture is the plain camera — and says
  /// why ([LiveMediaEngine.arStatus]); picking the effect again retries.
  void _watchArStatus() {
    if (_engine.arStatus.value.state != LiveArState.unavailable) return;
    if (state.beauty.effect == LiveArEffect.none) return;
    final beauty = state.beauty.copyWith(effect: LiveArEffect.none);
    state = state.copyWith(beauty: beauty);
    unawaited(_engine.setBeauty(beauty).then((_) {}, onError: (_) {}));
  }

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
  ///
  /// D144a: permissions first — granted: start; never asked or refused once:
  /// [explain] (the screen's rationale sheet) and, if the person goes on, the
  /// system prompt once; refused for good: [LiveCaptureProblem.blocked]
  /// (the screen offers the app's settings). An audio room asks for the
  /// microphone only.
  Future<void> startPreview({LivePermissionPrompt? explain}) async {
    state = state.copyWith(phase: GoLivePhase.preparing);
    if (!await _ensurePermission(
      camera: state.mode != LiveRoomMode.audio,
      explain: explain,
    )) {
      return;
    }
    if (!ref.mounted) return;
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

  /// D144a: whether the capture may start; else the phase says why.
  Future<bool> _ensurePermission({
    required bool camera,
    LivePermissionPrompt? explain,
  }) async {
    var permission = await _permissions.check(camera: camera);
    if (!ref.mounted) return false;
    if (permission.canStart) return true;
    if (permission != LivePermission.blocked) {
      // Explain first; nothing is asked if the person does not go on.
      if (explain != null && !await explain(camera: camera)) {
        if (ref.mounted) _refused(LiveCaptureProblem.denied);
        return false;
      }
      permission = await _permissions.request(camera: camera);
      if (!ref.mounted) return false;
      if (permission.canStart) return true;
    }
    _refused(
      permission == LivePermission.blocked
          ? LiveCaptureProblem.blocked
          : LiveCaptureProblem.denied,
    );
    return false;
  }

  void _refused(LiveCaptureProblem problem) => state = state.copyWith(
    phase: GoLivePhase.captureFailed,
    capture: problem,
  );

  /// D144a: back from the system settings (the app resumed): starts the
  /// capture if access is now allowed. Nothing is asked.
  Future<void> recheckPermission() async {
    if (state.phase != GoLivePhase.captureFailed ||
        (state.capture != LiveCaptureProblem.blocked &&
            state.capture != LiveCaptureProblem.denied)) {
      return;
    }
    final permission = await _permissions.check(
      camera: state.mode != LiveRoomMode.audio,
    );
    if (!ref.mounted || permission != LivePermission.granted) return;
    await startPreview();
  }

  /// D144a: «فتح الإعدادات» — this app's page in the system settings.
  Future<bool> openPermissionSettings() => _permissions.openSettings();

  /// CP-011: switches the mode before going live; an audio room needs no
  /// camera, so the camera stops (or starts again).
  ///
  /// D144a: from an audio room to a video one the camera may still need
  /// asking for ([explain], as in [startPreview]).
  Future<void> setMode(
    LiveRoomMode mode, {
    LivePermissionPrompt? explain,
  }) async {
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
      if (mode != LiveRoomMode.audio &&
          !await _ensurePermission(camera: true, explain: explain)) {
        return;
      }
      if (!ref.mounted) return;
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

  /// D136: the wish list (before going live it is kept and sent once the
  /// room exists; while live `PATCH`). Throws an `AppFailure`.
  Future<void> setWishGifts(List<String> codes) async {
    final room = state.room;
    if (state.phase == GoLivePhase.live && room != null) {
      final updated = await _repo.setWishGifts(room.id, codes);
      if (!ref.mounted) return;
      state = state.copyWith(room: updated, wishGifts: codes);
      return;
    }
    state = state.copyWith(wishGifts: codes);
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

  /// D143: Magic's colour filter, on the published picture (where the
  /// device has a camera pipeline: [LiveMediaEngine.filtersSupported]).
  Future<void> setColorFilter(LiveColorFilter filter) =>
      setBeauty(state.beauty.copyWith(filter: filter));

  /// D144: Magic's AR effect (DeepAR), on the published picture (where
  /// [LiveMediaEngine.arEffects] is ready).
  Future<void> setArEffect(LiveArEffect effect) =>
      setBeauty(state.beauty.copyWith(effect: effect));

  /// D143 fill light. The front camera: the screen's warm frame (nothing to
  /// ask the device). The back camera: its torch — `false` (and the light
  /// stays off) when it has none. Off turns the torch off too.
  Future<bool> setFillLight({required bool on}) async {
    if (!on) {
      state = state.copyWith(fillLight: false);
      if (!_engine.frontCamera) await _torch(on: false);
      return true;
    }
    if (_engine.frontCamera) {
      state = state.copyWith(fillLight: true);
      return true;
    }
    if (!await _torch(on: true)) return false;
    if (!ref.mounted) return false;
    state = state.copyWith(fillLight: true);
    return true;
  }

  /// Best effort: whether the torch is now [on].
  Future<bool> _torch({required bool on}) async {
    try {
      if (on && !await _engine.hasTorch()) return false;
      await _engine.setTorch(on: on);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> flipCamera() async {
    // The fill light follows the camera: torch off before leaving the back
    // camera, on again after reaching it (a camera without one turns the
    // light off rather than pretend).
    if (state.fillLight && !_engine.frontCamera) await _torch(on: false);
    await _engine.flipCamera();
    if (!ref.mounted) return;
    var fillLight = state.fillLight;
    if (fillLight && !_engine.frontCamera) {
      fillLight = await _torch(on: true);
      if (!ref.mounted) return;
    }
    state = state.copyWith(
      frontCamera: _engine.frontCamera,
      fillLight: fillLight,
    );
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
  ///
  /// [background] words the ongoing notification that keeps the live
  /// running while the app is in the background (D123).
  Future<void> goLive({
    required String title,
    String? categorySlug,
    LiveBackgroundTexts? background,
  }) async {
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
      // D136: the wish list picked in the setup.
      if (state.wishGifts case final wishes?) {
        // The live goes on without it if this fails; the host can set it
        // again.
        final wished = await _repo
            .setWishGifts(room.id, wishes)
            .then<LiveRoom?>((r) => r, onError: (Object _) => null);
        if (wished != null) room = wished;
      }
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
      if (background != null) _holdBackground(background);
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
          wishGifts: state.wishGifts,
        );
      }
      _release();
      throw failure;
    }
  }

  /// D123: the live keeps running while the app is away. The camera pauses
  /// there (Android blocks it; the microphone goes on) and resumes on
  /// return, when a heartbeat is also sent at once in case the timer was
  /// late. The notification's End ends the live as the ✕ does.
  void _holdBackground(LiveBackgroundTexts texts) {
    final video = state.mode != LiveRoomMode.audio;
    _keeper.hold(
      this,
      LiveBackgroundSpec.of(LiveBackgroundRole.host, texts),
      onEnd: () => unawaited(end()),
      onOpen: () {
        if (ref.mounted && ref.read(liveMinimizedProvider)) {
          ref.read(liveBackgroundOpenRequestsProvider.notifier).request();
        }
      },
      onBackground: video ? () => unawaited(_pauseVideo(paused: true)) : null,
      onForeground: () {
        if (video) unawaited(_pauseVideo(paused: false));
        unawaited(beatNow());
      },
    );
  }

  Future<void> _pauseVideo({required bool paused}) async {
    try {
      await _engine.setVideoPaused(paused: paused);
    } on Object {
      // Best effort: the live goes on.
    }
  }

  /// A heartbeat now (back from the background, D123).
  Future<void> beatNow() => _beat();

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
    _keeper.release(this);
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
