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

  /// The catalogue's tabs (add `LUCKY` with a lucky gift, D132).
  List<String> categories = const ['POPULAR', 'EVENT', 'FUN'];
  final Map<String, int> held;
  int coins;
  final bool ar;
  final String sender;

  final List<String> calls = [];
  final Map<String, AppFailure> failNext = {};
  final List<FakeGiftSend> sends = [];

  /// While set, a send waits for it (an answer still on its way).
  Completer<void>? sendGate;

  /// v1.27-live (D132): the odds served; the caller's age confirmation
  /// (a LUCKY send before it is refused with 403 AGE_UNCONFIRMED); the
  /// next lucky send's draws (none won by default).
  Map<String, Object?> Function({required bool ageConfirmed}) odds =
      ({required ageConfirmed}) => luckyOddsJson(
        reason: ageConfirmed ? null : 'AGE_UNCONFIRMED',
        ageConfirmed: ageConfirmed,
      );
  bool ageConfirmed = true;
  Map<String, Object?>? nextLucky;

  /// D154: the room's quip queue as the server answers it (each quip's
  /// delay), the rooms where the caller used their free quip, and the
  /// soundboard sounds played.
  int nextQuipDelayMs = 0;
  final Set<String> freeQuipUsed = {};
  final List<({String roomId, String soundCode})> sounds = [];

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
    return GiftCatalogue.fromJson(
      giftCatalogueJson(codes: codes, ar: ar, categories: categories),
    );
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
    final lucky = giftJson(giftCode)['category'] == 'LUCKY';
    if (lucky && !ageConfirmed) {
      throw const ServerFailure(
        code: ErrorCode.luckyGiftAgeUnconfirmed,
        rawCode: 'LUCKY_GIFT_AGE_UNCONFIRMED',
        debugMessage: 'x',
        statusCode: 403,
      );
    }
    final quip = giftJson(giftCode)['category'] == 'QUIPS';
    final total = giftFixturePrice(giftCode) * quantity * recipients.length;
    if (quip && total == 0 && !freeQuipUsed.add(roomId)) {
      throw conflict(ErrorCode.quipFreeUsed);
    }
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
    final draws = quantity * recipients.length;
    final luckyJson = !lucky
        ? null
        : (nextLucky ??
              {
                'draws': draws,
                'wins': <Object?>[],
                'coinsWon': 0,
                'topMultiplier': null,
                'downgraded': 0,
              });
    nextLucky = null;
    if (luckyJson != null) coins += (luckyJson['coinsWon']! as num).toInt();
    final result = LiveGiftResult.fromJson(
      liveGiftResultJson(
        gift: json,
        coins: coins,
        bagQuantity: held[giftCode] ?? 0,
        luckyResult: luckyJson,
        quip: quip
            ? liveQuipJson(
                id: id,
                roomId: roomId,
                code: giftCode,
                delayMs: nextQuipDelayMs,
                sender: giftUserJson(sender, sender),
              )
            : null,
      ),
    );
    _byClientId[clientId] = result;
    return result;
  }

  @override
  Future<LuckyGiftOdds> luckyOdds() async {
    _record('luckyOdds');
    return LuckyGiftOdds.fromJson(odds(ageConfirmed: ageConfirmed));
  }

  @override
  Future<LiveQuip> playSound(String roomId, {required String soundCode}) async {
    sounds.add((roomId: roomId, soundCode: soundCode));
    _record('playSound');
    return LiveQuip.fromJson(
      liveQuipJson(
        id: 'sound-${_serial++}',
        roomId: roomId,
        code: soundCode,
        kind: 'SOUNDBOARD',
        delayMs: nextQuipDelayMs,
        sender: giftUserJson(sender, sender),
      ),
    );
  }

  @override
  Future<void> confirmLuckyAge() async {
    _record('confirmLuckyAge');
    ageConfirmed = true;
  }
}
