// Wire models of live gifts (docs/contracts/openapi.yaml v1.23-live DRAFT,
// tag `gifts` and `sendLiveGift`, CP-020; `Gift.tag` v1.24.3-live, D117;
// CONVENTIONS §10.23).

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/shared_models.dart';

part 'live_gift_models.freezed.dart';
part 'live_gift_models.g.dart';

/// The person a gift panel opens with (their card's Gifts button).
typedef LiveGiftPreselect = ({String username, String name});

/// `GiftCategory`: a gift panel tab. Gifts of a category the app does not
/// know are dropped by the repository (§10.23).
enum GiftCategory {
  @JsonValue('POPULAR')
  popular('POPULAR'),
  @JsonValue('EVENT')
  event('EVENT'),
  @JsonValue('FUN')
  fun('FUN');

  new(this.wire);

  /// The exact string used on the wire.
  final String wire;

  /// The category named [wire], or null when the app does not know it.
  static GiftCategory? fromWire(Object? wire) =>
      values.where((c) => c.wire == wire).firstOrNull;
}

/// `GiftBadge`: the corner badge of a gift; unknown values show as [none].
enum GiftBadge {
  @JsonValue('NONE')
  none,
  @JsonValue('NEW')
  isNew,
  @JsonValue('EVENT')
  event,
}

/// `LiveGiftSource`: paid with coins or taken from the gift bag.
enum LiveGiftSource {
  @JsonValue('COINS')
  coins,
  @JsonValue('BAG')
  bag,
}

/// `GiftTag` (v1.24.3-live, D117): a gift's optional sub-category, shown as
/// a chip under the gift panel's tabs; [name] follows the app language.
@freezed
abstract class GiftTag with _$GiftTag {
  const factory({required String code, required String name}) = _GiftTag;

  factory fromJson(Map<String, dynamic> json) => _$GiftTagFromJson(json);
}

/// `Gift`: one gift of the catalogue. [name] follows the app language;
/// [assetKey] / [animationKey] name the app's bundled files.
@freezed
abstract class Gift with _$Gift {
  const factory({
    required String code,
    required GiftCategory category,
    required String name,
    required int priceCoins,
    required String assetKey,
    required String? animationKey,
    required int sortOrder,
    @JsonKey(unknownEnumValue: GiftBadge.none) required GiftBadge badge,

    /// The sub-category (v1.24.3-live), or null: none, or an older API.
    GiftTag? tag,
  }) = _Gift;

  factory fromJson(Map<String, dynamic> json) => _$GiftFromJson(json);
}

/// `GiftCatalogue` (`GET /gifts/catalogue`): the enabled gifts by tab.
/// [version] changes whenever anything but the names' language changes.
@freezed
abstract class GiftCatalogue with _$GiftCatalogue {
  const factory({
    required String version,
    required List<GiftCategory> categories,
    required List<int> quantities,
    required int maxRecipients,
    required int comboWindowSeconds,
    required List<Gift> data,
  }) = _GiftCatalogue;

  factory fromJson(Map<String, dynamic> json) => _$GiftCatalogueFromJson(json);
}

extension GiftCatalogueLookup on GiftCatalogue {
  /// The gift with [code], or null (unknown or disabled).
  Gift? byCode(String code) => data.where((g) => g.code == code).firstOrNull;

  /// The distinct tags of [category]'s gifts, in the order they first
  /// appear (the panel's chips after "All"; empty: no chip row).
  List<GiftTag> tagsOf(GiftCategory category) => giftTags(of(category));

  /// The catalogue's gifts of [category], in order.
  List<Gift> of(GiftCategory category) => [
    for (final g in data)
      if (g.category == category) g,
  ];
}

/// The distinct tags of [gifts] (by code), in the order they first appear.
List<GiftTag> giftTags(Iterable<Gift> gifts) {
  final seen = <String>{};
  return [
    for (final g in gifts)
      if (g.tag case final tag? when seen.add(tag.code)) tag,
  ];
}

/// `GiftBagItem`: a gift the caller holds, with how many.
@freezed
abstract class GiftBagItem with _$GiftBagItem {
  const factory({required Gift gift, required int quantity}) = _GiftBagItem;

  /// Every `Gift` field plus `quantity`, flat on the wire.
  factory fromJson(Map<String, dynamic> json) => GiftBagItem(
    gift: Gift.fromJson(json),
    quantity: (json['quantity']! as num).toInt(),
  );
}

/// `LiveGiftCombo`: [id] is the first send of the combo, [count] 1, 2, 3 …
/// and [quantity] the gifts per recipient in the combo so far.
@freezed
abstract class LiveGiftCombo with _$LiveGiftCombo {
  const factory({
    required String id,
    required int count,
    required int quantity,
  }) = _LiveGiftCombo;

  factory fromJson(Map<String, dynamic> json) => _$LiveGiftComboFromJson(json);
}

/// `LiveGift`: one send, as the answer and the `gift` data message carry
/// it. There is no name: the app takes it from its catalogue by
/// [giftCode].
@freezed
abstract class LiveGift with _$LiveGift {
  const factory({
    required String id,
    required String roomId,
    required String giftCode,
    required String assetKey,
    required String? animationKey,
    required int unitPrice,
    required int quantity,
    @JsonKey(unknownEnumValue: LiveGiftSource.coins)
    required LiveGiftSource source,
    required int totalCoins,
    required UserSummary sender,
    required List<UserSummary> recipients,
    required LiveGiftCombo combo,
    required DateTime createdAt,
  }) = _LiveGift;

  factory fromJson(Map<String, dynamic> json) => _$LiveGiftFromJson(json);
}

/// `LiveGiftResult` (`POST /live/rooms/{roomId}/gifts`): the send, the coin
/// balance and what the bag holds of that gift after it.
@freezed
abstract class LiveGiftResult with _$LiveGiftResult {
  const factory({
    required LiveGift gift,
    required int coins,
    required int bagQuantity,
  }) = _LiveGiftResult;

  factory fromJson(Map<String, dynamic> json) => _$LiveGiftResultFromJson(json);
}
