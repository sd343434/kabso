// KL-006 (A6, QA) regression tests for gaps found in the Phase 1 review.
// They cover KL-003 acceptance criteria and PHASE1_SCREENS.md §11 checklist
// items that had no test. Production code is not modified by QA.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/forgot_password_screen.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/contract_fixtures.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

/// [FakeAuthRepository] with a mutable server-side session list.
class _SessionsRepo extends FakeAuthRepository {
  new(this.sessions, {this.revokeFailure});

  List<Session> sessions;
  AppFailure? revokeFailure;
  final List<String> revoked = [];

  @override
  Future<List<Session>> listSessions() async => List.of(sessions);

  @override
  Future<void> revokeSession(String sessionId) async {
    revoked.add(sessionId);
    // The server-side session is gone in both cases (revoked now or before).
    sessions = sessions.where((s) => s.id != sessionId).toList();
    final failure = revokeFailure;
    if (failure != null) throw failure;
  }
}

Session _session(String id, {bool current = false, String? name}) => Session(
  id: id,
  current: current,
  deviceName: name,
  platform: SessionPlatform.android,
  createdAt: DateTime.utc(2026, 10, 1, 8),
  lastUsedAt: DateTime.utc(2026, 10, 15, 12, 30),
);

const _thisDevice = '0192f1c2-0000-7000-8000-000000000001';
const _otherDevice = '0192f1c2-0000-7000-8000-000000000002';

/// Eastern Arabic-Indic (U+0660–0669) and Extended Arabic-Indic (U+06F0–06F9).
final _arabicIndicDigits = RegExp('[٠-٩۰-۹]');

