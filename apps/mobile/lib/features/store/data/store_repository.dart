// «المتجر» (D270, owner; docs/contracts/openapi.yaml v1.84-social DRAFT, tag
// `store`; CONVENTIONS §10.98): the items on sale and a purchase — for
// oneself or a gift — with coins or cherries.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/item_badge.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// `StoreKind`: what an item is — the bag category it lands in — in the
/// app's tab order. A kind this app does not know is skipped (more come).
enum StoreKind {
  avatarFrame('AVATAR_FRAME'),
  profileCard('PROFILE_CARD'),
  chatBubble('CHAT_BUBBLE'),
  entryBanner('ENTRY_BANNER'),
  entryEffect('ENTRY_EFFECT');

  new(this.wire);

  /// The wire value (also the bag category).
  final String wire;

  static StoreKind? fromWire(Object? wire) =>
      values.where((k) => k.wire == wire).firstOrNull;
}

/// `StoreCurrency`.
enum StoreCurrency {
  coins('COINS'),
  cherries('CHERRIES');

  new(this.wire);

  final String wire;

  static StoreCurrency? fromWire(Object? wire) =>
      values.where((c) => c.wire == wire).firstOrNull;
}

int _int(Object? v) => v is num ? v.toInt() : 0;

/// `StorePrice`: [amount] for [days] in [currency].
@immutable
final class StorePrice {
  const new({required this.currency, required this.days, required this.amount});

  final StoreCurrency currency;
  final int days;
  final int amount;
}

/// `StoreItem`: an item on sale (names in the reader's language).
@immutable
final class StoreItem {
  const new({
    required this.id,
    required this.code,
    required this.kind,
    required this.name,
    required this.art,
    required this.prices,
    this.isNew = false,
    this.badges = const [],
    this.ownedUntil,
  });

  /// Null for a kind or a shape this app does not read.
  static StoreItem? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final kind = StoreKind.fromWire(json['kind']);
    final id = json['id'];
    final code = json['code'];
    final name = json['name'];
    if (kind == null || id is! String || code is! String || name is! String) {
      return null;
    }
    final prices = <StorePrice>[
      for (final p in (json['prices'] as List<dynamic>? ?? const []))
        if (p is Map<String, dynamic>)
          if (StoreCurrency.fromWire(p['currency']) case final currency?)
            StorePrice(
              currency: currency,
              days: _int(p['days']),
              amount: _int(p['amount']),
            ),
    ];
    final owned = json['ownedUntil'];
    return StoreItem(
      id: id,
      code: code,
      kind: kind,
      name: name,
      art: StoreArt.fromJson(json['art']) ?? const StoreArt(),
      prices: prices,
      isNew: json['isNew'] == true,
      badges: itemBadgesFromJson(json['badges']),
      ownedUntil: owned is String ? DateTime.tryParse(owned) : null,
    );
  }

  final String id;

  /// The bag code it has once bought.
  final String code;
  final StoreKind kind;
  final String name;
  final StoreArt art;

  /// Coins first, then cherries; shorter first (as the server lists them).
  final List<StorePrice> prices;

  /// Deprecated v1.79-live (D289): «جديد» runs (in [badges]).
  final bool isNew;

  /// v1.79-live (D289, §10.102): the running badges in display priority.
  final List<ItemBadge> badges;

  /// The badges to show: [badges], or «جديد» alone from an older API that
  /// sends only `isNew`.
  List<ItemBadge> get shownBadges => badges.isNotEmpty
      ? badges
      : (isNew ? const [ItemBadge(ItemBadgeCode.isNew)] : const []);

  /// The caller holds it until then (a purchase adds the days), else null.
  final DateTime? ownedUntil;

  /// The currencies priced, coins first.
  List<StoreCurrency> get currencies => [
    for (final c in StoreCurrency.values)
      if (prices.any((p) => p.currency == c)) c,
  ];

  /// The durations priced in [currency], shortest first.
  List<int> daysIn(StoreCurrency currency) => [
    for (final p in prices)
      if (p.currency == currency) p.days,
  ]..sort();

  /// The price of [days] in [currency], or null when not offered.
  int? priceOf(StoreCurrency currency, int days) => prices
      .where((p) => p.currency == currency && p.days == days)
      .firstOrNull
      ?.amount;

  /// The lowest price in [currency], or null when not priced in it.
  StorePrice? lowestIn(StoreCurrency currency) {
    final inC = prices.where((p) => p.currency == currency).toList()
      ..sort((a, b) => a.amount.compareTo(b.amount));
    return inC.firstOrNull;
  }

  /// The grid's prices (owner: «يعرض بسعرين»): the lowest in each currency
  /// priced — coins first, then cherries; one or two.
  List<StorePrice> get lowest => [
    for (final c in StoreCurrency.values) ?lowestIn(c),
  ];
}

