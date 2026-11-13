/// v1.90-social (D293, `VerificationBadge`, CONVENTIONS §10.105): the
/// automatic verification badge «شارة التوثيق» beside a person's name, in the
/// owner's priority order (one per person; the server picks the highest).
/// Unknown wire values read as null (no badge), so a newer server never
/// breaks an older app.
enum VerificationBadge {
  owner('OWNER'),
  staff('STAFF'),
  rechargeAgent('RECHARGE_AGENT'),
  hostAgent('HOST_AGENT'),
  creator('CREATOR'),
  verifiedHost('VERIFIED_HOST');

  new(this.wire);

  /// The exact string used on the wire.
  final String wire;

  /// The badge named [wire], or null (absent, null or unknown).
  static VerificationBadge? fromWire(Object? wire) =>
      values.where((b) => b.wire == wire).firstOrNull;
}

/// `@JsonKey(fromJson:)` of the `verification` fields.
VerificationBadge? verificationBadgeFromJson(Object? json) =>
    VerificationBadge.fromWire(json);

/// `@JsonKey(toJson:)` of the `verification` fields.
String? verificationBadgeToJson(VerificationBadge? badge) => badge?.wire;
