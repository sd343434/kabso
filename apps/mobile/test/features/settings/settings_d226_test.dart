// D226 (owner, 2026-11-01): Settings cleanup.
// 1. «الجلسات النشطة»: the two most recent sessions (this device always one
//    of them, «هذا الجهاز») and «عرض الكل (N)» → the full list, which keeps
//    the revoke action.
// 2. «الوضع الداكن»: one switch; follows the device until touched, then an
//    explicit choice; «اتباع الجهاز» goes back to following the device.
// 3. «اللغة: العربية»: one switch, العربية ↔ English, stored and synced.
// 4. «مستوياتي» and «اليوزرات المميزة» are no longer in Settings (they stay
//    in the «أنا» hub: me_hub_screen_test).
// 5. Demo data stays in test builds only; the component gallery is gone.
// Layout: ar/en × 393×852 / 360×800 × text 1.0 / 1.3 × light/dark.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/debug/demo_entry.dart';
import 'package:kabso_live/features/settings/sessions/sessions_screen.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

class _Repo extends FakeAuthRepository {
  new(this.sessions);

  List<Session> sessions;
  final List<String> revoked = [];

  @override
  Future<List<Session>> listSessions() async => List.of(sessions);

  @override
  Future<void> revokeSession(String sessionId) async {
    revoked.add(sessionId);
    sessions = sessions.where((s) => s.id != sessionId).toList();
  }
}

String _id(int n) => '0192f1c2-0000-7000-8000-00000000000$n';

/// Four sessions, newest first as the API sends them; this device (3) is
/// not the most recent one.
List<Session> _four() {
  final now = DateTime.now().toUtc();
  Session s(int n, Duration ago, {bool current = false, String? name}) =>
      Session(
        id: _id(n),
        current: current,
        deviceName: name,
        platform: SessionPlatform.android,
        createdAt: DateTime.utc(2026, 9, n),
        lastUsedAt: now.subtract(ago),
      );
  return [
    s(1, const Duration(minutes: 5), name: 'Tablet'),
    s(2, const Duration(hours: 2), name: 'Old phone'),
    s(3, const Duration(hours: 5), current: true, name: 'My phone'),
    s(4, const Duration(days: 3), name: 'Laptop'),
  ];
}