/// `StoreBalances`: the caller's coins and the cherries they may spend.
/// Owner (D270): «هل يُصرف كرز المهام المقفل في المتجر؟ لا» — [cherries] is
/// the unlocked balance (what a withdrawal may take); [lockedCherries] the
/// task cherries not spendable yet.
@immutable
final class StoreBalances {
  const new({
    required this.coins,
    required this.cherries,
    this.lockedCherries = 0,
  });

  factory fromJson(Object? json) => json is Map<String, dynamic>
      ? StoreBalances(
          coins: _int(json['coins']),
          cherries: _int(json['cherries']),
          lockedCherries: _int(json['lockedCherries']),
        )
      : const StoreBalances(coins: 0, cherries: 0);

  final int coins;

  /// Spendable (unlocked) cherries.
  final int cherries;
  final int lockedCherries;

  int of(StoreCurrency currency) =>
      currency == StoreCurrency.coins ? coins : cherries;
}

/// `StoreItemList`.
@immutable
final class StoreItemList {
  const new({required this.items, required this.kinds, required this.balances});

  final List<StoreItem> items;

  /// The tabs: the kinds with items on sale, in order.
  final List<StoreKind> kinds;
  final StoreBalances balances;

  List<StoreItem> of(StoreKind kind) => [
    for (final i in items)
      if (i.kind == kind) i,
  ];
}

/// `StorePurchaseResult`.
@immutable
final class StorePurchase {
  const new({
    required this.id,
    required this.itemId,
    required this.code,
    required this.kind,
    required this.name,
    required this.currency,
    required this.days,
    required this.cost,
    required this.expiresAt,
    required this.extended,
    required this.balances,
    this.recipient,
  });

  final String id;
  final String itemId;
  final String code;
  final StoreKind kind;
  final String name;
  final StoreCurrency currency;
  final int days;

  /// What was paid (in [currency]).
  final int cost;

  /// The person it was given to; null for oneself.
  final UserSummary? recipient;
  final DateTime expiresAt;
  final bool extended;
  final StoreBalances balances;
}

/// The store's API. Throws an `AppFailure` (`STORE_UNAVAILABLE`,
/// `STORE_PRICE_CHANGED`, `INSUFFICIENT_COINS`, `INSUFFICIENT_CHERRIES`,
/// `TOPUP_ACCOUNT_FROZEN`, `NOT_FOUND` for an unknown recipient…).
abstract interface class StoreRepository {
  /// `GET /store/items`.
  Future<StoreItemList> items();

  /// `POST /me/store/purchases` (`Idempotency-Key`): [recipient] (a
  /// username) makes it a gift.
  Future<StorePurchase> buy({
    required String itemId,
    required StoreCurrency currency,
    required int days,
    required int amount,
    required String idempotencyKey,
    String? recipient,
  });
}

class StoreRepositoryImpl implements StoreRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<StoreItemList> items() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/store/items');
    final body = res.data!;
    return StoreItemList(
      items: [
        for (final i in (body['data'] as List<dynamic>? ?? const []))
          ?StoreItem.fromJson(i),
      ],
      kinds: [
        for (final k in (body['kinds'] as List<dynamic>? ?? const []))
          ?StoreKind.fromWire(k),
      ],
      balances: StoreBalances.fromJson(body['balances']),
    );
  });

  @override
  Future<StorePurchase> buy({
    required String itemId,
    required StoreCurrency currency,
    required int days,
    required int amount,
    required String idempotencyKey,
    String? recipient,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/store/purchases',
      data: {
        'itemId': itemId,
        'currency': currency.wire,
        'days': days,
        'price': amount,
        'recipient': ?recipient,
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    final body = res.data!;
    final item = body['item']! as Map<String, dynamic>;
    final to = body['recipient'];
    return StorePurchase(
      id: body['id']! as String,
      itemId: item['id']! as String,
      code: item['code']! as String,
      kind: StoreKind.fromWire(item['kind']) ?? StoreKind.avatarFrame,
      name: item['name']! as String,
      currency: StoreCurrency.fromWire(body['currency']) ?? currency,
      days: _int(body['days']),
      cost: _int(body['price']),
      recipient: to is Map<String, dynamic> ? UserSummary.fromJson(to) : null,
      expiresAt: DateTime.parse(body['expiresAt']! as String),
      extended: body['extended'] == true,
      balances: StoreBalances.fromJson(body['balances']),
    );
  });
}

final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => StoreRepositoryImpl(ref.watch(apiDioProvider)),
);
