import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/notifications/application/notifications_controller.dart';

/// D305: one global strip — the gifts strip «شريط الهدايا» ([GiftStrip]) or
/// the games strip «شريط الألعاب» ([GameWinStrip]).
@immutable
sealed class GlobalStrip {
  const new();

  /// Unique per strip (the gift send's or the prize's id).
  String get key;

  /// The live it happened in (a tap opens it), or null.
  LuckyTickerRoom? get room;

  /// Who the strip is about: the sender, or the winner.
  UserSummary get person;

  /// The lane it shows in (D305b: the games lane above the gifts lane).
  StripLane get lane;
}

/// D305b (owner: «شريط الألعاب يكون موقعه فوق شريط الهدايا»): the two
/// places a global strip shows in, each with its own queue and timeline —
/// [games] right under the header, [gifts] right under it.
enum StripLane { games, gifts }

/// What each lane shows now.
typedef GlobalStripLanes = ({GlobalStrip? games, GlobalStrip? gifts});

final class GiftStrip extends GlobalStrip {
  const new(this.ticker);

  final GiftTicker ticker;

  @override
  String get key => 'gift.${ticker.gift.id}';

  @override
  LuckyTickerRoom get room => ticker.room;

  @override
  UserSummary get person => ticker.gift.sender;

  @override
  StripLane get lane => StripLane.gifts;
}

final class GameWinStrip extends GlobalStrip {
  const new(this.ticker);

  final GameWinTicker ticker;

  @override
  String get key => 'game.${ticker.id}';

  @override
  LuckyTickerRoom? get room => ticker.room;

  @override
  UserSummary get person => ticker.winner;

  @override
  StripLane get lane => StripLane.games;
}

/// v1.85-live (D305): whether this person sees each strip kind — the
/// account's `NotificationSettings.giftStrip` / `gameStrip` (every phone);
/// a guest, or before the settings arrive, or when they cannot be read:
/// both on.
typedef GlobalStripPrefs = ({bool gifts, bool games});

final Provider<GlobalStripPrefs> globalStripPrefsProvider =
    Provider.autoDispose<GlobalStripPrefs>((ref) {
      final me = ref.watch(currentUserProvider.select((u) => u?.id));
      if (me == null) return (gifts: true, games: true);
      final s = ref.watch(notificationSettingsProvider).value;
      return (gifts: s?.giftStrip ?? true, games: s?.gameStrip ?? true);
    });

/// D178 (owner: «والهدايا يجب أن تظهر في شريط في جميع البثوث») and D305
/// (owner: «يظهر في جميع الغرف من الجانب الى المنتصف ويخرج من الجهة
/// الأخرى، ويبقى في المنتصف ثانيتين»): the global strips of one live, from
/// the server's `gift-ticker` and `game-win-ticker` messages (at most one of
/// each kind every 3 s). D305b: two lanes ([StripLane]), each on its own —
/// one strip at a time per lane for [showTime] (enter, 2 s in the middle,
/// exit); at most [maxWaiting] wait per lane, the newest first (D178's rule;
/// the oldest is dropped when the line is full), and a strip that waited
/// longer than [maxAge] is dropped. Since v1.85-live the live it happened in
/// shows it too (owner «في جميع الغرف»). A strip about someone this person
/// blocked, or in a live of someone they blocked, is not shown; nor a kind
/// this person switched off ([globalStripPrefsProvider]).
class LiveGlobalStrips extends Notifier<GlobalStripLanes> {
  new(this.roomId);

  final String roomId;

  /// How long one strip stays: [enterTime] + [holdTime] + [exitTime].
  static const showTime = Duration(milliseconds: 2900);

  /// Sliding (or fading, with reduced motion) in from the reading start.
  static const enterTime = Duration(milliseconds: 450);

  /// Still in the middle (owner: «ويبقى في المنتصف ثانيتين»).
  static const holdTime = Duration(seconds: 2);

  /// Sliding (or fading) out by the other side.
  static const exitTime = Duration(milliseconds: 450);

