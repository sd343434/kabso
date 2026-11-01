// D226 (owner): the cleaned-up Settings, ar and en, 393 × 852.
// - settings.light: following the device (light), the «الوضع الداكن» switch
//   off with «يتبع إعداد الجهاز»; the language switch; two sessions and
//   «عرض الكل (4)».
// - settings.dark: an explicit dark choice (switch on, «اتباع الجهاز»).
// - settings.account: the end of the list — no «مستوياتي» or «اليوزرات
//   المميزة» (they are in the «أنا» hub), no component gallery (removed);
//   Demo data is there because goldens run in a test build (!kReleaseMode).
// - sessions.all: the full list. Test data only.
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/debug/demo_entry.dart';
import 'package:kabso_live/features/settings/sessions/sessions_screen.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

final _now = DateTime.utc(2026, 11, 1, 12);

class _Repo extends FakeAuthRepository {
  @override
  Future<List<Session>> listSessions() async {
    Session s(
      String id,
      Duration ago, {
      bool current = false,
      String? name,
      SessionPlatform platform = SessionPlatform.android,
    }) => Session(
      id: id,
      current: current,
      deviceName: name,
      platform: platform,
      appVersion: '1.0.0',
      createdAt: DateTime.utc(2026, 10, 2),
      lastUsedAt: _now.subtract(ago),
    );
    return [
      s(
        's1',
        const Duration(minutes: 20),
        name: 'iPad (test)',
        platform: SessionPlatform.ios,
      ),
      s('s2', const Duration(hours: 4), platform: SessionPlatform.web),
      s('s3', const Duration(seconds: 5), current: true, name: 'Pixel (test)'),
      s('s4', const Duration(days: 6), name: 'Galaxy (test)'),
    ];
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required AppLanguage language,
  required Brightness brightness,
}) async {
  final prefs = await testPrefs(
    language: language.name,
    extra: {
      if (brightness == Brightness.dark) PreferenceKeys.themeMode: 'dark',
    },
  );
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(_Repo()),
        currentUserProvider.overrideWithValue(testUser()),
      ],
      child: screen,
    ),
    language: language,
    brightness: brightness,
    bare: true,
  );
  await tester.pumpAndSettle();
}

void main() {
  forEachLanguage((language) {
    for (final brightness in Brightness.values) {
      testWidgets('settings (${brightness.name}, $language)', (tester) async {
        await withClock(Clock.fixed(_now), () async {
          await _pump(
            tester,
            const SettingsScreen(),
            language: language,
            brightness: brightness,
          );
          await expectScreenGolden(
            'settings.${brightness.name}',
            language: language,
          );
        });
      });
    }

    testWidgets('settings: the end of the list ($language)', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await _pump(
          tester,
          const SettingsScreen(),
          language: language,
          brightness: Brightness.dark,
        );
        await tester.scrollUntilVisible(find.byKey(DemoDataTile.tileKey), 300);
        await tester.pumpAndSettle();
        await expectScreenGolden('settings.account', language: language);
      });
    });

    testWidgets('sessions: every session ($language)', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await _pump(
          tester,
          const SessionsScreen(),
          language: language,
          brightness: Brightness.dark,
        );
        await expectScreenGolden('sessions.all', language: language);
      });
    });
  });
}
