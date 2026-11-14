import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// v1.89-social (D290, CONVENTIONS §10.103): «طلب رفع ليفيل» in the staff Me
/// tab (MODERATION / SUPPORT): the source apps, the live check of a
/// supporter, the staff member's own requests and sending one. The video is
/// uploaded first with `MediaRepository.uploadVideo(kind:
/// 'LEVEL_RAISE_VIDEO')`. Throws an `AppFailure`.
abstract interface class LevelRaiseRepository {
  /// `GET /staff/level-raises/source-apps`.
  Future<List<LevelRaiseSourceApp>> sourceApps();

  /// `GET /staff/level-raises/source-apps/suggest?q=`: «هل تقصد: …؟» for a
  /// typed "other" app name (listed apps by any spelling, earlier names).
  Future<List<LevelRaiseSuggestion>> suggest(String q);

  /// `GET /staff/level-raises/check?username=`.
  Future<LevelRaiseCheck> check(String username);

  /// `GET /staff/level-raises` (newest first).
  Future<List<LevelRaiseRequest>> mine();

  /// `POST /staff/level-raises`.
  Future<LevelRaiseRequest> create(LevelRaiseDraft draft);
}

/// `LevelRaiseConfidence`: only the owner or a cited source makes a figure
/// CONFIRMED; everything else is an estimate (shown as such).
enum LevelRaiseConfidence {
  confirmed('CONFIRMED'),
  estimate('ESTIMATE');

  new(this.wire);

  final String wire;

  static LevelRaiseConfidence fromWire(Object? v) =>
      v == 'CONFIRMED' ? confirmed : estimate;
}

/// `LevelRaiseStatus`.
enum LevelRaiseStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED');

  new(this.wire);

  final String wire;

  static LevelRaiseStatus fromWire(Object? v) =>
      values.firstWhere((s) => s.wire == v, orElse: () => pending);
}

/// `LevelRaiseSourceAppOption`.
@immutable
final class LevelRaiseSourceApp {
  const new({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.confidence,
    required this.isOther,
  });

  factory fromJson(Map<String, dynamic> j) => LevelRaiseSourceApp(
    code: j['code'] as String? ?? '',
    nameAr: j['nameAr'] as String? ?? '',
    nameEn: j['nameEn'] as String? ?? '',
    confidence: LevelRaiseConfidence.fromWire(j['confidence']),
    isOther: j['isOther'] as bool? ?? false,
  );

  final String code;
  final String nameAr;
  final String nameEn;
  final LevelRaiseConfidence confidence;

  /// The default for an app not in the list (its name is typed).
  final bool isOther;

  String name({required bool ar}) => ar ? nameAr : nameEn;
}

/// `LevelRaiseSuggestion`: a listed app ([app]) or a name typed for "other"
/// apps in earlier requests ([name], its first spelling).
@immutable
final class LevelRaiseSuggestion {
  const new({this.app, this.name});

  factory fromJson(Map<String, dynamic> j) => LevelRaiseSuggestion(
    app: switch (j['app']) {
      final Map<String, dynamic> m => LevelRaiseSourceApp.fromJson(m),
      _ => null,
    },
    name: j['name'] as String?,
  );

  final LevelRaiseSourceApp? app;
  final String? name;

  String label({required bool ar}) => app?.name(ar: ar) ?? name ?? '';
}

