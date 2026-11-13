import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/wallet/data/cherry_repository.dart';

/// v1.75-live (D285, CONVENTIONS §10.96.13): recruitment by staff «الاستقطاب»
/// — the forms' live check of the recruiter field, the recruiter's own
/// «استقطاباتي» / «أرباحي», and the creator programme «انضم كصانع محتوى».
/// Throws an `AppFailure`.
abstract interface class RecruitsRepository {
  /// `GET /staff-recruiters/lookup?q=`: null when nobody can recruit by
  /// that ID / username («غير موجود»).
  Future<StaffRecruiter?> lookup(String q);

  /// `GET /me/staff/recruits` (MODERATION / BD).
  Future<StaffRecruitList> myRecruits();

  /// `GET /me/staff/earnings` (MODERATION / BD).
  Future<StaffEarnings> myEarnings();

  /// `GET /me/creator-application`.
  Future<MyCreatorApplication> creatorApplication();

  /// `POST /me/creator-application`.
  Future<MyCreatorApplication> applyCreator(CreatorApplicationDraft draft);

  /// `POST /me/creator-application/cancel`.
  Future<MyCreatorApplication> cancelCreator();
}

/// What the recruit became.
enum RecruitType {
  host('HOST'),
  agency('AGENCY'),
  rechargeAgent('RECHARGE_AGENT'),
  creator('CREATOR');

  new(this.wire);

  final String wire;

  static RecruitType fromWire(Object? v) =>
      values.firstWhere((t) => t.wire == v, orElse: () => RecruitType.host);
}

/// `StaffRecruiterLookup.recruiter`: who the field names.
final class StaffRecruiter {
  const new({
    required this.staffId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bd,
  });

  factory fromJson(Map<String, dynamic> j) => StaffRecruiter(
    staffId: j['staffId'] as String?,
    username: j['username'] as String? ?? '',
    displayName: j['displayName'] as String? ?? '',
    avatarUrl: j['avatarUrl'] as String?,
    bd: j['role'] == 'BD',
  );

  final String? staffId;
  final String username;
  final String displayName;
  final String? avatarUrl;

  /// BD «تطوير الأعمال»; else MODERATION «مشرف».
  final bool bd;
}

/// `StaffRecruit`.
final class StaffRecruit {
  const new({
    required this.id,
    required this.type,
    required this.recruit,
    required this.active,
    required this.activatedAt,
    required this.profitUsd,
    required this.commissionCherries,
  });

  factory fromJson(Map<String, dynamic> j) => StaffRecruit(
    id: j['id'] as String,
    type: RecruitType.fromWire(j['type']),
    recruit: UserSummary.fromJson(j['recruit'] as Map<String, dynamic>),
    active: j['status'] == 'ACTIVE',
    activatedAt: DateTime.parse(j['activatedAt'] as String),
    profitUsd: (j['profitUsd'] as num? ?? 0).toDouble(),
    commissionCherries: (j['commissionCherries'] as num? ?? 0).toInt(),
  );

  final String id;
  final RecruitType type;
  final UserSummary recruit;
  final bool active;
  final DateTime activatedAt;
  final double profitUsd;
  final int commissionCherries;
}

/// `StaffRecruitList`.
final class StaffRecruitList {
  const new({
    required this.counts,
    required this.recruits,
    this.signupCode,
    this.signupLink,
    this.signupsGranted = 0,
    this.signupsWithheld = 0,
  });

  factory fromJson(Map<String, dynamic> j) {
    final c = j['counts'] as Map<String, dynamic>? ?? const {};
    final s = j['signups'] as Map<String, dynamic>? ?? const {};
    return StaffRecruitList(
      counts: {
        for (final t in RecruitType.values) t: (c[t.wire] as num? ?? 0).toInt(),
      },
      recruits: [
        for (final r in j['data'] as List<dynamic>? ?? const [])
          StaffRecruit.fromJson(r as Map<String, dynamic>),
      ],
      signupCode: j['signupCode'] as String?,
      signupLink: j['signupLink'] as String?,
      signupsGranted: (s['granted'] as num? ?? 0).toInt(),
      signupsWithheld: (s['withheld'] as num? ?? 0).toInt(),
    );
  }

  final Map<RecruitType, int> counts;
  final List<StaffRecruit> recruits;

  /// v1.108-social (D343, §10.142): the staff ID a new person types in
  /// «رمز الدعوة أو رمز المشرف», and the personal link
  /// `https://kabsolive.com/i/<staffId>` (null: none).
  final String? signupCode;
  final String? signupLink;

  /// D343: accounts created with that code — counted, or withheld (the
  /// person already had an account on the phone or the email before).
  final int signupsGranted;
  final int signupsWithheld;

  int get total => counts.values.fold(0, (a, b) => a + b);
}

/// One day credited to the caller (`StaffEarnings.history`).
final class StaffEarningDay {
  const new({
    required this.day,
    required this.type,
    required this.recruit,
    required this.profitUsd,
    required this.bps,
    required this.cherries,
  });

  factory fromJson(Map<String, dynamic> j) => StaffEarningDay(
    day: j['day'] as String,
    type: RecruitType.fromWire(j['type']),
    recruit: UserSummary.fromJson(j['recruit'] as Map<String, dynamic>),
    profitUsd: (j['profitUsd'] as num? ?? 0).toDouble(),
    bps: (j['bps'] as num? ?? 0).toInt(),
    cherries: (j['cherries'] as num? ?? 0).toInt(),
  );

