// v1.82-live (D295, owner): content creators go live «صانع محتوى».
//
//   creator_lives.cards        the hub grid alternating a host's live and a
//                              creator's live (the purple badge on the
//                              creator's cards)
//   creator_lives.host_pill    the room's host pill: a creator's name with the
//                              badge, a host's without
//   creator_lives.activate     the agency owner's activation sheet: the two
//                              choices with «صانع محتوى» chosen — the 72 %
//                              note, the creator form and the ticked warning
//                              (dark and light)
//
// 393 × 852 @3x. Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/creator_lives_d295_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/agency/data/agency_repository.dart';
import 'package:kabso_live/features/agency/presentation/agency_activation_sheet.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/recruits/data/recruits_repository.dart'
    show CreatorCategory;
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/creator_live_fixtures.dart';
import '../helpers/fake_economy_repositories.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    final name = language.name;

    testWidgets('creator_lives.cards $name', (tester) async {
      await pumpGolden(
        tester,
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: KMetrics.liveGridGap,
          crossAxisSpacing: KMetrics.liveGridGap,
          childAspectRatio: KSizes.liveCardAspect,
          children: [
            for (final room in creatorLiveRooms(language))
              KLiveGridCard(room: room, onTap: () {}),
          ],
        ),
        language: language,
        padding: const EdgeInsets.all(KMetrics.liveGridPadding),
      );
      await expectScreenGolden('creator_lives.cards', language: language);
    });

    testWidgets('creator_lives.host_pill $name', (tester) async {
      await pumpGolden(
        tester,
        ColoredBox(
          color: const Color(0xFF1B1430),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: KSpacing.lg, width: double.infinity),
              KHostPill(
                hostName: ar ? 'سارة' : 'Sara',
                username: 'sara.creates',
                hostIsCreator: true,
                subtitle: ar ? 'ID: 482915730' : 'ID: 482915730',
                onFollow: () {},
              ),
              const SizedBox(height: KSpacing.lg),
              KHostPill(
                hostName: ar ? 'خالد' : 'Khalid',
                username: 'khalid',
                subtitle: 'ID: 571039284',
                onFollow: () {},
              ),
            ],
          ),
        ),
        language: language,
      );
      await expectScreenGolden('creator_lives.host_pill', language: language);
    });

    for (final brightness in Brightness.values) {
      testWidgets('creator_lives.activate ${brightness.name} $name', (
        tester,
      ) async {
        setViewport(tester, GoldenViewport.phone);
        // Tall enough for the whole sheet (choices, note, form, warning).
        tester.view.physicalSize = const Size(393 * 3, 1320 * 3);
        await pumpScreen(
          tester,
          Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: KSpacing.lg),
                child: AgencyActivationSheet(member: testHosts()[1]),
              ),
            ),
          ),
          language: language,
          brightness: brightness,
          disableAnimations: true,
          overrides: [
            agencyRepositoryProvider.overrideWithValue(FakeAgencyRepository()),
          ],
        );
        await tester.tap(find.byKey(AgencyActivationSheet.creatorChoiceKey));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(AgencyActivationSheet.categoryKey(CreatorCategory.video)),
        );
        await tester.enterText(
          find.byKey(AgencyActivationSheet.linkKey(0)),
          'https://www.youtube.com/@mona',
        );
        await tester.ensureVisible(
          find.byKey(AgencyActivationSheet.confirmKey),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(AgencyActivationSheet.confirmKey));
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, 3000),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'png/creator_lives.activate.${brightness.name}.$name.phone.png',
          ),
        );
      });
    }
  });
}
