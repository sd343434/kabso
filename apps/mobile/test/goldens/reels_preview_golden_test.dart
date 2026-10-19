// KL-056 reels and posts preview goldens (labelled test data, generated art;
// stock photos are network-only and never load in tests), ar and en at
// 393×852 (iPhone-class insets 59 / 34) and 360×800, @3x.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/reels_preview_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/debug/reels_preview_screen.dart';

import '../helpers/golden.dart';

void main() {
  forEachLanguage((language) {
    group(language.name, () {
      for (final mode in ReelsMode.values) {
        for (final viewport in GoldenViewport.values) {
          testWidgets('${mode.name}_preview (${viewport.name})', (
            tester,
          ) async {
            if (viewport == GoldenViewport.phone) {
              tester.view.padding = const FakeViewPadding(
                top: 59 * GoldenViewport.pixelRatio,
                bottom: 34 * GoldenViewport.pixelRatio,
              );
              addTearDown(tester.view.resetPadding);
            }
            await pumpGolden(
              tester,
              ReelsPreviewScreen(initialMode: mode),
              language: language,
              viewport: viewport,
              bare: true,
            );
            await expectScreenGolden(
              '${mode.name}_preview',
              language: language,
              viewport: viewport,
            );
          });
        }
      }
    });
  });
}
