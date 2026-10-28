// Wire models of live gifts (docs/contracts/openapi.yaml v1.23-live DRAFT,
// tag `gifts` and `sendLiveGift`, CP-020; `Gift.tag` v1.24.3-live, D117;
// hosted art v1.26.2-live, D126; CONVENTIONS §10.23).

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
  fun('FUN'),

  /// v1.27-live (D132, §10.27): lucky gifts (listed only while they are on).
  @JsonValue('LUCKY')
  lucky('LUCKY'),

  /// v1.32-live (D154, §10.33): «إفيهات» quips — a sound (and its line)
  /// played to the whole room, one at a time.
  @JsonValue('QUIPS')
  quips('QUIPS');

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

/// `GiftQuip` (v1.32-live, D154, §10.33): a QUIPS gift's bundled sound
/// ([soundKey] under `assets/sounds/quips/`), its length and its words
/// (null: a sound without words).
@freezed
abstract class GiftQuip with _$GiftQuip {
  const factory({
    required String soundKey,
    required int durationMs,
    String? text,
  }) = _GiftQuip;

  factory fromJson(Map<String, dynamic> json) => _$GiftQuipFromJson(json);
}

/// `Gift`: one gift of the catalogue. [name] follows the app language;
/// [assetKey] / [animationKey] name the app's bundled files, [imageUrl] /
/// [animationUrl] the art hosted on the server (D126), which wins.
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

    /// The hosted static image (v1.26.2-live), or null: the bundled one.
    String? imageUrl,

    /// The hosted SVGA effect (v1.26.2-live), or null: the bundled one.
    String? animationUrl,

    /// [animationUrl]'s size in bytes (whether to prefetch it), or null.
    int? animationBytes,

    /// v1.32-live (D154): a quip's sound and words; null for other gifts.
    GiftQuip? quip,
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

    /// The gift's hosted art now (v1.26.2-live, D126), as in [Gift].
    String? imageUrl,
    String? animationUrl,
    int? animationBytes,
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

    /// v1.27-live (D132): the draws of a LUCKY send (absent otherwise).
    LuckyGiftResult? luckyResult,

    /// v1.32-live (D154): a quip's place in the room's queue (absent
    /// otherwise, and for a retry).
    LiveQuip? quip,
  }) = _LiveGiftResult;

  factory fromJson(Map<String, dynamic> json) => _$LiveGiftResultFromJson(json);
}

/// `LiveQuipKind`: sent from the gift panel, or the host's or a
/// moderator's soundboard.
enum LiveQuipKind {
  @JsonValue('GIFT')
  gift,
  @JsonValue('SOUNDBOARD')
  soundboard,
}

/// `LiveQuip` (v1.32-live, D154, §10.33): one sound for the whole room, as
/// the `quip` data message (topic `quip`) and the send's answer carry it.
/// Every app plays it [delayMs] after it receives it (the room's one
/// queue), with [text] as a chat bubble for [durationMs].
@freezed
abstract class LiveQuip with _$LiveQuip {
  const factory({
    required String id,
    required String roomId,
    @JsonKey(unknownEnumValue: LiveQuipKind.gift) required LiveQuipKind kind,
    required String giftCode,
    required String soundKey,
    required int durationMs,
    required bool free,
    required UserSummary sender,
    required int delayMs,
    required DateTime createdAt,
    String? text,
  }) = _LiveQuip;

  factory fromJson(Map<String, dynamic> json) => _$LiveQuipFromJson(json);
}

/// `LuckyGiftWin` (v1.27-live, D132): the draws of one send that paid one
/// multiplier.
@freezed
abstract class LuckyGiftWin with _$LuckyGiftWin {
  const factory({
    required int multiplier,
    required int count,
    required int coins,
  }) = _LuckyGiftWin;

  factory fromJson(Map<String, dynamic> json) => _$LuckyGiftWinFromJson(json);
}

/// `LuckyGiftResult` (v1.27-live, D132, §10.27): one draw per gift
/// (`quantity × recipients`); the coins won are already in the balance.
@freezed
abstract class LuckyGiftResult with _$LuckyGiftResult {
  const factory({
    required int draws,
    required List<LuckyGiftWin> wins,
    required int coinsWon,
    required int? topMultiplier,
    required int downgraded,

    /// v1.30-live (D148): a draw of this send was paid by the guarantee
    /// (×5 after 15 losing draws in a row); the celebration says «ضمان».
    /// Absent from older servers.
    @Default(false) bool guaranteed,
  }) = _LuckyGiftResult;

