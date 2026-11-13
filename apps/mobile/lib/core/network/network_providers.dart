import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/ids/install_source.dart';
import 'package:kabso_live/core/network/auth_tokens.dart';
import 'package:kabso_live/core/network/consent_required.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/network/interceptors.dart';
import 'package:kabso_live/core/network/token_manager.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';

/// Overridden in tests with a fake adapter; `null` means Dio's default.
final httpClientAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

/// `android` or `ios` (the only shipped targets).
String clientPlatform() =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

/// `X-Client: kabso-mobile/<version> (<android|ios>)` (CONVENTIONS.md §1).
String clientIdentifier(String version) =>
    'kabso-mobile/$version (${clientPlatform()})';

/// Builds a Dio instance with the common (non-auth) interceptors.
Dio createBaseDio({
  required AppConfig config,
  required String Function() languageCode,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiV1BaseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      sendTimeout: config.receiveTimeout,
      contentType: Headers.jsonContentType,
      headers: {'Accept': 'application/json'},
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.addAll([
    RequestIdInterceptor(),
    ClientHeadersInterceptor(
      languageCode: languageCode,
      clientId: clientIdentifier(config.appVersion),
    ),
    SafeLoggingInterceptor(),
  ]);
  return dio;
}

/// `POST /auth/refresh` on a Dio without the auth interceptor (no recursion).
/// v1.112-social (int21, §10.143.3): with [installSource] (where the app was
/// installed from) when it is known, so a session signed in before an update
/// gets it; the server keeps the stored one when it is omitted.
RefreshTokensCall refreshCallFor(
  Dio bareDio, {
  InstallSourceReader? installSource,
}) {
  return (refreshToken) async {
    final source = await installSource?.read();
    try {
      final response = await bareDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken, 'installSource': ?source},
        options: publicEndpoint(),
      );
      return AuthTokens.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  };
}

/// Dio for public calls and the refresh call. No auth interceptor.
final bareDioProvider = Provider<Dio>((ref) {
  final dio = createBaseDio(
    config: ref.watch(appConfigProvider),
    languageCode: () => ref.read(languageControllerProvider).name,
    adapter: ref.watch(httpClientAdapterProvider),
  );
  ref.onDispose(dio.close);
  return dio;
});

final tokenManagerProvider = Provider<TokenManager>((ref) {
  final manager = TokenManager(
    store: ref.watch(secureTokenStoreProvider),
    refreshCall: refreshCallFor(
      ref.watch(bareDioProvider),
      installSource: ref.watch(installSourceReaderProvider),
    ),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

/// Dio for every API call: base interceptors + bearer token + single-flight
/// refresh.
final apiDioProvider = Provider<Dio>((ref) {
  final dio = createBaseDio(
    config: ref.watch(appConfigProvider),
    languageCode: () => ref.read(languageControllerProvider).name,
    adapter: ref.watch(httpClientAdapterProvider),
  );
  dio.interceptors.insert(
    2,
    AuthInterceptor(tokens: ref.watch(tokenManagerProvider), dio: dio),
  );
  // D198: a 428 CONSENT_REQUIRED sends the person to the consent screen.
  dio.interceptors.insert(
    3,
    ConsentRequiredInterceptor(
      onConsentRequired: () =>
          ref.read(consentRequiredProvider.notifier).value = true,
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});
