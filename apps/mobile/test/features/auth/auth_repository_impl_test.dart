import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/auth_repository.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';

import '../../helpers/contract_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _base = '/api/v1';

void main() {
  late FakeHttpAdapter http;
  late InMemoryTokenStore store;
  late ProviderContainer container;
  late AuthRepository repo;

  Future<void> build({String? storedRefreshToken}) async {
    http = FakeHttpAdapter();
    store = InMemoryTokenStore(storedRefreshToken);
    final prefs = await testPrefs();
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://test', appVersion: '1.2.3'),
        ),
        httpClientAdapterProvider.overrideWithValue(http),
        secureTokenStoreProvider.overrideWithValue(store),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    repo = container.read(authRepositoryProvider);
  }

  setUp(build);

  group('login', () {
    test(
      'posts LoginRequest, stores the refresh token, returns the user',
      () async {
        http.on(
          'POST',
          '$_base/auth/login',
          (_) => FakeResponse(
            200,
            body: authResponseJson(
              user: meJson(emailVerified: true, role: 'ADMIN'),
              tokens: tokenPairJson(
                accessToken: 'acc',
                refreshToken: 'sid.secret',
              ),
            ),
          ),
        );

        final user = await repo.login(
          identifier: '  layla.k ',
          password: 'pa55word!',
        );

        final req = http.requestsTo('POST', '$_base/auth/login').single;
        expect(req.data, {
          'identifier': 'layla.k',
          'password': 'pa55word!',
          'device': {'platform': 'android', 'appVersion': '1.2.3'},
        });
        expect(req.headers.containsKey('Authorization'), isFalse);
        expect(user.username, 'layla.k');
        expect(user.emailVerified, isTrue);
        expect(user.role, UserRole.admin);
        expect(user.createdAt, DateTime.utc(2026, 10, 15, 13));
        expect(store.refreshToken, 'sid.secret');
        expect(container.read(tokenManagerProvider).accessToken, 'acc');
      },
    );

    test('AUTH_INVALID_CREDENTIALS surfaces as a ServerFailure', () async {
      http.on(
        'POST',
        '$_base/auth/login',
        (_) => FakeResponse(
          401,
          body: errorEnvelope('AUTH_INVALID_CREDENTIALS', 'Invalid'),
        ),
      );

      await expectLater(
        repo.login(identifier: 'layla', password: 'x'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.code,
            'code',
            ErrorCode.authInvalidCredentials,
          ),
        ),
      );
      expect(store.refreshToken, isNull);
      expect(http.requestsTo('POST', '$_base/auth/refresh'), isEmpty);
    });

    test('a body that breaks the contract is an UnexpectedFailure', () async {
      http.on(
        'POST',
        '$_base/auth/login',
        (_) => const FakeResponse(200, body: {'user': null}),
      );
      await expectLater(
        repo.login(identifier: 'layla', password: 'x'),
        throwsA(isA<UnexpectedFailure>()),
      );
    });
  });

  test('v1.2 register posts RegisterRequest (normalized email, locale) and '
      'creates no session (202 VerificationPending)', () async {
    http.on(
      'POST',
      '$_base/auth/register',
      (_) => const FakeResponse(202, body: {'status': 'verification_pending'}),
    );

    await repo.register(
      email: '  Layla@Example.COM ',
      password: 'pa55word!',
      username: 'layla.k',
      displayName: ' ليلى ',
      gender: Gender.female,
      locale: 'ar',
    );

    expect(http.requests.single.data, {
      'email': 'layla@example.com',
      'password': 'pa55word!',
      'username': 'layla.k',
      'displayName': 'ليلى',
      // v1.47-social (D175): required at sign-up.
      'gender': 'FEMALE',
      'locale': 'ar',
      'device': {'platform': 'android', 'appVersion': '1.2.3'},
    });
    // No tokens before the code is verified.
    expect(store.refreshToken, isNull);
    expect(container.read(tokenManagerProvider).accessToken, isNull);
  });

  group('v1.2 register/verify', () {
    test('posts {email, code, device}, stores the session, returns the '
        'user', () async {
      http.on(
        'POST',
        '$_base/auth/register/verify',
        (_) => FakeResponse(
          201,
          body: authResponseJson(
            user: meJson(emailVerified: true, displayName: 'Layla'),
            tokens: tokenPairJson(accessToken: 'acc', refreshToken: 'sid.s'),
          ),
        ),
      );

      final user = await repo.verifyRegistration(
        email: ' Layla@Example.COM ',
        code: '48210937',
      );

      final req = http.requests.single;
      expect(req.headers.containsKey('Authorization'), isFalse);
      expect(req.data, {
        'email': 'layla@example.com',
        'code': '48210937',
        'device': {'platform': 'android', 'appVersion': '1.2.3'},
      });
      expect(user.displayName, 'Layla');
      expect(user.emailVerified, isTrue);
      expect(store.refreshToken, 'sid.s');
      expect(container.read(tokenManagerProvider).accessToken, 'acc');
    });

    for (final (status, code, expected) in [
      (422, 'TOKEN_INVALID', ErrorCode.tokenInvalid),
      (409, 'USERNAME_TAKEN', ErrorCode.usernameTaken),
      (429, 'RATE_LIMITED', ErrorCode.rateLimited),
      (503, 'SERVICE_UNAVAILABLE', ErrorCode.serviceUnavailable),
    ]) {
      test('$status $code is mapped and stores nothing', () async {
        http.on(
          'POST',
          '$_base/auth/register/verify',
          (_) => FakeResponse(status, body: errorEnvelope(code, 'x')),
        );
        await expectLater(
          repo.verifyRegistration(email: 'a@b.co', code: '00000000'),
          throwsA(isA<ServerFailure>().having((f) => f.code, 'code', expected)),
        );
        expect(store.refreshToken, isNull);
        expect(http.requestsTo('POST', '$_base/auth/refresh'), isEmpty);
      });
    }

    test('resend posts the normalized email (always 202)', () async {
      http.on(
        'POST',
        '$_base/auth/register/resend',
        (_) =>
            const FakeResponse(202, body: {'status': 'verification_pending'}),
      );
      await repo.resendRegistrationCode(' A@B.co ');
      expect(http.requests.single.data, {'email': 'a@b.co'});
    });
  });

  test(
    'v1.2 updateLocale sends PATCH /me {"locale"} with the bearer',
    () async {
      await build(storedRefreshToken: 'sid.old');
      http
        ..on(
          'POST',
          '$_base/auth/refresh',
          (_) => FakeResponse(200, body: tokenPairJson(accessToken: 'acc')),
        )
        ..on('GET', '$_base/me', (_) => FakeResponse(200, body: meJson()))
        ..on(
          'PATCH',
          '$_base/me',
          (o) => FakeResponse(200, body: meJson(locale: 'en')),
        );
      await repo.restoreSession();

      final user = await repo.updateLocale('en');

      final req = http.requestsTo('PATCH', '$_base/me').single;
      expect(req.data, {'locale': 'en'});
      expect(req.headers['Authorization'], 'Bearer acc');
      expect(user.locale, 'en');
    },
  );

  test('contract v1.0.3: usernames are sent trimmed and lowercased', () async {
    http
      ..on(
        'POST',
        '$_base/auth/register',
        (_) =>
            const FakeResponse(202, body: {'status': 'verification_pending'}),
      )
      ..on(
        'GET',
        '$_base/users/username-availability',
        (o) => FakeResponse(
          200,
          body: {'username': o.queryParameters['username'], 'available': true},
        ),
      );

    await repo.checkUsernameAvailability(' Layla.K ');
    await repo.register(
      email: 'a@b.co',
      password: 'pa55word!',
      username: ' Layla.K ',
      displayName: 'L',
      gender: Gender.undisclosed,
      locale: 'en',
    );

    expect(http.requests.first.uri.queryParameters['username'], 'layla.k');
    expect((http.requests.last.data as Map)['username'], 'layla.k');
  });

  test('register maps USERNAME_TAKEN', () async {
    http.on(
      'POST',
      '$_base/auth/register',
      (_) => FakeResponse(409, body: errorEnvelope('USERNAME_TAKEN', 'taken')),
    );
    await expectLater(
      repo.register(
        email: 'a@b.co',
        password: 'pa55word!',
        username: 'admin',
        displayName: 'A',
        gender: Gender.male,
        locale: 'en',
      ),
      throwsA(
        isA<ServerFailure>().having(
          (f) => f.code,
          'code',
          ErrorCode.usernameTaken,
        ),
      ),
    );
  });

  group('restoreSession', () {
    test('returns null without any request when nothing is stored', () async {
      expect(await repo.restoreSession(), isNull);
      expect(http.requests, isEmpty);
    });

    test('refreshes then loads /me with the new access token', () async {
      await build(storedRefreshToken: 'sid.old');
      http
        ..on(
          'POST',
          '$_base/auth/refresh',
          (_) => FakeResponse(
            200,
            body: tokenPairJson(accessToken: 'new', refreshToken: 'sid.new'),
          ),
        )
        ..on('GET', '$_base/me', (o) {
          expect(o.headers['Authorization'], 'Bearer new');
          return FakeResponse(200, body: meJson(displayName: 'Layla'));
        });

      final user = await repo.restoreSession();

      expect(user?.displayName, 'Layla');
      expect(http.requestsTo('POST', '$_base/auth/refresh').single.data, {
        'refreshToken': 'sid.old',
      });
      expect(store.refreshToken, 'sid.new');
    });

    test('AUTH_REFRESH_INVALID clears the stored token', () async {
      await build(storedRefreshToken: 'sid.old');
      http.on(
        'POST',
        '$_base/auth/refresh',
        (_) => FakeResponse(
          401,
          body: errorEnvelope('AUTH_REFRESH_INVALID', 'reused'),
        ),
      );
      await expectLater(
        repo.restoreSession(),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.code,
            'code',
            ErrorCode.authRefreshInvalid,
          ),
        ),
      );
      expect(store.refreshToken, isNull);
    });
  });

  group('logout', () {
    test('revokes the session on the server and clears local tokens', () async {
      await build(storedRefreshToken: 'sid.old');
      http
        ..on(
          'POST',
          '$_base/auth/refresh',
          (_) => FakeResponse(200, body: tokenPairJson(accessToken: 'acc')),
        )
        ..on('GET', '$_base/me', (_) => FakeResponse(200, body: meJson()))
        ..on(
          'POST',
          '$_base/auth/logout',
          (_) => const FakeResponse.noContent(),
        );
      await repo.restoreSession();

      await repo.logout();

      final req = http.requestsTo('POST', '$_base/auth/logout').single;
      expect(req.headers['Authorization'], 'Bearer acc');
      expect(store.refreshToken, isNull);
      expect(container.read(tokenManagerProvider).accessToken, isNull);
    });

    test('clears local tokens even when the server call fails', () async {
      await build(storedRefreshToken: 'sid.old');
      http.on(
        'POST',
        '$_base/auth/logout',
        (_) => FakeResponse(500, body: errorEnvelope('INTERNAL_ERROR', 'x')),
      );
      await repo.logout();
      expect(store.refreshToken, isNull);
    });
  });

  test('getMe maps nullable fields', () async {
    http.on(
      'GET',
      '$_base/me',
      (_) => FakeResponse(
        200,
        body: meJson(bio: 'Hi', avatarUrl: 'https://cdn.example/a.jpg'),
      ),
    );
    final me = await repo.getMe();
    expect(me.bio, 'Hi');
    expect(me.avatarUrl, 'https://cdn.example/a.jpg');
    expect(me.role, UserRole.user);
  });

  test('checkUsernameAvailability sends the username query', () async {
    http.on(
      'GET',
      '$_base/users/username-availability',
      (o) => FakeResponse(
        200,
        body: {'username': o.queryParameters['username'], 'available': false},
      ),
    );
    final result = await repo.checkUsernameAvailability('admin');
    expect(result.username, 'admin');
    expect(result.available, isFalse);
    expect(http.requests.single.uri.query, 'username=admin');
  });

  test('requestPasswordReset posts the normalized email (202)', () async {
    http.on(
      'POST',
      '$_base/auth/password/forgot',
      (_) => const FakeResponse.noContent(202),
    );
    await repo.requestPasswordReset(' Layla@Example.com ');
    expect(http.requests.single.data, {'email': 'layla@example.com'});
  });

  test('listSessions maps SessionInfo', () async {
    http.on(
      'GET',
      '$_base/auth/sessions',
      (_) => FakeResponse(
        200,
        body: {
          'data': [
            sessionJson(
              id: 's1',
              current: true,
              deviceName: 'Pixel 9',
              platform: 'android',
              appVersion: '1.0.0',
            ),
            sessionJson(id: 's2', platform: 'ios'),
            sessionJson(id: 's3'),
          ],
        },
      ),
    );

    final sessions = await repo.listSessions();

    expect(sessions.map((s) => s.id), ['s1', 's2', 's3']);
    expect(sessions[0].current, isTrue);
    expect(sessions[0].deviceName, 'Pixel 9');
    expect(sessions[0].platform, SessionPlatform.android);
    expect(sessions[1].platform, SessionPlatform.ios);
    expect(sessions[2].platform, isNull);
    expect(sessions[0].lastUsedAt, DateTime.utc(2026, 10, 15, 12, 30));
  });

  test('revokeSession sends DELETE /auth/sessions/{id}', () async {
    const id = '0192f1c2-0000-7000-8000-000000000001';
    http.on(
      'DELETE',
      '$_base/auth/sessions/$id',
      (_) => const FakeResponse.noContent(),
    );
    await repo.revokeSession(id);
    expect(http.requests.single.method, 'DELETE');
  });

  test('revokeSession maps NOT_FOUND', () async {
    await expectLater(
      repo.revokeSession('missing'),
      throwsA(
        isA<ServerFailure>().having((f) => f.code, 'code', ErrorCode.notFound),
      ),
    );
  });
}
