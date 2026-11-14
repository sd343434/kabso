import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// The device's push token on the server (openapi v1.30-live DRAFT, D152,
/// CONVENTIONS §11.12): one token per signed-in session.
///
/// Every method throws an `AppFailure`.
abstract interface class PushTokensRepository {
  /// `PUT /me/push-token`.
  Future<void> register({
    required String token,
    required String platform,
    required String appVersion,
  });

  /// `DELETE /me/push-token`.
  Future<void> unregister();
}

class PushTokensRepositoryImpl implements PushTokensRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<void> register({
    required String token,
    required String platform,
    required String appVersion,
  }) => guardApiCall(() async {
    await _dio.put<void>(
      '/me/push-token',
      data: {'token': token, 'platform': platform, 'appVersion': appVersion},
    );
  });

  @override
  Future<void> unregister() => guardApiCall(() async {
    await _dio.delete<void>('/me/push-token');
  });
}

final pushTokensRepositoryProvider = Provider<PushTokensRepository>(
  (ref) => PushTokensRepositoryImpl(ref.watch(apiDioProvider)),
);

/// D152: whether this phone's token is registered for the signed-in session
/// (set by the push controller). The session's logout reads it without
/// depending on the controller (which listens to the session).
class PushTokenRegistered extends Notifier<bool> {
  @override
  bool build() => false;

  bool get registered => state;

  set registered(bool on) => state = on;
}

final pushTokenRegisteredProvider = NotifierProvider<PushTokenRegistered, bool>(
  PushTokenRegistered.new,
);

/// D152: before signing out — `DELETE /me/push-token` when this phone
/// registered one, so no more pushes reach it for that account (the
/// logout also removes it on the server). Best effort, at most 3 s.
Future<void> unregisterPushToken(Ref ref) async {
  if (!ref.read(pushTokenRegisteredProvider)) return;
  ref.read(pushTokenRegisteredProvider.notifier).registered = false;
  try {
    await ref
        .read(pushTokensRepositoryProvider)
        .unregister()
        .timeout(const Duration(seconds: 3));
  } on Object {
    // The logout itself removes it on the server.
  }
}
