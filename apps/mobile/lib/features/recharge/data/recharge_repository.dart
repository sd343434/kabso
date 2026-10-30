import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(Object? v) => v is String ? DateTime.parse(v) : null;

/// `RechargeAgentStatus` (openapi v1.54-social, D185, §10.48). An unknown
/// value reads as [none].
enum RechargeAgentStatus {
  none('NONE'),
  pending('PENDING'),
  rejected('REJECTED'),
  approved('APPROVED'),
  active('ACTIVE'),
  suspended('SUSPENDED');

  new(this.wire);

  final String wire;

  static RechargeAgentStatus fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull ?? none;
}

/// `RechargePaymentMethodType`.
enum RechargePaymentType {
  bankTransfer('BANK_TRANSFER'),
  mobileWallet('MOBILE_WALLET'),
  cash('CASH'),
  card('CARD'),
  crypto('CRYPTO'),
  other('OTHER');

  new(this.wire);

  final String wire;

  static RechargePaymentType fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull ?? other;
}

/// `WeeklySlot` (and, with [whatsapp] / [paymentMethod], an availability
/// slot): ISO days 1 = Monday … 7 = Sunday, `HH:MM` start and end.
@immutable
final class WeeklySlot {
  const new({
    required this.days,
    required this.start,
    required this.end,
    this.whatsapp,
    this.paymentMethod,
  });

  factory fromJson(Map<String, dynamic> json) => WeeklySlot(
    days: [for (final d in json['days']! as List<dynamic>) _int(d)],
    start: json['start']! as String,
    end: json['end']! as String,
    whatsapp: json['whatsapp'] as String?,
    paymentMethod: json['paymentMethod'] as String?,
  );

  final List<int> days;
  final String start;
  final String end;
  final String? whatsapp;
  final String? paymentMethod;

  Map<String, Object> toJson() => {
    'days': days,
    'start': start,
    'end': end,
    'whatsapp': ?whatsapp,
    'paymentMethod': ?paymentMethod,
  };
}

/// `RechargeAvailability`.
@immutable
final class RechargeAvailability {
  const new({required this.timeZone, required this.slots});

  factory fromJson(Map<String, dynamic> json) => RechargeAvailability(
    timeZone: json['timeZone']! as String,
    slots: [
      for (final s in json['slots']! as List<dynamic>)
        WeeklySlot.fromJson(s as Map<String, dynamic>),
    ],
  );

  final String timeZone;
  final List<WeeklySlot> slots;
}

typedef SalesTotals = ({int count, int coins});

SalesTotals _totals(Object? json) {
  final m = json! as Map<String, dynamic>;
  return (count: _int(m['count']), coins: _int(m['coins']));
}

/// `RechargeSalesStats`.
typedef SalesStats = ({
  SalesTotals today,
  SalesTotals last7Days,
  SalesTotals last30Days,
});

SalesStats salesStatsFromJson(Object? json) {
  final m = json! as Map<String, dynamic>;
  return (
    today: _totals(m['today']),
    last7Days: _totals(m['last7Days']),
    last30Days: _totals(m['last30Days']),
  );
}

/// `RechargeAgentDashboard`.
@immutable
final class RechargeAgentDashboard {
  const new({
    required this.status,
    required this.stockCoins,
    required this.dailyCherryCap,
    required this.todayCherries,
    required this.availability,
    required this.sales,
    this.code,
    this.activatedAt,
  });

  factory fromJson(Map<String, dynamic> json) => RechargeAgentDashboard(
    code: json['code'] as String?,
    status: RechargeAgentStatus.fromWire(json['status']),
    stockCoins: _int(json['stockCoins']),
    activatedAt: _date(json['activatedAt']),
    dailyCherryCap: _int(json['dailyCherryCap']),
    todayCherries: _int(json['todayCherries']),
    availability: RechargeAvailability.fromJson(
      json['availability']! as Map<String, dynamic>,
    ),
    sales: salesStatsFromJson(json['sales']),
  );

  final String? code;
  final RechargeAgentStatus status;
  final int stockCoins;
  final DateTime? activatedAt;
  final int dailyCherryCap;
  final int todayCherries;
  final RechargeAvailability availability;
  final SalesStats sales;
}

