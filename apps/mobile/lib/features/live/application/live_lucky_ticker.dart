import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';

/// D148: hides the global lucky ticker in every live. Off (shown) by
/// default; the viewer's ≡ switch for it comes in D151 and sets this.
class LuckyTickerHidden extends Notifier<bool> {
  @override
  bool build() => false;

  // The switch (D151) sets it; true hides the ticker.
  // ignore: avoid_setters_without_getters, the state is read through the provider.
  set hidden(bool value) => state = value;
}

final NotifierProvider<LuckyTickerHidden, bool> luckyTickerHiddenProvider =
    NotifierProvider<LuckyTickerHidden, bool>(LuckyTickerHidden.new);

/// D148 («لحظة الحظ», CONVENTIONS §10.27): the gold ticker of one live —
/// a big lucky win (×100 and up) in another live, from the server's
/// `lucky-ticker` data message (the server sends at most one every 10 s).
/// One shows at a time for [showTime]; a few more wait, the biggest first
/// (a smaller one is dropped when the line is full). A win by someone this
/// person blocked, or in a live of someone they blocked, is not shown
/// (best effort: the block list the room's chat loaded). The live the win
/// happened in shows its own big card instead.
class LiveLuckyTickers extends Notifier<LuckyTicker?> {
  new(this.roomId);

  final String roomId;

  /// How long one ticker stays.
  static const showTime = Duration(seconds: 6);

  /// At most this many wait for their turn.
  static const maxWaiting = 3;

  StreamSubscription<LiveChatEvent>? _events;
  Timer? _timer;
  final _waiting = <LuckyTicker>[];
  final _seen = <String>{};

  @override
  LuckyTicker? build() {
    ref.onDispose(() {
      unawaited(_events?.cancel());
      _timer?.cancel();
    });
    return null;
  }

  /// Shows the [engine]'s `lucky-ticker` messages from now on (once).
  void attach(LiveMediaEngine engine) {
    if (_events != null) return;
    _events = engine.chatEvents.listen((event) {
      if (event is LuckyTickerReceived) show(event.ticker);
    });
  }

  /// Shows [ticker] now, or keeps it waiting (the biggest first).
  void show(LuckyTicker ticker) {
    if (!ref.mounted || ticker.room.id == roomId) return;
    if (!_seen.add(ticker.win.giftId)) return;
    if (_blocked(ticker.win.sender.id) || _blocked(ticker.room.host.id)) {
      return;
    }
    if (state == null) {
      _set(ticker);
      return;
    }
    _waiting
      ..add(ticker)
      ..sort(_biggerFirst);
    if (_waiting.length > maxWaiting) _waiting.removeLast();
  }

  /// The ticker on screen goes now (a tap opened its live, or it was swiped).
  void dismiss() {
    if (!ref.mounted) return;
    _set(_waiting.isEmpty ? null : _waiting.removeAt(0));
  }

  static int _biggerFirst(LuckyTicker a, LuckyTicker b) {
    final m = b.win.multiplier.compareTo(a.win.multiplier);
    return m != 0 ? m : b.win.coinsWon.compareTo(a.win.coinsWon);
  }

  bool _blocked(String userId) {
    try {
      return ref.read(liveChatProvider(roomId).notifier).isBlocked(userId);
    } on Object {
      return false;
    }
  }

  void _set(LuckyTicker? ticker) {
    state = ticker;
    _timer?.cancel();
    if (ticker == null) return;
    _timer = Timer(showTime, () {
      if (!ref.mounted) return;
      _set(_waiting.isEmpty ? null : _waiting.removeAt(0));
    });
  }
}

final NotifierProviderFamily<LiveLuckyTickers, LuckyTicker?, String>
liveLuckyTickersProvider = NotifierProvider.autoDispose
    .family<LiveLuckyTickers, LuckyTicker?, String>(LiveLuckyTickers.new);
