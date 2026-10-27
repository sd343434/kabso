import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:material_ui/material_ui.dart' show immutable;

/// What a live shows of the gifts sent in it now (CP-020, §10.23): up to
/// [LiveGiftEffects.maxBanners] banners (one per combo, updated in place)
/// and one large centred effect for a gift with an animation or a big one.
@immutable
class LiveGiftEffectsState {
  const new({this.banners = const [], this.big, this.lucky});

  /// The banners on screen, oldest first.
  final List<LiveGift> banners;

  /// The big gift playing now, or null.
  final LiveGift? big;

  /// D132: the big lucky win announced now (×[LiveGiftEffects.luckyBanner]
  /// or more), or null.
  final LuckyWin? lucky;
}

/// Plays the gifts of one live: the `gift` data messages of the media room
/// and the caller's own sends (shown before their message comes back).
/// A send seen twice (its answer and its message) plays once.
///
/// The screen that owns the media session [attach]es its engine once.
class LiveGiftEffects extends Notifier<LiveGiftEffectsState> {
  new(this.roomId);

  final String roomId;

  /// Banners on screen at once; more wait in turn.
  static const maxBanners = 2;

  /// A banner stays this long after its last send.
  static const bannerTime = Duration(seconds: 3);

  /// The large effect's length (the image's grow and fade).
  static const bigTime = Duration(milliseconds: 3200);

  /// An effect that fetches or plays an SVGA ([bigHold]) ends when it has
  /// played ([bigDone]); this is only the longest it may stay on screen.
  static const maxAnimatedTime = Duration(seconds: 30);

  /// A send worth at least this many coins plays the large effect (as does
  /// a gift with an `animationKey` or a hosted `animationUrl`, D126).
  static const bigGiftCoins = 1000;

  /// At most this many sends wait for a banner or the large effect.
  static const maxWaiting = 20;

  /// D131/D132 (owner): a lucky win of at least this multiplier gets the
  /// room banner, for [luckyTime].
  static const luckyBanner = 100;
  static const luckyTime = Duration(seconds: 4);

  StreamSubscription<LiveChatEvent>? _events;
  final _seen = <String>{};
  final _waiting = <LiveGift>[];
  final _waitingBig = <LiveGift>[];
  final _timers = <String, Timer>{};
  Timer? _bigTimer;
  Timer? _luckyTimer;
  final _luckyWaiting = <LuckyWin>[];

  @override
  LiveGiftEffectsState build() {
    ref.onDispose(() {
      unawaited(_events?.cancel());
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
      _bigTimer?.cancel();
      _luckyTimer?.cancel();
    });
    return const LiveGiftEffectsState();
  }

  /// Plays the [engine]'s `gift` messages from now on (once).
  void attach(LiveMediaEngine engine) {
    if (_events != null) return;
    _events = engine.chatEvents.listen((event) {
      if (event is LiveGiftReceived && event.gift.roomId == roomId) {
        show(event.gift);
      } else if (event is LuckyWinReceived && event.win.roomId == roomId) {
        showLucky(event.win);
      }
    });
  }

  /// D132: announces [win] when it reaches [luckyBanner] (one at a time;
  /// a send seen twice shows once).
  void showLucky(LuckyWin win) {
    if (!ref.mounted || win.multiplier < luckyBanner) return;
    if (!_seen.add('lucky:${win.giftId}')) return;
    if (state.lucky != null) {
      if (_luckyWaiting.length < maxWaiting) _luckyWaiting.add(win);
      return;
    }
    _setLucky(win);
  }

  void _setLucky(LuckyWin? win) {
    state = LiveGiftEffectsState(
      banners: state.banners,
      big: state.big,
      lucky: win,
    );
    _luckyTimer?.cancel();
    if (win == null) return;
    _luckyTimer = Timer(luckyTime, () {
      if (!ref.mounted) return;
      _setLucky(_luckyWaiting.isEmpty ? null : _luckyWaiting.removeAt(0));
    });
  }

