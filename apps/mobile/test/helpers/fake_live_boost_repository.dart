// In-memory traffic cards (D154b, tests only; D233: the owner's rocket
// stages and prices in coins), a set
// of slots, the caller's cards and a wallet, following §10.34's rules for
// one live at a time.

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/data/live_boost_repository.dart';
import 'package:kabso_live/features/live/domain/live_boost_models.dart';

class FakeLiveBoostRepository implements LiveBoostRepository {
  new({
    this.coins = 1000000,
    Map<int, int> cards = const {},
    this.waitMinutes = 0,
  }) : cards = Map.of(cards);

  int coins;
  final Map<int, int> cards;

  /// How long a new card waits for a slot (0: starts now).
  int waitMinutes;
  final List<LiveBoostedRoom> boosted = [];
  final List<({String roomId, int minutes, LiveBoostSource source})> bought =
      [];
  final Map<String, LiveBoost> byRoom = {};

  /// D233: the owner's prices, stages 1–4 (they save nothing).
  static const prices = {10: 200000, 20: 550000, 30: 1500000, 60: 3500000};
  static const _stage = {10: 1, 20: 2, 30: 3, 60: 4};

  static const _user = UserSummary(
    id: 'user-me',
    username: 'me',
    displayName: 'Me',
    avatarUrl: null,
  );

  static ServerFailure conflict(ErrorCode code) => ServerFailure(
    code: code,
    rawCode: code.wire,
    debugMessage: code.wire,
    statusCode: 409,
  );

  List<LiveBoostCardStock> get _stock => [
    for (final e in cards.entries)
      if (e.value > 0) LiveBoostCardStock(minutes: e.key, quantity: e.value),
  ];

  @override
  Future<LiveBoostOffers> offers({String? roomId}) async => LiveBoostOffers(
    slots: 3,
    maxWaitMinutes: 180,
    options: [
      for (final e in prices.entries)
        LiveBoostOption(
          minutes: e.key,
          priceCoins: e.value,
          savePercent: 0,
          stage: _stage[e.key]!,
        ),
    ],
    cards: _stock,
    nextStartAt: DateTime.now().add(Duration(minutes: waitMinutes)),
    roomBoost: roomId == null ? null : byRoom[roomId],
  );

  @override
  Future<List<LiveBoostedRoom>> active() async => [...boosted];

  @override
  Future<LiveBoostResult> buy(
    String roomId, {
    required int minutes,
    required LiveBoostSource source,
    required String clientId,
  }) async {
    if (byRoom.containsKey(roomId)) throw conflict(ErrorCode.boostRoomBusy);
    if (source == LiveBoostSource.card) {
      if ((cards[minutes] ?? 0) < 1) {
        throw conflict(ErrorCode.boostCardInsufficient);
      }
      cards[minutes] = cards[minutes]! - 1;
    } else {
      final price = prices[minutes]!;
      if (coins < price) throw conflict(ErrorCode.insufficientCoins);
      coins -= price;
    }
    bought.add((roomId: roomId, minutes: minutes, source: source));
    final start = DateTime.now().add(Duration(minutes: waitMinutes));
    final boost = LiveBoost(
      id: 'boost-${bought.length}',
      roomId: roomId,
      host: _user,
      buyer: _user,
      minutes: minutes,
      stage: _stage[minutes]!,
      source: source,
      coinsCharged: source == LiveBoostSource.coins ? prices[minutes]! : 0,
      state: waitMinutes > 0 ? LiveBoostState.waiting : LiveBoostState.running,
      startsAt: start,
      endsAt: start.add(Duration(minutes: minutes)),
      createdAt: DateTime.now(),
    );
    byRoom[roomId] = boost;
    return LiveBoostResult(boost: boost, coins: coins, cards: _stock);
  }
}
