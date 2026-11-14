import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

/// In-app notifications (docs/contracts/openapi.yaml v1.5-social DRAFT, tag
/// `notifications`, CP-009, CONVENTIONS §11.10).
///
/// Every method throws an `AppFailure`.
abstract interface class NotificationsRepository {
  /// `GET /notifications`: newest activity first.
  Future<PageOf<AppNotification>> list({String? cursor});

  /// `GET /notifications/unread-count` (at most 99).
  Future<int> unreadCount();

  /// `POST /notifications/read` with these [ids] (1–100), or every one
  /// when [ids] is `null`. Idempotent.
  Future<void> markRead({List<String>? ids});

  /// `GET /me/notification-settings`.
  Future<NotificationSettings> settings();

  /// `PATCH /me/notification-settings` with one switch.
  Future<NotificationSettings> updateSetting(
    NotificationSetting setting, {
    required bool on,
  });
}

class NotificationsRepositoryImpl implements NotificationsRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<PageOf<AppNotification>> list({String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/notifications',
          queryParameters: {'cursor': ?cursor},
        );
        final body = res.data!;
        return PageOf([
          for (final e in body['data']! as List<dynamic>)
            AppNotification.fromJson(e as Map<String, dynamic>),
        ], PageInfo.fromJson(body['page']! as Map<String, dynamic>));
      });

  @override
  Future<int> unreadCount() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/notifications/unread-count',
    );
    return res.data!['count']! as int;
  });

  @override
  Future<void> markRead({List<String>? ids}) => guardApiCall(() async {
    await _dio.post<void>(
      '/notifications/read',
      data: ids == null ? {'all': true} : {'ids': ids},
    );
  });

  @override
  Future<NotificationSettings> settings() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/me/notification-settings',
    );
    return NotificationSettings.fromJson(res.data!);
  });

  @override
  Future<NotificationSettings> updateSetting(
    NotificationSetting setting, {
    required bool on,
  }) => guardApiCall(() async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/me/notification-settings',
      data: {setting.name: on},
    );
    return NotificationSettings.fromJson(res.data!);
  });
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepositoryImpl(ref.watch(apiDioProvider)),
);
