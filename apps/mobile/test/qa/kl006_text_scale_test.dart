// KL-006 (A6, QA): PHASE1_SCREENS.md §11 checklist #1 — every Phase 1 screen
// renders in ar/en, dark/light, at text scale 1.0 and 2.0 on a 360×640 dp
// screen without overflow exceptions.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/forgot_password_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/create/create_menu_sheet.dart';
import 'package:kabso_live/features/create/create_screen.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/posts/data/media_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_live_repository.dart';
import '../helpers/fakes.dart';

class _Repo extends FakeAuthRepository {
  new({super.storedUser});

  @override
  Future<List<Session>> listSessions() async => [
    Session(
      id: '0192f1c2-0000-7000-8000-000000000001',
      current: true,
      deviceName: 'A rather long device name for layout testing',
      platform: SessionPlatform.android,
      createdAt: DateTime.utc(2026, 10),
      lastUsedAt: DateTime.utc(2026, 10, 15, 12, 30),
    ),
    Session(
      id: '0192f1c2-0000-7000-8000-000000000002',
      current: false,
      platform: SessionPlatform.ios,
      createdAt: DateTime.utc(2026, 9),
      lastUsedAt: DateTime.utc(2026, 10, 2, 9, 5),
    ),
  ];
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String language,
  required String theme,
  required bool signedIn,
}) async {
  SharedPreferences.setMockInitialValues({
    PreferenceKeys.languageCode: language,
    PreferenceKeys.themeMode: theme,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveRepositoryProvider.overrideWithValue(
          FakeLiveRepository(hostingEnabled: false),
        ),
        authRepositoryProvider.overrideWithValue(
          _Repo(
            storedUser: signedIn
                ? testUser(
                    displayName: 'ليلى عبد الرحمن الطويلة الاسم جدا',
                    emailVerified: false,
                  )
                : null,
          ),
        ),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        mediaLibraryProvider.overrideWithValue(const UnsupportedMediaLibrary()),
      ],
      child: const KabsoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final language in AppLanguage.values) {
      for (final theme in [ThemeMode.dark, ThemeMode.light]) {
        final name = '${language.name}/${theme.name}/x$scale';

        testWidgets('$name: auth screens have no overflow', (tester) async {
          tester.view
            ..physicalSize = const Size(360, 640)
            ..devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await _pumpApp(
            tester,
            language: language.name,
            theme: theme.name,
            signedIn: false,
          );
          expect(tester.takeException(), isNull, reason: 'login');

          final router =
              tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
                  as GoRouter;
          for (final path in [AppRoutes.register, AppRoutes.forgotPassword]) {
            router.go(path);
            await tester.pumpAndSettle();
            expect(
              find.byType(
                path == AppRoutes.register
                    ? RegisterScreen
                    : ForgotPasswordScreen,
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull, reason: path);
          }
        });

        Future<void> signedIn(WidgetTester tester) async {
          tester.view
            ..physicalSize = const Size(360, 640)
            ..devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _pumpApp(
            tester,
            language: language.name,
            theme: theme.name,
            signedIn: true,
          );
        }

        testWidgets('$name: tabs and profile have no overflow', (tester) async {
          await signedIn(tester);
          expect(tester.takeException(), isNull, reason: 'home');
          for (final key in const [
            Key('nav.reels'),
            Key('nav.create'),
            Key('nav.messages'),
            Key('nav.profile'),
          ]) {
            await tester.tap(find.byKey(key));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$key');
            // D162: ➕ opens the menu (checked for overflow too); «منشور»
            // (Post) opens Create.
            if (key == const Key('nav.create')) {
              await tester.tap(
                find.byKey(CreateMenuSheet.choiceKey(CreateChoice.post)),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: 'Create');
            }
            // Create is full screen (no bottom bar): its Close leaves it.
            if (key == const Key('nav.create')) {
              await tester.tap(find.byKey(CreateScreen.closeKey));
              await tester.pumpAndSettle();
            }
          }
        });

        testWidgets(
          '$name: settings (sessions list) has no layout error',
          (tester) async {
            await signedIn(tester);
            await tester.tap(find.byKey(const Key('nav.profile')));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('profile.settings')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'settings');
          },
          // QA-004 fixed in KL-012 (adaptive session row).
        );
      }
    }
  }
}
