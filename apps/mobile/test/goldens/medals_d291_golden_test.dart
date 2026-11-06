// D291 (owner: «ما رأيك ان نصمم صفحة التي تعرض الميداليات بحيث يمكن ان يكون
// للميدالية ايضاً ليفيلات»): the medals page after the layout idea of a
// third-party reference (kept out of git, D40), with the owner's own art
// (2026-11-06, «استخدم هذول في صفحة الميداليات للدارك مود ولايت مود»:
// assets/medals/ — the pedestal, the card frame, the light / dark page
// backgrounds). Re-recorded for that art: the page follows the app theme.
//
//   medals.d291.empty[.light]   nothing earned: the dashed place on the
//                               pedestal, «غير مرتدية», «لا ترتدي أي ميدالية»
//   medals.d291.worn[.light]    «ملوك الثروة» level 1 (the owner's lion)
//                               alone on the pedestal; the grid:
//                               levelled, worn, top level, not obtained
//                               (greyscale art, desaturated frame)
//   medals.d291.activity        the Activity tab: progress bars and x / y
//   medals.d291.worn_x13        360 × 800 at text scale 1.3 (Arabic)
//   medals.d291.sheet[.light]   the detail sheet: levels, thresholds, «خلع»
//
// 393 × 852 with the status bar 59 and the home indicator 34 (360 × 800:
// 24 / 0). Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/medals_d291_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medal_stage.dart';
import 'package:kabso_live/features/medals/presentation/medals_screen.dart';
import 'package:kabso_live/features/medals/presentation/showcase_picker_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../features/bonds/bonds_harness.dart';
import '../fixtures/medals/medals_d291_fixtures.dart';
import '../helpers/golden.dart';

