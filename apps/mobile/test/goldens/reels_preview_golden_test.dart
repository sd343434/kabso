// KL-056 reels and posts preview goldens (labelled test data, generated art),
// ar and en at 393×852 (iPhone-class insets 59 / 34) and 360×800, @3x.
// D75 (owner): both are the real Reels tab ([PostsPreviewScreen]) — its
// Posts and its Reels — instead of the earlier standalone reels design.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/reels_preview_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/debug/posts_preview_screen.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';

import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

void main() {
  forEachLanguage((language) {
    group(language.name, () {
      for (final tab in HomeTab.values) {
        for (final viewport in GoldenViewport.values) {
          testWidgets('${tab.name}_preview (${viewport.name})', (tester) async {
            if (viewport == GoldenViewport.phone) {
              tester.view.padding = const FakeViewPadding(
                top: 59 * GoldenViewport.pixelRatio,
                bottom: 34 * GoldenViewport.pixelRatio,
              );
              addTearDown(tester.view.resetPadding);
            }
            await pumpGolden(
              tester,
              ProviderScope(
                overrides: [
                  sharedPreferencesProvider.overrideWithValue(
                    await testPrefs(language: language.name),
                  ),
                ],
                child: PostsPreviewScreen(initialTab: tab),
              ),
              language: language,
              viewport: viewport,
              bare: true,
            );
            await expectScreenGolden(
              '${tab.name}_preview',
              language: language,
              viewport: viewport,
            );
          });
        }
      }
    });
  });
}