/// `RechargeEmployment`: the caller works for an agent.
@immutable
final class RechargeEmployment {
  const new({
    required this.agent,
    required this.timeZone,
    required this.schedule,
    required this.onShiftNow,
    this.agentCode,
  });

  factory fromJson(Map<String, dynamic> json) => RechargeEmployment(
    agentCode: json['agentCode'] as String?,
    agent: UserSummary.fromJson(json['agent']! as Map<String, dynamic>),
    timeZone: json['timeZone']! as String,
    schedule: [
      for (final s in json['schedule']! as List<dynamic>)
        WeeklySlot.fromJson(s as Map<String, dynamic>),
    ],
    onShiftNow: json['onShiftNow'] == true,
  );

  final String? agentCode;
  final UserSummary agent;
  final String timeZone;
  final List<WeeklySlot> schedule;
  final bool onShiftNow;
}

/// `RechargeRules`.
@immutable
final class RechargeRules {
  const new({
    required this.activationMinCoins,
    required this.cherryUnit,
    required this.coinsPerCherryUnit,
    required this.minCherries,
    required this.stepCherries,
    required this.requestTtlMinutes,
    required this.payoutRateCherries,
    required this.payoutRateMinor,
    required this.currency,
  });

  factory fromJson(Map<String, dynamic> json) {
    final payout = json['payout']! as Map<String, dynamic>;
    return RechargeRules(
      activationMinCoins: _int(json['activationMinCoins']),
      cherryUnit: _int(json['cherryUnit']),
      coinsPerCherryUnit: _int(json['coinsPerCherryUnit']),
      minCherries: _int(json['minCherries']),
      stepCherries: _int(json['stepCherries']),
      requestTtlMinutes: _int(json['requestTtlMinutes']),
      payoutRateCherries: _int(payout['rateCherries']),
      payoutRateMinor: _int(payout['rateMinor']),
      currency: payout['currency']! as String,
    );
  }

  final int activationMinCoins;
  final int cherryUnit;
  final int coinsPerCherryUnit;
  final int minCherries;
  final int stepCherries;
  final int requestTtlMinutes;
  final int payoutRateCherries;
  final int payoutRateMinor;
  final String currency;

  /// What the agent's stock gets for [cherries] (the server's floor).
  int coinsFor(int cherries) =>
      cherryUnit == 0 ? 0 : cherries * coinsPerCherryUnit ~/ cherryUnit;

  /// What the agent pays the host for [cherries] (minor units).
  int payoutMinorFor(int cherries) => payoutRateCherries == 0
      ? 0
      : cherries * payoutRateMinor ~/ payoutRateCherries;
}

/// `RechargeAgentMe`.
@immutable
final class RechargeAgentMe {
  const new({
    required this.status,
    required this.canApply,
    required this.rules,
    this.submittedAt,
    this.rejectReason,
    this.agent,
    this.employment,
  });

  factory fromJson(Map<String, dynamic> json) {
    final app = json['application'] as Map<String, dynamic>?;
    return RechargeAgentMe(
      status: RechargeAgentStatus.fromWire(json['status']),
      canApply: json['canApply'] == true,
      submittedAt: _date(app?['submittedAt']),
      rejectReason: app?['rejectReason'] as String?,
      agent: json['agent'] == null
          ? null
          : RechargeAgentDashboard.fromJson(
              json['agent']! as Map<String, dynamic>,
            ),
      employment: json['employment'] == null
          ? null
          : RechargeEmployment.fromJson(
              json['employment']! as Map<String, dynamic>,
            ),
      rules: RechargeRules.fromJson(json['rules']! as Map<String, dynamic>),
    );
  }

  final RechargeAgentStatus status;
  final bool canApply;
  final DateTime? submittedAt;
  final String? rejectReason;
  final RechargeAgentDashboard? agent;
  final RechargeEmployment? employment;
  final RechargeRules rules;
}

/// `RechargeSale`.
@immutable
final class RechargeSale {
  const new({
    required this.id,
    required this.coins,
    required this.buyer,
    required this.seller,
    required this.agentCode,
    required this.createdAt,
    this.stockAfter,
  });

