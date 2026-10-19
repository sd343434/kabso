// KL-056 comments sheet goldens (opened from the feed preview; labelled
// data, generated art), ar and en at 393×852 and 360×800, @3x.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/comments_sheet_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/debug/feed_preview_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';

import '../helpers/golden.dart';

void main() {
  forEachLanguage((language) {
    group(language.name, () {
      for (final viewport in GoldenViewport.values) {
        testWidgets('comments_sheet (${viewport.name})', (tester) async {
          if (viewport == GoldenViewport.phone) {
            tester.view.padding = const FakeViewPadding(
              top: 59 * GoldenViewport.pixelRatio,
              bottom: 34 * GoldenViewport.pixelRatio,
            );
            addTearDown(tester.view.resetPadding);
          }
          await pumpGolden(
            tester,
            const FeedPreviewScreen(),
            language: language,
            viewport: viewport,
            bare: true,
          );
          final l10n = lookupAppLocalizations(language.locale);
          await tester.tap(
            find.bySemanticsLabel(RegExp('^${l10n.feedActionComment}, ')),
          );
          await tester.pumpAndSettle();
          await expectScreenGolden(
            'comments_sheet',
            language: language,
            viewport: viewport,
          );
        });
      }
    });
  });
}
