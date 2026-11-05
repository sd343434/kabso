import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/agency/data/hosting_application.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart'
    show storageDioProvider;
import 'package:kabso_live/features/recharge/data/recharge_repository.dart'
    show uploadPrivateImage;
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
    this.hostAgentCode,
    this.hostAgentActive = false,
    this.hostAgentUsernameShown = false,
    this.name,
    this.probation,
  });

  factory fromJson(Map<String, dynamic> json) {
    final p = json['progress']! as Map<String, dynamic>;
    // v1.58-social (D189): absent on older servers (no host-agent part).
    final host = switch (json['hostAgent']) {
      final Map<String, dynamic> h => h,
      _ => const <String, dynamic>{},
    };
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
      hostAgentCode: switch (host['code']) {
        final String code when code.isNotEmpty => code,
        _ => null,
      },
      hostAgentActive: host['active'] == true,
      hostAgentUsernameShown: host['usernameShown'] == true,
      name: json['name'] as String?,
      probation: switch (json['probation']) {
        final Map<String, dynamic> pr => AgencyProbation.fromJson(pr),
        _ => null,
      },
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

  /// v1.58-social (D189, §10.52): the owner's host-agent code `hostNN`
  /// (`OwnAgency.hostAgent.code`); null on an older server or before the
  /// server gave an older agency its code.
  final String? hostAgentCode;

  /// The host-agent perks are on (false: suspended by the team).
  final bool hostAgentActive;

  /// The code is the username shown now (false: suspended, or a recharge
  /// code activated first is shown and this one is kept reserved).
  final bool hostAgentUsernameShown;

  /// v1.70-social (D206): the agency's name (null: made by the team before
  /// D206 or an older server).
  final String? name;

  /// v1.70-social (D206): the probation of a self-opened agency (null: none).
  final AgencyProbation? probation;
}

/// v1.70-social (D206, §10.65): one host in a probation and the three steps.
@immutable
final class AgencyProbationHost {
  const new({
    required this.user,
    required this.joinedAt,
    required this.wentLive,
    required this.receivedGifts,
    required this.activated,
  });

  factory fromJson(Map<String, dynamic> json) => AgencyProbationHost(
    user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
    joinedAt: DateTime.parse(json['joinedAt']! as String),
    wentLive: json['wentLive'] == true,
    receivedGifts: json['receivedGifts'] == true,
    activated: json['activated'] == true,
  );

  final UserSummary user;
  final DateTime joinedAt;
  final bool wentLive;
  final bool receivedGifts;
  final bool activated;
}

/// v1.70-social (D206): `AgencyProbation`.
@immutable
final class AgencyProbation {
  const new({
    required this.running,
    required this.endsAt,
    required this.days,
    required this.requiredHosts,
    required this.activatedHosts,
    required this.hosts,
    this.passedAt,
  });

  factory fromJson(Map<String, dynamic> json) => AgencyProbation(
    running: json['status'] == 'RUNNING',
    endsAt: DateTime.parse(json['endsAt']! as String),
    passedAt: switch (json['passedAt']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    days: _int(json['days']),
    requiredHosts: _int(json['requiredHosts']),
    activatedHosts: _int(json['activatedHosts']),
    hosts: [
      for (final h in (json['hosts'] as List<dynamic>?) ?? const [])
        AgencyProbationHost.fromJson(h as Map<String, dynamic>),
    ],
  );

  /// RUNNING (false: PASSED).
  final bool running;
  final DateTime endsAt;
  final DateTime? passedAt;
  final int days;
  final int requiredHosts;
  final int activatedHosts;
  final List<AgencyProbationHost> hosts;
}

/// v1.70-social (D206): `ClosedAgency` — the caller's own agency, closed.
@immutable
final class ClosedAgency {
  const new({
    required this.inviteCode,
    required this.closedAt,
    required this.probationFailed,
    required this.reopenAt,
    this.name,
    this.activatedHosts,
    this.requiredHosts,
  });

