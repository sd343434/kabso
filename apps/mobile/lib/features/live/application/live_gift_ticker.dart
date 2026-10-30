import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';

/// D178 (owner: «والهدايا يجب أن تظهر في شريط في جميع البثوث»): the global
/// gift strip of one live — a big gift (at least the server's
/// `GIFT_GLOBAL_TICKER_MIN_COINS`) sent in another live, from the server's
/// `gift-ticker` data message (at most one every 3 s). One shows at a time
/// for [showTime] (owner: 3 s); a few more wait, the newest first (the
/// oldest is dropped when the line is full). A gift by someone this person
/// blocked, or in a live of someone they blocked, is not shown.
class LiveGiftTickers extends Notifier<GiftTicker?> {
  new(this.roomId);

  final String roomId;

  /// How long one strip stays (owner: 3 s).
  static const showTime = Duration(seconds: 3);

  /// At most this many wait for their turn.
  static const maxWaiting = 3;

  StreamSubscription<LiveChatEvent>? _events;
  Timer? _timer;
  final _waiting = <GiftTicker>[];
  final _seen = <String>{};

  @override
  GiftTicker? build() {
    ref.onDispose(() {
      unawaited(_events?.cancel());
      _timer?.cancel();
    });
    return null;
  }

  /// Shows the [engine]'s `gift-ticker` messages from now on (once).
  void attach(LiveMediaEngine engine) {
    if (_events != null) return;
    _events = engine.chatEvents.listen((event) {
      if (event is GiftTickerReceived) show(event.ticker);
    });
  }

  /// Shows [ticker] now, or keeps it waiting (the newest first).
  void show(GiftTicker ticker) {
    if (!ref.mounted || ticker.room.id == roomId) return;
    if (!_seen.add(ticker.gift.id)) return;
    if (_blocked(ticker.gift.sender.id) || _blocked(ticker.room.host.id)) {
      return;
    }
    if (state == null) {
      _set(ticker);
      return;
    }
    _waiting.insert(0, ticker);
    if (_waiting.length > maxWaiting) _waiting.removeLast();
  }

  /// The strip on screen goes now (a tap opened its live).
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

  void _set(GiftTicker? ticker) {
    state = ticker;
    _timer?.cancel();
    if (ticker == null) return;
    _timer = Timer(showTime, () {
      if (!ref.mounted) return;
      _set(_waiting.isEmpty ? null : _waiting.removeAt(0));
    });
  }
}

final NotifierProviderFamily<LiveGiftTickers, GiftTicker?, String>
liveGiftTickersProvider = NotifierProvider.autoDispose
    .family<LiveGiftTickers, GiftTicker?, String>(LiveGiftTickers.new);
