import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:material_ui/material_ui.dart' show immutable;

/// What a live shows of the gifts sent in it now (CP-020, §10.23): up to
/// [LiveGiftEffects.maxBanners] banners (one per combo, updated in place)
/// and one full-screen effect for a gift with an animation (D145c: never
/// the gift's still picture blown up).
@immutable
class LiveGiftEffectsState {
  const new({this.banners = const [], this.big, this.lucky});

  /// The banners on screen, oldest first.
  final List<LiveGift> banners;

  /// The animated gift playing now, or null.
  final LiveGift? big;

  /// D132: the lucky win announced now, or null: the room's big wins
  /// (×[LiveGiftEffects.luckyBanner] or more) and, D159, the caller's own
  /// wins of every tier.
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

  /// Banners on screen at once; more wait in turn (D145: 3, was 2).
  static const maxBanners = 3;

  /// A banner stays this long after the last send of its streak (D178,
  /// owner: 3 s each; D145c had 4).
  static const bannerTime = Duration(seconds: 3);

  /// How long the effect may stay without saying it fetches or plays an
  /// SVGA ([bigHold]); then the next one plays.
  static const bigTime = Duration(milliseconds: 3200);

  /// An effect that fetches or plays an SVGA ([bigHold]) ends when it has
  /// played ([bigDone]); this is only the longest it may stay on screen.
  static const maxAnimatedTime = Duration(seconds: 30);

  /// At most this many sends wait for a banner or the large effect.
  static const maxWaiting = 20;

  /// D131/D132 (owner): a lucky win of at least this multiplier gets the
  /// room banner, for [luckyTime].
  static const luckyBanner = 100;

  /// D145e (owner: a short ~3 s moment): the card's whole life, entrance to
  /// fade-out (was 4 s for the D132 pill). D159: the owner's win banner's
  /// timeline, 3.5 s in his revision 2.
  static const luckyTime = Duration(milliseconds: 3500);

  /// D159: wins waiting for their banner behind the one on screen; a bigger
  /// win takes the place of the smaller ones waiting.
  static const maxLuckyWaiting = 3;

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

  /// D132: announces [win] (a `lucky-win` message of the room). D178
  /// (owner: «حتى الصغيرة»): every win, ×5 and up — the server sends them
  /// all to the room since v1.41-live (it sent only ×100+ before).
  void showLucky(LuckyWin win) {
    if (!ref.mounted || win.multiplier <= 0) return;
    _queueLucky(win);
  }

  /// D159: the caller's own lucky send [result] won: its banner, whatever
  /// the tier (a ×5 gets the sapphire frame). The room's `lucky-win`
  /// message for the same send (×100 and more) then shows nothing more.
  void showOwnWin(LiveGiftResult result) {
    final lucky = result.luckyResult;
    final top = lucky?.topMultiplier;
    if (!ref.mounted || lucky == null || top == null || top <= 0) return;
    final gift = result.gift;
    _queueLucky(
      LuckyWin(
        giftId: gift.id,
        roomId: gift.roomId,
        giftCode: gift.giftCode,
        sender: gift.sender,
        multiplier: top,
        coinsWon: lucky.coinsWon,
        createdAt: gift.createdAt,
      ),
    );
  }

  /// One banner at a time (a send seen twice shows once). D159: at most
  /// [maxLuckyWaiting] wait; a bigger win replaces the smaller ones
  /// waiting, and a win no bigger than any of a full queue is dropped.
  void _queueLucky(LuckyWin win) {
    if (!_seen.add('lucky:${win.giftId}')) return;
    // D178: its chat line, for everyone in the room.
    _chat((chat) => chat.addLuckyWin(win));
    if (state.lucky == null) {
      _setLucky(win);
      return;
    }
    _luckyWaiting.removeWhere((w) => w.multiplier < win.multiplier);
    if (_luckyWaiting.length < maxLuckyWaiting) _luckyWaiting.add(win);
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

  /// D178: this live's chat (when the room has one open).
  void _chat(void Function(LiveChatController chat) add) {
    try {
      add(ref.read(liveChatProvider(roomId).notifier));
    } on Object {
      // No chat in this room (yet): nothing to add to.
    }
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
    // D145c (owner): the strip comes first, for every gift, on every
    // device — the sender's own answer included (and a gift to oneself).
    _banner(gift);
    // D178: and its line in this live's chat.
    _chat((chat) => chat.addGift(gift));
    // Only a gift with an SVGA plays the full-screen effect: the still
    // picture is never blown up mid-screen (it is in the strip).
    if (_animated(gift)) _big(gift);
  }

  bool _animated(LiveGift g) {
    if (g.animationKey != null || g.animationUrl != null) return true;
    // An older server's message without the hosted art (D126).
    final art = ref.read(giftCatalogueProvider).value?.byCode(g.giftCode);
    return art?.animationUrl != null || art?.animationKey != null;
  }

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

/// D145c: the height of the gift panel open over the room (from the
/// screen's bottom), or null while it is closed — so the gift strips keep
/// above it and the sender sees their own gift's strip (normal gifts keep
/// the panel open).
class LiveGiftPanelHeight extends Notifier<double?> {
  @override
  double? build() => null;

  void set(double? height) {
    if (!ref.mounted || state == height) return;
    state = height;
  }
}

final NotifierProvider<LiveGiftPanelHeight, double?>
liveGiftPanelHeightProvider = NotifierProvider<LiveGiftPanelHeight, double?>(
  LiveGiftPanelHeight.new,
);

/// D145c: the top of a live's chat on the screen (from the screen's top),
/// as the room's layout reports it, or null — the gift strips keep above
/// the chat text.
class LiveChatTop extends Notifier<double?> {
  new(this.roomId);

  final String roomId;

  @override
  double? build() => null;

  void set(double? top) {
    if (!ref.mounted || state == top) return;
    state = top;
  }
}

final NotifierProviderFamily<LiveChatTop, double?, String> liveChatTopProvider =
    NotifierProvider.autoDispose.family<LiveChatTop, double?, String>(
      LiveChatTop.new,
    );