  factory fromJson(Map<String, dynamic> json) => ClosedAgency(
    name: json['name'] as String?,
    inviteCode: json['inviteCode']! as String,
    closedAt: DateTime.parse(json['closedAt']! as String),
    probationFailed: json['reason'] == 'PROBATION_FAILED',
    activatedHosts: (json['activatedHosts'] as num?)?.toInt(),
    requiredHosts: (json['requiredHosts'] as num?)?.toInt(),
    reopenAt: DateTime.parse(json['reopenAt']! as String),
  );

  final String? name;
  final String inviteCode;
  final DateTime closedAt;

  /// PROBATION_FAILED (false: the team closed it).
  final bool probationFailed;
  final int? activatedHosts;
  final int? requiredHosts;
  final DateTime reopenAt;
}

/// v1.70-social (D206): why «افتح وكالة» is not offered now.
enum AgencyOpenRefusal {
  accountNotActive('ACCOUNT_NOT_ACTIVE'),
  ownsAgency('OWNS_AGENCY'),
  hostOfAgency('HOST_OF_AGENCY'),
  reopenCooldown('REOPEN_COOLDOWN'),

  /// v1.80-kyc (D227): Didit is on and the identity check is not approved.
  kycRequired('KYC_REQUIRED');

  new(this.wire);

  final String wire;

  static AgencyOpenRefusal? fromWire(Object? wire) =>
      values.where((r) => r.wire == wire).firstOrNull;
}

/// v1.70-social (D206): `AgencyOpenRule`. An older server sends none: the
/// app does not offer «افتح وكالة» there.
@immutable
final class AgencyOpenRule {
  const new({
    required this.canOpen,
    required this.probationDays,
    required this.requiredHosts,
    required this.reopenCooldownDays,
    this.refusal,
  });

  factory fromJson(Map<String, dynamic> json) => AgencyOpenRule(
    canOpen: json['canOpen'] == true,
    refusal: AgencyOpenRefusal.fromWire(json['refusal']),
    probationDays: _int(json['probationDays']),
    requiredHosts: _int(json['requiredHosts']),
    reopenCooldownDays: _int(json['reopenCooldownDays']),
  );

  final bool canOpen;
  final AgencyOpenRefusal? refusal;
  final int probationDays;
  final int requiredHosts;
  final int reopenCooldownDays;
}

/// v1.70-social (D206): the contact method of `OpenAgencyRequest`.
enum AgencyContactType {
  whatsapp('WHATSAPP'),
  telegram('TELEGRAM'),
  phone('PHONE'),
  email('EMAIL'),
  other('OTHER');

  new(this.wire);

  final String wire;
}

/// v1.70-social (D206): «افتح وكالة» as filled in.
@immutable
final class AgencyOpenDraft {
  const new({
    required this.name,
    required this.country,
    required this.contactType,
    required this.contactValue,
    required this.expectedHosts,
    required this.bio,
    required this.idempotencyKey,
    this.idCard,
    this.idCardType,
    this.selfie,
    this.selfieType,
    this.recruiter,
  });

  /// v1.75-live (D285): «إن كنت تابعاً لمشرف، ضع معرّفه هنا» — a staff ID or
  /// username, checked live (null: none).
  final String? recruiter;

  final String name;

  /// ISO alpha-2.
  final String country;
  final AgencyContactType contactType;
  final String contactValue;
  final int expectedHosts;
  final String bio;

  /// v1.80-kyc (D227): null while Didit is on (the identity check replaces
  /// the manual ID pictures; nothing is uploaded).
  final Uint8List? idCard;
  final String? idCardType;
  final Uint8List? selfie;
  final String? selfieType;

