import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:material_ui/material_ui.dart' show immutable;

/// What a lucky combo sends again on every tap (D145): the gift, the
/// quantity picked in the panel and the same recipients, with coins.
@immutable
class LuckyComboGift {
  const new({
    required this.code,
    required this.quantity,
    required this.recipients,
    required this.unitPrice,
    required this.assetKey,
    this.imageUrl,
  });

  final String code;
  final int quantity;

  /// Usernames, in the order the panel sent them.
  final List<String> recipients;
  final int unitPrice;
  final String assetKey;
  final String? imageUrl;

  /// What one tap costs.
  int get cost => unitPrice * quantity * recipients.length;
}

/// Why a combo stopped before its ring ran out.
@immutable
class LuckyComboStop {
  const new({required this.id, this.failure, this.notEnoughCoins = false});

  /// Grows with every stop (the screen shows each once).
  final int id;

  /// The refused or failed send, or null.
  final AppFailure? failure;

  /// The wallet could not pay the next tap (no request was made), or the
  /// server answered `INSUFFICIENT_COINS`.
  final bool notEnoughCoins;
}

/// The lucky combo of one live (D145). Owner: lucky gifts only — normal
/// gifts keep the panel open and its Send.
@immutable
class LuckyComboState {
  const new({
    this.gift,
    this.visible = false,
    this.count = 0,
    this.comboQuantity = 0,
    this.queued = 0,
    this.sending = false,
    this.ring = 0,
    this.taps = 0,
    this.draws = 0,
    this.coinsWon = 0,
    this.topMultiplier,
    this.last,
    this.lastId = 0,
    this.stop,
  });

  /// The gift the button sends again; null: no combo yet.
  final LuckyComboGift? gift;

  /// The button is on screen (its ring is running).
  final bool visible;

  /// The server's combo count of the last answer (`LiveGift.combo.count`).
  final int count;

  /// D145a: the gifts per recipient in the server's combo so far
  /// (`LiveGift.combo.quantity`): the one ×N the room shows.
  final int comboQuantity;

  /// Taps waiting behind the one in flight.
  final int queued;
  final bool sending;

  /// Grows on each (re)start of the ring: the button restarts it.
  final int ring;

  /// Grows on each accepted tap: the button bounces and a gift flies.
  final int taps;

  /// The streak's lucky totals (every answer of this combo).
  final int draws;
  final int coinsWon;
  final int? topMultiplier;

  /// The last answer's draw result, and its id (grows per answer).
  final LuckyGiftResult? last;
  final int lastId;

  /// Why the combo stopped, or null.
  final LuckyComboStop? stop;

  LuckyComboState copyWith({
    LuckyComboGift? gift,
    bool? visible,
    int? count,
    int? comboQuantity,
    int? queued,
    bool? sending,
    int? ring,
    int? taps,
    int? draws,
    int? coinsWon,
    int? topMultiplier,
    LuckyGiftResult? last,
    int? lastId,
    LuckyComboStop? stop,
  }) => LuckyComboState(
    gift: gift ?? this.gift,
    visible: visible ?? this.visible,
    count: count ?? this.count,
    comboQuantity: comboQuantity ?? this.comboQuantity,
    queued: queued ?? this.queued,
    sending: sending ?? this.sending,
    ring: ring ?? this.ring,
    taps: taps ?? this.taps,
    draws: draws ?? this.draws,
    coinsWon: coinsWon ?? this.coinsWon,
    topMultiplier: topMultiplier ?? this.topMultiplier,
    last: last ?? this.last,
    lastId: lastId ?? this.lastId,
    stop: stop ?? this.stop,
  );
}

/// D145 (owner, after another app's recording): after a lucky gift is sent
/// from the panel, the panel closes and a round Combo button shows over the
/// bar with a countdown ring of [ringTime]. Each tap sends the same gift to
/// the same people again (a new `clientId` per tap) and restarts the ring;
/// when the ring runs out the button goes.
///
/// Taps are queued and sent one at a time, never merged: a send's
/// `quantity` must be one of the catalogue's quantities (§10.23), so N taps
/// cannot become one request, and each lucky gift is its own draw anyway
/// (§10.27). An answer lost to the network is sent once more with the same
/// `clientId` (the server never charges it twice); any other failure stops
/// the combo and says why. A tap the known balance cannot pay stops the
/// combo without a request.
class LuckyComboController extends Notifier<LuckyComboState> {
  new(this.roomId);

  final String roomId;

  /// One constant for the ring (inside the server's 5 s combo window, so a
  /// tap before the ring ends continues the server's combo).
  static const ringTime = Duration(seconds: 4);

  /// At most this many taps wait (each is a real charge); more taps while
  /// the queue is full are not taken.
  static const maxQueued = 20;

  Timer? _ring;
  int _stops = 0;

  /// Bumped by [start] and [stop]: a drain of an older combo stops.
  int _epoch = 0;

  @override
  LuckyComboState build() {
    ref.onDispose(() => _ring?.cancel());
    return const LuckyComboState();
  }

