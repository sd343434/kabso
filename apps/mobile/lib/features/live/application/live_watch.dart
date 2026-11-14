import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_watch_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_watch.dart';

/// One live's watch-together as this phone knows it (D154i).
typedef LiveWatchView = ({
  /// The server's state, or null before it loaded.
  LiveWatch? watch,

  /// When this phone received [watch] (its own clock).
  DateTime? receivedAt,

  /// The host's waiting suggestions (empty for viewers).
  List<LiveWatchSuggestion> suggestions,

  /// A viewer hid the player on this phone.
  bool hidden,
});

/// D154i («يوتيوب», CONVENTIONS §10.39): watch-together in one live. The
/// state is loaded when the room attaches (late joiners start in the right
/// place) and replaced by the server's `watch` messages; the host's phone
/// also keeps the viewers' waiting suggestions (`watch-suggestion`
/// messages). The player itself is `YoutubePlayer` in the watch card.
class LiveWatchController extends Notifier<LiveWatchView> {
  new(this.roomId);

  final String roomId;

  StreamSubscription<LiveChatEvent>? _events;
  bool _host = false;

  /// Called with each new suggestion on the host's phone (a toast).
  void Function(LiveWatchSuggestion)? onSuggestion;

  @override
  LiveWatchView build() {
    ref.onDispose(() => unawaited(_events?.cancel()));
    return (
      watch: null,
      receivedAt: null,
      suggestions: const [],
      hidden: false,
    );
  }

  LiveWatchRepository get _repo => ref.read(liveWatchRepositoryProvider);

  /// Loads the state (and, for the [host], the suggestions) and follows the
  /// [engine]'s watch messages (once).
  void attach(LiveMediaEngine engine, {required bool host}) {
    if (_events != null) return;
    _host = host;
    _events = engine.chatEvents.listen((event) {
      switch (event) {
        case LiveWatchChanged(:final watch):
          apply(watch);
        case LiveWatchSuggested(:final suggestion):
          _suggested(suggestion);
        default:
          break;
      }
    });
    unawaited(load());
  }

  Future<void> load() async {
    try {
      apply(await _repo.get(roomId));
      if (_host) {
        final list = await _repo.suggestions(roomId);
        if (ref.mounted) {
          state = (
            watch: state.watch,
            receivedAt: state.receivedAt,
            suggestions: list,
            hidden: state.hidden,
          );
        }
      }
    } on Object {
      // Nothing to show rather than something wrong.
    }
  }

  /// A new state from the server.
  void apply(LiveWatch watch) {
    if (!ref.mounted || watch.roomId != roomId) return;
    final changed = watch.video?.videoId != state.watch?.video?.videoId;
    state = (
      watch: watch,
      receivedAt: clock.now(),
      suggestions: state.suggestions,
      // A new video shows again on a phone that hid the last one.
      hidden: state.hidden && !changed,
    );
  }

  void _suggested(LiveWatchSuggestion s) {
    if (!_host || !ref.mounted || s.roomId != roomId) return;
    if (state.suggestions.any((x) => x.id == s.id)) return;
    state = (
      watch: state.watch,
      receivedAt: state.receivedAt,
      suggestions: [...state.suggestions, s],
      hidden: state.hidden,
    );
    onSuggestion?.call(s);
  }

  /// Where the video should be now on this phone, in ms.
  int expectedPositionMs() {
    final w = state.watch;
    final at = state.receivedAt;
    if (w == null || at == null) return 0;
    return w.positionAfter(clock.now().difference(at));
  }

  Future<AppFailure?> _guard(Future<LiveWatch> Function() call) async {
    try {
      apply(await call());
      return null;
    } on Object catch (e) {
      return toAppFailure(e);
    }
  }

  /// The host shows [video] (an id or a link) from the start.
  Future<AppFailure?> start(String video) => _guard(
    () => _repo.set(roomId, video: video, playing: true, positionMs: 0),
  );

  /// The host's player state (play, pause, seek, and now and then).
  Future<AppFailure?> report({
    required bool playing,
    required int positionMs,
  }) =>
      _guard(() => _repo.set(roomId, playing: playing, positionMs: positionMs));

  /// The host stops watch-together.
  Future<AppFailure?> stop() => _guard(
    () => _repo.set(roomId, stop: true, playing: false, positionMs: 0),
  );

  /// The host plays ([approve]) or dismisses a suggestion.
  Future<AppFailure?> decide(String id, {required bool approve}) async {
    final failure = await _guard(
      () => _repo.decide(roomId, id, approve: approve),
    );
    if (ref.mounted &&
        (failure == null || failure.code == ErrorCode.notFound)) {
      state = (
        watch: state.watch,
        receivedAt: state.receivedAt,
        suggestions: [
          for (final s in state.suggestions)
            if (s.id != id) s,
        ],
        hidden: state.hidden,
      );
    }
    return failure;
  }

  /// A viewer suggests [video] (an id or a link).
  Future<AppFailure?> suggest(String video) async {
    try {
      await _repo.suggest(roomId, video);
      return null;
    } on Object catch (e) {
      return toAppFailure(e);
    }
  }

  /// A viewer hides or shows the player on this phone.
  void toggleHidden() {
    if (!ref.mounted) return;
    state = (
      watch: state.watch,
      receivedAt: state.receivedAt,
      suggestions: state.suggestions,
      hidden: !state.hidden,
    );
  }
}

final NotifierProviderFamily<LiveWatchController, LiveWatchView, String>
liveWatchProvider =
    NotifierProvider.family<LiveWatchController, LiveWatchView, String>(
      LiveWatchController.new,
    );
