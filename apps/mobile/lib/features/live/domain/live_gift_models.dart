// Wire models of live gifts (docs/contracts/openapi.yaml v1.23-live DRAFT,
// tag `gifts` and `sendLiveGift`, CP-020; `Gift.tag` v1.24.3-live, D117;
// hosted art v1.26.2-live, D126; CONVENTIONS §10.23).

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/item_badge.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';

part 'live_gift_models.freezed.dart';
part 'live_gift_models.g.dart';

/// v1.43-live (D195): `Gift.pkBooster` on the wire (an unknown value: none).
PkBoosterKind? pkBoosterFromJson(Object? wire) => PkBoosterKind.fromWire(wire);

String? pkBoosterToJson(PkBoosterKind? kind) => kind?.wire;

/// The person a gift panel opens with (their card's Gifts button).
typedef LiveGiftPreselect = ({String username, String name});

/// `GiftCategory`: a gift panel tab's code. v1.46-live (D207, §10.66): the
/// categories are managed in the admin panel, so a code is any
/// `^[A-Z][A-Z0-9_]{0,39}$` (the tab's name comes with it in
/// [GiftCatalogue.tabs]); the five below are the ones seeded from the old
/// fixed list. The special ones keep their codes: [lucky] (§10.27) and
/// [quips] (§10.33). Gifts of a malformed code are dropped by the
/// repository.
abstract final class GiftCategory {
  static const popular = 'POPULAR';
  static const event = 'EVENT';
  static const fun = 'FUN';

  /// v1.27-live (D132, §10.27): lucky gifts (listed only while they are on).
  static const lucky = 'LUCKY';

  /// v1.32-live (D154, §10.33): «إفيهات» quips — a sound (and its line)
  /// played to the whole room, one at a time.
  static const quips = 'QUIPS';

  /// v1.100-social (D312, §10.118): «مُخصَّص» — gifts that name their owner
  /// ([Gift.owner]); sent with coins only.
  static const custom = 'CUSTOM';

  /// The seeded tabs, in their order (an older API's, and a guest's).
  static const values = <String>[popular, event, fun, lucky, quips];

  static final _code = RegExp(r'^[A-Z][A-Z0-9_]{0,39}$');

  /// [wire] when it is a category code, else null.
  static String? fromWire(Object? wire) =>
      wire is String && _code.hasMatch(wire) ? wire : null;
}

/// `GiftCategoryKind` (v1.46-live, D207): what a tab does besides listing
/// gifts; an unknown value is [normal].
enum GiftCategoryKind {
  @JsonValue('NORMAL')
  normal,
  @JsonValue('LUCKY')
  lucky,
  @JsonValue('QUIPS')
  quips,

  /// v1.100-social (D312): «مُخصَّص» (custom gifts with an owner).
  @JsonValue('CUSTOM')
  custom,
}

/// `GiftCategoryTab` (v1.46-live, D207): a gift panel tab — its code, kind,
/// name in the app language and optional icon.
@freezed
abstract class GiftTab with _$GiftTab {
  const factory({
    required String code,
    @JsonKey(unknownEnumValue: GiftCategoryKind.normal)
    @Default(GiftCategoryKind.normal)
    GiftCategoryKind kind,

    /// Null only for a tab built from an older API's `categories`.
    String? name,
    String? iconUrl,
  }) = _GiftTab;

  factory fromJson(Map<String, dynamic> json) => _$GiftTabFromJson(json);
}

/// `GiftAnimationFormat` (v1.46-live, D207): a hosted effect's format; a
/// value the app does not know is [unknown] (never played: the image only).
enum GiftAnimationFormat {
  @JsonValue('SVGA')
  svga,
  @JsonValue('MP4')
  mp4,
  unknown,
}

/// `GiftVideoAlpha` (v1.46-live, D207): an MP4's transparency — a plain
/// video played as is, or the left half colour and the right half alpha.
enum GiftVideoAlpha {
  @JsonValue('NONE')
  none,
  @JsonValue('SIDE_BY_SIDE')
  sideBySide,
}

/// `GiftBadge`: the corner badge of a gift; unknown values show as [none].
/// Deprecated v1.79-live (D289): [Gift.badges] carries the set; this single
/// value stays for a lucky gift's tile, which keeps its earlier mark.
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

/// `GiftOwner` (v1.100-social, D312, §10.118): who a custom «مُخصَّص» gift
/// belongs to — the gift panel shows the name and the avatar on the gift.
@freezed
abstract class GiftOwner with _$GiftOwner {
  const factory({
    required String id,
    required String username,
    required String displayName,
    String? avatarUrl,
  }) = _GiftOwner;

  factory fromJson(Map<String, dynamic> json) => _$GiftOwnerFromJson(json);
}