class _Harness {
  new(this.repo, this.prefs);
  final _Repo repo;
  final SharedPreferences prefs;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  List<Session>? sessions,
  AppLanguage language = AppLanguage.en,
  Map<String, Object> prefs = const {},
  Size size = const Size(393, 852),
  double textScale = 1,
  Brightness device = Brightness.light,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher
    ..textScaleFactorTestValue = textScale
    ..platformBrightnessTestValue = device;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final preferences = await testPrefs(language: language.name, extra: prefs);
  final repo = _Repo(sessions ?? _four());
  final router = GoRouter(
    initialLocation: AppRoutes.settings,
    routes: [
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.sessions,
        builder: (_, _) => const SessionsScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(testUser()),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final locale = ref.watch(languageControllerProvider).locale;
          return MaterialApp.router(
            routerConfig: router,
            locale: locale,
            supportedLocales: KabsoApp.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            themeMode: ref.watch(themeModeControllerProvider),
            theme: buildAppTheme(brightness: Brightness.light, locale: locale),
            darkTheme: buildAppTheme(
              brightness: Brightness.dark,
              locale: locale,
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(repo, preferences);
}

Brightness _appBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

bool _switchValue(WidgetTester tester, Key key) =>
    tester.widget<SwitchListTile>(find.byKey(key)).value;

void main() {
  group('1. active sessions', () {
    testWidgets('Settings shows two: this device and the most recent other, '
        'and «Show all (4)»', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      await _pump(tester);
      final all = find.byKey(SettingsScreen.sessionsShowAllKey);
      await tester.scrollUntilVisible(all, 100);

      final current = find.byKey(Key('session.${_id(3)}'));
      expect(current, findsOneWidget);
      expect(
        find.descendant(
          of: current,
          matching: find.textContaining(l10n.sessionsCurrent),
        ),
        findsOneWidget,
      );
      expect(find.byKey(Key('session.${_id(1)}')), findsOneWidget);
      expect(find.byKey(Key('session.${_id(2)}')), findsNothing);
      expect(find.byKey(Key('session.${_id(4)}')), findsNothing);
      // This device first, then the most recent other.
      expect(
        tester.getTopLeft(current).dy,
        lessThan(tester.getTopLeft(find.byKey(Key('session.${_id(1)}'))).dy),
      );
      expect(
        find.descendant(of: all, matching: find.text(l10n.sessionsShowAll(4))),
        findsOneWidget,
      );
    });

    testWidgets('«Show all» opens every session; revoke works there', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.en);
      final h = await _pump(tester);
      final all = find.byKey(SettingsScreen.sessionsShowAllKey);
      await tester.scrollUntilVisible(all, 100);
      await tester.tap(all);
      await tester.pumpAndSettle();

      expect(find.byType(SessionsScreen), findsOneWidget);
      for (var n = 1; n <= 4; n++) {
        expect(find.byKey(Key('session.${_id(n)}')), findsOneWidget);
      }
      // This device has no revoke action; the three others have one.
      expect(
        find.descendant(
          of: find.byKey(Key('session.${_id(3)}')),
          matching: find.text(l10n.sessionsRevoke),
        ),
        findsNothing,
      );
      expect(find.text(l10n.sessionsRevoke), findsNWidgets(3));

      final laptop = find.byKey(Key('session.${_id(4)}'));
      await tester.tap(
        find.descendant(of: laptop, matching: find.text(l10n.sessionsRevoke)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('session.revoke.confirm')));
      await tester.pumpAndSettle();

      expect(h.repo.revoked, [_id(4)]);
      expect(laptop, findsNothing);
      expect(find.text(l10n.sessionsRevoked), findsOneWidget);

      // Back on Settings the count follows the list.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(all, 100);
      expect(
        find.descendant(of: all, matching: find.text(l10n.sessionsShowAll(3))),
        findsOneWidget,
      );
    });

    testWidgets('two sessions or fewer: no «Show all» row', (tester) async {
      final four = _four();
      await _pump(tester, sessions: [four[0], four[2]]);
      await tester.scrollUntilVisible(
        find.byKey(Key('session.${_id(1)}')),
        100,
      );
      expect(find.byKey(Key('session.${_id(3)}')), findsOneWidget);
      expect(find.byKey(SettingsScreen.sessionsShowAllKey), findsNothing);
    });

    testWidgets('only this device: the «only here» line, no «Show all»', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.en);
      await _pump(tester, sessions: [_four()[2]]);
      final line = find.text(l10n.sessionsNoOthers);
      await tester.scrollUntilVisible(line, 100);
      expect(line, findsOneWidget);
      expect(find.byKey(SettingsScreen.sessionsShowAllKey), findsNothing);
    });

    test('orderSessions: this device first, others by last activity', () {
      final four = _four();
      final ordered = orderSessions([four[3], four[1], four[2], four[0]]);
      expect(ordered.map((s) => s.id), [_id(3), _id(1), _id(2), _id(4)]);
    });
  });

  group('2. dark mode switch', () {
    for (final device in Brightness.values) {
      testWidgets('untouched: follows the device (${device.name})', (
        tester,
      ) async {
        final l10n = l10nFor(AppLanguage.en);
        final h = await _pump(tester, device: device);
        expect(
          _switchValue(tester, SettingsScreen.themeKey),
          device == Brightness.dark,
        );
        expect(_appBrightness(tester), device);
        expect(find.text(l10n.settingsThemeFollowsDevice), findsOneWidget);
        expect(find.byKey(SettingsScreen.themeFollowDeviceKey), findsNothing);
        expect(h.prefs.getString(PreferenceKeys.themeMode), isNull);
      });
    }

    testWidgets('the first toggle stores an explicit choice; «Follow '
        'device» returns to automatic', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      final h = await _pump(tester);
      expect(_switchValue(tester, SettingsScreen.themeKey), isFalse);

      await tester.tap(find.byKey(SettingsScreen.themeKey));
      await tester.pumpAndSettle();
      expect(_switchValue(tester, SettingsScreen.themeKey), isTrue);
      expect(_appBrightness(tester), Brightness.dark);
      expect(h.prefs.getString(PreferenceKeys.themeMode), 'dark');
      expect(find.text(l10n.settingsThemeFollowsDevice), findsNothing);

      // Explicit light, although the device is light too.
      await tester.tap(find.byKey(SettingsScreen.themeKey));
      await tester.pumpAndSettle();
      expect(h.prefs.getString(PreferenceKeys.themeMode), 'light');
      expect(_appBrightness(tester), Brightness.light);

      await tester.tap(find.byKey(SettingsScreen.themeFollowDeviceKey));
      await tester.pumpAndSettle();
      expect(h.prefs.getString(PreferenceKeys.themeMode), 'system');
      expect(find.text(l10n.settingsThemeFollowsDevice), findsOneWidget);
      expect(find.byKey(SettingsScreen.themeFollowDeviceKey), findsNothing);
    });

    testWidgets('a stored choice wins over the device', (tester) async {
      await _pump(
        tester,
        device: Brightness.dark,
        prefs: {PreferenceKeys.themeMode: 'light'},
      );
      expect(_switchValue(tester, SettingsScreen.themeKey), isFalse);
      expect(_appBrightness(tester), Brightness.light);
      expect(find.byKey(SettingsScreen.themeFollowDeviceKey), findsOneWidget);
    });
  });

  group('3. language switch', () {
    testWidgets('«اللغة: العربية» → English: applied, stored, synced', (
      tester,
    ) async {
      final ar = l10nFor(AppLanguage.ar);
      final en = l10nFor(AppLanguage.en);
      final h = await _pump(tester, language: AppLanguage.ar);
      final tile = find.byKey(SettingsScreen.languageKey);
      expect(
        find.descendant(
          of: tile,
          matching: find.text(
            ar.settingsLanguageCurrent('\u2068العربية\u2069'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.text(
            ar.settingsLanguageSwitchTo('\u2068English\u2069'),
          ),
        ),
        findsOneWidget,
      );
      expect(_switchValue(tester, SettingsScreen.languageKey), isFalse);
      expect(
        Directionality.of(tester.element(find.byType(SettingsScreen))),
        TextDirection.rtl,
      );

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(h.prefs.getString(PreferenceKeys.languageCode), 'en');
      expect(h.repo.localeUpdates, ['en']);
      expect(_switchValue(tester, SettingsScreen.languageKey), isTrue);
      expect(
        Directionality.of(tester.element(find.byType(SettingsScreen))),
        TextDirection.ltr,
      );
      expect(
        find.text(en.settingsLanguageCurrent('\u2068English\u2069')),
        findsOneWidget,
      );

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(h.prefs.getString(PreferenceKeys.languageCode), 'ar');
      expect(h.repo.localeUpdates, ['en', 'ar']);
    });
  });

  group('4. no duplicates of the «أنا» hub', () {
    for (final language in AppLanguage.values) {
      testWidgets('no «${l10nFor(language).levelsTitle}» or '
          '«${l10nFor(language).premiumTitle}» row (${language.name})', (
        tester,
      ) async {
        final l10n = l10nFor(language);
        await _pump(tester, language: language);
        await tester.scrollUntilVisible(
          find.byKey(SettingsScreen.logoutKey),
          200,
        );
        expect(find.text(l10n.levelsTitle), findsNothing);
        expect(find.text(l10n.meHubLevels), findsNothing);
        expect(find.text(l10n.premiumTitle), findsNothing);
        // The account rows that stay.
        expect(find.byKey(SettingsScreen.usernameKey), findsOneWidget);
        expect(find.byKey(SettingsScreen.deleteAccountKey), findsOneWidget);
      });
    }
  });

  testWidgets('5. test builds: Demo data stays (gated by !kReleaseMode); '
      'the component gallery row is gone', (tester) async {
    await _pump(tester);
    final demo = find.byKey(DemoDataTile.tileKey);
    await tester.scrollUntilVisible(demo, 200);
    expect(demo, findsOneWidget);
    expect(find.byKey(const Key('settings.debug.components')), findsNothing);
  });

  group('layout: no overflow', () {
    for (final language in AppLanguage.values) {
      for (final size in const [Size(393, 852), Size(360, 800)]) {
        for (final scale in const [1.0, 1.3]) {
          for (final device in Brightness.values) {
            final name =
                '${language.name} ${size.width.toInt()}×'
                '${size.height.toInt()} ×$scale ${device.name}';
            testWidgets(name, (tester) async {
              await _pump(
                tester,
                language: language,
                size: size,
                textScale: scale,
                device: device,
              );
              expect(tester.takeException(), isNull);
              expect(_appBrightness(tester), device);
              // Every row of the screen, top to bottom.
              await tester.scrollUntilVisible(
                find.byKey(DemoDataTile.tileKey),
                200,
              );
              expect(tester.takeException(), isNull);

              // The full list too.
              final all = find.byKey(SettingsScreen.sessionsShowAllKey);
              await tester.scrollUntilVisible(all, -200);
              // Fully on screen (not under the app bar).
              await tester.ensureVisible(all);
              await tester.pumpAndSettle();
              await tester.tap(all);
              await tester.pumpAndSettle();
              expect(find.byType(SessionsScreen), findsOneWidget);
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }
  });
}
