import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

// «شراء VIP» (openapi v1.82-social, D252, CONVENTIONS §10.93): the tiers the
// owner manages in the admin panel (order, price, length, perks), the
// caller's membership and a purchase with coins. Every rule is the
// server's; the app only shows what it answers.

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

int? _intOrNull(Object? v) => (v as num?)?.toInt();

List<Map<String, dynamic>> _list(Object? v) => [
  for (final e in v! as List<dynamic>) e as Map<String, dynamic>,
];

/// `#RRGGBB` → a colour; [fallback] when malformed.
int vipColorValue(Object? hex, {int fallback = 0xFFF5C451}) {
  final s = hex is String ? hex : '';
  if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(s)) return fallback;
  return 0xFF000000 | int.parse(s.substring(1), radix: 16);
}

/// `VipPerk`: a perk in the reader's language. [available]: the app
/// really does it today (false: shown as «قريباً», never as active).
@immutable
final class VipPerk {
  const new({
    required this.code,
    required this.title,
    required this.available,
    this.description,
    this.animation,
    this.still,
    this.artWidth,
    this.artHeight,
    this.amount,
    this.video,
    this.value,
    this.category,
    this.fromTier,
    this.entryDisplay,
  });

  /// D270 (§10.98.4): a store item worn, as the perk of its kind (the store
  /// item replaces the VIP one: one worn item per kind).
  factory fromStoreArt(String code, StoreArt art) => VipPerk(
    code: code,
    title: code,
    available: true,
    animation: art.animation,
    still: art.still,
    artWidth: art.width,
    artHeight: art.height,
    video: art.video,
    entryDisplay: art.entryDisplay,
  );

  factory fromJson(Map<String, dynamic> json) => VipPerk(
    code: json['code']! as String,
    title: json['title']! as String,
    description: json['description'] as String?,
    available: json['available'] == true,
    animation: json['animation'] as String?,
    still: json['still'] as String?,
    artWidth: _intOrNull(json['artWidth']),
    artHeight: _intOrNull(json['artHeight']),
    amount: _intOrNull(json['amount']),
    value: json['value'],
    category: json['category'] as String?,
    fromTier: json['fromTier'] as String?,
    entryDisplay: EntryDisplay.fromWire(json['entryDisplay']),
  );

  final String code;
  final String title;
  final String? description;
  final bool available;

  /// The perk's own art (an SVGA animation and a still: a bundled asset path
  /// `assets/vip/...` or a hosted https URL), and its intrinsic size.
  final String? animation;
  final String? still;
  final int? artWidth;
  final int? artHeight;

  /// v1.83-social (D258): the perk's number for this tier (free public
  /// messages / coins a day, the level speed-up %), or null.
  final int? amount;

  /// D270: the [animation] is an MP4 (a store item's art), else an SVGA.
  final ArtVideo? video;

  /// v1.129-social (D374, §10.166): the perk's value for the tier, as its
  /// catalogue says (a number, a text, a list or an object), or null. For
  /// DAILY_BULLET and LEVEL_SPEEDUP it equals [amount].
  final Object? value;

  /// D374: the catalogue category (IDENTITY, ENTRANCE, CHAT, …), or null.
  final String? category;

  /// D374: in [VipTier.effectivePerks] only — the code of the lower tier this
  /// perk is inherited from; null for the tier's own perk.
  final String? fromTier;

  /// D374: the number this perk carries — [amount], else a whole-number
  /// [value] — or null.
  int? get number => amount ?? (value is num ? (value! as num).toInt() : null);

  /// v1.128-social (D373, §10.165): the ENTRY_EFFECT perk's (or worn store
  /// car's) display, set in the panel; null: full screen (today's look).
  final EntryDisplay? entryDisplay;
}

/// `VipTier`: a tier on sale, in the panel's order ([level] 1 … n).
@immutable
final class VipTier {
  const new({
    required this.id,
    required this.code,
    required this.name,
    required this.level,
    required this.color,
    required this.priceCoins,
    required this.durationDays,
    required this.perks,
    List<VipPerk>? effectivePerks,
    this.badgeAnimation,
    this.badgeStill,
    this.nameColor,
    this.renewalDiscountPercent = 0,
    int? renewPriceCoins,
    this.pricePoints,
    int? renewPricePoints,
  }) : renewPriceCoins = renewPriceCoins ?? priceCoins,
       renewPricePoints = renewPricePoints ?? pricePoints,
       effectivePerks = effectivePerks ?? perks;

