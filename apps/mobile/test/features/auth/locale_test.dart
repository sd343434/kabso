// KL-018: first-launch language resolution and PATCH /me sync
// (contract v1.2 §6 Locale, PHASE1_1_SCREENS §3).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/locale_sync.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

void main() {
  group('resolveAppLanguage (D26)', () {
    AppLanguage resolve(String? saved, List<Locale> device) =>
        resolveAppLanguage(savedChoice: saved, deviceLocales: device);

    test('device en-US → en', () {
      expect(resolve(null, const [Locale('en', 'US')]), AppLanguage.en);
    });
    test('device ar-EG → ar', () {
      expect(resolve(null, const [Locale('ar', 'EG')]), AppLanguage.ar);
    });
    test('device fr-FR → ar (anything else)', () {
      expect(resolve(null, const [Locale('fr', 'FR')]), AppLanguage.ar);
    });
    test('only the first preferred locale counts', () {
      expect(resolve(null, const [Locale('fr'), Locale('en')]), AppLanguage.ar);
    });
    test('no device locale and no saved choice → ar', () {
      expect(resolve(null, const []), AppLanguage.ar);
    });
    test('a saved choice wins over the device', () {
      expect(resolve('ar', const [Locale('en', 'US')]), AppLanguage.ar);
      expect(resolve('en', const [Locale('ar', 'SA')]), AppLanguage.en);
    });
    test('an unknown saved value is ignored', () {
      expect(resolve('de', const [Locale('en', 'GB')]), AppLanguage.en);
    });
  });

  group('LanguageController persistence', () {
    test('nothing is persisted until an explicit choice', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer.test(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocalesProvider.overrideWithValue(const [Locale('en', 'US')]),
        ],
      );
      expect(container.read(languageControllerProvider), AppLanguage.en);
      final controller = container.read(languageControllerProvider.notifier);
      expect(controller.hasExplicitChoice, isFalse);
      expect(prefs.getString(PreferenceKeys.languageCode), isNull);

      await controller.select(AppLanguage.ar);
      expect(container.read(languageControllerProvider), AppLanguage.ar);
      expect(controller.hasExplicitChoice, isTrue);
      expect(prefs.getString(PreferenceKeys.languageCode), 'ar');
    });
  });

  group('LocaleSync after sign-in (§3.4)', () {
    late FakeAuthRepository repo;
    late SharedPreferences prefs;
    late ProviderContainer container;

    Future<void> build({
      String? savedChoice,
      Locale device = const Locale('fr', 'FR'),
    }) async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.languageCode: ?savedChoice,
      });
      prefs = await SharedPreferences.getInstance();
      container =
          ProviderContainer.test(
              retry: (_, _) => null,
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                deviceLocalesProvider.overrideWithValue([device]),
                authRepositoryProvider.overrideWithValue(repo),
                secureTokenStoreProvider.overrideWithValue(
                  InMemoryTokenStore(),
                ),
              ],
            )
            // Let the session controller finish its (empty) restore.
            ..read(sessionControllerProvider);
      await Future<void>.delayed(Duration.zero);
    }

    Future<void> signIn(String accountLocale) async {
      container
          .read(sessionControllerProvider.notifier)
          .signedIn(repo.me = repo.me.copyWith(locale: accountLocale));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    setUp(() => repo = FakeAuthRepository());

    test('saved choice differs from me.locale → PATCH /me', () async {
      await build(savedChoice: 'en');
      await signIn('ar');
      expect(repo.localeUpdates, ['en']);
      expect(container.read(currentUserProvider)?.locale, 'en');
      expect(prefs.getBool(PreferenceKeys.localeSyncPending), isNull);
    });

    test('saved choice equals me.locale → no PATCH', () async {
      await build(savedChoice: 'ar');
      await signIn('ar');
      expect(repo.localeUpdates, isEmpty);
    });

    test('no saved choice → adopt me.locale (stored), no PATCH', () async {
      await build(); // device fr → displayed ar
      await signIn('en');
      expect(repo.localeUpdates, isEmpty);
      expect(container.read(languageControllerProvider), AppLanguage.en);
      expect(prefs.getString(PreferenceKeys.languageCode), 'en');
    });

    test('no saved choice and me.locale equals the display → nothing '
        'stored', () async {
      await build(); // displayed ar
      await signIn('ar');
      expect(repo.localeUpdates, isEmpty);
      expect(prefs.getString(PreferenceKeys.languageCode), isNull);
    });

    test(
      'failure is silent, flagged, and retried on the next app start',
      () async {
        repo.updateLocaleFailure = const NetworkFailure.offline();
        await build(savedChoice: 'en');
        await signIn('ar');
        expect(repo.localeUpdates, ['en']);
        expect(prefs.getBool(PreferenceKeys.localeSyncPending), isTrue);
        expect(container.read(languageControllerProvider), AppLanguage.en);

        // Next start: session restored → retry.
        repo
          ..updateLocaleFailure = null
          ..storedUser = repo.me;
        await container.read(sessionControllerProvider.notifier).restore();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(repo.localeUpdates, ['en', 'en']);
        expect(prefs.getBool(PreferenceKeys.localeSyncPending), isNull);
      },
    );

    test('400 drops the pending flag', () async {
      repo.updateLocaleFailure = const ServerFailure(
        code: ErrorCode.validationFailed,
        rawCode: 'VALIDATION_FAILED',
        debugMessage: 'bad',
        statusCode: 400,
      );
      await build(savedChoice: 'en');
      await signIn('ar');
      expect(prefs.getBool(PreferenceKeys.localeSyncPending), isNull);
    });

    test('changing language while signed in PATCHes; logout keeps the '
        'choice', () async {
      await build(savedChoice: 'ar');
      await signIn('ar');
      await container
          .read(languageControllerProvider.notifier)
          .select(AppLanguage.en);
      await container.read(localeSyncProvider).languageChanged();
      expect(repo.localeUpdates, ['en']);

      await container.read(sessionControllerProvider.notifier).logout();
      expect(prefs.getString(PreferenceKeys.languageCode), 'en');
      expect(container.read(languageControllerProvider), AppLanguage.en);
    });

    test('changing language while signed out does not call the API', () async {
      await build(savedChoice: 'ar');
      await container
          .read(languageControllerProvider.notifier)
          .select(AppLanguage.en);
      await container.read(localeSyncProvider).languageChanged();
      expect(repo.localeUpdates, isEmpty);
    });
  });
}
