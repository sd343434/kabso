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
  const new({this.banners = const [], this.big});

  /// The banners on screen, oldest first.
  final List<LiveGift> banners;

  /// The big gift playing now, or null.
  final LiveGift? big;
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

  /// The large effect's length (the image's grow and fade; an animation
  /// file plays within it).
  static const bigTime = Duration(milliseconds: 3200);

  /// A send worth at least this many coins plays the large effect (as does
  /// a gift with an `animationKey`).
  static const bigGiftCoins = 1000;

  /// At most this many sends wait for a banner or the large effect.
  static const maxWaiting = 20;

  StreamSubscription<LiveChatEvent>? _events;
  final _seen = <String>{};
  final _waiting = <LiveGift>[];
  final _waitingBig = <LiveGift>[];
  final _timers = <String, Timer>{};
  Timer? _bigTimer;

  @override
  LiveGiftEffectsState build() {
    ref.onDispose(() {
      unawaited(_events?.cancel());
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
      _bigTimer?.cancel();
    });
    return const LiveGiftEffectsState();
  }

  /// Plays the [engine]'s `gift` messages from now on (once).
  void attach(LiveMediaEngine engine) {
    if (_events != null) return;
    _events = engine.chatEvents.listen((event) {
      if (event is LiveGiftReceived && event.gift.roomId == roomId) {
        show(event.gift);
      }
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
    if (gift.animationKey != null || gift.totalCoins >= bigGiftCoins) {
      _big(gift);
    }
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
      state = LiveGiftEffectsState(banners: [...banners, gift], big: state.big);
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
    state = LiveGiftEffectsState(banners: banners, big: state.big);
  }

  void _big(LiveGift gift) {
    if (state.big != null) {
      if (_waitingBig.length < maxWaiting) _waitingBig.add(gift);
      return;
    }
    state = LiveGiftEffectsState(banners: state.banners, big: gift);
    _bigTimer = Timer(bigTime, _bigDone);
  }

  void _bigDone() {
    _bigTimer = null;
    if (!ref.mounted) return;
    final next = _waitingBig.isEmpty ? null : _waitingBig.removeAt(0);
    state = LiveGiftEffectsState(banners: state.banners, big: next);
    if (next != null) _bigTimer = Timer(bigTime, _bigDone);
  }
}

final NotifierProviderFamily<LiveGiftEffects, LiveGiftEffectsState, String>
liveGiftEffectsProvider = NotifierProvider.autoDispose
    .family<LiveGiftEffects, LiveGiftEffectsState, String>(LiveGiftEffects.new);
