// KL-006c (A6, QA): independent checks of contract v1.2 behaviour in the
// app, end to end through KabsoApp (router, l10n, providers) where possible:
// first-launch language from the device locale, the auth language switch
// feeding the register locale, server displayName issues → PHASE1_1 §2 copy,
// and locale-sync robustness.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/app_router.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/locale_sync.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_code_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required List<Locale> deviceLocales,
  required FakeAuthRepository repo,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        deviceLocalesProvider.overrideWithValue(deviceLocales),
        authRepositoryProvider.overrideWithValue(repo),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        usernameDebounceProvider.overrideWithValue(Duration.zero),
      ],
      child: const KabsoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(KabsoApp)));
}

const _skipQa011 = bool.fromEnvironment('QA_SKIP_011', defaultValue: true);

void main() {
  group('PP-22 first launch follows the device locale (full app)', () {
    for (final (device, expected, dir) in [
      (const Locale('en', 'US'), AppLanguage.en, TextDirection.ltr),
      (const Locale('ar', 'EG'), AppLanguage.ar, TextDirection.rtl),
      (const Locale('fr', 'FR'), AppLanguage.ar, TextDirection.rtl),
    ]) {
      testWidgets('$device → ${expected.name} (${dir.name})', (tester) async {
        await _pumpApp(
          tester,
          deviceLocales: [device],
          repo: FakeAuthRepository(),
        );
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(LoginScreen))),
          dir,
        );
        final l10n = l10nFor(expected);
        expect(find.text(l10n.loginTitle), findsWidgets);
        // Nothing is persisted until the user chooses explicitly.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(PreferenceKeys.languageCode), isNull);
      });
    }

    testWidgets('a saved choice wins over the device (en saved, ar-EG)', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        deviceLocales: const [Locale('ar', 'EG')],
        repo: FakeAuthRepository(),
        prefs: {PreferenceKeys.languageCode: 'en'},
      );
      expect(find.text(l10nFor(AppLanguage.en).loginTitle), findsWidgets);
    });
  });

  group('PP-22 auth language chip → register locale', () {
    testWidgets('fr-FR device (Arabic UI): chip → English, persisted; '
        'register sends "en" and opens the code screen', (tester) async {
      final repo = FakeAuthRepository();
      await _pumpApp(
        tester,
        deviceLocales: const [Locale('fr', 'FR')],
        repo: repo,
      );
      // Arabic UI shows the target language "English".
      final chip = find.byKey(AuthLanguageSwitch.switchKey);
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: find.text('English')),
        findsOneWidget,
      );
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text(l10nFor(AppLanguage.en).loginTitle), findsWidgets);
      expect(
        Directionality.of(tester.element(find.byType(LoginScreen))),
        TextDirection.ltr,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PreferenceKeys.languageCode), 'en');

      // Register in the displayed language.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(KabsoApp)),
      );
      container.read(routerProvider).go('/auth/register');
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      await tester.enterText(find.byKey(RegisterScreen.emailKey), 'a@b.co');
      await tester.enterText(find.byKey(RegisterScreen.usernameKey), 'layla');
      await tester.enterText(
        find.byKey(RegisterScreen.displayNameKey),
        'علی‌رضا 👨‍👩‍👧',
      );
      await tester.enterText(
        find.byKey(RegisterScreen.passwordKey),
        'pa55word!',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
      await tester.tap(find.byKey(RegisterScreen.submitKey));
      await tester.pumpAndSettle();
      expect(repo.registerLocales, ['en']);
      expect(find.byType(RegisterCodeScreen), findsOneWidget);
    });
  });

  group('PP-21 server displayName issues → PHASE1_1 §2 copy', () {
    for (final language in AppLanguage.values) {
      for (final (issue, copy) in <(String, String Function(AppLocalizations))>[
        ('reserved_term', (l) => l.displayNameReserved),
        ('invalid_format', (l) => l.displayNameInvalid),
        ('too_long', (l) => l.displayNameTooLong),
      ]) {
        testWidgets('${language.name}: $issue', (tester) async {
          final repo = FakeAuthRepository(
            registerFailure: ServerFailure(
              code: ErrorCode.validationFailed,
              rawCode: 'VALIDATION_FAILED',
              debugMessage: 'bad name',
              statusCode: 400,
              details: [FieldIssue(field: 'displayName', issue: issue)],
            ),
          );
          await pumpScreen(
            tester,
            const RegisterScreen(),
            language: language,
            overrides: [
              authRepositoryProvider.overrideWithValue(repo),
              secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
              usernameDebounceProvider.overrideWithValue(Duration.zero),
            ],
          );
          await tester.enterText(find.byKey(RegisterScreen.emailKey), 'a@b.co');
          await tester.enterText(
            find.byKey(RegisterScreen.usernameKey),
            'layla',
          );
          // Passes every client-side check; only the server rejects it.
          await tester.enterText(
            find.byKey(RegisterScreen.displayNameKey),
            'Layla',
          );
          await tester.enterText(
            find.byKey(RegisterScreen.passwordKey),
            'pa55word!',
          );
          await tester.pump();
          await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
          await tester.tap(find.byKey(RegisterScreen.submitKey));
          await tester.pumpAndSettle();
          expect(repo.registerCalls, 1);
          expect(find.text(copy(l10nFor(language))), findsOneWidget);
          expect(find.byType(RegisterCodeScreen), findsNothing);
        });
      }
    }
  });

  group('PP-22 locale sync robustness', () {
    test(
      'a second language change during an in-flight PATCH is not lost',
      () async {
        final repo = _SlowLocaleRepo();
        SharedPreferences.setMockInitialValues({
          PreferenceKeys.languageCode: 'ar',
        });
        final sp = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sp),
            deviceLocalesProvider.overrideWithValue(const [Locale('ar')]),
            authRepositoryProvider.overrideWithValue(repo),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          ],
        );
        addTearDown(container.dispose);
        // Let the launch-time restore (no stored session) finish first.
        container.read(sessionControllerProvider);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        container
            .read(sessionControllerProvider.notifier)
            .signedIn(testUser().copyWith(locale: 'ar'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(container.read(currentUserProvider), isNotNull);
        expect(repo.localeUpdates, isEmpty, reason: 'choice equals me.locale');
        final language = container.read(languageControllerProvider.notifier);
        final sync = container.read(localeSyncProvider);

        await language.select(AppLanguage.en);
        final first = sync.languageChanged(); // PATCH en, in flight
        await language.select(AppLanguage.ar);
        final second = sync.languageChanged(); // user switched back
        await Future.wait([first, second]);
        // Let any retry the app schedules run.
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(container.read(languageControllerProvider), AppLanguage.ar);
        // The account must end up with the language the user is looking at
        // (or at least have a pending sync scheduled for it).
        final pending = sp.getBool(PreferenceKeys.localeSyncPending) ?? false;
        expect(
          repo.serverLocale == 'ar' || pending,
          isTrue,
          reason:
              'server=${repo.serverLocale} updates=${repo.localeUpdates} '
              'pending=$pending',
        );
      },
      skip: _skipQa011
          ? 'QA-011 (owner A2): LocaleSync._push drops a change made while a '
                'PATCH is in flight; remove this skip with the fix (D16)'
          : null,
    );
  });
}

/// PATCH /me takes 50 ms; the "server" keeps the last value it received.
class _SlowLocaleRepo extends FakeAuthRepository {
  String serverLocale = 'ar';

  @override
  Future<User> updateLocale(String locale) async {
    localeUpdates.add(locale);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    serverLocale = locale;
    return me = me.copyWith(locale: locale);
  }
}
