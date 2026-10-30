import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// `AgencyRank` (openapi v1.52-social, D179, CONVENTIONS §10.46). An
/// unknown value (a newer server) reads as [newAgency].
enum AgencyRank {
  newAgency('NEW'),
  agent('AGENT'),
  admin('ADMIN'),
  lapsed('LAPSED');

  new(this.wire);

  final String wire;

  static AgencyRank fromWire(Object? wire) =>
      values.where((r) => r.wire == wire).firstOrNull ?? newAgency;
}

/// `AgencyPreview`: an agency as a host sees it before and after joining.
@immutable
final class AgencyPreview {
  const new({
    required this.inviteCode,
    required this.owner,
    required this.rank,
    required this.hostCount,
  });

  factory fromJson(Map<String, dynamic> json) => AgencyPreview(
    inviteCode: json['inviteCode']! as String,
    owner: UserSummary.fromJson(json['owner']! as Map<String, dynamic>),
    rank: AgencyRank.fromWire(json['rank']),
    hostCount: _int(json['hostCount']),
  );

  final String inviteCode;
  final UserSummary owner;
  final AgencyRank rank;
  final int hostCount;
}

/// `AgencyComplaint`.
@immutable
final class AgencyComplaint {
  const new({
    required this.id,
    required this.open,
    required this.text,
    required this.createdAt,
    this.resolution,
  });

  factory fromJson(Map<String, dynamic> json) => AgencyComplaint(
    id: json['id']! as String,
    open: json['status'] == 'OPEN',
    text: json['text']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    resolution: json['resolution'] as String?,
  );

  final String id;
  final bool open;
  final String text;
  final DateTime createdAt;

  /// RELEASED, MOVED or KEPT once the team decided.
  final String? resolution;
}

/// `AgencyMembership`: the caller as a host.
@immutable
final class AgencyMembership {
  const new({
    required this.agency,
    required this.joinedAt,
    required this.leaveUntil,
    required this.canLeave,
    this.complaint,
  });

  factory fromJson(Map<String, dynamic> json) => AgencyMembership(
    agency: AgencyPreview.fromJson(json['agency']! as Map<String, dynamic>),
    joinedAt: DateTime.parse(json['joinedAt']! as String),
    leaveUntil: DateTime.parse(json['leaveUntil']! as String),
    canLeave: json['canLeave'] == true,
    complaint: json['complaint'] == null
        ? null
        : AgencyComplaint.fromJson(json['complaint']! as Map<String, dynamic>),
  );

  final AgencyPreview agency;
  final DateTime joinedAt;
  final DateTime leaveUntil;
  final bool canLeave;
  final AgencyComplaint? complaint;
}

/// `AgencyCommissionTotals`.
typedef CommissionTotals = ({int thisMonth, int lastMonth, int total});

CommissionTotals _totals(Object? json) {
  final m = json! as Map<String, dynamic>;
  return (
    thisMonth: _int(m['thisMonth']),
    lastMonth: _int(m['lastMonth']),
    total: _int(m['total']),
  );
}

/// `AgencySubAgency`.
@immutable
final class SubAgency {
  const new({
    required this.inviteCode,
    required this.owner,
    required this.rank,
    required this.activeHosts,
    required this.monthHostCherries,
    required this.qualifies,
  });

  factory fromJson(Map<String, dynamic> json) => SubAgency(
    inviteCode: json['inviteCode']! as String,
    owner: UserSummary.fromJson(json['owner']! as Map<String, dynamic>),
    rank: AgencyRank.fromWire(json['rank']),
    activeHosts: _int(json['activeHosts']),
    monthHostCherries: _int(json['monthHostCherries']),
    qualifies: json['qualifies'] == true,
  );

  final String inviteCode;
  final UserSummary owner;
  final AgencyRank rank;
  final int activeHosts;
  final int monthHostCherries;
  final bool qualifies;
}

/// `OwnAgency`: the caller's agency as its agent sees it.
@immutable
final class OwnAgency {
  const new({
    required this.inviteCode,
    required this.rank,
    required this.month,
    required this.commissionRateBps,
    required this.hostCount,
    required this.activeHosts,
    required this.requiredActiveHosts,
    required this.monthHostCherries,
    required this.lastMonthHostCherries,
    required this.exceptionCherries,
    required this.tierCherries,
    required this.qualifiesNow,
    required this.qualifiedSubAgencies,
    required this.requiredSubAgencies,
    required this.commission,
    required this.parentCommission,
    required this.subAgencies,
    this.parent,
  });

  factory fromJson(Map<String, dynamic> json) {
    final p = json['progress']! as Map<String, dynamic>;
    return OwnAgency(
      inviteCode: json['inviteCode']! as String,
      rank: AgencyRank.fromWire(json['rank']),
      month: json['month']! as String,
      commissionRateBps: _int(json['commissionRateBps']),
      hostCount: _int(p['hostCount']),
      activeHosts: _int(p['activeHosts']),
      requiredActiveHosts: _int(p['requiredActiveHosts']),
      monthHostCherries: _int(p['monthHostCherries']),
      lastMonthHostCherries: _int(p['lastMonthHostCherries']),
      exceptionCherries: _int(p['exceptionCherries']),
      tierCherries: _int(p['tierCherries']),
      qualifiesNow: p['qualifiesNow'] == true,
      qualifiedSubAgencies: _int(p['qualifiedSubAgencies']),
      requiredSubAgencies: _int(p['requiredSubAgencies']),
      commission: _totals(json['commission']),
      parentCommission: _totals(json['parentCommission']),
      subAgencies: [
        for (final s in json['subAgencies']! as List<dynamic>)
          SubAgency.fromJson(s as Map<String, dynamic>),
      ],
      parent: json['parent'] == null
          ? null
          : AgencyPreview.fromJson(json['parent']! as Map<String, dynamic>),
    );
  }