  factory fromJson(Map<String, dynamic> json) => RechargeSale(
    id: json['id']! as String,
    coins: _int(json['coins']),
    buyer: UserSummary.fromJson(json['buyer']! as Map<String, dynamic>),
    seller: UserSummary.fromJson(json['seller']! as Map<String, dynamic>),
    agentCode: json['agentCode']! as String,
    stockAfter: (json['stockAfter'] as num?)?.toInt(),
    createdAt: DateTime.parse(json['createdAt']! as String),
  );

  final String id;
  final int coins;
  final UserSummary buyer;
  final UserSummary seller;
  final String agentCode;
  final int? stockAfter;
  final DateTime createdAt;
}

/// `RechargeEmployee`.
@immutable
final class RechargeEmployee {
  const new({
    required this.user,
    required this.timeZone,
    required this.schedule,
    required this.onShiftNow,
    required this.addedAt,
    required this.sales,
  });

  factory fromJson(Map<String, dynamic> json) => RechargeEmployee(
    user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
    timeZone: json['timeZone']! as String,
    schedule: [
      for (final s in json['schedule']! as List<dynamic>)
        WeeklySlot.fromJson(s as Map<String, dynamic>),
    ],
    onShiftNow: json['onShiftNow'] == true,
    addedAt: DateTime.parse(json['addedAt']! as String),
    sales: salesStatsFromJson(json['sales']),
  );

  final UserSummary user;
  final String timeZone;
  final List<WeeklySlot> schedule;
  final bool onShiftNow;
  final DateTime addedAt;
  final SalesStats sales;
}

/// `RechargeLocation`.
typedef RechargeLocation = ({String country, List<String> cities});

/// `RechargeAgentListing`: one agent in the directory.
@immutable
final class RechargeAgentListing {
  const new({
    required this.code,
    required this.user,
    required this.locations,
    required this.paymentTypes,
    this.whatsappNow,
    this.paymentMethodNow,
  });

  factory fromJson(Map<String, dynamic> json) {
    final now = json['availableNow'] as Map<String, dynamic>?;
    return RechargeAgentListing(
      code: json['code']! as String,
      user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
      locations: [
        for (final l in json['locations']! as List<dynamic>)
          (
            country: (l as Map<String, dynamic>)['country']! as String,
            cities: [
              for (final c in l['cities']! as List<dynamic>) c as String,
            ],
          ),
      ],
      paymentTypes: [
        for (final t in json['paymentMethodTypes']! as List<dynamic>)
          RechargePaymentType.fromWire(t),
      ],
      whatsappNow: now?['whatsapp'] as String?,
      paymentMethodNow: now?['paymentMethod'] as String?,
    );
  }

  final String code;
  final UserSummary user;
  final List<RechargeLocation> locations;
  final List<RechargePaymentType> paymentTypes;

  /// The contact and payment method of the slot that contains «now»; null
  /// when the agent is not available now.
  final String? whatsappNow;
  final String? paymentMethodNow;

  bool get availableNow => whatsappNow != null;
}

/// `RechargeCherryRequest` status.
enum RechargeCherryStatus {
  pending('PENDING'),
  confirmed('CONFIRMED'),
  declined('DECLINED'),
  cancelled('CANCELLED'),
  expired('EXPIRED');

  new(this.wire);

  final String wire;

  static RechargeCherryStatus fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull ?? expired;
}

/// `RechargeCherryRequest`.
@immutable
final class RechargeCherryRequest {
  const new({
    required this.id,
    required this.status,
    required this.cherries,
    required this.coins,
    required this.payoutMinor,
    required this.currency,
    required this.agentCode,
    required this.agent,
    required this.host,
    required this.byHost,
    required this.createdAt,
    required this.expiresAt,
  });

  factory fromJson(Map<String, dynamic> json) => RechargeCherryRequest(
    id: json['id']! as String,
    status: RechargeCherryStatus.fromWire(json['status']),
    cherries: _int(json['cherries']),
    coins: _int(json['coins']),
    payoutMinor: _int(json['payoutMinor']),
    currency: json['currency']! as String,
    agentCode: json['agentCode']! as String,
    agent: UserSummary.fromJson(json['agent']! as Map<String, dynamic>),
    host: UserSummary.fromJson(json['host']! as Map<String, dynamic>),
    byHost: json['initiatedBy'] == 'HOST',
    createdAt: DateTime.parse(json['createdAt']! as String),
    expiresAt: DateTime.parse(json['expiresAt']! as String),
  );