  factory fromJson(Map<String, dynamic> json) => VipTier(
    renewalDiscountPercent: _int(json['renewalDiscountPercent']),
    pricePoints: _intOrNull(json['pricePoints']),
    renewPricePoints: _intOrNull(json['renewPricePoints']),
    renewPriceCoins: json['renewPriceCoins'] == null
        ? null
        : _int(json['renewPriceCoins']),
    nameColor: json['nameColor'] is String
        ? vipColorValue(json['nameColor'])
        : null,
    id: json['id']! as String,
    code: json['code']! as String,
    name: json['name']! as String,
    level: _int(json['level']),
    color: vipColorValue(json['color']),
    badgeAnimation: json['badgeAnimation'] as String?,
    badgeStill: json['badgeStill'] as String?,
    priceCoins: _int(json['priceCoins']),
    durationDays: _int(json['durationDays']),
    perks: [for (final p in _list(json['perks'])) VipPerk.fromJson(p)],
    effectivePerks: json['effectivePerks'] is List
        ? [for (final p in _list(json['effectivePerks'])) VipPerk.fromJson(p)]
        : null,
  );

  final String id;
  final String code;
  final String name;
  final int level;

  /// ARGB.
  final int color;

  /// D258 (§10.94.12): percent off a renewal of this tier (0 = none), and
  /// the renewal's price.
  final int renewalDiscountPercent;
  final int renewPriceCoins;

  /// v1.126-social (D370, §10.163): the price in recharge points for one
  /// period, and a renewal's (the same discount); null = not redeemable.
  final int? pricePoints;
  final int? renewPricePoints;

  /// D258 (§10.94.10): the special text colour of the tier's members (ARGB;
  /// the name, messages and entry line in a gradient of its hue), or null.
  final int? nameColor;

  /// The tier BADGE (central crest): an SVGA animation and a still (asset
  /// path or https URL); null = a token placeholder in [color].
  final String? badgeAnimation;
  final String? badgeStill;
  final int priceCoins;
  final int durationDays;

  /// The tier's own perks (as set in the panel).
  final List<VipPerk> perks;

  /// v1.129-social (D374, §10.166.5): what a holder of this tier has — its
  /// own perks and the lower tiers' (inherited, [VipPerk.fromTier]), in the
  /// catalogue's order; the VIP page lists these. [perks] when the server
  /// sends none (an older server).
  final List<VipPerk> effectivePerks;
}

/// `VipTierList`.
@immutable
final class VipTierList {
  const new({required this.tiers, required this.maxAheadDays});

  factory fromJson(Map<String, dynamic> json) => VipTierList(
    tiers: [for (final t in _list(json['data'])) VipTier.fromJson(t)],
    maxAheadDays: _int(json['maxAheadDays']),
  );

  final List<VipTier> tiers;

  /// A renewal may not take the end further than this many days from now.
  final int maxAheadDays;
}

/// `MyVip.renewal` (D258 §10.94.12): buying `tierId` again now costs
/// `priceCoins` (`discountPercent` off) until `until`.
typedef VipRenewal = ({
  String tierId,
  int priceCoins,
  int discountPercent,
  DateTime until,
  // v1.126-social (D370): the renewal's points price, or null.
  int? pricePoints,
});

/// `ProfileVisitor` (v1.83-social, D258 §10.94.9): one visitor of the
/// caller's profile.
@immutable
final class ProfileVisitor {
  const new({
    required this.user,
    required this.lastVisitedAt,
    required this.visits,
  });

  factory fromJson(Map<String, dynamic> json) => ProfileVisitor(
    user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
    lastVisitedAt: DateTime.parse(json['lastVisitedAt']! as String),
    visits: _int(json['visits']),
  );

  final UserSummary user;
  final DateTime lastVisitedAt;

  /// Openings at least 10 minutes apart.
  final int visits;
}

/// `ProfileVisitorList`: the newest 100 of the last 30 days, and how many.
typedef ProfileVisitorList = ({List<ProfileVisitor> data, int total});

/// `VipMembership`: the caller's active membership.
@immutable
final class VipMembership {
  const new({
    required this.tierId,
    required this.tierCode,
    required this.tierName,
    required this.tierColor,
    required this.onSale,
    required this.startedAt,
    required this.expiresAt,
    required this.daysLeft,
    this.badgeAnimation,
    this.badgeStill,
  });

  factory fromJson(Map<String, dynamic> json) {
    final tier = json['tier']! as Map<String, dynamic>;
    return VipMembership(
      tierId: tier['id']! as String,
      tierCode: tier['code']! as String,
      tierName: tier['name']! as String,
      tierColor: vipColorValue(tier['color']),
      onSale: tier['onSale'] == true,
      badgeAnimation: tier['badgeAnimation'] as String?,
      badgeStill: tier['badgeStill'] as String?,
      startedAt: DateTime.parse(json['startedAt']! as String),
      expiresAt: DateTime.parse(json['expiresAt']! as String),
      daysLeft: _int(json['daysLeft']),
    );
  }

