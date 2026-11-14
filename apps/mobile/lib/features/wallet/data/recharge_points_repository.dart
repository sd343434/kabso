import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

// «نقاط الشحن» (openapi v1.126-social, D370, CONVENTIONS §10.163): every
// coin the person recharges (website, store, a recharge agent) is one point;
// the points never expire and buy VIP («استبدل بالنقاط»). The server keeps
// the balance and the history; the app only shows them.

/// `RechargePointsReason`. A value this build does not know (a newer
/// server) is [other].
enum RechargePointsReason {
  rechargeWeb('RECHARGE_WEB'),
  rechargeStore('RECHARGE_STORE'),
  rechargeAgent('RECHARGE_AGENT'),
  vipRedeem('VIP_REDEEM'),
  reversal('REVERSAL'),
  adminAdjust('ADMIN_ADJUST'),
  other('');

  new(this.wire);

  final String wire;

  static RechargePointsReason fromWire(Object? wire) =>
      values.where((r) => r.wire == wire && r != other).firstOrNull ?? other;
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// `RechargePointsEntry`: one change of the caller's points.
@immutable
final class RechargePointsEntry {
  const new({
    required this.id,
    required this.reason,
    required this.delta,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory fromJson(Map<String, dynamic> json) => RechargePointsEntry(
    id: json['id']! as String,
    reason: RechargePointsReason.fromWire(json['reason']),
    delta: _int(json['delta']),
    balanceAfter: _int(json['balanceAfter']),
    createdAt: DateTime.parse(json['createdAt']! as String),
  );

  final String id;
  final RechargePointsReason reason;

  /// Signed, never 0.
  final int delta;
  final int balanceAfter;
  final DateTime createdAt;
}

/// `RechargePoints`: the balance (may be below 0 after a reversal) and one
/// page of the history, newest first.
typedef RechargePointsPage = ({
  int balance,
  List<RechargePointsEntry> items,
  String? next,
});

/// The recharge points API. Every method throws an `AppFailure`.
abstract interface class RechargePointsRepository {
  /// `GET /me/recharge-points`.
  Future<RechargePointsPage> page({String? cursor, int? limit});
}

class RechargePointsRepositoryImpl implements RechargePointsRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<RechargePointsPage> page({String? cursor, int? limit}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/me/recharge-points',
          queryParameters: {'cursor': ?cursor, 'limit': ?limit},
        );
        final body = res.data!;
        final page = PageInfo.fromJson(body['page']! as Map<String, dynamic>);
        return (
          balance: _int(body['balance']),
          items: [
            for (final e in body['data']! as List<dynamic>)
              RechargePointsEntry.fromJson(e as Map<String, dynamic>),
          ],
          next: page.hasMore ? page.nextCursor : null,
        );
      });
}

final rechargePointsRepositoryProvider = Provider<RechargePointsRepository>(
  (ref) => RechargePointsRepositoryImpl(ref.watch(apiDioProvider)),
);
