import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// `WalletLedgerReason` (openapi v1.43-social, D164, CONVENTIONS §10.40):
/// why a coin balance changed. A value this build does not know (a newer
/// server) is [other].
enum WalletLedgerReason {
  adminGrant('ADMIN_GRANT'),
  adminRevoke('ADMIN_REVOKE'),
  bulletMessage('BULLET_MESSAGE'),
  familyCreate('FAMILY_CREATE'),
  cpRequest('CP_REQUEST'),
  cpRefund('CP_REFUND'),
  cpGift('CP_GIFT'),
  liveGift('LIVE_GIFT'),
  luckyGift('LUCKY_GIFT'),
  luckyGiftWin('LUCKY_GIFT_WIN'),
  premiumUsernameRent('PREMIUM_USERNAME_RENT'),
  premiumUsernameRenew('PREMIUM_USERNAME_RENEW'),
  dmGift('DM_GIFT'),
  liveBoost('LIVE_BOOST'),
  liveBoostRefund('LIVE_BOOST_REFUND'),
  // D166: the Me hub's programs.
  taskReward('TASK_REWARD'),
  checkInReward('CHECK_IN_REWARD'),
  eventPrize('EVENT_PRIZE'),
  other('');

  new(this.wire);

  final String wire;

  static WalletLedgerReason fromWire(Object? wire) =>
      values.where((r) => r.wire == wire && r != other).firstOrNull ?? other;
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// `WalletLedgerEntry`: one change of the caller's balance.
@immutable
final class WalletLedgerEntry {
  const new({
    required this.id,
    required this.reason,
    required this.delta,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory fromJson(Map<String, dynamic> json) => WalletLedgerEntry(
    id: json['id']! as String,
    reason: WalletLedgerReason.fromWire(json['reason']),
    delta: _int(json['delta']),
    balanceAfter: _int(json['balanceAfter']),
    createdAt: DateTime.parse(json['createdAt']! as String),
  );

  final String id;
  final WalletLedgerReason reason;

  /// Coins added (> 0) or taken (< 0).
  final int delta;
  final int balanceAfter;
  final DateTime createdAt;
}

/// `MyEarnings`: the caller's gift earnings (display only — not coins and
/// not withdrawable yet, D149).
@immutable
final class MyEarnings {
  const new({
    required this.totalCoins,
    required this.last7DaysCoins,
    required this.last30DaysCoins,
    required this.sendCount,
  });

  factory fromJson(Map<String, dynamic> json) => MyEarnings(
    totalCoins: _int(json['totalCoins']),
    last7DaysCoins: _int(json['last7DaysCoins']),
    last30DaysCoins: _int(json['last30DaysCoins']),
    sendCount: _int(json['sendCount']),
  );

  final int totalCoins;
  final int last7DaysCoins;
  final int last30DaysCoins;
  final int sendCount;
}

/// `EarningContext`: where the gift was sent.
enum EarningContext { live, dm }

/// `Earning`: one gift send that gave the caller earnings.
@immutable
final class Earning {
  const new({
    required this.id,
    required this.createdAt,
    required this.context,
    required this.giftCode,
    required this.giftName,
    required this.quantity,
    required this.giftCoins,
    required this.shareBps,
    required this.coins,
    required this.sender,
  });

  factory fromJson(Map<String, dynamic> json) => Earning(
    id: json['id']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    context: json['context'] == 'DM' ? EarningContext.dm : EarningContext.live,
    giftCode: json['giftCode']! as String,
    giftName: json['giftName']! as String,
    quantity: _int(json['quantity']),
    giftCoins: _int(json['giftCoins']),
    shareBps: _int(json['shareBps']),
    coins: _int(json['coins']),
    sender: json['sender'] == null
        ? null
        : UserSummary.fromJson(json['sender']! as Map<String, dynamic>),
  );

  final String id;
  final DateTime createdAt;
  final EarningContext context;
  final String giftCode;
  final String giftName;
  final int quantity;

  /// The send's coin value to the caller.
  final int giftCoins;

  /// The caller's share stored with the send, in basis points.
  final int shareBps;

  /// The earnings: floor(giftCoins × shareBps / 10 000).
  final int coins;

  /// Null when the sender's account is not active or a block stands
  /// between them.
  final UserSummary? sender;
}

/// One page of a cursor list.
typedef WalletPage<T> = ({List<T> items, String? next});

/// The caller's coin history and gift earnings (openapi v1.43-social,
/// D164). Every method throws an `AppFailure`.
abstract interface class WalletRepository {
  /// `GET /wallet/me/ledger`.
  Future<WalletPage<WalletLedgerEntry>> ledger({String? cursor});

  /// `GET /wallet/me/earnings`.
  Future<MyEarnings> earnings();

  /// `GET /wallet/me/earnings/history`.
  Future<WalletPage<Earning>> earningHistory({String? cursor});
}

class WalletRepositoryImpl implements WalletRepository {
  new(this._dio);

  final Dio _dio;

  Future<WalletPage<T>> _page<T>(
    String path,
    String? cursor,
    T Function(Map<String, dynamic>) item,
  ) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {'cursor': ?cursor},
    );
    final body = res.data!;
    final page = PageInfo.fromJson(body['page']! as Map<String, dynamic>);
    return (
      items: [
        for (final e in body['data']! as List<dynamic>)
          item(e as Map<String, dynamic>),
      ],
      next: page.hasMore ? page.nextCursor : null,
    );
  });

  @override
  Future<WalletPage<WalletLedgerEntry>> ledger({String? cursor}) =>
      _page('/wallet/me/ledger', cursor, WalletLedgerEntry.fromJson);

  @override
  Future<MyEarnings> earnings() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/wallet/me/earnings');
    return MyEarnings.fromJson(res.data!);
  });

  @override
  Future<WalletPage<Earning>> earningHistory({String? cursor}) =>
      _page('/wallet/me/earnings/history', cursor, Earning.fromJson);
}

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepositoryImpl(ref.watch(apiDioProvider)),
);
