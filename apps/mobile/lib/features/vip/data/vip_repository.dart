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
  });

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
    this.badgeAnimation,
    this.badgeStill,
    this.nameColor,
    this.renewalDiscountPercent = 0,
    int? renewPriceCoins,
  }) : renewPriceCoins = renewPriceCoins ?? priceCoins;

  factory fromJson(Map<String, dynamic> json) => VipTier(
    renewalDiscountPercent: _int(json['renewalDiscountPercent']),
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

  /// D258 (§10.94.10): the special text colour of the tier's members (ARGB;
  /// the name, messages and entry line in a gradient of its hue), or null.
  final int? nameColor;

  /// The tier BADGE (central crest): an SVGA animation and a still (asset
  /// path or https URL); null = a token placeholder in [color].
  final String? badgeAnimation;
  final String? badgeStill;
  final int priceCoins;
  final int durationDays;
  final List<VipPerk> perks;
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

/// `VipDailyCoins` (v1.83-social, D258 §10.94.5): a member's daily coins.
@immutable
final class VipDailyCoins {
  const new({
    required this.amount,
    required this.claimedToday,
    required this.nextAt,
  });

  factory fromJson(Map<String, dynamic> json) => VipDailyCoins(
    amount: _int(json['amount']),
    claimedToday: json['claimedToday'] == true,
    nextAt: DateTime.parse(json['nextAt']! as String),
  );

  /// Coins a day.
  final int amount;
  final bool claimedToday;

  /// When the next claim opens (the next day's start).
  final DateTime nextAt;
}

/// `MyVip.renewal` (D258 §10.94.12): buying `tierId` again now costs
/// `priceCoins` (`discountPercent` off) until `until`.
typedef VipRenewal = ({
  String tierId,
  int priceCoins,
  int discountPercent,
  DateTime until,
});

/// `VipDailyCoinsClaim`: what a claim credited (0 when already claimed
/// today), the balance after it and the new state.
typedef VipDailyCoinsClaim = ({int coins, int balance, VipDailyCoins daily});

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
    this.dailyCoins,
  });

  factory fromJson(Map<String, dynamic> json, {VipDailyCoins? dailyCoins}) {
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
      dailyCoins: dailyCoins,
    );
  }

  /// D258: `MyVip.dailyCoins` (members holding DAILY_COINS), else null.
  final VipDailyCoins? dailyCoins;

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

  /// `GET /me/vip`'s `renewal` (D258): the renewal discount the caller has
  /// now, or null.
  Future<VipRenewal?> renewal();

  /// `POST /me/vip/daily-coins` (D258): today's daily coins (once a day).
  Future<VipDailyCoinsClaim> claimDailyCoins();

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
    final daily = res.data!['dailyCoins'];
    return m == null
        ? null
        : VipMembership.fromJson(
            m as Map<String, dynamic>,
            dailyCoins: daily is Map<String, dynamic>
                ? VipDailyCoins.fromJson(daily)
                : null,
          );
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
  Future<VipDailyCoinsClaim> claimDailyCoins() => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>('/me/vip/daily-coins');
    final body = res.data!;
    return (
      coins: _int(body['coins']),
      balance: _int(body['balance']),
      daily: VipDailyCoins.fromJson(
        body['dailyCoins']! as Map<String, dynamic>,
      ),
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
}

final vipRepositoryProvider = Provider<VipRepository>(
  (ref) => VipRepositoryImpl(ref.watch(apiDioProvider)),
);