  final String inviteCode;
  final AgencyRank rank;

  /// `YYYY-MM`.
  final String month;
  final int commissionRateBps;
  final int hostCount;
  final int activeHosts;
  final int requiredActiveHosts;
  final int monthHostCherries;
  final int lastMonthHostCherries;
  final int exceptionCherries;
  final int tierCherries;
  final bool qualifiesNow;
  final int qualifiedSubAgencies;
  final int requiredSubAgencies;
  final CommissionTotals commission;
  final CommissionTotals parentCommission;
  final List<SubAgency> subAgencies;
  final AgencyPreview? parent;
}

/// `MyAgency`.
@immutable
final class MyAgency {
  const new({
    required this.activeMinDays,
    required this.activeMinHours,
    required this.activeWindowDays,
    required this.leaveDays,
    this.membership,
    this.ownAgency,
  });

  factory fromJson(Map<String, dynamic> json) {
    final rule = json['activeHostRule']! as Map<String, dynamic>;
    return MyAgency(
      membership: json['membership'] == null
          ? null
          : AgencyMembership.fromJson(
              json['membership']! as Map<String, dynamic>,
            ),
      ownAgency: json['ownAgency'] == null
          ? null
          : OwnAgency.fromJson(json['ownAgency']! as Map<String, dynamic>),
      activeMinDays: _int(rule['minDays']),
      activeMinHours: _int(rule['minHours']),
      activeWindowDays: _int(rule['windowDays']),
      leaveDays: _int(json['leaveDays']),
    );
  }

  final AgencyMembership? membership;
  final OwnAgency? ownAgency;
  final int activeMinDays;
  final int activeMinHours;
  final int activeWindowDays;
  final int leaveDays;
}

/// `AgencyHost`: one host in the agent's list.
@immutable
final class AgencyHostRow {
  const new({
    required this.user,
    required this.joinedAt,
    required this.liveDays,
    required this.liveSeconds,
    required this.active,
    required this.monthCherries,
    required this.commissionEligible,
  });

  factory fromJson(Map<String, dynamic> json) => AgencyHostRow(
    user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
    joinedAt: DateTime.parse(json['joinedAt']! as String),
    liveDays: _int(json['liveDays']),
    liveSeconds: _int(json['liveSeconds']),
    active: json['active'] == true,
    monthCherries: _int(json['monthCherries']),
    commissionEligible: json['commissionEligible'] == true,
  );

  final UserSummary user;
  final DateTime joinedAt;
  final int liveDays;
  final int liveSeconds;
  final bool active;
  final int monthCherries;
  final bool commissionEligible;
}

/// Host agencies (openapi v1.52-social, D179). Every method throws an
/// `AppFailure`.
abstract interface class AgencyRepository {
  /// `GET /me/agency`.
  Future<MyAgency> mine();

  /// `GET /agencies/{inviteCode}`.
  Future<AgencyPreview> byCode(String inviteCode);

  /// `POST /me/agency/join`.
  Future<MyAgency> join(String inviteCode);

  /// `POST /me/agency/leave`.
  Future<MyAgency> leave();

  /// `POST /me/agency/complaints`.
  Future<AgencyComplaint> complain(String text);

  /// `GET /me/agency/hosts`.
  Future<WalletPage<AgencyHostRow>> hosts({String? cursor});
}

class AgencyRepositoryImpl implements AgencyRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<MyAgency> mine() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/agency');
    return MyAgency.fromJson(res.data!);
  });

  @override
  Future<AgencyPreview> byCode(String inviteCode) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/agencies/${Uri.encodeComponent(inviteCode.trim())}',
    );
    return AgencyPreview.fromJson(res.data!);
  });

  @override
  Future<MyAgency> join(String inviteCode) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/agency/join',
      data: {'inviteCode': inviteCode.trim()},
    );
    return MyAgency.fromJson(res.data!);
  });

  @override
  Future<MyAgency> leave() => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>('/me/agency/leave');
    return MyAgency.fromJson(res.data!);
  });

  @override
  Future<AgencyComplaint> complain(String text) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/agency/complaints',
      data: {'text': text.trim()},
    );
    return AgencyComplaint.fromJson(res.data!);
  });

  @override
  Future<WalletPage<AgencyHostRow>> hosts({String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/me/agency/hosts',
          queryParameters: {'cursor': ?cursor},
        );
        final body = res.data!;
        final page = PageInfo.fromJson(body['page']! as Map<String, dynamic>);
        return (
          items: [
            for (final e in body['data']! as List<dynamic>)
              AgencyHostRow.fromJson(e as Map<String, dynamic>),
          ],
          next: page.hasMore ? page.nextCursor : null,
        );
      });
}

final agencyRepositoryProvider = Provider<AgencyRepository>(
  (ref) => AgencyRepositoryImpl(ref.watch(apiDioProvider)),
);
