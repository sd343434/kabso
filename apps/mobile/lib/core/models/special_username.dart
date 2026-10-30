import 'package:flutter/foundation.dart';

/// v1.54-social (D185, `MeSpecialUsername`, CONVENTIONS §10.48.1): the
/// signed-in person's active special username «يوزر مميز». While it is
/// active everyone else sees only [username]; [baseUsername] (the person's
/// own username, still valid to sign in) is shown only to them — it comes
/// only in their own `Me`.
@immutable
class SpecialUsername {
  const new({
    required this.username,
    required this.baseUsername,
    required this.source,
    required this.grantedAt,
    required this.locked,
    this.expiresAt,
  });

  /// The wire object, or null (absent, null or malformed).
  static SpecialUsername? fromJson(Object? json) {
    if (json is! Map) return null;
    final username = json['username'];
    final base = json['baseUsername'];
    final granted = DateTime.tryParse('${json['grantedAt']}');
    if (username is! String || base is! String || granted == null) {
      return null;
    }
    final expires = json['expiresAt'];
    return SpecialUsername(
      username: username,
      baseUsername: base,
      source: SpecialUsernameSource.fromWire(json['source']),
      grantedAt: granted,
      expiresAt: expires is String ? DateTime.tryParse(expires) : null,
      locked: json['locked'] != false,
    );
  }

  final String username;
  final String baseUsername;
  final SpecialUsernameSource source;
  final DateTime grantedAt;

  /// When it ends (the base username is shown again); null = permanent.
  final DateTime? expiresAt;

  /// True: the username cannot be changed (`USERNAME_LOCKED`).
  final bool locked;

  Map<String, Object?> toJson() => {
    'username': username,
    'baseUsername': baseUsername,
    'source': source.wire,
    'grantedAt': grantedAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'locked': locked,
  };

  @override
  bool operator ==(Object other) =>
      other is SpecialUsername &&
      other.username == username &&
      other.baseUsername == baseUsername &&
      other.source == source &&
      other.grantedAt == grantedAt &&
      other.expiresAt == expiresAt &&
      other.locked == locked;

  @override
  int get hashCode =>
      Object.hash(username, baseUsername, source, grantedAt, expiresAt, locked);

  @override
  String toString() => 'SpecialUsername($username, $source)';
}

/// Where a special username comes from. Unknown wire values read as
/// [other], so a newer server never breaks an older app.
enum SpecialUsernameSource {
  rechargeAgent('RECHARGE_AGENT'),
  adminGift('ADMIN_GIFT'),
  purchase('PURCHASE'),
  other('');

  new(this.wire);

  /// The exact string used on the wire.
  final String wire;

  static SpecialUsernameSource fromWire(Object? wire) =>
      values.where((s) => s.wire == wire && s != other).firstOrNull ?? other;
}

/// `@JsonKey(fromJson:)` of `Me.specialUsername`.
SpecialUsername? specialUsernameFromJson(Object? json) =>
    SpecialUsername.fromJson(json);

/// `@JsonKey(toJson:)` of `Me.specialUsername`.
Map<String, Object?>? specialUsernameToJson(SpecialUsername? value) =>
    value?.toJson();
