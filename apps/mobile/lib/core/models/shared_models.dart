// Wire models shared by several features (docs/contracts/openapi.yaml
// v1.3 `components.schemas`).

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/models/store_art.dart';
import 'package:kabso_live/core/models/verification_badge.dart';

export 'package:kabso_live/core/models/store_art.dart';

part 'shared_models.freezed.dart';
part 'shared_models.g.dart';

/// `PageInfo` (CONVENTIONS §5). Cursors are opaque: never parsed or built.
@freezed
abstract class PageInfo with _$PageInfo {
  const factory({required String? nextCursor, required bool hasMore}) =
      _PageInfo;

  factory fromJson(Map<String, dynamic> json) => _$PageInfoFromJson(json);
}

/// v1.54-social (D185): reads `RechargeAgentTag` (`{code}`) to its code;
/// anything else (absent, null, malformed) is no agent. v1.58-social
/// (D189): also `HostAgentTag` (the same shape).
String? rechargeAgentCodeFromJson(Object? json) => switch (json) {
  {'code': final String code} when code.isNotEmpty => code,
  _ => null,
};

/// The wire shape of [rechargeAgentCodeFromJson].
Map<String, dynamic>? rechargeAgentCodeToJson(String? code) =>
    code == null ? null : {'code': code};

/// `AvatarFrame` (v1.55-social, D186, CONVENTIONS §10.49): the avatar frame a
/// user wears (bag `AVATAR_FRAME`). The app draws the frames it has art for
/// (`AvatarFrameArt.of`) and ignores the others.
@immutable
final class AvatarFrame {
  const new({required this.code, required this.assetKey});

  final String code;
  final String assetKey;

  @override
  bool operator ==(Object other) =>
      other is AvatarFrame && other.code == code && other.assetKey == assetKey;

  @override
  int get hashCode => Object.hash(code, assetKey);

  @override
  String toString() => 'AvatarFrame($code, $assetKey)';
}

/// v1.55-social (D186): reads `AvatarFrame` (`{code, assetKey}`); anything
/// else (absent, null, malformed) is no frame.
AvatarFrame? avatarFrameFromJson(Object? json) => switch (json) {
  {'code': final String code, 'assetKey': final String assetKey}
      when code.isNotEmpty && assetKey.isNotEmpty =>
    AvatarFrame(code: code, assetKey: assetKey),
  _ => null,
};

/// The wire shape of [avatarFrameFromJson].
Map<String, dynamic>? avatarFrameToJson(AvatarFrame? frame) =>
    frame == null ? null : {'code': frame.code, 'assetKey': frame.assetKey};

/// v1.56-social (D187, §10.50): `RechargeBadge` — the daily recharge badge
/// «شارة الشحن اليومي», tier 1–5 until [until] (the moment the tier was
/// reached + 24 h). The server sends it only while it shows; the app hides
/// it itself once [until] passes ([isActiveAt]).
@immutable
class RechargeBadge {
  const new({required this.tier, required this.until});

  /// 1 … 5.
  final int tier;
  final DateTime until;

  /// Whether the badge still shows at [now].
  bool isActiveAt(DateTime now) => now.isBefore(until);

  @override
  bool operator ==(Object other) =>
      other is RechargeBadge && other.tier == tier && other.until == until;

  @override
  int get hashCode => Object.hash(tier, until);

  @override
  String toString() => 'RechargeBadge($tier, $until)';
}

/// Reads `RechargeBadge` (`{tier, until}`); anything else (absent, null,
/// malformed, a tier outside 1–5) is no badge.
RechargeBadge? rechargeBadgeFromJson(Object? json) => switch (json) {
  {'tier': final int tier, 'until': final String until}
      when tier >= 1 && tier <= 5 =>
    switch (DateTime.tryParse(until)) {
      final DateTime at => RechargeBadge(tier: tier, until: at.toUtc()),
      null => null,
    },
  _ => null,
};

