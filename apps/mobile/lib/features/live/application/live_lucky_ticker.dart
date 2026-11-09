import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_global_strips.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';

/// D148 / D347 (owner «نعم موافق»: «إخفاء أشرطة الفوز» / "Hide win
/// banners"): true hides the global lucky banner in every live — the
/// account's `NotificationSettings.luckyStrip` switched off (every phone;
/// kept with the D305 strip switches, set from the live's settings sheet).
/// A guest, or before the settings arrive: shown. This live's own win banner
/// is not affected.
final Provider<bool> luckyTickerHiddenProvider = Provider.autoDispose<bool>(
  (ref) => !ref.watch(globalStripPrefsProvider).lucky,
);

/// v1.111-live (D347, CONVENTIONS §10.146): one global lucky banner — the
/// server's `lucky-ticker` ([ticker]) and its gift's art ([gift], null from
/// an older server).
@immutable
class GlobalLuckyBanner {
  const new(this.ticker, {this.gift});

  final LuckyTicker ticker;
  final LuckyTickerGift? gift;

  LuckyWin get win => ticker.win;
  LuckyTickerRoom get room => ticker.room;
}

/// D148 («لحظة الحظ», CONVENTIONS §10.27) and D347 (owner: «شريط المردود
/// يظهر في كل لايفات للشريط x250 / x500 / x1000», §10.146): the global lucky
/// banner of one live — a ×250 / ×500 / ×1000 win (the server's set,
/// `LUCKY_GLOBAL_BANNER_MULTIPLIERS`) in another live, from the server's
/// `lucky-ticker` data message (at most one every 10 s for the whole
/// service). Since D347 it is the room's own win banner «شريط المردود»
/// ([LiveGiftEffects.luckyTime]) with the live's name under it.
///
/// Queue (D347): one shows at a time for [showTime]; at most [maxWaiting]
/// wait, the biggest first (multiplier, then coins) — a smaller one is
/// dropped when the line is full — and one that waited longer than [maxAge]
/// is dropped. A win seen before (the same send) is not shown again. The
/// live the win happened in never shows it here: it has its own banner
/// (the `lucky-win` message), so it is not shown twice. A win by someone
/// this person blocked, or in a live of someone they blocked, is not shown
/// (best effort: the block list the room's chat loaded).
class LiveLuckyTickers extends Notifier<GlobalLuckyBanner?> {
  new(this.roomId);

  final String roomId;

  /// How long one banner stays: the room banner's timeline and a breath.
  static const showTime = Duration(milliseconds: 3900);

  /// At most this many wait for their turn.
  static const maxWaiting = 3;

  /// A waiting banner older than this is dropped (no longer news).
  static const maxAge = Duration(seconds: 30);

  /// The clock (tests replace it).
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  StreamSubscription<LiveChatEvent>? _events;
  Timer? _timer;
  final _waiting = <(GlobalLuckyBanner, DateTime)>[];
  final _seen = <String>{};

  @override
  GlobalLuckyBanner? build() {
    // D347: switched to hidden → the one on screen and the waiting ones go.
    ref.listen(luckyTickerHiddenProvider, (_, hidden) {
      if (!hidden) return;
      _waiting.clear();
      _set(null);
    });
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
      if (event is LuckyTickerReceived) show(event.ticker, gift: event.gift);
    });
  }

  /// Shows [ticker] now, or keeps it waiting (the biggest first).
  void show(LuckyTicker ticker, {LuckyTickerGift? gift}) {
    if (!ref.mounted) return;
    // Its own live has the room's banner: never twice there.
    if (ticker.room.id == roomId || ticker.win.roomId == roomId) return;
    if (!_seen.add(ticker.win.giftId)) return;
    // D347: «إخفاء أشرطة الفوز» — not shown, not kept for later.
    if (ref.read(luckyTickerHiddenProvider)) return;
    if (_blocked(ticker.win.sender.id) || _blocked(ticker.room.host.id)) {
      return;
    }
    final banner = GlobalLuckyBanner(ticker, gift: gift);
    if (state == null) {
      _set(banner);
      return;
    }
    _waiting
      ..add((banner, now()))
      ..sort((a, b) => _biggerFirst(a.$1, b.$1));
    if (_waiting.length > maxWaiting) _waiting.removeLast();
  }

  /// The banner on screen goes now (a tap opened its live).
  void dismiss() {
    if (!ref.mounted) return;
    _next();
  }

  static int _biggerFirst(GlobalLuckyBanner a, GlobalLuckyBanner b) {
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

  void _next() {
    final at = now();
    _waiting.removeWhere((w) => at.difference(w.$2) > maxAge);
    _set(_waiting.isEmpty ? null : _waiting.removeAt(0).$1);
  }

  void _set(GlobalLuckyBanner? banner) {
    state = banner;
    _timer?.cancel();
    if (banner == null) return;
    _timer = Timer(showTime, () {
      if (ref.mounted) _next();
    });
  }
}

final NotifierProviderFamily<LiveLuckyTickers, GlobalLuckyBanner?, String>
liveLuckyTickersProvider = NotifierProvider.autoDispose
    .family<LiveLuckyTickers, GlobalLuckyBanner?, String>(LiveLuckyTickers.new);
