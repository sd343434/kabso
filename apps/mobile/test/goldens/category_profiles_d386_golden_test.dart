// D386 (owner 2026-11-12: «أن يكون كل شخص تفاصيل صفحته حسب فئة الحساب»;
// «الموثقة»): a profile page per verified account category — one golden per
// family in Arabic, dark and light, English for two families, and an
// unverified singer (the default look and the category word).
//
//   category_profiles_d386.<family>.ar.phone[.light].png
//   category_profiles_d386.<family>.en.phone[.light].png (music, word)
//   category_profiles_d386.unverified_singer.ar.phone.png
//   category_profiles_d386.picker.ar.phone.png (the grouped picker)
//
// 393 × 852 with the status bar 59 and the home indicator 34; a fixed
// clock; the pictures from memory. Regenerate on Linux with the pinned
// Flutter:
//   flutter test --update-goldens test/goldens/category_profiles_d386_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/category/category_models.dart';
import 'package:kabso_live/features/profile/category/category_picker.dart';
import 'package:kabso_live/features/profile/category/category_repository.dart';
import 'package:kabso_live/features/profile/category/featured_section.dart';
import 'package:material_ui/material_ui.dart';

import '../features/profile/category_profiles_harness.dart';
import '../fixtures/profile/category_profile_fixtures.dart';
import '../helpers/fake_category_profile_repository.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

Future<void> _page(
  WidgetTester tester,
  AccountCategory category, {
  required AppLanguage language,
  required Brightness brightness,
  bool verified = true,
}) async {
  final ar = language == AppLanguage.ar;
  await withClock(Clock.fixed(d386Now), () async {
    await pumpCategoryProfile(
      tester,
      d386Profile(category: category, ar: ar, verified: verified),
      section: d386Featured(category, ar: ar),
      language: language,
      brightness: brightness,
    );
    await precacheImages(tester);
    await tester.pumpAndSettle();
  });
}

String _name(CategoryFamily f) => switch (f) {
  CategoryFamily.sportsGames => 'sports_games',
  _ => f.name,
};

void main() {
  setUpAll(() async {
    await loadAppFonts();
    // The poetry cards' bundled face (D64's welcome font).
    final baloo = FontLoader(KFonts.poetry)
      ..addFont(rootBundle.load('assets/fonts/BalooBhaijaan2-SemiBold.ttf'));
    await baloo.load();
  });
  setUp(() => featuredImageFor = d386Image);
  tearDown(() => featuredImageFor = NetworkImage.new);

  for (final entry in d386FamilySample.entries) {
    final family = _name(entry.key);
    for (final brightness in Brightness.values) {
      final light = brightness == Brightness.light ? '.light' : '';
      testWidgets('$family ar$light', (tester) async {
        await _page(
          tester,
          entry.value,
          language: AppLanguage.ar,
          brightness: brightness,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'png/category_profiles_d386.$family.ar.phone$light.png',
          ),
        );
      });
    }
  }

  for (final family in [CategoryFamily.music, CategoryFamily.word]) {
    for (final brightness in Brightness.values) {
      final light = brightness == Brightness.light ? '.light' : '';
      testWidgets('${family.name} en$light', (tester) async {
        await _page(
          tester,
          d386FamilySample[family]!,
          language: AppLanguage.en,
          brightness: brightness,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'png/category_profiles_d386.${family.name}.en.phone$light.png',
          ),
        );
      });
    }
  }

  // The word family's news cards «تقاريري», and the default look (OTHER, not
  // verified) for comparison.
  testWidgets('journalist ar', (tester) async {
    await _page(
      tester,
      AccountCategory.journalist,
      language: AppLanguage.ar,
      brightness: Brightness.dark,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/category_profiles_d386.journalist.ar.phone.png'),
    );
  });

  testWidgets('default other ar', (tester) async {
    await _page(
      tester,
      AccountCategory.other,
      language: AppLanguage.ar,
      brightness: Brightness.dark,
      verified: false,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'png/category_profiles_d386.default_other.ar.phone.png',
      ),
    );
  });

  testWidgets('unverified singer ar', (tester) async {
    await _page(
      tester,
      AccountCategory.singer,
      language: AppLanguage.ar,
      brightness: Brightness.dark,
      verified: false,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'png/category_profiles_d386.unverified_singer.ar.phone.png',
      ),
    );
  });

  for (final brightness in Brightness.values) {
    final light = brightness == Brightness.light ? '.light' : '';
    testWidgets('picker ar$light', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      d386Insets(tester);
      await pumpScreen(
        tester,
        const Scaffold(
          body: SafeArea(
            child: CategoryPickerSheet(
              current: AccountCategory.quranReciter,
              verified: false,
              locked: false,
            ),
          ),
        ),
        language: AppLanguage.ar,
        brightness: brightness,
        disableAnimations: true,
        overrides: [
          categoryProfileRepositoryProvider.overrideWithValue(
            FakeCategoryProfileRepository(
              state: const CategoryVerification(
                category: AccountCategory.quranReciter,
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'png/category_profiles_d386.picker.ar.phone$light.png',
        ),
      );
    });
  }
}
