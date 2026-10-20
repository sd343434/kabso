// KL-056 live room preview goldens (labelled test data, generated art), ar and
// en at 393×852 (iPhone-class insets 59 / 34) and 360×800, @3x; D71: solo,
// PK 1 v 1 and PK 2 v 2.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_preview_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/debug/live_preview_pk.dart';
import 'package:kabso_live/features/debug/live_preview_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';

import '../helpers/golden.dart';

void main() {
  forEachLanguage((language) {
    group(language.name, () {
      for (final viewport in GoldenViewport.values) {
        for (final mode in LivePreviewMode.values) {
          // Solo keeps its original file name.
          final name = mode == LivePreviewMode.solo
              ? 'live_preview'
              : 'live_preview_${mode.name}';
          testWidgets('$name (${viewport.name})', (tester) async {
            if (viewport == GoldenViewport.phone) {
              tester.view.padding = const FakeViewPadding(
                top: 59 * GoldenViewport.pixelRatio,
                bottom: 34 * GoldenViewport.pixelRatio,
              );
              addTearDown(tester.view.resetPadding);
            }
            // D73: draw Kabi on the bar. Goldens run with reduced motion,
            // so he holds a still frame (no loops, no timers); his Lottie
            // loads in real time.
            KabsoPkBar.enabled = true;
            addTearDown(() => KabsoPkBar.enabled = false);
            await pumpGolden(
              tester,
              LivePreviewScreen(mode: mode),
              language: language,
              viewport: viewport,
              bare: true,
            );
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 500)),
            );
            await tester.pump();
            await expectScreenGolden(
              name,
              language: language,
              viewport: viewport,
            );
          });
        }
      }
    });
  });
}
