import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/contract_fixtures.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

const _navKeys = [
  Key('nav.home'),
  Key('nav.discover'),
  Key('nav.create'),
  Key('nav.live'),
  Key('nav.profile'),
];

void main() {
  late FakeAuthRepository repo;

  setUp(() {
    repo = FakeAuthRepository(
      storedUser: testUser(displayName: 'Stored Layla'),
      me: testUser(displayName: 'Layla From Me', emailVerified: false),
    );
  });

  Future<void> pumpSignedIn(WidgetTester tester, {String language = 'en'}) =>
      pumpKabsoApp(
        tester,
        language: language,
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );

  group('shell', () {
    testWidgets('renders 5 tabs and switches branches', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      await pumpSignedIn(tester);
      await tester.pumpAndSettle();

      for (final key in _navKeys) {
        expect(find.byKey(key), findsOneWidget);
      }
      expect(find.text(l10n.homeComingTitle), findsOneWidget);

      final expected = {
        const Key('nav.discover'): l10n.discoverComingTitle,
        const Key('nav.create'): l10n.createComingTitle,
        const Key('nav.live'): l10n.liveComingTitle,
        const Key('nav.home'): l10n.homeComingTitle,
      };
      for (final MapEntry(:key, :value) in expected.entries) {
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(find.text(value), findsOneWidget, reason: '$key');
      }
    });

    testWidgets('profile tab shows the user from GET /me', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      await pumpSignedIn(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav.profile')));
      await tester.pumpAndSettle();

      expect(repo.getMeCalls, greaterThanOrEqualTo(1));
      expect(find.text('Layla From Me'), findsOneWidget);
      expect(find.text('Stored Layla'), findsNothing);
      expect(find.text('@layla.k'), findsOneWidget);
      expect(find.text('layla@example.com'), findsOneWidget);
      expect(find.text(l10n.profileEmailNotVerified), findsOneWidget);
      expect(find.text(l10n.profileResendVerification), findsOneWidget);
      expect(find.byKey(ProfileScreen.settingsButtonKey), findsOneWidget);
    });

    testWidgets('settings: language switch to Arabic and logout', (
      tester,
    ) async {
      await pumpSignedIn(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav.profile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProfileScreen.settingsButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      final ar = l10nFor(AppLanguage.ar);
      expect(find.text(ar.settingsTitle), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(SettingsScreen))),
        TextDirection.rtl,
      );

      await tester.scrollUntilVisible(
        find.byKey(SettingsScreen.logoutKey),
        200,
      );
      await tester.tap(find.byKey(SettingsScreen.logoutKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings.logout.confirm')));
      await tester.pumpAndSettle();

      expect(repo.logoutCalls, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('RTL', () {
    for (final (language, dir) in [
      ('ar', TextDirection.rtl),
      ('en', TextDirection.ltr),
    ]) {
      testWidgets('$language: direction is ${dir.name} and nav mirrors', (
        tester,
      ) async {
        await pumpSignedIn(tester, language: language);
        await tester.pumpAndSettle();

        final home = find.byKey(const Key('nav.home'));
        final profile = find.byKey(const Key('nav.profile'));
        expect(Directionality.of(tester.element(home)), dir);

        final xs = <double>[
          for (final k in _navKeys) tester.getCenter(find.byKey(k)).dx,
        ];
        if (dir == TextDirection.rtl) {
          // Home at the right edge, Profile at the left; Create centered.
          expect(tester.getCenter(home).dx, greaterThan(400));
          expect(tester.getCenter(profile).dx, lessThan(400));
          expect(
            xs,
            orderedEquals(List<double>.of(xs)..sort((a, b) => b.compareTo(a))),
          );
        } else {
          expect(tester.getCenter(home).dx, lessThan(400));
          expect(xs, orderedEquals(List<double>.of(xs)..sort()));
        }
      });
    }
  });

  group('splash / session restore (real repository, fake HTTP)', () {
    late FakeHttpAdapter http;

    setUp(() => http = FakeHttpAdapter());

    testWidgets('no stored token → login, without any request', (tester) async {
      await pumpKabsoApp(
        tester,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: 'http://test', appVersion: '1.0.0'),
          ),
          httpClientAdapterProvider.overrideWithValue(http),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(http.requests, isEmpty);
    });

    testWidgets('stored token → refresh → /me → home', (tester) async {
      http
        ..on(
          'POST',
          '/api/v1/auth/refresh',
          (_) => FakeResponse(200, body: tokenPairJson(accessToken: 'acc')),
        )
        ..on('GET', '/api/v1/me', (_) => FakeResponse(200, body: meJson()));
      await pumpKabsoApp(
        tester,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: 'http://test', appVersion: '1.0.0'),
          ),
          httpClientAdapterProvider.overrideWithValue(http),
          secureTokenStoreProvider.overrideWithValue(
            InMemoryTokenStore('sid.stored'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nav.home')), findsOneWidget);
      expect(find.text(l10nFor(AppLanguage.en).homeComingTitle), findsOne);
    });

    testWidgets('suspended account: refresh 403 ACCOUNT_SUSPENDED clears the '
        'session and login shows the suspended message', (tester) async {
      final store = InMemoryTokenStore('sid.stored');
      http.on(
        'POST',
        '/api/v1/auth/refresh',
        (_) => FakeResponse(
          403,
          body: errorEnvelope('ACCOUNT_SUSPENDED', 'Account suspended'),
        ),
      );
      await pumpKabsoApp(
        tester,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: 'http://test', appVersion: '1.0.0'),
          ),
          httpClientAdapterProvider.overrideWithValue(http),
          secureTokenStoreProvider.overrideWithValue(store),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.text(l10nFor(AppLanguage.en).accountSuspendedBanner),
        findsOneWidget,
      );
      expect(store.refreshToken, isNull);
    });

    testWidgets('offline during restore keeps the token and offers retry', (
      tester,
    ) async {
      final store = InMemoryTokenStore('sid.stored');
      http.on(
        'POST',
        '/api/v1/auth/refresh',
        (_) => throw const SocketException('Network is unreachable'),
      );
      await pumpKabsoApp(
        tester,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: 'http://test', appVersion: '1.0.0'),
          ),
          httpClientAdapterProvider.overrideWithValue(http),
          secureTokenStoreProvider.overrideWithValue(store),
        ],
      );
      await tester.pumpAndSettle();

      final l10n = l10nFor(AppLanguage.en);
      expect(find.text(l10n.splashRestoreFailed), findsOneWidget);
      expect(find.text(l10n.actionRetry), findsOneWidget);
      expect(store.refreshToken, 'sid.stored');
    });
  });
}