Future<void> _device(WidgetTester tester, GoldenViewport viewport) async {
  await loadAppFonts();
  setViewport(tester, viewport);
  final phone = viewport == GoldenViewport.phone;
  tester.view.padding = FakeViewPadding(
    top: (phone ? 59 : 24) * GoldenViewport.pixelRatio,
    bottom: (phone ? 34 : 0) * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

Future<void> _pump(
  WidgetTester tester, {
  required AppLanguage language,
  List<String>? worn,
  bool earned = true,
  int wealthLevel = 1,
  int luckyLevel = 2,
  GoldenViewport viewport = GoldenViewport.phone,
  Brightness brightness = Brightness.dark,
  MedalCategory tab = MedalCategory.achievement,
}) async {
  await _device(tester, viewport);
  final fakes = BondFakes();
  final ar = language == AppLanguage.ar;
  fakes.medals.medals = !earned
      ? d291NothingEarned(ar: ar)
      : worn == null
      ? d291Medals(ar: ar, wealthLevel: wealthLevel, luckyLevel: luckyLevel)
      : d291Medals(
          ar: ar,
          worn: worn,
          wealthLevel: wealthLevel,
          luckyLevel: luckyLevel,
        );
  await pumpBonds(
    tester,
    const MedalsScreen(),
    fakes: fakes,
    language: language,
    brightness: brightness,
  );
  if (tab != MedalCategory.achievement) {
    await tester.tap(find.byKey(MedalsScreen.tabKey(tab)));
    await tester.pumpAndSettle();
  }
  await precacheImages(tester);
}

Future<void> _expect(String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('png/$name.png'));

void main() {
  setUpAll(loadAppFonts);

  for (final brightness in Brightness.values) {
    final suffix = brightness == Brightness.light ? '.light' : '';
    final langs = brightness == Brightness.dark
        ? const [AppLanguage.ar, AppLanguage.en]
        : const [AppLanguage.ar];
    for (final language in langs) {
      final lang = language.name;

      testWidgets('medals.d291.empty$suffix $lang', (tester) async {
        await _pump(
          tester,
          language: language,
          earned: false,
          brightness: brightness,
        );
        await _expect('medals.d291.empty$suffix.$lang.phone');
      });

      testWidgets('medals.d291.sheet$suffix $lang', (tester) async {
        await _pump(
          tester,
          language: language,
          tab: MedalCategory.activity,
          brightness: brightness,
        );
        final card = find.byKey(MedalsScreen.medalKey('FIRST_LIVE'));
        await tester.scrollUntilVisible(card, 200);
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        // A tap stages an earned medal; a long press opens its sheet.
        await tester.longPress(card);
        await tester.pumpAndSettle();
        await precacheImages(tester);
        await _expect('medals.d291.sheet$suffix.$lang.phone');
      });
    }
    for (final language in AppLanguage.values) {
      final lang = language.name;
      testWidgets('medals.d291.worn$suffix $lang', (tester) async {
        await _pump(tester, language: language, brightness: brightness);
        await _expect('medals.d291.worn$suffix.$lang.phone');
      });
    }

    testWidgets('medals.d291.worn_x13$suffix ar android', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(
        tester,
        language: AppLanguage.ar,
        viewport: GoldenViewport.android,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      await _expect('medals.d291.worn_x13$suffix.ar.android');
    });
  }

  // «ملوك الثروة» at level 5 (the eagle) on the stage, and its sheet with
  // all six levels and their art.
  for (final brightness in Brightness.values) {
    final suffix = brightness == Brightness.light ? '.light' : '';
    testWidgets('medals.d291.wealth_l5$suffix ar', (tester) async {
      await _pump(
        tester,
        language: AppLanguage.ar,
        wealthLevel: 5,
        brightness: brightness,
      );
      await _expect('medals.d291.wealth_l5$suffix.ar.phone');
    });
    testWidgets('medals.d291.wealth_sheet$suffix ar', (tester) async {
      await _pump(
        tester,
        language: AppLanguage.ar,
        wealthLevel: 5,
        brightness: brightness,
      );
      await tester.tap(find.byKey(MedalStage.stagedKey(d291WealthCode)));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await _expect('medals.d291.wealth_sheet$suffix.ar.phone');
    });
  }

  // D291 (owner: the charm and live-hours codes are name-side icons, not
  // medals): the whole Achievements grid on a tall view, and the showcase
  // picker — only the wearable medals.
  for (final brightness in Brightness.values) {
    final suffix = brightness == Brightness.light ? '.light' : '';
    testWidgets('medals.d291.grid_all$suffix ar', (tester) async {
      await _pump(tester, language: AppLanguage.ar, brightness: brightness);
      tester.view.physicalSize = const Size(393, 1500) * 3;
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await _expect('medals.d291.grid_all$suffix.ar.tall');
    });
    testWidgets('medals.d291.picker$suffix ar', (tester) async {
      await _device(tester, GoldenViewport.phone);
      final fakes = BondFakes();
      fakes.medals
        ..medals = d291Medals(ar: true)
        ..chosen = [
          for (final m in d291Medals(ar: true))
            if (m.worn)
              ProfileMedal(
                code: m.code,
                name: m.name,
                iconKey: m.iconKey,
                level: m.shownLevel,
                iconAsset: m.shownIconAsset,
              ),
        ];
      await pumpBonds(
        tester,
        const ShowcasePickerScreen(),
        fakes: fakes,
        language: AppLanguage.ar,
        brightness: brightness,
      );
      await precacheImages(tester);
      await _expect('medals.d291.picker$suffix.ar.phone');
    });
  }

  // «سيد الحظ» at level 4 (10 B) worn first, so on the stage; its sheet with
  // the four levels and their art.
  for (final brightness in Brightness.values) {
    final suffix = brightness == Brightness.light ? '.light' : '';
    testWidgets('medals.d291.lucky_l4$suffix ar', (tester) async {
      await _pump(
        tester,
        language: AppLanguage.ar,
        worn: const [d291LuckyCode, d291WealthCode, 'FIRST_LIVE'],
        luckyLevel: 4,
        brightness: brightness,
      );
      await _expect('medals.d291.lucky_l4$suffix.ar.phone');
    });
    testWidgets('medals.d291.lucky_sheet$suffix ar', (tester) async {
      await _pump(
        tester,
        language: AppLanguage.ar,
        worn: const [d291LuckyCode, d291WealthCode, 'FIRST_LIVE'],
        luckyLevel: 4,
        brightness: brightness,
      );
      await tester.tap(find.byKey(MedalStage.stagedKey(d291LuckyCode)));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await _expect('medals.d291.lucky_sheet$suffix.ar.phone');
    });
  }

  testWidgets('medals.d291.activity en', (tester) async {
    await _pump(tester, language: AppLanguage.en, tab: MedalCategory.activity);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await _expect('medals.d291.activity.en.phone');
  });
}
