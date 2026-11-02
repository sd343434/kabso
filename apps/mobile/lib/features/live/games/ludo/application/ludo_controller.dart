import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/games/ludo/data/ludo_repository.dart';
import 'package:kabso_live/features/live/games/ludo/domain/ludo_game.dart';

/// One room's Ludo as this phone knows it (D168).
@immutable
final class LudoView {
  const new({
    this.game,
    this.receivedAt,
    this.shown = false,
    this.collapsed = false,
    this.busy = false,
  });

  /// The server's game: open, or the last one finished (its result shows
  /// until dismissed). Null when there is none.
  final LudoGame? game;

  /// When this phone received [game] (its own clock).
  final DateTime? receivedAt;

  /// The panel is open on this phone.
  final bool shown;

  /// The panel is folded to its bar (the stream shows above it).
  final bool collapsed;

  /// An intent of this phone is on its way.
  final bool busy;

  LudoView copyWith({
    LudoGame? game,
    DateTime? receivedAt,
    bool? shown,
    bool? collapsed,
    bool? busy,
  }) => LudoView(
    game: game ?? this.game,
    receivedAt: receivedAt ?? this.receivedAt,
    shown: shown ?? this.shown,
    collapsed: collapsed ?? this.collapsed,
    busy: busy ?? this.busy,
  );

  /// The time left of the turn now, as the server's clock counts it.
  Duration turnLeft(DateTime now) {
    final g = game;
    final at = receivedAt;
    final ends = g?.turnEndsAt;
    if (g == null || at == null || ends == null) return Duration.zero;
    final left = ends.difference(g.serverTime) - now.difference(at);
    return left.isNegative ? Duration.zero : left;
  }
}

/// D168 («لودو», CONVENTIONS §10.42): the Ludo game of one live room. The
/// game is loaded when the room attaches (late joiners and spectators get
/// the whole state) and replaced by the server's `ludo` messages; a
/// message older than what this phone has is ignored (versions only grow).
/// Intents go to the server, which answers the game; nothing is decided on
/// the phone.
class LiveLudoController extends Notifier<LudoView> {
  new(this.roomId);

  final String roomId;

  StreamSubscription<LiveChatEvent>? _events;
  bool _host = false;

  @override
  LudoView build() {
    ref.onDispose(() => unawaited(_events?.cancel()));
    return const LudoView();
  }

  LudoRepository get _repo => ref.read(ludoRepositoryProvider);

  /// Loads the game and follows the [engine]'s `ludo` messages (once).
  void attach(LiveMediaEngine engine, {required bool host}) {
    if (_events != null) return;
    _host = host;
    _events = engine.chatEvents.listen((event) {
      if (event case LiveLudoChanged(:final game)) apply(game);
    });
    unawaited(load());
  }

  /// `GET …/ludo`; a failure leaves what this phone had.
  Future<void> load() async {
    try {
      final game = await _repo.get(roomId);
      if (!ref.mounted) return;
      if (game != null) {
        apply(game, fresh: true);
      } else if (state.game?.isOpen ?? false) {
        // The game this phone showed is over and gone.
        state = const LudoView();
      }
    } on Object {
      // Nothing shown rather than something wrong.
    }
  }

  /// A game from the server (a message, an answer or a read).
  void apply(LudoGame game, {bool fresh = false}) {
    if (!ref.mounted || game.roomId != roomId) return;
    final old = state.game;
    final same = old != null && old.id == game.id;
    if (same && game.version < old.version) return;
    if (same && game.version == old.version && !fresh) return;
    if (game.status == LudoStatus.ended) {
      // The host ended it (or the live ended): the panel goes away.
      state = const LudoView();
      return;
    }
    final isNew = !same;
    state = state.copyWith(
      game: game,
      receivedAt: clock.now(),
      // The host's own new game opens at once; others see the banner.
      shown: state.shown || (isNew && _host && game.isOpen),
      collapsed: isNew ? false : null,
    );
  }

  void show() {
    if (ref.mounted) state = state.copyWith(shown: true, collapsed: false);
  }

  /// Closes the panel on this phone; a result shown is dismissed.
  void hide() {
    if (!ref.mounted) return;
    final g = state.game;
    state = g == null || !g.isOpen
        ? const LudoView()
        : state.copyWith(shown: false);
  }

  void toggleCollapsed() {
    if (ref.mounted) state = state.copyWith(collapsed: !state.collapsed);
  }

  Future<AppFailure?> _intent(Future<LudoGame> Function() call) async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);
    try {
      final game = await call();
      if (ref.mounted) {
        state = state.copyWith(busy: false);
        apply(game);
      }
      return null;
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (ref.mounted) state = state.copyWith(busy: false);
      // Someone (or the server's timer) was first: show the game now.
      if (failure is ServerFailure &&
          const {
            'LUDO_STALE_VERSION',
            'LUDO_NOT_YOUR_TURN',
            'LUDO_GAME_EXISTS',
          }.contains(failure.rawCode)) {
        unawaited(load());
      }
      return failure;
    }
  }

  /// The host opens a game ([quick]: 2 pieces each; 2 or 4 [players]).
  Future<AppFailure?> create({required bool quick, required int players}) =>
      _intent(() => _repo.create(roomId, quick: quick, players: players));

  Future<AppFailure?> takeSeat(int seat) =>
      _intent(() => _repo.takeSeat(roomId, seat));

  /// Leaves [seat] (or, the host, removes its player).
  Future<AppFailure?> leaveSeat(int seat) =>
      _intent(() => _repo.leaveSeat(roomId, seat));

  Future<AppFailure?> start() => _withGame((g) => _repo.start(roomId, g));

  Future<AppFailure?> roll() => _withGame((g) => _repo.roll(roomId, g));

  Future<AppFailure?> move(int piece) =>
      _withGame((g) => _repo.move(roomId, g, piece));

  Future<AppFailure?> end() => _intent(() => _repo.end(roomId));

  Future<AppFailure?> _withGame(Future<LudoGame> Function(int version) call) {
    final g = state.game;
    if (g == null) return Future.value();
    return _intent(() => call(g.version));
  }
}

final NotifierProviderFamily<LiveLudoController, LudoView, String>
liveLudoProvider =
    NotifierProvider.family<LiveLudoController, LudoView, String>(
      LiveLudoController.new,
    );
