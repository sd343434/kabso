// D157: the search home always shows under an empty field (owner device
// finding: staging had no trends, hashtags or lives, so the old big empty
// state showed instead). Two honest states, ar and en, 393 × 852:
// this device's Recent searches alone, and nothing at all (one quiet hint
// line inside the layout). Test data only; nothing is invented on screen.
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/discover/discover_screen.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_live_repository.dart';
import '../helpers/fake_posts_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  required AppLanguage language,
  bool recent = false,
}) async {
  final ar = language == AppLanguage.ar;
  final prefs = await testPrefs(
    language: language.name,
    extra: {
      if (recent)
        'pref.recentSearches.${testUser().id}': ar
            ? const ['طبخ', 'karaoke', 'مسابقة الغناء', 'pk', 'تعارف']
            : const ['karaoke', 'cooking', 'singing contest', 'pk', 'petra'],
    },
  );
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        postsRepositoryProvider.overrideWithValue(FakePostsRepository()),
        liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
        currentUserProvider.overrideWithValue(testUser()),
      ],
      child: const DiscoverScreen(),
    ),
    language: language,
    brightness: Brightness.light,
    bare: true,
  );
  await tester.pumpAndSettle();
}

void main() {
  forEachLanguage((language) {
    testWidgets('search home: recent searches only ($language)', (
      tester,
    ) async {
      await _pump(tester, language: language, recent: true);
      await expectScreenGolden('search_home.recent', language: language);
    });

    testWidgets('search home: nothing yet, one hint line ($language)', (
      tester,
    ) async {
      await _pump(tester, language: language);
      await expectScreenGolden('search_home.hint', language: language);
    });
  });
}