  factory fromJson(Map<String, dynamic> json) =>
      _$LuckyGiftResultFromJson(json);
}

/// `LuckyGiftOutcome`: one winning multiplier and its chance per draw.
@freezed
abstract class LuckyGiftOutcome with _$LuckyGiftOutcome {
  const factory({
    required int multiplier,
    required int chancePerMillion,
    required double probability,
  }) = _LuckyGiftOutcome;

  factory fromJson(Map<String, dynamic> json) =>
      _$LuckyGiftOutcomeFromJson(json);
}

/// Why the caller may not send lucky gifts now; unknown values read as
/// [unknown] ("not eligible").
enum LuckyGiftIneligibility {
  @JsonValue('DISABLED')
  disabled,
  @JsonValue('REGION_UNAVAILABLE')
  regionUnavailable,
  @JsonValue('AGE_UNCONFIRMED')
  ageUnconfirmed,
  unknown,
}

/// `LuckyGiftEligibility`: the signed-in caller's standing.
@freezed
abstract class LuckyGiftEligibility with _$LuckyGiftEligibility {
  const factory({
    required bool eligible,
    @JsonKey(unknownEnumValue: LuckyGiftIneligibility.unknown)
    required LuckyGiftIneligibility? reason,
    required bool ageConfirmed,
  }) = _LuckyGiftEligibility;

  factory fromJson(Map<String, dynamic> json) =>
      _$LuckyGiftEligibilityFromJson(json);
}

/// `LuckyGiftOdds` (`GET /live/gifts/lucky/odds`, v1.27-live, D132): the
/// published odds; [caller] is null for a guest.
@freezed
abstract class LuckyGiftOdds with _$LuckyGiftOdds {
  const factory({
    required bool enabled,
    required int drawsPerGift,
    required double returnPercent,
    required double hostSharePercent,
    required List<LuckyGiftOutcome> outcomes,
    required int noWinChancePerMillion,
    required double noWinProbability,
    required int bigWinMultiplier,
    required bool dailyProtection,
    required String dayTimeZone,
    required int minimumAge,
    required LuckyGiftEligibility? caller,

    /// v1.30-live (D148): the per-sender guarantee; null when it is off (or
    /// from an older server).
    LuckyGiftPity? pity,
  }) = _LuckyGiftOdds;

  factory fromJson(Map<String, dynamic> json) => _$LuckyGiftOddsFromJson(json);
}

/// `LuckyGiftPity` (v1.30-live, D148, §10.27): after [after] losing lucky
/// draws in a row (any room) the sender's next draw pays at least
/// ×[multiplier].
@freezed
abstract class LuckyGiftPity with _$LuckyGiftPity {
  const factory({required int after, required int multiplier}) = _LuckyGiftPity;

  factory fromJson(Map<String, dynamic> json) => _$LuckyGiftPityFromJson(json);
}

/// The live a [LuckyTicker] happened in.
@freezed
abstract class LuckyTickerRoom with _$LuckyTickerRoom {
  const factory({
    required String id,
    required String title,
    required UserSummary host,
  }) = _LuckyTickerRoom;

  factory fromJson(Map<String, dynamic> json) =>
      _$LuckyTickerRoomFromJson(json);
}

/// The `lucky-ticker` data message (topic `lucky`, v1.30-live, D148,
/// «لحظة الحظ»): a big win in another live, sent to every live room at most
/// once every 10 s. Tapping it opens [room].
@freezed
abstract class LuckyTicker with _$LuckyTicker {
  const factory({required LuckyWin win, required LuckyTickerRoom room}) =
      _LuckyTicker;

  factory fromJson(Map<String, dynamic> json) => _$LuckyTickerFromJson(json);
}

/// The `lucky-win` data message (topic `lucky`, v1.27-live, D132): a send
/// whose best win reached the room's big-win multiplier.
@freezed
abstract class LuckyWin with _$LuckyWin {
  const factory({
    required String giftId,
    required String roomId,
    required String giftCode,
    required UserSummary sender,
    required int multiplier,
    required int coinsWon,
    required DateTime createdAt,
  }) = _LuckyWin;

  factory fromJson(Map<String, dynamic> json) => _$LuckyWinFromJson(json);
}