/// `LevelRaisePerson`.
@immutable
final class LevelRaisePerson {
  const new({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  factory fromJson(Map<String, dynamic> j) => LevelRaisePerson(
    id: j['id'] as String? ?? '',
    username: j['username'] as String? ?? '',
    displayName: j['displayName'] as String? ?? '',
    avatarUrl: j['avatarUrl'] as String?,
  );

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
}

/// `LevelRaiseEvidence`: the supporter's recharge and levels.
@immutable
final class LevelRaiseEvidence {
  const new({
    required this.totalRechargeCoins,
    required this.firstDaysRechargeCoins,
    required this.firstDays,
    required this.supportLevel,
    required this.charmLevel,
    required this.minRechargeCoins,
    required this.eligible,
  });

  factory fromJson(Map<String, dynamic> j) => LevelRaiseEvidence(
    totalRechargeCoins: (j['totalRechargeCoins'] as num?)?.toInt() ?? 0,
    firstDaysRechargeCoins: (j['firstDaysRechargeCoins'] as num?)?.toInt() ?? 0,
    firstDays: (j['firstDays'] as num?)?.toInt() ?? 7,
    supportLevel: (j['supportLevel'] as num?)?.toInt() ?? 0,
    charmLevel: (j['charmLevel'] as num?)?.toInt() ?? 0,
    minRechargeCoins: (j['minRechargeCoins'] as num?)?.toInt() ?? 1000000,
    eligible: j['eligible'] as bool? ?? false,
  );

  final int totalRechargeCoins;
  final int firstDaysRechargeCoins;
  final int firstDays;
  final int supportLevel;
  final int charmLevel;
  final int minRechargeCoins;
  final bool eligible;
}

/// `LevelRaiseCheck`.
@immutable
final class LevelRaiseCheck {
  const new({
    required this.found,
    required this.supporter,
    required this.evidence,
    required this.openRequest,
    required this.staffAccount,
  });

  factory fromJson(Map<String, dynamic> j) => LevelRaiseCheck(
    found: j['found'] as bool? ?? false,
    supporter: switch (j['supporter']) {
      final Map<String, dynamic> m => LevelRaisePerson.fromJson(m),
      _ => null,
    },
    evidence: switch (j['evidence']) {
      final Map<String, dynamic> m => LevelRaiseEvidence.fromJson(m),
      _ => null,
    },
    openRequest: j['openRequest'] as bool? ?? false,
    staffAccount: j['staffAccount'] as bool? ?? false,
  );

  final bool found;
  final LevelRaisePerson? supporter;
  final LevelRaiseEvidence? evidence;
  final bool openRequest;
  final bool staffAccount;

  /// Whether a request can be sent for this person.
  bool get usable => found && !openRequest && !staffAccount;
}

/// `LevelRaiseRequest` (the fields the staff member's list shows).
@immutable
final class LevelRaiseRequest {
  const new({
    required this.id,
    required this.status,
    required this.supporter,
    required this.sourceApp,
    required this.sourceAppName,
    required this.sourceAccountId,
    required this.sourceLevel,
    required this.createdAt,
    this.note,
    this.decidedAt,
    this.rejectReason,
    this.approvedLevel,
    this.levelBefore,
    this.levelAfter,
    this.videoDeletedAt,
    this.previouslyRejected = false,
  });

  factory fromJson(Map<String, dynamic> j) => LevelRaiseRequest(
    id: j['id'] as String? ?? '',
    status: LevelRaiseStatus.fromWire(j['status']),
    supporter: LevelRaisePerson.fromJson(
      j['supporter'] as Map<String, dynamic>? ?? const {},
    ),
    sourceApp: switch (j['sourceApp']) {
      final Map<String, dynamic> m => LevelRaiseSourceApp.fromJson(m),
      _ => null,
    },
    sourceAppName: j['sourceAppName'] as String? ?? '',
    sourceAccountId: j['sourceAccountId'] as String? ?? '',
    sourceLevel: (j['sourceLevel'] as num?)?.toInt() ?? 0,
    note: j['note'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String),
    decidedAt: switch (j['decidedAt']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    rejectReason: j['rejectReason'] as String?,
    approvedLevel: (j['approvedLevel'] as num?)?.toInt(),
    levelBefore: (j['levelBefore'] as num?)?.toInt(),
    levelAfter: (j['levelAfter'] as num?)?.toInt(),
    videoDeletedAt: switch ((j['video']
        as Map<String, dynamic>?)?['deletedAt']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    previouslyRejected: j['previousRejection'] != null,
  );

  final String id;
  final LevelRaiseStatus status;
  final LevelRaisePerson supporter;
  final LevelRaiseSourceApp? sourceApp;
  final String sourceAppName;
  final String sourceAccountId;
  final int sourceLevel;
  final String? note;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? rejectReason;
  final int? approvedLevel;
  final int? levelBefore;
  final int? levelAfter;

  /// D290: the video is deleted after the decision.
  final DateTime? videoDeletedAt;

  /// «سبق رفض طلب بنفس الحساب»: the same source account was rejected before.
  final bool previouslyRejected;

  /// The app's name in the app's language (the typed name for "other").
  String appName({required bool ar}) => switch (sourceApp) {
    final a? when !a.isOther => a.name(ar: ar),
    _ => sourceAppName,
  };
}

/// What the form sends (`CreateLevelRaiseRequest`).
@immutable
final class LevelRaiseDraft {
  const new({
    required this.username,
    required this.sourceApp,
    required this.sourceAccountId,
    required this.sourceLevel,
    required this.videoId,
    this.sourceAppName,
    this.note,
  });

  final String username;
  final String sourceApp;
  final String? sourceAppName;
  final String sourceAccountId;
  final int sourceLevel;
  final String videoId;
  final String? note;

  Map<String, Object> toJson() => {
    'username': username,
    'sourceApp': sourceApp,
    'sourceAppName': ?sourceAppName,
    'sourceAccountId': sourceAccountId,
    'sourceLevel': sourceLevel,
    'videoId': videoId,
    if (note case final n? when n.isNotEmpty) 'note': n,
  };
}

class LevelRaiseRepositoryImpl implements LevelRaiseRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<List<LevelRaiseSourceApp>> sourceApps() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/staff/level-raises/source-apps',
    );
    return [
      for (final a in (res.data?['data'] as List<dynamic>? ?? const []))
        LevelRaiseSourceApp.fromJson(a as Map<String, dynamic>),
    ];
  });

