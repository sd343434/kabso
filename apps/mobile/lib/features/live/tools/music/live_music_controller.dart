import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/live/tools/live_tools_repository.dart';
import 'package:kabso_live/features/live/tools/music/live_music_mixer.dart';

/// D201 «موسيقى»: the host's short queue and the player's state.
@immutable
class LiveMusicState {
  const new({
    this.queue = const [],
    this.current,
    this.playing = false,
    this.volume = LiveMusicController.defaultVolume,
    this.ducking = true,
    this.position = Duration.zero,
    this.duration,
    this.error,
  });

  final List<LiveMusicFile> queue;

  /// The index in [queue] loaded now, or null.
  final int? current;
  final bool playing;

  /// 0 … 1, the music under the voice.
  final double volume;
  final bool ducking;
  final Duration position;
  final Duration? duration;

  /// D232: why the last file did not play, or null.
  final LiveMusicError? error;

  /// The last file did not play.
  bool get failed => error != null;

  LiveMusicFile? get track =>
      current == null || current! >= queue.length ? null : queue[current!];

  LiveMusicState copyWith({
    List<LiveMusicFile>? queue,
    int? Function()? current,
    bool? playing,
    double? volume,
    bool? ducking,
    Duration? position,
    Duration? Function()? duration,
    LiveMusicError? Function()? error,
  }) => LiveMusicState(
    queue: queue ?? this.queue,
    current: current == null ? this.current : current(),
    playing: playing ?? this.playing,
    volume: volume ?? this.volume,
    ducking: ducking ?? this.ducking,
    position: position ?? this.position,
    duration: duration == null ? this.duration : duration(),
    error: error == null ? this.error : error(),
  );
}

/// D201: the host's music for this live — files picked on the phone, played
/// one after the other into the mixer. Nothing plays until the host presses
/// play; the sheet opens only after the rights notice was accepted
/// ([liveMusicRightsProvider]).
class LiveMusicController extends Notifier<LiveMusicState> {
  /// A short queue.
  static const maxQueue = 20;

  /// The music's default level under the voice.
  static const defaultVolume = 0.35;

  StreamSubscription<LiveMusicEvent>? _events;

  LiveMusicMixer get _mixer => ref.read(liveMusicMixerProvider);

  @override
  LiveMusicState build() {
    final mixer = _mixer;
    _events = mixer.events.listen(_onEvent);
    ref.onDispose(() {
      unawaited(_events?.cancel());
      unawaited(mixer.stop().catchError((Object _) {}));
    });
    return const LiveMusicState();
  }

  void _onEvent(LiveMusicEvent event) {
    switch (event) {
      case LiveMusicPosition(:final position, :final duration):
        state = state.copyWith(position: position, duration: () => duration);
      case LiveMusicCompleted():
        unawaited(next());
      case LiveMusicFailed(:final error):
        state = state.copyWith(playing: false, error: () => error);
    }
  }

  /// Adds the picked files (up to [maxQueue]); returns how many did not fit.
  Future<int> addFiles() async {
    final files = await _mixer.pickFiles();
    final room = maxQueue - state.queue.length;
    final added = files.take(room < 0 ? 0 : room).toList();
    if (added.isNotEmpty) {
      state = state.copyWith(
        queue: [...state.queue, ...added],
        error: () => null,
      );
    }
    return files.length - added.length;
  }

  /// Loads and plays the file at [index].
  Future<void> playAt(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final file = state.queue[index];
    state = state.copyWith(
      current: () => index,
      playing: false,
      position: Duration.zero,
      duration: () => null,
      error: () => null,
    );
    try {
      final length = await _mixer.load(file);
      await _mixer.setVolume(state.volume);
      await _mixer.setDucking(on: state.ducking);
      await _mixer.play();
      // D232: a decode error reported while this was starting (the decoder
      // runs on its own thread) wins — it is not "playing" (was: the pause
      // icon next to «تعذّر تشغيل هذا الملف.»).
      if (state.failed || state.current != index) return;
      state = state.copyWith(playing: true, duration: () => length);
    } on LiveMusicLoadException catch (e) {
      state = state.copyWith(playing: false, error: () => e.error);
    } on Object {
      state = state.copyWith(
        playing: false,
        error: () => LiveMusicError.unreadable,
      );
    }
  }

  /// Play / pause; with nothing loaded, the first file. D232: after a
  /// failure, play loads the file again (the native decoder is gone; was a
  /// bare `play` on nothing, shown as playing).
  Future<void> toggle() async {
    if (state.track == null) {
      if (state.queue.isNotEmpty) await playAt(0);
      return;
    }
    if (state.failed && !state.playing) {
      await playAt(state.current!);
      return;
    }
    if (state.playing) {
      await _mixer.pause();
      state = state.copyWith(playing: false);
    } else {
      await _mixer.play();
      state = state.copyWith(playing: true);
    }
  }

  /// The next file; after the last one the player stops.
  Future<void> next() async {
    final current = state.current;
    if (current == null || current + 1 >= state.queue.length) {
      await _mixer.stop();
      state = state.copyWith(
        current: () => null,
        playing: false,
        position: Duration.zero,
        duration: () => null,
      );
      return;
    }
    await playAt(current + 1);
  }

  Future<void> remove(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final queue = [...state.queue]..removeAt(index);
    final current = state.current;
    if (current == index) {
      await _mixer.stop();
      state = state.copyWith(
        queue: queue,
        current: () => null,
        playing: false,
        position: Duration.zero,
        duration: () => null,
      );
      return;
    }
    state = state.copyWith(
      queue: queue,
      current: () => current != null && current > index ? current - 1 : current,
    );
  }

  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: v);
    await _mixer.setVolume(v);
  }

  Future<void> setDucking({required bool on}) async {
    state = state.copyWith(ducking: on);
    await _mixer.setDucking(on: on);
  }

  /// Stops the music (the live ends, the host leaves).
  Future<void> stopAll() async {
    await _mixer.stop();
    state = state.copyWith(
      current: () => null,
      playing: false,
      position: Duration.zero,
    );
  }
}

final NotifierProvider<LiveMusicController, LiveMusicState> liveMusicProvider =
    NotifierProvider.autoDispose<LiveMusicController, LiveMusicState>(
      LiveMusicController.new,
    );

/// D201: whether this app session knows the music-rights notice was accepted
/// (the server keeps the acceptance; asked once per session, then
/// remembered).
class LiveMusicRights extends Notifier<bool> {
  @override
  bool build() => false;

  /// Asks the server unless already known.
  Future<bool> accepted() async {
    if (state) return true;
    return state = await ref
        .read(liveToolsRepositoryProvider)
        .musicRightsAccepted();
  }

  /// Records the acceptance (the server keeps the first one).
  Future<void> accept() async {
    await ref.read(liveToolsRepositoryProvider).acceptMusicRights();
    state = true;
  }
}

final NotifierProvider<LiveMusicRights, bool> liveMusicRightsProvider =
    NotifierProvider<LiveMusicRights, bool>(LiveMusicRights.new);