/// `Gift`: one gift of the catalogue. [name] follows the app language;
/// [assetKey] / [animationKey] name the app's bundled files, [imageUrl] /
/// [animationUrl] the art hosted on the server (D126), which wins.
@freezed
abstract class Gift with _$Gift {
  const factory({
    required String code,
    required String category,
    required String name,
    required int priceCoins,
    required String assetKey,
    required String? animationKey,
    required int sortOrder,
    @JsonKey(unknownEnumValue: GiftBadge.none) required GiftBadge badge,

    /// v1.79-live (D289, §10.102): the running badges in display priority
    /// (none from an older API). A tile shows two, the details all.
    @JsonKey(fromJson: itemBadgesFromJson, toJson: itemBadgesToJson)
    @Default(<ItemBadge>[])
    List<ItemBadge> badges,

    /// The sub-category (v1.24.3-live), or null: none, or an older API.
    GiftTag? tag,

    /// The hosted static image (v1.26.2-live), or null: the bundled one.
    String? imageUrl,

    /// The hosted SVGA effect (v1.26.2-live), or null: the bundled one.
    String? animationUrl,

    /// [animationUrl]'s size in bytes (whether to prefetch it), or null.
    int? animationBytes,

    /// v1.46-live (D207): [animationUrl]'s format (null: an older API, an
    /// SVGA), an MP4's transparency, and the hosted MP3 played with the
    /// effect (or alone).
    @JsonKey(unknownEnumValue: GiftAnimationFormat.unknown)
    GiftAnimationFormat? animationFormat,
    @JsonKey(unknownEnumValue: GiftVideoAlpha.none)
    GiftVideoAlpha? animationAlpha,
    String? audioUrl,
    int? audioBytes,
    int? audioDurationMs,

    /// v1.32-live (D154): a quip's sound and words; null for other gifts.
    GiftQuip? quip,

    /// v1.43-live (D195): the PK booster this gift activates (listed only
    /// in the «PK» tab during a PK battle), or null: an ordinary gift.
    @JsonKey(fromJson: pkBoosterFromJson, toJson: pkBoosterToJson)
    PkBoosterKind? pkBooster,

    /// v1.100-social (D312): a custom gift's owner «صاحب الهدية»; null for
    /// every other gift (and from an older API).
    GiftOwner? owner,
  }) = _Gift;

  factory fromJson(Map<String, dynamic> json) => _$GiftFromJson(json);
}

/// D289: the badges to show — [Gift.badges], or (an older API without the
/// field) the single `badge`: NEW as «جديد», EVENT as «موسمي». The new API
/// derives `badge` from the set, so both agree.
extension GiftBadges on Gift {
  List<ItemBadge> get shownBadges => badges.isNotEmpty
      ? badges
      : switch (badge) {
          GiftBadge.isNew => const [ItemBadge(ItemBadgeCode.isNew)],
          GiftBadge.event => const [ItemBadge(ItemBadgeCode.seasonal)],
          GiftBadge.none => const <ItemBadge>[],
        };
}

/// `GiftCatalogue` (`GET /gifts/catalogue`): the enabled gifts by tab.
/// [version] changes whenever anything but the names' language changes.
@freezed
abstract class GiftCatalogue with _$GiftCatalogue {
  const factory({
    required String version,
    required List<String> categories,
    required List<int> quantities,
    required int maxRecipients,
    required int comboWindowSeconds,
    required List<Gift> data,

    /// v1.89-live (D318, owner «لا يظهر في التكست إلا المكسب x250 وx500
    /// وx1000»): a lucky win has its chat line only from this multiplier;
    /// null from an older server (every win has its line).
    int? luckyChatMinMultiplier,

    /// v1.46-live (D207): the tabs with their names and icons, in order
    /// (empty from an older API: [categories] with the app's names).
    @Default(<GiftTab>[]) List<GiftTab> tabs,
  }) = _GiftCatalogue;

  factory fromJson(Map<String, dynamic> json) => _$GiftCatalogueFromJson(json);
}

extension GiftCatalogueLookup on GiftCatalogue {
  /// The gift with [code], or null (unknown or disabled).
  Gift? byCode(String code) => data.where((g) => g.code == code).firstOrNull;

  /// The distinct tags of [category]'s gifts, in the order they first
  /// appear (the panel's chips after "All"; empty: no chip row).
  List<GiftTag> tagsOf(String category) => giftTags(of(category));

  /// v1.46-live (D207): the tab of [code], or null (an older API's).
  GiftTab? tabOf(String code) => tabs.where((t) => t.code == code).firstOrNull;