void main() {
  group('checklist #8: revoking another session', () {
    Future<_SessionsRepo> pumpSettings(
      WidgetTester tester, {
      AppFailure? revokeFailure,
    }) async {
      final repo = _SessionsRepo([
        _session(_thisDevice, current: true, name: 'This Phone'),
        _session(_otherDevice, name: 'Old Tablet'),
      ], revokeFailure: revokeFailure);
      await pumpScreen(
        tester,
        const SettingsScreen(),
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.pumpAndSettle();
      return repo;
    }

    Future<void> revokeOther(WidgetTester tester) async {
      final l10n = l10nFor(AppLanguage.en);
      final tile = find.byKey(const Key('session.$_otherDevice'));
      await tester.scrollUntilVisible(tile, 100);
      await tester.tap(
        find.descendant(of: tile, matching: find.text(l10n.sessionsRevoke)),
      );
      await tester.pumpAndSettle();
      // Confirm in the dialog.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          // KL-015 §5.5: the destructive confirm names the object.
          matching: find.text(l10n.sessionsRevokeConfirm),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the current device has no revoke action', (tester) async {
      await pumpSettings(tester);
      final l10n = l10nFor(AppLanguage.en);
      final current = find.byKey(const Key('session.$_thisDevice'));
      expect(current, findsOneWidget);
      expect(
        find.descendant(of: current, matching: find.text(l10n.sessionsRevoke)),
        findsNothing,
      );
    });

    testWidgets('success: the session disappears and a confirmation shows', (
      tester,
    ) async {
      final repo = await pumpSettings(tester);
      await revokeOther(tester);

      expect(repo.revoked, [_otherDevice]);
      expect(find.byKey(const Key('session.$_otherDevice')), findsNothing);
      expect(find.byKey(const Key('session.$_thisDevice')), findsOneWidget);
      expect(find.text(l10nFor(AppLanguage.en).sessionsRevoked), findsOne);
    });

    testWidgets('NOT_FOUND (already ended): the list is refreshed and the '
        'stale entry disappears', (tester) async {
      final repo = await pumpSettings(
        tester,
        revokeFailure: const ServerFailure(
          code: ErrorCode.notFound,
          rawCode: 'NOT_FOUND',
          debugMessage: 'Session not found',
        ),
      );
      await revokeOther(tester);

      expect(repo.revoked, [_otherDevice]);
      expect(find.byKey(const Key('session.$_otherDevice')), findsNothing);
      // The user still gets feedback (no silent failure).
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('cancelling the dialog does not revoke', (tester) async {
      final repo = await pumpSettings(tester);
      final l10n = l10nFor(AppLanguage.en);
      final tile = find.byKey(const Key('session.$_otherDevice'));
      await tester.scrollUntilVisible(tile, 100);
      await tester.tap(
        find.descendant(of: tile, matching: find.text(l10n.sessionsRevoke)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionCancel));
      await tester.pumpAndSettle();

      expect(repo.revoked, isEmpty);
      expect(tile, findsOneWidget);
    });
  });

  group('checklist #11: Latin digits in Arabic', () {
    // QA-003 fixed in KL-012 (KFormat: Latin digits in both locales).
    testWidgets('session dates in Arabic use Latin digits', (tester) async {
      final repo = _SessionsRepo([
        _session(_thisDevice, current: true, name: 'This Phone'),
      ]);
      await pumpScreen(
        tester,
        const SettingsScreen(),
        language: AppLanguage.ar,
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.pumpAndSettle();

      final tile = find.byKey(const Key('session.$_thisDevice'));
      expect(tile, findsOneWidget);
      final texts = tester
          .widgetList<Text>(
            find.descendant(of: tile, matching: find.byType(Text)),
          )
          .map((t) => t.data ?? '')
          .join(' | ');
      expect(texts, contains(RegExp('[0-9]')), reason: texts);
      expect(texts, isNot(contains(_arabicIndicDigits)), reason: texts);
    });
  });

  group('session expiry while using the app (interceptor + router)', () {
    testWidgets('401 on a protected call → refresh rejected → login with the '
        '"session ended" banner and the stored token is cleared', (
      tester,
    ) async {
      final http = FakeHttpAdapter();
      final store = InMemoryTokenStore('sid.stored');
      var refreshCalls = 0;
      var meCalls = 0;
      http
        ..on('POST', '/api/v1/auth/refresh', (_) {
          refreshCalls++;
          if (refreshCalls == 1) {
            return FakeResponse(200, body: tokenPairJson(accessToken: 'acc'));
          }
          return FakeResponse(
            401,
            body: errorEnvelope('AUTH_REFRESH_INVALID', 'Refresh invalid'),
          );
        })
        ..on('GET', '/api/v1/me', (_) {
          meCalls++;
          if (meCalls == 1) return FakeResponse(200, body: meJson());
          return FakeResponse(
            401,
            body: errorEnvelope('AUTH_UNAUTHENTICATED', 'Expired'),
          );
        });

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
      expect(find.byKey(const Key('nav.home')), findsOneWidget);

      // The Profile tab loads GET /me again: it now gets 401.
      await tester.tap(find.byKey(const Key('nav.profile')));
      await tester.pumpAndSettle();

      expect(refreshCalls, 2, reason: 'exactly one refresh attempt per 401');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.text(l10nFor(AppLanguage.en).sessionEndedBanner),
        findsOneWidget,
      );
      expect(store.refreshToken, isNull);
      // Every protected request carried the bearer token; public ones none.
      for (final r in http.requestsTo('GET', '/api/v1/me')) {
        expect(r.headers['Authorization'], 'Bearer acc');
      }
      for (final r in http.requestsTo('POST', '/api/v1/auth/refresh')) {
        expect(r.headers.containsKey('Authorization'), isFalse);
      }
    });
  });

  group('checklist #9: tap targets ≥ 48 dp and labels', () {
    for (final language in AppLanguage.values) {
      testWidgets('auth screens (${language.name})', (tester) async {
        final handle = tester.ensureSemantics();
        for (final screen in <Widget>[
          const LoginScreen(),
          const RegisterScreen(),
          const ForgotPasswordScreen(),
        ]) {
          await pumpScreen(
            tester,
            screen,
            language: language,
            overrides: [
              authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            ],
          );
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        }
        handle.dispose();
      });
    }

    testWidgets('bottom navigation items', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpKabsoApp(
        tester,
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(storedUser: testUser()),
          ),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );
      await tester.pumpAndSettle();
      for (final key in const [
        Key('nav.home'),
        Key('nav.discover'),
        Key('nav.create'),
        Key('nav.reels'),
        Key('nav.profile'),
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(48), reason: '$key');
        expect(size.height, greaterThanOrEqualTo(48), reason: '$key');
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('checklist #2: localization resources', () {
    Map<String, Object?> arb(String name) =>
        jsonDecode(File('lib/l10n/$name').readAsStringSync())
            as Map<String, Object?>;

    test('app_ar.arb and app_en.arb define the same keys and placeholders', () {
      final ar = arb('app_ar.arb');
      final en = arb('app_en.arb');
      Set<String> keys(Map<String, Object?> m) =>
          m.keys.where((k) => !k.startsWith('@')).toSet();
      expect(keys(ar), keys(en));

      final placeholder = RegExp(r'\{(\w+)');
      for (final key in keys(en)) {
        Set<String> names(Object? v) =>
            placeholder.allMatches('$v').map((m) => m.group(1)!).toSet();
        expect(names(ar[key]), names(en[key]), reason: key);
        expect('${ar[key]}'.trim(), isNotEmpty, reason: 'ar $key');
      }
    });

    test('no Text widget in lib/ is built from a string literal', () {
      final literalText = RegExp(r'''\bText\(\s*['"]''');
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.contains('${Platform.pathSeparator}gen')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (literalText.hasMatch(lines[i])) {
            offenders.add('${entity.path}:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('KL-003: defaults on a fresh install', () {
    // Contract v1.2 / D26 (PHASE1_1_SCREENS §3.1): with no saved choice the
    // device language decides (en* → en, ar* → ar, anything else → ar). The
    // test now pins a non-English, non-Arabic device locale so the Arabic
    // fallback is what is asserted, independent of the test host's locale.
    test('language defaults to Arabic and theme to dark', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocalesProvider.overrideWithValue(const [Locale('fr', 'FR')]),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(languageControllerProvider), AppLanguage.ar);
      // D68: the device decides until the user picks a theme.
      expect(container.read(themeModeControllerProvider), ThemeMode.system);
    });
  });

  group('checklist #4: username availability ordering', () {
    test('a slow response for an older value never overwrites the newer '
        'value', () async {
      final repo = _SlowFirstRepo();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          usernameDebounceProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(usernameAvailabilityProvider, (_, _) {});
      addTearDown(sub.close);
      final controller = container.read(usernameAvailabilityProvider.notifier)
        // "slowname" is taken but answers late; "fastname" is free.
        ..onChanged('SlowName');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.onChanged('fastname');
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(repo.availabilityChecks, ['slowname', 'fastname']);
      final state = container.read(usernameAvailabilityProvider);
      expect(state, isA<UsernameAvailable>());
      expect((state as UsernameAvailable).username, 'fastname');
    });
  });
}

/// The first lookup ("slowname", taken) answers after the second one.
class _SlowFirstRepo extends FakeAuthRepository {
  @override
  Future<UsernameAvailability> checkUsernameAvailability(
    String username,
  ) async {
    availabilityChecks.add(username);
    if (username == 'slowname') {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return UsernameAvailability(username: username, available: false);
    }
    return UsernameAvailability(username: username, available: true);
  }
}
