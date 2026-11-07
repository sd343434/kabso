import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/features/staff/domain/staff_report_view.dart';

/// v1.68-live (D273, CONVENTIONS §10.96.6): «أدوات فريق كابسو» — the staff
/// member's own app account doing the panel's live moderation (tag `staff`).
/// The server checks the role and the capability on every request; D286
/// (v1.76-live): no authenticator code any more (the deprecated step-up is not
/// used), and staff work switches the shift on (§10.96.14). Throws an
/// `AppFailure`.
abstract interface class StaffRepository {
  /// `GET /staff/me` (any signed-in account; `isStaff` false otherwise).
  Future<StaffStatus> status();

  /// `PUT /staff/shift`; returns the shift now.
  Future<bool> setShift({required bool onShift});

  /// `GET /staff/lives`: «بثوثي».
  Future<List<StaffLive>> myLives();

  /// `GET /staff/lives/{roomId}/reports`.
  Future<List<StaffReport>> reports(String roomId);

  /// `POST /staff/lives/{roomId}/moderate` (a reason the host is told).
  Future<void> moderate(
    String roomId,
    StaffLiveAction action, {
    required String reason,
    int? hours,
  });

  /// `POST /staff/lives/{roomId}/reports/dismiss`.
  Future<void> dismissReports(String roomId, {required String reason});

  /// `POST /staff/lives/{roomId}/kicks`.
  Future<void> kick(
    String roomId, {
    required String username,
    required String reason,
  });

  /// `PUT /staff/lives/{roomId}/chat-mutes`.
  Future<void> mute(
    String roomId, {
    required String username,
    required String reason,
  });

  /// `POST /staff/lives/{roomId}/chat/{messageId}/remove`.
  Future<void> removeMessage(
    String roomId,
    String messageId, {
    required String reason,
  });

  /// v1.78-live (D288): `GET /staff/reports` — «بلاغات», the shared queue.
  Future<SharedReportPage> sharedReports(SharedReportTab tab, {String? cursor});

  /// D288: `GET /staff/reports/summary` — the unresolved count.
  Future<int> openReportsCount();

  /// D288: `POST /staff/reports/{reportId}/resolve` «تم حله» (a second press
  /// throws the `REPORT_ALREADY_RESOLVED` failure).
  Future<SharedReport> resolveReport(String reportId, {String? note});

  /// v1.93-social (D296): `GET /staff/reports/{reportId}` — the reported
  /// content for the staff (a DM only as its snapshot) and the allowed
  /// actions.
  Future<StaffReportView> report(String reportId);

  /// D296: `POST /staff/reports/{reportId}/actions` — the action resolves the
  /// report (a closed one throws `REPORT_ALREADY_RESOLVED`).
  Future<SharedReport> actOnReport(
    String reportId,
    StaffReportAction action, {
    required String reason,
    StaffRestriction? restriction,
    int? days,
  });
}

class StaffRepositoryImpl implements StaffRepository {
  new(this._dio);

  final Dio _dio;

  String _live(String roomId) => '/staff/lives/${pathSegment(roomId)}';

  @override
  Future<StaffStatus> status() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/staff/me');
    return StaffStatus.fromJson(res.data!);
  });

  @override
  Future<bool> setShift({required bool onShift}) => guardApiCall(() async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/staff/shift',
      data: {'onShift': onShift},
    );
    return res.data!['onShift'] as bool? ?? onShift;
  });

  @override
  Future<List<StaffLive>> myLives() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/staff/lives');
    return [
      for (final l in res.data!['data']! as List<dynamic>)
        StaffLive.fromJson(l as Map<String, dynamic>),
    ];
  });

  @override
  Future<List<StaffReport>> reports(String roomId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '${_live(roomId)}/reports',
    );
    return [
      for (final r in res.data!['data']! as List<dynamic>)
        StaffReport.fromJson(r as Map<String, dynamic>),
    ];
  });

  @override
  Future<void> moderate(
    String roomId,
    StaffLiveAction action, {
    required String reason,
    int? hours,
  }) => guardApiCall(
    () => _dio.post<void>(
      '${_live(roomId)}/moderate',
      data: {'action': action.wire, 'reason': reason, 'hours': ?hours},
    ),
  );

  @override
  Future<void> dismissReports(String roomId, {required String reason}) =>
      guardApiCall(
        () => _dio.post<void>(
          '${_live(roomId)}/reports/dismiss',
          data: {'reason': reason},
        ),
      );

  @override
  Future<void> kick(
    String roomId, {
    required String username,
    required String reason,
  }) => guardApiCall(
    () => _dio.post<void>(
      '${_live(roomId)}/kicks',
      data: {'username': username, 'reason': reason},
    ),
  );

  @override
  Future<void> mute(
    String roomId, {
    required String username,
    required String reason,
  }) => guardApiCall(
    () => _dio.put<void>(
      '${_live(roomId)}/chat-mutes',
      data: {'username': username, 'reason': reason, 'muted': true},
    ),
  );

  @override
  Future<SharedReportPage> sharedReports(
    SharedReportTab tab, {
    String? cursor,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/staff/reports',
      queryParameters: {'status': tab.wire, 'cursor': ?cursor},
    );
    final page = res.data!['page'] as Map<String, dynamic>? ?? const {};
    return SharedReportPage(
      items: [
        for (final r in res.data!['data']! as List<dynamic>)
          SharedReport.fromJson(r as Map<String, dynamic>),
      ],
      nextCursor: page['nextCursor'] as String?,
    );
  });

  @override
  Future<int> openReportsCount() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/staff/reports/summary');
    return (res.data!['open'] as num?)?.toInt() ?? 0;
  });

  @override
  Future<StaffReportView> report(String reportId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/staff/reports/${pathSegment(reportId)}',
    );
    return StaffReportView.fromJson(res.data!);
  });

  @override
  Future<SharedReport> actOnReport(
    String reportId,
    StaffReportAction action, {
    required String reason,
    StaffRestriction? restriction,
    int? days,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/staff/reports/${pathSegment(reportId)}/actions',
      data: {
        'action': action.wire,
        'reason': reason.trim(),
        'restriction': ?restriction?.wire,
        'days': ?days,
        // The two permanent deletions: the staff member typed the word.
        if (action.permanent) 'confirm': StaffReportAction.confirmWire,
      },
    );
    return SharedReport.fromJson(res.data!['report']! as Map<String, dynamic>);
  });

  @override
  Future<SharedReport> resolveReport(String reportId, {String? note}) =>
      guardApiCall(() async {
        final trimmed = note?.trim();
        final res = await _dio.post<Map<String, dynamic>>(
          '/staff/reports/${pathSegment(reportId)}/resolve',
          data: {if (trimmed != null && trimmed.isNotEmpty) 'note': trimmed},
        );
        return SharedReport.fromJson(res.data!);
      });

  @override
  Future<void> removeMessage(
    String roomId,
    String messageId, {
    required String reason,
  }) => guardApiCall(
    () => _dio.post<void>(
      '${_live(roomId)}/chat/${pathSegment(messageId)}/remove',
      data: {'reason': reason},
    ),
  );
}

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepositoryImpl(ref.watch(apiDioProvider)),
);