  final String id;
  final RechargeCherryStatus status;
  final int cherries;
  final int coins;
  final int payoutMinor;
  final String currency;
  final String agentCode;
  final UserSummary agent;
  final UserSummary host;

  /// Created by the host (else by the agent).
  final bool byHost;
  final DateTime createdAt;
  final DateTime expiresAt;
}

/// What the application form sends (the two pictures are uploaded first).
@immutable
final class RechargeApplicationDraft {
  const new({
    required this.fullName,
    required this.phone,
    required this.photo,
    required this.photoType,
    required this.selfie,
    required this.selfieType,
    required this.locations,
    required this.paymentMethods,
  });

  final String fullName;
  final String phone;
  final Uint8List photo;
  final String photoType;
  final Uint8List selfie;
  final String selfieType;
  final List<RechargeLocation> locations;
  final List<({String country, RechargePaymentType type, String details})>
  paymentMethods;
}

/// Recharge agents (openapi v1.54-social, D185). Every method throws an
/// `AppFailure`.
abstract interface class RechargeRepository {
  Future<RechargeAgentMe> me();
  Future<RechargeAgentMe> apply(RechargeApplicationDraft draft);
  Future<RechargeAvailability> setAvailability(RechargeAvailability value);
  Future<RechargeSale> sell({
    required String buyer,
    required int coins,
    required String idempotencyKey,
  });
  Future<WalletPage<RechargeSale>> sales({String? cursor});
  Future<List<RechargeEmployee>> employees();
  Future<RechargeEmployee> addEmployee(
    String username,
    String timeZone,
    List<WeeklySlot> schedule,
  );
  Future<RechargeEmployee> updateEmployee(
    String username,
    String timeZone,
    List<WeeklySlot> schedule,
  );
  Future<void> removeEmployee(String username);
  Future<WalletPage<RechargeAgentListing>> directory(
    String country, {
    String? cursor,
  });
  Future<RechargeCherryRequest> createCherryRequest({
    required int cherries,
    required String idempotencyKey,
    String? agentCode,
    String? host,
  });
  Future<WalletPage<RechargeCherryRequest>> cherryRequests({String? cursor});
  Future<RechargeCherryRequest> answerCherryRequest(String id, String action);
}

class RechargeRepositoryImpl implements RechargeRepository {
  new(this._dio, this._storage);

  final Dio _dio;

  /// A bare client for the presigned upload URL (never the bearer token).
  final Dio _storage;

