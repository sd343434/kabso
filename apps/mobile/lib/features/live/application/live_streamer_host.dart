import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/streamer/live_screen_share.dart';
import 'package:kabso_live/features/live/data/streamer/live_streamer_platform.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';

/// Why the host's screen is paused for viewers now (any of them).
enum StreamerPause {
  /// Kabso itself is in front: viewers never see the host's chat, wallet or
  /// messages (the window is FLAG_SECURE too).
  inApp,

  /// A phone call rings or is on (the caller's name stays private).
  call,

  /// The phone's screen is off.
  screenOff,
}

/// D213: the streamer host's choices and what the phone reports.
@immutable
class StreamerHostState {
  const new({
    this.cameraVisible = true,
    this.corner = StreamerCorner.topLeft,
    this.gameAudioOn = true,
    this.gameMuted = false,
    this.live = false,
    this.layout,
    this.gameAudio,
    this.sdkInt,
    this.pauses = const {StreamerPause.inApp},
    this.stopped = false,
    this.headset,
    this.headsetTipSeen = false,
  });

  /// The camera bubble shown (setup and live).
  final bool cameraVisible;

  /// The bubble's corner of the screen (setup and live).
  final StreamerCorner corner;

  /// Setup: mix the game sound in (Android 10+).
  final bool gameAudioOn;

  /// Live: the game sound muted (the microphone has its own switch).
  final bool gameMuted;

  /// The screen is being streamed.
  final bool live;

  /// The server's layout (live).
  final LiveStreamer? layout;

  /// What became of the game sound (live).
  final StreamerGameAudio? gameAudio;

  /// Android's API level, once known (null elsewhere).
  final int? sdkInt;

  /// Why the screen is paused now (empty: viewers see it).
  final Set<StreamerPause> pauses;

  /// The capture was stopped from the system: the screen is over until the
  /// host shares it again.
  final bool stopped;

  /// A headset is connected (null: not known yet).
  final bool? headset;

  /// On air: the «use headphones» tip was shown and the host went to the
  /// game (it is shown once per live).
  final bool headsetTipSeen;

  bool get paused => pauses.isNotEmpty;

  /// The setup's «use headphones» tip: the game sound is on and no headset
  /// is known to be connected (the speaker's game sound would also reach
  /// the microphone, so viewers would hear it twice).
  bool get headsetTipInSetup =>
      gameAudioOn && gameAudioPossible && headset != true;

  /// The same tip on air, once: until the host first goes to the game.
  bool get headsetTipOnAir =>
      gameAudio == StreamerGameAudio.ok && headset != true && !headsetTipSeen;

  /// Android 10+ can capture the game sound.
  bool get gameAudioPossible => sdkInt == null || sdkInt! >= 29;

  /// The starting layout sent with `POST /live/rooms`.
  LiveStreamer get startLayout =>
      LiveStreamer(cameraVisible: cameraVisible, corner: corner);

  StreamerHostState copyWith({
    bool? cameraVisible,
    StreamerCorner? corner,
    bool? gameAudioOn,
    bool? gameMuted,
    bool? live,
    LiveStreamer? layout,
    StreamerGameAudio? gameAudio,
    int? sdkInt,
    Set<StreamerPause>? pauses,
    bool? stopped,
    bool? headset,
    bool? headsetTipSeen,
  }) => StreamerHostState(
    cameraVisible: cameraVisible ?? this.cameraVisible,
    corner: corner ?? this.corner,
    gameAudioOn: gameAudioOn ?? this.gameAudioOn,
    gameMuted: gameMuted ?? this.gameMuted,
    live: live ?? this.live,
    layout: layout ?? this.layout,
    gameAudio: gameAudio ?? this.gameAudio,
    sdkInt: sdkInt ?? this.sdkInt,
    pauses: pauses ?? this.pauses,
    stopped: stopped ?? this.stopped,
    headset: headset ?? this.headset,
    headsetTipSeen: headsetTipSeen ?? this.headsetTipSeen,
  );
}

/// D213 (v1.56-live, CONVENTIONS §10.86): the streamer host's side — the
/// setup's choices, then, on air, the screen track, the game sound, the
/// layout on the server and the pauses (Kabso in front, a call, the screen
/// off). The go-live controller drives it ([consent] before the room,
/// [begin] once the camera and microphone are published, [finish] at the
/// end); the screen's buttons and the notification call the rest.
class LiveStreamerHost extends Notifier<StreamerHostState> {
  LiveMediaEngine? _engine;
  LiveScreenShare? _share;
  String? _roomId;
  StreamSubscription<StreamerPlatformEvent>? _events;
  bool _micMixed = false;

  /// The native side was touched (secure window, mixer) and is not undone.
  bool _native = false;

  StreamerPlatform get _platform => ref.read(streamerPlatformProvider);
  LiveRepository get _repo => ref.read(liveRepositoryProvider);

