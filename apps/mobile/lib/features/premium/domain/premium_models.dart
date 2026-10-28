import 'package:flutter/foundation.dart' show immutable;
import 'package:kabso_live/core/models/premium_tier.dart';

/// What one name is for the caller (`PremiumUsernameStatus.status`, D146).
enum PremiumNameState {
  available('AVAILABLE'),
  notForSale('NOT_FOR_SALE'),
  taken('TAKEN'),
  held('HELD'),
  yours('YOURS'),
  yoursGrace('YOURS_GRACE'),
  reserved('RESERVED'),
  regular('REGULAR'),
  invalid('INVALID'),

  /// A value this build does not know (a newer server): shown as not
  /// available.
  unknown('');

  new(this.wire);

  final String wire;

  static PremiumNameState fromWire(Object? wire) =>
      values.where((s) => s.wire == wire && s != unknown).firstOrNull ??
      unknown;

  /// The caller can pay for this name now (rent, or renew their own).
  bool get purchasable =>
      this == available || this == yours || this == yoursGrace;
}

/// `PremiumUsernameStatus` (`GET /premium-usernames/{username}`).
@immutable
class PremiumNameStatus {
  const new({
    required this.username,
    required this.tier,
    required this.state,
    required this.priceCoins,
    required this.periodDays,
    this.heldUntil,
  });

  factory fromJson(Map<String, dynamic> json) => PremiumNameStatus(
    username: json['username']! as String,
    tier: PremiumTier.fromWire(json['tier']),
    state: PremiumNameState.fromWire(json['status']),
    priceCoins: (json['priceCoins'] as num?)?.toInt(),
    periodDays: (json['periodDays'] as num?)?.toInt() ?? 30,
    heldUntil: json['heldUntil'] == null
        ? null
        : DateTime.parse(json['heldUntil']! as String),
  );

  final String username;
  final PremiumTier? tier;
  final PremiumNameState state;

  /// The monthly price now; null when it is not for sale to the caller.
  final int? priceCoins;
  final int periodDays;
  final DateTime? heldUntil;

  @override
  bool operator ==(Object other) =>
      other is PremiumNameStatus &&
      other.username == username &&
      other.tier == tier &&
      other.state == state &&
      other.priceCoins == priceCoins &&
      other.periodDays == periodDays &&
      other.heldUntil == heldUntil;

  @override
  int get hashCode =>
      Object.hash(username, tier, state, priceCoins, periodDays, heldUntil);
}

/// One tier's monthly price in the store (null: not on sale).
typedef PremiumTierPrice = ({PremiumTier tier, int? priceCoins});

/// `PremiumUsernameStore` (`GET /premium-usernames`).
@immutable
class PremiumStore {
  const new({
    required this.periodDays,
    required this.graceDays,
    required this.tiers,
    required this.suggestions,
  });

  factory fromJson(Map<String, dynamic> json) => PremiumStore(
    periodDays: (json['periodDays'] as num?)?.toInt() ?? 30,
    graceDays: (json['graceDays'] as num?)?.toInt() ?? 7,
    tiers: [
      for (final t in json['tiers']! as List<dynamic>)
        if (PremiumTier.fromWire((t as Map<String, dynamic>)['tier'])
            case final tier?)
          (tier: tier, priceCoins: (t['priceCoins'] as num?)?.toInt()),
    ],
    suggestions: [
      for (final s in json['suggestions']! as List<dynamic>)
        PremiumNameStatus.fromJson(s as Map<String, dynamic>),
    ],
  );

  final int periodDays;
  final int graceDays;
  final List<PremiumTierPrice> tiers;
  final List<PremiumNameStatus> suggestions;

  /// No tier has a price: nothing can be rented yet.
  bool get nothingOnSale => tiers.every((t) => t.priceCoins == null);

  int? priceOf(PremiumTier tier) =>
      tiers.where((t) => t.tier == tier).firstOrNull?.priceCoins;
}

/// `MyPremiumUsername` (`GET /me/premium-username`).
@immutable
class MyPremiumUsername {
  const new({
    required this.username,
    required this.tier,
    required this.grace,
    required this.granted,
    required this.startedAt,
    required this.expiresAt,
    required this.graceUntil,
    required this.regularUsername,
    required this.renewPriceCoins,
    required this.canRenew,
    this.periodDays = 30,
  });

  factory fromJson(Map<String, dynamic> json) => MyPremiumUsername(
    username: json['username']! as String,
    tier: PremiumTier.fromWire(json['tier']) ?? PremiumTier.silver,
    grace: json['status'] == 'GRACE',
    granted: json['source'] == 'GRANT',
    startedAt: DateTime.parse(json['startedAt']! as String),
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.parse(json['expiresAt']! as String),
    graceUntil: json['graceUntil'] == null
        ? null
        : DateTime.parse(json['graceUntil']! as String),
    regularUsername: json['regularUsername']! as String,
    renewPriceCoins: (json['renewPriceCoins'] as num?)?.toInt(),
    canRenew: json['canRenew'] as bool? ?? false,
    periodDays: (json['periodDays'] as num?)?.toInt() ?? 30,
  );

  final String username;
  final PremiumTier tier;

  /// Expired: held for the caller until [graceUntil]; the caller is on
  /// [regularUsername] again.
  final bool grace;

  /// Given by the team (no charge).
  final bool granted;
  final DateTime startedAt;

  /// Null: a grant without an end.
  final DateTime? expiresAt;
  final DateTime? graceUntil;
  final String regularUsername;
  final int? renewPriceCoins;
  final bool canRenew;

  /// Days one renewal adds.
  final int periodDays;
}

/// `PremiumUsernameRental`: the answer of a rent or a renewal.
typedef PremiumRental = ({MyPremiumUsername premium, int coins});
