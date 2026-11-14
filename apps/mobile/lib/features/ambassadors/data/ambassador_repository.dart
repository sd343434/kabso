import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// v1.141-social (D390, CONVENTIONS §10.179): «برنامج سفراء Kabso» — the
/// programme page and the application, and the ambassador's dashboard.
/// Throws an `AppFailure`.
abstract interface class AmbassadorRepository {
  /// `GET /ambassadors/programme`.
  Future<AmbassadorProgramme> programme();

  /// `POST /ambassadors/applications`.
  Future<AmbassadorProgramme> apply(AmbassadorApplicationDraft draft);

  /// `GET /ambassadors/me` (404 for anyone who is not an ambassador).
  Future<AmbassadorDashboard> dashboard();
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
List<Map<String, dynamic>> _list(Object? v) =>
    (v as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

/// `AmbassadorReward`: NONE, COINS (`amount`), VIP_DAYS (`amount` days of
/// `vipTier`) or BAG_ITEM (`itemCode` for `amount` days).
final class AmbassadorReward {
  const new({required this.kind, this.amount = 0, this.vipTier, this.itemCode});

  factory fromJson(Map<String, dynamic> j) => AmbassadorReward(
    kind: j['kind'] as String? ?? 'NONE',
    amount: _int(j['amount']),
    vipTier: j['vipTier'] as String?,
    itemCode: j['itemCode'] as String?,
  );

  final String kind;
  final int amount;
  final String? vipTier;
  final String? itemCode;
}

/// `AmbassadorLevel`: the month's requirements, the commission, the reward.
final class AmbassadorLevel {
  const new({
    required this.code,
    required this.minActiveReferrals,
    required this.minTopupCoins,
    required this.commissionBps,
    required this.reward,
  });

  factory fromJson(Map<String, dynamic> j) => AmbassadorLevel(
    code: j['code'] as String? ?? '',
    minActiveReferrals: _int(j['minActiveReferrals']),
    minTopupCoins: _int(j['minTopupCoins']),
    commissionBps: _int(j['commissionBps']),
    reward: AmbassadorReward.fromJson(
      j['reward'] as Map<String, dynamic>? ?? const {},
    ),
  );

  final String code;
  final int minActiveReferrals;
  final int minTopupCoins;
  final int commissionBps;
  final AmbassadorReward reward;
}

/// `AmbassadorApplication` (the caller's latest).
final class AmbassadorApplication {
  const new({
    required this.id,
    required this.status,
    required this.rejectReason,
  });

  factory fromJson(Map<String, dynamic> j) => AmbassadorApplication(
    id: j['id'] as String? ?? '',
    status: j['status'] as String? ?? 'PENDING',
    rejectReason: j['rejectReason'] as String?,
  );

  final String id;
  final String status;
  final String? rejectReason;
}

/// `AmbassadorProgramme`.
final class AmbassadorProgramme {
  const new({
    required this.enabled,
    required this.status,
    required this.canApply,
    required this.refusal,
    required this.application,
    required this.levels,
    required this.attributionWindowDays,
    required this.holdDays,
    required this.minActiveDays,
    required this.minActiveTopupCoins,
  });

  factory fromJson(Map<String, dynamic> j) {
    final rules = j['rules'] as Map<String, dynamic>? ?? const {};
    final app = j['application'] as Map<String, dynamic>?;
    return AmbassadorProgramme(
      enabled: j['enabled'] as bool? ?? false,
      status: j['status'] as String? ?? 'NONE',
      canApply: j['canApply'] as bool? ?? false,
      refusal: j['refusal'] as String?,
      application: app == null ? null : AmbassadorApplication.fromJson(app),
      levels: _list(j['levels']).map(AmbassadorLevel.fromJson).toList(),
      attributionWindowDays: _int(rules['attributionWindowDays']),
      holdDays: _int(rules['holdDays']),
      minActiveDays: _int(rules['minActiveDays']),
      minActiveTopupCoins: _int(rules['minActiveTopupCoins']),
    );
  }

  final bool enabled;

  /// NONE, PENDING, REJECTED or AMBASSADOR.
  final String status;
  final bool canApply;

  /// DISABLED, ACCOUNT_NOT_ACTIVE, STAFF, AMBASSADOR, PENDING or null.
  final String? refusal;
  final AmbassadorApplication? application;
  final List<AmbassadorLevel> levels;
  final int attributionWindowDays;
  final int holdDays;
  final int minActiveDays;
  final int minActiveTopupCoins;

  bool get isAmbassador => status == 'AMBASSADOR';
}

/// The form's fields.
final class AmbassadorApplicationDraft {
  const new({
    required this.country,
    required this.links,
    required this.audienceSize,
    required this.motivation,
  });

  final String country;
  final List<String> links;
  final int audienceSize;
  final String motivation;
}

/// One month of `AmbassadorDashboard.history`.
final class AmbassadorMonth {
  const new({
    required this.month,
    required this.activeReferrals,
    required this.topupCoins,
    required this.commissionCherries,
    required this.levelAfter,
    required this.rewardStatus,
  });

  factory fromJson(Map<String, dynamic> j) => AmbassadorMonth(
    month: j['month'] as String? ?? '',
    activeReferrals: _int(j['activeReferrals']),
    topupCoins: _int(j['topupCoins']),
    commissionCherries: _int(j['commissionCherries']),
    levelAfter: j['levelAfter'] as String? ?? '',
    rewardStatus: j['rewardStatus'] as String? ?? 'NONE',
  );

  final String month;
  final int activeReferrals;
  final int topupCoins;
  final int commissionCherries;
  final String levelAfter;
  final String rewardStatus;
}

/// One of `AmbassadorDashboard.recent`.
final class AmbassadorCommission {
  const new({
    required this.id,
    required this.at,
    required this.friend,
    required this.coins,
    required this.cherries,
    required this.status,
  });

  factory fromJson(Map<String, dynamic> j) => AmbassadorCommission(
    id: j['id'] as String? ?? '',
    at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime(2026),
    friend: j['friend'] as String? ?? '',
    coins: _int(j['coins']),
    cherries: _int(j['cherries']),
    status: j['status'] as String? ?? 'PENDING',
  );

  final String id;
  final DateTime at;
  final String friend;
  final int coins;
  final int cherries;
  final String status;
}

/// `AmbassadorDashboard`.
final class AmbassadorDashboard {
  const new({
    required this.enabled,
    required this.payoutsHeld,
    required this.code,
    required this.link,
    required this.levelCode,
    required this.commissionBps,
    required this.nextLevel,
    required this.month,
    required this.monthActiveReferrals,
    required this.monthTopupCoins,
    required this.target,
    required this.referralsTotal,
    required this.referralsActive,
    required this.referralsPending,
    required this.pendingCherries,
    required this.heldCherries,
    required this.paidCherries,
    required this.reversedCherries,
    required this.history,
    required this.recent,
  });

  factory fromJson(Map<String, dynamic> j) {
    final level = j['level'] as Map<String, dynamic>?;
    final next = j['nextLevel'] as Map<String, dynamic>?;
    final month = j['month'] as Map<String, dynamic>? ?? const {};
    final target = month['target'] as Map<String, dynamic>?;
    final refs = j['referrals'] as Map<String, dynamic>? ?? const {};
    final c = j['commissions'] as Map<String, dynamic>? ?? const {};
    return AmbassadorDashboard(
      enabled: j['enabled'] as bool? ?? false,
      payoutsHeld: j['payoutsHeld'] as bool? ?? false,
      code: j['code'] as String? ?? '',
      link: j['link'] as String? ?? '',
      levelCode: level?['code'] as String? ?? '',
      commissionBps: _int(level?['commissionBps']),
      nextLevel: next == null
          ? null
          : (
              code: next['code'] as String? ?? '',
              activeReferrals: _int(next['activeReferrals']),
              topupCoins: _int(next['topupCoins']),
            ),
      month: month['month'] as String? ?? '',
      monthActiveReferrals: _int(month['activeReferrals']),
      monthTopupCoins: _int(month['topupCoins']),
      target: target == null
          ? null
          : AmbassadorLevel.fromJson({...target, 'commissionBps': 0}),
      referralsTotal: _int(refs['total']),
      referralsActive: _int(refs['active']),
      referralsPending: _int(refs['pending']),
      pendingCherries: _int(c['pendingCherries']),
      heldCherries: _int(c['heldCherries']),
      paidCherries: _int(c['paidCherries']),
      reversedCherries: _int(c['reversedCherries']),
      history: _list(j['history']).map(AmbassadorMonth.fromJson).toList(),
      recent: _list(j['recent']).map(AmbassadorCommission.fromJson).toList(),
    );
  }

  final bool enabled;
  final bool payoutsHeld;
  final String code;
  final String link;
  final String levelCode;
  final int commissionBps;
  final ({String code, int activeReferrals, int topupCoins})? nextLevel;
  final String month;
  final int monthActiveReferrals;
  final int monthTopupCoins;

  /// The month's target (the next level's requirements and reward).
  final AmbassadorLevel? target;
  final int referralsTotal;
  final int referralsActive;
  final int referralsPending;
  final int pendingCherries;
  final int heldCherries;
  final int paidCherries;
  final int reversedCherries;
  final List<AmbassadorMonth> history;
  final List<AmbassadorCommission> recent;
}

class AmbassadorRepositoryImpl implements AmbassadorRepository {
  const new(this._dio);

  final Dio _dio;

  @override
  Future<AmbassadorProgramme> programme() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/ambassadors/programme');
    return AmbassadorProgramme.fromJson(res.data!);
  });

  @override
  Future<AmbassadorProgramme> apply(AmbassadorApplicationDraft d) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/ambassadors/applications',
          data: {
            'country': d.country,
            'links': d.links,
            'audienceSize': d.audienceSize,
            'motivation': d.motivation,
          },
        );
        return AmbassadorProgramme.fromJson(res.data!);
      });

  @override
  Future<AmbassadorDashboard> dashboard() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/ambassadors/me');
    return AmbassadorDashboard.fromJson(res.data!);
  });
}

final ambassadorRepositoryProvider = Provider<AmbassadorRepository>(
  (ref) => AmbassadorRepositoryImpl(ref.watch(apiDioProvider)),
);

final FutureProvider<AmbassadorProgramme> ambassadorProgrammeProvider =
    FutureProvider.autoDispose<AmbassadorProgramme>(
      (ref) => ref.watch(ambassadorRepositoryProvider).programme(),
    );

final FutureProvider<AmbassadorDashboard> ambassadorDashboardProvider =
    FutureProvider.autoDispose<AmbassadorDashboard>(
      (ref) => ref.watch(ambassadorRepositoryProvider).dashboard(),
    );
