// In-memory CP-020 live gifts (tests only). Every call is recorded in
// `calls`; a failure set in `failNext[method]` is thrown once by it. Sends
// follow §10.23: the price, the bag, combos and the clientId retry.

import 'dart:async';

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';

import '../fixtures/live/live_gift_fixtures.dart';

/// One `POST /live/rooms/{roomId}/gifts` the app made.
typedef FakeGiftSend = ({
  String roomId,
  String giftCode,
  int quantity,
  List<String> recipients,
  LiveGiftSource source,
  String clientId,
});

class FakeLiveGiftRepository implements LiveGiftRepository {
  /// The catalogue holds [codes] (default: empty, as production starts);
  /// the bag holds [held] (code → quantity); the wallet [coins].
  new({
    this.codes = const [],
    Map<String, int> held = const {},
    this.coins = 1000,
    this.ar = false,
    this.sender = 'me',
  }) : held = Map.of(held);

  List<String> codes;
  final Map<String, int> held;
  int coins;
  final bool ar;
  final String sender;

  final List<String> calls = [];
  final Map<String, AppFailure> failNext = {};
  final List<FakeGiftSend> sends = [];

  /// While set, a send waits for it (an answer still on its way).
  Completer<void>? sendGate;

  final Map<String, LiveGiftResult> _byClientId = {};
  String? _comboKey;
  String? _comboId;
  int _comboCount = 0;
  int _serial = 0;

  void _record(String call) {
    calls.add(call);
    if (failNext.remove(call) case final failure?) throw failure;
  }

  static ServerFailure conflict(ErrorCode code) => ServerFailure(
    code: code,
    rawCode: code.wire,
    debugMessage: code.wire,
    statusCode: 409,
  );

  @override
  Future<GiftCatalogue> catalogue() async {
    _record('catalogue');
    return GiftCatalogue.fromJson(giftCatalogueJson(codes: codes, ar: ar));
  }

  @override
  Future<List<GiftBagItem>> bag() async {
    _record('bag');
    return [
      for (final code in giftFixtureCodes)
        if ((held[code] ?? 0) > 0)
          GiftBagItem.fromJson(giftBagItemJson(code, held[code]!, ar: ar)),
    ];
  }

  @override
  Future<LiveGiftResult> send(
    String roomId, {
    required String giftCode,
    required int quantity,
    required List<String> recipients,
    required LiveGiftSource source,
    required String clientId,
  }) async {
    sends.add((
      roomId: roomId,
      giftCode: giftCode,
      quantity: quantity,
      recipients: recipients,
      source: source,
      clientId: clientId,
    ));
    if (sendGate case final gate?) await gate.future;
    _record('send');
    if (_byClientId[clientId] case final first?) {
      return first.copyWith(coins: coins, bagQuantity: held[giftCode] ?? 0);
    }
    if (!codes.contains(giftCode) && !held.containsKey(giftCode)) {
      throw conflict(ErrorCode.giftUnavailable);
    }
    final total = giftFixturePrice(giftCode) * quantity * recipients.length;
    if (source == LiveGiftSource.coins) {
      if (coins < total) throw conflict(ErrorCode.insufficientCoins);
      coins -= total;
    } else {
      final have = held[giftCode] ?? 0;
      final need = quantity * recipients.length;
      if (have < need) throw conflict(ErrorCode.giftBagInsufficient);
      held[giftCode] = have - need;
    }
    final id = 'gift-${_serial++}';
    final key = '$giftCode|${([...recipients]..sort()).join(',')}';
    if (key == _comboKey) {
      _comboCount++;
    } else {
      _comboKey = key;
      _comboId = id;
      _comboCount = 1;
    }
    final json = liveGiftJson(
      id: id,
      roomId: roomId,
      code: giftCode,
      quantity: quantity,
      source: source == LiveGiftSource.bag ? 'BAG' : 'COINS',
      sender: giftUserJson(sender, sender),
      recipients: [for (final r in recipients) giftUserJson(r, r)],
      comboId: _comboId,
      comboCount: _comboCount,
    );
    final result = LiveGiftResult.fromJson(
      liveGiftResultJson(
        gift: json,
        coins: coins,
        bagQuantity: held[giftCode] ?? 0,
      ),
    );
    _byClientId[clientId] = result;
    return result;
  }
}