  /// The catalogue's gifts of [category], in order.
  List<Gift> of(String category) => [
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

    /// v1.46-live (D207): as in [Gift].
    @JsonKey(unknownEnumValue: GiftAnimationFormat.unknown)
    GiftAnimationFormat? animationFormat,
    @JsonKey(unknownEnumValue: GiftVideoAlpha.none)
    GiftVideoAlpha? animationAlpha,
    String? audioUrl,
    int? audioBytes,
    int? audioDurationMs,

    /// v1.133-social (D380, §10.170.5): an ANONYMOUS_GIFT send — [sender] is
    /// «مجهول» for everyone but the sender; its recipients may report it or
    /// refuse the sender's anonymous gifts by its [id].
    @JsonKey(includeIfNull: false, toJson: trueOrNull)
    @Default(false)
    bool anonymous,
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

/// v1.111-live (D347, CONVENTIONS §10.146): the gift of a global lucky
/// banner (`lucky-ticker.gift`) — its code and art, so the banner shows the
/// gift even to a viewer whose catalogue has no lucky gifts (the name comes
/// from the catalogue, else «هدية»). Absent from older servers.
@immutable
class LuckyTickerGift {
  const new({required this.code, required this.assetKey, this.imageUrl});

  /// Null when [json] is not the contract's shape (an older server).
  static LuckyTickerGift? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final code = json['code'];
    final assetKey = json['assetKey'];
    final imageUrl = json['imageUrl'];
    if (code is! String || assetKey is! String) return null;
    return LuckyTickerGift(
      code: code,
      assetKey: assetKey,
      imageUrl: imageUrl is String ? imageUrl : null,
    );
  }

  final String code;
  final String assetKey;
  final String? imageUrl;
}

/// The `gift-ticker` data message (topic `gift`, v1.41-live, D178): a send
/// of at least the server's `GIFT_GLOBAL_TICKER_MIN_COINS` (v1.85-live,
/// D305: 500 000 by default) in any live — its own too since v1.85-live —
/// shown as the gifts strip «شريط الهدايا»; a tap opens [room]. Its `kind`
/// is `GIFT` (v1.85-live; not read: the type says it).
@immutable
class GiftTicker {
  const new({required this.gift, required this.room, this.holdSeconds = 0});

  /// Throws a `TypeError` when the message does not match the contract.
  factory fromJson(Map<String, dynamic> json) => GiftTicker(
    gift: LiveGift.fromJson(json['gift']! as Map<String, dynamic>),
    room: LuckyTickerRoom.fromJson(json['room']! as Map<String, dynamic>),
    holdSeconds: ((json['holdSeconds'] as num?)?.toInt() ?? 0).clamp(0, 60),
  );

  final LiveGift gift;
  final LuckyTickerRoom room;

  /// v1.132-social (D379, §10.169.6): TICKER_HOLD «إيقاف الشريط العام
  /// مؤقتاً» — the sender's VIP keeps this strip this many seconds longer in
  /// the middle (0: none; older servers send nothing).
  final int holdSeconds;
}

/// The game of a [GameWinTicker] (v1.85-live, D305).
@immutable
class StripGame {
  const new({required this.code, required this.name, this.imageUrl});

  factory fromJson(Map<String, dynamic> json) => StripGame(
    code: json['code']! as String,
    name: json['name']! as String,
    imageUrl: json['imageUrl'] as String?,
  );

  final String code;
  final String name;

  /// The game's thumbnail; null: none (the strip's trophy art stands alone).
  final String? imageUrl;
}

/// The `game-win-ticker` data message (topic `gift`, v1.85-live, D305,
/// `kind` GAME_WIN): a game prize of at least the server's
/// `GAME_WIN_TICKER_MIN_TICKETS` (default 1 000 000 tickets), shown as the
/// games strip «شريط الألعاب» in every live. [room] is the live the game was
/// played in (null: none, or it ended).
@immutable
class GameWinTicker {
  const new({
    required this.id,
    required this.game,
    required this.winner,
    required this.tickets,
    required this.createdAt,
    this.room,
  });

  /// Throws a `TypeError` when the message does not match the contract.
  factory fromJson(Map<String, dynamic> json) {
    final win = json['win']! as Map<String, dynamic>;
    final room = json['room'];
    return GameWinTicker(
      id: win['id']! as String,
      game: StripGame.fromJson(win['game']! as Map<String, dynamic>),
      winner: UserSummary.fromJson(win['winner']! as Map<String, dynamic>),
      tickets: (win['tickets']! as num).toInt(),
      createdAt: DateTime.parse(win['createdAt']! as String),
      room: room == null
          ? null
          : LuckyTickerRoom.fromJson(room as Map<String, dynamic>),
    );
  }

  final String id;
  final StripGame game;
  final UserSummary winner;

  /// The prize in tickets «تذاكر» (game cards, D182).
  final int tickets;
  final DateTime createdAt;
  final LuckyTickerRoom? room;
}