/// The wire shape of [rechargeBadgeFromJson].
Map<String, dynamic>? rechargeBadgeToJson(RechargeBadge? badge) => badge == null
    ? null
    : {'tier': badge.tier, 'until': badge.until.toUtc().toIso8601String()};

/// v1.83-social (D258, §10.94): a person's active VIP — the tier's code, its
/// place in the panel's order and its colour (ARGB). The perks and their art
/// come from the VIP catalogue (`GET /vip/tiers`, by [tier]).
/// v1.65-live (D264, §10.97): [off] — the tier items the member took off in
/// the bag (perk codes); the look leaves them out.
@immutable
class UserVip {
  const new({
    required this.tier,
    required this.rank,
    required this.color,
    this.off = const {},
    this.store = const {},
  });

  /// D270 (§10.98.4): a person who wears store items and holds no VIP — the
  /// look carries the store items only (no badge, no name colour).
  const new storeOnly(this.store)
    : tier = '',
      rank = 0,
      color = 0xFF000000,
      off = const {};

  final String tier;
  final int rank;

  /// ARGB.
  final int color;

  /// D264: the perks taken off (empty: every tier item worn).
  final Set<String> off;

  /// D270 (§10.98.4): the store items worn (`UserSummary.wear`), by kind —
  /// AVATAR_FRAME, PROFILE_CARD, CHAT_BUBBLE, ENTRY_BANNER, ENTRY_EFFECT.
  /// Each replaces the VIP item of its kind in the look (the server lists
  /// that one in [off]: one worn item per kind).
  final Map<String, StoreArt> store;

  /// Whether this is a VIP membership (false: only store items worn).
  bool get member => tier.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is UserVip &&
      other.tier == tier &&
      other.rank == rank &&
      other.color == color &&
      other.off.length == off.length &&
      other.off.containsAll(off) &&
      mapEquals(other.store, store);

