// D300 (owner 2026-11-07): «مدرسة المحتوى» / Content School and «لاعب
// الأحكام» / Dares Player with the owner's own art of each level
// (assets/medals/PROVENANCE.md), on the D291 medals page.
//
//   medals.d300.school_sheet[.light]   the sheet at level 2: three bars
//                                      toward level 3 and the four levels
//                                      with their three thresholds and art
//   medals.d300.school_grid[.light]    the Achievements grid on a tall view:
//                                      its card with the lowest-of-three bar
//   medals.d300.school_l4[.light]      level 4 worn: the crystal-winged art
//                                      on the pedestal
//   medals.d300.creators_only          a non-creator's sheet «لصنّاع المحتوى
//                                      فقط»
//   medals.d300.dares_sheet[.light]    «لاعب الأحكام» at level 3: PK points
//                                      and the four levels with their art
//
// 393 × 852 with the status bar 59 and the home indicator 34. Regenerate on
// Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/medals_d300_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medals_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../features/bonds/bonds_harness.dart';
import '../fixtures/medals/medals_d300_fixtures.dart';
import '../helpers/golden.dart';

Future<void> _device(WidgetTester tester) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

Future<void> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.ar,
  Brightness brightness = Brightness.dark,
  int schoolLevel = 2,
  bool creator = true,
  int daresLevel = 3,
  List<String> worn = const [d300SchoolCode],
}) async {
  await _device(tester);
  final fakes = BondFakes();
  fakes.medals.medals = d300Medals(
    ar: language == AppLanguage.ar,
    schoolLevel: schoolLevel,
    creator: creator,
    daresLevel: daresLevel,
    worn: worn,
  );
  await pumpBonds(
    tester,
    const MedalsScreen(),
    fakes: fakes,
    language: language,
    brightness: brightness,
  );
  await precacheImages(tester);
}

Future<void> _sheet(
  WidgetTester tester,
  String code, {
  MedalCategory tab = MedalCategory.achievement,
}) async {
  if (tab != MedalCategory.achievement) {
    await tester.tap(find.byKey(MedalsScreen.tabKey(tab)));
    await tester.pumpAndSettle();
  }
  final card = find.byKey(MedalsScreen.medalKey(code));
  await tester.scrollUntilVisible(card, 200);
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  // A long press opens an earned medal's sheet; a tap a locked one's.
  await tester.longPress(card);
  await tester.pumpAndSettle();
  await precacheImages(tester);
}

Future<void> _expect(String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('png/$name.png'));

void main() {
  setUpAll(loadAppFonts);

  for (final brightness in Brightness.values) {
    final suffix = brightness == Brightness.light ? '.light' : '';
    testWidgets('medals.d300.school_sheet$suffix ar', (tester) async {
      await _pump(tester, brightness: brightness);
      await _sheet(tester, d300SchoolCode);
      await _expect('medals.d300.school_sheet$suffix.ar.phone');
    });
    testWidgets('medals.d300.school_grid$suffix ar', (tester) async {
      await _pump(tester, brightness: brightness);
      tester.view.physicalSize = const Size(393, 1500) * 3;
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await _expect('medals.d300.school_grid$suffix.ar.tall');
    });
    testWidgets('medals.d300.school_l4$suffix ar', (tester) async {
      await _pump(tester, brightness: brightness, schoolLevel: 4);
      await _expect('medals.d300.school_l4$suffix.ar.phone');
    });
    testWidgets('medals.d300.dares_sheet$suffix ar', (tester) async {
      await _pump(tester, brightness: brightness);
      await _sheet(tester, d300DaresCode, tab: MedalCategory.activity);
      await _expect('medals.d300.dares_sheet$suffix.ar.phone');
    });
  }

  testWidgets('medals.d300.school_sheet en', (tester) async {
    await _pump(tester, language: AppLanguage.en);
    await _sheet(tester, d300SchoolCode);
    await _expect('medals.d300.school_sheet.en.phone');
  });

  testWidgets('medals.d300.creators_only ar', (tester) async {
    await _pump(tester, schoolLevel: 0, creator: false, worn: const []);
    final card = find.byKey(MedalsScreen.medalKey(d300SchoolCode));
    await tester.scrollUntilVisible(card, 200);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await _expect('medals.d300.creators_only.ar.phone');
  });
}
