import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/auth_tokens.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/network/interceptors.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/network/token_manager.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';

import '../helpers/contract_fixtures.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

const _me = '/api/v1/me';
const _refresh = '/api/v1/auth/refresh';

void main() {
  late FakeHttpAdapter http;
  late InMemoryTokenStore store;
  late ProviderContainer container;
  late Dio dio;
  late TokenManager tokens;

  Future<void> setUpContainer({String? storedRefreshToken}) async {
    http = FakeHttpAdapter();
    store = InMemoryTokenStore(storedRefreshToken);
    final prefs = await testPrefs(language: 'ar');
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://test', appVersion: '9.9.9'),
        ),
        httpClientAdapterProvider.overrideWithValue(http),
        secureTokenStoreProvider.overrideWithValue(store),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    dio = container.read(apiDioProvider);
    tokens = container.read(tokenManagerProvider);
  }

  /// `/me` answers 200 only for `Bearer <valid>`, 401 otherwise.
  void meRequiresToken(String valid) {
    http.on('GET', _me, (o) {
      if (o.headers['Authorization'] == 'Bearer $valid') {
        return FakeResponse(200, body: meJson());
      }
      return FakeResponse(
        401,
        body: errorEnvelope('AUTH_UNAUTHENTICATED', 'expired'),
      );
    });
  }

  group('request headers', () {
    setUp(setUpContainer);

    test('adds request id, Accept-Language, X-Client and bearer', () async {
      await tokens.saveTokens(
        AuthTokens.fromJson(tokenPairJson(accessToken: 'tok')),
      );
      meRequiresToken('tok');

      await dio.get<Object?>('/me');

      final sent = http.requests.single;
      expect(sent.uri.toString(), 'http://test/api/v1/me');
      expect(sent.headers['Authorization'], 'Bearer tok');
      expect(sent.headers['Accept-Language'], 'ar');
      expect(sent.headers['X-Client'], matches(r'^kabso-mobile/9\.9\.9 \('));
      expect(
        sent.headers['X-Request-Id'],
        matches(
          RegExp(
            '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
            r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });
  });

  group('single-flight refresh', () {
    setUp(() => setUpContainer(storedRefreshToken: 'sid-1.old'));

    test('N concurrent 401s → exactly one refresh, every request retried '
        'once with the new token', () async {
      await tokens.saveTokens(
        AuthTokens.fromJson(
          tokenPairJson(accessToken: 'stale', refreshToken: 'sid-1.old'),
        ),
      );
      meRequiresToken('fresh');
      http.on('POST', _refresh, (o) {
        expect((o.data as Map)['refreshToken'], 'sid-1.old');
        return FakeResponse(
          200,
          body: tokenPairJson(
            accessToken: 'fresh',
            refreshToken: 'sid-1.rotated',
          ),
          delay: const Duration(milliseconds: 30),
        );
      });

      const n = 6;
      final results = await Future.wait(
        List.generate(n, (_) => dio.get<Map<String, dynamic>>('/me')),
      );

      expect(results.map((r) => r.statusCode), everyElement(200));
      expect(http.requestsTo('POST', _refresh), hasLength(1));
      // n failed attempts + n retries.
      final meCalls = http.requestsTo('GET', _me);
      expect(meCalls, hasLength(2 * n));
      expect(
        meCalls.where((r) => r.headers['Authorization'] == 'Bearer fresh'),
        hasLength(n),
      );
      expect(tokens.accessToken, 'fresh');
      expect(store.refreshToken, 'sid-1.rotated');
    });

    test('a 401 arriving after another request refreshed reuses the new '
        'token without refreshing again', () async {
      await tokens.saveTokens(
        AuthTokens.fromJson(
          tokenPairJson(accessToken: 'stale', refreshToken: 'sid-1.old'),
        ),
      );
      var slowServed = false;
      http
        ..on('GET', _me, (o) {
          final auth = o.headers['Authorization'];
          if (auth == 'Bearer fresh') {
            return FakeResponse(200, body: meJson());
          }
          // First stale call answers late, after the refresh completed.
          final delay = slowServed
              ? Duration.zero
              : const Duration(milliseconds: 80);
          slowServed = true;
          return FakeResponse(
            401,
            body: errorEnvelope('AUTH_UNAUTHENTICATED', 'expired'),
            delay: delay,
          );
        })
        ..on(
          'POST',
          _refresh,
          (_) => FakeResponse(200, body: tokenPairJson(accessToken: 'fresh')),
        );

      final slow = dio.get<Object?>('/me');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final fast = dio.get<Object?>('/me');
      await Future.wait([slow, fast]);

      expect(http.requestsTo('POST', _refresh), hasLength(1));
    });

    test(
      'a retried request that is still 401 is not refreshed again',
      () async {
        await tokens.saveTokens(
          AuthTokens.fromJson(
            tokenPairJson(accessToken: 'stale', refreshToken: 'sid-1.old'),
          ),
        );
        meRequiresToken('never-valid');
        http.on(
          'POST',
          _refresh,
          (_) => FakeResponse(200, body: tokenPairJson(accessToken: 'fresh')),
        );

        try {
          await dio.get<Object?>('/me');
          fail('expected 401');
        } on DioException catch (e) {
          expect(mapDioException(e).code, ErrorCode.authUnauthenticated);
        }
        expect(http.requestsTo('POST', _refresh), hasLength(1));
        expect(http.requestsTo('GET', _me), hasLength(2));
      },
    );

    for (final code in ['AUTH_REFRESH_INVALID', 'ACCOUNT_SUSPENDED']) {
      test('refresh failing with $code clears the session for every waiting '
          'request', () async {
        await tokens.saveTokens(
          AuthTokens.fromJson(
            tokenPairJson(accessToken: 'stale', refreshToken: 'sid-1.old'),
          ),
        );
        final invalidations = <ErrorCode>[];
        final sub = tokens.invalidations.listen(invalidations.add);
        addTearDown(sub.cancel);
        meRequiresToken('fresh');
        http.on(
          'POST',
          _refresh,
          (_) => FakeResponse(
            code == 'ACCOUNT_SUSPENDED' ? 403 : 401,
            body: errorEnvelope(code, 'nope'),
            delay: const Duration(milliseconds: 20),
          ),
        );

        final outcomes = await Future.wait(
          List.generate(
            4,
            (_) => dio
                .get<Object?>('/me')
                .then<AppFailure?>((_) => null)
                .catchError((Object e) => mapDioException(e as DioException)),
          ),
        );

        expect(outcomes.map((f) => f?.code.wire), everyElement(code));
        expect(http.requestsTo('POST', _refresh), hasLength(1));
        expect(tokens.accessToken, isNull);
        expect(store.refreshToken, isNull);
        await Future<void>.delayed(Duration.zero);
        expect(invalidations, [ErrorCode.fromWire(code)]);
      });
    }

    test('a network error during refresh keeps the stored session', () async {
      await tokens.saveTokens(
        AuthTokens.fromJson(
          tokenPairJson(accessToken: 'stale', refreshToken: 'sid-1.old'),
        ),
      );
      meRequiresToken('fresh');
      http.on(
        'POST',
        _refresh,
        (_) => throw DioException.connectionError(
          requestOptions: RequestOptions(),
          reason: 'offline',
        ),
      );

      try {
        await dio.get<Object?>('/me');
        fail('expected failure');
      } on DioException catch (e) {
        expect(mapDioException(e).code, ErrorCode.networkOffline);
      }
      expect(store.refreshToken, 'sid-1.old');
    });

    test('public endpoints never trigger a refresh', () async {
      http.on(
        'POST',
        '/api/v1/auth/login',
        (_) => FakeResponse(
          401,
          body: errorEnvelope('AUTH_INVALID_CREDENTIALS', 'bad'),
        ),
      );
      try {
        await dio.post<Object?>(
          '/auth/login',
          data: {'identifier': 'x'},
          options: publicEndpoint(),
        );
        fail('expected 401');
      } on DioException catch (e) {
        expect(mapDioException(e).code, ErrorCode.authInvalidCredentials);
      }
      expect(http.requestsTo('POST', _refresh), isEmpty);
    });
  });
}
