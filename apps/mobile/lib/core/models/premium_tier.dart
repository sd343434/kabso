/// D146 (`PremiumUsernameTier`, CONVENTIONS §10.32): the tier of a premium
/// username, which picks its badge (the owner's four medals). Unknown wire
/// values read as null (no badge), so a newer server never breaks an older
/// app.
enum PremiumTier {
  legend('LEGEND'),
  ruby('RUBY'),
  gold('GOLD'),
  silver('SILVER');

  new(this.wire);

  /// The exact string used on the wire.
  final String wire;

  /// The tier named [wire], or null (absent, null or unknown).
  static PremiumTier? fromWire(Object? wire) =>
      values.where((t) => t.wire == wire).firstOrNull;
}

/// `@JsonKey(fromJson:)` of the optional `premiumTier` fields.
PremiumTier? premiumTierFromJson(Object? json) => PremiumTier.fromWire(json);

/// `@JsonKey(toJson:)` of the optional `premiumTier` fields.
String? premiumTierToJson(PremiumTier? tier) => tier?.wire;