  @override
  StreamerHostState build() {
    final platform = ref.read(streamerPlatformProvider);
    ref.onDispose(() {
      unawaited(_events?.cancel());
      if (_native) {
        unawaited(platform.detach().then((_) {}, onError: (_) {}));
        unawaited(platform.setSecure(on: false).then((_) {}, onError: (_) {}));
      }
    });
    return StreamerHostState(corner: _savedCorner());
  }

  /// The corner last chosen on this phone (top left at first).
  StreamerCorner _savedCorner() {
    try {
      final wire = ref
          .read(sharedPreferencesProvider)
          .getString(PreferenceKeys.streamerCorner);
      for (final c in StreamerCorner.values) {
        if (c.wire == wire) return c;
      }
    } on Object {
      // No preferences (some tests): top left.
    }
    return StreamerCorner.topLeft;
  }

  /// Reads Android's API level (the setup's game-sound note) and whether a
  /// headset is connected (the «use headphones» tip).
  Future<void> readDevice() async {
    if (state.sdkInt == null) {
      try {
        final sdk = await _platform.sdkInt();
        if (ref.mounted) state = state.copyWith(sdkInt: sdk);
      } on Object {
        // Not Android: no note.
      }
    }
    try {
      final headset = await _platform.headsetConnected();
      if (ref.mounted) state = state.copyWith(headset: headset);
    } on Object {
      // Unknown: the tip shows.
    }
  }

  // ---- setup (and live) ----------------------------------------------------

  Future<void> setCameraVisible({required bool visible}) async {
    if (visible == state.cameraVisible) return;
    state = state.copyWith(cameraVisible: visible);
    if (!state.live) return;
    // A hidden bubble is not sent at all (the camera track is paused).
    final engine = _engine;
    if (engine != null) {
      await _quiet(() => engine.setVideoPaused(paused: !visible));
    }
    await _push(cameraVisible: visible);
  }

  Future<void> setCorner(StreamerCorner corner) async {
    if (corner == state.corner) return;
    state = state.copyWith(corner: corner);
    try {
      unawaited(
        ref
            .read(sharedPreferencesProvider)
            .setString(PreferenceKeys.streamerCorner, corner.wire),
      );
    } on Object {
      // No preferences (some tests): this app session only.
    }
    if (state.live) await _push(corner: corner);
  }

  void setGameAudioOn({required bool on}) {
    if (state.live) return;
    state = state.copyWith(gameAudioOn: on);
  }

  // ---- going live ----------------------------------------------------------

  /// The system's screen-capture consent (nothing was created yet). D262:
  /// granted, refused by the person, or failed with a short code — logged
  /// (no ids) so a dialog that never showed is told apart from a «no».
  Future<StreamerConsent> consent() async {
    StreamerConsent answer;
    try {
      answer = await _platform.requestCapture();
    } on Object catch (e) {
      answer = StreamerConsent.failed(StreamerConsent.code(e.runtimeType));
    }
    if (answer.outcome == StreamerConsentOutcome.failed) {
      AppLogger.warning('streamer: consent $answer');
    } else {
      AppLogger.info('streamer: consent $answer');
    }
    return answer;
  }

  /// On air: publishes the screen (throws when it cannot start), joins the
  /// microphone with the game sound, and starts paused (Kabso is in front
  /// until the host goes to the game). [micOn] is the host's choice.
  Future<void> begin({
    required LiveMediaEngine engine,
    required LiveRoom room,
    required bool micOn,
  }) async {
    final share = engine as LiveScreenShare;
    _engine = engine;
    _share = share;
    _roomId = room.id;
    await share.publishScreen();
    await share.setScreenPaused(paused: true);
    _native = true;
    state = state.copyWith(
      live: true,
      layout: room.streamer,
      pauses: {StreamerPause.inApp},
      stopped: false,
    );
    await _quiet(() => _platform.setSecure(on: true));
    try {
      final attached = await _platform.attach(gameAudio: state.gameAudioOn);
      _micMixed = true;
      if (ref.mounted) state = state.copyWith(gameAudio: attached.gameAudio);
    } on Object catch (e) {
      // The microphone still works the usual way; no game sound.
      AppLogger.warning('streamer: attach failed (${e.runtimeType})');
      _micMixed = false;
      if (ref.mounted) {
        state = state.copyWith(gameAudio: StreamerGameAudio.failed);
      }
    }
    if (!state.cameraVisible) {
      await _quiet(() => engine.setVideoPaused(paused: true));
    }
    unawaited(_events?.cancel());
    _events = _platform.events.listen(_onEvent);
    if (!micOn) await setMicMuted(muted: true);
  }

  /// Whether the microphone's mute is the mixer's (the track stays
  /// published so the game sound goes on).
  bool get micMixed => _micMixed;

