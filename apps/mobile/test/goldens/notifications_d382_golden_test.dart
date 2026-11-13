// D382 (owner: «اجعل الإشعارات بنفس هذه الطريقة اشعر انها اجمل بنفس الحجم
// والطريقة»): the notifications page restyled.
//
//   notifications.inbox  `/notifications`: your photo and «الإشعارات» as the
//                        header; «اليوم» / «هذا الأسبوع» / «سابقاً» as plain
//                        headings; rows without cards or dividers — the
//                        photo with the kind's coloured badge, one sentence
//                        (names bold) with the short time in grey, the
//                        comment's text in grey under it (3 lines at most)
//                        and a dot on the unread rows
//
// Arabic and English, dark and light, on the phone (393 × 852 with the
// status bar 59 and the home indicator 34). A fixed clock; synthetic people.
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/notifications_d382_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/notifications/notifications_d382_fixtures.dart';
import '../helpers/fake_notifications_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    final name = language.name;
    for (final (label, brightness) in [
      ('phone', Brightness.dark),
      ('phone.light', Brightness.light),
    ]) {
      testWidgets('notifications.inbox $name $label', (tester) async {
        await loadAppFonts();
        setViewport(tester, GoldenViewport.phone);
        tester.view.padding = const FakeViewPadding(
          top: 59 * GoldenViewport.pixelRatio,
          bottom: 34 * GoldenViewport.pixelRatio,
        );
        addTearDown(tester.view.resetPadding);
        final repo = FakeNotificationsRepository()
          ..items = d382Notifications(ar: ar);
        await withClock(Clock.fixed(d382Now), () async {
          await pumpScreen(
            tester,
            const NotificationsScreen(),
            language: language,
            brightness: brightness,
            notificationsRepository: repo,
            overrides: [currentUserProvider.overrideWithValue(testUser())],
          );
          await tester.pumpAndSettle();
          await precacheImages(tester);
        });
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/notifications.inbox.$name.$label.png'),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  });
}
