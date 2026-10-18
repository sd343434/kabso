// KL-056 private conversation preview goldens (labelled test data, generated
// art), ar and en at 393×852 (iPhone-class insets 59 / 34) and 360×800, @3x.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/messages_preview_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/debug/messages_preview_screen.dart';

import '../helpers/golden.dart';

void main() {
  forEachLanguage((language) {
    group(language.name, () {
      for (final viewport in GoldenViewport.values) {
        testWidgets('messages_preview (${viewport.name})', (tester) async {
          if (viewport == GoldenViewport.phone) {
            tester.view.padding = const FakeViewPadding(
              top: 59 * GoldenViewport.pixelRatio,
              bottom: 34 * GoldenViewport.pixelRatio,
            );
            addTearDown(tester.view.resetPadding);
          }
          await pumpGolden(
            tester,
            const MessagesPreviewScreen(),
            language: language,
            viewport: viewport,
            bare: true,
          );
          await expectScreenGolden(
            'messages_preview',
            language: language,
            viewport: viewport,
          );
        });
      }
    });
  });
}