  @override
  Future<List<LevelRaiseSuggestion>> suggest(String q) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/staff/level-raises/source-apps/suggest',
          queryParameters: {'q': q},
        );
        return [
          for (final s in (res.data?['data'] as List<dynamic>? ?? const []))
            LevelRaiseSuggestion.fromJson(s as Map<String, dynamic>),
        ];
      });

  @override
  Future<LevelRaiseCheck> check(String username) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/staff/level-raises/check',
      queryParameters: {'username': username},
    );
    return LevelRaiseCheck.fromJson(res.data!);
  });

  @override
  Future<List<LevelRaiseRequest>> mine() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/staff/level-raises');
    return [
      for (final r in (res.data?['data'] as List<dynamic>? ?? const []))
        LevelRaiseRequest.fromJson(r as Map<String, dynamic>),
    ];
  });

  @override
  Future<LevelRaiseRequest> create(LevelRaiseDraft draft) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/staff/level-raises',
          data: draft.toJson(),
        );
        return LevelRaiseRequest.fromJson(res.data!);
      });
}

final levelRaiseRepositoryProvider = Provider<LevelRaiseRepository>(
  (ref) => LevelRaiseRepositoryImpl(ref.watch(apiDioProvider)),
);

final FutureProvider<List<LevelRaiseRequest>> myLevelRaisesProvider =
    FutureProvider.autoDispose<List<LevelRaiseRequest>>(
      (ref) => ref.watch(levelRaiseRepositoryProvider).mine(),
    );

final FutureProvider<List<LevelRaiseSourceApp>> levelRaiseSourceAppsProvider =
    FutureProvider.autoDispose<List<LevelRaiseSourceApp>>(
      (ref) => ref.watch(levelRaiseRepositoryProvider).sourceApps(),
    );