  /// The panel sent [gift] and got [first]; [pending] taps of the panel's
  /// Send were still waiting (they are sent by the combo).
  void start(LuckyComboGift gift, LiveGiftResult first, {int pending = 0}) {
    _epoch++;
    final lucky = first.luckyResult;
    state = LuckyComboState(
      gift: gift,
      visible: true,
      count: first.gift.combo.count,
      comboQuantity: first.gift.combo.quantity,
      ring: state.ring + 1,
      taps: state.taps,
      draws: lucky?.draws ?? 0,
      coinsWon: lucky?.coinsWon ?? 0,
      topMultiplier: lucky?.topMultiplier,
      last: lucky,
      lastId: state.lastId + 1,
      queued: pending.clamp(0, maxQueued),
    );
    _restartRing();
    if (state.queued > 0) unawaited(_drain(_epoch));
  }

  /// A tap on the button: true when it was taken (queued).
  bool tap() {
    final gift = state.gift;
    if (!state.visible || gift == null) return false;
    if (state.queued >= maxQueued) return false;
    final coins = ref.read(liveCoinsProvider).value;
    final committed = (state.queued + (state.sending ? 1 : 0)) * gift.cost;
    if (coins != null && coins - committed < gift.cost) {
      _stopWith(const LuckyComboStop(id: 0, notEnoughCoins: true));
      return false;
    }
    state = state.copyWith(
      queued: state.queued + 1,
      taps: state.taps + 1,
      ring: state.ring + 1,
    );
    _restartRing();
    if (!state.sending) unawaited(_drain(_epoch));
    return true;
  }

  /// Hides the button now (the queue is dropped).
  void stop() {
    _epoch++;
    _ring?.cancel();
    state = state.copyWith(visible: false, queued: 0, sending: false);
  }

  void _restartRing() {
    _ring?.cancel();
    _ring = Timer(ringTime, () {
      if (!ref.mounted) return;
      // The ring ran out: the button goes; taps already made still go out.
      state = state.copyWith(visible: false);
    });
  }

  void _stopWith(LuckyComboStop stop) {
    _epoch++;
    _ring?.cancel();
    state = state.copyWith(
      visible: false,
      queued: 0,
      sending: false,
      stop: LuckyComboStop(
        id: ++_stops,
        failure: stop.failure,
        notEnoughCoins: stop.notEnoughCoins,
      ),
    );
  }

  Future<void> _drain(int epoch) async {
    if (state.sending) return;
    state = state.copyWith(sending: true);
    while (ref.mounted && epoch == _epoch && state.queued > 0) {
      final gift = state.gift!;
      state = state.copyWith(queued: state.queued - 1);
      final ok = await _sendOne(gift, epoch);
      if (!ok) return;
    }
    if (ref.mounted && epoch == _epoch) {
      state = state.copyWith(sending: false);
    }
  }

  Future<bool> _sendOne(LuckyComboGift gift, int epoch) async {
    final clientId = newClientId();
    final repo = ref.read(liveGiftRepositoryProvider);
    Future<LiveGiftResult> send() => repo.send(
      roomId,
      giftCode: gift.code,
      quantity: gift.quantity,
      recipients: gift.recipients,
      source: LiveGiftSource.coins,
      clientId: clientId,
    );
    LiveGiftResult result;
    try {
      try {
        result = await send();
      } on Object catch (e) {
        // A lost answer: once more with the same id (never charged twice).
        if (toAppFailure(e) is ServerFailure) rethrow;
        result = await send();
      }
    } on Object catch (e) {
      if (!ref.mounted) return false;
      final failure = toAppFailure(e);
      if (failure.code == ErrorCode.insufficientCoins &&
          ref.exists(liveCoinsProvider)) {
        ref.invalidate(liveCoinsProvider);
      }
      _stopWith(
        LuckyComboStop(
          id: 0,
          failure: failure,
          notEnoughCoins: failure.code == ErrorCode.insufficientCoins,
        ),
      );
      return false;
    }
    if (!ref.mounted) return false;
    if (ref.exists(liveCoinsProvider)) {
      ref.read(liveCoinsProvider.notifier).set(result.coins);
    }
    ref.read(liveGiftEffectsProvider(roomId).notifier).show(result.gift);
    final lucky = result.luckyResult;
    final best = switch ((state.topMultiplier, lucky?.topMultiplier)) {
      (final a?, final b?) => a > b ? a : b,
      (final a, final b) => a ?? b,
    };
    state = LuckyComboState(
      gift: state.gift,
      visible: state.visible,
      count: result.gift.combo.count,
      comboQuantity: result.gift.combo.quantity,
      queued: state.queued,
      sending: epoch == _epoch && state.sending,
      ring: state.ring,
      taps: state.taps,
      draws: state.draws + (lucky?.draws ?? 0),
      coinsWon: state.coinsWon + (lucky?.coinsWon ?? 0),
      topMultiplier: best,
      last: lucky ?? state.last,
      lastId: state.lastId + 1,
      stop: state.stop,
    );
    return epoch == _epoch;
  }
}

final NotifierProviderFamily<LuckyComboController, LuckyComboState, String>
liveLuckyComboProvider = NotifierProvider.autoDispose
    .family<LuckyComboController, LuckyComboState, String>(
      LuckyComboController.new,
    );