  /// One combo, one banner: the same sender's combo continues it.
  static String _comboKey(LiveGift g) => '${g.sender.id}:${g.combo.id}';

  /// Plays [gift] (a message or the caller's own answer).
  void show(LiveGift gift) {
    if (!ref.mounted || !_seen.add(gift.id)) return;
    if (_seen.length > 500) {
      _seen
        ..clear()
        ..add(gift.id);
    }
    _banner(gift);
    if (_animated(gift) || gift.totalCoins >= bigGiftCoins) {
      _big(gift);
    }
  }

  static bool _animated(LiveGift g) =>
      g.animationKey != null || g.animationUrl != null;

  /// The large effect of send [id] fetches or plays an SVGA: it stays
  /// until [bigDone] (at most [maxAnimatedTime]) instead of [bigTime].
  void bigHold(String id) {
    if (state.big?.id != id) return;
    _bigTimer?.cancel();
    _bigTimer = Timer(maxAnimatedTime, _bigDone);
  }

  /// The large effect of send [id] is over (its SVGA played, or the image
  /// popped): the next one plays. Ignored for an effect no longer shown.
  void bigDone(String id) {
    if (state.big?.id != id) return;
    _bigTimer?.cancel();
    _bigDone();
  }

  void _banner(LiveGift gift) {
    final key = _comboKey(gift);
    final banners = state.banners;
    final i = banners.indexWhere((b) => _comboKey(b) == key);
    if (i >= 0) {
      // A later send of the combo (messages may come out of order).
      if (gift.combo.count >= banners[i].combo.count) {
        state = LiveGiftEffectsState(
          banners: [...banners]..[i] = gift,
          big: state.big,
          lucky: state.lucky,
        );
      }
      _hold(key);
      return;
    }
    final w = _waiting.indexWhere((b) => _comboKey(b) == key);
    if (w >= 0) {
      if (gift.combo.count >= _waiting[w].combo.count) _waiting[w] = gift;
      return;
    }
    if (banners.length < maxBanners) {
      state = LiveGiftEffectsState(
        banners: [...banners, gift],
        big: state.big,
        lucky: state.lucky,
      );
      _hold(key);
    } else if (_waiting.length < maxWaiting) {
      _waiting.add(gift);
    }
  }

  void _hold(String key) {
    _timers[key]?.cancel();
    _timers[key] = Timer(bannerTime, () => _drop(key));
  }

  void _drop(String key) {
    _timers.remove(key)?.cancel();
    if (!ref.mounted) return;
    final banners = [
      for (final b in state.banners)
        if (_comboKey(b) != key) b,
    ];
    if (_waiting.isNotEmpty && banners.length < maxBanners) {
      final next = _waiting.removeAt(0);
      banners.add(next);
      _hold(_comboKey(next));
    }
    state = LiveGiftEffectsState(
      banners: banners,
      big: state.big,
      lucky: state.lucky,
    );
  }

  void _big(LiveGift gift) {
    if (state.big != null) {
      if (_waitingBig.length < maxWaiting) _waitingBig.add(gift);
      return;
    }
    state = LiveGiftEffectsState(
      banners: state.banners,
      big: gift,
      lucky: state.lucky,
    );
    _bigTimer = Timer(bigTime, _bigDone);
  }

  void _bigDone() {
    _bigTimer = null;
    if (!ref.mounted) return;
    final next = _waitingBig.isEmpty ? null : _waitingBig.removeAt(0);
    state = LiveGiftEffectsState(
      banners: state.banners,
      big: next,
      lucky: state.lucky,
    );
    if (next != null) _bigTimer = Timer(bigTime, _bigDone);
  }
}

final NotifierProviderFamily<LiveGiftEffects, LiveGiftEffectsState, String>
liveGiftEffectsProvider = NotifierProvider.autoDispose
    .family<LiveGiftEffects, LiveGiftEffectsState, String>(LiveGiftEffects.new);
