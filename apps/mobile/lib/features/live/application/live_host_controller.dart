import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show FutureProviderFamily, KeepAliveLink;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_streamer_host.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/beauty/live_color_filter.dart';
import 'package:kabso_live/features/live/data/beauty/live_fx_engine.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_permissions.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_theme_art.dart';

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
    this.fillLightLevel = LiveFillLight.medium,
    this.podcast = const PodcastSetup(topic: PodcastTopic.business),
    this.podcastGuests = const [],
    this.cameraOff = false,
  });

  /// D225 (owner): the host turned their camera off on air (the video track
  /// is muted; the others see the host's picture). The return from the
  /// background does not turn it on again.
  final bool cameraOff;

  /// D212: the podcast setup (topic, hands, question time), sent with a
  /// PODCAST room.
  final PodcastSetup podcast;

  /// D212: up to 3 guests the host picked; each is invited onto a speaker
  /// seat once they are in the live.
  final List<UserSummary> podcastGuests;

  /// D143 fill light, kept for this go-live (setup and on air): the front
  /// camera lights the face — D157: a soft exposure lift with a warm tint on
  /// the published picture ([fillLightLevel], carried in [beauty]`.light`),
  /// or a thin glow at the screen's edges where the device has no camera
  /// pipeline — the back camera with its torch.
  final bool fillLight;

  /// D157: how strong the front camera's fill light is (never
  /// [LiveFillLight.off]; off is [fillLight] false).
  final LiveFillLight fillLightLevel;

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
    // D212: a podcast's count is the server's (4).
    LiveRoomMode.solo ||
    LiveRoomMode.pk ||
    LiveRoomMode.podcast ||
    LiveRoomMode.streamer => null,
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
    LiveFillLight? fillLightLevel,
    PodcastSetup? podcast,
    List<UserSummary>? podcastGuests,
    bool? cameraOff,
  }) => GoLiveState(
    cameraOff: cameraOff ?? this.cameraOff,
    podcast: podcast ?? this.podcast,
    podcastGuests: podcastGuests ?? this.podcastGuests,
    fillLight: fillLight ?? this.fillLight,
    fillLightLevel: fillLightLevel ?? this.fillLightLevel,
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

/// D210: the step of going live that failed and what it failed with — the
/// «تفاصيل» line under the generic error, so a device report names it.
/// Never a message (it may carry a URL or a token): the step and the error
/// type or the server's error code only.
class LiveStartFailure {
  const new(this.stage, this.kind);

  /// [error] at [stage]; a [LivePublishException] names its own step.
  factory of(String stage, Object error) {
    if (error is LivePublishException) {
      return LiveStartFailure.of(error.stage.name, error.cause);
    }
    final failure = toAppFailure(error);
    final kind = failure is UnexpectedFailure
        ? error.runtimeType.toString()
        : failure.code.wire;
    return LiveStartFailure(stage, kind);
  }

  /// `config`, `room`, `token`, `camera`, `publish`, or the publish's own
  /// step: `connect`, `video`, `audio`.
  final String stage;

  /// The server's error code, or the exception's type.
  final String kind;

  /// What the screen shows, e.g. `GL-video:TrackPublishException`.
  String get code => 'GL-$stage:$kind';

  @override
  String toString() => code;
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

  /// D213: the streamer session of this go-live (set while it is on).
  LiveStreamerHost? _streamer;

  /// D210: why the last go-live failed (null once one succeeds).
  LiveStartFailure? get lastStartFailure => _startFailure;
  LiveStartFailure? _startFailure;

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
      // D213: FLAG_SECURE and the game sound never outlive the session.
      unawaited(_streamer?.finish().then((_) {}, onError: (_) {}));
      unawaited(_engine.stop().then((_) {}, onError: (_) {}));
    });
    return const GoLiveState();
  }

  int? _infoSeen;

  /// D144a: DeepAR switched the picked effect off on the device (it stopped
  /// giving new pictures, the licence was refused, it did not start). Magic
  /// shows None selected again — the picture is the plain camera — and says
  /// why ([LiveMediaEngine.arStatus]); picking the effect again retries.
  ///
  /// D228: the free engine likewise switches its beauty off (the sliders
  /// keep their values for the next try).
  void _watchArStatus() {
    if (_engine.arStatus.value.state != LiveArState.unavailable) return;
    final freeOn = state.beauty.free.on;
    if (state.beauty.effect == LiveArEffect.none && !freeOn) return;
    final beauty = state.beauty.copyWith(
      effect: LiveArEffect.none,
      free: state.beauty.free.copyWith(on: false),
    );
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
      camera: !state.mode.isVoice,
      explain: explain,
    )) {
      return;
    }
    if (!ref.mounted) return;
    try {
      var video = !state.mode.isVoice;
      await _engine.startPreview(video: video);
      // The mode may change while the camera starts (Audio tapped while
      // preparing): follow it, so an audio room never keeps a camera.
      while (ref.mounted && (!state.mode.isVoice) != video) {
        video = !state.mode.isVoice;
        await _engine.startPreview(video: video);
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: GoLivePhase.preview,
        frontCamera: _engine.frontCamera,
      );
      await _syncLight();
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
    final permission = await _permissions.check(camera: !state.mode.isVoice);
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
    final cameraChanges = mode.isVoice != (state.mode.isVoice);
    // D212: a podcast starts on the owner's podcast background; leaving the
    // podcast takes its background back to the classic one.
    final podcastTheme = LiveThemeArt.of(state.theme).podcast;
    final theme = mode == LiveRoomMode.podcast && !podcastTheme
        ? LiveThemeArt.podcastDefault
        : mode != LiveRoomMode.podcast && podcastTheme
        ? LiveThemes.classic
        : state.theme;
    state = state.copyWith(mode: mode, theme: theme);
    if (wasPreview && cameraChanges) {
      if (!mode.isVoice &&
          !await _ensurePermission(camera: true, explain: explain)) {
        return;
      }
      if (!ref.mounted) return;
      try {
        await _engine.startPreview(video: !mode.isVoice);
      } on LiveCaptureException catch (e) {
        if (!ref.mounted) return;
        state = state.copyWith(
          phase: GoLivePhase.captureFailed,
          capture: e.problem,
        );
      }
    }
  }

  /// D212: the podcast setup before going live (topic, hands, question
  /// time); while live the hands and the time go through
  /// [setPodcastSettings].
  void setPodcastSetup(PodcastSetup setup) {
    if (state.phase == GoLivePhase.live) return;
    state = state.copyWith(podcast: setup);
  }

  /// D212: the guests picked in the setup (up to 3).
  void setPodcastGuests(List<UserSummary> guests) {
    state = state.copyWith(podcastGuests: guests.take(3).toList());
  }

  /// D212: while live, the hands switch and/or the question time (`PATCH`;
  /// throws an `AppFailure`). [seconds] returns the new time (null inside
  /// = no limit); null = unchanged.
  Future<void> setPodcastSettings({
    bool? questionsOpen,
    int? Function()? seconds,
  }) async {
    final room = state.room;
    if (room == null) return;
    final updated = await _repo.setPodcastSettings(
      room.id,
      questionsOpen: questionsOpen,
      setQuestionSeconds: seconds != null,
      questionSeconds: seconds?.call(),
    );
    if (!ref.mounted) return;
    state = state.copyWith(room: updated);
  }

  /// D212: the guests picked in the setup who were invited this live.
  final Set<String> _invitedGuests = {};

  /// D212: invites each picked guest onto a speaker seat once they are in
  /// the live ([present]: the user ids watching now). Best effort: a
  /// refused invitation (a full stage, a block) is not retried.
  Future<void> inviteArrivedGuests(Set<String> present) async {
    final room = state.room;
    if (room == null || state.mode != LiveRoomMode.podcast) return;
    for (final g in state.podcastGuests) {
      if (!present.contains(g.id) || !_invitedGuests.add(g.id)) continue;
      try {
        await _repo.inviteToSeat(room.id, g.username);
      } on Object catch (e) {
        AppLogger.error('live: podcast guest invite failed', e);
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
    state = state.mode.isVoice
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
    // The fill light is the controller's to set (D157), never the sheet's.
    final withLight = beauty.copyWith(light: _effectiveLight);
    state = state.copyWith(beauty: withLight);
    await _engine.setBeauty(withLight);
  }

  /// D157: the light on the published picture — the front camera's fill
  /// light at its level; off otherwise (the back camera has its torch).
  LiveFillLight get _effectiveLight => state.fillLight && _engine.frontCamera
      ? state.fillLightLevel
      : LiveFillLight.off;

  /// Sends the fill light to the camera pipeline when it changed.
  Future<void> _syncLight() async {
    if (state.beauty.light == _effectiveLight) return;
    await setBeauty(state.beauty);
  }

  /// D143: Magic's colour filter, on the published picture (where the
  /// device has a camera pipeline: [LiveMediaEngine.filtersSupported]).
  Future<void> setColorFilter(LiveColorFilter filter) =>
      setBeauty(state.beauty.copyWith(filter: filter));

  /// D144: Magic's AR effect (DeepAR), on the published picture (where
  /// [LiveMediaEngine.arEffects] is ready).
  Future<void> setArEffect(LiveArEffect effect) =>
      setBeauty(state.beauty.copyWith(effect: effect));

  /// D228: the free effects engine's beauty (Magic's sliders), on the
  /// published picture while that engine runs.
  Future<void> setFreeBeauty(LiveFreeBeauty free) =>
      setBeauty(state.beauty.copyWith(free: free));

  /// D228: the effects engine (the server's `cameraFxEngine`, or the debug
  /// override). The picked effect and beauty carry over to it.
  Future<void> setFxEngine(LiveFxEngine engine) async {
    if (_engine.fxEngine == engine) return;
    await _engine.setFxEngine(engine);
  }

  /// D143 fill light. The front camera (D157): a soft exposure lift with a
  /// warm tint at [level] (or the last level) on the published picture.
  /// The back camera: its torch — `false` (and the light stays off) when it
  /// has none. Off turns the torch off too.
  Future<bool> setFillLight({required bool on, LiveFillLight? level}) async {
    if (!on || level == LiveFillLight.off) {
      state = state.copyWith(fillLight: false);
      if (!_engine.frontCamera) await _torch(on: false);
      await _syncLight();
      return true;
    }
    if (_engine.frontCamera) {
      state = state.copyWith(
        fillLight: true,
        fillLightLevel: level ?? state.fillLightLevel,
      );
      await _syncLight();
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
    await _syncLight();
  }

  /// D225: the host's camera off or on while live (a video live). The
  /// published camera track is muted (as a seated guest's, D174a, and the
  /// background pause, D123): nothing new on the server.
  Future<void> setCameraOff({required bool off}) async {
    if (state.mode.isVoice) return;
    // D213: a streamer's camera is the bubble (shown / hidden for everyone).
    if (state.mode == LiveRoomMode.streamer) {
      await ref
          .read(liveStreamerHostProvider.notifier)
          .setCameraVisible(visible: !off);
      if (ref.mounted) state = state.copyWith(cameraOff: off);
      _refreshStreamerNotice();
      return;
    }
    await _engine.setVideoPaused(paused: off);
    if (!ref.mounted) return;
    state = state.copyWith(cameraOff: off);
  }

  Future<void> toggleMic() async {
    final enabled = !state.micEnabled;
    // D213: on air a streamer's voice is muted in the mixer (the game sound
    // goes on in the same track).
    if (state.mode == LiveRoomMode.streamer &&
        state.phase == GoLivePhase.live) {
      await ref
          .read(liveStreamerHostProvider.notifier)
          .setMicMuted(muted: !enabled);
    } else {
      await _engine.setMicEnabled(enabled: enabled);
    }
    if (!ref.mounted) return;
    state = state.copyWith(micEnabled: enabled);
    _refreshStreamerNotice();
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
    _startFailure = null;
    LiveRoom? room;
    var stage = 'config';
    final LiveConfig config;
    // D213: a streamer (the screen asked consent for its capture first).
    final streamer = state.mode == LiveRoomMode.streamer
        ? ref.read(liveStreamerHostProvider.notifier)
        : null;
    _streamer = streamer;
    try {
      // D213 (Android 14): the foreground service gains the
      // `mediaProjection` type after the consent and before the capture.
      if (streamer != null && background != null) {
        stage = 'service';
        _holdBackground(background);
        await _keeper.settled;
      }
      config = await _repo.getConfig();
      // The count sent is the one previewed: a count the server no longer
      // allows moves to the next allowed one first (as D103 moved rooms).
      final allowed = switch (state.mode) {
        LiveRoomMode.audio => config.seatCounts.audio,
        LiveRoomMode.multi => config.seatCounts.multi,
        LiveRoomMode.solo ||
        LiveRoomMode.pk ||
        LiveRoomMode.podcast ||
        LiveRoomMode.streamer => const <int>[],
      };
      if (state.seatCount case final count?
          when fitSeatCount(count, allowed) != count) {
        final fitted = fitSeatCount(count, allowed);
        state = state.mode.isVoice
            ? state.copyWith(audioSeats: fitted)
            : state.copyWith(multiSeats: fitted);
      }
      stage = 'room';
      room = await _repo.startRoom(
        title: title,
        categorySlug: categorySlug,
        allowGuests: state.allowGuests,
        mode: state.mode,
        seatCount: state.seatCount,
        theme: state.mode.hasSeats ? state.theme : null,
        podcast: state.mode == LiveRoomMode.podcast ? state.podcast : null,
        // D213: the bubble as set up (the capture consent was given).
        streamer: streamer?.state.startLayout,
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
      stage = 'token';
      final access = await _repo.mediaToken(room.id);
      // An audio room's media token allows the microphone only (CP-011): a
      // camera left running would be refused and the publish would fail.
      stage = 'camera';
      if (state.mode.isVoice && _engine.videoEnabled) {
        await _engine.startPreview(video: false);
      }
      // The core of going live: joining the media room and publishing the
      // camera and the microphone. Only these may fail it (D210).
      stage = 'publish';
      await _engine.publish(access);
      // D213: then the phone screen (and the game sound).
      if (streamer != null) {
        stage = 'screen';
        await streamer.begin(
          engine: _engine,
          room: room,
          micOn: state.micEnabled,
        );
      }
      if (!ref.mounted) return;
      state = state.copyWith(phase: GoLivePhase.live, liveSince: clock.now());
    } on Object catch (e, stack) {
      final failure = toAppFailure(e);
      final why = LiveStartFailure.of(stage, e);
      _startFailure = why;
      AppLogger.error('live: go-live failed ($why)', e, stack);
      if (room != null && _onAir == room.id) {
        _onAir = null;
        _endQuietly(room.id);
      }
      if (streamer != null) {
        _keeper.release(this);
        await streamer.finish();
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
          fillLight: state.fillLight,
          fillLightLevel: state.fillLightLevel,
          podcast: state.podcast,
          podcastGuests: state.podcastGuests,
        );
      }
      _release();
      throw failure;
    }
    // D210: on air. What follows is optional — it never ends the live.
    try {
      _heartbeat = Timer.periodic(
        Duration(seconds: config.heartbeatIntervalSeconds),
        (_) => unawaited(_beat()),
      );
    } on Object catch (e) {
      AppLogger.warning('live: heartbeat timer not started (${e.runtimeType})');
    }
    if (background != null && streamer == null) {
      try {
        _holdBackground(background);
      } on Object catch (e) {
        // The live goes on in the foreground.
        AppLogger.warning('live: background keeper off (${e.runtimeType})');
      }
    }
  }

  /// D123: the live keeps running while the app is away. The camera pauses
  /// there (Android blocks it; the microphone goes on) and resumes on
  /// return, when a heartbeat is also sent at once in case the timer was
  /// late. The notification's End ends the live as the ✕ does.
  void _holdBackground(LiveBackgroundTexts texts) {
    _texts = texts;
    // D213: a streamer is never paused in the background — the game is the
    // point; it is paused while Kabso is in front instead.
    if (state.mode == LiveRoomMode.streamer) {
      _holdStreamer(texts);
      return;
    }
    final video = !state.mode.isVoice;
    _keeper.hold(
      this,
      LiveBackgroundSpec.of(LiveBackgroundRole.host, texts),
      onEnd: () => unawaited(end()),
      onOpen: () {
        if (ref.mounted && ref.read(liveMinimizedProvider)) {
          ref.read(liveBackgroundOpenRequestsProvider.notifier).request();
        }
      },
      onBackground: video
          ? () {
              unawaited(_pauseVideo(paused: true));
              unawaited(_reportAway(away: true));
            }
          : null,
      onForeground: () {
        if (video) {
          // D225: a camera the host turned off stays off.
          if (!state.cameraOff) unawaited(_pauseVideo(paused: false));
          unawaited(_reportAway(away: false));
        }
        unawaited(beatNow());
      },
    );
  }

  LiveBackgroundTexts? _texts;

  /// D213: the streamer host's notification: «إنهاء», the microphone and
  /// the camera bubble (their labels follow the state).
  void _holdStreamer(LiveBackgroundTexts texts) {
    final host = ref.read(liveStreamerHostProvider.notifier);
    final mic = state.micEnabled ? texts.micOff : texts.micOn;
    final camera = state.cameraOff ? texts.cameraShow : texts.cameraHide;
    _keeper.hold(
      this,
      LiveBackgroundSpec.of(
        LiveBackgroundRole.host,
        texts,
      ).streamer(mic: mic, camera: camera),
      onEnd: () => unawaited(end()),
      onOpen: () {
        if (ref.mounted && ref.read(liveMinimizedProvider)) {
          ref.read(liveBackgroundOpenRequestsProvider.notifier).request();
        }
      },
      onBackground: () => host.appInFront(front: false),
      onForeground: () {
        host.appInFront(front: true);
        unawaited(beatNow());
      },
      onToggleMic: () => unawaited(toggleMic()),
      onToggleCamera: () => unawaited(setCameraOff(off: !state.cameraOff)),
    );
  }

  /// D213: the notification's toggle labels follow the state.
  void _refreshStreamerNotice() {
    final texts = _texts;
    if (texts == null ||
        state.mode != LiveRoomMode.streamer ||
        !_keeper.holds(this)) {
      return;
    }
    _holdStreamer(texts);
  }

  /// D170: what the server should know (the video host is away, camera
  /// off) and what it last acknowledged; a failed report is sent again
  /// with the next heartbeat.
  bool _awayWanted = false;
  bool _awayAcked = false;
  int _reporting = 0;

  /// D170 (v1.42-live): tells the server the video host is away or back;
  /// a video live away for 5 minutes is ended by the server
  /// (`HOST_AWAY_TIMEOUT`). An audio host is never reported.
  Future<void> _reportAway({required bool away}) async {
    _awayWanted = away;
    final room = state.room;
    if (room == null || state.phase != GoLivePhase.live) return;
    _reporting++;
    try {
      await _repo.setHostPresence(room.id, away: away);
      if (_awayWanted == away) _awayAcked = away;
    } on Object catch (e) {
      // The room ended meanwhile (the away limit, timeout, admin): stop.
      // Anything else is retried with the next heartbeat.
      if (toAppFailure(e).code == ErrorCode.liveRoomEnded &&
          ref.mounted &&
          state.phase == GoLivePhase.live) {
        _onAir = null;
        await _finish();
      }
    } finally {
      _reporting--;
    }
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
      // D261: the chat lines whose data message never reached this phone.
      final chat = liveChatProvider(room.id);
      if (ref.mounted && ref.exists(chat)) {
        unawaited(ref.read(chat.notifier).catchUp());
      }
      // D170: a report that failed (none is under way) is sent again.
      if (_awayWanted != _awayAcked && _reporting == 0) {
        unawaited(_reportAway(away: _awayWanted));
      }
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
    // D213: the screen capture and its native helpers end with the live.
    if (state.mode == LiveRoomMode.streamer) {
      await ref.read(liveStreamerHostProvider.notifier).finish();
    }
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
final FutureProviderFamily<LiveViewersPage, String> liveViewersPreviewProvider =
    FutureProvider.autoDispose.family<LiveViewersPage, String>((ref, roomId) {
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