  @override
  Future<RechargeAgentMe> me() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/recharge-agent');
    return RechargeAgentMe.fromJson(res.data!);
  });

  /// Slot and PUT only: the application consumes the upload (never
  /// completed, never public, §10.48).
  Future<String> _privateUpload(
    Uint8List bytes,
    String contentType,
    String kind,
  ) async {
    final slot = (await _dio.post<Map<String, dynamic>>(
      '/media/uploads',
      data: {
        'kind': kind,
        'contentType': contentType,
        'byteSize': bytes.length,
      },
    )).data!;
    final headers = {
      for (final e in (slot['headers']! as Map<String, dynamic>).entries)
        e.key: e.value as String,
    };
    await _storage.put<void>(
      slot['uploadUrl']! as String,
      data: Stream.fromIterable([bytes]),
      options: Options(headers: headers, contentType: headers['Content-Type']),
    );
    return slot['uploadId']! as String;
  }

  @override
  Future<RechargeAgentMe> apply(RechargeApplicationDraft d) => guardApiCall(
    () async {
      final photo = await _privateUpload(
        d.photo,
        d.photoType,
        'RECHARGE_AGENT_PHOTO',
      );
      final selfie = await _privateUpload(
        d.selfie,
        d.selfieType,
        'RECHARGE_AGENT_SELFIE',
      );
      final res = await _dio.post<Map<String, dynamic>>(
        '/me/recharge-agent/application',
        data: {
          'fullName': d.fullName,
          'phone': d.phone,
          'whatsapp': true,
          'photoUploadId': photo,
          'selfieUploadId': selfie,
          'locations': [
            for (final l in d.locations)
              {'country': l.country, 'cities': l.cities},
          ],
          'paymentMethods': [
            for (final p in d.paymentMethods)
              {'country': p.country, 'type': p.type.wire, 'details': p.details},
          ],
        },
      );
      return RechargeAgentMe.fromJson(res.data!);
    },
  );

  @override
  Future<RechargeAvailability> setAvailability(RechargeAvailability value) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '/me/recharge-agent/availability',
          data: {
            'timeZone': value.timeZone,
            'slots': [for (final s in value.slots) s.toJson()],
          },
        );
        return RechargeAvailability.fromJson(res.data!);
      });

  @override
  Future<RechargeSale> sell({
    required String buyer,
    required int coins,
    required String idempotencyKey,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/recharge-agent/sales',
      data: {'buyer': buyer.trim(), 'coins': coins},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return RechargeSale.fromJson(res.data!);
  });

  Future<WalletPage<T>> _page<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, Object?> query = const {},
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {for (final e in query.entries) e.key: ?e.value},
    );
    final body = res.data!;
    final page = PageInfo.fromJson(body['page']! as Map<String, dynamic>);
    return (
      items: [
        for (final e in body['data']! as List<dynamic>)
          parse(e as Map<String, dynamic>),
      ],
      next: page.hasMore ? page.nextCursor : null,
    );
  });

  @override
  Future<WalletPage<RechargeSale>> sales({String? cursor}) => _page(
    '/me/recharge-agent/sales',
    RechargeSale.fromJson,
    query: {'cursor': cursor},
  );

  @override
  Future<List<RechargeEmployee>> employees() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/me/recharge-agent/employees',
    );
    return [
      for (final e in res.data!['data']! as List<dynamic>)
        RechargeEmployee.fromJson(e as Map<String, dynamic>),
    ];
  });

  @override
  Future<RechargeEmployee> addEmployee(
    String username,
    String timeZone,
    List<WeeklySlot> schedule,
  ) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/recharge-agent/employees',
      data: {
        'username': username.trim().replaceFirst('@', ''),
        'timeZone': timeZone,
        'schedule': [for (final s in schedule) s.toJson()],
      },
    );
    return RechargeEmployee.fromJson(res.data!);
  });

  @override
  Future<RechargeEmployee> updateEmployee(
    String username,
    String timeZone,
    List<WeeklySlot> schedule,
  ) => guardApiCall(() async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/me/recharge-agent/employees/${pathSegment(username)}',
      data: {
        'timeZone': timeZone,
        'schedule': [for (final s in schedule) s.toJson()],
      },
    );
    return RechargeEmployee.fromJson(res.data!);
  });

  @override
  Future<void> removeEmployee(String username) => guardApiCall(() async {
    await _dio.delete<void>(
      '/me/recharge-agent/employees/${pathSegment(username)}',
    );
  });

  @override
  Future<WalletPage<RechargeAgentListing>> directory(
    String country, {
    String? cursor,
  }) => _page(
    '/recharge-agents',
    RechargeAgentListing.fromJson,
    query: {'country': country, 'cursor': cursor},
  );

  @override
  Future<RechargeCherryRequest> createCherryRequest({
    required int cherries,
    required String idempotencyKey,
    String? agentCode,
    String? host,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/recharge-cherry-requests',
      data: {
        'cherries': cherries,
        'agentCode': ?agentCode?.trim(),
        'host': ?host?.trim().replaceFirst('@', ''),
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return RechargeCherryRequest.fromJson(res.data!);
  });

  @override
  Future<WalletPage<RechargeCherryRequest>> cherryRequests({String? cursor}) =>
      _page(
        '/recharge-cherry-requests',
        RechargeCherryRequest.fromJson,
        query: {'cursor': cursor},
      );

  @override
  Future<RechargeCherryRequest> answerCherryRequest(String id, String action) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/recharge-cherry-requests/${pathSegment(id)}/${pathSegment(action)}',
        );
        return RechargeCherryRequest.fromJson(res.data!);
      });
}

final rechargeRepositoryProvider = Provider<RechargeRepository>(
  (ref) => RechargeRepositoryImpl(
    ref.watch(apiDioProvider),
    ref.watch(storageDioProvider),
  ),
);