  /// The microphone on or off on air. With the mixer: the voice is silenced
  /// and the game sound goes on; without: the track is muted as usual.
  Future<void> setMicMuted({required bool muted}) async {
    if (_micMixed) {
      await _quiet(() => _platform.setMicMuted(muted: muted));
    } else {
      await _engine?.setMicEnabled(enabled: !muted);
    }
  }

  Future<void> setGameMuted({required bool muted}) async {
    state = state.copyWith(gameMuted: muted);
    await _quiet(() => _platform.setGameMuted(muted: muted));
  }

  /// Kabso left the front (the host went to the game) or came back.
  void appInFront({required bool front}) {
    if (!front && state.live && !state.headsetTipSeen) {
      state = state.copyWith(headsetTipSeen: true);
    }
    _setPause(StreamerPause.inApp, on: front);
  }

  /// The app goes to the background (to the game).
  Future<void> goToGame() => _quiet(_platform.moveToBack);

  /// After the system stopped the capture: a new consent, then the screen
  /// again. The consent's answer ([StreamerConsent.granted] once the screen
  /// runs again; `failed(start)` when it could not start); null when there
  /// was nothing to share again.
  Future<StreamerConsent?> shareAgain() async {
    final share = _share;
    if (share == null || !state.stopped) return null;
    final asked = await consent();
    if (!asked.isGranted) return asked;
    try {
      await share.publishScreen();
      await share.setScreenPaused(paused: state.paused);
      final attached = await _platform.attach(gameAudio: state.gameAudioOn);
      if (ref.mounted) {
        state = state.copyWith(stopped: false, gameAudio: attached.gameAudio);
      }
      return StreamerConsent.granted;
    } on Object catch (e) {
      AppLogger.warning('streamer: share again failed (${e.runtimeType})');
      return const StreamerConsent.failed(StreamerConsent.startFailed);
    }
  }

  /// The live ended (or failed): everything native is undone.
  Future<void> finish() async {
    // Not awaited: nothing more is listened to either way.
    unawaited(_events?.cancel());
    _events = null;
    if (_native) {
      _native = false;
      await _quiet(_platform.detach);
      await _quiet(() => _platform.setSecure(on: false));
    }
    _engine = null;
    _share = null;
    _roomId = null;
    _micMixed = false;
    if (ref.mounted) {
      state = StreamerHostState(
        cameraVisible: state.cameraVisible,
        corner: state.corner,
        gameAudioOn: state.gameAudioOn,
        sdkInt: state.sdkInt,
        headset: state.headset,
      );
    }
  }

  void _onEvent(StreamerPlatformEvent event) {
    switch (event) {
      case StreamerProjectionStopped():
        state = state.copyWith(stopped: true);
        final share = _share;
        if (share != null) unawaited(_quiet(share.unpublishScreen));
      case StreamerPhoneCall(:final active):
        _setPause(StreamerPause.call, on: active);
      case StreamerScreenPower(:final on):
        _setPause(StreamerPause.screenOff, on: !on);
      case StreamerHeadset(:final connected):
        state = state.copyWith(headset: connected);
      case StreamerRotation(:final landscape):
        unawaited(
          _push(
            orientation: landscape
                ? StreamerOrientation.landscape
                : StreamerOrientation.portrait,
          ),
        );
    }
  }

  void _setPause(StreamerPause why, {required bool on}) {
    if (!state.live || state.pauses.contains(why) == on) return;
    final pauses = {...state.pauses};
    on ? pauses.add(why) : pauses.remove(why);
    state = state.copyWith(pauses: pauses);
    final share = _share;
    if (share != null && !state.stopped) {
      unawaited(_quiet(() => share.setScreenPaused(paused: pauses.isNotEmpty)));
    }
  }

  /// `PUT /live/rooms/{id}/streamer` (best effort: the layout is cosmetic;
  /// the next change sends the whole wish again).
  Future<void> _push({
    StreamerOrientation? orientation,
    bool? cameraVisible,
    StreamerCorner? corner,
  }) async {
    final id = _roomId;
    if (id == null) return;
    try {
      final layout = await _repo.updateStreamer(
        id,
        orientation: orientation,
        cameraVisible: cameraVisible,
        corner: corner,
      );
      if (ref.mounted) {
        state = state.copyWith(layout: (state.layout ?? layout).newest(layout));
      }
    } on Object catch (e) {
      AppLogger.warning('streamer: layout not sent (${e.runtimeType})');
    }
  }

  Future<void> _quiet(Future<void> Function() step) async {
    try {
      await step();
    } on Object catch (e) {
      AppLogger.warning('streamer: ${e.runtimeType}');
    }
  }
}

final NotifierProvider<LiveStreamerHost, StreamerHostState>
liveStreamerHostProvider =
    NotifierProvider<LiveStreamerHost, StreamerHostState>(LiveStreamerHost.new);
