// v1.140-social (D390): «برنامج سفراء Kabso».
//
//   ambassadors_d390.programme   the explanation page with the levels, the
//                                rules and the application form (programme on)
//   ambassadors_d390.dashboard   a Silver ambassador's dashboard: the badge,
//                                the commission and the progress to Gold, the
//                                code and link, this month's targets, the
//                                referrals and commissions, the history
//   ambassadors_d390.badges      the four level badges, inline and large
//
// 393 wide @3x, tall enough for the whole page (the screens scroll). Regenerate
// on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/ambassadors_d390_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/ambassadors/data/ambassador_repository.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_badge.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_dashboard_screen.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_programme_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/ambassadors/ambassador_fixtures.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final name = language.name;

    for (final (screen, widget, height) in [
      ('programme', const AmbassadorProgrammeScreen(), 1460.0),
      ('dashboard', const AmbassadorDashboardScreen(), 1270.0),
    ]) {
      testWidgets('ambassadors_d390.$screen $name', (tester) async {
        setViewport(tester, GoldenViewport.phone);
        tester.view.physicalSize = Size(393 * 3, height * 3);
        await pumpScreen(
          tester,
          widget,
          language: language,
          disableAnimations: true,
          overrides: [
            currentUserProvider.overrideWithValue(testUser()),
            ambassadorRepositoryProvider.overrideWithValue(
              FakeAmbassadorRepository(),
            ),
          ],
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/ambassadors_d390.$screen.$name.phone.png'),
        );
      });
    }

    testWidgets('ambassadors_d390.badges $name', (tester) async {
      await pumpGolden(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final large in [false, true]) ...[
              Wrap(
                spacing: KSpacing.sm,
                runSpacing: KSpacing.sm,
                children: [
                  for (final level in ['BRONZE', 'SILVER', 'GOLD', 'DIAMOND'])
                    AmbassadorBadge(level: level, large: large),
                ],
              ),
              const SizedBox(height: KSpacing.lg),
            ],
          ],
        ),
        language: language,
      );
      await expectScreenGolden('ambassadors_d390.badges', language: language);
    });
  });
}
