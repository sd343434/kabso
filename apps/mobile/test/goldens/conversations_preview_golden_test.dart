// KL-056 conversation list and first-time conversation goldens (labelled
// test data), ar and en at 393×852 (insets 59 / 34) and 360×800, @3x;
// D68: the list also in the light theme (day mode) at 393×852.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/conversations_preview_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/debug/conversations_preview_screen.dart';
import 'package:kabso_live/features/debug/messages_preview_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/golden.dart';

void main() {
  forEachLanguage((language) {
    group(language.name, () {
      for (final viewport in GoldenViewport.values) {
        Future<void> pump(WidgetTester tester, Widget screen) async {
          if (viewport == GoldenViewport.phone) {
            tester.view.padding = const FakeViewPadding(
              top: 59 * GoldenViewport.pixelRatio,
              bottom: 34 * GoldenViewport.pixelRatio,
            );
            addTearDown(tester.view.resetPadding);
          }
          await pumpGolden(
            tester,
            screen,
            language: language,
            viewport: viewport,
            bare: true,
          );
        }

        testWidgets('conversations_preview (${viewport.name})', (tester) async {
          await withClock(
            Clock.fixed(DateTime(2026, 10, 18, 12)),
            () => pump(tester, const ConversationsPreviewScreen()),
          );
          await expectScreenGolden(
            'conversations_preview',
            language: language,
            viewport: viewport,
          );
        });

        testWidgets('conversation_first_time (${viewport.name})', (
          tester,
        ) async {
          await pump(
            tester,
            MessagesPreviewScreen(
              peer: language.name == 'ar' ? 'هند (تجربة)' : 'Hind (test)',
              initialMessages: const [],
            ),
          );
          await expectScreenGolden(
            'conversation_first_time',
            language: language,
            viewport: viewport,
          );
        });
      }

      testWidgets('conversations_preview_light (phone)', (tester) async {
        tester.view.padding = const FakeViewPadding(
          top: 59 * GoldenViewport.pixelRatio,
          bottom: 34 * GoldenViewport.pixelRatio,
        );
        addTearDown(tester.view.resetPadding);
        await withClock(
          Clock.fixed(DateTime(2026, 10, 18, 12)),
          () => pumpGolden(
            tester,
            const ConversationsPreviewScreen(),
            language: language,
            brightness: Brightness.light,
            bare: true,
          ),
        );
        await expectScreenGolden(
          'conversations_preview_light',
          language: language,
        );
      });
    });
  });
}