  // D374 (§10.166.6): the owner removed the daily coins; `MyVip.dailyCoins`
  // is never sent any more and the app no longer reads it.

  final String tierId;
  final String tierCode;
  final String tierName;
  final int tierColor;
  final String? badgeAnimation;
  final String? badgeStill;

  /// False when the owner took the tier off sale (kept to its end).
  final bool onSale;
  final DateTime startedAt;
  final DateTime expiresAt;
  final int daysLeft;
}

/// `VipPurchaseResult.kind`.
enum VipPurchaseKind {
  bought('NEW'),
  renewed('RENEW'),
  upgraded('UPGRADE');

  new(this.wire);

  final String wire;

  static VipPurchaseKind fromWire(Object? wire) =>
      values.where((k) => k.wire == wire).firstOrNull ?? bought;
}

/// `VipPurchaseResult`.
typedef VipPurchase = ({
  VipPurchaseKind kind,
  VipMembership membership,
  int coins,
});

/// v1.126-social (D370, §10.163): a purchase paid with recharge points —
/// what it did, the membership and the points left.
typedef VipRedemption = ({
  VipPurchaseKind kind,
  VipMembership membership,
  int rechargePoints,
});

/// The VIP API. Every method throws an `AppFailure`.
abstract interface class VipRepository {
  /// `GET /vip/tiers`.
  Future<VipTierList> tiers();

  /// `GET /me/vip`: the active membership, or null.
  Future<VipMembership?> mine();

  /// `POST /me/vip/purchases`: buy, renew or upgrade [tierId] at
  /// [priceCoins], the price the person agreed to. [idempotencyKey] is one
  /// UUID per confirmed tap (a retry sends the same one).
  Future<VipPurchase> buy({
    required String tierId,
    required int priceCoins,
    required String idempotencyKey,
  });

  /// `POST /me/vip/purchases` with `payWith: POINTS` (D370 «استبدل
  /// بالنقاط»): the same NEW / RENEW / UPGRADE rules, paid with
  /// [pricePoints] recharge points — the points price the person agreed to.
  Future<VipRedemption> redeemWithPoints({
    required String tierId,
    required int pricePoints,
    required String idempotencyKey,
  });

  /// `GET /me/vip`'s `renewal` (D258): the renewal discount the caller has
  /// now, or null.
  Future<VipRenewal?> renewal();

  /// `GET /me/profile-visitors` (D258): «من زار ملفي».
  Future<ProfileVisitorList> profileVisitors();
}

class VipRepositoryImpl implements VipRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<VipTierList> tiers() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/vip/tiers');
    return VipTierList.fromJson(res.data!);
  });

  @override
  Future<VipMembership?> mine() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/vip');
    final m = res.data!['membership'];
    return m == null ? null : VipMembership.fromJson(m as Map<String, dynamic>);
  });

  @override
  Future<VipRenewal?> renewal() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/vip');
    final r = res.data!['renewal'];
    if (r is! Map<String, dynamic>) return null;
    return (
      tierId: r['tierId']! as String,
      priceCoins: _int(r['priceCoins']),
      discountPercent: _int(r['discountPercent']),
      until: DateTime.parse(r['until']! as String),
      pricePoints: _intOrNull(r['pricePoints']),
    );
  });

  @override
  Future<ProfileVisitorList> profileVisitors() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/profile-visitors');
    final body = res.data!;
    return (
      data: [for (final v in _list(body['data'])) ProfileVisitor.fromJson(v)],
      total: _int(body['total']),
    );
  });

  @override
  Future<VipPurchase> buy({
    required String tierId,
    required int priceCoins,
    required String idempotencyKey,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/vip/purchases',
      data: {'tierId': tierId, 'priceCoins': priceCoins},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    final body = res.data!;
    return (
      kind: VipPurchaseKind.fromWire(body['kind']),
      membership: VipMembership.fromJson(
        body['membership']! as Map<String, dynamic>,
      ),
      coins: _int(body['coins']),
    );
  });

  @override
  Future<VipRedemption> redeemWithPoints({
    required String tierId,
    required int pricePoints,
    required String idempotencyKey,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/vip/purchases',
      data: {'tierId': tierId, 'payWith': 'POINTS', 'pricePoints': pricePoints},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    final body = res.data!;
    return (
      kind: VipPurchaseKind.fromWire(body['kind']),
      membership: VipMembership.fromJson(
        body['membership']! as Map<String, dynamic>,
      ),
      rechargePoints: _int(body['rechargePoints']),
    );
  });
}

final vipRepositoryProvider = Provider<VipRepository>(
  (ref) => VipRepositoryImpl(ref.watch(apiDioProvider)),
);