  @override
  int get hashCode => Object.hash(
    tier,
    rank,
    color,
    Object.hashAllUnordered(off),
    Object.hashAllUnordered(
      store.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() => store.isEmpty
      ? 'UserVip($tier, $rank)'
      : 'UserVip($tier, $rank, store: ${store.keys})';
}

/// D270: whether a VIP value is a membership (null or store items only: no).
extension UserVipMember on UserVip? {
  bool get isMember => this?.member ?? false;
}

/// D264: `UserVip.off` (absent: nothing taken off).
Set<String> _vipOff(Object? json) => switch (json) {
  {'off': final List<dynamic> list} => {...list.whereType<String>()},
  _ => const {},
};

/// Reads `UserVip` (`{tier, rank, color, off?}`); anything else is no VIP.
/// D270: a `wear` key (put there by [userVipWithWear]) adds the store items
/// worn — alone, a store-only look ([UserVip.storeOnly]).
UserVip? userVipFromJson(Object? json) {
  final store = json is Map
      ? storeWearFromJson(json['wear'])
      : const <String, StoreArt>{};
  return switch (json) {
    {
      'tier': final String tier,
      'rank': final int rank,
      'color': final String color,
    }
        when RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color) =>
      UserVip(
        tier: tier,
        rank: rank,
        color: 0xFF000000 | int.parse(color.substring(1), radix: 16),
        off: _vipOff(json),
        store: store,
      ),
    _ => store.isEmpty ? null : UserVip.storeOnly(store),
  };
}

/// D270 (§10.98.4): the `readValue` of a `vip` field — `UserSummary.vip` with
/// the sibling `UserSummary.wear` (the store items worn) put inside it, so
/// every renderer that draws a member's VIP items draws the store ones too.
Object? userVipWithWear(Map<dynamic, dynamic> json, String key) {
  final vip = json[key];
  final wear = json['wear'];
  if (wear == null) return vip;
  return {if (vip is Map) ...vip, 'wear': wear};
}

String _hex6(int argb) =>
    (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

/// The wire shape of [userVipFromJson].
Map<String, dynamic>? userVipToJson(UserVip? vip) => vip == null
    ? null
    : {
        if (vip.member) ...{
          'tier': vip.tier,
          'rank': vip.rank,
          'color': '#${_hex6(vip.color)}',
          if (vip.off.isNotEmpty) 'off': [...vip.off],
        },
        if (vip.store.isNotEmpty) 'wear': storeWearToJson(vip.store),
      };

/// `UserSummary`: minimal public identity of a user. Never has an email.
@freezed
abstract class UserSummary with _$UserSummary {
  const factory({
    required String id,
    required String username,
    required String displayName,
    required String? avatarUrl,

    /// v1.28-live (D146): the tier of the user's premium username (the
    /// badge), or null for a regular username. Only the server decides it.
    @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)
    PremiumTier? premiumTier,

    /// v1.54-social (D185, §10.48): the user's recharge-agent code while
    /// they are an ACTIVE agent (`UserSummary.rechargeAgent.code`): the
    /// small agent badge next to the name in live rooms. Null otherwise.
    @JsonKey(
      name: 'rechargeAgent',
      includeIfNull: false,
      fromJson: rechargeAgentCodeFromJson,
      toJson: rechargeAgentCodeToJson,
    )
    String? rechargeAgentCode,

    /// v1.58-social (D189, §10.52): the user's host-agent code «وكيل مضيفين»
    /// while their agency is not suspended (`UserSummary.hostAgent.code`,
    /// the same `{code}` shape): the host-agent badge next to the name and
    /// the entrance. Null otherwise.
    @JsonKey(
      name: 'hostAgent',
      includeIfNull: false,
      fromJson: rechargeAgentCodeFromJson,
      toJson: rechargeAgentCodeToJson,
    )
    String? hostAgentCode,

    /// v1.55-social (D186, §10.49): the avatar frame the user wears
    /// (`UserSummary.avatarFrame`, present only while one is worn): drawn
    /// around the picture on the live seats. Null otherwise.
    @JsonKey(
      includeIfNull: false,
      fromJson: avatarFrameFromJson,
      toJson: avatarFrameToJson,
    )
    AvatarFrame? avatarFrame,

    /// v1.56-social (D187, §10.50): the daily recharge badge while it shows
    /// (never for a recharge agent): next to the name in live rooms like the
    /// level badge. Null otherwise (also on older servers).
    @JsonKey(
      includeIfNull: false,
      fromJson: rechargeBadgeFromJson,
      toJson: rechargeBadgeToJson,
    )
    RechargeBadge? rechargeBadge,

    /// v1.83-social (D258, §10.94): the active VIP (badge, frame, name colour,
    /// bubble, card…, by the catalogue). Null otherwise (also older servers).
    /// D270 (§10.98.4): with the store items worn (`UserSummary.wear`) — a
    /// store-only look when the person holds no VIP ([UserVip.member]).
    @JsonKey(
      includeIfNull: false,
      readValue: userVipWithWear,
      fromJson: userVipFromJson,
      toJson: userVipToJson,
    )
    UserVip? vip,

    /// v1.73-live (D283c, §10.96.12): the official staff ID «Kabso01» while
    /// the user holds a panel role (the OWNER too): shown where the
    /// @username is (live viewers and chat, search, lists). Null otherwise.
    @JsonKey(includeIfNull: false) String? staffId,

    /// v1.90-social (D293, §10.105.5; owner «نعم»): the automatic
    /// verification badge «شارة التوثيق» — the seal right after the name
    /// wherever the name is shown. Null when none, for unknown values and
    /// from older servers.
    @JsonKey(
      includeIfNull: false,
      fromJson: verificationBadgeFromJson,
      toJson: verificationBadgeToJson,
    )
    VerificationBadge? verification,

    /// v1.130-social (D376, §10.167): «الحالة» — the status emoji worn over
    /// the picture (`<pack>.<emoji>`); the app shows nothing for an id it
    /// does not know. Null when none and from older servers.
    @JsonKey(includeIfNull: false) String? statusEmojiId,
  }) = _UserSummary;

  factory fromJson(Map<String, dynamic> json) => _$UserSummaryFromJson(json);
}