  /// At most this many wait for their turn, per lane.
  static const maxWaiting = 3;

  /// A waiting strip older than this is dropped.
  static const maxAge = Duration(seconds: 30);

  /// The clock (tests replace it).
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  StreamSubscription<LiveChatEvent>? _events;
  final _timers = <StripLane, Timer>{};
  final Map<StripLane, List<(GlobalStrip, DateTime)>> _waiting = {
    for (final lane in StripLane.values) lane: <(GlobalStrip, DateTime)>[],
  };
  final _seen = <String>{};

  /// What [lane] shows now.
  static GlobalStrip? of(GlobalStripLanes lanes, StripLane lane) =>
      switch (lane) {
        StripLane.games => lanes.games,
        StripLane.gifts => lanes.gifts,
      };

  @override
  GlobalStripLanes build() {
    // Keeps the person's switches loaded while this live is open.
    ref.listen(globalStripPrefsProvider, (_, prefs) {
      for (final lane in StripLane.values) {
        _waiting[lane]!.removeWhere((w) => !_allowed(w.$1, prefs));
        final shown = of(state, lane);
        if (shown != null && !_allowed(shown, prefs)) _next(lane);
      }
    });
    ref.onDispose(() {
      unawaited(_events?.cancel());
      for (final t in _timers.values) {
        t.cancel();
      }
    });
    return (games: null, gifts: null);
  }

  /// Shows the [engine]'s strip messages from now on (once).
  void attach(LiveMediaEngine engine) {
    if (_events != null) return;
    _events = engine.chatEvents.listen((event) {
      switch (event) {
        case GiftTickerReceived(:final ticker):
          show(GiftStrip(ticker));
        case GameWinTickerReceived(:final ticker):
          show(GameWinStrip(ticker));
        default:
          break;
      }
    });
  }

  /// Shows [strip] now in its lane, or keeps it waiting (the newest first).
  void show(GlobalStrip strip) {
    if (!ref.mounted) return;
    if (!_seen.add(strip.key)) return;
    if (!_allowed(strip, ref.read(globalStripPrefsProvider))) return;
    if (_blocked(strip.person.id) || _blocked(strip.room?.host.id)) return;
    final lane = strip.lane;
    if (of(state, lane) == null) {
      _set(lane, strip);
      return;
    }
    final waiting = _waiting[lane]!..insert(0, (strip, now()));
    if (waiting.length > maxWaiting) waiting.removeLast();
  }

  /// The strip on [lane] goes now (a tap opened its live).
  void dismiss(StripLane lane) {
    if (!ref.mounted) return;
    _next(lane);
  }

  static bool _allowed(GlobalStrip strip, GlobalStripPrefs prefs) =>
      switch (strip) {
        GiftStrip() => prefs.gifts,
        GameWinStrip() => prefs.games,
      };

  bool _blocked(String? userId) {
    if (userId == null) return false;
    try {
      return ref.read(liveChatProvider(roomId).notifier).isBlocked(userId);
    } on Object {
      return false;
    }
  }

  void _next(StripLane lane) {
    final at = now();
    final waiting = _waiting[lane]!
      ..removeWhere((w) => at.difference(w.$2) > maxAge);
    _set(lane, waiting.isEmpty ? null : waiting.removeAt(0).$1);
  }

  void _set(StripLane lane, GlobalStrip? strip) {
    state = switch (lane) {
      StripLane.games => (games: strip, gifts: state.gifts),
      StripLane.gifts => (games: state.games, gifts: strip),
    };
    _timers.remove(lane)?.cancel();
    if (strip == null) return;
    _timers[lane] = Timer(showTime, () {
      if (ref.mounted) _next(lane);
    });
  }
}

final NotifierProviderFamily<LiveGlobalStrips, GlobalStripLanes, String>
liveGlobalStripsProvider = NotifierProvider.autoDispose
    .family<LiveGlobalStrips, GlobalStripLanes, String>(LiveGlobalStrips.new);