  final String day;
  final RecruitType type;
  final UserSummary recruit;
  final double profitUsd;
  final int bps;
  final int cherries;
}

/// `StaffEarnings` «أرباحي».
final class StaffEarnings {
  const new({
    required this.wallet,
    required this.totalCherries,
    required this.last30DaysCherries,
    required this.bps,
    required this.byRecruit,
    required this.history,
  });

  factory fromJson(Map<String, dynamic> j) {
    final b = j['bps'] as Map<String, dynamic>? ?? const {};
    return StaffEarnings(
      wallet: CherryWallet.fromJson(j['wallet'] as Map<String, dynamic>),
      totalCherries: (j['totalCherries'] as num? ?? 0).toInt(),
      last30DaysCherries: (j['last30DaysCherries'] as num? ?? 0).toInt(),
      bps: {
        for (final t in RecruitType.values) t: (b[t.wire] as num? ?? 0).toInt(),
      },
      byRecruit: [
        for (final r in j['byRecruit'] as List<dynamic>? ?? const [])
          (
            type: RecruitType.fromWire((r as Map<String, dynamic>)['type']),
            recruit: UserSummary.fromJson(r['recruit'] as Map<String, dynamic>),
            cherries: (r['cherries'] as num? ?? 0).toInt(),
          ),
      ],
      history: [
        for (final d in j['history'] as List<dynamic>? ?? const [])
          StaffEarningDay.fromJson(d as Map<String, dynamic>),
      ],
    );
  }

  final CherryWallet wallet;
  final int totalCherries;
  final int last30DaysCherries;
  final Map<RecruitType, int> bps;
  final List<({RecruitType type, UserSummary recruit, int cherries})> byRecruit;
  final List<StaffEarningDay> history;
}

/// The creator programme's content kinds.
enum CreatorCategory {
  video('VIDEO'),
  photo('PHOTO'),
  music('MUSIC'),
  gaming('GAMING'),
  comedy('COMEDY'),
  education('EDUCATION'),
  lifestyle('LIFESTYLE'),
  other('OTHER');

  new(this.wire);

  final String wire;
}

/// `CreatorApplicationRequest`.
final class CreatorApplicationDraft {
  const new({
    required this.country,
    required this.category,
    required this.links,
    this.bio,
    this.recruiter,
  });

  final String country;
  final CreatorCategory category;
  final List<String> links;
  final String? bio;
  final String? recruiter;
}

/// `MyCreatorApplication` (only what the app shows).
final class MyCreatorApplication {
  const new({
    required this.member,
    required this.status,
    required this.rejectReason,
    required this.canApply,
    required this.refusal,
  });

  factory fromJson(Map<String, dynamic> j) {
    final app = j['application'] as Map<String, dynamic>?;
    final rule = j['rule'] as Map<String, dynamic>? ?? const {};
    return MyCreatorApplication(
      member: j['member'] != null,
      status: app?['status'] as String?,
      rejectReason: app?['rejectReason'] as String?,
      canApply: rule['canApply'] == true,
      refusal: rule['refusal'] as String?,
    );
  }

  final bool member;

  /// PENDING, APPROVED, REJECTED, CANCELLED; null: never applied.
  final String? status;
  final String? rejectReason;
  final bool canApply;
  final String? refusal;
}

class RecruitsRepositoryImpl implements RecruitsRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<StaffRecruiter?> lookup(String q) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/staff-recruiters/lookup',
      queryParameters: {'q': q},
    );
    final r = res.data?['recruiter'] as Map<String, dynamic>?;
    return r == null ? null : StaffRecruiter.fromJson(r);
  });

  @override
  Future<StaffRecruitList> myRecruits() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/staff/recruits');
    return StaffRecruitList.fromJson(res.data!);
  });

  @override
  Future<StaffEarnings> myEarnings() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/staff/earnings');
    return StaffEarnings.fromJson(res.data!);
  });

  @override
  Future<MyCreatorApplication> creatorApplication() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/creator-application');
    return MyCreatorApplication.fromJson(res.data!);
  });

  @override
  Future<MyCreatorApplication> applyCreator(CreatorApplicationDraft d) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/me/creator-application',
          data: {
            'country': d.country,
            'category': d.category.wire,
            'links': d.links,
            if (d.bio case final bio? when bio.isNotEmpty) 'bio': bio,
            'recruiter': ?d.recruiter,
          },
        );
        return MyCreatorApplication.fromJson(res.data!);
      });

  @override
  Future<MyCreatorApplication> cancelCreator() => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/creator-application/cancel',
    );
    return MyCreatorApplication.fromJson(res.data!);
  });
}

final recruitsRepositoryProvider = Provider<RecruitsRepository>(
  (ref) => RecruitsRepositoryImpl(ref.watch(apiDioProvider)),
);

final FutureProvider<StaffRecruitList> myStaffRecruitsProvider =
    FutureProvider.autoDispose<StaffRecruitList>(
      (ref) => ref.watch(recruitsRepositoryProvider).myRecruits(),
    );

final FutureProvider<StaffEarnings> myStaffEarningsProvider =
    FutureProvider.autoDispose<StaffEarnings>(
      (ref) => ref.watch(recruitsRepositoryProvider).myEarnings(),
    );

final FutureProvider<MyCreatorApplication> myCreatorApplicationProvider =
    FutureProvider.autoDispose<MyCreatorApplication>(
      (ref) => ref.watch(recruitsRepositoryProvider).creatorApplication(),
    );