  /// One per attempt of the form (a retry after a lost answer reuses it).
  final String idempotencyKey;
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
    this.closedAgency,
    this.openRule,
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
      closedAgency: switch (json['closedAgency']) {
        final Map<String, dynamic> c => ClosedAgency.fromJson(c),
        _ => null,
      },
      openRule: switch (json['openRule']) {
        final Map<String, dynamic> r => AgencyOpenRule.fromJson(r),
        _ => null,
      },
    );
  }

  final AgencyMembership? membership;
  final OwnAgency? ownAgency;

  /// v1.70-social (D206): the caller's own agency when it is closed.
  final ClosedAgency? closedAgency;

  /// v1.70-social (D206): «افتح وكالة» for the caller (null: an older
  /// server — not offered).
  final AgencyOpenRule? openRule;
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

  /// v1.70-social (D206): `POST /me/agency/open` — the two pictures go up as
  /// D185 private uploads first.
  Future<MyAgency> open(AgencyOpenDraft draft);

  /// v1.73-social (D209): `GET /me/hosting-application` — «كن مضيفاً مع
  /// الإدارة». Null from an older server (404): the page does not offer it.
  Future<MyHostingApplication?> hosting();

  /// v1.73-social (D209): `POST /me/hosting-application` — the two pictures
  /// go up as D185 private uploads first.
  Future<MyHostingApplication> applyForHosting(HostingDraft draft);

  /// v1.73-social (D209): `POST /me/hosting-application/cancel`.
  Future<MyHostingApplication> cancelHosting();
}

class AgencyRepositoryImpl implements AgencyRepository {
  new(this._dio, [Dio? storage]) : _storage = storage ?? _dio;

  final Dio _dio;

  /// The object store's client (presigned PUTs).
  final Dio _storage;

  /// v1.80-kyc (D227): the two D185 private uploads, or none while Didit is on
  /// (the draft carries no pictures).
  Future<(String?, String?)> _idPictures(
    Uint8List? idCard,
    String? idCardType,
    Uint8List? selfie,
    String? selfieType,
  ) async {
    if (idCard == null || selfie == null) return (null, null);
    final photo = await uploadPrivateImage(
      _dio,
      _storage,
      idCard,
      idCardType ?? 'image/jpeg',
      'RECHARGE_AGENT_PHOTO',
    );
    final face = await uploadPrivateImage(
      _dio,
      _storage,
      selfie,
      selfieType ?? 'image/jpeg',
      'RECHARGE_AGENT_SELFIE',
    );
    return (photo, face);
  }

  @override
  Future<MyAgency> open(AgencyOpenDraft d) => guardApiCall(() async {
    final (idCard, selfie) = await _idPictures(
      d.idCard,
      d.idCardType,
      d.selfie,
      d.selfieType,
    );
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/agency/open',
      data: {
        'name': d.name,
        'country': d.country,
        'contact': {'type': d.contactType.wire, 'value': d.contactValue},
        'expectedHosts': d.expectedHosts,
        if (d.bio.isNotEmpty) 'bio': d.bio,
        'photoUploadId': ?idCard,
        'selfieUploadId': ?selfie,
        'recruiter': ?d.recruiter,
      },
      options: Options(headers: {'Idempotency-Key': d.idempotencyKey}),
    );
    return MyAgency.fromJson(res.data!);
  });

  @override
  Future<MyHostingApplication?> hosting() => guardApiCall(() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/me/hosting-application',
      );
      return MyHostingApplication.fromJson(res.data!);
    } on DioException catch (e) {
      // An older server has no such route: «كن مضيفاً مع الإدارة» is hidden.
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  });

  @override
  Future<MyHostingApplication> applyForHosting(HostingDraft d) =>
      guardApiCall(() async {
        final (idCard, selfie) = await _idPictures(
          d.idCard,
          d.idCardType,
          d.selfie,
          d.selfieType,
        );
        final res = await _dio.post<Map<String, dynamic>>(
          '/me/hosting-application',
          data: {
            'displayName': d.displayName,
            'country': d.country,
            'dateOfBirth': d.dateOfBirthWire,
            'contact': {'type': d.contactType.wire, 'value': d.contactValue},
            'bio': d.bio,
            if (d.links.isNotEmpty) 'links': d.links,
            'acceptRules': true,
            'photoUploadId': ?idCard,
            'selfieUploadId': ?selfie,
            'recruiter': ?d.recruiter,
          },
          options: Options(headers: {'Idempotency-Key': d.idempotencyKey}),
        );
        return MyHostingApplication.fromJson(res.data!);
      });

  @override
  Future<MyHostingApplication> cancelHosting() => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/hosting-application/cancel',
    );
    return MyHostingApplication.fromJson(res.data!);
  });

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
  (ref) => AgencyRepositoryImpl(
    ref.watch(apiDioProvider),
    ref.watch(storageDioProvider),
  ),
);
