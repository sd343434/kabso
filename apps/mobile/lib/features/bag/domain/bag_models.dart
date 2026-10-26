// Wire models of the bag API (docs/contracts/openapi.yaml v1.22-live DRAFT,
// tag `bag`, CP-019; CONVENTIONS §10.22).

import 'package:freezed_annotation/freezed_annotation.dart';

part 'bag_models.freezed.dart';
part 'bag_models.g.dart';

/// `BagCategory`: the categories this app knows. The server adds more
/// later; items of a category the app does not know are ignored (§10.22).
enum BagCategory {
  /// The decoration on the profile card's header.
  profileCard('PROFILE_CARD');

  new(this.wire);

  /// The exact string used on the wire.
  final String wire;

  /// The category named [wire], or null when the app does not know it.
  static BagCategory? fromWire(String? wire) =>
      values.where((c) => c.wire == wire).firstOrNull;
}

/// `ProfileCard`: the profile card a user wears, on `PublicProfile`.
@freezed
abstract class ProfileCard with _$ProfileCard {
  const factory({required String code, required String assetKey}) =
      _ProfileCard;

  factory fromJson(Map<String, dynamic> json) => _$ProfileCardFromJson(json);
}

/// `BagCatalogueItem`: one item of the catalogue. [name] follows the app
/// language; [category] is the wire value (see [BagCategory.fromWire]).
@freezed
abstract class BagCatalogueItem with _$BagCatalogueItem {
  const factory({
    required String code,
    required String category,
    required String name,
    required String assetKey,
    required int sortOrder,
    required bool free,
  }) = _BagCatalogueItem;

  factory fromJson(Map<String, dynamic> json) =>
      _$BagCatalogueItemFromJson(json);
}

/// `BagItem`: an item the caller owns. [source] is opaque (more values come
/// later); [equipped] is true for at most one item per category.
@freezed
abstract class BagItem with _$BagItem {
  const factory({
    required String code,
    required String category,
    required String name,
    required String assetKey,
    required DateTime acquiredAt,
    required String source,
    required bool equipped,
  }) = _BagItem;

  factory fromJson(Map<String, dynamic> json) => _$BagItemFromJson(json);
}

/// `BagEquippedItem`: the item worn in a category.
@freezed
abstract class BagEquippedItem with _$BagEquippedItem {
  const factory({
    required String code,
    required String name,
    required String assetKey,
  }) = _BagEquippedItem;

  factory fromJson(Map<String, dynamic> json) =>
      _$BagEquippedItemFromJson(json);
}

/// `BagEquipped` (`PUT /me/bag/equipped`): what the caller wears in
/// [category] now; [equipped] null = nothing.
@freezed
abstract class BagEquipped with _$BagEquipped {
  const factory({required String category, BagEquippedItem? equipped}) =
      _BagEquipped;

  factory fromJson(Map<String, dynamic> json) => _$BagEquippedFromJson(json);
}
