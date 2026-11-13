// D387 (owner 2026-11-12, CONVENTIONS §10.176):
//
//   ops_roles_d387.follow_us   Settings scrolled to «تابعنا»: the app's
//                              official accounts from the panel, each with a
//                              generic glyph of the app's icon set (no
//                              third-party logo art), the handle and the
//                              outside-link mark
//   ops_roles_d387.staff       «فريق كابسو» for a staff member holding
//                              TRUST_SAFETY and VIP_CARE: the roles and the
//                              «في المناوبة الآن» badge from the shift
//                              schedule, then the live shift
//
// Arabic and English, dark and light, on the phone (393 × 852 with the
// status bar 59 and the home indicator 34). A fixed clock; synthetic handles
// only. Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/ops_roles_d387_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:kabso_live/features/settings/social/official_accounts.dart';
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/features/staff/presentation/staff_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_ops_roles.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

final DateTime _now = DateTime.utc(2026, 11, 12, 12);

Future<void> _phone(WidgetTester tester) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

Future<void> _scope(
  WidgetTester tester,
  Widget screen, {
  required AppLanguage language,
  required Brightness brightness,
  List<Override> overrides = const [],
}) async {
  final prefs = await testPrefs(
    language: language.name,
    extra: {
      PreferenceKeys.themeMode: brightness == Brightness.dark
          ? 'dark'
          : 'light',
    },
  );
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        currentUserProvider.overrideWithValue(testUser()),
        ...overrides,
      ],
      child: screen,
    ),
    language: language,
    brightness: brightness,
    bare: true,
  );
  await tester.pumpAndSettle();
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final name = language.name;
    for (final (label, brightness) in [
      ('phone', Brightness.dark),
      ('phone.light', Brightness.light),
    ]) {
      testWidgets('ops_roles_d387.follow_us $name $label', (tester) async {
        await _phone(tester);
        await withClock(Clock.fixed(_now), () async {
          await _scope(
            tester,
            const SettingsScreen(),
            language: language,
            brightness: brightness,
            overrides: [
              officialAccountsRepositoryProvider.overrideWithValue(
                FakeOfficialAccounts(d387Accounts()),
              ),
            ],
          );
          await tester.scrollUntilVisible(
            find.byKey(FollowUsSection.row(3)),
            200,
          );
          await tester.drag(find.byType(Scrollable).first, const Offset(0, 80));
          await tester.pumpAndSettle();
        });
        expect(tester.takeException(), isNull);
        expect(find.byKey(FollowUsSection.headerKey), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/ops_roles_d387.follow_us.$name.$label.png'),
        );
        await _end(tester);
      });

      testWidgets('ops_roles_d387.staff $name $label', (tester) async {
        await _phone(tester);
        await withClock(Clock.fixed(_now), () async {
          await _scope(
            tester,
            const StaffScreen(),
            language: language,
            brightness: brightness,
            overrides: [
              staffStatusProvider.overrideWith(
                () => FixedStaff(
                  d387Status(roles: ['MODERATION', 'VIP_CARE'], watch: true),
                ),
              ),
              staffLivesProvider.overrideWith(
                (ref) async => const <StaffLive>[],
              ),
            ],
          );
          await precacheImages(tester);
        });
        expect(tester.takeException(), isNull);
        expect(find.byKey(StaffScreen.scheduledBadgeKey), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/ops_roles_d387.staff.$name.$label.png'),
        );
        await _end(tester);
      });
    }
  });
}
