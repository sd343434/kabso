import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_level_ticker.dart';

/// D254 (owner: «شريط متحرك لاعلان عن ترقية الحسابات وصعود ليفيلات
/// لليفيلات المرتفعة»): the level banner of one live — someone reached a
/// high support or charm level in some live (this one too), from the
/// server's `level-ticker` data message (at most one every 8 s for the whole
/// service). One shows at a time for [showTime] while its text scrolls; a
/// few more wait in line, oldest first (the oldest waiting one is dropped
/// when the line is full). A level-up of someone this person blocked, or in
/// a live of someone they blocked, is not shown.
class LiveLevelTickers extends Notifier<LevelTicker?> {
  new(this.roomId);

  final String roomId;

  /// How long one banner stays (the server's gap between two).
  static const showTime = Duration(seconds: 8);

  /// At most this many wait for their turn.
  static const maxWaiting = 3;

  StreamSubscription<LiveChatEvent>? _events;
  Timer? _timer;
  final _waiting = <LevelTicker>[];
  final _seen = <String>{};

  @override
  LevelTicker? build() {
    ref.onDispose(() {
      unawaited(_events?.cancel());
      _timer?.cancel();
    });
    return null;
  }

  /// Shows the [engine]'s `level-ticker` messages from now on (once).
  void attach(LiveMediaEngine engine) {
    if (_events != null) return;
    _events = engine.chatEvents.listen((event) {
      if (event is LevelTickerReceived) show(event.ticker);
    });
  }

  /// Shows [ticker] now, or keeps it waiting (oldest first).
  void show(LevelTicker ticker) {
    if (!ref.mounted) return;
    if (!_seen.add(ticker.id)) return;
    if (_blocked(ticker.user.id) || _blocked(ticker.room.host.id)) return;
    if (state == null) {
      _set(ticker);
      return;
    }
    _waiting.add(ticker);
    if (_waiting.length > maxWaiting) _waiting.removeAt(0);
  }

  /// The banner on screen goes now (a tap opened its live).
  void dismiss() {
    if (!ref.mounted) return;
    _set(_waiting.isEmpty ? null : _waiting.removeAt(0));
  }

  bool _blocked(String userId) {
    try {
      return ref.read(liveChatProvider(roomId).notifier).isBlocked(userId);
    } on Object {
      return false;
    }
  }

  void _set(LevelTicker? ticker) {
    state = ticker;
    _timer?.cancel();
    if (ticker == null) return;
    _timer = Timer(showTime, () {
      if (!ref.mounted) return;
      _set(_waiting.isEmpty ? null : _waiting.removeAt(0));
    });
  }
}

final NotifierProviderFamily<LiveLevelTickers, LevelTicker?, String>
liveLevelTickersProvider = NotifierProvider.autoDispose
    .family<LiveLevelTickers, LevelTicker?, String>(LiveLevelTickers.new);
