// KL-030 UI audit capture harness. NOT part of the normal test suite (it
// lives outside test/). It renders the REAL app (KabsoApp:
// MaterialApp.router, GoRouter, StatefulShellRoute, theme, l10n, bundled
// fonts) headlessly at 393×852 @3x, with fake repositories at the
// repository boundary, and writes PNGs to docs/design/audit/<set>/
// (default `2026-10-16-before`; choose another set with UI_AUDIT_SET).
//
//   cd apps/mobile && flutter test tool/ui_audit/
//
// KL-033 "after" captures of Home and Live (same viewport and names):
//
//   flutter test tool/ui_audit/ --dart-define=UI_AUDIT_SET=2026-10-16-after \
//     --name '(home|live)'
//
// These are headless Flutter renders, not device screenshots.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/app_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/registration_flow.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/helpers/fakes.dart';
import '../../test/helpers/golden.dart';

const _set = String.fromEnvironment(
  'UI_AUDIT_SET',
  defaultValue: '2026-10-16-before',
);
const _outDir = '../../docs/design/audit/$_set';
const ValueKey<String> _boundary = ValueKey('ui-audit-boundary');

/// Fixed "now" so relative times (Settings → sessions) are stable.
final DateTime _now = DateTime.utc(2026, 10, 16, 9);

/// A signed-in account with two sessions (this device + one other).
class _AuditRepo extends FakeAuthRepository {
  new({super.storedUser});

  @override
  Future<List<Session>> listSessions() async => [
    Session(
      id: 's1',
      current: true,
      createdAt: _now.subtract(const Duration(days: 3)),
      lastUsedAt: _now,
      deviceName: 'Pixel 8',
      platform: SessionPlatform.android,
      appVersion: '1.0.0',
    ),
    Session(
      id: 's2',
      current: false,
      createdAt: _now.subtract(const Duration(days: 20)),
      lastUsedAt: _now.subtract(const Duration(hours: 5)),
      deviceName: 'iPhone 15',
      platform: SessionPlatform.ios,
      appVersion: '1.0.0',
    ),
  ];
}

/// Session restore never finishes: the splash stays up.
class _HangingRestoreRepo extends FakeAuthRepository {
  @override
  Future<User?> restoreSession() => Completer<User?>().future;
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required AppLanguage language,
  required String initialLocation,
  FakeAuthRepository? repo,
  ThemeMode themeMode = ThemeMode.dark,
}) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  // tool/ is a test harness too (run with `flutter test`).
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    PreferenceKeys.languageCode: language.name,
    PreferenceKeys.themeMode: themeMode.name,
    PreferenceKeys.installed: true,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocalesProvider.overrideWithValue([language.locale]),
          authRepositoryProvider.overrideWithValue(
            repo ?? _AuditRepo(storedUser: testUser()),
          ),
          secureTokenStoreProvider.overrideWithValue(
            InMemoryTokenStore('audit.refresh'),
          ),
          initialLocationProvider.overrideWithValue(initialLocation),
          usernameDebounceProvider.overrideWithValue(Duration.zero),
        ],
        child: const KabsoApp(),
      ),
    ),
  );
  await _settle(tester);
  // Launch always passes through the splash (session restore), which
  // redirects to Login or Home; then navigate like the user would.
  if (initialLocation != AppRoutes.splash) {
    _container(tester).read(routerProvider).go(initialLocation);
    await _settle(tester);
  }
}

/// Pumps frames for a fixed time (spinners never "settle").
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: GoldenViewport.pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$_outDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(KabsoApp)));

void main() {
  for (final language in const [AppLanguage.ar, AppLanguage.en]) {
    final l = language.name;

    group(l, () {
      Future<void> run(WidgetTester tester, Future<void> Function() body) =>
          withClock(Clock.fixed(_now), body);

      testWidgets('splash', (tester) async {
        await run(tester, () async {
          await _pumpApp(
            tester,
            language: language,
            initialLocation: AppRoutes.splash,
            repo: _HangingRestoreRepo(),
          );
          await _capture(tester, 'splash.$l');
        });
      });

      for (final (name, route) in const [
        ('login', AppRoutes.login),
        ('register', AppRoutes.register),
      ]) {
        testWidgets(name, (tester) async {
          await run(tester, () async {
            await _pumpApp(
              tester,
              language: language,
              initialLocation: route,
              repo: _AuditRepo(),
            );
            await _capture(tester, '$name.$l');
          });
        });
      }

      testWidgets('code entry', (tester) async {
        await run(tester, () async {
          await _pumpApp(
            tester,
            language: language,
            initialLocation: AppRoutes.register,
            repo: _AuditRepo(),
          );
          _container(tester)
              .read(registrationFlowProvider.notifier)
              .draft = RegistrationDraft(
            email: 'layla@example.com',
            username: 'layla.k',
            displayName: 'Layla',
            password: 'pa55word!',
            codeSentAt: clock.now(),
          );
          _container(tester).read(routerProvider).go(AppRoutes.registerCode);
          await _settle(tester);
          await _capture(tester, 'register-code.$l');
        });
      });

      for (final (name, route) in const [
        ('home', AppRoutes.home),
        ('discover', AppRoutes.discover),
        ('create', AppRoutes.create),
        ('reels', AppRoutes.reels),
        ('profile', AppRoutes.profile),
        ('settings', AppRoutes.settings),
      ]) {
        testWidgets(name, (tester) async {
          await run(tester, () async {
            await _pumpApp(tester, language: language, initialLocation: route);
            await _capture(tester, '$name.$l');
          });
        });
      }

      testWidgets('home (light theme)', (tester) async {
        await run(tester, () async {
          await _pumpApp(
            tester,
            language: language,
            initialLocation: AppRoutes.home,
            themeMode: ThemeMode.light,
          );
          await _capture(tester, 'home-light.$l');
        });
      });

      testWidgets('debug component gallery (3 viewports)', (tester) async {
        await run(tester, () async {
          await _pumpApp(
            tester,
            language: language,
            initialLocation: AppRoutes.debugComponents,
          );
          await _capture(tester, 'gallery-1.$l');
          for (final page in [2, 3]) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -700),
            );
            await _settle(tester);
            await _capture(tester, 'gallery-$page.$l');
          }
        });
      });
    });
  }
}
