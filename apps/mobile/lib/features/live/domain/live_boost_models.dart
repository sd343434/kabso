// Wire models of traffic cards «بطاقة الزيارات» (docs/contracts/openapi.yaml
// v1.33-live DRAFT: `getLiveBoostOffers`, `listActiveLiveBoosts`,
// `buyLiveBoost`, `listLiveRoomBoosts`; CONVENTIONS §10.34, D154b).

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';

part 'live_boost_models.freezed.dart';
part 'live_boost_models.g.dart';

/// How a card is paid: coins, or one of the caller's cards.
enum LiveBoostSource {
  @JsonValue('COINS')
  coins('COINS'),
  @JsonValue('CARD')
  card('CARD');

  new(this.wire);

  final String wire;
}

/// `LiveBoostState`; unknown values read as [done].
enum LiveBoostState {
  @JsonValue('WAITING')
  waiting,
  @JsonValue('RUNNING')
  running,
  @JsonValue('DONE')
  done,
  @JsonValue('CANCELLED')
  cancelled,
}

/// `LiveBoost`: one traffic card used on a live. [startsAt] is when it
/// starts at the latest while [state] is [LiveBoostState.waiting].
@freezed
abstract class LiveBoost with _$LiveBoost {
  const factory({
    required String id,
    required String roomId,
    required UserSummary host,
    required UserSummary buyer,
    required int minutes,
    @JsonKey(unknownEnumValue: LiveBoostSource.coins)
    required LiveBoostSource source,
    required int coinsCharged,
    @JsonKey(unknownEnumValue: LiveBoostState.done)
    required LiveBoostState state,
    required DateTime startsAt,
    required DateTime endsAt,
    required DateTime createdAt,
  }) = _LiveBoost;

  factory fromJson(Map<String, dynamic> json) => _$LiveBoostFromJson(json);
}

/// `LiveBoostOption`: a length on sale, its price and what it saves.
@freezed
abstract class LiveBoostOption with _$LiveBoostOption {
  const factory({
    required int minutes,
    required int priceCoins,
    required int savePercent,
  }) = _LiveBoostOption;

  factory fromJson(Map<String, dynamic> json) =>
      _$LiveBoostOptionFromJson(json);
}

/// `LiveBoostCardStock`: cards the caller holds of one length.
@freezed
abstract class LiveBoostCardStock with _$LiveBoostCardStock {
  const factory({required int minutes, required int quantity}) =
      _LiveBoostCardStock;

  factory fromJson(Map<String, dynamic> json) =>
      _$LiveBoostCardStockFromJson(json);
}

/// `LiveBoostOffers` (`GET /live/boosts/offers`).
@freezed
abstract class LiveBoostOffers with _$LiveBoostOffers {
  const factory({
    required int slots,
    required int maxWaitMinutes,
    required List<LiveBoostOption> options,
    required List<LiveBoostCardStock> cards,
    required DateTime nextStartAt,
    LiveBoost? roomBoost,
  }) = _LiveBoostOffers;

  factory fromJson(Map<String, dynamic> json) =>
      _$LiveBoostOffersFromJson(json);
}

/// `LiveBoostResult` (`POST /live/rooms/{roomId}/boosts`).
@freezed
abstract class LiveBoostResult with _$LiveBoostResult {
  const factory({
    required LiveBoost boost,
    required int coins,
    required List<LiveBoostCardStock> cards,
  }) = _LiveBoostResult;

  factory fromJson(Map<String, dynamic> json) =>
      _$LiveBoostResultFromJson(json);
}

/// `LiveBoostedRoom`: a live in a paid «مميز» slot now.
@freezed
abstract class LiveBoostedRoom with _$LiveBoostedRoom {
  const factory({required LiveRoomSummary room, required DateTime endsAt}) =
      _LiveBoostedRoom;

  factory fromJson(Map<String, dynamic> json) =>
      _$LiveBoostedRoomFromJson(json);
}
